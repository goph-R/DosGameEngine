program SpriteTest;

uses
  VGA, VGAPrint, Sprite, Keyboard, RTCTimer, PCX, ResMan;

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

  { Sprite draw rectangle }
  SpriteRect: TRectangle;

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

  CopyFrameBufferRect(FrameBuffer, R, ScreenBuffer, R.X, R.Y);
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
  CopyFrameBufferRect(FrameBuffer, R, ScreenBuffer, R.X, R.Y);
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
  CopyFrameBufferRect(FrameBuffer, R, ScreenBuffer, R.X, R.Y);
end;

procedure DrawUI;
var
  FreeMem: LongInt;
begin
  DrawAnimationText;
  DrawVsyncText;
  DrawFPS;

  { Display free memory }
  FreeMem := MemAvail;
  Str(FreeMem, StatusText);
  StatusText := 'Free: ' + StatusText + ' bytes';
  PrintText(5, 25, StatusText, 15, FrameBuffer);

  { Instructions }
  PrintText(5, 180, '1: Idle  2: Run  F: Flip  V: VSync', 14, FrameBuffer);
  PrintText(5, 190, 'ESC: Exit', 14, FrameBuffer);

  RenderFrameBuffer(FrameBuffer);
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

  SpriteRect.X := Player.X;
  SpriteRect.Y := Player.Y;
  SpriteRect.Width := 32;
  SpriteRect.Height := 32;

  { Initialize state }
  Running := True;
  CurrentAnimation := 0;
  VsyncEnabled := False;
  FPS := 0.0;
  FrameCount := 0;

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

    { Update sprite animation }
    UpdateSprite(Player, DeltaTime);

    { Clear only the sprite area }
    ClearRect(FrameBuffer, SpriteRect);

    { Render only the sprite }
    DrawSprite(Player, FrameBuffer);

    { Copy only sprite region to screen }
    CopyFrameBufferRect(FrameBuffer, SpriteRect, ScreenBuffer, SpriteRect.X, SpriteRect.Y);

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
  CloseVGA;

  DoneRTC;
  DoneKeyboard;

  ResMgr.Done;

  WriteLn('Sprite test completed.');
end.
