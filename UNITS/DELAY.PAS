unit Delay;

{ Custom delay routine to replace Crt.Delay }
{ Avoids Runtime Error 200 on fast CPUs }

interface

{ Delay for specified milliseconds }
procedure DelayMS(Milliseconds: Word);

implementation

{ BIOS timer tick counter at 0040:006C (increments ~18.2 times/second) }
function GetBIOSTicks: LongInt;
var
  Ticks: LongInt absolute $0040:$006C;
begin
  GetBIOSTicks := Ticks;
end;

procedure DelayMS(Milliseconds: Word);
var
  StartTicks, CurrentTicks, TargetTicks: LongInt;
  TicksToWait: LongInt;
begin
  { BIOS timer runs at 18.2065 Hz (1193182 / 65536 ticks per second) }
  { To convert milliseconds to ticks: ticks = ms * 18.2065 / 1000 }
  { Simplified: ticks = ms * 182 / 10000 (close approximation) }

  TicksToWait := (LongInt(Milliseconds) * 182) div 10000;

  { Minimum 1 tick for small delays }
  if TicksToWait < 1 then
    TicksToWait := 1;

  StartTicks := GetBIOSTicks;
  TargetTicks := StartTicks + TicksToWait;

  { Handle midnight rollover (timer resets at midnight) }
  repeat
    CurrentTicks := GetBIOSTicks;
  until (CurrentTicks >= TargetTicks) or (CurrentTicks < StartTicks);
end;

end.
