{ VGA.PAS - VGA Mode 13h graphics library

  Purpose: Core graphics routines for 320x200 256-color VGA mode.
           Provides framebuffer management, palette control, drawing
           primitives, and image manipulation with hardware clipping.

  Target: VGA Mode 13h (320x200, 256 colors, linear framebuffer at A000:0000)

  Features:
    - Double-buffered rendering with CreateFrameBuffer/RenderFrameBuffer
    - Hardware-accelerated operations using REP MOVSW (286 optimized)
    - Automatic clipping to screen bounds (0-319, 0-199)
    - Color 0 = transparent in PutImage operations
    - Palette manipulation and VSync support

  Dependencies: DOS, 286 CPU, VGA adapter

  Usage Example:
    InitVGA;
    fb := CreateFrameBuffer;
    ClearFrameBuffer(fb);
    DrawLine(0, 0, 319, 199, 15, fb);
    RenderFrameBuffer(fb);
    DoneVGA;
    FreeFrameBuffer(fb);
}

unit vga;

{$G+}  { Enable 286 instructions }

interface

type
  TRGBColor = record
    R, G, B: Byte;
  end;

  PPalette = ^TPalette;
  TPalette = array[0..255] of TRGBColor;

  PFrameBuffer = ^TFrameBuffer;
  TFrameBuffer = array[0..63999] of byte;

  PImage = ^TImage;
  TImage = record
    Width: Word;
    Height: Word;
    Data: Pointer;
  end;

  TRectangle = record
    X: Integer;
    Y: Integer;
    Width: Word;
    Height: Word;
  end;

procedure InitVGA;
procedure DoneVGA;
procedure SetClipRectangle(const R: TRectangle);  { Set clipping bounds for rendering }
procedure WaitForVSync;

{ FrameBuffer }
function CreateFrameBuffer: PFrameBuffer;  { Allocates off-screen buffer for double-buffering }
function GetScreenBuffer: PFrameBuffer;    { Returns pointer to VGA memory for direct drawing }
procedure ClearFrameBuffer(FrameBuffer: PFrameBuffer);
procedure CopyFrameBuffer(Source, Dest: PFrameBuffer);  { Fast copy from Source to Dest }
procedure CopyFrameBufferRect(Source: PFrameBuffer; var SourceRect: TRectangle; Dest: PFrameBuffer; DestX, DestY: Word);
procedure FreeFrameBuffer(var FrameBuffer: PFrameBuffer);
procedure RenderFrameBuffer(FrameBuffer: PFrameBuffer);

{ Palette }
function LoadPalette(const FileName: string; var Palette: TPalette): Boolean;
procedure SetPalette(const Palette: TPalette);
procedure SetPartialPalette(const Palette: TPalette; FromColor, ToColor: Byte);
procedure SetRGB(Index: Byte; const RGB: TRGBColor);
procedure GetRGB(Index: Byte; var RGB: TRGBColor);
procedure RotatePalette(StartColor: Byte; Count: Byte; Direction: ShortInt);

{ Drawing primitives }
procedure DrawLine(X1, Y1, X2, Y2: Integer; Color: Byte; FrameBuffer: PFrameBuffer);
procedure DrawHLine(X, Y, Width: Integer; Color: Byte; FrameBuffer: PFrameBuffer);
procedure DrawVLine(X, Y, Height: Integer; Color: Byte; FrameBuffer: PFrameBuffer);
procedure DrawFillRect(const R: TRectangle; Color: Byte; FrameBuffer: PFrameBuffer);
procedure DrawRect(const R: TRectangle; Color: Byte; FrameBuffer: PFrameBuffer);

{ Image operations }
procedure GetImage(var Image: TImage; X, Y, Width, Height: Word; FrameBuffer: PFrameBuffer);
procedure PutImage(var Image: TImage; X, Y: Word; Transparent: Boolean; FrameBuffer: PFrameBuffer);
procedure PutImageRect(var Source: TImage; var SourceRect: TRectangle;
                       X, Y: Integer; Transparent: Boolean; FrameBuffer: PFrameBuffer);
procedure PutFlippedImage(var Image: TImage; X, Y: Word; FlipX, FlipY, Transparent: Boolean; FrameBuffer: PFrameBuffer);
procedure PutFlippedImageRect(var Source: TImage; var SourceRect: TRectangle;
                              X, Y: Integer; FlipX, FlipY, Transparent: Boolean; FrameBuffer: PFrameBuffer);
procedure FreeImage(var Image: TImage);
procedure ClearImage(var Image: TImage);

implementation

var
  OldMode: byte;
  ClipRectangle: TRectangle;  { Global clipping bounds }

procedure InitVGA;
begin
  asm
    mov ax, 0f00h
    int 10h
    mov OldMode, al

    mov ax, 13h
    int 10h
  end;

  { Initialize default clipping rectangle to full screen }
  ClipRectangle.X := 0;
  ClipRectangle.Y := 0;
  ClipRectangle.Width := 320;
  ClipRectangle.Height := 200;
