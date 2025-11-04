Got it—here’s a clean, self-contained Markdown “mini-spec” for **HSC (HSC Adlib Composer / HSC-Tracker)** as implemented by AdPlug’s player. I pulled it straight from `hsc.h` and `hsc.cpp` and organized it into layout, structures, decoding rules, and playback behavior.

---

# HSC Format — AdPlug Implementation Notes

**Primary source:** AdPlug’s HSC player (`ChscPlayer`) in `src/hsc.h` and `src/hsc.cpp`. ([GitHub][1])

> This document describes how AdPlug expects/decodes HSC files: file layout, pattern/event encoding, instruments, order list, and the runtime behavior (speed/timing, effects, percussion mode).

---

## High-level layout

AdPlug validates and parses an HSC file as:

* **Instrument block**: 128 instruments × **12 bytes** each = **1536 bytes**.
* **Order list** (“tracklist” / song arrangement): **51 bytes**.
* **Pattern data**: each pattern is **64 rows × 9 channels × 2 bytes = 1152 bytes**.
  Total pattern bytes = `number_of_patterns * 1152`.

Validation constants from the loader:

* Minimum plausible size: `1536 (instr) + 51 (orders) + 1152 (1 pattern) = 1587 + 1152`.
* Maximum sanity check: `< 59188` (some files have a trailing `0x00`, hence “+1” in code).
* Pattern count derived as:
  `total_patterns = (filesize - 1587) / 1152`. ([GitHub][2])

---

## In-memory structures (AdPlug)

### Player class + key fields

From `hsc.h`:

```cpp
class ChscPlayer : public CPlayer {
  ...
  struct hscnote { unsigned char note, effect; };      // pattern cell (2 bytes)
  struct hscchan { unsigned char inst;                 // current instrument
                   signed char  slide;                 // manual slide accumulator
                   unsigned short freq; };            // current OPL F-number

  hscchan channel[9];                 // 9 AdLib voices
  unsigned char instr[128][12];       // instrument data (12 bytes each)
  unsigned char song[0x80];           // order list (AdPlug reads 51 bytes)
  hscnote patterns[50][64*9];         // up to 50 patterns, each 64 rows * 9 ch
  unsigned char pattpos, songpos;     // current row/order
  unsigned char pattbreak, songend, mode6, bd, fadein;
  unsigned int  speed, del;           // speed/tick counters
  unsigned char adl_freq[9];          // cached OPL freq reg hi bits
  int mtkmode;                        // MPU-401 Trakker compatibility hack
  ...
};
```

The player reports a **fixed refresh of 18.2 Hz** (PIT tick), i.e. `getrefresh() { return 18.2f; }`. ([GitHub][1])

---

## File sections in detail

### 1) Instrument block (1536 bytes = 128 × 12)

AdPlug loads 128 instruments of **12 bytes** each, then applies a small **fix-up** to a few fields:

```cpp
for (i=0; i<128*12; i++) instr_flat[i] = f->readInt(1);

for (i=0; i<128; i++) {
  instr[i][2] ^= (instr[i][2] & 0x40) << 1;   // adjust KSL/TL bit
  instr[i][3] ^= (instr[i][3] & 0x40) << 1;   // adjust KSL/TL bit
  instr[i][11] >>= 4;                         // pitch slide nibble normalization
}
```

Instrument bytes are then used to program OPL registers as follows:

```cpp
// Set channel (feedback/connection)
opl->write(0xc0 + chan, ins[8]);

// Operator params (carrier vs modulator are addressed via +op_table[chan]
// and by choosing 0x23/0x63/0x83/0xE3 for "carrier" vs 0x20/0x60/0x80/0xE0 for "modulator")

// "Characteristics" (trem/vib/sus/KSR + multiple):
opl->write(0x23 + op, ins[0]);   // carrier
opl->write(0x20 + op, ins[1]);   // modulator

// Attack/Decay:
opl->write(0x63 + op, ins[4]);   // carrier (decay low nibble, attack high nibble)
opl->write(0x60 + op, ins[5]);   // modulator

// Sustain/Release:
opl->write(0x83 + op, ins[6]);   // carrier (release low nibble, sustain high nibble)
opl->write(0x80 + op, ins[7]);   // modulator

// Waveform select:
opl->write(0xE3 + op, ins[9]);   // carrier (2 LSBs meaningful)
opl->write(0xE0 + op, ins[10]);  // modulator

// Total level (KSL/TL): written via setvolume() using ins[2] (carrier) and ins[3] (modulator)
```

