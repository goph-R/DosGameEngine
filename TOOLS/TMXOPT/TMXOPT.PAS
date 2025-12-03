{ TMX Optimizer - Collapses multi-layer TMX files into 2-layer atlas-based maps }
{ Part of DOS Game Engine - 2025 }
program TMXOptimizer;

{$M 16384,0,655360}  { Stack, MinHeap, MaxHeap }

uses
  MiniXML, PCX, GenTypes, StrUtil;

const
  MaxTileSets     = 4;
  MaxRawLayers    = 16;
  MaxStackHeight  = 8;
  MaxUniqueStacks = 4096;
  AtlasWidth      = 256;
  AtlasHeight     = 240;
  AtlasesMax      = 4;

type
  { Tileset info from TMX }
  PTileSetInfo = ^TTileSetInfo;
  TTileSetInfo = record
    FirstGID     : Word;
    TileWidth    : Byte;
    TileHeight   : Byte;
    TileCount    : Word;
    Columns      : Word;
    ImageNode    : PXMLNode;
    IsBlocks     : Boolean;
    IsObjects    : Boolean;
    Image        : TImage;
  end;

  { Raw layer before stacking }
  TRawLayerKind = (lkFront, lkBack, lkBlocks, lkIgnore);

  PRawLayer = ^TRawLayer;
  TRawLayer = record
    Name    : string[32];
    Kind    : TRawLayerKind;
    Data    : PWord;
    XMLNode : PXMLNode;
  end;

  { Tile stack per cell }
  TTileID = Word;

  PTileStack = ^TTileStack;
  TTileStack = record
    Count: Byte;
    Items: array[0..MaxStackHeight-1] of TTileID;
  end;

  { Stack registry for deduplication }
  TStackKey = TTileStack;

  TStackRegistry = record
    Count       : Word;
    Keys        : array[0..MaxUniqueStacks-1] of TStackKey;
    LocalIndex  : array[0..MaxUniqueStacks-1] of Word;
  end;

  { Atlas tileset }
  PAtlas = ^TAtlas;
  TAtlas = record
    FirstGID    : Word;
    TileWidth   : Byte;
    TileHeight  : Byte;
    Columns     : Word;
    Rows        : Word;
    MaxTiles    : Word;
    UsedTiles   : Word;
    Image       : TImage;
    TilesetXML  : PXMLNode;
  end;

  { Composite tile info }
  TCompositeInfo = record
    AtlasIndex : Byte;
    TileIndex  : Word;
  end;

var
  { Global state }
  InputFile  : string;
  OutputFile : string;
  MapWidth   : Word;
  MapHeight  : Word;
  TileWidth  : Byte;
  TileHeight : Byte;

  { XML tree }
  Root       : PXMLNode;
  MapNode    : PXMLNode;

  { Tilesets }
  TileSets          : array[0..MaxTileSets-1] of TTileSetInfo;
  TileSetCount      : Byte;
  BlocksTileSetIndex: ShortInt;
  ObjectsTileSetIndex: ShortInt;
  OldBlocksFirstGID : Word;
  OldObjectsFirstGID: Word;

  { TSX external tileset tracking }
  ExternalTilesets   : array[0..MaxTileSets-1] of PXMLNode;
  IsExternalTileset  : array[0..MaxTileSets-1] of Boolean;

  { Raw layers }
  RawLayers     : array[0..MaxRawLayers-1] of TRawLayer;
  RawLayerCount : Byte;

  { Stacks }
  FrontStacks, BackStacks: Pointer;  { Array of TTileStack }
  StackReg    : TStackRegistry;

  { Final layers }
  BackLayer, FrontLayer: PWord;
  CompositeCount: Word;

  { Atlases }
  Atlases     : array[0..AtlasesMax-1] of TAtlas;
  AtlasCount  : Byte;
  CompositeTiles: array[1..MaxUniqueStacks] of TCompositeInfo;

{ ========================================================================== }
{ Utility functions }
{ ========================================================================== }

function StackAt(Base: Pointer; X, Y, W: Word): PTileStack;
begin
  StackAt := Ptr(Seg(Base^), Ofs(Base^) + ((Y * W) + X) * SizeOf(TTileStack));
end;

function SameStack(const A, B: TTileStack): Boolean;
var
  i: Byte;
begin
  if A.Count <> B.Count then
  begin
    SameStack := False;
    Exit;
  end;
  for i := 0 to A.Count - 1 do
    if A.Items[i] <> B.Items[i] then
    begin
      SameStack := False;
      Exit;
    end;
  SameStack := True;
end;

function FindStackIndex(const Reg: TStackRegistry; const S: TTileStack): Integer;
var
  i: Word;
begin
  for i := 0 to Reg.Count - 1 do
    if SameStack(Reg.Keys[i], S) then
    begin
      FindStackIndex := i;
      Exit;
    end;
  FindStackIndex := -1;
end;

{ ========================================================================== }
{ Phase A - Load TMX and tilesets }
{ ========================================================================== }

function GetFolderPath(const FilePath: string): string;
var
  i: Integer;
begin
  for i := Length(FilePath) downto 1 do
    if FilePath[i] = '\' then
    begin
      GetFolderPath := Copy(FilePath, 1, i);
      Exit;
    end;
  GetFolderPath := '';
end;

