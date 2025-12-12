{ IMGTEST.PAS - Test program for TImage operations }
{ Demonstrates GetImage, PutImage with transparency, and sprite animation }
{ Refactored to use GameUnit framework }

program ImgTest;

{$M 16384,0,655360}  { Stack: 16KB, MinHeap: 0, MaxHeap: 640KB }

uses
  GameUnit, VGA, VGAPrint, PCX, Crt, Dos, PlayHSC, Config, Keyboard;

type
  TTestSprite = record
    X, Y: LongInt;
    VX, VY: LongInt;
    FlipX, FlipY: Boolean;
  end;

  { Test screen with sprite animation }
  PTestScreen = ^TTestScreen;
  TTestScreen = object(TScreen)
    BackgroundImage: PImage;
    Sprite1: TImage;
    TestSprites: array[1..4] of TTestSprite;
    ElapsedTime: Real;
    Frame: Integer;
    FPS: Word;
    ExplosionID: Integer;
    UseVSync: Boolean;
    UseMusic: Boolean;
    Music: PHSC_Obj;

    constructor Init;
    destructor Done; virtual;
    procedure PostInit; virtual;
    procedure Update(DT: Real); virtual;
    procedure Render;
    procedure Show; virtual;
    procedure Hide; virtual;
  end;

var
  TestScreen: PTestScreen;

{ ========== TTestScreen Implementation ========== }

constructor TTestScreen.Init;
var
  i: Integer;
begin
  inherited Init;

  UseVSync := True;  { VSync enabled by default }
  UseMusic := True;  { Music enabled by default }

  { Parse command line arguments }
  for i := 1 to ParamCount do
  begin
    if (ParamStr(i) = 'novsync') or (ParamStr(i) = 'NOVSYNC') then
      UseVSync := False;
    if (ParamStr(i) = 'nomusic') or (ParamStr(i) = 'NOMUSIC') then
      UseMusic := False;
  end;

  { Load test image }
  BackgroundImage := Game.ResMan.GetImage('test');
  if BackgroundImage = nil then
  begin
    WriteLn('Error: Could not load test image: ', Game.ResMan.LastError);
    Halt(1);
  end;

  { Render background to background buffer }
  PutImage(BackgroundImage^, 0, 0, False, Game.BackgroundBuffer);

  { Extract sprite from background }
  GetImage(Sprite1, 10, 10, 64, 64, Game.BackgroundBuffer);

  { Initialize test sprites with different trajectories and flip modes }
  { Sprite 1: Top-left, moving down-right, no flip }
  TestSprites[1].X := -16 shl 10;
  TestSprites[1].Y := -16 shl 10;
  TestSprites[1].VX := 50;
  TestSprites[1].VY := 40;
  TestSprites[1].FlipX := False;
  TestSprites[1].FlipY := False;

  { Sprite 2: Top-right, moving down-left, FlipX }
  TestSprites[2].X := LongInt(320) shl 10;
  TestSprites[2].Y := LongInt(-16) shl 10;
  TestSprites[2].VX := -45;
  TestSprites[2].VY := 35;
  TestSprites[2].FlipX := True;
  TestSprites[2].FlipY := False;

  { Sprite 3: Bottom-left, moving up-right, FlipY }
  TestSprites[3].X := LongInt(-16) shl 10;
  TestSprites[3].Y := LongInt(200) shl 10;
  TestSprites[3].VX := 55;
  TestSprites[3].VY := -45;
  TestSprites[3].FlipX := False;
  TestSprites[3].FlipY := True;

  { Sprite 4: Bottom-right, moving up-left, FlipX+FlipY }
  TestSprites[4].X := LongInt(320) shl 10;
  TestSprites[4].Y := LongInt(200) shl 10;
  TestSprites[4].VX := -60;
  TestSprites[4].VY := -50;
  TestSprites[4].FlipX := True;
  TestSprites[4].FlipY := True;

  { Load sound effect if Sound Blaster is configured }
  if Game.Config.SoundCard = SoundCard_SoundBlaster then
  begin
    ExplosionID := Game.ResMan.GetSound('explode');
    if ExplosionID < 0 then
      WriteLn('Warning: Failed to load explosion sound');
  end;

  { Load music if enabled }
  Music := nil;
  if (Game.Config.SoundCard <> SoundCard_None) and UseMusic then
  begin
    Music := Game.ResMan.GetMusic('fantasy');
    if Music <> nil then
      Music^.Start;
  end;

  ElapsedTime := 0.0;
  Frame := 0;
  FPS := 0;
end;

destructor TTestScreen.Done;
begin
  { Stop music if playing }
  if (Music <> nil) and UseMusic then
    Music^.Stop;

  FreeImage(Sprite1);
  inherited Done;
