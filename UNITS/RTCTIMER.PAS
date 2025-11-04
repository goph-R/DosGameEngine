unit RTCTimer;

interface

const
  RTC_FREQ = 1024;     { desired interrupts per second (2..8192) }
  CMOS_PORT = $70;
  CMOS_DATA = $71;
  PIC1_OCW1 = $21;
  PIC2_OCW1 = $A1;

var
  OldInt70 : pointer;
  RTC_Ticks: LongInt;

procedure InitRTC(Freq: Word);
procedure DoneRTC;
function GetTimeSeconds: Real;

implementation

uses Dos;

{ --- Low-level CMOS/RTC helpers --- }

procedure WriteRTC(Reg, Value: Byte);
begin
  Port[CMOS_PORT] := Reg;
  Port[CMOS_DATA] := Value;
end;

function ReadRTC(Reg: Byte): Byte;
begin
  Port[CMOS_PORT] := Reg;
  ReadRTC := Port[CMOS_DATA];
end;

{ --- IRQ8 handler --- }

procedure NewInt70; interrupt;
var
  tmp: Byte;
begin
  Inc(RTC_Ticks);

  { Read register C to clear the IRQ source bit }
  tmp := ReadRTC($0C);

  { Send EOI to both PICs }
  Port[$A0] := $20;
  Port[$20] := $20;
end;

{ --- Initialization --- }

procedure InitRTC(Freq: Word);
var
  rateSel, regA, regB: Byte;
  logval: Byte;
begin
  { Determine RateSelect code: 32768 >> (rateSel-1) = Freq }
  logval := 1;
  rateSel := 1;
  while (Freq < (32768 shr (rateSel - 1))) and (rateSel < 15) do
    Inc(rateSel);
  if rateSel < 3 then rateSel := 3;  { minimum 122 µs period }

  { Disable NMIs while programming CMOS }
  Port[CMOS_PORT] := $8A;  regA := Port[CMOS_DATA];
  regA := (regA and $F0) or rateSel;
  WriteRTC($8A, regA);

  Port[CMOS_PORT] := $8B;  regB := Port[CMOS_DATA];
  regB := regB or $40;     { enable periodic interrupt }
  WriteRTC($8B, regB);

  { Unmask IRQ8 on both PICs }
  Port[PIC2_OCW1] := Port[PIC2_OCW1] and not $01;
  Port[PIC1_OCW1] := Port[PIC1_OCW1] and not $08;

  { Install handler }
  GetIntVec($70, OldInt70);
  SetIntVec($70, @NewInt70);

  RTC_Ticks := 0;
end;

procedure DoneRTC;
var
  regB: Byte;
begin
  { Disable periodic interrupt }
  Port[CMOS_PORT] := $8B; regB := Port[CMOS_DATA];
  regB := regB and not $40;
  WriteRTC($8B, regB);

  SetIntVec($70, OldInt70);
end;

function GetTimeSeconds: Real;
begin
  GetTimeSeconds := RTC_Ticks / RTC_FREQ;
end;

end.