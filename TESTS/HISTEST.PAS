program HisTest;

{ High Score System Test - HISTEST.PAS
  Tests the HiScore unit with CRC32 tamper protection }

uses
  HiScore, MiniXML;

const
  TestFile = 'HISTEST.XML';
  TestSalt = 'HISTEST_SALT_V1';

var
  HS: THighScore;
  i: Integer;
  Result: Boolean;

procedure PrintHighScores;
var
  j: Integer;
begin
  WriteLn('Current High Scores (', HS.Count, '/10):');
  WriteLn('-------------------------------------');
  for j := 0 to HS.Count - 1 do
    WriteLn('  ', j + 1:2, '. ', HS.Names[j]:20, ' ', HS.Scores[j]:8);
  WriteLn;
end;

procedure TestBasicOperations;
begin
  WriteLn('TEST 1: Basic Operations');
  WriteLn('========================');
  WriteLn;

  { Initialize high score table }
  WriteLn('Initializing high score table with salt...');
  InitHighScore(HS, TestSalt);
  WriteLn('Salt: "', HS.Salt, '"');
  WriteLn('Count: ', HS.Count);
  WriteLn;

  { Add some test scores }
  WriteLn('Adding test scores...');
  Result := SaveHighScore(TestFile, 'Alice', 10000, HS);
  WriteLn('  Alice (10000): ', Result);

  Result := SaveHighScore(TestFile, 'Bob', 8500, HS);
  WriteLn('  Bob (8500): ', Result);

  Result := SaveHighScore(TestFile, 'Charlie', 12000, HS);
  WriteLn('  Charlie (12000): ', Result);

  Result := SaveHighScore(TestFile, 'Diana', 9500, HS);
  WriteLn('  Diana (9500): ', Result);

  Result := SaveHighScore(TestFile, 'Eve', 11000, HS);
  WriteLn('  Eve (11000): ', Result);
  WriteLn;

  PrintHighScores;
  WriteLn('PASSED: Basic operations');
  WriteLn;
end;

procedure TestLoadAndVerify;
var
  HS2: THighScore;
begin
  WriteLn('TEST 2: Load and Hash Verification');
  WriteLn('===================================');
  WriteLn;

  { Load from file }
  WriteLn('Loading high scores from ', TestFile, '...');
  InitHighScore(HS2, TestSalt);
  Result := LoadHighScore(TestFile, HS2);

  if Result then
  begin
    WriteLn('SUCCESS: File loaded and hash verified!');
    WriteLn;
    HS := HS2;  { Update global HS }
    PrintHighScores;
  end
  else
  begin
    WriteLn('ERROR: Failed to load or hash mismatch!');
    Halt(1);
  end;

  WriteLn('PASSED: Load and verification');
  WriteLn;
end;

procedure TestFullTable;
var
  j: Integer;
begin
  WriteLn('TEST 3: Fill Table to Maximum (10 entries)');
  WriteLn('===========================================');
  WriteLn;

  { Add 5 more scores to fill the table }
  WriteLn('Adding 5 more scores...');
  SaveHighScore(TestFile, 'Frank', 7000, HS);
  SaveHighScore(TestFile, 'Grace', 6500, HS);
  SaveHighScore(TestFile, 'Hank', 8000, HS);
  SaveHighScore(TestFile, 'Ivy', 9000, HS);
  SaveHighScore(TestFile, 'Jack', 7500, HS);
  WriteLn;

  { Reload to verify }
  InitHighScore(HS, TestSalt);
  if not LoadHighScore(TestFile, HS) then
  begin
    WriteLn('ERROR: Failed to reload full table!');
    Halt(1);
  end;

  PrintHighScores;

  if HS.Count <> 10 then
  begin
    WriteLn('ERROR: Expected 10 entries, got ', HS.Count);
    Halt(1);
  end;

  WriteLn('PASSED: Full table (10 entries)');
  WriteLn;
end;

procedure TestRejection;
begin
  WriteLn('TEST 4: Score Rejection (table full)');
  WriteLn('=====================================');
  WriteLn;

  { Try to add a score that shouldn''t make it }
  WriteLn('Attempting to add low score (5000)...');
  Result := SaveHighScore(TestFile, 'Loser', 5000, HS);

  if Result then
  begin
    WriteLn('ERROR: Low score should have been rejected!');
    Halt(1);
  end
  else
    WriteLn('SUCCESS: Low score correctly rejected!');

  WriteLn;

  { Verify table unchanged }
  InitHighScore(HS, TestSalt);
  if not LoadHighScore(TestFile, HS) then
  begin
    WriteLn('ERROR: Failed to reload table!');
    Halt(1);
  end;

  if HS.Count <> 10 then
  begin
    WriteLn('ERROR: Table count changed!');
    Halt(1);
  end;

  WriteLn('PASSED: Score rejection');
  WriteLn;
