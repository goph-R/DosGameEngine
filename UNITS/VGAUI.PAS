{ ========================================================================== }
{ VGAUI.PAS - Minimal UI System for VGA Mode 13h                            }
{                                                                            }
{ Lightweight widget-based UI framework for DOS VGA graphics.               }
{ Keyboard-driven navigation with event handling.                           }
{                                                                            }
{ Features:                                                                  }
{   - Object-oriented widget hierarchy (Label, Button, Checkbox, LineEdit) }
{   - Event-driven model with procedure pointers                            }
{   - Focus management with keyboard navigation (Tab, arrows, Enter)       }
{   - Theming system with 3D beveled panels                                 }
{   - Dirty rectangle rendering integration                                 }
{                                                                            }
{ Dependencies: VGA, VGAFONT, KEYBOARD, LINKLIST, GENTYPES                  }
{ ========================================================================== }

unit VGAUI;

interface

uses VGA, VGAFont, GenTypes, LinkList;

{ ========================================================================== }
{ Event System                                                               }
{ ========================================================================== }

type
  TEventType = (
    Event_None,
    Event_KeyPress,    { Key was pressed }
    Event_FocusGain,   { Widget gained focus }
    Event_FocusLost    { Widget lost focus }
  );

  TEvent = record
    EventType: TEventType;
    KeyCode: Byte;       { Scancode from KEYBOARD.PAS }
    Handled: Boolean;    { Set to True if widget handled the event }
  end;

{ ========================================================================== }
{ Forward Declarations                                                       }
{ ========================================================================== }

type
  TWidget = object
    Rectangle: TRectangle;
    Visible: Boolean;
    Enabled: Boolean;
    Focused: Boolean;
    EventHandler: Pointer;  { TEventHandler - defined below }
    Tag: Integer;

    procedure Init(X, Y: Integer; W, H: Word);
    procedure SetEventHandler(Handler: Pointer);
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; HighColor, NormalColor, LowColor, FocusColor: Byte); virtual;
    procedure Done; virtual;
  end;

  PWidget = ^TWidget;

{$F+}  { Far call for procedure pointer compatibility }
  TEventHandler = procedure(var Widget: TWidget; var Event: TEvent);
{$F-}

{ ========================================================================== }
{ UI Style and Theming                                                       }
{ ========================================================================== }

type
  TUIStyle = object
    HighColor: Byte;      { Light edge color (highlight) }
    NormalColor: Byte;    { Middle/fill color }
    LowColor: Byte;       { Dark edge color (shadow) }
    FocusColor: Byte;     { Border color for focused widgets (palette animated) }

    procedure Init(High, Normal, Low, Focus: Byte);
    procedure RenderPanel(const R: TRectangle; Pressed: Boolean; FrameBuffer: PFrameBuffer); virtual;
  end;

  PUIStyle = ^TUIStyle;

{ ========================================================================== }
{ Widget Types                                                               }
{ ========================================================================== }