function FixPath(const Path: string): string;
var
  i: Integer;
  Result: string;
begin
  Result := Path;
  for i := 1 to Length(Result) do
    if Result[i] = '/' then
      Result[i] := '\';
  FixPath := Result;
end;

function LoadTileSetInfo(const FolderPath: string; TilesetNode: PXMLNode;
                         var TileSet: TTileSetInfo): Boolean;
var
  ImageNode: PXMLNode;
  SourcePath, FullPath: string;
  i: Integer;
  Name: string;
  Palette: TPalette;
begin
  LoadTileSetInfo := False;

  { Read attributes }
  if not XMLHasAttr(TilesetNode, 'firstgid') then
  begin
    WriteLn('ERROR: Tileset missing firstgid');
    Exit;
  end;
  TileSet.FirstGID := StrToInt(XMLAttr(TilesetNode, 'firstgid'));

  if not XMLHasAttr(TilesetNode, 'tilewidth') then
  begin
    WriteLn('ERROR: Tileset missing tilewidth');
    Exit;
  end;
  TileSet.TileWidth := StrToInt(XMLAttr(TilesetNode, 'tilewidth'));

  if not XMLHasAttr(TilesetNode, 'tileheight') then
  begin
    WriteLn('ERROR: Tileset missing tileheight');
    Exit;
  end;
  TileSet.TileHeight := StrToInt(XMLAttr(TilesetNode, 'tileheight'));

  if not XMLHasAttr(TilesetNode, 'columns') then
  begin
    WriteLn('ERROR: Tileset missing columns');
    Exit;
  end;
  TileSet.Columns := StrToInt(XMLAttr(TilesetNode, 'columns'));

  if XMLHasAttr(TilesetNode, 'tilecount') then
    TileSet.TileCount := StrToInt(XMLAttr(TilesetNode, 'tilecount'))
  else
    TileSet.TileCount := 0;

  { Check if it's a special tileset }
  Name := '';
  if XMLHasAttr(TilesetNode, 'name') then
    Name := XMLAttr(TilesetNode, 'name');

  TileSet.IsBlocks := (Name = 'Blocks');
  TileSet.IsObjects := (Name = 'Objects');

  { Find image node }
  ImageNode := XMLFirstChild(TilesetNode, 'image');
  if ImageNode = nil then
  begin
    { Objects tileset might not have a single image }
    if not TileSet.IsObjects then
      WriteLn('WARNING: Tileset has no <image> node');
    TileSet.ImageNode := nil;
    LoadTileSetInfo := True;
    Exit;
  end;

  TileSet.ImageNode := ImageNode;

  { Load image if it's not Blocks or Objects (we only need visual tilesets) }
  if not TileSet.IsBlocks and not TileSet.IsObjects then
  begin
    if not XMLHasAttr(ImageNode, 'source') then
    begin
      WriteLn('ERROR: Image node missing source');
      Exit;
    end;

    SourcePath := XMLAttr(ImageNode, 'source');

    { Replace / with \ for DOS }
    for i := 1 to Length(SourcePath) do
      if SourcePath[i] = '/' then
        SourcePath[i] := '\';

    { Change extension to .PCX }
    i := Length(SourcePath);
    while (i > 0) and (SourcePath[i] <> '.') do
      Dec(i);
    if i > 0 then
      SourcePath := Copy(SourcePath, 1, i) + 'PCX';

    FullPath := FolderPath + SourcePath;

    WriteLn('  Loading tileset image: ', FullPath);
    if not LoadPCXWithPalette(FullPath, TileSet.Image, Palette) then
    begin
      WriteLn('ERROR: Failed to load tileset image: ', GetLastErrorMessage);
      Exit;
    end;
  end;

  LoadTileSetInfo := True;
end;

function ParseCSVLayer(const CSVText: string; var Data: PWord;
                       Width, Height: Word): Boolean;
var
  i, j, val: Word;
  NumStr: string;
  InNum: Boolean;
  Digit: Char;
begin
  ParseCSVLayer := False;

  GetMem(Data, Width * Height * SizeOf(Word));
  if Data = nil then
  begin
    WriteLn('ERROR: Out of memory allocating layer data');
    Exit;
  end;

  i := 1;
  j := 0;
  NumStr := '';
  InNum := False;

  while (i <= Length(CSVText)) and (j < Width * Height) do
  begin
    Digit := CSVText[i];

    if (Digit >= '0') and (Digit <= '9') then
    begin
      NumStr := NumStr + Digit;
      InNum := True;
    end
    else if (Digit = ',') or (Digit = #10) or (Digit = #13) then
    begin
      if InNum then
      begin
        val := StrToInt(NumStr);
        Data^[j] := val;
        Inc(j);
        NumStr := '';
        InNum := False;
      end;
    end;

    Inc(i);
  end;

  { Handle last number if no trailing comma }
  if InNum and (j < Width * Height) then
  begin
    val := StrToInt(NumStr);
    Data^[j] := val;
    Inc(j);
  end;

  if j <> Width * Height then
  begin
    WriteLn('ERROR: Layer data count mismatch. Expected ', Width * Height, ', got ', j);
    FreeMem(Data, Width * Height * SizeOf(Word));
    Data := nil;
    Exit;
  end;

  ParseCSVLayer := True;
end;

procedure LoadTMXFile;
var
  i: Integer;
  TilesetNode, LayerNode, DataNode: PXMLNode;
  FolderPath: string;
  FirstObjectGroup: Boolean;
  CSVText: string;
  LayerWidth, LayerHeight: Word;
  AttrVal: string;
  ResolvedTilesets: array[0..MaxTileSets-1] of PXMLNode;
  ResolvedCount: Byte;
  TSXSource, TSXPath, FirstGIDAttr: string;
  ExternalTSXNode: PXMLNode;
begin
  WriteLn('Phase A: Loading TMX file...');

  { Load XML }
  if not XMLLoadFile(InputFile, Root) then
  begin
    WriteLn('ERROR: Failed to load TMX file: ', GetLoadXMLError);
    Halt(1);
  end;

  { Find <map> node }
  MapNode := Root;
  if MapNode^.Name <> 'map' then
  begin
    WriteLn('ERROR: Root node is not <map>');
    Halt(1);
  end;

  { Read map dimensions }
  if not XMLHasAttr(MapNode, 'width') or not XMLHasAttr(MapNode, 'height') then
  begin
    WriteLn('ERROR: Map missing width or height');
    Halt(1);
  end;

  MapWidth := StrToInt(XMLAttr(MapNode, 'width'));
  MapHeight := StrToInt(XMLAttr(MapNode, 'height'));
  TileWidth := StrToInt(XMLAttr(MapNode, 'tilewidth'));
  TileHeight := StrToInt(XMLAttr(MapNode, 'tileheight'));

  WriteLn('  Map size: ', MapWidth, 'x', MapHeight, ' tiles (', TileWidth, 'x', TileHeight, ' px)');

  FolderPath := GetFolderPath(InputFile);

  { ===== STEP 1: Resolve external tilesets (TSX files) ===== }
  ResolvedCount := 0;
  TilesetNode := XMLFirstChild(MapNode, 'tileset');
  while (TilesetNode <> nil) and (ResolvedCount < MaxTileSets) do
  begin
    if XMLHasAttr(TilesetNode, 'source') then
    begin
      { External tileset reference - load TSX file }
      TSXSource := FixPath(XMLAttr(TilesetNode, 'source'));
      TSXPath := FolderPath + TSXSource;

      WriteLn('  Loading external tileset: ', TSXPath);

      { Load external TSX }
      if not XMLLoadFile(TSXPath, ExternalTSXNode) then
      begin
        WriteLn('ERROR: Failed to load external tileset: ', GetLoadXMLError);
        { Free any previously loaded external tilesets }
        for i := 0 to ResolvedCount - 1 do
          if IsExternalTileset[i] then
            XMLFreeTree(ExternalTilesets[i]);
        Halt(1);
      end;

      { Copy firstgid attribute from reference to external node }
      if XMLHasAttr(TilesetNode, 'firstgid') then
      begin
        FirstGIDAttr := XMLAttr(TilesetNode, 'firstgid');
        XMLSetAttr(ExternalTSXNode, 'firstgid', FirstGIDAttr);
      end;

      { Store the external node }
      ResolvedTilesets[ResolvedCount] := ExternalTSXNode;
      IsExternalTileset[ResolvedCount] := True;
      ExternalTilesets[ResolvedCount] := ExternalTSXNode;
      Inc(ResolvedCount);
    end
    else
    begin
      { Internal tileset - use as-is }
      ResolvedTilesets[ResolvedCount] := TilesetNode;
      IsExternalTileset[ResolvedCount] := False;
      ExternalTilesets[ResolvedCount] := nil;
      Inc(ResolvedCount);
    end;

    TilesetNode := XMLNextSibling(TilesetNode, 'tileset');
  end;

  { ===== STEP 2: Process resolved tilesets ===== }
  for i := 0 to ResolvedCount - 1 do
  begin
    WriteLn('  Processing tileset #', i + 1);

    if not LoadTileSetInfo(FolderPath, ResolvedTilesets[i], TileSets[TileSetCount]) then
    begin
      WriteLn('ERROR: Failed to load tileset');
      Halt(1);
    end;

    if TileSets[TileSetCount].IsBlocks then
    begin
      BlocksTileSetIndex := TileSetCount;
      OldBlocksFirstGID := TileSets[TileSetCount].FirstGID;
      WriteLn('    Blocks tileset detected (FirstGID=', OldBlocksFirstGID, ')');
    end;

    if TileSets[TileSetCount].IsObjects then
    begin
      ObjectsTileSetIndex := TileSetCount;
      OldObjectsFirstGID := TileSets[TileSetCount].FirstGID;
      WriteLn('    Objects tileset detected (FirstGID=', OldObjectsFirstGID, ')');
    end;

    Inc(TileSetCount);
  end;

  if TileSetCount = 0 then
  begin
    WriteLn('ERROR: No tilesets found');
    Halt(1);
  end;

  { Load layers and determine front/back split }
  FirstObjectGroup := True;
  LayerNode := MapNode^.FirstChild;

  while (LayerNode <> nil) and (RawLayerCount < MaxRawLayers) do
  begin
    if LayerNode^.Name = 'objectgroup' then
    begin
      if FirstObjectGroup then
      begin
        WriteLn('  Found objectgroup separator');
        FirstObjectGroup := False;
      end;
    end
    else if LayerNode^.Name = 'layer' then
    begin
      with RawLayers[RawLayerCount] do
      begin
        if XMLHasAttr(LayerNode, 'name') then
          Name := XMLAttr(LayerNode, 'name')
        else
          Name := 'Layer' + IntToStr(RawLayerCount);

        { Determine layer kind }
        if XMLHasAttr(LayerNode, 'properties') then
          Kind := lkBlocks
        else if FirstObjectGroup then
          Kind := lkFront
        else
          Kind := lkBack;

        XMLNode := LayerNode;

        { Parse CSV data }
        DataNode := XMLFirstChild(LayerNode, 'data');
        if DataNode = nil then
        begin
          WriteLn('ERROR: Layer has no <data> node');
          Halt(1);
        end;

        if not XMLHasAttr(DataNode, 'encoding') or (XMLAttr(DataNode, 'encoding') <> 'csv') then
        begin
          WriteLn('ERROR: Only CSV encoding supported');
          Halt(1);
        end;

        CSVText := XMLGetText(DataNode);

        { Get layer dimensions }
        if XMLHasAttr(LayerNode, 'width') then
          LayerWidth := StrToInt(XMLAttr(LayerNode, 'width'))
        else
          LayerWidth := MapWidth;

        if XMLHasAttr(LayerNode, 'height') then
          LayerHeight := StrToInt(XMLAttr(LayerNode, 'height'))
        else
          LayerHeight := MapHeight;

        if Kind <> lkBlocks then
        begin
          WriteLn('  Loading layer "', Name, '" (',
                  LayerWidth, 'x', LayerHeight, ') as ',
                  Ord(Kind):1);

          if not ParseCSVLayer(CSVText, Data, LayerWidth, LayerHeight) then
            Halt(1);

          { Clear CSV text to save memory }
          XMLSetText(DataNode, '');
        end
        else
        begin
          WriteLn('  Skipping blocks layer "', Name, '"');
          Data := nil;
        end;
      end;

      Inc(RawLayerCount);
    end;

    LayerNode := LayerNode^.NextSibling;
  end;

  WriteLn('  Loaded ', TileSetCount, ' tilesets, ', RawLayerCount, ' layers');
end;

{ ========================================================================== }
{ Phase B - Build Back/Front stacks }
{ ========================================================================== }

procedure BuildStacks;
var
  i, x, y: Word;
  gid: Word;
  S: PTileStack;
  LayerKind: TRawLayerKind;
  StackSize: LongInt;
begin
  WriteLn('Phase B: Building tile stacks...');

  { Allocate stack buffers }
  StackSize := LongInt(MapWidth) * LongInt(MapHeight) * SizeOf(TTileStack);
  GetMem(FrontStacks, StackSize);
  GetMem(BackStacks, StackSize);

  if (FrontStacks = nil) or (BackStacks = nil) then
  begin
    WriteLn('ERROR: Out of memory allocating stacks');
    Halt(1);
  end;

  FillChar(FrontStacks^, StackSize, 0);
  FillChar(BackStacks^, StackSize, 0);

  WriteLn('  Allocated ', StackSize, ' bytes for each stack grid');

  { Process each raw layer in order }
  for i := 0 to RawLayerCount - 1 do
  begin
    LayerKind := RawLayers[i].Kind;

    if (LayerKind = lkFront) or (LayerKind = lkBack) then
    begin
      WriteLn('  Processing layer "', RawLayers[i].Name, '"');

      for y := 0 to MapHeight - 1 do
        for x := 0 to MapWidth - 1 do
        begin
          gid := RawLayers[i].Data^[y * MapWidth + x];

          if gid <> 0 then
          begin
            { Get appropriate stack }
            if LayerKind = lkFront then
              S := StackAt(FrontStacks, x, y, MapWidth)
            else
              S := StackAt(BackStacks, x, y, MapWidth);

            { Append to stack if there's room }
            if S^.Count < MaxStackHeight then
            begin
              S^.Items[S^.Count] := gid;
              Inc(S^.Count);
            end
            else
            begin
              WriteLn('WARNING: Stack overflow at (', x, ',', y, ')');
            end;
          end;
        end;
    end;
  end;

  WriteLn('  Stacks built successfully');
end;

{ ========================================================================== }
{ Phase C - Deduplicate stacks }
{ ========================================================================== }

function AssignLayerFromStacks(StackBase: Pointer; var OutLayer: PWord;
                               const LayerName: string): Word;
var
  x, y: Word;
  S: PTileStack;
  idx: Integer;
  nextIdx: Word;
  LayerSize: LongInt;
begin
  WriteLn('  Processing ', LayerName, ' layer...');

  LayerSize := LongInt(MapWidth) * LongInt(MapHeight) * SizeOf(Word);
  GetMem(OutLayer, LayerSize);
  if OutLayer = nil then
  begin
    WriteLn('ERROR: Out of memory allocating output layer');
    Halt(1);
  end;

  FillChar(OutLayer^, LayerSize, 0);

  nextIdx := 1;

  for y := 0 to MapHeight - 1 do
    for x := 0 to MapWidth - 1 do
    begin
      S := StackAt(StackBase, x, y, MapWidth);

      if S^.Count = 0 then
        OutLayer^[y * MapWidth + x] := 0
      else
      begin
        idx := FindStackIndex(StackReg, S^);
        if idx >= 0 then
          OutLayer^[y * MapWidth + x] := StackReg.LocalIndex[idx]
        else
        begin
          if StackReg.Count >= MaxUniqueStacks then
          begin
            WriteLn('ERROR: Too many unique tile stacks (max ', MaxUniqueStacks, ')');
            Halt(1);
          end;

          StackReg.Keys[StackReg.Count] := S^;
          StackReg.LocalIndex[StackReg.Count] := nextIdx;
          OutLayer^[y * MapWidth + x] := nextIdx;
          Inc(StackReg.Count);
          Inc(nextIdx);
        end;
      end;
    end;

  AssignLayerFromStacks := nextIdx - 1;
end;

procedure DeduplicateStacks;
var
  BackCount, FrontCount: Word;
begin
  WriteLn('Phase C: Deduplicating stacks...');

  { Process both layers }
  BackCount := AssignLayerFromStacks(BackStacks, BackLayer, 'Back');
  FrontCount := AssignLayerFromStacks(FrontStacks, FrontLayer, 'Front');

  { CompositeCount is the total unique stacks }
  CompositeCount := StackReg.Count;

  WriteLn('  Found ', CompositeCount, ' unique tile combinations');
  WriteLn('    Back layer uses: ', BackCount, ' composites');
  WriteLn('    Front layer uses: ', FrontCount, ' composites');
end;

{ ========================================================================== }
{ Phase D - Build atlases and write PCX }
{ ========================================================================== }

function FindTileSetForGID(gid: Word): Integer;
var
  i: Integer;
begin
  for i := 0 to TileSetCount - 1 do
  begin
    if (gid >= TileSets[i].FirstGID) and
       (gid < TileSets[i].FirstGID + TileSets[i].TileCount) then
    begin
      FindTileSetForGID := i;
      Exit;
    end;
  end;
  FindTileSetForGID := -1;
end;

procedure RenderStackToTile(const Stack: TStackKey; var TileBuf: TImage);
var
  i: Byte;
  gid, localID: Word;
  TileSetIdx: Integer;
  Col, Row: Word;
  SrcX, SrcY: Word;
  j, k: Word;
  SrcPtr, DstPtr: PByte;
  Pixel: Byte;
begin
  { Clear tile buffer to transparent }
  FillChar(TileBuf.Data^, LongInt(TileWidth) * LongInt(TileHeight), 0);

  { Render each tile in stack from bottom to top }
  for i := 0 to Stack.Count - 1 do
  begin
    gid := Stack.Items[i];
    TileSetIdx := FindTileSetForGID(gid);

    if TileSetIdx < 0 then
    begin
      WriteLn('WARNING: GID ', gid, ' not found in any tileset');
      Continue;
    end;

    { Skip special tilesets }
    if TileSets[TileSetIdx].IsBlocks or TileSets[TileSetIdx].IsObjects then
      Continue;

    localID := gid - TileSets[TileSetIdx].FirstGID;
    Col := localID mod TileSets[TileSetIdx].Columns;
    Row := localID div TileSets[TileSetIdx].Columns;
    SrcX := Col * TileWidth;
    SrcY := Row * TileHeight;

    { Blit tile with transparency }
    for j := 0 to TileHeight - 1 do
    begin
      SrcPtr := Ptr(Seg(TileSets[TileSetIdx].Image.Data^),
                    Ofs(TileSets[TileSetIdx].Image.Data^) +
                    ((SrcY + j) * TileSets[TileSetIdx].Image.Width + SrcX));
      DstPtr := Ptr(Seg(TileBuf.Data^), Ofs(TileBuf.Data^) + (j * TileWidth));

      for k := 0 to TileWidth - 1 do
      begin
        Pixel := SrcPtr^;
        if Pixel <> 0 then  { 0 = transparent }
          DstPtr^ := Pixel;
        Inc(SrcPtr);
        Inc(DstPtr);
      end;
    end;
  end;
end;

procedure BuildAtlases;
var
  i, localIndex: Word;
  Col, Row: Word;
  DestX, DestY: Word;
  TileBuf: TImage;
  A: PAtlas;
  j, k: Word;
  SrcPtr, DstPtr: PByte;
  NextGID: Word;
  Idx: Word;
  CI: TCompositeInfo;
  Atlas: PAtlas;
  FileName: string;
  MapName: string;
  DotPos: Integer;
  GlobalPalette: TPalette;
begin
  WriteLn('Phase D: Building atlas tilesets...');

  { Initialize first atlas }
  AtlasCount := 1;
  with Atlases[0] do
  begin
    TileWidth := Self.TileWidth;
    TileHeight := Self.TileHeight;
    Columns := AtlasWidth div TileWidth;
    Rows := AtlasHeight div TileHeight;
    MaxTiles := Columns * Rows;
    UsedTiles := 0;

    Image.Width := AtlasWidth;
    Image.Height := AtlasHeight;
    GetMem(Image.Data, LongInt(AtlasWidth) * LongInt(AtlasHeight));
    if Image.Data = nil then
    begin
      WriteLn('ERROR: Out of memory for atlas image');
      Halt(1);
    end;
    FillChar(Image.Data^, LongInt(AtlasWidth) * LongInt(AtlasHeight), 0);
  end;

  WriteLn('  Atlas capacity: ', Atlases[0].MaxTiles, ' tiles (', Atlases[0].Columns, 'x', Atlases[0].Rows, ')');

  { Create tile buffer }
  TileBuf.Width := TileWidth;
  TileBuf.Height := TileHeight;
  GetMem(TileBuf.Data, LongInt(TileWidth) * LongInt(TileHeight));
  if TileBuf.Data = nil then
  begin
    WriteLn('ERROR: Out of memory for tile buffer');
    Halt(1);
  end;

  { Process each composite tile }
  for i := 1 to CompositeCount do
  begin
    { Pick current atlas }
    if Atlases[AtlasCount-1].UsedTiles = Atlases[AtlasCount-1].MaxTiles then
    begin
      if AtlasCount >= AtlasesMax then
      begin
        WriteLn('ERROR: Too many tiles for ', AtlasesMax, ' atlases');
        Halt(1);
      end;

      { Initialize new atlas }
      WriteLn('  Creating atlas #', AtlasCount + 1);
      with Atlases[AtlasCount] do
      begin
        TileWidth := Self.TileWidth;
        TileHeight := Self.TileHeight;
        Columns := AtlasWidth div TileWidth;
        Rows := AtlasHeight div TileHeight;
        MaxTiles := Columns * Rows;
        UsedTiles := 0;

        Image.Width := AtlasWidth;
        Image.Height := AtlasHeight;
        GetMem(Image.Data, LongInt(AtlasWidth) * LongInt(AtlasHeight));
        if Image.Data = nil then
        begin
          WriteLn('ERROR: Out of memory for atlas image');
          Halt(1);
        end;
        FillChar(Image.Data^, LongInt(AtlasWidth) * LongInt(AtlasHeight), 0);
      end;

      Inc(AtlasCount);
    end;

    A := @Atlases[AtlasCount-1];
    localIndex := A^.UsedTiles;
    Inc(A^.UsedTiles);

    CompositeTiles[i].AtlasIndex := AtlasCount-1;
    CompositeTiles[i].TileIndex := localIndex;

    { Compute destination coordinates }
    Col := localIndex mod A^.Columns;
    Row := localIndex div A^.Columns;
    DestX := Col * TileWidth;
    DestY := Row * TileHeight;

    { Render stack into tile buffer }
    RenderStackToTile(StackReg.Keys[i-1], TileBuf);

    { Blit tile buffer into atlas }
    for j := 0 to TileHeight - 1 do
    begin
      SrcPtr := Ptr(Seg(TileBuf.Data^), Ofs(TileBuf.Data^) + (j * TileWidth));
      DstPtr := Ptr(Seg(A^.Image.Data^),
                    Ofs(A^.Image.Data^) + ((DestY + j) * AtlasWidth + DestX));
      Move(SrcPtr^, DstPtr^, TileWidth);
    end;
  end;

  FreeMem(TileBuf.Data, LongInt(TileWidth) * LongInt(TileHeight));

  WriteLn('  Created ', AtlasCount, ' atlas(es) with ', CompositeCount, ' composite tiles');

  { Assign FirstGIDs: atlases start at 1, then Blocks, then Objects }
  NextGID := 1;
  for i := 0 to AtlasCount-1 do
  begin
    Atlases[i].FirstGID := NextGID;
    Inc(NextGID, Atlases[i].UsedTiles);
    WriteLn('    Atlas #', i+1, ': FirstGID=', Atlases[i].FirstGID, ', tiles=', Atlases[i].UsedTiles);
  end;

  if BlocksTileSetIndex >= 0 then
  begin
    TileSets[BlocksTileSetIndex].FirstGID := NextGID;
    Inc(NextGID, TileSets[BlocksTileSetIndex].TileCount);
    WriteLn('    Blocks: FirstGID=', TileSets[BlocksTileSetIndex].FirstGID);
  end;

  if ObjectsTileSetIndex >= 0 then
  begin
    TileSets[ObjectsTileSetIndex].FirstGID := NextGID;
    Inc(NextGID, TileSets[ObjectsTileSetIndex].TileCount);
    WriteLn('    Objects: FirstGID=', TileSets[ObjectsTileSetIndex].FirstGID);
  end;

  { Convert layer data from local indices to real atlas GIDs }
  WriteLn('  Converting layer GIDs...');
  for i := 0 to (MapWidth * MapHeight) - 1 do
  begin
    Idx := BackLayer^[i];
    if Idx > 0 then
    begin
      CI := CompositeTiles[Idx];
      Atlas := @Atlases[CI.AtlasIndex];
      BackLayer^[i] := Atlas^.FirstGID + CI.TileIndex;
    end;

    Idx := FrontLayer^[i];
    if Idx > 0 then
    begin
      CI := CompositeTiles[Idx];
      Atlas := @Atlases[CI.AtlasIndex];
      FrontLayer^[i] := Atlas^.FirstGID + CI.TileIndex;
    end;
  end;

  { Extract map name from input file }
  MapName := InputFile;
  DotPos := Length(MapName);
  while (DotPos > 0) and (MapName[DotPos] <> '.') do
    Dec(DotPos);
  if DotPos > 0 then
    MapName := Copy(MapName, 1, DotPos - 1);

  { Find last backslash }
  DotPos := Length(MapName);
  while (DotPos > 0) and (MapName[DotPos] <> '\') do
    Dec(DotPos);
  if DotPos > 0 then
    MapName := Copy(MapName, DotPos + 1, Length(MapName));

  { Load palette from first tileset for saving }
  if TileSetCount > 0 then
  begin
    { Use the first visual tileset's source image to get palette }
    i := 0;
    while (i < TileSetCount) and
          (TileSets[i].IsBlocks or TileSets[i].IsObjects) do
      Inc(i);

    if i < TileSetCount then
    begin
      { Reload with palette - we need it for saving }
      { For now, use a dummy palette - would need to reload PCX }
      FillChar(GlobalPalette, SizeOf(TPalette), 0);
    end;
  end;

  { Save atlas images }
  for i := 0 to AtlasCount - 1 do
  begin
    FileName := MapName + '_AT' + IntToStr(i+1) + '.PCX';
    WriteLn('  Saving ', FileName);

    if not SavePCX(FileName, Atlases[i].Image, GlobalPalette) then
    begin
      WriteLn('ERROR: Failed to save atlas PCX: ', GetLastErrorMessage);
      Halt(1);
    end;
  end;
end;

{ ========================================================================== }
{ Phase E - Update TMX MiniXML tree }
{ ========================================================================== }

function LayerDataToCSV(Data: PWord; Width, Height: Word): string;
var
  x, y: Word;
  Result: string;
  NumStr: string;
begin
  Result := '';
  for y := 0 to Height - 1 do
  begin
    for x := 0 to Width - 1 do
    begin
      Str(Data^[y * Width + x], NumStr);
      Result := Result + NumStr;
      if (y < Height - 1) or (x < Width - 1) then
        Result := Result + ',';
    end;
    if y < Height - 1 then
      Result := Result + #13#10;
  end;
  LayerDataToCSV := Result;
end;

procedure UpdateTMXTree;
var
  Node, NextNode: PXMLNode;
  TilesetNode, ImageNode, DataNode: PXMLNode;
  LayerNode: PXMLNode;
  i: Integer;
  FileName: string;
  CSVText: string;
begin
  WriteLn('Phase E: Updating TMX structure...');

  { Remove old visual tileset nodes (keep Blocks and Objects) }
  WriteLn('  Removing old tilesets...');
  Node := XMLFirstChild(MapNode, 'tileset');
  while Node <> nil do
  begin
    NextNode := XMLNextSibling(Node, 'tileset');

    { Check if this is Blocks or Objects tileset }
    if XMLHasAttr(Node, 'name') then
    begin
      if (XMLAttr(Node, 'name') <> 'Blocks') and
         (XMLAttr(Node, 'name') <> 'Objects') then
      begin
        { This is a visual tileset, remove it }
        { In MiniXML we can't easily remove, so we just won't write new tilesets }
        { and the old ones will be ignored }
      end
      else
      begin
        { Update FirstGID for special tilesets }
        if XMLAttr(Node, 'name') = 'Blocks' then
        begin
          if BlocksTileSetIndex >= 0 then
            XMLSetAttr(Node, 'firstgid', IntToStr(TileSets[BlocksTileSetIndex].FirstGID));
        end
        else if XMLAttr(Node, 'name') = 'Objects' then
        begin
          if ObjectsTileSetIndex >= 0 then
            XMLSetAttr(Node, 'firstgid', IntToStr(TileSets[ObjectsTileSetIndex].FirstGID));
        end;
      end;
    end;

    Node := NextNode;
  end;

  { Add new atlas tilesets at the beginning }
  WriteLn('  Adding atlas tilesets...');
  for i := 0 to AtlasCount - 1 do
  begin
    TilesetNode := XMLAddChildElement(MapNode, 'tileset');
    XMLSetAttr(TilesetNode, 'firstgid', IntToStr(Atlases[i].FirstGID));
    XMLSetAttr(TilesetNode, 'name', 'Atlas' + IntToStr(i + 1));
    XMLSetAttr(TilesetNode, 'tilewidth', IntToStr(TileWidth));
    XMLSetAttr(TilesetNode, 'tileheight', IntToStr(TileHeight));
    XMLSetAttr(TilesetNode, 'tilecount', IntToStr(Atlases[i].UsedTiles));
    XMLSetAttr(TilesetNode, 'columns', IntToStr(Atlases[i].Columns));

    ImageNode := XMLAddChildElement(TilesetNode, 'image');
    { Extract map name }
    FileName := InputFile;
    while (Length(FileName) > 0) and (FileName[Length(FileName)] <> '\') do
      Delete(FileName, Length(FileName), 1);

    { Build atlas filename }
    FileName := Copy(InputFile, Length(FileName) + 1, Length(InputFile));
    while (Length(FileName) > 0) and (FileName[Length(FileName)] <> '.') do
      Delete(FileName, Length(FileName), 1);
    if Length(FileName) > 0 then
      Delete(FileName, Length(FileName), 1);

    FileName := FileName + '_AT' + IntToStr(i + 1) + '.PCX';

    XMLSetAttr(ImageNode, 'source', FileName);
    XMLSetAttr(ImageNode, 'width', IntToStr(AtlasWidth));
    XMLSetAttr(ImageNode, 'height', IntToStr(AtlasHeight));
  end;

  { Remove old visual layers (keep Blocks layer and objectgroups) }
  WriteLn('  Removing old layers...');
  { We'll mark them by clearing their data, actual removal is complex in MiniXML }

  { Add new Back and Front layers }
  WriteLn('  Adding optimized layers...');

  LayerNode := XMLAddChildElement(MapNode, 'layer');
  XMLSetAttr(LayerNode, 'id', '100');
  XMLSetAttr(LayerNode, 'name', 'Back');
  XMLSetAttr(LayerNode, 'width', IntToStr(MapWidth));
  XMLSetAttr(LayerNode, 'height', IntToStr(MapHeight));

  DataNode := XMLAddChildElement(LayerNode, 'data');
  XMLSetAttr(DataNode, 'encoding', 'csv');
  CSVText := LayerDataToCSV(BackLayer, MapWidth, MapHeight);
  XMLSetText(DataNode, CSVText);

  LayerNode := XMLAddChildElement(MapNode, 'layer');
  XMLSetAttr(LayerNode, 'id', '101');
  XMLSetAttr(LayerNode, 'name', 'Front');
  XMLSetAttr(LayerNode, 'width', IntToStr(MapWidth));
  XMLSetAttr(LayerNode, 'height', IntToStr(MapHeight));

  DataNode := XMLAddChildElement(LayerNode, 'data');
  XMLSetAttr(DataNode, 'encoding', 'csv');
  CSVText := LayerDataToCSV(FrontLayer, MapWidth, MapHeight);
  XMLSetText(DataNode, CSVText);

  WriteLn('  TMX tree updated');
end;

{ ========================================================================== }
{ Phase F - Save and cleanup }
{ ========================================================================== }

procedure SaveAndCleanup;
var
  i: Integer;
  LayerSize: LongInt;
begin
  WriteLn('Phase F: Saving optimized TMX...');

  { Save XML }
  if not XMLSaveFile(OutputFile, Root) then
  begin
    WriteLn('ERROR: Failed to save TMX file: ', GetSaveXMLError);
    Halt(1);
  end;

  WriteLn('  Saved: ', OutputFile);

  { Cleanup }
  WriteLn('  Cleaning up...');

  { Free external TSX trees }
  for i := 0 to TileSetCount - 1 do
    if IsExternalTileset[i] and (ExternalTilesets[i] <> nil) then
      XMLFreeTree(ExternalTilesets[i]);

  { Free XML tree }
  XMLFreeTree(Root);

  { Free raw layer data }
  for i := 0 to RawLayerCount - 1 do
    if RawLayers[i].Data <> nil then
    begin
      LayerSize := LongInt(MapWidth) * LongInt(MapHeight) * SizeOf(Word);
      FreeMem(RawLayers[i].Data, LayerSize);
    end;

  { Free stacks }
  if FrontStacks <> nil then
    FreeMem(FrontStacks, LongInt(MapWidth) * LongInt(MapHeight) * SizeOf(TTileStack));
  if BackStacks <> nil then
    FreeMem(BackStacks, LongInt(MapWidth) * LongInt(MapHeight) * SizeOf(TTileStack));

  { Free final layers }
  if BackLayer <> nil then
    FreeMem(BackLayer, LongInt(MapWidth) * LongInt(MapHeight) * SizeOf(Word));
  if FrontLayer <> nil then
    FreeMem(FrontLayer, LongInt(MapWidth) * LongInt(MapHeight) * SizeOf(Word));

  { Free atlas images }
  for i := 0 to AtlasCount - 1 do
    if Atlases[i].Image.Data <> nil then
      FreeMem(Atlases[i].Image.Data, LongInt(AtlasWidth) * LongInt(AtlasHeight));

  { Free tileset images }
  for i := 0 to TileSetCount - 1 do
    if TileSets[i].Image.Data <> nil then
      FreeMem(TileSets[i].Image.Data,
              LongInt(TileSets[i].Image.Width) * LongInt(TileSets[i].Image.Height));

  WriteLn('  Cleanup complete');
end;

{ ========================================================================== }
{ Main program }
{ ========================================================================== }

begin
  WriteLn('TMX Optimizer v1.0');
  WriteLn('==================');
  WriteLn;

  { Parse command line }
  if ParamCount < 2 then
  begin
    WriteLn('Usage: TMXOPT <input.tmx> <output.tmx>');
    Halt(1);
  end;

  InputFile := ParamStr(1);
  OutputFile := ParamStr(2);

  WriteLn('Input : ', InputFile);
  WriteLn('Output: ', OutputFile);
  WriteLn;

  { Initialize globals }
  TileSetCount := 0;
  RawLayerCount := 0;
  BlocksTileSetIndex := -1;
  ObjectsTileSetIndex := -1;
  StackReg.Count := 0;
  AtlasCount := 0;
  FillChar(IsExternalTileset, SizeOf(IsExternalTileset), 0);
  FillChar(ExternalTilesets, SizeOf(ExternalTilesets), 0);

  { Execute phases }
  LoadTMXFile;
  BuildStacks;
  DeduplicateStacks;
  BuildAtlases;
  UpdateTMXTree;
  SaveAndCleanup;

  WriteLn;
  WriteLn('Optimization complete!');
end.
