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

VGAFONT.PAS provides a professional variable-width font rendering system for DOS games. Fonts are defined as sprite sheets (PKM images) with XML metadata describing character positions and widths.

### Key Features

- **Variable-width characters** - Proportional fonts for better readability
- **Sprite sheet-based** - Use existing PKM image format
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
| **Font source** | Embedded in code | External PKM + XML |
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

Fonts are stored as PKM images with characters arranged in a sprite sheet:

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
- Variable width (e.g., 'i' = 8px, 'W' = 24px)
- Position defined in XML
```

**Dimensions:**
- **Height**: Fixed for all characters (defined in XML)
- **Width**: Variable per character (defined in XML)
- **Sheet size**: Depends on character count and sizes
- **Typical**: 512×64 pixels for full ASCII set

---

### XML Metadata

Character positions and widths are defined in an XML file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<font height="32">
  <!-- Uppercase letters -->
  <character code="65" x="0" y="0" width="18" />    <!-- A -->
  <character code="66" x="18" y="0" width="16" />   <!-- B -->
  <character code="67" x="34" y="0" width="17" />   <!-- C -->

  <!-- Lowercase letters -->
  <character code="97" x="0" y="32" width="15" />   <!-- a -->
  <character code="98" x="15" y="32" width="15" />  <!-- b -->

  <!-- Numbers -->
  <character code="48" x="200" y="0" width="14" />  <!-- 0 -->
  <character code="49" x="214" y="0" width="10" />  <!-- 1 -->

  <!-- Special characters -->
  <character code="32" x="0" y="0" width="8" />     <!-- Space (no glyph) -->
  <character code="33" x="300" y="0" width="8" />   <!-- ! -->

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
    Image: TImage;                           { Font sprite sheet }
    Height: Byte;                            { Height of all characters }
    Chars: array[0..MaxChars-1] of TCharInfo; { Character metadata }
    Loaded: Boolean;                         { True if font successfully loaded }
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
function LoadFont(
  const ImageFile: string;
  const XMLFile: string;
  var Font: TFont
): Boolean;
```

Loads a font from PKM image and XML metadata files.

**Parameters:**
- `ImageFile` - Path to PKM sprite sheet (e.g., 'FONTS\MAIN.PKM')
- `XMLFile` - Path to XML metadata (e.g., 'FONTS\MAIN.XML')
- `Font` - TFont structure to populate

**Returns:**
- `True` if font loaded successfully
- `False` on error (use `GetLoadFontError` for details)

**Example:**
```pascal
var
  GameFont: TFont;

begin
  if not LoadFont('FONTS\MAIN.PKM', 'FONTS\MAIN.XML', GameFont) then
  begin
    WriteLn('Error loading font: ', GetLoadFontError);
    Halt(1);
  end;

  { Font ready to use }
end;
```

**Loading process:**
1. Load PKM image into `Font.Image`
2. Parse XML file using MINIXML.PAS
3. Extract `height` attribute from `<font>` element
4. Parse each `<character>` element:
   - Read `code`, `x`, `y`, `width` attributes
   - Store in `Font.Chars[code]`
   - Set `Defined := True`
5. Initialize undefined characters:
   - Set `Width := 0`
   - Set `Defined := False`
6. Set `Font.Loaded := True`

**Error conditions:**
- PKM file not found or invalid
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
if not LoadFont('FONT.PKM', 'FONT.XML', Font) then
begin
  WriteLn('Font loading failed:');
  WriteLn(GetLoadFontError);
end;
```

**Typical error messages:**
- `"PKM file not found: FONT.PKM"`
- `"XML file not found: FONT.XML"`
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
  LoadFont('FONT.PKM', 'FONT.XML', GameFont);

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
  BackBuffer: PFrameBuffer;

begin
  LoadFont('FONT.PKM', 'FONT.XML', GameFont);
  BackBuffer := CreateFrameBuffer;

  { Draw text }
  PrintFontText(100, 50, 'SCORE: 12345', GameFont, BackBuffer);
  PrintFontText(100, 90, 'LEVEL: 5', GameFont, BackBuffer);

  RenderFrameBuffer(BackBuffer);
end;
```

**Rendering process:**
1. Initialize cursor X position
2. For each character in text:
   - Get ASCII code
   - Look up character info in `Font.Chars[code]`
   - If `Defined = False`, skip character
   - If `Width = 0`, advance cursor by width (space)
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

  if not CharInfo.Defined then Continue;  { Undefined character }

  if CharInfo.Width = 0 then
  begin
    { Space or zero-width character }
    CursorX := CursorX + CharInfo.Width;
    Continue;
  end;

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

  CursorX := CursorX + CharInfo.Width;
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
      Width := Width + Font.Chars[CharCode].Width;
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
<font height="HEIGHT">
  <!-- Character definitions -->
