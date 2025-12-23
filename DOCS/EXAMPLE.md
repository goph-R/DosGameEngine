
# 🎮 Example Codes

## VGA Graphics
```pascal
uses VGA, PCX;

var
  FrameBuffer: PFrameBuffer;
  TestImage: TImage;
  Palette: TPalette;

begin
  { Load image with palette }
  LoadPCXWithPalette('DATA\TEST.PCX', TestImage, Palette);

  InitVGA;
  SetPalette(Palette);

  { Render to framebuffer }
  FrameBuffer := CreateFrameBuffer;
  PutImage(TestImage, 0, 0, False, FrameBuffer);
  RenderFrameBuffer(FrameBuffer);
  ReadLn;

  DoneVGA;
  FreeFrameBuffer(FrameBuffer);
  FreeImage(TestImage);
end.
```

## Playing Music
```pascal
uses PlayHSC, Crt;

var
  Music: HSC_Obj;

begin
  Music.Init(0);  { Auto-detect Adlib at port 388h }
  if Music.LoadFile('DATA\FANTASY.HSC') then
  begin
    Music.Start;
    while not KeyPressed do
    begin
      { ... your game loop ... }
      Music.Poll; { Music needs polling }
    end;
    Music.Done;  { CRITICAL: Unhook interrupt! }
  end;
end.
```

## Sound Effects with XMS
```pascal
uses SBDSP, SndBank, XMS;

var
  Bank: TSoundBank;
  ExplosionID: Integer;

begin
  { Initialize Sound Blaster }
  ResetDSP($22, 5, 1, 0);  { Port $220, IRQ 5, DMA 1 }

  { Initialize sound bank }
  Bank.Init;

  { Load sounds into XMS at startup }
  ExplosionID := Bank.LoadSound('DATA\EXPLODE.VOC');

  { Play on demand - no disk I/O! }
  Bank.PlaySound(ExplosionID);

  { Cleanup }
  Bank.Done;
  UninstallHandler;
end.
```

## Game Loop with Delta Timing
```pascal
uses VGA, Keyboard, RTCTimer;

var
  Running: Boolean;
  LastTime, CurrentTime, DeltaTime: Real;
  PlayerX, PlayerY: Real;

begin
  InitVGA;
  InitKeyboard;
  InitRTC(1024);  { 1024 Hz timer }

  CurrentTime := RTC_Ticks / 1024.0;
  Running := True;

  while Running do
  begin
    { Calculate delta time }
    LastTime := CurrentTime;
    CurrentTime := RTC_Ticks / 1024.0;
    DeltaTime := CurrentTime - LastTime;

    { Frame-rate independent movement }
    if IsKeyDown(Key_Right) then
      PlayerX := PlayerX + 100.0 * DeltaTime;  { 100 pixels/sec }

    if IsKeyPressed(Key_Escape) then
      Running := False;

    { Render frame... }

    ClearKeyPressed;  { MUST call at end of loop }
  end;

  { CRITICAL: Clean up all interrupts }
  DoneRTC;
  DoneKeyboard;
  DoneVGA;
end.
```
