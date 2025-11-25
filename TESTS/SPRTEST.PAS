program SpriteTest;

uses
  VGA, VGAPrint, Sprite, Keyboard, RTCTimer, PCXLoad;

var
  PlayerImage: TImage;
  Palette: TPalette;
  FrameBuffer: PFrameBuffer;
  ScreenBuffer: PFrameBuffer;

  { Sprite definitions }
  SpriteIdle: TSprite;
  SpriteRun: TSprite;

  { Sprite instances }
  Player: TSpriteInstance;

  { Timing }
  CurrentTime: Real;
  LastTime: Real;
  DeltaTimeMS: LongInt;
  DeltaTimeAccum: Real;  { Accumulator for fractional milliseconds }

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

procedure InitSprites;
var
  Frame: Integer;
begin
  { Initialize SpriteIdle: 4 frames, first row, 0.8 seconds }
  SpriteIdle.Image := @PlayerImage;
  SpriteIdle.FrameCount := 4;
  SpriteIdle.Width := 32;
  SpriteIdle.Height := 32;
  SpriteIdle.Duration := 800; { 0.8 seconds in milliseconds }
  SpriteIdle.PlayType := SpritePlayType_Forward;

  { Setup idle animation frames (first row: 0,0 to 128,0) }
  for Frame := 0 to 3 do
  begin
    SpriteIdle.Frames[Frame].X := Frame * 32;
    SpriteIdle.Frames[Frame].Y := 0;
    SpriteIdle.Frames[Frame].Width := 32;
    SpriteIdle.Frames[Frame].Height := 32;
  end;

  { Initialize SpriteRun: 6 frames, second row, 0.5 seconds }
  SpriteRun.Image := @PlayerImage;
  SpriteRun.FrameCount := 6;
  SpriteRun.Width := 32;
  SpriteRun.Height := 32;
  SpriteRun.Duration := 500; { 0.5 seconds in milliseconds }
  SpriteRun.PlayType := SpritePlayType_Forward;

  { Setup run animation frames (second row: 0,32 to 192,32) }
  for Frame := 0 to 5 do
  begin
    SpriteRun.Frames[Frame].X := Frame * 32;
    SpriteRun.Frames[Frame].Y := 32;
    SpriteRun.Frames[Frame].Width := 32;
    SpriteRun.Frames[Frame].Height := 32;
  end;
end;

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
  { Load player sprite sheet }
  WriteLn('Loading player sprite sheet from DATA\PLAYER.PCX...');
  if not LoadPCXWithPalette('..\DATA\PLAYER.PCX', PlayerImage, Palette) then
  begin
    WriteLn('ERROR: Could not load PLAYER.PCX');
    Halt(1);
  end;

  WriteLn('Player image loaded: ', PlayerImage.Width, 'x', PlayerImage.Height);
  WriteLn('Initializing sprites...');

  { Initialize sprite definitions }
  InitSprites;

  WriteLn('  SpriteIdle: ', SpriteIdle.FrameCount, ' frames, ', SpriteIdle.Duration, 'ms duration');
  WriteLn('  SpriteRun: ', SpriteRun.FrameCount, ' frames, ', SpriteRun.Duration, 'ms duration');

  { Initialize player sprite instance }
  Player.Sprite := @SpriteIdle;
  Player.Hidden := False;
  Player.X := 144;  { Center of screen (320/2 - 32/2) }
  Player.Y := 84;   { Center of screen (200/2 - 32/2) }
  Player.FlipX := False;
  Player.FlipY := False;
  Player.CurrentTime := 0;
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
  DeltaTimeAccum := 0.0;

  WriteLn('Press any key to start...');
  ReadLn;

  { Initialize systems }
  InitKeyboard;
  InitRTC(1024);
  LastFPSUpdate := GetTimeSeconds;
  LastTime := GetTimeSeconds;

  { Enter VGA mode }
  InitVGA;
  SetPalette(Palette);
  FrameBuffer := CreateFrameBuffer;
  ScreenBuffer := GetScreenBuffer;

  DrawUI;

  { Main loop }
  while Running do
  begin
    { Calculate delta time and accumulate fractional milliseconds }
    CurrentTime := GetTimeSeconds;
    DeltaTimeAccum := DeltaTimeAccum + ((CurrentTime - LastTime) * 1000.0);
    LastTime := CurrentTime;

    { Handle input }
    if IsKeyPressed(Key_Escape) then
      Running := False;

    if IsKeyPressed(Key_1) then
    begin
      CurrentAnimation := 0;
      Player.Sprite := @SpriteIdle;
      Player.CurrentTime := 0;
      Player.PlayBackward := False;
      DrawAnimationText;
    end;

    if IsKeyPressed(Key_2) then
    begin
      CurrentAnimation := 1;
      Player.Sprite := @SpriteRun;
      Player.CurrentTime := 0;
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

    { Update sprite animation only when we have at least 1ms accumulated }
    { This prevents animation freezing on fast CPUs (100MHz+ 486/Pentium) }
    if DeltaTimeAccum >= 1.0 then
    begin
      DeltaTimeMS := Trunc(DeltaTimeAccum);
      DeltaTimeAccum := DeltaTimeAccum - DeltaTimeMS;
      UpdateSprite(Player, DeltaTimeMS);
    end;

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

  FreeImage(PlayerImage);

  DoneRTC;
  DoneKeyboard;

  WriteLn('Sprite test completed.');
end.