type
  { Non-interactive text label }
  TLabel = object(TWidget)
    Text: PShortString;
    Font: PFont;

    procedure Init(X, Y: Integer; const TextStr: string; FontPtr: PFont);
    procedure SetText(const NewText: string);
    procedure Render(FrameBuffer: PFrameBuffer; HighColor, NormalColor, LowColor, FocusColor: Byte); virtual;
    procedure Done; virtual;
  end;

  PLabel = ^TLabel;

  { Interactive button with 3D panel }
  TButton = object(TWidget)
    Text: PShortString;
    Font: PFont;
    Pressed: Boolean;  { Visual state for rendering }

    procedure Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont);
    procedure SetText(const NewText: string);
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; HighColor, NormalColor, LowColor, FocusColor: Byte); virtual;
    procedure Done; virtual;
  end;

  PButton = ^TButton;

  { Interactive checkbox with image sprite }
  TCheckbox = object(TWidget)
    Text: PShortString;
    Font: PFont;
    Image: PImage;
    ImageWidth: Word;
    ImageHeight: Word;
    Checked: Boolean;

    procedure Init(X, Y: Integer; const TextStr: string; FontPtr: PFont;
                   CheckboxImage: PImage; ImgW, ImgH: Word);
    procedure SetText(const NewText: string);
    procedure SetChecked(Value: Boolean);
    function IsChecked: Boolean;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; HighColor, NormalColor, LowColor, FocusColor: Byte); virtual;
    procedure Done; virtual;
  end;

  PCheckbox = ^TCheckbox;

  { Interactive text input field }
  TLineEdit = object(TWidget)
    Text: PShortString;
    Font: PFont;
    MaxLength: Byte;
    CursorVisible: Boolean;
    CursorTimer: Real;

    procedure Init(X, Y: Integer; W, H: Word; FontPtr: PFont; MaxLen: Byte);
    procedure SetText(const NewText: string);
    function GetText: string;
    procedure Clear;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; HighColor, NormalColor, LowColor, FocusColor: Byte); virtual;
    procedure Update(DeltaTime: Real);
    procedure Done; virtual;
  end;

  PLineEdit = ^TLineEdit;

{ ========================================================================== }
{ UI Manager                                                                 }
{ ========================================================================== }

type
  TUIManager = object
    Widgets: TLinkedList;
    FocusedWidget: PWidget;
    BackBuffer: PFrameBuffer;
    Style: TUIStyle;

    procedure Init(FrameBuffer: PFrameBuffer);
    procedure AddWidget(Widget: PWidget);
    procedure RemoveWidget(Widget: PWidget);
    procedure SetFocus(Widget: PWidget);
    procedure FocusNext;
    procedure FocusPrev;
    procedure HandleEvent(var Event: TEvent);
    procedure RenderAll;
    procedure SetStyle(const NewStyle: TUIStyle);
    procedure Done;
  end;

  PUIManager = ^TUIManager;

{ ========================================================================== }

implementation

{ ========================================================================== }
{ TUIStyle Implementation                                                    }
{ ========================================================================== }

procedure TUIStyle.Init(High, Normal, Low, Focus: Byte);
begin
  HighColor := High;
  NormalColor := Normal;
  LowColor := Low;
  FocusColor := Focus;
end;

procedure TUIStyle.RenderPanel(const R: TRectangle; Pressed: Boolean; FrameBuffer: PFrameBuffer);
begin
  if Pressed then
  begin
    { Sunken: dark top-left, light bottom-right }
    DrawLine(R.X, R.Y, R.X + R.Width - 1, R.Y, LowColor, FrameBuffer);  { Top }
    DrawLine(R.X, R.Y, R.X, R.Y + R.Height - 1, LowColor, FrameBuffer); { Left }
    DrawLine(R.X + R.Width - 1, R.Y, R.X + R.Width - 1, R.Y + R.Height - 1, HighColor, FrameBuffer); { Right }
    DrawLine(R.X, R.Y + R.Height - 1, R.X + R.Width - 1, R.Y + R.Height - 1, HighColor, FrameBuffer); { Bottom }
  end
  else
  begin
    { Raised: light top-left, dark bottom-right }
    DrawLine(R.X, R.Y, R.X + R.Width - 1, R.Y, HighColor, FrameBuffer);  { Top }
    DrawLine(R.X, R.Y, R.X, R.Y + R.Height - 1, HighColor, FrameBuffer); { Left }
    DrawLine(R.X + R.Width - 1, R.Y, R.X + R.Width - 1, R.Y + R.Height - 1, LowColor, FrameBuffer); { Right }
    DrawLine(R.X, R.Y + R.Height - 1, R.X + R.Width - 1, R.Y + R.Height - 1, LowColor, FrameBuffer); { Bottom }
  end;
end;

{ ========================================================================== }
{ TWidget Base Implementation                                                }
{ ========================================================================== }

procedure TWidget.Init(X, Y: Integer; W, H: Word);
begin
  Rectangle.X := X;
  Rectangle.Y := Y;
  Rectangle.Width := W;
  Rectangle.Height := H;
  Visible := True;
  Enabled := True;
  Focused := False;
  EventHandler := nil;
  Tag := 0;
