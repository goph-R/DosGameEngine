{ IMGTEST.PAS - Test program for TImage operations }
{ Demonstrates GetImage, PutImage with transparency, and sprite animation }

program ImgTest;

{$M 16384,0,655360}  { Stack: 16KB, MinHeap: 0, MaxHeap: 640KB }

uses
  VGA, VGAPrint, PkmLoad, Crt, Dos, SndBank, SBDSP, XMS, PlayHSC, Config, RTCTimer;

var
  FrontBuffer, BackBuffer, ScreenBuffer: PFrameBuffer;
  Palette: TPalette;
  BackgroundImage: TImage;
  Sprite1, Sprite2: TImage;
  X, Y: Real;
  VX, VY: Real;  { Velocity in pixels/second }
  Frame: Integer;
  LastTime, CurrentTime, DeltaTime: Real;
  FPS: Word;
  FPSStr: String;
  UseVSync: Boolean;
  UseMusic: Boolean;
  Key: Char;
  Running: Boolean;
  Music: HSC_Obj;
  GameConfig: TConfig;

var
  ElapsedTime: Real;
  i: Integer;
  ExplosionID: Integer;
  Bank: TSoundBank;
  LastBIOSTicks: LongInt;
  Rect: TRectangle;

function GetHighResTime: Real;
begin
  GetHighResTime := RTC_Ticks / 1024.0;
end;

begin
  ClrScr;

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

  if (GameConfig.SoundCard <> SoundCard_None) and (UseMusic) then
  begin
    Music.Init(0);
    Music.LoadFile('..\DATA\FANTASY.HSC');
    Music.Start;
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

    { Initialize sound bank }
    if not Bank.Init then
    begin
      WriteLn('ERROR: Failed to initialize sound bank');
      UninstallHandler;
      Halt(1);
    end;

    WriteLn('Sound bank initialized - OK');
    WriteLn;

    { Load sounds into XMS }
    WriteLn('Loading sounds into XMS memory...');

    ExplosionID := Bank.LoadSound('..\DATA\EXPLODE.VOC');
    if ExplosionID < 0 then
    begin
      WriteLn('ERROR: Failed to load EXPLODE.VOC');
      Bank.Done;
      UninstallHandler;
      Halt(1);
    end;
  end;


  { Load test image and palette }
  if not LoadPKM('..\DATA\TEST.PKM', BackgroundImage, Palette) then
  begin
    WriteLn('Error: Could not load TEST.PKM');
    Halt(1);
  end;

  { Initialize VGA Mode 13h }
  InitVGA;
  SetPalette(Palette);

  { Create buffers and render background }
  BackBuffer := CreateFrameBuffer;
  FrontBuffer := CreateFrameBuffer;
  PutImage(BackgroundImage, 0, 0, False, BackBuffer);

  { Extract sprite from background }
  GetImage(Sprite1, 10, 10, 64, 64, BackBuffer);
  Rect.X := 10;
  Rect.Y := 10;
  Rect.Width := 64;
  Rect.Height := 64; 

  X := 160.0;
  Y := 100.0;
  VX := 80.0;   { 80 pixels per second }
  VY := 60.0;   { 60 pixels per second }

  ElapsedTime := 0;
  Frame := 0;
  Running := True;
  CurrentTime := GetHighResTime;

  while Running do
  begin
    { Poll HSC music if active (polling mode doesn't use interrupts) }
    if UseMusic then
      Music.Poll;

    CopyFrameBuffer(BackBuffer, FrontBuffer);
    PutImage(Sprite1, Trunc(X), Trunc(Y), True, FrontBuffer);
    {PutFlippedImageRect(BackgroundImage, Rect, 320 - Trunc(X) - 64, 200 - Trunc(Y) - 64,
      True, False, True, FrontBuffer);}
    Str(FPS, FPSStr);
    PrintText(5, 5, 'FPS: ' + FPSStr, 15, FrontBuffer);    

    { Wait for vertical sync to prevent tearing }
    if UseVSync then
      WaitForVSync;

    RenderFrameBuffer(FrontBuffer);

    { Calculate delta time }
    LastTime := CurrentTime;
    CurrentTime := GetHighResTime;
    DeltaTime := CurrentTime - LastTime;

    ElapsedTime := ElapsedTime + DeltaTime;
    if ElapsedTime > 1.0 then
    begin
      FPS := Frame;
      ElapsedTime := ElapsedTime - 1.0;
      Frame := 0;
    end;

    { Protect against negative or invalid delta times }
    if DeltaTime < 0.0 then
      DeltaTime := 0.001  { Use small value if time went backwards }
    else if DeltaTime > 0.5 then
      DeltaTime := 0.5;   { Prevent huge delta times }

    { Update sprite position using delta time }
    X := X + VX * DeltaTime;
    Y := Y + VY * DeltaTime;

    { Bounce off edges }
    if (X <= 0) or (X >= 340 - Sprite1.Width) then
    begin
      VX := -VX;
      { Clamp position to prevent getting stuck }
      if X < 0 then X := 0;
      if X > 340 - Sprite1.Width then X := 340 - Sprite1.Width;
    end;
    if (Y <= 0) or (Y >= 200 - Sprite1.Height) then
    begin
      VY := -VY;
      { Clamp position to prevent getting stuck }
      if Y < 0 then Y := 0;
      if Y > 200 - Sprite1.Height then Y := 200 - Sprite1.Height;
    end;

    Inc(Frame);

    if KeyPressed then
    begin
      Key := ReadKey;
      if Key = Chr(27) then
        Running := False
      else if (Key = 'e') and (GameConfig.SoundCard = SoundCard_SoundBlaster) then
        Bank.PlaySound(ExplosionID);
    end; 

  end;

  { Clean up }
  FreeImage(Sprite1);
  FreeImage(BackgroundImage);

  FreeFrameBuffer(BackBuffer);
  FreeFrameBuffer(FrontBuffer);

  CloseVGA;

  { CRITICAL: Unhook RTC interrupt before exit }
  DoneRTC;

  WriteLn('Image test completed!');
  WriteLn('');
  WriteLn('Summary:');
  WriteLn('- Timer: RTC based');
  WriteLn('- GetImage: Captured sprite regions from screen buffer');
  WriteLn('- Animation: Frame-rate independent movement using delta time');
  WriteLn('  Velocity: 80 pixels/sec horizontal, 60 pixels/sec vertical');
  WriteLn('- Text overlay: Real-time FPS counter with embedded 8x8 font');
  WriteLn('- Double-buffering: Off-screen rendering with RenderFrameBuffer');
  WriteLn('');
  WriteLn('Usage: IMGTEST [novsync]');
  WriteLn('  novsync - Disable VSync for maximum framerate (with tearing)');
  
  if GameConfig.SoundCard = SoundCard_SoundBlaster then
  begin
    Bank.Done;
    UninstallHandler;
  end;

  if (GameConfig.SoundCard <> SoundCard_None) and (UseMusic) then
  begin
    Music.Done;    
  end;

end.
