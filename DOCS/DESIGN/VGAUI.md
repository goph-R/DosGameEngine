# VGAUI.PAS - Minimal UI System Design

Lightweight widget-based UI framework for DOS VGA Mode 13h. Keyboard-driven navigation with event handling.

## Overview

**Purpose:** Provide minimal UI widgets (Label, Button, Checkbox) for menus, dialogs, and game screens.

**Architecture:**
- Object-oriented widget hierarchy (Turbo Pascal objects)
- Event-driven model with procedure pointers
- Linked list for widget storage and traversal
- Keyboard-only navigation (Tab, arrows, Enter, Space)
- Focus management for active widget
- Dirty rectangle rendering integration

## Core Types

### TUIStyle
```pascal
TUIStyle = object
  HighColor: Byte;      { Light edge color (highlight) }
  NormalColor: Byte;    { Middle/fill color }
  LowColor: Byte;       { Dark edge color (shadow) }
  FocusColor: Byte;     { Border color for focused widgets (palette animated) }

  procedure Init(High, Normal, Low, Focus: Byte);
  procedure RenderPanel(const R: TRectangle; Pressed: Boolean; FrameBuffer: PFrameBuffer); virtual;
end;
```

**Design Notes:**
- Provides consistent 3D panel theming across all widgets
- **Edge Colors (3D beveled panels):**
  - **HighColor**: Light edge (top-left when released, bottom-right when pressed)
  - **NormalColor**: Middle fill color
  - **LowColor**: Dark edge (bottom-right when released, top-left when pressed)
- `RenderPanel` draws 3D-style beveled panels:
  - **Pressed=False (released)**: High on top-left edges, Low on bottom-right edges (raised look)
  - **Pressed=True**: Low on top-left edges, High on bottom-right edges (sunken look)
- Virtual method allows custom panel rendering styles (can be overridden)
- Default colors: High=15 (white), Normal=7 (light gray), Low=8 (dark gray), Focus=14 (yellow)
- Focus color animated via palette rotation for fade in/out effect

**RenderPanel Implementation:**
```pascal
{ Default implementation - can be overridden }
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
```

### TEventType
```pascal
TEventType = (
  Event_None,
  Event_KeyPress,    { Key was pressed }
  Event_FocusGain,   { Widget gained focus }
  Event_FocusLost    { Widget lost focus }
);
```

### TEvent
```pascal
TEvent = record
  EventType: TEventType;
  KeyCode: Byte;       { Scancode from KEYBOARD.PAS }
  Handled: Boolean;    { Set to True if widget handled the event }
end;
```

### TEventHandler
```pascal
TEventHandler = procedure(var Widget: TWidget; var Event: TEvent);
{$F+}  { Far call for procedure pointer compatibility }
```

### TWidget (Base Object)
```pascal
TWidget = object
  Rectangle: TRectangle;        { Position and size }
  Visible: Boolean;             { Render if True }
  Enabled: Boolean;             { Can receive focus/events }
  Focused: Boolean;             { Currently has keyboard focus }
  EventHandler: TEventHandler;  { Event callback (nil = no handler) }
  Tag: Integer;                 { User data for identification }

  procedure Init(X, Y: Integer; W, H: Word);
  procedure SetEventHandler(Handler: TEventHandler);
  procedure HandleEvent(var Event: TEvent); virtual;
  procedure Render(FrameBuffer: PFrameBuffer; var Style: TUIStyle); virtual; abstract;
  procedure Done; virtual;
end;
```

**Design Notes:**
- Base object with virtual methods for polymorphism
- `Render` is abstract (must be overridden)
- `HandleEvent` calls EventHandler if set, can be overridden
- `Init`/`Done` for manual lifecycle (no constructors/destructors)

## Widget Types

### TLabel
```pascal
TLabel = object(TWidget)
  Text: PShortString;   { Pointer to avoid large stack usage }
  Font: PFont;          { Pointer to loaded font }

  procedure Init(X, Y: Integer; const TextStr: string; FontPtr: PFont);
  procedure SetText(const NewText: string);
  procedure Render(FrameBuffer: PFrameBuffer; var Style: TUIStyle); virtual;
  procedure Done; virtual;
end;
```

