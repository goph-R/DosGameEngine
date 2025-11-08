# 🟨 TileMap handling

The DOS Game Engine should be able to load `.tmx` files with very basic functionality that can be found in the `TMXLOAD.PAS`.

Only handles two layers: back and front. It is separated by the `<objectgroup>`, if no such tag present in the `.tmx`, only the front layer is used for the tiles. Every layer above it is merged to the front layer, and every layer below is merged to the back layer. 

## 🧱 Structures

```pascal
type PTileSet = ^TTileSet;
type TTileSet = record
  FirstGid: Word;      { The first tile ID in the set }
  TileWidth: Byte;     { Width of one tile }
  TileHeight: Byte;    { Height of one tile }
  Columns: Byte;       { Tile columns count }
  Image: TImage;       { The image that holds the graphics of the tiles. }
end;

const TileMapLayer_Front = 0;
const TileMapLayer_Back = 1;

type TTileMap = record
  Width: Word;                    { Width of the tile map }
  Height: Word;                   { Height of the tile map }
  Layers: array[0..1] of Pointer; { Back and front layers }
                                  { Every word represents a TileID } 
end;
````

## 🔥 Functions

`function GetLoadTileMapError(): String`

Returns the last error on TileMap loading, gets it from a unit scoped variable: `LoadTileMapError: String`.

`function LoadTileMap(const FilePath: String; var TileMap: TTileMap): Boolean`

Clears the `LoadTileMapError` variable, then loads the content of the `.tmx` file from the `FilePath` to an `XML` string. On any fail sets the `LoadTileMapError` and returns `False.`

If the XML string has content: searches for the `<map>` tag, if not presents the load fails. Sets the `TileMap.Width` and `TileMap.Height` via the `<map>` tag's `width` and `height` attributes, if any of these missing: the load fails. 

Searches for the `<tileset>` tags in the `XML` and calls the `LoadTileSet` for each. If a tile set load fails, returns with `False`.

Searches for the `<layer>` tags in the `XML` and calls the `LoadTileMapLayer` for each.

`function LoadTileSet(const FolderPath: String; const TileSetXML: String; var TTileSet): Boolean`

Sets the 

`procedure LoadTileMapLayers()`

Only those `<layer>` tags should be processed that are having a `<data>` tag with an `encoding` attribute with `csv` value.

If the layer order in a `.tmx` file is the following:

```xml
<layer><data encoding="csv">...</data></layer> <!-- front layer #0 -->
<layer><data encoding="csv">...</data></layer> <!-- front layer #1 -->
<objectgroup>...</objectgroup>
<layer><data encoding="csv">...</data></layer> <!-- back layer #0 -->
<layer><data encoding="csv">...</data></layer> <!-- back layer #1 -->
```

and the Front layer #0 does not have a tile ID on a given position but the Front layer #1 does, that should be on the Front layer. If both present the #0 should be used: the smaller the layer index is the bigger the priority. The same logic applies to the back layers.

The tile sets should be created manually in the code, not part of the load mechanism.

`procedure DrawTileMapLayer(var TileMap: TTileMap; Layer: Byte; FrameBuffer: PFrameBuffer);`

Draws the tile map layer to the given frame buffer.