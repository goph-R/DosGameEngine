# HISCORE.PAS - High Score Management with Tamper Protection

MD5-protected high score table with XML storage. Prevents cheating through cryptographic hash verification.

## Overview

Manages top 10 high scores with:
- MD5 hash verification to detect tampering
- Salted hashing for per-game uniqueness
- XML storage for human-readable format
- Automatic sorting by score (descending)
- Protection against manual file editing

Perfect for arcade-style games, leaderboards, and competitive play.

## Basic Usage

### Initialize and Load Scores

```pascal
uses HiScore;

var
  HS: THighScore;
  PlayerScore: LongInt;
begin
  { Initialize with game-specific salt }
  InitHighScore(HS, 'MYGAME_SALT_V1');

  { Load existing scores (returns False if file doesn't exist) }
  LoadHighScore('SCORES.XML', HS);

  { Check if player's score qualifies }
  PlayerScore := 12000;
  if IsHighScore(HS, PlayerScore) then
    WriteLn('New high score!')
  else
    WriteLn('Better luck next time!');
end;
```

### Save a New Score

```pascal
var
  HS: THighScore;
  PlayerName: String;
  PlayerScore: LongInt;
begin
  InitHighScore(HS, 'MYGAME_SALT_V1');
  LoadHighScore('SCORES.XML', HS);

  PlayerName := 'Alice';
  PlayerScore := 15000;

  { Add score and save (auto-sorts and limits to top 10) }
  if SaveHighScore('SCORES.XML', PlayerName, PlayerScore, HS) then
    WriteLn('Score saved!')
  else
    WriteLn('Score did not make top 10');
end;
```

### Display High Scores

```pascal
var
  HS: THighScore;
  i: Integer;
begin
  InitHighScore(HS, 'MYGAME_SALT_V1');
  LoadHighScore('SCORES.XML', HS);

  WriteLn('TOP SCORES:');
  WriteLn('-----------');
  for i := 0 to HS.Count - 1 do
    WriteLn(i + 1:2, '. ', HS.Names[i]:20, ' ', HS.Scores[i]:8);
end;
```

## API Reference

### Types

**THighScore**
```pascal
THighScore = record
  Names: array[0..MaxHighScores - 1] of String;
  Scores: array[0..MaxHighScores - 1] of LongInt;
  Count: Integer;  { Number of valid entries (0-10) }
  Salt: String;     { Salt for tamper protection }
end;
```
High score table with up to 10 entries.

### Constants

**MaxHighScores**
```pascal
const MaxHighScores = 10;
```
Maximum number of scores stored.

### Functions

**InitHighScore**
```pascal
procedure InitHighScore(var HS: THighScore; const SaltValue: String);
```
Initialize empty high score table with salt. **MUST** be called before LoadHighScore.
- `HS`: High score record to initialize
- `SaltValue`: Unique salt string (prevents cross-game tampering)

**LoadHighScore**
```pascal
function LoadHighScore(const FileName: String; var HS: THighScore): Boolean;
```
Load scores from XML file with hash verification.
- Returns `True` if loaded and hash verified
- Returns `False` if file missing, corrupt, or tampered
- On failure, HS is reset to empty (Count = 0)
- **IMPORTANT**: Call InitHighScore first to set the salt

**SaveHighScore**
```pascal
function SaveHighScore(const FileName: String; const Name: String;
                       Score: LongInt; var HS: THighScore): Boolean;
```
Add new score and save to file (if it qualifies for top 10).
- Automatically sorts by score (descending)
- Limits to 10 entries (lowest score bumped if full)
- Returns `True` if score was added
- Returns `False` if score too low or error saving

**IsHighScore**
```pascal
function IsHighScore(const HS: THighScore; Score: LongInt): Boolean;
```
Check if a score qualifies for top 10 (without modifying table).
- Returns `True` if table not full OR score beats lowest score
- Returns `False` if table full and score too low

