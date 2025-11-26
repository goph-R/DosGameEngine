{ ========================================================================== }
{ XILOGIC.PAS - XICLONE Game Logic                                          }
{                                                                            }
{ Core game rules and mechanics for XICLONE puzzle game.                    }
{                                                                            }
{ Features:                                                                  }
{   - Stack operations: spawn, rotate, random gem generation                }
{   - Collision detection: boundary and playfield checks                    }
{   - Match detection: 4-directional scanning (horiz/vert/diag)             }
{   - Gravity: cascade gems downward after removal                          }
{   - Flash system: mark matched gems for visual feedback                   }
{                                                                            }
{ All functions use explicit parameters (no globals) for testability.       }
{ ========================================================================== }

unit XILogic;

interface

uses XITypes;

{ Stack operations }
function RandomGemColor: TGemColor;
procedure SpawnStack(var Stack: TGemStack; var NextGems: array of TGemColor;
                     var LastX: Integer; var LastY: Real; First: Boolean);
procedure RotateStack(var Stack: TGemStack);

{ Collision detection }
function CheckStackCollision(const Field: TPlayfield; CheckX, StartCheckY: Integer): Boolean;

{ Match detection }
function CountMatchInDirection(const Field: TPlayfield; StartX, StartY, DX, DY: Integer;
                                Color: TGemColor): Integer;
function FindAndRemoveMatches(var Field: TPlayfield;
                               var FlashTiles: array of Boolean): Integer;

{ Gravity and removal }
procedure RemoveFlashedGems(var Field: TPlayfield; var FlashTiles: array of Boolean);
procedure ApplyGravity(var Field: TPlayfield);

implementation

function RandomGemColor: TGemColor;
var
  R: Integer;
begin
  R := Random(6) + 1;  { 1-6 for colored gems, excluding empty and magic jewel }
  RandomGemColor := TGemColor(R);
end;

procedure SpawnStack(var Stack: TGemStack; var NextGems: array of TGemColor;
                     var LastX: Integer; var LastY: Real; First: Boolean);
begin
  if First then
  begin
    Stack.Gems[0] := RandomGemColor;
    Stack.Gems[1] := RandomGemColor;
    Stack.Gems[2] := RandomGemColor;
  end
  else
  begin
    Stack.Gems[0] := NextGems[0];
    Stack.Gems[1] := NextGems[1];
    Stack.Gems[2] := NextGems[2];
  end;

  Stack.GridX := PlayfieldCols div 2;  { Start in middle column }
  Stack.PixelX := PlayfieldX + (Stack.GridX * TileSize);
  Stack.PixelY := -3 * TileSize;  { Start above playfield }
  Stack.FallSpeed := InitialFallSpeed;
  Stack.Active := True;

  { Generate next stack preview }
  NextGems[0] := RandomGemColor;
  NextGems[1] := RandomGemColor;
  NextGems[2] := RandomGemColor;

  { Initialize last position to current position }
  LastX := Stack.PixelX;
  LastY := Stack.PixelY;
end;

procedure RotateStack(var Stack: TGemStack);
var
  Temp: TGemColor;
begin
  { Rotate gems: Bottom -> Top, Middle -> Bottom, Top -> Middle }
  Temp := Stack.Gems[2];
  Stack.Gems[2] := Stack.Gems[1];
  Stack.Gems[1] := Stack.Gems[0];
  Stack.Gems[0] := Temp;
end;

function CheckStackCollision(const Field: TPlayfield; CheckX, StartCheckY: Integer): Boolean;
var
  i: Integer;
  CheckY: Integer;
begin
  CheckStackCollision := False;

  { Check playfield boundaries }
  if (CheckX < 0) or (CheckX >= PlayfieldCols) then
  begin
    CheckStackCollision := True;
    Exit;
  end;

  { Check collision with playfield gems }
  for i := 0 to 2 do
  begin
    CheckY := StartCheckY + i;
    if (CheckY >= 0) and (CheckY < PlayfieldRows) then
    begin
      if Field.Tiles[CheckX, CheckY] <> Gem_Empty then
      begin
        CheckStackCollision := True;
        Exit;
      end;
    end;
  end;
end;

function CountMatchInDirection(const Field: TPlayfield; StartX, StartY, DX, DY: Integer;
                                Color: TGemColor): Integer;
var
  Count: Integer;
  CheckX, CheckY: Integer;
begin
  Count := 1;  { Count starting gem }
  CheckX := StartX + DX;
  CheckY := StartY + DY;

  { Count consecutive matching gems in this direction }
  while (CheckX >= 0) and (CheckX < PlayfieldCols) and
        (CheckY >= 0) and (CheckY < PlayfieldRows) and
        ((Field.Tiles[CheckX, CheckY] = Color) or
         (Field.Tiles[CheckX, CheckY] = Gem_MagicJewel)) do
  begin
    Inc(Count);
    Inc(CheckX, DX);
    Inc(CheckY, DY);
  end;

  CountMatchInDirection := Count;
