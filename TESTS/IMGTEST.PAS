{ IMGTEST.PAS - Test program for TImage operations }
{ Demonstrates GetImage, PutImage with transparency, and sprite animation }

program ImgTest;

{$M 16384,0,655360}  { Stack: 16KB, MinHeap: 0, MaxHeap: 640KB }

uses
  VGA, VGAPrint, PCX, Crt, Dos, SndBank, SBDSP, XMS, PlayHSC, Config, RTCTimer, ResMan;

type
  TTestSprite = record
    X, Y: LongInt;
    VX, VY: LongInt;
    FlipX, FlipY: Boolean;
  end;

var
  ResMgr: TResourceManager;
  FrontBuffer, BackBuffer, ScreenBuffer: PFrameBuffer;
  TestPalette: PPalette;
  BackgroundImage: PImage;
  Sprite1, Sprite2: TImage;
  Frame: Integer;
  LastTime, CurrentTime: Real;
  DeltaTime, ElapsedTime: Real;
  DeltaTimeMS: LongInt;
  FPS: Word;
  FPSStr: String;
  UseVSync: Boolean;
  UseMusic: Boolean;
  Key: Char;
  Running: Boolean;
  Music: PHSC_Obj;
  GameConfig: TConfig;

  { Test sprites for clipping demonstration }
  TestSprites: array[1..4] of TTestSprite;

var
  i: Integer;
  ExplosionID: Integer;
  Bank: TSoundBank;
  LastBIOSTicks: LongInt;
  Rect: TRectangle;
  OldExitProc: Pointer;
  InterruptsUnhooked: Boolean;

{ Exit procedure - CRITICAL for cleanup on Ctrl+C/Ctrl+Break }
{$F+}
procedure CleanupOnExit;
begin
  ExitProc := OldExitProc;  { Restore previous exit proc }

  { Only unhook if not already done (prevent double cleanup) }
  if InterruptsUnhooked then
    Exit;

  { CRITICAL: Unhook ALL interrupt handlers FIRST before any cleanup or I/O }
  { This prevents interrupt vectors from pointing to deallocated memory }

  { 1. Stop music (IRQ0 - timer interrupt) }
  if (GameConfig.SoundCard <> SoundCard_None) and (UseMusic) and (Music <> nil) then
    Music^.Stop;

  { 2. Stop sound (IRQ5/7 - Sound Blaster interrupt) }
  if GameConfig.SoundCard = SoundCard_SoundBlaster then
    UninstallHandler;

  { 3. Stop RTC timer (IRQ8 - RTC periodic interrupt) }
  DoneRTC;

  InterruptsUnhooked := True;
end;
{$F-}

