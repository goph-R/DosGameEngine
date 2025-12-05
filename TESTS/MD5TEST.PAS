{ MD5TEST.PAS - Test MD5 hash implementation

  Tests MD5 against known test vectors from RFC 1321
}

program MD5Test;

uses MD5;

procedure TestVector(const input, expected: String);
var
  result: String;
begin
  result := MD5String(input);
  Write('Input: "', input, '"');
  WriteLn;
  Write('Expected: ', expected);
  WriteLn;
  Write('Got:      ', result);
  WriteLn;
  if result = expected then
    WriteLn('PASS')
  else
    WriteLn('FAIL ***');
  WriteLn;
end;

procedure TestFile;
var
  digest: TMD5Digest;
  f: Text;
begin
  WriteLn('Testing file hash...');

  { Create a test file }
  Assign(f, 'MD5TEST.TMP');
  Rewrite(f);
  Write(f, 'The quick brown fox jumps over the lazy dog');
  Close(f);

  { Hash it }
  if MD5File('MD5TEST.TMP', digest) then
  begin
    Write('File hash: ', MD5DigestToHex(digest));
    WriteLn;
    if MD5DigestToHex(digest) = '9e107d9d372bb6826bd81d3542a419d6' then
      WriteLn('PASS')
    else
      WriteLn('FAIL ***');
  end
  else
    WriteLn('FAIL: Could not read file ***');

  { Clean up }
  Erase(f);
  WriteLn;
end;

procedure TestDigestEqual;
var
  d1, d2: TMD5Digest;
begin
  WriteLn('Testing digest comparison...');

  { Same string should produce same digest }
  MD5File('MD5TEST.TMP', d1);
  MD5File('MD5TEST.TMP', d2);

  if MD5DigestEqual(d1, d2) then
    WriteLn('PASS: Identical digests match')
  else
    WriteLn('FAIL: Identical digests do not match ***');

  WriteLn;
end;

begin
  WriteLn('MD5 Implementation Test');
  WriteLn('RFC 1321 Test Vectors');
  WriteLn('=====================');
  WriteLn;

  { Official RFC 1321 test vectors }
  TestVector('', 'd41d8cd98f00b204e9800998ecf8427e');
  TestVector('a', '0cc175b9c0f1b6a831c399e269772661');
  TestVector('abc', '900150983cd24fb0d6963f7d28e17f72');
  TestVector('message digest', 'f96b697d7cb7938d525a2f31aaf161d0');
  TestVector('abcdefghijklmnopqrstuvwxyz', 'c3fcd3d76192e4007dfb496cca67e13b');
  TestVector('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789',
             'd174ab98d277d9f5a5611c2c9f419d9f');
  TestVector('12345678901234567890123456789012345678901234567890123456789012345678901234567890',
             '57edf4a22be3c955ac49da2e2107b67a');

  WriteLn('Additional Tests');
  WriteLn('================');
  WriteLn;

  TestFile;

  WriteLn('All tests complete!');
end.
