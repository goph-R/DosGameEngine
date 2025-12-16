unit BaseScr;

interface

uses
  VGA, VGAFont, VGAUI, Keyboard, GameUnit, Globals, HiScore, StrUtil;

const
  MaxDialogButtons = 5;

type
  PBaseScreen = ^TBaseScreen;
  TBaseScreen = object(TScreen)

    { Fonts }
    constructor Init;
    destructor Done; virtual;
    procedure PostInit; virtual;
    procedure Update(DT: Real); virtual;

    procedure InitDialog(Title: String; Height: Word);
    procedure AddDialogLabel(Text: String);
    procedure AddDialogButton(Text: String; EventHandler: TEventHandler);
    procedure ShowDialog(UpdateProcedure: TUpdateProcedure);
    function ShowConfirm(Message: String; UpdateProcedure: TUpdateProcedure): Boolean;
  end;

implementation

var
  DialogBackgroundBuffer: PFrameBuffer;
  DialogImage: PImage;
  DialogLabel: PLabel;
  DialogButtons: array [0..MaxDialogButtons - 1] of PButton;
  DialogButtonIndex: ShortInt;
  DialogHeight: Word;

  Palette: PPalette;

  DialogHasTitle: Boolean;

procedure RenderDialogBackground(FrameBuffer: PFrameBuffer); assembler;
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

constructor TBaseScreen.Init;
begin
  inherited Init;

  { Load globally used resources only once }
  if DialogBackgroundBuffer = nil then
  begin
    GemsImage := Game.ResMan.GetImage('gems1');

    FontLarge := Game.ResMan.GetFont('large');
    FontSmall := Game.ResMan.GetFont('small');

    DialogImage := Game.ResMan.GetImage('dialog');
    DialogBackgroundBuffer := CreateFrameBuffer;

    UIStyle.Init(186, 188, 189, 15);

    { Initialize high score system }
    InitHighScore(HighScoreTable, HighScoreSalt);
    { Load high score table }
    LoadHighScore('SCORES.XML', HighScoreTable);
  end;
end;

destructor TBaseScreen.Done;
begin
  if DialogBackgroundBuffer <> nil then
  begin
    FreeFrameBuffer(DialogBackgroundBuffer);  
  end;
end;

procedure TBaseScreen.PostInit;
begin
  inherited PostInit;

  { Set the palette only once }
  if Palette = nil then
  begin
    Palette := Game.ResMan.GetPalette('default');
    SetPalette(Palette^);
  end;
end;

procedure TBaseScreen.Update(DT: Real);
begin
end;

function GetDialogX: Integer;
begin
  GetDialogX := 160 - DialogImage^.Width div 2;
end;

function GetDialogY: Integer;
begin
  GetDialogY := 100 - DialogHeight div 2;
end;

procedure TBaseScreen.InitDialog(Title: String; Height: Word);
var
  DialogSourceRect: TRectangle;
  DialogX: Integer;
  DialogTopHeight: Word;
  DialogBottomHeight: Word;
begin
  DialogUI.Init(Game.BackBuffer, DialogBackgroundBuffer);
  DialogUI.SetStyle(@UIStyle);

  DialogHeight := Height;
  DialogButtonIndex := -1;
  DialogLabel := nil;
  DialogBottomHeight := 2;
  DialogTopHeight := DialogHeight - DialogBottomHeight;

  { Render the background }
  RenderDialogBackground(Game.BackBuffer);

  { Render the top part of the dialog background }
  DialogSourceRect.X := 0;
  DialogSourceRect.Y := 0;
  DialogSourceRect.Width := DialogImage^.Width;
  DialogSourceRect.Height := DialogTopHeight;
  PutImageRect(DialogImage^, DialogSourceRect, GetDialogX, GetDialogY, False, Game.BackBuffer);

  { Render the bottom part of the dialog background }
  DialogSourceRect.X := 0;
  DialogSourceRect.Y := DialogImage^.Height - DialogBottomHeight;
  DialogSourceRect.Width := DialogImage^.Width;
  DialogSourceRect.Height := DialogBottomHeight;
  PutImageRect(DialogImage^, DialogSourceRect, GetDialogX, GetDialogY + DialogTopHeight, False, Game.BackBuffer);

  if Title <> '' then 
  begin
    DialogHasTitle := True;
    PrintFontTextCentered(160, GetDialogY + 10, Title, FontLarge^, Game.BackBuffer);    
  end
  else
    DialogHasTitle := False;

  { Save the UI background }
  CopyFrameBuffer(Game.BackBuffer, DialogBackgroundBuffer);

  { Show it on screen }
  CopyFrameBuffer(Game.BackBuffer, Game.ScreenBuffer);
  
  ClearAllKeyStates; 
end;

procedure TBaseScreen.AddDialogLabel(Text: String);
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

procedure TBaseScreen.AddDialogButton(Text: String; EventHandler: TEventHandler);
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

procedure TBaseScreen.ShowDialog(UpdateProcedure: TUpdateProcedure);
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

  CopyFrameBuffer(Game.BackgroundBuffer, Game.BackBuffer);
  ClearAllKeyStates;

  Game.ResetTiming;
end;

{$F+}
procedure OkEvent(var Widget: TWidget; var Event: TEvent); far;
begin
  if DialogUI.IsEnter(Event) then
  begin
    ConfirmDialogAnswer := True;
    DialogUI.Stop;
  end;
end;

procedure CancelEvent(var Widget: TWidget; var Event: TEvent); far;
begin
  if DialogUI.IsEnter(Event) then
  begin
    ConfirmDialogAnswer := False;
    DialogUI.Stop;
  end;
end;
{$F-}


function TBaseScreen.ShowConfirm(Message: String; UpdateProcedure: TUpdateProcedure): Boolean;
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

begin
  Palette := nil;
  DialogBackgroundBuffer := nil;
end.