{ PARAMTST.PAS - Test assembly parameter access }

program ParamTest;

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

function TestParam(x: LongInt; y: Byte): LongInt; assembler;
asm
  mov   ax, word ptr x
  mov   dx, word ptr x+2
  { Return x unchanged }
end;

function TestParam2(a, b, c: LongInt): LongInt; assembler;
asm
  { Return b }
  mov   ax, word ptr b
  mov   dx, word ptr b+2
end;

var
  result: LongInt;

begin
  WriteLn('Assembly Parameter Access Test');
  WriteLn('===============================');
  WriteLn;

  result := TestParam($12345678, 5);
  WriteLn('TestParam($12345678, 5)');
  WriteLn('Expected: $12345678');
  Write('Got:      $');
  WriteLn(HexStr(result, 8));
  if result = $12345678 then
    WriteLn('PASS')
  else
    WriteLn('FAIL ***');
  WriteLn;

  result := TestParam2($11111111, $22222222, $33333333);
  WriteLn('TestParam2($11111111, $22222222, $33333333) - should return b');
  WriteLn('Expected: $22222222');
  Write('Got:      $');
  WriteLn(HexStr(result, 8));
  if result = $22222222 then
    WriteLn('PASS')
  else
    WriteLn('FAIL ***');

  WriteLn;
  WriteLn('All tests complete!');
end.
