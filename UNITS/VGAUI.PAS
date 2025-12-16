{ ========================================================================== }
{ VGAUI.PAS - Minimal UI System for VGA Mode 13h                             }
{                                                                            }
{ Lightweight widget-based UI framework for DOS VGA graphics.                }
{ Keyboard-driven navigation with event handling.                            }
{                                                                            }
{ Features:                                                                  }
{   - Object-oriented widget hierarchy (Label, Button, Checkbox, LineEdit)   }
{   - Event-driven model with procedure pointers                             }
{   - Focus management with keyboard navigation (Tab, arrows, Enter)         }
{   - Theming system with 3D beveled panels                                  }
{   - Dirty rectangle rendering integration                                  }
{                                                                            }
{ Dependencies: VGA, VGAFONT, KEYBOARD, LINKLIST, GENTYPES                   }
{ ========================================================================== }

unit VGAUI;

interface

uses VGA, VGAFont, GenTypes, LinkList, Keyboard, Mouse, DRect, RTCTimer, StrUtil;

{ ========================================================================== }
{ Text Alignment Constants                                                   }
{ ========================================================================== }

const
  { Horizontal alignment }
  Align_Left   = 1;
  Align_Center = 2;
  Align_Right  = 4;

  { Vertical alignment }
  Align_Top    = 8;
  Align_Middle = 16;
  Align_Bottom = 32;

{ ========================================================================== }
{ Event System                                                               }
{ ========================================================================== }

type
  TEventType = (
    Event_None,
    Event_KeyPress,    { Key was pressed }
    Event_MouseDown,   { Mouse button pressed }
    Event_MouseUp,     { Mouse button released }
    Event_MouseMove,   { Mouse moved }
    Event_FocusGain,   { Widget gained focus }
    Event_FocusLost    { Widget lost focus }
  );

  TEvent = record
    EventType: TEventType;
    KeyCode: Byte;       { Scancode from KEYBOARD.PAS }
    MouseX: Integer;     { Mouse X position }
    MouseY: Integer;     { Mouse Y position }
    MouseButton: Byte;   { Mouse button (MouseButton_Left, MouseButton_Right, etc.) }
    Handled: Boolean;    { Set to True if widget handled the event }
  end;

{ ========================================================================== }
{ UI Style and Theming                                                       }
{ ========================================================================== }

type
  { TUIStyle must be declared before TWidget since TWidget.Render uses PUIStyle }
  { RenderPanel is virtual to allow custom rendering styles }
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
    procedure Update(DeltaTime: Real); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    procedure RenderFocusRectangle(FrameBuffer: PFrameBuffer; Style: PUIStyle);
    destructor Done; virtual;
  end;

  PWidget = ^TWidget;

{$F+}  { Far call for procedure pointer compatibility }
  TEventHandler = procedure(var Widget: TWidget; var Event: TEvent);
  TUpdateProcedure = procedure;  { User update callback (no parameters) }
{$F-}

{ ========================================================================== }
{ Widget Types                                                               }
{ ========================================================================== }

