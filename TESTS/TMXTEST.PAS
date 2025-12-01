program TMapTest;

uses
  VGA, VGAPrint, TMXLoad, TMXDraw, Keyboard, RTCTimer, PCX;

var
  TileMap: TTileMap;
  FrameBuffer: PFrameBuffer;
  BackBuffer: PFrameBuffer;
  Background: TImage;
  Running: Boolean;
  CameraX, CameraY: Word;
  ViewWidthTiles, ViewHeightTiles: Word;
  MaxCameraX, MaxCameraY: Word;
  FPS: Real;
  FrameCount: Word;
  LastFPSUpdate: Real;
  StatusText: String;
  I: Integer;
  Palette: TPalette;
  BlocksVisible: Boolean;
  InfoVisible: Boolean;
  FpsVisible: Boolean;

procedure UpdateFPS;
var
  CurrentTime: Real;
  Elapsed: Real;
begin
  Inc(FrameCount);
  CurrentTime := GetTimeSeconds;
  Elapsed := CurrentTime - LastFPSUpdate;

  if Elapsed >= 1.0 then
  begin
    FPS := FrameCount / Elapsed;
    FrameCount := 0;
    LastFPSUpdate := CurrentTime;
  end;
end;

procedure DrawBlocks;
var
  TileX, TileY: Word;
  ScreenX, ScreenY: Integer;
  BlockType: Byte;
  TileWidth, TileHeight: Byte;
begin
  if not BlocksVisible then
    Exit;

  TileWidth := TileMap.TileSets[0].TileWidth;
  TileHeight := TileMap.TileSets[0].TileHeight;

  { Iterate through visible tiles }
  for TileY := 0 to ViewHeightTiles - 1 do
  begin
    for TileX := 0 to ViewWidthTiles - 1 do
    begin
      { Check if tile position is within map bounds }
      if (CameraX + TileX < TileMap.Width) and (CameraY + TileY < TileMap.Height) then
      begin
        { Get block type at this position }
        if IsBlockType(TileMap, CameraX + TileX, CameraY + TileY, 1) then
        begin
          { Block type 1 - display "B" }
          ScreenX := TileX * TileWidth + 4;
          ScreenY := TileY * TileHeight + 4;
          PrintText(ScreenX, ScreenY, 'B', 0, FrameBuffer);
        end
        else if IsBlockType(TileMap, CameraX + TileX, CameraY + TileY, 2) then
        begin
          { Block type 2 - display "T" }
          ScreenX := TileX * TileWidth + 4;
          ScreenY := TileY * TileHeight + 4;
          PrintText(ScreenX, ScreenY, 'T', 0, FrameBuffer);
        end;
      end;
    end;
  end;
end;

procedure DrawUI;
var
  FreeMem: LongInt;
begin
  if FpsVisible then
  begin
    Str(FPS:0:1, StatusText);
    StatusText := 'FPS: ' + StatusText;
    PrintText(5, 5, StatusText, 15, FrameBuffer);
  end;

  if InfoVisible then
  begin
    { Display camera position and FPS }
    Str(CameraX, StatusText);
    StatusText := 'Cam X: ' + StatusText;
    PrintText(5, 20, StatusText, 15, FrameBuffer);

    Str(CameraY, StatusText);
    StatusText := 'Cam Y: ' + StatusText;
    PrintText(5, 30, StatusText, 15, FrameBuffer);

    { Display free conventional memory }
    FreeMem := MemAvail;
    Str(FreeMem, StatusText);
    StatusText := 'Free: ' + StatusText + ' bytes';
    PrintText(5, 45, StatusText, 15, FrameBuffer);

    { Instructions }
    PrintText(5, 60, 'Arrows: Scroll', 15, FrameBuffer);
    PrintText(5, 70, 'ESC: Exit', 15, FrameBuffer);
    PrintText(5, 80, 'F: Toggle FPS', 15, FrameBuffer);
    PrintText(5, 90, 'I: Toggle info', 15, FrameBuffer);

    if TileMap.BlocksLayer <> nil then
      PrintText(5, 100, 'B: Toggle blocks', 15, FrameBuffer);
  end;
end;

