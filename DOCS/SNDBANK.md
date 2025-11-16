# SNDBANK.PAS - API Documentation

XMS-based sound library manager for Sound Blaster digital audio playback.

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [TSoundBank Object](#tsoundbank-object)
- [Methods](#methods)
- [Common Usage Patterns](#common-usage-patterns)
- [Important Notes](#important-notes)
- [Memory Management](#memory-management)

---

## Overview

SNDBANK.PAS provides a sound library manager that stores multiple VOC (Creative Voice File) sounds in XMS extended memory and plays them on demand via Sound Blaster. This approach minimizes conventional memory usage while allowing quick access to multiple sound effects.

**Key features:**
- **XMS storage** - Sounds stored in extended memory (above 1MB)
- **DMA-safe buffers** - Automatic 64KB page boundary handling for DMA
- **VOC format support** - Loads Creative Voice Files (.VOC)
- **On-demand playback** - Transfers from XMS to conventional memory only when playing
- **Up to 32 sounds** - MaxSounds constant (configurable)

**Dependencies:**
- **XMS.PAS** - Extended memory manager (requires HIMEM.SYS)
- **SBDSP.PAS** - Sound Blaster DSP driver
- **GenTypes.PAS** - Generic type definitions

---

## Requirements

### System Requirements
- **XMS driver** - HIMEM.SYS must be loaded (default in DOSBox)
- **Sound Blaster** - Compatible sound card at configured port
- **Extended memory** - Enough XMS for sound samples

### Initialization Order
```pascal
{ 1. Initialize Sound Blaster first }
if not ResetDSP(2, 5, 1, 0) then Halt(1);

{ 2. Initialize sound bank }
if not Bank.Init then Halt(1);

{ 3. Load sounds }
ExplosionID := Bank.LoadSound('EXPLODE.VOC');

{ 4. Play on demand }
Bank.PlaySound(ExplosionID);

{ 5. Cleanup on exit }
Bank.Done;
UninstallHandler;  { SBDSP cleanup }
```

---

## TSoundBank Object

### Type Definition

```pascal
type
  TSoundBank = object
    Sounds: array[0..MaxSounds-1] of TSoundInfo;
    Count: Integer;
    PlayBufferRaw: Pointer;
    PlayBuffer: Pointer;
    PlayBufferAllocSize: Word;
    PlayBufferSize: Word;
    XMSAvailable: Boolean;

    function Init: Boolean;
    function LoadSound(const FileName: string): Integer;
    function PlaySound(SoundID: Integer): Boolean;
    procedure StopSound;
    procedure Done;
  end;
```

### TSoundInfo Structure

```pascal
type
  TSoundInfo = record
    Name: String[12];       { Sound name (e.g., 'EXPLODE.VOC') }
    XMSHandle: Word;        { XMS block handle }
    XMSOffset: LongInt;     { Offset within XMS block }
    Size: Word;             { Size in bytes (includes 6-byte VOC header) }
    SampleRate: Word;       { Sample rate in Hz (e.g., 11111) }
    Loaded: Boolean;        { True if successfully loaded into XMS }
  end;
```

---

## Methods

### Init

```pascal
function Init: Boolean;
```

Initializes the sound bank and verifies XMS availability.

**Returns:** `True` if XMS is available and initialization succeeded, `False` otherwise.

**Example:**
```pascal
var
  Bank: TSoundBank;

begin
  if not Bank.Init then
  begin
    WriteLn('Error: XMS not available!');
    Halt(1);
  end;

  { Load sounds... }
end;
```

**Important:**
- **MUST** be called before any other sound bank operations
- Checks for XMS driver (HIMEM.SYS)
- Prints warning if XMS is not available

---

### LoadSound

```pascal
function LoadSound(const FileName: string): Integer;
```

Loads a VOC file into XMS extended memory.

**Parameters:**
- `FileName` - Path to VOC file (e.g., 'DATA\EXPLODE.VOC')

**Returns:** Sound ID (0-31) on success, `-1` on error.

**Example:**
```pascal
var
  Bank: TSoundBank;
  ExplosionID, LaserID: Integer;

begin
  Bank.Init;

  { Load multiple sounds }
  ExplosionID := Bank.LoadSound('DATA\EXPLODE.VOC');
  LaserID := Bank.LoadSound('DATA\LASER.VOC');

  if ExplosionID < 0 then
    WriteLn('Failed to load explosion sound!');
end;
```

**File Format:**
- Supports VOC files with Type 1 sound data blocks
- Extracts sample rate from VOC header
- Stores 6-byte VOC header + PCM data in XMS

**Error Conditions:**
- Returns `-1` if:
  - Bank is full (32 sounds loaded)
  - File not found or can't be opened
  - Invalid VOC format
  - XMS allocation failed
  - File read error

---

### PlaySound

```pascal
function PlaySound(SoundID: Integer): Boolean;
```

Plays a previously loaded sound by transferring it from XMS to conventional memory and starting DMA playback.

**Parameters:**
- `SoundID` - Sound ID returned by `LoadSound` (0-31)

**Returns:** `True` if playback started successfully, `False` on error.

**Example:**
```pascal
var
  Bank: TSoundBank;
  ExplosionID: Integer;

begin
  { Load sound at startup }
  ExplosionID := Bank.LoadSound('DATA\EXPLODE.VOC');

  { Play multiple times - no disk I/O! }
  Bank.PlaySound(ExplosionID);  { Fast - already in XMS }
  Delay(1000);
  Bank.PlaySound(ExplosionID);  { Play again }
end;
```

**Behavior:**
- Stops any currently playing sound automatically
- Allocates DMA-safe playback buffer (64KB page boundary aligned)
- Transfers sound from XMS to conventional memory
- Starts Sound Blaster DMA playback
- Reuses playback buffer if size matches

**DMA-Safe Buffer:**
- Automatically allocates buffer that doesn't cross 64KB page boundaries
- Required for proper DMA operation on 8086/286 CPUs
- Buffer is even-aligned for optimal performance

**Error Conditions:**
- Returns `False` if:
  - Invalid SoundID (out of range)
  - Sound not loaded
  - DMA buffer allocation failed
  - XMS transfer failed

---

### StopSound

```pascal
procedure StopSound;
```

Stops currently playing sound immediately.

**Example:**
```pascal
{ Play sound }
Bank.PlaySound(ExplosionID);

{ User presses key - stop immediately }
if IsKeyPressed(Key_Escape) then
  Bank.StopSound;
```

**Behavior:**
- Stops DMA transfer
- Turns off Sound Blaster speaker
- Waits 50ms for DMA to fully stop
- Safe to call even if nothing is playing

---

### Done

```pascal
procedure Done;
```

Cleanup - frees all XMS blocks and playback buffers. **MUST** be called before program exit.

**Example:**
```pascal
var
  Bank: TSoundBank;

begin
  Bank.Init;
  { Load and play sounds... }

  { Cleanup on exit }
  Bank.Done;          { Free XMS and buffers }
  UninstallHandler;   { SBDSP cleanup }
end;
```

**Behavior:**
- Stops any playing sound
- Frees all XMS blocks (all loaded sounds)
- Frees DMA playback buffer
- Resets sound count to 0

**CRITICAL:**
- **ALWAYS** call before program exit
- Call **BEFORE** `UninstallHandler` (SBDSP cleanup)
- Failure to call causes XMS memory leak

---

## Common Usage Patterns

### Basic Game Sound Effects

```pascal
uses SBDSP, SndBank, Keyboard;

var
  Bank: TSoundBank;
  ExplosionID, LaserID, JumpID: Integer;
  GameRunning: Boolean;

begin
  { Initialize Sound Blaster }
  if not ResetDSP(2, 5, 1, 0) then
  begin
    WriteLn('Sound Blaster not found!');
    Halt(1);
  end;

  { Initialize sound bank }
  if not Bank.Init then
  begin
    WriteLn('XMS not available!');
    Halt(1);
  end;

  { Load all sounds at startup }
  ExplosionID := Bank.LoadSound('DATA\EXPLODE.VOC');
  LaserID := Bank.LoadSound('DATA\LASER.VOC');
  JumpID := Bank.LoadSound('DATA\JUMP.VOC');

  { Game loop }
  InitKeyboard;
  GameRunning := True;

  while GameRunning do
  begin
    { Fire weapon }
    if IsKeyPressed(Key_Space) then
      Bank.PlaySound(LaserID);

    { Jump }
    if IsKeyPressed(Key_W) then
      Bank.PlaySound(JumpID);

    { Explosion }
    if IsKeyPressed(Key_E) then
      Bank.PlaySound(ExplosionID);

    { Exit }
    if IsKeyPressed(Key_Escape) then
      GameRunning := False;

    ClearKeyPressed;
  end;

  { Cleanup }
  DoneKeyboard;
  Bank.Done;
  UninstallHandler;
end.
```

---

### Loading Sounds with Error Checking

```pascal
var
  Bank: TSoundBank;
  SoundID: Integer;
  SoundFiles: array[0..4] of string = (
    'EXPLODE.VOC',
    'LASER.VOC',
    'JUMP.VOC',
    'COIN.VOC',
    'HURT.VOC'
  );
  i: Integer;

begin
  Bank.Init;

  { Load all sounds with error checking }
  for i := 0 to 4 do
  begin
    SoundID := Bank.LoadSound('DATA\' + SoundFiles[i]);
    if SoundID < 0 then
      WriteLn('Warning: Failed to load ', SoundFiles[i])
    else
      WriteLn('Loaded ', SoundFiles[i], ' as ID ', SoundID);
  end;
end;
```

---

### Playing Sounds with Music (HSC)

```pascal
uses SBDSP, SndBank, PlayHSC;

var
  Bank: TSoundBank;
  Music: HSC_obj;
  ExplosionID: Integer;

begin
  { Initialize Sound Blaster }
  ResetDSP(2, 5, 1, 0);

  { Initialize music }
  Music.Init(0);
  Music.LoadFile('FANTASY.HSC');
  Music.Start;

  { Initialize sound bank }
  Bank.Init;
  ExplosionID := Bank.LoadSound('EXPLODE.VOC');

  { Play sound - works fine with music! }
  Bank.PlaySound(ExplosionID);

  { IMPORTANT: Don't wait for sound in tight loop! }
  { while Playing do ; }  { DON'T DO THIS - causes freeze with HSC! }

  { Instead, let sound play in background }
  { Do game logic... }

  { Cleanup }
  Bank.Done;
  Music.Done;
  UninstallHandler;
end.
```

**CRITICAL:**
- Sound Blaster playback is **compatible** with HSC music (different interrupts)
- **NEVER** wait in tight `while Playing` loop when music is active
- Let sounds play in background during normal game loop

---

## Important Notes

### CRITICAL Rules

1. **Initialize SBDSP first** - Call `ResetDSP` before `Bank.Init`
2. **ALWAYS call `Bank.Done`** before program exit
3. **Don't wait for `Playing`** in tight loop when HSC music is active
4. **XMS required** - HIMEM.SYS must be loaded
5. **Cleanup order** - Call `Bank.Done` BEFORE `UninstallHandler`

### Sound Interruption

- `PlaySound` automatically stops any currently playing sound
- Only one sound can play at a time (single DMA channel)
- New sound starts immediately when previous stops

### File Limits

- **Maximum sounds**: 32 (MaxSounds constant)
- **Maximum size per sound**: ~64KB (Word limit)
- **Total XMS**: Limited by available extended memory

### VOC Format Support

- **Supported**: VOC Type 1 blocks (8-bit PCM data)
- **Not supported**:
  - Type 2+ blocks (compressed, ADPCM, stereo)
  - Multiple sound blocks per file
  - Loop/repeat markers

---

## Memory Management

### Conventional Memory Usage

**Minimal footprint:**
- Object structure: ~200 bytes
- DMA playback buffer: Size of largest sound (allocated on demand)
- No sound data in conventional memory when not playing

**Example:**
```
Largest sound: 8KB explosion
Conventional memory used: ~8.2KB total
All other sounds: Stored in XMS (above 1MB)
```

### XMS Extended Memory Usage

**Per sound:**
- Sound data size + 6-byte VOC header
- Rounded up to nearest 1KB for XMS allocation

**Example:**
```
5 sounds × 8KB average = 40KB XMS
vs.
40KB conventional memory if loaded normally
```

### DMA-Safe Buffer Allocation

The sound bank uses a sophisticated DMA-safe buffer allocation algorithm:

1. **Over-allocates** conventional memory (Size + 4KB)
2. **Searches** for a sub-region that doesn't cross 64KB page boundary
3. **Validates** even physical address alignment
4. **Reuses** buffer if size matches previous allocation

**Why this matters:**
- DMA on 8086/286 cannot cross 64KB physical page boundaries
- Incorrect alignment causes crackling, cutoff, or no sound
- Automatic handling - no user intervention needed

---

## Performance Notes

- **Loading**: Disk I/O only once per sound (at startup)
- **Playing**: Fast XMS transfer + DMA start (~1-2ms)
- **No disk seeks**: Perfect for action games with frequent sound effects
- **Background playback**: DMA-driven, no CPU polling required

---

## Compatibility

- **DOS only** - Requires real-mode DOS or DOSBox
- **Turbo Pascal 7.0** - Uses object-oriented programming
- **XMS 2.0+** - Standard XMS interface (HIMEM.SYS)
- **Sound Blaster** - Compatible cards with DMA support

---

## Troubleshooting

### "XMS not available" warning
- **Solution**: Load HIMEM.SYS in CONFIG.SYS or AUTOEXEC.BAT
- **DOSBox**: XMS is enabled by default

### Sound doesn't play
- **Check**: Did you call `ResetDSP` first?
- **Check**: Is Sound Blaster port/IRQ/DMA correct in CONFIG.INI?
- **Check**: Did `LoadSound` return valid ID (>= 0)?

### Sound cuts off or crackles
- **Fixed**: DMA-safe buffer allocation handles this automatically
- **If persists**: Check for interrupt conflicts (IRQ5/7)

### "Could not find DMA-safe buffer" error
- **Rare**: Conventional memory too fragmented
- **Solution**: Restart program or DOSBox

---

## See Also

- **[SBDSP.md](SBDSP.md)** - Sound Blaster DSP driver documentation
- **[XMS.PAS](../UNITS/XMS.PAS)** - Extended memory manager
- **[SNDTEST.PAS](../TESTS/SNDTEST.PAS)** - Interactive test program
- **[IMGTEST.PAS](../TESTS/IMGTEST.PAS)** - Sound effects + music example