end;

function FindAndRemoveMatches(var Field: TPlayfield;
                               var FlashTiles: array of Boolean): Integer;
var
  X, Y: Integer;
  Color: TGemColor;
  MatchLen: Integer;
  GemsRemoved: Integer;
  MarkForRemoval: array[0..PlayfieldCols - 1, 0..PlayfieldRows - 1] of Boolean;
  i, MarkX, MarkY: Integer;
  TileIndex: Integer;
begin
  GemsRemoved := 0;

  { Clear mark array }
  for Y := 0 to PlayfieldRows - 1 do
    for X := 0 to PlayfieldCols - 1 do
      MarkForRemoval[X, Y] := False;

  { PHASE 1: Find all matches and mark them (don't remove yet!) }
  for Y := 0 to PlayfieldRows - 1 do
  begin
    for X := 0 to PlayfieldCols - 1 do
    begin
      Color := Field.Tiles[X, Y];

      { Skip empty tiles }
      if Color = Gem_Empty then Continue;

      { Check horizontal (right) }
      MatchLen := CountMatchInDirection(Field, X, Y, 1, 0, Color);
      if MatchLen >= 3 then
      begin
        for i := 0 to MatchLen - 1 do
        begin
          MarkX := X + i;
          if (MarkX >= 0) and (MarkX < PlayfieldCols) then
            MarkForRemoval[MarkX, Y] := True;
        end;
      end;

      { Check vertical (down) }
      MatchLen := CountMatchInDirection(Field, X, Y, 0, 1, Color);
      if MatchLen >= 3 then
      begin
        for i := 0 to MatchLen - 1 do
        begin
          MarkY := Y + i;
          if (MarkY >= 0) and (MarkY < PlayfieldRows) then
            MarkForRemoval[X, MarkY] := True;
        end;
      end;

      { Check diagonal down-right }
      MatchLen := CountMatchInDirection(Field, X, Y, 1, 1, Color);
      if MatchLen >= 3 then
      begin
        for i := 0 to MatchLen - 1 do
        begin
          MarkX := X + i;
          MarkY := Y + i;
          if (MarkX >= 0) and (MarkX < PlayfieldCols) and
             (MarkY >= 0) and (MarkY < PlayfieldRows) then
            MarkForRemoval[MarkX, MarkY] := True;
        end;
      end;

      { Check diagonal down-left }
      MatchLen := CountMatchInDirection(Field, X, Y, -1, 1, Color);
      if MatchLen >= 3 then
      begin
        for i := 0 to MatchLen - 1 do
        begin
          MarkX := X - i;
          MarkY := Y + i;
          if (MarkX >= 0) and (MarkX < PlayfieldCols) and
             (MarkY >= 0) and (MarkY < PlayfieldRows) then
            MarkForRemoval[MarkX, MarkY] := True;
        end;
      end;
    end;
  end;

  { PHASE 2: Copy marks to flash array and count }
  for Y := 0 to PlayfieldRows - 1 do
  begin
    for X := 0 to PlayfieldCols - 1 do
    begin
      TileIndex := Y * PlayfieldCols + X;
      FlashTiles[TileIndex] := MarkForRemoval[X, Y];
      if MarkForRemoval[X, Y] then
        Inc(GemsRemoved);
    end;
  end;

  FindAndRemoveMatches := GemsRemoved;
end;

procedure RemoveFlashedGems(var Field: TPlayfield; var FlashTiles: array of Boolean);
var
  X, Y: Integer;
  TileIndex: Integer;
begin
  { Remove all flashed gems }
  for Y := 0 to PlayfieldRows - 1 do
  begin
    for X := 0 to PlayfieldCols - 1 do
    begin
      TileIndex := Y * PlayfieldCols + X;
      if FlashTiles[TileIndex] then
      begin
        Field.Tiles[X, Y] := Gem_Empty;
        Field.TileChanged[X, Y] := True;
        FlashTiles[TileIndex] := False;
      end;
    end;
  end;
end;

procedure ApplyGravity(var Field: TPlayfield);
var
  X, Y: Integer;
  Moved: Boolean;
begin
  repeat
    Moved := False;

    { Scan bottom to top }
    for Y := PlayfieldRows - 1 downto 1 do
    begin
      for X := 0 to PlayfieldCols - 1 do
      begin
        { If empty space below a gem, move gem down }
        if (Field.Tiles[X, Y] = Gem_Empty) and
           (Field.Tiles[X, Y - 1] <> Gem_Empty) then
        begin
          { Move gem down }
          Field.Tiles[X, Y] := Field.Tiles[X, Y - 1];
          Field.Tiles[X, Y - 1] := Gem_Empty;

          { Mark both tiles as changed }
          Field.TileChanged[X, Y] := True;
          Field.TileChanged[X, Y - 1] := True;

          Moved := True;
        end;
      end;
    end;
  until not Moved;
end;

end.
