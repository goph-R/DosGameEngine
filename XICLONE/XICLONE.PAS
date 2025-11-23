{ XICLONE - Xixit/Columns Clone }
{ Phase 2: Playfield & Rendering }

program XICLONE;

uses
  Crt, VGA, PKMLoad, Keyboard, RTCTimer, VGAPrint, StrUtil;

const
  { Data path - all resources are in DATA\ subfolder }
  DataPath = 'DATA\';

  { Playfield dimensions }
  PlayfieldCols = 6;
  PlayfieldRows = 12;
  TileSize = 16;

  { Screen positions }
  PlayfieldX = 113;  { Game stage start position }
  PlayfieldY = 4;

  { Max dirty rectangles per frame }
  MaxDirtyRects = 96;  { 6x12 playfield = 72 tiles, plus HUD, stack, etc. }

  { Game tuning }
  InitialFallSpeed = 16.0; { 1 tile per second }
  FastFallSpeed = 160.0;   { 10 tile per second, when holding down }

  { Resource filenames }
  BackgroundFile = 'BG1.PKM';
  GemsFile = 'GEMS1.PKM';
  FontLargeImage = 'FONT-LG.PKM';
  FontLargeXML = 'FONT-LG.XML';
  FontSmallImage = 'FONT-SM.PKM';
  FontSmallXML = 'FONT-SM.XML';

  { Next stack preview position }
  NextStackX = 230;
  NextStackY = 30;

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

var
  { Frame buffers }
  BackBuffer: PFrameBuffer;
  ScreenBuffer: PFrameBuffer;
  BackgroundBuffer: PFrameBuffer;

  { Images }
  BackgroundImage: TImage;
  GemsImage: TImage;

  { Game data }
  Playfield: TPlayfield;
  CurrentStack: TGemStack;
  LastStackY: Real;
  LastStackX: Integer;  { Track last rendered position }

  { Dirty rectangle system }
  DirtyRects: array[0..MaxDirtyRects - 1] of TRectangle;
  DirtyCount: Integer;

  { Timing }
  CurrentTime, LastTime: Real;
  DeltaTime, DeltaTimeAccum: Real;
  FrameCount: LongInt;
  FPSTimer: Real;
  FPS: Integer;

  { Game state }
  Running: Boolean;
  Score: LongInt;
  Level: Integer;
  NeedMatchCheck: Boolean;
  FlashTimer: Real;
  FlashActive: Boolean;
  FlashTiles: array[0..PlayfieldCols - 1, 0..PlayfieldRows - 1] of Boolean;
  NeedGravity: Boolean;

  { Palette }
  Palette: TPalette;

  { Next stack preview gems }
  NextStackGems: array [0..2] of TGemColor;  

{ Forward declarations }
procedure CheckForMatches; forward;

procedure CleanupGame;
begin
  { Cleanup timer }
  DoneRTC;

  { Cleanup keyboard }
  DoneKeyboard;

  { Free images }
  FreeImage(BackgroundImage);
  FreeImage(GemsImage);

  { Free framebuffers }
  FreeFrameBuffer(BackBuffer);
  FreeFrameBuffer(BackgroundBuffer);

  { Close VGA }
  CloseVGA;

  WriteLn('XICLONE - Shutdown complete');
end; 

{ Dirty rectangle management }

procedure FlushDirtyRects;
var
  i: Integer;
begin
  ScreenBuffer := GetScreenBuffer;

  { Copy each dirty rectangle from BackBuffer to VGA memory }
  for i := 0 to DirtyCount - 1 do
  begin
    CopyFrameBufferRect(
      BackBuffer, DirtyRects[i],
      ScreenBuffer, DirtyRects[i].X, DirtyRects[i].Y
    );
  end;

  { Clear dirty rect list }
  DirtyCount := 0;
end;

procedure AddDirtyRect(const NewRect: TRectangle);
begin
  if DirtyCount >= MaxDirtyRects then Exit;
  DirtyRects[DirtyCount] := NewRect;
  Inc(DirtyCount);
end;

{ Rendering }

procedure DrawGem(GemColor: TGemColor; X, Y: Integer; FrameBuffer: PFrameBuffer);
var
  GemRect: TRectangle;
  GemIndex: Integer;
