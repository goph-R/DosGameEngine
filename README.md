# DOS Game Engine

A retro DOS multimedia engine written in **Turbo Pascal 7.0** (1994-era), featuring VGA Mode 13h graphics, Adlib/OPL2 music, and Sound Blaster digital audio. Perfect for demoscene-style programming, retro game development, and learning classic DOS systems programming.

![DOS](https://img.shields.io/badge/DOS-16--bit-blue)
![Turbo Pascal](https://img.shields.io/badge/Turbo%20Pascal-7.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## 📸 Screenshots

<div align="center">
  <table>
    <tr>
      <td align="center">
        <a href="DOCS/SCREENS/TMXTEST.png">
          <img src="DOCS/SCREENS/TMXTEST-thumb.png" alt="TMX Tilemap Test">
        </a>
        <br>
        <strong>Tilemap Rendering</strong>
      </td>
      <td align="center">
        <a href="DOCS/SCREENS/FNTTEST.png">
          <img src="DOCS/SCREENS/FNTTEST-thumb.png" alt="Variable-Width Font Test">
        </a>
        <br>
        <strong>Variable-Width Fonts</strong>
      </td>
    </tr>
    <tr>
      <td align="center">
        <a href="DOCS/SCREENS/SPRTEST.png">
          <img src="DOCS/SCREENS/SPRTEST-thumb.png" alt="Sprite Animation Test">
        </a>
        <br>
        <strong>Sprite Animation</strong>
      </td>
      <td align="center">
        <a href="DOCS/SCREENS/SETUP.png">
          <img src="DOCS/SCREENS/SETUP-thumb.png" alt="Setup Utility">
        </a>
        <br>
        <strong>Setup Utility</strong>
      </td>
    </tr>
  </table>
</div>

## 🚀 Quick Start

### Prerequisites
- [Turbo Pascal 7.0](https://winworldpc.com/product/turbo-pascal/7x) (TPC.EXE)
- [DOSBox-X](https://dosbox-x.com/), [86Box](https://86box.net/) or real DOS/FreeDOS
- HIMEM.SYS loaded (for XMS extended memory support, default in DOSBox)

### First Run
```bash
# 1. Compile & run setup utility to configure sound card
cd SETUP
CSETUP.BAT
SETUP.EXE

# 2. Copy the saved CONFIG.INI to the TESTS folder
copy CONFIG.INI ..\TESTS

# 3. Compile & try the advanced VGA demo with music and sound
cd ..\TESTS
CIMGTEST.BAT
IMGTEST.EXE
```

**Controls:**
- **E**: Play an explosion
- **ESC**: Exit demo

## 📖 Documentation

### Core Documentation
- **[CLAUDE.md](CLAUDE.md)** - Detailed technical reference for all units
- **[README.md](README.md)** - This file, project overview and quick start
- **[DOCS/BUILD.md](DOCS/BUILD.md)** - Building and compilation guide
- **[DOCS/ISSUES.md](DOCS/ISSUES.md)** - Critical cleanup rules, common issues
- **[DOCS/UNITS_REFERENCE.md](DOCS/UNITS_REFERENCE.md)** - Complete units reference

### Format Specifications
- **[DOCS/PKM.md](DOCS/PKM.md)** - PKM image format specification
- **[DOCS/HSC.md](DOCS/HSC.md)** - HSC music format specification
- **[DOCS/TILEMAP.md](DOCS/TILEMAP.md)** - TMX tilemap format guide and loader API

### API References
- **[DOCS/KEYBOARD.md](DOCS/KEYBOARD.md)** - Keyboard handler API and scan codes
- **[DOCS/MINIXML.md](DOCS/MINIXML.md)** - XML parser API reference and examples
- **[DOCS/MOUSE.md](DOCS/MOUSE.md)** - Mouse input API and button handling
- **[DOCS/SBDSP.md](DOCS/SBDSP.md)** - Sound Blaster DSP API reference
- **[DOCS/SNDBANK.md](DOCS/SNDBANK.md)** - XMS sound bank manager API
- **[DOCS/SPRITE.md](DOCS/SPRITE.md)** - Sprite animation system API
- **[DOCS/VGA.md](DOCS/VGA.md)** - VGA graphics API reference
- **[DOCS/VGAFONT.md](DOCS/VGAFONT.md)** - Variable-width font system API

## ✨ Features

### 🎨 Graphics
- **VGA Mode 13h**: 320×200 pixels, 256 colors
- **PKM image loader**: RLE-compressed format from GrafX2
- **Double-buffering**: Flicker-free rendering with VSync support
- **Sprite rendering**: GetImage/PutImage with transparency and horizontal/vertical flipping
- **Sprite animation**: Delta-time based system with 3 play modes (Forward, PingPong, Once)
- **Tilemap support**: TMX tilemap loader and renderer for Tiled Map Editor files
- **Collision layers**: BlocksLayer support for tile-based collision detection (separate from visual layers)
- **Text rendering**: Embedded 8x8 bitmap font (VGAPRINT) for debug texts
- **Variable-width fonts**: Proportional fonts with XML metadata and PKM sprite sheets
- **Palette support**: Direct VGA DAC programming (0-63 RGB), 768 Byte PAL loader

### 🎵 Audio
- **HSC music player**: Adlib/OPL2 tracker format with interrupt-driven playback
- **Sound Blaster support**: 8-bit PCM digital audio (11-44 kHz)
- **VOC file format**: Creative Voice File support
- **XMS sound bank**: Store multiple sounds in extended memory, load on demand
- **DMA-safe buffers**: Automatic 64KB boundary handling

### 🎮 Input
- **Keyboard handler**: Direct INT 9h hardware access with scan code support
- **Keyboard detection**: IsKeyDown (continuous) and IsKeyPressed (single-tap)
- **Mouse support**: DOS mouse driver (INT 33h) with position and button tracking
- **Mouse features**: Automatic coordinate scaling for Mode 13h, 3-button support
- **No BIOS delays**: Instant response for games

### 💾 Memory Management
- **XMS support**: Access extended memory (>1MB) via HIMEM.SYS
- **Smart buffering**: Sounds stored in XMS, minimal conventional memory usage
- **Heap management**: GetMem/FreeMem wrappers for safety

### 📝 Data & Configuration
- **INI parser**: Simple INI loader and writer for the setup program
- **XML parser**: DOM-style XML loader for the game resources and TMX files
- **Hash map**: Fast O(1) attribute lookup for XML elements
- **64KB file support**: Handles files up to ~64KB (TP7 heap limit)
- **Numeric array parser**: Parse comma-separated Word arrays from XML content

### 🛠️ Development Tools
- **Configuration utility**: DOS-style setup program for sound card detection
- **Text UI library**: Menu system with direct video memory rendering
- **Test programs**: Example code demonstrating all features
- **Automated builds**: Batch files handle dependency compilation

## 📁 Project Structure

```
D:\ENGINE\
├── UNITS\          Core engine units
│   ├── CONFIG.PAS      - INI file configuration
│   ├── ENTITIES.PAS    - Entity component system (WIP)
│   ├── GENTYPES.PAS    - Generic type definitions
│   ├── KEYBOARD.PAS    - Keyboard interrupt handler
│   ├── LINKLIST.PAS    - Generic doubly-linked list
│   ├── MINIXML.PAS     - XML parser with DOM tree
│   ├── MOUSE.PAS       - Mouse interrupt handler
│   ├── PKMLOAD.PAS     - PKM image loader
│   ├── PLAYHSC.PAS     - HSC music player
│   ├── RESMAN.PAS      - Resource manager (WIP)
│   ├── RTCTIMER.PAS    - RTC high-resolution timer
│   ├── SBDSP.PAS       - Sound Blaster driver
│   ├── SNDBANK.PAS     - XMS sound bank manager
│   ├── SPRITE.PAS      - Sprite animation system
│   ├── STRMAP.PAS      - String hash map
│   ├── STRUTIL.PAS     - String utility functions
│   ├── TEXTUI.PAS      - Text mode UI library
│   ├── TMXLOAD.PAS     - TMX tilemap loader
│   ├── TMXDRAW.PAS     - TMX tilemap renderer
│   ├── VGA.PAS         - Mode 13h graphics driver
│   ├── VGAFONT.PAS     - Variable-width font text renderer
│   ├── VGAPRINT.PAS    - 8x8 bitmap font text renderer
│   └── XMS.PAS         - XMS extended memory driver
│
├── TESTS\          Test programs
│   ├── C*.BAT          - Compile scripts
│   ├── DRWTEST.PAS     - VGA drawing primitives demo
│   ├── IMGTEST.PAS     - Advanced sprite demo with audio
│   ├── MAPTEST.PAS     - String map (StrMap) demo
│   ├── MOUTEST.PAS     - Mouse input demo with crosshair
│   ├── SNDTEST.PAS     - Sound bank demo
│   ├── SPRTEST.PAS     - Sprite animation system demo
│   ├── TMXTEST.PAS     - TMX tilemap scrolling demo
│   ├── VGATEST.PAS     - VGA graphics demo
│   └── XMLTEST.PAS     - XML parser demo
│
├── SETUP\          Configuration utility
│   ├── CSETUP.BAT      - Compile script
│   ├── SETUP.PAS       - Sound card setup program
│   └── VOCLOAD.PAS     - VOC file loader
│
├── DATA\           Sample assets
│   ├── BG.PKM          - Background image for the TMXTEST
│   ├── BLOCKS.PNG      - Blocks image only used by TEST.TMX
│   ├── EXPLODE.VOC     - Example sound effect
│   ├── FANTASY.HSC     - Example Adlib music
│   ├── FONT.PKM        - Example font image
│   ├── FONT.XML        - Example font metadata
│   ├── PLAYER.PKM      - Example sprite sheet (192×64)
│   ├── RES.XML         - Example resources file (WIP)
│   ├── TEST.PAL        - Example PAL file for the TMXTEST
│   ├── TEST.PKM        - Example 289×171 image
│   ├── TEST.TMX        - Example tilemap
│   ├── TEST.XML        - Example game configuration
│   ├── TILESET.PKM     - Example tileset image for TMXTEST
│   ├── TILESET.PNG     - Tileset image only used by TEST.TMX
│   ├── TEST.TMX        - Example TMX file
│   └── TEST.XML        - Example game configuration
│
├── DOCS\           Documentation, see the links above
└── VENDOR\         Third-party libraries (not used), only for credits
```

## 🎨 Creating Assets

### PKM Images
Use [GrafX2](http://grafx2.chez.com/) the DOS pixel art editor (Windows/Linux/Mac):
1. Draw with 256 colors (any resolution supported)
2. Save as PKM format (RLE-compressed)
   - Common sizes: 320×200 (full screen), 32×32 (sprites), 16×16 (tiles)

### VOC Sound Effects
Use [Audacity](https://www.audacityteam.org/) (Windows/Linux/Mac):
1. Import audio (WAV, MP3, etc.)
2. **Tracks → Mix → Mix Stereo Down to Mono**
3. **Tracks → Resample → 11025 Hz** (or 22050 Hz)
4. **File → Export → Export Audio**
   - Format: "Other uncompressed files"
   - Header: "VOC (Creative Labs)"
   - Encoding: "Unsigned 8-bit PCM"

### HSC Music
Use one of the following:
1. [Adlib Tracker II](https://adlibtracker.net/) - More modern approach (Windows/Linux)
2. [HSC-tracker](https://demozoo.org/productions/293837/) - The original HSC tracker (only DOS)

### TMX tilemaps

Use [Tiled](https://www.mapeditor.org/) a full-featured level editor (Windows/Linux/Mac).
See the restrictions at the [tilemap documentation](DOCS/TILEMAP.md).

## 📜 Credits

- **SBDSP**: Romesh Prakashpalan (1995)
- **XMS Driver**: KIV without Co (1992)
- **HSC Player**: Glamorous Ray (1994)

## 🤝 Contributing

Contributions welcome! This engine aims to preserve 1990s DOS demoscene programming techniques while remaining hackable and educational.

---

**Made with 💾 for retro DOS enthusiasts**
