# VGAUI.PAS - VGA Mode 13h UI System

Lightweight widget-based UI framework for DOS VGA graphics. Provides keyboard-driven navigation with an event handling architecture for building menus, dialogs, and game screens.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Core Types](#core-types)
- [Widget Types](#widget-types)
- [Event System](#event-system)
- [UI Manager](#ui-manager)
- [Theming](#theming)
- [Memory Management](#memory-management)
- [Complete Example](#complete-example)

## Overview

**Purpose:** Minimal UI widgets (Label, Button, Checkbox, LineEdit) for retro DOS game interfaces.

**Key Features:**
- Object-oriented widget hierarchy with virtual methods
- Event-driven architecture with procedure pointer callbacks
- Keyboard-only navigation (Tab, arrows, Enter/Space)
- Focus management with visual feedback
- 3D beveled panel theming (Windows 3.1/95-style)
- Constructor/destructor pattern for proper VMT initialization

**Dependencies:**
- VGA.PAS - framebuffer rendering (DrawFillRect, DrawRect, DrawHLine, DrawVLine)
- VGAFONT.PAS - text rendering (PrintFontText, GetTextWidth)
- KEYBOARD.PAS - input handling (IsKeyDown, IsKeyPressed, scancodes)
- LINKLIST.PAS - widget storage
- GENTYPES.PAS - generic types (PShortString)

## Architecture

```
┌─────────────────────────────────────────┐
│          TUIManager                     │
│  - Widgets: TLinkedList                 │
│  - FocusedWidget: PWidget               │
│  - Style: TUIStyle                      │
│  - BackBuffer: PFrameBuffer             │
│  - BackgroundBuffer: PFrameBuffer       │
└─────────────────────────────────────────┘
               │ manages
               ▼
┌─────────────────────────────────────────┐
│          TWidget (base)                 │
│  - Rectangle: TRectangle                │
│  - Visible, Enabled, Focused            │
│  - EventHandler: Pointer                │
└─────────────────────────────────────────┘
               │ inheritance
        ┌──────┴──────┬──────┬───────┐
        ▼             ▼      ▼       ▼
    TLabel       TButton  TCheckbox  TLineEdit
  (non-interactive)  (clickable)  (toggleable)  (text input)
```

**Event Flow:**
```
Keyboard Input (KEYBOARD.PAS)
         ↓
Game/App Code
         ↓
UI.DispatchKeyboardEvents
         ↓
UI.HandleEvent
         ↓
FocusedWidget.HandleEvent
         ↓
Widget's EventHandler (if set)
```

## Core Types

### TUIStyle

3D panel theming with beveled edges (Windows 3.1/95-style).

```pascal
TUIStyle = object
  HighColor: Byte;      { Light edge color (highlight) }
  NormalColor: Byte;    { Middle/fill color }
  LowColor: Byte;       { Dark edge color (shadow) }
  FocusColor: Byte;     { Border color for focused widgets }

  constructor Init(High, Normal, Low, Focus: Byte);
  procedure RenderPanel(const R: TRectangle; Pressed: Boolean;
                        FrameBuffer: PFrameBuffer); virtual;
end;
```

**Panel Rendering:**
- **Pressed=False (released)**: Light edges top-left, dark edges bottom-right (raised)
- **Pressed=True (sunken)**: Dark edges top-left, light edges bottom-right (sunken)
- Virtual method allows custom theming by overriding RenderPanel

**Default Colors:**
- HighColor: 15 (white)
- NormalColor: 7 (light gray)
- LowColor: 8 (dark gray)
- FocusColor: 14 (yellow)

**Example Custom Style:**
```pascal
type
  TFlatStyle = object(TUIStyle)
    procedure RenderPanel(const R: TRectangle; Pressed: Boolean;
                          FrameBuffer: PFrameBuffer); virtual;
  end;

procedure TFlatStyle.RenderPanel(const R: TRectangle; Pressed: Boolean;
                                  FrameBuffer: PFrameBuffer);
begin
  { Flat design - single border, no bevels }
  DrawRect(R, LowColor, FrameBuffer);
end;

var
  FlatStyle: TFlatStyle;
begin
  FlatStyle.Init(15, 7, 8, 14);
  UI.SetStyle(FlatStyle);
end;
```

### TEvent

Event data structure passed to widgets.

```pascal
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
```

### TEventHandler

Far-call procedure pointer for event callbacks.

```pascal
{$F+}
TEventHandler = procedure(var Widget: TWidget; var Event: TEvent);
TUpdateProcedure = procedure;  { User update callback (no parameters) }
{$F-}
```

**CRITICAL:** Event handlers and update procedures MUST be defined in `{$F+}/{$F-}` blocks for far calls.

## Widget Types

### TWidget (Base)

Abstract base object for all widgets.

```pascal
TWidget = object
  Rectangle: TRectangle;        { Position and size }
  Visible: Boolean;             { Render if True }
  Enabled: Boolean;             { Can receive focus/events }
  Focused: Boolean;             { Currently has keyboard focus }
  NeedsRedraw: Boolean;         { Widget needs rendering (dirty flag) }
  EventHandler: Pointer;        { TEventHandler callback }
  Tag: Integer;                 { User data for identification }

  constructor Init(X, Y: Integer; W, H: Word);
  procedure SetEventHandler(Handler: Pointer);
  procedure MarkDirty;          { Request redraw of this widget }
  procedure SetVisible(Value: Boolean);  { Set visibility and mark dirty if changed }
  procedure SetEnabled(Value: Boolean);  { Set enabled state and mark dirty if changed }
  procedure HandleEvent(var Event: TEvent); virtual;
  procedure Update(DeltaTime: Real); virtual;
  procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
  procedure RenderFocusRectangle(FrameBuffer: PFrameBuffer; Style: PUIStyle);
  destructor Done; virtual;
end;
```

**CRITICAL:** Widgets with virtual methods MUST be allocated with constructor syntax:
```pascal
{ CORRECT }
New(Button, Init(x, y, w, h, 'Text', @Font));
Dispose(Button, Done);

{ WRONG - VMT not initialized! }
New(Button);
Button^.Init(x, y, w, h, 'Text', @Font);  { Will crash! }
```

### TLabel

Non-interactive text display.

```pascal
TLabel = object(TWidget)
  Text: PShortString;
  Font: PFont;

  constructor Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont);
  procedure SetText(const NewText: string);
  procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
  destructor Done; virtual;
end;
```

**Behavior:**
- Cannot receive focus (Enabled = False by default)
- Renders text at position using VGAFont
- Auto-calculates width from text + font metrics
- Height from Font.Height

**Example:**
```pascal
var Label: PLabel;
    TextWidth: Integer;
begin
  TextWidth := GetTextWidth('Score: 0', Font);
  New(Label, Init(10, 10, TextWidth, Font.Height, 'Score: 0', @Font));
  UI.AddWidget(Label);

  { Update text later }
  Label^.SetText('Score: 100');

  { Cleanup }
  UI.RemoveWidget(Label);
  Dispose(Label, Done);
end;
```

### TButton

Interactive clickable button with 3D panel.

```pascal
TButton = object(TWidget)
  Text: PShortString;
  Font: PFont;
  Pressed: Boolean;  { Visual state for rendering }

  constructor Init(X, Y: Integer; W, H: Word; const TextStr: string;
                   FontPtr: PFont);
  procedure SetText(const NewText: string);
  procedure HandleEvent(var Event: TEvent); virtual;
  procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
  destructor Done; virtual;
end;
```

**Behavior:**
- Interactive (can receive focus)
- Renders 3D raised panel + centered text
- Focused: yellow border (palette animated)
- Responds to Enter ($1C) or Space ($39)
- Fires EventHandler on activation

**Example:**
```pascal
{$F+}
procedure OnButtonClick(var Widget: TWidget; var Event: TEvent);
begin
  if Event.EventType = Event_KeyPress then
  begin
    WriteLn('Button clicked!');
    Event.Handled := True;
  end;
end;
{$F-}

var Button: PButton;
begin
  New(Button, Init(100, 60, 120, 24, 'Click Me', @Font));
  Button^.SetEventHandler(@OnButtonClick);
  UI.AddWidget(Button);
end;
```

### TCheckbox

Interactive toggle control with sprite image.

```pascal
TCheckbox = object(TWidget)
  Text: PShortString;
  Font: PFont;
  Image: PImage;        { Sprite sheet: unchecked (row 0) + checked (row 1) }
  Checked: Boolean;     { Current state }

  constructor Init(X, Y: Integer; W, H: Word; const TextStr: string; FontPtr: PFont; CheckboxImage: PImage);
  procedure SetText(const NewText: string);
  procedure SetChecked(Value: Boolean);
  function IsChecked: Boolean;
  procedure HandleEvent(var Event: TEvent); virtual;
  procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
  destructor Done; virtual;
end;
```

**Behavior:**
- Interactive (can receive focus)
- Renders checkbox image + text (layout: [Image] Text)
- Focused: yellow border around entire widget
- Responds to Enter or Space: toggles Checked state
- Fires EventHandler on toggle

**Image Format:**
```
┌────────────┐
│ Unchecked  │  ← Row 0 (Image.Width × (Image.Height / 2))
├────────────┤
│ Checked ✓  │  ← Row 1 (Image.Width × (Image.Height / 2))
└────────────┘
Total: Image.Width × Image.Height
Note: Image.Height should be 2× the height of a single checkbox state
```

**Example:**
```pascal
{$F+}
procedure OnSoundToggle(var Widget: TWidget; var Event: TEvent);
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

var
  CheckboxImage: TImage;
  SoundCheckbox: PCheckbox;
  TextWidth: Integer;
begin
  LoadPCX('DATA\CHECKBOX.PCX', CheckboxImage);
  TextWidth := CheckboxImage.Width + 4 + GetTextWidth('Sound Effects', Font);
  New(SoundCheckbox, Init(100, 100, TextWidth, CheckboxImage.Height div 2, 'Sound Effects', @Font, @CheckboxImage));
  SoundCheckbox^.SetEventHandler(@OnSoundToggle);
  UI.AddWidget(SoundCheckbox);
end;
```

### TLineEdit

Interactive text input field with blinking cursor.

```pascal
TLineEdit = object(TWidget)
  Text: PShortString;
  Font: PFont;
  MaxLength: Byte;      { Maximum characters (1-255) }
  CursorVisible: Boolean; { Blinking cursor state }
  CursorTimer: Real;    { Seconds for blink animation }

  constructor Init(X, Y: Integer; W, H: Word; FontPtr: PFont; MaxLen: Byte);
  procedure SetText(const NewText: string);
  function GetText: string;
  procedure Clear;
  procedure HandleEvent(var Event: TEvent); virtual;
  procedure Render(FrameBuffer: PFrameBuffer; Style: PUIStyle); virtual;
  procedure Update(DeltaTime: Real); virtual;
  destructor Done; virtual;
end;
```

**Behavior:**
- Interactive (can receive focus)
- Renders 3D sunken panel + text + blinking cursor
- Cursor blinks every 0.5 seconds when focused
- Text auto-scrolls left if wider than widget
- Responds to:
  - **Printable keys (A-Z, 0-9, punctuation)**: Append character if Length < MaxLength
  - **Backspace ($0E)**: Delete last character
  - **Enter ($1C)**: Fires EventHandler (for "submit" behavior)

**Character Input:**
- Uses KEYBOARD.PAS CharMapNormal/CharMapShift for scancode → ASCII
- Supports Shift key for uppercase/symbols
- Cursor always at end of text (no navigation)

**Example:**
```pascal
{$F+}
procedure OnNameSubmit(var Widget: TWidget; var Event: TEvent);
var Input: PLineEdit;
    PlayerName: string;
begin
  if (Event.EventType = Event_KeyPress) and (Event.KeyCode = Key_Enter) then
  begin
    Input := PLineEdit(@Widget);
    PlayerName := Input^.GetText;
    if Length(PlayerName) > 0 then
    begin
      { Do something with the `PlayerName` here}
      Event.Handled := True;
    end;
  end;
end;
{$F-}

var NameInput: PLineEdit;
begin
  New(NameInput, Init(100, 140, 120, 20, @Font, 20));  { Max 20 chars }
  NameInput^.SetEventHandler(@OnNameSubmit);
  UI.AddWidget(NameInput);
end;
```

## Event System

### Event Types

```pascal
Event_None       { No event }
Event_KeyPress   { Key was pressed (KeyCode = scancode) }
Event_FocusGain  { Widget gained focus }
Event_FocusLost  { Widget lost focus }
```

### Event Handling Pattern

```pascal
{$F+}
procedure MyEventHandler(var Widget: TWidget; var Event: TEvent);
begin
  case Event.EventType of
    Event_KeyPress:
      begin
        { Handle specific keys }
        if Event.KeyCode = Key_Enter then
        begin
          { Do something }
          Event.Handled := True;  { Prevent further processing }
        end;
      end;

    Event_FocusGain:
      begin
        { Widget gained focus - play sound, etc. }
      end;

    Event_FocusLost:
      begin
        { Widget lost focus - save state, etc. }
      end;
  end;
end;
{$F-}
```

**CRITICAL:** Always set `Event.Handled := True` when you process an event to prevent double-processing.

## UI Manager

### TUIManager

Central manager for all widgets.

```pascal
TUIManager = object
  Widgets: TLinkedList;            { All widgets }
  FocusedWidget: PWidget;          { Currently focused widget }
  BackBuffer: PFrameBuffer;        { Target framebuffer }
  BackgroundBuffer: PFrameBuffer;  { Static background for restoring dirty regions }
  FirstRender: Boolean;            { Force full redraw on first frame }
  Style: PUIStyle;                 { Theme for all widgets (pointer) }
  Running: Boolean;                { UI loop running flag }

  procedure Init(FrameBuffer, Background: PFrameBuffer);
  procedure AddWidget(Widget: PWidget);
  procedure RemoveWidget(Widget: PWidget);
  procedure SetFocus(Widget: PWidget);
  procedure FocusInDirection(DX, DY: Integer);  { Arrow key navigation }
  procedure DispatchKeyboardEvents;  { Check all keys and dispatch }
  procedure HandleEvent(var Event: TEvent);
  procedure Update(DeltaTime: Real);  { Update all widgets (seconds) }
  procedure RenderAll;              { Render all widgets unconditionally }
  procedure RenderDirty;            { Smart dirty rectangle rendering }
  procedure SetStyle(NewStyle: PUIStyle);
  function IsEnter(var Event: TEvent): Boolean;  { Helper to check Enter key }
  procedure Run(UpdateProcedure: Pointer);  { Main UI loop with optional update callback }
  procedure Stop;                   { Stop the UI loop }
  procedure Done;
end;
```

### Focus Management

**Focus Order:**
- Only one widget can have focus at a time
- Arrow keys focus nearest widget in that direction (geometric navigation)
- Labels cannot receive focus (Enabled = False)

**Navigation Keys:**
- **Arrow Keys (Up/Down/Left/Right)**: FocusInDirection (geometric navigation)

### Rendering

**Render Modes:**

1. **RenderAll**: Renders all visible widgets unconditionally
   - Use for initial render or full screen updates
   - Simple but slower for frequent updates

2. **RenderDirty**: Smart dirty rectangle rendering (optimized)
   - Only renders widgets with NeedsRedraw = True
   - Restores background from BackgroundBuffer before redrawing
   - Tracks dirty regions via DRECT.PAS
   - Significantly faster for interactive UIs

**Render Order:**
- Widgets render in insertion order (first added = back, last added = front)
- Only visible widgets render
- Each widget renders to BackBuffer
- Caller must call RenderFrameBuffer(BackBuffer) or FlushDirtyRects(BackBuffer) after rendering

**Example (Using UI.Run - Recommended):**
```pascal
{$F+}
procedure OnUpdate;
begin
  if IsKeyPressed(Key_Escape) then
    UI.Stop;
end;
{$F-}

var BackBuffer, Background: PFrameBuffer;
begin
  InitVGA;
  BackBuffer := CreateFrameBuffer;
  Background := CreateFrameBuffer;

  { Draw static background to Background buffer }
  { ... draw background art ... }
  CopyFrameBuffer(Background, BackBuffer);

  UI.Init(BackBuffer, Background);

  { Add widgets... }

  { Run UI loop with update callback }
  UI.Run(@OnUpdate);  { Handles timing, rendering, and keyboard automatically }

  UI.Done;
  FreeFrameBuffer(BackBuffer);
  FreeFrameBuffer(Background);
  CloseVGA;
end;
```

**Example (Manual Loop - Advanced):**
```pascal
var BackBuffer, Background: PFrameBuffer;
begin
  InitVGA;
  BackBuffer := CreateFrameBuffer;
  Background := CreateFrameBuffer;

  { Draw static background to Background buffer }
  { ... draw background art ... }
  CopyFrameBuffer(Background, BackBuffer);

  UI.Init(BackBuffer, Background);

  { Manual loop }
  while Running do
  begin
    { Update - internally calls DispatchKeyboardEvents }
    UI.Update(DeltaTime);  { DeltaTime in seconds }

    { Render only dirty widgets + flush dirty rects }
    UI.RenderDirty;

    ClearKeyPressed;
  end;

  UI.Done;
  FreeFrameBuffer(BackBuffer);
  FreeFrameBuffer(Background);
  CloseVGA;
end;
```

**Example (Simple Full Render):**
```pascal
var BackBuffer: PFrameBuffer;
begin
  InitVGA;
  BackBuffer := CreateFrameBuffer;
  UI.Init(BackBuffer, nil);  { No background buffer }

  while Running do
  begin
    UI.Update(DeltaTime);

    { Clear and render everything }
    ClearFrameBuffer(BackBuffer);
    UI.RenderAll;
    RenderFrameBuffer(BackBuffer);

    ClearKeyPressed;
  end;

  UI.Done;
  FreeFrameBuffer(BackBuffer);
  CloseVGA;
end;
```

### UI Loop Methods

**UI.Run(UpdateProcedure: Pointer)**

Built-in UI event loop that handles timing, rendering, and keyboard input automatically. This is the recommended way to run simple UI screens like menus and dialogs.

```pascal
procedure Run(UpdateProcedure: Pointer);
```

**Parameters:**
- `UpdateProcedure`: Optional pointer to TUpdateProcedure (far-call procedure with no parameters)
  - Called once per frame before widget updates
  - Use for custom input handling (e.g., Escape key to close dialog)
  - Pass `nil` if no custom update logic needed

**Behavior:**
- Maintains its own delta time calculation (in seconds)
- Calls UpdateProcedure (if not nil)
- Calls Update(DeltaTime) for widget updates (DeltaTime in seconds)
- Calls RenderDirty for optimized rendering
- Handles VSync and ClearKeyPressed automatically
- Runs until Stop is called

**UI.Stop**

Stops the UI.Run loop by setting Running := False.

```pascal
procedure Stop;
```

**UI.IsEnter(var Event: TEvent): Boolean**

Helper function to check if an event is an Enter key press.

```pascal
function IsEnter(var Event: TEvent): Boolean;
```

**Returns:** True if Event is a KeyPress event with KeyCode = Key_Enter

**Example Usage:**

```pascal
{$F+}
{ Custom update procedure - called each frame before widget updates }
procedure OnDialogUpdate;
begin
  if IsKeyPressed(Key_Escape) then
    UI.Stop;  { Close dialog on Escape }
end;

{ Button event handler }
procedure OnOkButtonClick(var Widget: TWidget; var Event: TEvent);
begin
  if UI.IsEnter(Event) then
  begin
    { Process OK button click }
    UI.Stop;  { Close dialog }
  end;
end;
{$F-}

var
  BackBuffer, Background: PFrameBuffer;
  OkButton: PButton;
begin
  { Setup UI }
  UI.Init(BackBuffer, Background);
  UI.SetStyle(@CustomStyle);

  New(OkButton, Init(100, 100, 120, 24, 'OK', @Font));
  OkButton^.SetEventHandler(@OnOkButtonClick);
  UI.AddWidget(OkButton);
  UI.SetFocus(OkButton);

  { Run UI loop - Escape or OK button will exit }
  UI.Run(@OnDialogUpdate);

  { Cleanup }
  UI.RemoveWidget(OkButton);
  Dispose(OkButton, Done);
  UI.Done;
end;
```

## Theming

### Default Style

```pascal
var Style: TUIStyle;
begin
  Style.Init(15, 7, 8, 14);  { High, Normal, Low, Focus }
  UI.SetStyle(@Style);  { Pass pointer to style }
end;
```

### Custom Style

Override RenderPanel for custom rendering:

```pascal
type
  TCustomStyle = object(TUIStyle)
    procedure RenderPanel(const R: TRectangle; Pressed: Boolean;
                          FrameBuffer: PFrameBuffer); virtual;
  end;

procedure TCustomStyle.RenderPanel(const R: TRectangle; Pressed: Boolean;
                                    FrameBuffer: PFrameBuffer);
begin
  { Custom rendering - flat, gradient, etc. }
  DrawRect(R, HighColor, FrameBuffer);
  DrawFillRect(MakeRect(R.X + 1, R.Y + 1, R.Width - 2, R.Height - 2),
               NormalColor, FrameBuffer);
end;

var CustomStyle: TCustomStyle;
begin
  CustomStyle.Init(15, 7, 8, 14);
  UI.SetStyle(@CustomStyle);  { Pass pointer to style }
end;
```

### Focus Animation (Palette Rotation)

Focus border color can be animated via palette rotation for pulsing effect:

```pascal
{ In main loop }
FocusFadeTimer := FocusFadeTimer + DeltaTime;
if FocusFadeTimer > 400 then
begin
  FocusFadeTimer := 0;
  { Rotate palette index 14 (yellow) for fade effect }
  { Example: swap between bright yellow and dim yellow }
  RotatePalette(14, 1, 1);  { See VGA.PAS for details }
end;
```

**Benefits:**
- Hardware-accelerated (VGA palette registers)
- No per-frame rendering cost
- Works on 8MHz 286 without performance impact

## Memory Management

### Widget Lifecycle

```pascal
{ 1. Allocate with constructor }
New(MyButton, Init(x, y, w, h, 'Text', @Font));

{ 2. Register }
UI.AddWidget(MyButton);

{ 3. Set event handler }
MyButton^.SetEventHandler(@OnButtonClick);

{ 4. Use }
{ ... events, rendering ... }

{ 5. Cleanup with destructor }
UI.RemoveWidget(MyButton);
Dispose(MyButton, Done);
```

**CRITICAL Rules:**
1. **Always use constructor syntax:** `New(Widget, Init(...))`
   - NOT: `New(Widget); Widget^.Init(...)`  ← Breaks VMT!
2. **Always use destructor syntax:** `Dispose(Widget, Done)`
3. **Remove before disposal:** `UI.RemoveWidget(Widget)` before `Dispose`
4. **Font/Image not owned:** Caller manages font/image lifetime
5. **UIManager.Done does NOT free widgets:** Caller responsibility

### Memory Ownership

```pascal
{ Widget owns: }
- Text: PShortString (allocated in Init, freed in Done)

{ Widget does NOT own: }
- Font: PFont (caller manages)
- Image: PImage (caller manages)

{ Example: }
var Font: TFont;
    Image: TImage;
    Button: PButton;
begin
  { Load resources FIRST }
  LoadFont('FONT.XML', 'FONT.PCX', Font);
  LoadPCX('IMAGE.PCX', Image);

  { Create widget (does NOT copy font/image) }
  New(Button, Init(x, y, w, h, 'Text', @Font));
  UI.AddWidget(Button);

  { ... use widget ... }

  { Cleanup: widget first, then resources }
  UI.RemoveWidget(Button);
  Dispose(Button, Done);
  FreeFont(Font);
  FreeImage(Image);
end;
```

## Complete Example

Check `TESTS\UITEST.PAS` for a complete example with optimized rendering.

## See Also

- **[VGA.md](VGA.md)** - Framebuffer rendering (DrawRect, DrawFillRect, etc.)
- **[VGAFONT.md](VGAFONT.md)** - Variable-width fonts
- **[KEYBOARD.md](KEYBOARD.md)** - Keyboard input and scancodes
- **[DOCS/DESIGN/VGAUI.md](DESIGN/VGAUI.md)** - Original design document
- **TESTS/UITEST.PAS** - Complete test program with all widget types
- **CLAUDE.md** - Technical reference (condensed)
- **UNITS/VGAUI.PAS** - Full source code