begin
  { --- FIX START --- }
  { Step 1: ALWAYS restore the background first. 
    This wipes whatever 'ghost' data (exploded gems, etc) 
    is currently in this spot in the BackBuffer. }
  GemRect.X := X;
  GemRect.Y := Y;
  GemRect.Width := TileSize;
  GemRect.Height := TileSize;

  CopyFrameBufferRect(BackgroundBuffer, GemRect, FrameBuffer, X, GemRect.Y);
  { --- FIX END --- }

  { Step 2: If it's empty, we are done (background is already restored) }
  if GemColor = Gem_Empty then Exit;

  { Calculate gem sprite index }
  GemIndex := Ord(GemColor);

  { Setup source rectangle in gem sprite sheet }
  GemRect.X := GemIndex * TileSize;
  GemRect.Y := 0;

  { Step 3: Draw gem sprite over the clean background }
  PutImageRect(GemsImage, GemRect, X, Y, True, FrameBuffer);
end;

procedure DrawGemFlash(GemColor: TGemColor; X, Y: Integer; FrameBuffer: PFrameBuffer; FlashOn: Boolean);
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
    PutImageRect(GemsImage, GemRect, X, Y, True, FrameBuffer);
  end
  else
  begin
    { Show background when flash is off (gem disappears) }
    GemRect.X := X;
    GemRect.Y := Y;
    CopyFrameBufferRect(BackgroundBuffer, GemRect, FrameBuffer, X, Y);
  end;
end;

procedure RenderPlayfield;
var
  X, Y: Integer;
  PixelX, PixelY: Integer;
  R: TRectangle;
  FlashOn: Boolean;
begin
  { Calculate flash state (blink every 100ms) }
  FlashOn := FlashActive and (Trunc(FlashTimer * 10) mod 2 = 0);

  { Render gems on playfield }
  for Y := 0 to PlayfieldRows - 1 do
  begin
    for X := 0 to PlayfieldCols - 1 do
    begin
      { Only redraw changed tiles or flashing tiles }
      if Playfield.TileChanged[X, Y] or (FlashActive and FlashTiles[X, Y]) then
      begin
        PixelX := PlayfieldX + X * TileSize;
        PixelY := PlayfieldY + Y * TileSize;

        { If this tile is flashing, draw flash effect }
        if FlashActive and FlashTiles[X, Y] then
        begin
          DrawGemFlash(Playfield.Tiles[X, Y], PixelX, PixelY, BackBuffer, FlashOn);
        end
        else
        begin
          { Draw the gem at this position }
          DrawGem(Playfield.Tiles[X, Y], PixelX, PixelY, BackBuffer);
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

procedure RenderHUD;
var
  R: TRectangle;
begin
  { Render FPS counter }
  R.X := 10;
  R.Y := 10;
  R.Width := 80;
  R.Height := 8;
  CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);
  PrintText(10, 10, 'FPS: ' + IntToStr(FPS), 15, BackBuffer);
  AddDirtyRect(R);

  { Render title }
  {
  R.X := 120;
  R.Y := 10;
  R.Width := 150;
  R.Height := 8;
  CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);
  PrintText(120, 10, 'XICLONE - Phase 4', 14, BackBuffer);
  AddDirtyRect(R);
  }

  { Render score }
  R.X := 10;
  R.Y := 20;
  R.Width := 100;
  R.Height := 8;
  CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);
  PrintText(10, 20, 'SCORE: ' + IntToStr(Score), 15, BackBuffer);
  AddDirtyRect(R);

  { Render level }
  R.X := 10;
  R.Y := 30;
  R.Width := 100;
  R.Height := 8;
  CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);
  PrintText(10, 30, 'LEVEL: ' + IntToStr(Level), 15, BackBuffer);
  AddDirtyRect(R);
end;

procedure RenderNextStack;
var
  i: Integer;
  GemY: Integer;
  R: TRectangle;
begin
  for i := 0 to 2 do
  begin
    DrawGem(NextStackGems[i], NextStackX, NextStackY + i * TileSize, BackBuffer);
  end;
  R.X := NextStackX;
  R.Y := NextStackY;
  R.Width := TileSize;
  R.Height := TileSize * 3;
  AddDirtyRect(R);
