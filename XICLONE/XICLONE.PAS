{ ========================================================================== }
{ XICLONE - Xixit/Columns Clone                                             }
{ A falling-block puzzle game inspired by Xixit and Columns                 }
{                                                                            }
{ Architecture:                                                              }
{   XITypes   - Game types and constants                                    }
{   XILogic   - Match detection, gravity, collision, stack operations       }
{   XIRender  - Dirty rectangle-based rendering system                      }
{   DRect     - Reusable dirty rectangle manager (engine unit)              }
{                                                                            }
{ This main program handles:                                                }
{   - Game state management                                                 }
{   - Stack physics and landing                                             }
{   - Input handling                                                        }
{   - Game loop orchestration                                               }
{   - Resource initialization                                               }
{ ========================================================================== }

{$M 8192,0,655360}  { Stack: 8KB, MinHeap: 0, MaxHeap: 640KB - reduced stack for more heap }

program XICLONE;

uses
  Crt, VGA, PCXLoad, Keyboard, RTCTimer, VGAPrint, StrUtil, DRect, XITypes,
  XILogic, XIRender, VGAFont, Config, SndBank, SBDSP, VGAUI, XIStyle;

var
  { Frame buffers }
  BackBuffer: PFrameBuffer;
  ScreenBuffer: PFrameBuffer;
  BackgroundBuffer: PFrameBuffer;
  DialogBackgroundBuffer: PFrameBuffer;  

  { Images }
  BackgroundImage: TImage;
  GemsImage: TImage;

  { UI related }
  DialogImage: TImage;
  UI: TUIManager;
  CustomStyle: TXIStyle;

  { Fonts }
  FontLarge: TFont;
  FontSmall: TFont;

  { Game data }
  Playfield: TPlayfield;
  CurrentStack: TGemStack;
  LastStackY: Real;
  LastStackX: Integer;  { Track last rendered position }

  { Timing }
  CurrentTime, LastTime: Real;
  DeltaTime, DeltaTimeAccum: Real;
  FrameCount: LongInt;
  FPSTimer: Real;
  FPS: Integer;

  { Game state }
  Running: Boolean;
  ShowFPS: Boolean;  { Display FPS counter (set via -showfps argument) }
  ShowMem: Boolean;  { Display free memory }
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

  { Palette }
  Palette: TPalette;

  { Configuration }
  GameConfig: TConfig;

  { Sound }
  SoundEnabled: Boolean;
  SoundBank: TSoundBank;
  LandSoundId: Integer;
  EnterSoundId: Integer;
  SwitchSoundId: Integer;
  MatchSoundId: Integer;
  RotateSoundId: Integer;
  GameOverSoundId: Integer;
  NextLevelSoundId: Integer;

  { Next stack preview gems }
  NextStackGems: array [0..2] of TGemColor;

  Paused: Boolean;

procedure CleanupGame;
begin
  { Cleanup timer }
  DoneRTC;

  { Cleanup keyboard }
  DoneKeyboard;

  { Cleanup sound }
  if SoundEnabled then
  begin
    SoundBank.Done;
    UninstallHandler;
  end;

  { Free fonts }
  FreeFont(FontLarge);
  FreeFont(FontSmall);

  { Free images }
  { BackgroundImage already freed after copying to buffer }
  FreeImage(GemsImage);

  { Free framebuffers }
  FreeFrameBuffer(BackBuffer);
  FreeFrameBuffer(BackgroundBuffer);
  FreeFrameBuffer(DialogBackgroundBuffer);

  { Close VGA }
  CloseVGA;

  WriteLn('XICLONE - Shutdown complete');
end;

{ Match detection }

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

procedure ShowDialog(Title: String);
var
  X, Y: Integer;
begin
  RenderDialogBackground(BackBuffer);
  PutImage(DialogImage, 160 - DialogImage.Width div 2, 100 - DialogImage.Height div 2, False, BackBuffer);
  PrintFontTextCentered(160, 63, Title, FontLarge, BackBuffer);
  CopyFrameBuffer(BackBuffer, ScreenBuffer);
  ClearKeyPressed;
end;

procedure DestroyDialog;
begin
  CopyFrameBuffer(BackgroundBuffer, BackBuffer);
  ClearKeyPressed;
end;

procedure FullRenderGame;
var
  X, Y: Integer;
begin
  { Mark all playfield tiles as changed to force full redraw }
  for Y := 0 to PlayfieldRows - 1 do
    for X := 0 to PlayfieldCols - 1 do
      Playfield.TileChanged[X, Y] := True;

  { Force HUD redraw by invalidating last values }
  LastScore := -1;
  LastLevel := -1;
  LastBlocks := -1;

  { Re-render all game elements }
  RenderPlayfield(Playfield, FlashActive, FlashTimer, FlashTiles);
  RenderStack(CurrentStack, LastStackX, LastStackY);
  RenderNextStack(NextStackGems);
  RenderHUD(FPS, ShowFPS, ShowMem, Score, Level, Blocks, LastScore, LastLevel, LastBlocks, FontLarge, FontSmall);

  { Display the restored screen }
  CopyFrameBuffer(BackBuffer, ScreenBuffer);

  { Reset timing to prevent delta time jump }
  LastTime := GetTimeSeconds;
  DeltaTimeAccum := 0.0;
