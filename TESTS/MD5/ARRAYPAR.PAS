{ ARRAYPAR.PAS - Test open array parameter access }

program ArrayParamTest;

procedure ModifyArray(var arr: array of LongInt);
begin
  arr[0] := arr[0] + LongInt($11111111);
  arr[1] := arr[1] + LongInt($22222222);
  arr[2] := arr[2] + LongInt($33333333);
  arr[3] := arr[3] + LongInt($44444444);
end;

function HexStr(value: LongInt; digits: Integer): String;
const
  HexChars: array[0..15] of Char = '0123456789ABCDEF';
var
  s: String;
  i: Integer;
  nibble: Byte;
begin
  s := '';
  for i := digits - 1 downto 0 do
  begin
    nibble := Byte((value shr (i * 4)) and $0F);
    s := s + HexChars[nibble];
  end;
  HexStr := s;
end;

var
  state: array[0..3] of LongInt;
  i: Integer;

begin
  WriteLn('Open Array Parameter Test');
  WriteLn('=========================');
  WriteLn;

  state[0] := LongInt($67452301);
  state[1] := LongInt($efcdab89);
  state[2] := LongInt($98badcfe);
  state[3] := LongInt($10325476);

  WriteLn('Before:');
  for i := 0 to 3 do
    WriteLn('state[', i, '] = $', HexStr(state[i], 8));
  WriteLn;

  ModifyArray(state);

  WriteLn('After (should add $11111111, $22222222, $33333333, $44444444):');
  for i := 0 to 3 do
    WriteLn('state[', i, '] = $', HexStr(state[i], 8));
  WriteLn;

  WriteLn('Expected:');
  WriteLn('state[0] = $78563412');
  WriteLn('state[1] = $11EFCDAB');
  WriteLn('state[2] = $CBFE0231');
  WriteLn('state[3] = $547658BA');
  WriteLn;

  if (state[0] = LongInt($78563412)) and
     (state[1] = LongInt($11EFCDAB)) and
     (state[2] = LongInt($CBFE0231)) and
     (state[3] = LongInt($547658BA)) then
    WriteLn('PASS')
  else
    WriteLn('FAIL ***');
end.
