# Tiled TMX optimizer

Make a separate DOS tool, e.g. `TMXOPT.EXE`, that:

* **Input:** a multi-layer TMX map (with normal tilesets + Blocks + Objects tileset).
* **Output:**

  * New TMX:

    * visual content collapsed into exactly **2 layers**: `Back` + `Front`.
    * visual tilesets replaced by **1–4 atlas tilesets** containing **unique stacked tiles**.
    * Blocks tileset + Blocks layer + Objects tileset + objectgroups preserved.
  * New PCX tileset image(s) for the atlases (max 256×240 each, so <64K).

Runtime `LoadTileMap` doesn’t change at all; it just gets a “pre-baked” TMX that’s cheaper for DOS.

---

## 1. Program structure (16-bit friendly)

Make a new program, e.g.:

```pascal
program TMXOptimizer;

uses
  MiniXML, PCXLoad, GenTypes;
```

Keep it simple: one main file plus a helper unit or two if it gets too big.

### Main phases in `TMXOptimizer`:

1. **Load TMX into MiniXML tree**.
2. **Extract raw map data** (width/height, tilesets, layers).
3. **Build per-cell stacks** (Back / Front).
4. **Deduplicate stacks → assign composite tile indices**.
5. **Build atlas tilesets and save PCX atlases**.
6. **Edit MiniXML tree to reflect new tilesets + layers**.
7. **Save optimized TMX via `XMLSaveFile`**.

---

## 2. Data structures to use

### 2.1. Tilesets (from TMX)

You don’t need full `TTileMap` here, just per-tileset metadata + image:

```pascal
const
  MaxTileSets = 4;

type
  PTileSetInfo = ^TTileSetInfo;
  TTileSetInfo = record
    FirstGID   : Word;
    TileWidth  : Byte;
    TileHeight : Byte;
    TileCount  : Word;
    Columns    : Word;  { from TMX }
    ImageNode  : PXMLNode;  { <image> node, for editing source attr }
    IsBlocks   : Boolean;   { true if tileset name="Blocks" }
    Image      : TImage;    { loaded PCX image for this tileset }
  end;
```

Keep an array:

```pascal
var
  TileSets: array[0..MaxTileSets-1] of TTileSetInfo;
  TileSetCount: Byte;
  BlocksTileSetIndex: ShortInt; { -1 if no Blocks tileset }
  ObjectsTileSetIndex: ShortInt; { -1 if no Objects tileset }
```

### 2.2. Raw map layers (before stacking)

You want **per-layer CSV data** as WORDs:

```pascal
const
  MaxRawLayers = 16;

type
  PRawLayer = ^TRawLayer;
  TRawLayerKind = (lkFront, lkBack, lkBlocks, lkIgnore);

  TRawLayer = record
    Name    : string[32];
    Kind    : TRawLayerKind;
    Data    : PWord;  { Width * Height tile GIDs }
    XMLNode : PXMLNode;  { <layer> node, for removal later }
  end;

var
  RawLayers: array[0..MaxRawLayers-1] of TRawLayer;
  RawLayerCount: Byte;
```

### 2.3. Stacks per cell

Small fixed-size stack (you probably don’t have 20 layers):

```pascal
const
  MaxStackHeight   = 8;       { adjust if you have many overlay layers }
  MaxUniqueStacks  = 4096;    { adjust depending on map size }

type
  TTileID = Word;

  TTileStack = record
    Count: Byte;
    Items: array[0..MaxStackHeight-1] of TTileID; { bottom → top }
  end;

var
  MapWidth, MapHeight: Word;
  FrontStacks, BackStacks: ^TTileStack; { Width*Height each }
```

Access helpers:

```pascal
function StackAt(var Stacks: TTileStack; X, Y, W: Word): PTileStack;
begin
  StackAt := @Stacks[(Y * W) + X];
end;
```

(Actual code: `Stacks` is pointer; you use `PArrayStack(Stacks)^[Y*W + X]` etc.)

### 2.4. Unique stack registry

Simple linear registry (no generics):

```pascal
type
  TStackKey = TTileStack; { same layout }

  TStackRegistry = record
    Count       : Word;
    Keys        : array[0..MaxUniqueStacks-1] of TStackKey;
    LocalIndex  : array[0..MaxUniqueStacks-1] of Word; { 1..N -> tile index }
  end;

var
  StackReg: TStackRegistry;
```

You’ll assign **local composite tile indices** `1..N` (0 = empty) first, then later map them into atlas GIDs.

