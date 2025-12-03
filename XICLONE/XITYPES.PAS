unit XiTypes;

interface

const
  { Data path - all resources are in DATA\ subfolder }
  DataPath = 'DATA\';

  { Playfield dimensions }
  PlayfieldCols = 6;
  PlayfieldRows = 12;
  TileSize = 16;

  { Screen positions }
  PlayfieldX = 113;  { Game stage start position }
  PlayfieldY = 4;

  { Max dirty rectangles per frame }
  MaxDirtyRects = 96;  { 6x12 playfield = 72 tiles, plus HUD, stack, etc. }

  { Game tuning }
  InitialFallSpeed = 16.0; { 1 tile per second }
  FastFallSpeed = 160.0;   { 10 tile per second, when holding down }

  { Resource filenames }
  BackgroundFile = 'BG1.PCX';
  GemsFile = 'GEMS1.PCX';
  DialogFIle = 'DIALOG.PCX';
  FontLargeImage = 'FONT-LG.PCX';
  FontLargeXML = 'FONT-LG.XML';
  FontSmallImage = 'FONT-SM.PCX';
  FontSmallXML = 'FONT-SM.XML';

  { Next stack preview position }
  NextStackX = 230;
  NextStackY = 31;
  NextLabelX = 226;
  NextLabelY = 17;

  StatLabelsX = 99;

  MaxDialogButtons = 10;

type
  { Gem colors }
  TGemColor = (
    Gem_Empty,       { 0 - No gem }
    Gem_Red,         { 1 - Red gem }
    Gem_Yellow,      { 2 - Yellow gem }
    Gem_Green,       { 3 - Green gem }
    Gem_Blue,        { 4 - Blue gem }
    Gem_Pink,        { 5 - Pink gem }
    Gem_Purple,      { 6 - Purple gem }
    Gem_MagicJewel   { 7 - Special multi-colored gem }
  );

  { Playfield grid }
  TPlayfield = record
    Tiles: array[0..PlayfieldCols - 1, 0..PlayfieldRows - 1] of TGemColor;
    TileChanged: array[0..PlayfieldCols - 1, 0..PlayfieldRows - 1] of Boolean;
  end;

  { Falling gem stack }
  TGemStack = record
    Gems: array[0..2] of TGemColor;  { Top, Middle, Bottom }
    GridX: Integer;     { Grid column (0-5) }
    PixelX: Integer;    { Pixel X position (for rendering) }
    PixelY: Real;       { Pixel Y position (smooth falling) }
    FallSpeed: Real;    { Pixels per second }
    Active: Boolean;    { Is stack currently falling? }
  end;

implementation

end.
