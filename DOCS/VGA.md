# VGA - Mode 13h Graphics

VGA Mode 13h driver (320×200, 256 colors).

## Types

```pascal
type
  TRGBColor = record R, G, B: Byte; end;  { 0-63 VGA DAC }
  TPalette = array[0..255] of TRGBColor;

  TFrameBuffer = array[0..63999] of Byte;
  PFrameBuffer = ^TFrameBuffer;

  TImage = record
    Width: Word;
    Height: Word;
    Data: Pointer;
  end;
  PImage = ^TImage;

  TRectangle = record
    X, Y: Integer;
    Width, Height: Word;
  end;
```

## Functions

### Initialization

```pascal
procedure InitVGA;
procedure DoneVGA;  { CRITICAL: Call before exit }
procedure WaitForVSync;
```

### Framebuffers

```pascal
function CreateFrameBuffer: PFrameBuffer;
function GetScreenBuffer: PFrameBuffer;  { VGA memory, don't free }
procedure ClearFrameBuffer(FrameBuffer: PFrameBuffer);
procedure CopyFrameBuffer(Source, Dest: PFrameBuffer);
procedure CopyFrameBufferRect(Source, Dest: PFrameBuffer; const Rect: TRectangle);
procedure RenderFrameBuffer(FrameBuffer: PFrameBuffer);
procedure FreeFrameBuffer(var FrameBuffer: PFrameBuffer);
```

### Palette

```pascal
procedure SetPalette(const Palette: TPalette);
procedure SetPartialPalette(const Palette: TPalette; FromColor, ToColor: Byte);
procedure SetRGB(Index: Byte; const RGB: TRGBColor);
procedure GetRGB(Index: Byte; var RGB: TRGBColor);
procedure RotatePalette(StartColor: Byte; Count: Byte; Direction: ShortInt);
function LoadPalette(const FileName: string; var Palette: TPalette): Boolean;
```

**SetPartialPalette** - Sets a range of palette colors (FromColor..ToColor inclusive) without affecting other colors. Useful for reserving palette ranges (e.g., colors 0-223 for game graphics, 224-255 for UI/HUD), allowing you to change game palettes without affecting UI.

**RotatePalette** - Rotates a range of colors in the VGA DAC palette for animation effects (water, fire, etc.). Directly modifies hardware palette (no need to call SetPalette afterward). Direction: 1 = rotate right, -1 = rotate left.

### Clipping

```pascal
procedure SetClipRectangle(const Rect: TRectangle);  { Set render bounds }
```

### Drawing

```pascal
procedure DrawLine(X1, Y1, X2, Y2: Integer; Color: Byte; FrameBuffer: PFrameBuffer);
procedure DrawHLine(X, Y, Width: Integer; Color: Byte; FrameBuffer: PFrameBuffer);
procedure DrawVLine(X, Y, Height: Integer; Color: Byte; FrameBuffer: PFrameBuffer);
procedure DrawRect(X, Y, Width, Height: Integer; Color: Byte; FrameBuffer: PFrameBuffer);
procedure DrawFillRect(X, Y, Width, Height: Integer; Color: Byte; FrameBuffer: PFrameBuffer);
```

### Images

```pascal
procedure GetImage(var Image: TImage; X, Y, Width, Height: Word; FrameBuffer: PFrameBuffer);
procedure PutImage(X, Y: Word; Image: PImage; FrameBuffer: PFrameBuffer);
procedure PutImageRect(X, Y: Integer; Image: PImage; const SourceRect: TRectangle; FrameBuffer: PFrameBuffer);
procedure PutFlippedImage(X, Y: Integer; Image: PImage; FlipX, FlipY: Boolean; FrameBuffer: PFrameBuffer);
procedure PutFlippedImageRect(X, Y: Integer; Image: PImage; const SourceRect: TRectangle; FlipX, FlipY: Boolean; FrameBuffer: PFrameBuffer);
procedure ClearImage(var Image: TImage);
procedure FreeImage(var Image: TImage);
```

## Example (Double-Buffering)

