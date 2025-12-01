Here’s a design doc-style description of how to build this **Tiled TMX → optimized 2-layer + composite tilesets** tool using only Lazarus / FPC built-ins.

---

## 1. Goal and context

You already have a DOS tile engine that:

* Loads TMX (Tiled) maps via `TMXLOAD.PAS` using your MiniXML.
* Merges *any number* of TMX layers into exactly **2 layers** in `TTileMap`:

  * Front (index 0) – layers before first `<objectgroup>`
  * Back (index 1) – layers after first `<objectgroup>` ([GitHub][1])
* Supports **multiple tilesets**, described by:

```pascal
type
  TTileSet = record
    FirstGID: Word;
    TileWidth: Byte;
    TileHeight: Byte;
    Columns: Byte;
    Image: TImage;      { holds the tileset graphics }
  end;

const
  TileMap_MaxTileSets = 4;

type
  TTileMap = record
    Width, Height : Word;
    TileSetCount  : Byte;
    TileSets      : array[0..TileMap_MaxTileSets] of TTileSet;
    Layers        : array[0..1] of PWord;     { final Back/Front }
    BlocksLayer   : PByteArray;               { collision data }
    BlocksTilesetFirstGID: Word;
  end;
```

([GitHub][1])

Your constraints:

* **Tileset images should be small** for DOS:

  * Preferred max size per tileset image: **256×240** (fits under 64K in Mode 13h).
  * Hard maximum you mentioned: **320×200** if needed.
* Engine expects **PCX** on disk; `LoadTileSet` replaces TMX `<image source="something.png">` with `something.pcx` when loading. ([GitHub][1])
* TMX constraints: CSV only, internal tilesets, orthogonal, etc. ([GitHub][1])

Your new idea:

> Load a multi-layer TMX in a Lazarus tool, collapse all visual layers into 2 (Front/Back), **detect unique tile stacks**, render each stack into a composite tile, and create one (or more) compact tileset(s) containing only those composite tiles.

So the engine still sees a normal TMX+PCX setup – just much more optimized.

---

## 2. Tool overview (what it does)

This Lazarus tool is a **pre-processor / optimizer** that runs on your dev machine (not in DOS):

**Input:**

* A TMX map created in Tiled using PNG tilesets (normal workflow).
* Matching PCX versions for each tileset (for DOS; can be generated separately).

**Output:**

* New **optimized TMX**:

  * Only 2 visual layers: `Front`, `Back`.
  * Visual layers reference one or more new “composite” tilesets.
  * Blocks layer + Blocks tileset left intact.
* New **PCX tileset image(s)**:

  * Each at most 256×240 (or 320×200) in size.
  * Contains all the composite tiles (unique tile stacks).
* Optional: PNG variants for Tiled preview (same layout as PCX).

Everything is implemented with Lazarus / FPC built-ins:

* XML: `DOM`, `XMLRead`, `XMLWrite`
* Graphics: `Graphics` (TBitmap/TCanvas), `IntfGraphics` + `LCLType`
* PCX: `FPImage`, `FPReadPCX`, `FPWritePCX`
* Maps/dicts: FPC generics (`FGL`) or `TFPHashList`

---

## 3. High-level pipeline

1. **Load TMX** into a DOM (`TXMLDocument`).
2. **Extract tileset metadata** (FirstGID, tile size, columns, image source).
3. **Load tileset images** into `TBitmap` (from PNG or PCX).
4. **Classify layers**:

   * Visual Front layers (before first `<objectgroup>`).
   * Visual Back layers (after first `<objectgroup>`).
   * Collision blocks layers (layers with `blocks` property). ([GitHub][1])
5. For each tile coordinate `(x, y)`:

   * Build **Back stack** = list of GIDs from all Back layers at `(x, y)` (bottom → top).
   * Build **Front stack** similarly.
6. For each stack:

   * If stack is empty → tile ID 0 in that layer.
   * Otherwise:

     * Check if this exact stack was already seen (using a map/dict).
     * If new: **render composite tile** into an atlas tileset.
     * Assign a new global TileID (GID) pointing into that atlas tileset.
7. When tileset atlas reaches capacity (e.g. 256×240 → max tiles), start a **new** tileset (up to 4).
8. Build the new TMX DOM:

   * Replace visual `<layer>` tags with exactly **two** layers (`Front`, `Back`) using our new IDs.
   * Insert new `<tileset>` tags describing the optimized tilesets.
   * Keep `<objectgroup>` and Blocks tileset / Blocks layer as-is.
9. Save:

   * `*.tmx` via `WriteXMLFile`.
   * `*.pcx` via `TFPWriterPCX`.

The result is 100% compatible with your `LoadTileMap` logic: it will still merge “all front layers” and “all back layers”, but now each of those is just a single pre-merged layer.

---

## 4. Important limits: tileset capacity

