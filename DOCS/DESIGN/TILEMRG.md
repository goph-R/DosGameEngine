# Tilemap Layer Merger and Optimizer

## Overview

A Lazarus (Free Pascal) tool that analyzes multi-layer TMX tilemaps, merges overlapping tiles pixel-by-pixel, and generates optimized tilesets containing only the unique tile combinations actually used in the map. This reduces runtime rendering overhead and memory usage in the DOS engine.

## Problem Statement

**Current system** (TMXLOAD.PAS):
- Tiled map has many layers for level design convenience
- Layers are merged into 2 render layers (front/back) based on `<objectgroup>` position
- Merging uses simple tile ID override: higher layers overwrite lower layers
- **Issue**: Overlapping tiles waste memory - only top tile is visible, but both consume tileset space

**Example scenario:**
```
Cell (10, 5) in final front layer:
  Layer 0 (lowest):  Tile #42 (grass)
  Layer 1:           Tile #0  (empty)
  Layer 2:           Tile #83 (rock)
  Layer 3 (highest): Tile #0  (empty)

Current result: Tile #83 (rock overwrites grass)
Problem: Grass tile #42 is never visible but still in tileset
```

## Solution

**Tile Combination Merger**:
1. Parse TMX and merge layers into front/back (existing logic)
2. For each map cell, collect the **stack of visible tiles** (skip tile #0)
3. For each unique tile stack, **merge pixel data** from source tilesets
4. Generate new optimized tileset containing only merged combinations
5. Remap tile IDs in front/back layers to reference new tileset
6. Output optimized PKM tileset + updated map data

**Benefits**:
- Smaller tilesets (only combinations actually used)
- Single tile draw per cell instead of multiple overlays
- Reduced memory usage in DOS (fewer tiles loaded)
- Faster rendering (no transparency checks for merged areas)

## Architecture

### Tool: TILEMRG (Lazarus/FPC console application)

**Inputs**:
- TMX file path (e.g., `LEVEL1.TMX`)
- Output base name (e.g., `LEVEL1`)

**Outputs**:
- Optimized tileset: `{basename}_OPT.PKM`
- Optimized map data: `{basename}_OPT.MAP` (binary format for DOS loader)
- Mapping report: `{basename}_OPT.TXT` (human-readable tile mapping)

**Dependencies**:
- Free Pascal XML units (DOM, XMLRead)
- PKM loader/writer (ported from PKMLoad.pas)
- Image manipulation (pixel-level compositing)

### Data Structures

```pascal
type
  { RGB color for pixel operations }
  TRGBColor = record
    R, G, B: Byte;
  end;

  { Palette data (256 colors) }
  TPalette = array[0..255] of TRGBColor;

  { Raw image data }
  TImageData = record
    Width, Height: Word;
    Palette: TPalette;
    Pixels: PByte;  { Width * Height bytes }
  end;

  { Tileset metadata }
  TTileSetInfo = record
    FirstGID: Word;
    TileWidth, TileHeight: Word;
    TileCount: Word;
    ImagePath: string;
    ImageData: TImageData;
  end;

  { Tile stack (multiple tiles in one cell) }
  TTileStack = array of Word;  { Bottom-to-top tile IDs }

  { Unique tile combination }
  TTileCombination = record
    Stack: TTileStack;         { Source tile IDs (bottom to top) }
    NewTileID: Word;           { Assigned ID in optimized tileset }
    MergedPixels: PByte;       { Merged pixel data (TileWidth * TileHeight) }
  end;

  { Optimized map layer }
  TOptimizedLayer = record
    Width, Height: Word;
    Tiles: array of Word;      { Width * Height tile IDs }
  end;

  { Blocks layer (collision/game logic) }
  TBlocksLayer = record
    Width, Height: Word;
    Blocks: array of Byte;     { Width * Height block flags (0 or 1) }
  end;
```

### Processing Pipeline

#### Phase 1: Load and Parse TMX
1. Parse TMX file using DOM XML parser
2. Extract map dimensions (width, height, tile size)
3. Load tileset metadata (FirstGID, image paths, tile dimensions)
4. Parse all `<layer>` nodes:
   - Check for custom `blocks` layer property:
     ```xml
     <layer>
       <properties>
         <property name="blocks" value="" />
       </properties>
     </layer>
     ```
   - If found, preserve this layer separately (do NOT merge)
   - Find first `<objectgroup>` position for front/back separation
5. Separate remaining layers into front group and back group

**Output**: Layer data arrays, tileset metadata, blocks layer (if present)

#### Phase 2: Load Tileset Images
1. For each tileset, convert PNG path to PKM path (`.png` → `.pkm`)
2. Load PKM files using ported PKMLoad logic
3. Store pixel data and for each tileset.
4. **Palette handling**: Use palette from first tileset as master palette

**Output**: `TTileSetInfo` array with loaded image data

#### Phase 3: Merge Layers and Collect Tile Stacks
1. Create front/back layer buffers (Width × Height arrays)
2. For each layer in front group (highest index = highest priority):
   - **Skip layer with `blocks` layer property** (already preserved from Phase 1)
   - Overlay tiles onto front buffer
   - Track tile stack at each cell (preserve order for merging)
3. Repeat for back group
4. For each cell, build `TTileStack` of visible tiles (skip tile #0)

**Example**:
```
Cell (5, 10) front layer stack:
  [42, 83]  (grass #42 below, rock #83 on top)

Cell (5, 11) front layer stack:
  [42]      (only grass, no overlay)

Cell (5, 12) front layer stack:
  []        (empty, was tile #0)
```

**Output**: Front/back layer arrays with tile stacks per cell, blocks layer preserved as-is

#### Phase 4: Find Unique Tile Combinations
1. Scan all cells in front layer, collect unique `TTileStack` values
2. Scan all cells in back layer, collect unique `TTileStack` values
3. Remove duplicates (use hash map or sorted comparison)
4. Assign new tile IDs sequentially (starting at 1, 0 = empty)

**Example results**:
```
Combination #1: [42]     → New Tile ID: 1
Combination #2: [42, 83] → New Tile ID: 2
Combination #3: [15]     → New Tile ID: 3
Combination #4: [15, 22] → New Tile ID: 4
... (total unique combinations found)
```

**Output**: `TTileCombination` array

#### Phase 5: Merge Tile Pixels
For each `TTileCombination`:
1. Allocate buffer for merged tile (TileWidth × TileHeight bytes)
2. Initialize with transparent color (palette index 0)
3. For each tile ID in stack (bottom to top):
   - Find source tileset using FirstGID ranges
   - Calculate tile position in tileset image (column/row)
   - Extract tile pixels from tileset ImageData
   - Composite onto merged buffer (skip palette index 0 = transparent)
4. Store merged pixels in `MergedPixels` field

**Pixel compositing logic**:
```pascal
procedure MergeTilePixels(dest: PByte; src: PByte; size: Word);
var
  i: Word;
begin
  for i := 0 to size - 1 do
  begin
    if src[i] <> 0 then  { 0 = transparent }
      dest[i] := src[i];
  end;
end;
```

**Output**: `TTileCombination.MergedPixels` populated for all combinations

#### Phase 6: Generate Optimized Tileset
1. Calculate tileset image dimensions:
   - Tiles per row: 16 (arbitrary choice for square-ish layout)
   - Rows needed: `Ceiling(TileCount / 16)`
   - Image width: `16 * TileWidth`
   - Image height: `Rows * TileHeight`
2. Allocate tileset image buffer
3. Fill with transparent color (palette index 0)
4. For each `TTileCombination`:
   - Calculate tile position (row/column based on NewTileID)
   - Copy `MergedPixels` to tileset image at correct offset
5. Write PKM file with master palette

**Output**: `{basename}_OPT.PKM` file

#### Phase 7: Remap Tile IDs
1. Create optimized front/back layer buffers (Width × Height)
2. For each cell in original front layer:
   - Look up tile stack in `TTileCombination` array
   - Find matching combination by stack comparison
   - Write `NewTileID` to optimized front layer
3. Repeat for back layer
4. Handle empty cells: Write tile ID 0

**Output**: `TOptimizedLayer` for front and back

#### Phase 8: Write Output Files
**Optimized map binary** (`{basename}_OPT.MAP`):
```
Header:
  Signature: "TMAP" (4 bytes)
  Version: 1 (Word)
  MapWidth, MapHeight: Word
  TileWidth, TileHeight: Word
  LayerCount: Word (always 2: front + back)
  HasBlocks: Byte (0 = no blocks layer, 1 = blocks layer present)

Front Layer:
  Tiles: array[0..Width*Height-1] of Word

Back Layer:
  Tiles: array[0..Width*Height-1] of Word

Blocks Layer (optional, only if HasBlocks = 1):
  Blocks: array[0..Width*Height-1] of Byte (0 = passable, non-zero = blocked)
```

**Mapping report** (`{basename}_OPT.TXT`):
```
Tilemap Optimization Report
Input: LEVEL1.TMX
Output: LEVEL1_OPT.PKM, LEVEL1_OPT.MAP

Original tilesets: 4
Original total tiles: 512

Optimized tileset tiles: 87
Reduction: 83.0%

Tile combinations:
  #1: [42] (grass)
  #2: [42, 83] (grass + rock)
  #3: [15] (dirt)
  ...

Front layer: 1024 cells, 45 unique combinations
Back layer: 1024 cells, 32 unique combinations
Blocks layer: Present (352 blocked cells, 672 passable)
```

## Usage

### Command-Line Interface
```bash
# Basic usage
TILEMRG.EXE input.tmx output_base

# Example
TILEMRG.EXE DATA\LEVEL1.TMX DATA\LEVEL1

# Output:
#   DATA\LEVEL1_OPT.PKM  (optimized tileset)
#   DATA\LEVEL1_OPT.MAP  (binary map data)
#   DATA\LEVEL1_OPT.TXT  (report)
```

### Integration with DOS Engine
Create new loader unit `OPTMAP.PAS`:

```pascal
unit OptMap;

interface

uses VGA;

type
  TOptimizedMap = record
    Width, Height: Word;
    TileWidth, TileHeight: Word;
    FrontLayer: PWord;  { Width * Height }
    BackLayer: PWord;
    BlocksLayer: PByte; { Width * Height, nil if no blocks }
    Tileset: TImage;
  end;

function LoadOptimizedMap(const filename: string; var map: TOptimizedMap): Boolean;
procedure FreeOptimizedMap(var map: TOptimizedMap);
procedure DrawOptimizedLayer(const map: TOptimizedMap; layer: PWord;
                             x, y, width, height: Integer; fb: PFrameBuffer);

implementation

{ Load .MAP file and associated .PKM tileset }
function LoadOptimizedMap(const filename: string; var map: TOptimizedMap): Boolean;
var
  F: File;
  Sig: array[1..4] of Char;
  Ver, LayerCount: Word;
  HasBlocks: Byte;
  TilesetPath: string;
  TileCount, i: Word;
begin
  { Open MAP file }
  Assign(F, filename);
  Reset(F, 1);

  { Read header }
  BlockRead(F, Sig, 4);
  if Sig <> 'TMAP' then begin
    Close(F);
    LoadOptimizedMap := False;
    Exit;
  end;

  BlockRead(F, Ver, 2);
  BlockRead(F, map.Width, 2);
  BlockRead(F, map.Height, 2);
  BlockRead(F, map.TileWidth, 2);
  BlockRead(F, map.TileHeight, 2);
  BlockRead(F, LayerCount, 2);
  BlockRead(F, HasBlocks, 1);

  { Allocate layers }
  TileCount := map.Width * map.Height;
  GetMem(map.FrontLayer, TileCount * 2);
  GetMem(map.BackLayer, TileCount * 2);

  { Read layer data }
  BlockRead(F, map.FrontLayer^, TileCount * 2);
  BlockRead(F, map.BackLayer^, TileCount * 2);

  { Read blocks layer if present }
  if HasBlocks = 1 then
  begin
    GetMem(map.BlocksLayer, TileCount);
    BlockRead(F, map.BlocksLayer^, TileCount);
  end
  else
    map.BlocksLayer := nil;

  Close(F);

  { Load tileset PKM }
  TilesetPath := Copy(filename, 1, Pos('.', filename) - 1) + '.PKM';
  if not LoadPKM(TilesetPath, map.Tileset) then begin
    FreeMem(map.FrontLayer);
    FreeMem(map.BackLayer);
    LoadOptimizedMap := False;
    Exit;
  end;

  LoadOptimizedMap := True;
end;

{ Render layer with camera offset }
procedure DrawOptimizedLayer(const map: TOptimizedMap; layer: PWord;
                              x, y, width, height: Integer; fb: PFrameBuffer);
var
  col, row, tileID, tileCol, tileRow: Integer;
  srcRect: TRectangle;
  tilesPerRow: Integer;
begin
  tilesPerRow := map.Tileset.Width div map.TileWidth;

  for row := 0 to height - 1 do
  begin
    for col := 0 to width - 1 do
    begin
      { Get tile ID }
      tileID := layer[(y + row) * map.Width + (x + col)];

      if tileID > 0 then
      begin
        { Calculate tile position in tileset (16 tiles per row) }
        tileCol := (tileID - 1) mod tilesPerRow;
        tileRow := (tileID - 1) div tilesPerRow;

        { Setup source rectangle }
        srcRect.X := tileCol * map.TileWidth;
        srcRect.Y := tileRow * map.TileHeight;
        srcRect.Width := map.TileWidth;
        srcRect.Height := map.TileHeight;

        { Draw tile }
        PutImageRect(map.Tileset, srcRect, col * map.TileWidth,
                     row * map.TileHeight, True, fb);
      end;
    end;
  end;
end;

procedure FreeOptimizedMap(var map: TOptimizedMap);
begin
  FreeMem(map.FrontLayer);
  FreeMem(map.BackLayer);
  if map.BlocksLayer <> nil then
    FreeMem(map.BlocksLayer);
  FreeImage(map.Tileset);
end;

end.
```

**Usage in game**:
```pascal
var
  Map: TOptimizedMap;
  CameraX, CameraY: Integer;

{ Helper function to check collision at world position }
function IsBlocked(const map: TOptimizedMap; x, y: Integer): Boolean;
var
  tileX, tileY: Integer;
  index: Word;
begin
  IsBlocked := False;

  { No blocks layer = everything passable }
  if map.BlocksLayer = nil then Exit;

  { Convert world position to tile coordinates }
  tileX := x div map.TileWidth;
  tileY := y div map.TileHeight;

  { Bounds check }
  if (tileX < 0) or (tileX >= map.Width) or
     (tileY < 0) or (tileY >= map.Height) then
  begin
    IsBlocked := True;  { Out of bounds = blocked }
    Exit;
  end;

  { Check blocks layer }
  index := tileY * map.Width + tileX;
  IsBlocked := map.BlocksLayer[index] <> 0;
end;

begin
  LoadOptimizedMap('DATA\LEVEL1_OPT.MAP', Map);

  { Game loop }
  while Running do
  begin
    { Check collision before moving player }
    if not IsBlocked(Map, PlayerX + VelX, PlayerY) then
      PlayerX := PlayerX + VelX;
    if not IsBlocked(Map, PlayerX, PlayerY + VelY) then
      PlayerY := PlayerY + VelY;

    { Render visible portion }
    DrawOptimizedLayer(Map, Map.BackLayer, CameraX div 16, CameraY div 16,
                       20, 12, FrameBuffer);  { 20x12 tiles visible }

    { ... render sprites/objects ... }

    DrawOptimizedLayer(Map, Map.FrontLayer, CameraX div 16, CameraY div 16,
                       20, 12, FrameBuffer);
  end;

  FreeOptimizedMap(Map);
end;
```

## Performance Considerations

**Memory savings example** (32x32 tile map with 4 original tilesets):
- Original: 4 tilesets × 128 tiles × 256 bytes = 131,072 bytes
- Optimized: 87 unique combinations × 256 bytes = 22,272 bytes
- **Savings**: 108,800 bytes (83%)

**Runtime performance**:
- Single tile draw per cell instead of 2-4 overlapping draws
- No transparency checking for merged regions
- Better cache locality (smaller tileset)

**Tool performance**:
- Lazarus/FPC compiled binary is fast (native code)
- XML parsing is negligible for typical map sizes
- Pixel merging is linear in tile count (< 1 second for typical maps)

## Edge Cases and Considerations

1. **Empty cells**: Tile ID 0 always represents empty (not in optimized tileset)
2. **Single-tile cells**: No merging needed, just remap to new tileset
3. **Palette conflicts**: First tileset palette is used as master (all tilesets should share palette)
4. **Maximum tiles**: DOS loader supports up to 65,535 tiles (Word limit)
5. **Tileset dimensions**: Must fit in 64KB segment (typical: 256×256 pixels max)
6. **PNG to PKM conversion**: Must be done beforehand (TILEMRG expects PKM files exist)
7. **Blocks layer**: Layer with `blocks="1"` attribute is preserved as-is, not merged or optimized. Tile IDs in blocks layer are converted to simple 0/non-zero flags (0=passable, non-zero=blocked). Only one blocks layer per TMX file is supported.

## Future Enhancements

1. **Palette optimization**: Merge palettes from multiple tilesets intelligently
2. **Tile deduplication**: Detect identical tiles across different tilesets
3. **Compression**: Apply RLE or custom compression to .MAP output
4. **Batch processing**: Process multiple TMX files in one run
5. **Reverse mapping**: Generate lookup table for "original tile → merged combinations"
6. **Visualization**: Output preview PNG showing optimized tileset layout

## Testing Strategy

1. **Unit tests**:
   - Tile stack comparison/hashing
   - Pixel merging with transparency
   - PKM read/write round-trip

2. **Integration tests**:
   - Simple 2×2 map with known combinations
   - Large map stress test (1024×1024 tiles)
   - Edge case maps (all empty, single tile, max combinations)

3. **Visual verification**:
   - Compare DOS rendering of original TMX vs optimized MAP
   - Should be pixel-perfect identical

## Example Workflow

```bash
# 1. Design level in Tiled with many layers
#    - Create visual layers: Background, Ground, Walls, Decorations, Foreground, etc.
#    - Add <objectgroup> layer to separate front/back rendering
#    - Create collision layer: Add a tile layer named "Collision"
#    - In Tiled, select Collision layer → Layer Properties → Add custom property:
#      Name: blocks, Type: bool, Value: true
#    - This adds blocks="1" attribute to the TMX XML
#    - Paint collision tiles where player should not walk (any non-zero tile ID = blocked)
#    Save as DATA\DUNGEON.TMX

# 2. Export tilesets from Tiled as PNG
#    Convert to PKM using existing tools

# 3. Run optimizer
TILEMRG.EXE DATA\DUNGEON.TMX DATA\DUNGEON
#    Outputs: DUNGEON_OPT.PKM, DUNGEON_OPT.MAP, DUNGEON_OPT.TXT

# 4. Copy to DOS environment
COPY DATA\DUNGEON_OPT.* D:\ENGINE\DATA\

# 5. Load in game and use collision detection
#    LoadOptimizedMap('DATA\DUNGEON_OPT.MAP', Map);
#    if IsBlocked(Map, PlayerX, PlayerY) then { handle collision }
```

## Conclusion

This optimizer bridges the gap between rich multi-layer level design in Tiled and efficient single-layer rendering in the DOS engine. By pre-merging tiles at build time, we eliminate runtime overhead while preserving the designer's workflow.

The tool runs on modern systems (Lazarus/Windows), making it easy to iterate on level design without DOS environment constraints.
