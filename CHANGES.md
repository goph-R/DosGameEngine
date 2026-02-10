# Changelog

All notable changes to the DOS Game Engine will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2025-01-23

Initial release of the DOS Game Engine - a retro multimedia framework for Turbo Pascal 7.0.

### Added
- **VGA Graphics** (VGA.PAS) - Mode 13h (320x200 256-color) with double buffering, palette control, clipping, and primitive drawing
- **Image Loading** - PCX (PCX.PAS) and BMP (BMP.PAS) loaders with palette support
- **Font System** (VGAFONT.PAS) - Variable-width bitmap fonts from XML + PCX sprite sheets
- **Sound System** - Sound Blaster driver (SBDSP.PAS) with VOC file support and XMS-based sound bank (SNDBANK.PAS)
- **Music System** (PLAYHSC.PAS) - HSC Adlib/OPL2 music player
- **UI Framework** (VGAUI.PAS) - Widget-based UI with Delphi-style event handlers
  - Widgets: Label, Button, Checkbox, LineEdit
  - OnClick event for buttons/checkboxes with keyboard and mouse support
  - Keyboard navigation (arrows, Tab, Enter/Space)
  - Mouse support with click tracking and drag feedback
  - Dirty rectangle optimization (40x performance boost)
  - 3D beveled panels (Windows 95-style)
- **Input** - Keyboard (KEYBOARD.PAS) with INT 9h handler and Mouse (MOUSE.PAS) with INT 33h driver
- **Timing** - RTC high-resolution timer (RTCTIMER.PAS, IRQ8) compatible with HSC music, CRT-free delay (DELAY.PAS)
- **Sprites** (SPRITE.PAS) - Delta-time animation with forward/pingpong/once playback
- **Tilemap** - TMX loader (TMXLOAD.PAS) and renderer (TMXDRAW.PAS) for Tiled Map Editor
- **Resource Manager** (RESMAN.PAS) - Centralized XML-based asset loading with lazy/eager modes
- **Game Framework** (DGECORE.PAS, DGESCR.PAS) - Screen management, delta-time loop, auto-initialization
- **Memory** (XMS.PAS) - Extended memory support via HIMEM.SYS
- **Utilities** - String map (STRMAP.PAS), linked list (LINKLIST.PAS), XML parser (MINIXML.PAS), string helpers (STRUTIL.PAS), logger (LOGGER.PAS), dirty rectangles (DRECT.PAS), CRC32 hashing (CRC32.PAS)
- **Configuration** (CONFIG.PAS) - INI file management for game settings
- **Text UI** (TEXTUI.PAS) - Text mode menus and dialogs
- **XiClone Game** - Complete Columns/Tetris-style puzzle game demonstrating all engine features
- **Documentation** - Comprehensive markdown docs for all major systems in DOCS/ folder
- **Test Suite** - Test programs for all engine components in TESTS/ folder

### Technical Features
- Targets 286 CPUs (8-25 MHz) with optimized assembly (REP MOVSW for fast blitting)
- DOS 8.3 filename compliance (except DOCS/ and TOOLS/)
- Period-accurate 1994-era demoscene programming style
- No Runtime Error 200 bug (CRT-free delay implementation)
- IRQ-safe timing (RTC IRQ8 doesn't conflict with HSC IRQ0)
- DMA-safe sound allocation (no 64KB boundary crossing)
- Virtual method table (VMT) support for object-oriented design

---
