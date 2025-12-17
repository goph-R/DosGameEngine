unit GameScr;

interface

uses
  VGA, VGAFont, VGAPrint, VGAUI, DRect, Keyboard, GameUnit, PCX, StrUtil,
  Globals, BaseScr, HiScore;

const
  { Playfield dimensions }
  PlayfieldCols = 6;
  PlayfieldRows = 12;

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

  MaxDialogButtons = 10;

type

  { Playfield grid }
  TPlayfield = record
    Tiles: array[0..PlayfieldCols - 1, 0..PlayfieldRows - 1] of TGemColor;
    TileChanged: array[0..PlayfieldCols - 1, 0..PlayfieldRows - 1] of Boolean;
  end;
  
  TGemStack = record
    Gems: array[0..2] of TGemColor;  { Top, Middle, Bottom }
    GridX: Integer;     { Grid column (0-5) }
    PixelX: Integer;    { Pixel X position (for rendering) }
    PixelY: Real;       { Pixel Y position (smooth falling) }
    FallSpeed: Real;    { Pixels per second }
    Active: Boolean;    { Is stack currently falling? }
  end;  

  PGameScreen = ^TGameScreen;
  TGameScreen = object(TBaseScreen)

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
    NeedSpawnRetry: Boolean;  { Retry spawn after matches clear }
    FlashTimer: Real;
    FlashActive: Boolean;
    FlashTiles: array[0..PlayfieldCols * PlayfieldRows - 1] of Boolean;

    { Combo system }
    ComboMultiplier: Integer;  { Current combo multiplier (1 = no combo, 2 = 2x, etc.) }
    IsComboCheck: Boolean;     { True if current match check is part of gravity combo chain }

    { HUD tracking - for dirty rectangle optimization }
    LastScore: LongInt;
    LastLevel: Integer;
    LastBlocks: Integer;

    { Next stack preview gems }
    NextStackGems: array [0..2] of TGemColor;

    { Flash message }
    FlashMessageText: String;
    FlashMessageTimer: Real;
    FlashMessageNeedsClear: Boolean;
    FlashMessageActive: Boolean;
    FlashMessageBackground: TImage;  { Saved area under flash message }
    FlashMessageBackgroundX: Integer;
    FlashMessageBackgroundY: Integer;
    FlashMessageWasOn: Boolean;

    { High scores }
    HighScoreReached: Boolean;

    Paused: Boolean;

    constructor Init;
    destructor Done; virtual;

    procedure Show; virtual;
    procedure InitPlayfield;
    procedure ResetGameState;
    procedure DrawStaticHUD;

    procedure Update(DT: Real); virtual;
    procedure UpdateFallingStack(DT: Real);
    procedure HandleStackInput;
    procedure TryMoveStackHoriz(Direction: Integer);
    procedure CheckForMatches;
    procedure LandStack;
    function RandomGemColor: TGemColor;
    function SpawnStack(First: Boolean): Boolean;
    procedure ShowGameOver;
    procedure RotateStack;
    function CheckStackCollision(CheckX, StartCheckY: Integer): Boolean;
    function CountMatchInDirection(StartX, StartY, DX, DY: Integer; Color: TGemColor): Integer;
    function FindAndRemoveMatches: Integer;
    procedure RemoveFlashedGems;
    procedure ApplyGravity;

    procedure DrawGemFlash(GemColor: TGemColor; X, Y: Integer; FlashOn: Boolean);
    procedure RenderPlayfield;
    procedure RenderStack;
    procedure RenderNextStack;
    procedure RenderHUD;
    procedure RenderFlashMessage;
    procedure RenderFrame;
    procedure FullRender;

    procedure ShowFlashMessage(Text: String; SoundName: String);
  end;

  TStatLabelInfo = record
    Y: Integer;
    Text: String;
  end;

const
  StatLabelInfos: array[0..2] of TStatLabelInfo = (
    (Y: 17;  Text: 'Score:'),
    (Y: 58;  Text: 'Level:'),
    (Y: 99;  Text: 'Blocks:')
  );

implementation

constructor TGameScreen.Init;
begin
  inherited Init;

  { Initialize flash message state }
  FlashMessageActive := False;
  FlashMessageTimer := 0.0;
  FlashMessageText := '';
  FlashMessageNeedsClear := False;
  FlashMessageBackground.Data := nil;  { Initialize to prevent freeing garbage }

  { Initialize high score state }
  HighScoreReached := False;
end;

destructor TGameScreen.Done;
begin
  FreeImage(FlashMessageBackground);
end;

procedure TGameScreen.DrawStaticHUD;
var
  i: Integer;
