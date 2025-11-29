unit XIStyle;

interface

uses VGA, VGAUI;

type
  TXIStyle = object(TUIStyle)
    procedure RenderPanel(const R: TRectangle; Pressed: Boolean; FrameBuffer: PFrameBuffer); virtual;
  end;

implementation

procedure TXIStyle.RenderPanel(const R: TRectangle; Pressed: Boolean; FrameBuffer: PFrameBuffer);
var
  C1, C2, C3: Byte;  
begin

  if Pressed then
  begin
    C1 := LowColor;
    C2 := HighColor;
    C3 := NormalColor;
  end
  else
  begin
    C1 := HighColor;
    C2 := LowColor;
    C3 := LowColor;
  end;

  DrawFillRect(R, C3, FrameBuffer);

  DrawHLine(R.X + 1, R.Y + 1, R.Width - 2, C1, FrameBuffer);                     
  DrawVLine(R.X + 1, R.Y + 1, R.Height - 2, C2, FrameBuffer);                    

  DrawVLine(R.X + R.Width - 1, R.Y, R.Height, C2, FrameBuffer);       
  DrawHLine(R.X, R.Y + R.Height - 1, R.Width, C2, FrameBuffer);       
  DrawVLine(R.X + R.Width - 2, R.Y + 1, R.Height - 2, C2, FrameBuffer);
  DrawHLine(R.X + 1, R.Y + R.Height - 1, R.Width - 2, C2, FrameBuffer);
end;


end.