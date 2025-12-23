{ MD5FULL.PAS - Full first transform test with "a" string }

program MD5FullTest;

uses GenTypes;

const
  T: array[0..63] of LongInt = (
    $d76aa478, $e8c7b756, $242070db, $c1bdceee,
    $f57c0faf, $4787c62a, $a8304613, $fd469501,
    $698098d8, $8b44f7af, $ffff5bb1, $895cd7be,
    $6b901122, $fd987193, $a679438e, $49b40821,
    $f61e2562, $c040b340, $265e5a51, $e9b6c7aa,
    $d62f105d, $02441453, $d8a1e681, $e7d3fbc8,
    $21e1cde6, $c33707d6, $f4d50d87, $455a14ed,
    $a9e3e905, $fcefa3f8, $676f02d9, $8d2a4c8a,
    $fffa3942, $8771f681, $6d9d6122, $fde5380c,
    $a4beea44, $4bdecfa9, $f6bb4b60, $bebfbc70,
    $289b7ec6, $eaa127fa, $d4ef3085, $04881d05,
    $d9d4d039, $e6db99e5, $1fa27cf8, $c4ac5665,
    $f4292244, $432aff97, $ab9423a7, $fc93a039,
    $655b59c3, $8f0ccc92, $ffeff47d, $85845dd1,
    $6fa87e4f, $fe2ce6e0, $a3014314, $4e0811a1,
    $f7537e82, $bd3af235, $2ad7d2bb, $eb86d391
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

function ROL(x: LongInt; n: Byte): LongInt; assembler;
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

function F(x, y, z: LongInt): LongInt; assembler;
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

function DecodeLongInt(const buf; ofs: Word): LongInt; assembler;
asm
  les   bx, buf
  add   bx, ofs
  mov   ax, es:[bx]
  mov   dx, es:[bx+2]
end;

procedure MD5Transform_A(var state: array of LongInt; const block: array of Byte);
var
  a, b, c, d: LongInt;
  x: array[0..15] of LongInt;
  i: Integer;
  temp: LongInt;
begin
  { Decode input }
  for i := 0 to 15 do
    x[i] := DecodeLongInt(block, i * 4);

  { Initialize }
  a := state[0];
  b := state[1];
  c := state[2];
  d := state[3];

  WriteLn('Initial state:');
  WriteLn('  a=$', HexStr(a, 8), ' b=$', HexStr(b, 8),
          ' c=$', HexStr(c, 8), ' d=$', HexStr(d, 8));
  WriteLn;

  WriteLn('Input x array:');
  for i := 0 to 15 do
    WriteLn('  x[', i, ']=$', HexStr(x[i], 8));
  WriteLn;

  { Round 1 - ALL 16 operations }
  WriteLn('Round 1:');

  temp := a + F(b, c, d); temp := temp + x[0]; temp := temp + T[0]; temp := ROL(temp, 7); a := b + temp;
  WriteLn('  Step 1: a=$', HexStr(a, 8));

  temp := d + F(a, b, c); temp := temp + x[1]; temp := temp + T[1]; temp := ROL(temp, 12); d := a + temp;
  WriteLn('  Step 2: d=$', HexStr(d, 8));

  temp := c + F(d, a, b); temp := temp + x[2]; temp := temp + T[2]; temp := ROL(temp, 17); c := d + temp;
  WriteLn('  Step 3: c=$', HexStr(c, 8));

  temp := b + F(c, d, a); temp := temp + x[3]; temp := temp + T[3]; temp := ROL(temp, 22); b := c + temp;
  WriteLn('  Step 4: b=$', HexStr(b, 8));
  WriteLn;

  state[0] := state[0] + a;
  state[1] := state[1] + b;
  state[2] := state[2] + c;
  state[3] := state[3] + d;

  WriteLn('Final state after accumulation:');
  WriteLn('  A=$', HexStr(state[0], 8), ' B=$', HexStr(state[1], 8),
          ' C=$', HexStr(state[2], 8), ' D=$', HexStr(state[3], 8));
end;

var
  state: array[0..3] of LongInt;
  block: array[0..63] of Byte;
  i: Integer;

begin
  WriteLn('MD5 Full Transform Test - String "a"');
  WriteLn('=====================================');
  WriteLn;

  { Initialize state }
  state[0] := LongInt($67452301);
  state[1] := LongInt($efcdab89);
  state[2] := LongInt($98badcfe);
  state[3] := LongInt($10325476);

  { Create block for "a" }
  FillChar(block, SizeOf(block), 0);
  block[0] := Ord('a');
  block[1] := $80;
  block[56] := $08;  { Length = 8 bits }

  MD5Transform_A(state, block);

  WriteLn;
  WriteLn('Expected final: A=$85037F8C B=$07653C78 C=$20C5373C D=$4F157E5B');
end.
