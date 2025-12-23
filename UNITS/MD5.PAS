{ MD5.PAS - MD5 Message-Digest Algorithm (RFC 1321)

  128-bit cryptographic hash function (1992, Ron Rivest)

  Usage:
    var ctx: TMD5Context; digest: TMD5Digest;
    MD5Init(ctx);
    MD5Update(ctx, @data, length);
    MD5Final(digest, ctx);
    WriteLn(MD5DigestToHex(digest));

  Or simplified:
    WriteLn('Hash: ', MD5String('hello'));
    if MD5File('DATA\IMAGE.PCX', digest) then ...
}

unit MD5;

interface

uses GenTypes;

type
  TMD5Digest = array[0..15] of Byte;  { 128-bit hash result }

  TMD5Context = record
    State: array[0..3] of LongInt;    { A, B, C, D state variables }
    Count: array[0..1] of LongInt;    { 64-bit bit count (low, high) }
    Buffer: array[0..63] of Byte;     { Input buffer (512 bits) }
  end;

{ Core MD5 functions }
procedure MD5Init(var ctx: TMD5Context);
procedure MD5Update(var ctx: TMD5Context; buf: Pointer; len: Word);
procedure MD5Final(var digest: TMD5Digest; var ctx: TMD5Context);

{ Convenience functions }
function MD5String(const s: String): String;  { Returns 32-char hex string }
function MD5File(const path: String; var digest: TMD5Digest): Boolean;
function MD5DigestToHex(const digest: TMD5Digest): String;
function MD5DigestEqual(const a, b: TMD5Digest): Boolean;

implementation

const
  { MD5 constants - derived from sine function }
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

{ Rotate left 32-bit value - assembly implementation for reliability }
function ROL(x: LongInt; n: Byte): LongInt; assembler;
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

{ MD5 auxiliary functions - assembly for CPU-independent bitwise operations }
function F(x, y, z: LongInt): LongInt; assembler;
asm
  mov   ax, word ptr x
  mov   dx, word ptr x+2
  and   ax, word ptr y       { x and y (low word) }
  and   dx, word ptr y+2     { x and y (high word) }
  mov   bx, ax               { Save low word in BX }
  mov   cx, dx               { Save high word in CX }

  mov   ax, word ptr x
  mov   dx, word ptr x+2
  not   ax                   { not x (low word) }
  not   dx                   { not x (high word) }
  and   ax, word ptr z       { (not x) and z (low word) }
  and   dx, word ptr z+2     { (not x) and z (high word) }

  or    ax, bx               { Combine results (low word) }
  or    dx, cx               { Combine results (high word) }
end;

function G(x, y, z: LongInt): LongInt; assembler;
asm
  mov   ax, word ptr x
  mov   dx, word ptr x+2
  and   ax, word ptr z       { x and z (low word) }
  and   dx, word ptr z+2     { x and z (high word) }
  mov   bx, ax               { Save low word in BX }
  mov   cx, dx               { Save high word in CX }

  mov   ax, word ptr z
  mov   dx, word ptr z+2
  not   ax                   { not z (low word) }
  not   dx                   { not z (high word) }
  and   ax, word ptr y       { y and (not z) (low word) }
  and   dx, word ptr y+2     { y and (not z) (high word) }

  or    ax, bx               { Combine results (low word) }
  or    dx, cx               { Combine results (high word) }
end;

function H(x, y, z: LongInt): LongInt; assembler;
asm
  mov   ax, word ptr x
  mov   dx, word ptr x+2
  xor   ax, word ptr y       { x xor y (low word) }
  xor   dx, word ptr y+2     { x xor y (high word) }
  xor   ax, word ptr z       { xor z (low word) }
  xor   dx, word ptr z+2     { xor z (high word) }
end;

function II(x, y, z: LongInt): LongInt; assembler;
asm
  mov   ax, word ptr z
  mov   dx, word ptr z+2
  not   ax                   { not z (low word) }
  not   dx                   { not z (high word) }
  or    ax, word ptr x       { x or (not z) (low word) }
  or    dx, word ptr x+2     { x or (not z) (high word) }
  xor   ax, word ptr y       { y xor result (low word) }
  xor   dx, word ptr y+2     { y xor result (high word) }
end;

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

{ MD5 transformation - processes one 64-byte block }
procedure MD5Transform(var state: array of LongInt; const block: array of Byte);
var
  a, b, c, d: LongInt;
  x: array[0..15] of LongInt;
  i: Integer;
  temp: LongInt;  { Temporary for breaking down complex expressions }
