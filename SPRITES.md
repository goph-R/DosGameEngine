# SPRITES.md

Design specification for sprite system in the DOS VGA engine.

## Overview

A flexible sprite system for 320x200 VGA Mode 13h games, supporting:
- Multiple sprite sheets loaded from PKM files
- Animation sequences with frame timing
- Horizontal and vertical flipping
- Transparency (color 0 = transparent)
- Efficient blitting with clipping
- Memory-efficient storage

## Data Structures

### Core Types

```pascal
type
  { Single sprite frame }
  PSpriteFrame = ^TSpriteFrame;
  TSpriteFrame = record
    Width, Height: Word;           { Dimensions in pixels }
    HotSpotX, HotSpotY: Integer;   { Registration point offset }
    Data: Pointer;                 { Pixel data (width * height bytes) }
  end;

  { Animation sequence }
  PAnimation = ^TAnimation;
  TAnimation = record
    Name: String[15];              { Animation identifier }
    FrameCount: Byte;              { Number of frames }
    FrameDelay: Byte;              { Ticks between frames (60Hz base) }
    Loop: Boolean;                 { Loop animation? }
    Frames: array[0..31] of Word;  { Indices into sprite sheet frames }
  end;

  { Sprite sheet - collection of frames and animations }
  PSpriteSheet = ^TSpriteSheet;
  TSpriteSheet = record
    Name: String[15];              { Sheet identifier }
    FrameCount: Word;              { Total frames in sheet }
    AnimCount: Byte;               { Number of animations }
    Palette: TPalette;             { Color palette }
    Frames: array[0..255] of PSpriteFrame;
    Anims: array[0..15] of PAnimation;
  end;

  { Active sprite instance }
  TSprite = record
    Sheet: PSpriteSheet;           { Reference to sprite sheet }
    X, Y: Integer;                 { Screen position }
    AnimIndex: Byte;               { Current animation index }
    Frame: Byte;                   { Current frame in animation }
    TickCounter: Byte;             { Countdown to next frame }
    FlipH, FlipV: Boolean;         { Flip flags }
    Visible: Boolean;              { Render this sprite? }
  end;
```

## File Format

### PKM Sprite Sheet Format

Extension: `.SPR` (modified PKM format)

**Header (after standard PKM header):**
```
Offset  Size  Description
------  ----  -----------
0       2     Frame count (word)
2       1     Animation count (byte)
3       1     Reserved
4       N     Frame descriptors (12 bytes each)
...     M     Animation descriptors (variable)
...     P     Pixel data (RLE compressed or raw)
```

**Frame Descriptor (12 bytes):**
```
Offset  Size  Description
------  ----  -----------
0       2     Width (word)
2       2     Height (word)
4       2     HotSpot X (signed word)
6       2     HotSpot Y (signed word)
8       4     Data offset (longint from start of pixel data)
```

**Animation Descriptor (variable):**
```
Offset  Size  Description
------  ----  -----------
0       1     Name length (byte)
1       N     Name string
N+1     1     Frame count (byte)
N+2     1     Frame delay in ticks (byte)
N+3     1     Flags (bit 0 = loop)
N+4     M     Frame indices (M bytes, one per frame)
```

### Example: Character Sprite Sheet

```
knight.spr:
  Frames:
    0-3:   Walk right (4 frames)
    4-7:   Walk left (4 frames)
    8-11:  Attack right (4 frames)
    12-15: Attack left (4 frames)
    16-19: Idle (4 frames)

  Animations:
    "walk_r"   -> frames 0-3,  delay=6, loop=true
    "walk_l"   -> frames 4-7,  delay=6, loop=true
    "attack_r" -> frames 8-11, delay=4, loop=false
    "attack_l" -> frames 12-15,delay=4, loop=false
    "idle"     -> frames 16-19,delay=10,loop=true
```

## Core Functions

### Loading and Management