type
  { Non-interactive text label }
  TLabel = object(TWidget)
    Lines: TMultiLineText;
    LineCount: Byte;
    Font: PFont;
    TextAlign: Byte;

    constructor Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont);
    procedure SetText(const NewText: string);
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    destructor Done; virtual;
  end;

  PLabel = ^TLabel;

  { Interactive button with 3D panel }
  TButton = object(TWidget)
    Lines: TMultiLineText;
    LineCount: Byte;
    Font: PFont;
    TextAlign: Byte;
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
    Lines: TMultiLineText;
    LineCount: Byte;
    Font: PFont;
    TextAlign: Byte;
    Image: PImage;
    ImageAlign: Byte;  { Vertical alignment only (Align_Top, Align_Middle, Align_Bottom) }
    Checked: Boolean;

    constructor Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont; CheckboxImage: PImage);
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
    CursorTimer: Real;  { Seconds }

    constructor Init(X, Y: Integer; W, H: Word; FontPtr: PFont; MaxLen: Byte);
    procedure SetText(const NewText: string);
    function GetText: string;
    procedure Clear;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    procedure Update(DeltaTime: Real); virtual;
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
    Style: PUIStyle;
    Running: Boolean;
    Tag: LongInt;                    { Metadata }
    LastMouseButtons: Byte;          { Previous frame's mouse button state }

    procedure Init(FrameBuffer, Background: PFrameBuffer);
    procedure AddWidget(Widget: PWidget);
    procedure RemoveWidget(Widget: PWidget);
    procedure SetFocus(Widget: PWidget);
    procedure FocusInDirection(DX, DY: Integer);  { Focus closest widget in direction }
    procedure DispatchKeyboardEvents;  { Check all keyboard keys and dispatch events }
    procedure DispatchMouseEvents;     { Check mouse state and dispatch events }
    procedure HandleEvent(var Event: TEvent);
    procedure Update(DeltaTime: Real);  { Update all widgets (DeltaTime in seconds) }
    procedure RenderAll;
    procedure RenderDirty;           { Smart dirty rectangle rendering }
    procedure SetStyle(NewStyle: PUIStyle);
    function IsEnter(var Event: TEvent): Boolean;
    procedure Run(UpdateProcedure: Pointer; VSync: Boolean);
    procedure Stop;
    procedure Done;
  end;

  PUIManager = ^TUIManager;

{ ========================================================================== }

implementation

var
  DefaultStyle: TUIStyle;  { Module-level default style }

{ ========================================================================== }
{ Alignment Helper Functions                                                 }
{ ========================================================================== }

{ Calculate aligned X position based on horizontal alignment flags }
function CalculateAlignedX(StartX, AvailableWidth, ContentWidth: Integer; Align: Byte; DefaultAlign: Byte): Integer;
begin
  if (Align and Align_Left) <> 0 then
    CalculateAlignedX := StartX
  else if (Align and Align_Center) <> 0 then
    CalculateAlignedX := StartX + (AvailableWidth - ContentWidth) div 2
  else if (Align and Align_Right) <> 0 then
    CalculateAlignedX := StartX + AvailableWidth - ContentWidth
  else
    { Use default alignment }
    CalculateAlignedX := CalculateAlignedX(StartX, AvailableWidth, ContentWidth, DefaultAlign, Align_Left);
end;

{ Calculate aligned Y position based on vertical alignment flags }
function CalculateAlignedY(StartY, AvailableHeight, ContentHeight: Integer; Align: Byte; DefaultAlign: Byte): Integer;
begin
  if (Align and Align_Top) <> 0 then
    CalculateAlignedY := StartY
  else if (Align and Align_Middle) <> 0 then
    CalculateAlignedY := StartY + (AvailableHeight - ContentHeight) div 2
  else if (Align and Align_Bottom) <> 0 then
    CalculateAlignedY := StartY + AvailableHeight - ContentHeight
  else
    { Use default alignment }
    CalculateAlignedY := CalculateAlignedY(StartY, AvailableHeight, ContentHeight, DefaultAlign, Align_Top);
end;

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
    DrawFillRect(R, LowColor, FrameBuffer);
    DrawHLine(R.X, R.Y, R.Width, LowColor, FrameBuffer);                      { Top }
    DrawVLine(R.X, R.Y, R.Height, LowColor, FrameBuffer);                     { Left }
    DrawVLine(R.X + R.Width - 1, R.Y, R.Height, HighColor, FrameBuffer);      { Right }
    DrawHLine(R.X, R.Y + R.Height - 1, R.Width, HighColor, FrameBuffer);      { Bottom }
  end
  else
  begin
    { Raised: light top-left, dark bottom-right }
    DrawFillRect(R, NormalColor, FrameBuffer);  
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

procedure TWidget.Update(DeltaTime: Real);
begin
  { Base implementation - override in subclasses that need updating }
end;

procedure TWidget.Render(FrameBuffer: PFrameBuffer; Style: PUIStyle);
begin
  { Abstract - must be overridden }
end;

procedure TWidget.RenderFocusRectangle(FrameBuffer: PFrameBuffer; Style: PUIStyle);
var
  FocusRect: TRectangle;
begin
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

destructor TWidget.Done;
begin
  { Base cleanup - override in subclasses }
end;

{ ========================================================================== }
{ TLabel Implementation                                                      }
{ ========================================================================== }

constructor TLabel.Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont);
begin
  { Initialize base widget }
  inherited Init(X, Y, W, H);
  Enabled := False;  { Labels cannot receive focus }

  { Split text into lines }
  SplitLines(TextStr, Lines, LineCount);
  Font := FontPtr;
  TextAlign := Align_Left + Align_Top;
end;

procedure TLabel.SetText(const NewText: string);
var
  i: Byte;
  MaxWidth: Integer;
  LineWidth: Integer;
begin
  SplitLines(NewText, Lines, LineCount);
  MarkDirty;
end;

procedure TLabel.Render(FrameBuffer: PFrameBuffer; Style: PUIStyle);
var
  i: Byte;
  X, Y: Integer;
  LineWidth: Integer;
  TotalHeight: Integer;
