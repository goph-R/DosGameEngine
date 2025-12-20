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

{ Rotate left 32-bit value - 16-bit compatible }
{ Bit-by-bit implementation to avoid signed integer shift issues }
function ROL(x: LongInt; n: Byte): LongInt;
var
  src, dst: LongInt;
  srcBytes: array[0..3] of Byte absolute src;
  dstBytes: array[0..3] of Byte absolute dst;
  bitPos, srcByte, srcBit, dstByte, dstBit: Integer;
begin
  if n = 0 then
  begin
    ROL := x;
    Exit;
  end;

  src := x;
  dst := 0;

  { Rotate each bit individually }
  for bitPos := 0 to 31 do
  begin
    srcByte := bitPos shr 3;          { bitPos div 8 }
    srcBit := bitPos and 7;           { bitPos mod 8 }

    dstByte := ((bitPos + n) and 31) shr 3;
    dstBit := ((bitPos + n) and 31) and 7;

    if (srcBytes[srcByte] and (1 shl srcBit)) <> 0 then
      dstBytes[dstByte] := dstBytes[dstByte] or (1 shl dstBit);
  end;

  ROL := dst;
end;

{ MD5 auxiliary functions }
function F(x, y, z: LongInt): LongInt;
begin
  F := (x and y) or ((not x) and z);
end;

function G(x, y, z: LongInt): LongInt;
begin
  G := (x and z) or (y and (not z));
end;

function H(x, y, z: LongInt): LongInt;
begin
  H := x xor y xor z;
end;

function II(x, y, z: LongInt): LongInt;
begin
  II := y xor (x or (not z));
end;

{ MD5 transformation - processes one 64-byte block }
procedure MD5Transform(var state: array of LongInt; const block: array of Byte);
var
  a, b, c, d: LongInt;
  x: array[0..15] of LongInt;
  i: Integer;
