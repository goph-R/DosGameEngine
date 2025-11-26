# XICLONE - Xixit/Columns Clone Design

Falling-block puzzle game: arrange 3-gem stacks to match colors (horizontal/vertical/diagonal).

## Game Overview

**Objective:** Match 3+ same-color gems to survive as long as possible.

**Mechanics:**
- 3-gem stack falls from top (single column)
- Move left/right, rotate, fast fall
- Smooth pixel-by-pixel falling (not tile-snapped)
- Match detection: horizontal, vertical, diagonal
- Gems flash 0.5s → removed → gravity → chain reactions
- Game over when tower reaches top

**Playfield:** 6×12 grid (16×16 tiles = 96×192 pixels)

## Core Implementation

### Data Structures

```pascal
TGemColor = (Gem_Empty, Gem_Red, Gem_Yellow, Gem_Green, Gem_Blue,
             Gem_Pink, Gem_Purple, Gem_MagicJewel);

TGemStack = record
  Gems: array[0..2] of TGemColor;  { Top, Middle, Bottom }
  GridX: Integer;      { Grid column (0-5) }
  PixelX: Integer;     { Pixel X for rendering }
  PixelY: Real;        { Smooth falling (Real for sub-pixel) }
  FallSpeed: Real;     { Pixels per second }
  Active: Boolean;
end;

TPlayfield = record
  Tiles: array[0..5, 0..11] of TGemColor;
  TileChanged: array[0..5, 0..11] of Boolean;  { Dirty flags }
end;
```

**Constants:**
```pascal
PlayfieldCols = 6;  PlayfieldRows = 12;  TileSize = 16;
PlayfieldX = 113;   PlayfieldY = 4;
InitialFallSpeed = 16.0;   { 1 tile/second }
FastFallSpeed = 160.0;     { 10 tiles/second when holding down }
MaxDirtyRects = 96;        { 6×12 playfield + HUD + stack }
```

### Critical Rendering System (286 Optimized)

**Dirty Rectangle Selective Redraw:**
```pascal
{ Track last rendered position separately from physics position }
var
  LastStackX: Integer;
  LastStackY: Real;  { Where stack was DRAWN last frame }
  DirtyRects: array[0..MaxDirtyRects-1] of TRectangle;
  DirtyCount: Integer;

procedure AddDirtyRect(const Rect: TRectangle);
procedure FlushDirtyRects;
  { Copies only dirty regions from BackBuffer to VGA memory }
  { Uses CopyFrameBufferRect for fast 16×16 tile copies }
```

**Why this matters:** Full-screen copy = 100ms on 286 (10 FPS). Dirty rects = ~5ms (60 FPS).

### Visual Artifact Fixes

**Root cause:** When collision snaps `CurrentStack.PixelY` (e.g., 143.7→128), internal position jumps, but we must clear **old visual position** (143) from previous frame.

**Solution:** Track `LastStackX`, `LastStackY` separately.

**RenderStack:**
```pascal
{ STEP 1: Clear old position using LastStackX/LastStackY }
R.X := LastStackX;
R.Y := Trunc(LastStackY) + PlayfieldY;
{ Clip if off-screen }
if R.Y < PlayfieldY then { adjust height };
CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);

{ STEP 2: Draw new position }
for I := 0 to 2 do
  DrawGem(CurrentStack.Gems[I], CurrentStack.PixelX, GemY, BackBuffer);

{ STEP 3: Save position for next frame }
LastStackX := CurrentStack.PixelX;
LastStackY := CurrentStack.PixelY;
```

**LandStack:** Same pattern - clear `LastStackX/LastStackY`, then place gems at snapped grid position.

**DrawGem Fix:**
```pascal
{ ALWAYS restore background first (wipes ghost data) }
GemRect.X := X; GemRect.Y := Y; GemRect.Width/Height := TileSize;
CopyFrameBufferRect(BackgroundBuffer, GemRect, FrameBuffer, X, Y);
{ Then draw gem sprite if not empty }
if GemColor <> Gem_Empty then
  PutImageRect(GemsImage, GemRect, X, Y, True, FrameBuffer);
```

### Collision Detection Fixes

**UpdateFallingStack - Lookahead:**
```pascal
{ CHECK 1: Hard collision }
if (GridY + 3 > PlayfieldRows) or CheckStackCollision(GridX, GridY) then
  { Snap back and land };

{ CHECK 2: Lookahead (critical for smooth falling) }
{ If stack has fractional offset, check if NEXT row is blocked }
if (NewY - (GridY * TileSize)) > 0.1 then
  if CheckStackCollision(GridX, GridY + 1) then
    { Snap to current grid line and land immediately };
```

