unit XMS;

{
  Minimal XMS interface for Turbo Pascal 7 (real mode).

  Features:
    - XMS_Init            : detect XMS driver, store entry point
    - XMS_GetVersion      : optional utility
    - XMS_AllocKB         : allocate block in extended memory (size in KB)
    - XMS_Free            : free that block
    - XMS_MoveToXMS       : copy from conventional RAM -> XMS block
    - XMS_MoveFromXMS     : copy from XMS block -> conventional RAM

  Notes:
    - You can't get a direct pointer into XMS. You "move" bytes in/out.
    - We rely on the XMS driver's "Move Extended Memory Block" function.
    - All offsets/lengths must fit in 32-bit values, but TP7 can't do 32-bit
      arithmetic automatically, so we pass them split as words.
    - This is a minimal version. You can build helpers on top of it
      (sprite banks, tilemap banks, etc).
}

interface

type
  TXMSHandle = word;

  { Result codes }
  TXMSBoolean = boolean;

  { Record passed to XMS move function }
  TXMSMoveRec = record
    Length: longint;       { bytes to move }
    SrcHandle: word;       { 0 = conventional mem, else XMS handle }
    SrcOffset: longint;    { if SrcHandle=0: segment:offset packed in Segment*16+Offset }
    DstHandle: word;       { 0 = conventional mem }
    DstOffset: longint;
  end;

function XMS_Init: TXMSBoolean;
function XMS_IsPresent: TXMSBoolean;
function XMS_GetVersion: word;

function XMS_AllocKB(KB: word; var Handle: TXMSHandle): TXMSBoolean;
function XMS_Free(Handle: TXMSHandle): TXMSBoolean;

function XMS_MoveToXMS(Handle: TXMSHandle; XmsDestOfs: longint;
                       SrcSeg, SrcOfs: word;
                       Count: word): TXMSBoolean;

function XMS_MoveFromXMS(Handle: TXMSHandle; XmsSrcOfs: longint;
                         DstSeg, DstOfs: word;
                         Count: word): TXMSBoolean;

implementation

var
  XMS_EntryPoint : pointer;  { call gate to XMS driver }
  XMS_Present    : boolean;
  XMS_EntryOfs   : word;
  XMS_EntrySeg   : word;

{
  Low-level helper to call XMS driver.
  AH = function number.
  On return:
    - AL often = status (1 = OK, 0 = fail)
    - Other regs depend on function.
}
procedure XMS_Call;
type
  TXMSProc = procedure; far;
var
  XMSProc: TXMSProc;
begin
  { Convert pointer to far procedure and call it }
  XMSProc := TXMSProc(XMS_EntryPoint);
  XMSProc;
end;

function XMS_Init: TXMSBoolean;
{ Detect XMS driver and get entry point via INT 2Fh }
begin
  { Int 2Fh, AX=4300h: check for XMS driver }
  asm
    mov ax, $4300
    int $2F
    cmp al, $80
    jne @no_xms
    mov XMS_Present, 1
    jmp @got
@no_xms:
    mov XMS_Present, 0
@got:
  end;

  if not XMS_Present then
  begin
    XMS_EntryPoint := nil;
    XMS_Init := false;
    exit;
  end;

  { Int 2Fh, AX=4310h: get XMS driver entry point in ES:BX }
  asm
    mov ax, $4310
    int $2F
    mov word ptr XMS_EntryPoint+0, bx
    mov word ptr XMS_EntryPoint+2, es
    mov XMS_EntryOfs, bx
    mov XMS_EntrySeg, es
  end;

  XMS_Init := true;
end;

function XMS_IsPresent: TXMSBoolean;
begin
  XMS_IsPresent := XMS_Present;
end;

function XMS_GetVersion: word;
{ AH=$00 -> Get XMS version. Returns AL=major, AH=minor }
var
  ver: word;
begin
  ver := 0;
  asm
    mov ah, $00
    call XMS_Call
    mov bl, al    { major in AL }
    mov bh, ah    { minor in AH }
    mov ver, bx
  end;
  XMS_GetVersion := ver;  { hi byte = minor, lo byte = major }
end;

function XMS_AllocKB(KB: word; var Handle: TXMSHandle): TXMSBoolean;
{ AH=$09 Allocate Extended Memory Block
  DX= size in KB
  Returns: AX=handle if AL=1, else AL=0 fail }
var
  ok: byte;
  h : word;
begin
  ok := 0;
  h  := 0;
  asm
    mov ah, $09
    mov dx, KB
    call XMS_Call
    mov ok, al
    mov h, ax
  end;
  Handle := h;
  XMS_AllocKB := (ok = 1);
end;

function XMS_Free(Handle: TXMSHandle): TXMSBoolean;
{ AH=$0A Free Extended Memory Block
  DX = handle }
var
  ok: byte;
begin
  ok := 0;
  asm
    mov ah, $0A
    mov dx, Handle
    call XMS_Call
    mov ok, al
  end;
  XMS_Free := (ok = 1);
end;

function XMS_DoMove(var M: TXMSMoveRec): boolean; assembler;
{ AH=$0B Move Extended Memory Block
  DS:SI -> move structure
  Returns: AL=1 if success, AL=0 if fail (AH contains error code if fail) }
asm
  push ds
  lds  si, M
  mov  ah, $0B
  call XMS_Call
  pop  ds
  { AL now contains: 1=success, 0=fail }
  { Turbo Pascal boolean: True=1, False=0, so AL is already correct }
  and  al, 1  { Ensure it's exactly 0 or 1 }
end;

function MakeLinearAddr(Segm, Ofs: word): longint;
{ Convert segment:offset to linear 20-bit style (Seg*16+Ofs),
  stored in a 32-bit longint for the XMS structure. }
var
  tmp: longint;
begin
  tmp := longint(Segm) shl 4;
  tmp := tmp + Ofs;
  MakeLinearAddr := tmp;
end;

function XMS_MoveToXMS(Handle: TXMSHandle; XmsDestOfs: longint;
                       SrcSeg, SrcOfs: word;
                       Count: word): TXMSBoolean;
{ Copy Count bytes from conventional memory buffer (SrcSeg:SrcOfs)
  into XMS block Handle at offset XmsDestOfs. }
var
  M: TXMSMoveRec;
begin
  M.Length    := Count;
  M.SrcHandle := 0;  { 0 means source is conventional RAM }
  M.SrcOffset := MakeLinearAddr(SrcSeg, SrcOfs);

  M.DstHandle := Handle;
  M.DstOffset := XmsDestOfs;

  XMS_MoveToXMS := XMS_DoMove(M);
end;

function XMS_MoveFromXMS(Handle: TXMSHandle; XmsSrcOfs: longint;
                         DstSeg, DstOfs: word;
                         Count: word): TXMSBoolean;
{ Copy Count bytes from XMS block Handle at offset XmsSrcOfs
  into conventional memory buffer (DstSeg:DstOfs). }
var
  M: TXMSMoveRec;
begin
  M.Length    := Count;
  M.SrcHandle := Handle;
  M.SrcOffset := XmsSrcOfs;

  M.DstHandle := 0; { 0 means dest is conventional RAM }
  M.DstOffset := MakeLinearAddr(DstSeg, DstOfs);

  XMS_MoveFromXMS := XMS_DoMove(M);
end;

end.
