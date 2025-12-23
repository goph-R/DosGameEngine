{ ENCTEST.PAS - Test encode/decode LongInt functions }

program EncodeTest;

uses GenTypes;

{ Decode 4 bytes to LongInt (little-endian) - assembly for reliability }
function DecodeLongInt(const buf; ofs: Word): LongInt; assembler;
asm
  les   bx, buf
  add   bx, ofs
  mov   ax, es:[bx]      { Load bytes 0-1 }
  mov   dx, es:[bx+2]    { Load bytes 2-3 }
end;

{ Encode LongInt to 4 bytes (little-endian) - assembly for reliability }
procedure EncodeLongInt(value: LongInt; var buf; ofs: Word); assembler;
asm
  les   bx, buf
  add   bx, ofs
  mov   ax, word ptr value     { Load low word }
  mov   dx, word ptr value+2   { Load high word }
  mov   es:[bx], ax      { Store bytes 0-1 }
  mov   es:[bx+2], dx    { Store bytes 2-3 }
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
  buffer: array[0..63] of Byte;
  i: Integer;
  value, decoded: LongInt;

begin
  WriteLn('Testing Encode/Decode LongInt');
  WriteLn('==============================');
  WriteLn;

  { Fill buffer with known pattern }
  for i := 0 to 63 do
    buffer[i] := i;

  { Test 1: Decode from buffer at various offsets }
  WriteLn('Test 1: Decode from buffer');
  for i := 0 to 3 do
  begin
    decoded := DecodeLongInt(buffer, i * 4);
    WriteLn('Offset ', i * 4, ': $', HexStr(decoded, 8));
  end;
  WriteLn;

  { Expected results:
    Offset 0: $03020100 (bytes 0,1,2,3)
    Offset 4: $07060504 (bytes 4,5,6,7)
    Offset 8: $0B0A0908 (bytes 8,9,10,11)
    Offset 12: $0F0E0D0C (bytes 12,13,14,15)
  }

  { Test 2: Encode and then decode }
  WriteLn('Test 2: Encode then Decode');
  FillChar(buffer, SizeOf(buffer), 0);

  value := LongInt($12345678);
  EncodeLongInt(value, buffer, 0);
  WriteLn('Encoded $', HexStr(value, 8));
  WriteLn('Buffer bytes: $', HexStr(buffer[0], 2), ' $', HexStr(buffer[1], 2),
          ' $', HexStr(buffer[2], 2), ' $', HexStr(buffer[3], 2));
  decoded := DecodeLongInt(buffer, 0);
  WriteLn('Decoded: $', HexStr(decoded, 8));
  if decoded = value then
    WriteLn('PASS')
  else
    WriteLn('FAIL ***');
  WriteLn;

  { Test 3: MD5 initial state values }
  WriteLn('Test 3: MD5 initial state');
  FillChar(buffer, SizeOf(buffer), 0);

  EncodeLongInt(LongInt($67452301), buffer, 0);
  EncodeLongInt(LongInt($efcdab89), buffer, 4);
  EncodeLongInt(LongInt($98badcfe), buffer, 8);
  EncodeLongInt(LongInt($10325476), buffer, 12);

  WriteLn('A = $', HexStr(DecodeLongInt(buffer, 0), 8), ' (expected $67452301)');
  WriteLn('B = $', HexStr(DecodeLongInt(buffer, 4), 8), ' (expected $EFCDAB89)');
  WriteLn('C = $', HexStr(DecodeLongInt(buffer, 8), 8), ' (expected $98BADCFE)');
  WriteLn('D = $', HexStr(DecodeLongInt(buffer, 12), 8), ' (expected $10325476)');
  WriteLn;

  { Test 4: Test with "a" string }
  WriteLn('Test 4: String "a" first block');
  FillChar(buffer, SizeOf(buffer), 0);
  buffer[0] := Ord('a');
  buffer[1] := $80;  { Padding }
  { Length bits at end: 8 bits = $08 $00 $00 $00 ... }
  buffer[56] := $08;

  for i := 0 to 15 do
  begin
    decoded := DecodeLongInt(buffer, i * 4);
    WriteLn('x[', i, '] = $', HexStr(decoded, 8));
  end;

  WriteLn;
  WriteLn('All tests complete!');
end.
