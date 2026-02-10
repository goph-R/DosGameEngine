{ CRCTEST.PAS - Test CRC32 hash implementation

  Tests CRC32 against known test vectors.
  All values verified against PHP 8 crc32() function.
}

program CRCTest;

uses CRC32;

var
  PassCount, FailCount: Integer;

procedure TestVector(const Input, Expected: String);
var
  Result: String;
begin
  Result := CRC32String(Input);
  Write('Input: "', Input, '"');
  WriteLn;
  Write('Expected: ', Expected);
  WriteLn;
  Write('Got:      ', Result);
  WriteLn;
  if Result = Expected then
  begin
    WriteLn('PASS');
    Inc(PassCount);
  end
  else
  begin
    WriteLn('FAIL ***');
    Inc(FailCount);
  end;
  WriteLn;
end;

procedure TestIncremental;
var
  CRC: TCRC32;
  S1, S2: String;
  FullResult, IncrResult: String;
begin
  WriteLn('Testing incremental hashing...');

  { Hash "helloworld" in one go }
  FullResult := CRC32String('helloworld');

  { Hash "hello" + "world" incrementally }
  S1 := 'hello';
  S2 := 'world';
  CRC32Init(CRC);
  CRC32Update(CRC, @S1[1], Length(S1));
  CRC32Update(CRC, @S2[1], Length(S2));
  CRC32Final(CRC);
  IncrResult := CRC32ToHex(CRC);

  Write('Full:        ', FullResult);
  WriteLn;
  Write('Incremental: ', IncrResult);
  WriteLn;

  if FullResult = IncrResult then
  begin
    WriteLn('PASS');
    Inc(PassCount);
  end
  else
  begin
    WriteLn('FAIL ***');
    Inc(FailCount);
  end;
  WriteLn;
end;

procedure TestFile;
var
  CRC: TCRC32;
  F: Text;
begin
  WriteLn('Testing file hash...');

  { Create a test file }
  Assign(F, 'CRCTEST.TMP');
  Rewrite(F);
  Write(F, 'The quick brown fox jumps over the lazy dog');
  Close(F);

  { Hash it }
  if CRC32File('CRCTEST.TMP', CRC) then
  begin
    Write('File hash: ', CRC32ToHex(CRC));
    WriteLn;
    { PHP: dechex(crc32("The quick brown fox jumps over the lazy dog")) = 414fa339 }
    if CRC32ToHex(CRC) = '414fa339' then
    begin
      WriteLn('PASS');
      Inc(PassCount);
    end
    else
    begin
      WriteLn('FAIL ***');
      Inc(FailCount);
    end;
  end
  else
  begin
    WriteLn('FAIL: Could not read file ***');
    Inc(FailCount);
  end;

  { Clean up }
  Erase(F);
  WriteLn;
end;

procedure TestEmpty;
var
  CRC: TCRC32;
begin
  WriteLn('Testing empty update...');

  { Init + Final with no update should give 00000000 }
  CRC32Init(CRC);
  CRC32Final(CRC);

  Write('Empty CRC: ', CRC32ToHex(CRC));
  WriteLn;
  if CRC32ToHex(CRC) = '00000000' then
  begin
    WriteLn('PASS');
    Inc(PassCount);
  end
  else
  begin
    WriteLn('FAIL ***');
    Inc(FailCount);
  end;
  WriteLn;
end;

begin
  PassCount := 0;
  FailCount := 0;

  WriteLn('CRC32 Implementation Test');
  WriteLn('=========================');
  WriteLn('PHP 8 compatible (CRC-32B, polynomial $EDB88320)');
  WriteLn;

  { Known test vectors (verified against PHP 8 crc32()) }
  TestVector('123456789', 'cbf43926');
  TestVector('hello', '3610a686');
  TestVector('a', 'e8b7be43');
  TestVector('abc', '352441c2');
  TestVector('message digest', '20159d7f');

  WriteLn('Additional Tests');
  WriteLn('================');
  WriteLn;

  TestEmpty;
  TestIncremental;
  TestFile;

  WriteLn('=========================');
  WriteLn('Results: ', PassCount, ' passed, ', FailCount, ' failed');
  if FailCount = 0 then
    WriteLn('ALL TESTS PASSED!')
  else
    WriteLn('SOME TESTS FAILED!');
  WriteLn;
end.