begin
  { Decode input block into 16 32-bit words (little-endian) }
  for i := 0 to 15 do
    x[i] := DecodeLongInt(block, i * 4);

  { Initialize working variables }
  a := state[0];
  b := state[1];
  c := state[2];
  d := state[3];

  { Round 1 - all operations broken down into simple steps }
  temp := a + F(b, c, d); temp := temp + x[0]; temp := temp + T[0]; temp := ROL(temp, 7); a := b + temp;
  temp := d + F(a, b, c); temp := temp + x[1]; temp := temp + T[1]; temp := ROL(temp, 12); d := a + temp;
  temp := c + F(d, a, b); temp := temp + x[2]; temp := temp + T[2]; temp := ROL(temp, 17); c := d + temp;
  temp := b + F(c, d, a); temp := temp + x[3]; temp := temp + T[3]; temp := ROL(temp, 22); b := c + temp;
  temp := a + F(b, c, d); temp := temp + x[4]; temp := temp + T[4]; temp := ROL(temp, 7); a := b + temp;
  temp := d + F(a, b, c); temp := temp + x[5]; temp := temp + T[5]; temp := ROL(temp, 12); d := a + temp;
  temp := c + F(d, a, b); temp := temp + x[6]; temp := temp + T[6]; temp := ROL(temp, 17); c := d + temp;
  temp := b + F(c, d, a); temp := temp + x[7]; temp := temp + T[7]; temp := ROL(temp, 22); b := c + temp;
  temp := a + F(b, c, d); temp := temp + x[8]; temp := temp + T[8]; temp := ROL(temp, 7); a := b + temp;
  temp := d + F(a, b, c); temp := temp + x[9]; temp := temp + T[9]; temp := ROL(temp, 12); d := a + temp;
  temp := c + F(d, a, b); temp := temp + x[10]; temp := temp + T[10]; temp := ROL(temp, 17); c := d + temp;
  temp := b + F(c, d, a); temp := temp + x[11]; temp := temp + T[11]; temp := ROL(temp, 22); b := c + temp;
  temp := a + F(b, c, d); temp := temp + x[12]; temp := temp + T[12]; temp := ROL(temp, 7); a := b + temp;
  temp := d + F(a, b, c); temp := temp + x[13]; temp := temp + T[13]; temp := ROL(temp, 12); d := a + temp;
  temp := c + F(d, a, b); temp := temp + x[14]; temp := temp + T[14]; temp := ROL(temp, 17); c := d + temp;
  temp := b + F(c, d, a); temp := temp + x[15]; temp := temp + T[15]; temp := ROL(temp, 22); b := c + temp;

  { Round 2 - all operations broken down into simple steps }
  temp := a + G(b, c, d); temp := temp + x[1]; temp := temp + T[16]; temp := ROL(temp, 5); a := b + temp;
  temp := d + G(a, b, c); temp := temp + x[6]; temp := temp + T[17]; temp := ROL(temp, 9); d := a + temp;
  temp := c + G(d, a, b); temp := temp + x[11]; temp := temp + T[18]; temp := ROL(temp, 14); c := d + temp;
  temp := b + G(c, d, a); temp := temp + x[0]; temp := temp + T[19]; temp := ROL(temp, 20); b := c + temp;
  temp := a + G(b, c, d); temp := temp + x[5]; temp := temp + T[20]; temp := ROL(temp, 5); a := b + temp;
  temp := d + G(a, b, c); temp := temp + x[10]; temp := temp + T[21]; temp := ROL(temp, 9); d := a + temp;
  temp := c + G(d, a, b); temp := temp + x[15]; temp := temp + T[22]; temp := ROL(temp, 14); c := d + temp;
  temp := b + G(c, d, a); temp := temp + x[4]; temp := temp + T[23]; temp := ROL(temp, 20); b := c + temp;
  temp := a + G(b, c, d); temp := temp + x[9]; temp := temp + T[24]; temp := ROL(temp, 5); a := b + temp;
  temp := d + G(a, b, c); temp := temp + x[14]; temp := temp + T[25]; temp := ROL(temp, 9); d := a + temp;
  temp := c + G(d, a, b); temp := temp + x[3]; temp := temp + T[26]; temp := ROL(temp, 14); c := d + temp;
  temp := b + G(c, d, a); temp := temp + x[8]; temp := temp + T[27]; temp := ROL(temp, 20); b := c + temp;
  temp := a + G(b, c, d); temp := temp + x[13]; temp := temp + T[28]; temp := ROL(temp, 5); a := b + temp;
  temp := d + G(a, b, c); temp := temp + x[2]; temp := temp + T[29]; temp := ROL(temp, 9); d := a + temp;
  temp := c + G(d, a, b); temp := temp + x[7]; temp := temp + T[30]; temp := ROL(temp, 14); c := d + temp;
  temp := b + G(c, d, a); temp := temp + x[12]; temp := temp + T[31]; temp := ROL(temp, 20); b := c + temp;

  { Round 3 - all operations broken down into simple steps }
  temp := a + H(b, c, d); temp := temp + x[5]; temp := temp + T[32]; temp := ROL(temp, 4); a := b + temp;
  temp := d + H(a, b, c); temp := temp + x[8]; temp := temp + T[33]; temp := ROL(temp, 11); d := a + temp;
  temp := c + H(d, a, b); temp := temp + x[11]; temp := temp + T[34]; temp := ROL(temp, 16); c := d + temp;
  temp := b + H(c, d, a); temp := temp + x[14]; temp := temp + T[35]; temp := ROL(temp, 23); b := c + temp;
  temp := a + H(b, c, d); temp := temp + x[1]; temp := temp + T[36]; temp := ROL(temp, 4); a := b + temp;
  temp := d + H(a, b, c); temp := temp + x[4]; temp := temp + T[37]; temp := ROL(temp, 11); d := a + temp;
  temp := c + H(d, a, b); temp := temp + x[7]; temp := temp + T[38]; temp := ROL(temp, 16); c := d + temp;
  temp := b + H(c, d, a); temp := temp + x[10]; temp := temp + T[39]; temp := ROL(temp, 23); b := c + temp;
  temp := a + H(b, c, d); temp := temp + x[13]; temp := temp + T[40]; temp := ROL(temp, 4); a := b + temp;
  temp := d + H(a, b, c); temp := temp + x[0]; temp := temp + T[41]; temp := ROL(temp, 11); d := a + temp;
  temp := c + H(d, a, b); temp := temp + x[3]; temp := temp + T[42]; temp := ROL(temp, 16); c := d + temp;
  temp := b + H(c, d, a); temp := temp + x[6]; temp := temp + T[43]; temp := ROL(temp, 23); b := c + temp;
  temp := a + H(b, c, d); temp := temp + x[9]; temp := temp + T[44]; temp := ROL(temp, 4); a := b + temp;
  temp := d + H(a, b, c); temp := temp + x[12]; temp := temp + T[45]; temp := ROL(temp, 11); d := a + temp;
  temp := c + H(d, a, b); temp := temp + x[15]; temp := temp + T[46]; temp := ROL(temp, 16); c := d + temp;
  temp := b + H(c, d, a); temp := temp + x[2]; temp := temp + T[47]; temp := ROL(temp, 23); b := c + temp;

  { Round 4 - all operations broken down into simple steps }
  temp := a + II(b, c, d); temp := temp + x[0]; temp := temp + T[48]; temp := ROL(temp, 6); a := b + temp;
  temp := d + II(a, b, c); temp := temp + x[7]; temp := temp + T[49]; temp := ROL(temp, 10); d := a + temp;
  temp := c + II(d, a, b); temp := temp + x[14]; temp := temp + T[50]; temp := ROL(temp, 15); c := d + temp;
  temp := b + II(c, d, a); temp := temp + x[5]; temp := temp + T[51]; temp := ROL(temp, 21); b := c + temp;
  temp := a + II(b, c, d); temp := temp + x[12]; temp := temp + T[52]; temp := ROL(temp, 6); a := b + temp;
  temp := d + II(a, b, c); temp := temp + x[3]; temp := temp + T[53]; temp := ROL(temp, 10); d := a + temp;
  temp := c + II(d, a, b); temp := temp + x[10]; temp := temp + T[54]; temp := ROL(temp, 15); c := d + temp;
  temp := b + II(c, d, a); temp := temp + x[1]; temp := temp + T[55]; temp := ROL(temp, 21); b := c + temp;
  temp := a + II(b, c, d); temp := temp + x[8]; temp := temp + T[56]; temp := ROL(temp, 6); a := b + temp;
  temp := d + II(a, b, c); temp := temp + x[15]; temp := temp + T[57]; temp := ROL(temp, 10); d := a + temp;
  temp := c + II(d, a, b); temp := temp + x[6]; temp := temp + T[58]; temp := ROL(temp, 15); c := d + temp;
  temp := b + II(c, d, a); temp := temp + x[13]; temp := temp + T[59]; temp := ROL(temp, 21); b := c + temp;
  temp := a + II(b, c, d); temp := temp + x[4]; temp := temp + T[60]; temp := ROL(temp, 6); a := b + temp;
  temp := d + II(a, b, c); temp := temp + x[11]; temp := temp + T[61]; temp := ROL(temp, 10); d := a + temp;
  temp := c + II(d, a, b); temp := temp + x[2]; temp := temp + T[62]; temp := ROL(temp, 15); c := d + temp;
  temp := b + II(c, d, a); temp := temp + x[9]; temp := temp + T[63]; temp := ROL(temp, 21); b := c + temp;

  { Add this chunk's hash to result so far }
  state[0] := state[0] + a;
  state[1] := state[1] + b;
  state[2] := state[2] + c;
  state[3] := state[3] + d;
end;

{ Initialize MD5 context }
procedure MD5Init(var ctx: TMD5Context);
begin
  ctx.Count[0] := 0;
  ctx.Count[1] := 0;

  { Load magic initialization constants (RFC 1321) }
  ctx.State[0] := LongInt($67452301);
  ctx.State[1] := LongInt($efcdab89);
  ctx.State[2] := LongInt($98badcfe);
  ctx.State[3] := LongInt($10325476);
end;

{ Update MD5 context with new data }
procedure MD5Update(var ctx: TMD5Context; buf: Pointer; len: Word);
var
  index, partLen, i: Word;
  p: PByte;
begin
  if len = 0 then Exit;

  p := PByte(buf);

  { Compute number of bytes mod 64 }
  index := Word((ctx.Count[0] shr 3) and $3F);

  { Update bit count }
  ctx.Count[0] := ctx.Count[0] + (LongInt(len) shl 3);
  if ctx.Count[0] < (LongInt(len) shl 3) then
    ctx.Count[1] := ctx.Count[1] + 1;
  ctx.Count[1] := ctx.Count[1] + (LongInt(len) shr 29);

  partLen := 64 - index;

  { Transform as many times as possible }
  if len >= partLen then
  begin
    Move(p^, ctx.Buffer[index], partLen);
    MD5Transform(ctx.State, ctx.Buffer);

    i := partLen;
    while i + 63 < len do
    begin
      Move(PByteArray(p)^[i], ctx.Buffer, 64);
      MD5Transform(ctx.State, ctx.Buffer);
      Inc(i, 64);
    end;
    index := 0;
  end
  else
    i := 0;

  { Buffer remaining input }
  Move(PByteArray(p)^[i], ctx.Buffer[index], len - i);
end;

{ Finalize MD5 hash and produce digest }
procedure MD5Final(var digest: TMD5Digest; var ctx: TMD5Context);
const
  Padding: array[0..63] of Byte = (
    $80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  );
var
  bits: array[0..7] of Byte;
  index, padLen: Word;
  i: Integer;
begin
  { Save bit count (little-endian) }
  EncodeLongInt(ctx.Count[0], bits, 0);
  EncodeLongInt(ctx.Count[1], bits, 4);

  { Pad to 56 bytes mod 64 }
  index := Word((ctx.Count[0] shr 3) and $3F);
  if index < 56 then
    padLen := 56 - index
  else
    padLen := 120 - index;
  MD5Update(ctx, @Padding, padLen);

  { Append length in bits }
  MD5Update(ctx, @bits, 8);

  { Store state in digest (little-endian) }
  for i := 0 to 3 do
    EncodeLongInt(ctx.State[i], digest, i * 4);
end;

{ Convert digest to 32-character hex string }
function MD5DigestToHex(const digest: TMD5Digest): String;
const
  HexChars: array[0..15] of Char = '0123456789abcdef';
var
  i: Integer;
  s: String;
begin
  s := '';
  for i := 0 to 15 do
  begin
    s := s + HexChars[digest[i] shr 4];
    s := s + HexChars[digest[i] and $0F];
  end;
  MD5DigestToHex := s;
end;

{ Hash a string and return hex result }
function MD5String(const s: String): String;
var
  ctx: TMD5Context;
  digest: TMD5Digest;
begin
  MD5Init(ctx);
  if Length(s) > 0 then
    MD5Update(ctx, @s[1], Length(s));
  MD5Final(digest, ctx);
  MD5String := MD5DigestToHex(digest);
end;

{ Hash a file and return digest }
function MD5File(const path: String; var digest: TMD5Digest): Boolean;
var
  f: File;
  ctx: TMD5Context;
  buf: array[0..4095] of Byte;
  bytesRead: Word;
begin
  MD5File := False;

  Assign(f, path);
  {$I-}
  Reset(f, 1);
  {$I+}
  if IOResult <> 0 then Exit;

  MD5Init(ctx);

  repeat
    {$I-}
    BlockRead(f, buf, SizeOf(buf), bytesRead);
    {$I+}
    if IOResult <> 0 then
    begin
      Close(f);
      Exit;
    end;

    if bytesRead > 0 then
      MD5Update(ctx, @buf, bytesRead);
  until bytesRead < SizeOf(buf);

  Close(f);
  MD5Final(digest, ctx);
  MD5File := True;
end;

{ Compare two digests for equality }
function MD5DigestEqual(const a, b: TMD5Digest): Boolean;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a[i] <> b[i] then
    begin
      MD5DigestEqual := False;
      Exit;
    end;
  MD5DigestEqual := True;
end;

end.
