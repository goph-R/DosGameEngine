unit TMXLoad;

{$G+}  { Enable 286 instructions }
{$F+}  { Enable far calls for procedural types }

interface

uses
  VGA, MiniXML;

type
  TTileSet = record
    FirstGID: Word;       { The first tile ID in the set }
    TileWidth: Byte;      { Width of one tile }
    TileHeight: Byte;     { Height of one tile }
    Columns: Byte;        { Tile columns count }
    Image: TImage;        { The image that holds the graphics of the tiles }
  end;

const
  TileMap_MaxTileSets = 4;
  TileMapLayer_Front = 0;
  TileMapLayer_Back = 1;

type
  TTileMap = record
    Width: Word;                                            { Width of the tile map (in tiles) }
    Height: Word;                                           { Height of the tile map (in tiles) }
    TileSetCount: Byte;                                     { How many tilesets are present }
    TileSets: array[0..TileMap_MaxTileSets - 1] of TTileSet;
    Layers: array[0..1] of PWord;                           { Back and front layers }
                                                            { Every word represents a TileID }
  end;

  { Callback for processing objectgroup }
  TObjectGroupProc = procedure(ObjectGroup: PXMLNode);

{ Public API }
function GetLoadTileMapError: String;
function LoadTileMap(const FilePath: String; var TileMap: TTileMap;
                     ObjectGroupProc: TObjectGroupProc): Boolean;
procedure DrawTileMapLayer(var TileMap: TTileMap; Layer: Byte; X, Y, Width, Height: Word; FrameBuffer: PFrameBuffer);
procedure FreeTileMap(var TileMap: TTileMap);

implementation

uses
  PKMLoad;

var
  LoadTileMapError: String;

{ Helper: Replace forward slashes with backslashes for DOS paths }
function FixPath(const Path: String): String;
var
  I: Integer;
  Result: String;
begin
  Result := Path;
  for I := 1 to Length(Result) do
    if Result[I] = '/' then
      Result[I] := '\';
  FixPath := Result;
end;

{ Helper: Extract folder path from full file path }
function ExtractFolder(const FilePath: String): String;
var
  I: Integer;
