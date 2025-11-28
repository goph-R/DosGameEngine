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

uses VGA, VGAFont, GenTypes, LinkList, Keyboard, Logger;

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
{ UI Style and Theming                                                       }
{ ========================================================================== }

type
  { TUIStyle must be declared before TWidget since TWidget.Render uses PUIStyle }
  { RenderPanel is virtual to allow custom rendering styles }
  { Example of custom style:
      TMyStyle = object(TUIStyle)
        procedure RenderPanel(const R: TRectangle; Pressed: Boolean; FB: PFrameBuffer); virtual;
      end;

    Then in your code:
      var MyStyle: TMyStyle;
      TMyStyle.Init(MyStyle, 15, 7, 8, 14);
      UIManager.SetStyle(MyStyle);  }
  TUIStyle = object
    HighColor: Byte;      { Light edge color (highlight) }
    NormalColor: Byte;    { Middle/fill color }
    LowColor: Byte;       { Dark edge color (shadow) }
    FocusColor: Byte;     { Border color for focused widgets (palette animated) }

    constructor Init(High, Normal, Low, Focus: Byte);
    procedure RenderPanel(const R: TRectangle; Pressed: Boolean; FrameBuffer: PFrameBuffer); virtual;
  end;

  PUIStyle = ^TUIStyle;

{ ========================================================================== }
{ Base Widget Type                                                           }
{ ========================================================================== }

  TWidget = object
    Rectangle: TRectangle;
    Visible: Boolean;
    Enabled: Boolean;
    Focused: Boolean;
    EventHandler: Pointer;  { TEventHandler - defined below }
    Tag: Integer;

    constructor Init(X, Y: Integer; W, H: Word);
    procedure SetEventHandler(Handler: Pointer);
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    destructor Done; virtual;
  end;

  PWidget = ^TWidget;

{$F+}  { Far call for procedure pointer compatibility }
  TEventHandler = procedure(var Widget: TWidget; var Event: TEvent);
{$F-}

{ ========================================================================== }
{ Widget Types                                                               }
{ ========================================================================== }

type
  { Non-interactive text label }
  TLabel = object(TWidget)
    Text: PShortString;
    Font: PFont;

    constructor Init(X, Y: Integer; const TextStr: string; FontPtr: PFont);
    procedure SetText(const NewText: string);
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    destructor Done; virtual;
  end;

  PLabel = ^TLabel;

  { Interactive button with 3D panel }
  TButton = object(TWidget)
    Text: PShortString;
    Font: PFont;
    Pressed: Boolean;  { Visual state for rendering }

    constructor Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont);
    procedure SetText(const NewText: string);
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    destructor Done; virtual;
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

    constructor Init(X, Y: Integer; const TextStr: string; FontPtr: PFont;
                   CheckboxImage: PImage; ImgW, ImgH: Word);
    procedure SetText(const NewText: string);
    procedure SetChecked(Value: Boolean);
    function IsChecked: Boolean;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    destructor Done; virtual;
  end;

  PCheckbox = ^TCheckbox;

  { Interactive text input field }
  TLineEdit = object(TWidget)
    Text: PShortString;
    Font: PFont;
    MaxLength: Byte;
    CursorVisible: Boolean;
    CursorTimer: Real;

    constructor Init(X, Y: Integer; W, H: Word; FontPtr: PFont; MaxLen: Byte);
    procedure SetText(const NewText: string);
    function GetText: string;
    procedure Clear;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    procedure Update(DeltaTime: Real);
    destructor Done; virtual;
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

constructor TUIStyle.Init(High, Normal, Low, Focus: Byte);
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
    DrawHLine(R.X, R.Y, R.Width, LowColor, FrameBuffer);                      { Top }
    DrawVLine(R.X, R.Y, R.Height, LowColor, FrameBuffer);                     { Left }
    DrawVLine(R.X + R.Width - 1, R.Y, R.Height, HighColor, FrameBuffer);      { Right }
    DrawHLine(R.X, R.Y + R.Height - 1, R.Width, HighColor, FrameBuffer);      { Bottom }
  end
  else
  begin
    { Raised: light top-left, dark bottom-right }
    DrawHLine(R.X, R.Y, R.Width, HighColor, FrameBuffer);                     { Top }
    DrawVLine(R.X, R.Y, R.Height, HighColor, FrameBuffer);                    { Left }
    DrawVLine(R.X + R.Width - 1, R.Y, R.Height, LowColor, FrameBuffer);       { Right }
    DrawHLine(R.X, R.Y + R.Height - 1, R.Width, LowColor, FrameBuffer);       { Bottom }
  end;
