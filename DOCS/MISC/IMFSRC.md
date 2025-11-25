# IMF Music Sources

Where to download IMF (Id Music Format) files for testing and development.

## 🎵 Best Sources for IMF Files

### 1. **Video Game Music Preservation Foundation (VGMPF)** ⭐ Recommended
**URL**: https://www.vgmpf.com/Wiki/index.php?title=IMF

- **Most complete archive** of extracted IMF files
- Individual game pages have download links
- Already extracted from game files (no need to rip yourself)
- Games include:
  - Wolfenstein 3D (700 Hz)
  - Commander Keen 4-6 (560 Hz)
  - Blake Stone: Aliens of Gold (700 Hz)
  - Blake Stone: Planet Strike (700 Hz)
  - Catacomb 3D

**How to download:**
1. Visit the VGMPF Wiki
2. Navigate to specific game page (e.g., "Wolfenstein 3D (DOS)")
3. Download the IMF music pack
4. Extract files like `NAZI_NOR.IMF`, `WARMARCH.IMF`, etc.

### 2. **Keen Modding Community - Shikadi.net**
**URL**: https://moddingwiki.shikadi.net/

- Active Commander Keen modding community
- IMF file collections and tools
- K1n9_Duk3's tools page: https://k1n9duk3.shikadi.net/imftools.html

### 3. **Extract from Shareware Games** (Legal & Free)

**Commander Keen 1** (Shareware):
- **Archive.org**: https://archive.org/details/msdos_Commander_Keen_1_-_Marooned_on_Mars_1990
- Download → Extract with tools like **ModKeen** or **UnlzEXE**
- IMF files play at **560 Hz**

**Wolfenstein 3D** (Shareware episode):
- Available on various abandonware sites
- Use **WDC (Wolf Data Compiler)** or **Slade** to extract IMF/WLF files
- IMF files play at **700 Hz**

### 4. **IMF Creator Example Files**
**GitHub**: https://github.com/adambiser/imf-creator

- May include sample IMF files in repository
- Can convert MIDI → IMF with the tool
- Active development (updated 2024)

### 5. **Quick Test Files** (Easiest Method)

**Fastest way to get test IMF files:**

1. **Download Commander Keen 1 shareware** from Archive.org
2. **Use DOSBox + AUDEXT** to extract audio files
3. Or use **ModKeen** tool to unpack .CK1 files

---

## 🛠️ Tools for Working with IMF Files

### Extraction Tools

**Slade** (Universal game archive tool)
- Extract IMF from various game formats
- Cross-platform (Windows, Linux, macOS)
- https://slade.mancubus.net/

**ModKeen** (Commander Keen specific)
- Extract resources from Keen games
- Windows executable

**WDC** (Wolfenstein Data Compiler)
- Extract/compile Wolfenstein 3D data
- Works with IMF and WLF files

### Creation Tools

**IMFCreator** ⭐ Recommended
- **GitHub**: https://github.com/adambiser/imf-creator
- Convert MIDI or MUS files to IMF
- Windows GUI application
- Supports all IMF variants (Type 0, Type 1)

**Adlib Tracker II**
- **URL**: https://adlibtracker.net/
- Full-featured tracker
- Can export to IMF format
- Windows application

**MIDI2IMF**
- Command-line MIDI to IMF converter
- Available on KeenWiki: https://keenwiki.shikadi.net/wiki/MIDI2IMF

### Playback Tools

**K1n9_Duk3's IMF Player for DOS** (v1.3)
- DOS executable, plays IMF/KMF files
- Adjustable playback rates
- https://k1n9duk3.shikadi.net/imftools.html

**Gerstrong's IMF Player** (v2.3)
- Windows-based player
- Built-in OPL emulator
- GUI interface

**AdPlug**
- Multi-format OPL music player
- Supports IMF and many other formats
- Can convert IMF to MIDI
- https://adplug.github.io/

### Utility Tools

**IMF to WAV Converter** (v1.2)
- Export IMF files as audio WAV files
- Useful for testing without OPL hardware

**IMF Crusher** (v1.5)
- Optimize and compress existing IMF files
- Reduce file size while maintaining quality

**DRO2IMF**
- Convert DOSBox DRO captures to IMF format
- Useful for converting existing OPL recordings

---

## 📚 Games That Use IMF Format