begin
  { Decode input block into 16 32-bit words (little-endian) }
  for i := 0 to 15 do
  begin
    x[i] := LongInt(block[i * 4]) or
            (LongInt(block[i * 4 + 1]) shl 8) or
            (LongInt(block[i * 4 + 2]) shl 16) or
            (LongInt(block[i * 4 + 3]) shl 24);
  end;

  { Initialize working variables }
  a := state[0];
  b := state[1];
  c := state[2];
  d := state[3];

  { Round 1 }
  a := b + ROL(a + F(b, c, d) + x[ 0] + T[ 0], 7);
  d := a + ROL(d + F(a, b, c) + x[ 1] + T[ 1], 12);
  c := d + ROL(c + F(d, a, b) + x[ 2] + T[ 2], 17);
  b := c + ROL(b + F(c, d, a) + x[ 3] + T[ 3], 22);
  a := b + ROL(a + F(b, c, d) + x[ 4] + T[ 4], 7);
  d := a + ROL(d + F(a, b, c) + x[ 5] + T[ 5], 12);
  c := d + ROL(c + F(d, a, b) + x[ 6] + T[ 6], 17);
  b := c + ROL(b + F(c, d, a) + x[ 7] + T[ 7], 22);
  a := b + ROL(a + F(b, c, d) + x[ 8] + T[ 8], 7);
  d := a + ROL(d + F(a, b, c) + x[ 9] + T[ 9], 12);
  c := d + ROL(c + F(d, a, b) + x[10] + T[10], 17);
  b := c + ROL(b + F(c, d, a) + x[11] + T[11], 22);
  a := b + ROL(a + F(b, c, d) + x[12] + T[12], 7);
  d := a + ROL(d + F(a, b, c) + x[13] + T[13], 12);
  c := d + ROL(c + F(d, a, b) + x[14] + T[14], 17);
  b := c + ROL(b + F(c, d, a) + x[15] + T[15], 22);

  { Round 2 }
  a := b + ROL(a + G(b, c, d) + x[ 1] + T[16], 5);
  d := a + ROL(d + G(a, b, c) + x[ 6] + T[17], 9);
  c := d + ROL(c + G(d, a, b) + x[11] + T[18], 14);
  b := c + ROL(b + G(c, d, a) + x[ 0] + T[19], 20);
  a := b + ROL(a + G(b, c, d) + x[ 5] + T[20], 5);
  d := a + ROL(d + G(a, b, c) + x[10] + T[21], 9);
  c := d + ROL(c + G(d, a, b) + x[15] + T[22], 14);
  b := c + ROL(b + G(c, d, a) + x[ 4] + T[23], 20);
  a := b + ROL(a + G(b, c, d) + x[ 9] + T[24], 5);
  d := a + ROL(d + G(a, b, c) + x[14] + T[25], 9);
  c := d + ROL(c + G(d, a, b) + x[ 3] + T[26], 14);
  b := c + ROL(b + G(c, d, a) + x[ 8] + T[27], 20);
  a := b + ROL(a + G(b, c, d) + x[13] + T[28], 5);
  d := a + ROL(d + G(a, b, c) + x[ 2] + T[29], 9);
  c := d + ROL(c + G(d, a, b) + x[ 7] + T[30], 14);
  b := c + ROL(b + G(c, d, a) + x[12] + T[31], 20);

  { Round 3 }
  a := b + ROL(a + H(b, c, d) + x[ 5] + T[32], 4);
  d := a + ROL(d + H(a, b, c) + x[ 8] + T[33], 11);
  c := d + ROL(c + H(d, a, b) + x[11] + T[34], 16);
  b := c + ROL(b + H(c, d, a) + x[14] + T[35], 23);
  a := b + ROL(a + H(b, c, d) + x[ 1] + T[36], 4);
  d := a + ROL(d + H(a, b, c) + x[ 4] + T[37], 11);
  c := d + ROL(c + H(d, a, b) + x[ 7] + T[38], 16);
  b := c + ROL(b + H(c, d, a) + x[10] + T[39], 23);
  a := b + ROL(a + H(b, c, d) + x[13] + T[40], 4);
  d := a + ROL(d + H(a, b, c) + x[ 0] + T[41], 11);
  c := d + ROL(c + H(d, a, b) + x[ 3] + T[42], 16);
  b := c + ROL(b + H(c, d, a) + x[ 6] + T[43], 23);
  a := b + ROL(a + H(b, c, d) + x[ 9] + T[44], 4);
  d := a + ROL(d + H(a, b, c) + x[12] + T[45], 11);
  c := d + ROL(c + H(d, a, b) + x[15] + T[46], 16);
  b := c + ROL(b + H(c, d, a) + x[ 2] + T[47], 23);

  { Round 4 }
  a := b + ROL(a + II(b, c, d) + x[ 0] + T[48], 6);
  d := a + ROL(d + II(a, b, c) + x[ 7] + T[49], 10);
  c := d + ROL(c + II(d, a, b) + x[14] + T[50], 15);
  b := c + ROL(b + II(c, d, a) + x[ 5] + T[51], 21);
  a := b + ROL(a + II(b, c, d) + x[12] + T[52], 6);
  d := a + ROL(d + II(a, b, c) + x[ 3] + T[53], 10);
  c := d + ROL(c + II(d, a, b) + x[10] + T[54], 15);
  b := c + ROL(b + II(c, d, a) + x[ 1] + T[55], 21);
  a := b + ROL(a + II(b, c, d) + x[ 8] + T[56], 6);
  d := a + ROL(d + II(a, b, c) + x[15] + T[57], 10);
  c := d + ROL(c + II(d, a, b) + x[ 6] + T[58], 15);
  b := c + ROL(b + II(c, d, a) + x[13] + T[59], 21);
  a := b + ROL(a + II(b, c, d) + x[ 4] + T[60], 6);
  d := a + ROL(d + II(a, b, c) + x[11] + T[61], 10);
  c := d + ROL(c + II(d, a, b) + x[ 2] + T[62], 15);
  b := c + ROL(b + II(c, d, a) + x[ 9] + T[63], 21);

  { Add this chunk's hash to result so far }
  Inc(state[0], a);
  Inc(state[1], b);
  Inc(state[2], c);
  Inc(state[3], d);
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
  Inc(ctx.Count[0], LongInt(len) shl 3);
  if ctx.Count[0] < (LongInt(len) shl 3) then
    Inc(ctx.Count[1]);
  Inc(ctx.Count[1], LongInt(len) shr 29);

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
  for i := 0 to 3 do
  begin
    bits[i] := Byte((ctx.Count[0] shr (i * 8)) and $FF);
    bits[i + 4] := Byte((ctx.Count[1] shr (i * 8)) and $FF);
  end;

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
  begin
    digest[i * 4] := Byte((ctx.State[i]) and $FF);
    digest[i * 4 + 1] := Byte((ctx.State[i] shr 8) and $FF);
    digest[i * 4 + 2] := Byte((ctx.State[i] shr 16) and $FF);
    digest[i * 4 + 3] := Byte((ctx.State[i] shr 24) and $FF);
  end;
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
