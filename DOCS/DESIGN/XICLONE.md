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
- **5 columns × 12 rows** (5×12 grid)
- **Tile size:** 16×16 pixels (from CONFIG.PAS TileSize constant)
- **Playfield area:** 80×192 pixels (5×16 × 12×16)

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
- `GEMS.PKM` - Gem sprite sheet (16×16 tiles)
- `BACKGROUND.PKM` - Static playfield background
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
Music.LoadFile('MUSIC\GAME1.HSC');
Music.Start;
Music.Poll;  { Call regularly in game loop }

{ Cleanup }
Music.Done;  { CRITICAL: Unhook IRQ0 before exit }
```

**Music tracks:**
1. `MENU.HSC` - Title screen music
2. `GAME1.HSC` - Gameplay music (track 1)
3. `GAME2.HSC` - Gameplay music (track 2, faster tempo)

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
│ 5×12   │               │
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
    for X := 0 to 4 do
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
procedure UpdateFallingStack;
var
  R: TRectangle;
begin
  { Clear old position }
  DrawBackground(OldStackX, OldStackY, 16, 48, BackBuffer);
  R.X := OldStackX;
  R.Y := OldStackY;
  R.Width := 16;
  R.Height := 48;
  AddDirtyRect(R);

  { Draw new position }
  DrawStack(StackX, StackY, BackBuffer);
  R.X := StackX;
  R.Y := StackY;
  R.Width := 16;
  R.Height := 48;
  AddDirtyRect(R);
end;
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
  - Playfield: 5×16×16 = 1280 bytes (average 2 tiles changed)
  - Stack: 16×48 = 768 bytes (every frame)
  - Total: ~2850 bytes = 4.4ms (227 FPS!)

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

## Game Architecture

### Core Data Structures

```pascal
type
  TGemColor = (
    Gem_Empty,
    Gem_Red,
    Gem_Blue,
    Gem_Green,
    Gem_Yellow,
    Gem_Purple,
    Gem_Cyan
  );

  TGemStack = record
    Gems: array[0..2] of TGemColor;  { Top, Middle, Bottom }
    X: Integer;         { Grid column (0-4) }
    Y: Integer;         { Pixel Y position (smooth falling) }
    PixelX: Integer;    { Pixel X position (for rendering) }
    FallSpeed: Integer; { Pixels per second }
    Active: Boolean;    { Is stack currently falling? }
  end;

  TPlayfield = record
    Tiles: array[0..4, 0..11] of TGemColor;  { 5×12 grid }
    TileChanged: array[0..4, 0..11] of Boolean;
  end;

  TGameState = record
    Playfield: TPlayfield;
    CurrentStack: TGemStack;
    NextStack: TGemStack;  { Preview }
    Score: LongInt;
    Level: Integer;
    GameOver: Boolean;
  end;
```

---

### Constants

```pascal
const
  { Playfield dimensions }
  PlayfieldCols = 5;
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

  { Scoring }
  PointsPerGem = 10;
  BonusMultiplier = 2;     { For chains/combos }
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
- HSC music playing (`MENU.HSC`)

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
  OldY: Integer;
  PixelsFallen: Integer;
  R: TRectangle;
begin
  if not CurrentStack.Active then Exit;

  OldY := CurrentStack.Y;

  { Calculate pixels to fall this frame }
  if IsKeyDown(Key_Down) or IsKeyDown(Key_Space) then
    PixelsFallen := (FastFallSpeed * DeltaTimeMS) div 1000
  else
    PixelsFallen := (CurrentStack.FallSpeed * DeltaTimeMS) div 1000;

  { Update Y position }
  CurrentStack.Y := CurrentStack.Y + PixelsFallen;

  { Check for landing }
  if HasStackLanded(CurrentStack) then
  begin
    SnapStackToGrid(CurrentStack);
    PlaceStackOnPlayfield(CurrentStack);
    SoundBank.PlaySound(SoundIDs.GemFall);
    CheckForMatches;
    SpawnNewStack;
  end;

  { Mark dirty rect if position changed }
  if CurrentStack.Y <> OldY then
  begin
    R.X := CurrentStack.PixelX;
    R.Y := OldY;
    R.Width := 16;
    R.Height := 48;
    AddDirtyRect(R);  { Old position }

    R.Y := CurrentStack.Y;
    AddDirtyRect(R);  { New position }
  end;
end;
```

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
procedure RemoveMatches(const Matches: TMatchList);
var
  i, X, Y: Integer;
  R: TRectangle;
begin
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

  { Update score }
  Score := Score + Matches.Count * PointsPerGem;

  { Play match sound }
  SoundBank.PlaySound(SoundIDs.GemMatch);

  { Apply gravity }
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
```

---

## Input System

### Input Mapping

```pascal
procedure ProcessInput;
var
  R: TRectangle;
begin
  { Horizontal movement (continuous) }
  if IsKeyDown(Key_Left) then
  begin
    if CanMoveLeft(CurrentStack) then
    begin
      MoveStackLeft(CurrentStack);
      R.X := OldStackX;
      R.Y := StackY;
      R.Width := 16;
      R.Height := 48;
      AddDirtyRect(R);
      R.X := StackX;
      AddDirtyRect(R);
    end;
  end;

  if IsKeyDown(Key_Right) then
  begin
    if CanMoveRight(CurrentStack) then
      MoveStackRight(CurrentStack);
  end;

  { Rotation (single-tap) }
  if IsKeyPressed(Key_Up) then
    RotateStackUp(CurrentStack);

  if IsKeyPressed(Key_Down) then
    RotateStackDown(CurrentStack);

  { Hard drop }
  if IsKeyPressed(Key_Space) then
    CurrentStack.FallSpeed := FastFallSpeed;

  { Pause }
  if IsKeyPressed(Key_Escape) then
  begin
    CurrentMode := Mode_Paused;
    Music.Fade;
  end;
end;
```

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
    'MUSIC\MENU.HSC',
    'MUSIC\GAME1.HSC',
    'MUSIC\GAME2.HSC'
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

**Gem Sprite Sheet (GEMS.PKM)**
```
16×16 tiles, 7 gems + empty

Layout:
[Empty][Red][Blue][Green][Yellow][Purple][Cyan][...]
  0      1     2     3      4       5       6

Total size: 128×16 pixels (8 tiles)
Palette: 256 colors (can share with background)
```

**Background (BACKGROUND.PKM)**
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

---

### Audio Assets

**Music (HSC format)**
```
MUSIC\MENU.HSC    - Title/menu music (calm, inviting)
MUSIC\GAME1.HSC   - Gameplay music (medium tempo)
MUSIC\GAME2.HSC   - Gameplay music (fast tempo, higher levels)
```

**Sound Effects (VOC format)**
```
SOUNDS\STEP.VOC   - Menu cursor move (short beep, ~0.1s)
SOUNDS\ENTER.VOC  - Menu confirm (upward chime, ~0.3s)
SOUNDS\FALL.VOC   - Gem lands (thud, ~0.2s)
SOUNDS\ROTATE.VOC - Stack rotates (click, ~0.1s)
SOUNDS\MATCH.VOC  - Gems matched (sparkle/explosion, ~0.5s)

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
- Sprite data (GEMS.PKM): ~1KB
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
- Load gem sprites (GEMS.PKM)
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