**Behavior:**
- Non-interactive (cannot receive focus)
- Renders text at position using VGAFont (font image determines colors)
- Auto-calculates width from text + font metrics
- Height from font.Height

### TButton
```pascal
TButton = object(TWidget)
  Text: PShortString;
  Font: PFont;

  procedure Init(X, Y: Integer; W, H: Word; const TextStr: string;
                 FontPtr: PFont);
  procedure SetText(const NewText: string);
  procedure HandleEvent(var Event: TEvent); virtual;
  procedure Render(FrameBuffer: PFrameBuffer; var Style: TUIStyle); virtual;
  procedure Done; virtual;
end;
```

**Behavior:**
- Interactive (can receive focus)
- Renders 3D panel using UIManager.Style.RenderPanel (Pressed=False) + centered text
- Focused: outer border drawn with UIManager.Style.FocusColor (palette animated for fade effect)
- Responds to Enter/Space: fires EventHandler with Event_KeyPress
- Text color determined by font image (no runtime color changes)
- Uses Style.RenderPanel for consistent 3D beveled appearance

### TCheckbox
```pascal
TCheckbox = object(TWidget)
  Text: PShortString;
  Font: PFont;
  Image: PImage;        { Sprite sheet: unchecked (top) + checked (bottom) }
  ImageWidth: Word;     { Width of single checkbox image }
  ImageHeight: Word;    { Height of single checkbox image }
  Checked: Boolean;     { Current state }

  procedure Init(X, Y: Integer; const TextStr: string; FontPtr: PFont;
                 CheckboxImage: PImage; ImgW, ImgH: Word);
  procedure SetText(const NewText: string);
  procedure SetChecked(Value: Boolean);
  function IsChecked: Boolean;
  procedure HandleEvent(var Event: TEvent); virtual;
  procedure Render(FrameBuffer: PFrameBuffer; var Style: TUIStyle); virtual;
  procedure Done; virtual;
end;
```

**Behavior:**
- Interactive (can receive focus)
- Renders checkbox image (unchecked row 0, checked row 1 of sprite) + text
- Focused: border drawn around entire widget with UIManager.Style.FocusColor (palette animated)
- Responds to Space: toggles Checked state, fires EventHandler
- Layout: [Image] Text (image on left, text on right with 4px gap)
- Text color determined by font image

**Image Format:**
```
Row 0: Unchecked sprite (ImageWidth × ImageHeight)
Row 1: Checked sprite (ImageWidth × ImageHeight)
```

Total image size: ImageWidth × (ImageHeight × 2)

### TLineEdit
```pascal
TLineEdit = object(TWidget)
  Text: PShortString;
  Font: PFont;
  MaxLength: Byte;      { Maximum characters (1-255) }
  CursorVisible: Boolean; { Blinking cursor state }
  CursorTimer: Real;    { For cursor blink animation }

  procedure Init(X, Y: Integer; W, H: Word; FontPtr: PFont; MaxLen: Byte);
  procedure SetText(const NewText: string);
  function GetText: string;
  procedure Clear;
  procedure HandleEvent(var Event: TEvent); virtual;
  procedure Render(FrameBuffer: PFrameBuffer; var Style: TUIStyle); virtual;
  procedure Update(DeltaTime: Real); { For cursor blinking }
  procedure Done; virtual;
end;
```

**Behavior:**
- Interactive (can receive focus)
- Renders 3D panel using UIManager.Style.RenderPanel (Pressed=False) + text + blinking cursor
- Focused: outer border drawn with UIManager.Style.FocusColor (palette animated)
- Cursor always at end of text (no navigation)
- Responds to:
  - **Printable keys (A-Z, 0-9, Space, etc.)**: Append character if Length < MaxLength
  - **Backspace**: Delete last character
  - **Enter**: Fires EventHandler (for "submit" behavior)