Given:

* `TileWidth`, `TileHeight` (from TMX `<map>` and `<tileset>`; you’re using 16×16).
* Tileset image maximum size: e.g. `TilesetMaxWidth = 256`, `TilesetMaxHeight = 240`.

Capacity of one tileset:

```text
Columns = TilesetMaxWidth  div TileWidth   (e.g. 256/16 = 16)
Rows    = TilesetMaxHeight div TileHeight  (e.g. 240/16 = 15)
MaxTiles = Columns * Rows                 (e.g. 16 * 15 = 240 tiles)
```

You must ensure:

* `MaxTiles` ≥ number of unique stacks per tileset.
* Total tilesets ≤ `TileMap_MaxTileSets` (4).

A simple strategy:

* Use **one composite tileset** for both front and back stacks (shared).
* If unique stack count > 240, create tileset #2, etc., but never exceed 4.

---

## 5. Data structures (Lazarus side)

Use plain records and dynamic arrays.

### 5.1. Tileset info

```pascal
type
  TTileSetInfo = record
    Name        : string;
    FirstGID    : Integer;
    TileWidth   : Integer;
    TileHeight  : Integer;
    Columns     : Integer;
    ImageSource : string;   // image source from TMX
    Bitmap      : TBitmap;  // loaded tileset graphics
  end;

  TTileSetInfoArray = array of TTileSetInfo;
```

### 5.2. Stack representation

At Lazarus tool level you can use generics:

```pascal
type
  TTileID = Integer;
  TTileStack = array of TTileID;  // [0..N-1], bottom -> top
```

For uniqueness, encode the stack as a string key:

```pascal
function StackKey(const S: TTileStack): string;
```

Mapping stack → global ID (GID):

```pascal
uses FGL;

type
  TStringToIntMap = specialize TFPGMap<string, Integer>;
```

You’ll have:

```pascal
var
  StackToGID: TStringToIntMap;  // all stacks (front+back) -> new GID
```

And layers as 2D arrays of final GIDs:

```pascal
type
  TTileIDGrid = array of array of TTileID;  // [Y][X]

var
  FrontLayer, BackLayer: TTileIDGrid;
```

### 5.3. Composite tileset atlas management

```pascal
type
  TAtlasTileSet = record
    FirstGID    : Integer;
    Columns     : Integer;
    Rows        : Integer;
    TileWidth   : Integer;
    TileHeight  : Integer;
    MaxTiles    : Integer;
    UsedTiles   : Integer;
    Bitmap      : TBitmap;      // the atlas
    Name        : string;
    ImageSource : string;       // something like "tiles_opt_0.png"
  end;

  TAtlasArray = array of TAtlasTileSet;
```

Each new unique stack gets mapped to:

* `AtlasIndex` (which atlas).
* `LocalTileIndex` within that atlas.
* Global GID = `Atlas.FirstGID + LocalTileIndex`.

---

## 6. Step-by-step algorithm

### 6.1. Load TMX with DOM

```pascal
uses DOM, XMLRead;

var
  Doc: TXMLDocument;
begin
  ReadXMLFile(Doc, 'MAP.TMX');
end;
```

From the `<map>` node:

* `width`, `height` → `MapWidth`, `MapHeight` (in tiles).
* `tilewidth`, `tileheight` → `TileW`, `TileH`.

### 6.2. Read tilesets and load images

Loop `<tileset>` children of `<map>`:

* Read `firstgid`, `name`, `tilewidth`, `tileheight`, `columns`.
* Find `<image>` child, get `source` attribute.

For each:

```pascal
SetLength(TileSets, Count+1);
with TileSets[Count] do
begin
  Name        := ...;
  FirstGID    := ...;
  TileWidth   := ...;
  TileHeight  := ...;
  Columns     := ...;
  ImageSource := ImageSourceFromTMX;

  Bitmap := TBitmap.Create;
  Bitmap.LoadFromFile(ResolvePath(ImageSource)); // PNG or PCX
end;
```

You’ll probably have:

* Visual tilesets (normal graphics).
* A special **Blocks** tileset used only for collision (by name “Blocks”). ([GitHub][1])

For the optimizer:

* Only **visual** tilesets participate in stack rendering.
* Blocks tileset is passed through unchanged; its tiles are never stacked visually.

### 6.3. Classify layers

Iterate `<layer>` and `<objectgroup>` children of `<map>` in order.

* Find index of first `<objectgroup>`; that’s the split point: layers before → **Front**, after → **Back**. ([GitHub][1])
* Detect **blocks** layers: `<layer>` with custom property `blocks=1` etc. (per your spec). ([GitHub][1])

  * Their data is used only for collision, not for visual stacks.

For each visual `<layer>`:

* Read `<data encoding="csv">` content.
* Parse into a 2D array `LayerGIDs[Y][X]`.