end;

{ ========================================================================== }
{ TWidget Base Implementation                                                }
{ ========================================================================== }

constructor TWidget.Init(X, Y: Integer; W, H: Word);
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

procedure TWidget.Render(FrameBuffer: PFrameBuffer; Style: PUIStyle);
begin
  { Abstract - must be overridden }
end;

destructor TWidget.Done;
begin
  { Base cleanup - override in subclasses }
end;

{ ========================================================================== }
{ TLabel Implementation                                                      }
{ ========================================================================== }

constructor TLabel.Init(X, Y: Integer; const TextStr: string; FontPtr: PFont);
begin
  { Initialize base widget }
  inherited Init(X, Y, GetTextWidth(TextStr, FontPtr^), FontPtr^.Height);
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

procedure TLabel.Render(FrameBuffer: PFrameBuffer; Style: PUIStyle);
begin
  if not Visible then Exit;
  PrintFontText(Rectangle.X, Rectangle.Y, Text^, Font^, FrameBuffer);
end;

destructor TLabel.Done;
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

constructor TButton.Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont);
begin
  inherited Init(X, Y, W, H);

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

procedure TButton.Render(FrameBuffer: PFrameBuffer; Style: PUIStyle);
var
  TextWidth: Integer;
  TextX, TextY: Integer;
  FocusRect: TRectangle;
begin
  if not Visible then Exit;

  { Render background }
  DrawFillRect(Rectangle, Style^.NormalColor, FrameBuffer);

  { Render 3D panel border using shared style instance }
  Style^.RenderPanel(Rectangle, Pressed, FrameBuffer);

  { Render centered text }
  if (Text <> nil) and (Font <> nil) then
  begin
    TextWidth := GetTextWidth(Text^, Font^);
    TextX := Rectangle.X + (Rectangle.Width - TextWidth) div 2;
    TextY := Rectangle.Y + (Rectangle.Height - Font^.Height) div 2;
    PrintFontText(TextX, TextY, Text^, Font^, FrameBuffer);
  end;

  { Render focus border if focused }
  if Focused then
  begin
    FocusRect.X := Rectangle.X - 1;
    FocusRect.Y := Rectangle.Y - 1;
    FocusRect.Width := Rectangle.Width + 2;
    FocusRect.Height := Rectangle.Height + 2;
    DrawRect(FocusRect, Style^.FocusColor, FrameBuffer);
  end;
end;

destructor TButton.Done;
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

constructor TCheckbox.Init(X, Y: Integer; const TextStr: string; FontPtr: PFont;
                         CheckboxImage: PImage; ImgW, ImgH: Word);
var
  TextWidth: Integer;
begin
  { Calculate total width: image + gap + text }
  TextWidth := GetTextWidth(TextStr, FontPtr^);
  inherited Init(X, Y, ImgW + 4 + TextWidth, ImgH);

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

procedure TCheckbox.Render(FrameBuffer: PFrameBuffer; Style: PUIStyle);
var
  SrcRect: TRectangle;
  TextX, TextY: Integer;
  FocusRect: TRectangle;
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

  { Render text vertically centered }
  TextX := Rectangle.X + ImageWidth + 4;
  TextY := Rectangle.Y + (Rectangle.Height - Font^.Height) div 2;
  PrintFontText(TextX, TextY, Text^, Font^, FrameBuffer);

  { Render focus border if focused }
  if Focused then
  begin
    FocusRect.X := Rectangle.X - 1;
    FocusRect.Y := Rectangle.Y - 1;
    FocusRect.Width := Rectangle.Width + 2;
    FocusRect.Height := Rectangle.Height + 2;
    DrawRect(FocusRect, Style^.FocusColor, FrameBuffer);
  end;
end;

destructor TCheckbox.Done;
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

constructor TLineEdit.Init(X, Y: Integer; W, H: Word; FontPtr: PFont; MaxLen: Byte);
begin
  inherited Init(X, Y, W, H);

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