end;

procedure TWidget.SetEventHandler(Handler: Pointer);
begin
  EventHandler := Handler;
end;

procedure TWidget.HandleEvent(var Event: TEvent);
begin
  { Default implementation: call event handler if set }
  if EventHandler <> nil then
    TEventHandler(EventHandler)(Self, Event);
end;

procedure TWidget.Render(FrameBuffer: PFrameBuffer; HighColor, NormalColor, LowColor, FocusColor: Byte);
begin
  { Abstract - must be overridden }
end;

procedure TWidget.Done;
begin
  { Base cleanup - override in subclasses }
end;

{ ========================================================================== }
{ TLabel Implementation                                                      }
{ ========================================================================== }

procedure TLabel.Init(X, Y: Integer; const TextStr: string; FontPtr: PFont);
begin
  { Initialize base widget }
  TWidget.Init(X, Y, GetTextWidth(TextStr, FontPtr^), FontPtr^.Height);
  Enabled := False;  { Labels cannot receive focus }

  { Allocate and copy text }
  New(Text);
  Text^ := TextStr;
  Font := FontPtr;
end;

procedure TLabel.SetText(const NewText: string);
begin
  if Text <> nil then
  begin
    Text^ := NewText;
    { Update width based on new text }
    Rectangle.Width := GetTextWidth(NewText, Font^);
  end;
end;

procedure TLabel.Render(FrameBuffer: PFrameBuffer; HighColor, NormalColor, LowColor, FocusColor: Byte);
begin
  if not Visible then Exit;
  PrintFontText(Rectangle.X, Rectangle.Y, Text^, Font^, FrameBuffer);
end;

procedure TLabel.Done;
begin
  if Text <> nil then
  begin
    Dispose(Text);
    Text := nil;
  end;
end;

{ ========================================================================== }
{ TButton Implementation                                                     }
{ ========================================================================== }

procedure TButton.Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont);
begin
  TWidget.Init(X, Y, W, H);

  { Allocate and copy text }
  New(Text);
  Text^ := TextStr;
  Font := FontPtr;
  Pressed := False;
end;

procedure TButton.SetText(const NewText: string);
begin
  if Text <> nil then
    Text^ := NewText;
end;

procedure TButton.HandleEvent(var Event: TEvent);
begin
  if Event.EventType = Event_KeyPress then
  begin
    { Enter or Space triggers the button }
    if (Event.KeyCode = $1C) or (Event.KeyCode = $39) then  { Enter=$1C, Space=$39 }
    begin
      Event.Handled := True;
      if EventHandler <> nil then
        TEventHandler(EventHandler)(Self, Event);
    end;
  end;
end;

procedure TButton.Render(FrameBuffer: PFrameBuffer; HighColor, NormalColor, LowColor, FocusColor: Byte);
var
  Style: TUIStyle;
  TextWidth: Integer;
  TextX, TextY: Integer;
begin
  if not Visible then Exit;

  { Render 3D panel }
  Style.Init(HighColor, NormalColor, LowColor, FocusColor);
  Style.RenderPanel(Rectangle, Pressed, FrameBuffer);

  { Render centered text }
  TextWidth := GetTextWidth(Text^, Font^);
  TextX := Rectangle.X + (Rectangle.Width - TextWidth) div 2;
  TextY := Rectangle.Y + (Rectangle.Height - Font^.Height) div 2;
  PrintFontText(TextX, TextY, Text^, Font^, FrameBuffer);

  { Render focus border if focused }
  if Focused then
    DrawRect(Rectangle.X - 1, Rectangle.Y - 1, Rectangle.Width + 2, Rectangle.Height + 2, FocusColor, FrameBuffer);
end;

procedure TButton.Done;
begin
  if Text <> nil then
  begin
    Dispose(Text);
    Text := nil;
  end;
end;

{ ========================================================================== }
{ TCheckbox Implementation                                                   }
{ ========================================================================== }