end;

{$F+}

procedure ContinueButtonEvent(var Widget: TWidget; var Event: TEvent);
begin
  if (Event.EventType = Event_KeyPress) and (Event.KeyCode = Key_Enter) then
  begin
    Paused := False;
  end;
end;

procedure QuitButtonEvent(var Widget: TWidget; var Event: TEvent);
begin
  if (Event.EventType = Event_KeyPress) and (Event.KeyCode = Key_Enter) then
  begin
    Running := False;
    Paused := False;
  end;
end;

{$F-}

procedure ShowPauseDialog;  
var
  DeltaTimeMS: LongInt;
  ContinueButton, QuitButton: PButton;
begin
  ShowDialog('PAUSED');

  { Save UI background }
  CopyFrameBuffer(BackBuffer, DialogBackgroundBuffer);

  { Create UI }
  UI.Init(BackBuffer, DialogBackgroundBuffer);
  UI.SetStyle(@CustomStyle);

  New(ContinueButton, Init(100, 97, 120, 14, 'Continue Game', @FontSmall));
  ContinueButton^.SetEventHandler(@ContinueButtonEvent);
  UI.AddWidget(ContinueButton);

  New(QuitButton, Init(100, 115, 120, 14, 'Quit to Menu', @FontSmall));
  QuitButton^.SetEventHandler(@QuitButtonEvent);
  UI.AddWidget(QuitButton);

  UI.SetFocus(ContinueButton);

  { Run UI }
  Paused := True;
  LastTime := GetTimeSeconds;
  while Paused do
  begin
    CurrentTime := GetTimeSeconds;
    DeltaTimeMS := Round((CurrentTime - LastTime) * 1000);
    LastTime := CurrentTime;

    UI.Update(DeltaTimeMS);
    UI.RenderDirty;

    WaitForVSync;    
    ClearKeyPressed;
  end;

  { Destory UI }
  UI.RemoveWidget(ContinueButton); Dispose(ContinueButton, Done);
  UI.RemoveWidget(QuitButton); Dispose(QuitButton, Done);
  UI.Done;  

  { Back to game }
  DestroyDialog;
  FullRenderGame;
end;

procedure RenderFrame;
begin
  { Render all game elements to BackBuffer }
  RenderPlayfield(Playfield, FlashActive, FlashTimer, FlashTiles);
  RenderStack(CurrentStack, LastStackX, LastStackY);
  RenderHUD(FPS, ShowFPS, ShowMem, Score, Level, Blocks, LastScore, LastLevel, LastBlocks, FontLarge, FontSmall);

  { Copy dirty regions to screen }
  FlushDirtyRects(BackBuffer);

  { Check for matches AFTER rendering (deferred from LandStack) }
  if NeedMatchCheck then
  begin
    CheckForMatches;
    NeedMatchCheck := False;
  end;
end;

{ Stack physics & collision }

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
  SpawnStack(CurrentStack, NextStackGems, LastStackX, LastStackY, False);
  RenderNextStack(NextStackGems);

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
  if (GridY + 3 > PlayfieldRows) or CheckStackCollision(Playfield, CurrentStack.GridX, GridY) then
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
                         CheckStackCollision(Playfield, CurrentStack.GridX, GridY + 1);

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
    CanMove := not CheckStackCollision(Playfield, NewX, GridY);

    { 2. If we are partially fallen into the next row, we must also check }
    {    if the stack fits one row lower in the new column. }
    if CanMove and (PixelOffset > 0) then
    begin
      if CheckStackCollision(Playfield, NewX, GridY + 1) then
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
    CanMove := not CheckStackCollision(Playfield, NewX, GridY);

    { 2. Check 'dangling' position if not grid aligned }
    if CanMove and (PixelOffset > 0) then
    begin
      if CheckStackCollision(Playfield, NewX, GridY + 1) then
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
    RotateStack(CurrentStack);

  { Fast fall }
  if IsKeyDown(Key_Down) then
    CurrentStack.FallSpeed := FastFallSpeed
  else
    CurrentStack.FallSpeed := InitialFallSpeed;
end;

{ Game update loop }

procedure UpdateGame;
begin
  { Check for pause }
  if IsKeyPressed(Key_Escape) then
  begin
    ShowPauseDialog;  { Pause game, wait for unpause }
  end;

  if IsKeyPressed(Key_Q) then
    Running := False;

  { Update flash timer }
  if FlashActive then
  begin
    FlashTimer := FlashTimer + DeltaTime;

    { After 0.5 seconds of flashing, remove gems and apply gravity }
    if FlashTimer >= 0.5 then
    begin
      FlashActive := False;
      RemoveFlashedGems(Playfield, FlashTiles);
      ApplyGravity(Playfield);

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

