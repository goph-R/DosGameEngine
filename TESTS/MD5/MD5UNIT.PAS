{ MD5UNIT.PAS - Test using actual MD5 unit functions }

program MD5UnitTest;

uses MD5;

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
  hash: String;

begin
  WriteLn('MD5 Unit Direct Test');
  WriteLn('====================');
  WriteLn;

  { Test the actual MD5String function from the unit }
  hash := MD5String('a');

  WriteLn('MD5("a") = ', hash);
  WriteLn('Expected = 0cc175b9c0f1b6a831c399e269772661');
  WriteLn;

  if hash = '0cc175b9c0f1b6a831c399e269772661' then
    WriteLn('PASS')
  else
    WriteLn('FAIL ***');

  WriteLn;

  { Test empty string }
  hash := MD5String('');
  WriteLn('MD5("") = ', hash);
  WriteLn('Expected = d41d8cd98f00b204e9800998ecf8427e');
  WriteLn;

  if hash = 'd41d8cd98f00b204e9800998ecf8427e' then
    WriteLn('PASS')
  else
    WriteLn('FAIL ***');
end.