### 2.5. Atlas tilesets

You want 1–4 atlas images, each max 256×240.

```pascal
const
  AtlasWidth  = 256;
  AtlasHeight = 240;
  AtlasesMax  = 4;

type
  PAtlas = ^TAtlas;
  TAtlas = record
    FirstGID   : Word;
    TileWidth  : Byte;
    TileHeight : Byte;
    Columns    : Word;
    Rows       : Word;
    MaxTiles   : Word;
    UsedTiles  : Word;
    Image      : TImage;
    TilesetXML : PXMLNode;  { <tileset> node created in TMX }
  end;

var
  Atlases: array[0..AtlasesMax-1] of TAtlas;
  AtlasCount: Byte;
```

And a mapping from local composite index → atlas + local tile index:

```pascal
type
  TCompositeInfo = record
    AtlasIndex : Byte;
    TileIndex  : Word;  { 0..MaxTiles-1 in that atlas }
  end;

var
  CompositeTiles: array[1..MaxUniqueStacks] of TCompositeInfo;
```

---

## 3. Phase A – Load TMX + tilesets

1. `XMLLoadFile(InputFileName, Root);`
2. The `<map>` node is the root node, read:

   * `width`, `height`, `tilewidth`, `tileheight`.
3. Enumerate `<tileset>` children:

   * Read attributes: `firstgid`, `name`, `tilewidth`, `tileheight`, `columns`.
   * Find `<image>` child → get `source`.
   * Detect **Blocks tileset** by `name="Blocks"`.
   * Detect **Objects tileset** by `name="Objects"`.
   * Load its PCX image with `PCXLoadWithPalette` (or your normal loader).
   * Store info into `TileSets[]`.

> Memory tip: **only load visual tileset images** you need to compose stacks (i.e., exclude Blocks and Objects tileset from rendering). You still keep Blocks tile metadata for TMX, but you don’t need its image.

4. Enumerate `<layer>` nodes in document order:

   * You already know from `TILEMAP.md` how you separate “front” vs “back” using first `<objectgroup>` etc; apply the same rule to set `Kind` for each.
   * If layer has property `blocks` (per your spec), mark as `lkBlocks`.
   * For each non-ignored layer:

     * Read its `<data encoding="csv">` text via `XMLGetText`.
     * Parse CSV into `Width*Height` WORDs, store in `TRawLayer.Data` (GetMem).
     * Right after parsing, **clear the layer text** to save memory:

       ```pascal
       XMLSetText(LayerNode, '');
       ```

       Now that big CSV string is gone from the MiniXML heap.

5. Remember which `<layer>` is the Blocks layer (if any) so you can **leave it untouched** in the final TMX.

---

## 4. Phase B – Build Back / Front stacks

1. Allocate stack buffers:

```pascal
GetMem(FrontStacks, MapWidth * MapHeight * SizeOf(TTileStack));
GetMem(BackStacks,  MapWidth * MapHeight * SizeOf(TTileStack));
FillChar(FrontStacks^, MapWidth * MapHeight * SizeOf(TTileStack), 0);
FillChar(BackStacks^,  MapWidth * MapHeight * SizeOf(TTileStack), 0);
```

2. For each `TRawLayer` in order:

* If `Kind = lkFront` or `lkBack`:

  * For `y = 0..Height-1`, `x = 0..Width-1`:

    * `gid := Data[y*Width + x]`
    * If `gid <> 0`:

      * `S := StackAt(FrontStacks^, x, y, MapWidth)` (or back).
      * If `S^.Count < MaxStackHeight`, append:

        ```pascal
        S^.Items[S^.Count] := gid;
        Inc(S^.Count);
        ```

* If `Kind = lkBlocks`: ignore here (visual stacking doesn’t use it).

Now you have two logical layers:

* `BackStacks[y,x]` = bottom→top tile GIDs all merged into one stack.
* `FrontStacks[y,x]` = same for front.

---

## 5. Phase C – Deduplicate stacks → composite indices

We want:

* **Final layers**: `BackLayer[Y,X]` and `FrontLayer[Y,X]` containing **composite tile indices** (0 = empty).
* A registry mapping **unique stack** → **composite index (1..N)**.

### 5.1. Helpers

* `SameStack(A, B: TTileStack): Boolean;`
* `FindStackIndex(Reg, S): Integer;` (linear search `0..Reg.Count-1`).
* `AddStack(Reg, S): Word;` (adds, returns new index).

### 5.2. Build layers

For each Y,X and each of the two stack grids:

```pascal
function AssignLayerFromStacks(StackBase: Pointer; var OutLayer: PWord): Word;
var
  x, y: Word;
  S: PTileStack;
  idx: Integer;
  nextIdx: Word;
begin
  nextIdx := 1; { start composite indices at 1 }

  for y := 0 to MapHeight-1 do
    for x := 0 to MapWidth-1 do
    begin
      S := StackAt(PTileStack(StackBase)^, x, y, MapWidth);
      if S^.Count = 0 then
        OutLayer^[y*MapWidth + x] := 0
      else
      begin
        idx := FindStackIndex(StackReg, S^);
        if idx >= 0 then
          OutLayer^[y*MapWidth + x] := StackReg.LocalIndex[idx]
        else
        begin
          if StackReg.Count >= MaxUniqueStacks then
          begin
            { handle overflow (error or fallback) }
          end;
          StackReg.Keys[StackReg.Count] := S^;
          StackReg.LocalIndex[StackReg.Count] := nextIdx;
          OutLayer^[y*MapWidth + x] := nextIdx;
          Inc(StackReg.Count);
          Inc(nextIdx);
        end;
      end;
    end;

  Result := nextIdx - 1; { total composite tiles used }
end;
```

Allocate:

```pascal
var
  BackLayer, FrontLayer: PWord;
  CompositeCount: Word;
```

Call for back + front; `CompositeCount` must be the same for both calls, or just track maximum.

---

## 6. Phase D – Build atlases and write PCX

Now you have `CompositeCount` composite tiles (1..CompositeCount) and their stack definitions in `StackReg.Keys[]`.

### 6.1. Initialize first atlas

```pascal
AtlasCount := 1;
with Atlases[0] do
begin
  TileWidth  := 16;  { from map }
  TileHeight := 16;
  Columns    := AtlasWidth div TileWidth;   { 256/16 = 16 }
  Rows       := AtlasHeight div TileHeight; { 240/16 = 15 }
  MaxTiles   := Columns * Rows;             { 240 }
  UsedTiles  := 0;
  InitImage(Image, AtlasWidth, AtlasHeight, ...);  { your TImage init }
end;
```

We’ll decide `FirstGID` later based on Blocks and Objects tileset.

### 6.2. For each composite index 1..CompositeCount

1. Pick current atlas:

   ```pascal
   if Atlases[AtlasCount-1].UsedTiles = Atlases[AtlasCount-1].MaxTiles then
   begin
     if AtlasCount >= AtlasesMax then
       { error: too many tiles }
     { init new atlas same as first, just another Image }
     Inc(AtlasCount);
   end;
   A := @Atlases[AtlasCount-1];
   localIndex := A^.UsedTiles;
   Inc(A^.UsedTiles);
   CompositeTiles[i].AtlasIndex := AtlasCount-1;
   CompositeTiles[i].TileIndex  := localIndex;
   ```

2. Compute destination coordinates:

   ```pascal
   Col := localIndex mod A^.Columns;
   Row := localIndex div A^.Columns;
   DestX := Col * A^.TileWidth;
   DestY := Row * A^.TileHeight;
   ```

3. Render stack into a small tile buffer and blit into atlas:

   * Create `TileBuf: TImage` (16×16).
   * Clear to transparent color index (0).
   * For each `gid` in `StackReg.Keys[i-1].Items[0..Count-1]` (bottom→top):

     * Find source tileset from `TileSets[]` using `FirstGID` & tile count.
     * Compute source X/Y like you already do in `DrawTileMapLayer`.
     * `PutImageRect(Source.Image, TileBuf, SrcX, SrcY, TileW, TileH, 0, 0)`
       (respect transparency if you need it).
   * Finally:

     ```pascal
     PutImageRect(TileBuf, A^.Image, 0, 0, TileW, TileH, DestX, DestY);
     ```

4. Free `TileBuf` or reuse one globally.

### 6.3. Decide atlas FirstGID & Blocks tileset positioning

To keep the **Blocks tileset unchanged**, we need to assign FirstGID values that don't conflict with the special tilesets:

**Strategy:**

1. **Preserve special tilesets:** Blocks and Objects tilesets keep their original FirstGID values from the source TMX.
2. **Atlas placement:** Place atlas tilesets in gaps or append after all special tilesets.

**Simple approach (recommended):**

Start atlases at FirstGID = 1, then adjust Blocks and Objects tilesets to come after:

```pascal
{ Assign atlas FirstGIDs starting at 1 }
NextGID := 1;
for i := 0 to AtlasCount-1 do
begin
  Atlases[i].FirstGID := NextGID;
  Inc(NextGID, Atlases[i].UsedTiles);
end;

{ Now place Blocks tileset after all atlases }
if BlocksTileSetIndex >= 0 then
begin
  TileSets[BlocksTileSetIndex].FirstGID := NextGID;
  Inc(NextGID, TileSets[BlocksTileSetIndex].TileCount);
end;

{ Objects tileset comes last }
if ObjectsTileSetIndex >= 0 then
begin
  TileSets[ObjectsTileSetIndex].FirstGID := NextGID;
  Inc(NextGID, TileSets[ObjectsTileSetIndex].TileCount);
end;
```

3. **Convert layer data:** Now convert `BackLayer`/`FrontLayer` from local composite indices (1..N) to real atlas GIDs:

```pascal
for y := 0 to MapHeight-1 do
  for x := 0 to MapWidth-1 do
  begin
    Idx := BackLayer^[y*MapWidth + x];
    if Idx > 0 then
    begin
      CI := CompositeTiles[Idx];
      Atlas := @Atlases[CI.AtlasIndex];
      BackLayer^[y*MapWidth + x] := Atlas^.FirstGID + CI.TileIndex;
    end;

    { Repeat for FrontLayer }
    Idx := FrontLayer^[y*MapWidth + x];
    if Idx > 0 then
    begin
      CI := CompositeTiles[Idx];
      Atlas := @Atlases[CI.AtlasIndex];
      FrontLayer^[y*MapWidth + x] := Atlas^.FirstGID + CI.TileIndex;
    end;
  end;
```

4. **Update Blocks layer tile IDs (if present):**

If the Blocks tileset FirstGID changed, update BlocksLayer data:

```pascal
if BlocksTileSetIndex >= 0 then
begin
  OldBlocksFirstGID := { original FirstGID from source TMX };
  NewBlocksFirstGID := TileSets[BlocksTileSetIndex].FirstGID;
  Offset := NewBlocksFirstGID - OldBlocksFirstGID;

  { Only update if offset is non-zero }
  if Offset <> 0 then
    for i := 0 to (MapWidth * MapHeight)-1 do
      if BlocksLayerData^[i] <> 0 then
        BlocksLayerData^[i] := BlocksLayerData^[i] + Offset;
end;
```

5. **Update objectgroup tile references (if present):**

If any `<objectgroup>` tags contain `<object>` elements with `gid` attributes (tile objects from the Objects tileset), those GIDs must be updated too:

```pascal
{ During Phase A when loading, store original Objects FirstGID }
if ObjectsTileSetIndex >= 0 then
  OldObjectsFirstGID := TileSets[ObjectsTileSetIndex].FirstGID;

{ After atlas GID assignment in Phase D }
if ObjectsTileSetIndex >= 0 then
begin
  NewObjectsFirstGID := TileSets[ObjectsTileSetIndex].FirstGID;
  Offset := NewObjectsFirstGID - OldObjectsFirstGID;

  { Only update if offset is non-zero }
  if Offset <> 0 then
  begin
    { Iterate all <objectgroup> nodes in the XML tree }
    ObjGroupNode := XMLFindFirstChild(MapNode, 'objectgroup');
    while ObjGroupNode <> nil do
    begin
      { Iterate all <object> children }
      ObjNode := XMLFindFirstChild(ObjGroupNode, 'object');
      while ObjNode <> nil do
      begin
        { Check if object has a gid attribute }
        if XMLHasAttr(ObjNode, 'gid') then
        begin
          OldGID := StrToInt(XMLAttr(ObjNode, 'gid'));
          { Only update if GID belongs to Objects tileset }
          if OldGID >= OldObjectsFirstGID then
          begin
            NewGID := OldGID + Offset;
            XMLSetAttr(ObjNode, 'gid', IntToStr(NewGID));
          end;
        end;
        ObjNode := XMLNextSibling(ObjNode);
      end;
      ObjGroupNode := XMLNextSibling(ObjGroupNode);
    end;
  end;
end;
```

Now `BackLayer`/`FrontLayer` are **real GIDs** that match atlas tilesets, and Blocks layer + objectgroup tile references won't collide with the new atlas tilesets.

### 6.4. Save atlas images as PCX

For each atlas:

```pascal
FileName := 'MAPNAME_ATLAS' + IntToStr(i) + '.PCX';
if not SavePCX(FileName, Atlases[i].Image, GlobalPalette) then
  { handle error }
```

