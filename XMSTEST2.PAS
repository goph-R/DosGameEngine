program XMSTest2;

{ Test XMS round-trip: write data, read it back, verify }

uses Crt, XMS;

var
  Handle: Word;
  TestData: array[0..99] of Byte;
  ReadBack: array[0..99] of Byte;
  E: EMMstruct;
  i: Integer;
  Match: Boolean;

function HexStr(Value: Word; Digits: Byte): string;
const
  HexChars: array[0..15] of Char = '0123456789ABCDEF';
var
  Result: string;
  i: Integer;
begin
  Result := '';
  for i := Digits - 1 downto 0 do
    Result := Result + HexChars[(Value shr (i * 4)) and $F];
  HexStr := Result;
end;

var
  B0,B1,B2,B3,B4,B5,B6: Byte;
begin
  ClrScr;
  WriteLn('XMS Round-Trip Test');
  WriteLn('===================');

  if not XMSinstalled then
  begin
    WriteLn('ERROR: XMS not installed');
    Halt(1);
  end;

  { NEW: read CallXMS stub bytes }
  if Debug_GetCallXMSBytes(B0,B1,B2,B3,B4,B5,B6) then
  begin
    Write('CallXMS bytes: ');
    Write(
      HexStr(B0,2),' ',
      HexStr(B1,2),' ',
      HexStr(B2,2),' ',
      HexStr(B3,2),' ',
      HexStr(B4,2),' ',
      HexStr(B5,2),' ',
      HexStr(B6,2)
    );
    WriteLn;
  end
  else
    WriteLn('Could not read CallXMS bytes');

  { Fill test data with pattern }
  for i := 0 to 99 do
    TestData[i] := i mod 256;

  WriteLn('Test pattern created');

  { Allocate 1KB in XMS }
  Handle := AllocXMS(1);
  if Handle = 0 then
  begin
    WriteLn('ERROR: Failed to allocate XMS');
    WriteLn('AllocXMS failed, XMSerror=$', HexStr(XMSerror, 2));
    Halt(1);
  end;

  WriteLn('XMS allocated, handle: ', Handle);

  { Transfer TO XMS }
  with E do
  begin
    size := 100;
    soh := 0;  { Source: conventional }
    soo := (LongInt(Seg(TestData)) * 16) + Ofs(TestData);
    dsh := Handle;  { Dest: XMS }
    dso := 0;
  end;

  if not MoveXMS(E) then
  begin
    WriteLn('ERROR: MoveXMS TO failed');
    FreeXMS(Handle);
    Halt(1);
  end;

  WriteLn('Data transferred TO XMS - OK');

  { Clear readback buffer }
  FillChar(ReadBack, 100, 0);

  { Transfer FROM XMS }
  with E do
  begin
    size := 100;
    soh := Handle;  { Source: XMS }
    soo := 0;
    dsh := 0;  { Dest: conventional }
    dso := (LongInt(Seg(ReadBack)) * 16) + Ofs(ReadBack);
  end;

  if not MoveXMS(E) then
  begin
    WriteLn('ERROR: MoveXMS FROM failed');
    FreeXMS(Handle);
    Halt(1);
  end;

  WriteLn('Data transferred FROM XMS - OK');

  { Verify data matches }
  Match := True;
  for i := 0 to 99 do
  begin
    if TestData[i] <> ReadBack[i] then
    begin
      Match := False;
      WriteLn('MISMATCH at byte ', i, ': sent ', TestData[i], ', got ', ReadBack[i]);
    end;
  end;

  if Match then
    WriteLn('SUCCESS: All data matches!')
  else
    WriteLn('FAILURE: Data corruption detected!');

  { Cleanup }
  FreeXMS(Handle);

  WriteLn;
  WriteLn('Press any key...');
  ReadKey;
end.
