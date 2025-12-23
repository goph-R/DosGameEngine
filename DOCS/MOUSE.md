# MOUSE - DOS Mouse Driver

Mouse input via INT 33h for VGA Mode 13h.

## Constants

```pascal
const
  MouseButton_Left   = $01;
  MouseButton_Right  = $02;
  MouseButton_Middle = $04;
```

## Functions

```pascal
function InitMouse: Boolean;                    { Returns True if driver found }
procedure ShowMouse;
procedure HideMouse;
procedure UpdateMouse;                          { CRITICAL: Call once per frame }
function GetMouseX: Word;                       { 0-319 for Mode 13h }
function GetMouseY: Word;                       { 0-199 for Mode 13h }
function GetMouseButtons: Byte;                 { Bitwise button flags }
function IsMouseButtonDown(Button: Byte): Boolean;
procedure SetMouseRangeX(MinX, MaxX: Word);
procedure SetMouseRangeY(MinY, MaxY: Word);
procedure UseDefaultMouseCursor(Use: Boolean);  { Enable/disable default cursor }
procedure DoneMouse;
```

## Example

```pascal
uses VGA, Mouse, Keyboard;

var
  MouseX, MouseY: Word;
  Running: Boolean;

begin
  InitVGA;

  if not InitMouse then
  begin
    WriteLn('Mouse driver not found! Load MOUSE.COM');
    DoneVGA;
    Halt(1);
  end;

  ShowMouse;
  InitKeyboard;

  Running := True;
  while Running do
  begin
    { Update mouse state FIRST }
    UpdateMouse;

    { Get position }
    MouseX := GetMouseX;
    MouseY := GetMouseY;

    { Handle clicks }
    if IsMouseButtonDown(MouseButton_Left) then
      HandleClick(MouseX, MouseY);

    if IsKeyPressed(Key_Escape) then
      Running := False;

    ClearKeyPressed;
  end;

  DoneMouse;
  DoneKeyboard;
  DoneVGA;
end.
```

## Click Detection

```pascal
var
  PrevButtons, CurrButtons: Byte;
  LeftClicked: Boolean;

begin
  PrevButtons := 0;

  while Running do
  begin
    UpdateMouse;
    CurrButtons := GetMouseButtons;

    { Edge detection - single click }
    LeftClicked := ((CurrButtons and MouseButton_Left) <> 0) and
                   ((PrevButtons and MouseButton_Left) = 0);

    if LeftClicked then
      HandleClick(GetMouseX, GetMouseY);

    PrevButtons := CurrButtons;
  end;
end;
```

## Custom Cursor

```pascal
uses VGA, PCX, Mouse;

var
  CursorImage: TImage;
  BackBuffer: PFrameBuffer;

begin
  InitVGA;
  InitMouse;
  BackBuffer := CreateFrameBuffer;

  LoadPCX('CURSOR.PCX', CursorImage);

  { Disable default cursor - prevents ShowMouse/HideMouse from affecting hardware cursor }
  UseDefaultMouseCursor(False);

  while Running do
  begin
    UpdateMouse;

    ClearFrameBuffer(BackBuffer);
    DrawScene(BackBuffer);

    { Draw custom cursor }
    PutImage(GetMouseX, GetMouseY, @CursorImage, BackBuffer);

    WaitForVSync;
    RenderFrameBuffer(BackBuffer);
  end;

  FreeImage(CursorImage);
  FreeFrameBuffer(BackBuffer);
  DoneMouse;
  DoneVGA;
end.
```

## Critical Notes

1. **MOUSE.COM/MOUSE.SYS** - Driver must be loaded before InitMouse
2. **UpdateMouse** - MUST call once per frame before reading position/buttons
3. **Coordinate scaling** - X auto-scaled from 640→320 for Mode 13h
4. **IsMouseButtonDown** - Returns True while held (continuous input)
5. **Edge detection** - Implement manually for single-click detection

## Notes

- Hardware cursor rendered by BIOS (not in framebuffer)
- UseDefaultMouseCursor(False) disables ShowMouse/HideMouse (useful for custom cursors or UI systems that manage cursor visibility)
- SetMouseRangeX/Y to confine cursor to specific area
- Compatible with DOSBox (mouse enabled by default)
