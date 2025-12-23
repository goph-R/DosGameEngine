# VGAUI - VGA UI System

Widget-based UI framework for VGA Mode 13h with keyboard and mouse support, using Delphi-style event handlers.

## Types

```pascal
type
  { Event handler procedure types }
  {$F+}
  TKeyPressEvent = procedure(Sender: PWidget; KeyCode: Byte);
  TMouseEvent = procedure(Sender: PWidget; X, Y: Integer; Button: Byte);
  TFocusEvent = procedure(Sender: PWidget);
  TUpdateProcedure = procedure;
  {$F-}

  TUIStyle = object
    HighColor, NormalColor, LowColor, FocusColor: Byte;
    constructor Init(High, Normal, Low, Focus: Byte);
    procedure RenderPanel(const R: TRectangle; Pressed: Boolean; FrameBuffer: PFrameBuffer); virtual;
  end;

  TWidget = object  { Base class }
    Rectangle: TRectangle;
    Visible, Enabled, Focused, NeedsRedraw: Boolean;
    Tag: Integer;
    WidgetType: TWidgetType;

    { Delphi-style event callbacks }
    OnKeyPress: Pointer;   { TKeyPressEvent }
    OnMouseDown: Pointer;  { TMouseEvent }
    OnMouseUp: Pointer;    { TMouseEvent }
    OnMouseMove: Pointer;  { TMouseEvent }
    OnFocus: Pointer;      { TFocusEvent }
    OnBlur: Pointer;       { TFocusEvent }

    constructor Init(X, Y: Integer; W, H: Word);
    procedure MarkDirty;
    procedure SetVisible(Value: Boolean);
    procedure SetEnabled(Value: Boolean);

    { Event trigger methods - override to intercept events }
    procedure DoKeyPress(KeyCode: Byte); virtual;
    procedure DoMouseDown(X, Y: Integer; Button: Byte); virtual;
    procedure DoMouseUp(X, Y: Integer; Button: Byte); virtual;
    procedure DoMouseMove(X, Y: Integer; Button: Byte); virtual;
    procedure DoFocus; virtual;
    procedure DoBlur; virtual;

    procedure Update(DeltaTime: Real); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    destructor Done; virtual;
  end;

  TLabel = object(TWidget)
    Text: PShortString;
    Lines: TMultiLineText;
    LineCount: Byte;
    Font: PFont;
    TextAlign: Byte;

    constructor Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont);
    procedure SetText(const NewText: string);
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    destructor Done; virtual;
  end;

  TButton = object(TWidget)
    Text: PShortString;
    Lines: TMultiLineText;
    LineCount: Byte;
    Font: PFont;
    TextAlign: Byte;
    Pressed: Boolean;

    constructor Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont);
    procedure SetText(const NewText: string);
    procedure DoKeyPress(KeyCode: Byte); virtual;
    procedure DoMouseDown(X, Y: Integer; Button: Byte); virtual;
    procedure DoBlur; virtual;
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    destructor Done; virtual;
  end;

  TCheckbox = object(TWidget)
    Text: PShortString;
    Lines: TMultiLineText;
    LineCount: Byte;
    Font: PFont;
    Image: PImage;
    ImageAlign: Byte;
    Checked: Boolean;

    constructor Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont; CheckboxImage: PImage);
    procedure SetText(const NewText: string);
    procedure SetChecked(Value: Boolean);
    function IsChecked: Boolean;
    procedure DoKeyPress(KeyCode: Byte); virtual;
    procedure DoMouseDown(X, Y: Integer; Button: Byte); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    destructor Done; virtual;
  end;

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
    procedure DoKeyPress(KeyCode: Byte); virtual;
    procedure DoMouseDown(X, Y: Integer; Button: Byte); virtual;
    procedure Update(DeltaTime: Real); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    destructor Done; virtual;
  end;

  TUIManager = object
    Widgets: TLinkedList;
    FocusedWidget: PWidget;
    BackBuffer, BackgroundBuffer: PFrameBuffer;
    Style: PUIStyle;
    Running: Boolean;
    LastMouseButtons: Byte;

    procedure Init(FrameBuffer, Background: PFrameBuffer);
    procedure AddWidget(Widget: PWidget);
    procedure RemoveWidget(Widget: PWidget);
    procedure SetFocus(Widget: PWidget);
    procedure FocusInDirection(DX, DY: Integer);
    procedure DispatchKeyboardEvents;
    procedure DispatchMouseEvents;
    procedure Update(DeltaTime: Real);
    procedure RenderAll;
    procedure RenderDirty;
    procedure SetStyle(NewStyle: PUIStyle);
    procedure Run(UpdateProcedure: Pointer; VSync: Boolean);
    procedure Stop;
    procedure Done;
  end;
```