You may keep:

```pascal
type
  TLayerInfo = record
    Name     : string;
    Kind     : (lkFront, lkBack, lkBlocks, lkIgnored);
    GIDs     : TTileIDGrid; // empty for blocks or ignored
  end;

  TLayerArray = array of TLayerInfo;
```

### 6.4. Build Back/Front stacks per tile

Initialize for each `(x, y)`:

```pascal
SetLength(BackStackGrid, MapHeight, MapWidth);
SetLength(FrontStackGrid, MapHeight, MapWidth);
```

For each visual layer:

```pascal
for y := 0 to MapHeight-1 do
  for x := 0 to MapWidth-1 do
  begin
    gid := Layer.GIDs[y][x];
    if gid <> 0 then
      if Layer.Kind = lkBack then
        AppendToStack(BackStackGrid[y][x], gid)
      else if Layer.Kind = lkFront then
        AppendToStack(FrontStackGrid[y][x], gid);
  end;
```

Order is automatically correct: later layers overwrite earlier ones, and we add them in layer order, so bottom → top is the order of push.

### 6.5. Deduplicate stacks and assign GIDs

Initialize:

```pascal
StackToGID := TStringToIntMap.Create;
NextGID := 1;          // you will later partition this into tilesets
SetLength(FrontLayer, MapHeight, MapWidth);
SetLength(BackLayer, MapHeight, MapWidth);
```

Then:

```pascal
procedure AssignLayerFromStacks(const StackGrid: array of array of TTileStack;
                                var OutLayer: TTileIDGrid);
var
  x, y: Integer;
  key : string;
  gid : Integer;
  s   : TTileStack;
begin
  for y := 0 to MapHeight-1 do
    for x := 0 to MapWidth-1 do
    begin
      s := StackGrid[y][x];
      if Length(s) = 0 then
      begin
        OutLayer[y][x] := 0;  // empty tile
        Continue;
      end;

      key := StackKey(s);
      if StackToGID.Find(key, gid) then
        OutLayer[y][x] := gid
      else
      begin
        gid := NextGID;
        Inc(NextGID);
        StackToGID.Add(key, gid);
        OutLayer[y][x] := gid;
      end;
    end;
end;
```

Call for `BackStackGrid` → `BackLayer`, and `FrontStackGrid` → `FrontLayer`.

Now:

* All non-empty stacks have a unique global ID.
* The total used GIDs = `NextGID - 1`.

### 6.6. Pack GIDs into one or more atlas tilesets

You now know how many unique composite tiles you have: `TileCount := NextGID - 1`.

Goal: distribute these GIDs into up to 4 tileset atlases, each with capacity `MaxTiles`.

Simple sequential packing:

```pascal
var
  Atlases: TAtlasArray;
  gid, atlasIndex, localIndex: Integer;
```

Algorithm:

1. Create first atlas:

   * `Columns := TilesetMaxWidth div TileW;`
   * `Rows    := TilesetMaxHeight div TileH;`
   * `MaxTiles := Columns * Rows;`
   * `FirstGID := 1;`
2. For each `gid` in `1..TileCount`:

   * `if Atlases[Current].UsedTiles = Atlases[Current].MaxTiles`:

     * Start a **new** atlas: `FirstGID := Prev.FirstGID + Prev.MaxTiles;`
   * `localIndex := Atlases[Current].UsedTiles;`
   * Increment `UsedTiles`.
   * Record: `GIDToAtlasIndex[gid] := Current;`
   * Record: `GIDToLocalIndex[gid] := localIndex;`

Later, when rendering composite tiles, you’ll draw each stack into the corresponding atlas at:

```pascal
Col := localIndex mod Columns;
Row := localIndex div Columns;
DestX := Col * TileWidth;
DestY := Row * TileHeight;
```

### 6.7. Render composite tiles into atlas bitmaps

For each unique stack key (you can iterate `StackToGID` map):

1. Get `gid`.
2. Determine `atlasIndex`, `localIndex`, and `DestRect` in bitmap.
3. Reconstruct the stack `TTileStack` from the key (or store the stacks in a parallel array when assigning GIDs).
4. Render:

   * Create a temporary `TBitmap` of size `TileW×TileH`.
   * Clear it with transparent color (e.g. index 0 or RGB magenta).
   * For each tileID in the stack from bottom to top:

     * Find its original tileset (`FindTileSetForGID` using `FirstGID/Columns` like in your TMXDRAW). ([GitHub][1])
     * Compute source rect in the original tileset bitmap.
     * Draw that rect onto the temp bitmap with transparency.
   * Copy the temp bitmap into the atlas bitmap at `(DestX, DestY)`.

All of this uses pure `TBitmap` and `TCanvas`:

```pascal
DestAtlas.Canvas.CopyRect(DestRect, Temp.Canvas, SrcRectAll);
```

