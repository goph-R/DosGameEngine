program SpriteTest;

uses
  VGA, VGAPrint, Sprite, Keyboard, RTCTimer, PCX, ResMan, DRect;

var
  ResMgr: TResourceManager;
  PlayerPalette: PPalette;
  FrameBuffer: PFrameBuffer;
  ScreenBuffer: PFrameBuffer;

  { Sprite definitions }
  SpriteIdle: PSprite;
  SpriteRun: PSprite;

  { Sprite instances }
  Player: TSpriteInstance;
  Enemy: TSpriteInstance;

  { Enemy movement }
  EnemyElapsedTime: Real;
  EnemyMoveXDirection: ShortInt;

  { Collision }
  IsColliding: Boolean;

  { Timing }
  CurrentTime: Real;
  LastTime: Real;
  DeltaTime: Real;

  { FPS calculation }
  FPS: Real;
  FrameCount: Word;
  LastFPSUpdate: Real;

  { State }
  Running: Boolean;
  CurrentAnimation: Byte; { 0 = Idle, 1 = Run }
  VsyncEnabled: Boolean;
  StatusText: String;
  I: Integer;

  { Sprite rectangles }
  PlayerRect, EnemyRect: TRectangle;
  OldPlayerRect, OldEnemyRect: TRectangle;
  OldPlayerX, OldPlayerY: Integer;
  OldEnemyX, OldEnemyY: Integer;

procedure ClearRect(Buffer: PFrameBuffer; var Rect: TRectangle);
{ Clear a rectangular region in the framebuffer }
var
  Row: Integer;
  Offset: Word;
begin
  for Row := 0 to Rect.Height - 1 do
  begin
    Offset := (Rect.Y + Row) * 320 + Rect.X;
    FillChar(Buffer^[Offset], Rect.Width, 0);
  end;
end;

procedure DrawFPS;
var
  R: TRectangle;
begin
  R.X := 5;
  R.Y := 15;
  R.Width := 100;
  R.Height := 8;
  ClearRect(FrameBuffer, R);

  { Display FPS }
  Str(FPS:0:1, StatusText);
  StatusText := 'FPS: ' + StatusText;
  PrintText(5, 15, StatusText, 15, FrameBuffer);

  AddDirtyRect(R);
end;

procedure UpdateFPS;
var
  Elapsed: Real;
begin
  Inc(FrameCount);
  Elapsed := CurrentTime - LastFPSUpdate;

  if Elapsed >= 1.0 then
  begin
    FPS := FrameCount / Elapsed;
    FrameCount := 0;
    LastFPSUpdate := CurrentTime;
    DrawFPS;
  end;
end;

procedure DrawAnimationText;
var
  R: TRectangle;
begin
  R.X := 5;
  R.Y := 5;
  R.Width := 150;
  R.Height := 8;
  ClearRect(FrameBuffer, R);
  if CurrentAnimation = 0 then
    PrintText(5, 5, 'Animation: IDLE', 15, FrameBuffer)
  else
    PrintText(5, 5, 'Animation: RUN', 15, FrameBuffer);
  AddDirtyRect(R);
end;

procedure DrawVsyncText;
var
  R: TRectangle;
begin
  R.X := 210;
  R.Y := 5;
  R.Width := 105;
  R.Height := 8;
  ClearRect(FrameBuffer, R);
  if VsyncEnabled then
    PrintText(210, 5, 'VSync: ON', 15, FrameBuffer)
  else
    PrintText(210, 5, 'VSync: OFF', 15, FrameBuffer);
  AddDirtyRect(R);
end;

procedure DrawCollisionText;
var
  R: TRectangle;
begin
  R.X := 5;
  R.Y := 25;
  R.Width := 130;
  R.Height := 8;
  ClearRect(FrameBuffer, R);
  if IsColliding then
    PrintText(5, 25, 'COLLISION!', 12, FrameBuffer)
  else
    PrintText(5, 25, 'No collision', 10, FrameBuffer);
  AddDirtyRect(R);