```pascal
uses VGA, PCX;

var
  BackBuffer: PFrameBuffer;
  PlayerImage: TImage;
  Palette: TPalette;

begin
  InitVGA;
  BackBuffer := CreateFrameBuffer;

  { Load image with palette }
  LoadPCXWithPalette('PLAYER.PCX', PlayerImage, Palette);
  SetPalette(Palette);

  { Game loop }
  while Running do
  begin
    ClearFrameBuffer(BackBuffer);

    { Draw to backbuffer }
    PutImage(100, 50, @PlayerImage, BackBuffer);
    DrawRect(10, 10, 100, 50, 15, BackBuffer);

    { Display }
    WaitForVSync;
    RenderFrameBuffer(BackBuffer);
  end;

  { Cleanup }
  FreeImage(PlayerImage);
  FreeFrameBuffer(BackBuffer);
  DoneVGA;
end.
```

## Palette Animation

```pascal
var
  Pal: TPalette;
begin
  LoadPalette('WATER.PAL', Pal);
  SetPalette(Pal);

  { Animate water (rotate colors 16-31) }
  while Running do
  begin
    RotatePalette(16, 16, 1);  { Start at color 16, rotate 16 colors, direction right }
    Delay(50);
  end;
end;
```

**Note:** `RotatePalette` directly modifies the VGA DAC palette, so no need to call `SetPalette` again.

## Partial Palette Updates

Use `SetPartialPalette` to reserve palette ranges for different purposes (e.g., game graphics vs UI):

```pascal
var
  Level1Pal, Level2Pal, UIPal: TPalette;
begin
  { Load UI palette (colors 224-255, fixed across all levels) }
  LoadPalette('UI.PAL', UIPal);

  { --- Level 1 --- }
  LoadPalette('LEVEL1.PAL', Level1Pal);
  SetPartialPalette(Level1Pal, 0, 223);  { Game graphics: colors 0-223 }
  SetPartialPalette(UIPal, 224, 255);     { UI/HUD: colors 224-255 }

  { ... gameplay ... }

  { --- Level 2 (different graphics, same UI) --- }
  LoadPalette('LEVEL2.PAL', Level2Pal);
  SetPartialPalette(Level2Pal, 0, 223);  { New game palette }
  { UI palette at 224-255 remains unchanged }
end;
```

**Common palette splits:**
- **0-223** (224 colors): Game graphics/sprites
- **224-255** (32 colors): UI/HUD/text (stays consistent across levels)

## Sprite Sheets

```pascal
var
  SpriteSheet: TImage;
  Frame: TRectangle;
begin
  LoadPCX('SPRITES.PCX', SpriteSheet);

  { Draw frame 0 (32×32) }
  Frame.X := 0;
  Frame.Y := 0;
  Frame.Width := 32;
  Frame.Height := 32;
  PutImageRect(100, 100, @SpriteSheet, Frame, BackBuffer);

  { Draw frame 1 (next frame) }
  Frame.X := 32;
  PutImageRect(150, 100, @SpriteSheet, Frame, BackBuffer);

  { Draw frame 0 flipped }
  PutFlippedImageRect(200, 100, @SpriteSheet, Frame, True, False, BackBuffer);
end;
```

## Critical Notes

1. **DoneVGA** - MUST call before exit or terminal stuck in graphics mode
2. **Color 0 = transparent** - When drawing images
3. **Palette range** - RGB values 0-63, not 0-255
4. **WaitForVSync** - Call before RenderFrameBuffer to prevent tearing
5. **Free buffers** - Match CreateFrameBuffer with FreeFrameBuffer
6. **Don't free screen buffer** - GetScreenBuffer returns VGA memory

## Performance

- Use double-buffering (CreateFrameBuffer + RenderFrameBuffer)
- Call WaitForVSync to limit to 60 FPS
- Fast assembly implementations (REP MOVSW for copies)
- Auto-clipping on all drawing functions

## Notes

- Mode 13h: 320×200, 256 colors, linear framebuffer at $A000:0000
- Palette animation for water/fire effects (no redraw needed)
- Supports horizontal/vertical flipping for sprites
- See PCX.PAS for loading images, SPRITE.PAS for animation
