   {$X+}

   program UseXMS;

   {*****************************************************}
   {*                                                   *}
   {*  Sample program for XMS unit                      *}
   {*         Copyright (c) 1992   KIV without Co       *}
   {*                                                   *}
   {*****************************************************}


   uses Graph,Crt,XMS;

   procedure PressKey;
   begin
       while KeyPressed do ReadKey;
       ReadKey;
   end;

   procedure CheckXMS;
   begin
       if XMSerror<>0 then
       begin
           WriteLn('XMS error - ',XMSerrorMSG(XMSerror));
           Halt;
       end;
   end;

   var
       GD,GM:Integer;
       Err  :Integer;
       S    :Word;
       SS   :array[0..3] of LongInt;
       E    :EMMstruct;
       P    :array[0..4] of string;
       H    :Word;
       I,J  :Word;
       B    :pointer;
       Tot,Blk:Word;

   begin
       RandSeed:=MemL[$0000:$046C];
       DirectVideo:=False;
       if not XMSinstalled then
       begin
           WriteLn('XMS not installed - aborting...');
           Halt;
       end;
       GetXMSmem(Tot,Blk);
       WriteLn('XMS total Kbytes - ',Tot);
       CheckXMS;
       WriteLn('XMS avail Kbytes - ',Blk);
       if Blk<120 then
       begin
           WriteLn('This program required 120 Kb XMS - aborting...');
           Halt;
       end else
       begin
           WriteLn('Press any key...');
           PressKey;
       end;
       GetXMSmem(Tot,Blk);
       Str(Blk,p[0]);
       p[0]:='Before exec XMS block '+p[0]+' Kb';
       Str(MemAvail,p[1]);
       p[1]:='Before exec Mem avail '+p[1]+' bytes';
       GD:=EGA;
       GM:=EGAHi;
       InitGraph(GD,GM,'\BGI');
       Err:=GraphResult;
       if Err<>grOK then
       begin
           WriteLn('Graph error - ',GraphErrorMsg(Err));
           Halt;
       end;
       for GD:=1 to 100 do
       begin
           SetColor(Random(16));
           Circle(Random(640),Random(350),Random(100));
           SetColor(Random(16));
           Line(Random(640),Random(350),Random(640),Random(350));
       end;
       Str(MemAvail,p[2]);
       p[2]:='During Graph Mem avail '+p[2]+' bytes';
       H:=AllocXMS(120);
       CheckXMS;
       GetXMSmem(Tot,Blk);
       CheckXMS;
       Str(Blk,p[3]);
       p[3]:='After Alloc XMS XMS block '+p[3]+' Kb';
       GetMem(B,ImageSize(0,0,160,350));
       with E do
       begin
           SS[0]:=0;
           for i:=0 to 3 do
           begin
               S:=ImageSize(i*160,0,i*160+159,349);
               if Odd(S) then Inc(S);
               GetImage(i*160,0,i*160+159,349,B^);
               size:=S;
               soh:=0;
               soo:=LongInt(B);
               dsh:=h;
               if i=0 then dso:=0 else
               begin
                   dso:=SS[i-1]+S;
                   SS[i]:=dso;
               end;
               MoveXMS(E);
               CheckXMS;
           end;
           Str(MemAvail,p[4]);
           p[4]:='After GetImage Mem Avail '+p[4]+' bytes';
           ClearDevice;
           WriteLn('Picture saved. Press any key...');
           PressKey;
           for i:=0 to 3 do
           begin
               size:=S;
               soh:=h;
               if i=0 then soo:=0 else soo:=SS[i];
               dsh:=0;
               dso:=LongInt(B);
               MoveXMS(E);
               CheckXMS;
               PutImage(i*160,0,B^,NormalPut);
           end;
       end;
       FreeXMS(H);
       FreeMem(B,ImageSize(0,0,160,350));
       CheckXMS;
       WriteLn('Press any key...');
       PressKey;
       CloseGraph;
       for j:=0 to 4 do WriteLn(p[j]);
       WriteLn('After all: Mem avail ',MemAvail,' bytes');
       GetXMSmem(Tot,Blk);
       CheckXMS;
       WriteLn('           XMS block ',Blk,' Kb');
   end.        {UseXMS}



