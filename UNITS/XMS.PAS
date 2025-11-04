   {$I-,D-,L-,N-,E-,F+,O-,G-,X+,S-,R-,V-}

   {**************************************************}
   {*                                                *}
   {*    UNIT   XMS                                  *}
   {*          Copyright (c) 1992  KIV without Co    *}
   {*                                                *}
   {**************************************************}

   unit XMS;

   interface

   var XMSerror:Byte;

   type EMMstruct=record
                     size:LongInt;  {must be even!}
                     soh  :Word;     {source handle}
                     soo  :LongInt;  {source offset}
                     dsh  :Word;     {destination handle}
                     dso  :LongInt;  {destination offset}
                  end;
   { if handle=0 then correspond offset is pointer to RAM }

   function XMSinstalled:Boolean;

   procedure GetXMSmem(var Total:Word; var Block:Word);  {in Kb}
   function AllocXMS(Mem:Word):Word;                     {in Kb}
   function ReallocXMS(Handle, Mem:Word):Boolean;        {in Kb}
   function FreeXMS(Handle:Word):Boolean;
   function MoveXMS( var M:EMMstruct ):Boolean;
   function Mem2Xms( var Buf; Count,Handle:Word;
                    Offset:LongInt):Boolean;
   function Xms2Mem( Handle:Word; Offset:LongInt;
                     var Buf; Count:Word):Boolean;
   function LockBlock(Handle:Word; var Address:LongInt):Boolean;
   {return 32-bit linear address of locked block}

   function UnlockBlock(Handle:Word):Boolean;

   function GetXMShandleInfo(Handle:Word; var LockCount:Byte;
                             var FreeHandles:Byte;
                             var Size:Word):Boolean;


   function RequestHMA(Mem:Word):Boolean;  {in bytes; $FFFF for all}
   function ReleaseHMA:Boolean;


   function XMSerrorMSG(Error:Byte):string;

   function Debug_GetCallXMSBytes(var B0,B1,B2,B3,B4,B5,B6: Byte): Boolean;

   implementation

   const XMSinst:Boolean=FALSE;  {For reading only !!!}

   function XMSinstalled:Boolean;
   begin
       XMSinstalled:=XMSinst;
   end;

   procedure CallXMS; far; assembler;
   asm
       PUSH AX
       DB 90h,90h,90h,90h,90h
       POP  CX
       PUSH DS
       PUSH AX
                              { set XMSerror  \                     }
                              {               |                     }
       MOV  AX,SEG @DATA      {               |                     }
       MOV  DS,AX             {                > because ds may be  }
       POP  AX                {               |                     }
       PUSH AX                {               |    changed !        }
       CMP CH,08h             {               |                     }
       JE   @3                {               |                     }
       CMP  AX,1              {               |                     }
       JE   @1                {               |                     }
       @3:                    {               |                     }
       MOV  XMSERROR,BL       {               |                     }
       JMP  @2                {               |                     }
       @1:                    {               |                     }
       XOR  AX,AX             {               |                     }
       MOV  XMSERROR,AL       {               |                     }
       @2:                    {               |                     }
       POP  AX                {               |                     }
       POP  DS                {               /                     }
   end;

   function Debug_GetCallXMSBytes(var B0,B1,B2,B3,B4,B5,B6: Byte): Boolean;
var
  P: Pointer;
  S, O: Word;
begin
  { Address of CallXMS (local to unit) }
  P := @CallXMS;
  S := Seg(P^);
  O := Ofs(P^);

  B0 := Mem[S:O+0];
  B1 := Mem[S:O+1];
  B2 := Mem[S:O+2];
  B3 := Mem[S:O+3];
  B4 := Mem[S:O+4];
  B5 := Mem[S:O+5];
  B6 := Mem[S:O+6];

  Debug_GetCallXMSBytes := True;
