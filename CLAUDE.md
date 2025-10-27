# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a retro DOS multimedia engine written in Turbo Pascal (1994-era codebase), featuring VGA Mode 13h graphics (320x200 256-color) and HSC (Adlib/OPL2) music playback. The codebase represents vintage demoscene-style programming with direct hardware access, assembly code, and real-mode DOS conventions.

## Building and Running

### Compilation
This project requires **Turbo Pascal 7.0** (or compatible version) for DOS:

```bash
# Compile the main test program
tpc VGATEST.PAS

# This generates VGATEST.EXE
```

### Running
Execute on DOS (or DOSBox/FreeDOS):
```
VGATEST.EXE
```

The program will:
1. Initialize VGA Mode 13h (320x200, 256 colors)
2. Load and play FANTASY.HSC music file via Adlib
3. Load and display TEST.PKM image file
4. Wait for Enter key, then restore text mode

## Code Architecture

### Core Units

**SB.PAS** - Sound Blaster digital audio driver
- `TSoundBlaster` object type for 8-bit PCM playback
- `Init`/`Detect`: Auto-detect Sound Blaster (ports $220-$2C0)
- `PlayVOC(filename)`: Load and play .VOC files
- `PlayRaw(buffer, length, samplerate)`: Play raw 8-bit unsigned PCM
- Full DMA programming (8237 DMA controller setup)
- Supports DMA channels 0-3 (typically channel 1)
- DMA buffer management with 64KB boundary safety
- **CRITICAL**: Always call `Done` to free DMA buffer and turn off speaker

**XMS.PAS** - Extended Memory Specification (XMS) interface ⚠️ **UNDER DEVELOPMENT**
- Provides access to extended memory (above 1MB) via HIMEM.SYS
- `XMS_Init`: Detect and initialize XMS driver
- `XMS_AllocKB`: Allocate blocks in extended memory
- `XMS_Free`: Free allocated XMS blocks
- `XMS_MoveToXMS` / `XMS_MoveFromXMS`: Transfer data to/from extended memory
- **STATUS**: Currently has issues with far call mechanism to XMS driver entry point
- **TODO**: Fix XMS_Call procedure to properly invoke far pointer on Turbo Pascal 7.0
- **USE CASE**: Store large data (sprites, maps, samples) in XMS, swap on demand

**VGA.PAS** - Low-level VGA Mode 13h graphics driver
- `TFrameBuffer`: 64000-byte (320x200) pixel buffer type
- `InitVGA`/`CloseVGA`: Switch between text mode and Mode 13h
- `CreateFrameBuffer`/`FreeFrameBuffer`: Memory-managed pixel buffer
- `RenderFrameBuffer`: Assembly routine to blit buffer to VGA memory ($A000:0000)
- All rendering uses double-buffering pattern for flicker-free updates

**PLAYHSC.PAS** - HSC music player wrapper (1994, by GLAMOROUS RAY)
- `HSC_obj` object type for music playback
- Links to external `HSCOBJ.OBJ` (assembly player core)
- `Init(AdlibAddress)`: Auto-detects Adlib at port 388h (pass 0 for auto)
- `LoadFile(filename)` / `LoadMem(ptr)`: Load from disk or embedded data
- `Start` / `Stop` / `Fade`: Playback control
- Hooks into timer interrupt (IRQ0) for automatic polling
- **CRITICAL**: Always call `Done` destructor before exit to unhook interrupt

**PKMLOAD.PAS** - PKM image format loader
- PKM format: Custom RLE-compressed 320x200 paletted image format
- `LoadPKM(filename, buffer, palette)`: Decompresses image to framebuffer
- Header structure:
  - Signature: "PKM" (3 bytes)
  - Version, pack markers (Pack_byte/Pack_word for RLE)
  - Width/Height (must be 320x200)
  - 768-byte palette (256 RGB triplets)
  - RLE-compressed pixel data (byte-run or word-run encoding)

### File Formats

**PKM Images**:
- TEST.PKM, HELLO.PKM (examples)
- 320x200 indexed color with embedded palette
- RLE compression using configurable pack markers

**HSC Music**:
- FANTASY.HSC (example)
- Adlib OPL2 tracker format
- Embeddable via BINOBJ.EXE → .OBJ linking

### Memory Model
- Uses Pascal heap (`GetMem`/`FreeMem`) for dynamic allocations
- 64KB framebuffer allocation per image
- Music files loaded entirely into memory
- Real-mode DOS constraints (640KB conventional memory)

### Assembly Integration
- Inline `assembler` blocks for performance-critical code
- External .OBJ linking for HSCOBJ.OBJ (HSC player core)
- Direct hardware access (VGA BIOS INT 10h, VGA memory writes)
- BINOBJ.EXE used to embed binary data as linkable objects