end;

{ Set the palette only when VGA is initalized }
procedure TTestScreen.PostInit;
var
  TestPalette: PPalette;
begin
  { Set palette }
  TestPalette := Game.ResMan.GetPalette('test');
  if TestPalette <> nil then
    SetPalette(TestPalette^);
end;

procedure TTestScreen.Update(DT: Real);
var
  i: Integer;
  DeltaTimeMS: LongInt;
begin
  { Music plays automatically via IRQ, no polling needed }

  { Render }
  Render;

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

    { Bounce off edges - allow sprites to go partially off-screen for clipping test }
    if (TestSprites[i].X <= LongInt(-32) shl 10) or (TestSprites[i].X >= LongInt(320) shl 10) then
      TestSprites[i].VX := -TestSprites[i].VX;
    if (TestSprites[i].Y <= LongInt(-32) shl 10) or (TestSprites[i].Y >= LongInt(200) shl 10) then
      TestSprites[i].VY := -TestSprites[i].VY;
  end;

  Inc(Frame);

  { Handle keyboard - use KEYBOARD unit for proper integration }
  if IsKeyPressed(Key_E) then
    if (Game.Config.SoundCard = SoundCard_SoundBlaster) and (ExplosionID >= 0) then
      Game.ResMan.SoundBank.PlaySound(ExplosionID);

  if IsKeyPressed(Key_Escape) then
    Game.Running := False;
end;

procedure TTestScreen.Render;
var
  i: Integer;
  FPSStr: String;
begin
  CopyFrameBuffer(Game.BackgroundBuffer, Game.BackBuffer);

  { Draw all test sprites - they will clip properly at screen edges }
  for i := 1 to 4 do
  begin
    PutFlippedImage(Sprite1, Trunc(TestSprites[i].X shr 10), Trunc(TestSprites[i].Y shr 10),
                    TestSprites[i].FlipX, TestSprites[i].FlipY, True, Game.BackBuffer);
  end;

  { Draw FPS and info }
  Str(FPS, FPSStr);
  PrintText(5, 5, 'FPS: ' + FPSStr, 15, Game.BackBuffer);
  PrintText(5, 15, 'Clipping Test', 14, Game.BackBuffer);
  PrintText(5, 25, '4 sprites with', 14, Game.BackBuffer);
  PrintText(5, 35, 'different flips', 14, Game.BackBuffer);
  PrintText(5, 45, 'E=Explosion', 14, Game.BackBuffer);

  { Wait for vertical sync to prevent tearing }
  if UseVSync then
    WaitForVSync;

  RenderFrameBuffer(Game.BackBuffer);
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
  WriteLn('IMGTEST - Image Operations Test (GameUnit)');
  WriteLn('===========================================');
  WriteLn;

  { Initialize game }
  Game.Init('..\SETUP\CONFIG.INI', 'DATA\RES.XML');
  Game.Start;

  { Create and register test screen }
  New(TestScreen, Init);
  Game.AddScreen('test', TestScreen);

  { Set initial screen and run }
  Game.SetNextScreen('test');
  Game.Run;

  { Cleanup }
  Game.Done;

  WriteLn;
  WriteLn('Image test completed!');
  WriteLn('');
  WriteLn('Summary:');
  WriteLn('- Clipping Test: 4 sprites bouncing off all screen edges');
  WriteLn('  * Sprite 1: No flip (normal rendering)');
  WriteLn('  * Sprite 2: FlipX (horizontal flip)');
  WriteLn('  * Sprite 3: FlipY (vertical flip)');
  WriteLn('  * Sprite 4: FlipX+FlipY (both flips)');
  WriteLn('- Timer: RTC based (IRQ8 high-resolution timing)');
  WriteLn('- Animation: Frame-rate independent using delta time');
  WriteLn('- Text overlay: Real-time FPS counter with embedded 8x8 font');
  WriteLn('- Double-buffering: Off-screen rendering with RenderFrameBuffer');
  WriteLn('- GameUnit: Managed lifecycle with TGame and TScreen');
  WriteLn('');
  WriteLn('Clipping: Sprites properly clip at negative X/Y coordinates');
  WriteLn('  and at right/bottom edges (320x200 screen boundaries).');
  WriteLn('');
  WriteLn('Usage: IMGTEST [novsync] [nomusic]');
  WriteLn('  novsync - Disable VSync for maximum framerate (with tearing)');
  WriteLn('  nomusic - Disable background music');
  WriteLn('');
  WriteLn('Press E to play explosion sound effect (if Sound Blaster enabled)');
  WriteLn('Press ESC to exit');
end.
