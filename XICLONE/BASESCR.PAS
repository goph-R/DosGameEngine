unit BaseScr;

interface

uses
  VGA, VGAFont, VGAUI, Keyboard, GameUnit, XiGame, HiScore, StrUtil;

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

constructor TBaseScreen.Init;
begin
  inherited Init;
end;

destructor TBaseScreen.Done;
begin
  inherited Done;
end;

procedure TBaseScreen.PostInit;
begin
  inherited PostInit;

  { Set the palette (loaded in TXiCloneGame.Start) }
  SetPalette(Game.Palette^);
end;

procedure TBaseScreen.Update(DT: Real);
begin
end;

function GetDialogX: Integer;
begin
  GetDialogX := 160 - Game.DialogImage^.Width div 2;
end;

function GetDialogY: Integer;
begin
  GetDialogY := 100 - Game.DialogHeight div 2;
end;

procedure TBaseScreen.InitDialog(Title: String; Height: Word);
var
  DialogSourceRect: TRectangle;
  DialogX: Integer;
  DialogTopHeight: Word;
  DialogBottomHeight: Word;
begin
  Game.DialogUI.Init(Game.BackBuffer, Game.DialogBackgroundBuffer);
  Game.DialogUI.SetStyle(@Game.UIStyle);

  Game.DialogHeight := Height;
  Game.DialogButtonIndex := -1;
  Game.DialogLabel := nil;
  DialogBottomHeight := 2;
  DialogTopHeight := Game.DialogHeight - DialogBottomHeight;

  if Game.PrevDialog = Dialog_None then
    RenderDialogDitheredBackground(Game.BackBuffer);

  { Save the background behind the dialog }
  GetImage(Game.DialogSavedBgImage, GetDialogX, GetDialogY, Game.DialogImage^.Width, Game.DialogHeight, Game.BackBuffer);

  { Render the top part of the dialog background }
  DialogSourceRect.X := 0;
  DialogSourceRect.Y := 0;
  DialogSourceRect.Width := Game.DialogImage^.Width;
  DialogSourceRect.Height := DialogTopHeight;
  PutImageRect(Game.DialogImage^, DialogSourceRect, GetDialogX, GetDialogY, False, Game.BackBuffer);

  { Render the bottom part of the dialog background }
  DialogSourceRect.X := 0;
  DialogSourceRect.Y := Game.DialogImage^.Height - DialogBottomHeight;
  DialogSourceRect.Width := Game.DialogImage^.Width;
  DialogSourceRect.Height := DialogBottomHeight;
  PutImageRect(Game.DialogImage^, DialogSourceRect, GetDialogX, GetDialogY + DialogTopHeight, False, Game.BackBuffer);

  if Title <> '' then
  begin
    Game.DialogHasTitle := True;
    PrintFontTextCentered(160, GetDialogY + 10, Title, Game.FontLarge^, Game.BackBuffer);
  end
  else
    Game.DialogHasTitle := False;

  { Save the UI background, we just need the background of the dialog }
  DialogSourceRect.X := GetDialogX;
  DialogSourceRect.Y := GetDialogY;
  DialogSourceRect.Width := Game.DialogImage^.Width;
  DialogSourceRect.Height := Game.DialogHeight;
  CopyFrameBufferRect(Game.BackBuffer, DialogSourceRect,
                      Game.DialogBackgroundBuffer, DialogSourceRect.X, DialogSourceRect.Y);


  if Game.PrevDialog = Dialog_None then
    { Fullscreen render  }
    RenderFrameBuffer(Game.BackBuffer)
  else
  begin
    { Only the dialog column render }
    DialogSourceRect.Y := 0;
    DialogSourceRect.Height := 200;
    CopyFrameBufferRect(Game.BackBuffer, DialogSourceRect,
                        Game.ScreenBuffer, DialogSourceRect.X, DialogSourceRect.Y);
  end;

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
  H := MessageLineCount * Game.FontSmall^.Height;

  StartY := GetDialogY + 10;
  if Game.DialogHasTitle then
    StartY := StartY + Game.FontLarge^.Height + 10;

  New(L, Init(GetDialogX + 8, StartY, Game.DialogImage^.Width - 16, H, Text, Game.FontSmall));
  L^.TextAlign := Align_Center + Align_Top;
  Game.DialogUI.AddWidget(L);

  Game.DialogLabel := L;
end;

procedure TBaseScreen.AddDialogButton(Text: String; EventHandler: TEventHandler);
var
  Button: PButton;
  StartY: Integer;
begin
  if Game.DialogButtonIndex = MaxDialogButtons then
    Exit;

  StartY := GetDialogY + 10;
  if Game.DialogHasTitle then
    StartY := StartY + Game.FontLarge^.Height + 10;
  if Game.DialogLabel <> nil then
    StartY := StartY + Game.DialogLabel^.Rectangle.Height + 10;

  Inc(Game.DialogButtonIndex);

  New(Button, Init(GetDialogX + 20, StartY + Game.DialogButtonIndex * 20, 120, 16, Text, Game.FontSmall));
  Button^.SetEventHandler(@EventHandler);
  Game.DialogUI.AddWidget(Button);

  Game.DialogButtons[Game.DialogButtonIndex] := Button;
end;

procedure TBaseScreen.ShowDialog(UpdateProcedure: TUpdateProcedure);
var
  i: Integer;
begin
  if Game.DialogButtonIndex < 0 then
    Exit;

  Game.DialogUI.SetFocus(Game.DialogButtons[0]);
  Game.DialogUI.Run(@UpdateProcedure, True);

  { Cleanup label if exists }
  if Game.DialogLabel <> nil then
  begin
    Game.DialogUI.RemoveWidget(Game.DialogLabel);
    Dispose(Game.DialogLabel, Done);
    Game.DialogLabel := nil;
  end;

  { Cleanup buttons }
  for i := 0 to Game.DialogButtonIndex do
  begin
    Game.DialogUI.RemoveWidget(Game.DialogButtons[i]);
    Dispose(Game.DialogButtons[i], Done);
  end;

  Game.DialogUI.Done;

  { Restore background behind the dialog }
  PutImage(Game.DialogSavedBgImage, GetDialogX, GetDialogY, False, Game.BackBuffer);
  FreeImage(Game.DialogSavedBgImage);

  if Game.NextDialog = Dialog_None then
    CopyFrameBuffer(Game.BackgroundBuffer, Game.BackBuffer);

  ClearAllKeyStates;

  Game.ResetTiming;
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
  H := MessageLineCount * Game.FontSmall^.Height;

  { Calculate dialog height: spacing (10) + message height + spacing (10) + 2 buttons (40) + bottom spacing (10) }
  DialogHeightCalc := 10 + H + 10 + 40 + 10;

  { Initialize dialog without title }
  InitDialog('', DialogHeightCalc);

  { Add message label }
  AddDialogLabel(Message);

  AddDialogButton('Cancel', CancelEvent);
  AddDialogButton('OK', OkEvent);

  ShowDialog(UpdateProcedure);

  ShowConfirm := Game.ConfirmDialogAnswer;
end;

end.