{ Helper: Convert scancode to ASCII character using KEYBOARD.PAS character maps }
function ScancodeToChar(Scancode: Byte): Char;
var
  ShiftPressed: Boolean;
begin
  { Check if either shift key is pressed }
  ShiftPressed := IsKeyDown(Key_LShift) or IsKeyDown(Key_RShift);

  { Use character map from KEYBOARD.PAS }
  if Scancode <= 127 then
  begin
    if ShiftPressed then
      ScancodeToChar := CharMapShift[Scancode]
    else
      ScancodeToChar := CharMapNormal[Scancode];
  end
  else
    ScancodeToChar := #0;  { Invalid scancode }
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
      Ch := ScancodeToChar(Event.KeyCode);
      if (Ch <> #0) and (Length(Text^) < MaxLength) then
      begin
        Text^ := Text^ + Ch;
        Event.Handled := True;
      end;
    end;
  end;
end;

procedure TLineEdit.Render(FrameBuffer: PFrameBuffer; Style: PUIStyle);
var
  TextX, TextY: Integer;
  DisplayText: string;
  TextWidth: Integer;
  AvailableWidth: Integer;
  CursorX: Integer;
  FocusRect: TRectangle;
begin
  if not Visible then Exit;

  { Render background }
  DrawFillRect(Rectangle, Style^.LowColor, FrameBuffer);

  { Render sunken 3D panel border using shared style instance (text input fields are sunken) }
  Style^.RenderPanel(Rectangle, True, FrameBuffer);

  { Safety check }
  if (Text = nil) or (Font = nil) then Exit;

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
    DrawVLine(CursorX, TextY, Font^.Height, Style^.FocusColor, FrameBuffer);
  end;

  { Render focus border if focused }
  if Focused then
  begin
    FocusRect.X := Rectangle.X - 1;
    FocusRect.Y := Rectangle.Y - 1;
    FocusRect.Width := Rectangle.Width + 2;
    FocusRect.Height := Rectangle.Height + 2;
    DrawRect(FocusRect, Style^.FocusColor, FrameBuffer);
  end;
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

destructor TLineEdit.Done;
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

  { Initialize default style with VMT }
  { Calling constructor on instance variable initializes VMT + fields }
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
  ListRemoveByValue(Widgets, Widget);
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
  Node: PListEntry;
  Found: Boolean;
  FirstEnabled: PWidget;
begin
  if Widgets.First = nil then Exit;

  Found := False;
  FirstEnabled := nil;
  Node := Widgets.First;

  { Find first enabled widget (for wrap-around) }
  while Node <> nil do
  begin
    if PWidget(Node^.Value)^.Enabled then
    begin
      if FirstEnabled = nil then
        FirstEnabled := PWidget(Node^.Value);
      Break;
    end;
    Node := Node^.Next;
  end;

  { Find current focused widget and move to next }
  Node := Widgets.First;
  while Node <> nil do
  begin
    if Found and PWidget(Node^.Value)^.Enabled then
    begin
      SetFocus(PWidget(Node^.Value));
      Exit;
    end;

    if PWidget(Node^.Value) = FocusedWidget then
      Found := True;

    Node := Node^.Next;
  end;

  { Wrap around to first enabled widget }
  if FirstEnabled <> nil then
    SetFocus(FirstEnabled);
end;

procedure TUIManager.FocusPrev;
var
  Node: PListEntry;
  PrevWidget: PWidget;
  LastEnabled: PWidget;
begin
  if Widgets.First = nil then Exit;

  PrevWidget := nil;
  LastEnabled := nil;

  { Find last enabled widget (for wrap-around) }
  Node := Widgets.First;
  while Node <> nil do
  begin
    if PWidget(Node^.Value)^.Enabled then
      LastEnabled := PWidget(Node^.Value);
    Node := Node^.Next;
  end;

  { Find current focused widget and move to previous }
  Node := Widgets.First;
  while Node <> nil do
  begin
    if PWidget(Node^.Value) = FocusedWidget then
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

    if PWidget(Node^.Value)^.Enabled then
      PrevWidget := PWidget(Node^.Value);

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
  Node: PListEntry;
  Widget: PWidget;
begin
  Node := Widgets.First;
  while Node <> nil do
  begin
    Widget := PWidget(Node^.Value);
    if Widget^.Visible then
      Widget^.Render(Self.BackBuffer, @Self.Style);
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
