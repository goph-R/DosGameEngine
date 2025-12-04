# KEYBOARD - INT 9h Handler

Hardware keyboard handler via INT 9h interrupt.

## Constants

### Common Keys

```pascal
const
  { Letters }
  Key_A = $1E;  Key_B = $30;  Key_C = $2E;  Key_D = $20;
  Key_E = $12;  Key_F = $21;  Key_G = $22;  Key_H = $23;
  Key_I = $17;  Key_J = $24;  Key_K = $25;  Key_L = $26;
  Key_M = $32;  Key_N = $31;  Key_O = $18;  Key_P = $19;
  Key_Q = $10;  Key_R = $13;  Key_S = $1F;  Key_T = $14;
  Key_U = $16;  Key_V = $2F;  Key_W = $11;  Key_X = $2D;
  Key_Y = $15;  Key_Z = $2C;

  { Numbers }
  Key_1 = $02;  Key_2 = $03;  Key_3 = $04;  Key_4 = $05;
  Key_5 = $06;  Key_6 = $07;  Key_7 = $08;  Key_8 = $09;
  Key_9 = $0A;  Key_0 = $0B;

  { Function keys }
  Key_F1 = $3B;  Key_F2 = $3C;  Key_F3 = $3D;  Key_F4 = $3E;
  Key_F5 = $3F;  Key_F6 = $40;  Key_F7 = $41;  Key_F8 = $42;
  Key_F9 = $43;  Key_F10 = $44; Key_F11 = $57; Key_F12 = $58;

  { Special }
  Key_Escape = $01;  Key_Enter = $1C;  Key_Space = $39;
  Key_Backspace = $0E;  Key_Tab = $0F;

  { Arrows }
  Key_Up = $48;  Key_Down = $50;  Key_Left = $4B;  Key_Right = $4D;

  { Modifiers }
  Key_LShift = $2A;  Key_RShift = $36;
  Key_LCtrl = $1D;   Key_LAlt = $38;
```

### Character Maps

```pascal
const
  CharMapNormal: array[0..127] of Char;  { Scancode → char }
  CharMapShift: array[0..127] of Char;   { Scancode → char (shifted) }
```

## Functions

```pascal
procedure InitKeyboard;                            { Hook INT 9h }
procedure DoneKeyboard;                            { CRITICAL: Unhook before exit }
function IsKeyDown(ScanCode: Byte): Boolean;       { Key currently held }
function IsKeyPressed(ScanCode: Byte): Boolean;    { Key pressed and released }
procedure ClearKeyPressed;                         { CRITICAL: Call at end of loop }
procedure ClearAllKeyStates;
function WaitForAnyKeyPress: Byte;
```

## Example

```pascal
uses Keyboard;

var
  Running: Boolean;

begin
  InitKeyboard;

  Running := True;
  while Running do
  begin
    { Continuous input - movement }
    if IsKeyDown(Key_W) then PlayerY := PlayerY - 2;
    if IsKeyDown(Key_S) then PlayerY := PlayerY + 2;
    if IsKeyDown(Key_A) then PlayerX := PlayerX - 2;
    if IsKeyDown(Key_D) then PlayerX := PlayerX + 2;

    { Single-press input - actions }
    if IsKeyPressed(Key_Space) then FireWeapon;
    if IsKeyPressed(Key_Escape) then Running := False;

    { Game logic and rendering }
    UpdateGame;
    RenderGame;

    { MUST call at end of loop }
    ClearKeyPressed;
  end;

  DoneKeyboard;  { CRITICAL: Unhook INT 9h }
end.
```

## Text Input

```pascal
var
  InputText: string;
  Shifted: Boolean;
  Ch: Char;
  ScanCode: Byte;

begin
  InitKeyboard;
  InputText := '';

  while InputActive do
  begin
    { Check shift state }
    Shifted := IsKeyDown(Key_LShift) or IsKeyDown(Key_RShift);

    { Scan letter keys }
    for ScanCode := Key_A to Key_Z do
    begin
      if IsKeyPressed(ScanCode) then
      begin
        if Shifted then
          Ch := CharMapShift[ScanCode]
        else
          Ch := CharMapNormal[ScanCode];
        InputText := InputText + Ch;
      end;
    end;

    { Backspace }
    if IsKeyPressed(Key_Backspace) and (Length(InputText) > 0) then
      Delete(InputText, Length(InputText), 1);

    { Enter to finish }
    if IsKeyPressed(Key_Enter) then
      InputActive := False;

    ClearKeyPressed;
  end;

  DoneKeyboard;
end;
```

## Critical Rules

1. **InitKeyboard** - MUST call before using any functions
2. **DoneKeyboard** - MUST call before exit (unhooks INT 9h)
3. **ClearKeyPressed** - MUST call at END of every game loop
4. **IsKeyDown** - Use for continuous input (movement)
5. **IsKeyPressed** - Use for single actions (fire, menu selection)

## IsKeyDown vs IsKeyPressed

**IsKeyDown** - Returns `True` while key is physically held:
```pascal
{ Player moves continuously while W is held }
if IsKeyDown(Key_W) then
  PlayerY := PlayerY - 1;
```

**IsKeyPressed** - Returns `True` once per key press (edge detection):
```pascal
{ Fire weapon once per Space press }
if IsKeyPressed(Key_Space) then
  FireWeapon;
```

## Notes

- Direct hardware access (no BIOS delays)
- Supports multiple simultaneous keys (perfect for games)
- Triggers on key **release** (ensures no quick taps missed)
- CharMapNormal/CharMapShift for ASCII conversion
- Install ExitProc handler to call DoneKeyboard on Ctrl+C