```pascal
{ Load sprite sheet from .SPR file }
function LoadSpriteSheet(const FileName: string): PSpriteSheet;

{ Free sprite sheet and all associated memory }
procedure FreeSpriteSheet(var Sheet: PSpriteSheet);

{ Get animation index by name }
function GetAnimationIndex(Sheet: PSpriteSheet; const Name: string): Integer;
```

### Sprite Instance Management

```pascal
{ Initialize a sprite instance }
procedure InitSprite(var Sprite: TSprite; Sheet: PSpriteSheet);

{ Set sprite animation by index }
procedure SetSpriteAnim(var Sprite: TSprite; AnimIndex: Byte);

{ Set sprite animation by name }
function SetSpriteAnimByName(var Sprite: TSprite; const Name: string): Boolean;

{ Update sprite animation (call once per game tick) }
procedure UpdateSprite(var Sprite: TSprite);
```

### Rendering

```pascal
{ Draw sprite to framebuffer (with transparency) }
procedure DrawSprite(FB: PFrameBuffer; var Sprite: TSprite);

{ Draw sprite frame directly (no animation state) }
procedure DrawSpriteFrame(FB: PFrameBuffer; Frame: PSpriteFrame;
                         X, Y: Integer; FlipH, FlipV: Boolean);

{ Fast blit without transparency (for backgrounds) }
procedure BlitSpriteFrame(FB: PFrameBuffer; Frame: PSpriteFrame; X, Y: Integer);
```

## Implementation Details

### Transparency

- **Color 0** is always transparent (common VGA convention)
- Drawing skips pixels with value 0
- Slightly slower than opaque blit but acceptable

### Flipping

**Horizontal Flip:**
```pascal
{ When FlipH = true, read pixels right-to-left }
SrcX := Width - 1 - X;
```

**Vertical Flip:**
```pascal
{ When FlipV = true, read pixels bottom-to-top }
SrcY := Height - 1 - Y;
```

**Implementation options:**
1. **Runtime flip**: Calculate source offset during blit (slower, saves memory)
2. **Pre-flipped frames**: Store 4 versions of each frame (faster, uses 4x memory)
3. **Hybrid**: Flip on-demand and cache (good balance)

**Recommendation**: Runtime flip for DOS - memory is precious, CPU is fast enough.

### Clipping

All drawing functions must clip to screen bounds (0-319, 0-199):

```pascal
{ Calculate visible region }
ClipX := Max(0, X);
ClipY := Max(0, Y);
ClipW := Min(Width, 320 - X);
ClipH := Min(Height, 200 - Y);

{ Skip if completely off-screen }
if (ClipW <= 0) or (ClipH <= 0) then Exit;
```

### Optimized Blitting (Assembly)

For performance-critical sprite drawing:

```pascal
procedure DrawSpriteLineTransparent(Dest, Src: Pointer; Width: Word); assembler;
asm
  push ds
  lds si, Src
  les di, Dest
  mov cx, Width
  cld
@loop:
  lodsb              { AL = next source pixel }
  test al, al        { Check if transparent (color 0) }
  jz @skip           { Skip if transparent }
  stosb              { Write pixel }
  jmp @next
@skip:
  inc di             { Skip destination pixel }
@next:
  loop @loop
  pop ds
end;
```

### Animation State Machine

```pascal
procedure UpdateSprite(var Sprite: TSprite);
var
  Anim: PAnimation;
begin
  if not Sprite.Visible then Exit;
  if Sprite.Sheet = nil then Exit;

  Anim := Sprite.Sheet^.Anims[Sprite.AnimIndex];
  if Anim = nil then Exit;

  { Countdown to next frame }
  Dec(Sprite.TickCounter);
  if Sprite.TickCounter = 0 then
  begin
    { Advance to next frame }
    Inc(Sprite.Frame);

    { Check for animation end }
    if Sprite.Frame >= Anim^.FrameCount then
    begin
      if Anim^.Loop then
        Sprite.Frame := 0  { Loop back to start }
      else
        Dec(Sprite.Frame); { Stay on last frame }
    end;

    { Reset tick counter }
    Sprite.TickCounter := Anim^.FrameDelay;
  end;
end;
```

