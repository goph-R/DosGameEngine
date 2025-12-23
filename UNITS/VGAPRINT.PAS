{ VGAPRINT.PAS - Embedded 8x8 bitmap font renderer

  Purpose: Simple, fast text rendering using an embedded fixed-width
           8x8 bitmap font. No external files required - font data is
           compiled directly into the executable.

  Font Characteristics:
    - Fixed 8x8 pixel monospace font
    - 96 printable characters (ASCII 32-127: space through tilde)
    - No external dependencies (embedded font data)
    - Fast rendering (no alignment or color replacement overhead)

  Features:
    - Direct framebuffer rendering
    - Simple API: PrintText(x, y, text, color, fb)
    - Minimal memory footprint (768 bytes font data)

  Usage Example:
    PrintText(10, 10, 'Score: 1000', 15, fb);

  When to use:
    - Quick debug output during development
    - Simple fixed-width text displays
    - Retro monospace aesthetic
    - Minimal memory/file overhead needed

  When to use VGAFONT instead:
    - Variable-width proportional fonts
    - Need text alignment (left/center/right)
    - Runtime color replacement needed
    - Custom font styles from PCX files
}

unit VGAPrint;

interface

uses VGA;

procedure PrintText(x, y: Integer; s: string; Color: Byte; FrameBuffer: PFrameBuffer);

implementation

