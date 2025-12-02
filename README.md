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

## 📖 Documentation

- **[GAMEUNIT.md](DOCS/GAMEUNIT.md)** - Central game loop framework with screens
- **[RESMAN.md](DOCS/RESMAN.md)** - Resource Manager (XML-based asset loading)
- **[VGA.md](DOCS/VGA.md)** - Graphics (Mode 13h, sprites, palettes)
- **[VGAUI.md](DOCS/VGAUI.md)** - UI widgets (Label, Button, Checkbox, LineEdit)
- **[KEYBOARD.md](DOCS/KEYBOARD.md)** - Keyboard handler & scan codes
- **[MOUSE.md](DOCS/MOUSE.md)** - Mouse input & buttons
- **[SBDSP.md](DOCS/SBDSP.md)** - Sound Blaster driver
- **[SNDBANK.md](DOCS/SNDBANK.md)** - XMS sound bank
- **[SPRITE.md](DOCS/SPRITE.md)** - Sprite animation system
- **[VGAFONT.md](DOCS/VGAFONT.md)** - Variable-width fonts
- **[MINIXML.md](DOCS/MINIXML.md)** - XML parser and writer
- **[PCX.md](DOCS/PCX.md)** - PCX image format loading and saving (Aseprite, GIMP, GrafX2)
- **[HSC.md](DOCS/HSC.md)** - HSC music format player (HSC-tracker, Adlib Tracker II)
- **[TILEMAP.md](DOCS/TILEMAP.md)** - TMX tilemap format (replaces PNG to PCX on load)

## ✨ Features

### 🎨 Graphics Engine

* **320×200 VGA Mode 13h renderer** with double-buffering for flicker-free visuals.
* **Full palette control** (RGB 0–63) and smooth palette effects.
* **Variable-width bitmap fonts** using PCX art + XML metadata.
* **UI widget toolkit** (buttons, labels, checkboxes, line edits) with keyboard navigation and event-driven behavior.
* **PCX loader/saver** compatible with Aseprite, GIMP, and GrafX2 workflows.
* **Tiled TMX integration** see [TILEMAP.md](DOCS/TILEMAP.md) for the restrictions.
* **Efficient tile renderer** optimized for DOS.
* **Sprite animation system** with multiple playback modes.

### 🔊 Audio System

* **HSC music playback** via AdLib/OPL2 (interrupt-driven).
* **Sound bank stored in XMS**, perfect for memory-heavy sample sets.
* **VOC format support** (8-bit PCM, 11–44 kHz) with DMA-safe mixing.
* **Dedicated Sound Blaster DSP driver** for maximum compatibility.

### 🎮 Input Handling

* **Real-time keyboard system** with key-down and key-press tracking.
* **Mouse support via INT 33h**, including 3-button mice.

### 🧠 Memory & Performance

* **Advanced XMS manager** for systems with >1 MB RAM.
* Smart buffering and optimized heap usage for large assets and audio banks.

### 📦 Data & Resource Management

* **Unified game loop framework** with screen management and subsystem initialization.
* **XML-based resource manager** with lazy/eager loading and palette extraction.
* **Lightweight XML parser/writer** (DOM-style, supports files up to 64 KB).
* **Simple INI parser** for configuration.
* **Fast string hash map** (O(1) lookup).
* **Linked list utilities** for game data structures.

### 🛠 Tools & Utilities

* **Setup utility** for configuring sound hardware.
* **Text-mode UI toolkit** for installers and tools.
* **Debug logger** for startup/shutdown diagnostics (safe for DOS’s slow disk I/O).
* **Test programs** for graphics, fonts, tiles, UI, sprites, audio, etc.
* **Automated build scripts** for quickly generating test binaries.

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