end;


   procedure GetXMSmem(var Total:Word; var Block:Word); assembler;
   asm
       MOV   AH,08h
       CALL  CALLXMS
       LES   DI,TOTAL
       MOV   ES:[DI],DX
       LES   DI,BLOCK
       MOV   ES:[DI],AX
   end;

   function AllocXMS(Mem:Word):Word; assembler;
   asm
       MOV   DX,MEM
       MOV   AH,09h
       CALL  CALLXMS
       CMP   AX,1
       JNE   @1
       MOV   AX,DX
       JMP   @2
       @1:
       MOV   AX,0
       @2:
   end;

   function FreeXMS(Handle:Word):Boolean; assembler;
   asm
       MOV  DX,HANDLE
       MOV  AH,0Ah
       CALL CALLXMS
   end;

   function MoveXMS( VAR M:EMMstruct ):Boolean; assembler;
   asm
       PUSH DS
       LDS  SI,M
       MOV  AH,0Bh
       CALL CALLXMS
       POP  DS
   end;

   function RequestHMA(Mem:Word):Boolean; assembler;
   asm
       MOV   DX,MEM
       MOV   AH,01h
       CALL  CALLXMS
   end;

   function ReleaseHMA:Boolean; assembler;
   asm
       MOV  AH,02h
       CALL CALLXMS
   end;

   function ReallocXMS(Handle, Mem:Word):Boolean; assembler;
   asm
       MOV  DX,HANDLE
       MOV  BX,MEM
       MOV  AH,0Fh
       CALL CALLXMS
   end;
