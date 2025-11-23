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
procedure CloseVGA;
function CreateFrameBuffer: PFrameBuffer;  { Allocates off-screen buffer for double-buffering }
function GetScreenBuffer: PFrameBuffer;    { Returns pointer to VGA memory for direct drawing }
procedure ClearFrameBuffer(FrameBuffer: PFrameBuffer);
procedure CopyFrameBuffer(Source, Dest: PFrameBuffer);  { Fast copy from Source to Dest }
procedure CopyFrameBufferRect(Source: PFrameBuffer; var SourceRect: TRectangle; Dest: PFrameBuffer; DestX, DestY: Word);
procedure FreeFrameBuffer(var FrameBuffer: PFrameBuffer);
procedure RenderFrameBuffer(FrameBuffer: PFrameBuffer);
procedure SetPalette(const Palette: TPalette);
procedure RotatePalette(var Palette: TPalette; StartColor: Byte; Count: Byte; Direction: ShortInt);
function LoadPalette(const FileName: string; var Palette: TPalette): Boolean;
procedure WaitForVSync;

{ Drawing primitives }
procedure DrawLine(X1, Y1, X2, Y2: Integer; Color: Byte; FrameBuffer: PFrameBuffer);

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

  { --- Clipping Logic (Preserved from original) --- }
  
  { Clip source rectangle to source buffer bounds }
  if SrcX < 0 then
  begin
    Width := Width + SrcX;
    DstX := DstX - SrcX;
    SrcX := 0;
  end;

  if SrcY < 0 then
  begin
    Height := Height + SrcY;
    DstY := DstY - SrcY;
    SrcY := 0;
  end;

  if SrcX + Width > 320 then
    Width := 320 - SrcX;

  if SrcY + Height > 200 then
    Height := 200 - SrcY;

  { Clip destination to destination buffer bounds }
  if DstX < 0 then
  begin
    Width := Width + DstX;
    SrcX := SrcX - DstX;
    DstX := 0;
  end;

  if DstY < 0 then
  begin
    Height := Height + DstY;
    SrcY := SrcY - DstY;
    DstY := 0;
  end;

  if DstX + Width > 320 then
    Width := 320 - DstX;

  if DstY + Height > 200 then
    Height := 200 - DstY;

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

procedure RotatePalette(var Palette: TPalette; StartColor: Byte; Count: Byte; Direction: ShortInt);
{ Rotates a range of palette colors for animation effects }
{ Direction: 1 = rotate right (colors shift up), -1 = rotate left (colors shift down) }
var
  i: Byte;
  TempColor: TRGBColor;
begin
  if Count <= 1 then
    Exit;  { Nothing to rotate }

  if Direction > 0 then
  begin
    { Rotate right: save last color, shift all down, put saved at start }
    TempColor := Palette[StartColor + Count - 1];
    for i := Count - 1 downto 1 do
      Palette[StartColor + i] := Palette[StartColor + i - 1];
    Palette[StartColor] := TempColor;
  end
  else if Direction < 0 then
  begin
    { Rotate left: save first color, shift all up, put saved at end }
    TempColor := Palette[StartColor];
    for i := 0 to Count - 2 do
      Palette[StartColor + i] := Palette[StartColor + i + 1];
    Palette[StartColor + Count - 1] := TempColor;
  end;
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

{ Drawing primitives }

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
begin
  { Early exit checks - completely off screen }
  if (X >= 320) or (Y >= 200) or
     (X + Integer(SourceRect.Width) <= 0) or
     (Y + Integer(SourceRect.Height) <= 0) then
    Exit;

  { Initialize clipped values with original parameters }
  ClippedRect := SourceRect;
  ClippedX := X;
  ClippedY := Y;

  { Clip left edge (screen X < 0) }
  if X < 0 then
  begin
    ClipAmount := -X;
    ClippedX := 0;

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

  { Clip top edge (screen Y < 0) }
  if Y < 0 then
  begin
    ClipAmount := -Y;
    ClippedY := 0;

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

  { Clip right edge (screen X + Width > 320) }
  if ClippedX + Integer(ClippedRect.Width) > 320 then
  begin
    ClipAmount := ClippedX + Integer(ClippedRect.Width) - 320;

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

  { Clip bottom edge (screen Y + Height > 200) }
  if ClippedY + Integer(ClippedRect.Height) > 200 then
  begin
    ClipAmount := ClippedY + Integer(ClippedRect.Height) - 200;

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

end.