> Practical mapping summary:
>
> * `ins[8]` → `0xC0+chan` (feedback + connection bit)
> * `ins[0]/ins[1]` → `0x23/0x20 + op` (trem/vib/sus/KSR/multiple)
> * `ins[4]/ins[5]` → `0x63/0x60 + op` (attack/decay)
> * `ins[6]/ins[7]` → `0x83/0x80 + op` (sustain/release)
> * `ins[9]/ins[10]` → `0xE3/0xE0 + op` (waveform)
> * `ins[2]/ins[3]` → total level (written to `0x43/0x40 + op` with masking)
> * `ins[11]` → pitch slide base (added to F-number), stored in the high nibble originally; AdPlug shifts it down (`>>=4`). ([GitHub][2])

> **Note:** The bit-twiddle on `ins[2]` and `ins[3]` corrects a KSL/TL quirk in some HSC banks. AdPlug masks with `~63` when writing TL so KSL bits survive. ([GitHub][2])

---

### 2) Order list (“song”)

* AdPlug reads **51 bytes** into `song[]`.
* Values ≥ `0xB2` are treated as “end/invalid” safeguards; `0xFF` explicitly marks **end of song**.
* Values with **bit 7 set** (i.e. `>= 0x80`) and `<= 0xB1` are **“goto pattern”** control words; the low 7 bits are interpreted as a jump target.
* Otherwise, values are pattern numbers.
* A **sanity check** clamps out-of-range entries to `0xFF` if they exceed the computed total pattern count or `0x31`. ([GitHub][2])

Helpers:

* `getpatterns()` scans orders to find the **highest** pattern index and returns `max+1`.
* `getorders()` returns the count up to the first `0xFF`. ([GitHub][2])

---

### 3) Pattern data

* Up to **50 patterns** are stored, each pattern = **64 rows × 9 channels**.
* Each cell is an **`hscnote`** (2 bytes):
  **`note`** (1 byte) and **`effect`** (1 byte).
* On disk this is a flat block per pattern, size **1152 bytes**. ([GitHub][2])

**Reading:** AdPlug bulk-reads the pattern area directly into `patterns[50][64*9]`. (The size math throughout the loader uses 1152 per pattern.) ([GitHub][2])

---

## Pattern cell semantics

For each row & channel, AdPlug decodes:

* **Instrument set:** if `note & 0x80` (bit 7 set), then the cell means “**set instrument**” and the **`effect`** byte is taken as the instrument number. No note is played for that cell.

* **Note event:** otherwise, if `note != 0`, it’s a note trigger:

  * AdPlug decrements the value once (`note--`).
  * A **pause** (key-off) is recognized when (after the decrement) `note == 0x7E` *or* the computed octave is invalid; in that case AdPlug clears the “key on” bit.
  * Otherwise, it computes octave and F-number:

    ```
    octave = ((note / 12) & 7) << 2
    fnr    = note_table[note % 12] + instr[inst][11] + channel[chan].slide
    ```

    Then it sets frequency registers and optionally the key-on bit (unless in drum channels under mode6).
  * If `mtkmode` (an MPU-401 Trakker compatibility toggle) is on, AdPlug applies an extra `note--` before computing pitch. ([GitHub][2])

* **No note change:** if `note == 0`, only effects (if any) apply. ([GitHub][2])

---

## Effects (by high nibble of `effect`)

AdPlug handles the following effect categories (the **low nibble** is `eff_op`):

### `0x00` — “Global” control (specials)

