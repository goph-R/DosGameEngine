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

uses VGA, VGAFont, GenTypes, LinkList, Keyboard, DRect;

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
    NeedsRedraw: Boolean;   { Widget needs rendering (dirty flag) }
    EventHandler: Pointer;  { TEventHandler - defined below }
    Tag: Integer;

    constructor Init(X, Y: Integer; W, H: Word);
    procedure SetEventHandler(Handler: Pointer);
    procedure MarkDirty;    { Request redraw of this widget }
    procedure SetVisible(Value: Boolean);  { Set visibility and mark dirty if changed }
    procedure SetEnabled(Value: Boolean);  { Set enabled state and mark dirty if changed }
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Update(DeltaTime: LongInt); virtual;
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
    CursorTimer: LongInt;  { Milliseconds }

    constructor Init(X, Y: Integer; W, H: Word; FontPtr: PFont; MaxLen: Byte);
    procedure SetText(const NewText: string);
    function GetText: string;
    procedure Clear;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    procedure Update(DeltaTime: LongInt); virtual;
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
    BackgroundBuffer: PFrameBuffer;  { Static background for restoring dirty regions }
    FirstRender: Boolean;            { Force full redraw on first frame }
    Style: TUIStyle;

    procedure Init(FrameBuffer, Background: PFrameBuffer);
    procedure AddWidget(Widget: PWidget);
    procedure RemoveWidget(Widget: PWidget);
    procedure SetFocus(Widget: PWidget);
    procedure FocusNext;
    procedure FocusPrev;
    procedure FocusInDirection(DX, DY: Integer);  { Focus closest widget in direction }
    procedure DispatchKeyboardEvents;  { Check all keyboard keys and dispatch events }
    procedure HandleEvent(var Event: TEvent);
    procedure Update(DeltaTime: LongInt);  { Update all widgets (DeltaTime in milliseconds) }
    procedure RenderAll;
    procedure RenderDirty;           { Smart dirty rectangle rendering }
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
  NeedsRedraw := True;  { New widgets always need initial draw }
  EventHandler := nil;
  Tag := 0;
end;

procedure TWidget.SetEventHandler(Handler: Pointer);
begin
  EventHandler := Handler;
end;

procedure TWidget.MarkDirty;
begin
  NeedsRedraw := True;
end;

procedure TWidget.SetVisible(Value: Boolean);
begin
  if Visible <> Value then
  begin
    Visible := Value;
    MarkDirty;  { Visibility changed, need redraw }
  end;
end;

procedure TWidget.SetEnabled(Value: Boolean);
begin
  if Enabled <> Value then
  begin
    Enabled := Value;
    MarkDirty;  { Enabled state affects appearance }
  end;
end;

procedure TWidget.HandleEvent(var Event: TEvent);
begin
  { Default implementation: call event handler if set }
  if EventHandler <> nil then
    TEventHandler(EventHandler)(Self, Event);
end;

procedure TWidget.Update(DeltaTime: LongInt);
begin
  { Base implementation - override in subclasses that need updating }
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
    if Text^ <> NewText then
    begin
      Text^ := NewText;
      { Update width based on new text }
      Rectangle.Width := GetTextWidth(NewText, Font^);
      MarkDirty;  { Label text changed }
    end;
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
var
  OldPressed: Boolean;
begin
  if Event.EventType = Event_KeyPress then
  begin
    { Enter or Space triggers the button }
    if (Event.KeyCode = $1C) or (Event.KeyCode = $39) then  { Enter=$1C, Space=$39 }
    begin
      OldPressed := Pressed;
      Pressed := True;
      if Pressed <> OldPressed then
        MarkDirty;  { Visual state changed }

      Event.Handled := True;
      if EventHandler <> nil then
        TEventHandler(EventHandler)(Self, Event);
    end;
  end
  else if Event.EventType = Event_FocusGain then
  begin
    Focused := True;
    MarkDirty;  { Focus border needs redraw }
  end
  else if Event.EventType = Event_FocusLost then
  begin
    Focused := False;
    Pressed := False;  { Release button when losing focus }
    MarkDirty;  { Focus border removal needs redraw }
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
  if Checked <> Value then
  begin
    Checked := Value;
    MarkDirty;  { Programmatic state change }
  end;
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
      MarkDirty;  { Checkbox state changed }
      Event.Handled := True;
      if EventHandler <> nil then
        TEventHandler(EventHandler)(Self, Event);
    end;
  end
  else if Event.EventType = Event_FocusGain then
  begin
    Focused := True;
    MarkDirty;
  end
  else if Event.EventType = Event_FocusLost then
  begin
    Focused := False;
    MarkDirty;
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
var
  OldText: string;
