   {*****************************************************}
   {*                                                   *}
   {*   UNIT   XSTREAM                                  *}
   {*               Copyright (c) 1992  KIV without Co  *}
   {*                                                   *}
   {*****************************************************}

   unit XStream;

   interface

   uses Objects, XMS;

   type PXmsStream=^TXmsStream;
        TXmsStream=object(TStream)
                   handle:Word;
                   curpos:LongInt;
                   cursiz:LongInt;
                   masiz :LongInt;
                   constructor Init(MaxSize:LongInt);
                   constructor InitH(H:Word;Size:LongInt);
                   function   GetPos:LongInt; virtual;
                   function   GetSize:LongInt;virtual;
                   procedure  Read(var Buf; Count:Word); virtual;
                   procedure  Write(var Buf; Count:Word); virtual;
                   procedure  Seek(Pos:LongInt); virtual;
                   procedure  Truncate; virtual;
                   destructor Done; virtual;
                   destructor NDDone; virtual;
                   end;

   const stXMSerror = -9;


   implementation

   constructor TXmsStream.InitH(H:Word;Size:LongInt);
   var LockCount,FreeHandles:Byte;
       Siz:Word;
   begin
       if not XMSinstalled then
       begin
           Error(stInitError,0);
           Exit;
       end;
       if not GetXMShandleInfo(H,LockCount,FreeHandles,Siz) then
       Error(stInitError,XMSerror) else
       begin
           handle:=H;
           curpos:=0;
           cursiz:=Size;
           masiz:=Siz*1024;
           Reset;
       end;
   end;

   constructor TXmsStream.Init(MaxSize:LongInt);
   var t,b:Word;
   begin
       if not XMSinstalled then
       begin
           Error(stInitError,0);
           Exit;
       end;
       GetXMSmem(t,b);
       if (XMSerror<>0) or (b<MaxSize div 1024+1) then
       begin
           Error(stInitError,XMSerror);
           Exit;
       end;
       masiz:=MaxSize;
       curpos:=0;
       cursiz:=0;
       handle:=AllocXMS(MaxSize div 1024+1);
       if XMSerror<>0 then
       begin
           Error(stInitError,XMSerror);
           Exit;
       end;
       Reset;
   end;

   function   TXMSStream.GetPos:LongInt;
   begin
       GetPos:=curpos;
   end;

   function   TXmsStream.GetSize:LongInt;
   begin
       GetSize:=cursiz;
   end;

   destructor TXMSStream.NDDone;
   begin
       TStream.Done;
   end;


   destructor TXmsStream.Done;
   begin
       FreeXMS(handle);
       NDDone;
   end;

   procedure  TXmsStream.Read(var Buf; Count:Word);
   var E:EMMstruct;
       w:Word;
       ww:Boolean;
   begin
       if Status<>stOK then Exit;
       if (cursiz-curpos)<Count then
       begin
           Error(stReadError,0);
           Exit;
       end;
       if not Xms2Mem(handle,curpos,Buf,Count) then
       Error(stXMSerror,XMSerror) else
       curpos:=curpos+Count;
   end;

   procedure  TXmsStream.Write(var Buf; Count:Word);
   var E:EMMstruct;
       p:pointer;
       w:Word;
       ww:Boolean;
   begin
       if Status<>stOK then Exit;
       if curpos+Count>masiz then
       begin
           Error(stWriteError,0);
           Exit;
       end;
       if not Mem2Xms(Buf,Count,Handle,curpos) then
       Error(stXMSerror,XMSerror) else
       begin
           curpos:=curpos+Count;
           if cursiz<curpos then cursiz:=curpos;
       end;
   end;

   procedure  TXmsStream.Seek(Pos:LongInt);
   begin
       if Status=stOK then
       if Pos<0 then Seek(0) else
       if Pos>cursiz then curpos:=cursiz else curpos:=Pos;
   end;

   procedure  TXmsStream.Truncate;
   begin
       if Status=stOK then cursiz:=curpos;
   end;



   end.   { UNIT XSTREAM }