</font>
```

**Attributes:**
- `height` (required): Integer, 1-255
  - Height of all characters in pixels
  - All characters in font have same height

**Child elements:**
- One or more `<character>` elements

---

### Character Element

```xml
<character code="CODE" x="X" y="Y" width="WIDTH" />
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
<character code="65" x="0" y="0" width="18" />  <!-- 'A' -->
```

---

### Complete Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<font height="32">
  <!-- Uppercase A-Z -->
  <character code="65" x="0" y="0" width="18" />    <!-- A -->
  <character code="66" x="18" y="0" width="16" />   <!-- B -->
  <character code="67" x="34" y="0" width="17" />   <!-- C -->
  <!-- ... Z -->

  <!-- Lowercase a-z -->
  <character code="97" x="0" y="32" width="15" />   <!-- a -->
  <character code="98" x="15" y="32" width="15" />  <!-- b -->
  <!-- ... z -->

  <!-- Numbers 0-9 -->
  <character code="48" x="200" y="0" width="14" />  <!-- 0 -->
  <character code="49" x="214" y="0" width="10" />  <!-- 1 -->
  <character code="50" x="224" y="0" width="14" />  <!-- 2 -->
  <!-- ... 9 -->

  <!-- Special characters -->
  <character code="32" x="0" y="0" width="8" />     <!-- Space -->
  <character code="33" x="300" y="0" width="8" />   <!-- ! -->
  <character code="46" x="308" y="0" width="6" />   <!-- . -->
  <character code="58" x="314" y="0" width="6" />   <!-- : -->

  <!-- Extended special characters -->
  <character code="44" x="320" y="0" width="6" />   <!-- , -->
  <character code="63" x="326" y="0" width="14" />  <!-- ? -->
</font>
```

---

## Usage Examples

### Basic Text Rendering

```pascal
program FontTest;

uses VGA, VGAFont, PKMLoad;

var
  GameFont: TFont;
  BackBuffer: PFrameBuffer;
  Running: Boolean;

begin
  InitVGA;
  BackBuffer := CreateFrameBuffer;

  { Load font }
  if not LoadFont('FONTS\MAIN.PKM', 'FONTS\MAIN.XML', GameFont) then
  begin
    CloseVGA;
    WriteLn('Error: ', GetLoadFontError);
    Halt(1);
  end;

  { Clear screen }
  ClearFrameBuffer(BackBuffer);

  { Draw text }
  PrintFontText(10, 10, 'Hello, World!', GameFont, BackBuffer);
  PrintFontText(10, 50, 'Variable Width Font!', GameFont, BackBuffer);

  { Display }
  RenderFrameBuffer(BackBuffer);

  ReadLn;

  { Cleanup }
  FreeFont(GameFont);
  FreeFrameBuffer(BackBuffer);
  CloseVGA;
end.
```

---

### HUD Rendering (Game UI)

```pascal
procedure RenderHUD(Score, Lives: Integer);
var
  ScoreText, LivesText: string;
begin
  { Format text }
  ScoreText := 'SCORE: ' + IntToStr(Score);
  LivesText := 'LIVES: ' + IntToStr(Lives);

  { Draw HUD elements }
  PrintFontText(10, 10, ScoreText, GameFont, BackBuffer);
  PrintFontText(10, 45, LivesText, GameFont, BackBuffer);

  { Mark HUD region dirty for selective redraw }
  AddDirtyRect(10, 10, GetTextWidth(ScoreText, GameFont), GameFont.Height);
  AddDirtyRect(10, 45, GetTextWidth(LivesText, GameFont), GameFont.Height);
end;
```

---

### Dialogue System

