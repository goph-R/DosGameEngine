unit XiGame;

interface

uses
  VGA, VGAUI, VGAFont, HiScore, GameUnit, Keyboard, StrUtil;

const
  TileSize = 16;
  HighScoreSalt = 'XICLONE_HIGHSCORE_V1';  { Salt for high score tamper protection }
  MaxDialogButtons = 5;

type
  TCustomUIStyle = object(TUIStyle)
    procedure RenderPanel(const R: TRectangle; Pressed: Boolean; FrameBuffer: PFrameBuffer); virtual;
  end;

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

  TDialogType = (
    Dialog_None,
    Dialog_Paused,
    Dialog_GameOver,
    Dialog_ConfirmRestart,
    Dialog_ConfirmQuit
  );

  { Xi Clone game - extends TGame with game-specific resources }
  TXiCloneGame = object(TGame)
    { Game-specific resources }
    GemsImage: PImage;
    FontLarge: PFont;
    FontSmall: PFont;
    UIStyle: TCustomUIStyle;
    DialogUI: TUIManager;
    HighScoreTable: THighScore;
    Palette: PPalette;

    { Dialog resources }
    DialogImage: PImage;
    DialogBackgroundBuffer: PFrameBuffer;

    { Dialog state }
    ConfirmDialogAnswer: Boolean;
    NextDialog: TDialogType;
    PrevDialog: TDialogType;
    BackDialog: TDialogType;
    DialogSavedBgImage: TImage;
    DialogLabel: PLabel;
    DialogButtons: array [0..MaxDialogButtons - 1] of PButton;
    DialogButtonIndex: ShortInt;
    DialogHeight: Word;
    DialogHasTitle: Boolean;

    { Game-specific initialization and cleanup }
    constructor Init(const ConfigIniPath: String; const ResXmlPath: String);
    destructor Done; virtual;
    procedure Start; virtual;

    { Helper methods }
    procedure DrawGem(GemColor: TGemColor; X, Y: Integer);
    procedure SetNextDialog(ND: TDialogType);

    { Dialog methods }
    procedure InitDialog(Title: String; Height: Word);
    procedure AddDialogLabel(Text: String);
    procedure AddDialogButton(Text: String; EventHandler: TEventHandler);
    procedure ShowDialog(UpdateProcedure: TUpdateProcedure);
    function ShowConfirm(Message: String; UpdateProcedure: TUpdateProcedure): Boolean;
  end;

var
  Game: TXiCloneGame;  { Global game instance }

implementation

procedure TCustomUIStyle.RenderPanel(const R: TRectangle; Pressed: Boolean; FrameBuffer: PFrameBuffer);
var
  TC, BC1, BC2, RC: Byte;
begin

  if Pressed then
  begin
    TC := LowColor;
    BC1 := NormalColor;
    BC2 := HighColor;
    RC := LowColor;
  end
  else
  begin
    TC := HighColor;
    BC1 := LowColor;
    BC2 := 12;
    RC := NormalColor;
  end;

  DrawFillRect(R, RC, FrameBuffer);

  DrawHLine(R.X + 1, R.Y + 1, R.Width - 3, TC, FrameBuffer);
  DrawVLine(R.X + 1, R.Y + 1, R.Height - 3, TC, FrameBuffer);

  DrawVLine(R.X + R.Width - 2, R.Y + 1, R.Height - 2, BC1, FrameBuffer);
  DrawHLine(R.X + 2, R.Y + R.Height - 2, R.Width - 3, BC1, FrameBuffer);
  DrawVLine(R.X + R.Width - 1, R.Y, R.Height, BC2, FrameBuffer);
  DrawHLine(R.X + 1, R.Y + R.Height - 1, R.Width - 2, BC2, FrameBuffer);
end;

{ ========== TXiCloneGame Implementation ========== }

constructor TXiCloneGame.Init(const ConfigIniPath: String; const ResXmlPath: String);
var
  I: Integer;
