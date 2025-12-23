{ MATHUTIL.PAS - Mathematical utility functions

  Purpose: Common mathematical operations for game development including
           clamping, interpolation, and fixed-point arithmetic.

  Fixed-Point Format: 16.16 (16 bits integer, 16 bits fractional)
  - Range: -32768.0 to 32767.99998
  - Precision: ~0.000015
  - Use FixedMul for multiplication to avoid overflow

  Usage Example:
    x := Clamp(playerX, 0, 319);
    alpha := Lerp(0.0, 1.0, 0.5);
    result := FixedMul(LongInt(320) shl 16, LongInt(200) shl 16);
}

unit MathUtil;

interface

{ Clamps an integer value between Min and Max (inclusive) }
function Clamp(Value, Min, Max: Integer): Integer;

{ Clamps a LongInt value between Min and Max (inclusive) }
function ClampLong(Value, Min, Max: LongInt): LongInt;

{ Linear interpolation between A and B by factor T (0.0 to 1.0) }
function Lerp(A, B, T: Real): Real;

{ Integer linear interpolation between A and B by factor T (0-255 scale) }
function LerpInt(A, B: Integer; T: Byte): Integer;

{ Fixed-point multiplication (16.16 format)
  Multiplies two 16.16 fixed-point numbers and returns 16.16 result
  Example: FixedMul($00010000, $00020000) = $00020000 (1.0 * 2.0 = 2.0) }
function FixedMul(A, B: LongInt): LongInt;

{ Fixed-point division (16.16 format)
  Divides two 16.16 fixed-point numbers and returns 16.16 result }
function FixedDiv(A, B: LongInt): LongInt;

{ Converts integer to 16.16 fixed-point }
function IntToFixed(Value: Integer): LongInt;

{ Converts 16.16 fixed-point to integer (truncates fractional part) }
function FixedToInt(Value: LongInt): Integer;

{ Returns the minimum of two integers }
function Min(A, B: Integer): Integer;

{ Returns the maximum of two integers }
function Max(A, B: Integer): Integer;

{ Returns the minimum of two LongInts }
function MinLong(A, B: LongInt): LongInt;

{ Returns the maximum of two LongInts }
function MaxLong(A, B: LongInt): LongInt;

{ Returns the absolute value of an integer }
function Abs(Value: Integer): Integer;

{ Returns the absolute value of a LongInt }
function AbsLong(Value: LongInt): LongInt;

implementation

function Clamp(Value, Min, Max: Integer): Integer;
begin
  if Value < Min then
    Clamp := Min
  else if Value > Max then
    Clamp := Max
  else
    Clamp := Value;
end;

function ClampLong(Value, Min, Max: LongInt): LongInt;
begin
  if Value < Min then
    ClampLong := Min
  else if Value > Max then
    ClampLong := Max
  else
    ClampLong := Value;
end;

function Lerp(A, B, T: Real): Real;
begin
  Lerp := A + (B - A) * T;
end;

function LerpInt(A, B: Integer; T: Byte): Integer;
begin
  { T is 0-255, scale to 0.0-1.0 by dividing by 255 }
  LerpInt := A + ((B - A) * T) div 255;
end;

function FixedMul(A, B: LongInt): LongInt;
var
  ResultHigh, ResultLow: LongInt;
begin
  { Multiply and shift right by 16 to maintain 16.16 format
    Using inline assembly for 286-compatible 32-bit multiplication }
  asm
    mov ax, word ptr A      { Load low word of A }
    mov dx, word ptr A+2    { Load high word of A }
    mov bx, word ptr B      { Load low word of B }
    mov cx, word ptr B+2    { Load high word of B }

    { Perform 32-bit multiplication: DX:AX * CX:BX }
    push ax
    push dx

    { Multiply high parts }
    mov ax, dx
    imul cx
    mov word ptr ResultHigh+2, ax

    { Multiply A.low * B.high }
    pop dx
    pop ax
    push ax
    imul cx
    add word ptr ResultHigh+2, ax

    { Multiply A.high * B.low }
    pop ax
    mov cx, dx
    imul bx
    add word ptr ResultHigh+2, ax

    { Multiply low parts }
    pop ax
    push ax
    mul bx
    mov word ptr ResultLow, ax
    mov word ptr ResultLow+2, dx

    { Shift right by 16: take high 32 bits of 64-bit result }
    mov ax, word ptr ResultLow+2
    mov dx, word ptr ResultHigh+2
    mov word ptr @Result, ax
    mov word ptr @Result+2, dx

    pop ax  { Clean up stack }
  end;
end;

function FixedDiv(A, B: LongInt): LongInt;
begin
  { Shift A left by 16 before division to maintain 16.16 format
    WARNING: This can overflow if A is too large }
  if B = 0 then
    FixedDiv := 0
  else
    FixedDiv := (A shl 16) div B;
end;

function IntToFixed(Value: Integer): LongInt;
begin
  IntToFixed := LongInt(Value) shl 16;
end;

function FixedToInt(Value: LongInt): Integer;
begin
  FixedToInt := Integer(Value shr 16);
end;

function Min(A, B: Integer): Integer;
begin
  if A < B then
    Min := A
  else
    Min := B;
end;

function Max(A, B: Integer): Integer;
begin
  if A > B then
    Max := A
  else
    Max := B;
end;

function MinLong(A, B: LongInt): LongInt;
begin
  if A < B then
    MinLong := A
  else
    MinLong := B;
end;

function MaxLong(A, B: LongInt): LongInt;
begin
  if A > B then
    MaxLong := A
  else
    MaxLong := B;
end;

function Abs(Value: Integer): Integer;
begin
  if Value < 0 then
    Abs := -Value
  else
    Abs := Value;
end;

function AbsLong(Value: LongInt): LongInt;
begin
  if Value < 0 then
    AbsLong := -Value
  else
    AbsLong := Value;
end;

end.
