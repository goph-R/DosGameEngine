Program RPD2VOC;
Uses SBDSP, Crt;
(**************************************************************************)
(*                            Program RPD2VOC                             *)
(*                       By: Romesh Prakashpalan                          *)
(**************************************************************************)
(* NOTE: This program will only convert RPD files that are up to approx   *)
(* 15MB in length!!                                                       *)
(**************************************************************************)

type
  RPDHeader = Record
                Sig: Array [0..2] of Char; (* "RPD" *)
                Version: Word;             (* Version # *)
                DAC: Byte;                 (* 8/16/4/4.6/2/2.6, etc...*)
                Phase: Byte;               (* Mono=0, Stereo=1, Surround=2*)
                Freq: Word;                (* Sample Frequency *)
                Channels: Byte;            (* # of DIGITAL Channels *)
                ChannelMethod: Byte;       (* Method for laying down channels *)
                Size: LongInt;             (* Size of Sample *)
                Reserved: Array [0..31] of Byte;
              end;

  VOCHeader = Record
                Sig:Array [0..$13] of Char;(* "Creative Voice File" *)
                Offset: Word;              (* Offset of first datablock in the*)
                                           (* .VOC file.                      *)
                Version: Word;             (* Version # *)
                Version2s: Word;           (* 2's complement of version # plus*)
                                           (* 1234h ex: 1.10 = 1129           *)
              end;

  ThreeByte = Array [1..3] of Byte;

  Block1Type = Record                      (* Voice Data Block *)
                Length: ThreeByte;
                TimeConstant: Byte;        (* = 256 - 1000000/Sample Rate *)
                PackType: Byte;            (* 0 = 8-bit unpacked *)
                                           (* 1 = 4-bit packed   *)
                                           (* 2 = 2.6 bit packed *)
                                           (* 3 = 2-bit packed   *)
               end;
  Block2Type = Record                      (* Voice Continuation *)
                 Length: ThreeByte;
               end;

  Block3Type = Record                      (* Silence block *)
                 Length: ThreeByte;        (* Always 3 *)
                 Pause: Word;              (* Pause period in sample bytes *)
                 TimeConstant: Byte;
               end;

  Block4Type = Record                      (* Marker Block *)
                 Length: ThreeByte;
                 MarkerValue: Word;
               end;

  Block5Type = Record                      (* Ascii Text (null-terminated) *)
                 Length: ThreeByte;
               end;

  Block6Type = Record                      (* Repeat Loop *)
                 Length: ThreeByte;        (* Always 2 *)
                 Count: Word;              (* 1 to $FFFE, $FFFF = endless loop*)
               end;

  Block7Type = Record                      (* End Repeat Loop *)
                 Length: ThreeByte;        (* Always 0 *)
               end;

  Block8Type = Record                      (* Extended Block *)
                 Length: ThreeByte;        (* Always 4 *)
                 TimeConstant: Word;       (* For Mono:  *)
                                           (* 65535-(256,000,000/sample rate)*)
                                           (* For Stereo: *)
                                           (* 65535-(256000000/sample rate*2) *)
                 PackType: Byte;           (* Same as Block 1 *)
                 Mode: Byte;               (* 0 = Mono, 1 = Stereo *)
               end;

  Block9Type = Record                      (* NEW Extended VOC Block *)
                 Length: ThreeByte;        (* Length of Sample + 12 (Bytes) *)
                 SamplesPerSec: LongInt;   (* ACTUAL Samples/Second *)
                 BitsPerSample: Byte;      (* Bits/Sample after compression *)
                 Channels: Byte;           (* 1 for mono, 2 for stereo *)
                 FormatTag: Word;          (* Format Tags follow: *)
                                           (*   $000 - 8 bit unsigned PCM *)
                                           (*   $001 - 4 Bit ADPCM *)
                                           (*   $002 - 2.6 Bit ADPCM *)
                                           (*   $003 - 2 Bit ADPCM *)
                                           (*   $004 - 16 Bit Signed PCM *)
                                           (*   $006 - CCITT a-Law *)
                                           (*   $007 - CCITT u-Law *)
                                           (*   $200 - 16 bit -> 4 Bit ADPCM *)
                 Reserved: LongInt;        (* Reserved by Creative Labs *)
               end;

var
  Source, Destination: String;
  Ch: Char;

Function FileExists (Filename: String): Boolean;
var
 F: file;
Begin
 {$I-}
 Assign(F, FileName);
 FileMode := 0;      (* Set file access to read only *)
 Reset(F);
 Close(F);
 {$I+}
 FileExists := (IOResult = 0) and (FileName <> '');
End;

Procedure Long2ThreeByte (Num: Longint; var Result: ThreeByte);
Begin
  Move (Ptr (Seg (Num), Ofs (Num))^, Result, SizeOf (Result));
End;

Function ThreeByte2Long (TheData: ThreeByte): LongInt;
Begin
  ThreeByte2Long := LongInt (TheData[1]) + LongInt (TheData[2]) shl 8 +
                    LongInt (TheData[3]) shl 16;
End;

Procedure RPDToVoc (Source, Destination: String);
var
  SFile, DFile: File;
  TempVOCHeader: VOCHeader;
  TempRPDHeader: RPDHeader;
  TempString: String;
  I: Integer;
  Block9: Block9Type;  (* Save as the MOST RECENT type of block available! *)
  TempThreeByte: ThreeByte;
  TempBuffer: Pointer;
  LeftToGo: LongInt;
  TempByte: Byte;
Begin
  GetMem (TempBuffer, $FFFF);
  Assign (SFile, Source);
  Assign (DFile, Destination);
  Reset (SFile, 1);
  Rewrite (DFile, 1);
  TempString := 'Creative Voice File';
  For I := 1 to Length (TempString) do
    TempVOCHeader.Sig[I-1] := TempString[I];
  TempVOCHeader.Offset := SizeOf (TempVOCHeader);
  TempVOCHeader.Version := $A01;
  TempVOCHeader.Version2s := $2911;
  BlockWrite (DFile, TempVOCHeader, SizeOf (TempVOCHeader));
  BlockRead (SFile, TempRPDHeader, SizeOf (TempRPDHeader));
  LeftToGo := TempRPDHeader.Size;
  Long2ThreeByte (TempRPDHeader.Size - 12 - SizeOf (TempRPDHeader),
                  TempThreeByte);
  Block9.Length := TempThreeByte;
  Block9.SamplesPerSec := TempRPDHeader.Freq;
  Case TempRPDHeader.DAC of
    EightBitDMA:   Block9.FormatTag := $000;
    FourBitDMA:    Block9.FormatTag := $001;
    TwoSixBitDMA:  Block9.FormatTag := $002;
    TwoBitDMA:     Block9.FormatTag := $003;
    SixteenBitDMA: Block9.FormatTag := $004;
  end;
  Block9.Channels := TempRPDHeader.Channels + 1;
  If TempRPDHeader.Channels = Stereo then
    Block9.SamplesPerSec := Block9.SamplesPerSec div 2;

  Block9.Reserved := 0;
  TempByte := 9;
  BlockWrite (DFile, TempByte, 1);
  BlockWrite (DFile, Block9, SizeOf (Block9));
  Repeat
    If LeftToGo > $FFFF then
    Begin
      Dec (LeftToGo, $FFFF);
      BlockRead (SFile, TempBuffer^, $FFFF);
      BlockWrite (DFile, TempBuffer^, $FFFF);
    End
    Else
    Begin
      BlockRead (SFile, TempBuffer^, LeftToGo);
      BlockWrite (DFile, TempBuffer^, LeftToGo);
      LeftToGo := 0;
    End;
    Write ('.');
  Until LeftToGo = 0;
  TempByte := 0;
  BlockWrite (DFile, TempByte, 1);
End;

Begin
  Clrscr;
  WriteLn ('           RPD2VOC version 1.00, By: Romesh Prakashpalan, 1995');
  WriteLn ('                            RPD2VOC is FREEWARE             ');
  Write ('Enter in RPD file to be converted: ');
  ReadLn (Source);
  If not FileExists (Source) then
  Begin
    WriteLn ('Source File Doesn''t Exist!');
    Halt;
  End;
  Write ('Enter in VOC file to convert to: ');
  ReadLn (Destination);
  If FileExists (Destination) then
  Begin
    Write ('File exists! overwrite? (''N'' for No, any other key kills it): ');
    Ch := UpCase (Readkey);
    WriteLn (Ch);
    If Ch = 'N' then Halt;
  End;
  RPDToVOC (Source, Destination);
End.