begin

  { Load tilemap }
  WriteLn('Loading tilemap from DATA\TEST.TMX...');
  if not LoadTileMap('DATA\TEST.TMX', TileMap, nil) then
  begin
    WriteLn('ERROR: ', GetLoadTileMapError);
    Halt(1);
  end;

  WriteLn('Tilemap loaded successfully!');
  WriteLn('  Map size: ', TileMap.Width, ' x ', TileMap.Height, ' tiles');
  WriteLn('  Tilesets: ', TileMap.TileSetCount);
  for I := 0 to TileMap.TileSetCount - 1 do
  begin
    WriteLn('    Tileset ', I, ': FirstGID=', TileMap.TileSets[I].FirstGID,
            ' Size=', TileMap.TileSets[I].TileWidth, 'x', TileMap.TileSets[I].TileHeight,
            ' Cols=', TileMap.TileSets[I].Columns);
  end;

  if TileMap.BlocksLayer <> nil then
    WriteLn('  Blocks layer: Present')
  else
    WriteLn('  Blocks layer: Not found');

  { Calculate view size in tiles }
  ViewWidthTiles := 320 div TileMap.TileSets[0].TileWidth;
  ViewHeightTiles := 200 div TileMap.TileSets[0].TileHeight + 1;

  WriteLn('  View size: ', ViewWidthTiles, ' x ', ViewHeightTiles, ' tiles');
  WriteLn('Press any key to start...');
  ReadLn;

  { Load palette }
  WriteLn('Loading palette from DATA\TEST.PAL...');
  if not LoadPalette('DATA\TEST.PAL', Palette) then
  begin
    WriteLn('Could not load palette.');
    Halt(1);
  end;

  WriteLn('Loading background from DATA\BG.PCX...');
  if not LoadPCX('DATA\BG.PCX', Background) then
  begin
    WriteLn('Could not background.');
    Halt(1);
  end;

  { Initialize }
  Running := True;
  CameraX := 0;
  CameraY := 0;
  FPS := 0.0;
  FrameCount := 0;
  BlocksVisible := TileMap.BlocksLayer <> nil;
  FpsVisible := True;
  InfoVisible := True;

  { Initialize keyboard handler }
  InitKeyboard;

  { Initialize RTC timer for FPS calculation }
  InitRTC(1024);
  LastFPSUpdate := GetTimeSeconds;

  { Calculate max camera position }
  if TileMap.Width > ViewWidthTiles then
    MaxCameraX := TileMap.Width - ViewWidthTiles
  else
    MaxCameraX := 0;

  if TileMap.Height > ViewHeightTiles then
    MaxCameraY := TileMap.Height - ViewHeightTiles
  else
    MaxCameraY := 0;

  { Enter VGA mode }
  InitVGA;
  SetPalette(Palette);

  BackBuffer := CreateFrameBuffer;
  PutImage(Background, 0, 0, False, BackBuffer);
  FreeImage(Background);

  FrameBuffer := CreateFrameBuffer;

  { Main loop }
  while Running do
  begin
    { Handle input }
    if IsKeyPressed(Key_Escape) then
      Running := False;

    if IsKeyPressed(Key_Left) and (CameraX > 0) then
      Dec(CameraX);

    if IsKeyPressed(Key_Right) and (CameraX < MaxCameraX) then
      Inc(CameraX);

    if IsKeyPressed(Key_Up) and (CameraY > 0) then
      Dec(CameraY);

    if IsKeyPressed(Key_Down) and (CameraY < MaxCameraY) then
      Inc(CameraY);

    if IsKeyPressed(Key_B) then
      BlocksVisible := not BlocksVisible;

    if IsKeyPressed(Key_F) then
      FpsVisible := not FpsVisible;

    if IsKeyPressed(Key_I) then
      InfoVisible := not InfoVisible;

    { Render background image }
    CopyFrameBuffer(BackBuffer, FrameBuffer);

    { Render back layer (background) }
    DrawTileMapLayer(TileMap, TileMapLayer_Back, CameraX, CameraY, ViewWidthTiles, ViewHeightTiles, FrameBuffer);

    { TODO: Render game sprites here }

    { Render front layer (foreground) }
    DrawTileMapLayer(TileMap, TileMapLayer_Front, CameraX, CameraY, ViewWidthTiles, ViewHeightTiles, FrameBuffer);

    { Draw blocks overlay }
    DrawBlocks;

    { Draw UI overlay }
    DrawUI;

    { Display }
    {WaitForVSync;}
    RenderFrameBuffer(FrameBuffer);

    { Update FPS }
    UpdateFPS;

    { Clear key states for next frame }
    ClearKeyPressed;
  end;

  { Cleanup }
  FreeFrameBuffer(FrameBuffer);
  FreeFrameBuffer(BackBuffer);
  CloseVGA;

  FreeTileMap(TileMap);

  DoneRTC;
  DoneKeyboard;

  WriteLn('Tilemap test completed.');
end.