## Example

```pascal
uses VGA, VGAFont, VGAUI, Keyboard, Mouse, RTCTimer;

var
  UI: TUIManager;
  BackBuffer, Background: PFrameBuffer;
  Font: TFont;
  Button: PButton;
  Checkbox: PCheckbox;
  LineEdit: PLineEdit;

{$F+}
procedure OnButtonClick(Sender: PWidget);
begin
  WriteLn('Button clicked!');
end;

procedure OnCheckboxClick(Sender: PWidget);
var
  CB: PCheckbox;
begin
  CB := PCheckbox(Sender);
  { Checkbox already toggled by widget }
  if CB^.IsChecked then
    WriteLn('Checkbox checked')
  else
    WriteLn('Checkbox unchecked');
end;

procedure OnNameSubmit(Sender: PWidget; KeyCode: Byte);
var
  Input: PLineEdit;
begin
  if KeyCode = Key_Enter then
  begin
    Input := PLineEdit(Sender);
    WriteLn('Name submitted: ', Input^.GetText);
  end;
end;

procedure OnUpdate;
begin
  if IsKeyPressed(Key_Escape) then
    UI.Stop;
end;
{$F-}

begin
  InitVGA;
  InitKeyboard;
  InitMouse;
  ShowMouse;
  BackBuffer := CreateFrameBuffer;
  Background := CreateFrameBuffer;
  ClearFrameBuffer(Background);

  { Load font }
  LoadFont('DATA\FONT.XML', Font);

  { Setup UI }
  UI.Init(BackBuffer, Background);

  { Create widgets - MUST use constructor syntax }
  New(Button, Init(10, 10, 120, 20, 'Click Me', @Font));
  Button^.OnClick := @OnButtonClick;
  UI.AddWidget(Button);

  New(Checkbox, Init(10, 35, 120, 16, 'Enable Sound', @Font, @CheckboxImage));
  Checkbox^.OnClick := @OnCheckboxClick;
  Checkbox^.SetChecked(True);
  UI.AddWidget(Checkbox);

  New(LineEdit, Init(10, 55, 120, 16, @Font, 20));
  LineEdit^.OnKeyPress := @OnNameSubmit;
  LineEdit^.SetText('Player Name');
  UI.AddWidget(LineEdit);

  { Focus first widget }
  UI.SetFocus(Button);

  { Run UI loop with VSync }
  UI.Run(@OnUpdate, True);

  { Cleanup }
  UI.RemoveWidget(Button); Dispose(Button, Done);
  UI.RemoveWidget(Checkbox); Dispose(Checkbox, Done);
  UI.RemoveWidget(LineEdit); Dispose(LineEdit, Done);
  UI.Done;

  FreeFont(Font);
  FreeFrameBuffer(BackBuffer);
  FreeFrameBuffer(Background);
  HideMouse;
  DoneMouse;
  DoneKeyboard;
  DoneVGA;
end.
```

## Navigation

- **Arrow Keys:** Focus nearest widget in direction (automatic)
- **Enter/Space:** Activate focused button/checkbox
- **Mouse Click:** Focus and activate widget
- **A-Z, 0-9:** Text input in LineEdit
- **Backspace:** Delete character in LineEdit

## Event Handlers

### Delphi-Style Event Callbacks

VGAUI uses Delphi VCL-style event handlers. Event handlers MUST use `{$F+}` directive:

```pascal
{$F+}
procedure OnButtonClick(Sender: PWidget);
begin
  { Handle button click (keyboard or mouse) }
end;
{$F-}

{ Assign event handler }
Button^.OnClick := @OnButtonClick;
```

### Available Events

- **OnClick** - `TClickEvent` - Widget activated (Enter/Space or complete mouse click)
- **OnKeyPress** - `TKeyPressEvent` - Key pressed while widget focused
- **OnMouseDown** - `TMouseEvent` - Mouse button pressed on widget
- **OnMouseUp** - `TMouseEvent` - Mouse button released
- **OnMouseMove** - `TMouseEvent` - Mouse moved while button down
- **OnFocus** - `TFocusEvent` - Widget gained focus
- **OnBlur** - `TFocusEvent` - Widget lost focus

