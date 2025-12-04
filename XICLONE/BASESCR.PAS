unit BaseScr;

interface

uses
  VGA, VGAFont, VGAUI, Keyboard, GameUnit, XiStyle, XiRender;

const
  MaxDialogButtons = 2;

type
  PBaseScreen = ^TBaseScreen;
  TBaseScreen = object(TScreen)

    { UI related }
    DialogBackgroundBuffer: PFrameBuffer;  
    DialogImage: PImage;
    DialogButtons: array [0..MaxDialogButtons - 1] of PButton;
    DialogButtonIndex: ShortInt;

    CustomStyle: TXiStyle;

    { Fonts }
    FontLarge: PFont;
    FontSmall: PFont;

    { Palette }
    Palette: PPalette;    

    constructor Init;
    destructor Done; virtual;
    procedure Update(DT: Real); virtual;

    procedure InitDialog(Title: String);
    procedure AddDialogButton(Text: String; EventHandler: TEventHandler);
    procedure ShowDialog(UpdateProcedure: TUpdateProcedure);
  end;

var
  UI: TUIManager;

implementation


constructor TBaseScreen.Init;
begin
  inherited Init;
  { Load fonts }
  FontLarge   := Game.ResMan.GetFont('large');
  FontSmall   := Game.ResMan.GetFont('small');
  
  { Load dialog background }
  DialogImage := Game.ResMan.GetImage('dialog');  
  DialogBackgroundBuffer := CreateFrameBuffer;  

  { Initialize the UI style }
  CustomStyle.Init(186, 188, 189, 15);
end;

destructor TBaseScreen.Done;
begin
  FreeFrameBuffer(DialogBackgroundBuffer);  
end;

procedure TBaseScreen.Update(DT: Real);
begin
end;

procedure TBaseScreen.InitDialog(Title: String);
begin
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

  { Create UI }
  UI.Init(Game.BackBuffer, DialogBackgroundBuffer);
  UI.SetStyle(@CustomStyle);  
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
  UI.AddWidget(Button);

  DialogButtons[DialogButtonIndex] := Button;
end;

procedure TBaseScreen.ShowDialog(UpdateProcedure: TUpdateProcedure);
var
  i: Integer;
begin
  if DialogButtonIndex < 0 then
    Exit;

  UI.SetFocus(DialogButtons[0]);

  UI.Run(@UpdateProcedure, True);

  for i := 0 to DialogButtonIndex - 1 do
  begin
    UI.RemoveWidget(DialogButtons[i]);
    Dispose(DialogButtons[i], Done);
  end;
  UI.Done;  

  CopyFrameBuffer(Game.BackgroundBuffer, Game.BackBuffer);
  ClearAllKeyStates;

  Game.ResetTiming;
end;

end.