end;

procedure RenderStack;
var
  I: Integer;
  GemY: Integer;
  R: TRectangle;
begin
  if not CurrentStack.Active then Exit;

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

  CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);
  AddDirtyRect(R);

  { --- STEP 2: DRAW NEW POSITION --- }

  for I := 0 to 2 do
  begin
    { Calculate Y relative to the stack top }
    GemY := Trunc(CurrentStack.PixelY) + (I * TileSize);
    DrawGem(CurrentStack.Gems[I], CurrentStack.PixelX, GemY + PlayfieldY, BackBuffer);
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
end;

procedure RenderFrame;
begin
  { Render all game elements to BackBuffer }
  RenderPlayfield;
  RenderStack;
  RenderHUD;

  { Copy dirty regions to screen }
  FlushDirtyRects;

  { Check for matches AFTER rendering (deferred from LandStack) }
  if NeedMatchCheck then
  begin
    CheckForMatches;
    NeedMatchCheck := False;
  end;
end;

{ Game logic }

function RandomGemColor: TGemColor;
var
  R: Integer;
begin
  R := Random(6) + 1;  { 1-6 for colored gems, excluding empty and magic jewel }
  RandomGemColor := TGemColor(R);
end;

procedure SpawnNewStack(First: Boolean);
begin
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
  CurrentStack.GridX := PlayfieldCols div 2;  { Start in middle column }
  CurrentStack.PixelX := PlayfieldX + (CurrentStack.GridX * TileSize);
  CurrentStack.PixelY := -3 * TileSize;  { Start above playfield }
  CurrentStack.FallSpeed := InitialFallSpeed;
  CurrentStack.Active := True;

  NextStackGems[0] := RandomGemColor;
  NextStackGems[1] := RandomGemColor;
  NextStackGems[2] := RandomGemColor;

  { Initialize last position to current position }
  LastStackX := CurrentStack.PixelX;
  LastStackY := CurrentStack.PixelY;

  RenderNextStack; { Only render on spawn }
end;

function CheckStackCollision(CheckX, StartCheckY: Integer): Boolean;
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

procedure RotateStack;
var
  Temp: TGemColor;
begin
  { Rotate gems: Bottom -> Top, Middle -> Bottom, Top -> Middle }
  Temp := CurrentStack.Gems[2];
  CurrentStack.Gems[2] := CurrentStack.Gems[1];
  CurrentStack.Gems[1] := CurrentStack.Gems[0];
  CurrentStack.Gems[0] := Temp;
end;

function CountMatchInDirection(StartX, StartY, DX, DY: Integer; Color: TGemColor): Integer;
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

function FindAndRemoveMatches: Integer;
var
  X, Y: Integer;
  Color: TGemColor;
  MatchLen: Integer;
  GemsRemoved: Integer;
  MarkForRemoval: array[0..PlayfieldCols - 1, 0..PlayfieldRows - 1] of Boolean;
  i, MarkX, MarkY: Integer;
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

      { Check horizontal (right) }
      MatchLen := CountMatchInDirection(X, Y, 1, 0, Color);
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
      MatchLen := CountMatchInDirection(X, Y, 0, 1, Color);
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
      MatchLen := CountMatchInDirection(X, Y, 1, 1, Color);
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
      MatchLen := CountMatchInDirection(X, Y, -1, 1, Color);
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
      FlashTiles[X, Y] := MarkForRemoval[X, Y];
      if MarkForRemoval[X, Y] then
        Inc(GemsRemoved);
    end;
  end;

  FindAndRemoveMatches := GemsRemoved;
end;

procedure RemoveFlashedGems;
var
  X, Y: Integer;
begin
  { Remove all flashed gems }
  for Y := 0 to PlayfieldRows - 1 do
  begin
    for X := 0 to PlayfieldCols - 1 do
    begin
      if FlashTiles[X, Y] then
      begin
        Playfield.Tiles[X, Y] := Gem_Empty;
        Playfield.TileChanged[X, Y] := True;
        FlashTiles[X, Y] := False;
      end;
    end;
  end;
