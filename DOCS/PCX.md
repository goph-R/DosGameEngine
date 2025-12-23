# PCX Image Format

**PCX** (ZSoft Paintbrush) is a classic DOS image format (1985) widely used in retro games like DOOM, Duke Nukem, and Commander Keen. It's the native export format for [Aseprite](https://www.aseprite.org/), making it perfect for modern pixel art workflows.

## Overview

- **Format**: ZSoft PCX v5 (256-color)
- **Color Mode**: 8-bit indexed (256 colors, VGA Mode 13h compatible)
- **Compression**: Simple RLE (Run-Length Encoding)
- **Palette**: 768-byte RGB triplets at end of file
- **DOS Era**: 1985-1995 (extremely period-correct)

## Specifications

### File Structure

```
[128-byte header]
[RLE-compressed pixel data]
[0x0C marker byte]          ← Palette marker
[768-byte palette]          ← 256 RGB triplets (0-255 range)
```

### Header (128 bytes)

| Offset | Size | Field | Value |
|--------|------|-------|-------|
| 0 | 1 | Manufacturer | 10 (always) |
| 1 | 1 | Version | 5 = 256-color |
| 2 | 1 | Encoding | 1 = RLE |
| 3 | 1 | BitsPerPixel | 8 |
| 4 | 2 | XMin | Left edge (usually 0) |
| 6 | 2 | YMin | Top edge (usually 0) |
| 8 | 2 | XMax | Right edge (Width-1) |
| 10 | 2 | YMax | Bottom edge (Height-1) |
| 12 | 2 | HDpi | Horizontal DPI |
| 14 | 2 | VDpi | Vertical DPI |
| 16 | 48 | ColorMap | EGA palette (unused) |
| 64 | 1 | Reserved | 0 |
| 65 | 1 | NPlanes | 1 (256-color) |
| 66 | 2 | BytesPerLine | Scanline width (may be padded) |
| 68 | 2 | PaletteInfo | 1 = color |
| 70 | 2 | HScreenSize | Horizontal screen size |
| 72 | 2 | VScreenSize | Vertical screen size |
| 74 | 54 | Filler | Reserved (zeros) |

**Important**: Width = XMax - XMin + 1, Height = YMax - YMin + 1

### RLE Compression

PCX uses extremely simple run-length encoding:

| Byte Value | Meaning |
|------------|---------|
| `0x00-0xBF` | Literal pixel value (no run) |
| `0xC0-0xFF` | Run: (byte & 0x3F) = count, next byte = color |

**Example:**
```
0xC5 0x12  →  5 pixels of color 0x12
0x12       →  1 pixel of color 0x12 (literal)
0xCA 0xFF  →  10 pixels of color 0xFF
```

**Decoding Algorithm:**
```pascal
Read(byte);
if (byte and $C0) = $C0 then
  count := byte and $3F;
  Read(color);
  Output color 'count' times
else
  Output byte once (literal)
```

### Palette

- Located at **EOF - 768 bytes**
- Preceded by marker byte **0x0C** (at EOF-769)
- Format: 256 RGB triplets, each 0-255
- **Conversion for VGA**: Divide by 4 (0-255 → 0-63)

```pascal
for i := 0 to 255 do
  Read(R, G, B);           { 0-255 range }
  Palette[i].R := R shr 2; { Convert to VGA 0-63 }
  Palette[i].G := G shr 2;
  Palette[i].B := B shr 2;
```

## Creating PCX Files

### Aseprite (Recommended)

1. **Create sprite** (File → New)
   - **Mode**: Indexed (256 colors)
   - **Size**: 320×200 (full screen), 32×32 (sprites), 16×16 (tiles)

2. **Draw your pixel art**
   - Use up to 256 colors
   - Color 0 = transparent (engine convention)

3. **Export** (File → Export)
   - **Format**: .pcx
   - **Color Mode**: Indexed (8-bit)
   - ✅ Ensure "Apply pixel ratio" is OFF

4. **Save to** `D:\ENGINE\DATA\YOURIMAGE.PCX`

### GIMP

1. Image → Mode → Indexed (256 colors)
2. File → Export As → .pcx
3. Options: "8-bit indexed color"

### Photoshop

1. Image → Mode → Indexed Color (256 colors)
2. File → Save As → PCX
3. Format: "8 bits/pixel"

## Using PCX.PAS

### Interface

```pascal
uses PCX, VGA;

function LoadPCX(const FileName: string; var Image: TImage): Boolean;
function LoadPCXWithPalette(const FileName: string; var Image: TImage;
                            var Palette: TPalette): Boolean;
function LoadPCXToFrameBuffer(const FileName: string; FrameBuffer: PFrameBuffer): Boolean;
function GetLoadPCXError: string;
```

