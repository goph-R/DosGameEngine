unit Sprite;

interface

uses VGA;

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
  	Duration: LongInt; { Milliseconds }
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
  	CurrentTime: LongInt; { Milliseconds }
  	PlayBackward: Boolean; { Only matters when PlayMode is PingPong }
  end;

procedure UpdateSprite(var SpriteInstance: TSpriteInstance; DeltaTime: LongInt);
procedure DrawSprite(var SpriteInstance: TSpriteInstance; FrameBuffer: PFrameBuffer);

implementation

procedure UpdateSprite(var SpriteInstance: TSpriteInstance; DeltaTime: LongInt);
begin
  if SpriteInstance.CurrentTime < 0 then
    Exit;
  SpriteInstance.CurrentTime := SpriteInstance.CurrentTime + DeltaTime;
  if SpriteInstance.CurrentTime > SpriteInstance.Sprite^.Duration then
  begin
  	if SpriteInstance.Sprite^.PlayType = SpritePlayType_Once then
  	  SpriteInstance.CurrentTime := -1 { Disable update }
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
  Progress: LongInt;
  FrameRect: TRectangle;
begin
  if SpriteInstance.Hidden then
    Exit;

  { Handle stopped animation (PlayType_Once finished) }
  if SpriteInstance.CurrentTime < 0 then
  begin
    { Show last frame }
    FrameNumber := SpriteInstance.Sprite^.FrameCount - 1;
  end
  else
  begin
    { Calculate frame number based on current time }
    if SpriteInstance.Sprite^.Duration > 0 then
    begin
      { Calculate progress as frame index (0 to FrameCount-1) }
      Progress := (SpriteInstance.CurrentTime * SpriteInstance.Sprite^.FrameCount) div SpriteInstance.Sprite^.Duration;

      { Clamp to valid range }
      if Progress >= SpriteInstance.Sprite^.FrameCount then
        Progress := SpriteInstance.Sprite^.FrameCount - 1;
      if Progress < 0 then
        Progress := 0;

      FrameNumber := Progress;

      { Reverse frame order if playing backward (PingPong mode) }
      if SpriteInstance.PlayBackward then
        FrameNumber := (SpriteInstance.Sprite^.FrameCount - 1) - FrameNumber;
    end
    else
    begin
      { No duration, show first frame }
      FrameNumber := 0;
    end;
  end;

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