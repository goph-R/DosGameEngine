#!/usr/bin/env python3
"""
Author: ChatGPT 5.1

List instruments from a Dune II / Kyrandia 1 ADL file,
and optionally export them as HSC .INS files.

Layout for these games (per ADL format docs):

- 120 bytes: song indexes (1 byte each)
- 250 * 2 bytes: track pointers (uint16, little-endian)
- 250 * 2 bytes: instrument pointers (uint16, little-endian)
- Then: track data + instrument data

Each pointer value is *relative to the size of the primary index block*,
so absolute_offset = PRIMARY_BLOCK_SIZE + pointer_value.

Each instrument is an 11-byte block used by setupInstrument().
We convert that to a 12-byte HSC .INS using this mapping:

  ADL[0] -> HSC[1]   (0x20 modulator)
  ADL[1] -> HSC[0]   (0x23 carrier)
  ADL[2] -> HSC[8]   (0xC0 feedback/algorithm)
  ADL[3] -> HSC[10]  (0xE0 modulator waveform)
  ADL[4] -> HSC[9]   (0xE3 carrier waveform)
  ADL[5] -> HSC[3]   (0x40 modulator level)
  ADL[6] -> HSC[2]   (0x43 carrier level)
  ADL[7] -> HSC[5]   (0x60 modulator attack/decay)
  ADL[8] -> HSC[4]   (0x63 carrier attack/decay)
  ADL[9] -> HSC[7]   (0x80 modulator sustain/release)
  ADL[10] -> HSC[6]  (0x83 carrier sustain/release)
  HSC[11] = 0        (finetune / slide)
"""

import argparse
from pathlib import Path

PRIMARY_INDEX_COUNT = 120          # bytes
TRACK_POINTER_COUNT = 250          # number of 16-bit entries
INSTR_POINTER_COUNT = 250          # number of 16-bit entries

PRIMARY_BLOCK_SIZE = PRIMARY_INDEX_COUNT  # in bytes

TRACK_POINTER_TABLE_OFFSET = PRIMARY_BLOCK_SIZE                     # 0x78
INSTR_POINTER_TABLE_OFFSET = TRACK_POINTER_TABLE_OFFSET + TRACK_POINTER_COUNT * 2  # 0x26C


def read_le16(data: bytes, offset: int) -> int:
    if offset + 2 > len(data):
        return 0xFFFF
    return data[offset] | (data[offset + 1] << 8)


def adl_to_hsc_ins(adl_bytes: bytes) -> bytes:
    """
    Convert an 11-byte ADL instrument to a 12-byte HSC .INS instrument.
    """
    if len(adl_bytes) != 11:
        raise ValueError("ADL instrument must be exactly 11 bytes")

    h = bytearray(12)

    # HSC layout vs ADL (see big comment in module docstring)
    h[0] = adl_bytes[1]   # carrier AM/VIB/EG/KSR/Multi (reg 0x23)
    h[1] = adl_bytes[0]   # modulator AM/VIB/EG/KSR/Multi (reg 0x20)
    h[2] = adl_bytes[6]   # carrier level (reg 0x43)
    h[3] = adl_bytes[5]   # modulator level (reg 0x40)
    h[4] = adl_bytes[8]   # carrier attack/decay (reg 0x63)
    h[5] = adl_bytes[7]   # modulator attack/decay (reg 0x60)
    h[6] = adl_bytes[10]  # carrier sustain/release (reg 0x83)
    h[7] = adl_bytes[9]   # modulator sustain/release (reg 0x80)
    h[8] = adl_bytes[2]   # feedback / algorithm (reg 0xC0)
    h[9] = adl_bytes[4]   # carrier waveform (reg 0xE3)
    h[10] = adl_bytes[3]  # modulator waveform (reg 0xE0)
    h[11] = 0             # finetune / slide (tracker-specific; 0 = none)

    return bytes(h)


def list_instruments(adl_data: bytes, export: bool = False, export_dir: Path | None = None):
    print(f"ADL size: {len(adl_data)} bytes")
    print(f"Primary index block size: {PRIMARY_BLOCK_SIZE} bytes")
    print(f"Track ptr table offset:  0x{TRACK_POINTER_TABLE_OFFSET:04X}")
    print(f"Instr ptr table offset:  0x{INSTR_POINTER_TABLE_OFFSET:04X}")
    print()

    if export and export_dir is None:
        export_dir = Path(".")

    inst_id = 0
    seen_offsets = set()

    for i in range(INSTR_POINTER_COUNT):
        ptr_off = INSTR_POINTER_TABLE_OFFSET + i * 2
        if ptr_off + 2 > len(adl_data):
            break

        rel_ptr = read_le16(adl_data, ptr_off)
        if rel_ptr == 0 or rel_ptr == 0xFFFF:
            continue

        abs_off = PRIMARY_BLOCK_SIZE + rel_ptr

        # Must fit 11 bytes
        if abs_off + 11 > len(adl_data):
            continue

        # Skip duplicates (multiple pointers to the same instrument)
        if abs_off in seen_offsets:
            continue
        seen_offsets.add(abs_off)

        inst_bytes = adl_data[abs_off: abs_off + 11]
        hex_bytes = " ".join(f"{b:02X}" for b in inst_bytes)

        print(
            f"Instrument {inst_id:3d}: "
            f"ptrIndex={i:3d}  rel=0x{rel_ptr:04X}  off=0x{abs_off:04X}  "
            f"bytes: {hex_bytes}"
        )

        if export:
            export_dir.mkdir(parents=True, exist_ok=True)
            # 2-digit decimal file name: 00.INS, 01.INS, ...
            filename = export_dir / f"{inst_id:02d}.INS"
            hsc_data = adl_to_hsc_ins(inst_bytes)
            with open(filename, "wb") as f:
                f.write(hsc_data)

        inst_id += 1

    if inst_id == 0:
        print("No instruments found.")
    else:
        print()
        print(f"Total *unique* instruments found: {inst_id}")
        if export:
            print(f"Exported to: {export_dir.resolve()}\n")
            print("Note: Some exported instruments may sound unusual or incomplete because")
            print("the original game applied dynamic volume, vibrato, and effect processing")
            print("that isn’t preserved in the raw instrument data.")


def main():
    parser = argparse.ArgumentParser(
        description="List instruments from a Dune II / Kyrandia 1 ADL file, "
                    "and optionally export them as HSC .INS files."
    )
    parser.add_argument("filename", help="Input .ADL file (e.g., dune7.adl)")
    parser.add_argument(
        "--export",
        action="store_true",
        help="Export each instrument as XX.INS (HSC format) in the current directory.",
    )
    parser.add_argument(
        "--export-dir",
        help="Optional directory to export INS files into (default: current directory).",
    )

    args = parser.parse_args()

    with open(args.filename, "rb") as f:
        data = f.read()

    export_dir = Path(args.export_dir) if args.export_dir else None
    list_instruments(data, export=args.export, export_dir=export_dir)


if __name__ == "__main__":
    main()
