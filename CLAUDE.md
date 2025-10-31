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
2. Load and display TEST.PKM image file
3. Wait for Enter key, then restore text mode

## Code Architecture

### Core Units

**SB.PAS** - Sound Blaster digital audio driver
- `TSoundBlaster` object type for 8-bit PCM playback
- `Init`/`Detect`: Auto-detect Sound Blaster (ports $220-$2C0)
- `PlayVOC(filename)`: Load and play .VOC files ⚠️ **UNDER DEVELOPMENT**
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
- `TPalette`: 256-color RGB palette (0-63 range for VGA DAC)
- `InitVGA`/`CloseVGA`: Switch between text mode and Mode 13h
- `CreateFrameBuffer`/`FreeFrameBuffer`: Memory-managed pixel buffer
- `RenderFrameBuffer`: Assembly routine to blit buffer to VGA memory ($A000:0000)
- `SetPalette`: Upload 256-color palette to VGA DAC
- `LoadPalette`: Load 768-byte .PAL file
- `WaitForVSync`: Sync to vertical blanking interval (prevents tearing)
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
- PKM format: RLE-compressed paletted image format from GrafX2 drawing program (http://grafx2.chez.com/)
- `LoadPKM(filename, buffer, palette)`: Decompresses image to framebuffer
- **Current limitation**: Only loads 320x200 pixel images (under construction - will support arbitrary sizes later)
- Header structure:
  - Signature: "PKM" (3 bytes)
  - Version, pack markers (Pack_byte/Pack_word for RLE)
  - Width/Height (currently must be 320x200)
  - 768-byte palette (256 RGB triplets)
  - RLE-compressed pixel data (byte-run or word-run encoding)

**KEYBOARD.PAS** - Low-level keyboard handler using scan codes
- Hooks INT 9h (keyboard interrupt) for direct hardware access (no BIOS delays)
- `InitKeyboard`: Initialize keyboard handler - **MUST call before use**
- `DoneKeyboard`: Restore original interrupt handler - **MUST call before exit**
- `IsKeyDown(scancode)`: Returns true while key is physically held down (continuous input)
- `IsKeyPressed(scancode)`: Returns true once when key is **released** (edge detection)
- `ClearKeyPressed`: Clears all checked key press flags - call once at end of game loop
- **Scan code constants**: `Key_A` through `Key_Z`, `Key_0` through `Key_9`, `Key_F1` through `Key_F12`, arrow keys (`Key_Up`, `Key_Down`, `Key_Left`, `Key_Right`), modifiers (`Key_LShift`, `Key_RShift`, `Key_LCtrl`, `Key_LAlt`), special keys (`Key_Escape`, `Key_Enter`, `Key_Space`, `Key_Backspace`, `Key_Tab`)
- **Key detection behavior**:
  - `IsKeyPressed` triggers on key **release** (not press) to ensure no quick taps are missed
  - Uses `KeyChecked` array to track which keys were queried this frame
  - Only checked keys get cleared by `ClearKeyPressed`, preserving unchecked events
  - Can call `IsKeyPressed` multiple times per frame for same key safely
- **CRITICAL**: Always call `DoneKeyboard` before exit to unhook interrupt handler, or system will hang

**CONFIG.PAS** - Configuration management
- Handles loading and saving settings to CONFIG.INI text file (INI format)
- `TConfig` record type containing sound type and Sound Blaster settings
- `LoadConfig(var Config)`: Load configuration from INI file, sets defaults if missing (SoundCard defaults to 0)
- `SaveConfig(const Config)`: Save configuration to INI file
- **Constants**:
  - `GameTitle`, `GameVersion`: Application metadata constants
  - `SoundCard_None` (0), `SoundCard_Adlib` (1), `SoundCard_SoundBlaster` (2) for sound card enumeration
  - `ConfigFile`: Filename constant ('CONFIG.INI')
- **INI Format**: Standard INI-style text file with `[Sound]` section and key=value pairs
- Used by SETUP.PAS and can be used by games to detect sound hardware configuration

**TEXTUI.PAS** - Text mode UI library
- Direct video memory access ($B800:0000) for fast text rendering
- **Types**: `TMenu`, `TMenuItem` (menu system with linked list structure)
- **Cursor management**: `HideCursor`, `ShowCursor`
- **Text rendering**: `PutCharAt`, `RenderText`, `RenderCenterText`, `RenderEmptyLine`
- **Box rendering**: `RenderBox` (with drop shadows), `RenderBackground`
- **Menu system**:
  - `AddMenuItem`: Add item to menu with procedure pointer callback
  - `AddEmptyMenuItem`: Add disabled separator item
  - `RenderMenu`: Draw menu with highlighted selection
  - `RunMenu`: Handle keyboard navigation and execute selected item
  - `FreeMenu`: Clean up menu items
  - `ShowMessage`: Shows a message with an info line, waits for a key press, returns with the pressed scancode
- **Menu features**: Disabled items (drawn in gray, skipped during navigation), inverted color selection bar
- First menu item is always enabled (cannot be disabled)

### File Formats

**PKM Images**:
- Format from GrafX2 drawing program (http://grafx2.chez.com/)
- TEST.PKM (example image)
- Indexed color (256 colors) with embedded palette
- RLE compression using configurable pack markers
- **Current**: Only 320x200 images supported ⚠️ **UNDER CONSTRUCTION** (arbitrary dimensions planned)

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

### Testing Keyboard
```pascal
uses Keyboard;

begin
  InitKeyboard;

  while GameRunning do
  begin
    { Continuous input - movement }
    if IsKeyDown(Key_W) then
      Player.Y := Player.Y - 1;

    { Single-press input - actions }
    if IsKeyPressed(Key_Space) then
      FireWeapon;

    if IsKeyPressed(Key_Escape) then
      GameRunning := False;

    { Game logic and rendering... }

    { MUST call at end of loop }
    ClearKeyPressed;
  end;

  DoneKeyboard;  { MUST call before exit }
end;
```

### Running Setup Program
```bash
# Compile SETUP.PAS
tpc SETUP.PAS

# Run the setup program
SETUP.EXE
```

**SETUP.PAS** provides a DOS-style configuration utility:
- Uses **CONFIG.PAS** and **TEXTUI.PAS** units
- **Architecture**:
  - Menu-driven interface using TMenu/TMenuItem linked lists
  - Far procedure pointers (`{$F+}`) for menu callbacks
  - Direct video memory rendering via TEXTUI
  - Main menu with submenu navigation
- **Features**:
  - Sound card selection: None, Adlib, Sound Blaster
  - Saves settings to CONFIG.INI text file
  - Menu system with disabled items support
- **Controls**:
  - Up/Down arrow keys for navigation
  - ENTER to select menu item
  - ESC to cancel/exit
- **Usage Pattern**:
  ```pascal
  uses Config;

  var
    GameConfig: TConfig;

  begin
    { Load config at game startup }
    LoadConfig(GameConfig);

    { Initialize sound based on config }
    case GameConfig.SoundCard of
      SoundCard_Adlib: InitAdlib;
      SoundCard_SoundBlaster:
        begin
          SoundCard.Port := GameConfig.SBPort;
          SoundCard.IRQ := GameConfig.SBIRQ;
          SoundCard.DMA := GameConfig.SBDMA;
          SoundCard.Init;
        end;
    end;
  end;
  ```

**Example CONFIG.INI file**:
```ini
; DOS Game Engine Configuration

[Sound]
SoundCard=2
SBPort=544
SBIRQ=5
SBDMA=1
```
Note: SoundCard defaults to 0 (None) if CONFIG.INI doesn't exist.

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

- **VGATEST.PAS**: VGA graphics test with a PKM image load and show
- **SBTEST.PAS**: Sound Blaster detection and VOC playback test
- **KBTEST.PAS**: Keyboard handler test (demonstrates IsKeyDown vs IsKeyPressed)
- **XMSTEST.PAS**: Extended memory test ⚠️ (currently broken - far call issue)
- **SETUP.PAS**: Menu-driven setup program using TEXTUI for sound card configuration

## Common Pitfalls

1. **Music interrupts**: Failing to call `HSC_obj.Done` will leave timer interrupt hooked, causing system hang on program exit
2. **Keyboard interrupts**: Failing to call `DoneKeyboard` will leave INT 9h hooked, causing system hang on program exit
3. **Sound Blaster cleanup**: Always call `SoundCard.Done` to free DMA buffer and turn off speaker
4. **VGA mode cleanup**: Always call `CloseVGA` before exit or terminal will stay in graphics mode
5. **Memory leaks**: Match every `CreateFrameBuffer` with `FreeFrameBuffer`
6. **Keyboard loop order**: Always call `ClearKeyPressed` at the **end** of the game loop
7. **DMA boundaries**: Sound samples must not cross 64KB page boundaries (handled automatically)
8. **Image dimensions**: PKM loader enforces 320x200; other sizes will fail silently
9. **Palette**: PKM palette values are used directly (0-63 for VGA DAC)
10. **File paths**: DOS 8.3 filenames, case-insensitive, backslash paths
11. **XMS far calls**: Turbo Pascal 7.0 has quirks with far procedure pointers - XMS.PAS needs fixing
12. **Timer interrupt safety**: Keep interrupt handlers minimal - complex logic can cause crashes. Always chain to original BIOS handler.
13. **Menu callbacks**: Procedures used as menu item callbacks must be compiled with `{$F+}` (far calls) directive, otherwise they cannot be assigned to procedure pointers

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