begin
  { Call parent constructor }
  inherited Init(ConfigIniPath, ResXmlPath);

  { Initialize dialog state }
  NextDialog := Dialog_None;
  PrevDialog := Dialog_None;
  BackDialog := Dialog_None;
  ConfirmDialogAnswer := False;
  DialogLabel := nil;
  DialogButtonIndex := -1;
  DialogHeight := 0;
  DialogHasTitle := False;

  { Initialize dialog button array }
  for I := 0 to MaxDialogButtons - 1 do
    DialogButtons[I] := nil;

  { Resources will be loaded in Start after VGA initialization }
  GemsImage := nil;
  FontLarge := nil;
  FontSmall := nil;
  Palette := nil;
  DialogImage := nil;
  DialogBackgroundBuffer := nil;
end;

destructor TXiCloneGame.Done;
begin
  { Free dialog resources }
  if DialogBackgroundBuffer <> nil then
  begin
    FreeFrameBuffer(DialogBackgroundBuffer);
    DialogBackgroundBuffer := nil;
  end;

  { Parent will cleanup resources via ResMan }
  inherited Done;
end;

procedure TXiCloneGame.Start;
begin
  { Call parent Start (initializes VGA, etc.) }
  inherited Start;

  { Load game-specific resources (only once, after VGA init) }
  GemsImage := ResMan.GetImage('gems1');
  FontLarge := ResMan.GetFont('large');
  FontSmall := ResMan.GetFont('small');
  Palette := ResMan.GetPalette('default');

  { Set the palette }
  SetPalette(Palette^);

  { Load dialog resources }
  DialogImage := ResMan.GetImage('dialog');
  DialogBackgroundBuffer := CreateFrameBuffer;

  { Initialize UI style }
  UIStyle.Init(186, 188, 189, 15);

  { Initialize high score system }
  InitHighScore(HighScoreTable, HighScoreSalt);
  LoadHighScore('SCORES.XML', HighScoreTable);
end;

procedure TXiCloneGame.DrawGem(GemColor: TGemColor; X, Y: Integer);
var
  GemRect: TRectangle;
  GemIndex: Integer;
