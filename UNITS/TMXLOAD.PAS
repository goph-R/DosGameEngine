unit TMXLoad;

{$G+}  { Enable 286 instructions }
{$F+}  { Enable far calls for procedural types }

interface

uses
  VGA, MiniXML, GenTypes;

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
    BlocksLayer: PByteArray;                                { Collision/blocks layer (nil if not present) }
                                                            { Each byte is a block type (0 = passable) }
    BlocksTilesetFirstGID: Word;                            { FirstGID of tileset with 'blocks' property (0 if none) }
  end;

  { Callback for processing objectgroup }
  TObjectGroupProc = procedure(ObjectGroup: PXMLNode);

{ Public API }
function GetLoadTileMapError: String;
function LoadTileMap(const FilePath: String; var TileMap: TTileMap;
                     ObjectGroupProc: TObjectGroupProc): Boolean;
procedure FreeTileMap(var TileMap: TTileMap);
function IsBlockType(const TileMap: TTileMap; X, Y: Word; BlockType: Byte): Boolean;

implementation

uses
  PCX, StrUtil;

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

{ Helper: Change file extension to .PCX }
function ChangeExtToPCX(const FileName: String): String;
var
  I: Integer;
begin
  for I := Length(FileName) downto 1 do
    if FileName[I] = '.' then
    begin
      ChangeExtToPCX := Copy(FileName, 1, I - 1) + '.PCX';
      Exit;
    end;
  ChangeExtToPCX := FileName + '.PCX';
end;

{ Helper: Checks if a <xmlnode><properties><property="name"> exists }
function HasProperty(const XMLNode: PXMLNode; const Name: string): Boolean;
var
  PropertiesNode: PXMLNode;
  PropertyNode: PXMLNode;
  PropertyName: string;
begin
  HasProperty := False;
  PropertiesNode := XMLFirstChild(XMLNode, 'properties');
  if PropertiesNode <> nil then
  begin
    PropertyNode := XMLFirstChild(PropertiesNode, 'property');
    while PropertyNode <> nil do
    begin
      if XMLHasAttr(PropertyNode, 'name') then
      begin
        PropertyName := XMLAttr(PropertyNode, 'name');
        if PropertyName = Name then
        begin
          HasProperty := True;
          Exit;
        end;
      end;
      PropertyNode := XMLNextSibling(PropertyNode, 'property');
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

  { Convert path: fix slashes, change extension to PCX }
  ImageSource := FixPath(ImageSource);
  ImageSource := ChangeExtToPCX(ImageSource);
  FullPath := FolderPath + ImageSource;

  { Load the PCX image }
  if not LoadPCX(FullPath, TileSet.Image) then
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
  LayerSize: LongInt;
begin
  { Check for blocks property }
  IsBlocksLayer := HasProperty(XMLNode, 'blocks');

  { If this is a blocks layer, allocate BlocksLayer if not already allocated }
  if IsBlocksLayer then
  begin
    if TileMap.BlocksLayer = nil then
    begin
      LayerSize := LongInt(TileMap.Width) * LongInt(TileMap.Height);
      GetMem(TileMap.BlocksLayer, LayerSize);
      { Initialize with zeros (passable) }
      FillChar(TileMap.BlocksLayer^, LayerSize, 0);
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

  { Process tiles }
  if IsBlocksLayer then
  begin
    { Fill BlocksLayer with tile IDs (as bytes, ignoring values > 255) }
    for I := 0 to TileCount - 1 do
    begin
      TileID := PWordArray(TileData)^[I];

      { Skip empty tiles }
      if TileID = 0 then
        Continue;

      { Convert to block type: subtract FirstGID and add 1 }
      TileID := TileID - TileMap.BlocksTilesetFirstGID + 1;

      { Calculate destination index }
      Y := I div TileMap.Width;
      X := I mod TileMap.Width;
      DestIndex := LongInt(Y) * LongInt(TileMap.Width) + LongInt(X);

      { Store tile ID as byte (ignore if > 255) }
      if TileID <= 255 then
        TileMap.BlocksLayer^[DestIndex] := Byte(TileID);
    end;
  end
  else
  begin
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
  end;

  { Free temporary tile data }
  FreeMem(TileData, TileCount * SizeOf(Word));