```pascal
procedure ShowDialogue(const Speaker, Text: string);
var
  BoxX, BoxY, BoxWidth, BoxHeight: Integer;
  TextY: Integer;
begin
  { Draw dialogue box background }
  BoxX := 20;
  BoxY := 140;
  BoxWidth := 280;
  BoxHeight := 50;

  DrawBox(BoxX, BoxY, BoxWidth, BoxHeight, BackBuffer);

  { Draw speaker name }
  PrintFontText(BoxX + 10, BoxY + 5, Speaker, BoldFont, BackBuffer);

  { Draw dialogue text }
  TextY := BoxY + 5 + BoldFont.Height + 5;
  PrintFontText(BoxX + 10, TextY, Text, NormalFont, BackBuffer);

  RenderFrameBuffer(BackBuffer);
end;

{ Usage }
ShowDialogue('HERO', 'I must find the ancient gem!');
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
  LoadFont('FONTS\TITLE.PKM', 'FONTS\TITLE.XML', TitleFont);
  LoadFont('FONTS\NORMAL.PKM', 'FONTS\NORMAL.XML', NormalFont);
  LoadFont('FONTS\SMALL.PKM', 'FONTS\SMALL.XML', SmallFont);

  { Use appropriate font for each element }
  PrintFontTextCentered(50, 'XICLONE', TitleFont, BackBuffer);
  PrintFontTextCentered(100, 'Press ENTER to start', NormalFont, BackBuffer);
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

4. **Save as PKM:**
   - File → Save As → PKM format
   - Save to `DATA\FONTS\MYFONT.PKM`

---

### Step 2: Generate XML Metadata

**Option A: Manual creation**

Create `MYFONT.XML`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<font height="32">
  <character code="65" x="0" y="0" width="18" />  <!-- A -->
  <!-- Add all characters... -->
</font>
```

**Option B: DOS tool (recommended)**

Write a helper program `FONTGEN.PAS`:
```pascal
program FontGen;

{ Generates XML from user input }

var
  OutFile: Text;
  CharCode: Integer;
  X, Y, Width: Integer;
  Height: Integer;
  Done: Boolean;

begin
  Assign(OutFile, 'FONT.XML');
  Rewrite(OutFile);

  WriteLn('Font height (pixels): ');
  ReadLn(Height);

  WriteLn(OutFile, '<?xml version="1.0" encoding="UTF-8"?>');
  WriteLn(OutFile, '<font height="', Height, '">');

  Done := False;
  while not Done do
  begin
    Write('Character code (0-127, -1 to finish): ');
    ReadLn(CharCode);

    if CharCode = -1 then
    begin
      Done := True;
      Continue;
    end;

    Write('X position: ');
    ReadLn(X);
    Write('Y position: ');
    ReadLn(Y);
    Write('Width: ');
    ReadLn(Width);

    WriteLn(OutFile, '  <character code="', CharCode,
            '" x="', X, '" y="', Y, '" width="', Width, '" />');
  end;

  WriteLn(OutFile, '</font>');
  Close(OutFile);

  WriteLn('XML file generated: FONT.XML');
end.
```

**Option C: Python script**

```python
# fontgen.py - Generate XML from measurements

import xml.etree.ElementTree as ET

font = ET.Element('font', height='32')

# Define characters (code, x, y, width)
chars = [
    (65, 0, 0, 18),    # A
    (66, 18, 0, 16),   # B
    (67, 34, 0, 17),   # C
    # ... add all characters
]

for code, x, y, width in chars:
    ET.SubElement(font, 'character',
                  code=str(code),
                  x=str(x),
                  y=str(y),
                  width=str(width))

tree = ET.ElementTree(font)
tree.write('FONT.XML', encoding='UTF-8', xml_declaration=True)
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

  if not LoadFont('FONTS\MYFONT.PKM', 'FONTS\MYFONT.XML', Font) then
  begin
    CloseVGA;
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
  CloseVGA;
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
Load PKM image: ~100ms on 286
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

## Implementation Details

### Error Message Storage

```pascal
var
  LastError: string;  { Global in implementation section }

procedure SetError(const Msg: string);
begin
  LastError := Msg;
end;

function GetLoadFontError: string;
begin
  GetLoadFontError := LastError;
end;
```

---

### XML Parsing with MINIXML

```pascal
uses MiniXML;

function LoadFont(const ImageFile, XMLFile: string; var Font: TFont): Boolean;
var
  Doc: PXMLDocument;
  FontNode, CharNode: PXMLNode;
  HeightStr, CodeStr, XStr, YStr, WidthStr: string;
  Height, Code, X, Y, Width: Integer;
  i: Integer;
