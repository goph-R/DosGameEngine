unit Globals;

interface

uses
  VGA, VGAUI, VGAFont;

const
  TileSize = 16;

type
  TCustomUIStyle = object(TUIStyle)
    procedure RenderPanel(const R: TRectangle; Pressed: Boolean; FrameBuffer: PFrameBuffer); virtual;
  end;

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

var
  GemsImage: PImage;

  FontLarge: PFont;
  FontSmall: PFont;

  UIStyle: TCustomUIStyle;

  DialogUI: TUIManager;

procedure DrawGem(GemColor: TGemColor; X, Y: Integer);  

implementation

uses
  GameUnit;

procedure DrawGem(GemColor: TGemColor; X, Y: Integer);
var
  GemRect: TRectangle;
  GemIndex: Integer;
begin
  { Step 1: ALWAYS restore the background first }
  { This wipes whatever 'ghost' data (exploded gems, etc) is in this spot }
  GemRect.X := X;
  GemRect.Y := Y;
  GemRect.Width := TileSize;
  GemRect.Height := TileSize;

  CopyFrameBufferRect(Game.BackgroundBuffer, GemRect, Game.BackBuffer, X, GemRect.Y);

  { Step 2: If it's empty, we are done (background is already restored) }
  if GemColor = Gem_Empty then Exit;

  { Calculate gem sprite index }
  GemIndex := Ord(GemColor);

  { Setup source rectangle in gem sprite sheet }
  GemRect.X := GemIndex * TileSize;
  GemRect.Y := 0;

  { Step 3: Draw gem sprite over the clean background }
  PutImageRect(GemsImage^, GemRect, X, Y, True, Game.BackBuffer);
end;

procedure TCustomUIStyle.RenderPanel(const R: TRectangle; Pressed: Boolean; FrameBuffer: PFrameBuffer);
var
  TC, BC1, BC2, RC: Byte;  
begin

  if Pressed then
  begin
    TC := LowColor;
    BC1 := NormalColor;
    BC2 := HighColor;
    RC := LowColor;
  end
  else
  begin
    TC := HighColor;
    BC1 := LowColor;
    BC2 := 12;
    RC := NormalColor;
  end;

  DrawFillRect(R, RC, FrameBuffer);

  DrawHLine(R.X + 1, R.Y + 1, R.Width - 3, TC, FrameBuffer);                     
  DrawVLine(R.X + 1, R.Y + 1, R.Height - 3, TC, FrameBuffer);                    

  DrawVLine(R.X + R.Width - 2, R.Y + 1, R.Height - 2, BC1, FrameBuffer);
  DrawHLine(R.X + 2, R.Y + R.Height - 2, R.Width - 3, BC1, FrameBuffer);
  DrawVLine(R.X + R.Width - 1, R.Y, R.Height, BC2, FrameBuffer);       
  DrawHLine(R.X + 1, R.Y + R.Height - 1, R.Width - 2, BC2, FrameBuffer);       
end;

end.
