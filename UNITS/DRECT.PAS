unit DRect;

interface

uses VGA;

{ Add a rectangle to the dirty list (will be copied on next flush) }
procedure AddDirtyRect(const R: TRectangle);

{ Copy all dirty rectangles from BackBuffer to screen, then clear list }
procedure FlushDirtyRects(BackBuffer: PFrameBuffer);

{ Clear the dirty rectangle list without flushing }
procedure ClearDirtyRects;

{ Get current number of dirty rectangles }
function GetDirtyCount: Integer;

{ Merge two rectangles into one that encompasses both }
procedure MergeRectangles(R1, R2: TRectangle; var Result: TRectangle);

implementation

const
  MaxDirtyRects = 256;  { Maximum dirty rectangles }

var
  DirtyRects: array[0..MaxDirtyRects - 1] of TRectangle;
  DirtyCount: Integer;

procedure AddDirtyRect(const R: TRectangle);
begin
  if DirtyCount >= MaxDirtyRects then Exit;
  DirtyRects[DirtyCount] := R;
  Inc(DirtyCount);
end;

procedure FlushDirtyRects(BackBuffer: PFrameBuffer);
var
  i: Integer;
  ScreenBuffer: PFrameBuffer;
begin
  ScreenBuffer := GetScreenBuffer;

  { Copy each dirty rectangle from BackBuffer to VGA memory }
  for i := 0 to DirtyCount - 1 do
  begin
    CopyFrameBufferRect(
      BackBuffer, DirtyRects[i],
      ScreenBuffer, DirtyRects[i].X, DirtyRects[i].Y
    );
  end;

  { Clear dirty rect list }
  DirtyCount := 0;
end;

procedure ClearDirtyRects;
begin
  DirtyCount := 0;
end;

function GetDirtyCount: Integer;
begin
  GetDirtyCount := DirtyCount;
end;

procedure MergeRectangles(R1, R2: TRectangle; var Result: TRectangle);
var
  MinX, MinY, MaxX, MaxY: Integer;
begin
  if R1.X < R2.X then MinX := R1.X else MinX := R2.X;
  if R1.Y < R2.Y then MinY := R1.Y else MinY := R2.Y;

  if R1.X + R1.Width > R2.X + R2.Width then
    MaxX := R1.X + R1.Width
  else
    MaxX := R2.X + R2.Width;

  if R1.Y + R1.Height > R2.Y + R2.Height then
    MaxY := R1.Y + R1.Height
  else
    MaxY := R2.Y + R2.Height;

  Result.X := MinX;
  Result.Y := MinY;
  Result.Width := MaxX - MinX;
  Result.Height := MaxY - MinY;
end;

begin
  { Initialize dirty count }
  DirtyCount := 0;
end.
