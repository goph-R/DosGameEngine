# IMF Music Format

**IMF** (Id Music Format) is a simple OPL2 music format created by Id Software in 1991 for Commander Keen 4-6. It was later used in Wolfenstein 3D, Blake Stone, and other DOS classics.

## Overview

- **Format**: Direct OPL2 register writes with timing delays
- **Era**: 1991-1995 (id Software golden age)
- **Games**: Commander Keen 4-6, Wolfenstein 3D, Blake Stone, Bio Menace
- **Complexity**: Dead simple (delay + register + data)
- **Playback**: Polling-based (no interrupt conflicts)

## Specifications

### File Structure

**Type 0 IMF** (No header):
```
[delay word][register byte][data byte]
[delay word][register byte][data byte]
...
[0x0000][register][data]  ← End marker
```

**Type 1 IMF** (With header):
```
[length word]              ← Data size (little-endian)
[delay word][register byte][data byte]
[delay word][register byte][data byte]
...
[0x0000][register][data]  ← End marker
```

### Data Format

Each chunk is 4 bytes:
- **Delay** (Word, little-endian): Ticks to wait before next chunk
- **Register** (Byte): OPL2 register address (0x00-0xFF)
- **Data** (Byte): Value to write to register

### Playback Rates

Different games use different tick rates:

| Game | Rate (Hz) | Usage |
|------|-----------|-------|
| Commander Keen 4-6 | 560 | Standard Keen rate |
| Wolfenstein 3D | 700 | Most common rate |
| Blake Stone 1 & 2 | 700 | Wolf3D engine |
| Bio Menace | 560 | Keen rate |
| Halloween Harry | 560 | Keen rate |

**Important**: Playing at the wrong rate = wrong tempo!

### End Markers

- **Delay = 0**: Can mean end of song OR loop point
- **EOF**: Actual end of file
- **Looping**: Restart from beginning when delay = 0

### OPL2 Hardware

- **Port 0x388**: Address/Status port (write register address)
- **Port 0x389**: Data port (write data value)
- **Wait timing**: ~3.3µs after address, ~23µs after data

## Using PLAYIMF.PAS

### Interface

```pascal
uses PlayIMF;

type
  IMF_Obj = object
    Playing: Boolean;
    Looping: Boolean;

    constructor Init(PlaybackRate: Word);
    function LoadFile(const FileName: string): Boolean;
    procedure LoadMem(MusicAddress: Pointer; MusicSize: LongInt);
    procedure Start;
    procedure Stop;
    procedure Poll;  { MUST be called every frame! }
    destructor Done;
  end;

function GetLastIMFError: string;
```

### Basic Example

```pascal
uses PlayIMF, Crt;

var
  Music: IMF_Obj;

begin
  { Initialize with Wolfenstein 3D rate (700 Hz) }
  Music.Init(700);

  { Load IMF file }
  if Music.LoadFile('MUSIC.IMF') then
  begin
    Music.Start;

    { Main loop }
    while Music.Playing do
    begin
      Music.Poll;  { CRITICAL: Call every frame! }

      { Your game logic here }

      Delay(10);
    end;

    Music.Done;
  end;
end.
```

### With Looping

```pascal
Music.Init(700);
Music.Looping := True;  { Enable looping }

if Music.LoadFile('MUSIC.IMF') then
begin
  Music.Start;

  while not KeyPressed do
  begin
    Music.Poll;  { Music loops forever }
    Delay(10);
  end;

  Music.Done;
end;
```

### Load from Memory

```pascal
{$L MUSIC.OBJ}  { Embed IMF file via BINOBJ.EXE }

var
  MusicData: array[0..9999] of Byte; external;

begin
  Music.Init(700);
  Music.LoadMem(@MusicData, SizeOf(MusicData));
  Music.Start;

  { ... game loop with Music.Poll ... }
end;
```

### Commander Keen Rate

```pascal
{ Use 560 Hz for Commander Keen music }
Music.Init(560);
Music.LoadFile('KEEN.IMF');
Music.Start;
```

### Controls Example

```pascal
uses PlayIMF, Keyboard;

begin
  InitKeyboard;
  Music.Init(700);
  Music.LoadFile('MUSIC.IMF');
  Music.Start;

  while not IsKeyPressed(Key_Escape) do
  begin
    Music.Poll;

    { Pause/Resume }
    if IsKeyPressed(Key_Space) then
    begin
      if Music.Playing then
        Music.Stop
      else
        Music.Start;
    end;

    { Toggle looping }
    if IsKeyPressed(Key_L) then
      Music.Looping := not Music.Looping;

    { Restart }
    if IsKeyPressed(Key_R) then
      Music.Start;

    ClearKeyPressed;
    Delay(10);
  end;

  Music.Done;
  DoneKeyboard;
end;
```

## Creating IMF Files

### Method 1: Convert from MIDI (Easiest)

1. **Download IMFCreator**: https://github.com/adambiser/imf-creator
2. **Open your MIDI file** in IMFCreator
3. **Set playback rate**: 560 (Keen) or 700 (Wolf3D)
4. **Export as IMF** (Type 1 recommended)

### Method 2: Compose in Tracker

1. **Download Adlib Tracker II**: https://adlibtracker.net/
2. **Compose using OPL2 instruments**
3. **Export → IMF format**
4. **Set playback rate** during export

