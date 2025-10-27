program Game;

{$G+}  { Enable 286 instructions }

{
  Example game loop using hybrid timing:
  - Game logic updates at fixed 60 Hz (via PIT timer)
  - Graphics rendering synced to VBlank (~70 Hz)
  - Smooth animation with no screen tearing
}

uses VGA, Dos;

const
  GAME_TICK_RATE = 60;     { Logic updates per second }
  TIMER_FREQ = 100;        { Timer interrupts per second }
  TICKS_PER_UPDATE = TIMER_FREQ div GAME_TICK_RATE;  { ~1.67 ticks }

type
  TGameObject = record
    X, Y: Integer;
    VelX, VelY: Integer;
    Color: Byte;
  end;

var
  FrameBuffer: PFrameBuffer;
  TimerTicks: LongInt;
  OldTimerInt: Pointer;
  GameRunning: Boolean;

  { Game state }
  Player: TGameObject;
  LastUpdateTick: LongInt;
  FrameCount: LongInt;

{ Simple keyboard functions to replace Crt unit }
function KeyPressed: Boolean; assembler;
asm
  mov ah, 01h
  int 16h
  jz @NoKey
  mov al, 1
  jmp @Done
@NoKey:
  xor al, al
@Done:
end;

function ReadKey: Char; assembler;
asm
  mov ah, 00h
  int 16h
end;

procedure ClrScr; assembler;
asm
  mov ax, 0003h
  int 10h
end;

{ Timer interrupt handler - called 100 times per second }
procedure TimerInterrupt; interrupt; assembler;
asm
  { Increment timer ticks }
  inc word ptr [TimerTicks]
  adc word ptr [TimerTicks+2], 0  { Handle LongInt carry }

  { Always chain to BIOS timer - let it handle everything }
  { This is simpler and more reliable }
  pushf
  call dword ptr [OldTimerInt]
end;

procedure SetTimerFreq(Hz: Word);
var
  Divisor: Word;
begin
  if Hz = 0 then Hz := 18;  { Safety check }

  Divisor := 1193180 div Hz;  { PIT base frequency / desired frequency }

  Port[$43] := $36;           { Timer 0, LSB then MSB, mode 3 (square wave) }
  Port[$40] := Lo(Divisor);
  Port[$40] := Hi(Divisor);
end;

procedure InitTimer;
begin
  TimerTicks := 0;
  LastUpdateTick := 0;

  { Save old timer interrupt vector }
  GetIntVec($08, OldTimerInt);

  { Install our timer handler }
  SetIntVec($08, @TimerInterrupt);

  { Set timer to 100 Hz }
  SetTimerFreq(TIMER_FREQ);
end;

procedure RestoreTimer;
begin
  { Restore original timer frequency (18.2 Hz) }
  SetTimerFreq(18);

  { Restore original interrupt vector }
  SetIntVec($08, OldTimerInt);
end;

procedure InitGame;
begin
  { Initialize player in center of screen }
  Player.X := 160;
  Player.Y := 100;
  Player.VelX := 2;
  Player.VelY := 1;
  Player.Color := 15;  { White }

  GameRunning := True;
  FrameCount := 0;
end;

procedure UpdateGameLogic;
begin
  { Move player }
  Inc(Player.X, Player.VelX);
  Inc(Player.Y, Player.VelY);

  { Bounce off screen edges }
  if (Player.X <= 0) or (Player.X >= 319) then
    Player.VelX := -Player.VelX;

  if (Player.Y <= 0) or (Player.Y >= 199) then
    Player.VelY := -Player.VelY;

  { Check for ESC key }
  if KeyPressed then
  begin
    if ReadKey = #27 then  { ESC }
      GameRunning := False;
  end;
end;

procedure DrawPixel(FB: PFrameBuffer; X, Y: Integer; Color: Byte);
begin
  if (X >= 0) and (X < 320) and (Y >= 0) and (Y < 200) then
    FB^[Y * 320 + X] := Color;
end;

procedure DrawRect(FB: PFrameBuffer; X, Y, W, H: Integer; Color: Byte);
var
  i, j: Integer;
begin
  for j := 0 to H - 1 do
    for i := 0 to W - 1 do
      DrawPixel(FB, X + i, Y + j, Color);
end;

procedure RenderFrame;
var
  i, y, offset: Integer;
  col: Byte;
begin
  { Draw animated gradient background - optimized }
  offset := 0;
  for y := 0 to 199 do
  begin
    col := ((y + (FrameCount shr 2)) mod 240) + 16;  { Use rainbow colors, slower animation }
    FillChar(FrameBuffer^[offset], 320, col);  { Fast line fill }
    Inc(offset, 320);
  end;

  { Draw some decorative elements }
  for i := 0 to 15 do
  begin
    DrawPixel(FrameBuffer, i * 20, (FrameCount + i * 12) mod 200, 15);  { White dots }
  end;

  { Draw player as 8x8 square }
  DrawRect(FrameBuffer, Player.X - 4, Player.Y - 4, 8, 8, 15);  { White player }

  { Draw player trail effect }
  DrawPixel(FrameBuffer, Player.X, Player.Y, 14);  { Yellow center dot }

  { Draw FPS counter bar in top-left }
  for i := 0 to (FrameCount mod 70) do
    DrawPixel(FrameBuffer, i, 0, 0);  { Black bar }

  { Blit to screen }
  RenderFrameBuffer(FrameBuffer);

  Inc(FrameCount);
