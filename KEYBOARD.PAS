{ KEYBOARD.PAS - Low-level keyboard handler using scan codes }
{ Hooks INT 9h (keyboard interrupt) for direct hardware access }

unit Keyboard;

interface

{ Scan code constants for all keyboard keys }
const
  { Letter keys }
  Key_A = $1E;
  Key_B = $30;
  Key_C = $2E;
  Key_D = $20;
  Key_E = $12;
  Key_F = $21;
  Key_G = $22;
  Key_H = $23;
  Key_I = $17;
  Key_J = $24;
  Key_K = $25;
  Key_L = $26;
  Key_M = $32;
  Key_N = $31;
  Key_O = $18;
  Key_P = $19;
  Key_Q = $10;
  Key_R = $13;
  Key_S = $1F;
  Key_T = $14;
  Key_U = $16;
  Key_V = $2F;
  Key_W = $11;
  Key_X = $2D;
  Key_Y = $15;
  Key_Z = $2C;

  { Number keys (top row) }
  Key_1 = $02;
  Key_2 = $03;
  Key_3 = $04;
  Key_4 = $05;
  Key_5 = $06;
  Key_6 = $07;
  Key_7 = $08;
  Key_8 = $09;
  Key_9 = $0A;
  Key_0 = $0B;

  { Function keys }
  Key_F1  = $3B;
  Key_F2  = $3C;
  Key_F3  = $3D;
  Key_F4  = $3E;
  Key_F5  = $3F;
  Key_F6  = $40;
  Key_F7  = $41;
  Key_F8  = $42;
  Key_F9  = $43;
  Key_F10 = $44;
  Key_F11 = $57;
  Key_F12 = $58;

  { Special keys }
  Key_Escape    = $01;
  Key_Enter     = $1C;
  Key_Space     = $39;
  Key_Backspace = $0E;
  Key_Tab       = $0F;

  { Arrow keys }
  Key_Up    = $48;
  Key_Down  = $50;
  Key_Left  = $4B;
  Key_Right = $4D;

  { Modifier keys }
  Key_LShift = $2A;
  Key_RShift = $36;
  Key_LCtrl  = $1D;
  Key_LAlt   = $38;
  Key_CapsLock = $3A;

  { Extended keys }
  Key_Home   = $47;
  Key_End    = $4F;
  Key_PgUp   = $49;
  Key_PgDn   = $51;
  Key_Insert = $52;
  Key_Delete = $53;

  { Punctuation }
  Key_Minus     = $0C;  { - _ }
  Key_Equals    = $0D;  { = + }
  Key_LBracket  = $1A;  
  Key_RBracket  = $1B;  
  Key_Semicolon = $27;  { ; : }
  Key_Quote     = $28;  { ' " }
  Key_Backquote = $29;  { ` ~ }
  Key_Backslash = $2B;  { \ | }
  Key_Comma     = $33;  { , < }
  Key_Period    = $34;  { . > }
  Key_Slash     = $35;  { / ? }

  { Character lookup tables for input }
  { Map scan codes to unshifted characters (0 = not printable) }
  CharMapNormal: array[0..127] of Char = (
    #0,  #0,  '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', #0,  #0,  { 00-0F }
    'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', #0,  #0,  'a', 's', { 10-1F }
    'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '''', '`', #0,  '\', 'z', 'x', 'c', 'v', { 20-2F }
    'b', 'n', 'm', ',', '.', '/', #0,  #0,  #0,  ' ', #0,  #0,  #0,  #0,  #0,  #0,  { 30-3F }
    #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  { 40-4F }
    #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  { 50-5F }
    #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  { 60-6F }
    #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0   { 70-7F }
  );

  { Map scan codes to shifted characters (0 = not printable) }
  CharMapShift: array[0..127] of Char = (
    #0,  #0,  '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', #0,  #0,  { 00-0F }
    'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', #0,  #0,  'A', 'S', { 10-1F }
    'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', #0,  '|', 'Z', 'X', 'C', 'V', { 20-2F }
    'B', 'N', 'M', '<', '>', '?', #0,  #0,  #0,  ' ', #0,  #0,  #0,  #0,  #0,  #0,  { 30-3F }
    #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  { 40-4F }
    #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  { 50-5F }
    #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  { 60-6F }
    #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0   { 70-7F }
  );

{ Initialize keyboard handler - MUST be called before use }
procedure InitKeyboard;

{ Shutdown keyboard handler - MUST be called before exit }
procedure DoneKeyboard;

{ Check if a key is currently held down }
function IsKeyDown(ScanCode: Byte): Boolean;

{ Check if a key was pressed (edge detection - true only once per press) }
function IsKeyPressed(ScanCode: Byte): Boolean;

{ Clear the key pressed states }
procedure ClearKeyPressed;

{ Waits for any key press and returns with the scancode }
function WaitForAnyKeyPress: Byte;

implementation

uses
  Dos;

var
  KeyDown: array[0..127] of Boolean;      { Current key state }
  KeyPressed: array[0..127] of Boolean;   { Edge-detected press }
  KeyChecked: array[0..127] of Boolean;   { Was the key press checked? }
  OldInt9: Pointer;                       { Original INT 9h handler }

{ Keyboard interrupt handler - called on every key press/release }
{$F+}  { Far call required for interrupt handlers }
procedure KeyboardInt; interrupt;
var
  ScanCode: Byte;
  KeyIsDown: Boolean;
  ControlPort: Byte;
begin
  { Read scan code from keyboard port }
  ScanCode := Port[$60];
  KeyIsDown := (ScanCode and $80) = 0;
  ScanCode := ScanCode and $7F;
  { The key is pressed if it was released but now it is down }
  if not KeyDown[ScanCode] and KeyIsDown then
    KeyPressed[ScanCode] := True;
  { Set the current state }
  KeyDown[ScanCode] := KeyIsDown;
  Port[$20] := $20;
end;
{$F-}

{ Clear all key states }
procedure ClearAllKeyStates;
var
  i: Integer;
begin
  for i := 0 to 127 do
  begin
    KeyDown[i] := False;
    KeyPressed[i] := False;
    KeyChecked[i] := False;
  end;
end;

procedure InitKeyboard;
var
  i: Integer;
begin
  ClearAllKeyStates;

  { Save old interrupt handler and install ours }
  GetIntVec($09, OldInt9);
  SetIntVec($09, @KeyboardInt);
end;

procedure DoneKeyboard;
begin
  { Restore original interrupt handler }
  SetIntVec($09, OldInt9);
end;

function IsKeyDown(ScanCode: Byte): Boolean;
begin
  IsKeyDown := KeyDown[ScanCode];
end;

{ Can be called more than once in a loop }
function IsKeyPressed(ScanCode: Byte): Boolean;
begin
  if KeyPressed[ScanCode] then
    KeyChecked[ScanCode] := True;
  IsKeyPressed := KeyPressed[ScanCode];
end;

{ Needs to be cleared at the end of the loop if it was checked  }
procedure ClearKeyPressed;
var
  i: Integer;
begin
  for i := 0 to 127 do
    if KeyChecked[i] then
    begin
      KeyChecked[i] := False;
      KeyPressed[i] := False;
    end;
end;

{ Waits for any key press and returns with the scancode }
function WaitForAnyKeyPress: Byte;
var
  i: Byte;
  Waiting: Boolean;
begin
  Waiting := True;
  ClearAllKeyStates;
  while Waiting do
  begin
    for i := 0 to 127 do
      if IsKeyPressed(i) then
      begin
        WaitForAnyKeyPress := i;
        Waiting := False;
      end;
  end;
  ClearAllKeyStates;
end;

end.
