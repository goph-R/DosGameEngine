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