# 🎼 Extract Instruments from Dune II / Kyrandia ADL Files

### …and optionally export them as HSC Tracker `.INS` files

This tool reads the **ADL music files** used by *Dune II* and *The Legend of Kyrandia (1992)*, lists all embedded FM instruments, and can export them to **HSC Tracker `.INS` format**.

---

## 📦 ADL File Structure (relevant parts)

According to the reverse-engineered ADL format used by Westwood’s games:

| Section                  | Size          | Notes                  |
| ------------------------ | ------------- | ---------------------- |
| Song index table         | 120 bytes     | One byte per song      |
| Track pointer table      | 250 × 2 bytes | Little-endian pointers |
| Instrument pointer table | 250 × 2 bytes | Little-endian pointers |
| Track & instrument data  | variable      | Follows pointer tables |

All pointers are **relative** to the beginning of the file’s primary block (120 bytes).

An *instrument* is stored as an **11-byte block**, tightly matching the structure used by Westwood’s `setupInstrument()` code.

---

## 🔁 ADL → HSC `.INS` Conversion

The HSC tracker expects a **12-byte** structure.
Mapping from ADL → HSC:

| ADL | HSC | Meaning                           |
| --- | --- | --------------------------------- |
| 0   | 1   | Modulator AM/VIB/EG/KSR/Multi     |
| 1   | 0   | Carrier AM/VIB/EG/KSR/Multi       |
| 2   | 8   | Feedback / algorithm              |
| 3   | 10  | Modulator waveform                |
| 4   | 9   | Carrier waveform                  |
| 5   | 3   | Modulator level                   |
| 6   | 2   | Carrier level                     |
| 7   | 5   | Modulator attack/decay            |
| 8   | 4   | Carrier attack/decay              |
| 9   | 7   | Modulator sustain/release         |
| 10  | 6   | Carrier sustain/release           |
| —   | 11  | (set to 0; finetune/slide unused) |

The exporter automatically converts and saves them as **`00.INS`, `01.INS`, …`NN.INS`**.

---

# 🚀 Usage

## 1️⃣ List all instruments

```bash
python adl_extract.py dune7.adl
```

Example output:

```
ADL size: 18432 bytes
Instrument   0: ptrIndex= 14  rel=0x1234  off=0x12AC  bytes: 23 01 0F 03 ...
Instrument   1: ptrIndex= 15  rel=0x1250  off=0x12C8  bytes: 21 02 10 04 ...
...
Total *unique* instruments found: 14
```

The script automatically eliminates **duplicate pointers** referencing the same instrument data.

---

## 2️⃣ Export instruments as `.INS`

### Export to current directory:

```bash
python adl_extract.py dune7.adl --export
```

Creates:

```
00.INS
01.INS
02.INS
...
```

---

### Export to a custom directory:

```bash
python adl_extract.py dune7.adl --export --export-dir instruments/
```

If the directory does not exist, it will be created.

---

# 🎧 Notes on Sound Quality

Some exported instruments may sound *different* from how they sound in-game because:

* Westwood added runtime effects (dynamic volume, vibrato, tremolo),
* Some instruments were modified per-note or per-track,
* ADL format stores only static operator parameters.

The `.INS` data is still valid and fully compatible with **HSC Tracker** and tools expecting the same 12-byte layout.