procedure MakeCall(p:pointer); far; assembler;
asm
    { 1. Check for XMS driver via INT 2Fh, AX=4300h }
    mov   ax,4300h
    int   2Fh              { AL = $80 if XMS present }
    cmp   al,80h
    jne   @EXITUS          { if not, skip everything }

    mov   XMSinst,1        { remember: XMS is available }

    { 2. Get XMS entry point via INT 2Fh, AX=4310h }
    mov   ax,4310h
    int   2Fh              { returns ES:BX = XMS driver entry point }
    mov   dx,es            { DX = segment of XMS entry }
    mov   cx,bx            { CX = offset of XMS entry }

    cld

    { 3. Patch CallXMS's 5 NOP bytes into a FAR CALL instruction }
    {    Save ES and DI because we'll change them }
    push  es
    push  di

    { IMPORTANT:
      Turbo Pascal already created a stack frame.
      For a FAR procedure with one pointer parameter "p",
      after TP's prologue:
        [BP+6] = offset of p
        [BP+8] = segment of p

      We passed @CallXMS as that parameter.
    }

    mov   ax,ss:[bp+8]     { AX = segment of CallXMS }
    mov   es,ax
    mov   di,ss:[bp+6]     { DI = offset of CallXMS }

    inc   di               { skip the first byte (PUSH AX) }

    mov   al,9Ah           { 9A = CALL FAR imm16:16 opcode }
    stosb                  { write opcode }

    mov   ax,cx            { AX = offset of XMS entry point }
    stosw                  { write <ofs> }

    mov   ax,dx            { AX = segment of XMS entry point }
    stosw                  { write <seg> }

    { restore DI and ES as they were before we messed with them }
    pop   di
    pop   es

@EXITUS:
    { no manual pop bp / retf here!
      Turbo Pascal will generate the normal epilogue/RETF for us }
end;




   function XMSerrorMSG(Error:Byte):string;
   begin
       case Error of
           $00:XMSerrorMSG:='successful';
           $80:XMSerrorMSG:='function not implemented';
           $81:XMSerrorMSG:='VDISK was detected';
           $82:XMSerrorMSG:='an A20 error occurred';
           $8E:XMSerrorMSG:='a general driver error';
           $8F:XMSerrorMSG:='unrecoverable driver error';
           $90:XMSerrorMSG:='HMA does not exist';
           $91:XMSerrorMSG:='HMA is already in use';
           $92:XMSerrorMSG:='DX is less then the /HMAMIN= parameter';
           $93:XMSerrorMSG:='HMA is not allocated';
           $94:XMSerrorMSG:='A20 line still enabled';
           $A0:XMSerrorMSG:='all extended memory is allocated';
           $A1:XMSerrorMSG:='all available extended memory handles are allocated';
           $A2:XMSerrorMSG:='invalid handle';
           $A3:XMSerrorMSG:='source handle is invalid';
           $A4:XMSerrorMSG:='source offset is invalid';
           $A5:XMSerrorMSG:='destination handle is invalid';
           $A6:XMSerrorMSG:='destination offset is invalid';
           $A7:XMSerrorMSG:='length is invalid';
           $A8:XMSerrorMSG:='move has an invalid overlap';
           $A9:XMSerrorMSG:='parity error occured';
           $AA:XMSerrorMSG:='block is not locked';
           $AB:XMSerrorMSG:='block is locked';
           $AC:XMSerrorMSG:='block lock count overflowed';
           $AD:XMSerrorMSG:='lock failed';
           $B0:XMSerrorMSG:='only a smaller UMB is available';
           $B1:XMSerrorMSG:='no UMB''s are available';
           $B2:XMSerrorMSG:='UMB segment number is invalid';
           else XMSerrorMSG:='unknown error';
       end;
   end;

   function LockBlock(Handle:Word; var Address:LongInt):Boolean; assembler;
   asm
       MOV   DX,HANDLE
       MOV   AH,0Ch
       CALL  CALLXMS
       LES   DI,ADDRESS
       MOV   ES:[DI],BX
       INC   DI
       INC   DI
       MOV   ES:[DI],DX
   end;


   function UnlockBlock(Handle:Word):Boolean; assembler;
   asm
       MOV   DX,HANDLE
       MOV   AH,0Dh
       CALL  CALLXMS
   end;

   function GetXMShandleInfo(Handle:Word; var LockCount:Byte;
                             var FreeHandles:Byte;
                             var Size:Word):Boolean; assembler;
   asm
       MOV   DX,HANDLE
       MOV   AH,0Eh
       CALL  CALLXMS
       CMP   AX,1
       JNE   @ERROR
       LES   DI,LOCKCOUNT
       MOV   ES:[DI],BH
       LES   DI,FREEHANDLES
       MOV   ES:[DI],BL
       LES   DI,SIZE
       MOV   ES:[DI],DX
       PUSH DS
       PUSH AX
       MOV  AX,SEG @DATA
       MOV  DS,AX
       MOV  BL,0
       MOV  XMSERROR,BL
       POP  AX
       POP  DS
       @ERROR:
   end;

   function Mem2Xms( var Buf; Count,Handle:Word; Offset:LongInt):Boolean;
   var E:EMMstruct;
       w:Word;
       ww:Boolean;
   begin
       with E do
       begin
           ww:=Odd(Count);
           if ww then
           begin
               Size:=2;
               soh:=handle;
               soo:=Offset+Count;
               dsh:=0;
               dso:=LongInt(@w);
               if not MoveXMS(E) then
               begin
                   Mem2Xms:=False;
                   Exit;
               end;
           end;
           if ww then Size:=Count+1 else Size:=Count;
           soh:=0;
           soo:=LongInt(@Buf);
           dsh:=handle;
           dso:=Offset;
           if not MoveXMS(E) then
           begin
               Mem2Xms:=False;
               Exit;
           end;
           if ww then
           begin
               Size:=2;
               soh:=0;
               soo:=LongInt(@w);
               dsh:=handle;
               dso:=Offset+Count;
               if not MoveXMS(E) then
               begin
                   Mem2Xms:=False;
                   Exit;
               end;
           end;
       end;
       Mem2Xms:=True;
   end;

   function Xms2Mem( Handle:Word; Offset:LongInt; var Buf; Count:Word):Boolean;
   var E:EMMstruct;
       w:Word;
       ww:Boolean;
   begin
       with E do
       begin
           Size:=Count;
           ww:=Odd(Count);
           if ww then Dec(Size);
           soh:=handle;
           soo:=Offset;
           dsh:=0;
           dso:=LongInt(@Buf);
           if not MoveXMS(E) then
           begin
               Xms2Mem:=False;
               Exit;
           end;
           if ww then
           begin
               size:=2;
               soh:=handle;
               soo:=Offset+Count-1;
               dsh:=0;
               dso:=LongInt(@w);
               if not MoveXMS(E) then
               begin
                   Xms2Mem:=False;
                   Exit;
               end;
               Move(w,Ptr(Seg(Buf),Ofs(Buf)+Count-1)^,1);
           end;
       end;
       Xms2Mem:=True;
   end;


   begin
       MakeCall(@CallXMS);

   end.     { UNIT XMS }