{ Embedded 8x8 font data - basic ASCII printable characters (32-127) }
{ Each character is 8 bytes, each byte is one row of 8 pixels }
const
  Font8x8: array[32..127, 0..7] of Byte = (
    { Space (32) }
    ($00, $00, $00, $00, $00, $00, $00, $00),
    { ! (33) }
    ($18, $3C, $3C, $18, $18, $00, $18, $00),
    { " (34) }
    ($36, $36, $36, $00, $00, $00, $00, $00),
    { # (35) }
    ($36, $36, $7F, $36, $7F, $36, $36, $00),
    { $ (36) }
    ($0C, $3E, $03, $1E, $30, $1F, $0C, $00),
    { % (37) }
    ($00, $63, $33, $18, $0C, $66, $63, $00),
    { & (38) }
    ($1C, $36, $1C, $6E, $3B, $33, $6E, $00),
    { ' (39) }
    ($06, $06, $03, $00, $00, $00, $00, $00),
    { ( (40) }
    ($18, $0C, $06, $06, $06, $0C, $18, $00),
    { ) (41) }
    ($06, $0C, $18, $18, $18, $0C, $06, $00),
    { * (42) }
    ($00, $66, $3C, $FF, $3C, $66, $00, $00),
    { + (43) }
    ($00, $0C, $0C, $3F, $0C, $0C, $00, $00),
    { , (44) }
    ($00, $00, $00, $00, $00, $0C, $0C, $06),
    { - (45) }
    ($00, $00, $00, $3F, $00, $00, $00, $00),
    { . (46) }
    ($00, $00, $00, $00, $00, $0C, $0C, $00),
    { / (47) }
    ($60, $30, $18, $0C, $06, $03, $01, $00),
    { 0 (48) }
    ($3E, $63, $73, $7B, $6F, $67, $3E, $00),
    { 1 (49) }
    ($0C, $0E, $0C, $0C, $0C, $0C, $3F, $00),
    { 2 (50) }
    ($1E, $33, $30, $1C, $06, $33, $3F, $00),
    { 3 (51) }
    ($1E, $33, $30, $1C, $30, $33, $1E, $00),
    { 4 (52) }
    ($38, $3C, $36, $33, $7F, $30, $78, $00),
    { 5 (53) }
    ($3F, $03, $1F, $30, $30, $33, $1E, $00),
    { 6 (54) }
    ($1C, $06, $03, $1F, $33, $33, $1E, $00),
    { 7 (55) }
    ($3F, $33, $30, $18, $0C, $0C, $0C, $00),
    { 8 (56) }
    ($1E, $33, $33, $1E, $33, $33, $1E, $00),
    { 9 (57) }
    ($1E, $33, $33, $3E, $30, $18, $0E, $00),
    { : (58) }
    ($00, $0C, $0C, $00, $00, $0C, $0C, $00),
    { ; (59) }
    ($00, $0C, $0C, $00, $00, $0C, $0C, $06),
    { < (60) }
    ($18, $0C, $06, $03, $06, $0C, $18, $00),
    { = (61) }
    ($00, $00, $3F, $00, $00, $3F, $00, $00),
    { > (62) }
    ($06, $0C, $18, $30, $18, $0C, $06, $00),
    { ? (63) }
    ($1E, $33, $30, $18, $0C, $00, $0C, $00),
    { @ (64) }
    ($3E, $63, $7B, $7B, $7B, $03, $1E, $00),
    { A (65) }
    ($0C, $1E, $33, $33, $3F, $33, $33, $00),
    { B (66) }
    ($3F, $66, $66, $3E, $66, $66, $3F, $00),
    { C (67) }
    ($3C, $66, $03, $03, $03, $66, $3C, $00),
    { D (68) }
    ($1F, $36, $66, $66, $66, $36, $1F, $00),
    { E (69) }
    ($7F, $46, $16, $1E, $16, $46, $7F, $00),
    { F (70) }
    ($7F, $46, $16, $1E, $16, $06, $0F, $00),
    { G (71) }
    ($3C, $66, $03, $03, $73, $66, $7C, $00),
    { H (72) }
    ($33, $33, $33, $3F, $33, $33, $33, $00),
    { I (73) }
    ($1E, $0C, $0C, $0C, $0C, $0C, $1E, $00),
    { J (74) }
    ($78, $30, $30, $30, $33, $33, $1E, $00),
    { K (75) }
    ($67, $66, $36, $1E, $36, $66, $67, $00),
    { L (76) }
    ($0F, $06, $06, $06, $46, $66, $7F, $00),
    { M (77) }
    ($63, $77, $7F, $7F, $6B, $63, $63, $00),
    { N (78) }
    ($63, $67, $6F, $7B, $73, $63, $63, $00),
    { O (79) }
    ($1C, $36, $63, $63, $63, $36, $1C, $00),
    { P (80) }
    ($3F, $66, $66, $3E, $06, $06, $0F, $00),
    { Q (81) }
    ($1E, $33, $33, $33, $3B, $1E, $38, $00),
    { R (82) }
    ($3F, $66, $66, $3E, $36, $66, $67, $00),
    { S (83) }
    ($1E, $33, $07, $0E, $38, $33, $1E, $00),
    { T (84) }
    ($3F, $2D, $0C, $0C, $0C, $0C, $1E, $00),
    { U (85) }
    ($33, $33, $33, $33, $33, $33, $3F, $00),
    { V (86) }
    ($33, $33, $33, $33, $33, $1E, $0C, $00),
    { W (87) }
    ($63, $63, $63, $6B, $7F, $77, $63, $00),
    { X (88) }
    ($63, $63, $36, $1C, $1C, $36, $63, $00),
    { Y (89) }
    ($33, $33, $33, $1E, $0C, $0C, $1E, $00),
    { Z (90) }
    ($7F, $63, $31, $18, $4C, $66, $7F, $00),
    { [ (91) }
    ($1E, $06, $06, $06, $06, $06, $1E, $00),
    { \ (92) }
    ($03, $06, $0C, $18, $30, $60, $40, $00),
    { ] (93) }
    ($1E, $18, $18, $18, $18, $18, $1E, $00),
    { ^ (94) }
    ($08, $1C, $36, $63, $00, $00, $00, $00),
    { _ (95) }
    ($00, $00, $00, $00, $00, $00, $00, $FF),
    { ` (96) }
    ($0C, $0C, $18, $00, $00, $00, $00, $00),
    { a (97) }
    ($00, $00, $1E, $30, $3E, $33, $6E, $00),
    { b (98) }
    ($07, $06, $06, $3E, $66, $66, $3B, $00),
    { c (99) }
    ($00, $00, $1E, $33, $03, $33, $1E, $00),
    { d (100) }
    ($38, $30, $30, $3E, $33, $33, $6E, $00),
    { e (101) }
    ($00, $00, $1E, $33, $3F, $03, $1E, $00),
    { f (102) }
    ($1C, $36, $06, $0F, $06, $06, $0F, $00),
    { g (103) }
    ($00, $00, $6E, $33, $33, $3E, $30, $1F),
    { h (104) }
    ($07, $06, $36, $6E, $66, $66, $67, $00),
    { i (105) }
    ($0C, $00, $0E, $0C, $0C, $0C, $1E, $00),
    { j (106) }
    ($30, $00, $30, $30, $30, $33, $33, $1E),
    { k (107) }
    ($07, $06, $66, $36, $1E, $36, $67, $00),
    { l (108) }
    ($0E, $0C, $0C, $0C, $0C, $0C, $1E, $00),
    { m (109) }
    ($00, $00, $33, $7F, $7F, $6B, $63, $00),
    { n (110) }
    ($00, $00, $1F, $33, $33, $33, $33, $00),
    { o (111) }
    ($00, $00, $1E, $33, $33, $33, $1E, $00),
    { p (112) }
    ($00, $00, $3B, $66, $66, $3E, $06, $0F),
    { q (113) }
    ($00, $00, $6E, $33, $33, $3E, $30, $78),
    { r (114) }
    ($00, $00, $3B, $6E, $66, $06, $0F, $00),
    { s (115) }
    ($00, $00, $3E, $03, $1E, $30, $1F, $00),
    { t (116) }
    ($08, $0C, $3E, $0C, $0C, $2C, $18, $00),
    { u (117) }
    ($00, $00, $33, $33, $33, $33, $6E, $00),
    { v (118) }
    ($00, $00, $33, $33, $33, $1E, $0C, $00),
    { w (119) }
    ($00, $00, $63, $6B, $7F, $7F, $36, $00),
    { x (120) }
    ($00, $00, $63, $36, $1C, $36, $63, $00),
    { y (121) }
    ($00, $00, $33, $33, $33, $3E, $30, $1F),
    { z (122) }
    ($00, $00, $3F, $19, $0C, $26, $3F, $00),
    { { (123) }
    ($38, $0C, $0C, $07, $0C, $0C, $38, $00),
    { | (124) }
    ($18, $18, $18, $00, $18, $18, $18, $00),
    {  (125) }
    ($07, $0C, $0C, $38, $0C, $0C, $07, $00),
    { ~ (126) }
    ($6E, $3B, $00, $00, $00, $00, $00, $00),
    { DEL (127) }
    ($00, $00, $00, $00, $00, $00, $00, $00)
  );

procedure PrintText(x, y: Integer; s: string; Color: Byte; FrameBuffer: PFrameBuffer);
var
  i, CharIndex: Integer;
  CharRow, Bit: Byte;
  PixelX, PixelY: Integer;
  DestPtr: ^Byte;
begin
  { Draw each character }
  for i := 1 to Length(s) do
  begin
    CharIndex := Ord(s[i]);

    { Only support printable ASCII (32-127) }
    if (CharIndex < 32) or (CharIndex > 127) then
      CharIndex := 32; { Replace with space }

    { Draw the 8x8 character bitmap }
    for PixelY := 0 to 7 do
    begin
      if (y + PixelY < 0) or (y + PixelY >= 200) then
        Continue;

      { Get the font row for this character }
      CharRow := Font8x8[CharIndex, PixelY];

      for Bit := 0 to 7 do
      begin
        PixelX := x + (i - 1) * 8 + Bit;

        if (PixelX < 0) or (PixelX >= 320) then
          Continue;

        { Check if bit is set in font bitmap (LSB = leftmost pixel) }
        if (CharRow and ($01 shl Bit)) <> 0 then
        begin
          DestPtr := @FrameBuffer^[(y + PixelY) * 320 + PixelX];
          DestPtr^ := Color;
        end;
      end;
    end;
  end;
end;

end.