begin
  if not Visible then Exit;

  { Calculate total height of all lines }
  TotalHeight := LineCount * Font^.Height;

  { Calculate starting Y position using helper }
  Y := CalculateAlignedY(Rectangle.Y, Rectangle.Height, TotalHeight, TextAlign, Align_Top);

  { Render each line }
  for i := 0 to LineCount - 1 do
  begin
    LineWidth := GetTextWidth(Lines[i], Font^);
    X := CalculateAlignedX(Rectangle.X, Rectangle.Width, LineWidth, TextAlign, Align_Left);
    PrintFontText(X, Y, Lines[i], Font^, FrameBuffer);
    Inc(Y, Font^.Height);
  end;
end;

destructor TLabel.Done;
begin
  { No dynamic memory to free - Lines is a static array }
end;

{ ========================================================================== }
{ TButton Implementation                                                     }
{ ========================================================================== }

constructor TButton.Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont);
begin
  inherited Init(X, Y, W, H);

  { Split text into lines }
  SplitLines(TextStr, Lines, LineCount);
  Font := FontPtr;
  TextAlign := Align_Center + Align_Middle;
  Pressed := False;
end;

procedure TButton.SetText(const NewText: string);
begin
  { Split text into lines }
  SplitLines(NewText, Lines, LineCount);
  MarkDirty;  { Text changed }
end;

procedure TButton.HandleEvent(var Event: TEvent);
var
  OldPressed: Boolean;
  InBounds: Boolean;
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
  else if Event.EventType = Event_MouseDown then
  begin
    { Check if mouse click is within button bounds }
    InBounds := (Event.MouseX >= Rectangle.X) and
                (Event.MouseX < Rectangle.X + Rectangle.Width) and
                (Event.MouseY >= Rectangle.Y) and
                (Event.MouseY < Rectangle.Y + Rectangle.Height);

    if InBounds and Enabled then
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
  else if Event.EventType = Event_FocusLost then
  begin
    Pressed := False;
  end;
end;

procedure TButton.Render(FrameBuffer: PFrameBuffer; Style: PUIStyle);
var
  i: Byte;
  LineWidth: Integer;
  TextX, TextY: Integer;
  TotalHeight: Integer;
begin
  if not Visible then Exit;

  { Render 3D panel border using shared style instance }
  Style^.RenderPanel(Rectangle, Pressed, FrameBuffer);

  { Render text (all lines) with alignment }
  if (LineCount > 0) and (Font <> nil) then
  begin
    { Calculate total height of all lines }
    TotalHeight := LineCount * Font^.Height;

    { Calculate starting Y position using helper (default to middle) }
    TextY := CalculateAlignedY(Rectangle.Y, Rectangle.Height, TotalHeight, TextAlign, Align_Middle);

    { Render each line }
    for i := 0 to LineCount - 1 do
    begin
      LineWidth := GetTextWidth(Lines[i], Font^);
      TextX := CalculateAlignedX(Rectangle.X, Rectangle.Width, LineWidth, TextAlign, Align_Center);
      PrintFontText(TextX, TextY, Lines[i], Font^, FrameBuffer);
      Inc(TextY, Font^.Height);
    end;
  end;

  RenderFocusRectangle(FrameBuffer, Style);
end;

destructor TButton.Done;
begin
  { No dynamic memory to free - Lines is a static array }
end;

{ ========================================================================== }
{ TCheckbox Implementation                                                   }
{ ========================================================================== }

constructor TCheckbox.Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont; CheckboxImage: PImage);
begin
  inherited Init(X, Y, W, H);

  Image := CheckboxImage;

  { Split text into lines }
  SplitLines(TextStr, Lines, LineCount);
  Font := FontPtr;
  TextAlign := Align_Left + Align_Middle;
  ImageAlign := Align_Middle;
  Checked := False;
end;

procedure TCheckbox.SetText(const NewText: string);
begin
  { Split text into lines }
  SplitLines(NewText, Lines, LineCount);
  MarkDirty;  { Text changed }
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
var
  InBounds: Boolean;