**Why:** Prevents visual "overshoot" by one tile before landing.

**HandleStackInput - Dangling Check:**
```pascal
{ When moving left/right, check BOTH GridY and GridY+1 if PixelOffset > 0 }
PixelOffset := Trunc(CurrentStack.PixelY) mod TileSize;
CanMove := not CheckStackCollision(NewX, GridY);
if CanMove and (PixelOffset > 0) then
  if CheckStackCollision(NewX, GridY + 1) then
    CanMove := False;
```

**Why:** Prevents moving "through" gems when stack is partially fallen into next row.

### Match Detection & Removal

**FindAndRemoveMatches:**
```pascal
{ PHASE 1: Find all matches, mark for removal (don't remove yet) }
for Y := 0 to 11 do
  for X := 0 to 5 do
    { Check 4 directions (horizontal, vertical, 2 diagonals) }
    if MatchLen >= 3 then MarkForRemoval[X, Y] := True;

{ PHASE 2: Copy to FlashTiles array, start flash effect }
FlashActive := True; FlashTimer := 0.0;
```

**FlashTiles:** 0.5-second flash effect (blink every 100ms).

**RemoveFlashedGems:** After flash timer expires, clear marked tiles → ApplyGravity.

**ApplyGravity:** Repeat until no movement, then check for new matches (chain reactions).

### Input & Game Loop

**Controls:**
- Left/Right: Move stack (IsKeyPressed for tap movement)
- Space: Rotate stack
- Down: Fast fall (IsKeyDown for continuous)
- Escape: Exit

**Delta Timing:**
```pascal
InitRTC(1024);
DeltaTimeAccum := DeltaTimeAccum + (CurrentTime - LastTime);
if DeltaTimeAccum >= 0.014 then { ~70 FPS max }
  UpdateGame(DeltaTime);
  RenderFrame;
  WaitForVSync;
ClearKeyPressed;  { At end of loop }
```

## Engine Features Used

- **VGA.PAS:** InitVGA, CreateFrameBuffer, CopyFrameBufferRect (critical!), PutImageRect, SetPalette, WaitForVSync
- **PKMLOAD.PAS:** LoadPKM, LoadPKMWithPalette
- **KEYBOARD.PAS:** InitKeyboard, IsKeyDown, IsKeyPressed, ClearKeyPressed, DoneKeyboard
- **RTCTIMER.PAS:** InitRTC(1024), GetTimeSeconds, DoneRTC
- **VGAPRINT.PAS:** PrintText (FPS, score, level)
- **STRUTIL.PAS:** IntToStr

## Assets

**Graphics:**
- `DATA\BG1.PKM` - Background (320×200)
- `DATA\GEMS1.PKM` - Gem sprites (8×16×16: Empty, Red, Yellow, Green, Blue, Pink, Purple, MagicJewel)
- `DATA\FONT-LG.PKM/XML` - Large font (unused in current phase)
- `DATA\FONT-SM.PKM/XML` - Small font (unused in current phase)

**Current Phase Status:** Phase 4+ (playable with flash effects, gravity, chain reactions)

## Performance
- 6-7 FPS on ~750 CPU cycles (286 8Mhz)
- 14-18 FPS on ~1510 CPU cycles (286 12Mhz)
- 35+ FPS on ~3300 CPU cycles (286 25Mhz)

**Memory:**
- BackBuffer: 64KB
- BackgroundBuffer: 64KB (pre-rendered background)
- Program + data: ~50KB
- Free: ~450KB

**Optimization Keys:**
1. CopyFrameBufferRect for selective redraw (16×16 tiles)
2. Track dirty rectangles (MaxDirtyRects = 96)
3. Pre-render background to BackgroundBuffer
4. Delta timing for smooth physics

## Future Features (Not Yet Implemented)

- Magic Jewel mechanics (7% of code present, not active)
- Difficulty levels (Novice/Amateur/Pro with 4/5/6 colors)
- Combo system (chain reaction tracking)
- Sound effects (SBDSP/SndBank integration)
- Music (HSC integration)
- Title/menu screens
- Game over detection
- Level progression
- Next stack preview (rendering exists, not randomized)

## Critical Learnings

1. **Separate visual from physics:** LastStackX/Y ≠ CurrentStack position
2. **Lookahead collision:** Check GridY+1 when PixelOffset > 0.1
3. **Dangling collision:** Check both GridY and GridY+1 for horizontal movement
4. **Background restoration:** ALWAYS clear background before drawing gems
5. **Flash before remove:** Mark tiles → flash 0.5s → remove → gravity
6. **Deferred match check:** Set NeedMatchCheck flag, check after rendering complete
