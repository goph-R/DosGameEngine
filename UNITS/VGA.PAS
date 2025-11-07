unit vga;

{$G+}  { Enable 286 instructions }

interface

type
  TRGBColor = record
    R, G, B: Byte;
  end;

  TPalette = array[0..255] of TRGBColor;

  PFrameBuffer = ^TFrameBuffer;
  TFrameBuffer = array[0..63999] of byte;

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
procedure CloseVGA;
function CreateFrameBuffer: PFrameBuffer;  { Allocates off-screen buffer for double-buffering }
function GetScreenBuffer: PFrameBuffer;    { Returns pointer to VGA memory for direct drawing }
procedure ClearFrameBuffer(FrameBuffer: PFrameBuffer);
procedure CopyFrameBuffer(Source, Dest: PFrameBuffer);  { Fast copy from Source to Dest }
procedure FreeFrameBuffer(var FrameBuffer: PFrameBuffer);
procedure RenderFrameBuffer(FrameBuffer: PFrameBuffer);
procedure SetPalette(const Palette: TPalette);
function LoadPalette(const FileName: string; var Palette: TPalette): Boolean;
procedure WaitForVSync;

{ Text operations }
procedure PrintText(x, y: Integer; s: string; Color: Byte; FrameBuffer: PFrameBuffer);

{ Image operations }
procedure GetImage(var Image: TImage; X, Y, Width, Height: Word; FrameBuffer: PFrameBuffer);
procedure PutImage(var Image: TImage; X, Y: Word; Transparent: Boolean; FrameBuffer: PFrameBuffer);
procedure PutImageRect(var Source: TImage; var SourceRect: TRectangle;
                       X, Y: Integer; Transparent: Boolean; FrameBuffer: PFrameBuffer);
procedure FreeImage(var Image: TImage);
procedure ClearImage(var Image: TImage);

implementation

var
  OldMode: byte;

