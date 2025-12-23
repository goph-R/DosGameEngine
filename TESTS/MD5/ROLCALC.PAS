{ ROLCALC.PAS - Calculate correct ROL values }

program ROLCalc;

{ Manual ROL implementation in Pascal for verification }
function ROL_Pascal(x: LongInt; n: Byte): LongInt;
var
  i: Integer;
  highBit: Boolean;
  temp, value: LongInt;
begin
  value := x;
  for i := 1 to n do
  begin
    temp := LongInt($80000000);
    highBit := (value and temp) <> 0;
    value := value shl 1;
    if highBit then
      value := value or 1;
  end;
  ROL_Pascal := value;
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
  result: LongInt;

begin
  WriteLn('ROL Calculation Verification');
  WriteLn('============================');
  WriteLn;

  result := ROL_Pascal($67452301, 7);
  WriteLn('ROL_Pascal($67452301, 7) = $', HexStr(result, 8));
  WriteLn;

  result := ROL_Pascal($12345678, 1);
  WriteLn('ROL_Pascal($12345678, 1) = $', HexStr(result, 8));
  WriteLn;

  result := ROL_Pascal($80000001, 1);
  WriteLn('ROL_Pascal($80000001, 1) = $', HexStr(result, 8));
end.