### When to Use OnClick vs OnKeyPress

**Use OnClick for buttons/checkboxes:**
- Fires on complete activation (key release or mouse click)
- No need to check for specific keys
- Works for both keyboard (Enter/Space) and mouse clicks
- Provides tactile feedback (button press/release animation)

**Use OnKeyPress for text input or custom key handling:**
- LineEdit uses this for character input
- When you need to handle specific keys (F1, Escape, etc.)
- When you need low-level key processing

**Pattern for forms with text input + submit button:**
```pascal
{ Shared submission logic }
procedure DoSubmit;
begin
  { Get text from input and process it }
end;

{ Button handler - fires on click }
procedure OnSubmitButton(Sender: PWidget);
begin
  DoSubmit;
end;

{ LineEdit handler - fires on Enter key }
procedure OnInputEnter(Sender: PWidget; KeyCode: Byte);
begin
  if KeyCode = Key_Enter then
    DoSubmit;
end;

{ Assign handlers }
LineEdit^.OnKeyPress := @OnInputEnter;  { Enter in text field }
SubmitButton^.OnClick := @OnSubmitButton;  { Click button }
```

### Virtual Do* Methods

Widgets can override Do* methods to intercept events before callbacks:

```pascal
procedure TMyButton.DoKeyPress(KeyCode: Byte);
begin
  { Custom handling }
  if KeyCode = Key_F1 then
    ShowHelp
  else
    inherited DoKeyPress(KeyCode);  { Call parent + user callback }
end;
```

## Rendering

```pascal
{ Full render (all widgets) }
UI.RenderAll;
RenderFrameBuffer(BackBuffer);

{ Optimized dirty rendering (40x faster) }
UI.RenderDirty;  { Only renders widgets with NeedsRedraw=True }
```

## UI Loop

```pascal
{ Built-in UI loop with timing }
UI.Run(@OnUpdate, True);  { VSync enabled }

{ Manual loop }
InitRTC(1024);
Last := GetTimeSeconds;
while Running do
begin
  Cur := GetTimeSeconds;
  DT := Cur - Last;
  Last := Cur;

  OnUpdate;  { User code }
  UI.Update(DT);
  UI.RenderDirty;
  ClearKeyPressed;
end;
DoneRTC;
```

## Alignment Constants

```pascal
{ Horizontal }
Align_Left   = 1;
Align_Center = 2;
Align_Right  = 4;

{ Vertical }
Align_Top    = 8;
Align_Middle = 16;
Align_Bottom = 32;

{ Examples }
Label^.TextAlign := Align_Center + Align_Middle;  { Centered text }
Label^.TextAlign := Align_Left + Align_Top;       { Top-left aligned }
```

## Critical Notes

1. **Constructor syntax** - MUST use `New(Widget, Init(...))` for VMT
2. **Destructor syntax** - MUST use `Dispose(Widget, Done)`
3. **Far calls** - Event handlers need `{$F+}` directive
4. **Remove before dispose** - Call `UI.RemoveWidget` before `Dispose`
5. **Font/Image lifetime** - Caller manages, widgets don't copy
6. **Event assignment** - Use `@` operator: `Widget^.OnKeyPress := @Handler`

## Widget Memory

```pascal
{ Widget owns: }
- Text: PShortString (allocated in Init, freed in Done)
- Lines: TMultiLineText (for multi-line text wrapping)

{ Widget does NOT own: }
- Font: PFont (caller manages)
- Image: PImage (caller manages - for checkbox)
```

## Widget Types

```pascal
WidgetType_Base     = 0;
WidgetType_Label    = 1;
WidgetType_Button   = 2;
WidgetType_Checkbox = 3;
WidgetType_LineEdit = 4;
```

## Notes

- Keyboard + mouse navigation (Tab, arrows, Enter/Space, click)
- 3D beveled panels (Windows 95-style)
- Dirty rectangle optimization for 40x performance boost
- Delphi VCL-style event architecture
- Multi-line text support with automatic wrapping
- Blinking cursor in LineEdit (500ms interval)
- See `TESTS\UITEST.PAS` for complete example
- See `DOCS\DESIGN\UI-REFACTOR.md` for event system design
