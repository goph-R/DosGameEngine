# SPRITE.PAS - API Documentation

Delta-time sprite animation system for VGA Mode 13h.

## Table of Contents

- [Overview](#overview)
- [Types](#types)
- [Constants](#constants)
- [Functions](#functions)
- [Common Usage Patterns](#common-usage-patterns)
- [Animation Timing](#animation-timing)
- [Important Notes](#important-notes)

---

## Overview

SPRITE.PAS provides a frame-rate independent sprite animation system using delta-time updates. This approach ensures smooth animation regardless of CPU speed or frame rate.

**Key Features:**
- **Delta-time based** - Frame-rate independent animation
- **Three play modes** - Forward loop, ping-pong, and play-once
- **Sprite sheet support** - Multiple animations from single image
- **Flipping support** - Horizontal/vertical mirroring
- **Shared sprite data** - Multiple instances from one definition
- **Millisecond timing** - Precise animation control

**Architecture:**
- **TSprite** - Shared sprite definition (frames, timing, play mode)
- **TSpriteInstance** - Per-entity state (position, flip, current time)

---

## Types

### TSprite

```pascal
type
  TSprite = record
    Image: PImage;                              { Pointer to sprite sheet }
    Frames: array[0..63] of TRectangle;         { Frame rectangles }
    FrameCount: Byte;                           { Number of frames }
    Width: Word;                                { Frame width (informational) }
    Height: Word;                               { Frame height (informational) }
    Duration: LongInt;                          { Total duration in milliseconds }
    PlayType: Byte;                             { Forward/PingPong/Once }
  end;

  PSprite = ^TSprite;
```

Sprite definition containing shared animation data. Multiple instances can reference the same TSprite.

**Fields:**

- `Image` - Pointer to sprite sheet TImage (shared by all instances)
- `Frames` - Array of frame rectangles within sprite sheet
- `FrameCount` - Number of frames in animation (1-64)
- `Width` - Frame width in pixels (optional, for convenience)
- `Height` - Frame height in pixels (optional, for convenience)
- `Duration` - Total animation duration in milliseconds
- `PlayType` - Animation playback mode (see [Constants](#constants))

**Example:**
```pascal
var
  SpriteSheet: TImage;
  PlayerRun: TSprite;

begin
  { Load sprite sheet }
  LoadPKM('PLAYER.PKM', SpriteSheet);

  { Setup sprite definition }
  PlayerRun.Image := @SpriteSheet;
  PlayerRun.FrameCount := 8;
  PlayerRun.Duration := 800;  { 0.8 seconds total }
  PlayerRun.PlayType := SpritePlayType_Forward;

  { Define frame rectangles (8 frames, 32×32 each, in a row) }
  for i := 0 to 7 do
  begin
    PlayerRun.Frames[i].X := i * 32;
    PlayerRun.Frames[i].Y := 0;
    PlayerRun.Frames[i].Width := 32;
    PlayerRun.Frames[i].Height := 32;
  end;
end;
```

---

### TSpriteInstance

```pascal
type
  TSpriteInstance = record
    Sprite: PSprite;         { Pointer to sprite definition }
    Hidden: Boolean;         { If True, DrawSprite does nothing }
    X: Integer;              { Screen X position }
    Y: Integer;              { Screen Y position }
    FlipX: Boolean;          { Horizontal flip }
    FlipY: Boolean;          { Vertical flip }
    CurrentTime: LongInt;    { Current time in milliseconds }
    PlayBackward: Boolean;   { Internal: PingPong direction }
  end;

  PSpriteInstance = ^TSpriteInstance;
```

Per-entity sprite instance containing position, state, and animation time.

**Fields:**

- `Sprite` - Pointer to TSprite definition (shared data)
- `Hidden` - If `True`, sprite is not drawn
- `X`, `Y` - Screen position (top-left corner)
- `FlipX` - If `True`, flip horizontally (mirror left-right)
- `FlipY` - If `True`, flip vertically (mirror top-bottom)
- `CurrentTime` - Current animation time in milliseconds
  - `-1` = Animation stopped (PlayType_Once finished)
  - `0+` = Active animation time
- `PlayBackward` - Internal flag for PingPong mode direction

**Example:**
```pascal
var
  Player: TSpriteInstance;

begin
  { Create instance from sprite definition }
  Player.Sprite := @PlayerRun;
  Player.X := 100;
  Player.Y := 50;
  Player.FlipX := False;  { Facing right }
  Player.FlipY := False;
  Player.CurrentTime := 0;  { Start at beginning }
  Player.Hidden := False;
  Player.PlayBackward := False;
end;
```

---

## Constants

### Play Types

```pascal
const
  SpritePlayType_Forward  = 0;  { Loop continuously }
  SpritePlayType_PingPong = 1;  { Bounce back and forth }
  SpritePlayType_Once     = 2;  { Play once and stop }
```

**SpritePlayType_Forward** - Loop animation continuously:
```
Frame:  0 → 1 → 2 → 3 → 0 → 1 → 2 → 3 → ...
```

**SpritePlayType_PingPong** - Bounce animation back and forth:
```
Frame:  0 → 1 → 2 → 3 → 2 → 1 → 0 → 1 → 2 → ...
```

**SpritePlayType_Once** - Play once and stop on last frame:
```
Frame:  0 → 1 → 2 → 3 [STOP]
```

**Example:**
```pascal
{ Walk animation - loop }
PlayerWalk.PlayType := SpritePlayType_Forward;

{ Idle breathing - ping-pong }
PlayerIdle.PlayType := SpritePlayType_PingPong;

{ Death animation - play once }
PlayerDeath.PlayType := SpritePlayType_Once;
```

---

### Maximum Frames

```pascal
const
  MaxSpriteFrames = 64;
```

Maximum number of frames per sprite (0-63).

---

## Functions

### UpdateSprite

```pascal
procedure UpdateSprite(var SpriteInstance: TSpriteInstance; DeltaTime: LongInt);
```

Updates sprite animation time. **MUST be called once per frame** with delta time in milliseconds.

**Parameters:**
- `SpriteInstance` - Sprite instance to update (by reference)
- `DeltaTime` - Time elapsed since last update in milliseconds

**Behavior:**
- Advances `CurrentTime` by `DeltaTime`
- When `CurrentTime` exceeds `Duration`:
  - **Forward:** Wraps back to 0 (loops)
  - **PingPong:** Reverses direction, continues
  - **Once:** Stops animation (`CurrentTime = -1`)
- If `CurrentTime = -1`, does nothing (animation stopped)

**Example:**
```pascal
var
  LastTimeMS, CurrentTimeMS, DeltaTimeMS: LongInt;

begin
  InitRTC(1024);
  LastTimeMS := Round(GetTimeSeconds * 1000);

  while GameRunning do
  begin
    { Calculate delta time }
    CurrentTimeMS := Round(GetTimeSeconds * 1000);
    DeltaTimeMS := CurrentTimeMS - LastTimeMS;
    LastTimeMS := CurrentTimeMS;

    { Update sprite - MUST call every frame }
    UpdateSprite(Player, DeltaTimeMS);

    { Render }
    DrawSprite(Player, BackBuffer);
  end;

  DoneRTC;
end;
```

**CRITICAL:** Call with actual delta time, not fixed value! Using fixed delta (e.g., `UpdateSprite(Player, 16)`) breaks frame-rate independence.

---

### DrawSprite

```pascal
procedure DrawSprite(var SpriteInstance: TSpriteInstance; FrameBuffer: PFrameBuffer);
```

Renders current animation frame to framebuffer.

**Parameters:**
- `SpriteInstance` - Sprite instance to draw (by reference)
- `FrameBuffer` - Destination framebuffer

**Behavior:**
- If `Hidden = True`, does nothing
- Calculates current frame from `CurrentTime`
- If `CurrentTime = -1`, shows last frame (stopped animation)
- Applies `FlipX` and `FlipY` transformations
- Draws with transparency (color 0 is transparent)
- Automatically clips at screen boundaries

**Example:**
```pascal
var
  Player: TSpriteInstance;
  Enemy: TSpriteInstance;

begin
  while GameRunning do
  begin
    ClearFrameBuffer(BackBuffer);

    { Draw all sprites }
    DrawSprite(Player, BackBuffer);
    DrawSprite(Enemy, BackBuffer);

    RenderFrameBuffer(BackBuffer);
  end;
end;
```

---

## Common Usage Patterns

### Basic Sprite Animation

```pascal
uses VGA, Sprite, PKMLoad, RTCTimer;

var
  SpriteSheet: TImage;
  PlayerRun: TSprite;
  Player: TSpriteInstance;
  BackBuffer: PFrameBuffer;
  LastTimeMS, CurrentTimeMS, DeltaTimeMS: LongInt;
  i: Integer;

begin
  InitVGA;
  InitRTC(1024);
  BackBuffer := CreateFrameBuffer;

  { Load sprite sheet }
  LoadPKM('PLAYER.PKM', SpriteSheet);

  { Setup sprite (8 frames, 32×32 each) }
  PlayerRun.Image := @SpriteSheet;
  PlayerRun.FrameCount := 8;
  PlayerRun.Duration := 800;  { 0.8 seconds }
  PlayerRun.PlayType := SpritePlayType_Forward;

  { Define frames (horizontal strip) }
  for i := 0 to 7 do
  begin
    PlayerRun.Frames[i].X := i * 32;
    PlayerRun.Frames[i].Y := 0;
    PlayerRun.Frames[i].Width := 32;
    PlayerRun.Frames[i].Height := 32;
  end;

  { Create instance }
  Player.Sprite := @PlayerRun;
  Player.X := 144;
  Player.Y := 84;
  Player.FlipX := False;
  Player.FlipY := False;
  Player.CurrentTime := 0;
  Player.Hidden := False;

  { Animation loop }
  LastTimeMS := Round(GetTimeSeconds * 1000);
  while not IsKeyPressed(Key_Escape) do
  begin
    { Calculate delta time }
    CurrentTimeMS := Round(GetTimeSeconds * 1000);
    DeltaTimeMS := CurrentTimeMS - LastTimeMS;
    LastTimeMS := CurrentTimeMS;

    { Update and render }
    UpdateSprite(Player, DeltaTimeMS);

    ClearFrameBuffer(BackBuffer);
    DrawSprite(Player, BackBuffer);
    RenderFrameBuffer(BackBuffer);

    ClearKeyPressed;
  end;

  FreeFrameBuffer(BackBuffer);
  FreeImage(SpriteSheet);
  DoneRTC;
  CloseVGA;
end.
```

---

### Multiple Animations (Idle/Run)

```pascal
type
  TPlayerState = (PS_Idle, PS_Running);

var
  SpriteSheet: TImage;
  PlayerIdle: TSprite;
  PlayerRun: TSprite;
  Player: TSpriteInstance;
  PlayerState: TPlayerState;

begin
  { Load sprite sheet }
  LoadPKM('PLAYER.PKM', SpriteSheet);

  { Setup idle animation (4 frames, row 0) }
  PlayerIdle.Image := @SpriteSheet;
  PlayerIdle.FrameCount := 4;
  PlayerIdle.Duration := 1000;
  PlayerIdle.PlayType := SpritePlayType_PingPong;

  for i := 0 to 3 do
  begin
    PlayerIdle.Frames[i].X := i * 32;
    PlayerIdle.Frames[i].Y := 0;
    PlayerIdle.Frames[i].Width := 32;
    PlayerIdle.Frames[i].Height := 32;
  end;

  { Setup run animation (8 frames, row 1) }
  PlayerRun.Image := @SpriteSheet;
  PlayerRun.FrameCount := 8;
  PlayerRun.Duration := 600;
  PlayerRun.PlayType := SpritePlayType_Forward;

  for i := 0 to 7 do
  begin
    PlayerRun.Frames[i].X := i * 32;
    PlayerRun.Frames[i].Y := 32;  { Second row }
    PlayerRun.Frames[i].Width := 32;
    PlayerRun.Frames[i].Height := 32;
  end;

  { Create instance }
  Player.Sprite := @PlayerIdle;  { Start with idle }
  Player.X := 100;
  Player.Y := 50;
  Player.CurrentTime := 0;
  Player.FlipX := False;
  PlayerState := PS_Idle;

  { Game loop }
  while GameRunning do
  begin
    { Input }
    if IsKeyDown(Key_D) then
    begin
      { Switch to run animation if not already }
      if PlayerState <> PS_Running then
      begin
        Player.Sprite := @PlayerRun;
        Player.CurrentTime := 0;  { Reset animation }
        PlayerState := PS_Running;
      end;
      Player.X := Player.X + 2;
      Player.FlipX := False;  { Face right }
    end
    else if IsKeyDown(Key_A) then
    begin
      if PlayerState <> PS_Running then
      begin
        Player.Sprite := @PlayerRun;
        Player.CurrentTime := 0;
        PlayerState := PS_Running;
      end;
      Player.X := Player.X - 2;
      Player.FlipX := True;  { Face left }
    end
    else
    begin
      { Switch to idle if not already }
      if PlayerState <> PS_Idle then
      begin
        Player.Sprite := @PlayerIdle;
        Player.CurrentTime := 0;
        PlayerState := PS_Idle;
      end;
    end;

    { Update and render }
    UpdateSprite(Player, DeltaTimeMS);
    DrawSprite(Player, BackBuffer);

    ClearKeyPressed;
  end;
end;
```

---

### Play-Once Animation (Explosion)

```pascal
var
  ExplosionAnim: TSprite;
  Explosion: TSpriteInstance;

begin
  { Setup explosion (12 frames) }
  ExplosionAnim.Image := @ExplosionSheet;
  ExplosionAnim.FrameCount := 12;
  ExplosionAnim.Duration := 500;  { Half second }
  ExplosionAnim.PlayType := SpritePlayType_Once;

  { ... define frames ... }

  { Trigger explosion }
  Explosion.Sprite := @ExplosionAnim;
  Explosion.X := EnemyX;
  Explosion.Y := EnemyY;
  Explosion.CurrentTime := 0;  { Start animation }
  Explosion.Hidden := False;

  { Game loop }
  while GameRunning do
  begin
    UpdateSprite(Explosion, DeltaTimeMS);

    { Check if animation finished }
    if Explosion.CurrentTime = -1 then
    begin
      WriteLn('Explosion finished!');
      Explosion.Hidden := True;  { Don't draw anymore }
    end;

    if not Explosion.Hidden then
      DrawSprite(Explosion, BackBuffer);
  end;
end;
```

---

### Multiple Instances (Enemies)

```pascal
var
  EnemyWalk: TSprite;  { Shared sprite definition }
  Enemies: array[0..9] of TSpriteInstance;  { 10 instances }
  i: Integer;

begin
  { Setup shared sprite }
  EnemyWalk.Image := @EnemySheet;
  EnemyWalk.FrameCount := 6;
  EnemyWalk.Duration := 600;
  EnemyWalk.PlayType := SpritePlayType_Forward;
  { ... define frames ... }

  { Create 10 enemy instances }
  for i := 0 to 9 do
  begin
    Enemies[i].Sprite := @EnemyWalk;  { All share same sprite }
    Enemies[i].X := Random(320);
    Enemies[i].Y := Random(200);
    Enemies[i].CurrentTime := Random(600);  { Stagger animations }
    Enemies[i].FlipX := Random(2) = 0;
    Enemies[i].Hidden := False;
  end;

  { Game loop }
  while GameRunning do
  begin
    { Update all enemies }
    for i := 0 to 9 do
      UpdateSprite(Enemies[i], DeltaTimeMS);

    { Draw all enemies }
    ClearFrameBuffer(BackBuffer);
    for i := 0 to 9 do
      DrawSprite(Enemies[i], BackBuffer);
    RenderFrameBuffer(BackBuffer);
  end;
end;
```

---

### Sprite Sheet Layouts

**Horizontal Strip (common):**
```
[Frame 0][Frame 1][Frame 2][Frame 3][Frame 4]
```

```pascal
{ 5 frames, 32×32 each, horizontal }
for i := 0 to 4 do
begin
  Sprite.Frames[i].X := i * 32;
  Sprite.Frames[i].Y := 0;
  Sprite.Frames[i].Width := 32;
  Sprite.Frames[i].Height := 32;
end;
```

**Vertical Strip:**
```
[Frame 0]
[Frame 1]
[Frame 2]
[Frame 3]
```

```pascal
{ 4 frames, 32×32 each, vertical }
for i := 0 to 3 do
begin
  Sprite.Frames[i].X := 0;
  Sprite.Frames[i].Y := i * 32;
  Sprite.Frames[i].Width := 32;
  Sprite.Frames[i].Height := 32;
end;
```

**Grid Layout:**
```
[0][1][2][3]
[4][5][6][7]
```

```pascal
{ 8 frames, 32×32 each, 4×2 grid }
for i := 0 to 7 do
begin
  Sprite.Frames[i].X := (i mod 4) * 32;
  Sprite.Frames[i].Y := (i div 4) * 32;
  Sprite.Frames[i].Width := 32;
  Sprite.Frames[i].Height := 32;
end;
```

**Multiple Animations in One Sheet:**
```
[Idle 0][Idle 1][Idle 2][Idle 3]
[Run  0][Run  1][Run  2][Run  3][Run  4][Run  5]
[Jump 0][Jump 1][Jump 2]
```

```pascal
{ Idle - row 0, 4 frames }
for i := 0 to 3 do
begin
  PlayerIdle.Frames[i].X := i * 32;
  PlayerIdle.Frames[i].Y := 0;
  PlayerIdle.Frames[i].Width := 32;
  PlayerIdle.Frames[i].Height := 32;
end;

{ Run - row 1, 6 frames }
for i := 0 to 5 do
begin
  PlayerRun.Frames[i].X := i * 32;
  PlayerRun.Frames[i].Y := 32;
  PlayerRun.Frames[i].Width := 32;
  PlayerRun.Frames[i].Height := 32;
end;

{ Jump - row 2, 3 frames }
for i := 0 to 2 do
begin
  PlayerJump.Frames[i].X := i * 32;
  PlayerJump.Frames[i].Y := 64;
  PlayerJump.Frames[i].Width := 32;
  PlayerJump.Frames[i].Height := 32;
end;
```

---

## Animation Timing

### Frame Duration Calculation

Given:
- `Duration` = 800 milliseconds
- `FrameCount` = 8 frames

Each frame displays for: `800 / 8 = 100 milliseconds`

**Example:**
```pascal
PlayerRun.Duration := 800;    { Total 0.8 seconds }
PlayerRun.FrameCount := 8;    { 8 frames }
{ Each frame shows for 100ms }
```

### Frame Rate vs Delta Time

**Fixed Frame Rate (wrong):**
```pascal
{ DON'T DO THIS - breaks on different CPUs }
UpdateSprite(Player, 16);  { Assumes 60 FPS always }
```

**Delta Time (correct):**
```pascal
{ DO THIS - frame-rate independent }
CurrentTimeMS := Round(GetTimeSeconds * 1000);
DeltaTimeMS := CurrentTimeMS - LastTimeMS;
LastTimeMS := CurrentTimeMS;

UpdateSprite(Player, DeltaTimeMS);  { Adapts to actual frame rate }
```

### Synchronizing Animations

**Start all at time 0:**
```pascal
Enemy1.CurrentTime := 0;
Enemy2.CurrentTime := 0;
Enemy3.CurrentTime := 0;
{ All enemies animate in sync }
```

**Stagger animations:**
```pascal
Enemy1.CurrentTime := 0;
Enemy2.CurrentTime := 200;  { 200ms offset }
Enemy3.CurrentTime := 400;  { 400ms offset }
{ Enemies animate with offset - looks more organic }
```

**Random start times:**
```pascal
for i := 0 to 9 do
  Enemies[i].CurrentTime := Random(Sprite.Duration);
{ Each enemy starts at random point in animation }
```

---

## Important Notes

### CRITICAL Rules

1. **MUST use delta time** - Never use fixed values (e.g., 16ms)
2. **Call UpdateSprite every frame** - Even if sprite is hidden (or check first)
3. **Duration in milliseconds** - Not frames, not seconds
4. **Shared sprite data** - Multiple instances can share one TSprite
5. **CurrentTime = -1** means stopped (PlayType_Once finished)

### Performance Tips

1. **Share sprite sheets** - Load once, use many instances
2. **Hide offscreen sprites** - Set `Hidden = True` when not visible
3. **Minimal frame rectangles** - Only define frames you need
4. **Efficient frame layouts** - Use grid layouts for sprite sheets

### Common Mistakes

1. **Fixed delta time** - Using constant like `16` instead of actual delta
   ```pascal
   { WRONG }
   UpdateSprite(Player, 16);

   { RIGHT }
   UpdateSprite(Player, DeltaTimeMS);
   ```

2. **Not resetting animation** - When switching animations
   ```pascal
   { WRONG - continues from old time }
   Player.Sprite := @PlayerRun;

   { RIGHT - restart animation }
   Player.Sprite := @PlayerRun;
   Player.CurrentTime := 0;
   ```

3. **Forgetting to update** - Not calling UpdateSprite
   ```pascal
   { WRONG - sprite never animates }
   DrawSprite(Player, BackBuffer);

   { RIGHT }
   UpdateSprite(Player, DeltaTimeMS);
   DrawSprite(Player, BackBuffer);
   ```

4. **Wrong duration units** - Using frames instead of milliseconds
   ```pascal
   { WRONG - 8 frames is only 8ms (0.008 seconds)! }
   Sprite.Duration := 8;

   { RIGHT - 800ms = 0.8 seconds }
   Sprite.Duration := 800;
   ```

### Frame Calculation

Current frame is calculated as:
```pascal
Progress := (CurrentTime × FrameCount) div Duration;
FrameNumber := Progress;  { Clamped to 0..FrameCount-1 }
```

**Example:**
- Duration = 800ms
- FrameCount = 8
- CurrentTime = 400ms
- Progress = (400 × 8) / 800 = 4
- Shows frame 4 (fifth frame)

### Animation State

**Active animation:**
```pascal
CurrentTime >= 0  { Animation running normally }
```

**Stopped animation (PlayType_Once finished):**
```pascal
CurrentTime = -1  { Shows last frame, UpdateSprite does nothing }
```

**Restart stopped animation:**
```pascal
Instance.CurrentTime := 0;  { Reset to beginning }
```

### Flipping

**Horizontal flip** (face left/right):
```pascal
Instance.FlipX := True;   { Mirror left-right }
Instance.FlipX := False;  { Normal }
```

**Vertical flip** (upside-down):
```pascal
Instance.FlipY := True;   { Mirror top-bottom }
Instance.FlipY := False;  { Normal }
```

**Both:**
```pascal
Instance.FlipX := True;
Instance.FlipY := True;  { Upside-down and mirrored }
```

---

## Integration with Other Units

### With RTCTimer (recommended)

```pascal
uses Sprite, RTCTimer;

begin
  InitRTC(1024);  { 1024 Hz timer }

  LastTimeMS := Round(GetTimeSeconds * 1000);

  while Running do
  begin
    CurrentTimeMS := Round(GetTimeSeconds * 1000);
    DeltaTimeMS := CurrentTimeMS - LastTimeMS;
    LastTimeMS := CurrentTimeMS;

    UpdateSprite(Player, DeltaTimeMS);
  end;

  DoneRTC;
end;
```

### With Keyboard (player control)

```pascal
uses Sprite, Keyboard;

begin
  InitKeyboard;

  while Running do
  begin
    { Movement }
    if IsKeyDown(Key_A) then
    begin
      Player.X := Player.X - 2;
      Player.FlipX := True;  { Face left }
    end;

    if IsKeyDown(Key_D) then
    begin
      Player.X := Player.X + 2;
      Player.FlipX := False;  { Face right }
    end;

    UpdateSprite(Player, DeltaTimeMS);
    DrawSprite(Player, BackBuffer);

    ClearKeyPressed;
  end;

  DoneKeyboard;
end;
```

### With TMXLOAD (tilemap games)

```pascal
uses Sprite, TMXLoad, TMXDraw;

begin
  LoadTileMap('LEVEL1.TMX', Map, nil);

  while Running do
  begin
    { Draw background }
    DrawTileMapLayer(Map, TileMapLayer_Back, CameraX, CameraY, 320, 200, BackBuffer);

    { Update and draw player sprite }
    UpdateSprite(Player, DeltaTimeMS);
    DrawSprite(Player, BackBuffer);

    { Draw foreground }
    DrawTileMapLayer(Map, TileMapLayer_Front, CameraX, CameraY, 320, 200, BackBuffer);
  end;
end;
```

---

## Example: Complete Player System

```pascal
uses VGA, Sprite, Keyboard, RTCTimer, PKMLoad;

type
  TPlayerState = (PS_Idle, PS_Walking, PS_Jumping);

var
  SpriteSheet: TImage;
  PlayerIdle, PlayerWalk, PlayerJump: TSprite;
  Player: TSpriteInstance;
  PlayerState: TPlayerState;
  BackBuffer: PFrameBuffer;
  LastTimeMS, CurrentTimeMS, DeltaTimeMS: LongInt;

procedure SetupAnimations;
var
  i: Integer;
begin
  LoadPKM('PLAYER.PKM', SpriteSheet);

  { Idle - 4 frames, row 0, ping-pong }
  PlayerIdle.Image := @SpriteSheet;
  PlayerIdle.FrameCount := 4;
  PlayerIdle.Duration := 1000;
  PlayerIdle.PlayType := SpritePlayType_PingPong;
  for i := 0 to 3 do
  begin
    PlayerIdle.Frames[i].X := i * 32;
    PlayerIdle.Frames[i].Y := 0;
    PlayerIdle.Frames[i].Width := 32;
    PlayerIdle.Frames[i].Height := 32;
  end;

  { Walk - 8 frames, row 1, loop }
  PlayerWalk.Image := @SpriteSheet;
  PlayerWalk.FrameCount := 8;
  PlayerWalk.Duration := 600;
  PlayerWalk.PlayType := SpritePlayType_Forward;
  for i := 0 to 7 do
  begin
    PlayerWalk.Frames[i].X := i * 32;
    PlayerWalk.Frames[i].Y := 32;
    PlayerWalk.Frames[i].Width := 32;
    PlayerWalk.Frames[i].Height := 32;
  end;

  { Jump - 3 frames, row 2, once }
  PlayerJump.Image := @SpriteSheet;
  PlayerJump.FrameCount := 3;
  PlayerJump.Duration := 300;
  PlayerJump.PlayType := SpritePlayType_Once;
  for i := 0 to 2 do
  begin
    PlayerJump.Frames[i].X := i * 32;
    PlayerJump.Frames[i].Y := 64;
    PlayerJump.Frames[i].Width := 32;
    PlayerJump.Frames[i].Height := 32;
  end;

  { Initialize instance }
  Player.Sprite := @PlayerIdle;
  Player.X := 144;
  Player.Y := 84;
  Player.CurrentTime := 0;
  Player.FlipX := False;
  Player.FlipY := False;
  Player.Hidden := False;
  PlayerState := PS_Idle;
end;

procedure SwitchAnimation(NewState: TPlayerState);
begin
  if PlayerState = NewState then
    Exit;

  PlayerState := NewState;
  Player.CurrentTime := 0;  { Restart animation }

  case NewState of
    PS_Idle: Player.Sprite := @PlayerIdle;
    PS_Walking: Player.Sprite := @PlayerWalk;
    PS_Jumping: Player.Sprite := @PlayerJump;
  end;
end;

begin
  InitVGA;
  InitKeyboard;
  InitRTC(1024);
  BackBuffer := CreateFrameBuffer;

  SetupAnimations;

  LastTimeMS := Round(GetTimeSeconds * 1000);

  while not IsKeyPressed(Key_Escape) do
  begin
    { Calculate delta time }
    CurrentTimeMS := Round(GetTimeSeconds * 1000);
    DeltaTimeMS := CurrentTimeMS - LastTimeMS;
    LastTimeMS := CurrentTimeMS;

    { Handle input }
    if IsKeyDown(Key_A) then
    begin
      SwitchAnimation(PS_Walking);
      Player.X := Player.X - 2;
      Player.FlipX := True;
    end
    else if IsKeyDown(Key_D) then
    begin
      SwitchAnimation(PS_Walking);
      Player.X := Player.X + 2;
      Player.FlipX := False;
    end
    else if IsKeyPressed(Key_Space) and (PlayerState <> PS_Jumping) then
    begin
      SwitchAnimation(PS_Jumping);
    end
    else if (PlayerState = PS_Walking) then
    begin
      SwitchAnimation(PS_Idle);
    end;

    { Check if jump finished }
    if (PlayerState = PS_Jumping) and (Player.CurrentTime = -1) then
      SwitchAnimation(PS_Idle);

    { Update animation }
    UpdateSprite(Player, DeltaTimeMS);

    { Render }
    ClearFrameBuffer(BackBuffer);
    DrawSprite(Player, BackBuffer);
    RenderFrameBuffer(BackBuffer);

    ClearKeyPressed;
  end;

  FreeFrameBuffer(BackBuffer);
  FreeImage(SpriteSheet);
  DoneKeyboard;
  DoneRTC;
  CloseVGA;
end.
```

---

## See Also

- **VGA.PAS** - Image rendering (PutFlippedImageRect)
- **PKMLOAD.PAS** - Loading sprite sheets
- **RTCTIMER.PAS** - High-resolution timing for delta time
- **KEYBOARD.PAS** - Player input for sprite control
- **TMXLOAD.PAS** / **TMXDRAW.PAS** - Tilemap integration
