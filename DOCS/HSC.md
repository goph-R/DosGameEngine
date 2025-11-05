# 🎵 HSC Music File Format Specification

*(HSC AdLib Composer / HSC Tracker, OPL2 Music Data Format)*

---

## Overview

The **HSC file format** stores music sequences composed for **AdLib (OPL2)** synthesizers.
It contains 128 instruments, a pattern order list, and pattern data (note and effect pairs).
Each HSC file represents a complete song that can be played by a 9-channel OPL2 synthesizer.

| Section         | Description                                    | Size              |
| --------------- | ---------------------------------------------- | ----------------- |
| Instrument bank | 128 instruments × 12 bytes                     | 1536 bytes        |
| Order list      | Sequence of pattern indices (51 bytes typical) | 51 bytes          |
| Pattern data    | 64 rows × 9 channels × 2 bytes per pattern     | 1152 × N patterns |

---

## File Layout Summary

| Offset | Size | Description                                                     |
| -----: | ---- | --------------------------------------------------------------- |
| 0x0000 | 1536 | Instrument data (128 × 12 bytes)                                |
| 0x0600 | 51   | Order list (pattern sequence)                                   |
| 0x0633 | ...  | Pattern data (each 1152 bytes = 64 rows × 9 channels × 2 bytes) |

The number of patterns is derived as:

```
pattern_count = (file_size - 1587) / 1152
```

---

## 1. Instrument Block (1536 bytes)

Each instrument is **12 bytes** and defines all OPL2 register parameters for one sound.

| Byte | Register Written       | Description                                           |
| ---: | ---------------------- | ----------------------------------------------------- |
|    0 | 0x23 + op              | Carrier: Tremolo/Vibrato/Sustain/KSR + Multiple       |
|    1 | 0x20 + op              | Modulator: Tremolo/Vibrato/Sustain/KSR + Multiple     |
|    2 | 0x43 + op              | Carrier Total Level (TL) / KSL — bit corrected        |
|    3 | 0x40 + op              | Modulator Total Level (TL) / KSL — bit corrected      |
|    4 | 0x63 + op              | Carrier Attack/Decay                                  |
|    5 | 0x60 + op              | Modulator Attack/Decay                                |
|    6 | 0x83 + op              | Carrier Sustain/Release                               |
|    7 | 0x80 + op              | Modulator Sustain/Release                             |
|    8 | 0xC0 + chan            | Feedback + Connection                                 |
|    9 | 0xE3 + op              | Carrier waveform select                               |
|   10 | 0xE0 + op              | Modulator waveform select                             |
|   11 | (not written directly) | Pitch slide base (upper nibble, normalized)           |

A nibble is a group of 4 bits — exactly half a byte.

### Bit Correction Details (`ins[2]`, `ins[3]`, `ins[11]`)

The original **HSC instrument format** (as produced by early HSC Tracker/AdLib Composer versions) stored certain **OPL2 register fields** in a slightly inconsistent way compared to the actual **AdLib chip layout**.
When AdPlug (and compatible players) load instruments, they apply the following fix-ups:

```cpp
ins[2] ^= (ins[2] & 0x40) << 1  // adjust carrier TL/KSL bit overlap 
ins[3] ^= (ins[3] & 0x40) << 1  // adjust modulator TL/KSL bit overlap
ins[11] >>= 4                   // normalize pitch slide nibble
```

#### 1. KSL/TL Bit Fix (`ins[2]` and `ins[3]`)

* Each operator in the OPL2 has a **Total Level (TL)** register:

  ```
  Bits 0–5 → Volume level (0–63)
  Bits 6–7 → Key Scale Level (KSL)
  ```

* In some HSC instrument banks, the **bit 6 (value 0x40)** — the lowest KSL bit — was **misaligned** due to the tracker’s internal byte packing.
  This caused the TL and KSL fields to overlap incorrectly: e.g., a KSL value of 1 might double the intended TL level.

* The expression

  ```cpp
  ins[x] ^= (ins[x] & 0x40) << 1
  ```

  effectively **swaps** the misplaced KSL bit into its proper position (bit 7).
  In other words, if bit 6 was set, bit 7 becomes set too, restoring the correct KSL value.

* This ensures the written OPL registers (`0x40+op` and `0x43+op`) receive the right 2-bit KSL field and a clean 6-bit TL value.

#### 2. Pitch Slide Normalization (`ins[11]`)

* Byte 11 of each instrument stores a **base frequency offset**, used by the tracker’s pitch-slide effect.
* The original HSC files encoded this offset in the **upper nibble** (bits 4–7) only.
  For example, an instrument might have `ins[11] = 0xA0`, meaning a slide base of `0x0A`.
* AdPlug shifts it down with:

  ```cpp
  ins[11] >>= 4
  ```

  so the value becomes a normal 4-bit integer (0–15) that can be directly added to the F-number during note playback.

---

**Summary:**
These adjustments correct for historical quirks in how the tracker saved instrument bytes.
They ensure that the reconstructed OPL register values match what the composer actually heard when saving the `.HSC` file — preserving tone and pitch consistency across players.


---

## 2. Order List (Song Sequence)

| Description                  | Notes                                        |
| ---------------------------- | -------------------------------------------- |
| Contains up to **51 bytes**  | Each byte = pattern index                    |
| `0xFF`                       | End of song                                  |
| `0x80..0xB1`                 | Goto pattern command (lower 7 bits = target) |
| `>= 0xB2`                    | Invalid / treated as song end                |
| Out-of-range pattern indices | Clamped to valid count (≤ 50)                |

Pseudo-code to read:

```text
orders = read(51)
for each entry:
    if entry == 0xFF → end_of_song
    else if entry >= 0x80 and entry <= 0xB1 → jump to entry & 0x7F
    else if entry >= 0xB2 → treat as 0xFF
```

---

## 3. Pattern Data

Each pattern = **64 rows × 9 channels**, where each cell is 2 bytes:

| Byte | Name     | Description                      |
| ---: | -------- | -------------------------------- |
|    1 | `note`   | Note number or instrument marker |
|    2 | `effect` | Effect or instrument number      |

### Pattern Size:

```
64 rows × 9 channels × 2 bytes = 1152 bytes
```

### Note Cell Meaning

| Condition                | Action                                                |
| ------------------------ | ----------------------------------------------------- |
| `note == 0`              | No note change (effects may still apply)              |
| `note & 0x80 != 0`       | Set instrument → `effect = instrument number`         |
| `note != 0`              | Play note: AdPlug decrements value by 1 before lookup |
| Resulting `note == 0x7E` | Key-off (pause)                                       |

---

## 4. Effects (by High Nibble of Effect Byte)

| High Nibble | Description                   | Behavior                                                                            |
| ----------- | ----------------------------- | ----------------------------------------------------------------------------------- |
| `0x00`      | Global control                | 01: Pattern break<br>03: Fade in<br>05: 6-voice rhythm ON<br>06: 9-voice melodic ON |
| `0x10`      | Pitch slide down              | Decrease frequency by low nibble                                                    |
| `0x20`      | Pitch slide up                | Increase frequency by low nibble                                                    |
| `0x50`      | Set percussion instrument     | (Unused)                                                                            |
| `0x60`      | Set feedback                  | `C0+chan = (ins[8]&1) + (low_nibble<<1)`                                            |
| `0xA0`      | Set carrier volume            | TL of carrier = `(low_nibble << 2)`                                                 |
| `0xB0`      | Set modulator volume          | TL of modulator = `(low_nibble << 2)`                                               |
| `0xC0`      | Set overall instrument volume | Both ops’ TL set to `(low_nibble << 2)`                                             |
| `0xD0`      | Position jump                 | Jump to order `low_nibble`                                                          |
| `0xF0`      | Set speed                     | Speed = `low_nibble`                                                                |

---

## 5. Timing & Playback

| Parameter             | Description                                    |
| --------------------- | ---------------------------------------------- |
| Refresh rate          | 18.2 Hz (one tick per PIT IRQ0 interval)       |
| Speed                 | Rows per tick counter (`speed`, `del`)         |
| Speed effect (`F0xx`) | Sets `speed = value`, `del = speed + 1`        |
| Rows per pattern      | 64                                             |
| Channels              | 9 total, or 6 melodic + 3 drums in rhythm mode |

Pseudo-logic per update tick:

```text
if (--del == 0):
    del = speed
    advance row
else:
    process effects only
```

---

## 6. Rhythm (6-Voice) Mode

Enabled by effect `05`.
Channels 0–5 remain melodic, while channels 6–8 become drums:

| Channel | Drum      | Bit in 0xBD |
| ------- | --------- | ----------- |
| 6       | Bass Drum | Bits 4–5    |
| 7       | Hi-Hat    | Bit 0       |
| 8       | Cymbal    | Bit 1       |

When rhythm mode is active, note events on channels 6–8 toggle these bits instead of normal note-on.

---

## 7. End-of-Song Behavior

When the order list hits `0xFF` or an invalid pattern index:

```
songend = true
reset songpos to 0 (or stop playback)
```

If a pattern break (`01` effect) occurs, the player skips remaining rows in the current pattern and proceeds to the next order.

---

## 8. Suggested Writer Implementation

When producing `.HSC` files programmatically:

1. **Write 128 instruments** — 12 bytes each (zeros allowed if not defined).
2. **Write order list (51 bytes)** — pattern numbers, ending with `0xFF`.
3. **Write patterns** — each 64×9×2 bytes.
4. **Encode cells:**

   * Set instrument: `note |= 0x80`, `effect = instrument_index`.
   * Play note: `note = pitch_number`, `effect = effect_byte`.
   * Empty cell: `note = 0`, `effect = 0`.
5. **Initial speed:** place an `F0xx` effect on first row (typ. `F006`).
6. **Enable drums:** issue `05` (global) in a control channel.

---

## 9. Practical Limits

| Property         | Limit |
| ---------------- | ----- |
| Instruments      | 128   |
| Patterns         | 50    |
| Orders           | 51    |
| Channels         | 9     |
| Rows per pattern | 64    |

---

## 10. Example Pseudocode: Pattern Decoding

```pseudocode
for each row in 64:
  for each chan in 9:
    note = read_byte()
    eff  = read_byte()

    if note & 0x80:
        instrument[chan] = eff
        continue

    if note == 0:
        apply_effect(chan, eff)
        continue

    note = note - 1
    if note == 0x7E:
        key_off(chan)
        continue

    pitch = note_table[note % 12] + instrument[chan].pitchbase + slide[chan]
    octave = ((note / 12) & 7) << 2
    set_frequency(chan, pitch, octave)
    apply_effect(chan, eff)
```

---

## 11. Implementation Notes

* The **fixed tick rate** (18.2 Hz) matches the PC timer interrupt frequency.
* **Speed** defines how many ticks per row; lower values = faster playback.
* **Instrument TL/KSL** correction ensures compatibility with older HSC data banks.
* Pattern arrays are capped at 50; exceeding this may cause truncation.

---

## 12. Reference

Specification derived from analysis of AdPlug’s `hsc.h` and `hsc.cpp` (licensed open source)
but rewritten as an **independent, formal description** for implementers of HSC readers/writers.