* `0x01` — **Pattern break** (advance to next order)
* `0x03` — **Fade in** (internal fade counter set to 31; applied to volumes)
* `0x05` — **6-voice mode ON** (OPL rhythm mode enabled; channels 6–8 used for drums)
* `0x06` — **6-voice mode OFF** (return to 9 melodic voices)

(Notes in code say some global main-volume slides are intentionally not implemented because no known HSCs use them that way.) ([GitHub][2])

### `0x10` and `0x20` — **Manual pitch slides**

* `0x1?` → slide **down** by `eff_op`
* `0x2?` → slide **up** by `eff_op`
  AdPlug updates both the **current freq** and the per-channel **slide accumulator**. If no simultaneous note is triggered, it writes the new frequency immediately. ([GitHub][2])

### `0x50` — Set percussion instrument (**unimplemented**)

Placeholder; ignored by AdPlug. ([GitHub][2])

### `0x60` — **Set feedback**

Writes channel feedback/connection:
`opl->write(0xC0 + chan, (ins[8] & 1) + (eff_op << 1))`.
(LSB from instrument’s connection bit is preserved.) ([GitHub][2])

### `0xA0` — **Set carrier volume**

`vol = eff_op << 2` → written to `0x43 + op` (TL for carrier) with masking to preserve KSL bits. ([GitHub][2])

### `0xB0` — **Set modulator volume**

Same as above, but to `0x40 + op` (TL for modulator). If the instrument uses “carrier as output,” it uses the carrier’s TL slot appropriately. ([GitHub][2])

### `0xC0` — **Set instrument volume** (both ops)

Sets a common dB level (`eff_op << 2`) to carrier TL and (if carrier-output flag is set) also to modulator TL. ([GitHub][2])

### `0xD0` — **Position jump**

`pattbreak++; songpos = eff_op; songend = 1;` (forces order jump). ([GitHub][2])

### `0xF0` — **Set speed**

`speed = eff_op; del = ++speed;` (see timing below). ([GitHub][2])

---

## Timing, speed, and flow

* **Refresh rate:** hard-coded **18.2 Hz**. Every `update()` call simulates one tick. ([GitHub][1])
* **Speed handling:** The pair `(speed, del)` controls when a row advances. At the top of `update()` it decrements `del`; if not zero, it returns (no row advance).

  * On `F0` effect, `speed = eff_op; del = ++speed;`.
* **Row/order advance:**

  * If `pattbreak` got set by an effect, AdPlug resets `pattpos` to 0, advances `songpos` (mod 50), and flags end when wrapping.
  * Otherwise it increments `pattpos` (mod 64); on wrap it advances `songpos` similarly.
* **Order values ≥ `0xB2`** or otherwise “weird” are normalized to avoid reading out of bounds; `0xFF` terminates. ([GitHub][2])

---

## Rhythm (6-voice) mode

When **mode6** is ON (via effect `0x05`) AdPlug enables OPL **rhythm**:

* **Melodic voices**: channels 0–5 (six voices)
* **Drums**: channels 6, 7, 8 become:

  * 6 → **Bass Drum** (sets/clears bits 4/5 of `0xBD`)
  * 7 → **Hi-Hat** (bit 0)
  * 8 → **Cymbal** (bit 1)

On each note for channels 6–8, AdPlug manipulates `0xBD` to trigger the respective drum(s). It never sets the “key on” bit for those channels in rhythm mode. ([GitHub][2])

---

## Utility getters

* `getpatterns()` — scans orders and returns the highest referenced pattern index + 1.
* `getorders()` — counts until the first `0xFF`.
* `getinstruments()` — counts how many of the 128 have any non-zero byte. ([GitHub][2])

---

## Writer’s hints (if you build an exporter)

If you’re generating an HSC **from scratch** that AdPlug can play:

1. **Write instruments:** 128 × 12 bytes.

   * If you don’t want to define them yet, you can write zeroes and set instruments later in a tracker.
   * Be aware AdPlug applies the KSL fix and `>>=4` to byte 11.

