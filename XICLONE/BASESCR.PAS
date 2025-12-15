unit BaseScr;

interface

uses
  VGA, VGAFont, VGAUI, Keyboard, GameUnit, Globals, HiScore;

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
    procedure AddDialogButton(Text: String; EventHandler: TEventHandler);
    procedure ShowDialog(UpdateProcedure: TUpdateProcedure);
  end;

implementation

var
  DialogBackgroundBuffer: PFrameBuffer;  
  DialogImage: PImage;
  DialogButtons: array [0..MaxDialogButtons - 1] of PButton;
  DialogButtonIndex: ShortInt;
  DialogHeight: Word;

  Palette: PPalette;

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

  PrintFontTextCentered(160, GetDialogY + 8, Title, FontLarge^, Game.BackBuffer);

  { Save the UI background }
  CopyFrameBuffer(Game.BackBuffer, DialogBackgroundBuffer);

  { Show it on screen }
  CopyFrameBuffer(Game.BackBuffer, Game.ScreenBuffer);
  
  ClearAllKeyStates; 
end;

procedure TBaseScreen.AddDialogButton(Text: String; EventHandler: TEventHandler);
var
  Button: PButton;
begin
  if DialogButtonIndex = MaxDialogButtons then
    Exit;

  Inc(DialogButtonIndex);

  New(Button, Init(GetDialogX + 20, GetDialogY + 32 + DialogButtonIndex * 20, 120, 16, Text, FontSmall));
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

  for i := 0 to DialogButtonIndex - 1 do
  begin
    DialogUI.RemoveWidget(DialogButtons[i]);
    Dispose(DialogButtons[i], Done);
  end;

  DialogUI.Done;

  CopyFrameBuffer(Game.BackgroundBuffer, Game.BackBuffer);
  ClearAllKeyStates;

  Game.ResetTiming;
end;

begin
  Palette := nil;
  DialogBackgroundBuffer := nil;
end.