- Cursor blinks every 0.5 seconds when focused
- Text auto-scrolls left if wider than widget width
- Text color determined by font image
- Uses Style.RenderPanel for consistent 3D beveled appearance

**Character Input:**
- Use KEYBOARD.PAS scancodes + shift state to convert to ASCII
- Accept: A-Z (auto-uppercase or use shift), 0-9, space, basic punctuation
- Reject: function keys, arrows, special keys

**Rendering:**
```
┌─────────────────┐
│ UserName_       │  ← Border, text, blinking cursor
└─────────────────┘
```

**Text Scrolling:**
- If text width > widget width - 8px (padding):
  - Calculate visible substring from right (show end of text)
  - Render only visible portion
- Else: Render full text left-aligned with 4px padding

## UI Manager

### TUIManager
```pascal
TUIManager = object
  Widgets: TLinkedList;      { From LINKLIST.PAS }
  FocusedWidget: PWidget;    { Currently focused widget (nil if none) }
  BackBuffer: PFrameBuffer;  { Target framebuffer for rendering }
  Style: TUIStyle;           { Theme/style for all widgets }

  procedure Init(FrameBuffer: PFrameBuffer);
  procedure AddWidget(Widget: PWidget);
  procedure RemoveWidget(Widget: PWidget);
  procedure SetFocus(Widget: PWidget);
  procedure FocusNext;       { Tab: move focus to next enabled widget }
  procedure FocusPrev;       { Shift+Tab: move focus to previous }
  procedure HandleEvent(var Event: TEvent);
  procedure RenderAll;       { Render all visible widgets }
  procedure SetStyle(const NewStyle: TUIStyle); { Configure theme - accepts custom TUIStyle subclasses }
  procedure Done;
end;
```

**Focus Management:**
- Only one widget can have focus at a time
- Tab/Shift+Tab cycles through enabled widgets
- Focus order = order added to list (insertion order)
- Labels cannot receive focus (Enabled = False by default)
- Focus indicated by border (DrawRect) using Style.FocusColor
- Focus color can be palette animated externally for fade in/out effect

**Theming:**
- SetStyle accepts TUIStyle instance (can be custom subclass with overridden RenderPanel)
- Allows complete customization of panel rendering (bevels, flat, gradients, etc.)
- Widgets call UIManager.Style.RenderPanel for consistent appearance

## Focus Animation

**Palette Animation for Focus:**
- Focus border color (UIManager.Style.FocusColor) can be animated via palette rotation
- Use VGA.PAS `RotatePalette` to fade the focus color in/out for pulsing effect
- Animation handled externally in main loop (not inside VGAUI)
- Typical implementation: fade between two brightness levels every 0.3-0.5 seconds

**Example Animation:**
```pascal
{ In main loop }
FocusFadeTimer := FocusFadeTimer + DeltaTime;
if FocusFadeTimer > 0.4 then
begin
  FocusFadeTimer := 0;
  { Rotate palette index 14 between bright yellow and dim yellow }
  RotatePalette(14, 1, 1);  { Pseudo-code for palette cycling }
end;
```

**Benefits:**
- Smooth visual feedback without redrawing widgets
- Hardware-accelerated (VGA palette registers)
- Works on 8MHz 286 without performance impact
- No per-frame rendering cost

## Event Flow

```
Keyboard Input (KEYBOARD.PAS)
         ↓
   Game/App Code
         ↓
   TUIManager.HandleEvent
         ↓
   Focused Widget.HandleEvent
         ↓
   Widget's EventHandler (if set)
```

**Example:**
```pascal
var
  Event: TEvent;
begin
  if IsKeyPressed(Key_Enter) then
  begin
    Event.EventType := Event_KeyPress;
    Event.KeyCode := Key_Enter;
    Event.Handled := False;
    UIManager.HandleEvent(Event);
    if Event.Handled then
      { Widget processed it, don't handle in game code }
  end;
end;
```

## Rendering Strategy