(Tweak file naming to your liking.)

---

## 7. Phase E – Update TMX MiniXML tree

Now use your new MiniXML editing API.

### 7.1. Remove old visual tilesets

* Iterate `<tileset>` nodes:

  * If it’s the Blocks or Objects tileset (`name="Blocks"` or `name="Objects"`), **keep**.
  * All others: **remove** from the tree.

You may want a helper like `XMLRemoveNode(Node: PXMLNode);` but you can also just rebuild children list manually; or be lazy and mark them, and when saving only use the new ones — up to you.

### 7.2. Add new atlas `<tileset>` nodes

For each atlas:

```pascal
TilesetNode := XMLAddChildElement(MapNode^.Parent or Root, 'tileset');
XMLSetAttr(TilesetNode, 'firstgid', IntToStr(Atlases[i].FirstGID));
XMLSetAttr(TilesetNode, 'name', 'Atlas' + IntToStr(i));
XMLSetAttr(TilesetNode, 'tilewidth',  IntToStr(Atlases[i].TileWidth));
XMLSetAttr(TilesetNode, 'tileheight', IntToStr(Atlases[i].TileHeight));
XMLSetAttr(TilesetNode, 'columns',    IntToStr(Atlases[i].Columns));

ImageNode := XMLAddChildElement(TilesetNode, 'image');
XMLSetAttr(ImageNode, 'source', 'MAPNAME_ATLAS' + IntToStr(i) + '.png'); 
XMLSetAttr(ImageNode, 'width',  IntToStr(AtlasWidth));
XMLSetAttr(ImageNode, 'height', IntToStr(AtlasHeight));
```

(Your DOS engine will change `.png` → `.pcx` on load anyway.)

### 7.3. Replace visual layers with new Back/Front

* Remove all original visual `<layer>` nodes **except** the Blocks layer.
* Create 2 new layers:

```pascal
BackNode  := XMLAddChildElement(MapNode, 'layer');
XMLSetAttr(BackNode,  'name', 'Back');
XMLSetAttr(BackNode,  'width',  IntToStr(MapWidth));
XMLSetAttr(BackNode,  'height', IntToStr(MapHeight));

FrontNode := XMLAddChildElement(MapNode, 'layer');
XMLSetAttr(FrontNode, 'name', 'Front');
XMLSetAttr(FrontNode, 'width',  IntToStr(MapWidth));
XMLSetAttr(FrontNode, 'height', IntToStr(MapHeight));
```

Add `<data encoding="csv">` children and fill them:

```pascal
DataNode := XMLAddChildElement(BackNode, 'data');
XMLSetAttr(DataNode, 'encoding', 'csv');
XMLSetText(DataNode, '');
{ then loop Y/X, append "gid," etc with XMLAppendText in small chunks }
```

Do the same for `FrontLayer`.

**Blocks layer & tileset:**

* Leave the Blocks `<tileset>`, the Objects `<tileset>` and Blocks `<layer>` node **untouched**, only the `<tileset>` GID can be changed depending on the order of the layers and the `tilecount` of the created tilesets.

### 7.4. Keep `<objectgroup>` as-is

The engine already uses objectgroups; just leave them in the tree.

---

## 8. Phase F – Save & cleanup

* `XMLSaveFile(OutputTMX, Root);`
* Free:

  * `XMLFreeTree(Root);`
  * `FreeMem` layers and stacks.
  * Release `TImage` resources (your image free function).

---

## 9. Development steps (suggested order)

To avoid going insane in TP7, I’d do it incrementally:

1. **Step 1 – XML round-trip only**

   * Load TMX, immediately `XMLSaveFile` under a new name.
   * Confirm Tiled + engine can read it.

2. **Step 2 – Raw map loader**

   * Add code to parse tilesets + layers into `TRawLayer`/`TileSets`.
   * Print some stats, but still save original TMX.

3. **Step 3 – Stacks**

   * Build `BackStacks`/`FrontStacks`, but don’t change TMX.
   * Print number of non-empty stacks and unique stacks.

4. **Step 4 – Composite indices**

   * Build `BackLayer`/`FrontLayer` with composite indices, but still keep old tilesets and layers in TMX.

5. **Step 5 – Atlas + PCX**

   * Build one atlas, save PCX; inspect visually (GrafX2).

6. **Step 6 – Full TMX rewrite**

   * Remove old tilesets/layers, add atlas tilesets and new layers.
   * Test in your engine.
