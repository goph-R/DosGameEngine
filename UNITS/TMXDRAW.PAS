unit TMXDraw;

{$G+}  { Enable 286 instructions }

interface

uses
  VGA, TMXLoad, MiniXML, GenTypes;

{ Render a portion of a tilemap layer to a framebuffer }
procedure DrawTileMapLayer(var TileMap: TTileMap; Layer: Byte; X, Y, Width, Height: Word; FrameBuffer: PFrameBuffer);

implementation

{ Helper: Find which tileset contains a given tile ID }
function FindTileSet(var TileMap: TTileMap; TileID: Word): Integer;
var
  I: Integer;
begin
  FindTileSet := -1;
  if TileID = 0 then Exit;  { Tile ID 0 is always empty }

  for I := 0 to TileMap.TileSetCount - 1 do
  begin
    { Check if TileID falls in this tileset's range }
    if I < TileMap.TileSetCount - 1 then
    begin
      { Not the last tileset - check if ID is between FirstGID and next FirstGID }
      if (TileID >= TileMap.TileSets[I].FirstGID) and (TileID < TileMap.TileSets[I + 1].FirstGID) then
      begin
        FindTileSet := I;
        Exit;
      end;
    end
    else
    begin
      { Last tileset - just check if >= FirstGID }
      if TileID >= TileMap.TileSets[I].FirstGID then
      begin
        FindTileSet := I;
        Exit;
      end;
    end;
  end;
end;

{ Render a portion of a tilemap layer }
procedure DrawTileMapLayer(
  var TileMap: TTileMap;
  Layer: Byte; X, Y, Width, Height: Word;
  FrameBuffer: PFrameBuffer
);
var
  TileX, TileY: Word;
  TileID: Word;
  TileIndex: LongInt;
  TileSetIndex: Integer;
  TileSet: TTileSet;
  LocalTileIndex: Word;
  SourceRect: TRectangle;
  DestX, DestY: Integer;
  Col, Row: Byte;
begin
  { Render each tile in the specified range }
  for TileY := Y to Y + Height - 1 do
  begin
    if TileY >= TileMap.Height then Break;

    for TileX := X to X + Width - 1 do
    begin
      if TileX >= TileMap.Width then Break;

      { Get tile ID at this position }
      TileIndex := LongInt(TileY) * LongInt(TileMap.Width) + LongInt(TileX);
      TileID := PWordArray(TileMap.Layers[Layer])^[TileIndex];

      { Skip empty tiles }
      if TileID = 0 then Continue;

      { Find which tileset contains this tile }
      TileSetIndex := FindTileSet(TileMap, TileID);
      if TileSetIndex < 0 then Continue;

      TileSet := TileMap.TileSets[TileSetIndex];

      { Calculate local tile index within this tileset }
      LocalTileIndex := TileID - TileSet.FirstGID;

      { Calculate source rectangle in tileset image }
      Row := LocalTileIndex div TileSet.Columns;
      Col := LocalTileIndex mod TileSet.Columns;

      SourceRect.X := Col * TileSet.TileWidth;
      SourceRect.Y := Row * TileSet.TileHeight;
      SourceRect.Width := TileSet.TileWidth;
      SourceRect.Height := TileSet.TileHeight;

      { Calculate destination position (relative to camera) }
      DestX := (TileX - X) * TileSet.TileWidth;
      DestY := (TileY - Y) * TileSet.TileHeight;

      { Render tile }
      { TODO: differentiate opaque and transparent tiles! Can be +10 FPS! }
      PutImageRect(TileSet.Image, SourceRect, DestX, DestY, True, FrameBuffer);
    end;
  end;
end;

end.