**ComputeHighScoreHash**
```pascal
function ComputeHighScoreHash(const HS: THighScore): String;
```
Compute MD5 hash of all scores (for verification). Normally called internally.
- Returns 32-character hex string
- Hash includes: salt + all names + all scores
- Uses incremental MD5 to avoid 255-char String limit

## Complete Example

### Game with High Scores

```pascal
program MyGame;

uses
  HiScore, Keyboard;

const
  GameSalt = 'MYGAME_V1';
  ScoreFile = 'SCORES.XML';

var
  HS: THighScore;
  PlayerName: String;
  PlayerScore: LongInt;
  i: Integer;

procedure ShowHighScores;
var
  j: Integer;
begin
  WriteLn;
  WriteLn('===== HIGH SCORES =====');
  for j := 0 to HS.Count - 1 do
    WriteLn(j + 1:2, '. ', HS.Names[j]:20, ' ', HS.Scores[j]:8);
  WriteLn('=======================');
  WriteLn;
end;

begin
  { Initialize and load existing scores }
  InitHighScore(HS, GameSalt);
  LoadHighScore(ScoreFile, HS);

  { Simulate gameplay }
  PlayerName := 'Alice';
  PlayerScore := 15000;

  WriteLn('Game Over!');
  WriteLn('Your score: ', PlayerScore);
  WriteLn;

  { Check if high score }
  if IsHighScore(HS, PlayerScore) then
  begin
    WriteLn('NEW HIGH SCORE!');
    WriteLn;
    Write('Enter your name: ');
    ReadLn(PlayerName);

    { Save to table }
    if SaveHighScore(ScoreFile, PlayerName, PlayerScore, HS) then
      WriteLn('Score saved!')
    else
      WriteLn('Error saving score!');
  end
  else
    WriteLn('Not a high score this time.');

  { Display final table }
  ShowHighScores;
end.
```

## XML Format

Scores are stored in XML with MD5 hash attribute:

```xml
<?xml version="1.0"?>
<highscores hash="a3f8b9c2d1e4f5a6b7c8d9e0f1a2b3c4">
  <highscore name="Alice" score="15000"/>
  <highscore name="Bob" score="12000"/>
  <highscore name="Charlie" score="10000"/>
</highscores>
```

The `hash` attribute contains an MD5 checksum of:
```
Salt + Name[0] + Score[0] + Name[1] + Score[1] + ...
```

If **any** name, score, or the hash itself is modified, LoadHighScore will detect tampering and reject the file.

## Tamper Protection

### How It Works

1. **Salted Hash**: Each game uses a unique salt (prevents copying scores between games)
2. **Incremental MD5**: Hashes all data without String length limits
3. **Verification on Load**: Recomputes hash and compares with stored hash
4. **Rejection on Mismatch**: Returns empty table if hash doesn't match

### What Gets Protected

✅ **Protected:**
- Manual editing of scores in XML file
- Changing player names
- Copying scores from another game
- Modifying the hash itself

❌ **Not Protected:**
- Deleting the entire file (creates fresh table)
- Using a hex editor to modify memory at runtime
- Debugger-based cheating

### Salt Best Practices

```pascal
{ Good salts (unique per game/version) }
const
  GameSalt = 'ASTEROIDS_V1_2024';
  GameSalt = 'TETRIS_CLONE_BUILD_42';
  GameSalt = 'PACMAN_REMAKE_FINAL';

{ Bad salts (too generic or reused) }
const
  GameSalt = 'GAME';           { Not unique }
  GameSalt = 'HIGHSCORE';      { Not game-specific }
  GameSalt = '';               { No protection! }
```

**Tip:** Store salt in GLOBALS.PAS as a constant, pass to InitHighScore.

## Integration with GLOBALS.PAS

### Define Salt in GLOBALS.PAS

```pascal
unit Globals;

interface

const
  GameTitle = 'My Game';
  GameVersion = '1.0';
  HighScoreSalt = 'MYGAME_HIGHSCORE_V1';  { Unique salt }
```

### Use in Your Game

