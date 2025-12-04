# VGAUI - VGA UI System

Widget-based UI framework for VGA Mode 13h with keyboard navigation.

## Types

```pascal
type
  TEventType = (Event_None, Event_KeyPress, Event_FocusGain, Event_FocusLost);

  TEvent = record
    EventType: TEventType;
    KeyCode: Byte;
    Handled: Boolean;
  end;

  {$F+}
  TEventHandler = procedure(var Widget: TWidget; var Event: TEvent);
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
    EventHandler: Pointer;
    Tag: Integer;
    constructor Init(X, Y: Integer; W, H: Word);
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Update(DeltaTime: Real); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    destructor Done; virtual;
  end;

  TLabel = object(TWidget)
    Text: PShortString;
    Font: PFont;
    constructor Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont);
    procedure SetText(const NewText: string);
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    destructor Done; virtual;
  end;

  TButton = object(TWidget)
    Text: PShortString;
    Font: PFont;
    Pressed: Boolean;
    constructor Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont);
    procedure SetText(const NewText: string);
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
    destructor Done; virtual;
  end;

  TCheckbox = object(TWidget)
    Text: PShortString;
    Font: PFont;
    Image: PImage;
    Checked: Boolean;
    constructor Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont; CheckboxImage: PImage);
    procedure SetChecked(Value: Boolean);
    function IsChecked: Boolean;
    procedure HandleEvent(var Event: TEvent); virtual;
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
    procedure HandleEvent(var Event: TEvent); virtual;
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

    procedure Init(FrameBuffer, Background: PFrameBuffer);
    procedure AddWidget(Widget: PWidget);
    procedure RemoveWidget(Widget: PWidget);
    procedure SetFocus(Widget: PWidget);
    procedure Update(DeltaTime: Real);
    procedure RenderAll;
    procedure RenderDirty;
    procedure SetStyle(NewStyle: PUIStyle);
    procedure Run(UpdateProcedure: Pointer);  { Built-in UI loop }
    procedure Stop;
    procedure Done;
  end;
```

## Example

```pascal
uses VGA, VGAFont, VGAUI, Keyboard, RTCTimer;

{$F+}
procedure OnButtonClick(var Widget: TWidget; var Event: TEvent);
begin
  if (Event.EventType = Event_KeyPress) and
     ((Event.KeyCode = Key_Enter) or (Event.KeyCode = Key_Space)) then
  begin
    WriteLn('Button clicked!');
    Event.Handled := True;
  end;
end;

procedure OnUpdate;
begin
  if IsKeyPressed(Key_Escape) then
    UI.Stop;
end;
{$F-}

var
  UI: TUIManager;
  Style: TUIStyle;
  BackBuffer, Background: PFrameBuffer;
  Font: TFont;
  Button: PButton;
  Label: PLabel;

begin
  InitVGA;
  InitKeyboard;
  BackBuffer := CreateFrameBuffer;
  Background := CreateFrameBuffer;

  { Load font }
  LoadFont('DATA\FONT.XML', Font);

  { Setup UI }
  UI.Init(BackBuffer, Background);
  Style.Init(15, 7, 8, 14);  { High, Normal, Low, Focus }
  UI.SetStyle(@Style);

  { Create widgets - MUST use constructor syntax }
  New(Label, Init(10, 10, 200, Font.Height, 'Hello World!', @Font));
  UI.AddWidget(Label);

  New(Button, Init(100, 60, 120, 24, 'Click Me', @Font));
  Button^.SetEventHandler(@OnButtonClick);
  UI.AddWidget(Button);
  UI.SetFocus(Button);

  { Run UI loop }
  UI.Run(@OnUpdate);

  { Cleanup }
  UI.RemoveWidget(Button);
  Dispose(Button, Done);
  UI.RemoveWidget(Label);
  Dispose(Label, Done);
  UI.Done;

  FreeFont(Font);
  FreeFrameBuffer(BackBuffer);
  FreeFrameBuffer(Background);
  DoneKeyboard;
  CloseVGA;
end.
```

## Navigation

- **Arrow Keys:** Focus nearest widget in direction
- **Enter/Space:** Activate focused button/checkbox
- **A-Z, 0-9:** Text input in LineEdit
- **Backspace:** Delete character in LineEdit

## Rendering

```pascal
{ Full render (all widgets) }
UI.RenderAll;
RenderFrameBuffer(BackBuffer);

{ Optimized dirty rendering }
UI.RenderDirty;  { Only renders widgets with NeedsRedraw=True }
```

## Event Handlers

Event handlers MUST use `{$F+}` directive:

```pascal
{$F+}
procedure OnCheckboxToggle(var Widget: TWidget; var Event: TEvent);
var CB: PCheckbox;
begin
  if Event.EventType = Event_KeyPress then
  begin
    CB := PCheckbox(@Widget);
    if CB^.IsChecked then
      EnableSound
    else
      DisableSound;
    Event.Handled := True;
  end;
end;
{$F-}
```

## Critical Notes

1. **Constructor syntax** - MUST use `New(Widget, Init(...))` for VMT
2. **Destructor syntax** - MUST use `Dispose(Widget, Done)`
3. **Far calls** - Event handlers need `{$F+}` directive
4. **Remove before dispose** - Call `UI.RemoveWidget` before `Dispose`
5. **Font/Image lifetime** - Caller manages, widgets don't copy

## Widget Memory

```pascal
{ Widget owns: }
- Text: PShortString (allocated in Init, freed in Done)

{ Widget does NOT own: }
- Font: PFont (caller manages)
- Image: PImage (caller manages)
```

## Notes

- Keyboard-only navigation (Tab, arrows, Enter/Space)
- 3D beveled panels (Windows 95-style)
- Dirty rectangle optimization for performance
- Event-driven architecture
- See TESTS\UITEST.PAS for complete example
