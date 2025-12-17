Unit SBDSP;
                          (* Version 2.0� *)

{$G+}           { Enable 286 instructions     }
{$N+}           { Enable Numeric Coprocessor  }
{$E+}           { Enable FPU emulation        }
{$A+}           { Word Alignment              }
{$S-}           { No Stack Checking           }
{$R-}           { No Range Checking           }
{$O-}           { Unit Can't be overlayed!!   }
{$X+}           { Enable Extended Syntax      }

(***************************************************************************)
(*              Unit for driving a SB in DMA or DIRECT MODE                *)
(*                 Coming Soon: Real Time FX engine!                       *)
(*               Note: Only for playing Digital samples!!!                 *)
(* SBDSP is Copyright (C) 1995 by Romesh Prakashpalan, all rights reserved *)
(***************************************************************************)
(* Revision history:                                                       *)
(*    Version 0.5�: Would not play samples across a page boundary correctly*)
(*                  (I *was* getting VERY angry!)                          *)
(*    Version 1.0�: FINALLY works across page breaks, and now I shall      *)
(*                  proceed to create a way to play from a virtual mem     *)
(*                  file (or XMS).                                         *)
(*    Version 1.01: Allright, now the unit will also work by transfering a *)
(*                  file straight from disk (by using 1 buffer of 64K in   *)
(*                  low memory). The reason that I didn't want to use      *)
(*                  Ethan Brodsky's Unit is because he would load the      *)
(*                  ENTIRE VOC file into memory at once, thus drastically  *)
(*                  reducing the amnt. of memory available to the rest of  *)
(*                  my program. (I load the file from disk in 32K chunks)  *)
(*                  However, I do admire the fact that he was able to play *)
(*                  VOC files quite nicely and efficiently!                *)
(*    Version 1.1 : Now, support for 8-bit Stereo files, and the SBPRO     *)
(*                  mixer have been added in.                              *)
(*    Version 1.11: The Basic module for FM playing has been added in a    *)
(*                  seperate unit called SBFM. Also expanded available     *)
(*                  range of IRQ levels for a sound card in order to       *)
(*                  maintain compatibility with some older versions. Plus, *)
(*                  have added the "High Speed DMA" mode, which allows     *)
(*                  playback of samples which were recorded at > 22KHz     *)
(*    Version 1.2:  Added "mixing" capabilities, however, they are still a *)
(*                  bit primitive though (and computationally expensive)   *)
(*    Version 1.21: Cleaned up the interface section a bit, and got rid of *)
(*                  IntHandlerInstalled from the Interface (Thanks goes to *)
(*                  Paul Merkus! :) ), also fixed the MixSample procedure  *)
(*                  so that it can mix samples that don't have the same    *)
(*                  length. Note: Check out my unit for playing digital    *)
(*                  samples over the GUS! I haven't tested it yet, but it  *)
(*                  should work (I have an AWE 32, but would also like to  *)
(*                  test out my routines on the GUS)                       *)
(*    Version 1.22: Made the sample type a PChar, since pointer arithmetic *)
(*                  is only defined for that type (in Turbo Pascal v7.0)   *)
(*    Version 1.3 : FIXED A HUGE BUG!! High-Speed DMA xfers would not play *)
(*                  back correctly, and would leave the system hanging! My *)
(*                  code now compensates for this occurence! (phew)        *)
(*    Version 1.3B: Bundled with the VOC2RPD program for ease of use!      *)
(*    Version 1.31: Fixed a slight bug with PlaySoundRPD, which would give *)
(*                  a disk read error on some very small RPD files. I have *)
(*                  also provided two functions which change and check on  *)
(*                  the size of the sound buffer. (This prevents the       *)
(*                  programmer from changing the size of the buffer while  *)
(*                  the program is playing sound!)                         *)
(*    Version 1.31B:  Bundled with the VOC2RPD program AND the WAV2RPD     *)
(*                  program for WAV file conversion.                       *)
(*   *Version 2.0�:   WOW! It seems like much of the code in this unit has *)
(*                  evolved rather quickly (in the space of 3 months!), and*)
(*                  I am already at the second MAJOR release! This �eta    *)
(*                  test unit is for people who need Double Buffering more *)
(*                  than anything else. 2 Procedures have been disabled:   *)
(*                  MixSamples, and PlaySoundDSK. These 2 have to be       *)
(*                  converted over to Double Buffering, so since this is a *)
(*                  �eta, I do not have the time to convert ALL functions  *)
(*                  over. Also note that I have added the FRAMEWORK for    *)
(*                  16-bit sound, but they are NOT functional yet! I am    *)
(*                  still working on it, and if you try to play 16-bit     *)
(*                  sound, you are likely to get garbage played back!      *)
(*                  Version 2.0 should fix all of these items.             *)
(*                    This version also allows for REAL-TIME voice         *)
(*                  amplification, but since it would take a lot of CPU    *)
(*                  horsepower to multiply by a Floating Point amp value,  *)
(*                  I had to cut down the values that can be used for      *)
(*                  amplification. The reason that we are able to do REAL  *)
(*                  TIME Voice amplification is because I am using Double  *)
(*                  Buffers, this way, while one sound is being output,    *)
(*                  another will be calculating its voice level!           *)
(*                    I have fixed the re-entrancy problem (at least it    *)
(*                  appears as if I have fixed it ;-) ).                   *)
(*                    Also, recording was hastily thrown in (someone       *)
(*                  requested it), but is fixed at 8-bit Mono currently.   *)
(***************************************************************************)
(* Future Releases:                                                        *)
(* ----------------                                                        *)
(*   Well, I think that the next great step is to make this DSP package a  *)
(* REAL-TIME FX engine as well! We can do things like add echo, mix a few  *)
(* samples, etc... in Real Time. This code already does Voice Amplification*)
(* in Real-Time, and (my computer) doesn't seem to notice the difference,  *)
(* ( < 1% CPU time on my Pentium 60), so it definately is feasible. I plan *)
(* on adding FX such as Reverb, Chorus, and Echo.                          *)
(***************************************************************************)
(* Known Bugs:                                                             *)
(* -----------                                                             *)
(*   It appears as if I have FIXED the re-entrancy problems that I was     *)
(* experiencing on earlier versions of this code! The only problem now, is *)
(* that machines will need DOS 3.0+ in order to run it (as if anyone with  *)
(* a sound card and a 386 is running anything lower than 3.31 ;-) ).       *)
(***************************************************************************)
(* Performance Problems (2.0�):                                            *)
(* ----------------------------                                            *)
(*   This �eta version does NOT support auto-init modes, and it is doubtful*)
(* if the "real" version of this unit will either (2.0). That is probably  *)
(* something that I will leave for future versions.                        *)
(***************************************************************************)
(* Thanks goes to the following people:                                    *)
(* ------------------------------------                                    *)
(* - Ethan Brodsky for his SBDSP Unit that allows one to play VOC files    *)
(* over the Sound Blaster. This guy is a real hero in my book, as he shares*)
(* his code with *EVERYONE*. He truly deserves the title: Sound Blaster    *)
(* Code Guru! (Seems as if we agreed upon that tile, right Ethan? ;-) )    *)
(* If you ever need a Sound Programmer in C/Turbo Pascal/Assembler/and     *)
(* perhaps even more, don't hesitate to email him at:                      *)
(*                  *  ericbrodsky@psl.wisc.edu  *                         *)
(*                                                                         *)
(* - Mark Feldman for his article on how to program the SB DSP chip, and   *)
(* the SB PRO's Mixer chip.                                                *)
(*                                                                         *)
(* - Paul Merkus for his constructive comments about what I put in the     *)
(* interface section of this module.                                       *)
(*                                                                         *)
(* - Chris Sullens for his help in finding some bugs both in SBDSP and in  *)
(* VOC2RPD.                                                                *)
(*                                                                         *)
(* - Anthony Williams for helping me with the re-entrancy problem I was    *)
(* experiencing. I definately owe him one!                                 *)
(*                                                                         *)
(* - And to all of the people on the comp.lang.pascal who have devoted     *)
(* time to testing my code. Thanx!                                         *)
(***************************************************************************)
(*  For comments, help, suggestions, etc: e-mail me at:                    *)
(*                   * hacscb93@huey.csun.edu *                            *)
(*                                                                         *)
(*                    +-------------------------+                          *)
(*  OR, write me at:  |    17304 Westbury Dr.   |                          *)
(*                    | Granada Hills, CA 91344 |                          *)
(*                    |          USA            |                          *)
(*                    +-------------------------+                          *)
(*                                                                         *)
(*    If you haven't the slightest clue on what I'm doing (or why I'm doing*)
(*  it), don't hesitate to e-mail me, I shall endeavor to clear up the     *)
(*  subject. Sound programming (especially on the Sound Blaster) is not    *)
(*  THAT intuitive, so contact me if you need any help!                    *)
(*                                                                         *)
(*  Please let me know what I can do to make this unit better!             *)
(*                                                                         *)
(* Tested on my computer:                                                  *)
(*  Pentium Processor @60Mhz                                               *)
(*  24MB of memory                                                         *)
(*  590 MB Hard Drive                                                      *)
(*  Running under MSDOS 6.2 and OS/2 2.1                                   *)
(*  Tested on a Sound Blaster Pro 2.0 AND Sound Blaster AWE 32 :-) (Not at *)
(*  the same time of course ;-) ).                                         *)
(*  SB PRO at: IO 220h, IRQ 7, DMA 1                                       *)
(*  AWE 32 at: IO 220h, IRQ 5, DMA 1, HIGH DMA: 5                          *)
(*                                                                         *)
(*  It has also been tested on a friend's machine:                         *)
(*  80386-40Mhz                                                            *)
(*  Running MS-DOS 6.2                                                     *)
(*  Sound Blaster 2.0 AND Sound Blaster 16 Multi CD                        *)
(*  SB 2.0 at: IO 220h, IRQ 7, DMA 1                                       *)
(*  SB 16  at: IO 220h, IRQ 5, DMA 1, HIGH DMA: 5                          *)
(*                                                                         *)
(*  And another friend:                                                    *)
(*  80486-33Mhz                                                            *)
(*  Running OS/2 3.0                                                       *)
(*  Sound Blaster Pro 2.0, Sound Blaster 1.5                               *)
(*  SB 2.0 at: IO 220h, IRQ 5, DMA 1                                       *)
(*  SB 1.5 at: IO 220h, IRQ 7, DMA 1                                       *)
(*                                                                         *)
(* Code was compiled under the following environment:                      *)
(*   DOS IDE for Turbo Pascal 7.0 (Real Mode), and also tested under the   *)
(* DOS Protected mode IDE -> TPX.EXE. Sorry, no BP 7.0 :-( but the code    *)
(* should also run fine on TP 6.0 (maybe minor modifications are needed)   *)
(*                                                                         *)
(***************************************************************************)
(* Now, for some legalities:                                               *)
(*   This code is FREEWARE (as of version 2.0�), and NO ONE is to charge   *)
(* anything for this code. If you distribute this document, do so WITHOUT  *)
(* any changes (contact me if you think it needs changing). All derivative *)
(* works are free from these limitations. You can use the code in any way  *)
(* for commercial purposes, however if you mention my name in the credits  *)
(* screen I would be grateful ;-). If you use this unit in a commercial    *)
(* package, and are making money off of it, please send me whatever you    *)
(* think this unit is worth! This way, I can do further research, and buy  *)
(* upgrades to my computer.                                                *)
(*   Also note that those who send a donation shall be put into a database,*)
(* and will receive the latest version as soon as it comes out, as well as *)
(* top priority for "technical support".                                   *)
(***************************************************************************)

interface

const
  (* These are the Valid constants for doing REAL-TIME Voice amplification*)
  (* Since REAL TIME Voice Amplification takes a while, we must use shifts*)
  (* for FAST performance!                                                *)
  SilentVol    = 10;    (* 0.00x amplification *)
  QuarterVol   = 5;     (* 0.25x amplification *)
  HalfVol      = 3;     (* 0.50x amplification *)
  NormalVol    = 0;     (* 1.00x amplification *)
  One25Vol     = 7;     (* 1.25x amplification *)
  One5Vol      = 9;     (* 1.50x amplification *)
  DoubleVol    = 1;     (* 2.00x amplification *)
  QuadrupleVol = 2;     (* 4.00x amplification *)

  (* All types of possible DMA xfers available (includes compressed modes)*)
  SixteenBitDMA   = $B6;      (* Rich CD Quality Sound Output *)
  EightBitDMA     = $14;      (* You'll normally need this *)
  TwoBitDMA       = $16;      (* YUKK! (In most cases) *)
  TwoBitRefDMA    = $17;
  FourBitDMA      = $74;      (* Actually, this doesn't sound too bad! *)
  FourBitRefDMA   = $75;
  TwoSixBitDMA    = $76;
  TwoSixBitRefDMA = $77;
  EightBitDMAADC  = $24;      (* Record at a resolution of 8 bits/sample *)
  HighSpeedDMAADC = $99;      (* Record at high speeds > 22Khz.          *)
  HighSpeedDMA    = $91;      (* This allows playback of samples > 22kHz *)

  Mono            = 0;        (* How the channels are played back...     *)
  Stereo          = 1;
  Surround        = 2;
type

  PhaseType = Mono..Surround;        (* Phase shift types possible       *)

(****************************************************************************)
(* Voice type incorported in my programs, (I use the VOC2RPD program to     *)
(* convert VOC files, and the WAV2RPD program to convert WAV files)         *)
(* Channel method: 0 - Layed down Byte 1 - Channel 0, Byte 2 - Channel 1... *)
(*                 1 - First Channel continuously for Size Bytes, then comes*)
(*                     the Second Channel, etc...                           *)
(****************************************************************************)
  RPDHeader = Record
                Sig: Array [0..2] of Char; (* "RPD" *)
                Version: Word;             (* Version # *)
                DAC: Byte;                 (* 8/16/4/4.6/2/2.6, etc...*)
                Phase: PhaseType;          (* Mono=0, Stereo=1, Surround=2 *)
                Freq: Word;                (* Sample Frequency *)
                Channels: Byte;            (* # of DIGITAL Channels *)
                ChannelMethod: Byte;       (* Method for laying down channels *)
                Size: LongInt;             (* Size of Sample *)
                Signed: Boolean;           (* 16-bit Signed/Unsigned sample *)
                Reserved: Array [1..31] of Byte;
              end;

  BaseSoundType = Record             (* For USER Defined sound clips     *)
                   Frequency: Word;
                   DACType: Byte;
                   Phase: PhaseType;
                   Buffer: Pointer;
                   BufferSize: Word;
                 end;

  (* This holds a "chunk" of up to 64K of the sample.                    *)
  SoundType = Record
                Frequency: Word;     (* Frequency of the sample          *)
                DACType: Byte;       (* ADPCM Method used for compression*)
                Phase: PhaseType;    (* Indicates Stereo/Mono/Surround   *)
                Buffer1: Pointer;    (* Our Two Buffers *)
                Buffer2: Pointer;
                Buffer1Size: Word;   (* Size of the sample in our buffers*)
                Buffer2Size: Word;
                BufferPlaying: 1..2; (* Which buffer is curently playing*)
              end;

  MicVolumeType = 0..7;              (* Volume resolution on the MIC-IN  *)
  ProVolumeType = 0..15;             (* Volume setting Resolution on an  *)
                                     (* SB-PRO                           *)
  InputSourceType = 0..3;
                                     (************************************)
  FilterType = 0..2;                 (* Filters available on the SB PRO  *)
                                     (* Filter 0 - Low Filter            *)
                                     (*        1 - High Filter           *)
                                     (*        2 - No Filter             *)
                                     (************************************)

const
 (* These are the valid parameters that can be sent to the SetInputSource*)
 (* procedure:                                                           *)
  Mic1Input = 0;  (* Input from Microphone #1         *)
  CDInput   = 1;  (* Input from the CD                *)
  Mic2Input = 2;  (* Input from Mic #2 (Can this be?) *)
  LineInput = 3;  (* Input from the Line-In jack.     *)

 (* These are the valid filter values for the Sound Blaster Pro:         *)
  LowFilter  = 0;
  HighFilter = 1;
  NoFilter   = 2;

var
  CurrentSound: SoundType;           (* The current sound playing        *)
  Playing: Boolean;                  (* If there is sound playing...     *)
  Recording: Boolean;                (* If we are currently recording... *)

(* The following Initializes the DSP chip for data, and should always be *)
(* called before you use ANY of the routines. The following are          *)
(* descriptions of what the parameters require:                          *)
(*                                                                       *)
(* Base should be:                                                       *)
(*  1 for Base Address 210h                                              *)
(*  2 for Base Address 220h (Default on most cards)                      *)
(*  3 for Base Address 230h                                              *)
(*  etc..                                                                *)
(*                                                                       *)
(* IRQ should be the IRQ level of your card (usually 5 or 7)             *)
(* Valid IRQs are now in the range of: 0..15 (or, in Hex: $0..$F)        *)
(* DMAChannel is the DMA Channel of your sound card (usually 1)          *)
(* HighDMA is the High DMA channel of your card (leave at 0 if no 16-bit *)
(* DAC/ADC is on the sound card!)                                        *)
(*                                                                       *)
(* Returns True if DSP was detected, else returns False                  *)
Function ResetDSP(Base : Byte; IRQ, DMAChannel, HighDMA: Byte) : Boolean;

(* Outputs a Byte to the Sound Card by writing directly to it...         *)
Procedure WriteDAC(Level : Byte);

(* Reads a Byte from the Sound Card by reading directly to it...         *)
Function ReadDAC : Byte;

(* Turns on the speaker (use before outputting sound to the card)        *)
Function SpeakerOn: Byte;

(* Turns off the speaker (does not affect DMA transfers, e.g: DMA xfers  *)
(* will still occur, but you will not HEAR them)                         *)
Function SpeakerOff: Byte;

(* Pauses a DMA xfer                                                     *)
Procedure DMAStop;

(* Continues a paused DMA xfer                                           *)
Procedure DMAContinue;

(* Use the following to play a sound up to 64K long                      *)
Procedure PlaySound (Sound: BaseSoundType);

(* This will play a sound file from DISK (using a 64K buffer), with the  *)
(* specified frequency and compression algorithm in SoundType.           *)
Procedure PlaySoundDSK (Filename: String; Frequency: Word; SoundType: Byte);

(* This will play a sound file (RPD) from disk, so all you have to do is *)
(* specify the Filename (no other settings are required)                 *)
Procedure PlaySoundRPD (Filename: String);

(* This will Load a RPD file's contents (up to 64K) into a memory buffer *)
(* specified. If MemAlloc is True then the procedure will allocate       *)
(* memory to the buffer, else the user has already allocated a suitable  *)
(* amount, and the program will not allocate memory for it (could result *)
(* in a Crash if Memory HASN'T been allocated...                         *)
Procedure LoadSoundRPD (Filename: String; var Sound: BaseSoundType;
          MemAlloc: Boolean);

(* This will record sound from the MICROPHONE to a RPD file on disk, use *)
(* the StopRecording command to stop the recording...                    *)
Procedure RecordSoundRPD (Filename: String; Freq: Word);

(* Stops a recording initiated by RecordSoundRPD.                        *)
Function StopRecording: Boolean;

(* Installs the SB Interrupt Hook                                        *)
Procedure InstallHandler;

(* Uninstalls the SB Interrupt Hook                                      *)
Procedure UninstallHandler;

(* Read a Byte from the DSP chip                                         *)
Function  ReadDSP : Byte;

(* Write a Byte to the DSP chip                                          *)
Procedure WriteDSP (Value : Byte);

(* Gets the DSP chip version number                                      *)
Function GetDSPVersion: String;

(* Mixes the two input parameters: Buffer1 and Buffer2, and returns it in*)
(* the Result parameter. Note: The Result Parameter needs to be allocated*)
(* prior to the call of this function!                                   *)
Procedure MixSamples (Buffer1, Buffer2: BaseSoundType;var Result:BaseSoundType);

(* Changes the size of the sound buffer (used for Disk xfers). A higher  *)
(* value provides smoother playback (albeit at the cost of memory), and  *)
(* a smaller one takes up less memory (but sounds choppier).             *)
(* Returns:                                                              *)
(*    True if Buffer size was changed (no sound was playing)             *)
(*    False if Buffer size wasn't changed (sound was playing)            *)
Function ChangeBufferSize (Size: Word): Boolean;

(* Returns the size of the allocated sound buffer.                       *)
Function CheckBufferSize: Word;

(* Changes the *Global* volume level (use the constants in the interface *)
(* section. One note on volume level: If you increase the volume level   *)
(* TOO Much, then you are going to get values above the 255 volume range!*)
(* This, needless to say, is NOT too good! You will end up getting VERY  *)
(* distorted sounds. So, unless you have a VERY SOFT sample, don't change*)
(* this Amount. However, if you have TOO LOUD of a sample, you could     *)
(* make it SOFTER. Anyways, this is the first REAL-TIME code in this     *)
(* unit, and I am pleased with its performance (I don't know about any   *)
(* one else's machine yet, but on my Pentium 60, I can't tell the        *)
(* difference in speed ;-) ). But really, I did this function up really  *)
(* quick to see the feasibility of REAL-TIME Sound Programming!          *)
Procedure ChangeVolumeLevel (Amnt: Byte);

(* Returns the *Global* volume level                                     *)
Function GetVolumeLevel: Byte;

(* Converts a signed 16-bit sample to a 8-bit unsigned sample...         *)
Procedure Convert16to8 (var SixteenBitSound, EightBitSound: BaseSoundType);

(*+---------------------------------------------------------------------+*)
(*|The Following routines should only be used with an SB PRO or higher: |*)
(*+---------------------------------------------------------------------+*)

(* Sets the Mixer to Mono mode                                           *)
Procedure PlayMono;

(* Sets the Mixer to Stereo mode                                         *)
(* VOC files are arranged differently in Stereo modes (odd bytes -> left *)
(* channel, even bytes -> right channel)                                 *)
Procedure PlayStereo;

(* Resets the CT 1345 Mixer chip (call before using any other functions) *)
Procedure ResetMixer;

(* Sets the Voice Level on the Sound Card *)
Procedure SetVocVolume (Left, Right: ProVolumeType);

(* Sets the FM Level on the Sound Card *)
Procedure SetFMVolume (Left, Right: ProVolumeType);

(* Sets the CD Level on the Sound Card *)
Procedure SetCDVolume (Left, Right: ProVolumeType);

(* Sets the Master Volume on the Sound Card *)
Procedure SetMasterVolume (Left, Right: ProVolumeType);

(* Sets the Mic in Volume Level on the Sound Card, before recording, make *)
(* sure that you set this to a non-zero value!                            *)
Procedure SetMicVolume (Volume: MicVolumeType);

(* Sets the Line in Volume Level, see notes on the Mic In Volume level for*)
(* more details...                                                        *)
Procedure SetLineInVolume (Left, Right: ProVolumeType);

(* Selects the Input Source (Line In, Mic, etc...) Use ONLY the valid     *)
(* constants!! Also, remember to specify a filter!                        *)
Procedure SetInputSource (Filter: FilterType; TheInputs: InputSourceType);

implementation
Uses Delay, DOS, Memory;

const
  (************************************************************************)
  (* Notes on the Buffer Size:                                            *)
  (* -------------------------                                            *)
  (* I generally find that values in the range of 16K to 64K are the best *)
  (* to use, (16K saves memory, and it still allows decent performance,   *)
  (* especially if the sample rate <= 11Khz, and 64K allows the BEST      *)
  (* performance possible, but takes away some precious memory space). I  *)
  (* usually prefer 32K ($7FFF) => Nice balance. But, when playing 16-bit *)
  (* sound at 44.1KHz stereo, note that we will be processing: 176,400    *)
  (* bytes/second! This means that with a buffer size of 64K, we will hit *)
  (* the interrupt handler 2.7x/sec! This could degrade system performance*)
  (* if you are doing heavy duty graphics processing at the same time, so *)
  (* I would advise that you use a lower sampling rate and/or depth.      *)
  (* Unless of course, you are making a music player.                     *)
  (************************************************************************)

  MaxXferSize: Word = $7FFF;  (* Double Buffer Size *)

 (************************************************************************)
 (* Note: In previous versions of the program, the user was able to      *)
 (* ----  change the size of the buffer as the program goes along,       *)
 (*       without having to check if the program was playing sound at    *)
 (*       that current moment. Now, this variable is isolated, and to    *)
 (*       change/check on the size of the currently allocated buffer, one*)
 (*       has to make the following calls: ChangeBufferSize, and         *)
 (*       CheckBufferSize. This way, the user doesn't "kill" the system  *)
 (*       in some weird way! Also, experiment with this value, especially*)
 (*       when you are doing Real-Time FX.                               *)
 (************************************************************************)

type
  BytePtr = ^Byte;
var
  SBBase : Word;
  SBDMA  : Byte;
  SBIRQ  : Byte;
  SBDMA16: Byte;

  DSP_RESET        : Word;
  DSP_READ_DATA    : Word;
  DSP_WRITE_DATA   : Word;
  DSP_WRITE_STATUS : Word;
  DSP_DATA_AVAIL   : Word;
  DSP_INT_ACK16    : Word;
  DSPPRO_READWRITE : Word;
  DSPPRO_INDEX     : Word;
  PlayingSixteenBit: Boolean;

  InDOSFlag: BytePtr;

  DMAMaskPort     : Word;
  DMAClrPtrPort   : Word;
  DMAModePort     : Word;
  DMABaseAddrPort : Word;
  DMACountPort    : Word;
  DMAPagePort     : Word;

  DMAStartMask    : Byte;
  DMAStopMask     : Byte;
  DMAMode         : Byte;

  Regs            : Registers;
  TurboPSP        : Word;
  TempPSP         : Word;

  LastSavedBuffer : Byte;

  IntHandler: Byte;
  OldIntHandler: Procedure;
  PicPort: Byte;
  IRQStopMask, IRQStartMask: Byte;
  CurPos: LongInt;
  CurPageEnd: LongInt;
  Length: Word;
  LeftToPlay: LongInt;
  VoiceEnd: LongInt;
  DSKFile: File;
  FileXferLeft: LongInt;
  PlayFromDisk: Boolean;
  OldExitProc: Pointer;
  FinishUp: Boolean;
  TotalRecorded: Longint;

const
  IRQHandlerInstalled: Boolean = False;
  SixteenBitCapable: Boolean = False;
  AutoInitCapable: Boolean = False;
  CurrentVolLevel: Byte = NormalVol;
  PlaySurround: Boolean = False;

Procedure Convert8to16 (var EightBitSound, SixteenBitSound: BaseSoundType);
Begin
End;

Procedure Convert16to8 (var SixteenBitSound, EightBitSound: BaseSoundType);
(***************************************************************************)
(* Converts a 16-bit Signed sample in SixteenBitSound to a 8-bit unsigned  *)
(* sample in EightBitSound. Frequency is preserved, but DACType and size   *)
(* are changed (EightBitSize := SixteenBitSize div 2)                      *)
(* Each sample word -> 1 Byte in the output buffer                         *)
(***************************************************************************)
var
  Dest, Source: Pointer;
  Amnt: Word;
Begin
  EightBitSound.DACType := EightBitDMA;
  EightBitSound.Frequency := SixteenBitSound.Frequency;
  EightBitSound.BufferSize := SixteenBitSound.BufferSize div 2;
  Dest := EightBitSound.Buffer;
  Source := SixteenBitSound.Buffer;
  Amnt := SixteenBitSound.BufferSize;
  asm
    CLD                 {; Clear the Direction flag }
    MOV CX, AMNT        {; Number of BYTES to xfer  }
    LES DI, [DEST]      {; ES:DI = Destination Buffer }
    LDS SI, [SOURCE]    {; DS:SI = Source Buffer      }
 @GETNEWSAMPLE:
    LODSW               {; Load a WORD (Unsigned) from the 16-bit sound }
    SHR AX, 9           {; Convert Word -> Byte                         }
    ADD AL, 128         {; Unsigned -> Signed                           }
    STOSB               {; Store the resulting Byte                     }
    LOOP @GETNEWSAMPLE  {; Finish off the REST of the Sample Data       }
    MOV AX, SEG @DATA   {; Restore Turbo Pascal's Data Segment          }
    MOV DS, AX
  end;
End;

Function GetAbsoluteAddress (P: Pointer): LongInt;
(* 286/8086 compatible version using 16-bit register pairs *)
(* Calculates: Segment * 16 + Offset using DX:AX *)
Begin
  asm
    XOR DX, DX                     {; Clear high word }
    MOV AX, WORD PTR [P+2]         {; AX = Segment }

    {; Shift DX:AX left by 4 bits (multiply by 16) }
    SHL AX, 1                      {; Shift bit into carry }
    RCL DX, 1                      {; Rotate carry into DX }
    SHL AX, 1
    RCL DX, 1
    SHL AX, 1
    RCL DX, 1
    SHL AX, 1
    RCL DX, 1

    {; Now DX:AX = Segment * 16, add the offset }
    ADD AX, WORD PTR [P]           {; Add offset to low word }
    ADC DX, 0                      {; Add carry to high word }

    {; Store 32-bit result (LongInt = DX:AX) }
    MOV WORD PTR @RESULT, AX       {; Low word }
    MOV WORD PTR @RESULT+2, DX     {; High word }
  end;
End;

Function NormalizePtr (P: Pointer): Pointer;
(* Returns Normalized Pointer of P *)
var
  LinearAddr: LongInt;
Begin
  LinearAddr := GetAbsoluteAddress (P);
  NormalizePtr := Ptr (LinearAddr div 16, LinearAddr mod 16);
End;

Function MemAllocPage (Size: Word): Pointer;
(* Returns a Pointer that is allocated on a PAGE boundary, NOT a SEGMENT *)
(* boundary, as DMA xfers are based on pages...                          *)
var
  P: Pointer;
Begin
  GetMem (P, Size);
  If (GetAbsoluteAddress (P) mod 65536) + Size < 65536 then
    MemAllocPage := P
  Else MemAllocPage := NormalizePtr (Ptr (Seg(P^), Ofs (P^) + Size));
End;

Function OutputSurround: Boolean;
Begin
  OutputSurround := False;
  If not Playing then
  Begin
    OutputSurround := True;
    PlaySurround := True;
  End;
End;

Function ShutOffSurround: Boolean;
Begin
  ShutOffSurround := False;
  If not Playing then
  Begin
    ShutOffSurround := True;
    PlaySurround := False;
  End;
End;

Procedure ChangeSampleVol (Buffer: PChar; Size: Word);
(*          Quick function to change the Sample Volume!          *)
var
  I: Word;
  ShrConstant: Byte;
Begin
  If CurrentVolLevel = NormalVol then Exit;
  If CurrentVolLevel = SilentVol then
    FillChar (Buffer^, Size, 0)
  Else if CurrentVolLevel in [DoubleVol, QuadrupleVol] then
    For I := 0 to Size do
      Buffer [I] := Char (Byte (Buffer [I]) shl CurrentVolLevel)
  Else if CurrentVolLevel in [HalfVol, QuarterVol] then
  Begin
   If CurrentVolLevel = HalfVol then
     ShrConstant := 1
   Else ShrConstant := 2;
    For I := 0 to Size do
      Buffer [I] := Char (Byte (Buffer [I]) shr ShrConstant);
  End
  Else if CurrentVolLevel in [One25Vol, One5Vol] then
  Begin
    If CurrentVolLevel = One25Vol then
      ShrConstant := 2
    Else ShrConstant := 1;
    For I := 0 to Size do
      Buffer [I] := Char (Byte (Buffer[I]) + Byte (Buffer[I]) shr ShrConstant);
  End;
End;

Procedure ChangeVolumeLevel (Amnt: Byte);
Begin
  CurrentVolLevel := Amnt;
End;

Function GetVolumeLevel: Byte;
Begin
  GetVolumeLevel := CurrentVolLevel;
End;

Procedure MixSamples (Buffer1, Buffer2: BaseSoundType;var Result:BaseSoundType);
var
  Temp1, Temp2, TempC: PChar;
  CurrentByte: Word;
Begin
  (* Figure out the size of the resulting sample (Max [Buffer1, Buffer2]) *)
  If Buffer1.BufferSize > Buffer2.BufferSize then
    Result.BufferSize := Buffer1.BufferSize
  else Result.BufferSize := Buffer2.BufferSize;
  (* Assuming that both frequencies are the same *)
  Result.Frequency := Buffer1.Frequency;

  (* Assuming that both DAC types are the same *)
  CurrentSound.DACType := Buffer1.DACType;
  CurrentByte := 0;
  Temp1 := Buffer1.Buffer;
  Temp2 := Buffer2.Buffer;
  TempC := Result.Buffer;
  Repeat
    (* Simple scaling function to "mix" the samples *)
    TempC^ := Char ((((Byte (Temp2^) * 2) - Byte (Temp1^))*2) div 2);
    Inc (TempC);
    If (CurrentByte < Buffer1.BufferSize) then
      Inc (Temp1)
    Else
      Temp1^ := #0;
    If (CurrentByte < Buffer2.BufferSize) then
      Inc (Temp2)
    Else
      Temp2^ := #0;
    Inc (CurrentByte);
  Until (CurrentByte >= Result.BufferSize);
End;

Function GetDSPVersion: String;
var
  MajorByte, MinorByte: Byte;
  MajorStr, MinorStr: String;
Begin
  WriteDSP ($E1);
  MajorByte := ReadDSP;
  If MajorByte >= 4 then
    SixteenBitCapable := True
  else SixteenBitCapable := False;
  If MajorByte >= 2 then
    AutoInitCapable := True
  Else AutoInitCapable := False;
  Str (MajorByte, MajorStr);
  MinorByte := ReadDSP;
  Str(MinorByte, MinorStr);
  If MinorByte < 10 then MinorStr := '0' + MinorStr;
  GetDSPVersion := MajorStr + '.' + MinorStr;
End;

Procedure WriteDSP(Value: Byte);
Begin
  While Port[DSP_WRITE_STATUS] and $80 <> 0 do;
    Port[DSP_WRITE_DATA] := Value;
End;

Function ReadDSP: Byte;
Begin
  While Port[DSP_DATA_AVAIL] and $80 = 0 do;
    ReadDSP := Port[DSP_READ_DATA];
End;

Procedure WriteDAC(Level: Byte);
Begin
  WriteDSP($10);
  WriteDSP(Level);
End;

Function ReadDAC: Byte;
Begin
  WriteDSP($20);
  ReadDAC := ReadDSP;
End;

Function SpeakerOn: Byte;
Begin
  WriteDSP($D1);
End;

Function SpeakerOff: Byte;
Begin
  WriteDSP($D3);
End;

Procedure DMAContinue;
Begin
  WriteDSP($D4);
End;

Procedure DMAStop;
Begin
  WriteDSP($D0);
End;

Procedure InitSB16for16Out;
Begin
  DMAMaskPort     := $D4;
  DMAClrPtrPort   := $D8;
  DMAModePort     := $D6;
  DMABaseAddrPort := $C0 + 4 * (SBDMA16 - 4);
  DMACountPort    := $C2 + 4 * (SBDMA16 - 4);
  Case SBDMA16 of
    5:  DMAPagePort := $8B;
    6:  DMAPagePort := $89;
    7:  DMAPagePort := $8A;
  end;
  DMAStopMask  := (SBDMA16 - 4) + $04;
  DMAStartMask := (SBDMA16 - 4) + $00;
  DMAMode      := (SBDMA16 - 4) + $48;  (* Non-Auto Init Mode... *)
End;

Procedure InitSB16for8Out;
Begin
  DMAMaskPort     := $0A;
  DMAClrPtrPort   := $0C;
  DMAModePort     := $0B;
  DMABaseAddrPort := 2 * SBDMA;
  DMACountPort    := 2 * SBDMA + 1;
  Case SBDMA of
    0:  DMAPagePort := $87;
    1:  DMAPagePort := $83;
    2:  DMAPagePort := $81;
    3:  DMAPagePort := $82;
  end;
  DMAStopMask  := SBDMA + $04;   (* Non-Auto Init Mode... *)
  DMAStartMask := SBDMA + $00;
  DMAMode      := SBDMA + $48;
End;

Function ResetDSP(Base : Byte; IRQ, DMAChannel, HighDMA: Byte) : Boolean;
   (* Returns TRUE if a DSP chip was found, else returns FALSE *)
const
   (* The IRQ Interrupt numbers available *)
   IRQIntNums : Array[0..15] of Byte =
                ($08, $09, $0A, $0B, $0C, $0D, $0E, $0F,
                 $70, $71, $72, $73, $74, $75, $76, $77);

Begin
(* Initialize Global variables *)
  SBBase := Base;
  SBIRQ := IRQ;
  SBDMA := DMAChannel;
  SBDMA16 := HighDMA;

  If IRQ <= 7 then PICPort := $21 else PICPort := $A1;

  IRQStopMask  := 1 SHL (IRQ MOD 8);
  IRQStartMask := Not (IRQStopMask);

  Base := Base * $10;

  (* Calculate the port addresses *)
  DSP_RESET        := Base + $206;
  DSP_READ_DATA    := Base + $20A;
  DSP_WRITE_DATA   := Base + $20C;
  DSP_WRITE_STATUS := Base + $20C;
  DSP_DATA_AVAIL   := Base + $20E;
  DSP_INT_ACK16    := Base + $20F;
  DSPPRO_READWRITE := Base + $205;
  DSPPRO_INDEX     := Base + $204;

  { GetDSPVersion moved to after detection - it calls WriteDSP/ReadDSP which can hang }

 (************************************************************************)
 (* Even if you have a Sound Blaster 16 card, this procedure initializes *)
 (* it for 8-bit playback! So, use the InitSB16for16Out procedure before *)
 (* attempting to play 16-bit sounds (unless you are using PlaySoundRPD, *)
 (* and in that case, my code automatically compensates). I chose to     *)
 (* write it this way for compatibility.                                 *)
 (************************************************************************)

  DMAMaskPort     := $0A;
  DMAClrPtrPort   := $0C;
  DMAModePort     := $0B;
  DMABaseAddrPort := 2 * DMAChannel;
  DMACountPort    := 2 * DMAChannel + 1;
  Case DMAChannel of
    0:  DMAPagePort := $87;
    1:  DMAPagePort := $83;
    2:  DMAPagePort := $81;
    3:  DMAPagePort := $82;
  end;
  DMAStopMask  := DMAChannel + $04;
  DMAStartMask := DMAChannel + $00;
  DMAMode      := DMAChannel + $48;
  (* Reset the DSP, and give some nice long delays just to be safe *)
  Port[DSP_RESET] := 1;
  DelayMS(10);
  Port[DSP_RESET] := 0;
  DelayMS(10);
  if (Port[DSP_DATA_AVAIL] and $80 = $80) and (Port[DSP_READ_DATA] = $AA) then
  begin
    ResetDSP := True;

    { Now safe to check DSP version (uses WriteDSP/ReadDSP which can hang on invalid ports) }
    GetDSPVersion;

    IntHandler := IRQIntNums[IRQ];
    InstallHandler;  { Only install handler if DSP detected successfully }
  end
  else
    ResetDSP := False;
end;

Procedure Playback; near;
(***************************************************************************)
(* This procedure should NOT be called by anyone outside of this unit, as  *)
(* its prime purpose is to start a DMA xfer, or get called by the Interrupt*)
(* handler when a xfer has to be continued!                                *)
(***************************************************************************)
var
  Time_Constant : Word;
  Page, Offset : Word;
begin
  (* Set up the DMA chip, by setting the Page and Offsets *)
  If PlayingSixteenBit then
  Begin
    Page := (CurPos div 2) div 65536;      (* Divide by 2 for 16-bit xfers *)
    Offset := (CurPos div 2) mod 65536;
  End
  Else
  Begin
    Page := CurPos div 65536;
    Offset := CurPos mod 65536;
  End;
  If VoiceEnd < CurPageEnd then
    Length := LeftToPlay-1
  Else
    Length := CurPageEnd - CurPos;

  Inc(CurPos, LongInt(Length)+1);
  Dec(LeftToPlay, LongInt(Length)+1);
  Inc(CurPageEnd, 65536);

  (* Set the playback frequency (Note: Not used for 16-bit xfers) *)
  If not PlayingSixteenBit then
    Time_Constant := 256 - (1000000 div CurrentSound.Frequency);

  { ---- BEGIN: Atomic DMA/DSP program window ---- }
  { Prevent interrupt preemption and force forward string ops }
  asm
    pushf      { save flags incl. IF/DF }
    cli        { no preemption during programming }
    cld        { guarantee forward string ops }
  end;

  (* Now, we must program the DMA chip for another xfer *)
  Port[DMAMaskPort]     := DMAStopMask;  (* Stop any DMA activity so far *)
  Port[DMAClrPtrPort]   := $00;
  Port[DMAModePort]     := DMAMode;
  Port[DMABaseAddrPort] := Lo(Offset);
  Port[DMABaseAddrPort] := Hi(Offset);
  If PlayingSixteenBit then
  Begin
    Port[DMACountPort]    := Lo(Length div 2); (* # of WORDS to xfer *)
    Port[DMACountPort]    := Hi(Length div 2);
  End
  Else
  Begin
    Port[DMACountPort]    := Lo(Length);       (* # of BYTES to xfer *)
    Port[DMACountPort]    := Hi(Length);
  End;
  Port[DMAPagePort]     := Page;
  Port[DMAMaskPort]     := DMAStartMask; (* Start the DMA transfer *)

  If PlayingSixteenBit then
  Begin
    WriteDSP ($41);
    WriteDSP (Hi (CurrentSound.Frequency)*2);
    WriteDSP (Lo (CurrentSound.Frequency)*2);
    WriteDSP ($B2);      { 10111010 }
    If CurrentSound.Phase = Stereo then
      WriteDSP ($20)     { 00xx0000 }
    Else WriteDSP ($10);
    WriteDSP (Lo (Length) div 2);
    WriteDSP (Hi (Length) div 2);
  End
  Else
  Begin
    WriteDSP($40);
    WriteDSP(Time_constant);
    If CurrentSound.DACType = HighSpeedDMA then
    Begin
      WriteDSP ($48);
      WriteDSP (Lo (Length));
      WriteDSP (Hi (Length));
      WriteDSP ($91);
    End
    Else
    Begin
      WriteDSP(CurrentSound.DACType);
      WriteDSP(Lo(Length));
      WriteDSP(Hi(Length));
    End;
  End;

  asm
    popf       { restore IF/DF exactly as they were }
  end;
  { ---- END: Atomic DMA/DSP program window ---- }
End;

Procedure PlaySoundDSK (Filename: String; Frequency: Word; SoundType: Byte);
Begin
  Assign (DSKFile, Filename);
  Reset (DSKFile, 1);
  CurrentSound.Frequency := Frequency;
  CurrentSound.DACType := SoundType;
  FileXferLeft := FileSize (DSKFile);
  PlayFromDisk := True;
  If FileSize (DSKFile) > MaxXferSize then
  Begin
    CurrentSound.Buffer1Size := MaxXferSize;
    BlockRead (DSKFile, CurrentSound.Buffer1^, MaxXferSize);
    Dec (FileXferLeft, MaxXferSize);
  End
  Else
  Begin
    CurrentSound.Buffer1Size := FileSize (DSKFile);
    BlockRead (DSKFile, CurrentSound.Buffer1^, Filesize (DSKFile));
    Dec (FileXferLeft, FileSize (DSKFile));
  End;
  LeftToPlay := CurrentSound.Buffer1Size - 6;
  CurPos := GetAbsoluteAddress (CurrentSound.Buffer1) + 6;
  CurPageEnd := ((CurPos shr 16) shl 16) + 65536 - 1;
  Length := CurPageEnd - CurPos;
  VoiceEnd := CurPos + LeftToPlay;
  Playing := True;
  PlayFromDisk := True;
  SpeakerOn;
  PlayBack;
End;

Procedure RecordSoundRPD (Filename: String; Freq: Word);
(*****************************************************************************)
(* Record to a File (Filename), with 8bits/sample at the frequency specified *)
(* (Note: Sound will record UNTIL StopRecording is issued!)                  *)
(*****************************************************************************)
var
  TempHead: RPDHeader;
Begin
  TotalRecorded := 0;
  CurrentSound.DACType := EightBitDMAADC;            (* Input = ADC *)
  CurrentSound.Frequency := Freq;
  Assign (DSKFile, Filename);
  Rewrite (DSKFile, 1);
  BlockWrite (DSKFile, TempHead, SizeOf (TempHead)); (* Write "garbage" to *)
                                                     (* the header, we'll  *)
                                                     (* fill it in later!  *)
  CurrentSound.Phase := Mono;     (* We'll only record in MONO!            *)
  CurrentSound.BufferPlaying := 1;
  FillChar (CurrentSound.Buffer1^, CheckBufferSize div 2, 0);
  FillChar (CurrentSound.Buffer2^, CheckBufferSize div 2, 0);
  DMAMode := SBDMA + $44;         (* THE NEW DMA MODE! *)
  CurrentSound.Buffer1Size := MaxXferSize div 2;
  CurrentSound.Buffer2Size := MaxXferSize div 2;
  LeftToPlay := CurrentSound.Buffer1Size - 6;
  CurPos := GetAbsoluteAddress (CurrentSound.Buffer1) + 6;
  CurPageEnd := ((CurPos shr 16) shl 16) + 65536 - 1;
  Length := CurPageEnd - CurPos;
  VoiceEnd := CurPos + LeftToPlay;
  Recording := True;
  SpeakerOn;
  LastSavedBuffer := 2;
  PlayBack;
End;

Function StopRecording: Boolean;
(***************************************************************************)
(*   MUST be called to stop the recording! Returns TRUE if there was a     *)
(* recording in progress, FALSE otherwise...                               *)
(***************************************************************************)

var
  TempHead: RPDHeader;
Begin
  StopRecording := False;
  If Recording then
  Begin
    Port [DMAMaskPort] := DMAStopMask;  (* STOP DMA Xfer! *)
    DMAStop;                            (* Stop the Sound Card too *)
    StopRecording := True;
    TempHead.DAC := EightBitDMA;
    TempHead.Phase := Mono;
    TempHead.Freq := CurrentSound.Frequency;
    TempHead.Size := TotalRecorded;
    TempHead.Channels := 1;
    If LastSavedBuffer = 1 then
      BlockWrite (DSKFile, CurrentSound.Buffer2^, MaxXferSize div 2)
    Else
      BlockWrite (DSKFile, CurrentSound.Buffer1^, MaxXferSize div 2);
    Seek (DSKFile, 0);
    BlockWrite (DSKFile, TempHead, SizeOf (TempHead));
    Close (DSKFile);
    Recording := False;
  End;
End;

Procedure LoadSoundRPD (Filename: String; var Sound: BaseSoundType;
          MemAlloc: Boolean);
(***************************************************************************)
(*  Loads a RPD file into a buffer (up to 64K). MemAlloc should be True if *)
(* the buffer hasn't been allocated yet, False if a buffer in memory has   *)
(* already been allocated...                                               *)
(***************************************************************************)

var
  TempHead: RPDHeader;
  TempFile: File;
Begin
  Assign (TempFile, Filename);
  Reset (TempFile, 1);
  BlockRead (TempFile, TempHead, SizeOf (TempHead));
  Sound.Frequency := TempHead.Freq;
  Sound.DACType := TempHead.DAC;
  If not SixteenBitCapable then
    If Sound.Frequency >= 23000 then
      Sound.DACType := HighSpeedDMA;
  Sound.Phase := TempHead.Phase;
  If FileSize (TempFile) - SizeOf (TempHead) > $FFFF then
    Sound.BufferSize := $FFFF
  else Sound.BufferSize := FileSize (TempFile) - SizeOf (TempHead);
  If MemAlloc then
    GetMem (Sound.Buffer, Sound.BufferSize);
  BlockRead (TempFile, Sound.Buffer^, Sound.BufferSize);
  ChangeSampleVol (Sound.Buffer, Sound.BufferSize);
  Close (TempFile);
End;

Procedure PlaySoundRPD (Filename: String);
var
  TempHead: RPDHeader;
Begin
  Assign (DSKFile, Filename);
  Reset (DSKFile, 1);
  BlockRead (DSKFile, TempHead, Sizeof (TempHead));
  CurrentSound.Frequency := TempHead.Freq;
  CurrentSound.DACType := TempHead.DAC;
  If CurrentSound.DACType = SixteenBitDMA then
  Begin
    PlayingSixteenBit := True;
    InitSB16for16Out;
  End
  Else
  Begin
    PlayingSixteenBit := False;
    If SixteenBitCapable then
      InitSB16for8Out;
  End;
   (* Note that High Speed DMA xfers are not supported on the Sound Blaster *)
   (* 16 (since it doesn't need them), and should NOT be used on that class *)
   (* of sound card!!                                                       *)
  If not SixteenBitCapable then
  Begin
    If CurrentSound.Frequency >= 23000 then
      CurrentSound.DACType := HighSpeedDMA;
  End;
  ResetMixer;
  (* Then we have a stereo file, and for the SB-PRO, output in stereo... *)
  If TempHead.Phase = 1 then
    PlayStereo   (* Initialize the SB-PRO to play in stereo  *)
  Else PlayMono; (* We have a mono file, and reset the mixer *)
  CurrentSound.Phase := TempHead.Phase;
  FileXferLeft := FileSize (DSKFile) - SizeOf (TempHead);
  PlayFromDisk := True;
  If FileSize (DSKFile) > (MaxXferSize - SizeOf (TempHead)) then
  Begin
    CurrentSound.Buffer1Size := MaxXferSize div 2;
    CurrentSound.Buffer2Size := MaxXferSize div 2;
    BlockRead (DSKFile, CurrentSound.Buffer1^, (MaxXferSize - SizeOf (TempHead))
                         div 2);
    BlockRead (DSKFile, CurrentSound.Buffer2^, (MaxXferSize - SizeOf (TempHead))
                         div 2);
    If CurrentVolLevel <> NormalVol then
    Begin
      ChangeSampleVol (CurrentSound.Buffer1, MaxXferSize div 2);
      ChangeSampleVol (CurrentSound.Buffer2, MaxXferSize div 2);
    End;
    Dec (FileXferLeft, MaxXferSize);
    FinishUp := False;
  End
  Else
  Begin
    CurrentSound.Buffer1Size := FileSize (DSKFile) div 2;
    CurrentSound.Buffer2Size := FileSize (DSKFile) div 2;
    BlockRead (DSKFile, CurrentSound.Buffer1^, FileXferLeft div 2);
    BlockRead (DSKFile, CurrentSound.Buffer2^, FileXferLeft div 2);
    If CurrentVolLevel <> NormalVol then
    Begin
      ChangeSampleVol (CurrentSound.Buffer1, FileXferLeft div 2);
      ChangeSampleVol (CurrentSound.Buffer2, FileXferLeft div 2);
    End;
    Dec (FileXferLeft, FileSize (DSKFile));
    FinishUp := True;
  End;
  CurrentSound.BufferPlaying := 1;
  LeftToPlay := CurrentSound.Buffer1Size - 6;
  CurPos := GetAbsoluteAddress (CurrentSound.Buffer1) + 6;
  CurPageEnd := ((CurPos shr 16) shl 16) + 65536 - 1;
  Length := CurPageEnd - CurPos;
  VoiceEnd := CurPos + LeftToPlay;
  Playing := True;
  PlayFromDisk := True;
  SpeakerOn;
  PlayBack;
End;

Procedure PlaySound (Sound: BaseSoundType);
Begin
  { Normalize DF before we set up globals (belt-and-suspenders) }
  asm cld end;
  LeftToPlay := Sound.BufferSize - 6;
  CurrentSound.DACType := Sound.DACType;
  CurrentSound.Frequency := Sound.Frequency;
  CurPos := GetAbsoluteAddress (Sound.Buffer) + 6;
  CurPageEnd := ((CurPos shr 16) shl 16) + 65536 - 1;
  Length := CurPageEnd - CurPos;
  VoiceEnd := CurPos + LeftToPlay;
  Playing := True;
  PlayFromDisk := False;
  FinishUp := False;  { BUGFIX: Initialize to prevent interrupt handler from using wrong code path }
  If SixteenBitCapable then
  Begin
    If CurrentSound.DACType = SixteenBitDMA then
      InitSB16for16Out
    Else InitSB16for8Out;
  End;
  If CurrentVolLevel <> NormalVol then
    ChangeSampleVol (Sound.Buffer, Sound.BufferSize);
  SpeakerOn;
  PlayBack;
End;

Function ChangeBufferSize (Size: Word): Boolean;
Begin
  ChangeBufferSize := False;
  If ((not Playing) and (not Recording)) then
  Begin
    FreeMem (CurrentSound.Buffer1, MaxXferSize div 2);
    FreeMem (CurrentSound.Buffer2, MaxXferSize div 2);
    MaxXferSize := Size;
    ChangeBufferSize := True;
    GetMem (CurrentSound.Buffer1, MaxXferSize div 2);
    GetMem (CurrentSound.Buffer2, MaxXferSize div 2);
  End;
End;

Function CheckBufferSize: Word;
Begin
  CheckBufferSize := MaxXferSize;
End;

Procedure ClearInterrupt;
var
  Temp: Byte;
Begin
  If not PlayingSixteenBit then
    Temp := Port[DSP_DATA_AVAIL]
  Else
    Temp := Port[DSP_INT_ACK16];
  Port[PICPort - 1] := $20;
End;

Procedure DoFinishUp; near;
Begin
  If CurrentSound.BufferPlaying = 1 then
  Begin
    CurrentSound.BufferPlaying := 2;
    LeftToPlay := CurrentSound.Buffer2Size - 6;
    CurPos := GetAbsoluteAddress (CurrentSound.Buffer2) + 6;
    CurPageEnd := ((CurPos shr 16) shl 16) + 65536 - 1;
    Length := CurPageEnd - CurPos;
    VoiceEnd := CurPos + LeftToPlay;
    PlayBack;
  End
  Else
  Begin
    CurrentSound.BufferPlaying := 1;
    LeftToPlay := CurrentSound.Buffer1Size - 6;
    CurPos := GetAbsoluteAddress (CurrentSound.Buffer1) + 6;
    CurPageEnd := ((CurPos shr 16) shl 16) + 65536 - 1;
    Length := CurPageEnd - CurPos;
    VoiceEnd := CurPos + LeftToPlay;
    PlayBack;
  End;
  FinishUp := False;
End;

Procedure DoRecordToDisk; near;
Begin
  If CurrentSound.BufferPlaying = 1 then
  Begin
    CurrentSound.BufferPlaying := 2;
    LeftToPlay := CurrentSound.Buffer2Size - 6;
    CurPos := GetAbsoluteAddress (CurrentSound.Buffer2) + 6;
    CurPageEnd := ((CurPos shr 16) shl 16) + 65536 - 1;
    Length := CurPageEnd - CurPos;
    VoiceEnd := CurPos + LeftToPlay;
    PlayBack;
    BlockWrite (DSKFile, CurrentSound.Buffer1^, MaxXferSize div 2);
    LastSavedBuffer := 1;
    FillChar (CurrentSound.Buffer1^, MaxXferSize div 2, 0);
  End
  Else
  Begin
    CurrentSound.BufferPlaying := 1;
    LeftToPlay := CurrentSound.Buffer1Size - 6;
    CurPos := GetAbsoluteAddress (CurrentSound.Buffer1) + 6;
    CurPageEnd := ((CurPos shr 16) shl 16) + 65536 - 1;
    Length := CurPageEnd - CurPos;
    VoiceEnd := CurPos + LeftToPlay;
    PlayBack;
    BlockWrite (DSKFile, CurrentSound.Buffer2^, MaxXferSize div 2);
    LastSavedBuffer := 2;
    FillChar (CurrentSound.Buffer2^, MaxXferSize div 2, 0);
  End;
End;

Procedure DoPlayFromDisk; near;
Begin
    If FileXferLeft > 0 then
    Begin
      If FileXferLeft > (MaxXferSize div 2) then
      Begin
        If CurrentSound.BufferPlaying = 1 then
        Begin
          CurrentSound.BufferPlaying := 2;
          LeftToPlay := CurrentSound.Buffer2Size - 6;
          CurPos := GetAbsoluteAddress (CurrentSound.Buffer2) + 6;
          CurPageEnd := ((CurPos shr 16) shl 16) + 65536 - 1;
          Length := CurPageEnd - CurPos;
          VoiceEnd := CurPos + LeftToPlay;
          PlayBack;
          BlockRead (DSKFile, CurrentSound.Buffer1^, MaxXferSize div 2);
          CurrentSound.Buffer1Size := MaxXferSize div 2;
          If CurrentVolLevel <> NormalVol then
            ChangeSampleVol (CurrentSound.Buffer1, MaxXferSize div 2);
          Dec (FileXferLeft, MaxXferSize div 2);
        End
        Else
        Begin
          CurrentSound.BufferPlaying := 1;
          LeftToPlay := CurrentSound.Buffer1Size - 6;
          CurPos := GetAbsoluteAddress (CurrentSound.Buffer1) + 6;
          CurPageEnd := ((CurPos shr 16) shl 16) + 65536 - 1;
          Length := CurPageEnd - CurPos;
          VoiceEnd := CurPos + LeftToPlay;
          PlayBack;
          BlockRead (DSKFile, CurrentSound.Buffer2^, MaxXferSize div 2);
          If CurrentVolLevel <> NormalVol then
            ChangeSampleVol (CurrentSound.Buffer2, MaxXferSize div 2);
          CurrentSound.Buffer2Size := MaxXferSize div 2;
          Dec (FileXferLeft, MaxXferSize div 2);
        End;
      End
      Else
      Begin
        FinishUp := True;
        If CurrentSound.BufferPlaying = 1 then
        Begin
          CurrentSound.BufferPlaying := 2;
          LeftToPlay := CurrentSound.Buffer2Size - 6;
          CurPos := GetAbsoluteAddress (CurrentSound.Buffer2) + 6;
          CurPageEnd := ((CurPos shr 16) shl 16) + 65536 - 1;
          Length := CurPageEnd - CurPos;
          VoiceEnd := CurPos + LeftToPlay;
          PlayBack;
          BlockRead (DSKFile, CurrentSound.Buffer1^, FileXferLeft);
          CurrentSound.Buffer1Size := FileXferLeft;
          If CurrentVolLevel <> NormalVol then
            ChangeSampleVol (CurrentSound.Buffer1, FileXferLeft);
          FileXferLeft := 0;
        End
        Else
        Begin
          CurrentSound.BufferPlaying := 1;
          LeftToPlay := CurrentSound.Buffer1Size - 6;
          CurPos := GetAbsoluteAddress (CurrentSound.Buffer1) + 6;
          CurPageEnd := ((CurPos shr 16) shl 16) + 65536 - 1;
          Length := CurPageEnd - CurPos;
          VoiceEnd := CurPos + LeftToPlay;
          PlayBack;
          BlockRead (DSKFile, CurrentSound.Buffer2^, FileXferLeft);
          CurrentSound.Buffer2Size := FileXferLeft;
          If CurrentVolLevel <> NormalVol then
            ChangeSampleVol (CurrentSound.Buffer2, FileXferLeft);
          FileXferLeft := 0;
        End;
      End;
    End
    Else
    Begin
      (* Say that we have nothing more to say :-) *)
      Playing := False;
      PlayFromDisk := False;
      (* Turn off the speaker *)
      SpeakerOff;
      (* Close the file that we used *)
      Close (DSKFile);
    End;
End;

Procedure SBIntHandler; interrupt;
(***************************************************************************)
(* This procedure handles interrupt calls from the DMA chip when a xfer is *)
(* complete. As of version 1.01, this procedure has been expanded to read  *)
(* in a block off of a disk file as well. I have to try to make this code  *)
(* as fast as possible in the future, as it will "Interrupt" the main      *)
(* program, to do its own thing. And, in a game that can slow things down  *)
(* considerably. (Depending on sample rates, after all, sound that is      *)
(* recorded at 44Khz at 8 bits will xfer 44K to the DMA chip/second, that  *)
(* means with a 32K buffer, we won't even get 1 SECOND before the next     *)
(* interrupt!!!                                                            *)
(*                                                                         *)
(* Revisions:                                                              *)
(* ---------                                                               *)
(*   Version 1.01: Modified to handle disk reads into a "buffer", and then *)
(*                 output the buffer to the sound card. NO Double Buffering*)
(*   Version 2.0�: Modified to handle Double Buffering AND Real-Time       *)
(*                 Voice Amplification. Also modified to handle DOS        *)
(*                 re-entrancy issues. Recording implemented as well.      *)
(*                 Made the function a LOT prettier with modules broken up!*)
(*   2025 PATCH: Removed CLI/STI to allow HSC timer interrupts to continue *)
(*               while processing SB DMA blocks. The DOS re-entrancy code  *)
(*               (InDOSFlag, PSP switching, DTA) already protects against  *)
(*               conflicts. This allows simultaneous music + sound FX.     *)
(***************************************************************************)

var
  NewDTAArea: Array [1..128] of Byte;
  OldDTAArea: Pointer;
Begin
  { Ensure DF=0 inside handler; prevent DF leak on exit }
  asm cld end;
  { CLI removed - allow timer interrupts (HSC music) to continue }
  { asm CLI end; }
  (* First, we set the DOS critical error flag, so it uses that stack on   *)
  (* re-entry.                                                             *)
  If not Recording then
    InDOSFlag^ := 1;
  (* Now, we switch from the DOS PSP (if there is one, to ours)            *)
  Regs.AH := $51;
  MsDOS (Regs);
  TempPSP := Regs.BX;
  Regs.AH := $50;
  Regs.BX := TurboPSP;
  MsDOS (Regs);
  (* Get the Main Program's Data Transfer Area, and store it in OLDDTAArea *)
  Regs.AH := $2F;
  MsDOS (Regs);
  OldDTAArea := Ptr (Regs.ES, Regs.BX);
  (* Set the DTA to our temporary one, that we will use... *)
  Regs.AH := $1A;
  Regs.DS := Seg (NewDTAArea);
  Regs.DX := Ofs (NewDTAArea);
  MsDOS (Regs);

  If LeftToPlay > 0 then
    PlayBack
  Else if FinishUp then
    DoFinishUp
  Else if PlayFromDisk then
    DoPlayFromDisk
  Else if Recording then
    DoRecordToDisk
  Else
    Playing := False;
  (* Now, we switch to the DOS PSP (if there was one, from ours) *)
  Regs.AH := $50;
  Regs.BX := TempPSP;
  MsDOS (Regs);
  (* Now, we switch back to the OLD DTA... *)
  Regs.AH := $1A;
  Regs.DS := Seg (OldDTAArea);
  Regs.DX := Ofs (OldDTAArea);
  MsDOS (Regs);
  { STI removed - interrupts remain enabled throughout handler }
  { asm STI end; }
  ClearInterrupt;   (* Tell the PIC chip that the interrupt is OVER *)
End;

Procedure StopSBIRQ;
Begin
  Port[PICPort] := Port[PICPort] OR IRQStopMask;
End;

Procedure StartSBIRQ;
Begin
  Port[PICPort] := Port[PICPort] AND IRQStartMask;
End;

Procedure SetMixerReg(Index, Value : Byte);
Begin
  Port[DSPPRO_INDEX] := Index;
  Port[DSPPRO_READWRITE] := Value;
End;

Function GetMixerReg(Index : Byte) : Byte;
Begin
  Port[DSPPRO_INDEX] := Index;
  GetMixerReg := Port[DSPPRO_READWRITE];
End;

Procedure ResetMixer;
Begin
  SetMixerReg (0, 0);
End;

Procedure PlayStereo;
Begin
  SetMixerReg ($E, $2);
End;

Procedure PlayMono;
Begin
  SetMixerReg ($E, $0);
End;

Procedure SetFMVolume (Left, Right: ProVolumeType);
Begin
  SetMixerReg ($26, Left SHL 4 + Right);
End;

Procedure SetCDVolume (Left, Right: ProVolumeType);
Begin
  SetMixerReg ($28, Left SHL 4 + Right);
End;

Procedure SetMasterVolume (Left, Right: ProVolumeType);
Begin
  SetMixerReg ($22, Left SHL 4 + Right);
End;

Procedure SetVocVolume (Left, Right: ProVolumeType);
Begin
  SetMixerReg ($4, Left SHL 4 + Right);
End;

Procedure SetMicVolume (Volume: MicVolumeType);
Begin
  SetMixerReg ($A, Volume);
End;

Procedure SetLineInVolume (Left, Right: ProVolumeType);
Begin
  SetMixerReg ($2E, Left SHL 4 + Right);
End;

Procedure SetInputSource (Filter: FilterType; TheInputs: InputSourceType);
Begin
  SetMixerReg ($C, Filter shl 3 + TheInputs shl 1);
End;

Procedure InstallHandler;
Begin
  StopSBIRQ;
  GetIntVec(IntHandler, @OldIntHandler);
  SetIntVec(IntHandler, @SBIntHandler);
  StartSBIRQ;
  IRQHandlerInstalled := True;
End;

Procedure UninstallHandler;
Begin
  StopSBIRQ;
  SetIntVec(IntHandler, @OldIntHandler);
  IRQHandlerInstalled := False;
End;

{$F+}
Procedure SBExitProc;
Begin
  ExitProc := OldExitProc;
  If Playing then
    DMAStop;
  If IRQHandlerInstalled then
    UninstallHandler;
End;
{$F-}

Procedure GetInDOSFlag;
Begin
  Regs.AH := $34;
  MsDOS (Regs);
  InDOSFlag := Ptr (Regs.ES, Regs.BX);
  Regs.AH := $51;
  MsDOS (Regs);
  TurboPSP := Regs.BX;
End;

Begin
  OldExitProc := ExitProc;
  ExitProc := @SBExitProc;
  Playing := False;
  Recording := False;
  GetMem (CurrentSound.Buffer1, MaxXferSize div 2);
  GetMem (CurrentSound.Buffer2, MaxXferSize div 2);
  GetInDOSFlag;
  LastSavedBuffer := 0;
End.