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

**Core:**
- **[CLAUDE.md](CLAUDE.md)** - Technical reference for all units
- **[DOCS/BUILD.md](DOCS/BUILD.md)** - Building and compilation
- **[DOCS/ISSUES.md](DOCS/ISSUES.md)** - Critical cleanup rules
- **[DOCS/UNITS_REFERENCE.md](DOCS/UNITS_REFERENCE.md)** - Complete units reference

**Formats:**
- **[PKM.md](DOCS/PKM.md)** - PKM image format
- **[HSC.md](DOCS/HSC.md)** - HSC music format
- **[TILEMAP.md](DOCS/TILEMAP.md)** - TMX tilemap format

**APIs:**
- **[VGA.md](DOCS/VGA.md)** - Graphics (Mode 13h, sprites, palettes)
- **[KEYBOARD.md](DOCS/KEYBOARD.md)** - Keyboard handler & scan codes
- **[MOUSE.md](DOCS/MOUSE.md)** - Mouse input & buttons
- **[SBDSP.md](DOCS/SBDSP.md)** - Sound Blaster driver
- **[SNDBANK.md](DOCS/SNDBANK.md)** - XMS sound bank
- **[SPRITE.md](DOCS/SPRITE.md)** - Sprite animation system
- **[VGAFONT.md](DOCS/VGAFONT.md)** - Variable-width fonts
- **[MINIXML.md](DOCS/MINIXML.md)** - XML parser

## ✨ Features

**Graphics:** VGA Mode 13h (320×200 256-color), PKM image loader (RLE), double-buffering, sprite animation (3 play modes), TMX tilemap support, collision layers, variable-width fonts, palette control (0-63 RGB)

**Audio:** HSC music (Adlib/OPL2), Sound Blaster (8-bit PCM 11-44kHz), VOC files, XMS sound bank, DMA-safe buffers

**Input:** Keyboard (INT 9h, IsKeyDown/IsKeyPressed), Mouse (INT 33h, 3-button support)

**Memory:** XMS extended memory (>1MB via HIMEM.SYS), smart buffering, heap management

**Data:** XML parser (DOM-style), INI config, hash map (O(1) lookup), 64KB file support

**Tools:** Setup utility (sound card config), text UI library, test programs, automated builds

## 📁 Project Structure

```
D:\ENGINE\
├── UNITS\          Core engine (VGA, SBDSP, Keyboard, Mouse, XML, Sprite, etc.)
├── TESTS\          Test programs (IMGTEST, TMXTEST, SPRTEST, FNTTEST, etc.)
├── SETUP\          Sound card setup utility
├── DATA\           Sample assets (PKM, VOC, HSC, TMX, fonts)
├── DOCS\           Documentation (see links above)
└── VENDOR\         Third-party libraries (credits only)
```

**Core Units:** VGA, PKMLOAD, SBDSP, SNDBANK, XMS, PLAYHSC, RTCTIMER, KEYBOARD, MOUSE, SPRITE, TMXLOAD, TMXDRAW, VGAFONT, MINIXML, STRMAP, CONFIG, TEXTUI

**Test Programs:** VGATEST, DRWTEST, FNTTEST, IMGTEST (music+sound), SNDTEST, SPRTEST, TMXTEST, MOUTEST, MAPTEST, XMLTEST

## 🎨 Creating Assets

**PKM Images:** Use [GrafX2](http://grafx2.chez.com/) → Draw 256-color → Save as PKM (RLE-compressed). Common: 320×200 (full screen), 32×32 (sprites), 16×16 (tiles).

**VOC Sounds:** Use [Audacity](https://www.audacityteam.org/) → Mix to Mono → Resample 11025Hz → Export as VOC (Unsigned 8-bit PCM).

**HSC Music:** Use [Adlib Tracker II](https://adlibtracker.net/) or [HSC-tracker](https://demozoo.org/productions/293837/).

**TMX Tilemaps:** Use [Tiled](https://www.mapeditor.org/) (see [TILEMAP.md](DOCS/TILEMAP.md) for restrictions).

## 📜 Credits

- **SBDSP**: Romesh Prakashpalan (1995)
- **XMS Driver**: KIV without Co (1992)
- **HSC Player**: Glamorous Ray (1994)

## 🤝 Contributing

Contributions welcome! This engine preserves 1990s DOS demoscene techniques while remaining hackable and educational.

## 🔒 Asset Licensing

Some `DATA` files (`BG.PKM`, `PLAYER.PKM`, `TILESET.PKM/PNG`) are © 2025 Dynart Kft. Free for non-commercial use with credits. Commercial use requires separate license. See `ASSETS_LICENSE.md`.

---

**Made with 💾 for retro DOS enthusiasts**
