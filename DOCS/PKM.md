# 📘 PKM File Format Specification (GrafX2 2.00, v1.08 — 1997)

> **Author:** Karl Maritaud
> **Source:** GrafX2 Technical Documentation (TECH_ENG.TXT, May 10, 1997)
> **Purpose:** Defines the `.PKM` 256-color bitmap format used by GrafX2.

---

## 🧩 Overview

PKM (“**Piksel Map**”) is a simple, compact image format created for GrafX2.
It was designed to be:

* **Easy to encode and decode**
* **Evolutive** (via optional post-header fields)
* **Limited to 256 colors**

Compression is RLE-based and performs well on pixel art or low-complexity images.

> ⚠️ PKM uses 6-bit RGB components (0–63) instead of 8-bit (0–255).

---

## 📄 File Layout

A PKM file is composed of three sections:

1. **Header** — Fixed 780 bytes (includes palette)
2. **Post-Header** — Variable size (optional metadata fields)
3. **Image Data** — RLE-compressed pixels

---

## 🧱 Header Structure

| Offset | Field         | Type        | Size | Description                                  |
| :----: | ------------- | :---------- | :--- | -------------------------------------------- |
|   `0`  | **Signature** | `char[3]`   | 3    | Constant string `"PKM"` (no null-terminator) |
|   `3`  | **Version**   | `byte`      | 1    | File version (currently `0`)                 |
|   `4`  | **Pack_byte** | `byte`      | 1    | Recognition byte for 1-byte repeat packets   |
|   `5`  | **Pack_word** | `byte`      | 1    | Recognition byte for 2-byte repeat packets   |
|   `6`  | **Width**     | `word`      | 2    | Image width (pixels)                         |
|   `8`  | **Height**    | `word`      | 2    | Image height (pixels)                        |
|  `10`  | **Palette**   | `byte[768]` | 768  | 256 × (R,G,B), values 0–63                   |
|  `778` | **PH_size**   | `word`      | 2    | Post-Header size in bytes (can be 0)         |

> Multi-byte values are **little-endian** (Intel convention).

---

## 🗒️ Post-Header (Optional Fields)

The **post-header** is an extensible structure of *field entries*.
Each entry has the format:

```
[FieldID][FieldSize][FieldData...]
```

| Field ID | Description                        | Size                | Example                       |
| :------: | ---------------------------------- | :------------------ | :---------------------------- |
|    `0`   | **Comment**                        | 1–255 bytes         | `[0][16]["Picture by X-Man"]` |
|    `1`   | **Original Screen Dimensions**     | 4 bytes (two words) | `[1][4][320][256]`            |
|    `2`   | **Back (Transparent) Color Index** | 1 byte              | `[2][1][255]`                 |

### Behavior

* Unknown fields can be skipped using the size byte.
* If a field’s range overlaps image data, the file is invalid.
* Strings are **not null-terminated** (size is explicit).

---

## 🧮 Image Compression Method

PKM uses a **Run-Length Encoding (RLE)** scheme optimized for horizontal color repetitions.

Compression efficiency increases when the same color repeats ≥ 3 times.

---

### 📘 Decompression Algorithm (Pseudo-code)

```pseudocode
BEGIN
  Image_size  ← Header.Width × Header.Height
  Data_size   ← File_length(File) − (780 + Header.PH_size)

  Packed_data_counter ← 0
  Pixels_counter      ← 0

  WHILE Pixels_counter < Image_size AND Packed_data_counter < Data_size DO
    Byte_read ← Read_byte(File)

    IF Byte_read ≠ Header.Pack_byte AND Byte_read ≠ Header.Pack_word THEN
      Draw_pixel(Pixels_counter MOD Header.Width,
                 Pixels_counter DIV Header.Width,
                 Byte_read)
      Pixels_counter      ← Pixels_counter + 1
      Packed_data_counter ← Packed_data_counter + 1

    ELSE IF Byte_read = Header.Pack_byte THEN
      Color     ← Read_byte(File)
      Byte_read ← Read_byte(File)
      REPEAT Byte_read times:
         Draw_pixel(next position, Color)
      Pixels_counter      ← Pixels_counter + Byte_read
      Packed_data_counter ← Packed_data_counter + 3

    ELSE  // Byte_read = Header.Pack_word
      Color     ← Read_byte(File)
      Word_read ← (Read_byte(File) << 8) + Read_byte(File)
      REPEAT Word_read times:
         Draw_pixel(next position, Color)
      Pixels_counter      ← Pixels_counter + Word_read
      Packed_data_counter ← Packed_data_counter + 4
  END WHILE
END
```

---

### 📖 Example

Given:

```
Pack_byte = 01h
Pack_word = 02h
Data = 04 03 01 05 06 03 02 00 01 2C
```

Decodes to:

```
04 03 05 05 05 05 05 05 03 00 00 00 ... (300× zeros)
```

(`012Ch` = 300 decimal)

> Word counts in repetition packets are **big-endian** (high byte first),
> but header and post-header words remain **little-endian**.

---

## 🧰 Encoding Notes

### Handling `Pack_byte` / `Pack_word` Colors

If a raw pixel equals one of the recognizer bytes, **force it into a packet**, even for single pixels.

Example (`Pack_byte = 9`):

| Pixels | Encoded Sequence |
| :----: | :--------------: |
|   `9`  |      `9,9,1`     |
|  `9,9` |      `9,9,2`     |

---

### Choosing Pack Bytes

Select rarely-used colors as `Pack_byte` and `Pack_word`.
GrafX2 automatically finds the two least-frequent colors in the image before compression.

---

### Small Runs

Two identical colors (`A,A`) are **faster uncompressed** (2 bytes) than a packet (`Pack_byte,A,2`, 3 bytes).

---

### Long Runs

For runs > 65535 pixels, split them into multiple packets:

Example (color 0 repeated 65635 times, with `Pack_byte=01`, `Pack_word=02`):

```
02 00 FF FF 01 00 64
```

→ 65 535 × 0 then 100 × 0

---

## 🧩 Summary

| Section     | Description                      |
| :---------- | :------------------------------- |
| Header      | Basic info + palette (780 bytes) |
| Post-Header | Optional fields for metadata     |
| Image Data  | RLE-compressed pixel stream      |

**Advantages**

* Compact for repetitive images
* Simple to decode
* Palette embedded
* Extensible metadata system

**Limitations**

* 256 colors only
* No alpha or truecolor
* Compression less efficient on noisy art

---

**End of PKM Format Section**
*(Based on GrafX 2.00 Technical Documentation, v1.08 — 10 May 1997)*
