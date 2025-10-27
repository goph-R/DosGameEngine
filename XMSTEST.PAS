program XMSTest;

uses XMS, Crt;

var
  ok      : boolean;
  handle  : TXMSHandle;
  workbuf : array[0..16383] of byte; { 16 KB scratch buffer in conventional RAM }
  testbuf : array[0..4095] of byte;  { 4 KB for verification }
  i       : word;
  ver     : word;
  errors  : word;

begin
  ClrScr;
  WriteLn('XMS (Extended Memory) Test Program');
  WriteLn('===================================');
  WriteLn;

  { Initialize XMS driver }
  Write('Initializing XMS driver... ');
  ok := XMS_Init;
  if (not ok) or (not XMS_IsPresent) then
  begin
    WriteLn('FAILED!');
    WriteLn;
    WriteLn('No XMS driver detected!');
    WriteLn;
    WriteLn('To fix this:');
    WriteLn('  1. Add HIMEM.SYS to CONFIG.SYS:');
    WriteLn('     DEVICE=C:\DOS\HIMEM.SYS');
    WriteLn('  2. For DOSBox, XMS is enabled by default');
    WriteLn;
    WriteLn('Press any key to exit...');
    ReadKey;
    Halt(1);
  end;
  WriteLn('OK');

  { Get XMS version }
  ver := XMS_GetVersion;
  WriteLn('XMS Version: ', Lo(ver), '.', Hi(ver));
  WriteLn;

  { Allocate 512 KB in extended memory }
  Write('Allocating 512 KB in XMS... ');
  if not XMS_AllocKB(512, handle) then
  begin
    WriteLn('FAILED!');
    WriteLn('Not enough extended memory available.');
    WriteLn('Press any key to exit...');
    ReadKey;
    Halt(1);
  end;
  WriteLn('OK (Handle: ', handle, ')');
  WriteLn;

  { Fill test buffer with pattern }
  WriteLn('Preparing 16 KB test data...');
  for i := 0 to High(workbuf) do
    workbuf[i] := i mod 256;
  WriteLn('  Pattern: 0, 1, 2, ..., 255, 0, 1, 2, ...');
  WriteLn;

  { Upload to XMS }
  Write('Uploading 16 KB to XMS block at offset 0... ');
  if not XMS_MoveToXMS(handle, 0, Seg(workbuf), Ofs(workbuf), SizeOf(workbuf)) then
  begin
    WriteLn('FAILED!');
    XMS_Free(handle);
    Halt(1);
  end;
  WriteLn('OK');
  WriteLn;

  { Clear local buffer to verify download }
  FillChar(testbuf, SizeOf(testbuf), 0);

  { Download 4 KB subset from XMS }
  Write('Downloading 4 KB from XMS offset 4096... ');
  if not XMS_MoveFromXMS(handle, 4096, Seg(testbuf), Ofs(testbuf), SizeOf(testbuf)) then
  begin
    WriteLn('FAILED!');
    XMS_Free(handle);
    Halt(1);
  end;
  WriteLn('OK');
  WriteLn;

  { Verify data integrity }
  Write('Verifying data integrity... ');
  errors := 0;
  for i := 0 to High(testbuf) do
  begin
    { Offset 4096 means we start at pattern byte (4096 mod 256) = 0 }
    if testbuf[i] <> ((4096 + i) mod 256) then
    begin
      Inc(errors);
      if errors <= 5 then  { Show first 5 errors only }
        WriteLn('  Error at offset ', i, ': expected ', (4096 + i) mod 256, ', got ', testbuf[i]);
    end;
  end;

  if errors = 0 then
  begin
    WriteLn('OK');
    WriteLn('All 4096 bytes verified successfully!');
  end
  else
  begin
    WriteLn('FAILED!');
    WriteLn('Found ', errors, ' errors in data!');
  end;
  WriteLn;

  { Cleanup }
  Write('Freeing XMS block... ');
  if not XMS_Free(handle) then
  begin
    WriteLn('FAILED!');
    WriteLn('Warning: Could not free XMS block (handle may be lost)');
  end
  else
    WriteLn('OK');

  WriteLn;
  if errors = 0 then
    WriteLn('==> XMS TEST PASSED! <==')
  else
    WriteLn('==> XMS TEST FAILED! <==');
  WriteLn;
  WriteLn('Press any key to exit...');
  ReadKey;
end.