procedure TCheckbox.Init(X, Y: Integer; const TextStr: string; FontPtr: PFont;
                         CheckboxImage: PImage; ImgW, ImgH: Word);
var
  TextWidth: Integer;
begin
  { Calculate total width: image + gap + text }
  TextWidth := GetTextWidth(TextStr, FontPtr^);
  TWidget.Init(X, Y, ImgW + 4 + TextWidth, ImgH);

  { Allocate and copy text }
  New(Text);
  Text^ := TextStr;
  Font := FontPtr;
  Image := CheckboxImage;
  ImageWidth := ImgW;
  ImageHeight := ImgH;
  Checked := False;
end;

procedure TCheckbox.SetText(const NewText: string);
begin
  if Text <> nil then
    Text^ := NewText;
end;

procedure TCheckbox.SetChecked(Value: Boolean);
begin
  Checked := Value;
end;

function TCheckbox.IsChecked: Boolean;
begin
  IsChecked := Checked;
end;

procedure TCheckbox.HandleEvent(var Event: TEvent);
begin
  if Event.EventType = Event_KeyPress then
  begin
    { Space toggles checkbox }
    if Event.KeyCode = $39 then  { Space=$39 }
    begin
      Checked := not Checked;
      Event.Handled := True;
      if EventHandler <> nil then
        TEventHandler(EventHandler)(Self, Event);
    end;
  end;
end;

procedure TCheckbox.Render(FrameBuffer: PFrameBuffer; HighColor, NormalColor, LowColor, FocusColor: Byte);
var
  SrcRect: TRectangle;
  TextX: Integer;
begin
  if not Visible then Exit;

  { Render checkbox image (row 0=unchecked, row 1=checked) }
  SrcRect.X := 0;
  if Checked then
    SrcRect.Y := ImageHeight
  else
    SrcRect.Y := 0;
  SrcRect.Width := ImageWidth;
  SrcRect.Height := ImageHeight;

  PutImageRect(Image^, SrcRect, Rectangle.X, Rectangle.Y, True, FrameBuffer);

  { Render text }
  TextX := Rectangle.X + ImageWidth + 4;
  PrintFontText(TextX, Rectangle.Y, Text^, Font^, FrameBuffer);

  { Render focus border if focused }
  if Focused then
    DrawRect(Rectangle.X - 1, Rectangle.Y - 1, Rectangle.Width + 2, Rectangle.Height + 2, FocusColor, FrameBuffer);
end;

procedure TCheckbox.Done;
begin
  if Text <> nil then
  begin
    Dispose(Text);
    Text := nil;
  end;
end;

{ ========================================================================== }
{ TLineEdit Implementation                                                   }
{ ========================================================================== }

procedure TLineEdit.Init(X, Y: Integer; W, H: Word; FontPtr: PFont; MaxLen: Byte);
begin
  TWidget.Init(X, Y, W, H);

  { Allocate empty text }
  New(Text);
  Text^ := '';
  Font := FontPtr;
  MaxLength := MaxLen;
  CursorVisible := True;
  CursorTimer := 0;
end;

procedure TLineEdit.SetText(const NewText: string);
begin
  if Text <> nil then
  begin
    if Length(NewText) <= MaxLength then
      Text^ := NewText
    else
      Text^ := Copy(NewText, 1, MaxLength);
  end;
end;

function TLineEdit.GetText: string;
begin
  if Text <> nil then
    GetText := Text^
  else
    GetText := '';
end;

procedure TLineEdit.Clear;
begin
  if Text <> nil then
    Text^ := '';
end;

