# VGA.PAS - API Documentation

Low-level VGA Mode 13h graphics driver for DOS (320×200, 256 colors).

## Table of Contents

- [Types](#types)
- [Initialization and Cleanup](#initialization-and-cleanup)
- [Framebuffer Management](#framebuffer-management)
- [Palette Operations](#palette-operations)
- [Drawing Primitives](#drawing-primitives)
- [Image Operations](#image-operations)
- [Common Usage Patterns](#common-usage-patterns)

---

## Types

### TRGBColor

```pascal
type
  TRGBColor = record
    R, G, B: Byte;
  end;
```

RGB color triplet for palette entries. Each component ranges from 0-63 (VGA DAC format).

**Fields:**
- `R` - Red component (0-63)
- `G` - Green component (0-63)
- `B` - Blue component (0-63)

**Example:**
```pascal
var
  Red: TRGBColor;
begin
  Red.R := 63;  { Maximum red }
  Red.G := 0;
  Red.B := 0;
end;
```

---

### TPalette

```pascal
type
  TPalette = array[0..255] of TRGBColor;
```

256-color palette array. Each entry is an RGB triplet.

**Example:**
```pascal
var
  MyPalette: TPalette;
begin
  { Create grayscale palette }
  for i := 0 to 255 do
  begin
    MyPalette[i].R := i shr 2;  { Scale 0-255 to 0-63 }
    MyPalette[i].G := i shr 2;
    MyPalette[i].B := i shr 2;
  end;
  SetPalette(MyPalette);
end;
```

---

### TFrameBuffer / PFrameBuffer

```pascal
type
  PFrameBuffer = ^TFrameBuffer;
  TFrameBuffer = array[0..63999] of byte;
```

64000-byte buffer representing a 320×200 screen (one byte per pixel).

**Access pattern:**
```pascal
Offset := Y * 320 + X;
FrameBuffer^[Offset] := ColorIndex;
```

---

### TImage / PImage

```pascal
type
  PImage = ^TImage;
  TImage = record
    Width: Word;
    Height: Word;
    Data: Pointer;
  end;
```

Image structure for sprites and textures.

**Fields:**
- `Width` - Image width in pixels
- `Height` - Image height in pixels
- `Data` - Pointer to raw pixel data (Width × Height bytes)

**Memory management:**
- Use `GetImage` to allocate and capture
- Use `FreeImage` to deallocate when done
- Data is stored row-by-row, left-to-right

---

### TRectangle

```pascal
type
  TRectangle = record
    X: Integer;
    Y: Integer;
    Width: Word;
    Height: Word;
  end;
```

Rectangular region for image clipping and sprite frames.

**Example:**
```pascal
var
  SpriteFrame: TRectangle;
begin
  SpriteFrame.X := 0;       { Top-left corner in sprite sheet }
  SpriteFrame.Y := 0;
  SpriteFrame.Width := 32;  { 32×32 frame }
  SpriteFrame.Height := 32;
end;
```

---

## Initialization and Cleanup

### InitVGA

```pascal
procedure InitVGA;
```

Switches to VGA Mode 13h (320×200, 256 colors). Saves previous video mode for restoration.

**Example:**
```pascal
begin
  InitVGA;
  { Your graphics code here }
  CloseVGA;  { ALWAYS call to restore text mode }
end;
```

**Notes:**
- Previous video mode is automatically saved
- No parameters or return value

---

### CloseVGA

```pascal
procedure CloseVGA;
```

Restores the original video mode (usually text mode).

**Example:**
```pascal
begin
  InitVGA;
  { Draw graphics }
  CloseVGA;  { Restore text mode before exit }
end;
```

**CRITICAL:**
- **ALWAYS** call before program exit
- Failure to call leaves terminal in graphics mode
- No parameters or return value

---

## Framebuffer Management

### CreateFrameBuffer

```pascal
function CreateFrameBuffer: PFrameBuffer;
```

Allocates a 64000-byte off-screen framebuffer for double-buffering.

**Returns:** Pointer to allocated framebuffer (cleared to black).

**Example:**
```pascal
var
  BackBuffer: PFrameBuffer;
begin
  InitVGA;
  BackBuffer := CreateFrameBuffer;

  { Draw to BackBuffer }
  RenderFrameBuffer(BackBuffer);

  FreeFrameBuffer(BackBuffer);  { MUST free }
  CloseVGA;
end;
```

**Notes:**
- Allocated buffer is cleared to color 0 (black)
- Must be freed with `FreeFrameBuffer` to prevent memory leak
- Use for smooth double-buffering (prevents tearing)

---

### GetScreenBuffer

```pascal
function GetScreenBuffer: PFrameBuffer;
```

Returns a pointer to VGA memory ($A000:0000) for direct drawing.

**Returns:** Pointer to VGA memory (not allocated, no need to free).

**Example:**
```pascal
var
  Screen: PFrameBuffer;
begin
  InitVGA;
  Screen := GetScreenBuffer;

  { Draw directly to screen (no buffering) }
  Screen^[100] := 15;  { Set pixel to color 15 }

  CloseVGA;
end;
```

**Notes:**
- No allocation - points to hardware memory
- **DO NOT** call `FreeFrameBuffer` on this pointer
- Drawing is immediately visible (may cause tearing)
- Useful for debugging or simple programs

---

### ClearFrameBuffer

```pascal
procedure ClearFrameBuffer(FrameBuffer: PFrameBuffer);
```

Fills entire framebuffer with color 0 (black).

**Parameters:**
- `FrameBuffer` - Framebuffer to clear

**Example:**
```pascal
var
  FB: PFrameBuffer;
begin
  FB := CreateFrameBuffer;

  { Draw something }

  ClearFrameBuffer(FB);  { Clear for next frame }

  FreeFrameBuffer(FB);
end;
```

**Notes:**
- Fast assembly implementation (REP STOSW)
- Always clears to color 0 (black)

---

### CopyFrameBuffer

```pascal
procedure CopyFrameBuffer(Source, Dest: PFrameBuffer);
```

Fast copy of entire framebuffer (64000 bytes).

**Parameters:**
- `Source` - Source framebuffer
- `Dest` - Destination framebuffer

**Example:**
```pascal
var
  FrontBuffer, BackBuffer: PFrameBuffer;
begin
  FrontBuffer := CreateFrameBuffer;
  BackBuffer := CreateFrameBuffer;

  { Draw to BackBuffer }

  CopyFrameBuffer(BackBuffer, FrontBuffer);  { Fast copy }

  FreeFrameBuffer(FrontBuffer);
  FreeFrameBuffer(BackBuffer);
end;
```

**Notes:**
- Fast assembly implementation (REP MOVSW)
- Copies all 64000 bytes

---

### RenderFrameBuffer

```pascal
procedure RenderFrameBuffer(FrameBuffer: PFrameBuffer);
```

Blits framebuffer to VGA memory ($A000:0000). Use for double-buffering.

**Parameters:**
- `FrameBuffer` - Framebuffer to display

**Example:**
```pascal
var
  BackBuffer: PFrameBuffer;
begin
  InitVGA;
  BackBuffer := CreateFrameBuffer;

  while GameRunning do
  begin
    ClearFrameBuffer(BackBuffer);
    { Draw to BackBuffer }
    RenderFrameBuffer(BackBuffer);  { Show on screen }
  end;

  FreeFrameBuffer(BackBuffer);
  CloseVGA;
end;
```

**Notes:**
- Fast assembly implementation (REP MOVSW)
- Use `WaitForVSync` before calling to prevent tearing
- Standard double-buffering pattern

---

### FreeFrameBuffer

```pascal
procedure FreeFrameBuffer(var FrameBuffer: PFrameBuffer);
```

Frees allocated framebuffer memory and sets pointer to nil.

**Parameters:**
- `FrameBuffer` - Framebuffer to free (passed by reference)

**Example:**
```pascal
var
  FB: PFrameBuffer;
begin
  FB := CreateFrameBuffer;
  { Use FB }
  FreeFrameBuffer(FB);  { FB is now nil }
end;
```

**Notes:**
- Sets pointer to nil after freeing
- **CRITICAL:** Match every `CreateFrameBuffer` with `FreeFrameBuffer`
- **DO NOT** call on `GetScreenBuffer` result

---

## Palette Operations

### SetPalette

```pascal
procedure SetPalette(const Palette: TPalette);
```

Uploads 256-color palette to VGA DAC.

**Parameters:**
- `Palette` - 256-color palette to upload

**Example:**
```pascal
var
  MyPalette: TPalette;
  i: Integer;
begin
  InitVGA;

  { Create rainbow palette }
  for i := 0 to 255 do
  begin
    MyPalette[i].R := (i * 63) div 255;
    MyPalette[i].G := ((255 - i) * 63) div 255;
    MyPalette[i].B := 31;
  end;

  SetPalette(MyPalette);
  CloseVGA;
end;
```

**Notes:**
- RGB values range from 0-63 (VGA DAC format)
- Fast assembly implementation
- Effect is immediate
- Can be called anytime (even during rendering)

---

### RotatePalette

```pascal
procedure RotatePalette(var Palette: TPalette; StartColor: Byte;
                        Count: Byte; Direction: ShortInt);
```

Rotates a range of palette colors for animation effects.

**Parameters:**
- `Palette` - Palette to modify (by reference)
- `StartColor` - First color index to rotate (0-255)
- `Count` - Number of consecutive colors to rotate
- `Direction` - Rotation direction:
  - `1` = rotate right (colors shift up, last wraps to first)
  - `-1` = rotate left (colors shift down, first wraps to last)

**Example:**
```pascal
var
  MyPalette: TPalette;
begin
  LoadPalette('WATER.PAL', MyPalette);

  { Animate water effect - rotate blue colors }
  while GameRunning do
  begin
    RotatePalette(MyPalette, 16, 16, 1);  { Rotate colors 16-31 right }
    SetPalette(MyPalette);
    Delay(50);  { 50ms delay }
  end;
end;
```

**Classic uses:**
- Water ripples (rotate blue/cyan colors)
- Fire effects (rotate red/orange/yellow colors)
- Energy fields (rotate bright colors)
- Conveyor belts (simulate movement)

**Notes:**
- If `Count <= 1`, does nothing
- If `Direction = 0`, does nothing
- After rotation, call `SetPalette` to apply changes
- Very efficient (only copies RGB triplets in memory)

---

### LoadPalette

```pascal
function LoadPalette(const FileName: string; var Palette: TPalette): Boolean;
```

Loads 768-byte palette file (256 RGB triplets) from disk.

**Parameters:**
- `FileName` - Path to .PAL file
- `Palette` - Palette to load into (by reference)

**Returns:** `True` if successful, `False` on error.

**Example:**
```pascal
var
  MyPalette: TPalette;
begin
  InitVGA;

  if LoadPalette('DATA\IMAGE.PAL', MyPalette) then
  begin
    SetPalette(MyPalette);
    WriteLn('Palette loaded!');
  end
  else
    WriteLn('Failed to load palette');

  CloseVGA;
end;
```

**File format:**
- 768 bytes total (256 colors × 3 bytes per color)
- Each color: R, G, B (0-63 range)
- No header or metadata

**Notes:**
- File must be exactly 768 bytes
- Returns `False` if file not found or wrong size
- Does **not** automatically call `SetPalette`

---

### WaitForVSync

```pascal
procedure WaitForVSync;
```

Waits for vertical blanking interval to prevent screen tearing.

**Example:**
```pascal
var
  BackBuffer: PFrameBuffer;
begin
  InitVGA;
  BackBuffer := CreateFrameBuffer;

  while GameRunning do
  begin
    { Draw to BackBuffer }

    WaitForVSync;              { Wait for VBlank }
    RenderFrameBuffer(BackBuffer);  { Blit during safe period }
  end;

  FreeFrameBuffer(BackBuffer);
  CloseVGA;
end;
```

**Notes:**
- Polls VGA Input Status Register ($03DA)
- Ensures smooth, tear-free rendering
- Call **before** `RenderFrameBuffer` or palette changes
- Adds ~16ms delay (60Hz refresh rate)

---

## Drawing Primitives

### DrawLine

```pascal
procedure DrawLine(X1, Y1, X2, Y2: Integer; Color: Byte;
                   FrameBuffer: PFrameBuffer);
```

Draws a line using Bresenham's algorithm with automatic clipping.

**Parameters:**
- `X1, Y1` - Starting point
- `X2, Y2` - Ending point
- `Color` - Color index (0-255)
- `FrameBuffer` - Framebuffer to draw into

**Example:**
```pascal
var
  FB: PFrameBuffer;
begin
  InitVGA;
  FB := CreateFrameBuffer;

  { Draw a red diagonal line }
  DrawLine(10, 10, 100, 100, 4, FB);

  { Draw a blue horizontal line }
  DrawLine(0, 50, 319, 50, 1, FB);

  { Draw a green vertical line }
  DrawLine(160, 0, 160, 199, 2, FB);

  RenderFrameBuffer(FB);
  ReadLn;

  FreeFrameBuffer(FB);
  CloseVGA;
end;
```

**Notes:**
- Uses Bresenham's algorithm (integer-only, very fast)
- Automatically clips at screen boundaries (0-319, 0-199)
- Works in all directions (8 octants)
- No anti-aliasing (single-pixel width)

---

## Image Operations

### GetImage

```pascal
procedure GetImage(var Image: TImage; X, Y, Width, Height: Word;
                   FrameBuffer: PFrameBuffer);
```

Captures rectangular region from framebuffer into TImage structure.

**Parameters:**
- `Image` - Image structure to populate (by reference)
- `X, Y` - Top-left corner of capture region
- `Width, Height` - Size of capture region
- `FrameBuffer` - Source framebuffer

**Example:**
```pascal
var
  FB: PFrameBuffer;
  PlayerSprite: TImage;
begin
  InitVGA;
  FB := CreateFrameBuffer;

  { Draw player at (10, 10) with size 32×32 }

  GetImage(PlayerSprite, 10, 10, 32, 32, FB);

  { Now PlayerSprite contains captured data }

  FreeImage(PlayerSprite);  { MUST free when done }
  FreeFrameBuffer(FB);
  CloseVGA;
end;
```

**Notes:**
- Allocates memory for `Image.Data` (must call `FreeImage` later)
- Sets `Image.Width` and `Image.Height`
- No clipping - ensure region is within framebuffer bounds

---

### PutImage

```pascal
procedure PutImage(var Image: TImage; X, Y: Word; Transparent: Boolean;
                   FrameBuffer: PFrameBuffer);
```

Draws entire TImage to framebuffer with optional transparency.

**Parameters:**
- `Image` - Image to draw
- `X, Y` - Top-left corner destination
- `Transparent` - If `True`, color 0 is transparent; if `False`, opaque
- `FrameBuffer` - Destination framebuffer

**Example:**
```pascal
var
  FB: PFrameBuffer;
  Sprite: TImage;
begin
  InitVGA;
  FB := CreateFrameBuffer;

  { Assume Sprite is loaded }

  PutImage(Sprite, 100, 50, True, FB);   { Transparent }
  PutImage(Sprite, 200, 50, False, FB);  { Opaque }

  RenderFrameBuffer(FB);
  FreeFrameBuffer(FB);
  CloseVGA;
end;
```

**Notes:**
- Automatically clips at screen boundaries
- Color 0 (black) is treated as transparent when `Transparent = True`
- Delegates to `PutFlippedImage` internally

---

### PutImageRect

```pascal
procedure PutImageRect(var Source: TImage; var SourceRect: TRectangle;
                       X, Y: Integer; Transparent: Boolean;
                       FrameBuffer: PFrameBuffer);
```

Draws a rectangular portion of an image (for sprite sheets or tilesets).

**Parameters:**
- `Source` - Source image (sprite sheet)
- `SourceRect` - Rectangle within source image
- `X, Y` - Destination coordinates
- `Transparent` - If `True`, color 0 is transparent
- `FrameBuffer` - Destination framebuffer

**Example:**
```pascal
var
  FB: PFrameBuffer;
  SpriteSheet: TImage;
  Frame: TRectangle;
begin
  InitVGA;
  FB := CreateFrameBuffer;

  { Load sprite sheet (e.g., 256×64 with 8 frames of 32×32 each) }

  { Draw frame 0 (first frame) }
  Frame.X := 0;
  Frame.Y := 0;
  Frame.Width := 32;
  Frame.Height := 32;
  PutImageRect(SpriteSheet, Frame, 100, 100, True, FB);

  { Draw frame 3 (fourth frame) }
  Frame.X := 96;  { 32 * 3 }
  PutImageRect(SpriteSheet, Frame, 150, 100, True, FB);

  RenderFrameBuffer(FB);
  FreeFrameBuffer(FB);
  CloseVGA;
end;
```

**Notes:**
- Perfect for sprite animation (single sheet, multiple frames)
- Automatically clips at screen boundaries
- No clipping on source rectangle (ensure it's within image bounds)

---

### PutFlippedImage

```pascal
procedure PutFlippedImage(var Image: TImage; X, Y: Word;
                          FlipX, FlipY, Transparent: Boolean;
                          FrameBuffer: PFrameBuffer);
```

Draws entire TImage with optional horizontal/vertical flipping.

**Parameters:**
- `Image` - Image to draw
- `X, Y` - Destination coordinates
- `FlipX` - If `True`, mirror horizontally
- `FlipY` - If `True`, mirror vertically
- `Transparent` - If `True`, color 0 is transparent
- `FrameBuffer` - Destination framebuffer

**Example:**
```pascal
var
  FB: PFrameBuffer;
  Player: TImage;
begin
  InitVGA;
  FB := CreateFrameBuffer;

  { Draw normal }
  PutFlippedImage(Player, 50, 100, False, False, True, FB);

  { Draw facing left (flipped horizontally) }
  PutFlippedImage(Player, 150, 100, True, False, True, FB);

  { Draw upside-down }
  PutFlippedImage(Player, 250, 100, False, True, True, FB);

  RenderFrameBuffer(FB);
  FreeFrameBuffer(FB);
  CloseVGA;
end;
```

**Notes:**
- Useful for player direction (walk left/right with single sprite)
- Fast assembly implementation with specialized code paths
- Automatically clips at screen boundaries

---

### PutFlippedImageRect

```pascal
procedure PutFlippedImageRect(var Source: TImage; var SourceRect: TRectangle;
                              X, Y: Integer; FlipX, FlipY, Transparent: Boolean;
                              FrameBuffer: PFrameBuffer);
```

Draws portion of image with optional flipping. Most versatile image drawing function.

**Parameters:**
- `Source` - Source image
- `SourceRect` - Rectangle within source image
- `X, Y` - Destination coordinates
- `FlipX` - If `True`, mirror horizontally
- `FlipY` - If `True`, mirror vertically
- `Transparent` - If `True`, color 0 is transparent
- `FrameBuffer` - Destination framebuffer

**Example:**
```pascal
var
  FB: PFrameBuffer;
  SpriteSheet: TImage;
  Frame: TRectangle;
begin
  InitVGA;
  FB := CreateFrameBuffer;

  { Setup frame }
  Frame.X := 0;
  Frame.Y := 0;
  Frame.Width := 32;
  Frame.Height := 32;

  { Draw frame 0, facing right }
  PutFlippedImageRect(SpriteSheet, Frame, 100, 100, False, False, True, FB);

  { Draw frame 0, facing left (flipped) }
  PutFlippedImageRect(SpriteSheet, Frame, 150, 100, True, False, True, FB);

  RenderFrameBuffer(FB);
  FreeFrameBuffer(FB);
  CloseVGA;
end;
```

**Notes:**
- Most powerful image drawing function
- All other Put* functions delegate to this internally
- 8 specialized assembly code paths (all flip/transparency combinations)
- Automatically clips at screen boundaries
- Proper clipping logic for all four edges with flip support

---

### FreeImage

```pascal
procedure FreeImage(var Image: TImage);
```

Frees image data memory and resets structure.

**Parameters:**
- `Image` - Image to free (by reference)

**Example:**
```pascal
var
  Sprite: TImage;
begin
  { Allocate via GetImage or manually }
  GetImage(Sprite, 0, 0, 32, 32, SomeBuffer);

  { Use sprite }

  FreeImage(Sprite);  { MUST call to prevent leak }
end;
```

**Notes:**
- Sets `Image.Data` to nil
- Sets `Image.Width` and `Image.Height` to 0
- Safe to call multiple times (checks for nil)
- **CRITICAL:** Match every image allocation with `FreeImage`

---

### ClearImage

```pascal
procedure ClearImage(var Image: TImage);
```

Fills image data with color 0 (black).

**Parameters:**
- `Image` - Image to clear (by reference)

**Example:**
```pascal
var
  Canvas: TImage;
begin
  { Allocate canvas }
  Canvas.Width := 64;
  Canvas.Height := 64;
  GetMem(Canvas.Data, 64 * 64);

  ClearImage(Canvas);  { Fill with black }

  { Draw to canvas }

  FreeImage(Canvas);
end;
```

**Notes:**
- Only clears if `Image.Data` is not nil
- Uses `FillChar` for fast clearing

---

## Common Usage Patterns

### Double-Buffering Pattern

Prevents screen tearing by rendering off-screen, then blitting during VBlank.

```pascal
var
  BackBuffer: PFrameBuffer;
begin
  InitVGA;
  BackBuffer := CreateFrameBuffer;

  while not IsKeyPressed(Key_Escape) do
  begin
    { Clear previous frame }
    ClearFrameBuffer(BackBuffer);

    { Draw all game objects to BackBuffer }
    DrawPlayer(BackBuffer);
    DrawEnemies(BackBuffer);
    DrawUI(BackBuffer);

    { Wait for safe time and display }
    WaitForVSync;
    RenderFrameBuffer(BackBuffer);
  end;

  FreeFrameBuffer(BackBuffer);
  CloseVGA;
end;
```

---

### Palette Animation Pattern

Rotate palette colors for animated effects (water, fire, etc.).

```pascal
var
  MyPalette: TPalette;
  FrameCount: Integer;
begin
  InitVGA;
  LoadPalette('GAME.PAL', MyPalette);
  SetPalette(MyPalette);

  FrameCount := 0;
  while GameRunning do
  begin
    { Rotate water colors every 3 frames }
    if FrameCount mod 3 = 0 then
    begin
      RotatePalette(16, 16, 1);  { Colors 16-31 }
    end;

    Inc(FrameCount);
  end;

  CloseVGA;
end;
```

---

### Sprite Sheet Animation Pattern

Use multiple frames from a sprite sheet for character animation.

```pascal
var
  SpriteSheet: TImage;
  Frame: TRectangle;
  CurrentFrame: Integer;
begin
  { Load sprite sheet with 8 frames (32×32 each) in a row }
  LoadPCX('PLAYER.PCX', SpriteSheet);

  { Setup frame rectangle }
  Frame.Y := 0;
  Frame.Width := 32;
  Frame.Height := 32;

  CurrentFrame := 0;
  while GameRunning do
  begin
    { Calculate frame position }
    Frame.X := CurrentFrame * 32;

    { Draw current frame }
    PutFlippedImageRect(SpriteSheet, Frame, PlayerX, PlayerY,
                        FacingLeft, False, True, BackBuffer);

    { Advance animation }
    CurrentFrame := (CurrentFrame + 1) mod 8;
  end;
end;
```

---

### Pixel-Perfect Collision Detection

Use GetImage to capture and compare pixel data.

```pascal
function CheckCollision(X1, Y1: Integer; Sprite1: TImage;
                        X2, Y2: Integer; Sprite2: TImage): Boolean;
var
  dx, dy, sx, sy, i, j: Integer;
  Offset1, Offset2: Word;
  Pixel1, Pixel2: Byte;
begin
  CheckCollision := False;

  { Calculate overlap region }
  dx := X2 - X1;
  dy := Y2 - Y1;

  for j := 0 to Sprite1.Height - 1 do
    for i := 0 to Sprite1.Width - 1 do
    begin
      sx := i + dx;
      sy := j + dy;

      if (sx >= 0) and (sx < Sprite2.Width) and
         (sy >= 0) and (sy < Sprite2.Height) then
      begin
        Offset1 := j * Sprite1.Width + i;
        Offset2 := sy * Sprite2.Width + sx;

        Pixel1 := Byte(Sprite1.Data^) + Offset1)^;
        Pixel2 := Byte(Sprite2.Data^) + Offset2)^;

        { If both pixels are non-transparent }
        if (Pixel1 <> 0) and (Pixel2 <> 0) then
        begin
          CheckCollision := True;
          Exit;
        end;
      end;
    end;
end;
```

---

### Drawing Shapes with DrawLine

```pascal
{ Draw a rectangle }
procedure DrawRect(X, Y, W, H: Integer; Color: Byte; FB: PFrameBuffer);
begin
  DrawLine(X, Y, X + W - 1, Y, Color, FB);          { Top }
  DrawLine(X, Y + H - 1, X + W - 1, Y + H - 1, Color, FB);  { Bottom }
  DrawLine(X, Y, X, Y + H - 1, Color, FB);          { Left }
  DrawLine(X + W - 1, Y, X + W - 1, Y + H - 1, Color, FB);  { Right }
end;

{ Draw a filled rectangle }
procedure FillRect(X, Y, W, H: Integer; Color: Byte; FB: PFrameBuffer);
var
  i: Integer;
begin
  for i := 0 to H - 1 do
    DrawLine(X, Y + i, X + W - 1, Y + i, Color, FB);
end;
```

---

## Performance Tips

1. **Use double-buffering** - Always render to off-screen buffer, then blit once
2. **Call WaitForVSync** - Prevents tearing and limits frame rate to 60 FPS
3. **Minimize SetPalette calls** - Only call when palette actually changes
4. **Use PutImageRect** - More efficient than multiple PutImage calls for sprite sheets
5. **Clip before drawing** - Check bounds before expensive operations
6. **Cache calculations** - Pre-calculate offsets for frequently-accessed pixels

---

## Common Pitfalls

1. **Forgetting CloseVGA** - Terminal stays in graphics mode (reboot required!)
2. **Memory leaks** - Every `CreateFrameBuffer` needs `FreeFrameBuffer`, every `GetImage` needs `FreeImage`
3. **FreeFrameBuffer on screen buffer** - Never free result of `GetScreenBuffer`
4. **Palette range** - RGB values are 0-63, not 0-255 (VGA DAC format)
5. **No bounds checking on images** - Ensure source rectangles fit within image dimensions
6. **Color 0 transparency** - Remember that color 0 is transparent when `Transparent = True`

---

## See Also

- **PCXLOAD.PAS** - Load PCX image files with palettes
- **SPRITE.PAS** - Delta-time sprite animation system
- **VGAPRINT.PAS** - Bitmap font text rendering
- **KEYBOARD.PAS** - Keyboard input for interactive graphics
