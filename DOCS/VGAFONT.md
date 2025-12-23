# VGAFONT.PAS - Variable-Width Font System Design

A sprite sheet-based variable-width font renderer for high-quality text display in VGA Mode 13h.

---

## Table of Contents

- [Overview](#overview)
- [Comparison to VGAPRINT](#comparison-to-vgaprint)
- [Font Format](#font-format)
- [Data Structures](#data-structures)
- [API Functions](#api-functions)
- [XML Schema](#xml-schema)
- [Usage Examples](#usage-examples)
- [Font Creation Workflow](#font-creation-workflow)
- [Performance Considerations](#performance-considerations)
- [Implementation Details](#implementation-details)
- [Error Handling](#error-handling)

---

## Overview

VGAFONT.PAS provides a professional variable-width font rendering system for DOS games. Fonts are defined as sprite sheets (PCX images) with XML metadata describing character positions and widths.

### Key Features

- **Variable-width characters** - Proportional fonts for better readability
- **Sprite sheet-based** - Use existing PCX image format
- **XML metadata** - Character positions and widths defined externally
- **Efficient rendering** - Uses `PutImageRect` for fast character blitting
- **Flexible character set** - Support ASCII 0-127
- **Undefined character handling** - Skip characters not in font (width=0)

### Use Cases

- **Game dialogue** - Variable-width text looks more professional
- **Menu systems** - Better visual appearance than monospace
- **HUD elements** - Score displays, labels, etc.
- **Cutscenes** - Subtitle text rendering
- **Credits screens** - Large decorative fonts

---

## Comparison to VGAPRINT

| Feature | VGAPRINT.PAS | VGAFONT.PAS |
|---------|--------------|-------------|
| **Font type** | Fixed-width (8×8) | Variable-width |
| **Font source** | Embedded in code | External PCX + XML |
| **Character sizes** | All 8×8 | Custom per character |
| **Visual quality** | Monospace (retro) | Proportional (modern) |
| **Setup** | None (built-in) | Load font file |
| **Memory usage** | ~1KB (embedded) | ~Depends on font size |
| **Performance** | Fast (direct pixel write) | Fast (PutImageRect) |
| **Use case** | Debug text, FPS counters | Game UI, dialogue |

**When to use each:**
- **VGAPRINT**: Quick debug output, FPS counters, simple overlays
- **VGAFONT**: Professional game UI, dialogue, menus, titles

---

## Font Format

### Sprite Sheet Layout

Fonts are stored as PCX images with characters arranged in a sprite sheet:

```
Example: 32-pixel tall font

┌──────────────────────────────────────┐
│ A  B  C  D  E  F  G  H  I  J  K  ... │  Row 1 (letters)
├──────────────────────────────────────┤
│ 0  1  2  3  4  5  6  7  8  9  !  ... │  Row 2 (numbers/symbols)
├──────────────────────────────────────┤
│ ...                                  │  Additional rows as needed
└──────────────────────────────────────┘

Each character:
- Fixed height (e.g., 32 pixels)
- Fixed right padding (e.g., 1 pixel)
- Variable width (e.g., 'i' = 8px, 'W' = 24px)
- Position defined in XML
```

**Dimensions:**
- **Height**: Fixed for all characters (defined in XML)
- **Padding**: Fixed for all characters (defined in XML)
- **Width**: Variable per character (defined in XML)
- **Sheet size**: Depends on character count and sizes
- **Typical**: 512×64 pixels for full ASCII set

---

### XML Metadata

Character positions and widths are defined in an XML file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<font height="32" padding="1">
  <!-- Uppercase letters -->
  <char code="65" x="0" y="0" width="18" />    <!-- A -->
  <char code="66" x="18" y="0" width="16" />   <!-- B -->
  <char code="67" x="34" y="0" width="17" />   <!-- C -->

  <!-- Lowercase letters -->
  <char code="97" x="0" y="32" width="15" />   <!-- a -->
  <char code="98" x="15" y="32" width="15" />  <!-- b -->

  <!-- Numbers -->
  <char code="48" x="200" y="0" width="14" />  <!-- 0 -->
  <char code="49" x="214" y="0" width="10" />  <!-- 1 -->

  <!-- Special characters -->
  <char code="32" x="0" y="0" width="8" />     <!-- Space (no glyph) -->
  <char code="33" x="300" y="0" width="8" />   <!-- ! -->

  <!-- Characters not defined have width=0 and are skipped -->
</font>
```

**Attributes:**
- `height`: Font height in pixels (applies to all characters)
- `code`: ASCII character code (0-127)
- `x`, `y`: Position in sprite sheet (pixels)
- `width`: Character width in pixels

---

## Data Structures

### TFont Type

```pascal
unit VGAFont;

interface

uses VGA, GenTypes;

const
  MaxChars = 128;  { ASCII 0-127 }

type
  TCharInfo = record
    X: Integer;        { X position in sprite sheet }
    Y: Integer;        { Y position in sprite sheet }
    Width: Byte;       { Character width in pixels }
    Defined: Boolean;  { True if character exists in font }
  end;

  TFont = record
    Image: TImage;                            { Font sprite sheet }
    Height: Byte;                             { Height of all characters }
    Padding: Byte;                            { Right padding of all characters }
    Chars: array[0..MaxChars-1] of TCharInfo; { Character metadata }
    Loaded: Boolean;                          { True if font successfully loaded }
  end;
  PFont = ^TFont;
```

**Memory layout:**
```
TFont structure:
- Image: TImage (Width, Height, Data pointer)
- Height: 1 byte
- Chars: 128 × TCharInfo (128 × 7 bytes = 896 bytes)
- Loaded: 1 byte
Total: ~900 bytes + image data
```

---

## API Functions

### LoadFont

```pascal
function LoadFont(const XMLFile: string; var Font: TFont): Boolean;
```

Loads a font from PCX image and XML metadata files.

**Parameters:**
- `XMLFile` - Path to XML metadata (e.g., 'FONTS\MAIN.XML')
- `ImageFile` - Path to PCX sprite sheet (e.g., 'FONTS\MAIN.PCX')
- `Font` - TFont structure to populate

**Returns:**
- `True` if font loaded successfully
- `False` on error (use `GetLoadFontError` for details)

**Example:**
```pascal
var
  GameFont: TFont;

begin
  if not LoadFont('FONTS\MAIN.XML', GameFont) then
  begin
    WriteLn('Error loading font: ', GetLoadFontError);
    Halt(1);
  end;

  { Font ready to use }
end;
```

**Loading process:**
1. Load PCX image into `Font.Image`
2. Parse XML file using MINIXML.PAS
3. Extract `height` attribute from `<font>` element
4. Parse each `<char>` element:
   - Read `code`, `x`, `y`, `width` attributes
   - Store in `Font.Chars[code]`
   - Set `Defined := True`
5. Initialize undefined characters:
   - Set `Width := 0`
   - Set `Defined := False`
6. Set `Font.Loaded := True`

**Error conditions:**
- PCX file not found or invalid
- XML file not found or invalid
- XML parsing errors (malformed XML)
- Missing required attributes
- Invalid attribute values (negative, out of range)

---

### GetLoadFontError

```pascal
function GetLoadFontError: string;
```

Returns the last error message from `LoadFont`.

**Returns:** Error description string

**Example:**
```pascal
if not LoadFont('FONT.XML', Font) then
begin
  WriteLn('Font loading failed:');
  WriteLn(GetLoadFontError);
end;
```

**Typical error messages:**
- `"PCX file not found: FONT.PCX"`
- `"XML file could not be loaded: FONT.XML"`
- `"Invalid XML format"`
- `"Missing height attribute in <font> element"`
- `"Invalid character code: 200 (must be 0-127)"`
- `"Missing required attribute: width"`

---

### FreeFont

```pascal
procedure FreeFont(var Font: TFont);
```

Frees all resources associated with a font.

**Parameters:**
- `Font` - TFont structure to free

**Example:**
```pascal
var
  GameFont: TFont;

begin
  LoadFont('FONT.XML', GameFont);

  { Use font... }

  FreeFont(GameFont);  { Free resources before exit }
end;
```

**Cleanup actions:**
1. Free sprite sheet image data: `FreeImage(Font.Image)`
2. Clear character metadata
3. Set `Font.Loaded := False`

**CRITICAL:**
- Always call before program exit
- Prevents memory leaks
- Safe to call on unloaded fonts (no-op)

---

### PrintFontText

```pascal
procedure PrintFontText(
  X, Y: Integer;
  const Text: string;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);
```

Renders text using a loaded font.

**Parameters:**
- `X, Y` - Starting position in framebuffer (pixels)
- `Text` - String to render (ASCII 0-127 only)
- `Font` - Loaded TFont structure
- `FrameBuffer` - Target framebuffer to draw into

**Example:**
```pascal
var
  GameFont: TFont;
  ScreenBuffer: PFrameBuffer;

begin
  LoadFont('FONT.XML', GameFont);
  ScreenBuffer := GetScreenBuffer;

  { Draw text }
  PrintFontText(100, 50, 'SCORE: 12345', GameFont, ScreenBuffer);
  PrintFontText(100, 90, 'LEVEL: 5', GameFont, ScreenBuffer);
end;
```

**Rendering process:**
1. Initialize cursor X position
2. For each character in text:
   - Get ASCII code
   - Look up character info in `Font.Chars[code]`
   - If `Defined = False` or `Width = 0`, skip character
   - Otherwise, call `PutImageRect` to draw character:
     ```pascal
     PutImageRect(
       Font.Image,          { Source sprite sheet }
       CharRect,            { Source rectangle }
       CursorX, Y,          { Destination position }
       True,                { Transparent }
       FrameBuffer          { Target buffer }
     );
     ```
   - Advance cursor: `CursorX := CursorX + Width`
3. Return final cursor position (for chaining)

**Character handling:**
```pascal
{ Example character rendering logic }
for i := 1 to Length(Text) do
begin
  CharCode := Ord(Text[i]);

  if CharCode > 127 then Continue;  { Skip extended ASCII }

  CharInfo := Font.Chars[CharCode];

  if (not CharInfo.Defined) or (CharInfo.Width = 0) then Continue;

  { Draw character }
  SourceRect.X := CharInfo.X;
  SourceRect.Y := CharInfo.Y;
  SourceRect.Width := CharInfo.Width;
  SourceRect.Height := Font.Height;

  PutImageRect(
    Font.Image,
    SourceRect,
    CursorX, Y,
    True,  { Transparent (color 0 = transparent) }
    FrameBuffer
  );

  CursorX := CursorX + CharInfo.Width + Font.Padding;
end;
```

**Transparency:**
- Uses `PutImageRect` with `Transparent := True`
- Color 0 (black) is treated as transparent
- Font sprite sheets should use color 0 for background

---

### Additional Helper Functions (Optional)

```pascal
{ Calculate text width in pixels (for centering) }
function GetTextWidth(const Text: string; var Font: TFont): Integer;

{ Draw centered text }
procedure PrintFontTextCentered(
  Y: Integer;
  const Text: string;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);

{ Draw right-aligned text }
procedure PrintFontTextRight(
  X, Y: Integer;
  const Text: string;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);
```

**GetTextWidth implementation:**
```pascal
function GetTextWidth(const Text: string; var Font: TFont): Integer;
var
  i, Width: Integer;
  CharCode: Byte;
begin
  Width := 0;
  for i := 1 to Length(Text) do
  begin
    CharCode := Ord(Text[i]);
    if (CharCode <= 127) and Font.Chars[CharCode].Defined then
      Width := Width + Font.Chars[CharCode].Width + Font.Padding;
  end;
  GetTextWidth := Width;
end;
```

**Centered text:**
```pascal
procedure PrintFontTextCentered(
  Y: Integer;
  const Text: string;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);
var
  TextWidth, X: Integer;
begin
  TextWidth := GetTextWidth(Text, Font);
  X := (320 - TextWidth) div 2;  { Center horizontally }
  PrintFontText(X, Y, Text, Font, FrameBuffer);
end;
```

---

## XML Schema

### Font Element

```xml
<font height="HEIGHT" padding="PADDING">
  <!-- Character definitions -->
</font>
```

**Attributes:**
- `height` (required): Integer, 1-255
  - Height of all characters in pixels
  - All characters in font have same height

- `padding` (optional): Integer, 1-255
  - Right padding of all characters in pixel
  - All characters in font have same padding

**Child elements:**
- One or more `<char>` elements

---

### Character Element

```xml
<char code="CODE" x="X" y="Y" width="WIDTH" />
```

**Attributes:**
- `code` (required): Integer, 0-127
  - ASCII character code
  - Must be unique (no duplicate codes)

- `x` (required): Integer, 0-65535
  - X position in sprite sheet (pixels)
  - Left edge of character glyph

- `y` (required): Integer, 0-65535
  - Y position in sprite sheet (pixels)
  - Top edge of character glyph

- `width` (required): Integer, 0-255
  - Character width in pixels
  - Can be 0 for space characters

**Example:**
```xml
<char code="65" x="0" y="0" width="18" />  <!-- 'A' -->
```

---

### Complete Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<font height="32">
  <!-- Uppercase A-Z -->
  <char code="65" x="0" y="0" width="18" />    <!-- A -->
  <char code="66" x="18" y="0" width="16" />   <!-- B -->
  <char code="67" x="34" y="0" width="17" />   <!-- C -->
  <!-- ... Z -->

  <!-- Lowercase a-z -->
  <char code="97" x="0" y="32" width="15" />   <!-- a -->
  <char code="98" x="15" y="32" width="15" />  <!-- b -->
  <!-- ... z -->

  <!-- Numbers 0-9 -->
  <char code="48" x="200" y="0" width="14" />  <!-- 0 -->
  <char code="49" x="214" y="0" width="10" />  <!-- 1 -->
  <char code="50" x="224" y="0" width="14" />  <!-- 2 -->
  <!-- ... 9 -->

  <!-- Special characters -->
  <char code="32" x="0" y="0" width="8" />     <!-- Space -->
  <char code="33" x="300" y="0" width="8" />   <!-- ! -->
  <char code="46" x="308" y="0" width="6" />   <!-- . -->
  <char code="58" x="314" y="0" width="6" />   <!-- : -->

  <!-- Extended special characters -->
  <char code="44" x="320" y="0" width="6" />   <!-- , -->
  <char code="63" x="326" y="0" width="14" />  <!-- ? -->
</font>
```

---

## Usage Examples

### Basic Text Rendering

```pascal
program FontTest;

uses VGA, VGAFont, PCX;

var
  GameFont: TFont;
  ScreenBuffer: PFrameBuffer;
  Running: Boolean;

begin
  InitVGA;
  ScreenBuffer := GetScreenBuffer;

  { Load font }
  if not LoadFont('FONTS\MAIN.XML', GameFont) then
  begin
    DoneVGA;
    WriteLn('Error: ', GetLoadFontError);
    Halt(1);
  end;

  { Clear screen }
  ClearFrameBuffer(BackBuffer);

  { Draw text }
  PrintFontText(10, 10, 'Hello, World!', GameFont, ScreenBuffer);
  PrintFontText(10, 50, 'Variable Width Font!', GameFont, ScreenBuffer);

  ReadLn;

  { Cleanup }
  FreeFont(GameFont);
  DoneVGA;
end.
```

---

### Multiple Fonts

```pascal
var
  TitleFont: TFont;     { Large decorative font }
  NormalFont: TFont;    { Regular game text }
  SmallFont: TFont;     { Small UI text }

begin
  { Load different fonts for different purposes }
  LoadFont('FONTS\TITLE.XML', TitleFont);
  LoadFont('FONTS\NORMAL.XML', NormalFont);
  LoadFont('FONTS\SMALL.XML', SmallFont);

  { Use appropriate font for each element }
  PrintFontTextCentered(160, 50, 'XICLONE', TitleFont, BackBuffer);
  PrintFontTextCentered(160, 100, 'Press ENTER to start', NormalFont, BackBuffer);
  PrintFontText(10, 190, 'v1.0', SmallFont, BackBuffer);

  { Cleanup all fonts }
  FreeFont(TitleFont);
  FreeFont(NormalFont);
  FreeFont(SmallFont);
end;
```

---

### Text Wrapping (Advanced)

```pascal
procedure PrintWrappedText(
  X, Y, MaxWidth: Integer;
  const Text: string;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);
var
  Words: array[0..99] of string;
  WordCount, i: Integer;
  Line: string;
  LineWidth: Integer;
  CursorY: Integer;
begin
  { Split text into words }
  WordCount := SplitWords(Text, Words);

  CursorY := Y;
  Line := '';

  for i := 0 to WordCount - 1 do
  begin
    { Try adding word to current line }
    if Line = '' then
      TestLine := Words[i]
    else
      TestLine := Line + ' ' + Words[i];

    LineWidth := GetTextWidth(TestLine, Font);

    if LineWidth > MaxWidth then
    begin
      { Line too long - print current line and start new one }
      if Line <> '' then
      begin
        PrintFontText(X, CursorY, Line, Font, FrameBuffer);
        CursorY := CursorY + Font.Height + 4;  { Line spacing }
      end;
      Line := Words[i];
    end
    else
      Line := TestLine;
  end;

  { Print remaining line }
  if Line <> '' then
    PrintFontText(X, CursorY, Line, Font, FrameBuffer);
end;
```

---

## Font Creation Workflow

### Step 1: Design Font in GrafX2

1. **Create new image:**
   - Width: 512 pixels (or as needed)
   - Height: 64-128 pixels (depends on character count)
   - Colors: 256 (indexed palette)

2. **Draw characters:**
   - Fixed height per character (e.g., 32 pixels)
   - Variable width (proportional spacing)
   - Use color 0 (black) for transparent background
   - Leave padding between characters for clarity

3. **Layout example:**
   ```
   Row 1: A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
   Row 2: a b c d e f g h i j k l m n o p q r s t u v w x y z
   Row 3: 0 1 2 3 4 5 6 7 8 9 ! ? . , : ; ' "
   ```

4. **Save as PCX:**
   - File → Export → PCX format (8-bit indexed color)
   - Save to `DATA\FONTS\MYFONT.PCX`

---

### Step 2: Generate XML Metadata

Create `MYFONT.XML`:
```xml
<?xml version="1.0" encoding="US-ASCII"?>
<font height="32" padding="1">
  <char code="65" x="0" y="0" width="18" />  <!-- A -->
  <!-- Add all characters... -->
</font>
```

---

### Step 3: Test Font

```pascal
program TestFont;

uses VGA, VGAFont;

var
  Font: TFont;
  Buffer: PFrameBuffer;

begin
  InitVGA;
  Buffer := CreateFrameBuffer;

  if not LoadFont('FONTS\MYFONT.XML', Font) then
  begin
    DoneVGA;
    WriteLn('Error: ', GetLoadFontError);
    Halt(1);
  end;

  ClearFrameBuffer(Buffer);

  { Test all printable ASCII }
  PrintFontText(10, 10, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', Font, Buffer);
  PrintFontText(10, 50, 'abcdefghijklmnopqrstuvwxyz', Font, Buffer);
  PrintFontText(10, 90, '0123456789 !?.,:;', Font, Buffer);

  RenderFrameBuffer(Buffer);
  ReadLn;

  FreeFont(Font);
  FreeFrameBuffer(Buffer);
  DoneVGA;
end.
```

---

## Performance Considerations

### Rendering Speed

**Character rendering cost:**
```
Single character (16×32 pixels):
- PutImageRect call: ~0.5ms on 286
- Memory copied: 512 bytes

Text line "SCORE: 12345" (12 characters):
- Total time: ~6ms on 286
- 166 FPS if only drawing text

Typical HUD (5 text lines):
- Total time: ~30ms on 286
- Still achieves 30+ FPS
```

**Optimization tips:**
1. **Cache static text** - Don't re-render every frame
2. **Use dirty rectangles** - Only redraw changed text
3. **Pre-render common strings** - "SCORE:", "LEVEL:", etc.
4. **Avoid text in inner loops** - Render UI once per frame max

---

### Memory Usage

**Per font:**
```
TFont structure: ~900 bytes
Sprite sheet (512×64, 256 colors): 32KB
Total per font: ~33KB

Multiple fonts (Title + Normal + Small): ~100KB
Still plenty of room in 640KB conventional memory
```

**Comparison:**
- VGAPRINT (embedded): 1KB
- VGAFONT (typical): 33KB per font
- Trade-off: Quality vs. memory

---

### XML Parsing Performance

**Loading time:**
```
Parse XML (128 characters): ~50ms on 286
Load PCX image: ~100ms on 286
Total load time: ~150ms (done once at startup)

Acceptable for:
- Game initialization
- Level loading
- Not acceptable for: Every frame rendering
```

**Best practice:**
- Load fonts at startup
- Keep loaded for entire game session
- Don't reload fonts during gameplay

---

## Error Handling

### Error Categories

**File errors:**
- PCX file not found
- XML file not found
- File read errors

**XML errors:**
- Invalid XML format (malformed)
- Missing root element
- Missing required attributes
- Invalid attribute values

**Data errors:**
- Character code out of range (not 0-127)
- Negative dimensions
- Duplicate character codes

---

### Example Error Messages

```
"PCX file not found: FONTS\MAIN.PCX"
"XML file could not be loaded: FONTS\MAIN.XML"
"Invalid XML format"
"Missing root <font> element"
"Missing height attribute in <font> element"
"Invalid height: -5 (must be 1-255)"
"Missing required attribute: width"
"Invalid character code: 200 (must be 0-127)"
"Invalid width: -10 (must be 0-255)"
"Duplicate character code: 65"
```

---

## Conclusion

VGAFONT.PAS provides a professional variable-width font system that:

**✅ Advantages:**
- Better visual appearance than monospace fonts
- Flexible character sizes (proportional spacing)
- External font definitions (easy to modify)
- Efficient rendering (PutImageRect)
- Multiple fonts support

**⚠️ Considerations:**
- Requires external PCX + XML files
- Higher memory usage than VGAPRINT
- Slower loading (XML parsing)
- More complex setup

**Best for:**
- Game UI, menus, dialogues
- Professional-looking text
- Games with high production values

**Use VGAPRINT for:**
- Debug output, FPS counters
- Quick prototypes
- Minimal memory footprint