begin
  if Event.EventType = Event_KeyPress then
  begin
    { Space toggles checkbox }
    if (Event.KeyCode = $1C) or (Event.KeyCode = $39) then  { Enter=$1C, Space=$39 }
    begin
      Checked := not Checked;
      MarkDirty;  { Checkbox state changed }
      Event.Handled := True;
      if EventHandler <> nil then
        TEventHandler(EventHandler)(Self, Event);
    end;
  end
  else if Event.EventType = Event_MouseDown then
  begin
    { Check if mouse click is within checkbox bounds }
    InBounds := (Event.MouseX >= Rectangle.X) and
                (Event.MouseX < Rectangle.X + Rectangle.Width) and
                (Event.MouseY >= Rectangle.Y) and
                (Event.MouseY < Rectangle.Y + Rectangle.Height);

    if InBounds and Enabled then
    begin
      Checked := not Checked;
      MarkDirty;  { Checkbox state changed }
      Event.Handled := True;
      if EventHandler <> nil then
        TEventHandler(EventHandler)(Self, Event);
    end;
  end;
end;

procedure TCheckbox.Render(FrameBuffer: PFrameBuffer; Style: PUIStyle);
var
  i: Byte;
  SrcRect: TRectangle;
  ImageX, ImageY: Integer;
  TextX, TextY: Integer;
  ImageHeight: Word;
  TextTotalHeight: Integer;
  TextAreaX: Integer;
  TextAreaWidth: Integer;
  LineWidth: Integer;
begin
  if not Visible then Exit;

  ImageHeight := Image^.Height shr 1;

  { Calculate checkbox image Y position using helper (vertical only, default to middle) }
  ImageY := CalculateAlignedY(Rectangle.Y, Rectangle.Height, ImageHeight, ImageAlign, Align_Middle);

  { Render checkbox image (row 0=unchecked, row 1=checked) }
  SrcRect.X := 0;
  if Checked then
    SrcRect.Y := ImageHeight
  else
    SrcRect.Y := 0;
  SrcRect.Width := Image^.Width;
  SrcRect.Height := ImageHeight;

  ImageX := Rectangle.X;
  PutImageRect(Image^, SrcRect, ImageX, ImageY, True, FrameBuffer);

  { Calculate text area (subtract checkbox image width from available space) }
  TextAreaX := Rectangle.X + Image^.Width + 4;
  TextAreaWidth := Integer(Rectangle.Width) - Image^.Width - 4;

  { Render text (all lines) with alignment }
  if LineCount > 0 then
  begin
    { Calculate total height of all lines }
    TextTotalHeight := LineCount * Font^.Height;

    { Calculate starting Y position using helper (default to top) }
    TextY := CalculateAlignedY(Rectangle.Y, Rectangle.Height, TextTotalHeight, TextAlign, Align_Top);

    { Render each line }
    for i := 0 to LineCount - 1 do
    begin
      LineWidth := GetTextWidth(Lines[i], Font^);
      TextX := CalculateAlignedX(TextAreaX, TextAreaWidth, LineWidth, TextAlign, Align_Left);
      PrintFontText(TextX, TextY, Lines[i], Font^, FrameBuffer);
      Inc(TextY, Font^.Height);
    end;
  end;

  RenderFocusRectangle(FrameBuffer, Style);
end;