{ Command-line argument parsing }

procedure ParseCommandLine;
var
  i: Integer;
  Arg: string;
begin
  ShowFPS := False;  { Default: don't show FPS }
  ShowMem := False;

  { Check each command-line argument }
  for i := 1 to ParamCount do
  begin
    Arg := ParamStr(i);
    if (Arg = '-showfps') or (Arg = '--showfps') then
      ShowFPS := True;
    if (Arg = '-showmem') or (Arg = '--showmem') then
      ShowMem := True;
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

  { Load configuration }
  LoadConfig(GameConfig);

  { Initialize sound system if Sound Blaster is configured }
  SoundEnabled := False;
  if GameConfig.SoundCard = SoundCard_SoundBlaster then
    if ResetDSP(GameConfig.SBPort, GameConfig.SBIRQ, GameConfig.SBDMA, 0) then
      if SoundBank.Init then
        SoundEnabled := True
      else
        WriteLn('Sound bank initialization failed')
    else
      WriteLn('Sound Blaster initialization failed');

  { Load sound effects }
  if SoundEnabled then
  begin
    LandSoundId := SoundBank.LoadSound(DataPath + 'LAND.VOC');
    EnterSoundId := SoundBank.LoadSound(DataPath + 'ENTER.VOC');
    SwitchSoundId := SoundBank.LoadSound(DataPath + 'SELECT.VOC');
    MatchSoundId := SoundBank.LoadSound(DataPath + 'MATCH.VOC');
    RotateSoundId := SoundBank.LoadSound(DataPath + 'ROTATE.VOC');
    GameOverSoundId := SoundBank.LoadSound(DataPath + 'GAMEOVER.VOC');
    NextLevelSoundId := SoundBank.LoadSound(DataPath + 'NEXTLVL.VOC');
  end;

  { Load fonts }
  if (not LoadFont(DataPath + FontSmallXML, DataPath + FontSmallImage, FontSmall)) or
     (not LoadFont(DataPath + FontLargeXML, DataPath + FontLargeImage, FontLarge)) then
  begin
    WriteLn('Error loading font: ', GetLoadFontError);
    Halt(1);
  end;

  { Initialize UI style }
  CustomStyle.Init(186, 188, 189, 15);

  { Create framebuffers }
  BackBuffer := CreateFrameBuffer;
  BackgroundBuffer := CreateFrameBuffer;
  DialogBackgroundBuffer := CreateFrameBuffer;

  { Load gem sprites and dialog }
  if (not LoadPCXWithPalette(DataPath + GemsFile, GemsImage, Palette)) or
     (not LoadPCX(DataPath + DialogFile, DialogImage)) then
  begin
    WriteLn(PCXLoad.GetLoadPCXError);
    Halt(1);
  end;

  { --- Load and render a backround image }

  { Load background }
  if not LoadPCX(DataPath + BackgroundFile, BackgroundImage) then
  begin
    WriteLn(PCXLoad.GetLoadPCXError);
    Halt(1);
  end;

  { Copy and free background image to BackgroundBuffer }
  PutImage(BackgroundImage, 0, 0, False, BackgroundBuffer);
  FreeImage(BackgroundImage);

  { --- Render game static background }

  { Render static labels to background buffer }
  PrintFontTextRight(StatLabelsX, 17, 'Score:', FontSmall, BackgroundBuffer);
  PrintFontTextRight(StatLabelsX, 58, 'Level:', FontSmall, BackgroundBuffer);
  PrintFontTextRight(StatLabelsX, 99, 'Blocks:', FontSmall, BackgroundBuffer);
  PrintFontText(NextLabelX, NextLabelY, 'Next:', FontSmall, BackgroundBuffer);

  CopyFrameBuffer(BackgroundBuffer, BackBuffer);

  { Initialize renderer }
  InitRenderer(BackgroundBuffer, BackBuffer, GemsImage);

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
  Blocks := 0;
  NeedMatchCheck := False;
  FlashActive := False;
  FlashTimer := 0.0;

  { Initialize HUD tracking (force initial render) }
  LastScore := -1;
  LastLevel := -1;
  LastBlocks := -1;

  { Initialize playfield }
  InitPlayfield;

  { Initialize random number generator }
  Randomize;

  { Spawn first falling stack }
  SpawnStack(CurrentStack, NextStackGems, LastStackX, LastStackY, True);
  RenderNextStack(NextStackGems);

  { Render initial playfield state }
  RenderPlayfield(Playfield, FlashActive, FlashTimer, FlashTiles);
  FlushDirtyRects(BackBuffer);

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

    { Update game only when we have at least 14ms accumulated delta time - max ~70 fps }
    if DeltaTimeAccum >= 0.014 then
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
      WaitForVSync;
    end;

    { Clear key pressed flags }
    ClearKeyPressed;
  end;
end;

{ Main program }

begin
  ParseCommandLine;
  InitGame;  
  GameLoop;
  CleanupGame;
end.