**Dirty Rectangle Integration:**
- Each widget knows its bounding rectangle
- Widget.Render draws to BackBuffer
- Caller responsible for adding dirty rect via VGA's dirty rect system
- Render order = list traversal order (first added = back, last added = front)

**Typical Usage:**
```pascal
procedure RenderUI;
var
  Node: PListNode;
  Widget: PWidget;
  R: TRectangle;
begin
  Node := UIManager.Widgets.Head;
  while Node <> nil do
  begin
    Widget := PWidget(Node^.Data);
    if Widget^.Visible then
    begin
      Widget^.Render(BackBuffer, UIManager.Style);
      R := Widget^.Rectangle;
      AddDirtyRect(R);  { From your dirty rect system }
    end;
    Node := Node^.Next;
  end;
end;
```

**Note:** Widgets receive Style as var parameter to access RenderPanel method and theme colors.

## Memory Management

**Widget Lifecycle:**
```pascal
{ 1. Allocate }
New(MyButton);

{ 2. Initialize }
MyButton^.Init(x, y, w, h, 'Click Me', @MyFont);
MyButton^.SetEventHandler(@OnButtonClick);

{ 3. Register }
UIManager.AddWidget(MyButton);

{ 4. Use }
{ ... events, rendering ... }

{ 5. Cleanup }
UIManager.RemoveWidget(MyButton);
MyButton^.Done;
Dispose(MyButton);
```

**Important:**
- Widgets must be heap-allocated (New/Dispose)
- Text strings are copied (allocated in Init, freed in Done)
- Font/Image pointers are NOT owned (caller manages lifetime)
- UIManager.Done does NOT free widgets (caller responsibility)

## Event Handler Examples

### Button Click
```pascal
{$F+}
procedure OnPlayButtonClick(var Widget: TWidget; var Event: TEvent);
begin
  if (Event.EventType = Event_KeyPress) and
     ((Event.KeyCode = Key_Enter) or (Event.KeyCode = Key_Space)) then
  begin
    StartGame;  { Your game function }
    Event.Handled := True;
  end;
end;
{$F-}
```

### Checkbox Toggle
```pascal
{$F+}
procedure OnSoundCheckbox(var Widget: TWidget; var Event: TEvent);
var
  CB: PCheckbox;
begin
  if Event.EventType = Event_KeyPress then
  begin
    CB := PCheckbox(@Widget);  { Cast to checkbox }
    if CB^.IsChecked then
      EnableSound
    else
      DisableSound;
    Event.Handled := True;
  end;
end;
{$F-}
```

### Text Input Submit
```pascal
{$F+}
procedure OnNameLineEditSubmit(var Widget: TWidget; var Event: TEvent);
var
  Input: PLineEdit;
  PlayerName: string;
begin
  if (Event.EventType = Event_KeyPress) and (Event.KeyCode = Key_Enter) then
  begin
    Input := PLineEdit(@Widget);  { Cast to input }
    PlayerName := Input^.GetText;
    if Length(PlayerName) > 0 then
    begin
      SavePlayerName(PlayerName);  { Your game function }
      Event.Handled := True;
    end;
  end;
end;
{$F-}
```

## Implementation Order

### Phase 1: Core Types
1. TEvent, TEventType, TEventHandler types
2. TUIStyle object (Init, RenderPanel)
3. TWidget base object (Init, HandleEvent, Done)
4. Basic pointer types (PWidget, PLabel, PButton, PCheckbox, PLineEdit, PUIStyle)

### Phase 2: TLabel
1. Implement TLabel.Init/Done (string allocation)
2. Implement TLabel.Render (use VGAFont.PrintFontText)
3. Test standalone label rendering

### Phase 3: TButton
1. Implement TButton.Init/Done
2. Implement TButton.Render (use UIManager.Style.RenderPanel + centered text)
3. Implement TButton.HandleEvent (Enter/Space detection)
4. Test button focus and events, verify 3D panel rendering