{ Helper: Convert scancode to ASCII character }
function ScancodeToChar(Scancode: Byte; ShiftPressed: Boolean): Char;
begin
  { Letters A-Z (scancodes $10-$19, $1E-$26, $2C-$32) }
  case Scancode of
    $10: if ShiftPressed then ScancodeToChar := 'Q' else ScancodeToChar := 'q';
    $11: if ShiftPressed then ScancodeToChar := 'W' else ScancodeToChar := 'w';
    $12: if ShiftPressed then ScancodeToChar := 'E' else ScancodeToChar := 'e';
    $13: if ShiftPressed then ScancodeToChar := 'R' else ScancodeToChar := 'r';
    $14: if ShiftPressed then ScancodeToChar := 'T' else ScancodeToChar := 't';
    $15: if ShiftPressed then ScancodeToChar := 'Y' else ScancodeToChar := 'y';
    $16: if ShiftPressed then ScancodeToChar := 'U' else ScancodeToChar := 'u';
    $17: if ShiftPressed then ScancodeToChar := 'I' else ScancodeToChar := 'i';
    $18: if ShiftPressed then ScancodeToChar := 'O' else ScancodeToChar := 'o';
    $19: if ShiftPressed then ScancodeToChar := 'P' else ScancodeToChar := 'p';
    $1E: if ShiftPressed then ScancodeToChar := 'A' else ScancodeToChar := 'a';
    $1F: if ShiftPressed then ScancodeToChar := 'S' else ScancodeToChar := 's';
    $20: if ShiftPressed then ScancodeToChar := 'D' else ScancodeToChar := 'd';
    $21: if ShiftPressed then ScancodeToChar := 'F' else ScancodeToChar := 'f';
    $22: if ShiftPressed then ScancodeToChar := 'G' else ScancodeToChar := 'g';
    $23: if ShiftPressed then ScancodeToChar := 'H' else ScancodeToChar := 'h';
    $24: if ShiftPressed then ScancodeToChar := 'J' else ScancodeToChar := 'j';
    $25: if ShiftPressed then ScancodeToChar := 'K' else ScancodeToChar := 'k';
    $26: if ShiftPressed then ScancodeToChar := 'L' else ScancodeToChar := 'l';
    $2C: if ShiftPressed then ScancodeToChar := 'Z' else ScancodeToChar := 'z';
    $2D: if ShiftPressed then ScancodeToChar := 'X' else ScancodeToChar := 'x';
    $2E: if ShiftPressed then ScancodeToChar := 'C' else ScancodeToChar := 'c';
    $2F: if ShiftPressed then ScancodeToChar := 'V' else ScancodeToChar := 'v';
    $30: if ShiftPressed then ScancodeToChar := 'B' else ScancodeToChar := 'b';
    $31: if ShiftPressed then ScancodeToChar := 'N' else ScancodeToChar := 'n';
    $32: if ShiftPressed then ScancodeToChar := 'M' else ScancodeToChar := 'm';

    { Numbers 0-9 }
    $02: if ShiftPressed then ScancodeToChar := '!' else ScancodeToChar := '1';
    $03: if ShiftPressed then ScancodeToChar := '@' else ScancodeToChar := '2';
    $04: if ShiftPressed then ScancodeToChar := '#' else ScancodeToChar := '3';
    $05: if ShiftPressed then ScancodeToChar := '$' else ScancodeToChar := '4';
    $06: if ShiftPressed then ScancodeToChar := '%' else ScancodeToChar := '5';
    $07: if ShiftPressed then ScancodeToChar := '^' else ScancodeToChar := '6';
    $08: if ShiftPressed then ScancodeToChar := '&' else ScancodeToChar := '7';
    $09: if ShiftPressed then ScancodeToChar := '*' else ScancodeToChar := '8';
    $0A: if ShiftPressed then ScancodeToChar := '(' else ScancodeToChar := '9';
    $0B: if ShiftPressed then ScancodeToChar := ')' else ScancodeToChar := '0';

    { Space }
    $39: ScancodeToChar := ' ';

    { Punctuation }
    $0C: if ShiftPressed then ScancodeToChar := '_' else ScancodeToChar := '-';
    $0D: if ShiftPressed then ScancodeToChar := '+' else ScancodeToChar := '=';
    $33: if ShiftPressed then ScancodeToChar := '<' else ScancodeToChar := ',';
    $34: if ShiftPressed then ScancodeToChar := '>' else ScancodeToChar := '.';
    $35: if ShiftPressed then ScancodeToChar := '?' else ScancodeToChar := '/';

    else
      ScancodeToChar := #0;  { Invalid/unsupported key }
  end;
