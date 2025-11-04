# DOS Game Engine

A retro DOS multimedia engine written in **Turbo Pascal 7.0** (1994-era), featuring VGA Mode 13h graphics, Adlib/OPL2 music, and Sound Blaster digital audio. Perfect for demoscene-style programming, retro game development, and learning classic DOS systems programming.

![DOS](https://img.shields.io/badge/DOS-16--bit-blue)
![Turbo Pascal](https://img.shields.io/badge/Turbo%20Pascal-7.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ Features

### 🎨 Graphics
- **VGA Mode 13h**: 320×200 pixels, 256 colors
- **PKM image loader**: RLE-compressed format from GrafX2
- **Double-buffering**: Flicker-free rendering with VSync support
- **Sprite system**: GetImage/PutImage with transparency [WIP]
- **Palette support**: Direct VGA DAC programming (0-63 RGB)

### 🎵 Audio
- **HSC music player**: Adlib/OPL2 tracker format with interrupt-driven playback
- **Sound Blaster support**: 8-bit PCM digital audio (11-44 kHz)
- **VOC file format**: Creative Voice File support
- **XMS sound bank**: Store multiple sounds in extended memory, load on demand
- **DMA-safe buffers**: Automatic 64KB boundary handling

### ⌨️ Input
- **Keyboard handler**: Direct INT 9h hardware access
- **Scan code support**: IsKeyDown (continuous) and IsKeyPressed (single-tap) detection
- **No BIOS delays**: Instant response for games

### 💾 Memory Management
- **XMS support**: Access extended memory (>1MB) via HIMEM.SYS
- **Smart buffering**: Sounds stored in XMS, minimal conventional memory usage
- **Heap management**: GetMem/FreeMem wrappers for safety

### 🛠️ Development Tools
- **Configuration utility**: DOS-style setup program for sound card detection
- **Text UI library**: Menu system with direct video memory rendering
- **Test programs**: Example code demonstrating all features
- **Automated builds**: Batch files handle dependency compilation

## 🚀 Quick Start

### Prerequisites
- **Turbo Pascal 7.0** (TPC.EXE)
- **DOSBox-X** or real DOS/FreeDOS
- **HIMEM.SYS** loaded (for XMS extended memory support)

### First Run
```bash
# 1. Run setup utility to configure sound card
cd SETUP
CSETUP.BAT
SETUP.EXE

# 2. Copy the saved CONFIG.INI to the TESTS folder
copy CONFIG.INI ..\TESTS

# 3. Try the sprite animation demo
cd ..\TESTS
CIMGTEST.BAT
IMGTEST.EXE
```

**Controls:**
- **ESC**: Exit demo
- **E**: Play explosion sound effect

### Building from Source

**Automated (recommended):**
```bash
cd TESTS
CVGATEST.BAT    # VGA graphics test
CSNDTEST.BAT    # Sound bank test
CIMGTEST.BAT    # Full sprite demo with music and sound
```

**Manual compilation:**
```bash
cd UNITS
tpc VGA.PAS
tpc PKMLOAD.PAS
tpc SBDSP.PAS
# ... compile other units

cd ..\TESTS
tpc -U..\UNITS VGATEST.PAS
```

## 📁 Project Structure

```
D:\ENGINE\
├── UNITS\          Core engine units
│   ├── VGA.PAS         - Mode 13h graphics driver
│   ├── PKMLOAD.PAS     - PKM image loader
│   ├── SBDSP.PAS       - Sound Blaster driver
│   ├── SNDBANK.PAS     - XMS sound bank manager
│   ├── PLAYHSC.PAS     - HSC music player
│   ├── KEYBOARD.PAS    - Keyboard interrupt handler
│   ├── RTCTIMER.PAS    - RTC high-resolution timer
│   ├── CONFIG.PAS      - INI file configuration
│   └── TEXTUI.PAS      - Text mode UI library
│
├── TESTS\          Test programs
│   ├── VGATEST.PAS     - VGA graphics demo
│   ├── SNDTEST.PAS     - Sound bank demo
│   ├── IMGTEST.PAS     - Sprite animation with audio
│   └── C*.BAT          - Compile scripts
│
├── SETUP\          Configuration utility
│   ├── SETUP.PAS       - Sound card setup program
│   ├── VOCLOAD.PAS     - VOC file loader
│   └── CSETUP.BAT      - Compile script
│
├── DATA\           Sample assets
│   ├── TEST.PKM        - Example 320×200 image
│   ├── FANTASY.HSC     - Example Adlib music
│   └── EXPLODE.VOC     - Example sound effect
│
├── DOCS\           File format documentation
│   ├── PKM.md          - PKM image format spec
│   └── HSC.md          - HSC music format spec
│
└── VENDOR\         Third-party libraries - Not used directly
    ├── SBDSP2B\        - Sound Blaster driver (1995)
    └── XMS\            - XMS memory manager (1992)
```

## 🎮 Example Code

### VGA Graphics
```pascal
uses VGA, PKMLoad;

var
  FrameBuffer: PFrameBuffer;
  Palette: TPalette;

begin
  FrameBuffer := CreateFrameBuffer;
  LoadPKM('DATA\TEST.PKM', FrameBuffer, Palette);

  InitVGA;
  SetPalette(Palette);
  RenderFrameBuffer(FrameBuffer);
  ReadLn;

  CloseVGA;
  FreeFrameBuffer(FrameBuffer);
end.
```

### Playing Music
```pascal
uses PlayHSC;

var
  Music: HSC_Obj;

begin
  Music.Init(0);  { Auto-detect Adlib at port 388h }
  if Music.LoadFile('DATA\FANTASY.HSC') then
  begin
    Music.Start;
    { ... your game loop ... }
    Music.Done;  { CRITICAL: Unhook interrupt! }
  end;
end.
```

### Sound Effects with XMS
```pascal
uses SBDSP, SndBank, XMS;

var
  Bank: TSoundBank;
  ExplosionID: Integer;

begin
  { Initialize Sound Blaster }
  ResetDSP($22, 5, 1, 0);  { Port $220, IRQ 5, DMA 1 }

  { Initialize sound bank }
  Bank.Init;

  { Load sounds into XMS at startup }
  ExplosionID := Bank.LoadSound('DATA\EXPLODE.VOC');

  { Play on demand - no disk I/O! }
  Bank.PlaySound(ExplosionID);

  { Cleanup }
  Bank.Done;
  UninstallHandler;
end.
```

### Game Loop with Delta Timing
```pascal
uses VGA, Keyboard, RTCTimer;

var
  Running: Boolean;
  LastTime, CurrentTime, DeltaTime: Real;
  PlayerX, PlayerY: Real;

begin
  InitVGA;
  InitKeyboard;
  InitRTC(1024);  { 1024 Hz timer }

  CurrentTime := RTC_Ticks / 1024.0;
  Running := True;

  while Running do
  begin
    { Calculate delta time }
    LastTime := CurrentTime;
    CurrentTime := RTC_Ticks / 1024.0;
    DeltaTime := CurrentTime - LastTime;

    { Frame-rate independent movement }
    if IsKeyDown(Key_Right) then
      PlayerX := PlayerX + 100.0 * DeltaTime;  { 100 pixels/sec }

    if IsKeyPressed(Key_Escape) then
      Running := False;

    { Render frame... }

    ClearKeyPressed;  { MUST call at end of loop }
  end;

  { CRITICAL: Clean up all interrupts }
  DoneRTC;
  DoneKeyboard;
  CloseVGA;
end.
```

## 📖 Documentation

- **[CLAUDE.md](CLAUDE.md)** - Detailed technical reference for all units
- **[DOCS/PKM.md](DOCS/PKM.md)** - PKM image format specification
- **[DOCS/HSC.md](DOCS/HSC.md)** - HSC music format specification
- **[VENDOR/SBDSP2B/SBDSP.TXT](VENDOR/SBDSP2B/SBDSP.TXT)** - Sound Blaster driver documentation

## 🎨 Creating Assets

### PKM Images
Use [GrafX2](http://grafx2.chez.com/) (DOS pixel art editor):
1. Draw in 320×200 mode with 256 colors
2. Save as PKM format (RLE-compressed)

### VOC Sound Effects
Use **Audacity** (Windows/Linux/Mac):
1. Import audio (WAV, MP3, etc.)
2. **Tracks → Mix → Mix Stereo Down to Mono**
3. **Tracks → Resample → 11025 Hz** (or 22050 Hz)
4. **File → Export → Export Audio**
   - Format: "Other uncompressed files"
   - Header: "VOC (Creative Labs)"
   - Encoding: "Unsigned 8-bit PCM"

### HSC Music
Use [HSC-tracker](https://demozoo.org/productions/293837/) or [Adlib Tracker II](https://adlibtracker.net/).

## ⚠️ Critical Cleanup Rules

Always clean up interrupt handlers before exit, or the system will crash:

```pascal
{ Correct cleanup order }
DoneRTC;          { Unhook RTC timer (IRQ8) }
DoneKeyboard;     { Unhook keyboard (INT 9h) }
Music.Done;       { Unhook music timer (IRQ0) }
UninstallHandler; { Unhook Sound Blaster (IRQ5/7) }
CloseVGA;         { Restore text mode }
```

**Failure to unhook interrupts will:**
- Cause DOSBox-X to crash
- Hang the DOS system
- Prevent running other programs

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| "XMS not installed" | Load HIMEM.SYS in CONFIG.SYS |
| "Sound Blaster not detected" | Run SETUP.EXE to configure port/IRQ/DMA |
| DOSBox-X crashes after exit | Missing `DoneRTC` or `DoneKeyboard` call |
| Sound cuts off immediately | Use RTCTimer instead of PIT Timer 0 for timing |
| Screen stays in graphics mode | Missing `CloseVGA` call |
| Crackling audio | DMA buffer crossing 64KB boundary (auto-fixed in SBDSP) |

## 📊 Technical Specs

- **Target Platform**: DOS real mode (16-bit x86)
- **Memory Model**: 640KB conventional + XMS extended
- **Graphics**: VGA Mode 13h (320×200, 256 colors, 70 Hz)
- **Audio**: Adlib OPL2 (music) + Sound Blaster DMA (samples)
- **Interrupts Used**: INT 9h (keyboard), IRQ0 (music), IRQ8 (timer), IRQ5/7 (audio)
- **Max Segment Size**: 64KB (real mode constraint)

## 🤝 Contributing

Contributions welcome! This engine aims to preserve 1990s DOS demoscene programming techniques while remaining hackable and educational.

## 📜 License

MIT License - See [LICENSE](LICENSE) file

## 🙏 Credits

- **SBDSP**: Romesh Prakashpalan (1995)
- **XMS Driver**: KIV without Co (1992)
- **HSC Player**: GLAMOROUS RAY (1994)
- **RTCTimer**: by ChatGPT (2025)
- **Test Assets**: Sample PKM/HSC/VOC files included

## 🔗 Links

- [DOSBox-X](https://dosbox-x.com/) - Recommended DOS emulator
- [GrafX2](http://grafx2.chez.com/) - DOS pixel art editor
- [Turbo Pascal 7.0](https://en.wikipedia.org/wiki/Turbo_Pascal) - Classic Pascal compiler
- [Audacity](https://www.audacityteam.org/) - Audio editor for VOC creation

---

**Made with 💾 for retro DOS enthusiasts**
