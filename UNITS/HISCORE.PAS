{ HISCORE.PAS - High Score Management with Tamper Protection

  Manages top 10 high scores with CRC32 hash verification to prevent cheating.
  Uses XML storage with salted hash of all names and scores.

  Usage:
    var HS: THighScore;
    InitHighScore(HS, 'MY_GAME_SALT_V1');
    LoadHighScore('SCORES.XML', HS);
    if IsHighScore(HS, PlayerScore) then
      SaveHighScore('SCORES.XML', PlayerName, PlayerScore, HS);
}

unit HiScore;

interface

uses
  CRC32, MiniXML, StrUtil;

const
  MaxHighScores = 10;

type
  THighScore = record
    Names: array[0..MaxHighScores - 1] of String;
    Scores: array[0..MaxHighScores - 1] of LongInt;
    Count: Integer;  { Number of valid entries (0-10) }
    Salt: String;     { Salt for tamper protection }
  end;

{ Initialize empty high score table with salt }
procedure InitHighScore(var HS: THighScore; const SaltValue: String);

{ Load high scores from XML file with hash verification }
{ Returns True on success, False if file missing or hash invalid }
function LoadHighScore(const FileName: String; var HS: THighScore): Boolean;

{ Add new score and save to XML file }
{ Returns True if score was added (was in top 10), False otherwise }
function SaveHighScore(const FileName: String; const Name: String; Score: LongInt; var HS: THighScore): Boolean;

{ Check if a score qualifies for top 10 }
function IsHighScore(const HS: THighScore; Score: LongInt): Boolean;

{ Compute CRC32 hash of all scores (for verification) }
function ComputeHighScoreHash(const HS: THighScore): String;

implementation

procedure InitHighScore(var HS: THighScore; const SaltValue: String);
var
  i: Integer;
begin
  for i := 0 to MaxHighScores - 1 do
  begin
    HS.Names[i] := '';
    HS.Scores[i] := 0;
  end;
  HS.Count := 0;
  HS.Salt := SaltValue;
end;

function ComputeHighScoreHash(const HS: THighScore): String;
var
  i: Integer;
  CRC: TCRC32;
  ScoreStr: String;
begin
  { Use incremental hashing to avoid 255-char String limit }
  CRC32Init(CRC);

  { Hash salt }
  if Length(HS.Salt) > 0 then
    CRC32Update(CRC, @HS.Salt[1], Length(HS.Salt));

  { Hash each name and score }
  for i := 0 to HS.Count - 1 do
  begin
    { Hash name }
    if Length(HS.Names[i]) > 0 then
      CRC32Update(CRC, @HS.Names[i][1], Length(HS.Names[i]));

    { Hash score as string }
    ScoreStr := IntToStr(HS.Scores[i]);
    CRC32Update(CRC, @ScoreStr[1], Length(ScoreStr));
  end;

  { Finalize and convert to hex string }
  CRC32Final(CRC);
  ComputeHighScoreHash := CRC32ToHex(CRC);
end;

function LoadHighScore(const FileName: String; var HS: THighScore): Boolean;
var
  Root, Node: PXMLNode;
  StoredHash, ComputedHash, SavedSalt: String;
  i: Integer;
  Name, ScoreStr: String;
begin
  LoadHighScore := False;

  { Preserve salt and reinitialize }
  SavedSalt := HS.Salt;
  InitHighScore(HS, SavedSalt);

  { Load XML file }
  if not XMLLoadFile(FileName, Root) then
    Exit;  { File doesn't exist or invalid XML }

  { Get stored hash }
  StoredHash := XMLAttr(Root, 'hash');
  if StoredHash = '' then
  begin
    XMLFreeTree(Root);
    Exit;  { No hash attribute }
  end;

  { Load all highscore entries }
  Node := XMLFirstChild(Root, 'highscore');
  i := 0;
  while (Node <> nil) and (i < MaxHighScores) do
  begin
    Name := XMLAttr(Node, 'name');
    ScoreStr := XMLAttr(Node, 'score');

    if (Name <> '') and (ScoreStr <> '') then
    begin
      HS.Names[i] := Name;
      HS.Scores[i] := StrToInt(ScoreStr);
      Inc(i);
    end;

    Node := XMLNextSibling(Node, 'highscore');
  end;

  HS.Count := i;

  { Verify hash }
  ComputedHash := ComputeHighScoreHash(HS);
  if ComputedHash <> StoredHash then
  begin
    { Hash mismatch - file tampered or corrupted, reject all scores }
    InitHighScore(HS, SavedSalt);
    XMLFreeTree(Root);
    Exit;
  end;

  XMLFreeTree(Root);
  LoadHighScore := True;
end;

function IsHighScore(const HS: THighScore; Score: LongInt): Boolean;
begin
  { Don't accept zero scores }
  if Score = 0 then
  begin
    IsHighScore := False;
    Exit;
  end;

  { If table is not full, any score > 0 counts }
  if HS.Count < MaxHighScores then
  begin
    IsHighScore := True;
    Exit;
  end;

  { If table is full, check if score beats the LOWEST score (last place) }
  IsHighScore := (Score > HS.Scores[MaxHighScores - 1]);
end;

function AddHighScore(var HS: THighScore; const Name: String; Score: LongInt): Boolean;
var
  InsertPos: Integer;
  i: Integer;
begin
  AddHighScore := False;

  { Find insert position (scores sorted descending) }
  InsertPos := -1;
  for i := 0 to HS.Count - 1 do
  begin
    if Score > HS.Scores[i] then
    begin
      InsertPos := i;
      Break;
    end;
  end;

  { If score doesn't beat any existing score and table is full, reject }
  if (InsertPos = -1) and (HS.Count >= MaxHighScores) then
    Exit;

  { If score doesn't beat any but table not full, append at end }
  if InsertPos = -1 then
    InsertPos := HS.Count;

  { Increase count if table not full }
  if HS.Count < MaxHighScores then
    Inc(HS.Count);

  { Shift entries down to make room }
  for i := HS.Count - 1 downto InsertPos + 1 do
  begin
    HS.Names[i] := HS.Names[i - 1];
    HS.Scores[i] := HS.Scores[i - 1];
  end;

  { Insert new entry }
  HS.Names[InsertPos] := Name;
  HS.Scores[InsertPos] := Score;

  AddHighScore := True;
end;

function SaveHighScore(const FileName: String; const Name: String; Score: LongInt; var HS: THighScore): Boolean;
var
  Root, Node: PXMLNode;
  Hash: String;
  i: Integer;
begin
  SaveHighScore := False;

  { Add the new score to the table }
  if not AddHighScore(HS, Name, Score) then
    Exit;  { Score didn't qualify }

  { Compute hash of updated table }
  Hash := ComputeHighScoreHash(HS);

  { Build XML tree }
  New(Root);
  XMLInitNode(Root^);
  Root^.Name := 'highscores';
  XMLSetAttr(Root, 'hash', Hash);

  { Add all entries }
  for i := 0 to HS.Count - 1 do
  begin
    Node := XMLAddChildElement(Root, 'highscore');
    XMLSetAttr(Node, 'name', HS.Names[i]);
    XMLSetAttr(Node, 'score', IntToStr(HS.Scores[i]));
  end;

  { Save to file }
  if not XMLSaveFile(FileName, Root) then
  begin
    XMLFreeTree(Root);
    Exit;
  end;

  XMLFreeTree(Root);
  SaveHighScore := True;
end;

end.