{ Embedded 8x8 font data - basic ASCII printable characters (32-127) }
{ Each character is 8 bytes, each byte is one row of 8 pixels }
const
  Font8x8: array[32..127, 0..7] of Byte = (
    { Space (32) }
    ($00, $00, $00, $00, $00, $00, $00, $00),
    { ! (33) }
    ($18, $3C, $3C, $18, $18, $00, $18, $00),
    { " (34) }
    ($36, $36, $36, $00, $00, $00, $00, $00),
    { # (35) }
    ($36, $36, $7F, $36, $7F, $36, $36, $00),
    { $ (36) }
    ($0C, $3E, $03, $1E, $30, $1F, $0C, $00),
    { % (37) }
    ($00, $63, $33, $18, $0C, $66, $63, $00),
    { & (38) }
    ($1C, $36, $1C, $6E, $3B, $33, $6E, $00),
    { ' (39) }
    ($06, $06, $03, $00, $00, $00, $00, $00),
    { ( (40) }
    ($18, $0C, $06, $06, $06, $0C, $18, $00),
    { ) (41) }
    ($06, $0C, $18, $18, $18, $0C, $06, $00),
    { * (42) }
    ($00, $66, $3C, $FF, $3C, $66, $00, $00),
    { + (43) }
    ($00, $0C, $0C, $3F, $0C, $0C, $00, $00),
    { , (44) }
    ($00, $00, $00, $00, $00, $0C, $0C, $06),
    { - (45) }
    ($00, $00, $00, $3F, $00, $00, $00, $00),
    { . (46) }
    ($00, $00, $00, $00, $00, $0C, $0C, $00),
    { / (47) }
    ($60, $30, $18, $0C, $06, $03, $01, $00),
    { 0 (48) }
    ($3E, $63, $73, $7B, $6F, $67, $3E, $00),
    { 1 (49) }
    ($0C, $0E, $0C, $0C, $0C, $0C, $3F, $00),
    { 2 (50) }
    ($1E, $33, $30, $1C, $06, $33, $3F, $00),
    { 3 (51) }
    ($1E, $33, $30, $1C, $30, $33, $1E, $00),
    { 4 (52) }
    ($38, $3C, $36, $33, $7F, $30, $78, $00),
    { 5 (53) }
    ($3F, $03, $1F, $30, $30, $33, $1E, $00),
    { 6 (54) }
    ($1C, $06, $03, $1F, $33, $33, $1E, $00),
    { 7 (55) }
    ($3F, $33, $30, $18, $0C, $0C, $0C, $00),
    { 8 (56) }
    ($1E, $33, $33, $1E, $33, $33, $1E, $00),
    { 9 (57) }
    ($1E, $33, $33, $3E, $30, $18, $0E, $00),
    { : (58) }
    ($00, $0C, $0C, $00, $00, $0C, $0C, $00),
    { ; (59) }
    ($00, $0C, $0C, $00, $00, $0C, $0C, $06),
    { < (60) }
    ($18, $0C, $06, $03, $06, $0C, $18, $00),
    { = (61) }
    ($00, $00, $3F, $00, $00, $3F, $00, $00),
    { > (62) }
    ($06, $0C, $18, $30, $18, $0C, $06, $00),
    { ? (63) }
    ($1E, $33, $30, $18, $0C, $00, $0C, $00),
    { @ (64) }
    ($3E, $63, $7B, $7B, $7B, $03, $1E, $00),
    { A (65) }
    ($0C, $1E, $33, $33, $3F, $33, $33, $00),
    { B (66) }
    ($3F, $66, $66, $3E, $66, $66, $3F, $00),
    { C (67) }
    ($3C, $66, $03, $03, $03, $66, $3C, $00),
    { D (68) }
    ($1F, $36, $66, $66, $66, $36, $1F, $00),
    { E (69) }
    ($7F, $46, $16, $1E, $16, $46, $7F, $00),
    { F (70) }
    ($7F, $46, $16, $1E, $16, $06, $0F, $00),
    { G (71) }
    ($3C, $66, $03, $03, $73, $66, $7C, $00),
    { H (72) }
    ($33, $33, $33, $3F, $33, $33, $33, $00),
    { I (73) }
    ($1E, $0C, $0C, $0C, $0C, $0C, $1E, $00),
    { J (74) }
    ($78, $30, $30, $30, $33, $33, $1E, $00),
    { K (75) }
    ($67, $66, $36, $1E, $36, $66, $67, $00),
    { L (76) }
    ($0F, $06, $06, $06, $46, $66, $7F, $00),
    { M (77) }
    ($63, $77, $7F, $7F, $6B, $63, $63, $00),
    { N (78) }
    ($63, $67, $6F, $7B, $73, $63, $63, $00),
    { O (79) }
    ($1C, $36, $63, $63, $63, $36, $1C, $00),
    { P (80) }
    ($3F, $66, $66, $3E, $06, $06, $0F, $00),
    { Q (81) }
    ($1E, $33, $33, $33, $3B, $1E, $38, $00),
    { R (82) }
    ($3F, $66, $66, $3E, $36, $66, $67, $00),
    { S (83) }
    ($1E, $33, $07, $0E, $38, $33, $1E, $00),
    { T (84) }
    ($3F, $2D, $0C, $0C, $0C, $0C, $1E, $00),
    { U (85) }
    ($33, $33, $33, $33, $33, $33, $3F, $00),
    { V (86) }
    ($33, $33, $33, $33, $33, $1E, $0C, $00),
    { W (87) }
    ($63, $63, $63, $6B, $7F, $77, $63, $00),
    { X (88) }
    ($63, $63, $36, $1C, $1C, $36, $63, $00),
    { Y (89) }
    ($33, $33, $33, $1E, $0C, $0C, $1E, $00),
    { Z (90) }
    ($7F, $63, $31, $18, $4C, $66, $7F, $00),
    { [ (91) }
    ($1E, $06, $06, $06, $06, $06, $1E, $00),
    { \ (92) }
    ($03, $06, $0C, $18, $30, $60, $40, $00),
    { ] (93) }
    ($1E, $18, $18, $18, $18, $18, $1E, $00),
    { ^ (94) }
    ($08, $1C, $36, $63, $00, $00, $00, $00),
    { _ (95) }
    ($00, $00, $00, $00, $00, $00, $00, $FF),
    { ` (96) }
    ($0C, $0C, $18, $00, $00, $00, $00, $00),
    { a (97) }
    ($00, $00, $1E, $30, $3E, $33, $6E, $00),
    { b (98) }
    ($07, $06, $06, $3E, $66, $66, $3B, $00),
    { c (99) }
    ($00, $00, $1E, $33, $03, $33, $1E, $00),
    { d (100) }
    ($38, $30, $30, $3E, $33, $33, $6E, $00),
    { e (101) }
    ($00, $00, $1E, $33, $3F, $03, $1E, $00),
    { f (102) }
    ($1C, $36, $06, $0F, $06, $06, $0F, $00),
    { g (103) }
    ($00, $00, $6E, $33, $33, $3E, $30, $1F),
    { h (104) }
    ($07, $06, $36, $6E, $66, $66, $67, $00),
    { i (105) }
    ($0C, $00, $0E, $0C, $0C, $0C, $1E, $00),
    { j (106) }
    ($30, $00, $30, $30, $30, $33, $33, $1E),
    { k (107) }
    ($07, $06, $66, $36, $1E, $36, $67, $00),
    { l (108) }
    ($0E, $0C, $0C, $0C, $0C, $0C, $1E, $00),
    { m (109) }
    ($00, $00, $33, $7F, $7F, $6B, $63, $00),
    { n (110) }
    ($00, $00, $1F, $33, $33, $33, $33, $00),
    { o (111) }
    ($00, $00, $1E, $33, $33, $33, $1E, $00),
    { p (112) }
    ($00, $00, $3B, $66, $66, $3E, $06, $0F),
    { q (113) }
    ($00, $00, $6E, $33, $33, $3E, $30, $78),
    { r (114) }
    ($00, $00, $3B, $6E, $66, $06, $0F, $00),
    { s (115) }
    ($00, $00, $3E, $03, $1E, $30, $1F, $00),
    { t (116) }
    ($08, $0C, $3E, $0C, $0C, $2C, $18, $00),
    { u (117) }
    ($00, $00, $33, $33, $33, $33, $6E, $00),
    { v (118) }
    ($00, $00, $33, $33, $33, $1E, $0C, $00),
    { w (119) }
    ($00, $00, $63, $6B, $7F, $7F, $36, $00),
    { x (120) }
    ($00, $00, $63, $36, $1C, $36, $63, $00),
    { y (121) }
    ($00, $00, $33, $33, $33, $3E, $30, $1F),
    { z (122) }
    ($00, $00, $3F, $19, $0C, $26, $3F, $00),
    { { (123) }
    ($38, $0C, $0C, $07, $0C, $0C, $38, $00),
    { | (124) }
    ($18, $18, $18, $00, $18, $18, $18, $00),
    {  (125) }
    ($07, $0C, $0C, $38, $0C, $0C, $07, $00),
    { ~ (126) }
    ($6E, $3B, $00, $00, $00, $00, $00, $00),
    { DEL (127) }
    ($00, $00, $00, $00, $00, $00, $00, $00)
  );

procedure InitVGA; assembler;
asm
  mov ax, 0f00h
  int 10h
  mov OldMode, al

  mov ax, 13h
  int 10h
end;

procedure CloseVGA; assembler;
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

{ Text operations }

procedure PrintText(x, y: Integer; s: string; Color: Byte; FrameBuffer: PFrameBuffer);
var
  i, CharIndex: Integer;
  CharRow, Bit: Byte;
  PixelX, PixelY: Integer;
  DestPtr: ^Byte;
begin
  { Draw each character }
  for i := 1 to Length(s) do
  begin
    CharIndex := Ord(s[i]);

    { Only support printable ASCII (32-127) }
    if (CharIndex < 32) or (CharIndex > 127) then
      CharIndex := 32; { Replace with space }

    { Draw the 8x8 character bitmap }
    for PixelY := 0 to 7 do
    begin
      if (y + PixelY < 0) or (y + PixelY >= 200) then
        Continue;

      { Get the font row for this character }
      CharRow := Font8x8[CharIndex, PixelY];

      for Bit := 0 to 7 do
      begin
        PixelX := x + (i - 1) * 8 + Bit;

        if (PixelX < 0) or (PixelX >= 320) then
          Continue;

        { Check if bit is set in font bitmap (LSB = leftmost pixel) }
        if (CharRow and ($01 shl Bit)) <> 0 then
        begin
          DestPtr := @FrameBuffer^[(y + PixelY) * 320 + PixelX];
          DestPtr^ := Color;
        end;
      end;
    end;
  end;
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

procedure PutImage(var Image: TImage; X, Y: Word; Transparent: Boolean; FrameBuffer: PFrameBuffer); assembler;
{ Optimized assembly version - much faster than Pascal loops }
asm
  push ds
  push es

  { Check if Y >= 200, exit if so }
  mov ax, Y
  cmp ax, 200
  jae @Done

  { Load Image structure address }
  les di, Image

  { Calculate number of rows to draw (min of Image.Height and 200 - Y) }
  mov cx, 200
  sub cx, Y           { CX = 200 - Y = max rows we can draw }
  mov dx, es:[di+2]   { DX = Image.Height }
  cmp dx, cx
  jbe @HeightOK
  mov dx, cx          { DX = min(Image.Height, 200 - Y) }
@HeightOK:
  or dx, dx
  jz @Done            { Exit if no rows to draw }

  { Calculate bytes per row to draw (min of Image.Width and 320 - X) }
  mov ax, 320
  sub ax, X           { AX = 320 - X = max pixels we can draw per row }
  mov cx, es:[di]     { CX = Image.Width }
  mov bx, cx          { BX = Image.Width (save for later) }
  cmp cx, ax
  jbe @WidthOK
  mov cx, ax          { CX = min(Image.Width, 320 - X) }
@WidthOK:
  jcxz @Done          { Exit if no pixels to draw }

  { Load source pointer from Image.Data }
  lds si, es:[di+4]   { DS:SI = Image.Data }

  { Calculate destination starting address }
  les di, FrameBuffer
  mov ax, Y
  push dx             { Save row count }
  mov dx, 320
  mul dx              { DX:AX = Y * 320 }
  add ax, X           { AX = Y * 320 + X }
  add di, ax          { ES:DI = FrameBuffer + offset }
  pop dx              { Restore row count }

  { Check transparent flag }
  cmp byte ptr Transparent, 0
  jne @TransparentLoop

  { Non-transparent blit - fast REP MOVSB for each row }
@FastLoop:
  push cx
  cld
  rep movsb           { Copy CX bytes from DS:SI to ES:DI }
  pop cx

  { Advance to next row }
  add di, 320
  sub di, cx          { DI += 320 - pixels_drawn }
  add si, bx
  sub si, cx          { SI += Image.Width - pixels_drawn }

  dec dx
  jnz @FastLoop
  jmp @Done

  { Transparent blit - check each pixel }
@TransparentLoop:
  push cx             { Save pixels per row }

@PixelLoop:
  lodsb               { AL = [DS:SI++] }
  or al, al
  jz @Skip            { Skip if pixel is 0 }
  mov es:[di], al     { Write pixel }
@Skip:
  inc di
  loop @PixelLoop

  { Advance to next row }
  pop cx              { Restore pixels per row }
  add di, 320
  sub di, cx          { DI += 320 - pixels_drawn }
  add si, bx
  sub si, cx          { SI += Image.Width - pixels_drawn }

  dec dx
  jnz @TransparentLoop

@Done:
  pop es
  pop ds
end;

procedure PutImageRect(var Source: TImage; var SourceRect: TRectangle; X, Y: Integer;
                       Transparent: Boolean; FrameBuffer: PFrameBuffer); assembler;
{ Optimized assembly version - blits a rectangular region from source image }
asm
  push ds
  push es

  { Check if Y >= 200, exit if so }
  mov ax, Y
  cmp ax, 200
  jge @Done

  { Load SourceRect structure to get dimensions }
  les di, SourceRect
  mov cx, es:[di+4]     { CX = SourceRect.Width }
  mov dx, es:[di+6]     { DX = SourceRect.Height }

  { Calculate rows to draw: min(SourceRect.Height, 200 - Y) }
  mov ax, 200
  sub ax, Y             { AX = 200 - Y = max rows we can draw }
  cmp dx, ax
  jbe @HeightOK
  mov dx, ax            { DX = min(SourceRect.Height, 200 - Y) }
@HeightOK:
  or dx, dx
  jz @Done              { Exit if no rows to draw }

  { Calculate pixels per row: min(SourceRect.Width, 320 - X) }
  mov ax, 320
  sub ax, X             { AX = 320 - X = max pixels we can draw per row }
  cmp cx, ax
  jbe @WidthOK
  mov cx, ax            { CX = min(SourceRect.Width, 320 - X) }
@WidthOK:
  jcxz @Done            { Exit if no pixels to draw }

  { Load Source image structure }
  les di, Source
  mov bx, es:[di]       { BX = Source.Width (for stride calculation) }

  { Calculate source starting offset: SourceRect.Y * Source.Width + SourceRect.X }
  les di, SourceRect
  mov ax, es:[di+2]     { AX = SourceRect.Y }
  push dx               { Save row count }
  mul bx                { DX:AX = SourceRect.Y * Source.Width }
  add ax, es:[di]       { AX += SourceRect.X }
  mov si, ax            { SI = source offset }
  pop dx                { Restore row count }

  { Load source data pointer and add offset }
  les di, Source
  push ds
  lds ax, es:[di+4]     { DS:AX = Source.Data }
  add si, ax            { DS:SI = Source.Data + offset }
  pop ax                { Discard temp DS }

  { Calculate destination starting address }
  les di, FrameBuffer
  mov ax, Y
  push dx               { Save row count }
  push cx               { Save pixels per row }
  mov cx, 320
  mul cx                { DX:AX = Y * 320 }
  pop cx                { Restore pixels per row }
  add ax, X             { AX = Y * 320 + X }
  add di, ax            { ES:DI = FrameBuffer + offset }
  pop dx                { Restore row count }

  { Check transparent flag }
  cmp byte ptr Transparent, 0
  jne @TransparentLoop

  { Non-transparent blit - fast REP MOVSB for each row }
@FastLoop:
  push cx
  cld
  rep movsb             { Copy CX bytes from DS:SI to ES:DI }
  pop cx

  { Advance to next row }
  add di, 320
  sub di, cx            { DI += 320 - pixels_drawn }
  add si, bx
  sub si, cx            { SI += Source.Width - pixels_drawn }

  dec dx
  jnz @FastLoop
  jmp @Done

  { Transparent blit - check each pixel }
@TransparentLoop:
  push cx               { Save pixels per row }

@PixelLoop:
  lodsb                 { AL = [DS:SI++] }
  or al, al
  jz @Skip              { Skip if pixel is 0 }
  mov es:[di], al       { Write pixel }
@Skip:
  inc di
  loop @PixelLoop

  { Advance to next row }
  pop cx                { Restore pixels per row }
  add di, 320
  sub di, cx            { DI += 320 - pixels_drawn }
  add si, bx
  sub si, cx            { SI += Source.Width - pixels_drawn }

  dec dx
  jnz @TransparentLoop

@Done:
  pop es
  pop ds
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

end.