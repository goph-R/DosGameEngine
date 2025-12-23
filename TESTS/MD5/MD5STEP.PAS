{ MD5STEP.PAS - Test individual MD5 round operation }

program MD5StepTest;

uses MD5;  { To access F, ROL functions }

{ Recreate the assembly functions locally for testing }
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
  x0: LongInt;
  T0: LongInt;
  temp, result: LongInt;

begin
  WriteLn('MD5 First Round Operation Test');
  WriteLn('================================');
  WriteLn;

  { Initial MD5 state }
  a := LongInt($67452301);
  b := LongInt($efcdab89);
  c := LongInt($98badcfe);
  d := LongInt($10325476);

  { First word of "a" = $61 (rest zeros) in little-endian }
  x0 := $00000061;

  { First T constant }
  T0 := LongInt($d76aa478);

  WriteLn('Initial values:');
  WriteLn('a = $', HexStr(a, 8));
  WriteLn('b = $', HexStr(b, 8));
  WriteLn('c = $', HexStr(c, 8));
  WriteLn('d = $', HexStr(d, 8));
  WriteLn('x[0] = $', HexStr(x0, 8));
  WriteLn('T[0] = $', HexStr(T0, 8));
  WriteLn;

  { First MD5 round: a := b + ROL(a + F(b, c, d) + x[0] + T[0], 7); }
  WriteLn('Step by step:');

  temp := TestF(b, c, d);
  WriteLn('F(b,c,d) = $', HexStr(temp, 8));

  temp := a + temp;
  WriteLn('a + F(b,c,d) = $', HexStr(temp, 8));

  temp := temp + x0;
  WriteLn('+ x[0] = $', HexStr(temp, 8));

  temp := temp + T0;
  WriteLn('+ T[0] = $', HexStr(temp, 8));

  temp := TestROL(temp, 7);
  WriteLn('ROL(7) = $', HexStr(temp, 8));

  result := b + temp;
  WriteLn('+ b = $', HexStr(result, 8));
  WriteLn;

  WriteLn('Final a = $', HexStr(result, 8));
  WriteLn;
  WriteLn('This value should be the same on both platforms!');
end.
