import argparse
import re
import os

def main():
    parser = argparse.ArgumentParser(
        description="Create a PAL file from DOSBox-X VGA DACPAL debug output."
    )
    parser.add_argument("filename", help="Input .TXT file (e.g. kyrandia_dacpal.txt)")
    parser.add_argument(
        "-o", "--out",
        help="Output .PAL file (default: input filename with .pal extension)"
    )
    args = parser.parse_args()

    # Auto-generate output name if not provided
    if args.out:
        outfile = args.out
    else:
        basename, _ = os.path.splitext(args.filename)
        outfile = basename + ".pal"

    text = open(args.filename).read()

    chunks = re.findall(r"\b[0-3][0-9a-f][0-3][0-9a-f][0-3][0-9a-f]\b", text.lower())
    if len(chunks) < 256:
        raise SystemExit(f"Only found {len(chunks)} color entries, expected at least 256.")

    chunks = chunks[:256]

    with open(outfile, "wb") as out:
        for chunk in chunks:
            for i in (0, 2, 4):
                val = int(chunk[i:i+2], 16) & 0x3F
                out.write(bytes([val]))

    print(f"Wrote {outfile} ({256*3} bytes)")

if __name__ == "__main__":
    main()
