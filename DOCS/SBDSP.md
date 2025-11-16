# SBDSP.PAS - API Documentation

Professional Sound Blaster DSP driver for DOS with DMA-based digital audio playback.

**Version:** 2.0β
**Author:** Romesh Prakashpalan (1995)
**License:** Freeware

## Table of Contents

- [Overview](#overview)
- [Types](#types)
- [Constants](#constants)
- [Global Variables](#global-variables)
- [Initialization and Cleanup](#initialization-and-cleanup)
- [Playback Functions](#playback-functions)
- [Recording Functions](#recording-functions)
- [Control Functions](#control-functions)
- [Mixer Functions (SB Pro)](#mixer-functions-sb-pro)
- [Low-Level Functions](#low-level-functions)
- [Common Usage Patterns](#common-usage-patterns)
- [Performance Notes](#performance-notes)

---

## Overview

SBDSP.PAS is a professional-grade Sound Blaster driver featuring:

- **Double-buffered DMA playback** - Smooth audio without CPU polling
- **8-bit mono/stereo support** - Standard Sound Blaster capabilities
- **Interrupt-driven** - Uses IRQ5/7 for automatic buffer management
- **Real-time volume control** - Adjust volume during playback
- **RPD file format** - Optimized binary format for efficient storage
- **SB Pro mixer support** - Control master/voice/CD/line-in volumes
- **Recording support** - Capture audio from microphone/line-in

**Tested on:**
- Sound Blaster Pro 2.0
- Sound Blaster 16
- Sound Blaster AWE 32

**Typical Configuration:**
- Base: $220 (Port 220h)
- IRQ: 5 or 7
- DMA: 1

---

## Types

### BaseSoundType

```pascal
type
  BaseSoundType = Record
    Frequency: Word;      { Sample rate in Hz (e.g., 11025, 22050) }
    DACType: Byte;        { Compression algorithm (usually EightBitDMA) }
    Phase: PhaseType;     { Mono, Stereo, or Surround }
    Buffer: Pointer;      { Pointer to raw sample data }
    BufferSize: Word;     { Size of sample in bytes (max 64KB) }
  end;
```

User-defined sound structure for playback of samples up to 64KB.

**Example:**
```pascal
var
  Sound: BaseSoundType;
begin
  Sound.Frequency := 11025;        { 11 kHz }
  Sound.DACType := EightBitDMA;    { 8-bit uncompressed }
  Sound.Phase := Mono;             { Mono playback }
  GetMem(Sound.Buffer, 32000);     { Allocate 32KB }
  Sound.BufferSize := 32000;

  { Fill buffer with sample data }

  PlaySound(Sound);

  FreeMem(Sound.Buffer, 32000);
end;
```

---

### SoundType

```pascal
type
  SoundType = Record
    Frequency: Word;        { Sample rate in Hz }
    DACType: Byte;          { Compression algorithm }
    Phase: PhaseType;       { Mono/Stereo/Surround }
    Buffer1: Pointer;       { First buffer (double-buffering) }
    Buffer2: Pointer;       { Second buffer (double-buffering) }
    Buffer1Size: Word;      { Size of buffer 1 }
    Buffer2Size: Word;      { Size of buffer 2 }
    BufferPlaying: 1..2;    { Which buffer is currently playing }
  end;
```

Internal structure for double-buffered streaming playback. Used by `PlaySoundRPD` and `PlaySoundDSK`.

**Note:** This is managed internally - users typically work with `BaseSoundType`.

---

### RPDHeader

```pascal
type
  RPDHeader = Record
    Sig: Array [0..2] of Char;   { "RPD" signature }
    Version: Word;                { File format version }
    DAC: Byte;                    { Bit depth (8/16/4/2.6, etc.) }
    Phase: PhaseType;             { Mono/Stereo/Surround }
    Freq: Word;                   { Sample frequency }
    Channels: Byte;               { Number of digital channels }
    ChannelMethod: Byte;          { Channel interleaving method }
    Size: LongInt;                { Total sample size in bytes }
    Signed: Boolean;              { 16-bit signed/unsigned flag }
    Reserved: Array [1..31] of Byte;
  end;
```

Header structure for RPD (Romesh Prakashpalan Digital) audio files. Created using VOC2RPD.EXE or WAV2RPD.EXE utilities.

**Creating RPD files:**
```bash
VOC2RPD INPUT.VOC OUTPUT.RPD
WAV2RPD INPUT.WAV OUTPUT.RPD
```

---

### PhaseType

```pascal
type
  PhaseType = Mono..Surround;
```

Audio channel configuration:
- `Mono` (0) - Single channel
- `Stereo` (1) - Two channels (left/right)
- `Surround` (2) - Surround sound effect

---

### Volume Types

```pascal
type
  MicVolumeType = 0..7;      { Microphone volume (0-7) }
  ProVolumeType = 0..15;     { SB Pro mixer volume (0-15) }
```

Volume level ranges for mixer controls.

---

### Filter/Input Types

```pascal
type
  FilterType = 0..2;         { Low/High/No filter }
  InputSourceType = 0..3;    { Mic/CD/Line-in source }
```

Recording input configuration for SB Pro mixer.

---

## Constants

### Volume Amplification

Real-time volume control constants (use with `ChangeVolumeLevel`):

```pascal
const
  SilentVol    = 10;    { 0.00x - Mute }
  QuarterVol   = 5;     { 0.25x - Very quiet }
  HalfVol      = 3;     { 0.50x - Half volume }
  NormalVol    = 0;     { 1.00x - Original volume }
  One25Vol     = 7;     { 1.25x - Slight boost }
  One5Vol      = 9;     { 1.50x - 50% louder }
  DoubleVol    = 1;     { 2.00x - Double volume }
  QuadrupleVol = 2;     { 4.00x - Quadruple (may distort!) }
```

**Warning:** Values above `DoubleVol` may cause clipping and distortion!

---

### DMA Transfer Types

```pascal
const
  EightBitDMA     = $14;    { Standard 8-bit PCM (most common) }
  HighSpeedDMA    = $91;    { High-speed mode (>22 kHz) }
  FourBitDMA      = $74;    { 4-bit ADPCM compression }
  TwoBitDMA       = $16;    { 2-bit ADPCM (low quality) }
  SixteenBitDMA   = $B6;    { 16-bit PCM (SB16 only) }
  EightBitDMAADC  = $24;    { 8-bit recording }
  HighSpeedDMAADC = $99;    { High-speed recording (>22 kHz) }
```

**Note:** Use `EightBitDMA` for normal 8-bit playback, `HighSpeedDMA` for samples above 22050 Hz.

---

### Input Sources

```pascal
const
  Mic1Input = 0;    { Microphone input #1 }
  CDInput   = 1;    { CD audio input }
  Mic2Input = 2;    { Microphone input #2 }
  LineInput = 3;    { Line-in jack }
```

---

### Filters

```pascal
const
  LowFilter  = 0;   { Low-pass filter }
  HighFilter = 1;   { High-pass filter }
  NoFilter   = 2;   { No filtering }
```

---

## Global Variables

### Playing

```pascal
var
  Playing: Boolean;
```

Global flag indicating whether sound is currently playing via DMA.

**Example:**
```pascal
PlaySound(MySound);

{ Wait for playback to finish }
while Playing do
  asm nop end;  { Allow interrupts }
```

**Note:** Don't use tight polling loops when HSC music is active - causes freezes!

---

### Recording

```pascal
var
  Recording: Boolean;
```

Global flag indicating whether recording is in progress.

**Example:**
```pascal
RecordSoundRPD('SAMPLE.RPD', 11025);

{ Record for 5 seconds }
Delay(5000);

StopRecording;
```

---

### CurrentSound

```pascal
var
  CurrentSound: SoundType;
```

Internal structure tracking currently playing sound (double-buffered).

**Note:** For advanced users only - normally managed internally.

---

## Initialization and Cleanup

### ResetDSP

```pascal
function ResetDSP(Base: Byte; IRQ, DMAChannel, HighDMA: Byte): Boolean;
```

Initializes Sound Blaster DSP chip. **MUST be called before any other functions.**

**Parameters:**
- `Base` - Base I/O port:
  - `1` = $210 (Port 210h)
  - `2` = $220 (Port 220h) ← Most common
  - `3` = $230 (Port 230h)
  - `4` = $240 (Port 240h)
- `IRQ` - Interrupt request line (typically 5 or 7)
- `DMAChannel` - DMA channel for 8-bit transfers (typically 1)
- `HighDMA` - High DMA channel for 16-bit (0 if no SB16)

**Returns:** `True` if Sound Blaster detected, `False` otherwise.

**Example:**
```pascal
begin
  { Initialize SB at port $220, IRQ 5, DMA 1 }
  if ResetDSP(2, 5, 1, 0) then
  begin
    WriteLn('Sound Blaster detected!');
    { Use sound functions }
    UninstallHandler;  { MUST call before exit }
  end
  else
    WriteLn('No Sound Blaster found');
end;
```

**CRITICAL:** Always call `UninstallHandler` before program exit!

---

### InstallHandler

```pascal
procedure InstallHandler;
```

Installs IRQ interrupt handler for DMA audio. Called automatically by `ResetDSP`.

**Note:** Normally you don't call this manually - `ResetDSP` handles it.

---

### UninstallHandler

```pascal
procedure UninstallHandler;
```

Removes IRQ interrupt handler and restores original vector.

**Example:**
```pascal
begin
  ResetDSP(2, 5, 1, 0);

  { Use Sound Blaster }

  UninstallHandler;  { MUST call before exit! }
end;
```

**CRITICAL:**
- **ALWAYS** call before program exit
- Failure causes system hang (interrupt points to freed memory)
- No exceptions - even on errors, call this!

---

## Playback Functions

### PlaySound

```pascal
procedure PlaySound(Sound: BaseSoundType);
```

Plays a sound sample up to 64KB in size via DMA.

**Parameters:**
- `Sound` - Sound structure with sample data

**Example:**
```pascal
var
  Explosion: BaseSoundType;
begin
  { Setup sound }
  Explosion.Frequency := 11025;
  Explosion.DACType := EightBitDMA;
  Explosion.Phase := Mono;
  Explosion.BufferSize := 16000;
  GetMem(Explosion.Buffer, 16000);

  { Load sample data into Explosion.Buffer }

  { Play sound }
  PlaySound(Explosion);

  { Sound plays in background via DMA }

  { Wait for completion (optional) }
  while Playing do
    asm nop end;

  FreeMem(Explosion.Buffer, 16000);
  UninstallHandler;
end;
```

**Notes:**
- Sound plays asynchronously in background
- Max size: 64KB (65535 bytes)
- Check `Playing` global to detect completion
- Buffer must remain valid during playback

---

### PlaySoundRPD

```pascal
procedure PlaySoundRPD(Filename: String);
```

Plays RPD audio file from disk using streaming double-buffered DMA.

**Parameters:**
- `Filename` - Path to .RPD file

**Example:**
```pascal
begin
  ResetDSP(2, 5, 1, 0);

  PlaySoundRPD('DATA\EXPLODE.RPD');

  { Sound streams from disk automatically }
  { No size limit - uses double buffering }

  while Playing do
    asm nop end;  { Wait for completion }

  UninstallHandler;
end;
```

**Notes:**
- No size limit - streams from disk
- Automatically reads RPD header for settings
- Uses double-buffering for smooth playback
- File remains open during playback

---

### LoadSoundRPD

```pascal
procedure LoadSoundRPD(Filename: String; var Sound: BaseSoundType;
                       MemAlloc: Boolean);
```

Loads RPD file into memory (up to 64KB) for repeated playback.

**Parameters:**
- `Filename` - Path to .RPD file
- `Sound` - Sound structure to populate
- `MemAlloc` - If `True`, allocates buffer; if `False`, uses pre-allocated buffer

**Example:**
```pascal
var
  LaserSound: BaseSoundType;
begin
  ResetDSP(2, 5, 1, 0);

  { Load into memory (auto-allocate) }
  LoadSoundRPD('LASER.RPD', LaserSound, True);

  { Play multiple times with no disk I/O }
  PlaySound(LaserSound);
  while Playing do asm nop end;

  PlaySound(LaserSound);  { Play again - instant! }
  while Playing do asm nop end;

  { Free memory }
  FreeMem(LaserSound.Buffer, LaserSound.BufferSize);
  UninstallHandler;
end;
```

**Notes:**
- Max 64KB - for larger files use `PlaySoundRPD`
- If `MemAlloc = False`, ensure buffer is pre-allocated
- Faster than streaming for short, repeated sounds

---

### PlaySoundDSK

```pascal
procedure PlaySoundDSK(Filename: String; Frequency: Word; SoundType: Byte);
```

Plays raw PCM file from disk with specified parameters.

**Parameters:**
- `Filename` - Path to raw PCM file
- `Frequency` - Sample rate (e.g., 11025, 22050)
- `SoundType` - DMA type (use `EightBitDMA`)

**Example:**
```pascal
begin
  ResetDSP(2, 5, 1, 0);

  { Play raw 8-bit PCM at 11025 Hz }
  PlaySoundDSK('SOUND.RAW', 11025, EightBitDMA);

  while Playing do
    asm nop end;

  UninstallHandler;
end;
```

**Note:** For RPD files, use `PlaySoundRPD` instead (auto-detects settings).

---

## Recording Functions

### RecordSoundRPD

```pascal
procedure RecordSoundRPD(Filename: String; Freq: Word);
```

Records audio from microphone/line-in to RPD file on disk.

**Parameters:**
- `Filename` - Output .RPD file path
- `Freq` - Sample rate (e.g., 11025, 22050)

**Example:**
```pascal
begin
  ResetDSP(2, 5, 1, 0);

  { Configure mixer for recording }
  SetInputSource(NoFilter, Mic1Input);
  SetMicVolume(7);  { Max mic volume }

  { Start recording }
  RecordSoundRPD('VOICE.RPD', 11025);
  WriteLn('Recording... Press any key to stop');

  ReadKey;

  { Stop recording }
  StopRecording;
  WriteLn('Saved to VOICE.RPD');

  UninstallHandler;
end;
```

**Notes:**
- Recording is 8-bit mono
- File grows until `StopRecording` is called
- Set mic volume before recording!

---

### StopRecording

```pascal
function StopRecording: Boolean;
```

Stops active recording and closes RPD file.

**Returns:** `True` if recording was stopped successfully.

**Example:**
```pascal
RecordSoundRPD('SAMPLE.RPD', 22050);

{ Record for 3 seconds }
Delay(3000);

if StopRecording then
  WriteLn('Recording saved')
else
  WriteLn('No recording active');
```

---

## Control Functions

### SpeakerOn

```pascal
function SpeakerOn: Byte;
```

Enables Sound Blaster speaker output.

**Returns:** DSP acknowledgment byte.

**Example:**
```pascal
ResetDSP(2, 5, 1, 0);
SpeakerOn;         { Enable speaker }
PlaySound(MySound);
```

**Note:** Usually not needed - `PlaySound` enables speaker automatically.

---

### SpeakerOff

```pascal
function SpeakerOff: Byte;
```

Disables Sound Blaster speaker output (mutes sound).

**Returns:** DSP acknowledgment byte.

**Example:**
```pascal
SpeakerOff;  { Mute - DMA continues but no audio output }
{ Do something }
SpeakerOn;   { Unmute }
```

**Note:** DMA transfers continue - only mutes output.

---

### DMAStop

```pascal
procedure DMAStop;
```

Pauses active DMA transfer. Sound can be resumed with `DMAContinue`.

**Example:**
```pascal
PlaySound(MySound);

Delay(500);
DMAStop;      { Pause }

Delay(1000);
DMAContinue;  { Resume from pause point }
```

---

### DMAContinue

```pascal
procedure DMAContinue;
```

Resumes paused DMA transfer.

**Example:**
```pascal
{ Implement pause/unpause in game }
if IsKeyPressed(Key_P) then
begin
  if Paused then
    DMAContinue
  else
    DMAStop;
  Paused := not Paused;
end;
```

---

### ChangeVolumeLevel

```pascal
procedure ChangeVolumeLevel(Amnt: Byte);
```

Changes real-time global volume amplification during playback.

**Parameters:**
- `Amnt` - Volume constant (see [Volume Amplification](#volume-amplification))

**Example:**
```pascal
PlaySound(Music);

{ Start at normal volume }
ChangeVolumeLevel(NormalVol);

{ Fade to half volume }
ChangeVolumeLevel(HalfVol);

{ Boost to double (may distort!) }
ChangeVolumeLevel(DoubleVol);
```

**Notes:**
- Changes apply in real-time during playback
- Values above `DoubleVol` may cause clipping
- Uses bit-shifting for fast performance

---

### GetVolumeLevel

```pascal
function GetVolumeLevel: Byte;
```

Returns current global volume amplification level.

**Returns:** Current volume constant.

**Example:**
```pascal
var
  CurrentVol: Byte;
begin
  CurrentVol := GetVolumeLevel;
  if CurrentVol = NormalVol then
    WriteLn('Volume is normal');
end;
```

---

### ChangeBufferSize

```pascal
function ChangeBufferSize(Size: Word): Boolean;
```

Changes internal DMA buffer size for disk streaming.

**Parameters:**
- `Size` - New buffer size in bytes (16384-65535 typical)

**Returns:** `True` if changed, `False` if sound is currently playing.

**Example:**
```pascal
{ Increase buffer for smoother playback (uses more memory) }
if ChangeBufferSize($7FFF) then  { 32KB }
  WriteLn('Buffer increased to 32KB')
else
  WriteLn('Cannot change - sound playing');
```

**Recommended sizes:**
- 16KB ($3FFF) - Low memory usage, slight stuttering possible
- 32KB ($7FFF) - Balanced (default)
- 64KB ($FFFF) - Smoothest, highest memory usage

---

### CheckBufferSize

```pascal
function CheckBufferSize: Word;
```

Returns current DMA buffer size.

**Returns:** Buffer size in bytes.

**Example:**
```pascal
var
  BufSize: Word;
begin
  BufSize := CheckBufferSize;
  WriteLn('Current buffer: ', BufSize, ' bytes');
end;
```

---

## Mixer Functions (SB Pro)

**Note:** These functions require Sound Blaster Pro or higher.

### ResetMixer

```pascal
procedure ResetMixer;
```

Resets CT-1345 mixer chip to default state.

**Example:**
```pascal
ResetDSP(2, 5, 1, 0);
ResetMixer;  { Reset mixer before use }
```

**Note:** Call before using other mixer functions.

---

### PlayMono / PlayStereo

```pascal
procedure PlayMono;
procedure PlayStereo;
```

Sets mixer to mono or stereo playback mode.

**Example:**
```pascal
PlayStereo;  { Enable stereo mode }
{ Stereo samples: odd bytes = left, even bytes = right }
```

---

### SetVocVolume

```pascal
procedure SetVocVolume(Left, Right: ProVolumeType);
```

Sets digital audio (voice) volume level.

**Parameters:**
- `Left` - Left channel volume (0-15)
- `Right` - Right channel volume (0-15)

**Example:**
```pascal
ResetMixer;
SetVocVolume(15, 15);  { Maximum voice volume }
```

---

### SetFMVolume

```pascal
procedure SetFMVolume(Left, Right: ProVolumeType);
```

Sets FM synthesis (OPL2/OPL3) volume level.

**Parameters:**
- `Left` - Left channel volume (0-15)
- `Right` - Right channel volume (0-15)

**Example:**
```pascal
SetFMVolume(10, 10);  { Moderate FM volume }
```

---

### SetCDVolume

```pascal
procedure SetCDVolume(Left, Right: ProVolumeType);
```

Sets CD audio input volume level.

**Parameters:**
- `Left` - Left channel volume (0-15)
- `Right` - Right channel volume (0-15)

**Example:**
```pascal
SetCDVolume(12, 12);  { CD audio volume }
```

---

### SetMasterVolume

```pascal
procedure SetMasterVolume(Left, Right: ProVolumeType);
```

Sets master output volume (affects all sources).

**Parameters:**
- `Left` - Left channel volume (0-15)
- `Right` - Right channel volume (0-15)

**Example:**
```pascal
SetMasterVolume(15, 15);  { Maximum master volume }
```

---

### SetMicVolume

```pascal
procedure SetMicVolume(Volume: MicVolumeType);
```

Sets microphone input volume level.

**Parameters:**
- `Volume` - Mic volume (0-7)

**Example:**
```pascal
{ Enable mic recording at max volume }
SetMicVolume(7);
RecordSoundRPD('VOICE.RPD', 11025);
```

**Note:** Set non-zero before recording!

---

### SetLineInVolume

```pascal
procedure SetLineInVolume(Left, Right: ProVolumeType);
```

Sets line-in input volume level.

**Parameters:**
- `Left` - Left channel volume (0-15)
- `Right` - Right channel volume (0-15)

**Example:**
```pascal
SetLineInVolume(12, 12);  { Line-in volume }
```

---

### SetInputSource

```pascal
procedure SetInputSource(Filter: FilterType; TheInputs: InputSourceType);
```

Selects recording input source and filter.

**Parameters:**
- `Filter` - Filter type (LowFilter, HighFilter, NoFilter)
- `TheInputs` - Input source (Mic1Input, CDInput, LineInput, etc.)

**Example:**
```pascal
{ Record from line-in with no filtering }
SetInputSource(NoFilter, LineInput);
SetLineInVolume(15, 15);
RecordSoundRPD('AUDIO.RPD', 22050);
```

---

## Low-Level Functions

### ReadDSP

```pascal
function ReadDSP: Byte;
```

Reads a byte from DSP chip.

**Returns:** Byte read from DSP.

**Note:** For advanced users - normally not needed.

---

### WriteDSP

```pascal
procedure WriteDSP(Value: Byte);
```

Writes a byte to DSP chip.

**Parameters:**
- `Value` - Byte to write

**Note:** For advanced users - can corrupt playback if misused!

---

### WriteDAC

```pascal
procedure WriteDAC(Level: Byte);
```

Writes directly to DAC (direct mode, not DMA).

**Parameters:**
- `Level` - Sample value (0-255)

**Note:** For real-time synthesis - very CPU intensive!

---

### ReadDAC

```pascal
function ReadDAC: Byte;
```

Reads directly from ADC (direct mode, not DMA).

**Returns:** Sample value (0-255).

**Note:** For real-time input - very CPU intensive!

---

### GetDSPVersion

```pascal
function GetDSPVersion: String;
```

Returns DSP chip version string.

**Returns:** Version string (e.g., "4.16" for SB16).

**Example:**
```pascal
if ResetDSP(2, 5, 1, 0) then
  WriteLn('DSP Version: ', GetDSPVersion);
```

---

## Common Usage Patterns

### Basic Sound Playback

Simple playback of RPD files:

```pascal
uses SBDSP;

begin
  { Initialize Sound Blaster }
  if not ResetDSP(2, 5, 1, 0) then
  begin
    WriteLn('No Sound Blaster detected!');
    Halt(1);
  end;

  { Play sound effect }
  PlaySoundRPD('DATA\EXPLODE.RPD');

  { Wait for completion }
  while Playing do
    asm nop end;

  { Cleanup }
  UninstallHandler;
end;
```

---

### Game Sound Effects (No Waiting)

Play sounds in background without blocking:

```pascal
uses SBDSP;

var
  SoundInitialized: Boolean;

procedure InitSound;
begin
  SoundInitialized := ResetDSP(2, 5, 1, 0);
end;

procedure PlaySFX(const Filename: String);
begin
  if SoundInitialized then
    PlaySoundRPD(Filename);
  { Don't wait - sound plays in background }
end;

begin
  InitSound;

  { Game loop }
  while GameRunning do
  begin
    if PlayerShoot then
      PlaySFX('LASER.RPD');  { Fire and forget }

    if EnemyHit then
      PlaySFX('EXPLODE.RPD');

    { Game logic continues while sound plays }
  end;

  if SoundInitialized then
    UninstallHandler;
end;
```

---

### Pre-Loading Sound Effects

Load sounds into memory for instant playback:

```pascal
uses SBDSP;

var
  LaserSound: BaseSoundType;
  ExplosionSound: BaseSoundType;

begin
  ResetDSP(2, 5, 1, 0);

  { Load all sounds at startup }
  LoadSoundRPD('LASER.RPD', LaserSound, True);
  LoadSoundRPD('EXPLODE.RPD', ExplosionSound, True);

  { Play repeatedly with NO disk I/O }
  while GameRunning do
  begin
    if FireWeapon then
      PlaySound(LaserSound);  { Instant! }

    if EnemyDead then
      PlaySound(ExplosionSound);
  end;

  { Cleanup }
  FreeMem(LaserSound.Buffer, LaserSound.BufferSize);
  FreeMem(ExplosionSound.Buffer, ExplosionSound.BufferSize);
  UninstallHandler;
end;
```

---

### Recording Audio

Capture microphone input:

```pascal
uses SBDSP, Crt;

begin
  if not ResetDSP(2, 5, 1, 0) then
    Halt(1);

  { Configure mixer }
  ResetMixer;
  SetInputSource(NoFilter, Mic1Input);
  SetMicVolume(7);  { Maximum mic volume }

  { Start recording }
  WriteLn('Recording... Press SPACE to stop');
  RecordSoundRPD('VOICE.RPD', 11025);

  { Wait for user }
  repeat until ReadKey = ' ';

  { Stop and save }
  if StopRecording then
    WriteLn('Saved to VOICE.RPD');

  UninstallHandler;
end;
```

---

### Volume Fade Effect

Fade volume in/out during playback:

```pascal
uses SBDSP;

const
  FadeSteps: array[0..5] of Byte =
    (SilentVol, QuarterVol, HalfVol, NormalVol, HalfVol, SilentVol);

var
  i: Integer;

begin
  ResetDSP(2, 5, 1, 0);

  PlaySoundRPD('MUSIC.RPD');

  { Fade in/out over 6 steps }
  for i := 0 to 5 do
  begin
    ChangeVolumeLevel(FadeSteps[i]);
    Delay(500);  { 0.5 second per step }
  end;

  while Playing do
    asm nop end;

  UninstallHandler;
end;
```

---

### Mixer Configuration

Setup ideal mixer settings for gaming:

```pascal
procedure ConfigureMixer;
begin
  ResetMixer;

  { Set master volume }
  SetMasterVolume(15, 15);  { Maximum }

  { Digital audio (sound effects) }
  SetVocVolume(15, 15);     { Loud }

  { FM music (if using PLAYHSC) }
  SetFMVolume(10, 10);      { Moderate - don't drown SFX }

  { CD audio }
  SetCDVolume(8, 8);        { Background music }

  { Disable mic monitoring }
  SetMicVolume(0);
end;

begin
  ResetDSP(2, 5, 1, 0);
  ConfigureMixer;

  { Now sounds are balanced }
end;
```

---

## Performance Notes

### Buffer Sizes

**Streaming playback** (PlaySoundRPD, PlaySoundDSK):
- **16KB ($3FFF)** - Low memory, may stutter on slow systems
- **32KB ($7FFF)** - Balanced (default)
- **64KB ($FFFF)** - Smoothest, highest memory usage

**Example:**
```pascal
ChangeBufferSize($7FFF);  { 32KB - good balance }
```

### CPU Usage

- **DMA playback** - Minimal CPU usage (~1% on 386)
- **Direct mode** (WriteDAC/ReadDAC) - Very high CPU usage
- **Real-time volume** - Negligible overhead (<1% on Pentium 60)

### Sample Rates

- **11025 Hz** - Good for speech, low quality SFX
- **22050 Hz** - Good for most sound effects
- **44100 Hz** - CD quality (use HighSpeedDMA, requires SB16)

### Memory Considerations

At 44100 Hz stereo 16-bit:
- **176,400 bytes/second**
- With 64KB buffer: 2.7 interrupts/second (low overhead)
- With 16KB buffer: 10.7 interrupts/second (higher overhead)

**Recommendation:** Use lower sample rates (11025/22050) for games to save memory and CPU.

---

## Common Pitfalls

1. **Forgetting UninstallHandler** - System hangs on exit (interrupt points to freed memory)
2. **Not calling ResetDSP** - All functions will fail
3. **Tight polling loops** - `while Playing do;` wastes CPU - add `asm nop end`
4. **Playing + HSC music** - Don't wait in tight loop if HSC is active (causes freeze)
5. **Freeing buffer during playback** - DMA reads freed memory (crackling/crash)
6. **Wrong base port** - Most cards use Base=2 ($220), not 1 ($210)
7. **No mic volume** - Set `SetMicVolume` non-zero before recording!
8. **Excessive amplification** - `QuadrupleVol` causes distortion on loud samples
9. **64KB limit** - `PlaySound` limited to 64KB - use `PlaySoundRPD` for larger files
10. **IRQ conflicts** - If IRQ 5 fails, try IRQ 7 (or check BLASTER environment variable)

---

## Compatibility Notes

**Sound Blaster versions:**
- **SB 1.0/2.0** - 8-bit mono, basic DMA
- **SB Pro** - 8-bit stereo, mixer chip
- **SB16** - 16-bit support (not fully implemented in v2.0β)
- **AWE32** - Full compatibility

**DOS versions:**
- Requires DOS 3.0 or higher
- Tested on MS-DOS 6.2, OS/2 2.1+

**Typical hardware:**
- Works on 386-40 and faster
- IRQ 5 or 7
- DMA channel 1 (8-bit) or 5 (16-bit)

---

## Creating RPD Files

Use included utilities to convert audio files:

```bash
# Convert VOC to RPD
VOC2RPD SOUND.VOC SOUND.RPD

# Convert WAV to RPD
WAV2RPD MUSIC.WAV MUSIC.RPD
```

**RPD advantages:**
- Optimized header (faster parsing)
- Streaming-friendly format
- Smaller than VOC (no Creative headers)

---

## See Also

- **VOCLOAD.PAS** - High-level VOC file loader wrapper
- **SNDBANK.PAS** - XMS-based sound effects manager
- **PLAYHSC.PAS** - HSC music player (compatible with SBDSP)
- **VENDOR/SBDSP2B/** - Original documentation and utilities

---

## Credits

**Author:** Romesh Prakashpalan (1995)
**Email:** hacscb93@huey.csun.edu

**Special thanks:**
- Ethan Brodsky - Sound Blaster Code Guru
- Mark Feldman - SB DSP programming articles
- Paul Merkus - Interface design feedback
- Chris Sullens - Bug hunting
- Anthony Williams - Re-entrancy problem solving

**License:** Freeware - Use freely in commercial/non-commercial projects. Credit appreciated!