end;

procedure TLineEdit.HandleEvent(var Event: TEvent);
var
  Ch: Char;
begin
  if Event.EventType = Event_KeyPress then
  begin
    { Backspace }
    if Event.KeyCode = $0E then  { Backspace=$0E }
    begin
      if Length(Text^) > 0 then
        Delete(Text^, Length(Text^), 1);
      Event.Handled := True;
    end
    { Enter - fire event handler }
    else if Event.KeyCode = $1C then  { Enter=$1C }
    begin
      Event.Handled := True;
      if EventHandler <> nil then
        TEventHandler(EventHandler)(Self, Event);
    end
    { Character input }
    else
    begin
      { TODO: Get shift state from KEYBOARD.PAS }
      Ch := ScancodeToChar(Event.KeyCode, False);
      if (Ch <> #0) and (Length(Text^) < MaxLength) then
      begin
        Text^ := Text^ + Ch;
        Event.Handled := True;
      end;
    end;
  end;
end;

procedure TLineEdit.Render(FrameBuffer: PFrameBuffer; HighColor, NormalColor, LowColor, FocusColor: Byte);
var
  Style: TUIStyle;
  TextX, TextY: Integer;
  DisplayText: string;
  TextWidth: Integer;
  AvailableWidth: Integer;
  CursorX: Integer;
begin
  if not Visible then Exit;

  { Render 3D panel }
  Style.Init(HighColor, NormalColor, LowColor, FocusColor);
  Style.RenderPanel(Rectangle, False, FrameBuffer);

  { Calculate text display }
  AvailableWidth := Rectangle.Width - 8;  { 4px padding on each side }
  TextWidth := GetTextWidth(Text^, Font^);

  { Text scrolling: if text is too wide, show rightmost portion }
  if TextWidth > AvailableWidth then
  begin
    { Find visible substring from right }
    DisplayText := Text^;
    while GetTextWidth(DisplayText, Font^) > AvailableWidth do
      Delete(DisplayText, 1, 1);
  end
  else
    DisplayText := Text^;

  { Render text }
  TextX := Rectangle.X + 4;
  TextY := Rectangle.Y + (Rectangle.Height - Font^.Height) div 2;
  PrintFontText(TextX, TextY, DisplayText, Font^, FrameBuffer);

  { Render blinking cursor if focused }
  if Focused and CursorVisible then
  begin
    CursorX := TextX + GetTextWidth(DisplayText, Font^);
    DrawLine(CursorX, TextY, CursorX, TextY + Font^.Height - 1, FocusColor, FrameBuffer);
  end;

  { Render focus border if focused }
  if Focused then
    DrawRect(Rectangle.X - 1, Rectangle.Y - 1, Rectangle.Width + 2, Rectangle.Height + 2, FocusColor, FrameBuffer);
end;

procedure TLineEdit.Update(DeltaTime: Real);
begin
  { Cursor blink animation }
  CursorTimer := CursorTimer + DeltaTime;
  if CursorTimer >= 0.5 then
  begin
    CursorTimer := 0;
    CursorVisible := not CursorVisible;
  end;
end;

procedure TLineEdit.Done;
begin
  if Text <> nil then
  begin
    Dispose(Text);
    Text := nil;
  end;
end;

{ ========================================================================== }
{ TUIManager Implementation                                                  }
{ ========================================================================== }

procedure TUIManager.Init(FrameBuffer: PFrameBuffer);
begin
  ListInit(Widgets);
  FocusedWidget := nil;
  BackBuffer := FrameBuffer;

  { Initialize default style }
  Style.Init(15, 7, 8, 14);  { White, gray, dark gray, yellow }
end;

procedure TUIManager.AddWidget(Widget: PWidget);
begin
  ListAdd(Widgets, Widget);
end;

procedure TUIManager.RemoveWidget(Widget: PWidget);
begin
  if FocusedWidget = Widget then
    FocusedWidget := nil;
  ListRemove(Widgets, Widget);
end;

procedure TUIManager.SetFocus(Widget: PWidget);
var
  OldEvent, NewEvent: TEvent;
begin
  { Unfocus old widget }
  if FocusedWidget <> nil then
  begin
    FocusedWidget^.Focused := False;
    OldEvent.EventType := Event_FocusLost;
    OldEvent.KeyCode := 0;
    OldEvent.Handled := False;
    FocusedWidget^.HandleEvent(OldEvent);
  end;

  { Focus new widget (if enabled) }
  FocusedWidget := Widget;
  if (Widget <> nil) and Widget^.Enabled then
  begin
    Widget^.Focused := True;
    NewEvent.EventType := Event_FocusGain;
    NewEvent.KeyCode := 0;
    NewEvent.Handled := False;
    Widget^.HandleEvent(NewEvent);
  end;
end;

procedure TUIManager.FocusNext;
var
  Node: PListNode;
  Found: Boolean;
  FirstEnabled: PWidget;
begin
  if Widgets.Head = nil then Exit;

  Found := False;
  FirstEnabled := nil;
  Node := Widgets.Head;

  { Find first enabled widget (for wrap-around) }
  while Node <> nil do
  begin
    if PWidget(Node^.Data)^.Enabled then
    begin
      if FirstEnabled = nil then
        FirstEnabled := PWidget(Node^.Data);
      Break;
    end;
    Node := Node^.Next;
  end;

  { Find current focused widget and move to next }
  Node := Widgets.Head;
  while Node <> nil do
  begin
    if Found and PWidget(Node^.Data)^.Enabled then
    begin
      SetFocus(PWidget(Node^.Data));
      Exit;
    end;

    if PWidget(Node^.Data) = FocusedWidget then
      Found := True;

    Node := Node^.Next;
  end;

  { Wrap around to first enabled widget }
  if FirstEnabled <> nil then
    SetFocus(FirstEnabled);
end;

procedure TUIManager.FocusPrev;
var
  Node: PListNode;
  PrevWidget: PWidget;
  LastEnabled: PWidget;
begin
  if Widgets.Head = nil then Exit;

  PrevWidget := nil;
  LastEnabled := nil;

  { Find last enabled widget (for wrap-around) }
  Node := Widgets.Head;
  while Node <> nil do
  begin
    if PWidget(Node^.Data)^.Enabled then
      LastEnabled := PWidget(Node^.Data);
    Node := Node^.Next;
  end;

  { Find current focused widget and move to previous }
  Node := Widgets.Head;
  while Node <> nil do
  begin
    if PWidget(Node^.Data) = FocusedWidget then
    begin
      if PrevWidget <> nil then
      begin
        SetFocus(PrevWidget);
        Exit;
      end
      else
      begin
        { At beginning, wrap to last }
        if LastEnabled <> nil then
          SetFocus(LastEnabled);
        Exit;
      end;
    end;

    if PWidget(Node^.Data)^.Enabled then
      PrevWidget := PWidget(Node^.Data);

    Node := Node^.Next;
  end;
end;

procedure TUIManager.HandleEvent(var Event: TEvent);
begin
  if FocusedWidget <> nil then
    FocusedWidget^.HandleEvent(Event);
end;

procedure TUIManager.RenderAll;
var
  Node: PListNode;
  Widget: PWidget;
begin
  Node := Widgets.Head;
  while Node <> nil do
  begin
    Widget := PWidget(Node^.Data);
    if Widget^.Visible then
      Widget^.Render(BackBuffer, Style.HighColor, Style.NormalColor, Style.LowColor, Style.FocusColor);
    Node := Node^.Next;
  end;
end;

procedure TUIManager.SetStyle(const NewStyle: TUIStyle);
begin
  Style := NewStyle;
end;

procedure TUIManager.Done;
begin
  ListFree(Widgets);
  FocusedWidget := nil;
end;

end.
