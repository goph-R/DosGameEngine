# KEYBOARD.PAS - API Documentation

Low-level keyboard handler using INT 9h interrupt for direct hardware access.

## Table of Contents

- [Overview](#overview)
- [Scan Code Constants](#scan-code-constants)
- [Character Maps](#character-maps)
- [Functions](#functions)
- [Common Usage Patterns](#common-usage-patterns)
- [Important Notes](#important-notes)

---

## Overview

KEYBOARD.PAS provides hardware-level keyboard input by hooking INT 9h (keyboard interrupt). This approach offers:

- **No BIOS delays** - Direct hardware access, faster than BIOS
- **Continuous input detection** - Check if key is currently held down
- **Edge detection** - Detect single key presses (fire once on press dowm)
- **Multiple simultaneous keys** - Perfect for games (walk + jump)
- **Scan code based** - Hardware-level key identification

**CRITICAL:** Always call `InitKeyboard` before use and `DoneKeyboard` before exit!

---

## Scan Code Constants

### Letter Keys

```pascal
const
  Key_A = $1E;  Key_B = $30;  Key_C = $2E;  Key_D = $20;
  Key_E = $12;  Key_F = $21;  Key_G = $22;  Key_H = $23;
  Key_I = $17;  Key_J = $24;  Key_K = $25;  Key_L = $26;
  Key_M = $32;  Key_N = $31;  Key_O = $18;  Key_P = $19;
  Key_Q = $10;  Key_R = $13;  Key_S = $1F;  Key_T = $14;
  Key_U = $16;  Key_V = $2F;  Key_W = $11;  Key_X = $2D;
  Key_Y = $15;  Key_Z = $2C;
```

### Number Keys (Top Row)

```pascal
const
  Key_1 = $02;  Key_2 = $03;  Key_3 = $04;  Key_4 = $05;
  Key_5 = $06;  Key_6 = $07;  Key_7 = $08;  Key_8 = $09;
  Key_9 = $0A;  Key_0 = $0B;
```

### Function Keys

```pascal
const
  Key_F1  = $3B;  Key_F2  = $3C;  Key_F3  = $3D;  Key_F4  = $3E;
  Key_F5  = $3F;  Key_F6  = $40;  Key_F7  = $41;  Key_F8  = $42;
  Key_F9  = $43;  Key_F10 = $44;  Key_F11 = $57;  Key_F12 = $58;
```

### Special Keys

```pascal
const
  Key_Escape    = $01;
  Key_Enter     = $1C;
  Key_Space     = $39;
  Key_Backspace = $0E;
  Key_Tab       = $0F;
```

### Arrow Keys

```pascal
const
  Key_Up    = $48;
  Key_Down  = $50;
  Key_Left  = $4B;
  Key_Right = $4D;
```

### Modifier Keys

```pascal
const
  Key_LShift   = $2A;
  Key_RShift   = $36;
  Key_LCtrl    = $1D;
  Key_LAlt     = $38;
  Key_CapsLock = $3A;
```

### Extended Keys

```pascal
const
  Key_Home   = $47;
  Key_End    = $4F;
  Key_PgUp   = $49;
  Key_PgDn   = $51;
  Key_Insert = $52;
  Key_Delete = $53;
```

### Punctuation Keys

```pascal
const
  Key_Minus     = $0C;  { - _ }
  Key_Equals    = $0D;  { = + }
  Key_LBracket  = $1A;  { [ { }
  Key_RBracket  = $1B;  { ] } }
  Key_Semicolon = $27;  { ; : }
  Key_Quote     = $28;  { ' " }
  Key_Backquote = $29;  { ` ~ }
  Key_Backslash = $2B;  { \ | }
  Key_Comma     = $33;  { , < }
  Key_Period    = $34;  { . > }
  Key_Slash     = $35;  { / ? }
```

---

## Character Maps

### CharMapNormal

```pascal
const
  CharMapNormal: array[0..127] of Char;
```

Maps scan codes to unshifted characters. Returns `#0` for non-printable keys.

**Example:**
```pascal
var
  Ch: Char;
begin
  if IsKeyPressed(Key_A) then
    Ch := CharMapNormal[Key_A];  { Ch = 'a' }
end;
```

---

### CharMapShift

```pascal
const
  CharMapShift: array[0..127] of Char;
```

Maps scan codes to shifted characters (Shift key held). Returns `#0` for non-printable keys.

**Example:**
```pascal
var
  Ch: Char;
  Shifted: Boolean;
begin
  Shifted := IsKeyDown(Key_LShift) or IsKeyDown(Key_RShift);

  if IsKeyPressed(Key_A) then
  begin
    if Shifted then
      Ch := CharMapShift[Key_A]  { Ch = 'A' }
    else
      Ch := CharMapNormal[Key_A]; { Ch = 'a' }
  end;
end;
```

---

## Functions

### InitKeyboard

```pascal
procedure InitKeyboard;
```

Initializes keyboard handler by hooking INT 9h. **MUST be called before any keyboard functions.**

**Example:**
```pascal
begin
  InitKeyboard;  { MUST call first! }

  { Your game code }

  DoneKeyboard;  { MUST call before exit! }
end;
```

**CRITICAL:** Failure to call causes all keyboard functions to fail.

---

### DoneKeyboard

```pascal
procedure DoneKeyboard;
```

Restores original INT 9h handler. **MUST be called before program exit.**

**Example:**
```pascal
begin
  InitKeyboard;

  { Game loop }
  while GameRunning do
  begin
    if IsKeyPressed(Key_Escape) then
      GameRunning := False;
  end;

  DoneKeyboard;  { CRITICAL: MUST call before exit! }
end;
```

**CRITICAL:** Failure to call leaves INT 9h pointing to freed memory → system hang!

---

### IsKeyDown

```pascal
function IsKeyDown(ScanCode: Byte): Boolean;
```

Checks if a key is **currently held down**. Returns `True` while key is physically pressed.

**Parameters:**
- `ScanCode` - Scan code constant (e.g., `Key_W`, `Key_Space`)

**Returns:** `True` if key is currently down, `False` otherwise.

**Example:**
```pascal
{ Continuous movement while key is held }
while GameRunning do
begin
  { Move up while W is held }
  if IsKeyDown(Key_W) then
    PlayerY := PlayerY - 1;

  { Move down while S is held }
  if IsKeyDown(Key_S) then
    PlayerY := PlayerY + 1;

  { Multiple simultaneous keys }
  if IsKeyDown(Key_W) and IsKeyDown(Key_Space) then
    WriteLn('Walking and jumping!');

  ClearKeyPressed;  { MUST call at end of loop }
end;
```

**Use cases:**
- Continuous player movement
- Check modifier keys (Shift, Ctrl, Alt)
- Multi-key combos

---

### IsKeyPressed

```pascal
function IsKeyPressed(ScanCode: Byte): Boolean;
```

Checks if a key was **pressed and released** (edge detection). Returns `True` **once** per key press.

**Parameters:**
- `ScanCode` - Scan code constant (e.g., `Key_Enter`, `Key_Escape`)

**Returns:** `True` once on key release, `False` otherwise.

**Example:**
```pascal
{ Single actions - fire once per press }
while GameRunning do
begin
  { Fire weapon (once per press, not continuous) }
  if IsKeyPressed(Key_Space) then
    FireWeapon;

  { Pause/unpause }
  if IsKeyPressed(Key_P) then
    Paused := not Paused;

  { Exit }
  if IsKeyPressed(Key_Escape) then
    GameRunning := False;

  ClearKeyPressed;  { MUST call at end of loop }
end;
```

**Important behavior:**
- Triggers on key **release**, not press (ensures no quick taps are missed)
- Returns `True` only once per press
- Must call `ClearKeyPressed` at end of game loop
- Can call multiple times per frame for same key safely

**Use cases:**
- Menu selection
- Single-shot actions (fire weapon, jump)
- Toggle states (pause, inventory)

---

### ClearKeyPressed

```pascal
procedure ClearKeyPressed;
```

Clears all **checked** key press states. **MUST be called at the end of every game loop.**

**Example:**
```pascal
while GameRunning do
begin
  { Check keys }
  if IsKeyPressed(Key_Space) then
    FireWeapon;

  if IsKeyPressed(Key_Escape) then
    GameRunning := False;

  { Game logic }
  UpdateGame;
  RenderGame;

  { CRITICAL: Call at end of loop }
  ClearKeyPressed;
end;
```

**CRITICAL:**
- **MUST** be called at the **end** of every game loop
- Only clears keys that were checked with `IsKeyPressed`
- Unchecked keys preserve their state for next frame
- Failure to call causes key presses to repeat every frame

---

### ClearAllKeyStates

```pascal
procedure ClearAllKeyStates;
```

Clears all key states (both `KeyDown` and `KeyPressed`).

**Example:**
```pascal
{ Clear all keys when switching to menu }
procedure ShowPauseMenu;
begin
  ClearAllKeyStates;  { Ignore keys held before pause }

  { Menu loop }
  while MenuActive do
  begin
    { Handle menu input }
    ClearKeyPressed;
  end;
end;
```

**Use cases:**
- Switching between game states (game ↔ menu)
- Starting new level (clear held keys)
- After cutscenes

---

### WaitForAnyKeyPress

```pascal
function WaitForAnyKeyPress: Byte;
```

Waits for any key to be pressed and returns its scan code.

**Returns:** Scan code of the pressed key.

**Example:**
```pascal
begin
  WriteLn('Press any key to continue...');
  WaitForAnyKeyPress;  { Blocks until key pressed }

  { Or get the specific key }
  KeyPressed := WaitForAnyKeyPress;
  if KeyPressed = Key_Escape then
    WriteLn('Cancelled')
  else
    WriteLn('Confirmed');
end;
```

**Note:** Blocks execution until a key is pressed.

---

## Common Usage Patterns

### Basic Game Loop

```pascal
uses Keyboard;

var
  GameRunning: Boolean;

begin
  InitKeyboard;

  GameRunning := True;
  while GameRunning do
  begin
    { Continuous input - movement }
    if IsKeyDown(Key_W) then PlayerY := PlayerY - 1;
    if IsKeyDown(Key_S) then PlayerY := PlayerY + 1;
    if IsKeyDown(Key_A) then PlayerX := PlayerX - 1;
    if IsKeyDown(Key_D) then PlayerX := PlayerX + 1;

    { Single-press input - actions }
    if IsKeyPressed(Key_Space) then
      FireWeapon;

    if IsKeyPressed(Key_Escape) then
      GameRunning := False;

    { Update and render }
    UpdateGame;
    RenderGame;

    { MUST call at end of loop }
    ClearKeyPressed;
  end;

  DoneKeyboard;
end;
```

---

### Text Input with Shift

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

    { Scan all letter keys }
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

---

### Modifier Key Combos

```pascal
{ Ctrl+S = Save, Ctrl+Q = Quit }
while GameRunning do
begin
  if IsKeyDown(Key_LCtrl) then
  begin
    if IsKeyPressed(Key_S) then
      SaveGame;

    if IsKeyPressed(Key_Q) then
      GameRunning := False;
  end;

  ClearKeyPressed;
end;
```

---

### Multi-Key Detection

```pascal
{ Diagonal movement }
var
  DirX, DirY: Integer;

begin
  DirX := 0;
  DirY := 0;

  if IsKeyDown(Key_W) then DirY := -1;
  if IsKeyDown(Key_S) then DirY :=  1;
  if IsKeyDown(Key_A) then DirX := -1;
  if IsKeyDown(Key_D) then DirX :=  1;

  { Both X and Y can be non-zero = diagonal }
  PlayerX := PlayerX + DirX;
  PlayerY := PlayerY + DirY;
end;
```

---

### Cheat Code Detection

```pascal
const
  CheatCode: array[0..4] of Byte =
    (Key_I, Key_D, Key_D, Key_Q, Key_D);  { "IDDQD" }

var
  CheatIndex: Integer;

begin
  CheatIndex := 0;

  while GameRunning do
  begin
    { Check next key in sequence }
    if IsKeyPressed(CheatCode[CheatIndex]) then
    begin
      Inc(CheatIndex);

      { Complete sequence }
      if CheatIndex = 5 then
      begin
        WriteLn('God mode activated!');
        GodMode := True;
        CheatIndex := 0;
      end;
    end
    else
    begin
      { Wrong key - reset }
      if IsKeyPressed(Key_Any) then
        CheatIndex := 0;
    end;

    ClearKeyPressed;
  end;
end;
```

---

## Important Notes

### CRITICAL Rules

1. **ALWAYS call `InitKeyboard`** before using any keyboard functions
2. **ALWAYS call `DoneKeyboard`** before program exit (even on error!)
3. **ALWAYS call `ClearKeyPressed`** at the **end** of every game loop
4. **Install ExitProc handler** for Ctrl+C/Ctrl+Break safety

### Edge Detection Behavior

- `IsKeyPressed` triggers on key **release**, not press
- This ensures no quick taps are missed
- Can call multiple times per frame for same key safely
- Only returns `True` once per press (until `ClearKeyPressed`)

### ExitProc Pattern

```pascal
var
  OldExitProc: Pointer;

{$F+}
procedure MyExitProc;
begin
  ExitProc := OldExitProc;  { Restore chain }
  DoneKeyboard;             { Unhook interrupt }
end;
{$F-}

begin
  InitKeyboard;

  { Install exit handler }
  OldExitProc := ExitProc;
  ExitProc := @MyExitProc;

  { Game code - even Ctrl+C will call MyExitProc }

  DoneKeyboard;
end;
```

---

## Common Pitfalls

1. **Forgetting `DoneKeyboard`** - System hangs (INT 9h points to freed memory)
2. **Not calling `ClearKeyPressed`** - Key presses repeat every frame
3. **Calling `ClearKeyPressed` at wrong time** - Call at **end** of loop, not beginning
4. **Using `IsKeyPressed` for movement** - Use `IsKeyDown` instead (continuous)
5. **Using `IsKeyDown` for menu selection** - Use `IsKeyPressed` instead (single-shot)

---

## Performance Notes

- **Minimal CPU usage** - Interrupt-driven, not polling
- **No BIOS delays** - Direct hardware access
- **128 simultaneous keys** - Can check all keys every frame
- **Fast lookup** - Array-based, O(1) access

---

## Compatibility

- **DOS only** - Requires real-mode DOS (or DOSBox)
- **Turbo Pascal 7.0** - Uses interrupt procedures
- **All DOS versions** - Standard INT 9h interrupt

---

## See Also

- **MOUSE.PAS** - Mouse input support
- **TEXTUI.PAS** - Uses KEYBOARD.PAS for menu navigation
- **SPRITE.PAS** - Combine with keyboard for player control
