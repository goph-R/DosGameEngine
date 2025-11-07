unit RTCTimer;

interface

const
  CMOS_PORT   = $70;
  CMOS_DATA   = $71;
  PIC1_OCW1   = $21;
  PIC2_OCW1   = $A1;

var
  OldInt70     : pointer;
  RTC_Ticks    : LongInt;
  RTC_Freq_Hz  : Word;   { actual programmed periodic rate }

procedure InitRTC(DesiredFreq: Word);
procedure DoneRTC;
function GetTimeSeconds: Real;

implementation

uses Dos;

{ --- TP7-compatible I/O helpers --- }
function InPortB(PortAddr: Word): Byte;
begin
  InPortB := Port[PortAddr];
end;

procedure OutPortB(PortAddr: Word; Value: Byte);
begin
  Port[PortAddr] := Value;
end;

{ --- Interrupt flag helpers (CLI/STI) --- }
procedure DisableInts; assembler;
asm
  cli
end;

procedure EnableInts; assembler;
asm
  sti
end;

{ Preserve NMI bit when selecting CMOS register }
procedure SelectRTCReg(Reg: Byte);
var nmi: Byte;
begin
  nmi := InPortB(CMOS_PORT) and $80;                 { keep current NMI state }
  OutPortB(CMOS_PORT, nmi or (Reg and $7F));
end;

function ReadRTC(Reg: Byte): Byte;
begin
  SelectRTCReg(Reg);
  ReadRTC := InPortB(CMOS_DATA);
end;

procedure WriteRTC(Reg, Value: Byte);
var nmi: Byte;
begin
  nmi := InPortB(CMOS_PORT) and $80;
  OutPortB(CMOS_PORT, nmi or (Reg and $7F));
  OutPortB(CMOS_DATA, Value);
end;

{ Wait until Update-In-Progress (UIP) = 0 before touching Reg A }
procedure WaitUIPClear;
begin
  while (ReadRTC($0A) and $80) <> 0 do ;            { bit7 of Reg A = UIP }
end;

{ --- IRQ8 handler --- }
procedure NewInt70; interrupt;
var tmp: Byte;
begin
  Inc(RTC_Ticks);
  tmp := ReadRTC($0C);                               { ACK RTC: read Reg C }
  OutPortB($A0, $20);                                { EOI to slave PIC }
  OutPortB($20, $20);                                { EOI to master PIC }
end;

{ Compute RateSelect nibble (3..15) and the actual frequency }
procedure ComputeRateSelect(Desired: Word; var RS: Byte; var ActualHz: Word);
{ RTC periodic freq = 32768 >> (RS-1), valid RS = 3..15
  RS=6->1024, 7->512, 8->256, ... 15->2 }
var r: Byte; f: LongInt;
begin
  if Desired < 2 then Desired := 2;
  if Desired > 8192 then Desired := 8192;

  r := 3;
  f := 32768 shr (r-1);
  while (f > Desired) and (r < 15) do
  begin
    Inc(r);
    f := 32768 shr (r-1);
  end;

  RS := r;
  if f > 8192 then f := 8192;
  if f < 2 then f := 2;
  ActualHz := Word(f);
end;

procedure InitRTC(DesiredFreq: Word);
var regA, regB, RS: Byte;
    dummy: Byte;
begin
  DisableInts;                                      { CLI }

  { Install handler first }
  GetIntVec($70, OldInt70);
  SetIntVec($70, @NewInt70);

  { Disable periodic interrupt while reprogramming }
  regB := ReadRTC($0B);
  regB := regB and not $40;                         { PIE = 0 }
  WriteRTC($0B, regB);
  dummy := ReadRTC($0C);                            { clear any pending }

  { Compute rate select and write Reg A safely }
  ComputeRateSelect(DesiredFreq, RS, RTC_Freq_Hz);
  WaitUIPClear;
  regA := ReadRTC($0A);
  regA := (regA and $F0) or (RS and $0F);
  WriteRTC($0A, regA);

  { Enable periodic interrupts (PIE) }
  regB := ReadRTC($0B);
  regB := regB or $40;                              { PIE = 1 }
  WriteRTC($0B, regB);

  dummy := ReadRTC($0C);                            { arm/clear pending }

  { Unmask IRQ8 (slave bit0) - IRQ2 cascade should already be unmasked by BIOS }
  OutPortB(PIC2_OCW1, InPortB(PIC2_OCW1) and not $01);

  RTC_Ticks := 0;
  EnableInts;                                       { STI }
end;

procedure DoneRTC;
var regB: Byte;
begin
  DisableInts;

  { Mask IRQ8 only - NEVER mask IRQ2 cascade or slave PIC (mouse, etc.) will break! }
  OutPortB(PIC2_OCW1, InPortB(PIC2_OCW1) or $01);

  { Disable periodic interrupt }
  regB := ReadRTC($0B);
  regB := regB and not $40;
  WriteRTC($0B, regB);

  SetIntVec($70, OldInt70);
  EnableInts;
end;

function GetTimeSeconds: Real;
begin
  if RTC_Freq_Hz = 0 then
    GetTimeSeconds := 0.0
  else
    GetTimeSeconds := RTC_Ticks / RTC_Freq_Hz;
end;

end.
