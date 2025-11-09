program TMapTest;

uses
  VGA, TmxLoad, Keyboard, VgaPrint, RTCTimer;

var
  TileMap: TTileMap;
  FrameBuffer: PFrameBuffer;
  Running: Boolean;
  CameraX, CameraY: Word;
  ViewWidthTiles, ViewHeightTiles: Word;
  MaxCameraX, MaxCameraY: Word;
  FPS: Real;
  FrameCount: Word;
  LastFPSUpdate: Real;
  StatusText: String;
  I: Integer;

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

procedure DrawUI;
begin
  { Display camera position and FPS }
  Str(CameraX, StatusText);
  StatusText := 'Cam X: ' + StatusText;
  PrintText(5, 5, StatusText, 15, FrameBuffer);

  Str(CameraY, StatusText);
  StatusText := 'Cam Y: ' + StatusText;
  PrintText(5, 15, StatusText, 15, FrameBuffer);

  Str(FPS:0:1, StatusText);
  StatusText := 'FPS: ' + StatusText;
  PrintText(5, 25, StatusText, 15, FrameBuffer);

  { Instructions }
  PrintText(5, 45, 'Arrow keys: Scroll', 14, FrameBuffer);
  PrintText(5, 55, 'ESC: Exit', 14, FrameBuffer);
end;

begin
  { Initialize }
  Running := True;
  CameraX := 0;
  CameraY := 0;
  FPS := 0.0;
  FrameCount := 0;

  { Initialize keyboard handler }
  InitKeyboard;

  { Initialize RTC timer for FPS calculation }
  InitRTC(1024);
  LastFPSUpdate := GetTimeSeconds;

  { Load tilemap }
  WriteLn('Loading tilemap from DATA\TEST.TMX...');
  if not LoadTileMap('DATA\TEST.TMX', TileMap) then
  begin
    WriteLn('ERROR: ', GetLoadTileMapError());
    DoneRTC;
    DoneKeyboard;
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

  { Calculate view size in tiles (assuming 32x32 tiles for now) }
  if TileMap.TileSetCount > 0 then
  begin
    ViewWidthTiles := 320 div TileMap.TileSets[0].TileWidth;
    ViewHeightTiles := 200 div TileMap.TileSets[0].TileHeight;
  end
  else
  begin
    ViewWidthTiles := 10;
    ViewHeightTiles := 6;
  end;

  { Calculate max camera position }
  if TileMap.Width > ViewWidthTiles then
    MaxCameraX := TileMap.Width - ViewWidthTiles
  else
    MaxCameraX := 0;

  if TileMap.Height > ViewHeightTiles then
    MaxCameraY := TileMap.Height - ViewHeightTiles
  else
    MaxCameraY := 0;

  WriteLn('  View size: ', ViewWidthTiles, ' x ', ViewHeightTiles, ' tiles');
  WriteLn('Press any key to start...');
  ReadLn;

  { Enter VGA mode }
  InitVGA;
  FrameBuffer := CreateFrameBuffer;

  { Main loop }
  while Running do
  begin
    { Handle input }
    if IsKeyPressed(Key_Escape) then
      Running := False;

    if IsKeyDown(Key_Left) and (CameraX > 0) then
      Dec(CameraX);

    if IsKeyDown(Key_Right) and (CameraX < MaxCameraX) then
      Inc(CameraX);

    if IsKeyDown(Key_Up) and (CameraY > 0) then
      Dec(CameraY);

    if IsKeyDown(Key_Down) and (CameraY < MaxCameraY) then
      Inc(CameraY);

    { Clear framebuffer }
    ClearFrameBuffer(FrameBuffer);

    { Render back layer (background) }
    DrawTileMapLayer(TileMap, TileMapLayer_Back, CameraX, CameraY, ViewWidthTiles, ViewHeightTiles, FrameBuffer);

    { TODO: Render game sprites here }

    { Render front layer (foreground) }
    DrawTileMapLayer(TileMap, TileMapLayer_Front, CameraX, CameraY, ViewWidthTiles, ViewHeightTiles, FrameBuffer);

    { Draw UI overlay }
    DrawUI;

    { Display }
    WaitForVSync;
    RenderFrameBuffer(FrameBuffer);

    { Update FPS }
    UpdateFPS;

    { Clear key states for next frame }
    ClearKeyPressed;
  end;

  { Cleanup }
  FreeFrameBuffer(FrameBuffer);
  CloseVGA;

  FreeTileMap(TileMap);

  DoneRTC;
  DoneKeyboard;

  WriteLn('Tilemap test completed.');
end.