begin
  for I := Length(FilePath) downto 1 do
    if (FilePath[I] = '\') or (FilePath[I] = '/') then
    begin
      ExtractFolder := Copy(FilePath, 1, I);
      Exit;
    end;
  ExtractFolder := '';
end;

{ Helper: Change file extension to .PKM }
function ChangeExtToPKM(const FileName: String): String;
var
  I: Integer;
begin
  for I := Length(FileName) downto 1 do
    if FileName[I] = '.' then
    begin
      ChangeExtToPKM := Copy(FileName, 1, I - 1) + '.PKM';
      Exit;
    end;
  ChangeExtToPKM := FileName + '.PKM';
end;

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

{ Load a single tileset from XML node }
function LoadTileSet(const FolderPath: String; const XMLNode: PXMLNode; var TileSet: TTileSet): Boolean;
var
  ImageNode: PXMLNode;
  ImageSource: String;
  FullPath: String;
begin
  LoadTileSet := False;

  { Extract required attributes }
  if not XMLHasAttr(XMLNode, 'firstgid') then
  begin
    LoadTileMapError := 'Missing firstgid attribute in tileset';
    Exit;
  end;
  TileSet.FirstGID := StrToInt(XMLAttr(XMLNode, 'firstgid'));

  if not XMLHasAttr(XMLNode, 'tilewidth') then
  begin
    LoadTileMapError := 'Missing tilewidth attribute in tileset';
    Exit;
  end;
  TileSet.TileWidth := StrToInt(XMLAttr(XMLNode, 'tilewidth'));

  if not XMLHasAttr(XMLNode, 'tileheight') then
  begin
    LoadTileMapError := 'Missing tileheight attribute in tileset';
    Exit;
  end;
  TileSet.TileHeight := StrToInt(XMLAttr(XMLNode, 'tileheight'));

  if not XMLHasAttr(XMLNode, 'columns') then
  begin
    LoadTileMapError := 'Missing columns attribute in tileset';
    Exit;
  end;
  TileSet.Columns := StrToInt(XMLAttr(XMLNode, 'columns'));

  { Find <image> child node }
  ImageNode := XMLFirstChild(XMLNode, 'image');
  if ImageNode = nil then
  begin
    LoadTileMapError := 'Missing <image> tag in tileset';
    Exit;
  end;

  { Get image source path }
  if not XMLHasAttr(ImageNode, 'source') then
  begin
    LoadTileMapError := 'Missing source attribute in <image> tag';
    Exit;
  end;
  ImageSource := XMLAttr(ImageNode, 'source');

  { Convert path: fix slashes, change extension to PKM }
  ImageSource := FixPath(ImageSource);
  ImageSource := ChangeExtToPKM(ImageSource);
  FullPath := FolderPath + ImageSource;

  { Load the PKM image }
  if not LoadPKM(FullPath, TileSet.Image) then
  begin
    LoadTileMapError := 'Failed to load tileset image: ' + FullPath;
    Exit;
  end;

  LoadTileSet := True;
end;

{ Load and merge a single layer into the tilemap }
procedure LoadTileMapLayer(const XMLNode: PXMLNode; var TileMap: TTileMap; const Layer: Byte);
var
  DataNode: PXMLNode;
  PropertiesNode: PXMLNode;
  PropertyNode: PXMLNode;
  PropertyName: String;
  Encoding: String;
  TileData: PWord;
  TileCount: Word;
  I, X, Y: Word;
  TileID: Word;
  DestIndex: LongInt;
  IsBlocksLayer: Boolean;
begin
  { Check for blocks property (TODO: implement block map handling) }
  IsBlocksLayer := False;
  PropertiesNode := XMLFirstChild(XMLNode, 'properties');
  if PropertiesNode <> nil then
  begin
    PropertyNode := XMLFirstChild(PropertiesNode, 'property');
    while PropertyNode <> nil do
    begin
      if XMLHasAttr(PropertyNode, 'name') then
      begin
        PropertyName := XMLAttr(PropertyNode, 'name');
        if PropertyName = 'blocks' then
        begin
          IsBlocksLayer := True;
          { TODO: Handle as block map instead of tile layer }
          Break;
        end;
      end;
      PropertyNode := XMLNextSibling(PropertyNode, 'property');
    end;
  end;

  { Find <data> child node }
  DataNode := XMLFirstChild(XMLNode, 'data');
  if DataNode = nil then Exit;

  { Check encoding }
  Encoding := XMLAttr(DataNode, 'encoding');
  if Encoding <> 'csv' then Exit;  { Only CSV supported }

  { Parse CSV data using XMLReadWordArray }
  if not XMLReadWordArray(DataNode, TileData, TileCount) then Exit;

  { Merge tiles into the layer (higher index = higher priority, later layers overwrite earlier) }
  for I := 0 to TileCount - 1 do
  begin
    TileID := PWordArray(TileData)^[I];

    { Calculate destination index }
    Y := I div TileMap.Width;
    X := I mod TileMap.Width;
    DestIndex := LongInt(Y) * LongInt(TileMap.Width) + LongInt(X);

    { Merge: non-zero tiles always overwrite (later layers have priority) }
    if TileID > 0 then
      PWordArray(TileMap.Layers[Layer])^[DestIndex] := TileID;
  end;

  { Free temporary tile data }
  FreeMem(TileData, TileCount * SizeOf(Word));
end;

{ Main loader function }
function LoadTileMap(const FilePath: String; var TileMap: TTileMap;
                     ObjectGroupProc: TObjectGroupProc): Boolean;
var
  Root: PXMLNode;
  MapNode: PXMLNode;
  Node: PXMLNode;
  FolderPath: String;
  LayerSize: LongInt;
  ObjectGroupFound: Boolean;
  LayersBefore, LayersAfter: Byte;
begin
  LoadTileMap := False;
  LoadTileMapError := '';

  { Initialize tilemap }
  TileMap.Width := 0;
  TileMap.Height := 0;
  TileMap.TileSetCount := 0;
  TileMap.Layers[0] := nil;
  TileMap.Layers[1] := nil;

  { Load and parse XML }
  Root := XMLLoad(FilePath);
  if Root = nil then
  begin
    LoadTileMapError := 'Failed to load TMX file: ' + FilePath;
    Exit;
  end;

  { Find <map> node }
  MapNode := XMLFirstChild(Root, 'map');
  if MapNode = nil then
  begin
    LoadTileMapError := 'No <map> tag found in TMX file';
    XMLFree(Root);
    Exit;
  end;

  { Get map dimensions }
  if not XMLHasAttr(MapNode, 'width') then
  begin
    LoadTileMapError := 'Missing width attribute in <map> tag';
    XMLFree(Root);
    Exit;
  end;
  TileMap.Width := StrToInt(XMLAttr(MapNode, 'width'));

  if not XMLHasAttr(MapNode, 'height') then
  begin
    LoadTileMapError := 'Missing height attribute in <map> tag';
    XMLFree(Root);
    Exit;
  end;
  TileMap.Height := StrToInt(XMLAttr(MapNode, 'height'));

  { Allocate layer memory }
  LayerSize := LongInt(TileMap.Width) * LongInt(TileMap.Height) * SizeOf(Word);
  GetMem(TileMap.Layers[0], LayerSize);
  GetMem(TileMap.Layers[1], LayerSize);

  { Initialize layers to zero }
  FillChar(TileMap.Layers[0]^, LayerSize, 0);
  FillChar(TileMap.Layers[1]^, LayerSize, 0);

  { Extract folder path for relative tileset loading }
  FolderPath := ExtractFolder(FilePath);

  { Load all tilesets }
  TileMap.TileSetCount := 0;
  Node := XMLFirstChild(MapNode, 'tileset');
  while (Node <> nil) and (TileMap.TileSetCount < TileMap_MaxTileSets) do
  begin
    if not LoadTileSet(FolderPath, Node, TileMap.TileSets[TileMap.TileSetCount]) then
    begin
      XMLFree(Root);
      FreeTileMap(TileMap);
      Exit;
    end;
    Inc(TileMap.TileSetCount);
    Node := XMLNextSibling(Node, 'tileset');
  end;

  { Verify at least one tileset was loaded }
  if TileMap.TileSetCount = 0 then
  begin
    LoadTileMapError := 'No tilesets found';
    XMLFree(Root);
    FreeTileMap(TileMap);
    Exit;
  end;

  { Process layers with merging logic }
  { Scan for objectgroup to determine layer split point }
  ObjectGroupFound := False;
  LayersBefore := 0;
  LayersAfter := 0;

  Node := MapNode^.FirstChild;
  while Node <> nil do
  begin
    if Node^.Name = 'objectgroup' then
    begin
      ObjectGroupFound := True;
      { Call callback for custom objectgroup processing }
      if @ObjectGroupProc <> nil then
        ObjectGroupProc(Node);
    end
    else if Node^.Name = 'layer' then
    begin
      if ObjectGroupFound then
        LoadTileMapLayer(Node, TileMap, TileMapLayer_Back)
      else
        LoadTileMapLayer(Node, TileMap, TileMapLayer_Front);
    end;
    Node := Node^.NextSibling;
  end;

  XMLFree(Root);
  LoadTileMap := True;
end;

{ Render a portion of a tilemap layer }
procedure DrawTileMapLayer(var TileMap: TTileMap; Layer: Byte; X, Y, Width, Height: Word; FrameBuffer: PFrameBuffer);
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
      PutImageRect(TileSet.Image, SourceRect, DestX, DestY, True, FrameBuffer);
    end;
  end;
end;

{ Free tilemap memory }
procedure FreeTileMap(var TileMap: TTileMap);
var
  I: Integer;
begin
  { Free layer memory }
  if TileMap.Layers[0] <> nil then
  begin
    FreeMem(TileMap.Layers[0], LongInt(TileMap.Width) * LongInt(TileMap.Height) * SizeOf(Word));
    TileMap.Layers[0] := nil;
  end;

  if TileMap.Layers[1] <> nil then
  begin
    FreeMem(TileMap.Layers[1], LongInt(TileMap.Width) * LongInt(TileMap.Height) * SizeOf(Word));
    TileMap.Layers[1] := nil;
  end;

  { Free tileset images }
  for I := 0 to TileMap.TileSetCount - 1 do
    FreeImage(TileMap.TileSets[I].Image);

  TileMap.TileSetCount := 0;
end;

{ Get last error message }
function GetLoadTileMapError: String;
begin
  GetLoadTileMapError := LoadTileMapError;
end;

end.