2. **Write order list (51 bytes):**

   * Fill with pattern numbers (0..max), terminate with `0xFF`.
   * You can use `0x80..0xB1` encodings for “goto pattern” if desired.

3. **Write patterns:** for each pattern you have, output **64 × 9 × 2** bytes (`note`, `effect` per cell).

   * To **set instrument** on a channel: put `note` with bit 7 = 1, and `effect = instrument_index`.
   * To **play a note**:

     * `note` = 1..N (AdPlug decrements once internally; 0 is “no note change”).
     * Special pause is recognized via the post-decrement check (`0x7E`); you can also just emit a “no note” and rely on key-off semantics in your flow.
   * To leave a cell empty: `note = 0, effect = 0`.

4. **Speed:** you can set an initial speed by placing an `F0xx` effect at row 0 in one channel (e.g., `0xF006`).

5. **Percussion:** to use OPL rhythm, emit `0x05` (global) to enable, and write drum notes on channels 6–8. (AdPlug ignores `0x50` “set percussion instrument”.)

Everything above is exactly how AdPlug’s `ChscPlayer` will read and interpret the file. ([GitHub][1])

---

## Known quirks / caveats

* **Instrument TL/KSL fix-ups:** HSC instrument banks sometimes store TL/KSL bits in a way that AdPlug corrects at load time. If you’re producing instruments externally, expect AdPlug to do:

  ```
  ins[2] ^= (ins[2] & 0x40) << 1;
  ins[3] ^= (ins[3] & 0x40) << 1;
  ins[11] >>= 4;
  ```

  before use. ([GitHub][2])

* **Pattern count cap:** AdPlug allocates for **50 patterns** (`patterns[50][...]`) and validates orders accordingly; very large pattern indices will be clamped/end-stopped during load. ([GitHub][1])

* **Refresh is fixed:** 18.2 Hz tick; `speed` controls how many ticks per row. If you want exact tempo mapping from MIDI, you must quantize to rows and choose an `F0xx` that feels right at 18.2 Hz. ([GitHub][1])

---

## Appendix: Quick register map used by instruments

(Where `op` is the operator base from `op_table[chan]`.)

| Instrument byte | OPL register written          | Meaning (OPL2)                         |
| --------------: | ----------------------------- | -------------------------------------- |
|        `ins[8]` | `0xC0 + chan`                 | Feedback + connection bit              |
|        `ins[0]` | `0x23 + op`                   | **Carrier**: trem/vib/sus/KSR + mult   |
|        `ins[1]` | `0x20 + op`                   | **Modulator**: trem/vib/sus/KSR + mult |
|        `ins[4]` | `0x63 + op`                   | **Carrier**: Attack/Decay              |
|        `ins[5]` | `0x60 + op`                   | **Modulator**: Attack/Decay            |
|        `ins[6]` | `0x83 + op`                   | **Carrier**: Sustain/Release           |
|        `ins[7]` | `0x80 + op`                   | **Modulator**: Sustain/Release         |
|        `ins[9]` | `0xE3 + op`                   | **Carrier**: Waveform (2 LSBs)         |
|       `ins[10]` | `0xE0 + op`                   | **Modulator**: Waveform (2 LSBs)       |
|        `ins[2]` | `0x43 + op` (via `setvolume`) | **Carrier** TL (mask preserves KSL)    |
|        `ins[3]` | `0x40 + op` (via `setvolume`) | **Modulator** TL (mask preserves KSL)  |
|       `ins[11]` | (added to F-number)           | Pitch slide base (after `>> 4` fix)    |

All register writes and comments come directly from AdPlug’s `setinstr()`/`setvolume()` implementations. ([GitHub][2])

---

If you want, I can also produce a compact **writer’s template** (structs + minimal encoder) in C/C#/Python that matches this spec exactly.

[1]: https://raw.githubusercontent.com/adplug/adplug/refs/heads/master/src/hsc.h "raw.githubusercontent.com"
[2]: https://raw.githubusercontent.com/adplug/adplug/refs/heads/master/src/hsc.cpp "raw.githubusercontent.com"