**Functions:**
- `LoadPCX` - Load image without palette (uses existing VGA palette)
- `LoadPCXWithPalette` - Load image with palette extraction
- `LoadPCXToFrameBuffer` - Load PCX directly to framebuffer (no intermediate TImage, optimized)
- `GetLoadPCXError` - Get last error message

### Basic Example

```pascal
uses VGA, PCX;

var
  Img: TImage;
  Pal: TPalette;
  FB: PFrameBuffer;

begin
  { Load PCX with palette }
  if not LoadPCXWithPalette('IMAGE.PCX', Img, Pal) then
  begin
    WriteLn('Error: ', GetLoadPCXError);
    Halt(1);
  end;

  { Display }
  InitVGA;
  SetPalette(Pal);
  FB := CreateFrameBuffer;
  PutImage(Img, 0, 0, False, FB);
  RenderFrameBuffer(FB);

  ReadLn;

  { Cleanup }
  FreeFrameBuffer(FB);
  FreeImage(Img);
  DoneVGA;
end.
```

### Load Without Palette

```pascal
{ Use when palette already set (e.g., from another image) }
if LoadPCX('SPRITE.PCX', Img) then
  PutImage(Img, 100, 50, True, FrameBuffer);
```

### Load Directly to FrameBuffer (Optimized)

```pascal
uses VGA, PCX;

var
  FB: PFrameBuffer;
  Pal: TPalette;

begin
  InitVGA;
  FB := CreateFrameBuffer;

  { Load PCX directly to framebuffer - no intermediate TImage needed }
  if not LoadPCXToFrameBuffer('BACKGROUND.PCX', FB) then
  begin
    WriteLn('Error: ', GetLoadPCXError);
    Halt(1);
  end;

  { Display }
  RenderFrameBuffer(FB);
  ReadLn;

  { Cleanup }
  FreeFrameBuffer(FB);
  DoneVGA;
end.
```

**Benefits:**
- No intermediate `TImage` allocation
- No `PutImage` call needed
- Saves memory and CPU time
- Perfect for loading backgrounds directly to BackgroundBuffer

## Testing

```bash
# Compile PCX loader and test
cd TESTS
CPCXTEST.BAT
PCXTEST.EXE
```

Test program loads `DATA\TEST.PCX` and displays it with palette.

## Comparison: PCX vs PCX

| Feature | PCX | PCX |
|---------|-----|-----|
| **Era** | 1985-1995 (DOS golden age) | 1990s (demoscene) |
| **Tool** | Aseprite, GIMP, Photoshop | GrafX2 only |
| **Compression** | Simple RLE (2-byte runs) | Complex RLE (byte/word runs) |
| **Palette** | End of file (768 bytes) | After header (768 bytes) |
| **Padding** | BytesPerLine (may pad) | No padding |
| **Workflow** | Modern (Aseprite) | Retro (GrafX2) |
| **Games** | DOOM, Duke3D, Commander Keen | Demoscene productions |

**Recommendation**: Use **PCX** for modern pixel art workflows (Aseprite), **PCX** for authentic demoscene aesthetics (GrafX2).

## Size Limits

- **Max image size**: 65,520 bytes (DOS GetMem limit)
- **Max dimensions**: 65,535×65,535 (Word type)
- **Practical limits**:
  - Full screen: 320×200 = 64,000 bytes ✅
  - Large sprite: 320×204 = 65,280 bytes ✅
  - Oversized: 320×205 = 65,600 bytes ❌

## Technical Notes

### Scanline Padding

PCX may pad scanlines to even byte boundaries:
- **BytesPerLine** ≥ Width
- Extra bytes at end of each scanline are discarded
- PCX.PAS handles this automatically

### Palette Marker

Some PCX files omit the 256-color palette (rare). PCX.PAS:
- Checks for marker byte **0x0C** at EOF-769
- If missing: uses grayscale fallback palette
- Continues loading (non-fatal warning)

### VGA Color Conversion

PCX palette uses 0-255 range, VGA DAC uses 0-63:
```pascal
VGA_R := PCX_R shr 2;  { Divide by 4 }
VGA_G := PCX_G shr 2;
VGA_B := PCX_B shr 2;
```

### Turbo Pascal Compatibility

- Uses BlockRead (untyped files)
- No external dependencies (except VGA.PAS)
- Real mode safe (no extended memory)
- 16-bit pointer arithmetic

## References

- **ZSoft PCX Specification**: [Available at FileFormat.Info](https://www.fileformat.info/format/pcx/egff.htm)
- **Aseprite**: https://www.aseprite.org/
- **GrafX2** (for PCX): http://grafx2.chez.com/

## See Also

- **[VGA.md](VGA.md)** - Graphics API reference
- **[UNITS_REFERENCE.md](UNITS_REFERENCE.md)** - Complete units documentation
