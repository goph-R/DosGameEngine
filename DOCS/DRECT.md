# DRECT - Dirty Rectangle System

Optimized rendering by tracking changed screen regions.

## Functions

```pascal
procedure AddDirtyRect(const Rect: TRectangle);
procedure FlushDirtyRects(BackBuffer: PFrameBuffer);
procedure ClearDirtyRects;
function GetDirtyCount: Integer;
procedure MergeRectangles(R1, R2: TRectangle; var Result: TRectangle);
```

### AddDirtyRect
Marks a rectangular region as changed. Will be copied to screen on next flush.

### FlushDirtyRects
Copies all dirty rectangles from backbuffer to VGA screen memory, then clears the list.

### ClearDirtyRects
Clears the dirty rectangle list without flushing to screen.

### GetDirtyCount
Returns the current number of dirty rectangles in the list.

### MergeRectangles
Merges two rectangles into one that encompasses both. Useful for sprite movement where you need to clear both old and new positions to avoid trails.

## Example

```pascal
uses VGA, DRect, Sprite;

var
  BackBuffer: PFrameBuffer;
  SpriteRect: TRectangle;
begin
  InitVGA;
  BackBuffer := CreateFrameBuffer;

  { Game loop }
  while Running do
  begin
    { Update sprite position }
    SpriteRect.Left := SpriteX;
    SpriteRect.Top := SpriteY;
    SpriteRect.Right := SpriteX + SpriteWidth;
    SpriteRect.Bottom := SpriteY + SpriteHeight;

    { Draw to backbuffer }
    DrawBackground(BackBuffer);
    DrawSprite(SpriteX, SpriteY, BackBuffer);

    { Mark changed region }
    AddDirtyRect(SpriteRect);

    { Copy only dirty regions to screen }
    FlushDirtyRects(BackBuffer);
    ClearDirtyRects;
  end;

  DoneVGA;
  FreeFrameBuffer(BackBuffer);
end;
```

## Sprite Movement Example

To prevent sprite trails on slow CPUs, merge old and new sprite positions:

```pascal
var
  BackBuffer: PFrameBuffer;
  Sprite: TSpriteInstance;
  OldX, OldY: Integer;
  OldRect, NewRect, MergedRect: TRectangle;

begin
  { Save old position before movement }
  OldX := Sprite.X;
  OldY := Sprite.Y;

  { Update sprite position }
  Sprite.X := Sprite.X + VelocityX;
  Sprite.Y := Sprite.Y + VelocityY;

  { Create rectangles for old and new positions }
  OldRect.X := OldX;
  OldRect.Y := OldY;
  OldRect.Width := 32;
  OldRect.Height := 32;

  NewRect.X := Sprite.X;
  NewRect.Y := Sprite.Y;
  NewRect.Width := 32;
  NewRect.Height := 32;

  { Merge into single rectangle that covers both }
  MergeRectangles(OldRect, NewRect, MergedRect);

  { Clear merged area (removes old sprite) }
  ClearRect(BackBuffer, MergedRect);

  { Draw sprite at new position }
  DrawSprite(Sprite, BackBuffer);

  { Update only the merged region }
  AddDirtyRect(MergedRect);
  FlushDirtyRects(BackBuffer);
  ClearDirtyRects;
end;
```

## How It Works

1. **AddDirtyRect**: Marks a region as changed (max 256 rectangles)
2. **FlushDirtyRects**: Copies ONLY dirty regions from backbuffer to screen
3. **ClearDirtyRects**: Resets for next frame

## Notes

- Max 256 dirty rectangles per frame
- Does NOT automatically merge overlapping regions - use `MergeRectangles` manually when needed
- Significantly faster than full-screen blit for UI/sparse updates
- Used by VGAUI for widget rendering
- For full-screen updates, use `RenderFrameBuffer` instead
- For moving sprites, use `MergeRectangles` to combine old+new positions to prevent trails

## Performance

```
Full screen blit: ~64000 bytes/frame
Dirty rect (1 button): ~2400 bytes/frame (26x faster)
```