## Memory Optimization

### Sprite Packing

For typical game with ~100 sprite frames averaging 16x16 pixels:
- 100 frames × 256 bytes = **25 KB** (easily fits in conventional memory)

### Sheet Swapping

For larger games exceeding memory:
1. Load sprite sheets on-demand (level-based)
2. Keep only active sheets in memory
3. Use XMS for sheet caching (when XMS.PAS is fixed)

### Compression

PKM RLE compression works well for sprites with large transparent areas:
- Character sprites: ~40-60% compression
- UI elements: ~60-80% compression

## Tool Workflow

### Creating Sprite Sheets

**Step 1: Draw sprites in image editor**
- Use indexed color mode (256 colors)
- Reserve color 0 for transparency (typically magenta #FF00FF in editor)
- Save as PNG

**Step 2: Convert to sprite sheet**
- Create tool `PNG2SPR.EXE` (can be modern C/Python tool)
- Reads PNG, extracts individual frames by grid
- Generates .SPR file with animation metadata

**Example command:**
```bash
png2spr knight.png knight.spr --grid 16x16 --frames 20 --anims anims.txt
```

**anims.txt:**
```
walk_r,0-3,6,loop
walk_l,4-7,6,loop
attack_r,8-11,4,once
attack_l,12-15,4,once
idle,16-19,10,loop
```

### Alternative: Manual PKM conversion

Since PKM loader exists:
1. Create 320x200 sprite sheet image with all frames
2. Save as PKM
3. Manually define frame rectangles in code
4. Extract frames from PKM at load time

## Usage Example

```pascal
var
  KnightSheet: PSpriteSheet;
  Player: TSprite;

begin
  { Load sprite sheet }
  KnightSheet := LoadSpriteSheet('KNIGHT.SPR');

  { Initialize player sprite }
  InitSprite(Player, KnightSheet);
  SetSpriteAnimByName(Player, 'idle');
  Player.X := 160;
  Player.Y := 100;
  Player.Visible := True;

  { Game loop }
  while GameRunning do
  begin
    { Update (60 Hz) }
    if TimerTick then
    begin
      UpdateSprite(Player);

      { Change animation based on input }
      if KeyPressed then
      begin
        case ReadKey of
          'a': SetSpriteAnimByName(Player, 'walk_l');
          'd': SetSpriteAnimByName(Player, 'walk_r');
          ' ': SetSpriteAnimByName(Player, 'attack_r');
        end;
      end;
    end;

    { Render (~70 Hz) }
    ClearFrameBuffer(FrameBuffer);
    DrawSprite(FrameBuffer, Player);
    RenderFrameBuffer(FrameBuffer);
    WaitForVSync;
  end;

  { Cleanup }
  FreeSpriteSheet(KnightSheet);
end;
```

## Future Enhancements

### Priority/Layering
- Add Z-order field to TSprite
- Sort sprites before drawing

### Collision Detection
- Add bounding box to TSpriteFrame
- Implement AABB or per-pixel collision

### Effects
- Alpha blending (limited on VGA - palette tricks)
- Rotation (difficult without hardware support)
- Scaling (2x/4x integer scales only)

### Particle Systems
- Extend sprite system for particles
- Pool allocation for efficiency

## Implementation Priority

**Phase 1: Basic System**
1. ✅ VGA.PAS already has framebuffer and palette support
2. Create SPRITES.PAS with core data structures
3. Implement LoadSpriteSheet (parse .SPR format)
4. Implement DrawSprite with transparency and clipping

**Phase 2: Animation**
5. Implement UpdateSprite for frame animation
6. Add flip support (H/V)
7. Test with simple sprite sheet

**Phase 3: Tools**
8. Create PNG2SPR converter tool
9. Document workflow
10. Create example sprite sheets

**Phase 4: Optimization**
11. Assembly-optimized blitting
12. Profiling and tuning
13. Memory optimization if needed