end;

procedure TestReplacement;
begin
  WriteLn('TEST 5: Score Replacement');
  WriteLn('=========================');
  WriteLn;

  { Add a high score that bumps someone off }
  WriteLn('Adding new high score (13000)...');
  Result := SaveHighScore(TestFile, 'King', 13000, HS);

  if not Result then
  begin
    WriteLn('ERROR: High score should have been accepted!');
    Halt(1);
  end;

  WriteLn('SUCCESS: Score added!');
  WriteLn;

  { Reload and verify }
  InitHighScore(HS, TestSalt);
  if not LoadHighScore(TestFile, HS) then
  begin
    WriteLn('ERROR: Failed to reload!');
    Halt(1);
  end;

  PrintHighScores;

  { Verify King is first }
  if HS.Names[0] <> 'King' then
  begin
    WriteLn('ERROR: Expected King at position 1!');
    Halt(1);
  end;

  if HS.Scores[0] <> 13000 then
  begin
    WriteLn('ERROR: Expected score 13000 at position 1!');
    Halt(1);
  end;

  WriteLn('PASSED: Score replacement');
  WriteLn;
end;

procedure TestTamperDetection;
var
  Root: PXMLNode;
  HS2: THighScore;
begin
  WriteLn('TEST 6: Tamper Detection');
  WriteLn('========================');
  WriteLn;

  { Load XML and modify a score without updating hash }
  WriteLn('Loading XML file and tampering with it...');
  if not XMLLoadFile(TestFile, Root) then
  begin
    WriteLn('ERROR: Failed to load XML!');
    Halt(1);
  end;

  { Change first score (but don''t update hash) }
  XMLSetAttr(XMLFirstChild(Root, 'highscore'), 'score', '99999');

  { Save tampered file }
  if not XMLSaveFile(TestFile, Root) then
  begin
    WriteLn('ERROR: Failed to save tampered XML!');
    XMLFreeTree(Root);
    Halt(1);
  end;

  XMLFreeTree(Root);
  WriteLn('Tampered file saved (changed score to 99999)');
  WriteLn;

  { Try to load - should fail hash verification }
  WriteLn('Attempting to load tampered file...');
  InitHighScore(HS2, TestSalt);
  Result := LoadHighScore(TestFile, HS2);

  if Result then
  begin
    WriteLn('ERROR: Tampered file should have been rejected!');
    Halt(1);
  end
  else
  begin
    WriteLn('SUCCESS: Tamper detected, file rejected!');
    WriteLn('Count after rejection: ', HS2.Count, ' (should be 0)');
  end;

  WriteLn;
  WriteLn('PASSED: Tamper detection');
  WriteLn;
end;

procedure TestWrongSalt;
var
  HS2: THighScore;
begin
  WriteLn('TEST 7: Wrong Salt Detection');
  WriteLn('============================');
  WriteLn;

  { Restore valid file first }
  WriteLn('Restoring valid file...');
  InitHighScore(HS, TestSalt);
  SaveHighScore(TestFile, 'Alice', 10000, HS);
  WriteLn;

  { Try to load with wrong salt }
  WriteLn('Attempting to load with wrong salt...');
  InitHighScore(HS2, 'WRONG_SALT');
  Result := LoadHighScore(TestFile, HS2);

  if Result then
  begin
    WriteLn('ERROR: File with wrong salt should be rejected!');
    Halt(1);
  end
  else
    WriteLn('SUCCESS: Wrong salt detected, file rejected!');

  WriteLn;
  WriteLn('PASSED: Wrong salt detection');
  WriteLn;
end;

begin
  WriteLn('========================================');
  WriteLn(' High Score System Test Suite');
  WriteLn(' Testing CRC32 Tamper Protection');
  WriteLn('========================================');
  WriteLn;

  TestBasicOperations;
  TestLoadAndVerify;
  TestFullTable;
  TestRejection;
  TestReplacement;
  TestTamperDetection;
  TestWrongSalt;

  WriteLn('========================================');
  WriteLn(' ALL TESTS PASSED!');
  WriteLn('========================================');
  WriteLn;
  WriteLn('Press any key to exit...');
  ReadLn;
end.
