unit Mouse;

{$G+}  { Enable 286 instructions }

interface

{ Mouse button constants }
const
  MouseButton_Left   = $01;
  MouseButton_Right  = $02;
  MouseButton_Middle = $04;

{ Initialize mouse driver and reset to defaults }
function InitMouse: Boolean;

{ Show/hide mouse cursor }
procedure ShowMouse;
procedure HideMouse;

{ Update mouse state (call once per frame) }
procedure UpdateMouse;

{ Get current mouse position (0-319, 0-199 for Mode 13h) }
function GetMouseX: Word;
function GetMouseY: Word;

{ Get button states }
function GetMouseButtons: Byte;
function IsMouseButtonDown(Button: Byte): Boolean;

{ Cleanup mouse driver }
procedure DoneMouse;

{ Set horizontal cursor range }
procedure SetMouseRangeX(MinX, MaxX: Word);

{ Set vertical cursor range }
procedure SetMouseRangeY(MinY, MaxY: Word);

implementation

var
  MouseInstalled: Boolean;
  MouseX: Word;
  MouseY: Word;
  MouseButtons: Byte;
  CursorVisible: Boolean;
  CursorCount: Integer;

{ Helper: Detect mouse driver }
function DetectMouse: Boolean; assembler;
asm
  xor ax, ax           { AX = 0: Reset mouse }
  int 33h
  cmp ax, 0FFFFh       { AX = FFFFh if mouse driver installed }
  je @installed
  xor al, al           { Return False }
  jmp @done
@installed:
  mov al, 1            { Return True }
@done:
end;

{ Initialize mouse driver }
function InitMouse: Boolean;
begin
  MouseInstalled := DetectMouse;
  InitMouse := MouseInstalled;
  if MouseInstalled then
  begin
    { Initialize position }
    UpdateMouse;
  end;
end;

{ Show mouse cursor }
procedure ShowMouse; assembler;
asm
  mov ax, 1            { AX = 1: Show cursor }
  int 33h
end;

{ Hide mouse cursor }
procedure HideMouse; assembler;
asm
  mov ax, 2            { AX = 2: Hide cursor }
  int 33h
end;

{ Set horizontal cursor range }
procedure SetMouseRangeX(MinX, MaxX: Word); assembler;
asm
  mov ax, 7            { AX = 7: Set horizontal min/max }
  mov cx, MinX
  mov dx, MaxX
  int 33h
end;

{ Set vertical cursor range }
procedure SetMouseRangeY(MinY, MaxY: Word); assembler;
asm
  mov ax, 8            { AX = 8: Set vertical min/max }
  mov cx, MinY
  mov dx, MaxY
  int 33h
end;

{ Get mouse position and button state }
procedure GetMouseState(var X, Y: Word; var Buttons: Byte); assembler;
asm
  push ds
  mov ax, 3            { AX = 3: Get position and button status }
  int 33h

  { BX = button state, CX = X position, DX = Y position }
  { Store button state }
  les di, Buttons
  mov es:[di], bl

  { Store X position (scale from virtual 640 to 320 for Mode 13h) }
  les di, X
  mov ax, cx
  shr ax, 1            { Divide by 2: 640 virtual -> 320 actual }
  mov es:[di], ax

  { Store Y position (already in 0-199 range) }
  les di, Y
  mov es:[di], dx

  pop ds
end;

{ Update mouse state - call once per frame }
procedure UpdateMouse;
begin
  if not MouseInstalled then
    Exit;
  GetMouseState(MouseX, MouseY, MouseButtons);
end;

{ Get current mouse X position }
function GetMouseX: Word;
begin
  GetMouseX := MouseX;
end;

{ Get current mouse Y position }
function GetMouseY: Word;
begin
  GetMouseY := MouseY;
end;

{ Get button states }
function GetMouseButtons: Byte;
begin
  GetMouseButtons := MouseButtons;
end;

{ Check if specific button is down }
function IsMouseButtonDown(Button: Byte): Boolean;
begin
  IsMouseButtonDown := (MouseButtons and Button) <> 0;
end;

{ Cleanup mouse driver }
procedure DoneMouse;
begin
  if MouseInstalled then
  begin
    { Hide cursor before cleanup }
    if CursorVisible then
      HideMouse;
    MouseInstalled := False;
  end;
end;

{ Unit initialization }
begin
  MouseInstalled := False;
  MouseX := 0;
  MouseY := 0;
  MouseButtons := 0;
  CursorVisible := False;
  CursorCount := 0;
end.
