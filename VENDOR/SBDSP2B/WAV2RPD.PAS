Program WAV2RPD;

(**************************************************************************)
(*                            Program WAV2RPD                             *)
(*                       By: Romesh Prakashpalan                          *)
(**************************************************************************)
(*  This program is similar to my VOC2RPD program in that it converts a   *)
(* WAV file to the RPD format. A WAV file is considerably easier to       *)
(* convert than a VOC file, as there aren't that many Block Types!        *)
(**************************************************************************)

Uses SBDSP, Crt;

(**************************************************************************)
(* Revisions:                                                             *)
(*   *Version 1.0a: Current Version                                       *)
(**************************************************************************)
type
  ChunkType = Record
                ID: Array [1..4] of Char;      (* "RIFF" *)
                Len: LongInt;                  (* Size of the Data Chunk *)
              end;


  DataType = Record    (* For a Wave Type File *)
                ID: Array [1..4] of Char;      (* "WAVE" *)
              end;
  FormatChunkType = Record
                 ChunkID: Array [1..4] of Char; (* "fmt" *)
                 Len: LongInt;         (* Size of Data *)
                 FormatTag: Word;      (* 01 = PCM     *)
                 Channels: Word;       (* 1 = Mono, 2 = Stereo *)
                 SamplesPerSec: Word;  (* PlayBack Freq *)
                 AvgBytesPerSec: Word;
                 BlockAlign: Word;
                 FormatSpecific: Word;
               end;

  RPDHeader = Record
                Sig: Array [0..2] of Char; (* "RPD" *)
                Version: Word;             (* Version # *)
                DAC: Byte;                 (* 16/8/4/4.6/2/2.6, etc...*)
                Phase: Byte;               (* Mono=0, Stereo=1, Surround=2 *)
                Freq: Word;                (* Sample Frequency *)
                Channels: Byte;            (* # of DIGITAL Channels *)
                ChannelMethod: Byte;       (* Method for laying down channels *)
                Size: LongInt;             (* Size of Sample *)
                Reserved: Array [0..31] of Byte;
              end;

var
  Source, Destination: String;
  Ch: Char;

Procedure ConvertWAV2RPD (Source, Destination: String);
var
  SourceF, DestF: File;
  TempRPDHead: RPDHeader;
  TempChunk: ChunkType;
  TempData: DataType;
  TempFormatChunk: FormatChunkType;
  TempBuffer: Pointer;
  NumRead, NumWritten: Word;
Begin
  GetMem (TempBuffer, $FFFF);
  Assign (SourceF, Source);
  Assign (DestF, Destination);
  Reset (SourceF, 1);
  Rewrite (DestF, 1);
  BlockRead (SourceF, TempChunk, SizeOf (TempChunk));
  BlockRead (SourceF, TempData, SizeOf (TempData));
  BlockRead (SourceF, TempFormatChunk, SizeOf (TempFormatChunk));
  TempRPDHead.Sig := 'RPD';
  TempRPDHead.Version := 1;
  TempRPDHead.DAC := EightBitDMA;
  TempRPDHead.Phase := TempFormatChunk.Channels - 1;
  TempRPDHead.Channels := TempFormatChunk.Channels;
  TempRPDHead.Freq := TempFormatChunk.BlockAlign;
  TempRPDHead.ChannelMethod := 0;
  TempRPDHead.Size := FileSize (SourceF) - FilePos (SourceF);
  BlockWrite (DestF, TempRPDHead, SizeOf (TempRPDHead));
  Repeat
    BlockRead(SourceF, TempBuffer^, $FFFF, NumRead);
    BlockWrite(DestF, TempBuffer^, NumRead, NumWritten);
  Until (NumRead = 0) or (NumWritten <> NumRead);
  Close (SourceF);
  Close (DestF);
  FreeMem (TempBuffer, $FFFF);
End;

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

Begin
  Clrscr;
  WriteLn ('           WAV2RPD version 1.0a, By: Romesh Prakashpalan, 1994');
  WriteLn ('                            WAV2RPD is FREEWARE             ');
  Write ('Enter in WAV file to be converted: ');
  ReadLn (Source);
  If not FileExists (Source) then
  Begin
    WriteLn ('Source File Doesn''t Exist!');
    Halt;
  End;
  Write ('Enter in RPD file to convert to: ');
  ReadLn (Destination);
  If FileExists (Destination) then
  Begin
    Write ('File exists! overwrite? (''N'' for No, any other key kills it): ');
    Ch := UpCase (Readkey);
    WriteLn (Ch);
    If Ch = 'N' then Halt;
  End;

  ConvertWAV2RPD (Source, Destination);
End.