# 🟨 TileMap handling

The DOS Game Engine can load `.tmx` files (Tiled Map Editor XML format) with basic functionality found in `TMXLOAD.PAS`.

## 🎯 Layer Merging System

The loader can read **multiple `<layer>` tags** from a TMX file, but **merges them into exactly 2 layers** in the final `TTileMap` structure:

- **Front Layer** (index 0): All layers before the first `<objectgroup>` tag
- **Back Layer** (index 1): All layers after the first `<objectgroup>` tag

**Merging behavior:**
- When multiple source layers overlap at the same tile position, the **lower index has priority** (earlier layers draw on top)
- If no `<objectgroup>` tag exists, all layers merge into the front layer only
- Empty tiles (ID = 0) are treated as transparent during merging

This allows complex multi-layer TMX files created in Tiled to be simplified for efficient DOS rendering. 

## 🧱 Structures

```pascal
type TTileSet = record
  FirstGID Word;       { The first tile ID in the set }
  TileWidth: Byte;     { Width of one tile }
  TileHeight: Byte;    { Height of one tile }
  Columns: Byte;       { Tile columns count }
  Image: TImage;       { The image that holds the graphics of the tiles. }
end;

const TileMap_MaxTileSets = 4;

const TileMapLayer_Front = 0;
const TileMapLayer_Back = 1;

type TTileMap = record
  Width: Word;                    { Width of the tile map (in tiles) }
  Height: Word;                   { Height of the tile map (in tiles) }
  TileSetCount: Byte;             { How many tilesets are present }
  TileSets: array[0..TileMap_MaxTileSets] of TTileset;
  Layers: array[0..1] of PWord;   { Back and front layers }
                                  { Every word represents a TileID }
end;
```

**TTileSet** represents a tileset image referenced by the map. Each tileset contains:
- `FirstGID`: The starting tile ID for this tileset (e.g., if FirstGID=1, tile ID 1 is the first tile)
- `TileWidth/TileHeight`: Dimensions of individual tiles in pixels
- `Columns`: Number of tile columns in the tileset image (used to calculate tile positions)
- `Image`: The `TImage` structure holding the actual tileset graphics (see VGA.PAS)

**TTileMap** stores the final merged map data with exactly 2 layers. Each layer is a dynamically allocated array of `Word` values (tile IDs), with dimensions `Width × Height`. Memory layout is row-major: `Layers[0]^[y * Width + x]` accesses tile at position (x, y).