begin
  { Step 1: ALWAYS restore the background first }
  { This wipes whatever 'ghost' data (exploded gems, etc) is in this spot }
  GemRect.X := X;
  GemRect.Y := Y;
  GemRect.Width := TileSize;
  GemRect.Height := TileSize;

  CopyFrameBufferRect(BackgroundBuffer, GemRect, BackBuffer, X, GemRect.Y);

  { Step 2: If it's empty, we are done (background is already restored) }
  if GemColor = Gem_Empty then Exit;

  { Calculate gem sprite index }
  GemIndex := Ord(GemColor);

  { Setup source rectangle in gem sprite sheet }
  GemRect.X := GemIndex * TileSize;
  GemRect.Y := 0;

  { Step 3: Draw gem sprite over the clean background }
  PutImageRect(GemsImage^, GemRect, X, Y, True, BackBuffer);
end;

procedure TXiCloneGame.SetNextDialog(ND: TDialogType);
begin
  PrevDialog := NextDialog;
  NextDialog := ND;
end;

{ ========== Dialog Helper Functions ========== }

procedure RenderDialogDitheredBackground(FrameBuffer: PFrameBuffer); assembler;
{ Optimized assembly checkerboard dither for 286 }
{ Odd rows (1,3,5...): black at even X positions (0,2,4...) }
{ Even rows (0,2,4...): black at odd X positions (1,3,5...) }
 asm
  push ds
  les di, FrameBuffer    { ES:DI = framebuffer base }
  xor bx, bx             { BX = row counter (0-199) }
  cld                    { Clear direction flag }

@RowLoop:
  { Calculate row start address: FrameBuffer + (row * 320) }
  les di, FrameBuffer
  mov ax, bx             { AX = row number }
  mov cx, 320
  mul cx                 { DX:AX = row * 320 }
  add di, ax             { ES:DI = framebuffer + row offset }

  { Check if row is odd or even }
  test bl, 1             { Test bit 0 of row number }
  jnz @OddRow

@EvenRow:
  { Even rows: write black at odd positions (1,3,5,...) }
  inc di                 { Start at offset 1 }
  mov cx, 160            { 320/2 = 160 pixels to write }
  xor al, al             { AL = 0 (black color) }
@EvenLoop:
  stosb                  { Write black to [ES:DI], DI++ }
  inc di                 { Skip next pixel (DI++) }
  loop @EvenLoop
  jmp @NextRow

@OddRow:
  { Odd rows: write black at even positions (0,2,4,...) }
  mov cx, 160            { 320/2 = 160 pixels to write }
  xor al, al             { AL = 0 (black color) }
@OddLoop:
  stosb                  { Write black to [ES:DI], DI++ }
  inc di                 { Skip next pixel (DI++) }
  loop @OddLoop

@NextRow:
  inc bx                 { Next row }
  cmp bx, 200
  jl @RowLoop

  pop ds
end;

function GetDialogX: Integer;
begin
  GetDialogX := 160 - Game.DialogImage^.Width div 2;
end;

function GetDialogY: Integer;
begin
  GetDialogY := 100 - Game.DialogHeight div 2;
end;

{$F+}
procedure OkEvent(var Widget: TWidget; var Event: TEvent); far;
begin
  if Game.DialogUI.IsEnter(Event) then
  begin
    Game.ConfirmDialogAnswer := True;
    Game.DialogUI.Stop;
  end;
end;

procedure CancelEvent(var Widget: TWidget; var Event: TEvent); far;
begin
  if Game.DialogUI.IsEnter(Event) then
  begin
    Game.ConfirmDialogAnswer := False;
    Game.DialogUI.Stop;
  end;
end;
{$F-}

{ ========== Dialog Methods ========== }

procedure TXiCloneGame.InitDialog(Title: String; Height: Word);
var
  DialogSourceRect: TRectangle;
  DialogX: Integer;
  DialogTopHeight: Word;
  DialogBottomHeight: Word;
begin
  DialogUI.Init(BackBuffer, DialogBackgroundBuffer);
  DialogUI.SetStyle(@UIStyle);

  DialogHeight := Height;
  DialogButtonIndex := -1;
  DialogLabel := nil;
  DialogBottomHeight := 2;
  DialogTopHeight := DialogHeight - DialogBottomHeight;

  if PrevDialog = Dialog_None then
    RenderDialogDitheredBackground(BackBuffer);

  { Save the background behind the dialog }
  GetImage(DialogSavedBgImage, GetDialogX, GetDialogY, DialogImage^.Width, DialogHeight, BackBuffer);

  { Render the top part of the dialog background }
  DialogSourceRect.X := 0;
  DialogSourceRect.Y := 0;
  DialogSourceRect.Width := DialogImage^.Width;
  DialogSourceRect.Height := DialogTopHeight;
  PutImageRect(DialogImage^, DialogSourceRect, GetDialogX, GetDialogY, False, BackBuffer);

  { Render the bottom part of the dialog background }
  DialogSourceRect.X := 0;
  DialogSourceRect.Y := DialogImage^.Height - DialogBottomHeight;
  DialogSourceRect.Width := DialogImage^.Width;
  DialogSourceRect.Height := DialogBottomHeight;
  PutImageRect(DialogImage^, DialogSourceRect, GetDialogX, GetDialogY + DialogTopHeight, False, BackBuffer);

  if Title <> '' then
  begin
    DialogHasTitle := True;
    PrintFontTextCentered(160, GetDialogY + 10, Title, FontLarge^, BackBuffer);
  end
  else
    DialogHasTitle := False;

  { Save the UI background, we just need the background of the dialog }
  DialogSourceRect.X := GetDialogX;
  DialogSourceRect.Y := GetDialogY;
  DialogSourceRect.Width := DialogImage^.Width;
  DialogSourceRect.Height := DialogHeight;
  CopyFrameBufferRect(BackBuffer, DialogSourceRect,
                      DialogBackgroundBuffer, DialogSourceRect.X, DialogSourceRect.Y);


  if PrevDialog = Dialog_None then
    { Fullscreen render  }
    RenderFrameBuffer(BackBuffer)
  else
  begin
    { Only the dialog column render }
    DialogSourceRect.Y := 0;
    DialogSourceRect.Height := 200;
    CopyFrameBufferRect(BackBuffer, DialogSourceRect,
                        ScreenBuffer, DialogSourceRect.X, DialogSourceRect.Y);
  end;

  ClearAllKeyStates;
end;

procedure TXiCloneGame.AddDialogLabel(Text: String);
var
  L: PLabel;
  H: Integer;
  MessageLines: TMultiLineText;
  MessageLineCount: Byte;
  StartY: Integer;
begin
  SplitLines(Text, MessageLines, MessageLineCount);
  H := MessageLineCount * FontSmall^.Height;

  StartY := GetDialogY + 10;
  if DialogHasTitle then
    StartY := StartY + FontLarge^.Height + 10;

  New(L, Init(GetDialogX + 8, StartY, DialogImage^.Width - 16, H, Text, FontSmall));
  L^.TextAlign := Align_Center + Align_Top;
  DialogUI.AddWidget(L);

  DialogLabel := L;
end;

procedure TXiCloneGame.AddDialogButton(Text: String; EventHandler: TEventHandler);
var
  Button: PButton;
  StartY: Integer;
begin
  if DialogButtonIndex = MaxDialogButtons then
    Exit;

  StartY := GetDialogY + 10;
  if DialogHasTitle then
    StartY := StartY + FontLarge^.Height + 10;
  if DialogLabel <> nil then
    StartY := StartY + DialogLabel^.Rectangle.Height + 10;

  Inc(DialogButtonIndex);

  New(Button, Init(GetDialogX + 20, StartY + DialogButtonIndex * 20, 120, 16, Text, FontSmall));
  Button^.SetEventHandler(@EventHandler);
  DialogUI.AddWidget(Button);

  DialogButtons[DialogButtonIndex] := Button;
end;

procedure TXiCloneGame.ShowDialog(UpdateProcedure: TUpdateProcedure);
var
  i: Integer;
begin
  if DialogButtonIndex < 0 then
    Exit;

  DialogUI.SetFocus(DialogButtons[0]);
  DialogUI.Run(@UpdateProcedure, True);

  { Cleanup label if exists }
  if DialogLabel <> nil then
  begin
    DialogUI.RemoveWidget(DialogLabel);
    Dispose(DialogLabel, Done);
    DialogLabel := nil;
  end;

  { Cleanup buttons }
  for i := 0 to DialogButtonIndex do
  begin
    DialogUI.RemoveWidget(DialogButtons[i]);
    Dispose(DialogButtons[i], Done);
  end;

  DialogUI.Done;

  { Restore background behind the dialog }
  PutImage(DialogSavedBgImage, GetDialogX, GetDialogY, False, BackBuffer);
  FreeImage(DialogSavedBgImage);

  if NextDialog = Dialog_None then
    CopyFrameBuffer(BackgroundBuffer, BackBuffer);

  ClearAllKeyStates;

  ResetTiming;
end;

function TXiCloneGame.ShowConfirm(Message: String; UpdateProcedure: TUpdateProcedure): Boolean;
var
  MessageLines: TMultiLineText;
  MessageLineCount: Byte;
  i: Byte;
  H: Integer;
  DialogHeightCalc: Word;
begin
  { Calculate message dimensions }
  SplitLines(Message, MessageLines, MessageLineCount);
  H := MessageLineCount * FontSmall^.Height;

  { Calculate dialog height: spacing (10) + message height + spacing (10) + 2 buttons (40) + bottom spacing (10) }
  DialogHeightCalc := 10 + H + 10 + 40 + 10;

  { Initialize dialog without title }
  InitDialog('', DialogHeightCalc);

  { Add message label }
  AddDialogLabel(Message);

  AddDialogButton('Cancel', CancelEvent);
  AddDialogButton('OK', OkEvent);

  ShowDialog(UpdateProcedure);

  ShowConfirm := ConfirmDialogAnswer;
end;

end.
