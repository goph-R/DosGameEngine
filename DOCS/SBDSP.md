# SBDSP - Sound Blaster Driver

Sound Blaster DSP driver with DMA-based digital audio (1995, Romesh Prakashpalan).

## Types

```pascal
type
  BaseSoundType = Record
    Frequency: Word;      { Sample rate (11025, 22050 Hz) }
    DACType: Byte;        { EightBitDMA, HighSpeedDMA, etc. }
    Phase: PhaseType;     { Mono, Stereo, Surround }
    Buffer: Pointer;
    BufferSize: Word;     { Max 64KB }
  end;

  RPDHeader = Record
    Sig: Array[0..2] of Char;  { "RPD" }
    Version: Word;
    DAC: Byte;
    Phase: PhaseType;
    Freq: Word;
    Size: LongInt;
    { ... }
  end;

  PhaseType = Mono..Surround;
```

## Constants

```pascal
const
  { Volume levels (use with ChangeVolumeLevel) }
  SilentVol    = 10;   { 0.00x }
  HalfVol      = 3;    { 0.50x }
  NormalVol    = 0;    { 1.00x }
  DoubleVol    = 1;    { 2.00x }
  QuadrupleVol = 2;    { 4.00x - may distort }

  { DMA transfer types }
  EightBitDMA     = $14;  { Standard 8-bit PCM }
  HighSpeedDMA    = $91;  { >22 kHz }
  SixteenBitDMA   = $B6;  { SB16 only }

  { Input sources }
  Mic1Input = 0;
  CDInput   = 1;
  LineInput = 3;
```

## Globals

```pascal
var
  Playing: Boolean;         { True if sound is playing }
  Recording: Boolean;
  CurrentSound: SoundType;
```

## Functions

### Initialization

```pascal
function ResetDSP(Base, IRQ, DMAChannel, HighDMA: Byte): Boolean;
procedure InstallHandler;
procedure UninstallHandler;  { CRITICAL: Call before exit }
```

**Base values:** 1=$210, 2=$220 (most common), 3=$230, 4=$240
**IRQ:** 5 or 7
**DMA:** 1 (8-bit), 5 (16-bit)

### Playback

```pascal
procedure PlaySound(Sound: BaseSoundType);
procedure PlaySoundRPD(Filename: String);  { Streaming, no size limit }
procedure PlaySoundDSK(Filename: String; Frequency: Word; SoundType: Byte);
procedure LoadSoundRPD(Filename: String; var Sound: BaseSoundType; MemAlloc: Boolean);
```

### Recording

```pascal
procedure RecordSoundRPD(Filename: String; Freq: Word);
function StopRecording: Boolean;
```

### Control

```pascal
function SpeakerOn: Byte;
function SpeakerOff: Byte;
procedure DMAStop;
procedure DMAContinue;
procedure ChangeVolumeLevel(Amnt: Byte);  { Use volume constants }
function GetVolumeLevel: Byte;
function ChangeBufferSize(Size: Word): Boolean;
function CheckBufferSize: Word;
```

### Mixer (SB Pro)

```pascal
procedure ResetMixer;
procedure SetVocVolume(Left, Right: ProVolumeType);    { 0-15 }
procedure SetFMVolume(Left, Right: ProVolumeType);
procedure SetMasterVolume(Left, Right: ProVolumeType);
procedure SetMicVolume(Volume: MicVolumeType);         { 0-7 }
procedure SetInputSource(Filter: FilterType; TheInputs: InputSourceType);
```

## Example

```pascal
uses SBDSP;

var
  Explosion: BaseSoundType;

begin
  { Initialize }
  if not ResetDSP(2, 5, 1, 0) then  { Port $220, IRQ 5, DMA 1 }
  begin
    WriteLn('Sound Blaster not found!');
    Halt(1);
  end;

  { Play RPD file (streaming) }
  PlaySoundRPD('DATA\EXPLODE.RPD');
  while Playing do asm nop end;

  { Or preload for instant playback }
  LoadSoundRPD('LASER.RPD', Explosion, True);
  PlaySound(Explosion);
  while Playing do asm nop end;

  { Cleanup }
  FreeMem(Explosion.Buffer, Explosion.BufferSize);
  UninstallHandler;  { MUST call before exit }
end.
```

## Critical Notes

1. **UninstallHandler** - MUST call before exit or system hangs
2. **ResetDSP first** - Call before any other functions
3. **64KB limit** - PlaySound limited to 64KB, use PlaySoundRPD for larger
4. **HSC conflict** - Don't use `while Playing` loop with HSC music (freezes)
5. **DMA boundaries** - Handled automatically by driver
6. **Base port** - Most cards use Base=2 ($220)

## Creating RPD Files

```bash
VOC2RPD INPUT.VOC OUTPUT.RPD
WAV2RPD INPUT.WAV OUTPUT.RPD
```

Utilities in VENDOR/SBDSP2B/.

## Notes

- Double-buffered streaming for smooth playback
- Minimal CPU usage (~1% on 386)
- Compatible with SB Pro, SB16, AWE32
- Real-time volume control during playback
- See SNDBANK.PAS for XMS-based sound library manager
