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