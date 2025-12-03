unit GameScr;

interface

uses
  VGA, GameUnit, BaseScr, XiStyle, XiTypes;

const
  { Playfield dimensions }
  PlayfieldCols = 6;
  PlayfieldRows = 12;
  TileSize = 16;

type
  { Gem colors }
  TGemColor = (
    Gem_Empty,       { 0 - No gem }
    Gem_Red,         { 1 - Red gem }
    Gem_Yellow,      { 2 - Yellow gem }
    Gem_Green,       { 3 - Green gem }
    Gem_Blue,        { 4 - Blue gem }
    Gem_Pink,        { 5 - Pink gem }
    Gem_Purple,      { 6 - Purple gem }
    Gem_MagicJewel   { 7 - Special multi-colored gem }
  );

  { Playfield grid }
  TPlayfield = record
    Tiles: array[0..PlayfieldCols - 1, 0..PlayfieldRows - 1] of TGemColor;
    TileChanged: array[0..PlayfieldCols - 1, 0..PlayfieldRows - 1] of Boolean;
  end;

  { Falling gem stack }
  TGemStack = record
    Gems: array[0..2] of TGemColor;  { Top, Middle, Bottom }
    GridX: Integer;     { Grid column (0-5) }
    PixelX: Integer;    { Pixel X position (for rendering) }
    PixelY: Real;       { Pixel Y position (smooth falling) }
    FallSpeed: Real;    { Pixels per second }
    Active: Boolean;    { Is stack currently falling? }
  end;

type 
  PGameScreen = ^TGameScreen;
  TGameScreen = object(TBaseScreen)

    { Images }
    BackgroundImage: PImage;
    GemsImage: PImage;

    { Game data }
    Playfield: TPlayfield;
    CurrentStack: TGemStack;
    LastStackY: Real;
    LastStackX: Integer;  { Track last rendered position }

    { Game state }
    Score: LongInt;
    Level: Integer;
    Blocks: Integer;
    NeedMatchCheck: Boolean;
    FlashTimer: Real;
    FlashActive: Boolean;
    FlashTiles: array[0..PlayfieldCols * PlayfieldRows - 1] of Boolean;

    { HUD tracking - for dirty rectangle optimization }
    LastScore: LongInt;
    LastLevel: Integer;
    LastBlocks: Integer;

    { Next stack preview gems }
    NextStackGems: array [0..2] of TGemColor;

    Paused: Boolean;

    constructor Init(G: PGame);
    destructor Done; virtual;
    procedure Update(DT: Real); virtual;    
  end;

implementation

const
  { Screen positions }
  PlayfieldX = 113;  { Game stage start position }
  PlayfieldY = 4;

  { Game tuning }
  InitialFallSpeed = 16.0; { 1 tile per second }
  FastFallSpeed = 160.0;   { 10 tile per second, when holding down }

  { Next stack preview position }
  NextStackX = 230;
  NextStackY = 31;
  NextLabelX = 226;
  NextLabelY = 17;

  StatLabelsX = 99;


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

procedure CheckForMatches;
var
  GemsRemoved: Integer;
begin
  { Find matches and mark them for flashing }
  GemsRemoved := FindAndRemoveMatches(Playfield, FlashTiles);

  if GemsRemoved > 0 then
  begin
    { Start flash effect }
    FlashActive := True;
    FlashTimer := 0.0;

    { Update score }
    Inc(Score, GemsRemoved * 10);
  end;
end;

constructor TGameScreen.Init(G: PGame);
begin
  inherited Init(G);
  GemsImage       := G^.ResMan.GetImage('gems1');
  BackgroundImage := G^.ResMan.GetImage('bg1');
end;

destructor TGameScreen.Done;
begin
end;

procedure TGameScreen.Update(DT: Real);
begin
end;

end.