### Method 3: Extract from Games

See **[DOCS/MISC/IMFSRC.md](MISC/IMFSRC.md)** for complete guide on extracting IMF files from classic games.

## Testing

```bash
cd TESTS
CIMFTEST.BAT
IMFTEST.EXE ..\DATA\MUSIC.IMF 700
```

**Test program controls:**
- **SPACE**: Pause/Resume
- **L**: Toggle looping
- **R**: Restart music
- **ESC**: Exit

## Comparison: IMF vs HSC

| Feature | IMF | HSC |
|---------|-----|-----|
| **Complexity** | Dead simple (~300 lines) | Complex black-box player |
| **Format** | Direct OPL2 register dumps | Compressed tracker format |
| **Playback** | Polling-based (safe) | Interrupt-based (IRQ0 hook) |
| **Conflicts** | None (no IRQ usage) | IRQ0 conflict warnings |
| **Games** | Wolfenstein 3D, Keen | Demoscene productions |
| **Educational** | ✅ See exactly how OPL2 works | ❌ Black-box .OBJ |
| **File Size** | Larger (uncompressed) | Smaller (compressed) |
| **Tools** | Many (IMFCreator, etc.) | Fewer (HSC Tracker) |

**Recommendation**: Use **IMF** for transparency and simplicity, **HSC** for demoscene aesthetics and compression.

## Technical Notes

### Polling vs Interrupts

PLAYIMF.PAS uses **polling** instead of interrupts:
- **Safe**: No IRQ conflicts with HSC, RTC Timer, or Sound Blaster
- **Simple**: No interrupt vector management
- **Flexible**: Works in any context
- **Requires**: Must call `Music.Poll` every frame

### Timing Implementation

Uses BIOS timer (18.2 Hz) with accumulator:
```pascal
TicksPerUpdate = (18.2 * 65536) / PlaybackRate
TickAccumulator += DeltaTicks * 65536
while TickAccumulator >= TicksPerUpdate do
  ProcessNextChunk
  TickAccumulator -= TicksPerUpdate
```

### OPL2 Register Writes

Direct port I/O with proper wait timing:
1. Write register to port 0x388
2. Wait ~3.3µs (6 status reads)
3. Write data to port 0x389
4. Wait ~23µs (35 status reads)

### Memory Usage

- **Type 0**: Entire file loaded (no header)
- **Type 1**: Data only (skip 2-byte header)
- **LoadFile**: Allocates heap memory, auto-freed
- **LoadMem**: External pointer, NOT freed

### Compatibility

- **No conflicts**: Polling-based, no interrupt usage
- **Works with HSC**: Can switch between players
- **Works with SBDSP**: Sound effects continue during music
- **Works with RTC Timer**: Uses BIOS timer instead

## File Size Limits

- **Max chunks**: 8191 (32KB array limit, Turbo Pascal constraint)
- **Max file size**: ~32KB of music data (~4-8 minutes at 700 Hz)
- **Typical sizes**:
  - Simple tune: 5-10 KB (1-2 minutes)
  - Complex song: 10-20 KB (2-4 minutes)
  - Very long: 20-32 KB (4-8 minutes)

**Note**: Most IMF files from classic games are 5-20KB, well within limits.

## Where to Get IMF Files

See **[DOCS/MISC/IMFSRC.md](MISC/IMFSRC.md)** for comprehensive list of sources:

- **VGMPF Wiki**: Pre-extracted IMF packs from classic games
- **Shikadi.net**: Keen modding community resources
- **Archive.org**: Shareware games (legal to extract)
- **IMFCreator**: Convert your own MIDI files

**Quick start**: Download Wolfenstein 3D music pack from VGMPF.com

## Example IMF Files

**From Wolfenstein 3D** (700 Hz):
- `NAZI_NOR.IMF` - Nazi March (iconic!)
- `WARMARCH.IMF` - War March
- `GETTHEM.IMF` - Get Them!
- `WONDERIN.IMF` - Wondering About My Loved Ones

**From Commander Keen 4** (560 Hz):
- `KEEN4E.IMF` - Episode 4 ending theme
- `KEEN4T.IMF` - Episode 4 title theme

## Embedding in EXE

Like HSC, you can embed IMF files:

```bash
# Create .OBJ file from IMF
BINOBJ MUSIC.IMF music_obj music_len

# Link in your program
{$L MUSIC.OBJ}
var
  music_obj: array[0..9999] of Byte; external;
  music_len: Word; external;

Music.LoadMem(@music_obj, music_len);
```

## References

- **IMF Format Spec**: https://moddingwiki.shikadi.net/wiki/IMF_Format
- **VGMPF Wiki**: https://www.vgmpf.com/Wiki/index.php?title=IMF
- **IMFCreator**: https://github.com/adambiser/imf-creator
- **Adlib Tracker II**: https://adlibtracker.net/
- **K1n9_Duk3's IMF Tools**: https://k1n9duk3.shikadi.net/imftools.html

## See Also

- **[MISC/IMFSRC.md](MISC/IMFSRC.md)** - Where to download IMF files
- **[HSC.md](HSC.md)** - Alternative music format
- **[UNITS_REFERENCE.md](UNITS_REFERENCE.md)** - Complete units documentation