end;

procedure ApplyGravity;
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

procedure CheckForMatches;
var
  GemsRemoved: Integer;
begin
  { Find matches and mark them for flashing }
  GemsRemoved := FindAndRemoveMatches;

  if GemsRemoved > 0 then
  begin
    { Start flash effect }
    FlashActive := True;
    FlashTimer := 0.0;

    { Update score }
    Inc(Score, GemsRemoved * 10);
  end;
end;

procedure LandStack;
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
  CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);
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
  SpawnNewStack(False);

  { Schedule match check for next frame (after render completes) }
  NeedMatchCheck := True;
end;

procedure UpdateFallingStack;
var
  NewY: Real;
  GridY: Integer;
  PixelsFallen: Real;
  NextStepBlocked: Boolean;
begin
  if not CurrentStack.Active then Exit;

  { Calculate pixels to fall this frame }
  PixelsFallen := CurrentStack.FallSpeed * DeltaTime;

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

procedure HandleStackInput;
var
  NewX: Integer;
  GridY: Integer;
  PixelOffset: Integer;
  CanMove: Boolean;
begin
  if not CurrentStack.Active then Exit;

  GridY := Trunc(CurrentStack.PixelY) div TileSize;
  
  { Calculate how deep we are into the current tile }
  PixelOffset := Trunc(CurrentStack.PixelY) mod TileSize;

  { --- Left Movement --- }
  if IsKeyPressed(Key_Left) then
  begin
    NewX := CurrentStack.GridX - 1;
    
    { 1. Check if the stack fits in the new column at the current Grid Y }
    CanMove := not CheckStackCollision(NewX, GridY);

    { 2. If we are partially fallen into the next row, we must also check }
    {    if the stack fits one row lower in the new column. }
    if CanMove and (PixelOffset > 0) then
    begin
      if CheckStackCollision(NewX, GridY + 1) then
        CanMove := False;
    end;

    if CanMove then
    begin
      CurrentStack.GridX := NewX;
      CurrentStack.PixelX := PlayfieldX + (CurrentStack.GridX * TileSize);
    end;
  end;

  { --- Right Movement --- }
  if IsKeyPressed(Key_Right) then
  begin
    NewX := CurrentStack.GridX + 1;
    
    { 1. Check main position }
    CanMove := not CheckStackCollision(NewX, GridY);

    { 2. Check 'dangling' position if not grid aligned }
    if CanMove and (PixelOffset > 0) then
    begin
      if CheckStackCollision(NewX, GridY + 1) then
        CanMove := False;
    end;

    if CanMove then
    begin
      CurrentStack.GridX := NewX;
      CurrentStack.PixelX := PlayfieldX + (CurrentStack.GridX * TileSize);
    end;
  end;

  { Rotation }
  if IsKeyPressed(Key_Space) then
    RotateStack;

  { Fast fall }
  if IsKeyDown(Key_Down) then
    CurrentStack.FallSpeed := FastFallSpeed
  else
    CurrentStack.FallSpeed := InitialFallSpeed;
end;

procedure UpdateGame;
begin
  { Check for exit }
  if IsKeyPressed(Key_Escape) then
    Running := False;

  { Update flash timer }
  if FlashActive then
  begin
    FlashTimer := FlashTimer + DeltaTime;

    { After 0.5 seconds of flashing, remove gems and apply gravity }
    if FlashTimer >= 0.5 then
    begin
      FlashActive := False;
      RemoveFlashedGems;
      ApplyGravity;

      { Check for new matches after gravity }
      NeedMatchCheck := True;
    end;
  end
  else
  begin
    { Only allow stack movement when not flashing }
    HandleStackInput;
    UpdateFallingStack;
  end;
end;

{ FPS calculation }

procedure UpdateFPS;
begin
  Inc(FrameCount);

  if (CurrentTime - FPSTimer) >= 1.0 then
  begin
    FPS := FrameCount;
    FrameCount := 0;
    FPSTimer := CurrentTime;
  end;
end;

{ Initialization }

