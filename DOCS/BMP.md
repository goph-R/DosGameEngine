# BMP - Windows Bitmap Image Format

Loads/saves Windows BMP files (256-color indexed, uncompressed).

## Types

```pascal
type
  TBMPFileHeader = record
    bfType: Word;           { 'BM' = $4D42 }
    bfSize: LongInt;        { File size }
    bfReserved1: Word;
    bfReserved2: Word;
    bfOffBits: LongInt;     { Offset to pixel data }
  end;

  TBMPInfoHeader = record
    biSize: LongInt;        { Header size (40) }
    biWidth: LongInt;
    biHeight: LongInt;
    biPlanes: Word;         { 1 }
    biBitCount: Word;       { 8 (256 colors) }
    biCompression: LongInt; { 0 = BI_RGB (uncompressed) }
    biSizeImage: LongInt;
    biXPelsPerMeter: LongInt;
    biYPelsPerMeter: LongInt;
    biClrUsed: LongInt;     { 0 or 256 }
    biClrImportant: LongInt;
  end;

  TBMPRGBQuad = record
    rgbBlue: Byte;
    rgbGreen: Byte;
    rgbRed: Byte;
    rgbReserved: Byte;      { 0 }
  end;
```

## Functions

```pascal
function LoadBMP(const FileName: string; var Img: TImage): Boolean;
function LoadBMPWithPalette(const FileName: string; var Img: TImage; var Pal: TPalette): Boolean;
function GetLoadBMPError: string;

function SaveBMP(const FileName: string; const Img: TImage; const Pal: TPalette): Boolean;
function GetSaveBMPError: string;
```

## Example

```pascal
uses BMP, VGA;

var
  Img: TImage;
  Pal: TPalette;
begin
  InitVGA;

  if not LoadBMPWithPalette('PLAYER.BMP', Img, Pal) then
  begin
    WriteLn('Error: ', GetLoadBMPError);
    DoneVGA;
    Exit;
  end;

  SetPalette(Pal);
  PutImage(0, 0, @Img, GetScreenBuffer);
  ReadKey;

  SaveBMP('OUTPUT.BMP', Img, Pal);

  FreeImage(@Img);
  DoneVGA;
end;
```

## Format Details

- **8-bit indexed color** (256 colors)
- **BI_RGB** (uncompressed)
- **Bottom-up scanlines** (first scanline = bottom row)
- **4-byte alignment** per scanline (padded)
- **BGRA palette** (Blue, Green, Red, Reserved)

## Palette Conversion

BMP uses BGRA format (0-255), VGA uses RGB (0-63). Automatic conversion:

```pascal
{ BMP → VGA }
Pal[i].R := BMPPalette[i].rgbRed shr 2;
Pal[i].G := BMPPalette[i].rgbGreen shr 2;
Pal[i].B := BMPPalette[i].rgbBlue shr 2;

{ VGA → BMP }
BMPPalette[i].rgbRed := Pal[i].R shl 2;
BMPPalette[i].rgbGreen := Pal[i].G shl 2;
BMPPalette[i].rgbBlue := Pal[i].B shl 2;
```

## Creating BMP Files

### Windows Paint
1. Image → Resize → 256 colors
2. Save As → 24-bit BMP (auto-converts to 8-bit)

### GIMP
1. Image → Mode → Indexed (256 colors)
2. File → Export As → .bmp
3. Options: 8 bits, no color space info

### Photoshop
1. Image → Mode → Indexed Color
2. File → Save As → BMP
3. Format: Windows, 8 bits/pixel

## BMP vs PCX

| Feature         | BMP              | PCX              |
|-----------------|------------------|------------------|
| **Compression** | None             | RLE              |
| **Scanlines**   | Bottom-up        | Top-down         |
| **Palette**     | BGRA (0-255)     | RGB (0-255)      |
| **Tools**       | Paint, Photoshop | Aseprite, GIMP   |
| **File Size**   | Larger           | Smaller          |

## Notes

- Max image size: 320×204 (65520 bytes) due to TImage limits
- Handles scanline padding (4-byte alignment) automatically
- Compatible with Windows Paint, Photoshop, GIMP
- For RLE compression, use PCX format instead
