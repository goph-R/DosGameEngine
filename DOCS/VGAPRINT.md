# VGAPRINT - Embedded Bitmap Font

Simple 8×8 monospace bitmap font for VGA Mode 13h.

## Function

```pascal
procedure PrintText(X, Y: Integer; const Text: string; Color: Byte; FB: PFrameBuffer);
```

## Example

```pascal
uses VGA, VGAPrint;

var
  BackBuffer: PFrameBuffer;
begin
  InitVGA;
  BackBuffer := CreateFrameBuffer;

  PrintText(10, 10, 'Hello World!', 15, BackBuffer);
  PrintText(10, 20, 'Score: 1234', 14, BackBuffer);

  RenderFrameBuffer(BackBuffer);
  DoneVGA;
  FreeFrameBuffer(BackBuffer);
end;
```

## Notes

- Fixed 8×8 pixel monospace font
- Embedded in unit (no external files)
- Color 0 = transparent background
- For variable-width fonts, use VGAFONT (see DOCS\VGAFONT.md)

## Character Set

- ASCII 32-127 (printable characters)
- Uppercase/lowercase letters
- Numbers and symbols