end;

{ Main loader function }
function LoadTileMap(const FilePath: String; var TileMap: TTileMap;
                     ObjectGroupProc: TObjectGroupProc): Boolean;
var
  MapNode: PXMLNode;
  Node: PXMLNode;
  FolderPath: String;
  LayerSize: LongInt;
  ObjectGroupFound: Boolean;
  ObjectGroupNode: PXMLNode;
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
  TileMap.BlocksLayer := nil;
  TileMap.BlocksTilesetFirstGID := 0;

  { Load and parse XML, the <map> is the root node }
  XMLLoadFile(FilePath, MapNode);
  if MapNode = nil then
  begin
    LoadTileMapError := 'Failed to load TMX file: ' + FilePath;
    Exit;
  end;

  { Get map dimensions }
  if not XMLHasAttr(MapNode, 'width') then
  begin
    LoadTileMapError := 'Missing width attribute in <map> tag';
    XMLFreeTree(MapNode);
    Exit;
  end;
  TileMap.Width := StrToInt(XMLAttr(MapNode, 'width'));

  if not XMLHasAttr(MapNode, 'height') then
  begin
    LoadTileMapError := 'Missing height attribute in <map> tag';
    XMLFreeTree(MapNode);
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
    { Check if this is a `Blocks` named tileset }
    if XMLAttr(Node, 'name') = 'Blocks' then
    begin
      { Store FirstGID for blocks tileset and skip loading image }
      if XMLHasAttr(Node, 'firstgid') then
        TileMap.BlocksTilesetFirstGID := StrToInt(XMLAttr(Node, 'firstgid'));
    end
    else
    begin
      { Normal tileset - load it }
      if not LoadTileSet(FolderPath, Node, TileMap.TileSets[TileMap.TileSetCount]) then
      begin
        XMLFreeTree(MapNode);
        FreeTileMap(TileMap);
        Exit;
      end;
      Inc(TileMap.TileSetCount);
    end;
    Node := XMLNextSibling(Node, 'tileset');
  end;

  { Verify at least one tileset was loaded }
  if TileMap.TileSetCount = 0 then
  begin
    LoadTileMapError := 'No tilesets found';
    XMLFreeTree(MapNode);
    FreeTileMap(TileMap);
    Exit;
  end;

  { Process layers with merging logic }
  { Scan for objectgroup to determine layer split point }
  ObjectGroupFound := False;
  ObjectGroupNode := nil;
  LayersBefore := 0;
  LayersAfter := 0;

  Node := MapNode^.FirstChild;
  while Node <> nil do
  begin
    if Node^.Name = 'objectgroup' then
    begin
      ObjectGroupFound := True;
      ObjectGroupNode := Node;  { Save node pointer for callback after loading }
    end
    else if Node^.Name = 'layer' then
    begin
      if ObjectGroupFound then
        LoadTileMapLayer(Node, TileMap, TileMapLayer_Front)
      else
        LoadTileMapLayer(Node, TileMap, TileMapLayer_Back);
    end;
    Node := Node^.NextSibling;
  end;

  { Call objectgroup callback AFTER tilemap is fully loaded }
  if (ObjectGroupNode <> nil) and (@ObjectGroupProc <> nil) then
    ObjectGroupProc(ObjectGroupNode);

  XMLFreeTree(MapNode);
  LoadTileMap := True;
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

  { Free blocks layer }
  if TileMap.BlocksLayer <> nil then
  begin
    FreeMem(TileMap.BlocksLayer, LongInt(TileMap.Width) * LongInt(TileMap.Height));
    TileMap.BlocksLayer := nil;
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

{ Check if a tile position has a specific block type }
function IsBlockType(const TileMap: TTileMap; X, Y: Word; BlockType: Byte): Boolean;
var
  Index: LongInt;
begin
  IsBlockType := False;

  { No blocks layer means everything is passable }
  if TileMap.BlocksLayer = nil then
    Exit;

  { Bounds check }
  if (X >= TileMap.Width) or (Y >= TileMap.Height) then
    Exit;

  { Calculate index and check block type }
  Index := LongInt(Y) * LongInt(TileMap.Width) + LongInt(X);
  IsBlockType := (TileMap.BlocksLayer^[Index] = BlockType);
end;

end.
