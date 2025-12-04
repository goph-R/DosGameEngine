# DRECT - Dirty Rectangle System

Optimized rendering by tracking changed screen regions.

## Functions

```pascal
procedure AddDirtyRect(const Rect: TRectangle);
procedure FlushDirtyRects(BackBuffer: PFrameBuffer);
procedure ClearDirtyRects;
function GetDirtyCount: Word;
```

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

  CloseVGA;
  FreeFrameBuffer(BackBuffer);
end;
```

## How It Works

1. **AddDirtyRect**: Marks a region as changed (max 256 rectangles)
2. **FlushDirtyRects**: Copies ONLY dirty regions from backbuffer to screen
3. **ClearDirtyRects**: Resets for next frame

## Notes

- Max 256 dirty rectangles per frame
- Automatically merges overlapping regions
- Significantly faster than full-screen blit for UI/sparse updates
- Used by VGAUI for widget rendering
- For full-screen updates, use `RenderFrameBuffer` instead

## Performance

```
Full screen blit: ~64000 bytes/frame
Dirty rect (1 button): ~2400 bytes/frame (26x faster)
```
