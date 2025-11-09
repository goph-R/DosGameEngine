program SpriteTest;

uses
  VGA, VGAPrint, Sprite, Keyboard, RTCTimer, PKMLoad;

var
  PlayerImage: TImage;
  Palette: TPalette;
  FrameBuffer: PFrameBuffer;

  { Sprite definitions }
  SpriteIdle: TSprite;
  SpriteRun: TSprite;

  { Sprite instances }
  Player: TSpriteInstance;

  { Timing }
  CurrentTimeMS: LongInt;
  LastTimeMS: LongInt;
  DeltaTimeMS: Word;

  { FPS calculation }
  FPS: Real;
  FrameCount: Word;
  LastFPSUpdate: Real;

  { State }
  Running: Boolean;
  CurrentAnimation: Byte; { 0 = Idle, 1 = Run }
  StatusText: String;
  I: Integer;

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

procedure UpdateFPS;
var
  CurrentTime: Real;
  Elapsed: Real;
begin
  Inc(FrameCount);
  CurrentTime := GetTimeSeconds;
  Elapsed := CurrentTime - LastFPSUpdate;

  if Elapsed >= 1.0 then
  begin
    FPS := FrameCount / Elapsed;
    FrameCount := 0;
    LastFPSUpdate := CurrentTime;
  end;
end;

procedure DrawUI;
var
  FreeMem: LongInt;
begin
  { Display current animation }
  if CurrentAnimation = 0 then
    PrintText(5, 5, 'Animation: IDLE', 15, FrameBuffer)
  else
    PrintText(5, 5, 'Animation: RUN', 15, FrameBuffer);

  { Display FPS }
  Str(FPS:0:1, StatusText);
  StatusText := 'FPS: ' + StatusText;
  PrintText(5, 15, StatusText, 15, FrameBuffer);

  { Display free memory }
  FreeMem := MemAvail;
  Str(FreeMem, StatusText);
  StatusText := 'Free: ' + StatusText + ' bytes';
  PrintText(5, 25, StatusText, 15, FrameBuffer);

  { Instructions }
  PrintText(5, 180, '1: Idle  2: Run  F: Flip', 14, FrameBuffer);
  PrintText(5, 190, 'ESC: Exit', 14, FrameBuffer);
end;

begin
  { Load player sprite sheet }
  WriteLn('Loading player sprite sheet from DATA\PLAYER.PKM...');
  if not LoadPKMWithPalette('..\DATA\PLAYER.PKM', PlayerImage, Palette) then
  begin
    WriteLn('ERROR: Could not load PLAYER.PKM');
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

  { Initialize state }
  Running := True;
  CurrentAnimation := 0;
  FPS := 0.0;
  FrameCount := 0;

  WriteLn('Press any key to start...');
  ReadLn;

  { Initialize systems }
  InitKeyboard;
  InitRTC(1024);
  LastFPSUpdate := GetTimeSeconds;
  LastTimeMS := Round(GetTimeSeconds * 1000);

  { Enter VGA mode }
  InitVGA;
  SetPalette(Palette);
  FrameBuffer := CreateFrameBuffer;

  { Main loop }
  while Running do
  begin
    { Calculate delta time }
    CurrentTimeMS := Round(GetTimeSeconds * 1000);
    DeltaTimeMS := CurrentTimeMS - LastTimeMS;
    LastTimeMS := CurrentTimeMS;

    { Handle input }
    if IsKeyPressed(Key_Escape) then
      Running := False;

    if IsKeyPressed(Key_1) then
    begin
      CurrentAnimation := 0;
      Player.Sprite := @SpriteIdle;
      Player.CurrentTime := 0;
      Player.PlayBackward := False;
    end;

    if IsKeyPressed(Key_2) then
    begin
      CurrentAnimation := 1;
      Player.Sprite := @SpriteRun;
      Player.CurrentTime := 0;
      Player.PlayBackward := False;
    end;

    if IsKeyPressed(Key_F) then
      Player.FlipX := not Player.FlipX;

    { Update sprite animation }
    UpdateSprite(Player, DeltaTimeMS);

    { Render }
    ClearFrameBuffer(FrameBuffer);
    DrawSprite(Player, FrameBuffer);
    DrawUI;

    { Display }
    RenderFrameBuffer(FrameBuffer);

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
