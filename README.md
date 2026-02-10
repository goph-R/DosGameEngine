# DOS Game Engine

A retro DOS multimedia engine written in **Turbo Pascal 7.0** (1994-era), featuring VGA Mode 13h graphics, AdLib/OPL2 music, and Sound Blaster digital audio. Perfect for demoscene-style programming, retro game development, and learning classic DOS systems programming.

![Version](https://img.shields.io/badge/Version-1.0.0-green)
![DOS](https://img.shields.io/badge/DOS-16--bit-blue)
![Turbo Pascal](https://img.shields.io/badge/Turbo%20Pascal-7.0-orange)
![License](https://img.shields.io/badge/License-MIT-magenta)

## 📸 Screenshots

<div align="center">
  <table>
    <tr>
      <td align="center">
        <a href="IMAGES/TMXTEST.png">
          <img src="IMAGES/TMXTEST-thumb.png" alt="TMX Tilemap Test">
        </a>
        <br>
        <strong>Tilemap Rendering</strong><br>
        <small>TMXTEST.PAS</small>
      </td>
      <td align="center">
        <a href="IMAGES/XICLONE.png">
          <img src="IMAGES/XICLONE-thumb.png" alt="Variable-Width Font Test">
        </a>
        <br>
        <strong>Example Game</strong><br>
        <small>XICLONE.PAS</small>
      </td>
    </tr>
    <tr>
      <td align="center">
        <a href="IMAGES/SPRTEST.png">
          <img src="IMAGES/SPRTEST-thumb.png" alt="Sprite Animation Test">
        </a>
        <br>
        <strong>Sprite Animation</strong><br>
        <small>SPRTEST.PAS</small>
      </td>
      <td align="center">
        <a href="IMAGES/SETUP.png">
          <img src="IMAGES/SETUP-thumb.png" alt="Setup Utility">
        </a>
        <br>
        <strong>Setup Utility</strong><br>
        <small>SETUP.PAS</small>
      </td>
    </tr>
  </table>
</div>

## 🚀 Quick Start

### Prerequisites
- [Turbo Pascal 7.0](https://winworldpc.com/product/turbo-pascal/7x) (TPC.EXE in %PATH%)
- [DOSBox-X](https://dosbox-x.com/), [86Box](https://86box.net/) or real DOS/FreeDOS
- HIMEM.SYS loaded (for XMS extended memory support, default in DOSBox)

### First Run
```bash
# Compile & try the example game (WIP)
cd ..\XICLONE
CXICLONE.BAT
XICLONE.EXE
```

**Controls:**
- **Left/Right**: Move the stack left and right
- **Down**: Falling faster
- **Space**: Rotate stack
- **ESC**: Pause

## ✨ Features

### 🎨 Graphics
- 320×200 VGA Mode 13h with double-buffering
- Variable-width bitmap fonts (PCX + XML)
- UI widget toolkit (buttons, labels, checkboxes, line edits)
- PCX/BMP image loading (Aseprite, GIMP compatible)
- TMX tilemap support (Tiled Map Editor)
- Delta-time sprite animation system
- Dirty rectangle optimization

### 🔊 Audio
- HSC music (AdLib/OPL2, interrupt-driven)
- XMS-based sound bank (VOC format, 8-bit PCM)
- Sound Blaster DSP driver (DMA-safe mixing)

### 🎮 Input
- Hardware keyboard handler (INT 9h)
- Mouse support (INT 33h, 3-button)

### 🧠 Memory & Performance
- XMS extended memory manager (>1MB RAM)
- RTC high-resolution timer (IRQ8, no HSC conflict)
- Dirty rectangle rendering

### 📦 Resources
- XML-based resource manager (lazy/eager loading)
- Unified game loop framework
- Lightweight XML parser/writer
- INI configuration system
- String hash map (O(1) lookup)
- Linked list utilities
- CRC32 hash (ISO 3309, PHP compatible)
- High score system with tamper protection

### 🛠 Tools
- Sound card setup utility
- Text-mode UI toolkit
- Debug logger (startup/shutdown safe)
- Comprehensive test suite

## 📚 Documentation

### Core Graphics
- **[VGA.PAS](https://docs.dynart.net/dos-game-engine/BASICS/VGA.html)** - Mode 13h graphics driver (320×200, 256 colors)
- **[PCX.PAS](https://docs.dynart.net/dos-game-engine/BASICS/PCX.html)** - PCX image loader/saver
- **[BMP.PAS](https://docs.dynart.net/dos-game-engine/BASICS/BMP.html)** - Windows BMP image loader/saver
- **[VGAPRINT.PAS](https://docs.dynart.net/dos-game-engine/BASICS/VGAPRINT.html)** - Embedded 8×8 bitmap font
- **[VGAFONT.PAS](https://docs.dynart.net/dos-game-engine/ADVANCED/VGAFONT.html)** - Variable-width font system
- **[SPRITE.PAS](https://docs.dynart.net/dos-game-engine/BASICS/SPRITE.html)** - Delta-time sprite animation
- **[DRECT.PAS](https://docs.dynart.net/dos-game-engine/ADVANCED/DRECT.html)** - Dirty rectangle optimization

### User Interface
- **[VGAUI.PAS](https://docs.dynart.net/dos-game-engine/ADVANCED/VGAUI.html)** - VGA widget toolkit (buttons, labels, checkboxes, line edits)
- **[TEXTUI.PAS](https://docs.dynart.net/dos-game-engine/ADVANCED/TEXTUI.html)** - Text mode UI system (SETUP utility)

### Audio
- **[SBDSP.PAS](https://docs.dynart.net/dos-game-engine/AUDIO/SBDSP.html)** - Sound Blaster DSP driver
- **[SNDBANK.PAS](https://docs.dynart.net/dos-game-engine/AUDIO/SNDBANK.html)** - XMS sound bank manager
- **[PLAYHSC.PAS](https://docs.dynart.net/dos-game-engine/AUDIO/PLAYHSC.html)** - HSC music player (AdLib/OPL2)
- **[HSC Format](https://docs.dynart.net/dos-game-engine/AUDIO/HSC.html)** - HSC file format specification

### Input
- **[KEYBOARD.PAS](https://docs.dynart.net/dos-game-engine/BASICS/KEYBOARD.html)** - Hardware keyboard handler (INT 9h)
- **[MOUSE.PAS](https://docs.dynart.net/dos-game-engine/BASICS/MOUSE.html)** - Mouse driver (INT 33h)

### Tilemaps
- **[TMXLOAD.PAS](https://docs.dynart.net/dos-game-engine/ADVANCED/TILEMAP.html)** - TMX tilemap loader (Tiled Map Editor)
- **[TMXDRAW.PAS](https://docs.dynart.net/dos-game-engine/ADVANCED/TILEMAP.html)** - TMX rendering system

### Memory & Timing
- **[XMS.PAS](https://docs.dynart.net/dos-game-engine/UTILS/XMS.html)** - Extended memory manager (HIMEM.SYS)
- **[RTCTIMER.PAS](https://docs.dynart.net/dos-game-engine/UTILS/RTCTIMER.html)** - RTC high-resolution timer (IRQ8)

### Resources
- **[RESMAN.PAS](https://docs.dynart.net/dos-game-engine/ADVANCED/RESMAN.html)** - XML-based resource manager
- **[MINIXML.PAS](https://docs.dynart.net/dos-game-engine/ADVANCED/MINIXML.html)** - Lightweight XML parser/writer
- **[CONFIG.PAS](https://docs.dynart.net/dos-game-engine/ADVANCED/CONFIG.html)** - INI configuration system

### Utilities
- **[GENTYPES.PAS](https://docs.dynart.net/dos-game-engine/UTILS/GENTYPES.html)** - Generic pointer and array types, alignment constants
- **MATHUTIL.PAS** - Math utilities (Clamp, Lerp, Min/Max, 16.16 fixed-point)
- **[STRUTIL.PAS](https://docs.dynart.net/dos-game-engine/UTILS/STRUTIL.html)** - String conversion utilities
- **[STRMAP.PAS](https://docs.dynart.net/dos-game-engine/UTILS/STRMAP.html)** - String hash map (O(1) lookup)
- **[LINKLIST.PAS](https://docs.dynart.net/dos-game-engine/UTILS/LINKLIST.html)** - Doubly-linked list
- **[CRC32.PAS](https://docs.dynart.net/dos-game-engine/UTILS/CRC32.html)** - CRC-32 hash (ISO 3309, PHP compatible)
- **[HISCORE.PAS](https://docs.dynart.net/dos-game-engine/ADVANCED/HISCORE.html)** - High score management with tamper protection
- **[LOGGER.PAS](https://docs.dynart.net/dos-game-engine/UTILS/LOGGER.html)** - Debug file logger

### Game Framework (DGE - DOS Game Engine)
- **[DGECORE.PAS](https://docs.dynart.net/dos-game-engine/ADVANCED/DGECORE.html)** - Game framework core (TGame object, subsystem integration)
- **[DGESCR.PAS](https://docs.dynart.net/dos-game-engine/ADVANCED/DGECORE.html)** - Screen/state management (TScreen base object)

### Guides
- **[Build Guide](https://docs.dynart.net/dos-game-engine/STARTING/BUILD.html)** - Compilation instructions
- **[Asset Creation](https://docs.dynart.net/dos-game-engine/STARTING/CREATE.html)** - Creating PCX, VOC, HSC, TMX assets
- **[Example Program](https://docs.dynart.net/dos-game-engine/STARTING/EXAMPLE.html)** - Complete game example walkthrough

## 📁 Project Structure

```
D:\ENGINE\
├── DOCS\           Documentation and design notes
├── TESTS\          Test programs (IMGTEST, TMXTEST, SPRTEST, FNTTEST, etc.)
├── SETUP\          Sound card setup utility
├── UNITS\          Core engine units (VGA, SBDSP, Keyboard, Mouse, XML, Sprite, etc.)
├── VENDOR\         Third-party libraries (SBDSP, XMS, HSC)
└── XICLONE\        Example game (Columns/Xixit clone, WIP)
```

## 🎨 Creating Assets

**PCX Images:**
- **Aseprite** (recommended): File → Export → .pcx (8-bit indexed color mode)
- **GrafX2** (good palette handling): File → Save → .pcx
- **GIMP**: Image → Mode → Indexed (256 colors) → Export as PCX
- **Photoshop**: Image → Mode → Indexed Color → Save As PCX (8 bits/pixel)
- Common sizes: 320×200 (full screen), 32×32 (sprites), 16×16 (tiles)

**VOC Sounds:**
Use [Audacity](https://www.audacityteam.org/) → Mix to Mono → Resample 11025Hz → Export as VOC (Unsigned 8-bit PCM).

**HSC Music:**
Use [Adlib Tracker II](https://adlibtracker.net/) or [HSC-tracker](https://demozoo.org/productions/293837/).

**TMX Tilemaps:**
Use [Tiled](https://www.mapeditor.org/) (see [TILEMAP.md](https://docs.dynart.net/dos-game-engine/TILEMAP.html) for restrictions).

## 📜 Credits

- **SBDSP**: Romesh Prakashpalan (1995)
- **XMS Driver**: KIV without Co (1992)
- **HSC Player**: Glamorous Ray (1994)

## 🤝 Contributing

Contributions welcome! This engine preserves 1990s DOS demoscene techniques while remaining hackable and educational.

## 🔒 Asset Licensing

Some `DATA` files (images and tilesets) are © 2025 Dynart Kft. Free for non-commercial use with credits. Commercial use requires separate license. See `ASSETS_LICENSE.md`.

---

**Made with 💾 for retro DOS enthusiasts**
