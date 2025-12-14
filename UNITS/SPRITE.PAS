unit Sprite;

interface

uses VGA, GenTypes;

const SpritePlayType_Forward = 0;
const SpritePlayType_PingPong = 1;
const SpritePlayType_Once = 2;

const MaxSpriteFrames = 64;

type
  PSprite = ^TSprite;
  TSprite = record
  	Image: PImage;
  	Frames: array[0..MaxSpriteFrames - 1] of TRectangle;
  	FrameCount: Byte;
  	Width: Word;
  	Height: Word;
  	Duration: Real; { Seconds }
  	PlayType: Byte;
  end;

type
  PSpriteInstance = ^TSpriteInstance;
  TSpriteInstance = record
  	Sprite: PSprite;
  	Hidden: Boolean;
  	X: Integer;
  	Y: Integer;
  	FlipX: Boolean;
  	FlipY: Boolean;
  	CurrentTime: Real; { Seconds }
  	PlayBackward: Boolean; { Only matters when PlayMode is PingPong }
  end;

procedure UpdateSprite(var SpriteInstance: TSpriteInstance; DeltaTime: Real);
procedure DrawSprite(var SpriteInstance: TSpriteInstance; FrameBuffer: PFrameBuffer);
function SpriteGetCurrentFrame(var SpriteInstance: TSpriteInstance): Byte;
function CheckSpriteCollision(SpriteA, SpriteB: PSpriteInstance): Boolean;

implementation

function SpriteGetCurrentFrame(var SpriteInstance: TSpriteInstance): Byte;
var
  Progress: Real;
  FrameNumber: Byte;
begin
  { Handle stopped animation (PlayType_Once finished) }
  if SpriteInstance.CurrentTime < 0.0 then
  begin
    FrameNumber := SpriteInstance.Sprite^.FrameCount - 1;
  end
  else
  begin
    { Calculate frame number based on current time }
    if SpriteInstance.Sprite^.Duration > 0.0 then
    begin
      Progress := (SpriteInstance.CurrentTime * SpriteInstance.Sprite^.FrameCount) / SpriteInstance.Sprite^.Duration;
      if Progress >= SpriteInstance.Sprite^.FrameCount then
        Progress := SpriteInstance.Sprite^.FrameCount - 1;
      if Progress < 0.0 then
        Progress := 0.0;
      FrameNumber := Trunc(Progress);
      if SpriteInstance.PlayBackward then
        FrameNumber := (SpriteInstance.Sprite^.FrameCount - 1) - FrameNumber;
    end
    else
    begin
      FrameNumber := 0;
    end;
  end;
  SpriteGetCurrentFrame := FrameNumber;
end;

function CheckSpriteCollision(SpriteA, SpriteB: PSpriteInstance): Boolean;
var
  FrameA, FrameB: Byte;
  RectA, RectB: TRectangle;
  OverlapX1, OverlapY1, OverlapX2, OverlapY2: Integer;
  X, Y: Integer;
  PixelA, PixelB: Byte;
  SrcXA, SrcYA, SrcXB, SrcYB: Integer;
  OffsetA, OffsetB: Word;
