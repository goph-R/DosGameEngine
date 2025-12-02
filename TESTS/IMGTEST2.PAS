{ IMGTEST2.PAS - Test program using GameUnit }
{ Demonstrates GameUnit with sprite animation and sound }

program ImgTest2;

{$M 16384,0,655360}  { Stack: 16KB, MinHeap: 0, MaxHeap: 640KB }

uses
  GameUnit, VGA, VGAPrint, PCX, Crt, ResMan, Config;

type
  TTestSprite = record
    X, Y: LongInt;
    VX, VY: LongInt;
    FlipX, FlipY: Boolean;
  end;

  { Test screen with sprite animation }
  PTestScreen = ^TTestScreen;
  TTestScreen = object(TScreen)
    ResMgr: TResourceManager;
    BackgroundImage: PImage;
    Sprite1: TImage;
    TestSprites: array[1..4] of TTestSprite;
    ElapsedTime: Real;
    Frame: Integer;
    FPS: Word;
    ExplosionID: Integer;
    UseVSync: Boolean;

    constructor Init(AGame: PGame);
    destructor Done; virtual;
    procedure Update(DT: Real); virtual;
    procedure Show; virtual;
    procedure Hide; virtual;
  end;

var
  Game: TGame;
  TestScreen: PTestScreen;

{ ========== TTestScreen Implementation ========== }

constructor TTestScreen.Init(AGame: PGame);
var
  i: Integer;
  TestPalette: PPalette;
begin
  inherited Init(AGame);

  UseVSync := True;  { VSync enabled by default }

  { Check command line for novsync }
  for i := 1 to ParamCount do
    if (ParamStr(i) = 'novsync') or (ParamStr(i) = 'NOVSYNC') then
      UseVSync := False;

  { Initialize resource manager }
  ResMgr.Init(True);  { Lazy loading }
  if not ResMgr.LoadFromXML('DATA\RES.XML') then
  begin
    WriteLn('ERROR: Failed to load resources: ', ResMgr.LastError);
    Halt(1);
  end;

  { Load test image }
  BackgroundImage := ResMgr.GetImage('test');
  if BackgroundImage = nil then
  begin
    WriteLn('Error: Could not load test image: ', ResMgr.LastError);
    Halt(1);
  end;

  { Set palette }
  TestPalette := ResMgr.GetPalette('test');
  if TestPalette <> nil then
    SetPalette(TestPalette^);

  { Render background to background buffer }
  PutImage(BackgroundImage^, 0, 0, False, Game^.BackgroundBuffer);

  { Extract sprite from background }
  GetImage(Sprite1, 10, 10, 64, 64, Game^.BackgroundBuffer);

  { Initialize test sprites }
  TestSprites[1].X := -32 shl 10;
  TestSprites[1].Y := -32 shl 10;
  TestSprites[1].VX := 50;
  TestSprites[1].VY := 40;
  TestSprites[1].FlipX := False;
  TestSprites[1].FlipY := False;

  TestSprites[2].X := 320 shl 10;
  TestSprites[2].Y := -32 shl 10;
  TestSprites[2].VX := -45;
  TestSprites[2].VY := 35;
  TestSprites[2].FlipX := True;
  TestSprites[2].FlipY := False;

  TestSprites[3].X := -32 shl 10;
  TestSprites[3].Y := 200 shl 10;
  TestSprites[3].VX := 55;
  TestSprites[3].VY := -45;
  TestSprites[3].FlipX := False;
  TestSprites[3].FlipY := True;

  TestSprites[4].X := 320 shl 10;
  TestSprites[4].Y := 200 shl 10;
  TestSprites[4].VX := -60;
  TestSprites[4].VY := -50;
  TestSprites[4].FlipX := True;
  TestSprites[4].FlipY := True;

  { Load sound effect if Sound Blaster is configured }
  if Game^.Config.SoundCard = SoundCard_SoundBlaster then
  begin
    ExplosionID := ResMgr.GetSound('explode');
    if ExplosionID < 0 then
      WriteLn('Warning: Failed to load explosion sound');
  end;

  ElapsedTime := 0.0;
  Frame := 0;
  FPS := 0;
end;

destructor TTestScreen.Done;
begin
  FreeImage(Sprite1);
  ResMgr.Done;
  inherited Done;
end;

procedure TTestScreen.Update(DT: Real);
var
  i: Integer;
  DeltaTimeMS: LongInt;
  FPSStr: String;
  Key: Char;
begin
  { Draw all test sprites }
  for i := 1 to 4 do
  begin
    PutFlippedImage(Sprite1, Trunc(TestSprites[i].X shr 10), Trunc(TestSprites[i].Y shr 10),
                    TestSprites[i].FlipX, TestSprites[i].FlipY, True, Game^.BackBuffer);
  end;

  { Draw FPS and info }
  Str(FPS, FPSStr);
  PrintText(5, 5, 'FPS: ' + FPSStr, 15, Game^.BackBuffer);
  PrintText(5, 15, 'Clipping Test', 14, Game^.BackBuffer);
  PrintText(5, 25, '4 sprites', 14, Game^.BackBuffer);
  PrintText(5, 35, 'ESC=Exit E=Sound', 14, Game^.BackBuffer);

  { Wait for vertical sync }
  if UseVSync then
    WaitForVSync;

  { Calculate FPS }
  ElapsedTime := ElapsedTime + DT;
  if ElapsedTime > 1.0 then
  begin
    FPS := Frame;
    ElapsedTime := ElapsedTime - 1.0;
    Frame := 0;
  end;

  { Update sprite positions }
  DeltaTimeMS := Trunc(DT * 1000.0);
  for i := 1 to 4 do
  begin
    TestSprites[i].X := TestSprites[i].X + TestSprites[i].VX * DeltaTimeMS;
    TestSprites[i].Y := TestSprites[i].Y + TestSprites[i].VY * DeltaTimeMS;

    { Bounce off edges }
    if (TestSprites[i].X <= -32 shl 10) or (TestSprites[i].X >= 320 shl 10) then
      TestSprites[i].VX := -TestSprites[i].VX;
    if (TestSprites[i].Y <= -32 shl 10) or (TestSprites[i].Y >= 200 shl 10) then
      TestSprites[i].VY := -TestSprites[i].VY;
  end;

  Inc(Frame);

  { Handle keyboard }
  if KeyPressed then
  begin
    Key := ReadKey;
    if Key = 'e' then
      if (Game^.Config.SoundCard = SoundCard_SoundBlaster) and (ExplosionID >= 0) then
        ResMgr.SoundBank.PlaySound(ExplosionID);
  end;
end;

procedure TTestScreen.Show;
begin
  WriteLn('Test screen activated!');
end;

procedure TTestScreen.Hide;
begin
  WriteLn('Test screen deactivated!');
end;

{ ========== Main Program ========== }

begin
  ClrScr;
  WriteLn('IMGTEST2 - GameUnit Test');
  WriteLn('========================');
  WriteLn;

  { Initialize game }
  Game.Init('CONFIG.INI', 'DATA\RES.XML');
  Game.Start;

  { Create and register test screen }
  New(TestScreen, Init(@Game));
  Game.AddScreen('test', TestScreen);

  { Set initial screen and run }
  Game.SetScreen('test');
  Game.Run;

  { Cleanup }
  Game.Done;

  WriteLn;
  WriteLn('Image test completed!');
  WriteLn('Usage: IMGTEST2 [novsync]');
  WriteLn('  novsync - Disable VSync for maximum framerate');
  WriteLn('Press E to play explosion sound effect');
end.