begin
  for i := Low(StatLabelInfos) to High(StatLabelInfos) do
    PrintFontTextRight(
      StatLabelsX,
      StatLabelInfos[i].Y,
      StatLabelInfos[i].Text,
      FontSmall^,
      Game.BackgroundBuffer
    );

  PrintFontText(NextLabelX, NextLabelY, 'Next:', FontSmall^, Game.BackgroundBuffer);
end;

procedure TGameScreen.Show;
begin
  { Show loading message while decompressing PCX (takes ~2-3s on 8MHz) }
  ClearFrameBuffer(Game.ScreenBuffer);
  PrintText(120, 95, 'Loading...', 15, Game.ScreenBuffer);

  { Load background (slow: RLE decompression) }
  LoadPCXToFrameBuffer('DATA\BG1.PCX', Game.BackgroundBuffer);

  DrawStaticHUD;

  { Play game music }
  Game.PlayMusic('normal');

  { Initalize buffers }
  CopyFrameBuffer(Game.BackgroundBuffer, Game.BackBuffer);
  CopyFrameBuffer(Game.BackBuffer, Game.ScreenBuffer);

  ResetGameState;

  { Reset timing to prevent delta time jump }
  Game.ResetTiming;
end;

procedure TGameScreen.ResetGameState;
begin
  { Initialize game state }
  Score := 0;
  Level := 1;
  Blocks := 0;
  NeedMatchCheck := False;
  NeedSpawnRetry := False;
  FlashActive := False;
  FlashTimer := 0.0;
  NextDialog := Dialog_None;
  BackDialog := Dialog_None;

  { Reset combo system }
  ComboMultiplier := 1;
  IsComboCheck := False;

  { Reset high score flag for new game session }
  HighScoreReached := False;

  { Initialize HUD tracking (force initial render) }
  LastScore := -1;
  LastLevel := -1;
  LastBlocks := -1;

  { Initialize playfield }
  InitPlayfield;

  { Initialize random number generator }
  Randomize;

  { Spawn first falling stack }
  SpawnStack(True);
  RenderNextStack;

  { Render initial playfield state }
  RenderPlayfield;
  FlushDirtyRects(Game.BackBuffer);
end;

procedure TGameScreen.ShowFlashMessage(Text: String; SoundName: String);
var
  SoundID: Integer;
  TextWidth: Integer;
  TextX, TextY: Integer;
begin
  FlashMessageText := Text;
  FlashMessageActive := True;
  FlashMessageWasOn := False;
  FlashMessageTimer := 0.0;
  FlashMessageNeedsClear := False;

  FreeImage(FlashMessageBackground);

  { Play sound if specified }
  if SoundName <> '' then
  begin
    SoundID := Game.ResMan.GetSound(SoundName);
    if SoundID >= 0 then
      Game.ResMan.SoundBank.PlaySound(SoundID);
  end;
end;

procedure TGameScreen.CheckForMatches;
var
  GemsRemoved: Integer;
  ComboText: String;
begin
  { Find matches and mark them for flashing }
  GemsRemoved := FindAndRemoveMatches;

  if GemsRemoved > 0 then
  begin
    { Start flash effect }
    FlashActive := True;
    FlashTimer := 0.0;

    { Handle combo system }
    if IsComboCheck then
    begin
      { This is a match after gravity - increment combo }
      Inc(ComboMultiplier);
      if ComboMultiplier > 1 then
      begin
        ComboText := IntToStr(ComboMultiplier) + 'x combo!';
        ShowFlashMessage(ComboText, '');
      end;
    end;

    { Update score with combo multiplier }
    Inc(Score, GemsRemoved * 10 * ComboMultiplier);

    { Check for high score (only show message once per session) }
    if (not HighScoreReached) and IsHighScore(HighScoreTable, Score) then
    begin
      HighScoreReached := True;
      ShowFlashMessage('High Score!', '');
    end;
  end
  else
  begin
    { No matches found - reset combo }
    ComboMultiplier := 1;
  end;
end;

procedure TGameScreen.LandStack;
var
  i: Integer;
  GridY: Integer;
  R: TRectangle;