### Commander Keen Series (560 Hz)
- Commander Keen 4: Secret of the Oracle
- Commander Keen 5: The Armageddon Machine
- Commander Keen 6: Aliens Ate My Babysitter

### Wolfenstein 3D Engine (700 Hz)
- Wolfenstein 3D
- Spear of Destiny
- Blake Stone: Aliens of Gold
- Blake Stone: Planet Strike
- Corridor 7: Alien Invasion
- Operation Body Count

### Other Games
- Catacomb 3D (various rates)
- Bio Menace (560 Hz)
- Halloween Harry / Alien Carnage (560 Hz)

---

## 🎹 Creating Your Own IMF Files

### Method 1: Convert from MIDI (Easiest)

1. **Create/find MIDI file** (preferably simple, melodic)
2. **Download IMFCreator**: https://github.com/adambiser/imf-creator
3. **Open MIDI in IMFCreator**
4. **Set playback rate**: 560 Hz (Keen) or 700 Hz (Wolf3D)
5. **Export as IMF** (Type 1 recommended)

### Method 2: Compose in Tracker

1. **Download Adlib Tracker II**: https://adlibtracker.net/
2. **Compose music** using OPL2 instruments
3. **Export → IMF format**
4. **Choose playback rate** based on target game/engine

### Method 3: Record from DOSBox

1. **Play any DOS game with OPL music** in DOSBox
2. **Enable OPL capture**: `capture startopl` in DOSBox console
3. **Convert DRO to IMF**: Use DRO2IMF tool
4. **Note**: Results in larger files (unoptimized)

---

## 📖 IMF Format Specifications

### Type 0 IMF (No Header)
```
[delay word][register byte][data byte]
[delay word][register byte][data byte]
...
```

### Type 1 IMF (With Header)
```
[length word] (little-endian, file size - 2)
[delay word][register byte][data byte]
[delay word][register byte][data byte]
...
```

### Playback Details

- **Delay**: 16-bit word (little-endian), number of ticks to wait
- **Register**: OPL2 register address (0x00-0xFF)
- **Data**: Value to write to register
- **Tick Rate**: Game-specific (560 Hz, 700 Hz, etc.)
- **End Marker**: Delay = 0 (can also indicate loop point)

### OPL2 Ports

- **0x388**: Address/Status port (write register address here)
- **0x389**: Data port (write data value here)

---

## 🔗 Useful Links

- **VGMPF Wiki IMF Page**: https://www.vgmpf.com/Wiki/index.php?title=IMF
- **IMFCreator GitHub**: https://github.com/adambiser/imf-creator
- **Adlib Tracker II**: https://adlibtracker.net/
- **K1n9_Duk3's IMF Tools**: https://k1n9duk3.shikadi.net/imftools.html
- **Shikadi Modding Wiki**: https://moddingwiki.shikadi.net/
- **AdPlug Homepage**: https://adplug.github.io/

---

## 💡 Quick Start for Testing

**Recommended workflow:**

1. Visit **VGMPF.com** → "Wolfenstein 3D (DOS)" page
2. Download IMF music pack
3. Copy a few IMF files to `D:\ENGINE\DATA\`
4. Use `PLAYIMF.PAS` unit in your test program
5. Set playback rate to 700 Hz for Wolf3D music

**Sample IMF files from Wolfenstein 3D:**
- `NAZI_NOR.IMF` - Nazi March (iconic!)
- `WARMARCH.IMF` - War March
- `GETTHEM.IMF` - Get Them!
- `WONDERIN.IMF` - Wondering About My Loved Ones

**Sample IMF files from Commander Keen:**
- `KEEN4E.IMF` - Episode 4 ending theme
- `KEEN4T.IMF` - Episode 4 title theme

---

## ⚠️ Important Notes

### Playback Rate Matters!
Different games use different tick rates:
- **Commander Keen 4-6**: 560 Hz
- **Wolfenstein 3D/Blake Stone**: 700 Hz
- **Custom IMF files**: Specified by composer

Playing at wrong rate = wrong tempo!

### File Extensions
- `.IMF` - Standard IMF file
- `.WLF` - Wolfenstein-specific IMF (same format)
- `.KMF` - Keen-specific IMF (rare variant)

### Legal Considerations
- **Shareware games**: Free to download and extract
- **Commercial games**: Respect copyright when extracting music
- **Your own creations**: Fully free to use

---

**See also**: [IMF.md](../IMF.md) for format specification and PLAYIMF.PAS usage