Every `/` character in the paths in the TMX files should be replaced with `\` because of the DOS paths.

## 🔥 Functions

```pascal
function GetLoadTileMapError(): String
```

Returns the last error on TileMap loading, gets it from a unit scoped variable: `LoadTileMapError: String`.

```pascal
function LoadTileMap(const FilePath: String; var TileMap: TTileMap): Boolean
```

Clears the `LoadTileMapError` variable, then loads the content of the `.tmx` file from the `FilePath` to an `XMLNode` (see MINIXML.PAS). On any fail sets the `LoadTileMapError` and returns `False.`

Searches for the `<map>` tag, if not presents the load fails. Sets the `TileMap.Width` and `TileMap.Height` via the `<map>` tag's `width` and `height` attributes, if any of these missing: the load fails.

Searches for the `<tileset>` tags in the `<map>` node and calls the `LoadTileSet` for each. If a tileset load fails, returns with `False`. The `FolderPath` parameter will be the folder from the `FilePath`. **At least one tileset must be present** - if no tilesets are found, the load fails with error "No tilesets found".

Searches for the `<layer>` tags in the `<map>` node and calls the `LoadTileMapLayer` for each.

**Layer separation logic:**
- Scans for the first `<objectgroup>` tag to determine the split point
- All layers **before** the objectgroup merge into `TileMapLayer_Front` (index 0)
- All layers **after** the objectgroup merge into `TileMapLayer_Back` (index 1)
- If no objectgroup exists, all layers merge into front only

**Merging priority example:**

Given this layer order in a TMX file:

```xml
<layer id="0"><data encoding="csv">...</data></layer> <!-- Front source #0 (highest priority) -->
<layer id="1"><data encoding="csv">...</data></layer> <!-- Front source #1 -->
<objectgroup id="2">...</objectgroup>                 <!-- Split point -->
<layer id="3"><data encoding="csv">...</data></layer> <!-- Back source #0 (highest priority) -->
<layer id="4"><data encoding="csv">...</data></layer> <!-- Back source #1 -->
```

At tile position (x, y):
- If Front #0 has tile ID > 0, use it (highest priority)
- Else if Front #1 has tile ID > 0, use it
- Else position is empty (ID = 0)

The same priority logic applies to back layers. **Lower index = higher priority** during merging.

```pascal
function LoadTileSet(const FolderPath: String; const XMLNode: PXMLNode; var TileSet: TTileSet): Boolean
```

Loads a `<tileset>` XML node and populates the `TileSet` record. Extracts `firstgid`, `tilewidth`, `tileheight`, and `columns` attributes from the tileset tag. If any of these attributes missing sets the error message and returns `False`. Loads the tileset image from `FolderPath` using the `<image source="...">` child node, replaces the file extension with `pkm`, for example if the `source` is `tileset.png`, the FolderPath is `../DATA` the the full path of the image will be `..\DATA\tileset.pkm`. Loaded by the `PKMLoad` unit's `LoadPKM` function. Returns `False` and sets `LoadTileMapError` if any required attribute or the image is missing.

```pascal
procedure LoadTileMapLayer(const XMLNode: PXMLNode; var TileMap: TTileMap; const Layer: Byte)
```

Processes a `<layer>` tag, only with `<data encoding="csv">` tags (Base64 and compressed formats are unsupported).

```pascal
procedure DrawTileMapLayer(
  var TileMap: TTileMap; 
  Layer: Byte; X: Word; Y: Word; Width: Word; Height: Word;
  FrameBuffer: PFrameBuffer
)
```

Renders the specified layer to the framebuffer. Iterates through the specific tiles in the layer (based on `X`, `Y`, `Width`, `Height` parameters), calculates the tileset based on the `FirstGID` then the source tile coordinates (TRect), then blits each tile to the destination position and framebuffer with the `PutImageRect` (see VGA.PAS).

**Parameters:**
- `Layer`: Use `TileMapLayer_Back` (1) or `TileMapLayer_Front` (0)
- `X`: The start tile X position
- `Y`: The start tile Y position
- `Width`: The width for the drawing loop (in tiles)
- `Height`: The height for the drawing loop (in tiles)
- `FrameBuffer`: Destination buffer (320x200)

**Rendering behavior:**
- Tile ID 0 is treated as empty/transparent (no draw)
- Tiles are clipped at screen boundaries automatically
- Only renders that is visible

Note on the `FirstGID`: needs a separate function that has a fast look up algorithm to decide which TileSet should be used, called before every tile render.

`procedure FreeTileMap(var TileMap: TTileMap)`

Frees dynamically allocated layer memory. Calls `FreeMem` on both layer arrays if they are not `nil`, then sets pointers to `nil`. **Must be called** before program exit to prevent memory leaks. Frees tileset images memory too.

## 📝 Usage Example

```pascal
program TileMapDemo;
uses VGA, Image, TMXLoad;

var
  Map: TTileMap;
  TileSet: TTileSet;
  Buffer: PFrameBuffer;

begin
  { Initialize graphics }
  InitVGA;
  Buffer := CreateFrameBuffer;

  { Load tilemap from TMX file }
  if LoadTileMap('DATA\LEVEL1.TMX', Map) then
  begin
    { Render back layer (background scenery) }
    DrawTileMapLayer(Map, TileMapLayer_Back, 0, 0, 20, 11, Buffer);

    { TODO: Draw game sprites here }

    { Render front layer (foreground objects) }
    DrawTileMapLayer(Map, TileMapLayer_Front, 0, 0, 20, 11, Buffer);

    { Display result }
    RenderFrameBuffer(Buffer);
    ReadLn;

    { Cleanup }
    FreeTileMap(Map);
  end
  else
    WriteLn('Error: ', GetLoadTileMapError());

  FreeFrameBuffer(Buffer);
  CloseVGA;