end;

procedure GameLoop;
var
  TicksSinceUpdate: LongInt;
begin
  while GameRunning do
  begin
    { Update game logic at fixed rate (60 Hz) }
    TicksSinceUpdate := TimerTicks - LastUpdateTick;

    if TicksSinceUpdate >= TICKS_PER_UPDATE then
    begin
      UpdateGameLogic;
      LastUpdateTick := TimerTicks;
    end;

    { Render frame and sync to VBlank }
    RenderFrame;
    WaitForVSync;  { Caps rendering at ~70 FPS, prevents tearing }
  end;
end;

procedure SetupPalette;
var
  Palette: TPalette;
  i: Integer;
begin
  { Create colorful VGA palette }

  { Colors 0-15: Standard VGA colors }
  Palette[0].R := 0;  Palette[0].G := 0;  Palette[0].B := 0;   { Black }
  Palette[1].R := 0;  Palette[1].G := 0;  Palette[1].B := 42;  { Blue }
  Palette[2].R := 0;  Palette[2].G := 42; Palette[2].B := 0;   { Green }
  Palette[3].R := 0;  Palette[3].G := 42; Palette[3].B := 42;  { Cyan }
  Palette[4].R := 42; Palette[4].G := 0;  Palette[4].B := 0;   { Red }
  Palette[5].R := 42; Palette[5].G := 0;  Palette[5].B := 42;  { Magenta }
  Palette[6].R := 42; Palette[6].G := 21; Palette[6].B := 0;   { Brown }
  Palette[7].R := 42; Palette[7].G := 42; Palette[7].B := 42;  { Light Gray }
  Palette[8].R := 21; Palette[8].G := 21; Palette[8].B := 21;  { Dark Gray }
  Palette[9].R := 21; Palette[9].G := 21; Palette[9].B := 63;  { Light Blue }
  Palette[10].R := 21; Palette[10].G := 63; Palette[10].B := 21; { Light Green }
  Palette[11].R := 21; Palette[11].G := 63; Palette[11].B := 63; { Light Cyan }
  Palette[12].R := 63; Palette[12].G := 21; Palette[12].B := 21; { Light Red }
  Palette[13].R := 63; Palette[13].G := 21; Palette[13].B := 63; { Light Magenta }
  Palette[14].R := 63; Palette[14].G := 63; Palette[14].B := 21; { Yellow }
  Palette[15].R := 63; Palette[15].G := 63; Palette[15].B := 63; { White }

  { Colors 16-255: Color gradient/rainbow }
  for i := 16 to 255 do
  begin
    if i < 80 then
    begin
      { Red to Yellow }
      Palette[i].R := 63;
      Palette[i].G := ((i - 16) * 63) div 64;
      Palette[i].B := 0;
    end
    else if i < 144 then
    begin
      { Yellow to Green }
      Palette[i].R := 63 - (((i - 80) * 63) div 64);
      Palette[i].G := 63;
      Palette[i].B := 0;
    end
    else if i < 208 then
    begin
      { Green to Cyan }
      Palette[i].R := 0;
      Palette[i].G := 63;
      Palette[i].B := ((i - 144) * 63) div 64;
    end
    else
    begin
      { Cyan to Blue }
      Palette[i].R := 0;
      Palette[i].G := 63 - (((i - 208) * 63) div 47);
      Palette[i].B := 63;
    end;
  end;

  SetPalette(Palette);
end;

begin
  ClrScr;
  WriteLn('Hybrid Timing Game Loop Example');
  WriteLn('================================');
  WriteLn;
  WriteLn('This demo shows:');
  WriteLn('  - Game logic updates at fixed 60 Hz');
  WriteLn('  - Graphics rendering at ~70 Hz (VGA VSync)');
  WriteLn('  - Smooth animation with no tearing');
  WriteLn;
  WriteLn('Watch the white square bounce around.');
  WriteLn('The top line shows frame counter.');
  WriteLn;
  WriteLn('Press ESC to exit...');
  WriteLn;
  Write('Press any key to start...');
  ReadKey;

  { Initialize subsystems }
  InitTimer;
  InitVGA;
  FrameBuffer := CreateFrameBuffer;
  SetupPalette;

  { Initialize game }
  InitGame;

  { Main game loop }
  GameLoop;

  { Cleanup }
  FreeFrameBuffer(FrameBuffer);
  CloseVGA;
  RestoreTimer;

  { Show statistics }
  ClrScr;
  WriteLn('Game ended.');
  WriteLn('Total frames rendered: ', FrameCount);
  WriteLn('Total timer ticks: ', TimerTicks);

  { Calculate average FPS safely }
  if TimerTicks > 0 then
    WriteLn('Average FPS: ', (FrameCount * TIMER_FREQ) div TimerTicks)
  else
    WriteLn('Average FPS: N/A (too short)');
end.
