unit BaseScr;

interface

uses
  VGA, VGAFont, VGAUI, Keyboard, GameUnit, XiStyle, XiRender;

const
  MaxDialogButtons = 2;

type
  PBaseScreen = ^TBaseScreen;
  TBaseScreen = object(TScreen)

    { Fonts }
    constructor Init;
    destructor Done; virtual;
    procedure PostInit; virtual;
    procedure Update(DT: Real); virtual;

    procedure InitDialog(Title: String);
    procedure AddDialogButton(Text: String; EventHandler: TEventHandler);
    procedure ShowDialog(UpdateProcedure: TUpdateProcedure);
  end;

var
  FontLarge: PFont;
  FontSmall: PFont;

  DialogUI: TUIManager;
  UIStyle: TXiStyle;

  DialogBackgroundBuffer: PFrameBuffer;  
  DialogImage: PImage;
  DialogButtons: array [0..MaxDialogButtons - 1] of PButton;
  DialogButtonIndex: ShortInt;

implementation

constructor TBaseScreen.Init;
begin
  inherited Init;

  { Load globally used resources only once }
  if DialogBackgroundBuffer = nil then
  begin
    { Load fonts }
    FontLarge   := Game.ResMan.GetFont('large');
    FontSmall   := Game.ResMan.GetFont('small');
  
    { Load dialog background }
    DialogImage := Game.ResMan.GetImage('dialog');  
    DialogBackgroundBuffer := CreateFrameBuffer;  

    { Initialize the UI style }
    UIStyle.Init(186, 188, 189, 15);
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
end;

procedure TBaseScreen.Update(DT: Real);
begin
end;

procedure TBaseScreen.InitDialog(Title: String);
begin
  DialogUI.Init(Game.BackBuffer, DialogBackgroundBuffer);
  DialogUI.SetStyle(@UIStyle);

  DialogButtonIndex := -1;

  { Render the background }
  RenderDialogBackground(Game.BackBuffer);
  PutImage(DialogImage^, 160 - DialogImage^.Width div 2, 100 - DialogImage^.Height div 2, False, Game.BackBuffer);
  PrintFontTextCentered(160, 67, Title, FontLarge^, Game.BackBuffer);

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

  New(Button, Init(100, 97 + DialogButtonIndex * 18, 120, 14, Text, FontSmall));
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
  DialogBackgroundBuffer := nil;
end.