end;

procedure SetClipRectangle(const R: TRectangle);
{ Sets the clipping rectangle for all rendering operations }
{ Default is (0, 0, 320, 200) - full screen }
begin
  ClipRectangle := R;
end;

procedure DoneVGA; assembler;
 asm
  mov ah, 00h
  mov al, OldMode
  int 10h
end;

function CreateFrameBuffer: PFrameBuffer;
var
  p: PFrameBuffer;
begin
  GetMem(p, 64000);
  ClearFrameBuffer(p);
  CreateFrameBuffer := p;
end;

function GetScreenBuffer: PFrameBuffer;
{ Returns a pointer directly to VGA memory at $A000:0000 }
{ Allows direct drawing without double-buffering }
begin
  GetScreenBuffer := Ptr($A000, $0000);
end;

procedure ClearFrameBuffer(FrameBuffer: PFrameBuffer); assembler;
{ Fast assembly clear using REP STOSW }
 asm
  les di, FrameBuffer
  xor ax, ax          { AX = 0 (value to fill) }
  mov cx, 32000       { 64000 bytes / 2 = 32000 words }
  cld
  rep stosw           { Fill ES:DI with AX, CX times }
end;

procedure CopyFrameBuffer(Source, Dest: PFrameBuffer); assembler;
{ Fast assembly copy using REP MOVSW }
{ Copies 64000 bytes from Source to Dest }
 asm
  push ds             { Save Pascal's DS }
  lds si, Source      { DS:SI = Source buffer }
  les di, Dest        { ES:DI = Dest buffer }
  mov cx, 32000       { 64000 bytes / 2 = 32000 words }
  cld
  rep movsw           { Copy CX words from DS:SI to ES:DI }
  pop ds              { Restore Pascal's DS }
end;

procedure CopyFrameBufferRect(Source: PFrameBuffer; var SourceRect: TRectangle;
                               Dest: PFrameBuffer; DestX, DestY: Word);
var
  SrcX, SrcY: Integer;
  DstX, DstY: Integer;
  Width, Height: Integer;
begin
  { Start with source rectangle coordinates }
  SrcX := SourceRect.X;
  SrcY := SourceRect.Y;
  DstX := Integer(DestX);
  DstY := Integer(DestY);
  Width := SourceRect.Width;
  Height := SourceRect.Height;

  { Early exit for zero dimensions }
  if (Width <= 0) or (Height <= 0) then Exit;

  { --- Clipping Logic (Uses global ClipRectangle) --- }

  { Clip source rectangle to source buffer bounds }
  if SrcX < ClipRectangle.X then
  begin
    Width := Width + (SrcX - ClipRectangle.X);
    DstX := DstX - (SrcX - ClipRectangle.X);
    SrcX := ClipRectangle.X;
  end;

  if SrcY < ClipRectangle.Y then
  begin
    Height := Height + (SrcY - ClipRectangle.Y);
    DstY := DstY - (SrcY - ClipRectangle.Y);
    SrcY := ClipRectangle.Y;
  end;

  if SrcX + Width > ClipRectangle.X + Integer(ClipRectangle.Width) then
    Width := ClipRectangle.X + Integer(ClipRectangle.Width) - SrcX;

  if SrcY + Height > ClipRectangle.Y + Integer(ClipRectangle.Height) then
    Height := ClipRectangle.Y + Integer(ClipRectangle.Height) - SrcY;

  { Clip destination to destination buffer bounds }
  if DstX < ClipRectangle.X then
  begin
    Width := Width + (DstX - ClipRectangle.X);
    SrcX := SrcX - (DstX - ClipRectangle.X);
    DstX := ClipRectangle.X;
  end;

  if DstY < ClipRectangle.Y then
  begin
    Height := Height + (DstY - ClipRectangle.Y);
    SrcY := SrcY - (DstY - ClipRectangle.Y);
    DstY := ClipRectangle.Y;
  end;

  if DstX + Width > ClipRectangle.X + Integer(ClipRectangle.Width) then
    Width := ClipRectangle.X + Integer(ClipRectangle.Width) - DstX;

  if DstY + Height > ClipRectangle.Y + Integer(ClipRectangle.Height) then
    Height := ClipRectangle.Y + Integer(ClipRectangle.Height) - DstY;

  { --- Final Validation and Optimization --- }

  { Make width even for Word-aligned copy (truncates odd pixel) }
  Width := Width and $FFFE;

  { Exit if nothing to copy }
  if (Width <= 0) or (Height <= 0) then Exit;

  { --- Assembly Blit --- }
  asm
    push ds             { Save Pascal's Data Segment }
    cld                 { Clear Direction Flag (Forward copy) }

    { 1. Setup Destination Pointer (ES:DI) }
    les di, Dest        { Load Dest pointer segment:offset into ES:DI }
    mov ax, 320         { Screen Width }
    mul DstY            { DX:AX = DstY * 320 }
    add di, ax          { Add Y offset }
    add di, DstX        { Add X offset }

    { 2. Setup Source Pointer (DS:SI) }
    lds si, Source      { Load Source pointer segment:offset into DS:SI }
    mov ax, 320         { Screen Width }
    mul SrcY            { DX:AX = SrcY * 320 }
    add si, ax          { Add Y offset }
    add si, SrcX        { Add X offset }

    { 3. Prepare Counters and Stride }
    mov bx, Width       { Load Width in Bytes }
    mov ax, 320         { Total Screen Width }
    sub ax, bx          { AX = Stride (Amount to jump to reach next line) }
                        { Stride = 320 - Width_In_Bytes }
    
    shr bx, 1           { Convert Width to Words (Width / 2) for movsw }
    mov dx, Height      { Load Row Counter }

    { 4. Copy Loop }
    @RowLoop:
      mov cx, bx        { Load Word count for this row }
      rep movsw         { Copy CX words from DS:SI to ES:DI }
      
      add si, ax        { Advance Source ptr to start of next line }
      add di, ax        { Advance Dest ptr to start of next line }
      
      dec dx            { Decrement Height counter }
      jnz @RowLoop      { Repeat if lines remain }

    pop ds              { Restore Pascal's Data Segment }
  end;
end;

procedure FreeFrameBuffer(var FrameBuffer: PFrameBuffer);
begin
  FreeMem(FrameBuffer, 64000);
  FrameBuffer := nil;
end;

procedure RenderFrameBuffer(FrameBuffer: PFrameBuffer); assembler;
 asm
  mov bx, ds              { save Pascal's DS }
  mov ax, $a000
  mov es, ax
  xor di, di
  lds si, FrameBuffer
  mov cx, 32000
  cld
  rep movsw
  mov ds, bx              { restore Pascal's DS }
end;

procedure SetPalette(const Palette: TPalette); assembler;
 asm
  push ds
  lds si, Palette
  xor bx, bx
  mov cx, 256
@Loop:
  mov dx, 03c8h
  mov al, bl
  out dx, al
  mov dx, 03c9h
  mov al, [ds:si]
  inc si
  out dx, al
  mov al, [ds:si]
  inc si
  out dx, al
  mov al, [ds:si]
  inc si
  out dx, al
  inc bx
  loop @Loop
  pop ds
end;

procedure SetPartialPalette(const Palette: TPalette; FromColor, ToColor: Byte); assembler;
 asm
  push ds
  lds si, Palette

  { Calculate starting offset in palette array: From * 3 }
  xor ah, ah
  mov al, FromColor
  mov bx, 3
  mul bx              { AX = From * 3 }
  add si, ax          { DS:SI points to Palette[From] }

  { Calculate count: To - From + 1 }
  mov al, ToColor
  sub al, FromColor
  inc al
  mov cx, ax          { CX = count }

  { BL = current palette index }
  mov bl, FromColor

@Loop:
  mov dx, 03c8h
  mov al, bl
  out dx, al
  mov dx, 03c9h
  mov al, [ds:si]
  inc si
  out dx, al
  mov al, [ds:si]
  inc si
  out dx, al
  mov al, [ds:si]
  inc si
  out dx, al
  inc bl
  loop @Loop
  pop ds
end;

procedure SetRGB(Index: Byte; const RGB: TRGBColor); assembler;
asm
  push ds
  lds  si, RGB        { DS:SI -> TRGBColor }

  mov  dx, 03C8h      { write palette index }
  mov  al, Index
  out  dx, al

  mov  dx, 03C9h      { then write R, G, B }

  mov  al, [si]       { R }
  out  dx, al
  mov  al, [si+1]     { G }
  out  dx, al
  mov  al, [si+2]     { B }
  out  dx, al

  pop  ds
end;

procedure GetRGB(Index: Byte; var RGB: TRGBColor); assembler;
asm
  push ds
  lds  di, RGB        { DS:DI -> TRGBColor }

  mov  dx, 03C7h      { read-index register }
  mov  al, Index
  out  dx, al         { select palette entry }

  mov  dx, 03C9h      { read R, G, B back }

  in   al, dx         { R }
  mov  [di], al
  in   al, dx         { G }
  mov  [di+1], al
  in   al, dx         { B }
  mov  [di+2], al

  pop  ds
end;

{ Rotates a range of palette colors for animation effects }
{ Direction: 1 = rotate right (colors shift up), -1 = rotate left (colors shift down) }
procedure RotatePalette(StartColor: Byte; Count: Byte; Direction: ShortInt);
var
  Colors: array[0..255] of TRGBColor;
  Temp: TRGBColor;
  i: Integer;
begin
  if Count < 2 then Exit;  { Nothing to rotate }

  { Read the affected palette entries }
  for i := 0 to Count - 1 do
    GetRGB(StartColor + i, Colors[i]);

  if Direction > 0 then
  begin
    { Rotate right }
    Temp := Colors[Count - 1];
    for i := Count - 1 downto 1 do
      Colors[i] := Colors[i - 1];
    Colors[0] := Temp;
  end
  else
  begin
    { Rotate left }
    Temp := Colors[0];
    for i := 0 to Count - 2 do
      Colors[i] := Colors[i + 1];
    Colors[Count - 1] := Temp;
  end;

  { Write the palette entries back }
  for i := 0 to Count - 1 do
    SetRGB(StartColor + i, Colors[i]);
end;

function LoadPalette(const FileName: string; var Palette: TPalette): Boolean;
var
  F: File;
  BytesRead: Word;
begin
  LoadPalette := False;

  { Open file }
  Assign(F, FileName);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult <> 0 then
    Exit;

  { Read palette data - 768 bytes (256 colors * 3 RGB components) }
  BlockRead(F, Palette, 768, BytesRead);
  Close(F);

  if BytesRead = 768 then
    LoadPalette := True;
end;

procedure WaitForVSync; assembler;
{ Wait for vertical retrace to prevent screen tearing }
 asm
  mov dx, 03DAh     { VGA Input Status Register 1 }
@wait1:
  in al, dx
  test al, 08h      { Wait for bit 3 to clear (not in VBlank) }
  jnz @wait1
@wait2:
  in al, dx
  test al, 08h      { Wait for bit 3 to set (VBlank started) }
  jz @wait2
end;

{ Drawing primitives - TODO: assembler }

procedure DrawLine(X1, Y1, X2, Y2: Integer; Color: Byte; FrameBuffer: PFrameBuffer);
{ Bresenham's line drawing algorithm with clipping }
var
  dx, dy, sx, sy, err, e2: Integer;
  Offset: Word;
begin
  { Calculate dx = Abs(X2 - X1) }
  dx := X2 - X1;
  if dx < 0 then
  begin
    dx := -dx;
    sx := -1;
  end
  else
    sx := 1;

  { Calculate dy = Abs(Y2 - Y1) }
  dy := Y2 - Y1;
  if dy < 0 then
  begin
    dy := -dy;
    sy := -1;
  end
  else
    sy := 1;

  { Initial error }
  err := dx - dy;

  { Main loop }
  while True do
  begin
    { Plot pixel if within bounds }
    if (X1 >= 0) and (X1 < 320) and (Y1 >= 0) and (Y1 < 200) then
    begin
      Offset := Word(Y1) * 320 + Word(X1);
      FrameBuffer^[Offset] := Color;
    end;

    { Check if we've reached the end point }
    if (X1 = X2) and (Y1 = Y2) then
      Break;

    { Calculate error and adjust coordinates }
    e2 := err * 2;
    if e2 > -dy then
    begin
      err := err - dy;
      X1 := X1 + sx;
    end;
    if e2 < dx then
    begin
      err := err + dx;
      Y1 := Y1 + sy;
    end;
  end;
end;

procedure DrawHLine(X, Y, Width: Integer; Color: Byte; FrameBuffer: PFrameBuffer);
{ Draws a horizontal line with clipping - optimized assembly version }
var
  X1, X2: Integer;
  ClipX2: Integer;
  Offset: Word;
  DrawWidth: Integer;
begin
  { Early exit if Width is zero or negative }
  if Width <= 0 then Exit;

  { Early exit if Y is outside clip bounds }
  if (Y < ClipRectangle.Y) or (Y >= ClipRectangle.Y + Integer(ClipRectangle.Height)) then
    Exit;

  { Calculate line end points }
  X1 := X;
  X2 := X + Width - 1;

  { Calculate clip bounds }
  ClipX2 := ClipRectangle.X + Integer(ClipRectangle.Width) - 1;

  { Clip X coordinates }
  if X1 < ClipRectangle.X then X1 := ClipRectangle.X;
  if X2 > ClipX2 then X2 := ClipX2;

  { Check if completely clipped }
  if X1 > X2 then Exit;

  { Calculate offset and width }
  DrawWidth := X2 - X1 + 1;
  Offset := Word(Y) * 320 + Word(X1);

  { Draw line using FillChar (fast memory fill) }
  FillChar(FrameBuffer^[Offset], DrawWidth, Color);
end;

procedure DrawVLine(X, Y, Height: Integer; Color: Byte; FrameBuffer: PFrameBuffer);
{ Draws a vertical line with clipping }
var
  Y1, Y2: Integer;
  ClipY2: Integer;
  Row: Integer;
  Offset: Word;
begin
  { Early exit if Height is zero or negative }
  if Height <= 0 then Exit;

  { Early exit if X is outside clip bounds }
  if (X < ClipRectangle.X) or (X >= ClipRectangle.X + Integer(ClipRectangle.Width)) then
    Exit;

  { Calculate line end points }
  Y1 := Y;
  Y2 := Y + Height - 1;

  { Calculate clip bounds }
  ClipY2 := ClipRectangle.Y + Integer(ClipRectangle.Height) - 1;

  { Clip Y coordinates }
  if Y1 < ClipRectangle.Y then Y1 := ClipRectangle.Y;
  if Y2 > ClipY2 then Y2 := ClipY2;

  { Check if completely clipped }
  if Y1 > Y2 then Exit;

  { Draw vertical line pixel by pixel }
  for Row := Y1 to Y2 do
  begin
    Offset := Word(Row) * 320 + Word(X);
    FrameBuffer^[Offset] := Color;
  end;
end;

procedure DrawFillRect(const R: TRectangle; Color: Byte; FrameBuffer: PFrameBuffer);
{ Draws a filled rectangle with clipping }
var
  ClippedRect: TRectangle;
  X1, Y1, X2, Y2: Integer;
  ClipX2, ClipY2: Integer;
  Row: Integer;
  Offset: Word;
begin
  { Calculate clipping bounds }
  ClipX2 := ClipRectangle.X + ClipRectangle.Width - 1;
  ClipY2 := ClipRectangle.Y + ClipRectangle.Height - 1;

  { Calculate rectangle bounds }
  X1 := R.X;
  Y1 := R.Y;
  X2 := R.X + R.Width - 1;
  Y2 := R.Y + R.Height - 1;

  { Clip to bounds }
  if X1 < ClipRectangle.X then X1 := ClipRectangle.X;
  if Y1 < ClipRectangle.Y then Y1 := ClipRectangle.Y;
  if X2 > ClipX2 then X2 := ClipX2;
  if Y2 > ClipY2 then Y2 := ClipY2;

  { Check if completely outside clip region }
  if (X1 > X2) or (Y1 > Y2) then Exit;

  { Build clipped rectangle }
  ClippedRect.X := X1;
  ClippedRect.Y := Y1;
  ClippedRect.Width := X2 - X1 + 1;
  ClippedRect.Height := Y2 - Y1 + 1;

  { Draw clipped rectangle row by row }
  for Row := 0 to ClippedRect.Height - 1 do
  begin
    Offset := (ClippedRect.Y + Row) * 320 + ClippedRect.X;
    FillChar(FrameBuffer^[Offset], ClippedRect.Width, Color);
  end;
end;

procedure DrawRect(const R: TRectangle; Color: Byte; FrameBuffer: PFrameBuffer); assembler;
{ Draws a rectangle outline (border only) using fast assembly }
{ Draws 4 edges: top, bottom, left, right }
asm
  push ds
  cld

  { Load rectangle parameters }
  les di, R
  mov ax, es:[di]        { AX = R.X }
  mov bx, es:[di+2]      { BX = R.Y }
  mov cx, es:[di+4]      { CX = R.Width }
  mov dx, es:[di+6]      { DX = R.Height }

  { Early exit if width or height is less than 2 }
  cmp cx, 2
  jl @Done
  cmp dx, 2
  jl @Done

  { Save all parameters on stack for reuse }
  push ax                { X }
  push bx                { Y }
  push cx                { Width }
  push dx                { Height }

  { --- Draw top edge: horizontal line from (X, Y) to (X+Width-1, Y) --- }
  mov ax, bx             { AX = Y }
  mov si, 320
  mul si                 { DX:AX = Y * 320 }
  pop dx                 { DX = Height (pop and save for later) }
  pop cx                 { CX = Width }
  pop bx                 { BX = Y }
  pop si                 { SI = X }
  push si                { Save all params again }
  push bx
  push cx
  push dx

  add ax, si             { AX = Y * 320 + X }
  les di, FrameBuffer
  add di, ax             { ES:DI = start of top edge }

  mov al, Color
  push cx                { Save width }
  rep stosb              { Draw top edge }
  pop cx                 { Restore width }

  { --- Draw bottom edge: horizontal line from (X, Y+Height-1) to (X+Width-1, Y+Height-1) --- }
  pop dx                 { DX = Height }
  pop cx                 { CX = Width }
  pop bx                 { BX = Y }
  pop si                 { SI = X }
  push si
  push bx
  push cx
  push dx

  mov ax, bx             { AX = Y }
  add ax, dx             { AX = Y + Height }
  dec ax                 { AX = Y + Height - 1 }
  push cx
  mov cx, 320
  mul cx                 { DX:AX = (Y+Height-1) * 320 }
  pop cx
  add ax, si             { AX = (Y+Height-1) * 320 + X }
  les di, FrameBuffer
  add di, ax

  mov al, Color
  rep stosb              { Draw bottom edge }

  { --- Draw left edge: vertical line from (X, Y+1) to (X, Y+Height-2) --- }
  pop dx                 { DX = Height }
  pop cx                 { CX = Width }
  pop bx                 { BX = Y }
  pop si                 { SI = X }
  push si
  push bx
  push cx
  push dx

  { Start at Y+1 to avoid overdrawing corners }
  inc bx                 { BX = Y + 1 }
  mov ax, bx             { AX = Y + 1 }
  push dx
  mov dx, 320
  mul dx                 { DX:AX = (Y+1) * 320 }
  pop dx
  add ax, si             { AX = (Y+1) * 320 + X }
  les di, FrameBuffer
  add di, ax

  mov al, Color
  sub dx, 2              { Height - 2 (skip top and bottom corners) }
  mov cx, dx
  jcxz @SkipLeft         { Skip if no pixels to draw }

@LeftLoop:
  mov es:[di], al        { Write pixel }
  add di, 320            { Move to next row }
  loop @LeftLoop

@SkipLeft:
  { --- Draw right edge: vertical line from (X+Width-1, Y+1) to (X+Width-1, Y+Height-2) --- }
  pop dx                 { DX = Height }
  pop cx                 { CX = Width }
  pop bx                 { BX = Y }
  pop si                 { SI = X }

  add si, cx             { SI = X + Width }
  dec si                 { SI = X + Width - 1 }

  inc bx                 { BX = Y + 1 }
  mov ax, bx             { AX = Y + 1 }
  push dx
  mov dx, 320
  mul dx                 { DX:AX = (Y+1) * 320 }
  pop dx
  add ax, si             { AX = (Y+1) * 320 + (X+Width-1) }
  les di, FrameBuffer
  add di, ax

  mov al, Color
  sub dx, 2              { Height - 2 }
  mov cx, dx
  jcxz @Done             { Skip if no pixels to draw }

@RightLoop:
  mov es:[di], al        { Write pixel }
  add di, 320            { Move to next row }
  loop @RightLoop

@Done:
  pop ds
end;


{ Image operations }

procedure GetImage(var Image: TImage; X, Y, Width, Height: Word; FrameBuffer: PFrameBuffer);
var
  SrcRow: Word;
  SrcPtr, DstPtr: ^Byte;
  ImageSize: LongInt;
begin
  Image.Width := Width;
  Image.Height := Height;
  ImageSize := LongInt(Width) * LongInt(Height);
  GetMem(Image.Data, ImageSize);

  DstPtr := Image.Data;
  for SrcRow := 0 to Height - 1 do
  begin
    SrcPtr := @FrameBuffer^[(Y + SrcRow) * 320 + X];
    Move(SrcPtr^, DstPtr^, Width);
    Inc(DstPtr, Width);
  end;
end;

procedure PutImage(var Image: TImage; X, Y: Word; Transparent: Boolean; FrameBuffer: PFrameBuffer);
begin
  PutFlippedImage(Image, X, Y, False, False, Transparent, FrameBuffer);
end;

procedure PutImageRect(var Source: TImage; var SourceRect: TRectangle; X, Y: Integer;
                       Transparent: Boolean; FrameBuffer: PFrameBuffer);
begin
  PutFlippedImageRect(Source, SourceRect, X, Y, False, False, Transparent, FrameBuffer);
end;

procedure PutFlippedImage(var Image: TImage; X, Y: Word; FlipX, FlipY, Transparent: Boolean; FrameBuffer: PFrameBuffer);
var
  FullRect: TRectangle;
begin
  { Set up rectangle covering entire image }
  FullRect.X := 0;
  FullRect.Y := 0;
  FullRect.Width := Image.Width;
  FullRect.Height := Image.Height;

  { Delegate to PutFlippedImageRect }
  PutFlippedImageRect(Image, FullRect, X, Y, FlipX, FlipY, Transparent, FrameBuffer);
end;

procedure PutFlippedImageRect(var Source: TImage; var SourceRect: TRectangle;
                              X, Y: Integer; FlipX, FlipY, Transparent: Boolean;
                              FrameBuffer: PFrameBuffer);
{ Optimized assembly version with 8 specialized code paths for flip combinations }
{ Pascal pre-calculations handle proper clipping for all four edges }
var
  ClippedRect: TRectangle;
  ClippedX, ClippedY: Integer;
  ClipAmount: Integer;
  ClipRight, ClipBottom: Integer;
begin
  { Calculate clipping bounds }
  ClipRight := ClipRectangle.X + Integer(ClipRectangle.Width);
  ClipBottom := ClipRectangle.Y + Integer(ClipRectangle.Height);

  { Early exit checks - completely off screen }
  if (X >= ClipRight) or (Y >= ClipBottom) or
     (X + Integer(SourceRect.Width) <= ClipRectangle.X) or
     (Y + Integer(SourceRect.Height) <= ClipRectangle.Y) then
    Exit;

  { Initialize clipped values with original parameters }
  ClippedRect := SourceRect;
  ClippedX := X;
  ClippedY := Y;

  { Clip left edge (screen X < ClipRectangle.X) }
  if X < ClipRectangle.X then
  begin
    ClipAmount := ClipRectangle.X - X;
    ClippedX := ClipRectangle.X;

    if FlipX then
      { FlipX: reading right-to-left, so reduce width (clips from right of source) }
      ClippedRect.Width := ClippedRect.Width - ClipAmount
    else
      { Normal: reading left-to-right, so skip from left of source }
      begin
        Inc(ClippedRect.X, ClipAmount);
        Dec(ClippedRect.Width, ClipAmount);
      end;
  end;

  { Clip top edge (screen Y < ClipRectangle.Y) }
  if Y < ClipRectangle.Y then
  begin
    ClipAmount := ClipRectangle.Y - Y;
    ClippedY := ClipRectangle.Y;

    if FlipY then
      { FlipY: reading bottom-to-top, so reduce height (clips from bottom of source) }
      ClippedRect.Height := ClippedRect.Height - ClipAmount
    else
      { Normal: reading top-to-bottom, so skip from top of source }
      begin
        Inc(ClippedRect.Y, ClipAmount);
        Dec(ClippedRect.Height, ClipAmount);
      end;
  end;

  { Clip right edge (screen X + Width > ClipRight) }
  if ClippedX + Integer(ClippedRect.Width) > ClipRight then
  begin
    ClipAmount := ClippedX + Integer(ClippedRect.Width) - ClipRight;

    if FlipX then
      { FlipX: reading right-to-left, so skip from left of source }
      begin
        Inc(ClippedRect.X, ClipAmount);
        Dec(ClippedRect.Width, ClipAmount);
      end
    else
      { Normal: reading left-to-right, so reduce width (clips from right of source) }
      ClippedRect.Width := ClippedRect.Width - ClipAmount;
  end;

  { Clip bottom edge (screen Y + Height > ClipBottom) }
  if ClippedY + Integer(ClippedRect.Height) > ClipBottom then
  begin
    ClipAmount := ClippedY + Integer(ClippedRect.Height) - ClipBottom;

    if FlipY then
      { FlipY: reading bottom-to-top, so skip from top of source }
      begin
        Inc(ClippedRect.Y, ClipAmount);
        Dec(ClippedRect.Height, ClipAmount);
      end
    else
      { Normal: reading top-to-bottom, so reduce height (clips from bottom of source) }
      ClippedRect.Height := ClippedRect.Height - ClipAmount;
  end;

  { Final validation - nothing left to draw }
  if (ClippedRect.Width = 0) or (ClippedRect.Height = 0) then
    Exit;

  { Assembly code using clipped parameters }
  asm
  push ds
  push es

  { Load clipped rectangle dimensions directly from local variables }
  mov cx, ClippedRect.Width   { CX = ClippedRect.Width }
  mov dx, ClippedRect.Height  { DX = ClippedRect.Height }

  { Save clipped width and height on stack }
  push cx               { Clipped width }
  push dx               { Clipped height }

  { Load Source image structure }
  les di, Source
  mov bx, es:[di]       { BX = Source.Width (for stride calculation) }

  { Calculate source starting offset based on FlipY }
  cmp byte ptr FlipY, 0
  je @NoFlipY_Offset

  { FlipY: Start from bottom row }
  mov ax, ClippedRect.Y       { AX = ClippedRect.Y }
  add ax, ClippedRect.Height  { AX = ClippedRect.Y + ClippedRect.Height }
  dec ax                      { AX = last row }
  jmp @CalcOffset

@NoFlipY_Offset:
  { Normal: Start from top row }
  mov ax, ClippedRect.Y       { AX = ClippedRect.Y }

@CalcOffset:
  pop dx                { Restore clipped height }
  pop cx                { Restore clipped width }
  push cx               { Save again }
  push dx
  push dx               { Save row count }
  mul bx                { DX:AX = Row * Source.Width }
  add ax, ClippedRect.X { AX += ClippedRect.X }
  mov si, ax            { SI = source offset }
  pop dx                { Restore row count }

  { Load source data pointer and add offset }
  les di, Source
  mov ax, si            { Save calculated offset in AX }
  lds si, es:[di+4]     { DS:SI = Source.Data base pointer }
  add si, ax            { DS:SI = Source.Data + offset }

  { If FlipX, adjust SI to end of row }
  cmp byte ptr FlipX, 0
  je @NoFlipX_SrcAdjust
  pop dx                { Get clipped height }
  pop cx                { Get clipped width }
  add si, cx            { SI now at end of row }
  dec si                { SI at last pixel of row }
  push cx
  push dx

@NoFlipX_SrcAdjust:
  { Calculate destination starting address }
  les di, FrameBuffer
  mov ax, ClippedY
  pop dx                { Restore clipped height }
  pop cx                { Restore clipped width }
  push cx               { Save pixels per row }
  push dx               { Save row count }
  push cx
  mov cx, 320
  mul cx                { DX:AX = ClippedY * 320 }
  pop cx
  add ax, ClippedX      { AX = ClippedY * 320 + ClippedX }
  add di, ax            { ES:DI = FrameBuffer + offset }
  pop dx                { Restore row count }
  pop cx                { Restore pixels per row }

  { Determine code path: FlipY(bit2) FlipX(bit1) Transparent(bit0) }
  xor ah, ah
  mov al, byte ptr FlipY
  shl al, 1
  or al, byte ptr FlipX
  shl al, 1
  or al, byte ptr Transparent

  cmp al, 0
  je @Path0_NormalOpaque
  cmp al, 1
  je @Path1_NormalTransparent
  cmp al, 2
  je @Path2_FlipXOpaque
  cmp al, 3
  je @Path3_FlipXTransparent
  cmp al, 4
  je @Path4_FlipYOpaque
  cmp al, 5
  je @Path5_FlipYTransparent
  cmp al, 6
  je @Path6_FlipXYOpaque
  jmp @Path7_FlipXYTransparent

{ ========== Path 0: Normal Opaque (REP MOVSB) ========== }
@Path0_NormalOpaque:
  push cx
  cld
  rep movsb
  pop cx
  add di, 320
  sub di, cx
  add si, bx
  sub si, cx
  dec dx
  jnz @Path0_NormalOpaque
  jmp @Done

{ ========== Path 1: Normal Transparent ========== }
@Path1_NormalTransparent:
  push cx
@Path1_PixelLoop:
  lodsb
  or al, al
  jz @Path1_Skip
  mov es:[di], al
@Path1_Skip:
  inc di
  loop @Path1_PixelLoop
  pop cx
  add di, 320
  sub di, cx
  add si, bx
  sub si, cx
  dec dx
  jnz @Path1_NormalTransparent
  jmp @Done

{ ========== Path 2: FlipX Opaque ========== }
@Path2_FlipXOpaque:
  push cx
@Path2_PixelLoop:
  mov al, [si]
  stosb
  dec si
  loop @Path2_PixelLoop
  pop cx
  add di, 320
  sub di, cx
  add si, bx
  add si, cx
  dec dx
  jnz @Path2_FlipXOpaque
  jmp @Done

{ ========== Path 3: FlipX Transparent ========== }
@Path3_FlipXTransparent:
  push cx
@Path3_PixelLoop:
  mov al, [si]
  or al, al
  jz @Path3_Skip
  mov es:[di], al
@Path3_Skip:
  inc di
  dec si
  loop @Path3_PixelLoop
  pop cx
  add di, 320
  sub di, cx
  add si, bx
  add si, cx
  dec dx
  jnz @Path3_FlipXTransparent
  jmp @Done

{ ========== Path 4: FlipY Opaque ========== }
@Path4_FlipYOpaque:
  push cx
  cld
  rep movsb
  pop cx
  add di, 320
  sub di, cx
  sub si, bx
  sub si, cx
  dec dx
  jnz @Path4_FlipYOpaque
  jmp @Done

{ ========== Path 5: FlipY Transparent ========== }
@Path5_FlipYTransparent:
  push cx
@Path5_PixelLoop:
  lodsb
  or al, al
  jz @Path5_Skip
  mov es:[di], al
@Path5_Skip:
  inc di
  loop @Path5_PixelLoop
  pop cx
  add di, 320
  sub di, cx
  sub si, bx
  sub si, cx
  dec dx
  jnz @Path5_FlipYTransparent
  jmp @Done

{ ========== Path 6: FlipX+FlipY Opaque ========== }
@Path6_FlipXYOpaque:
  push cx
@Path6_PixelLoop:
  mov al, [si]
  stosb
  dec si
  loop @Path6_PixelLoop
  pop cx
  add di, 320
  sub di, cx
  sub si, bx
  add si, cx
  dec dx
  jnz @Path6_FlipXYOpaque
  jmp @Done

{ ========== Path 7: FlipX+FlipY Transparent ========== }
@Path7_FlipXYTransparent:
  push cx
@Path7_PixelLoop:
  mov al, [si]
  or al, al
  jz @Path7_Skip
  mov es:[di], al
@Path7_Skip:
  inc di
  dec si
  loop @Path7_PixelLoop
  pop cx
  add di, 320
  sub di, cx
  sub si, bx
  add si, cx
  dec dx
  jnz @Path7_FlipXYTransparent

@Done:
  pop es
  pop ds
  end;
end;

procedure FreeImage(var Image: TImage);
var
  ImageSize: LongInt;
begin
  if Image.Data <> nil then
  begin
    ImageSize := LongInt(Image.Width) * LongInt(Image.Height);
    FreeMem(Image.Data, ImageSize);
    Image.Data := nil;
  end;
  Image.Width := 0;
  Image.Height := 0;
end;

procedure ClearImage(var Image: TImage);
var
  ImageSize: LongInt;
begin
  if Image.Data <> nil then
  begin
    ImageSize := LongInt(Image.Width) * LongInt(Image.Height);
    FillChar(Image.Data^, ImageSize, 0);
  end;
end;

begin
  { Initialize default clipping rectangle to full screen }
  ClipRectangle.X := 0;
  ClipRectangle.Y := 0;
  ClipRectangle.Width := 320;
  ClipRectangle.Height := 200;
end.
