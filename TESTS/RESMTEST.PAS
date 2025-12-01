program ResmTest;

uses
  VGA, ResMan, Sprite, Keyboard, RTCTimer;

var
  ResMgr: TResourceManager;
  PlayerSprite: PSprite;
  PlayerPalette: PPalette;
  Player: TSpriteInstance;
  BackBuffer: PFrameBuffer;
  Running: Boolean;
  CurrentTime, LastTime, DeltaTime: Real;

begin
  WriteLn('Resource Manager Test');
  WriteLn('====================');
  WriteLn;

  { Initialize resource manager with lazy loading }
  WriteLn('Initializing resource manager...');
  ResMgr.Init(True);

  { Load resource definitions from XML }
  WriteLn('Loading RES.XML...');

  if not ResMgr.LoadFromXML('DATA\RES.XML') then
  begin
    WriteLn('ERROR: ', ResMgr.LastError);
    Halt(1);
  end;
  WriteLn('Resources loaded successfully!');
  WriteLn;

  { Test lazy loading - get sprite (should load image + sprite) }
  WriteLn('Loading sprite "player_idle" (lazy)...');
  PlayerSprite := ResMgr.GetSprite('player_idle');
  if PlayerSprite = nil then
  begin
    WriteLn('ERROR: ', ResMgr.LastError);
    ResMgr.Done;
    Halt(1);
  end;
  WriteLn('Sprite loaded! Frames: ', PlayerSprite^.FrameCount);
  WriteLn('  Size: ', PlayerSprite^.Width, 'x', PlayerSprite^.Height);
  WriteLn('  Duration: ', PlayerSprite^.Duration:0:2, ' seconds');
  WriteLn;

  { Setup sprite instance }
  Player.Sprite := PlayerSprite;
  Player.X := 144;
  Player.Y := 84;
  Player.Hidden := False;
  Player.FlipX := False;
  Player.FlipY := False;
  Player.CurrentTime := 0.0;

  BackBuffer := CreateFrameBuffer;

  { Initialize graphics }
  InitVGA;
  PlayerPalette := ResMgr.GetPalette('player');
  SetPalette(PlayerPalette^);

  InitKeyboard;
  InitRTC(1024);

  WriteLn('Running animation test...');
  WriteLn('Press ESC to exit');

  Running := True;
  LastTime := GetTimeSeconds;

  { Main loop }
  while Running do
  begin
    CurrentTime := GetTimeSeconds;
    DeltaTime := CurrentTime - LastTime;
    LastTime := CurrentTime;

    if IsKeyPressed(Key_Escape) then
      Running := False;

    UpdateSprite(Player, DeltaTime);

    ClearFrameBuffer(BackBuffer);
    DrawSprite(Player, BackBuffer);
    RenderFrameBuffer(BackBuffer);

    WaitForVSync;
    ClearKeyPressed;
  end;

  { Cleanup }
  DoneRTC;
  DoneKeyboard;
  FreeFrameBuffer(BackBuffer);
  CloseVGA;

  WriteLn('Cleaning up resource manager...');
  ResMgr.Done;

  WriteLn;
  WriteLn('Test completed successfully!');
end.
