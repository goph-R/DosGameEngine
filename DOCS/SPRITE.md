# SPRITE - Delta-Time Animation

Frame-rate independent sprite animation system.

## Types

```pascal
type
  TSprite = record
    Image: PImage;
    Frames: array[0..63] of TRectangle;
    FrameCount: Byte;
    Width, Height: Word;
    Duration: Real;      { Total duration in seconds }
    PlayType: Byte;      { Forward/PingPong/Once }
  end;
  PSprite = ^TSprite;

  TSpriteInstance = record
    Sprite: PSprite;
    X, Y: Integer;
    FlipX, FlipY: Boolean;
    Hidden: Boolean;
    CurrentTime: Real;   { Current time in seconds, -1.0 = stopped }
    PlayBackward: Boolean;
  end;
  PSpriteInstance = ^TSpriteInstance;
```

## Constants

```pascal
const
  SpritePlayType_Forward  = 0;  { Loop continuously: 0→1→2→3→0→... }
  SpritePlayType_PingPong = 1;  { Bounce: 0→1→2→3→2→1→0→... }
  SpritePlayType_Once     = 2;  { Play once: 0→1→2→3 [STOP] }
  MaxSpriteFrames = 64;
```

## Functions

```pascal
procedure UpdateSprite(var SpriteInstance: TSpriteInstance; DeltaTime: Real);
procedure DrawSprite(var SpriteInstance: TSpriteInstance; FrameBuffer: PFrameBuffer);
function SpriteGetCurrentFrame(var SpriteInstance: TSpriteInstance): Byte;
function CheckSpriteCollision(SpriteA, SpriteB: PSpriteInstance): Boolean;
```

### UpdateSprite
Updates the sprite animation state based on elapsed time. Call once per frame with delta time.

### DrawSprite
Renders the current frame to the framebuffer with transparency (color 0).

### SpriteGetCurrentFrame
Returns the current frame index (0..FrameCount-1) based on CurrentTime and PlayType. Useful for manual frame access or debugging.

### CheckSpriteCollision
Performs pixel-perfect collision detection between two sprite instances. Returns `True` if any non-transparent pixels overlap. Optimized with bounding box check and early exit. Accounts for FlipX/FlipY transformations.

## Example

```pascal
uses VGA, Sprite, PCX, RTCTimer;

var
  SpriteSheet: TImage;
  PlayerRun: TSprite;
  Player: TSpriteInstance;
  BackBuffer: PFrameBuffer;
  LastTime, CurrentTime, DeltaTime: Real;
  i: Integer;

begin
  InitVGA;
  InitRTC(1024);
  BackBuffer := CreateFrameBuffer;

  { Load sprite sheet }
  LoadPCX('PLAYER.PCX', SpriteSheet);

  { Setup sprite (8 frames, 32×32 each) }
  PlayerRun.Image := @SpriteSheet;
  PlayerRun.FrameCount := 8;
  PlayerRun.Duration := 0.8;  { 0.8 seconds total }
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
  Player.CurrentTime := 0.0;
  Player.FlipX := False;
  Player.Hidden := False;

  { Animation loop }
  LastTime := GetTimeSeconds;
  while Running do
  begin
    { Calculate delta time }
    CurrentTime := GetTimeSeconds;
    DeltaTime := CurrentTime - LastTime;
    LastTime := CurrentTime;

    { Update and render }
    UpdateSprite(Player, DeltaTime);

    ClearFrameBuffer(BackBuffer);
    DrawSprite(Player, BackBuffer);
    RenderFrameBuffer(BackBuffer);
  end;

  FreeFrameBuffer(BackBuffer);
  FreeImage(SpriteSheet);
  DoneRTC;
  DoneVGA;
end.
```

## Multiple Animations

```pascal
var
  PlayerIdle, PlayerRun: TSprite;
  Player: TSpriteInstance;

begin
  { Setup idle (4 frames, ping-pong) }
  PlayerIdle.Image := @SpriteSheet;
  PlayerIdle.FrameCount := 4;
  PlayerIdle.Duration := 1.0;
  PlayerIdle.PlayType := SpritePlayType_PingPong;
  { Define frames row 0... }

  { Setup run (8 frames, loop) }
  PlayerRun.Image := @SpriteSheet;
  PlayerRun.FrameCount := 8;
  PlayerRun.Duration := 0.6;
  PlayerRun.PlayType := SpritePlayType_Forward;
  { Define frames row 1... }

  { Switch animations }
  if IsKeyDown(Key_D) then
  begin
    Player.Sprite := @PlayerRun;
    Player.CurrentTime := 0.0;  { Reset animation }
    Player.FlipX := False;
  end
  else
  begin
    Player.Sprite := @PlayerIdle;
    Player.CurrentTime := 0.0;
  end;
end;
```

## Sprite Sheet Layouts

**Horizontal strip (common):**
```pascal
{ 5 frames, 32×32 each }
for i := 0 to 4 do
begin
  Sprite.Frames[i].X := i * 32;
  Sprite.Frames[i].Y := 0;
  Sprite.Frames[i].Width := 32;
  Sprite.Frames[i].Height := 32;
end;
```

**Grid layout (4×2):**
```pascal
{ 8 frames }
for i := 0 to 7 do
begin
  Sprite.Frames[i].X := (i mod 4) * 32;
  Sprite.Frames[i].Y := (i div 4) * 32;
  Sprite.Frames[i].Width := 32;
  Sprite.Frames[i].Height := 32;
end;
```

## Critical Notes

1. **MUST use delta time** - Never use fixed values like 0.016
2. **Duration in seconds** - Not frames or milliseconds
3. **Reset animation** - Set `CurrentTime := 0.0` when switching sprites
4. **Shared sprite data** - Multiple instances can share one TSprite
5. **CurrentTime < 0.0** - Means stopped (PlayType_Once finished)

## Frame Duration

- Duration = 0.8 seconds
- FrameCount = 8 frames
- Each frame displays for: 0.8 / 8 = 0.1 seconds

## Stagger Animations

```pascal
{ All enemies sync }
for i := 0 to 9 do
  Enemies[i].CurrentTime := 0.0;

{ Stagger for organic look }
for i := 0 to 9 do
  Enemies[i].CurrentTime := Random(1000) / 1000.0 * Sprite.Duration;
```

## Collision Detection

```pascal
var
  Player, Enemy: TSpriteInstance;
  Hit: Boolean;

begin
  { Update both sprites }
  UpdateSprite(Player, DeltaTime);
  UpdateSprite(Enemy, DeltaTime);

  { Check pixel-perfect collision }
  Hit := CheckSpriteCollision(@Player, @Enemy);
  if Hit then
  begin
    { Handle collision }
    WriteLn('COLLISION DETECTED!');
  end;

  { Alternative: Check current frame manually }
  if SpriteGetCurrentFrame(Player) = 3 then
    WriteLn('Player is on attack frame');
end;
```

**Collision features:**
- Pixel-perfect (ignores transparent pixels, color 0)
- Bounding box optimization (early exit if boxes don't overlap)
- Flip-aware (handles FlipX/FlipY correctly)
- Hidden-aware (returns False if either sprite is hidden)
- Fast early exit (returns True on first pixel collision)

## Notes

- Frame-rate independent (works on any CPU speed)
- Supports horizontal/vertical flipping
- Color 0 = transparent when drawing
- Use with RTCTIMER for accurate delta-time
- See RESMAN.PAS for loading sprites from XML
