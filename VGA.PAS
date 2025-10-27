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

procedure InitVGA;
procedure CloseVGA;
function CreateFrameBuffer: PFrameBuffer;
procedure ClearFrameBuffer(FrameBuffer: PFrameBuffer);
procedure FreeFrameBuffer(var FrameBuffer: PFrameBuffer);
procedure TestCenterPixel(FrameBuffer: PFrameBuffer);
procedure RenderFrameBuffer(FrameBuffer: PFrameBuffer);
procedure SetPalette(const Palette: TPalette);
function LoadPalette(const FileName: string; var Palette: TPalette): Boolean;

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

procedure ClearFrameBuffer(FrameBuffer: PFrameBuffer);
begin
  FillChar(FrameBuffer^, 64000, 0);
end;

procedure FreeFrameBuffer(var FrameBuffer: PFrameBuffer);
begin
  FreeMem(FrameBuffer, 64000);
  FrameBuffer := nil;
end;

procedure TestCenterPixel(FrameBuffer: PFrameBuffer); assembler;
asm
  les di, FrameBuffer
  mov ax, 32160
  add di, ax
  mov ax, 10
  mov [es:di], ax
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

end.