end.
```

## 🗺️ Tile ID Mapping

Each tile ID in the layer data maps to a specific position in the tileset image:

**Formula:**
```
TileIndex = TileID - TileSet.FirstGid
Row = TileIndex div TileSet.Columns
Col = TileIndex mod TileSet.Columns
SourceX = Col * TileSet.TileWidth
SourceY = Row * TileSet.TileHeight
```

**Example:**
- TileSet: `FirstGid=1`, `Columns=8`, `TileWidth=16`, `TileHeight=16`
- Map contains Tile ID `15`
- Calculation:
  - `TileIndex = 15 - 1 = 14`
  - `Row = 14 div 8 = 1`
  - `Col = 14 mod 8 = 6`
  - Source position: `(96, 16)` in tileset image

## 🎨 TMX Format Support

**Supported features:**
- CSV-encoded tile data (`<data encoding="csv">`)
- Multiple tilesets per map
- Multiple layers (merged to 2 final layers)
- Objectgroup layer separator
- Tile dimensions and map dimensions

**Unsupported features:**
- Base64 encoding
- Compression (gzip, zlib)
- Infinite maps
- Tile animations
- Tile properties/custom data
- Isometric/hexagonal orientations (orthogonal only)
- External TSX tileset files (only internal)

**TMX format info:** https://doc.mapeditor.org/en/stable/reference/tmx-map-format/

## 📐 Coordinate Systems

**Tile coordinates:** Map positions measured in tiles (0 to Width-1, 0 to Height-1)

**Pixel coordinates:** Screen positions measured in pixels (0 to 319, 0 to 199 for Mode 13h)

**Conversion:**
```pascal
PixelX := TileX * TileSet.TileWidth;
PixelY := TileY * TileSet.TileHeight;
```

## 💾 Memory Management

**Memory usage per map:**
```
Bytes = Width × Height × 2 layers × 2 bytes per tile
```

**Example:** 64×64 tile map = 64 × 64 × 2 × 2 = **16,384 bytes** (16 KB)

**DOS constraints:**
- The TMX file maximum size is 64KB (see MINIXML.PAS)
- Tileset images also consume memory (see LOADPKM.PAS, VGA.PAS)

**Best practices:**
- Always call `FreeTileMap` before exit
- Free unused tilesets with `FreeTileSet`

## ⚡ Performance Considerations

**Rendering speed:**
- Drawing a full 20×12 screen of 16×16 tiles = 240 tile blits per frame
- At 60 FPS: 14,400 tile copies per second
- Use VSync (`WaitForVSync`) to prevent tearing

**Optimization tips:**
- Pre-calculate visible tile range based on screen size
- Only redraw changed tiles (dirty rectangle tracking)
- Cache tileset row offsets to avoid multiplication in inner loops
- Consider pre-rendering static backgrounds to a single buffer

## 🔧 Troubleshooting

**"No <map> tag found"**
- TMX file is corrupted or not valid XML
- Wrong file format (not a Tiled map file)

**"Missing width/height attributes"**
- Map tag must have both `width="X"` and `height="Y"` attributes
- Check TMX file structure in text editor

**"No tilesets found"**
- TMX file must contain at least one `<tileset>` tag
- Check if tileset definition exists in the map file
- Verify `<tileset>` tags are direct children of `<map>`

**"Failed to load tileset"**
- Tileset image file not found (check relative path in `<image source="...">`)
- Missing required tileset attributes (`firstgid`, `tilewidth`, `tileheight`, `columns`)

**"Unsupported encoding"**
- TMX must use CSV encoding
- In Tiled: Map → Map Properties → Tile Layer Format → **CSV**

**"Out of memory"**
- Map too large for DOS conventional memory
- Free unused resources before loading
- Consider using XMS for large maps

**Tiles render incorrectly:**
- Verify `TileSet.Columns` matches actual tileset image width
- Check `FirstGid` matches tileset configuration
- Ensure tile IDs in map data are valid for the tileset

## 📄 Example TMX File

Minimal working TMX file demonstrating 2-layer merging:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal"
     renderorder="right-down" width="20" height="15"
     tilewidth="16" tileheight="16" infinite="0">

  <tileset firstgid="1" name="Terrain" tilewidth="16" tileheight="16"
           tilecount="64" columns="8">
    <image source="TILES.PNG" width="128" height="128"/>
  </tileset>

  <!-- Front layer: Decorations -->
  <layer id="1" name="Decorations" width="20" height="15">
    <data encoding="csv">
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,5,0,0,0,0,0,0,0,0,0,0,0,5,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
...
    </data>
  </layer>

  <!-- Front layer: Trees (overlays decorations) -->
  <layer id="2" name="Trees" width="20" height="15">
    <data encoding="csv">
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,9,10,0,0,0,0,0,9,10,0,0,0,0,0,0,
0,0,0,0,0,17,18,0,0,0,0,0,17,18,0,0,0,0,0,0,
...
    </data>
  </layer>

  <!-- Separator: Everything after this goes to back layer -->
  <objectgroup id="3" name="Objects"/>

  <!-- Back layer: Ground tiles -->
  <layer id="4" name="Ground" width="20" height="15">
    <data encoding="csv">
1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
...
    </data>
  </layer>

</map>
```

**Result:** "Decorations" and "Trees" merge into front layer (trees have priority), "Ground" becomes back layer.