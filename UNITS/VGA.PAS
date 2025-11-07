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
                              FrameBuffer: PFrameBuffer); assembler;
{ Optimized assembly version with 8 specialized code paths for flip combinations }
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

  { Save clipped width and height on stack }
  push cx               { Clipped width }
  push dx               { Clipped height }

  { Calculate pixels per row: min(SourceRect.Width, 320 - X) }
  mov ax, 320
  sub ax, X             { AX = 320 - X = max pixels we can draw per row }
  cmp cx, ax
  jbe @WidthOK
  mov cx, ax            { CX = min(SourceRect.Width, 320 - X) }
@WidthOK:
  or cx, cx
  jnz @Continue         { Continue if there are pixels to draw }
  pop dx               
  pop cx
  jmp @Done
@Continue:
  { Load Source image structure }
  les di, Source
  mov bx, es:[di]       { BX = Source.Width (for stride calculation) }

  { Calculate source starting offset based on FlipY }
  les di, SourceRect
  cmp byte ptr FlipY, 0
  je @NoFlipY_Offset

  { FlipY: Start from bottom row }
  mov ax, es:[di+2]     { AX = SourceRect.Y }
  add ax, es:[di+6]     { AX = SourceRect.Y + SourceRect.Height }
  dec ax                { AX = last row }
  jmp @CalcOffset

@NoFlipY_Offset:
  { Normal: Start from top row }
  mov ax, es:[di+2]     { AX = SourceRect.Y }

@CalcOffset:
  pop dx                { Restore clipped height }
  pop cx                { Restore clipped width }
  push cx               { Save again }
  push dx
  push dx               { Save row count }
  mul bx                { DX:AX = Row * Source.Width }
  les di, SourceRect
  add ax, es:[di]       { AX += SourceRect.X }
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
  mov ax, Y
  pop dx                { Restore clipped height }
  pop cx                { Restore clipped width }
  push cx               { Save pixels per row }
  push dx               { Save row count }
  push cx
  mov cx, 320
  mul cx                { DX:AX = Y * 320 }
  pop cx
  add ax, X             { AX = Y * 320 + X }
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