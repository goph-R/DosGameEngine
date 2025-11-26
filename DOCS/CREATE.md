
# 🎨 Creating Assets

## PCX Images
Use [GrafX2](http://grafx2.chez.com/) the DOS pixel art editor (Windows/Linux/Mac):
1. Draw with 256 colors (any resolution supported)
2. Save as PCX format (RLE-compressed)
   - Common sizes: 320×200 (full screen), 32×32 (sprites), 16×16 (tiles)

## VOC Sound Effects
Use [Audacity](https://www.audacityteam.org/) (Windows/Linux/Mac):
1. Import audio (WAV, MP3, etc.)
2. **Tracks → Mix → Mix Stereo Down to Mono**
3. **Tracks → Resample → 11025 Hz** (or 22050 Hz)
4. **File → Export → Export Audio**
   - Format: "Other uncompressed files"
   - Header: "VOC (Creative Labs)"
   - Encoding: "Unsigned 8-bit PCM"

## HSC Music
Use one of the following:
1. [Adlib Tracker II](https://adlibtracker.net/) - More modern approach (Windows/Linux)
2. [HSC-tracker](https://demozoo.org/productions/293837/) - The original HSC tracker (only DOS)

## XML Configuration Files
Create game configuration files with any text editor (this is just an example):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<game version="1.0">
  <levels>
    <level id="1" name="Forest" difficulty="easy">
      <music>FOREST.HSC</music>
      <background>FOREST.PCX</background>
    </level>
  </levels>
  <sprites>
    <sprite id="player" file="PLAYER.PCX" width="32" height="32" />
  </sprites>
</game>
```

**Features:**
- DOM-style tree navigation
- Fast attribute lookup (O(1) hash map)
- Supports files up to ~64KB
- Automatic text storage optimization
- See [DOCS/MINIXML.md](DOCS/MINIXML.md) for complete API reference

## TMX tilemaps

Use [Tiled](https://www.mapeditor.org/) a full-featured level editor (Windows/Linux/Mac).
See the restrictions at the [tilemap documentation](DOCS/TILEMAP.md).