procedure InitPlayfield;
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

  { Add some test gems }
  { Bottom row - display all gem types }
  Playfield.Tiles[0, 11] := Gem_Red;
  Playfield.Tiles[1, 11] := Gem_Yellow;
  Playfield.Tiles[2, 11] := Gem_Green;
  Playfield.Tiles[3, 11] := Gem_Blue;
  Playfield.Tiles[4, 11] := Gem_Pink;
  Playfield.Tiles[5, 11] := Gem_Purple;

  { Second row from bottom }
  Playfield.Tiles[0, 10] := Gem_Blue;
  Playfield.Tiles[1, 10] := Gem_Blue;
  Playfield.Tiles[2, 10] := Gem_Blue;
  Playfield.Tiles[3, 10] := Gem_Red;
  Playfield.Tiles[4, 10] := Gem_Red;

  { Third row }
  Playfield.Tiles[2, 9] := Gem_Yellow;
  Playfield.Tiles[3, 9] := Gem_Yellow;
  Playfield.Tiles[4, 9] := Gem_Yellow;

  { Add a magic jewel for testing }
  Playfield.Tiles[5, 10] := Gem_MagicJewel;
end;

procedure InitGame;
begin
  WriteLn('XICLONE - Initializing...');

  { Create framebuffers }
  BackBuffer := CreateFrameBuffer;
  BackgroundBuffer := CreateFrameBuffer;

  { Clear buffers }
  ClearFrameBuffer(BackBuffer);
  ClearFrameBuffer(BackgroundBuffer);

  { Load background }
  if not LoadPKMWithPalette(DataPath + BackgroundFile, BackgroundImage, Palette) then
  begin
    WriteLn(PKMLoad.GetLastErrorMessage);
    Halt(1);
  end;

  { Load gem sprites }
  if not LoadPKM(DataPath + GemsFile, GemsImage) then
  begin
    WriteLn(PKMLoad.GetLastErrorMessage);
    Halt(1);
  end;

  { Copy background image to BackgroundBuffer }
  PutImage(BackgroundImage, 0, 0, False, BackgroundBuffer);

  { Copy background to BackBuffer }
  Move(BackgroundBuffer^, BackBuffer^, 64000);

  { Initialize video }
  InitVGA;

  { Set palette from loaded image }
  SetPalette(Palette);

  ScreenBuffer := GetScreenBuffer;
  CopyFrameBuffer(BackBuffer, ScreenBuffer);

  { Initialize keyboard }
  InitKeyboard;

  { Initialize timer }
  InitRTC(1024);

  { Initialize timing }
  LastTime := GetTimeSeconds;
  FPSTimer := LastTime;
  FrameCount := 0;
  FPS := 0;
  DeltaTimeAccum := 0.0;

  { Initialize game state }
  Score := 0;
  Level := 1;
  NeedMatchCheck := False;
  FlashActive := False;
  FlashTimer := 0.0;

  { Initialize dirty rect system }
  DirtyCount := 0;

  { Initialize playfield }
  InitPlayfield;

  { Initialize random number generator }
  Randomize;

  { Spawn first falling stack }
  SpawnNewStack(True);

  { Render initial playfield state }
  RenderPlayfield;
  FlushDirtyRects;
  { Set running flag }
  Running := True;
end;


{ Main game loop }

procedure GameLoop;
begin
  while Running do
  begin
    { Calculate delta time and accumulate fractional milliseconds }
    CurrentTime := GetTimeSeconds;
    DeltaTimeAccum := DeltaTimeAccum + (CurrentTime - LastTime);
    LastTime := CurrentTime;

    { Update game only when we have at least 10ms accumulated delta time }
    if DeltaTimeAccum >= 0.01 then
    begin
      DeltaTime := DeltaTimeAccum;
      DeltaTimeAccum := DeltaTimeAccum - DeltaTime;
    
      { Update game state }
      UpdateGame;
    
      { Update FPS counter }
      UpdateFPS;

      { Render frame }
      RenderFrame;

      { Wait for VSync to throttle frame rate }
      WaitForVSync; { TODO: make it optional }
    end;

    Delay(1);

    { Clear key pressed flags }
    ClearKeyPressed;
  end;
end;

{ Main program }

begin
  InitGame;
  GameLoop;
  CleanupGame;
end.