### Phase 4: TCheckbox
1. Implement TCheckbox.Init/Done
2. Implement TCheckbox.Render (PutImageRect + text)
3. Implement TCheckbox.HandleEvent (Space to toggle)
4. Create test checkbox sprites (PCX with 2 rows)

### Phase 5: TLineEdit
1. Implement TLineEdit.Init/Done (string allocation)
2. Implement TLineEdit.Render (use UIManager.Style.RenderPanel + text + cursor)
3. Implement TLineEdit.HandleEvent (character input, backspace)
4. Implement TLineEdit.Update (cursor blink timing)
5. Implement scancode to ASCII conversion
6. Test text input, max length, scrolling, verify 3D panel rendering

### Phase 6: UI Manager
1. Implement TUIManager.Init/Done (initialize default Style)
2. Implement SetStyle (accepts TUIStyle instance, copies to internal Style)
3. Implement AddWidget/RemoveWidget (LinkList operations)
4. Implement SetFocus/FocusNext/FocusPrev
5. Implement HandleEvent (dispatch to focused widget)
6. Implement RenderAll (widgets call UIManager.Style.RenderPanel)

### Phase 7: Testing
1. Create UITEST.PAS with all widget types
2. Test keyboard navigation (Tab, Enter, Space)
3. Test event handlers
4. Test text input (typing, backspace, max length)
5. Test memory cleanup (no leaks)

## Integration with Existing Systems

**Dependencies:**
- LINKLIST.PAS - widget storage
- VGA.PAS - DrawRect, DrawFillRect, framebuffers
- VGAFONT.PAS - text rendering (PrintFontText, GetTextWidth)
- KEYBOARD.PAS - keyboard input (IsKeyPressed, Key_* constants)
- GENTYPES.PAS - PShortString if needed

**Compatibility:**
- Works with dirty rectangle system (caller adds rects)
- Works with existing font loading (XICLONE fonts can be reused)
- Does NOT use mouse (keyboard-only as specified)
- Does NOT handle clipping (assumes widgets fit in screen)

## Usage Example: Simple Menu

```pascal
var
  UI: TUIManager;
  TitleLabel: PLabel;
  PlayButton: PButton;
  SoundCheckbox: PCheckbox;
  NameLineEdit: PLineEdit;
  Font: TFont;
  CheckboxImage: TImage;
  DefaultStyle: TUIStyle;

begin
  { Load resources }
  LoadFont('FONT.XML', 'FONT.PCX', Font);
  LoadPCX('CHECKBOX.PCX', CheckboxImage);

  { Initialize UI and style }
  UI.Init(BackBuffer);
  DefaultStyle.Init(15, 7, 8, 14);  { High=white, Normal=gray, Low=dark gray, Focus=yellow }
  UI.SetStyle(DefaultStyle);

  { Create widgets }
  New(TitleLabel);
  TitleLabel^.Init(100, 20, 'Main Menu', @Font);
  UI.AddWidget(TitleLabel);

  New(PlayButton);
  PlayButton^.Init(100, 60, 120, 20, 'Play Game', @Font);
  PlayButton^.SetEventHandler(@OnPlayButtonClick);
  UI.AddWidget(PlayButton);

  New(SoundCheckbox);
  SoundCheckbox^.Init(100, 100, 'Sound Effects', @Font, @CheckboxImage, 16, 16);
  SoundCheckbox^.SetEventHandler(@OnSoundCheckbox);
  UI.AddWidget(SoundCheckbox);

  New(NameLineEdit);
  NameLineEdit^.Init(100, 140, 120, 20, @Font, 20);  { Max 20 chars }
  NameLineEdit^.SetEventHandler(@OnNameLineEditSubmit);
  UI.AddWidget(NameLineEdit);

  { Focus first interactive widget }
  UI.SetFocus(PlayButton);

  { Main loop }
  while Running do
  begin
    if IsKeyPressed(Key_Tab) then
      UI.FocusNext;

    UI.HandleEvent(GetKeyEvent);  { Pseudo-code }
    UI.RenderAll;
    RenderFrameBuffer(BackBuffer);
    ClearKeyPressed;
  end;

  { Cleanup }
  UI.RemoveWidget(TitleLabel); TitleLabel^.Done; Dispose(TitleLabel);
  UI.RemoveWidget(PlayButton); PlayButton^.Done; Dispose(PlayButton);
  UI.RemoveWidget(SoundCheckbox); SoundCheckbox^.Done; Dispose(SoundCheckbox);
  UI.RemoveWidget(NameLineEdit); NameLineEdit^.Done; Dispose(NameLineEdit);
  UI.Done;
  FreeFont(Font);
  FreeImage(CheckboxImage);
end;
```

