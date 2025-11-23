# XICLONE - Xixit/Columns Clone Design Document

A falling-block puzzle game where players arrange stacks of three gems to match colors horizontally, vertically, or diagonally.

---

## Table of Contents

- [Game Overview](#game-overview)
- [Technical Specifications](#technical-specifications)
- [Engine Features Used](#engine-features-used)
- [Rendering Strategy (286 Optimized)](#rendering-strategy-286-optimized)
- [Game Architecture](#game-architecture)
- [Game States](#game-states)
- [Core Game Logic](#core-game-logic)
- [Input System](#input-system)
- [Audio System](#audio-system)
- [Asset Requirements](#asset-requirements)
- [Performance Considerations](#performance-considerations)
- [Implementation Phases](#implementation-phases)

---

## Game Overview

### Gameplay

**Objective:** Survive as long as possible by matching three or more gems of the same color.

**Mechanics:**
- A stack of **3 gems** falls from the top in a single column
- Player can **move left/right** and **rotate** the stack
- Gems fall with **smooth pixel-by-pixel** animation (not tile-snapped)
- When stack lands, check for matches (3+ same color)
- Matches can be **horizontal, vertical, or diagonal**
- Matched gems disappear, gems above fall down
- Game ends when tower reaches the top

**Playfield:**
- **6 columns × 12 rows** (6×12 grid)
- **Tile size:** 16×16 pixels (from CONFIG.PAS TileSize constant)
- **Playfield area:** 96×192 pixels (6×16 × 12×16)

### Difficulty Levels & Gem Colors

The number of colored gems available in the game varies depending on the difficulty setting:

- **Novice difficulty:** Uses 4 different colors of gems (Red, Green, Blue, Yellow)
- **Amateur difficulty:** Uses 5 different colors of gems (Red, Pink, Green, Blue, Yellow)
- **Pro difficulty** (standard/arcade mode): Uses 6 different colors of gems (Red, Pink, Green, Blue, Yellow, Purple)

### Magic Jewel

A special **Magic Jewel** (multi-colored) occasionally appears in falling stacks. When it lands on the playfield, it eliminates all other gems of the color it lands on, creating powerful chain reactions and scoring opportunities.

**Magic Jewel behavior:**
- Appears randomly with a 3% chance per stack (~3 in 100)
- **Guaranteed spawn:** If you eliminate three sets of jewels simultaneously or consecutively (a combo), a Magic Jewel is guaranteed to appear in your next set of jewels
- Replaces one gem in the falling stack
- When placed, destroys all gems of the same color as the tile it occupies
- Does not count as a match by itself
- Creates opportunities for cascading combos

---

## Technical Specifications

### Target Hardware

- **CPU:** 286 (8-12 MHz)
- **Memory:** 640KB conventional RAM
- **Graphics:** VGA Mode 13h (320×200, 256 colors)
- **Sound:** Adlib (HSC music) + Sound Blaster (digital audio)

### Performance Constraints

**Why no double buffering:**
- 286 CPU too slow for 64KB framebuffer copies (320×200 = 64000 bytes)
- `RenderFrameBuffer` copies entire screen (~100ms on 286)
- 10 FPS max with full-screen double buffering
- **Solution:** Selective redraw using `CopyFrameBufferRect`

**Target Frame Rate:**
- 30 FPS minimum (33ms per frame)
- 60 FPS ideal (16ms per frame)

---

## Engine Features Used

### Graphics (VGA.PAS)

```pascal
uses VGA;

{ Core functions }
- InitVGA / CloseVGA
- CreateFrameBuffer / FreeFrameBuffer
- GetScreenBuffer: Returns pointer to VGA memory ($A000:0000)
- ClearFrameBuffer
- SetPalette / LoadPalette

{ Rendering - CRITICAL for 286! }
- PutImage: Draw gem sprites
- PutImageRect: Draw portion of sprite sheet
- CopyFrameBufferRect: Copy rectangular region (FAST!)

  procedure CopyFrameBufferRect(
    Source: PFrameBuffer;
    var SourceRect: TRectangle;
    Dest: PFrameBuffer;
    DestX, DestY: Word
  );

  { Uses REP MOVSW for fast word-aligned copying }
  { Width is rounded down to even (odd widths become Width-1) }

{ Strategy: }
{ - Render to off-screen buffer }
{ - Copy ONLY changed regions to VGA memory using CopyFrameBufferRect }
{ - Avoid full-screen RenderFrameBuffer! }
```

**Why CopyFrameBufferRect is key:**
- Copies small regions (e.g., 16×16 tile = 256 bytes)
- 250× faster than full screen copy (256 bytes vs 64000 bytes)
- Enables 60 FPS on 286

---

### Image Loading (PKMLOAD.PAS)

```pascal
uses PKMLoad;

{ Load sprite sheets and backgrounds }
- LoadPKM(filename, buffer): Load background/title screen
- LoadPKMWithPalette(filename, buffer, palette): Load with palette
```

**Assets:**
- `GEMS1.PKM` - Gem sprite sheet (16×16 tiles)
- `BG1.PKM` - Static playfield background #1 (maybe later more)
- `TITLE.PKM` - Title screen

---

### Input (KEYBOARD.PAS)

```pascal
uses Keyboard;

{ Initialization }
- InitKeyboard / DoneKeyboard

{ Input detection }
- IsKeyDown(scancode): Continuous (for movement)
- IsKeyPressed(scancode): Single-tap (for rotation, menu)
- ClearKeyPressed: Call at end of game loop

{ Keys used }
- Key_Left / Key_Right: Move falling stack
- Key_Up / Key_Down: Rotate stack up/down
- Key_Space: Hard drop (fast fall)
- Key_Escape: Pause/exit
- Key_Enter: Menu selection
```

**Input pattern:**
```pascal
{ Continuous movement }
if IsKeyDown(Key_Left) then
  MoveStackLeft;

{ Single-tap rotation }
if IsKeyPressed(Key_Up) then
  RotateStackUp;

{ MUST call at end of loop }
ClearKeyPressed;
```

---

### Timing (RTCTIMER.PAS)

```pascal
uses RTCTimer;

{ High-resolution timing (IRQ8, no conflict with HSC music) }
- InitRTC(1024): Initialize at 1024 Hz
- DoneRTC: Cleanup
- GetTimeSeconds: Returns Real (seconds)

{ Delta time pattern }
var
  CurrentTime, LastTime: Real;
  DeltaTime: LongInt;  { milliseconds }

begin
  InitRTC(1024);
  LastTime := GetTimeSeconds;

  while GameRunning do
  begin
    CurrentTime := GetTimeSeconds;
    DeltaTime := Round((CurrentTime - LastTime) * 1000.0);
    LastTime := CurrentTime;

    UpdateGame(DeltaTime);  { Pass delta time in ms }
  end;

  DoneRTC;
end;
```

**Why delta timing:**
- Frame-rate independent game logic
- Smooth falling animation regardless of CPU speed
- Consistent game speed on 286 vs 486

---

### Audio System

#### Music (PLAYHSC.PAS)

```pascal
uses PlayHSC;

var
  Music: HSC_obj;

{ Initialization }
Music.Init(0);  { Auto-detect Adlib at $388 }

{ Playback }
Music.LoadFile('MUSIC\ADTHELIB.HSC.HSC');
Music.Start;
Music.Poll;  { Call regularly in game loop }

{ Cleanup }
Music.Done;  { CRITICAL: Unhook IRQ0 before exit }
```

**Music tracks:**
1. `INTRO.HSC`        - Title screen music
2. `ADTHELIB.HSC.HSC` - Gameplay music (track 1)
3. `TECHNO.HSC`       - Gameplay music (track 2, faster tempo)

---

#### Sound Effects (SNDBANK.PAS + SBDSP.PAS)

```pascal
uses SBDSP, SndBank;

var
  SoundBank: TSoundBank;
  SoundIDs: record
    MenuStep: Integer;
    MenuEnter: Integer;
    GemFall: Integer;
    GemRotate: Integer;
    GemMatch: Integer;
    MagicJewel: Integer;
  end;

{ Initialization }
ResetDSP(2, 5, 1, 0);  { SB at port $220, IRQ 5, DMA 1 }
SoundBank.Init;

{ Load sounds }
SoundIDs.MenuStep := SoundBank.LoadSound('SOUNDS\STEP.VOC');
SoundIDs.MenuEnter := SoundBank.LoadSound('SOUNDS\ENTER.VOC');
SoundIDs.GemFall := SoundBank.LoadSound('SOUNDS\FALL.VOC');
SoundIDs.GemRotate := SoundBank.LoadSound('SOUNDS\ROTATE.VOC');
SoundIDs.GemMatch := SoundBank.LoadSound('SOUNDS\MATCH.VOC');
SoundIDs.MagicJewel := SoundBank.LoadSound('SOUNDS\MAGIC.VOC');

{ Play sounds }
SoundBank.PlaySound(SoundIDs.GemRotate);

{ Cleanup }
SoundBank.Done;
UninstallHandler;
```

**Sound effects:**
- `STEP.VOC` - Menu cursor move
- `ENTER.VOC` - Menu selection confirm
- `FALL.VOC` - Gem stack lands
- `ROTATE.VOC` - Gem stack rotates
- `MATCH.VOC` - Gems matched and destroyed

---

### Text Rendering (VGAPRINT.PAS)

```pascal
uses VGAPrint;

{ Draw text overlays }
- PrintText(x, y, text, color, framebuffer)

{ Usage }
PrintText(10, 10, 'SCORE: ' + IntToStr(Score), 15, FrameBuffer);
PrintText(10, 20, 'LEVEL: ' + IntToStr(Level), 15, FrameBuffer);
```

**HUD elements:**
- Score (top-left)
- Level (top-left)
- Next gem preview (top-right)
- FPS counter (debug mode)

---

## Rendering Strategy (286 Optimized)

### The Problem with Double Buffering

**Traditional approach:**
```pascal
{ BAD for 286! }
while GameRunning do
begin
  ClearFrameBuffer(BackBuffer);
  DrawEverything(BackBuffer);
  RenderFrameBuffer(BackBuffer);  { 64KB copy = 100ms on 286! }
end;
{ Result: 10 FPS max }
```

---

### Selective Redraw Strategy ⭐

**Key insight:** Only redraw what changed!

```pascal
uses VGA;

type
  TDirtyRect = record
    Rect: TRectangle;
    Dirty: Boolean;
  end;

var
  BackBuffer: PFrameBuffer;    { Off-screen buffer for drawing }
  ScreenBuffer: PFrameBuffer;  { Direct VGA memory pointer }
  DirtyRects: array[0..31] of TDirtyRect;
  DirtyCount: Integer;

procedure AddDirtyRect(const Rect: TRectangle);
begin
  if DirtyCount >= 32 then Exit;
  with DirtyRects[DirtyCount] do
  begin
    Rect := Rect;
    Dirty := True;
  end;
  Inc(DirtyCount);
end;

procedure FlushDirtyRects;
var
  i: Integer;
begin
  ScreenBuffer := GetScreenBuffer;  { Get VGA memory pointer }

  for i := 0 to DirtyCount - 1 do
  begin
    with DirtyRects[i] do
    begin
      if Dirty then
      begin
        CopyFrameBufferRect(
          BackBuffer,    { Source: off-screen buffer }
          Rect,          { Source rectangle }
          ScreenBuffer,  { Dest: VGA memory }
          Rect.X, Rect.Y { Dest position (same as source) }
        );
      end;
    end;
  end;

  DirtyCount := 0;
end;
```

---

### Rendering Zones

**Divide screen into regions:**

```
┌────────────────────────┐
│ HUD (Score/Level)      │ ← Zone 1: Static (redraw on change)
├────────┬───────────────┤
│ Play   │ Next Gem      │ ← Zone 2: Dynamic (redraw every frame)
│ Field  │ Preview       │ ← Zone 3: Static (redraw on change)
│ 6×12   │               │
│        │               │
└────────┴───────────────┘
```

**Zone rendering:**

```pascal
{ Zone 1: HUD - Only redraw when score/level changes }
procedure UpdateHUD;
var
  R: TRectangle;
begin
  if ScoreChanged then
  begin
    PrintText(10, 10, 'SCORE: ' + IntToStr(Score), 15, BackBuffer);
    R.X := 10;
    R.Y := 10;
    R.Width := 100;
    R.Height := 8;
    AddDirtyRect(R);  { Mark HUD region dirty }
  end;
end;

{ Zone 2: Playfield - Redraw only changed tiles }
procedure UpdatePlayfield;
var
  X, Y: Integer;
  R: TRectangle;
begin
  for Y := 0 to 11 do
  begin
    for X := 0 to 5 do
    begin
      if TileChanged[X, Y] then
      begin
        DrawTile(X, Y, BackBuffer);
        R.X := PlayfieldX + X * 16;
        R.Y := PlayfieldY + Y * 16;
        R.Width := 16;
        R.Height := 16;
        AddDirtyRect(R);
        TileChanged[X, Y] := False;
      end;
    end;
  end;
end;

{ Zone 3: Falling stack - Always redraw (moving every frame) }
{ CRITICAL: Track LastStackX/LastStackY to clear old rendered position! }
var
  LastStackX: Integer;
  LastStackY: Real;

procedure RenderStack;
var
  I: Integer;
  GemY: Integer;
  R: TRectangle;
  ClipOffset: Integer;
begin
  if not CurrentStack.Active then Exit;

  { --- STEP 1: CLEAR OLD POSITION --- }
  { Use LastStackX/LastStackY (last rendered position), not CurrentStack values! }
  { CurrentStack.PixelY may have jumped during collision/snapping, causing artifacts }

  R.X := LastStackX;
  R.Y := Trunc(LastStackY) + PlayfieldY;
  R.Width := TileSize;
  R.Height := TileSize * 3;

  { Clipping Logic: Handle if the stack is partially off the top of the screen }
  if R.Y < 0 then
  begin
    ClipOffset := -R.Y;  { How many pixels are off-screen }
    R.Y := 0;            { Move to top of screen }
    R.Height := R.Height - ClipOffset;  { Reduce height }
  end;

  { Only clear if there is actually something visible to clear }
  if R.Height > 0 then
  begin
    CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);
    AddDirtyRect(R);
  end;

  { --- STEP 2: DRAW NEW POSITION --- }

  for I := 0 to 2 do
  begin
    GemY := Trunc(CurrentStack.PixelY) + (I * TileSize);

    { Only draw if gem would be visible (not off top of screen) }
    if (GemY + PlayfieldY) >= 0 then
      DrawGem(CurrentStack.Gems[I], CurrentStack.PixelX, GemY + PlayfieldY, BackBuffer);
  end;

  { --- STEP 3: MARK DIRTY RECT FOR NEW POSITION --- }

  R.X := CurrentStack.PixelX;
  R.Y := Trunc(CurrentStack.PixelY) + PlayfieldY;
  R.Width := TileSize;
  R.Height := TileSize * 3;

  { Apply same clipping logic for the dirty rect }
  if R.Y < 0 then
  begin
    ClipOffset := -R.Y;
    R.Y := 0;
    R.Height := R.Height - ClipOffset;
  end;

  if R.Height > 0 then
    AddDirtyRect(R);

  { CRITICAL: Save current position for next frame! }
  LastStackX := CurrentStack.PixelX;
  LastStackY := CurrentStack.PixelY;
end;
```

**Critical fixes for visual artifacts:**

1. **Track last rendered position:** Use `LastStackX` and `LastStackY` to store where the stack was **actually drawn** on the previous frame. When `CurrentStack.PixelY` snaps during collision detection, it can jump by several pixels, but we must clear the **old visual position**, not the current internal position.

2. **Clipping for off-screen stacks:** When the stack spawns above the playfield (negative Y), handle clipping correctly:
   - Don't try to clear/draw negative Y coordinates
   - Calculate `ClipOffset` to adjust rectangle dimensions
   - Only process dirty rects when `R.Height > 0`

3. **Save position after rendering:** At the end of `RenderStack`, save the current position to `LastStackX`/`LastStackY` for the next frame's cleanup.
```

---

### Main Rendering Loop

```pascal
procedure RenderGame;
begin
  { 1. Update off-screen buffer (BackBuffer) }
  UpdateHUD;              { Only if score changed }
  UpdatePlayfield;        { Only changed tiles }
  UpdateFallingStack;     { Always (moving) }

  { 2. Copy dirty regions to VGA memory }
  FlushDirtyRects;        { Fast! Only copies changed areas }

  { Result: ~16ms on 286 = 60 FPS! }
end;
```

**Performance analysis:**
```
Full screen copy: 64000 bytes = 100ms (10 FPS)
Dirty rect copy:
  - HUD: 100×8 = 800 bytes (when changed)
  - Playfield: 6×16×16 = 1536 bytes (average 2 tiles changed)
  - Stack: 16×48 = 768 bytes (every frame)
  - Total: ~3104 bytes = 4.9ms (204 FPS!)

Actual framerate with game logic: 60 FPS
```

---

### Background Rendering Strategy

**Static background:**
```pascal
{ Pre-render static background once }
procedure InitBackground;
var
  FullScreenRect: TRectangle;
begin
  { Draw playfield border, decorations, etc. to BackBuffer }
  LoadPKM('BACKGROUND.PKM', BackgroundImage);
  PutImage(BackgroundImage, 0, 0, False, BackBuffer);

  { Copy to screen once }
  ScreenBuffer := GetScreenBuffer;
  FullScreenRect.X := 0;
  FullScreenRect.Y := 0;
  FullScreenRect.Width := 320;
  FullScreenRect.Height := 200;
  CopyFrameBufferRect(BackBuffer, FullScreenRect, ScreenBuffer, 0, 0);
end;

{ When redrawing a tile, restore background first }
procedure RestoreBackground(const Rect: TRectangle);
begin
  { Copy from pre-rendered background image }
  CopyFrameBufferRect(
    BackgroundBuffer,  { Source: clean background }
    Rect,              { Source rectangle }
    BackBuffer,        { Dest: working buffer }
    Rect.X, Rect.Y     { Dest position }
  );
end;
```

---

### Visual Artifact Fixes Summary

The smooth pixel-by-pixel falling animation introduces several subtle rendering bugs that manifest as visual artifacts. All fixes involve tracking the **last rendered position** separately from the **current physics position**.

**Root cause:** When collision detection snaps `CurrentStack.PixelY` (e.g., from 143.7 to 128), the internal position jumps instantly, but we must clear the **old visual position** (143) from the previous frame, not the new snapped position (128).

**Solution:** Track `LastStackX` and `LastStackY` variables that store where the stack was **actually rendered** on the previous frame.

**All affected procedures:**

1. **RenderStack:**
   - Clear old position using `LastStackX` / `LastStackY`
   - Draw new position at `CurrentStack.PixelX` / `CurrentStack.PixelY`
   - Save current position to `LastStackX` / `LastStackY` for next frame
   - Apply clipping when stack is off-screen (negative Y)

2. **LandStack:**
   - Clear old position using `LastStackX` / `LastStackY` (not current position!)
   - Place gems on grid using snapped `CurrentStack.PixelY`
   - Apply clipping for off-screen stacks

3. **UpdateFallingStack:**
   - **Lookahead collision check** when `PixelOffset > 0.1`
   - Prevents visual "overshoot" by one tile before landing
   - Snaps to grid line when next row is blocked

4. **HandleStackInput:**
   - **Dangling collision check** when `PixelOffset > 0`
   - Checks both `GridY` AND `GridY + 1` for horizontal movement
   - Prevents stack from moving "through" gems when partially fallen

**Without these fixes:** Gem trails, ghost images, overshoot artifacts, and collision bugs occur.

---

## Game Architecture

### Core Data Structures

```pascal
type
  TDifficulty = (
    Difficulty_Novice,   { 4 colors: Red, Green, Blue, Yellow }
    Difficulty_Amateur,  { 5 colors: + Pink }
    Difficulty_Pro       { 6 colors: + Purple }
  );

  TGemColor = (
    Gem_Empty,
    Gem_Red,
    Gem_Pink,
    Gem_Green,
    Gem_Blue,
    Gem_Yellow,
    Gem_Purple,
    Gem_MagicJewel       { Special gem that clears matching colors }
  );

  TGemStack = record
    Gems: array[0..2] of TGemColor;  { Top, Middle, Bottom }
    X: Integer;         { Grid column (0-5) }
    Y: Integer;         { Pixel Y position (smooth falling) }
    PixelX: Integer;    { Pixel X position (for rendering) }
    FallSpeed: Integer; { Pixels per second }
    Active: Boolean;    { Is stack currently falling? }
  end;

  TPlayfield = record
    Tiles: array[0..5, 0..11] of TGemColor;  { 6×12 grid }
    TileChanged: array[0..5, 0..11] of Boolean;
  end;

  TGameState = record
    Playfield: TPlayfield;
    CurrentStack: TGemStack;
    NextStack: TGemStack;  { Preview }
    Score: LongInt;
    Level: Integer;
    Difficulty: TDifficulty;
    ComboCount: Integer;           { Number of consecutive/simultaneous matches }
    GuaranteeMagicJewel: Boolean;  { Force Magic Jewel in next stack }
    GameOver: Boolean;
  end;
```

---

### Constants

```pascal
const
  { Playfield dimensions }
  PlayfieldCols = 6;
  PlayfieldRows = 12;
  TileSize = 16;  { From CONFIG.PAS }

  { Screen positions }
  PlayfieldX = 80;   { Center playfield horizontally }
  PlayfieldY = 20;   { Leave room for HUD }

  { Game tuning }
  InitialFallSpeed = 30;   { Pixels per second }
  FastFallSpeed = 120;     { When holding down/space }
  LevelSpeedIncrease = 5;  { Pixels per second per level }

  { Match detection }
  MinMatchLength = 3;      { Minimum gems to match }

  { Difficulty settings }
  NoviceColorCount = 4;    { Red, Green, Blue, Yellow }
  AmateurColorCount = 5;   { + Pink }
  ProColorCount = 6;       { + Purple }

  { Magic Jewel }
  MagicJewelChance = 3;    { 3% chance per stack (~3 in 100) }

  { Scoring }
  PointsPerGem = 10;
  BonusMultiplier = 2;     { For chains/combos }
  MagicJewelBonus = 50;    { Bonus points when Magic Jewel activates }
```

---

## Game States

### State Machine

```pascal
type
  TGameMode = (
    Mode_Title,
    Mode_Menu,
    Mode_Playing,
    Mode_Paused,
    Mode_GameOver
  );

var
  CurrentMode: TGameMode;

{ Main loop }
while Running do
begin
  UpdateMouse;

  case CurrentMode of
    Mode_Title:    UpdateTitle;
    Mode_Menu:     UpdateMenu;
    Mode_Playing:  UpdateGame(DeltaTime);
    Mode_Paused:   UpdatePause;
    Mode_GameOver: UpdateGameOver;
  end;

  ClearKeyPressed;
end;
```

---

### Title Screen

**Features:**
- Static PKM image with title/logo
- "Press any key" text blinking
- HSC music playing (`INTRO.HSC`)

**Rendering:**
```pascal
procedure RenderTitle;
begin
  { Load title screen once }
  LoadPKMWithPalette('TITLE.PKM', TitleImage, Palette);
  SetPalette(Palette);

  { Copy to screen }
  ScreenBuffer := GetScreenBuffer;
  Move(TitleImage^, ScreenBuffer^, 64000);

  { Blink "Press any key" }
  if (BlinkTimer mod 1000) < 500 then
    PrintText(100, 180, 'PRESS ANY KEY', 15, ScreenBuffer);
end;
```

---

### Menu Screen

**Options:**
- Start Game
- Select Difficulty (Novice / Amateur / Pro)
- Options (sound on/off, music track selection)
- Exit

**Input:**
```pascal
procedure UpdateMenu;
begin
  if IsKeyPressed(Key_Up) then
  begin
    Dec(MenuIndex);
    if MenuIndex < 0 then MenuIndex := MenuCount - 1;
    SoundBank.PlaySound(SoundIDs.MenuStep);
  end;

  if IsKeyPressed(Key_Down) then
  begin
    Inc(MenuIndex);
    if MenuIndex >= MenuCount then MenuIndex := 0;
    SoundBank.PlaySound(SoundIDs.MenuStep);
  end;

  if IsKeyPressed(Key_Enter) then
  begin
    SoundBank.PlaySound(SoundIDs.MenuEnter);
    ExecuteMenuItem(MenuIndex);
  end;
end;
```

---

## Core Game Logic

### Falling Stack Update

```pascal
procedure UpdateFallingStack(DeltaTimeMS: LongInt);
var
  OldY: Real;
  NewY: Real;
  GridY: Integer;
  PixelsFallen: Real;
  NextStepBlocked: Boolean;
  R: TRectangle;
begin
  if not CurrentStack.Active then Exit;

  { Calculate pixels to fall this frame }
  if IsKeyDown(Key_Down) or IsKeyDown(Key_Space) then
    PixelsFallen := (FastFallSpeed * DeltaTimeMS) / 1000.0
  else
    PixelsFallen := (CurrentStack.FallSpeed * DeltaTimeMS) / 1000.0;

  { Calculate tentative new position }
  NewY := CurrentStack.PixelY + PixelsFallen;

  { Calculate the primary grid row }
  GridY := Trunc(NewY) div TileSize;

  { CHECK 1: HARD COLLISION }
  { If we moved a full tile and hit something strictly at this new GridY }
  if (GridY + 3 > PlayfieldRows) or CheckStackCollision(CurrentStack.GridX, GridY) then
  begin
    { We hit something. Back up to the previous valid row (GridY - 1) and land. }
    CurrentStack.PixelY := (GridY - 1) * TileSize;
    LandStack;
  end
  else
  begin
    { CHECK 2: LOOKAHEAD (Critical for smooth falling) }
    { If the stack is not perfectly aligned (fraction > 0), it means the bottom }
    { of the stack is visually entering the territory of the NEXT row (GridY+3). }
    { Without this check, the stack appears to "overshoot" by one tile before landing. }

    if (NewY - (GridY * TileSize)) > 0.1 then
    begin
      { Check if the NEXT grid position down is blocked }
      NextStepBlocked := (GridY + 1 + 3 > PlayfieldRows) or
                         CheckStackCollision(CurrentStack.GridX, GridY + 1);

      if NextStepBlocked then
      begin
        { The space we are trying to slide into is blocked. }
        { Force snap to the current integer grid line and land immediately. }
        CurrentStack.PixelY := GridY * TileSize;
        LandStack;
        Exit;
      end;
    end;

    { No collision detected, allow movement }
    CurrentStack.PixelY := NewY;
  end;

  { Mark dirty rect if position changed }
  if CurrentStack.PixelY <> OldY then
  begin
    R.X := CurrentStack.PixelX;
    R.Y := Trunc(OldY) + PlayfieldY;
    R.Width := 16;
    R.Height := 48;
    AddDirtyRect(R);  { Old position }

    R.Y := Trunc(CurrentStack.PixelY) + PlayfieldY;
    AddDirtyRect(R);  { New position }
  end;
end;
```

**Key insight - Pixel Offset Lookahead:**

The critical fix is the **lookahead collision check** when the stack has a fractional pixel offset. When `PixelY` is not grid-aligned (e.g., `PixelY = 32.5`), the visual bottom of the 3-gem stack is entering the territory of the next row down. Without lookahead, the stack would render one frame "inside" the blocked tile before detecting collision, causing a visual "overshoot" artifact.

**The solution:** When the stack has any fractional offset (`NewY - (GridY * TileSize) > 0.1`), we check if `GridY + 1` is blocked. If so, we snap to the current grid line (`GridY * TileSize`) and land immediately, preventing the visual overshoot.

---

### Stack Landing Detection

```pascal
function HasStackLanded(const Stack: TGemStack): Boolean;
var
  GridY: Integer;
  i: Integer;
begin
  { Convert pixel Y to grid row }
  GridY := (Stack.Y - PlayfieldY) div TileSize;

  { Bottom gem position }
  GridY := GridY + 2;  { Stack is 3 gems tall }

  { Check if hit bottom }
  if GridY >= PlayfieldRows then
  begin
    HasStackLanded := True;
    Exit;
  end;

  { Check if hit existing gem }
  if Playfield.Tiles[Stack.X, GridY + 1] <> Gem_Empty then
  begin
    HasStackLanded := True;
    Exit;
  end;

  HasStackLanded := False;
end;

procedure SnapStackToGrid(var Stack: TGemStack);
begin
  { Snap Y position to grid }
  Stack.Y := PlayfieldY + ((Stack.Y - PlayfieldY) div TileSize) * TileSize;
end;
```

---

### Stack Landing and Placement

```pascal
procedure LandStack;
var
  i: Integer;
  GridY: Integer;
  R: TRectangle;
  ClipOffset: Integer;
begin
  { --- FIX: Clear the LAST RENDERED position, not the current internal position --- }
  { This is critical because CurrentStack.PixelY may have been snapped/adjusted }
  { during collision detection, but LastStackY holds where it was ACTUALLY drawn }

  R.X := LastStackX;
  R.Y := Trunc(LastStackY) + PlayfieldY;
  R.Width := TileSize;
  R.Height := TileSize * 3;

  { Apply Clipping (Safety for top of screen) }
  if R.Y < 0 then
  begin
    ClipOffset := -R.Y;
    R.Y := 0;
    R.Height := R.Height - ClipOffset;
  end;

  { Restore background over the old visual artifact }
  if R.Height > 0 then
  begin
    CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);
    AddDirtyRect(R);
  end;

  { --- Logic to place gems in grid --- }

  { Convert the SNAPPED pixel Y to grid Y }
  GridY := Trunc(CurrentStack.PixelY) div TileSize;

  { Place gems on playfield }
  for i := 0 to 2 do
  begin
    if (GridY + i >= 0) and (GridY + i < PlayfieldRows) then
    begin
      Playfield.Tiles[CurrentStack.GridX, GridY + i] := CurrentStack.Gems[i];
      Playfield.TileChanged[CurrentStack.GridX, GridY + i] := True;
    end;
  end;

  { Deactivate stack and spawn new one }
  CurrentStack.Active := False;
  SpawnNewStack;
end;
```

**Critical fixes in LandStack:**

1. **Clear last rendered position:** When landing, we must clear where the stack was **visually drawn** on the last frame (`LastStackX`, `LastStackY`), NOT where the internal physics position is (`CurrentStack.PixelY`). The physics position may have been snapped back during collision detection.

2. **Same clipping logic:** Apply the same off-screen clipping as `RenderStack` to handle stacks that are partially above the playfield.

3. **Use snapped position for grid placement:** Use the current (snapped) `CurrentStack.PixelY` to calculate `GridY` for placing gems on the playfield grid.

---

### Stack Rotation

```pascal
procedure RotateStackUp(var Stack: TGemStack);
var
  Temp: TGemColor;
  R: TRectangle;
begin
  { Rotate: Bottom → Middle → Top → Bottom }
  Temp := Stack.Gems[2];  { Save bottom }
  Stack.Gems[2] := Stack.Gems[1];  { Middle → Bottom }
  Stack.Gems[1] := Stack.Gems[0];  { Top → Middle }
  Stack.Gems[0] := Temp;           { Bottom → Top }

  SoundBank.PlaySound(SoundIDs.GemRotate);
  R.X := Stack.PixelX;
  R.Y := Stack.Y;
  R.Width := 16;
  R.Height := 48;
  AddDirtyRect(R);
end;

procedure RotateStackDown(var Stack: TGemStack);
var
  Temp: TGemColor;
  R: TRectangle;
begin
  { Rotate: Top → Middle → Bottom → Top }
  Temp := Stack.Gems[0];  { Save top }
  Stack.Gems[0] := Stack.Gems[1];  { Middle → Top }
  Stack.Gems[1] := Stack.Gems[2];  { Bottom → Middle }
  Stack.Gems[2] := Temp;           { Top → Bottom }

  SoundBank.PlaySound(SoundIDs.GemRotate);
  R.X := Stack.PixelX;
  R.Y := Stack.Y;
  R.Width := 16;
  R.Height := 48;
  AddDirtyRect(R);
end;
```

---

### Gem Generation & Stack Spawning

```pascal
function GetColorCountForDifficulty(Difficulty: TDifficulty): Integer;
begin
  case Difficulty of
    Difficulty_Novice:  GetColorCountForDifficulty := NoviceColorCount;
    Difficulty_Amateur: GetColorCountForDifficulty := AmateurColorCount;
    Difficulty_Pro:     GetColorCountForDifficulty := ProColorCount;
  end;
end;

function RandomGemColor(Difficulty: TDifficulty): TGemColor;
var
  ColorCount: Integer;
  ColorIndex: Integer;
  ColorMap: array[0..5] of TGemColor;
begin
  { Setup color map based on difficulty }
  ColorMap[0] := Gem_Red;
  ColorMap[1] := Gem_Green;
  ColorMap[2] := Gem_Blue;
  ColorMap[3] := Gem_Yellow;
  ColorMap[4] := Gem_Pink;     { Available in Amateur+ }
  ColorMap[5] := Gem_Purple;   { Available in Pro only }

  ColorCount := GetColorCountForDifficulty(Difficulty);
  ColorIndex := Random(ColorCount);
  RandomGemColor := ColorMap[ColorIndex];
end;

procedure SpawnNewStack(var Stack: TGemStack; Difficulty: TDifficulty;
                        var GuaranteeMagicJewel: Boolean);
var
  i: Integer;
  UseMagicJewel: Boolean;
  MagicJewelPos: Integer;
begin
  { Check for guaranteed Magic Jewel (from combo) }
  if GuaranteeMagicJewel then
  begin
    UseMagicJewel := True;
    GuaranteeMagicJewel := False;  { Reset flag }
  end
  else
  begin
    { Randomly determine if this stack gets a Magic Jewel }
    UseMagicJewel := (Random(100) < MagicJewelChance);
  end;

  if UseMagicJewel then
  begin
    { Pick random position for Magic Jewel (0-2) }
    MagicJewelPos := Random(3);

    { Fill stack with random gems }
    for i := 0 to 2 do
    begin
      if i = MagicJewelPos then
        Stack.Gems[i] := Gem_MagicJewel
      else
        Stack.Gems[i] := RandomGemColor(Difficulty);
    end;
  end
  else
  begin
    { Normal stack - all random colored gems }
    for i := 0 to 2 do
      Stack.Gems[i] := RandomGemColor(Difficulty);
  end;

  { Initialize stack position }
  Stack.X := PlayfieldCols div 2;  { Center column }
  Stack.Y := PlayfieldY - 48;      { Above playfield }
  Stack.PixelX := PlayfieldX + Stack.X * TileSize;
  Stack.Active := True;
end;
```

**Key points:**
- Difficulty determines available color pool (4, 5, or 6 colors)
- Magic Jewel has 3% random spawn chance (~3 in 100 stacks)
- Magic Jewel is **guaranteed** after achieving a 3-match combo
- Magic Jewel replaces one random gem in the stack
- Random number generator should be seeded on game start
- Combo counter tracks consecutive/simultaneous match eliminations

---

### Match Detection

```pascal
type
  TMatchList = record
    Positions: array[0..59] of record X, Y: Integer; end;
    Count: Integer;
  end;

function FindMatches: TMatchList;
var
  Matches: TMatchList;
  X, Y, DX, DY: Integer;
  Directions: array[0..3] of record DX, DY: Integer; end;
begin
  { Check 4 directions: Horizontal, Vertical, Diagonal× }
  Directions[0].DX := 1;  Directions[0].DY := 0;   { Horizontal }
  Directions[1].DX := 0;  Directions[1].DY := 1;   { Vertical }
  Directions[2].DX := 1;  Directions[2].DY := 1;   { Diagonal ↘ }
  Directions[3].DX := 1;  Directions[3].DY := -1;  { Diagonal ↗ }

  Matches.Count := 0;

  for Y := 0 to PlayfieldRows - 1 do
  begin
    for X := 0 to PlayfieldCols - 1 do
    begin
      if Playfield.Tiles[X, Y] = Gem_Empty then Continue;
      if Playfield.Tiles[X, Y] = Gem_MagicJewel then Continue;

      { Check each direction }
      for DirIdx := 0 to 3 do
      begin
        MatchLen := CountMatchInDirection(
          X, Y,
          Directions[DirIdx].DX,
          Directions[DirIdx].DY
        );

        if MatchLen >= MinMatchLength then
          AddMatchToList(Matches, X, Y, DirIdx, MatchLen);
      end;
    end;
  end;

  FindMatches := Matches;
end;

function CountMatchInDirection(X, Y, DX, DY: Integer): Integer;
var
  Count: Integer;
  Color: TGemColor;
  CheckX, CheckY: Integer;
begin
  Color := Playfield.Tiles[X, Y];
  Count := 1;  { Count starting gem }

  CheckX := X + DX;
  CheckY := Y + DY;

  while (CheckX >= 0) and (CheckX < PlayfieldCols) and
        (CheckY >= 0) and (CheckY < PlayfieldRows) and
        (Playfield.Tiles[CheckX, CheckY] = Color) do
  begin
    Inc(Count);
    Inc(CheckX, DX);
    Inc(CheckY, DY);
  end;

  CountMatchInDirection := Count;
end;
```

---

### Gem Removal and Gravity

```pascal
procedure RemoveMatches(const Matches: TMatchList; var ComboCount: Integer;
                        var GuaranteeMagicJewel: Boolean);
var
  i, X, Y: Integer;
  R: TRectangle;
  SetCount: Integer;
begin
  if Matches.Count = 0 then Exit;

  { Count number of separate match sets (groups of 3+) }
  SetCount := CountMatchSets(Matches);

  { Increment combo counter }
  Inc(ComboCount);

  { Remove matched gems }
  for i := 0 to Matches.Count - 1 do
  begin
    X := Matches.Positions[i].X;
    Y := Matches.Positions[i].Y;

    Playfield.Tiles[X, Y] := Gem_Empty;
    Playfield.TileChanged[X, Y] := True;
    R.X := PlayfieldX + X * TileSize;
    R.Y := PlayfieldY + Y * TileSize;
    R.Width := TileSize;
    R.Height := TileSize;
    AddDirtyRect(R);
  end;

  { Update score (with combo multiplier) }
  Score := Score + (Matches.Count * PointsPerGem * ComboCount);

  { Check for Magic Jewel unlock (3 or more combos) }
  if ComboCount >= 3 then
  begin
    GuaranteeMagicJewel := True;
    { Optional: Display "MAGIC JEWEL UNLOCKED!" message }
  end;

  { Play match sound }
  SoundBank.PlaySound(SoundIDs.GemMatch);

  { Apply gravity (may trigger more matches) }
  ApplyGravity;
end;

procedure ApplyGravity;
var
  X, Y, CheckY: Integer;
  Moved: Boolean;
begin
  repeat
    Moved := False;

    { Scan bottom to top }
    for Y := PlayfieldRows - 1 downto 1 do
    begin
      for X := 0 to PlayfieldCols - 1 do
      begin
        { If gem above empty space, move down }
        if (Playfield.Tiles[X, Y] = Gem_Empty) and
           (Playfield.Tiles[X, Y - 1] <> Gem_Empty) then
        begin
          Playfield.Tiles[X, Y] := Playfield.Tiles[X, Y - 1];
          Playfield.Tiles[X, Y - 1] := Gem_Empty;

          Playfield.TileChanged[X, Y] := True;
          Playfield.TileChanged[X, Y - 1] := True;

          Moved := True;
        end;
      end;
    end;
  until not Moved;

  { Check for new matches after gravity }
  CheckForMatches;
end;

function CountMatchSets(const Matches: TMatchList): Integer;
var
  i: Integer;
  { Implementation counts unique match groups }
  { For simplicity, can estimate based on match count }
begin
  { Simplified: assume each 3 gems = 1 set }
  { More accurate implementation would track unique groups }
  CountMatchSets := (Matches.Count + 2) div 3;
end;
```

---

### Combo System

The combo system tracks consecutive or simultaneous matches and rewards players with a guaranteed Magic Jewel after achieving 3 combos.

```pascal
{ Called when a new stack is placed }
procedure PlaceStackOnPlayfield(var Stack: TGemStack);
var
  i, GridY: Integer;
begin
  { Calculate grid row for bottom gem }
  GridY := (Stack.Y - PlayfieldY) div TileSize + 2;

  { Place each gem on the playfield (bottom to top) }
  for i := 2 downto 0 do
  begin
    if GridY - (2 - i) >= 0 then
    begin
      Playfield.Tiles[Stack.X, GridY - (2 - i)] := Stack.Gems[i];
      Playfield.TileChanged[Stack.X, GridY - (2 - i)] := True;
    end;
  end;

  { IMPORTANT: Reset combo counter when new stack is placed }
  { This ensures combos only count consecutive chain reactions }
  ComboCount := 0;

  { Check for Magic Jewels and activate them }
  ActivateMagicJewels;

  { Then check for normal matches (this will increment ComboCount) }
  CheckForMatches;
end;
```

**Combo counting logic:**
- ComboCount is reset to 0 when a new stack is placed
- Each match removal increments ComboCount by 1
- Gravity can trigger additional matches (chain reactions)
- If ComboCount reaches 3 or more, set GuaranteeMagicJewel flag
- Next spawned stack will have a Magic Jewel guaranteed
- Combo multiplier increases score for each consecutive match

**Example combo sequence:**
1. Player places stack → ComboCount = 0
2. First match detected and removed → ComboCount = 1
3. Gems fall, second match detected → ComboCount = 2
4. Gems fall, third match detected → ComboCount = 3, GuaranteeMagicJewel = True
5. Next stack spawned with guaranteed Magic Jewel

---

### Magic Jewel Activation

When a stack is placed on the playfield, Magic Jewels are detected and activated (see PlaceStackOnPlayfield in Combo System section above).

```pascal
procedure ActivateMagicJewels;
var
  X, Y, ScanX, ScanY: Integer;
  TargetColor: TGemColor;
  GemsRemoved: Integer;
  R: TRectangle;
begin
  { Scan playfield for Magic Jewels }
  for Y := 0 to PlayfieldRows - 1 do
  begin
    for X := 0 to PlayfieldCols - 1 do
    begin
      if Playfield.Tiles[X, Y] = Gem_MagicJewel then
      begin
        { Determine which color to eliminate }
        { Use the color of the tile the Magic Jewel landed on }
        { This is the previous color before the jewel replaced it }
        { Alternative: Use color of adjacent gem (implementation choice) }

        { For simplicity: eliminate random color on playfield }
        TargetColor := FindMostCommonColor;

        if TargetColor <> Gem_Empty then
        begin
          GemsRemoved := 0;

          { Remove all gems of target color }
          for ScanY := 0 to PlayfieldRows - 1 do
          begin
            for ScanX := 0 to PlayfieldCols - 1 do
            begin
              if Playfield.Tiles[ScanX, ScanY] = TargetColor then
              begin
                Playfield.Tiles[ScanX, ScanY] := Gem_Empty;
                Playfield.TileChanged[ScanX, ScanY] := True;
                R.X := PlayfieldX + ScanX * TileSize;
                R.Y := PlayfieldY + ScanY * TileSize;
                R.Width := TileSize;
                R.Height := TileSize;
                AddDirtyRect(R);
                Inc(GemsRemoved);
              end;
            end;
          end;

          { Remove the Magic Jewel itself }
          Playfield.Tiles[X, Y] := Gem_Empty;
          Playfield.TileChanged[X, Y] := True;

          { Update score }
          Score := Score + MagicJewelBonus + (GemsRemoved * PointsPerGem);

          { Play special sound }
          SoundBank.PlaySound(SoundIDs.MagicJewel);

          { Apply gravity after removal }
          ApplyGravity;
        end;
      end;
    end;
  end;
end;

function FindMostCommonColor: TGemColor;
var
  X, Y: Integer;
  ColorCounts: array[TGemColor] of Integer;
  Color: TGemColor;
  MaxCount: Integer;
  MostCommon: TGemColor;
begin
  { Count occurrences of each color }
  for Color := Gem_Red to Gem_Purple do
    ColorCounts[Color] := 0;

  for Y := 0 to PlayfieldRows - 1 do
  begin
    for X := 0 to PlayfieldCols - 1 do
    begin
      Color := Playfield.Tiles[X, Y];
      if (Color <> Gem_Empty) and (Color <> Gem_MagicJewel) then
        Inc(ColorCounts[Color]);
    end;
  end;

  { Find color with highest count }
  MaxCount := 0;
  MostCommon := Gem_Empty;
  for Color := Gem_Red to Gem_Purple do
  begin
    if ColorCounts[Color] > MaxCount then
    begin
      MaxCount := ColorCounts[Color];
      MostCommon := Color;
    end;
  end;

  FindMostCommonColor := MostCommon;
end;
```

**Magic Jewel activation:**
- Activates immediately when stack lands (before normal match detection)
- Finds most common color on playfield
- Removes all gems of that color
- Awards bonus points (MagicJewelBonus + cleared gems)
- Triggers gravity, which may create chain reactions
- Plays special sound effect

---

## Input System

### Input Mapping

```pascal
procedure HandleStackInput;
var
  NewX: Integer;
  GridY: Integer;
  PixelOffset: Integer;
  CanMove: Boolean;
begin
  if not CurrentStack.Active then Exit;

  GridY := Trunc(CurrentStack.PixelY) div TileSize;

  { Calculate how deep we are into the current tile }
  PixelOffset := Trunc(CurrentStack.PixelY) mod TileSize;

  { --- Left Movement --- }
  if IsKeyPressed(Key_Left) then
  begin
    NewX := CurrentStack.GridX - 1;

    { 1. Check if the stack fits in the new column at the current Grid Y }
    CanMove := not CheckStackCollision(NewX, GridY);

    { 2. CRITICAL: If we are partially fallen into the next row, we must also check }
    {    if the stack fits one row lower in the new column. }
    {    Without this, the stack can move horizontally "through" gems when dangling. }
    if CanMove and (PixelOffset > 0) then
    begin
      if CheckStackCollision(NewX, GridY + 1) then
        CanMove := False;
    end;

    if CanMove then
    begin
      CurrentStack.GridX := NewX;
      CurrentStack.PixelX := PlayfieldX + (CurrentStack.GridX * TileSize);
    end;
  end;

  { --- Right Movement --- }
  if IsKeyPressed(Key_Right) then
  begin
    NewX := CurrentStack.GridX + 1;

    { 1. Check main position }
    CanMove := not CheckStackCollision(NewX, GridY);

    { 2. Check 'dangling' position if not grid aligned }
    if CanMove and (PixelOffset > 0) then
    begin
      if CheckStackCollision(NewX, GridY + 1) then
        CanMove := False;
    end;

    if CanMove then
    begin
      CurrentStack.GridX := NewX;
      CurrentStack.PixelX := PlayfieldX + (CurrentStack.GridX * TileSize);
    end;
  end;

  { Rotation (single-tap) }
  if IsKeyPressed(Key_Space) then
    RotateStack(CurrentStack);

  { Fast fall }
  if IsKeyDown(Key_Down) then
    CurrentStack.FallSpeed := FastFallSpeed
  else
    CurrentStack.FallSpeed := InitialFallSpeed;

  { Pause }
  if IsKeyPressed(Key_Escape) then
  begin
    CurrentMode := Mode_Paused;
    Music.Fade;
  end;
end;
```

**Key insight - Dangling Stack Collision:**

When a stack is falling with smooth pixel-by-pixel movement, it's often not perfectly aligned to the grid. When `PixelOffset > 0` (meaning the stack has fallen partially into the next row), the visual representation of the 3-gem stack is "dangling" into `GridY + 1`.

**The problem:** If you only check collision at `GridY`, the stack can move horizontally even when the bottom gems would visually overlap with gems in row `GridY + 1`.

**The solution:** Always check collision at **both** `GridY` AND `GridY + 1` when `PixelOffset > 0`. This ensures the stack can only move horizontally when the entire visual representation (including the dangling portion) is clear.

---

## Audio System

### Music State Management

```pascal
type
  TMusicTrack = (
    Music_Menu,
    Music_Game1,
    Music_Game2
  );

var
  CurrentTrack: TMusicTrack;
  MusicEnabled: Boolean;

procedure PlayMusic(Track: TMusicTrack);
const
  MusicFiles: array[TMusicTrack] of string = (
    'MUSIC\INTRO.HSC',
    'MUSIC\ADTHELIB.HSC',
    'MUSIC\TECHNO.HSC'
  );
begin
  if not MusicEnabled then Exit;

  Music.Stop;
  if Music.LoadFile(MusicFiles[Track]) then
  begin
    Music.Start;
    CurrentTrack := Track;
  end;
end;

{ Switch music based on level }
procedure UpdateMusic;
begin
  if Level < 5 then
  begin
    if CurrentTrack <> Music_Game1 then
      PlayMusic(Music_Game1);
  end
  else
  begin
    if CurrentTrack <> Music_Game2 then
      PlayMusic(Music_Game2);
  end;
end;
```

---

### Sound Effect Timing

```pascal
{ Don't play sounds in tight loops! }
procedure CheckForMatches;
var
  Matches: TMatchList;
begin
  Matches := FindMatches;

  if Matches.Count > 0 then
  begin
    RemoveMatches(Matches);

    { Play sound ONCE per match sequence }
    if not Playing then  { Check SBDSP global flag }
      SoundBank.PlaySound(SoundIDs.GemMatch);
  end;
end;
```

---

## Asset Requirements

### Graphics Assets

**Gem Sprite Sheet (GEMS1.PKM)**
```
16×16 tiles, 8 gem types

Layout:
[Empty][Red][Yellow][Green][Blue][Pink][Purple][MagicJewel]
  0      1     2       3      4     5       6        7

Difficulty usage:
- Novice:  Uses tiles 0-5 (Red, Yellow, Green, Blue)
- Amateur: Uses tiles 0-6 (+ Pink)
- Pro:     Uses tiles 0-7 (+ Purple)
- Magic Jewel (tile 7): Multi-colored/rainbow appearance, used in all difficulties

Total size: 128×16 pixels (8 tiles)
Palette: 256 colors (can share with background)
```

**Background (BG1.PKM)**
```
320×200 pixels
- Playfield border/grid
- Decorative elements
- HUD background
- Next gem preview area
```

**Title Screen (TITLE.PKM)**
```
320×200 pixels
- Game logo
- Copyright info
- Background art
```

**Fonts**
```
- LG-FONT.XML, LG-FONT.PKM
  Large bitmap font for titles and scores

- SM-FONT.XML, SM-FONT.PKM
  Small bitmap font for HUD and general text
```

---

### Audio Assets

**Music (HSC format)**
```
MUSIC\INTRO.HSC    - Title/menu music (calm, inviting)
MUSIC\ADTHELIB.HSC - Gameplay music (medium tempo)
MUSIC\TECHNO.HSC   - Gameplay music (fast tempo, higher levels)
```

**Sound Effects (VOC format)**
```
SOUNDS\STEP.VOC   - Menu cursor move (short beep, ~0.1s)
SOUNDS\ENTER.VOC  - Menu confirm (upward chime, ~0.3s)
SOUNDS\FALL.VOC   - Gem lands (thud, ~0.2s)
SOUNDS\ROTATE.VOC - Stack rotates (click, ~0.1s)
SOUNDS\MATCH.VOC  - Gems matched (sparkle/explosion, ~0.5s)
SOUNDS\MAGIC.VOC  - Magic Jewel activates (magical chime/whoosh, ~0.7s)

Sample rate: 11025 Hz (standard)
Format: 8-bit mono PCM
```

---

## Performance Considerations

### 286 Optimization Checklist

**✅ DO:**
- Use `CopyFrameBufferRect` for selective redraw
- Mark only changed regions dirty
- Pre-render static backgrounds
- Use fixed-point math (avoid Real when possible)
- Cache frequently used calculations
- Use delta timing for smooth animation

**❌ DON'T:**
- Call `RenderFrameBuffer` every frame
- Redraw entire playfield when only 1 tile changed
- Use floating-point in game loop (use LongInt ms timing)
- Copy large memory blocks unnecessarily
- Allocate/free memory in game loop

---

### Memory Budget

```
Conventional Memory (640KB):
- Program code: ~50KB
- Framebuffer (BackBuffer): 64KB
- Background buffer: 64KB
- Sprite data (GEMS1.PKM): ~1KB
- Sound playback buffer: ~8KB (largest sound)
- Music data (HSC): ~10KB
- XMS sounds: Stored in extended memory
- Free: ~440KB (plenty!)

Extended Memory (XMS):
- Sound bank: ~50KB (5 sounds × ~10KB each)
```

---

### Frame Budget (30 FPS = 33ms)

```
Target breakdown per frame:
- Input processing: 1ms
- Game logic: 5ms
- Match detection: 3ms
- Rendering (selective): 5ms
- CopyFrameBufferRect calls: 10ms
- HSC music polling: 1ms
- Misc overhead: 8ms
Total: 33ms ✓

Worst case (full playfield redraw):
- 60 tiles × 256 bytes = 15360 bytes
- Copy time on 286: ~24ms
- Still within budget!
```

---

## Implementation Phases

### Phase 1: Core Engine (Week 1)

**Goals:**
- Initialize VGA, keyboard, timer
- Implement selective redraw system
- Test `CopyFrameBufferRect` performance
- Create debug FPS counter

**Deliverables:**
- Basic game loop running at 60 FPS on 286
- Dirty rect system working

---

### Phase 2: Playfield & Rendering (Week 2)

**Goals:**
- Load gem sprites (GEMS1.PKM)
- Draw playfield grid
- Implement tile rendering with dirty rects
- Add HUD text rendering

**Deliverables:**
- Static playfield displaying correctly
- HUD showing dummy score/level

---

### Phase 3: Falling Stack (Week 3)

**Goals:**
- Implement smooth pixel-by-pixel falling
- Add keyboard input (left/right/rotate)
- Collision detection with playfield
- Stack landing and placement

**Deliverables:**
- Falling stack with full player control
- Stack lands correctly on playfield

---

### Phase 4: Game Logic (Week 4)

**Goals:**
- Match detection (horizontal/vertical/diagonal)
- Gem removal animation
- Gravity system (gems fall down)
- Scoring system

**Deliverables:**
- Playable game with match detection
- Score updates correctly

---

### Phase 5: Audio Integration (Week 5)

**Goals:**
- Initialize SBDSP + SndBank
- Load all sound effects
- Integrate HSC music player
- Add music polling to game loop

**Deliverables:**
- All sounds playing correctly
- Music plays without conflicts

---

### Phase 6: Polish & Menus (Week 6)

**Goals:**
- Title screen with music
- Menu system with navigation
- Pause screen
- Game over screen
- Level progression

**Deliverables:**
- Complete game flow
- All states working

---

### Phase 7: Testing & Optimization (Week 7)

**Goals:**
- Test on real 286 hardware (or DOSBox 286 mode)
- Profile performance bottlenecks
- Optimize dirty rect system
- Balance difficulty curve

**Deliverables:**
- Game running smoothly on 286
- 30+ FPS maintained

---

## Success Metrics

**Performance:**
- ✅ 30 FPS minimum on 286 (12 MHz)
- ✅ 60 FPS target on 386+
- ✅ No screen tearing (selective redraw)
- ✅ Smooth falling animation

**Gameplay:**
- ✅ Responsive controls (< 50ms input lag)
- ✅ Fair difficulty progression
- ✅ Clear visual feedback
- ✅ Satisfying audio feedback

**Code Quality:**
- ✅ Clean separation of concerns
- ✅ Efficient memory usage
- ✅ Proper cleanup (no memory leaks)
- ✅ No interrupt conflicts

---

## Conclusion

This design leverages the DOS engine's strengths (XMS sound bank, HSC music, selective rendering) while working within 286 constraints. The key innovation is the **dirty rectangle system** using `CopyFrameBufferRect`, which enables 60 FPS performance on slow CPUs by only updating changed screen regions.

**Core engine features used:**
- ✅ VGA.PAS - Selective rendering with CopyFrameBufferRect
- ✅ PKMLoad - Sprite and background loading
- ✅ Keyboard - Responsive input handling
- ✅ RTCTimer - Delta-time smooth animation
- ✅ PlayHSC - Background music (3 tracks)
- ✅ SndBank + SBDSP - Sound effects (5 sounds)
- ✅ VGAPrint - HUD text rendering

**Ready to implement!** 🎮✨
