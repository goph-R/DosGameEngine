{ IMGTEST.PAS - Test program for TImage operations }
{ Demonstrates GetImage, PutImage with transparency, and sprite animation }

program ImgTest;

{$M 16384,0,655360}  { Stack: 16KB, MinHeap: 0, MaxHeap: 640KB }

uses
  VGA, PkmLoad, Crt, Dos, SndBank, SBDSP, XMS, PlayHSC, Config;

var
  FrontBuffer, BackBuffer, ScreenBuffer: PFrameBuffer;
  Palette: TPalette;
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
  PITTicks: LongInt;
  LastPITValue: Word;
  ElapsedTime: Real;
  i: Integer;
  ExplosionID: Integer;
  Bank: TSoundBank;
  LastBIOSTicks: LongInt;

  { DOSBox-X workaround: Required for Bank.PlaySound to work }
  { Mechanism unknown - only caller-side dummy vars fix the bug }
  { See CLAUDE.md Common Pitfall #16 for full investigation history }
  Dummy1, Dummy2, Dummy3, Dummy4: Integer;
  DummyStr1, DummyStr2: String;


{ InitHiResTimer removed - now using Timer 0 which is already initialized by BIOS }
(*
procedure InitHiResTimer; assembler;
asm
  mov al, 0B6h      { 1011_0110b:
                       ch2 select,
                       lobyte/hibyte,
                       mode 3 (square wave),
                       binary }
  out 43h, al

  xor ax, ax        { divisor = 0 -> actually means 65536 }
  out 42h, al       { low byte }
  mov al, ah
  out 42h, al       { high byte }

  { Enable timer 2 counting, but keep speaker muted }
  in  al, 61h
  or  al, 01h       { set bit0 = 1 (gate high so ch2 runs) }
  and al, 0FDh      { clear bit1 = 0 (mute speaker output) }
  out 61h, al
end;
*)

function ReadPIT: Word; assembler;
asm
  mov al, 00h       { 00_000000b = latch counter 0 (system timer) }
  out 43h, al

  in  al, 40h       { latched low byte from Timer 0 }
  mov ah, al
  in  al, 40h       { latched high byte from Timer 0 }
  xchg al, ah       { AX = current 16-bit count }
  { AX now holds the *current down-counter value* of Timer 0 }
end;

function GetBIOSTicks: LongInt;
{ Read BIOS timer tick counter at 0040:006C (increments at 18.2065 Hz) }
begin
  GetBIOSTicks := MemL[$0040:$006C];
end;

function GetHighResTime: Real;
{ Returns time in seconds }
{ Uses BIOS ticks when music is active (HSC reprograms PIT) }
var
  CurrentPIT: Word;
  Elapsed: LongInt;
  CurrentTicks: LongInt;
begin

  { No music - use direct PIT reads for high resolution }
  CurrentPIT := ReadPIT;

  { Detect if PIT wrapped (it counts DOWN, wraps at 0 back to 65535) }
  if CurrentPIT > LastPITValue then
    { Wrapped - calculate ticks from LastPITValue down to 0, then from 65535 down to CurrentPIT }
    Elapsed := LongInt(LastPITValue) + (65536 - LongInt(CurrentPIT))
  else
    { Normal - just the difference }
    Elapsed := LongInt(LastPITValue - CurrentPIT);

  Inc(PITTicks, Elapsed);
  LastPITValue := CurrentPIT;

  { Convert PIT ticks to seconds (PIT runs at 1193182 Hz) }
  GetHighResTime := PITTicks / 1193182.0;

end;

begin
  ClrScr;

  { Timer 0 already initialized by BIOS - no setup needed }

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
    Music.LoadFile('DATA\FANTASY.HSC');
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

    ExplosionID := Bank.LoadSound('DATA\EXPLODE.VOC');
    if ExplosionID < 0 then
    begin
      WriteLn('ERROR: Failed to load EXPLODE.VOC');
      Bank.Done;
      UninstallHandler;
      Halt(1);
    end;
  end;


  { Initialize VGA Mode 13h }
  InitVGA;

  { Get direct pointer to VGA screen memory }
  BackBuffer := CreateFrameBuffer;
  FrontBuffer := CreateFrameBuffer;

  { Load test image and palette directly to screen }
  if not LoadPKM('DATA\TEST.PKM', BackBuffer, Palette) then
  begin
    CloseVGA;
    WriteLn('Error: Could not load TEST.PKM');
    Halt(1);
  end;

  SetPalette(Palette);

  GetImage(Sprite1, 10, 10, 64, 64, BackBuffer);

  X := 160.0;
  Y := 100.0;
  VX := 80.0;   { 80 pixels per second }
  VY := 60.0;   { 60 pixels per second }

  ElapsedTime := 0;
  Frame := 0;

  Running := True;


  { Initialize timer (after music init if music is active) }
  PITTicks := 0;
  LastPITValue := ReadPIT;
  CurrentTime := GetHighResTime;

  while Running do
  begin
    { Poll HSC music if active (polling mode doesn't use interrupts) }
    if UseMusic then
      Music.Poll;

    CopyFrameBuffer(BackBuffer, FrontBuffer);
    PutImage(Sprite1, Trunc(X), Trunc(Y), True, FrontBuffer);
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
    if (X <= 0) or (X >= 320 - Sprite1.Width) then
    begin
      VX := -VX;
      { Clamp position to prevent getting stuck }
      if X < 0 then X := 0;
      if X > 320 - Sprite1.Width then X := 320 - Sprite1.Width;
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
        Running := False;
      if (Key = 'e') and (GameConfig.SoundCard = SoundCard_SoundBlaster) then
      begin
        Bank.PlaySound(ExplosionID);
      end;
    end; 

  end;

  { Clean up }
  FreeImage(Sprite1);

  FreeFrameBuffer(BackBuffer);
  FreeFrameBuffer(FrontBuffer);

  CloseVGA;

  WriteLn('Image test completed!');
  WriteLn('');
  WriteLn('Summary:');
  WriteLn('- Timer: PIT direct read with wrap detection (~1us resolution)');
  WriteLn('- GetImage: Captured sprite regions from screen buffer');
  WriteLn('- Animation: Frame-rate independent movement using delta time');
  WriteLn('  Velocity: 80 pixels/sec horizontal, 60 pixels/sec vertical');
  WriteLn('- Text overlay: Real-time FPS counter with embedded 8x8 font');
  WriteLn('- Double-buffering: Off-screen rendering with RenderFrameBuffer');
  WriteLn('');
  WriteLn('Usage: IMGTEST [novsync]');
  WriteLn('  novsync - Disable VSync for maximum framerate (with tearing)');
  
  if GameConfig.SoundCard = SoundCard_SoundBlaster then
    Bank.Done;

  if (GameConfig.SoundCard <> SoundCard_None) and (UseMusic) then
  begin
    Music.Done;
    UninstallHandler;
  end;

end.
