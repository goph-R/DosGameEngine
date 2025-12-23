{ CONSTACC.PAS - Test constant array access }

program ConstAccessTest;

const
  TestArray: array[0..3] of LongInt = (
    $d76aa478, $e8c7b756, $242070db, $c1bdceee
  );

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
  i: Integer;
  value: LongInt;

begin
  WriteLn('Constant Array Access Test');
  WriteLn('==========================');
  WriteLn;

  for i := 0 to 3 do
  begin
    value := TestArray[i];
    Write('TestArray[', i, '] = $', HexStr(value, 8));
    WriteLn;
  end;

  WriteLn;
  Write('Expected: $D76AA478, $E8C7B756, $242070DB, $C1BDCEEE');
  WriteLn;
  WriteLn;

  if (TestArray[0] = LongInt($d76aa478)) and
     (TestArray[1] = LongInt($e8c7b756)) and
     (TestArray[2] = LongInt($242070db)) and
     (TestArray[3] = LongInt($c1bdceee)) then
    WriteLn('PASS')
  else
    WriteLn('FAIL ***');
end.
