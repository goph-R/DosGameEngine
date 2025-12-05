{ HISCORE.PAS - High Score Management with Tamper Protection

  Manages top 10 high scores with MD5 hash verification to prevent cheating.
  Uses XML storage with salted hash of all names and scores.

  Usage:
    var HS: THighScore;
    InitHighScore(HS);
    LoadHighScore('SCORES.XML', HS);
    if IsHighScore(HS, PlayerScore) then
      SaveHighScore('SCORES.XML', PlayerName, PlayerScore, HS);
}

unit HiScore;

interface

uses
  MD5, MiniXML, StrUtil;

const
  MaxHighScores = 10;
  HighScoreSalt = 'XICLONE_HIGHSCORE_V1';  { Salt to prevent tampering }

type
  THighScore = record
    Names: array[0..MaxHighScores - 1] of String;
    Scores: array[0..MaxHighScores - 1] of LongInt;
    Count: Integer;  { Number of valid entries (0-10) }
  end;

{ Initialize empty high score table }
procedure InitHighScore(var HS: THighScore);

{ Load high scores from XML file with hash verification }
{ Returns True on success, False if file missing or hash invalid }
function LoadHighScore(const FileName: String; var HS: THighScore): Boolean;

{ Add new score and save to XML file }
{ Returns True if score was added (was in top 10), False otherwise }
function SaveHighScore(const FileName: String; const Name: String; Score: LongInt; var HS: THighScore): Boolean;

{ Check if a score qualifies for top 10 }
function IsHighScore(const HS: THighScore; Score: LongInt): Boolean;

{ Compute MD5 hash of all scores (for verification) }
function ComputeHighScoreHash(const HS: THighScore): String;

implementation

procedure InitHighScore(var HS: THighScore);
var
  i: Integer;
begin
  for i := 0 to MaxHighScores - 1 do
  begin
    HS.Names[i] := '';
    HS.Scores[i] := 0;
  end;
  HS.Count := 0;
end;

function ComputeHighScoreHash(const HS: THighScore): String;
var
  i: Integer;
  DataToHash: String;
begin
  { Build string: salt + name[0] + score[0] + name[1] + score[1] + ... }
  DataToHash := HighScoreSalt;

  for i := 0 to HS.Count - 1 do
  begin
    DataToHash := DataToHash + HS.Names[i];
    DataToHash := DataToHash + IntToStr(HS.Scores[i]);
  end;

  ComputeHighScoreHash := MD5String(DataToHash);
end;

function LoadHighScore(const FileName: String; var HS: THighScore): Boolean;
var
  Root, Node: PXMLNode;
  StoredHash, ComputedHash: String;
  i: Integer;
  Name, ScoreStr: String;
begin
  LoadHighScore := False;
  InitHighScore(HS);

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
    InitHighScore(HS);
    XMLFreeTree(Root);
    Exit;
  end;

  XMLFreeTree(Root);
  LoadHighScore := True;
end;

function IsHighScore(const HS: THighScore; Score: LongInt): Boolean;
begin
  { Always true if table not full }
  if HS.Count < MaxHighScores then
  begin
    IsHighScore := True;
    Exit;
  end;

  { Check if score beats the lowest score }
  IsHighScore := (Score > HS.Scores[HS.Count - 1]);
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
  XMLInitNode(Root);
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