end;

procedure DrawUI;
var
  R: TRectangle;
begin
  DrawAnimationText;
  DrawVsyncText;
  DrawFPS;
  DrawCollisionText;

  { Instructions }
  R.X := 5;
  R.Y := 180;
  R.Width := 270;
  R.Height := 18;
  PrintText(5, 180, '1: Idle  2: Run  F: Flip  V: VSync', 14, FrameBuffer);
  PrintText(5, 190, 'ESC: Exit', 14, FrameBuffer);
  AddDirtyRect(R);
end;

begin
  { Initialize resource manager }
  WriteLn('Initializing resource manager...');
  ResMgr.Init(True);  { Lazy loading }
  if not ResMgr.LoadFromXML('DATA\RES.XML') then
  begin
    WriteLn('ERROR: Failed to load resources: ', ResMgr.LastError);
    Halt(1);
  end;

  { Load sprites }
  WriteLn('Loading sprites...');
  SpriteIdle := ResMgr.GetSprite('player_idle');
  if SpriteIdle = nil then
  begin
    WriteLn('ERROR: Could not load player_idle sprite: ', ResMgr.LastError);
    Halt(1);
  end;

  SpriteRun := ResMgr.GetSprite('player_run');
  if SpriteRun = nil then
  begin
    WriteLn('ERROR: Could not load player_run sprite: ', ResMgr.LastError);
    Halt(1);
  end;

  WriteLn('  SpriteIdle: ', SpriteIdle^.FrameCount, ' frames, ', Trunc(SpriteIdle^.Duration * 1000.0), 'ms duration');
  WriteLn('  SpriteRun: ', SpriteRun^.FrameCount, ' frames, ', Trunc(SpriteRun^.Duration * 1000.0), 'ms duration');

  { Initialize player sprite instance }
  Player.Sprite := SpriteIdle;
  Player.Hidden := False;
  Player.X := 144;  { Center of screen (320/2 - 32/2) }
  Player.Y := 84;   { Center of screen (200/2 - 32/2) }
  Player.FlipX := False;
  Player.FlipY := False;
  Player.CurrentTime := 0.0;
  Player.PlayBackward := False;

  { Initialize enemy sprite instance }
  Enemy.Sprite := SpriteRun;
  Enemy.Hidden := False;
  Enemy.X := 80;   { Start at left boundary }
  Enemy.Y := 84;   { Same Y as player }
  Enemy.FlipX := False;
  Enemy.FlipY := False;
  Enemy.CurrentTime := 0.0;
  Enemy.PlayBackward := False;

  { Initialize enemy movement }
  EnemyElapsedTime := 0.0;
  EnemyMoveXDirection := 1; { 1 = right, -1 = left }

  { Initialize old positions }
  OldPlayerX := Player.X;
  OldPlayerY := Player.Y;
  OldEnemyX := Enemy.X;
  OldEnemyY := Enemy.Y;

  { Initialize state }
  Running := True;
  CurrentAnimation := 0;
  VsyncEnabled := False;
  FPS := 0.0;
  FrameCount := 0;
  IsColliding := False;

  WriteLn('Press any key to start...');
  ReadLn;

  { Initialize systems }
  InitKeyboard;
  InitRTC(1024);
  LastFPSUpdate := GetTimeSeconds;
  LastTime := GetTimeSeconds;

  { Enter VGA mode }
  InitVGA;

  { Set palette (extracted from image during loading) }
  PlayerPalette := ResMgr.GetPalette('player');
  if PlayerPalette <> nil then
    SetPalette(PlayerPalette^);

  FrameBuffer := CreateFrameBuffer;
  ScreenBuffer := GetScreenBuffer;

  DrawUI;

  { Main loop }
  while Running do
  begin
    { Calculate delta time in seconds }
    CurrentTime := GetTimeSeconds;
    DeltaTime := CurrentTime - LastTime;
    LastTime := CurrentTime;

    { Handle input }
    if IsKeyPressed(Key_Escape) then
      Running := False;

    if IsKeyPressed(Key_1) then
    begin
      CurrentAnimation := 0;
      Player.Sprite := SpriteIdle;
      Player.CurrentTime := 0.0;
      Player.PlayBackward := False;
      DrawAnimationText;
    end;

    if IsKeyPressed(Key_2) then
    begin
      CurrentAnimation := 1;
      Player.Sprite := SpriteRun;
      Player.CurrentTime := 0.0;
      Player.PlayBackward := False;
      DrawAnimationText;
    end;

    if IsKeyPressed(Key_F) then
      Player.FlipX := not Player.FlipX;

    if IsKeyPressed(Key_V) then
    begin
      VsyncEnabled := not VsyncEnabled;
      DrawVsyncText;
    end;

    { Save old positions before movement }
    OldPlayerX := Player.X;
    OldPlayerY := Player.Y;
    OldEnemyX := Enemy.X;
    OldEnemyY := Enemy.Y;

    { Update enemy movement }
    EnemyElapsedTime := EnemyElapsedTime + DeltaTime;
    if EnemyElapsedTime > 2.6667 then
    begin
      EnemyElapsedTime := EnemyElapsedTime - 2.6667;
      EnemyMoveXDirection := -EnemyMoveXDirection;
      Enemy.FlipX := EnemyMoveXDirection < 0;
    end;

    { Calculate enemy position based on elapsed time }
    if EnemyMoveXDirection = 1 then
      Enemy.X := 80 + Trunc(EnemyElapsedTime * 60.0)
    else
      Enemy.X := 240 - Trunc(EnemyElapsedTime * 60.0);

    { Update sprite animations }
    UpdateSprite(Player, DeltaTime);
    UpdateSprite(Enemy, DeltaTime);

    { Check collision }
    IsColliding := CheckSpriteCollision(@Player, @Enemy);
    DrawCollisionText;

    { Create rectangles for old and new positions }
    OldPlayerRect.X := OldPlayerX;
    OldPlayerRect.Y := OldPlayerY;
    OldPlayerRect.Width := 32;
    OldPlayerRect.Height := 32;

    PlayerRect.X := Player.X;
    PlayerRect.Y := Player.Y;
    PlayerRect.Width := 32;
    PlayerRect.Height := 32;

    OldEnemyRect.X := OldEnemyX;
    OldEnemyRect.Y := OldEnemyY;
    OldEnemyRect.Width := 32;
    OldEnemyRect.Height := 32;

    EnemyRect.X := Enemy.X;
    EnemyRect.Y := Enemy.Y;
    EnemyRect.Width := 32;
    EnemyRect.Height := 32;

    { Merge old and new positions for each sprite }
    MergeRectangles(OldPlayerRect, PlayerRect, PlayerRect);
    MergeRectangles(OldEnemyRect, EnemyRect, EnemyRect);

    { Clear merged sprite areas }
    ClearRect(FrameBuffer, PlayerRect);
    ClearRect(FrameBuffer, EnemyRect);

    { Draw sprites }
    DrawSprite(Player, FrameBuffer);
    DrawSprite(Enemy, FrameBuffer);

    { Add merged dirty rectangles }
    AddDirtyRect(PlayerRect);
    AddDirtyRect(EnemyRect);

    { Flush dirty rectangles to screen }
    FlushDirtyRects(FrameBuffer);
    ClearDirtyRects;

    { Wait for vertical blank if VSync enabled (caps at ~60-70 FPS) }
    if VsyncEnabled then
      WaitForVSync;

    { Update FPS }
    UpdateFPS;

    { Clear key states for next frame }
    ClearKeyPressed;
  end;

  { Cleanup }
  FreeFrameBuffer(FrameBuffer);
  DoneVGA;

  DoneRTC;
  DoneKeyboard;

  ResMgr.Done;

  WriteLn('Sprite test completed.');
end.