You can use:

* Either **24-bit** bitmaps on the Lazarus side and quantize later.
* Or **8-bit paletted** bitmaps with a fixed VGA-like palette if you want to stay close to DOS.

Later, before saving PCX, convert or ensure palette matches what `PCX`/`VGA` units expect.

### 6.8. Save atlases as PCX

For each `TAtlasTileSet.Bitmap`:

* Convert `TBitmap` → `TFPMemoryImage` (using `TLazIntfImage`).
* Save with `TFPWriterPCX`.

Potential helper flow:

```pascal
uses FPImage, FPWritePCX, IntfGraphics;

procedure SaveBitmapAsPCX(const FileName: string; Bmp: TBitmap);
var
  IntfImg: TLazIntfImage;
  Raw    : TRawImage;
  Img    : TFPMemoryImage;
  Writer : TFPWriterPCX;
begin
  IntfImg := TLazIntfImage.Create(0,0);
  IntfImg.LoadFromBitmap(Bmp.Handle, Bmp.MaskHandle);
  Raw := IntfImg.GetRawImage;

  Img := TFPMemoryImage.Create(Raw.Description.Width, Raw.Description.Height);
  Img.LoadFromRawImage(Raw, False);

  Writer := TFPWriterPCX.Create;
  Img.SaveToFile(FileName, Writer);

  Writer.Free;
  Img.Free;
  IntfImg.Free;
end;
```

Name the files something like:

* `tiles_opt_0.pcx`
* `tiles_opt_1.pcx`
* …

And in TMX `<image source="tiles_opt_0.png">` you can:

* Also save PNG for Tiled, **or**
* Just keep `.png` but only produce PCX with same basename; the DOS engine will change extension to `.pcx` anyway. ([GitHub][1])

---

## 7. Build the optimized TMX DOM

### 7.1. Tilesets

Remove original visual tileset `<tileset>` elements (but keep Blocks tileset).

For each atlas:

```xml
<tileset firstgid="X" name="Atlas0" tilewidth="16" tileheight="16" columns="16">
  <image source="tiles_opt_0.png" width="256" height="240"/>
</tileset>
```

* `firstgid`: from `Atlas.FirstGID`.
* `columns`: from `Atlas.Columns`.
* `image source`: path of the atlas image (PNG counterpart). DOS loader will use `.pcx`.

Blocks tileset is copied over unchanged so your collision logic still works. ([GitHub][1])

### 7.2. Layers

* Delete all visual layers from the original TMX.
* Create two new `<layer>` elements:

  * `<layer name="Front" width="W" height="H">`
  * `<layer name="Back"  width="W" height="H">`

Each has:

```xml
<data encoding="csv">
  0,0,15,0,23,...
  ...
</data>
```

Generated from `FrontLayer` and `BackLayer` `TTileIDGrid`.

Blocks layer:

* Copy the original Blocks `<layer>` element and its data unchanged. Tiles there still refer to the original Blocks tileset and your DOS loader converts them to block types using `BlocksTilesetFirstGID`. ([GitHub][1])

Objectgroups:

* Keep `<objectgroup>` nodes as they are (engine already calls a callback per objectgroup). ([GitHub][1])

Finally:

```pascal
WriteXMLFile(Doc, 'MAP_OPT.TMX');
```

---

## 8. Resulting DOS-side behavior

From the engine’s point of view:

* `LoadTileMap` sees:

  * 1..N visual tilesets (our atlases).
  * 1 Blocks tileset named "Blocks".
  * A few `<layer>` tags – but due to the merging logic:

    * All layers before the first `<objectgroup>` are merged into **Front**.
    * All after into **Back**. ([GitHub][1])

* Because we created exactly one visual “Front” and one visual “Back” layer, the merge is trivial:

  * `TileMap.Layers[TileMapLayer_Front]` = our optimized front data.
  * `TileMap.Layers[TileMapLayer_Back]`  = our optimized back data.

* Tileset logic is unchanged – `DrawTileMapLayer` uses `FirstGID`, `Columns`, etc., to compute which part of the atlas to blit. ([GitHub][1])

You’ve just pre-baked all the overlapping layers into unique composite tiles, saving:

* DOS RAM (fewer/lower tileset images).
* CPU at runtime (no need to draw multiple stacked tiles per cell).

---

If you’d like, next step I can:

* Turn this into a **concrete Lazarus unit layout** (`uMapOptimizer`, `uTmxIO`, `uAtlasBuilder`).
* Or write a small **skeleton program** in Lazarus that:

  * Reads a TMX,
  * Builds stacks,
  * Prints how many unique stacks you have and how many tilesets you’d need with 256×240.

[1]: https://raw.githubusercontent.com/goph-R/DOS-Game-Engine/refs/heads/main/DOCS/TILEMAP.md "raw.githubusercontent.com"