## Development Workflow

### Testing Graphics
```pascal
// Modify VGATEST.PAS to experiment
InitVGA;
FrameBuffer := CreateFrameBuffer;
// Draw to FrameBuffer^ array...
RenderFrameBuffer(FrameBuffer);
ReadLn; // Wait for user
CloseVGA;
FreeFrameBuffer(FrameBuffer);
```

### Testing Music
```pascal
Music.Init(0);
if Music.LoadFile('YOURFILE.HSC') then
begin
  Music.Start;
  // Do stuff while music plays...
  Music.Done; // MUST call before exit
end;
```

### Testing Sound Effects
```pascal
uses SB;

var
  SoundCard: TSoundBlaster;

begin
  if SoundCard.Init then
  begin
    SoundCard.PlayVOC('EXPLOSION.VOC');
    // Sound plays via DMA in background
    SoundCard.WaitForPlayback; // Optional: wait for completion
    SoundCard.Done;
  end;
end;
```

### Embedding Music in EXE
```bash
# Convert HSC to linkable OBJ
BINOBJ.EXE MUSIC.HSC MUSIC.OBJ MUSIC_DATA

# In your Pascal code:
{$F+}
{$L MUSIC.OBJ}
PROCEDURE MUSIC_DATA; EXTERNAL;
{$F-}

# Then use:
Music.LoadMem(@MUSIC_DATA);
```

## Creating VOC Files (Windows 11)

### Method 1: Audacity (Recommended)
1. Download from https://www.audacityteam.org/
2. Import audio (WAV, MP3, etc.)
3. **Tracks → Mix → Mix Stereo Down to Mono**
4. **Tracks → Resample → 11025 Hz** (or 22050 Hz)
5. **File → Export → Export Audio**
   - Format: "Other uncompressed files"
   - Header: "VOC (Creative Labs)"
   - Encoding: "Unsigned 8-bit PCM"

### Method 2: FFmpeg
```bash
ffmpeg -i input.wav -ar 11025 -ac 1 -acodec pcm_u8 output.voc
```

## Test Programs

- **VGATEST.PAS**: Main graphics/music test (VGA + HSC music + PKM image)
- **SBTEST.PAS**: Sound Blaster detection and VOC playback test
- **XMSTEST.PAS**: Extended memory test ⚠️ (currently broken - far call issue)

## Common Pitfalls

1. **Music interrupts**: Failing to call `HSC_obj.Done` will leave timer interrupt hooked, causing system hang on program exit
2. **Sound Blaster cleanup**: Always call `SoundCard.Done` to free DMA buffer and turn off speaker
3. **VGA mode cleanup**: Always call `CloseVGA` before exit or terminal will stay in graphics mode
4. **Memory leaks**: Match every `CreateFrameBuffer` with `FreeFrameBuffer`
5. **DMA boundaries**: Sound samples must not cross 64KB page boundaries (handled automatically)
6. **Image dimensions**: PKM loader enforces 320x200; other sizes will fail silently
7. **Palette**: PKM palette values are used directly (0-63 for VGA DAC)
8. **File paths**: DOS 8.3 filenames, case-insensitive, backslash paths
9. **XMS far calls**: Turbo Pascal 7.0 has quirks with far procedure pointers - XMS.PAS needs fixing

## Technical Constraints

- **Platform**: DOS real mode (16-bit x86)
- **Compiler**: Turbo Pascal 7.0 (use TPC.EXE or TURBO.EXE IDE)
- **Testing environment**: DOSBox-X recommended
- **Graphics**: VGA Mode 13h only (320x200, 256 colors)
- **Audio**:
  - Adlib/OPL2 for music (HSC tracker format)
  - Sound Blaster for 8-bit digital audio (VOC files)
  - DMA channels 0-3 supported (default: channel 1)
- **Memory**:
  - Conventional: 640KB real-mode limit
  - Extended: XMS support planned (HIMEM.SYS required) - currently broken
- **Max file size**: 64KB code segments, heap limited by DOS memory
- **No multithreading**: Single-threaded with interrupt-based music/DMA audio

## Known Issues

1. **XMS.PAS far call problem**: The `XMS_Call` procedure cannot properly invoke the far pointer returned by INT 2Fh/4310h. Multiple approaches tried (inline asm `call dword ptr`, RETF trick, procedure variable casting) all fail or freeze. Needs investigation of Turbo Pascal 7.0 far call semantics.

2. **Palette brightness**: Some PKM images may appear darker than expected - verify if palette values are in 0-63 range (VGA) or 0-255 range (need conversion).
