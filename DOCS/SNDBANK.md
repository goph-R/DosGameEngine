# SNDBANK - XMS Sound Bank

XMS-based sound library for Sound Blaster (stores sounds in extended memory).

## Types

```pascal
type
  TSoundInfo = record
    Name: String[12];
    XMSHandle: Word;
    XMSOffset: LongInt;
    Size: Word;
    SampleRate: Word;
    Loaded: Boolean;
  end;

  TSoundBank = object
    Sounds: array[0..31] of TSoundInfo;
    Count: Integer;
    SoundBankInitialized: Boolean;
    { ... internal fields ... }

    function Init: Boolean;
    function LoadSound(const FileName: string): Integer;  { Returns sound ID }
    function PlaySound(SoundID: Integer): Boolean;
    procedure StopSound;
    procedure Done;
  end;
```

## Example

```pascal
uses SBDSP, SndBank, Keyboard;

const
  MaxSounds = 32;

var
  Bank: TSoundBank;
  ExplosionID, LaserID: Integer;

begin
  { Initialize Sound Blaster }
  if not ResetDSP(2, 5, 1, 0) then Halt(1);

  { Initialize sound bank }
  if not Bank.Init then
  begin
    WriteLn('XMS not available! Load HIMEM.SYS');
    Halt(1);
  end;

  { Load sounds at startup (stored in XMS) }
  ExplosionID := Bank.LoadSound('DATA\EXPLODE.VOC');
  LaserID := Bank.LoadSound('DATA\LASER.VOC');

  if ExplosionID < 0 then
    WriteLn('Failed to load explosion!');

  { Game loop }
  InitKeyboard;
  while Running do
  begin
    { Play on demand (fast XMS transfer) }
    if IsKeyPressed(Key_Space) then
      Bank.PlaySound(LaserID);

    if IsKeyPressed(Key_E) then
      Bank.PlaySound(ExplosionID);

    if IsKeyPressed(Key_Escape) then
      Running := False;

    ClearKeyPressed;
  end;

  { Cleanup }
  DoneKeyboard;
  Bank.Done;          { Free XMS memory }
  UninstallHandler;   { SBDSP cleanup }
end.
```

## Methods

### Init

```pascal
function Init: Boolean;
```

Initializes sound bank and checks for XMS driver.

**Returns:** `True` if XMS available, `False` otherwise.

### LoadSound

```pascal
function LoadSound(const FileName: string): Integer;
```

Loads VOC file into XMS extended memory.

**Returns:** Sound ID (0-31) on success, `-1` on error.

### PlaySound

```pascal
function PlaySound(SoundID: Integer): Boolean;
```

Plays sound by transferring from XMS to DMA buffer.

**Returns:** `True` on success, `False` on error.

**Behavior:**
- Stops any currently playing sound
- Allocates DMA-safe buffer (64KB boundary aligned)
- Transfers from XMS to conventional memory
- Starts Sound Blaster playback

### StopSound

```pascal
procedure StopSound;
```

Stops currently playing sound immediately.

### Done

```pascal
procedure Done;
```

Frees all XMS blocks and DMA buffers. **MUST** call before exit.

## With HSC Music

```pascal
uses SBDSP, SndBank, PlayHSC;

var
  Bank: TSoundBank;
  Music: HSC_obj;

begin
  ResetDSP(2, 5, 1, 0);

  { Start music }
  Music.Init(0);
  Music.LoadFile('THEME.HSC');
  Music.Start;

  { Sound effects work with music }
  Bank.Init;
  ExplosionID := Bank.LoadSound('EXPLODE.VOC');
  Bank.PlaySound(ExplosionID);

  { IMPORTANT: Don't wait in tight loop! }
  { while Playing do ; }  { DON'T - causes freeze }

  { Cleanup }
  Bank.Done;
  Music.Done;
  UninstallHandler;
end.
```

## Critical Notes

1. **XMS required** - Load HIMEM.SYS in CONFIG.SYS
2. **ResetDSP first** - Initialize SBDSP before Bank.Init
3. **Don't wait with HSC** - Never use `while Playing` loop when music active
4. **Call Bank.Done** - Before UninstallHandler
5. **Max 32 sounds** - Up to ~64KB each

## Memory Usage

- **Conventional memory:** ~8KB (largest sound + overhead)
- **XMS extended memory:** All sound data stored above 1MB
- **DMA-safe buffer:** Automatically handles 64KB page boundaries

## Requirements

- HIMEM.SYS loaded (provides XMS driver)
- Sound Blaster at port $220, IRQ 5, DMA 1
- VOC files (Type 1 sound data blocks)

## Notes

- Minimal conventional memory usage (sounds in XMS)
- Fast XMS transfer (~1-2ms)
- Only one sound plays at a time (single DMA channel)
- Compatible with HSC music (different interrupts)