begin
  CheckSpriteCollision := False;

  { Skip if either sprite is hidden }
  if SpriteA^.Hidden or SpriteB^.Hidden then
    Exit;

  { Get current frames }
  FrameA := SpriteGetCurrentFrame(SpriteA^);
  FrameB := SpriteGetCurrentFrame(SpriteB^);
  RectA := SpriteA^.Sprite^.Frames[FrameA];
  RectB := SpriteB^.Sprite^.Frames[FrameB];

  { Check bounding box collision first }
  if (SpriteA^.X + RectA.Width <= SpriteB^.X) or
     (SpriteB^.X + RectB.Width <= SpriteA^.X) or
     (SpriteA^.Y + RectA.Height <= SpriteB^.Y) or
     (SpriteB^.Y + RectB.Height <= SpriteA^.Y) then
    Exit;

  { Calculate overlapping region in screen coordinates }
  if SpriteA^.X > SpriteB^.X then
    OverlapX1 := SpriteA^.X
  else
    OverlapX1 := SpriteB^.X;

  if SpriteA^.Y > SpriteB^.Y then
    OverlapY1 := SpriteA^.Y
  else
    OverlapY1 := SpriteB^.Y;

  if SpriteA^.X + RectA.Width < SpriteB^.X + RectB.Width then
    OverlapX2 := SpriteA^.X + RectA.Width
  else
    OverlapX2 := SpriteB^.X + RectB.Width;

  if SpriteA^.Y + RectA.Height < SpriteB^.Y + RectB.Height then
    OverlapY2 := SpriteA^.Y + RectA.Height
  else
    OverlapY2 := SpriteB^.Y + RectB.Height;

  { Check each pixel in the overlapping region }
  for Y := OverlapY1 to OverlapY2 - 1 do
  begin
    for X := OverlapX1 to OverlapX2 - 1 do
    begin
      { Calculate source coordinates for sprite A }
      SrcXA := X - SpriteA^.X;
      SrcYA := Y - SpriteA^.Y;

      { Apply flipping for sprite A }
      if SpriteA^.FlipX then
        SrcXA := RectA.Width - 1 - SrcXA;
      if SpriteA^.FlipY then
        SrcYA := RectA.Height - 1 - SrcYA;

      { Add frame offset }
      SrcXA := SrcXA + RectA.X;
      SrcYA := SrcYA + RectA.Y;

      { Calculate source coordinates for sprite B }
      SrcXB := X - SpriteB^.X;
      SrcYB := Y - SpriteB^.Y;

      { Apply flipping for sprite B }
      if SpriteB^.FlipX then
        SrcXB := RectB.Width - 1 - SrcXB;
      if SpriteB^.FlipY then
        SrcYB := RectB.Height - 1 - SrcYB;

      { Add frame offset }
      SrcXB := SrcXB + RectB.X;
      SrcYB := SrcYB + RectB.Y;

      { Get pixels from source images }
      OffsetA := SrcYA * SpriteA^.Sprite^.Image^.Width + SrcXA;
      OffsetB := SrcYB * SpriteB^.Sprite^.Image^.Width + SrcXB;
      PixelA := PByteArray(SpriteA^.Sprite^.Image^.Data)^[OffsetA];
      PixelB := PByteArray(SpriteB^.Sprite^.Image^.Data)^[OffsetB];

      { Check if both pixels are non-transparent (color 0 = transparent) }
      if (PixelA <> 0) and (PixelB <> 0) then
      begin
        CheckSpriteCollision := True;
        Exit;
      end;
    end;
  end;
end;

procedure UpdateSprite(var SpriteInstance: TSpriteInstance; DeltaTime: Real);
begin
  if SpriteInstance.CurrentTime < 0.0 then
    Exit;
  SpriteInstance.CurrentTime := SpriteInstance.CurrentTime + DeltaTime;
  if SpriteInstance.CurrentTime > SpriteInstance.Sprite^.Duration then
  begin
  	if SpriteInstance.Sprite^.PlayType = SpritePlayType_Once then
  	  SpriteInstance.CurrentTime := -1.0 { Disable update }
  	else if SpriteInstance.Sprite^.PlayType = SpritePlayType_PingPong then
  	begin
  	  SpriteInstance.PlayBackward := not SpriteInstance.PlayBackward;
  	  SpriteInstance.CurrentTime := SpriteInstance.CurrentTime - SpriteInstance.Sprite^.Duration;
  	end
  	else { SpritePlayType_Forward }
  	begin
  	  SpriteInstance.CurrentTime := SpriteInstance.CurrentTime - SpriteInstance.Sprite^.Duration;
  	end;
  end;
end;

procedure DrawSprite(var SpriteInstance: TSpriteInstance; FrameBuffer: PFrameBuffer);
var
  FrameNumber: Byte;
  FrameRect: TRectangle;
begin
  if SpriteInstance.Hidden then
    Exit;

  { Get current frame }
  FrameNumber := SpriteGetCurrentFrame(SpriteInstance);

  { Get the frame rectangle }
  FrameRect := SpriteInstance.Sprite^.Frames[FrameNumber];

  { Draw the sprite frame with flipping support }
  PutFlippedImageRect(
    SpriteInstance.Sprite^.Image^,
    FrameRect,
    SpriteInstance.X,
    SpriteInstance.Y,
    SpriteInstance.FlipX,
    SpriteInstance.FlipY,
    True,  { Transparent = True }
    FrameBuffer
  );
end;

end.