begin
  if Text <> nil then
  begin
    OldText := Text^;
    if Length(NewText) <= MaxLength then
      Text^ := NewText
    else
      Text^ := Copy(NewText, 1, MaxLength);
    if Text^ <> OldText then
      MarkDirty;  { Text changed }
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
  OldText: string;
begin
  if Event.EventType = Event_KeyPress then
  begin
    OldText := Text^;

    { Backspace }
    if Event.KeyCode = $0E then  { Backspace=$0E }
    begin
      if Length(Text^) > 0 then
      begin
        Delete(Text^, Length(Text^), 1);
        if Text^ <> OldText then
          MarkDirty;  { Text changed }
      end;
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
        if Text^ <> OldText then
          MarkDirty;  { Text changed }
        Event.Handled := True;
      end;
    end;
  end
  else if Event.EventType = Event_FocusGain then
  begin
    Focused := True;
    MarkDirty;
  end
  else if Event.EventType = Event_FocusLost then
  begin
    Focused := False;
    MarkDirty;
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

procedure TLineEdit.Update(DeltaTime: LongInt);
var
  OldCursorVisible: Boolean;
begin
  { Cursor blink animation - DeltaTime in milliseconds }
  OldCursorVisible := CursorVisible;
  CursorTimer := CursorTimer + DeltaTime;
  if CursorTimer >= 500 then
  begin
    CursorTimer := 0;
    CursorVisible := not CursorVisible;
    if Focused and (CursorVisible <> OldCursorVisible) then
      MarkDirty;  { Cursor visibility changed }
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

procedure TUIManager.Init(FrameBuffer, Background: PFrameBuffer);
begin
  ListInit(Widgets);
  FocusedWidget := nil;
  BackBuffer := FrameBuffer;
  BackgroundBuffer := Background;
  FirstRender := True;

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

procedure TUIManager.FocusInDirection(DX, DY: Integer);
{ Focuses the closest widget in the given direction (DX, DY) }
{ DX: -1=left, 1=right, DY: -1=up, 1=down }
var
  Node: PListEntry;
  Widget: PWidget;
  BestWidget: PWidget;
  BestDistance: LongInt;
  Distance: LongInt;
  CenterX, CenterY: Integer;
  TargetCenterX, TargetCenterY: Integer;
  DeltaX, DeltaY: Integer;
  InDirection: Boolean;
begin
  if FocusedWidget = nil then Exit;
  if Widgets.First = nil then Exit;

  { Calculate center of currently focused widget }
  CenterX := FocusedWidget^.Rectangle.X + Integer(FocusedWidget^.Rectangle.Width) div 2;
  CenterY := FocusedWidget^.Rectangle.Y + Integer(FocusedWidget^.Rectangle.Height) div 2;

  BestWidget := nil;
  BestDistance := 2147483647;  { MaxLongInt }

  { Find closest widget in the specified direction }
  Node := Widgets.First;
  while Node <> nil do
  begin
    Widget := PWidget(Node^.Value);

    { Skip current widget and disabled widgets }
    if (Widget <> FocusedWidget) and Widget^.Enabled then
    begin
      { Calculate center of candidate widget }
      TargetCenterX := Widget^.Rectangle.X + Integer(Widget^.Rectangle.Width) div 2;
      TargetCenterY := Widget^.Rectangle.Y + Integer(Widget^.Rectangle.Height) div 2;

      { Calculate delta }
      DeltaX := TargetCenterX - CenterX;
      DeltaY := TargetCenterY - CenterY;

      { Check if widget is in the requested direction }
      InDirection := False;
      if DX <> 0 then
      begin
        { Horizontal movement: check if target is in correct X direction }
        if (DX > 0) and (DeltaX > 0) then InDirection := True
        else if (DX < 0) and (DeltaX < 0) then InDirection := True;
      end;
      if DY <> 0 then
      begin
        { Vertical movement: check if target is in correct Y direction }
        if (DY > 0) and (DeltaY > 0) then InDirection := True
        else if (DY < 0) and (DeltaY < 0) then InDirection := True;
      end;

      if InDirection then
      begin
        { Calculate Manhattan distance (abs(dx) + abs(dy)) }
        if DeltaX < 0 then Distance := -DeltaX else Distance := DeltaX;
        if DeltaY < 0 then Distance := Distance - DeltaY else Distance := Distance + DeltaY;

        { Keep closest widget }
        if Distance < BestDistance then
        begin
          BestDistance := Distance;
          BestWidget := Widget;
        end;
      end;
    end;

    Node := Node^.Next;
  end;

  { Focus the best widget found }
  if BestWidget <> nil then
    SetFocus(BestWidget);
end;