```pascal
uses HiScore, Globals;

var
  HS: THighScore;
begin
  InitHighScore(HS, HighScoreSalt);  { Salt from Globals }
  LoadHighScore('SCORES.XML', HS);
end;
```

This keeps salts centralized and prevents accidental reuse across projects.

## Common Patterns

### Check Before Prompting Name

```pascal
{ Only prompt for name if score qualifies }
if IsHighScore(HS, FinalScore) then
begin
  WriteLn('NEW HIGH SCORE!');
  Write('Enter name: ');
  ReadLn(PlayerName);
  SaveHighScore('SCORES.XML', PlayerName, FinalScore, HS);
end;
```

### Default Scores for First Run

```pascal
procedure InitializeDefaultScores;
begin
  InitHighScore(HS, GameSalt);

  { Add default scores if file doesn't exist }
  if not LoadHighScore('SCORES.XML', HS) then
  begin
    SaveHighScore('SCORES.XML', 'Alice', 10000, HS);
    SaveHighScore('SCORES.XML', 'Bob', 8000, HS);
    SaveHighScore('SCORES.XML', 'Charlie', 6000, HS);
  end;
end;
```

### Reset Scores (Debug/Testing)

```pascal
procedure ResetHighScores;
var
  NewHS: THighScore;
begin
  InitHighScore(NewHS, GameSalt);
  { Save empty table (overwrites existing file) }
  SaveHighScore('SCORES.XML', 'Player', 0, NewHS);
end;
```

## Performance

- **Load**: ~10-50ms on 286 @ 12 MHz (depends on file size)
- **Save**: ~20-100ms on 286 @ 12 MHz (XML write + MD5 hash)
- **Hash Computation**: ~5-20ms for 10 entries (incremental MD5)

**Recommendations:**
- Load at startup or menu screen (not during gameplay)
- Save immediately after game over (before displaying scores)
- Cache HS in memory; don't reload every frame

## Security Notes

### What This Unit Does

✅ Prevents **casual cheating** (editing XML in Notepad)
✅ Detects **accidental corruption** (disk errors, bad edits)
✅ Prevents **score copying** between games (unique salts)

### What This Unit Doesn't Do

❌ Doesn't prevent **memory editing** (use debugger anti-cheat)
❌ Doesn't prevent **file deletion** (backups recommended)
❌ Doesn't encrypt data (hash verification only)

MD5 is cryptographically broken for adversarial use, but **perfect** for this use case (game high scores in 1994-era DOS environment).

## Troubleshooting

### LoadHighScore Always Returns False

**Cause:** Salt mismatch or file doesn't exist.

**Fix:**
```pascal
{ Make sure InitHighScore uses the SAME salt every time }
InitHighScore(HS, 'MYGAME_V1');  { Don't change this! }
LoadHighScore('SCORES.XML', HS);
```

### Scores Get Reset After Editing XML

**Cause:** Hash verification failed (tamper detection working correctly).

**Fix:** Don't edit XML manually. Use SaveHighScore to add scores.

### SaveHighScore Returns False

**Possible causes:**
1. Score too low (didn't make top 10) - Expected behavior
2. Disk write error - Check disk space
3. Invalid filename - Use 8.3 format for DOS

## Files

- **UNITS\HISCORE.PAS** - Main implementation
- **TESTS\HISTEST.PAS** - Comprehensive test suite
- **TESTS\CHISTEST.BAT** - Compile test

## Example: XICLONE

See **XICLONE\GAMESCR.PAS** for a real-world implementation in the XICLONE game.

## Dependencies

- **MD5.PAS** - MD5 hashing (incremental API)
- **MINIXML.PAS** - XML loading/saving
- **STRUTIL.PAS** - IntToStr, StrToInt

## See Also

- [MD5.PAS](MD5.md) - MD5 cryptographic hash
- [MINIXML.PAS](MINIXML.md) - XML parser/writer
- [STRUTIL.PAS](STRUTIL.md) - String utilities