## Design Rationale

**Why objects, not records?**
- Virtual methods for polymorphism (Render, HandleEvent)
- Cleaner inheritance (TButton IS-A TWidget)
- Method pointers for event handlers

**Why pointers for Text/Font?**
- Text: Avoids 255-byte strings on stack, allows dynamic content
- Font/Image: Shared resources, not owned by widget

**Why linked list, not array?**
- Dynamic widget count (no MAX_WIDGETS limit)
- Efficient insertion/removal
- Easy traversal for focus management

**Why keyboard-only?**
- DOS mouse support is limited
- Consistent with retro game UX (arrow keys + Enter)
- Simpler implementation
- Can add mouse later without breaking API

**Why no automatic rendering?**
- Caller controls when UI renders (game vs menu)
- Integrates with existing dirty rect system
- Avoids hidden state/side effects

## Performance Considerations

**Rendering:**
- Label: 1× PrintFontText call (~500 cycles per character)
- Button: 1× DrawRect + 1× PrintFontText (~2000 cycles)
- Checkbox: 1× PutImageRect + 1× PrintFontText (~3000 cycles)
- Input: 1× DrawRect + 1× PrintFontText + cursor (~2500 cycles)

**Event Handling:**
- Single linked list traversal to find focused widget
- Max 10-20 widgets per screen → negligible overhead
- Scancode to ASCII conversion: ~100 cycles per keypress

**Memory:**
- TWidget: ~16 bytes
- TLabel: ~24 bytes + string length
- TButton: ~28 bytes + string length
- TCheckbox: ~36 bytes + string length
- TLineEdit: ~32 bytes + string length (max 255)
- Typical menu: 5-10 widgets = ~300-500 bytes total

## Future Enhancements (Not in v1)

- Mouse support (click to focus, click buttons)
- List/menu widget (TListBox)
- Panel/container widget (TPanel)
- Image widget (TImageBox)
- Progress bar (TProgressBar)
- Clipping support for scrollable containers
- Z-order management (bring to front)
- Modal dialogs
- Custom TUIStyle subclasses for advanced themes

## Testing Strategy

**Unit Tests (UITEST.PAS):**
1. Create each widget type, verify rendering
2. Test focus navigation (Tab through widgets)
3. Test event handlers (Enter on button, Space on checkbox)
4. Test text input (typing, backspace, max length, cursor blink)
5. Test keyboard edge cases (Tab on last widget wraps to first)
6. Test memory cleanup (valgrind-style manual checking)

**Integration Tests (XICLONE menu):**
1. Verify pause dialog works with VGAUI
2. Verify settings screen with checkboxes
3. Verify game over screen with replay button

## Acceptance Criteria

- [ ] All 4 widget types (Label, Button, Checkbox, Input) render correctly
- [ ] Tab/Shift+Tab cycles focus through enabled widgets
- [ ] Enter triggers button event handlers
- [ ] Space toggles checkbox state
- [ ] Text input accepts typing, backspace, respects max length
- [ ] Cursor blinks in focused input field
- [ ] Event.Handled prevents double-processing
- [ ] No memory leaks (all widgets properly freed)
- [ ] Works at 8MHz 286 (60+ FPS for typical menu)
- [ ] Integrates with VGAFont (all font features work)
- [ ] Code compiles with Turbo Pascal 7.0 in DOS
