# DOS Game Engine

A retro DOS multimedia engine written in **Turbo Pascal 7.0** (1994-era), featuring VGA Mode 13h graphics, AdLib/OPL2 music, and Sound Blaster digital audio. Perfect for demoscene-style programming, retro game development, and learning classic DOS systems programming.

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
        <strong>Tilemap Rendering</strong><br>
        <small>TMXTEST.PAS</small>
      </td>
      <td align="center">
        <a href="DOCS/SCREENS/XICLONE.png">
          <img src="DOCS/SCREENS/XICLONE-thumb.png" alt="Variable-Width Font Test">
        </a>
        <br>
        <strong>Example Game</strong><br>
        <small>XICLONE.PAS</small>
      </td>
    </tr>
    <tr>
      <td align="center">
        <a href="DOCS/SCREENS/SPRTEST.png">
          <img src="DOCS/SCREENS/SPRTEST-thumb.png" alt="Sprite Animation Test">
        </a>
        <br>
        <strong>Sprite Animation</strong><br>
        <small>SPRTEST.PAS</small>
      </td>
      <td align="center">
        <a href="DOCS/SCREENS/SETUP.png">
          <img src="DOCS/SCREENS/SETUP-thumb.png" alt="Setup Utility">
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
- [Turbo Pascal 7.0](https://winworldpc.com/product/turbo-pascal/7x) (TPC.EXE)
- [DOSBox-X](https://dosbox-x.com/), [86Box](https://86box.net/) or real DOS/FreeDOS
- HIMEM.SYS loaded (for XMS extended memory support, default in DOSBox)

### First Run
```bash
# 1. Compile & run setup utility to configure sound card
cd SETUP
CSETUP.BAT
SETUP.EXE

# 2. Compile & try the advanced VGA demo with music and sound
cd ..\TESTS
CIMGTEST.BAT
IMGTEST.EXE

# 3. Compile & try the example game (WIP)
cd ..\XICLONE
CXICLONE.BAT
XICLONE.EXE
```

**Controls:**
- **E**: Play an explosion
- **ESC**: Exit demo

## ✨ Features

### 🎨 Graphics Engine

* [320×200 VGA Mode 13h renderer](DOCS/VGA.md)  
  with double-buffering for flicker-free visuals, transparent images, primitive drawing, full palette control.  
* [Variable-width bitmap fonts](DOCS/VGAUI.md)  
  using PCX art + XML metadata.  
* [UI widget toolkit](DOCS/VGAUI.md)  
  (buttons, labels, checkboxes, line edits) with keyboard navigation and event-driven behavior.  
* [PCX loader/saver](DOCS/PCX.md)  
  compatible with Aseprite, GIMP, and GrafX2 workflows.  
* [Tiled TMX integration](DOCS/TILEMAP.md)  
  Back and front layers merged automatically (a TMX optimizer is work in progress),
  "Blocks" layer for a collision grid,
  `<objectgroup>` loading hook: you can load your objects however you want.
* [Sprite animation system](DOCS/SPRITE.md)  
  with multiple playback modes.

### 🔊 Audio System

* [HSC music playback](DOCS/HSC.md)  
  via AdLib/OPL2 (interrupt-driven).  
* [Sound bank stored in XMS](DOCS/SNDBANK.md),  
  perfect for memory-heavy sample sets. VOC format support (8-bit PCM, 11–44 kHz) with DMA-safe mixing.  
* [Dedicated Sound Blaster DSP driver](DOCS/SBDSP.md)  
  for maximum compatibility.

### 🎮 Input Handling

* [Real-time keyboard system](DOCS/KEYBOARD.md)  
  with key-down and key-press tracking.  
* [Mouse support via INT 33h](DOCS/MOUSE.md),  
  including 3-button mice.

### 🧠 Memory & Performance

* [Advanced XMS manager](DOCS/XMS.md)  
  for systems with >1 MB RAM.

### 📦 Data & Resource Management

* [Unified game loop framework](DOCS/GAMEUNIT.md)  
  with screen management and subsystem initialization.  
* [XML-based resource manager](DOCS/RESMAN.md)  
  with lazy/eager loading and palette extraction.  
* [Lightweight XML parser/writer](DOCS/MINIXML.md)  
  (DOM-style, supports files up to 64 KB).  
* Simple INI parser for configuration.  
* Fast string hash map (O(1) lookup).  
* Linked list utilities for game data structures.

### 🛠 Tools & Utilities

* Setup utility for configuring sound hardware.  
* Text-mode UI toolkit for installers and tools.  
* Debug logger for startup/shutdown diagnostics (safe for DOS’s slow disk I/O).  
* Test programs for graphics, fonts, tiles, UI, sprites, audio, etc.  
* Automated build scripts for quickly generating test binaries.

## 📁 Project Structure

```
D:\ENGINE\
├── DOCS\           Documentation (see links above)
├── TESTS\          Test programs (IMGTEST, TMXTEST, SPRTEST, FNTTEST, etc.)
├── SETUP\          Basic setup utility (currently for Sound card setup)
├── UNITS\          Core engine (VGA, SBDSP, Keyboard, Mouse, XML, Sprite, etc.)
├── VENDOR\         Third-party libraries (credits only)
└── XICLONE\        Example game project, Columns/Xixit clone
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
Use [Tiled](https://www.mapeditor.org/) (see [TILEMAP.md](DOCS/TILEMAP.md) for restrictions).

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