procedure TUIManager.HandleEvent(var Event: TEvent);
begin
  { Let the focused widget handle the event first }
  if FocusedWidget <> nil then
    FocusedWidget^.HandleEvent(Event);

  { If the event was not handled and it's a cursor key, do directional focus }
  if (not Event.Handled) and (Event.EventType = Event_KeyPress) then
  begin
    case Event.KeyCode of
      Key_Up:    FocusInDirection(0, -1);
      Key_Down:  FocusInDirection(0, 1);
      Key_Left:  FocusInDirection(-1, 0);
      Key_Right: FocusInDirection(1, 0);
    end;
  end;
end;

procedure TUIManager.DispatchKeyboardEvents;
{ Checks all keyboard keys and dispatches events to the UI system }
var
  Event: TEvent;
  ScanCode: Byte;
begin
  { Check all scan codes from 1 to 127 }
  for ScanCode := 1 to 127 do
  begin
    if IsKeyPressed(ScanCode) then
    begin
      Event.EventType := Event_KeyPress;
      Event.KeyCode := ScanCode;
      Event.Handled := False;
      HandleEvent(Event);
    end;
  end;
end;

procedure TUIManager.Update(DeltaTime: LongInt);
{ Update all widgets (for animations, timers, etc.) }
{ DeltaTime is in milliseconds }
var
  Node: PListEntry;
  Widget: PWidget;
begin
  Node := Widgets.First;
  while Node <> nil do
  begin
    Widget := PWidget(Node^.Value);
    Widget^.Update(DeltaTime);
    Node := Node^.Next;
  end;
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

{ Helper: Expand rectangle by 1px for focus border, clamp to screen }
procedure ExpandRectForFocusBorder(const R: TRectangle; IsFocused: Boolean; var Result: TRectangle);
begin
  if IsFocused then
  begin
    { Expand by 1px in all directions }
    Result.X := R.X - 1;
    Result.Y := R.Y - 1;
    Result.Width := R.Width + 2;
    Result.Height := R.Height + 2;

    { Clamp to screen bounds (0-319, 0-199) }
    if Result.X < 0 then
    begin
      Result.Width := Result.Width + Result.X;
      Result.X := 0;
    end;
    if Result.Y < 0 then
    begin
      Result.Height := Result.Height + Result.Y;
      Result.Y := 0;
    end;
    if Result.X + Integer(Result.Width) > 320 then
      Result.Width := 320 - Result.X;
    if Result.Y + Integer(Result.Height) > 200 then
      Result.Height := 200 - Result.Y;
  end
  else
    Result := R;  { No expansion needed }
end;

procedure TUIManager.RenderDirty;
var
  Node: PListEntry;
  Widget: PWidget;
  DirtyRect: TRectangle;
  HasDirtyWidgets: Boolean;
begin
  { Step 1: Check if any widgets are dirty }
  HasDirtyWidgets := FirstRender;
  if not FirstRender then
  begin
    Node := Widgets.First;
    while Node <> nil do
    begin
      Widget := PWidget(Node^.Value);
      if Widget^.Visible and Widget^.NeedsRedraw then
      begin
        HasDirtyWidgets := True;
        Break;
      end;
      Node := Node^.Next;
    end;
  end;

  { If nothing is dirty, skip rendering entirely }
  if not HasDirtyWidgets then
    Exit;

  { Step 3: Render dirty widgets to backbuffer }
  if FirstRender then
  begin
    { First frame: render all widgets }
    Node := Widgets.First;
    while Node <> nil do
    begin
      Widget := PWidget(Node^.Value);
      if Widget^.Visible then
      begin
        Widget^.Render(Self.BackBuffer, @Self.Style);
        ExpandRectForFocusBorder(Widget^.Rectangle, Widget^.Focused, DirtyRect);
        AddDirtyRect(DirtyRect);
      end;
      Node := Node^.Next;
    end;
    FirstRender := False;
  end
  else
  begin
    { Subsequent frames: only render dirty widgets }
    Node := Widgets.First;
    while Node <> nil do
    begin
      Widget := PWidget(Node^.Value);
      if Widget^.Visible then
      begin
        if Widget^.NeedsRedraw then
        begin
          { Expand rectangle to include potential focus border from previous frame }
          ExpandRectForFocusBorder(Widget^.Rectangle, True, DirtyRect);

          { Restore background for this dirty region }
          if BackgroundBuffer <> nil then
            CopyFrameBufferRect(BackgroundBuffer, DirtyRect, BackBuffer, DirtyRect.X, DirtyRect.Y);

          { Redraw this widget }
          Widget^.Render(Self.BackBuffer, @Self.Style);

          AddDirtyRect(DirtyRect);
          Widget^.NeedsRedraw := False;
        end;
      end;
      Node := Node^.Next;
    end;
  end;

  { Step 4: Flush dirty rectangles to VGA memory (slow part) }
  FlushDirtyRects(BackBuffer);
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