begin
  LoadFont := False;

  { Initialize font structure }
  for i := 0 to MaxChars - 1 do
  begin
    Font.Chars[i].Defined := False;
    Font.Chars[i].Width := 0;
  end;
  Font.Loaded := False;

  { Load image }
  if not LoadPKM(ImageFile, Font.Image) then
  begin
    SetError('PKM file not found: ' + ImageFile);
    Exit;
  end;

  { Load XML }
  Doc := LoadXMLDocument(XMLFile);
  if Doc = nil then
  begin
    SetError('XML file not found: ' + XMLFile);
    FreeImage(Font.Image);
    Exit;
  end;

  { Get root <font> element }
  FontNode := Doc^.Root;
  if FontNode = nil then
  begin
    SetError('Invalid XML: Missing root element');
    FreeXMLDocument(Doc);
    FreeImage(Font.Image);
    Exit;
  end;

  { Read height attribute }
  HeightStr := GetAttribute(FontNode, 'height');
  if HeightStr = '' then
  begin
    SetError('Missing height attribute in <font> element');
    FreeXMLDocument(Doc);
    FreeImage(Font.Image);
    Exit;
  end;

  Height := StrToInt(HeightStr);
  if (Height <= 0) or (Height > 255) then
  begin
    SetError('Invalid height: ' + HeightStr);
    FreeXMLDocument(Doc);
    FreeImage(Font.Image);
    Exit;
  end;

  Font.Height := Height;

  { Parse each <character> element }
  CharNode := FontNode^.FirstChild;
  while CharNode <> nil do
  begin
    if CharNode^.Name = 'character' then
    begin
      { Read attributes }
      CodeStr := GetAttribute(CharNode, 'code');
      XStr := GetAttribute(CharNode, 'x');
      YStr := GetAttribute(CharNode, 'y');
      WidthStr := GetAttribute(CharNode, 'width');

      { Validate required attributes }
      if (CodeStr = '') or (XStr = '') or (YStr = '') or (WidthStr = '') then
      begin
        SetError('Missing required attribute in <character> element');
        FreeXMLDocument(Doc);
        FreeImage(Font.Image);
        Exit;
      end;

      { Parse values }
      Code := StrToInt(CodeStr);
      X := StrToInt(XStr);
      Y := StrToInt(YStr);
      Width := StrToInt(WidthStr);

      { Validate ranges }
      if (Code < 0) or (Code > 127) then
      begin
        SetError('Invalid character code: ' + CodeStr + ' (must be 0-127)');
        FreeXMLDocument(Doc);
        FreeImage(Font.Image);
        Exit;
      end;

      { Store character info }
      with Font.Chars[Code] do
      begin
        X := X;
        Y := Y;
        Width := Width;
        Defined := True;
      end;
    end;

    CharNode := CharNode^.NextSibling;
  end;

  { Cleanup }
  FreeXMLDocument(Doc);

  Font.Loaded := True;
  LoadFont := True;
end;
```

---

### PrintFontText Implementation

```pascal
procedure PrintFontText(
  X, Y: Integer;
  const Text: string;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);
var
  i: Integer;
  CharCode: Byte;
  CharInfo: TCharInfo;
  SourceRect: TRectangle;
  CursorX: Integer;
begin
  if not Font.Loaded then Exit;

  CursorX := X;

  for i := 1 to Length(Text) do
  begin
    CharCode := Ord(Text[i]);

    { Skip extended ASCII }
    if CharCode > 127 then Continue;

    CharInfo := Font.Chars[CharCode];

    { Skip undefined characters }
    if not CharInfo.Defined then Continue;

    { Handle zero-width characters (advance cursor but don't draw) }
    if CharInfo.Width = 0 then
    begin
      CursorX := CursorX + CharInfo.Width;
      Continue;
    end;

    { Setup source rectangle }
    SourceRect.X := CharInfo.X;
    SourceRect.Y := CharInfo.Y;
    SourceRect.Width := CharInfo.Width;
    SourceRect.Height := Font.Height;

    { Draw character }
    PutImageRect(
      Font.Image,      { Source sprite sheet }
      SourceRect,      { Source rectangle }
      CursorX, Y,      { Destination position }
      True,            { Transparent (color 0) }
      FrameBuffer      { Target buffer }
    );

    { Advance cursor }
    CursorX := CursorX + CharInfo.Width;
  end;
end;
```

---

## Error Handling

### Error Categories

**File errors:**
- PKM file not found
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
"PKM file not found: FONTS\MAIN.PKM"
"XML file not found: FONTS\MAIN.XML"
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
- Requires external PKM + XML files
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

---

## Integration with XICLONE

**Font usage in puzzle game:**
```pascal
var
  TitleFont: TFont;   { 48px tall, decorative }
  UIFont: TFont;      { 24px tall, clean }
  ScoreFont: TFont;   { 32px tall, bold numbers }

procedure RenderGameUI;
begin
  { Title screen }
  PrintFontTextCentered(50, 'XICLONE', TitleFont, BackBuffer);

  { Game HUD }
  PrintFontText(10, 10, 'SCORE:', UIFont, BackBuffer);
  PrintFontText(70, 10, IntToStr(Score), ScoreFont, BackBuffer);

  PrintFontText(10, 40, 'LEVEL:', UIFont, BackBuffer);
  PrintFontText(70, 40, IntToStr(Level), ScoreFont, BackBuffer);
end;
```

**Ready to implement!** 🎨✨
