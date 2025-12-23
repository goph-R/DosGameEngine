{ MD5SEQ.PAS - Test sequence of MD5 operations }

program MD5SequenceTest;

const
  { First 4 T constants }
  T: array[0..3] of LongInt = (
    $d76aa478, $e8c7b756, $242070db, $c1bdceee
  );

function TestF(x, y, z: LongInt): LongInt; assembler;
asm
  mov   ax, word ptr x
  mov   dx, word ptr x+2
  and   ax, word ptr y
  and   dx, word ptr y+2
  mov   bx, ax
  mov   cx, dx

  mov   ax, word ptr x
  mov   dx, word ptr x+2
  not   ax
  not   dx
  and   ax, word ptr z
  and   dx, word ptr z+2

  or    ax, bx
  or    dx, cx
end;

function TestROL(x: LongInt; n: Byte): LongInt; assembler;
asm
  mov   cl, n
  mov   ax, word ptr x
  mov   dx, word ptr x+2

  or    cl, cl
  jz    @done

@loop:
  shl   ax, 1
  rcl   dx, 1
  jnc   @nocarry
  or    ax, 1
@nocarry:
  dec   cl
  jnz   @loop

@done:
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
  a, b, c, d: LongInt;
  x: array[0..3] of LongInt;

begin
  WriteLn('MD5 First 4 Rounds Test');
  WriteLn('========================');
  WriteLn;

  { Initial MD5 state }
  a := LongInt($67452301);
  b := LongInt($efcdab89);
  c := LongInt($98badcfe);
  d := LongInt($10325476);

  { First 4 words for string "a" (padded) }
  x[0] := $00000061;  { 'a' }
  x[1] := $00000080;  { padding }
  x[2] := $00000000;
  x[3] := $00000000;

  WriteLn('Initial state:');
  WriteLn('a=$', HexStr(a, 8), ' b=$', HexStr(b, 8));
  WriteLn('c=$', HexStr(c, 8), ' d=$', HexStr(d, 8));
  WriteLn;

  { Round 1 - exactly as MD5 does it }
  a := b + TestROL(a + TestF(b, c, d) + x[0] + T[0], 7);
  WriteLn('After round 1: a=$', HexStr(a, 8));

  d := a + TestROL(d + TestF(a, b, c) + x[1] + T[1], 12);
  WriteLn('After round 2: d=$', HexStr(d, 8));

  c := d + TestROL(c + TestF(d, a, b) + x[2] + T[2], 17);
  WriteLn('After round 3: c=$', HexStr(c, 8));

  b := c + TestROL(b + TestF(c, d, a) + x[3] + T[3], 22);
  WriteLn('After round 4: b=$', HexStr(b, 8));

  WriteLn;
  WriteLn('Final values after 4 rounds:');
  WriteLn('a=$', HexStr(a, 8));
  WriteLn('b=$', HexStr(b, 8));
  WriteLn('c=$', HexStr(c, 8));
  WriteLn('d=$', HexStr(d, 8));
  WriteLn;
  WriteLn('These should match on both platforms!');
end.
