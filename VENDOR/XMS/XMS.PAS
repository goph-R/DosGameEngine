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
       MOV   AX,4300h
       INT   2Fh
       CMP   AL,80h
       JNE   @EXITUS
       MOV   XMSinst,1
       MOV   AX,4310h
       INT   2Fh
       MOV   DX,ES
       MOV   CX,BX
       CLD
       MOV   AX,SS:[BP+8]
       MOV   ES,AX
       MOV   DI,SS:[BP+6]
       INC   DI
       MOV   AL,9Ah
       STOSB
       MOV   AX,CX
       STOSW
       MOV   AX,DX
       STOSW
       @EXITUS:
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