begin
  ClrScr;

  { Initialize cleanup flag }
  InterruptsUnhooked := False;

  { Install exit procedure FIRST - ensures cleanup on Ctrl+C/Ctrl+Break }
  OldExitProc := ExitProc;
  ExitProc := @CleanupOnExit;

  InitRTC(1024);

  LoadConfig(GameConfig);

  { Parse command line arguments }

  UseVSync := True;  { VSync enabled by default }
  UseMusic := True;

  for i := 1 to ParamCount do
  begin
    if (ParamStr(i) = 'novsync') or (ParamStr(i) = 'NOVSYNC') then
      UseVSync := False;
    if (ParamStr(i) = 'nomusic') or (ParamStr(i) = 'NOMUSIC') then
      UseMusic := False;
  end;

  { Initialize resource manager }
  ResMgr.Init(True);  { Lazy loading }
  if not ResMgr.LoadFromXML('DATA\RES.XML') then
  begin
    WriteLn('ERROR: Failed to load resources: ', ResMgr.LastError);
    Halt(1);
  end;

  { Load music }
  if (GameConfig.SoundCard <> SoundCard_None) and (UseMusic) then
  begin
    Music := ResMgr.GetMusic('fantasy');
    if Music <> nil then
      Music^.Start;
  end;
  
  WriteLn('XMS Sound Bank Test with SBDSP');
  WriteLn('================================');
  WriteLn;

  { Check XMS availability }
  if not XMSinstalled then
  begin
    WriteLn('ERROR: XMS not installed!');
    WriteLn('Load HIMEM.SYS in CONFIG.SYS');
    Halt(1);
  end;

  WriteLn('XMS driver detected - OK');

  { Initialize Sound Blaster }
  if GameConfig.SoundCard = SoundCard_SoundBlaster then
  begin
    WriteLn('Initializing Sound Blaster...');
    if not ResetDSP(GameConfig.SBPort, GameConfig.SBIRQ, GameConfig.SBDMA, 0) then
    begin
      WriteLn('ERROR: Sound Blaster not detected!');
      Halt(1);
    end;

    WriteLn('Sound Blaster initialized - OK');
    WriteLn;

    { Load sound }
    WriteLn('Loading sounds...');
    ExplosionID := ResMgr.GetSound('explode');
    if ExplosionID < 0 then
    begin
      WriteLn('ERROR: Failed to load explosion sound');
      UninstallHandler;
      Halt(1);
    end;
    WriteLn('Sounds loaded - OK');
    WriteLn;
  end;


  { Load test image }
  BackgroundImage := ResMgr.GetImage('test');
  if BackgroundImage = nil then
  begin
    WriteLn('Error: Could not load test image: ', ResMgr.LastError);
    Halt(1);
  end;

  { Initialize VGA Mode 13h }
  InitVGA;

  { Set palette (extracted from image during loading) }
  TestPalette := ResMgr.GetPalette('test');
  if TestPalette <> nil then
    SetPalette(TestPalette^);

  { Create buffers and render background }
  BackBuffer := CreateFrameBuffer;
  FrontBuffer := CreateFrameBuffer;
  PutImage(BackgroundImage^, 0, 0, False, BackBuffer);

  { Extract sprite from background }
  GetImage(Sprite1, 10, 10, 64, 64, BackBuffer);
  Rect.X := 10;
  Rect.Y := 10;
  Rect.Width := 64;
  Rect.Height := 64; 

  { Initialize test sprites with different trajectories and flip modes }
  { Sprite 1: Top-left, moving down-right, no flip }
  TestSprites[1].X := -32 shl 10;
  TestSprites[1].Y := -32 shl 10;
  TestSprites[1].VX := 50;
  TestSprites[1].VY := 40;
  TestSprites[1].FlipX := False;
  TestSprites[1].FlipY := False;

  { Sprite 2: Top-right, moving down-left, FlipX }
  TestSprites[2].X := 320 shl 10;
  TestSprites[2].Y := -32 shl 10;
  TestSprites[2].VX := -45;
  TestSprites[2].VY := 35;
  TestSprites[2].FlipX := True;
  TestSprites[2].FlipY := False;

  { Sprite 3: Bottom-left, moving up-right, FlipY }
  TestSprites[3].X := -32 shl 10;
  TestSprites[3].Y := 200 shl 10;
  TestSprites[3].VX := 55;
  TestSprites[3].VY := -45;
  TestSprites[3].FlipX := False;
  TestSprites[3].FlipY := True;

  { Sprite 4: Bottom-right, moving up-left, FlipX+FlipY }
  TestSprites[4].X := 320 shl 10;
  TestSprites[4].Y := 200 shl 10;
  TestSprites[4].VX := -60;
  TestSprites[4].VY := -50;
  TestSprites[4].FlipX := True;
  TestSprites[4].FlipY := True;

  ElapsedTime := 0.0;
  Frame := 0;
  Running := True;
  CurrentTime := GetTimeSeconds;

  while Running do
  begin
    { Poll HSC music if active (polling mode doesn't use interrupts) }
    if UseMusic then
      Music^.Poll;

    CopyFrameBuffer(BackBuffer, FrontBuffer);

    { Draw all test sprites - they will clip properly at screen edges }
    for i := 1 to 4 do
    begin
      PutFlippedImage(Sprite1, Trunc(TestSprites[i].X shr 10), Trunc(TestSprites[i].Y shr 10),
                      TestSprites[i].FlipX, TestSprites[i].FlipY, True, FrontBuffer);
    end;

    Str(FPS, FPSStr);
    PrintText(5, 5, 'FPS: ' + FPSStr, 15, FrontBuffer);
    PrintText(5, 15, 'Clipping Test', 14, FrontBuffer);
    PrintText(5, 25, '4 sprites with', 14, FrontBuffer);
    PrintText(5, 35, 'different flips', 14, FrontBuffer);

    { Wait for vertical sync to prevent tearing }
    if UseVSync then
      WaitForVSync;

    RenderFrameBuffer(FrontBuffer);

    { Calculate delta time (seconds) }
    LastTime := CurrentTime;
    CurrentTime := GetTimeSeconds;
    DeltaTime := CurrentTime - LastTime;

    { Calculate FPS }
    ElapsedTime := ElapsedTime + DeltaTime;
    if ElapsedTime > 1.0 then
    begin
      FPS := Frame;
      ElapsedTime := ElapsedTime - 1.0;
      Frame := 0;
    end;

    { Protect against negative or invalid delta times }
    if DeltaTime < 0.0 then
      DeltaTime := 0.0  { Use zero if time went backwards }
    else if DeltaTime > 0.5 then
      DeltaTime := 0.5;   { Prevent huge delta times (cap at 0.5 seconds) }

    { Update all test sprite positions }
    DeltaTimeMS := Trunc(DeltaTime * 1000.0);
    for i := 1 to 4 do
    begin
      TestSprites[i].X := TestSprites[i].X + TestSprites[i].VX * DeltaTimeMS;
      TestSprites[i].Y := TestSprites[i].Y + TestSprites[i].VY * DeltaTimeMS;

      { Bounce off edges - allow sprites to go partially off-screen for clipping test }
      if (TestSprites[i].X <= -32 shl 10) or (TestSprites[i].X >= 320 shl 10) then
        TestSprites[i].VX := -TestSprites[i].VX;
      if (TestSprites[i].Y <= -32 shl 10) or (TestSprites[i].Y >= 200 shl 10) then
        TestSprites[i].VY := -TestSprites[i].VY;
    end;

    Inc(Frame);

    if KeyPressed then
    begin
      Key := ReadKey;
      if Key = Chr(27) then
        Running := False
      else if (Key = 'e') and (GameConfig.SoundCard = SoundCard_SoundBlaster) then
        ResMgr.SoundBank.PlaySound(ExplosionID);
    end; 

  end;

  { CRITICAL: Unhook ALL interrupt handlers FIRST before any cleanup or I/O }
  { This prevents interrupt vectors from pointing to deallocated memory }
  CleanupOnExit;

  { Now it's safe to free resources and do I/O }
  FreeImage(Sprite1);

  FreeFrameBuffer(BackBuffer);
  FreeFrameBuffer(FrontBuffer);

  CloseVGA;

  { Cleanup resource manager }
  ResMgr.Done;

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
  WriteLn('');
  WriteLn('Clipping: Sprites properly clip at negative X/Y coordinates');
  WriteLn('  and at right/bottom edges (320x200 screen boundaries).');
  WriteLn('');
  WriteLn('Usage: IMGTEST [novsync] [nomusic]');
  WriteLn('  novsync - Disable VSync for maximum framerate (with tearing)');
  WriteLn('  nomusic - Disable background music');
  WriteLn('');
  WriteLn('Press E to play explosion sound effect (if Sound Blaster enabled)');

end.
