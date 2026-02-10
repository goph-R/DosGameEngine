{ CRC32.PAS - CRC-32 Hash (ISO 3309, same as ZIP/PNG/PHP)

  Fast 32-bit hash using table lookup. Compatible with PHP crc32().

  Usage:
    var CRC: TCRC32;
    CRC32Init(CRC);
    CRC32Update(CRC, @data, length);
    CRC32Final(CRC);
    WriteLn(CRC32ToHex(CRC));

  Or simplified:
    WriteLn('Hash: ', CRC32String('hello'));
    if CRC32File('DATA\IMAGE.PCX', CRC) then ...
}

unit CRC32;

interface

uses GenTypes;

type
  TCRC32 = LongInt;  { 32-bit CRC value }

{ Core CRC32 functions }
procedure CRC32Init(var CRC: TCRC32);
procedure CRC32Update(var CRC: TCRC32; Buf: Pointer; Len: Word);
procedure CRC32Final(var CRC: TCRC32);

{ Convenience functions }
function CRC32String(const S: String): String;  { Returns 8-char hex string }
function CRC32File(const Path: String; var CRC: TCRC32): Boolean;
function CRC32ToHex(CRC: TCRC32): String;

implementation

var
  CRCTable: array[0..255] of LongInt;

{ Build CRC-32 lookup table (polynomial $EDB88320, reflected) }
procedure BuildCRCTable;
var
  I, J: Integer;
  CRC: LongInt;
begin
  for I := 0 to 255 do
  begin
    CRC := LongInt(I);
    for J := 0 to 7 do
    begin
      if (CRC and 1) = 1 then
        CRC := (CRC shr 1) xor LongInt($EDB88320)
      else
        CRC := CRC shr 1;
    end;
    CRCTable[I] := CRC;
  end;
end;

{ Initialize CRC32 state }
procedure CRC32Init(var CRC: TCRC32);
begin
  CRC := LongInt($FFFFFFFF);
end;

{ Update CRC32 with new data }
procedure CRC32Update(var CRC: TCRC32; Buf: Pointer; Len: Word);
var
  P: PByteArray;
  I: Word;
begin
  if Len = 0 then Exit;
  P := PByteArray(Buf);
  for I := 0 to Len - 1 do
    CRC := CRCTable[Byte(CRC xor LongInt(P^[I]))] xor (CRC shr 8);
end;

{ Finalize CRC32 value }
procedure CRC32Final(var CRC: TCRC32);
begin
  CRC := CRC xor LongInt($FFFFFFFF);
end;

{ Convert CRC32 to 8-character hex string }
function CRC32ToHex(CRC: TCRC32): String;
const
  HexChars: array[0..15] of Char = '0123456789abcdef';
var
  S: String;
  I: Integer;
  B: Byte;
begin
  S := '';
  { Output high byte first (big-endian hex representation) }
  for I := 3 downto 0 do
  begin
    B := Byte(CRC shr (I * 8));
    S := S + HexChars[B shr 4];
    S := S + HexChars[B and $0F];
  end;
  CRC32ToHex := S;
end;

{ Hash a string and return hex result }
function CRC32String(const S: String): String;
var
  CRC: TCRC32;
begin
  CRC32Init(CRC);
  if Length(S) > 0 then
    CRC32Update(CRC, @S[1], Length(S));
  CRC32Final(CRC);
  CRC32String := CRC32ToHex(CRC);
end;

{ Hash a file and return CRC32 }
function CRC32File(const Path: String; var CRC: TCRC32): Boolean;
var
  F: File;
  Buf: array[0..4095] of Byte;
  BytesRead: Word;
begin
  CRC32File := False;

  Assign(F, Path);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult <> 0 then Exit;

  CRC32Init(CRC);

  repeat
    {$I-}
    BlockRead(F, Buf, SizeOf(Buf), BytesRead);
    {$I+}
    if IOResult <> 0 then
    begin
      Close(F);
      Exit;
    end;

    if BytesRead > 0 then
      CRC32Update(CRC, @Buf, BytesRead);
  until BytesRead < SizeOf(Buf);

  Close(F);
  CRC32Final(CRC);
  CRC32File := True;
end;

{ Unit initialization - build lookup table }
begin
  BuildCRCTable;
end.
