{ MD5DEMO.PAS - Practical MD5 usage examples

  Demonstrates:
  - Asset integrity verification
  - Save game checksums
  - Quick string hashing
}

program MD5Demo;

uses MD5;

procedure VerifyAsset(const path, expectedHash: String);
var
  digest: TMD5Digest;
  hash: String;
begin
  Write('Checking: ', path, '...');

  if not MD5File(path, digest) then
  begin
    WriteLn(' ERROR: File not found');
    Exit;
  end;

  hash := MD5DigestToHex(digest);

  if hash = expectedHash then
    WriteLn(' OK')
  else
  begin
    WriteLn(' MISMATCH!');
    WriteLn('  Expected: ', expectedHash);
    WriteLn('  Got:      ', hash);
  end;
end;

procedure HashPassword(const password: String);
var
  hash: String;
begin
  hash := MD5String(password);
  WriteLn('Password hash: ', hash);
  WriteLn('(Never store passwords in plain text!)');
  WriteLn;
end;

procedure CreateManifest;
var
  manifest: Text;
  digest: TMD5Digest;
begin
  WriteLn('Creating asset manifest...');
  WriteLn;

  Assign(manifest, 'MANIFEST.TXT');
  Rewrite(manifest);

  { Hash all PCX files in DATA directory }
  if MD5File('DATA\FONT.PCX', digest) then
  begin
    WriteLn(manifest, 'FONT.PCX=', MD5DigestToHex(digest));
    WriteLn('  FONT.PCX: ', MD5DigestToHex(digest));
  end;

  { Add more files as needed }
  { Example: CONFIG.INI verification }
  if MD5File('CONFIG.INI', digest) then
  begin
    WriteLn(manifest, 'CONFIG.INI=', MD5DigestToHex(digest));
    WriteLn('  CONFIG.INI: ', MD5DigestToHex(digest));
  end;

  Close(manifest);
  WriteLn;
  WriteLn('Manifest saved to MANIFEST.TXT');
  WriteLn;
end;

procedure QuickHashes;
begin
  WriteLn('Quick String Hashing');
  WriteLn('====================');
  WriteLn;

  WriteLn('MD5("hello") = ', MD5String('hello'));
  WriteLn('MD5("world") = ', MD5String('world'));
  WriteLn('MD5("DOS")   = ', MD5String('DOS'));
  WriteLn;
end;

var
  choice: Char;

begin
  WriteLn('MD5 Practical Examples');
  WriteLn('======================');
  WriteLn;
  WriteLn('1. Quick string hashing');
  WriteLn('2. Create asset manifest');
  WriteLn('3. Verify assets');
  WriteLn('4. Password hashing (demo)');
  WriteLn;
  Write('Choose (1-4): ');
  ReadLn(choice);
  WriteLn;

  case choice of
    '1': QuickHashes;
    '2': CreateManifest;
    '3': begin
           WriteLn('Asset Verification');
           WriteLn('==================');
           WriteLn;
           WriteLn('(Edit this code to add your expected hashes)');
           WriteLn;
           { Example: VerifyAsset('DATA\FONT.PCX', 'abc123...'); }
         end;
    '4': begin
           WriteLn('Password Hashing Demo');
           WriteLn('=====================');
           WriteLn;
           HashPassword('secret123');
           WriteLn('Note: For real password storage, use a proper');
           WriteLn('      key derivation function like PBKDF2.');
         end;
  else
    WriteLn('Invalid choice');
  end;
end.
