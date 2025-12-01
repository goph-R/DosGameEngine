# MOUSE.PAS - API Documentation

DOS mouse driver support via INT 33h for VGA Mode 13h.

## Table of Contents

- [Overview](#overview)
- [Constants](#constants)
- [Functions](#functions)
- [Common Usage Patterns](#common-usage-patterns)
- [Important Notes](#important-notes)

---

## Overview

MOUSE.PAS provides mouse input support using the DOS mouse driver (INT 33h). It automatically handles coordinate scaling for VGA Mode 13h (320×200) and provides simple button state checking.

**Key features:**
- **DOS mouse driver** - Uses standard INT 33h interface
- **Automatic scaling** - Virtual 640 coordinates → 320 actual (Mode 13h)
- **3-button support** - Left, right, and middle buttons
- **Cursor control** - Show/hide hardware cursor
- **Range limiting** - Set cursor movement boundaries

**Requirements:**
- **MOUSE.COM or MOUSE.SYS** - DOS mouse driver must be loaded
- **VGA Mode 13h** - Coordinate scaling optimized for 320×200

---

## Constants

### Button Constants

```pascal
const
  MouseButton_Left   = $01;
  MouseButton_Right  = $02;
  MouseButton_Middle = $04;
```

**Usage:**
```pascal
{ Check single button }
if IsMouseButtonDown(MouseButton_Left) then
  FireWeapon;

{ Check multiple buttons (bitwise AND) }
if (GetMouseButtons and MouseButton_Right) <> 0 then
  OpenMenu;
```

---

## Functions

### InitMouse

```pascal
function InitMouse: Boolean;
```

Initializes mouse driver and detects presence.

**Returns:** `True` if mouse driver is installed, `False` otherwise.

**Example:**
```pascal
begin
  if not InitMouse then
  begin
    WriteLn('Error: Mouse driver not found!');
    WriteLn('Please load MOUSE.COM or MOUSE.SYS');
    Halt(1);
  end;

  { Mouse is ready to use }
  ShowMouse;
end;
```

**CRITICAL:**
- **MUST** be called before any other mouse functions
- Returns `False` if MOUSE.COM/MOUSE.SYS not loaded
- Automatically calls `UpdateMouse` to initialize position

---

### ShowMouse

```pascal
procedure ShowMouse;
```

Shows the hardware mouse cursor.

**Example:**
```pascal
begin
  InitMouse;
  ShowMouse;  { Cursor now visible }

  { Game/program code... }
end;
```

**Note:**
- Cursor is rendered by BIOS, not your program
- For custom cursors, keep hardware cursor hidden and draw your own

---

### HideMouse

```pascal
procedure HideMouse;
```

Hides the hardware mouse cursor.

**Example:**
```pascal
begin
  InitMouse;
  ShowMouse;

  { Hide before drawing to prevent artifacts }
  HideMouse;
  DrawCustomCursor(GetMouseX, GetMouseY);
end;
```

**Use cases:**
- Custom cursor rendering
- Cutscenes or menus without cursor
- Preventing cursor flicker during rendering

---

### UpdateMouse

```pascal
procedure UpdateMouse;
```

Updates mouse position and button state. **MUST** be called once per frame before reading mouse data.

**Example:**
```pascal
while GameRunning do
begin
  { Update mouse state FIRST }
  UpdateMouse;

  { Now read position and buttons }
  X := GetMouseX;
  Y := GetMouseY;

  if IsMouseButtonDown(MouseButton_Left) then
    HandleClick(X, Y);

  { Render game... }
end;
```

**CRITICAL:**
- **Call once per frame** at the start of your game loop
- Reading position/buttons without `UpdateMouse` gives stale data
- Safe to call multiple times, but unnecessary

---

### GetMouseX

```pascal
function GetMouseX: Word;
```

Returns current mouse X position (0-319 for Mode 13h).

**Returns:** X coordinate in pixels (0-319).

**Example:**
```pascal
var
  X: Word;

begin
  UpdateMouse;
  X := GetMouseX;

  { Draw cursor at mouse position }
  PutImage(CursorImage, X, GetMouseY, True, FrameBuffer);
end;
```

**Coordinate Range:**
- **Mode 13h**: 0-319 (320 pixels wide)
- Automatically scaled from virtual 640 coordinates

---

### GetMouseY

```pascal
function GetMouseY: Word;
```

Returns current mouse Y position (0-199 for Mode 13h).

**Returns:** Y coordinate in pixels (0-199).

**Example:**
```pascal
var
  Y: Word;

begin
  UpdateMouse;
  Y := GetMouseY;

  { Check if mouse is in top menu bar }
  if Y < 20 then
    HandleMenuHover;
end;
```

**Coordinate Range:**
- **Mode 13h**: 0-199 (200 pixels tall)
- No scaling needed (already in correct range)

---

### GetMouseButtons

```pascal
function GetMouseButtons: Byte;
```

Returns button state byte (bitwise combination of button flags).

**Returns:** Byte with button bits set (bit 0=left, bit 1=right, bit 2=middle).

**Example:**
```pascal
var
  Buttons: Byte;

begin
  UpdateMouse;
  Buttons := GetMouseButtons;

  { Check left button }
  if (Buttons and MouseButton_Left) <> 0 then
    WriteLn('Left button down');

  { Check multiple buttons }
  if (Buttons and (MouseButton_Left or MouseButton_Right)) <> 0 then
    WriteLn('Left or Right button down');
end;
```

**Bit Layout:**
```
Bit 0 ($01): Left button
Bit 1 ($02): Right button
Bit 2 ($04): Middle button
Bits 3-7: Unused
```

---

### IsMouseButtonDown

```pascal
function IsMouseButtonDown(Button: Byte): Boolean;
```

Checks if a specific button is currently pressed.

**Parameters:**
- `Button` - Button constant (`MouseButton_Left`, `MouseButton_Right`, `MouseButton_Middle`)

**Returns:** `True` if button is down, `False` otherwise.

**Example:**
```pascal
begin
  UpdateMouse;

  { Left click to fire }
  if IsMouseButtonDown(MouseButton_Left) then
    FireWeapon;

  { Right click to open menu }
  if IsMouseButtonDown(MouseButton_Right) then
    OpenContextMenu;

  { Middle click to pan }
  if IsMouseButtonDown(MouseButton_Middle) then
    PanView;
end;
```

**Behavior:**
- Returns `True` while button is **held down** (continuous input)
- Use for drag operations, continuous firing, etc.
- For single-click detection, track previous frame state

---

### SetMouseRangeX

```pascal
procedure SetMouseRangeX(MinX, MaxX: Word);
```

Sets horizontal cursor movement range.

**Parameters:**
- `MinX` - Minimum X coordinate
- `MaxX` - Maximum X coordinate

**Example:**
```pascal
begin
  InitMouse;

  { Restrict mouse to left half of screen }
  SetMouseRangeX(0, 159);

  { Restore full range }
  SetMouseRangeX(0, 319);
end;
```

**Use cases:**
- Confine cursor to menu area
- Split-screen multiplayer boundaries
- Prevent cursor from leaving game area

---

### SetMouseRangeY

```pascal
procedure SetMouseRangeY(MinY, MaxY: Word);
```

Sets vertical cursor movement range.

**Parameters:**
- `MinY` - Minimum Y coordinate
- `MaxY` - Maximum Y coordinate

**Example:**
```pascal
begin
  InitMouse;

  { Restrict mouse to top menu bar }
  SetMouseRangeY(0, 19);

  { Restore full range }
  SetMouseRangeY(0, 199);
end;
```

---

### DoneMouse

```pascal
procedure DoneMouse;
```

Cleanup mouse driver (hides cursor).

**Example:**
```pascal
begin
  InitMouse;
  ShowMouse;

  { Game code... }

  DoneMouse;  { Hide cursor before exit }
end;
```

**Behavior:**
- Hides cursor if visible
- Resets internal state
- Safe to call even if mouse not initialized

**Note:**
- Not strictly required (no interrupt hooks to restore)
- Good practice for clean exit

---

## Common Usage Patterns

### Basic Mouse Input Loop

```pascal
uses Crt, VGA, Mouse, Keyboard;

var
  GameRunning: Boolean;
  MouseX, MouseY: Word;

begin
  InitVGA;
  InitMouse;
  InitKeyboard;
  ShowMouse;

  GameRunning := True;
  while GameRunning do
  begin
    { Update mouse state }
    UpdateMouse;

    { Get position }
    MouseX := GetMouseX;
    MouseY := GetMouseY;

    { Handle input }
    if IsMouseButtonDown(MouseButton_Left) then
      WriteLn('Click at ', MouseX, ', ', MouseY);

    if IsKeyPressed(Key_Escape) then
      GameRunning := False;

    ClearKeyPressed;
  end;

  DoneMouse;
  DoneKeyboard;
  CloseVGA;
end.
```

---

### Click Detection (Single-Click)

```pascal
var
  PrevButtons: Byte;
  CurrButtons: Byte;
  LeftClicked: Boolean;

begin
  PrevButtons := 0;

  while GameRunning do
  begin
    UpdateMouse;
    CurrButtons := GetMouseButtons;

    { Detect left button press (edge detection) }
    LeftClicked := ((CurrButtons and MouseButton_Left) <> 0) and
                   ((PrevButtons and MouseButton_Left) = 0);

    if LeftClicked then
      HandleClick(GetMouseX, GetMouseY);

    { Save for next frame }
    PrevButtons := CurrButtons;
  end;
end;
```

---

### Drag and Drop

```pascal
var
  Dragging: Boolean;
  DragStartX, DragStartY: Word;
  DragEndX, DragEndY: Word;

begin
  Dragging := False;

  while GameRunning do
  begin
    UpdateMouse;

    { Start drag on left button press }
    if IsMouseButtonDown(MouseButton_Left) and not Dragging then
    begin
      Dragging := True;
      DragStartX := GetMouseX;
      DragStartY := GetMouseY;
    end;

    { Update drag }
    if Dragging then
    begin
      DragEndX := GetMouseX;
      DragEndY := GetMouseY;

      { Draw drag rectangle }
      DrawRect(DragStartX, DragStartY, DragEndX, DragEndY);
    end;

    { End drag on button release }
    if not IsMouseButtonDown(MouseButton_Left) and Dragging then
    begin
      Dragging := False;
      HandleDrop(DragStartX, DragStartY, DragEndX, DragEndY);
    end;
  end;
end;
```

---

### Custom Cursor Rendering

```pascal
uses VGA, PCX, Mouse;

var
  CursorImage: TImage;
  FrameBuffer: PFrameBuffer;
  MouseX, MouseY: Word;

begin
  InitVGA;
  InitMouse;
  LoadPCX('CURSOR.PCX', CursorImage);

  { Hide hardware cursor }
  HideMouse;

  FrameBuffer := CreateFrameBuffer;

  while GameRunning do
  begin
    UpdateMouse;
    MouseX := GetMouseX;
    MouseY := GetMouseY;

    { Clear and draw scene }
    ClearFrameBuffer(FrameBuffer);
    DrawScene(FrameBuffer);

    { Draw custom cursor on top }
    PutImage(CursorImage, MouseX, MouseY, True, FrameBuffer);

    { Blit to screen }
    WaitForVSync;
    RenderFrameBuffer(FrameBuffer);
  end;

  FreeImage(CursorImage);
  FreeFrameBuffer(FrameBuffer);
  DoneMouse;
  CloseVGA;
end.
```

---

### Menu System with Mouse

```pascal
type
  TButton = record
    X, Y, Width, Height: Integer;
    Text: string;
  end;

var
  Buttons: array[0..2] of TButton;

function IsMouseOverButton(const Btn: TButton; MouseX, MouseY: Word): Boolean;
begin
  IsMouseOverButton :=
    (MouseX >= Btn.X) and (MouseX < Btn.X + Btn.Width) and
    (MouseY >= Btn.Y) and (MouseY < Btn.Y + Btn.Height);
end;

var
  i: Integer;
  MouseX, MouseY: Word;
  PrevButtons, CurrButtons: Byte;
  LeftClicked: Boolean;

begin
  { Setup buttons }
  Buttons[0].X := 100; Buttons[0].Y := 50;
  Buttons[0].Width := 120; Buttons[0].Height := 30;
  Buttons[0].Text := 'Start Game';

  Buttons[1].X := 100; Buttons[1].Y := 90;
  Buttons[1].Width := 120; Buttons[1].Height := 30;
  Buttons[1].Text := 'Options';

  Buttons[2].X := 100; Buttons[2].Y := 130;
  Buttons[2].Width := 120; Buttons[2].Height := 30;
  Buttons[2].Text := 'Exit';

  InitMouse;
  ShowMouse;
  PrevButtons := 0;

  while MenuActive do
  begin
    UpdateMouse;
    MouseX := GetMouseX;
    MouseY := GetMouseY;
    CurrButtons := GetMouseButtons;

    { Detect click }
    LeftClicked := ((CurrButtons and MouseButton_Left) <> 0) and
                   ((PrevButtons and MouseButton_Left) = 0);

    { Check button clicks }
    if LeftClicked then
    begin
      for i := 0 to 2 do
      begin
        if IsMouseOverButton(Buttons[i], MouseX, MouseY) then
        begin
          case i of
            0: StartGame;
            1: ShowOptions;
            2: MenuActive := False;
          end;
        end;
      end;
    end;

    { Highlight hovered button }
    for i := 0 to 2 do
    begin
      if IsMouseOverButton(Buttons[i], MouseX, MouseY) then
        DrawButton(Buttons[i], True)   { Highlighted }
      else
        DrawButton(Buttons[i], False);  { Normal }
    end;

    PrevButtons := CurrButtons;
  end;

  DoneMouse;
end;
```

---

## Important Notes

### CRITICAL Rules

1. **Load MOUSE.COM/MOUSE.SYS** - Driver must be loaded before InitMouse
2. **Call UpdateMouse every frame** - Required for accurate position/button data
3. **Update before reading** - Always call UpdateMouse before GetMouseX/GetMouseY
4. **Hide cursor when drawing** - Prevents artifacts with custom cursor rendering

### Coordinate Scaling

- **DOS mouse driver** reports virtual 640×200 coordinates
- **MOUSE.PAS** automatically scales X coordinate: `X / 2` (640 → 320)
- **Y coordinate** already in 0-199 range (no scaling needed)

### Button State

- `IsMouseButtonDown` returns `True` while button is **held**
- For single-click detection, implement edge detection (check previous frame)
- Multiple buttons can be down simultaneously

### Hardware Cursor

- **Rendered by BIOS** - Not part of your framebuffer
- **Cannot customize** appearance easily
- **Hide for custom cursor** - Draw your own using PutImage

---

## Performance Notes

- **Minimal overhead** - INT 33h call is very fast (~microseconds)
- **No polling** - Driver handles hardware interrupt
- **One update per frame** - Sufficient for smooth cursor tracking
- **No memory allocation** - All state in static variables

---

## Compatibility

- **DOS only** - Requires DOS mouse driver (MOUSE.COM or MOUSE.SYS)
- **Turbo Pascal 7.0** - Uses assembly for INT 33h calls
- **All VGA modes** - But coordinate scaling optimized for Mode 13h
- **DOSBox** - Mouse support enabled by default

---

## Troubleshooting

### InitMouse returns False
- **Solution**: Load MOUSE.COM before running your program
- **DOSBox**: Mouse driver is built-in (no action needed)
- **FreeDOS**: Add `DEVICE=MOUSE.SYS` to CONFIG.SYS

### Cursor position is wrong
- **Check**: Did you call `UpdateMouse` this frame?
- **Check**: Are you in VGA Mode 13h? (Scaling assumes 320×200)

### Cursor flickers or leaves artifacts
- **Solution**: Hide hardware cursor, draw custom cursor
- **Pattern**:
  ```pascal
  HideMouse;
  { Clear and draw scene }
  DrawCustomCursor(GetMouseX, GetMouseY);
  RenderFrameBuffer(FrameBuffer);
  ```

### Buttons not responding
- **Check**: Call `UpdateMouse` before checking buttons
- **Check**: Use `IsMouseButtonDown` for continuous, or implement edge detection for clicks

---

## See Also

- **[KEYBOARD.md](KEYBOARD.md)** - Keyboard input documentation
- **[VGA.md](VGA.md)** - VGA graphics for custom cursor rendering
- **[MOUTEST.PAS](../TESTS/MOUTEST.PAS)** - Mouse input test program with crosshair