begin
  { --- FIX: Clear the LAST RENDERED position, not the current internal position --- }

  R.X := LastStackX;
  R.Y := Trunc(LastStackY) + PlayfieldY;
  R.Width := TileSize;
  R.Height := TileSize * 3;

  { CopyFrameBufferRect now handles clipping automatically }
  CopyFrameBufferRect(Game.BackgroundBuffer, R, Game.BackBuffer, R.X, R.Y);
  AddDirtyRect(R);

  { --- Logic to place gems in grid --- }

  { Convert the SNAPPED pixel Y to grid Y }
  GridY := Trunc(CurrentStack.PixelY) div TileSize;

  { Place gems on playfield }
  for i := 0 to 2 do
  begin
    if (GridY + i >= 0) and (GridY + i < PlayfieldRows) then
    begin
      Playfield.Tiles[CurrentStack.GridX, GridY + i] := CurrentStack.Gems[i];
      Playfield.TileChanged[CurrentStack.GridX, GridY + i] := True;
    end;
  end;

  { Deactivate stack and spawn new one }
  CurrentStack.Active := False;

  if not SpawnStack(False) then
  begin
    { Check if there are any matches that could clear space }
    { If no matches, it's truly game over }
    if not FlashActive then  { Don't check if already flashing }
    begin
      if FindAndRemoveMatches = 0 then
      begin
        { Game Over - couldn't spawn and no matches to clear }
        SetNextDialog(Dialog_GameOver);
      end
      else
      begin
        { Matches found - start flash effect and retry spawn after clear }
        FlashActive := True;
        FlashTimer := 0.0;
        NeedSpawnRetry := True;
        { Note: Don't set NeedMatchCheck - we already handled the match }
      end;
    end;
  end
  else
  begin
    RenderNextStack;
    { Schedule match check for next frame (after render completes) }
    { This is NOT a combo check - it's the first match after landing }
    ComboMultiplier := 1;
    IsComboCheck := False;
    NeedMatchCheck := True;
  end;
end;

procedure TGameScreen.UpdateFallingStack(DT: Real);
var
  NewY: Real;
  GridY: Integer;
  PixelsFallen: Real;
  NextStepBlocked: Boolean;
begin
  if not CurrentStack.Active then Exit;

  { Calculate pixels to fall this frame }
  PixelsFallen := CurrentStack.FallSpeed * DT;

  { Calculate tentative new position }
  NewY := CurrentStack.PixelY + PixelsFallen;
  
  { Calculate the primary grid row }
  GridY := Trunc(NewY) div TileSize;

  { CHECK 1: HARD COLLISION }
  { If we moved a full tile and hit something strictly at this new GridY }
  if (GridY + 3 > PlayfieldRows) or CheckStackCollision(CurrentStack.GridX, GridY) then
  begin
    { We hit something. Back up to the previous valid row (GridY - 1) and land. }
    CurrentStack.PixelY := (GridY - 1) * TileSize;
    LandStack;
  end
  else
  begin
    { CHECK 2: LOOKAHEAD (The Fix) }
    { If the stack is not perfectly aligned (fraction > 0), it means the bottom }
    { of the stack is visually entering the territory of the NEXT row setup (GridY+3). }
    
    if (NewY - (GridY * TileSize)) > 0.1 then
    begin
      { Check if the NEXT grid position down is blocked }
      NextStepBlocked := (GridY + 1 + 3 > PlayfieldRows) or
                         CheckStackCollision(CurrentStack.GridX, GridY + 1);

      if NextStepBlocked then
      begin
        { The space we are trying to slide into is blocked. }
        { Force snap to the current integer grid line and land immediately. }
        CurrentStack.PixelY := GridY * TileSize;
        LandStack;
        Exit;
      end;
    end;

    { No collision detected, allow movement }
    CurrentStack.PixelY := NewY;
  end;
end;

{ Input handling }
procedure TGameScreen.TryMoveStackHoriz(Direction: Integer);
var
  NewX: Integer;
  GridY: Integer;
  PixelOffset: Integer;
  CanMove: Boolean;
begin
  if not CurrentStack.Active then
    Exit;

  GridY := Trunc(CurrentStack.PixelY) div TileSize;
  PixelOffset := Trunc(CurrentStack.PixelY) mod TileSize;

  NewX := CurrentStack.GridX + Direction;

  { Bounds check }
  if (NewX < 0) or (NewX >= PlayfieldCols) then
    Exit;

  { 1. Check if the stack fits at the current row }
  CanMove := not CheckStackCollision(NewX, GridY);

  { 2. If we are in-between rows, also check one row lower }
  if CanMove and (PixelOffset > 0) then
    if CheckStackCollision(NewX, GridY + 1) then
      CanMove := False;

  if not CanMove then
    Exit;

  CurrentStack.GridX := NewX;
  CurrentStack.PixelX := PlayfieldX + (NewX * TileSize);
end;

procedure TGameScreen.HandleStackInput;
begin
  if not CurrentStack.Active then Exit;

  { Horizontal movement }
  if IsKeyPressed(Key_Left) then
    TryMoveStackHoriz(-1);
  if IsKeyPressed(Key_Right) then
    TryMoveStackHoriz(+1);

  { Rotation }
  if IsKeyPressed(Key_Space) then
    RotateStack;

  { Fast fall }
  if IsKeyDown(Key_Down) then
    CurrentStack.FallSpeed := FastFallSpeed
  else
    CurrentStack.FallSpeed := InitialFallSpeed;
end;

{$F+}

procedure PauseContinueAction;
begin
  SetNextDialog(Dialog_None);
  DialogUI.Stop;
end;

procedure PauseDialogUpdate;
begin
  if IsKeyPressed(Key_Escape) then
    PauseContinueAction;
end;

procedure PauseContinueButtonEvent(var Widget: TWidget; var Event: TEvent);
begin
  if DialogUI.IsEnter(Event) then
    PauseContinueAction;
end;

procedure PauseQuitButtonEvent(var Widget: TWidget; var Event: TEvent);
begin
  if DialogUI.IsEnter(Event) then
  begin
    SetNextDialog(Dialog_ConfirmQuit);
    BackDialog := Dialog_Paused;
    DialogUI.Stop;
  end;
end;

procedure GameOverSubmitScoreButtonEvent(var Widget: TWidget; var Event: TEvent);
begin
  if DialogUI.IsEnter(Event) then
  begin
    { TODO: Implement score submission }
  end;
end;

procedure GameOverRestartButtonEvent(var Widget: TWidget; var Event: TEvent);
begin
  if DialogUI.IsEnter(Event) then
  begin
    SetNextDialog(Dialog_ConfirmRestart);
    BackDialog := Dialog_GameOver;
    DialogUI.Stop;
  end;
end;

procedure GameOverQuitButtonEvent(var Widget: TWidget; var Event: TEvent);
begin
  if DialogUI.IsEnter(Event) then
  begin
    SetNextDialog(Dialog_ConfirmQuit);
    BackDialog := Dialog_GameOver;
    DialogUI.Stop;
  end;
end;

procedure ConfirmDialogUpdate;
begin
  if IsKeyPressed(Key_Escape) then
  begin
    ConfirmDialogAnswer := False;  { Treat Escape as cancel }
    SetNextDialog(BackDialog);
    DialogUI.Stop;
  end;
end;

{$F-}

procedure TGameScreen.ShowGameOver;
var
  ScoreText: String;
  DialogHeight: Word;
begin
  { Display final score }
  ScoreText := 'Final Score: ' + IntToStr(Score);

  { Determine dialog height based on high score }
  if HighScoreReached then
    DialogHeight := 128  { 108 + 20 for extra button }
  else
    DialogHeight := 108;

  { Create game over dialog }
  InitDialog('GAME OVER', DialogHeight);

  AddDialogLabel(ScoreText);

  { Add Submit Score button if high score was reached }
  if HighScoreReached then
    AddDialogButton('Submit Score', GameOverSubmitScoreButtonEvent);

  AddDialogButton('Restart', GameOverRestartButtonEvent);
  AddDialogButton('Quit to Menu', GameOverQuitButtonEvent);

  { Run dialog event loop }
  ShowDialog(nil);
end;


procedure TGameScreen.Update(DT: Real);
begin

  if NextDialog = Dialog_GameOver then
    ShowGameOver;

  if NextDialog = Dialog_Paused then
  begin
    InitDialog('PAUSED', 88);
    AddDialogButton('Continue Game', PauseContinueButtonEvent);
    AddDialogButton('Quit to Menu', PauseQuitButtonEvent);
    ShowDialog(PauseDialogUpdate);

    { Restore game screen after dialog closes }
    if NextDialog = Dialog_None then
    begin
      CopyFrameBuffer(Game.BackgroundBuffer, Game.BackBuffer);
      FullRender;
    end;
  end;

  if NextDialog = Dialog_ConfirmRestart then
  begin
    if ShowConfirm('Do you want to' + #10 + 'restart the game?', ConfirmDialogUpdate) then
    begin
      ResetGameState;
      SetNextDialog(Dialog_None);
      CopyFrameBuffer(Game.BackgroundBuffer, Game.BackBuffer);
      FullRender;
    end
    else
      SetNextDialog(BackDialog);
  end;

  if NextDialog = Dialog_ConfirmQuit then
  begin
    if ShowConfirm('Do you want to quit?', ConfirmDialogUpdate) then
    begin
      Game.Stop;
      Exit;
    end;
    SetNextDialog(BackDialog);
  end;

  if NextDialog = Dialog_None then
  begin
    { Pause on ESC }
    if IsKeyPressed(Key_Escape) then
    begin
      SetNextDialog(Dialog_Paused);
      BackDialog := Dialog_None;
    end;  

    { Update flash timer }
    if FlashActive then
    begin
      FlashTimer := FlashTimer + DT;

      { After 0.5 seconds of flashing, remove gems and apply gravity }
      if FlashTimer >= 0.5 then
      begin
        FlashActive := False;
        RemoveFlashedGems;
        ApplyGravity;

        { Retry spawn if needed (from failed spawn at top) }
        if NeedSpawnRetry then
        begin
          NeedSpawnRetry := False;
          if not SpawnStack(False) then
          begin
            { Still can't spawn - game over }
            SetNextDialog(Dialog_GameOver);
          end
          else
          begin
            RenderNextStack;
          end;
        end;

        { Check for new matches after gravity }
        { Any matches found now are part of a combo chain }
        IsComboCheck := True;
        NeedMatchCheck := True;
      end;
    end
    else
    begin
      { Only allow stack movement when not flashing }
      HandleStackInput;
      UpdateFallingStack(DT);
    end;

    { Render frame }
    RenderFrame;

    { Update flash message timer, after render! }
    if FlashMessageActive then
    begin
      FlashMessageTimer := FlashMessageTimer + DT;

      { After 0.5 seconds of flashing, hide message and mark for clear }
      if FlashMessageTimer >= 1.0 then
        FlashMessageActive := False;
    end;

  end;
end;

{ Initialization }

procedure TGameScreen.InitPlayfield;
var
  X, Y: Integer;
begin
  { Clear playfield }
  for Y := 0 to PlayfieldRows - 1 do
  begin
    for X := 0 to PlayfieldCols - 1 do
    begin
      Playfield.Tiles[X, Y] := Gem_Empty;
      Playfield.TileChanged[X, Y] := True;  { Mark all tiles as changed }
    end;
  end;
end;

{ Game logic }

function TGameScreen.RandomGemColor: TGemColor;
var
  R: Integer;
begin
  R := Random(6) + 1;  { 1-6 for colored gems, excluding empty and magic jewel }
  RandomGemColor := TGemColor(R);
end;

function TGameScreen.SpawnStack(First: Boolean): Boolean;
var
  SpawnCol: Integer;
  i: Integer;
begin
  SpawnCol := PlayfieldCols div 2;  { Middle column }

  { Check if spawn position is blocked (top row only) }
  if Playfield.Tiles[SpawnCol, 0] <> Gem_Empty then
  begin
    SpawnStack := False;  { Game Over - can't spawn }
    Exit;
  end;

  { Spawn position is clear - create new stack }
  if First then
  begin
    CurrentStack.Gems[0] := RandomGemColor;
    CurrentStack.Gems[1] := RandomGemColor;
    CurrentStack.Gems[2] := RandomGemColor;
  end
  else
  begin
    CurrentStack.Gems[0] := NextStackGems[0];
    CurrentStack.Gems[1] := NextStackGems[1];
    CurrentStack.Gems[2] := NextStackGems[2];
  end;

  CurrentStack.GridX := SpawnCol;
  CurrentStack.PixelX := PlayfieldX + (CurrentStack.GridX * TileSize);
  CurrentStack.PixelY := -3 * TileSize;  { Start above playfield }
  CurrentStack.FallSpeed := InitialFallSpeed;
  CurrentStack.Active := True;

  { Generate next stack preview }
  NextStackGems[0] := RandomGemColor;
  NextStackGems[1] := RandomGemColor;
  NextStackGems[2] := RandomGemColor;

  { Initialize last position to current position }
  LastStackX := CurrentStack.PixelX;
  LastStackY := CurrentStack.PixelY;

  SpawnStack := True;  { Success }
end;

procedure TGameScreen.RotateStack;
var
  Temp: TGemColor;
begin
  { Rotate gems: Bottom -> Top, Middle -> Bottom, Top -> Middle }
  Temp := CurrentStack.Gems[2];
  CurrentStack.Gems[2] := CurrentStack.Gems[1];
  CurrentStack.Gems[1] := CurrentStack.Gems[0];
  CurrentStack.Gems[0] := Temp;
end;

function TGameScreen.CheckStackCollision(CheckX, StartCheckY: Integer): Boolean;
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
      if Playfield.Tiles[CheckX, CheckY] <> Gem_Empty then
      begin
        CheckStackCollision := True;
        Exit;
      end;
    end;
  end;
end;

function TGameScreen.CountMatchInDirection(StartX, StartY, DX, DY: Integer; Color: TGemColor): Integer;
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
        ((Playfield.Tiles[CheckX, CheckY] = Color) or
         (Playfield.Tiles[CheckX, CheckY] = Gem_MagicJewel)) do
  begin
    Inc(Count);
    Inc(CheckX, DX);
    Inc(CheckY, DY);
  end;

  CountMatchInDirection := Count;
end;

function TGameScreen.FindAndRemoveMatches: Integer;
const
  { Direction vectors: DX, DY for horizontal, vertical, and two diagonals }
  Directions: array[0..3, 0..1] of Integer = (
    (1, 0),   { Horizontal right }
    (0, 1),   { Vertical down }
    (1, 1),   { Diagonal down-right }
    (-1, 1)   { Diagonal down-left }
  );
var
  X, Y: Integer;
  Color: TGemColor;
  MatchLen: Integer;
  GemsRemoved: Integer;
  MarkForRemoval: array[0..PlayfieldCols - 1, 0..PlayfieldRows - 1] of Boolean;
  i, MarkX, MarkY: Integer;
  TileIndex: Integer;
  Dir: Integer;
  DX, DY: Integer;
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
      Color := Playfield.Tiles[X, Y];

      { Skip empty tiles }
      if Color = Gem_Empty then Continue;

      { Check all four directions }
      for Dir := 0 to 3 do
      begin
        DX := Directions[Dir, 0];
        DY := Directions[Dir, 1];

        MatchLen := CountMatchInDirection(X, Y, DX, DY, Color);
        if MatchLen >= 3 then
        begin
          for i := 0 to MatchLen - 1 do
          begin
            MarkX := X + (i * DX);
            MarkY := Y + (i * DY);
            if (MarkX >= 0) and (MarkX < PlayfieldCols) and
               (MarkY >= 0) and (MarkY < PlayfieldRows) then
              MarkForRemoval[MarkX, MarkY] := True;
          end;
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

procedure TGameScreen.RemoveFlashedGems;
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
        Playfield.Tiles[X, Y] := Gem_Empty;
        Playfield.TileChanged[X, Y] := True;
        FlashTiles[TileIndex] := False;
      end;
    end;
  end;
end;

procedure TGameScreen.ApplyGravity;
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
        if (Playfield.Tiles[X, Y] = Gem_Empty) and
           (Playfield.Tiles[X, Y - 1] <> Gem_Empty) then
        begin
          { Move gem down }
          Playfield.Tiles[X, Y] := Playfield.Tiles[X, Y - 1];
          Playfield.Tiles[X, Y - 1] := Gem_Empty;

          { Mark both tiles as changed }
          Playfield.TileChanged[X, Y] := True;
          Playfield.TileChanged[X, Y - 1] := True;

          Moved := True;
        end;
      end;
    end;
  until not Moved;
end;

procedure TGameScreen.DrawGemFlash(GemColor: TGemColor; X, Y: Integer; FlashOn: Boolean);
var
  GemRect: TRectangle;
  GemIndex: Integer;
begin
  GemRect.X := X;
  GemRect.Y := Y;
  GemRect.Width := TileSize;
  GemRect.Height := TileSize;

  if FlashOn then
  begin
    { Show the gem when flash is on }
    GemIndex := Ord(GemColor);
    GemRect.X := GemIndex * TileSize;
    GemRect.Y := 0;
    GemRect.Width := TileSize;
    GemRect.Height := TileSize;
    PutImageRect(GemsImage^, GemRect, X, Y, True, Game.BackBuffer);
  end
  else
  begin
    { Show background when flash is off (gem disappears) }
    GemRect.X := X;
    GemRect.Y := Y;
    CopyFrameBufferRect(Game.BackgroundBuffer, GemRect, Game.BackBuffer, X, Y);
  end;
end;

procedure TGameScreen.RenderPlayfield;
var
  X, Y: Integer;
  PixelX, PixelY: Integer;
  R: TRectangle;
  FlashOn: Boolean;
  TileIndex: Integer;  
begin
  { Calculate flash state (blink every 100ms) }
  FlashOn := FlashActive and (Trunc(FlashTimer * 10) mod 2 = 0);

  { Render gems on playfield }
  for Y := 0 to PlayfieldRows - 1 do
  begin
    for X := 0 to PlayfieldCols - 1 do
    begin
      TileIndex := Y * PlayfieldCols + X;

      { Only redraw changed tiles or flashing tiles }
      if Playfield.TileChanged[X, Y] or (FlashActive and FlashTiles[TileIndex]) then
      begin
        PixelX := PlayfieldX + X * TileSize;
        PixelY := PlayfieldY + Y * TileSize;

        { If this tile is flashing, draw flash effect }
        if FlashActive and FlashTiles[TileIndex] then
        begin
          DrawGemFlash(Playfield.Tiles[X, Y], PixelX, PixelY, FlashOn);
        end
        else
        begin
          { Draw the gem at this position }
          DrawGem(Playfield.Tiles[X, Y], PixelX, PixelY);
        end;

        { Mark this tile as dirty }
        R.X := PixelX;
        R.Y := PixelY;
        R.Width := TileSize;
        R.Height := TileSize;
        AddDirtyRect(R);

        { Clear changed flag }
        Playfield.TileChanged[X, Y] := False;
      end;
    end;
  end;
end;

procedure TGameScreen.RenderStack;
var
  I: Integer;
  GemY: Integer;
  R: TRectangle;
begin
  if not CurrentStack.Active then Exit;

  { Set clipping to playfield bounds only }
  R.X := PlayfieldX;
  R.Y := PlayfieldY;
  R.Width := PlayfieldCols * TileSize;
  R.Height := PlayfieldRows * TileSize;
  SetClipRectangle(R);

  { --- STEP 1: CLEAR OLD POSITION --- }

  R.X := LastStackX;
  R.Y := Trunc(LastStackY) + PlayfieldY;
  R.Width := TileSize;
  R.Height := TileSize * 3;

  { Clip playfield top }
  if R.Y < PlayfieldY then
  begin
    Dec(R.Height, Abs(R.Y - PlayfieldY));
    R.Y := PlayfieldY;
  end;

  CopyFrameBufferRect(Game.BackgroundBuffer, R, Game.BackBuffer, R.X, R.Y);
  AddDirtyRect(R);

  { --- STEP 2: DRAW NEW POSITION --- }

  for I := 0 to 2 do
  begin
    { Calculate Y relative to the stack top }
    GemY := Trunc(CurrentStack.PixelY) + (I * TileSize);
    DrawGem(CurrentStack.Gems[I], CurrentStack.PixelX, GemY + PlayfieldY);
  end;

  { --- STEP 3: MARK DIRTY RECT FOR NEW POSITION --- }

  R.X := CurrentStack.PixelX;
  R.Y := Trunc(CurrentStack.PixelY) + PlayfieldY;
  R.Width := TileSize;
  R.Height := TileSize * 3;

  { Clip playfield top }
  if R.Y < PlayfieldY then
  begin
    Dec(R.Height, Abs(R.Y - PlayfieldY));
    R.Y := PlayfieldY;
  end;

  AddDirtyRect(R);

  { Save current position for next frame }
  LastStackX := CurrentStack.PixelX;
  LastStackY := CurrentStack.PixelY;

  { Reset clipping to full screen }
  R.X := 0;
  R.Y := 0;
  R.Width := 320;
  R.Height := 200;
  SetClipRectangle(R);
end;

procedure TGameScreen.RenderNextStack;
var
  i: Integer;
  R: TRectangle;
begin
  for i := 0 to 2 do
  begin
    DrawGem(NextStackGems[i], NextStackX, NextStackY + i * TileSize);
  end;

  R.X := NextStackX;
  R.Y := NextStackY;
  R.Width := TileSize;
  R.Height := TileSize * 3;
  AddDirtyRect(R);
end;

{ Helper function to zero-pad numbers }
function PadZero(Value: LongInt; Length: Integer): string;
var
  S: string;
begin
  S := IntToStr(Value);
  while System.Length(S) < Length do
    S := '0' + S;
  PadZero := S;
end;

procedure TGameScreen.RenderFlashMessage;
var
  FlashOn: Boolean;
  TextWidth: Integer;
  TextX, TextY: Integer;
  R: TRectangle;
begin
  { Always calculate text position and rectangle }
  TextWidth := GetTextWidth(FlashMessageText, FontLarge^);
  TextX := 160 - (TextWidth div 2);
  TextY := 100 - (FontLarge^.Height div 2);

  R.X := TextX;
  R.Y := TextY;
  R.Width := TextWidth;
  R.Height := FontLarge^.Height;

  { Handle final clear when flash message ends }
  if not FlashMessageActive then
  begin
    if FlashMessageNeedsClear then
    begin
      AddDirtyRect(R);
      FlashMessageNeedsClear := False;
    end;
    Exit;
  end;

  { Calculate flash state (blink every 200ms) }
  FlashOn := Trunc(FlashMessageTimer * 5) mod 2 = 0;

  { Only draw text when flash is on }
  if FlashOn then
  begin
    { Save the background (free old one first to prevent memory leak) }
    { This must be done every frame to capture moving stack behind message }
    FreeImage(FlashMessageBackground);
    GetImage(FlashMessageBackground, TextX, TextY, TextWidth, FontLarge^.Height, Game.BackBuffer);
    FlashMessageBackgroundX := TextX;
    FlashMessageBackgroundY := TextY;

    { Need to clear after dirty rectangles flushed }
    FlashMessageNeedsClear := True;

    { Draw the text }
    PrintFontText(TextX, TextY, FlashMessageText, FontLarge^, Game.BackBuffer);
  end;

  { Add dirty rect when flash turns on or off }
  if (FlashOn) or (not FlashOn and FlashMessageWasOn) then
    AddDirtyRect(R);

  FlashMessageWasOn := FlashOn;
end;

procedure TGameScreen.RenderHUD;
var
  {
  NextY: Integer;
  }
  R: TRectangle;
  ScoreText, LevelText, BlocksText: string;
  TextWidth: Integer;
  FreeMem: LongInt;
  S: string;
const
  ScoreY = 25;   { 17 + 8 }
  LevelY = 66;   { 58 + 8 }
  BlocksY = 107; { 99 + 8 }
begin
  {
  NextY := 10;

  if (ShowFPS) then
  begin    
    R.X := NextY;
    R.Y := 10;
    R.Width := 80;
    R.Height := 8;
    CopyFrameBufferRect(Game.BackgroundBuffer, R, Game.BackBuffer, R.X, R.Y);
    PrintText(10, 10, 'FPS: ' + IntToStr(FPS), 15, Game.BackBuffer);
    AddDirtyRect(R);
    Inc(NextY, R.Height + 2);
  end;

  if (ShowMem) then
  begin
    R.X := NextY;
    R.Y := 10;
    R.Width := 160;
    R.Height := 8;
    CopyFrameBufferRect(Game.BackgroundBuffer, R, Game.BackBuffer, R.X, R.Y);
    FreeMem := MemAvail;
    Str(FreeMem, S);
    PrintText(10, NextY, 'Free: ' + S + ' bytes', 15, Game.BackBuffer);
    AddDirtyRect(R);
    Inc(NextY, R.Height + 2);
  end; 
  } 

  R.X := 0;
  R.Width := StatLabelsX;
  R.Height := FontLarge^.Height;

  { Render Score number (only if changed) }
  if Score <> LastScore then
  begin
    ScoreText := PadZero(Score, 7);
    TextWidth := GetTextWidth(ScoreText, FontLarge^);

    { Clear area and redraw }
    R.Y := ScoreY;
    CopyFrameBufferRect(Game.BackgroundBuffer, R, Game.BackBuffer, R.X, R.Y);

    { Draw right-aligned }
    PrintFontTextRight(StatLabelsX, ScoreY, ScoreText, FontLarge^, Game.BackBuffer);
    AddDirtyRect(R);

    LastScore := Score;
  end;

  { Render Level number (only if changed) }
  if Level <> LastLevel then
  begin
    LevelText := PadZero(Level, 2);
    TextWidth := GetTextWidth(LevelText, FontLarge^);

    { Clear area and redraw }
    R.Y := LevelY;
    CopyFrameBufferRect(Game.BackgroundBuffer, R, Game.BackBuffer, R.X, R.Y);

    { Draw right-aligned }
    PrintFontTextRight(StatLabelsX, LevelY, LevelText, FontLarge^, Game.BackBuffer);
    AddDirtyRect(R);

    LastLevel := Level;
  end;

  { Render Blocks number (only if changed) }
  if Blocks <> LastBlocks then
  begin
    BlocksText := PadZero(Blocks, 3);
    TextWidth := GetTextWidth(BlocksText, FontLarge^);

    { Clear area and redraw }
    R.Y := BlocksY;
    CopyFrameBufferRect(Game.BackgroundBuffer, R, Game.BackBuffer, R.X, R.Y);

    { Draw right-aligned }
    PrintFontTextRight(StatLabelsX, BlocksY, BlocksText, FontLarge^, Game.BackBuffer);
    AddDirtyRect(R);

    LastBlocks := Blocks;
  end;
end;

procedure TGameScreen.RenderFrame;
begin
  { Render all game elements to BackBuffer }
  RenderPlayfield;
  RenderStack;
  RenderHUD;
  RenderFlashMessage;  { Render on top of everything }

  { Copy dirty regions to screen }
  FlushDirtyRects(Game.BackBuffer);

  { Clear the flashing message if needed }
  if FlashMessageNeedsClear then
    PutImage(FlashMessageBackground, FlashMessageBackgroundX, FlashMessageBackgroundY, False, Game.BackBuffer);

  { Check for matches AFTER rendering (deferred from LandStack) }
  if NeedMatchCheck then
  begin
    CheckForMatches;
    NeedMatchCheck := False;
  end;
end;

procedure TGameScreen.FullRender;
var
  X, Y: Integer;
begin
  { Clear any stale dirty rects from dialogs }
  ClearDirtyRects;

  { Mark all playfield tiles as changed to force full redraw }
  for Y := 0 to PlayfieldRows - 1 do
    for X := 0 to PlayfieldCols - 1 do
      Playfield.TileChanged[X, Y] := True;

  { Force HUD redraw by invalidating last values }
  LastScore := -1;
  LastLevel := -1;
  LastBlocks := -1;

  { Re-render all game elements }
  RenderPlayfield;
  RenderStack;
  RenderNextStack;
  RenderHUD;

  { Display the restored screen }
  CopyFrameBuffer(Game.BackBuffer, Game.ScreenBuffer);

  { Clear dirty rects since we did a full copy }
  ClearDirtyRects;
end;

end.