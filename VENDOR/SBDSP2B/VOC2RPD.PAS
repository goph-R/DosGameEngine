Program ConvertVOCRPD;

(**************************************************************************)
(*                            Program VOC2RPD                             *)
(*                       By: Romesh Prakashpalan                          *)
(**************************************************************************)
(*  This program will convert a VOC file to my RPD format (the specs have *)
(* been given out with my SBDSP unit). This will eliminate any "noise"    *)
(* you might get due to the fact that you are probably reading in VOC     *)
(* data structures instead of pure RAW data.                              *)
(*  Any questions or comments (or donations ;-) ) should be directed to:  *)
(*    Romesh Prakashpalan (hacscb93@huey.csun.edu) <- Until 01/31/94.     *)
(*     Note: After 01/31/94, my account at CSUN expires, so look in the   *)
(*           comp.lang.pascal or alt.sb.programmer newsgroups, for my     *)
(*           current address.                                             *)
(**************************************************************************)

Uses SBDSP, Crt;

(**************************************************************************)
(*  Revisions:                                                            *)
(*    Version 1.0à: Just strips off the VOC file header, to reduce a bit  *)
(*                  of the "popping" that occurs when played back as a RAW*)
(*                  file. This was pretty lame!                           *)
(*    Version 1.10: Converts the file pretty much with all VOC specific   *)
(*                  information removed. However, repeat loops will only  *)
(*                  iterate ONCE, and Silence blocks will be REMOVED from *)
(*                  the VOC file. In future versions, I plan on adding    *)
(*                  repeats manually, digital silence (if user specifies  *)
(*                  it), but these are minor things.                      *)
(*    Version 1.11: STOOPID MISTAKE FIXED!!!! Would not write header to   *)
(*                  the beginning of the file, but rather to the END!!    *)
(*    Version 1.12: Added Input/Output checking on files, instead of      *)
(*                  the program giving a "run-time error", it gives a     *)
(*                  suitable error message.                               *)
(*    Version 1.13: Fixed a Block 9 error in conversion (Previously I     *)
(*                  did not have any VOC files to test Block 9 conversion *)
(*                  on, so I apologize!). At this point, most SERIOUS     *)
(*                  conversion flaws should have been recognized.         *)
(**************************************************************************)
(* Future Revisions:                                                      *)
(*  I hope to create support for 16-bit sound in the next versions of my  *)
(* code, but this is dependant on when I will be able to get code to      *)
(* program the Sound Blaster 16! Only then will I be able to implement    *)
(* such a conversion, as my program is the only one which will read, or   *)
(* even recognise an RPD file! (As far as I know)                         *)
(**************************************************************************)
(*  Note: To all of those who are using this file for the SBDSP unit that *)
(*        I have given out: What do you think of my unit???, do you think *)
(*        that I should create support for the Sound Blaster 16? I do not *)
(*        think that I should charge anything for it, as that would make  *)
(*        me as bad as Creative Labs, but I would willingly take a small  *)
(*        donation ;-). That's all right, just as long as you are able to *)
(*        use the code, I'm happy. Please let me know what you think about*)
(*        the unit though!                                                *)
(**************************************************************************)

type

(****************************************************************************)
(* Channel method: 0 - Layed down Byte 1 - Channel 0, Byte 2 - Channel 1... *)
(*                 1 - First Channel continuously for Size Bytes, then comes*)
(*                     the Second Channel, etc...                           *)
(****************************************************************************)
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

Function ThreeByte2Long (TheData: ThreeByte): LongInt;
Begin
  ThreeByte2Long := LongInt (TheData[1]) + LongInt (TheData[2]) shl 8 +
                    LongInt (TheData[3]) shl 16;
End;

Procedure ConvertVOC2RPD (Source, Destination: String);
var
  SourceF: File;
  DestF: File;
  TempRPDHead: RPDHeader;
  TempVOCHead: VOCHeader;
  TempBuffer: Pointer;
  BlockType: Byte;
  BytesConverted: LongInt;
  Done: Boolean;
  Block1: Block1Type;
  Block2: Block2Type;
  Block3: Block3Type;
  Block4: Block4Type;
  Block5: Block5Type;
  Block6: Block6Type;
  Block7: Block7Type;
  Block8: Block8Type;
  Block9: Block9Type;
  LeftToGo: LongInt;
  SkipNextBlock1: Boolean;

Begin
  SkipNextBlock1 := False;
  BytesConverted := 0;
  Assign (SourceF, Source);
  Assign (DestF, Destination);
  Reset (SourceF, 1);
  Rewrite (DestF, 1);
  BlockRead (SourceF, TempVOCHead, SizeOf (TempVOCHead));
  GetMem (TempBuffer, $FFFF);
  TempRPDHead.Sig := 'RPD';
  TempRPDHead.Version := 1;
  TempRPDHead.Channels := 1;
  TempRPDHead.ChannelMethod := 0;
  (* Blank out the reserved field with 0's, so that future software won't *)
  (* be confused!                                                         *)
  FillChar (TempRPDHead.Reserved, SizeOf (TempRPDHead.Reserved), 0);
  (* Write the incomplete header to the file, we shall update it later... *)
  BlockWrite (DestF, TempRPDHead, SizeOf (TempRPDHead));
  Done := False;
  Repeat
    BlockRead (SourceF, BlockType, SizeOf (BlockType));
    Case BlockType of
       0: Begin         (* Terminator Block *)
            WriteLn ('Block Type 0 encountered, conversion complete...');
            Done := True;
          End;
       1: Begin         (* Data Block *)
            Write ('Converting Block Type 1.');
            BlockRead (SourceF, Block1, SizeOf (Block1));
            If not SkipNextBlock1 then
            Begin
              Case Block1.PackType of
                0: TempRPDHead.DAC := EightBitDMA;
                1: TempRPDHead.DAC := FourBitDMA;
                2: TempRPDHead.DAC := TwoSixBitDMA;
                3: TempRPDHead.DAC := TwoBitDMA;
              end;
              TempRPDHead.Freq := Round (1000000/(256 - Block1.TimeConstant));
              TempRPDHead.Phase := 0;   (* Block Type 1 is ALWAYS MONO *)
            End
            Else SkipNextBlock1 := False;
            Inc (BytesConverted, ThreeByte2Long (Block1.Length)-2);
            LeftToGo := ThreeByte2Long (Block1.Length) - 2;
            Repeat
              If LeftToGo > $FFFF then
              Begin
                Dec (LeftToGo, $FFFF);
                BlockRead (SourceF, TempBuffer^, $FFFF);
                BlockWrite (DestF, TempBuffer^, $FFFF);
              End
              Else
              Begin
                BlockRead (SourceF, TempBuffer^, LeftToGo);
                BlockWrite (DestF, TempBuffer^, LeftToGo);
                LeftToGo := 0;
              End;
              Write ('.');
            Until LeftToGo = 0;
            WriteLn;
            WriteLn ('Block Type 1: ', ThreeByte2Long (Block1.Length),
                     ' bytes converted.');
          end;
          2: Begin      (* Voice Continuation *)
               WriteLn ('Converting Block 2, Voice Continuation.');
               BlockRead (SourceF, Block2, SizeOf (Block2));
               Inc (BytesConverted, ThreeByte2Long (Block2.Length));
               LeftToGo := ThreeByte2Long (Block2.Length);
               Repeat
                If LeftToGo > $FFFF then
                Begin
                  Dec (LeftToGo, $FFFF);
                  BlockRead (SourceF, TempBuffer^, $FFFF);
                  BlockWrite (DestF, TempBuffer^, $FFFF);
                End
                Else
                Begin
                  BlockRead (SourceF, TempBuffer^, LeftToGo);
                  BlockWrite (DestF, TempBuffer^, LeftToGo);
                  LeftToGo := 0;
                End;
                Write ('.');
              Until LeftToGo = 0;
              WriteLn;
              WriteLn ('Block Type 2: ', ThreeByte2Long (Block1.Length),
                       ' bytes converted.');
             end;
          3: Begin      (* Silence Block, will be skipped *)
               WriteLn ('Skipping a Silence Block (Block Type 3)');
               BlockRead (SourceF, Block3, SizeOf (Block3));
             end;
          4: Begin      (* Marker Block *)
               WriteLn ('Skipping a Marker Block (Block Type 4)');
               BlockRead (SourceF, Block4, SizeOf (Block4));
             End;
          5: Begin      (* ASCII text *)
               WriteLn ('Skipping embedded ASCII text (Block Type 5)');
               BlockRead (SourceF, Block5, SizeOf (Block5));
             End;
          6: Begin      (* Repeat Loop, in version 1.10, they are skipped *)
               WriteLn ('Skipping the repeat loop, loop will play ONCE');
               BlockRead (SourceF, Block6, SizeOf (Block6));
             End;
          7: Begin      (* Signal the end of a repeat loop *)
               WriteLn ('End of Repeat Loop found...');
               BlockRead (SourceF, Block7, SizeOf (Block7));
             End;
          8: Begin      (* Extended Block (Stereo, and other 8-bit goodies) *)
               WriteLn ('An extended block was found (8), reading data...');
               SkipNextBlock1 := True;
               BlockRead (SourceF, Block8, SizeOf (Block8));
               Case Block8.PackType of
                 0: TempRPDHead.DAC := EightBitDMA;
                 1: TempRPDHead.DAC := FourBitDMA;
                 2: TempRPDHead.DAC := TwoSixBitDMA;
                 3: TempRPDHead.DAC := TwoBitDMA;
               end;
               If Block8.Mode = 0 then
               Begin
                 TempRPDHead.Phase := 0;
                 TempRPDHead.Freq := (-256000000 div (Block8.TimeConstant
                                      - 65536));
               End
               Else
               Begin
                 TempRPDHead.Phase := 1;
                 TempRPDHead.Freq := (-256000000 div (Block8.TimeConstant
                                      - 65536));
               End;
             End;
          9: Begin     (* NEW Extended Block (16-Bit/other NEW stuff) *)
               Write ('Converting Block 9.');
               BlockRead (SourceF, Block9, SizeOf (Block9));
               TempRPDHead.Freq := Block9.SamplesPerSec;
               TempRPDHead.DAC := 0;
               Inc (BytesConverted, ThreeByte2Long (Block9.Length));
               Case Block9.FormatTag of
                    $000: TempRPDHead.DAC := EightBitDMA;
                    $001: TempRPDHead.DAC := FourBitDMA;
                    $002: TempRPDHead.DAC := TwoSixBitDMA;
                    $003: TempRPDHead.DAC := TwoBitDMA;
                    $004: Begin
                            TempRPDHead.DAC := SixteenBitDMA;
                            WriteLn ('HA! Sixteen Bit DAC found!');
                          End;
                    (* All other types are undefined in my program as of now!*)
                    (* These will be the Sixteen Bit Compression types       *)
               end;
               TempRPDHead.Phase := (Block9.Channels - 1);
               If TempRPDHead.Phase = 1 then
                 TempRPDHead.Freq := TempRPDHead.Freq * 2;
               LeftToGo := ThreeByte2Long (Block9.Length) - 12;
               Repeat
                If LeftToGo > $FFFF then
                Begin
                  Dec (LeftToGo, $FFFF);
                  BlockRead (SourceF, TempBuffer^, $FFFF);
                  BlockWrite (DestF, TempBuffer^, $FFFF);
                End
                Else
                Begin
                  BlockRead (SourceF, TempBuffer^, LeftToGo);
                  BlockWrite (DestF, TempBuffer^, LeftToGo);
                  LeftToGo := 0;
                End;
                Write ('.');
              Until LeftToGo = 0;
              WriteLn;
              WriteLn ('Block Type 9: ', ThreeByte2Long (Block9.Length) - 12,
                       ' bytes converted.');
             End;
    end;
  Until Done;
  TempRPDHead.Size := BytesConverted;
  FreeMem (TempBuffer, $FFFF);
  Seek (DestF, 0);
  (* Now, write the completed information... *);
  BlockWrite (DestF, TempRPDHead, SizeOf (TempRPDHead));
  Close (SourceF);
  Close (DestF);
  WriteLn ('File conversion done...');
  WriteLn ('***************************************************');
  Write ('Mode: ');
  Case TempRPDHead.Phase of
    0: WriteLn ('Mono');
    1: WriteLn ('Stereo');
  end;
  Case TempRPDHead.Dac of
       EightBitDMA: WriteLn ('8 Bit (unpacked)');
       FourBitDMA: WriteLn ('4 Bit (packed)');
       FourBitRefDMA: WriteLn ('4 Bit w/Reference Byte (packed)');
       TwoSixBitDMA: WriteLn ('2.6 Bit (packed)');
       TwoSixBitRefDMA: WriteLn ('2.6 Bit w/Reference Byte (packed)');
       TwoBitDMA: WriteLn ('2 Bit (packed)');
       TwoBitRefDMA: WriteLn ('2 Bit w/Reference Byte (packed)');
  end;
  If TempRPDHead.Phase = 1 then TempRPDHead.Freq := TempRPDHead.Freq div 2;
  WriteLn ('Frequency:  ', TempRPDHead.Freq, ' Hz');
  WriteLn ('***************************************************');
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
  WriteLn ('           VOC2RPD version 1.13, By: Romesh Prakashpalan, 1994');
  WriteLn ('                            VOC2RPD is FREEWARE             ');
  Write ('Enter in VOC file to be converted: ');
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
  ConvertVOC2RPD (Source, Destination);
End.