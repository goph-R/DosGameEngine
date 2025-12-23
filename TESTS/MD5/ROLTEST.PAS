{ ROLTEST.PAS - Test ROL function specifically }

program ROLTest;

uses MD5;  { To access the ROL function }

{ We need to expose ROL for testing - let's create our own copy }
function TestROL(x: LongInt; n: Byte): LongInt; assembler;
asm
  mov   cl, n       { Load shift count into CL }
  mov   ax, word ptr x     { Load low word of x }
  mov   dx, word ptr x+2   { Load high word of x }

  or    cl, cl      { Check if n = 0 }
  jz    @done

  { Rotate DX:AX left by CL bits }
@loop:
  shl   ax, 1       { Shift low word left }
  rcl   dx, 1       { Rotate high word left with carry }
  jnc   @nocarry
  or    ax, 1       { Set bit 0 if carry from DX }
@nocarry:
  dec   cl
  jnz   @loop

@done:
  { Return value in DX:AX }
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
  WriteLn('ROL Function Test');
  WriteLn('=================');
  WriteLn;

  { Test 1: ROL by 0 (should return unchanged) }
  result := TestROL($12345678, 0);
  WriteLn('ROL($12345678, 0)');
  WriteLn('Expected: $12345678');
  Write('Got:      $');
  WriteLn(HexStr(result, 8));
  if result = $12345678 then
    WriteLn('PASS')
  else
    WriteLn('FAIL ***');
  WriteLn;

  { Test 2: ROL by 1 }
  result := TestROL($12345678, 1);
  WriteLn('ROL($12345678, 1)');
  WriteLn('Expected: $2468ACF0');
  Write('Got:      $');
  WriteLn(HexStr(result, 8));
  if result = $2468ACF0 then
    WriteLn('PASS')
  else
    WriteLn('FAIL ***');
  WriteLn;

  { Test 3: ROL by 7 (used in MD5) }
  result := TestROL($67452301, 7);
  WriteLn('ROL($67452301, 7)');
  WriteLn('Expected: $3A291808');
  Write('Got:      $');
  WriteLn(HexStr(result, 8));
  if result = LongInt($3A291808) then
    WriteLn('PASS')
  else
    WriteLn('FAIL ***');
  WriteLn;

  { Test 4: ROL with high bit set }
  result := TestROL(LongInt($80000001), 1);
  WriteLn('ROL($80000001, 1)');
  WriteLn('Expected: $00000003');
  Write('Got:      $');
  WriteLn(HexStr(result, 8));
  if result = $00000003 then
    WriteLn('PASS')
  else
    WriteLn('FAIL ***');
  WriteLn;

  { Test 5: ROL by 16 (swap words) }
  result := TestROL($12345678, 16);
  WriteLn('ROL($12345678, 16)');
  WriteLn('Expected: $56781234');
  Write('Got:      $');
  WriteLn(HexStr(result, 8));
  if result = $56781234 then
    WriteLn('PASS')
  else
    WriteLn('FAIL ***');

  WriteLn;
  WriteLn('All tests complete!');
end.