destructor TCheckbox.Done;
begin
  { No dynamic memory to free - Lines is a static array }
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
  InBounds: Boolean;
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
  else if Event.EventType = Event_MouseDown then
  begin
    { Check if mouse click is within lineedit bounds }
    InBounds := (Event.MouseX >= Rectangle.X) and
                (Event.MouseX < Rectangle.X + Rectangle.Width) and
                (Event.MouseY >= Rectangle.Y) and
                (Event.MouseY < Rectangle.Y + Rectangle.Height);

    if InBounds and Enabled then
    begin
      { Mouse click just gives focus, doesn't trigger handler }
      Event.Handled := True;
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
begin
  if not Visible then Exit;

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
    DrawVLine(CursorX, TextY, Font^.Height, Style^.HighColor, FrameBuffer);
  end;

  RenderFocusRectangle(FrameBuffer, Style);
end;

procedure TLineEdit.Update(DeltaTime: Real);
var
  OldCursorVisible: Boolean;
begin
  { Cursor blink animation - DeltaTime in seconds }
  OldCursorVisible := CursorVisible;
  CursorTimer := CursorTimer + DeltaTime;
  if CursorTimer >= 0.5 then
  begin
    CursorTimer := 0.0;
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
  LastMouseButtons := 0;

  { Point to default style (user can override with SetStyle) }
  Style := @DefaultStyle;
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

    FocusedWidget^.Focused := False;
    FocusedWidget^.MarkDirty;
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

    Widget^.Focused := True;
    Widget^.MarkDirty;
    Widget^.HandleEvent(NewEvent);
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
var
  Node: PListEntry;
  Widget: PWidget;
  InBounds: Boolean;
begin
  { For mouse events, find the widget under the cursor and give it focus }
  if Event.EventType = Event_MouseDown then
  begin
    Node := Widgets.First;
    while Node <> nil do
    begin
      Widget := PWidget(Node^.Value);
      if Widget^.Visible and Widget^.Enabled then
      begin
        InBounds := (Event.MouseX >= Widget^.Rectangle.X) and
                    (Event.MouseX < Widget^.Rectangle.X + Widget^.Rectangle.Width) and
                    (Event.MouseY >= Widget^.Rectangle.Y) and
                    (Event.MouseY < Widget^.Rectangle.Y + Widget^.Rectangle.Height);

        if InBounds then
        begin
          SetFocus(Widget);
          Widget^.HandleEvent(Event);
          Exit;  { Event handled by this widget }
        end;
      end;
      Node := Node^.Next;
    end;
  end
  else
  begin
    { Let the focused widget handle keyboard events }
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

procedure TUIManager.DispatchMouseEvents;
{ Checks mouse state and dispatches events to the UI system }
var
  Event: TEvent;
  Buttons: Byte;
begin
  { Update mouse state from INT 33h driver }
  UpdateMouse;

  Event.MouseX := GetMouseX;
  Event.MouseY := GetMouseY;
  Buttons := GetMouseButtons;
  Event.Handled := False;

  { Detect button press transitions (0 -> non-zero) }
  if (Buttons <> 0) and (LastMouseButtons = 0) then
  begin
    Event.EventType := Event_MouseDown;
    Event.MouseButton := Buttons;
    HandleEvent(Event);
  end;

  { Detect button release transitions (non-zero -> 0) }
  if (Buttons = 0) and (LastMouseButtons <> 0) then
  begin
    Event.EventType := Event_MouseUp;
    Event.MouseButton := LastMouseButtons;
    HandleEvent(Event);
  end;

  { Store current state for next frame }
  LastMouseButtons := Buttons;
end;

procedure TUIManager.Update(DeltaTime: Real);
{ Update all widgets (for animations, timers, etc.) }
{ DeltaTime is in seconds }
var
  Node: PListEntry;
  Widget: PWidget;
begin
  { Dispatch all keyboard and mouse events to UI system }
  DispatchKeyboardEvents;
  DispatchMouseEvents;

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
  { Hide mouse cursor during rendering to prevent glitches }
  HideMouse;

  Node := Widgets.First;
  while Node <> nil do
  begin
    Widget := PWidget(Node^.Value);
    if Widget^.Visible then
      Widget^.Render(Self.BackBuffer, Self.Style);
    Node := Node^.Next;
  end;

  { Show mouse cursor after rendering }
  ShowMouse;
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

  { Hide mouse cursor during rendering to prevent glitches }
  HideMouse;

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
        Widget^.Render(Self.BackBuffer, Self.Style);
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
          Widget^.Render(Self.BackBuffer, Self.Style);

          AddDirtyRect(DirtyRect);
          Widget^.NeedsRedraw := False;
        end;
      end;
      Node := Node^.Next;
    end;
  end;

  { Step 4: Flush dirty rectangles to VGA memory (slow part) }
  FlushDirtyRects(BackBuffer);

  { Show mouse cursor after rendering }
  ShowMouse;
end;

procedure TUIManager.SetStyle(NewStyle: PUIStyle);
begin
  Style := NewStyle;
end;

procedure TUIManager.Run(UpdateProcedure: Pointer; VSync: Boolean);
var
  CurrentTime, LastTime: Real;
  DeltaTime: Real;
begin
  Running := True;
  LastTime := GetTimeSeconds;
  while Running do
  begin
    CurrentTime := GetTimeSeconds;
    DeltaTime := CurrentTime - LastTime;
    LastTime := CurrentTime;

    { Call user update procedure if provided }
    if UpdateProcedure <> nil then
      TUpdateProcedure(UpdateProcedure);

    Update(DeltaTime);
    RenderDirty;

    if VSync then
      WaitForVSync;

    ClearKeyPressed;
  end;
end;

procedure TUIManager.Stop;
begin
  Running := False;
end;

function TUIManager.IsEnter(var Event: TEvent): Boolean;
begin
  IsEnter := (Event.EventType = Event_KeyPress) and (Event.KeyCode = Key_Enter);
end;

procedure TUIManager.Done;
begin
  ListFree(Widgets);
  FocusedWidget := nil;
end;

begin
  { Initialize default style }
  DefaultStyle.Init(15, 7, 8, 14);  { white, gray, dark gray, yellow }
end.
