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

begin
  { Initialize dirty count }
  DirtyCount := 0;
end.
