{ FNTTEST.PAS - Variable-Width Font System Test }
{ Tests VGAFONT.PAS with font loading and text rendering }

program FontTest;

uses VGA, VGAFont;

var
  TestFont: TFont;
  ScreenBuffer: PFrameBuffer;
  Running: Boolean;

begin
  WriteLn('VGAFont Test Program');
  WriteLn('====================');
  WriteLn;

  { Load font }
  WriteLn('Loading font...');
  if not LoadFont('..\DATA\FONT.XML', '..\DATA\FONT.PKM', TestFont) then
  begin
    WriteLn;
    WriteLn('ERROR: Failed to load font!');
    WriteLn('Reason: ', GetLoadFontError);
    WriteLn;
    WriteLn('To create a test font:');
    WriteLn('1. Create DATA\FONT.PKM in GrafX2 (sprite sheet with characters)');
    WriteLn('2. Create DATA\FONT.XML with character positions and widths');
    WriteLn('3. See DOCS\VGAFONT.md for format specification');
    Halt(1);
  end;

  WriteLn('Font loaded successfully!');
  WriteLn('Font height: ', TestFont.Height, ' pixels');
  WriteLn('Font padding: ', TestFont.Padding, ' pixels');
  WriteLn;
  WriteLn('Press enter to continue...');
  ReadLn;

  { Initialize VGA Mode 13h }
  InitVGA;

  { Initalize screen buffer }
  ScreenBuffer := GetScreenBuffer;
  ClearFrameBuffer(ScreenBuffer);

  { Test text rendering at different positions }
  PrintFontText(10, 10, 'Hello World!', TestFont, ScreenBuffer);
  PrintFontText(10, 10 + TestFont.Height + 5, 'Variable Width Font Test', TestFont, ScreenBuffer);

  { Test centered text }
  PrintFontTextCentered(160, 80, 'Centered Text', TestFont, ScreenBuffer);

  { Test all uppercase letters }
  PrintFontText(10, 100, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', TestFont, ScreenBuffer);

  { Test all lowercase letters (if font has them) }
  PrintFontText(10, 100 + TestFont.Height + 5, 'abcdefghijklmnopqrstuvwxyz', TestFont, ScreenBuffer);

  { Test numbers and symbols }
  PrintFontText(10, 140, '0123456789 !?.,:', TestFont, ScreenBuffer);

  { Test right-aligned text }
  PrintFontTextRight(310, 180, 'Right Align', TestFont, ScreenBuffer);

  ReadLn;

  { Cleanup }
  FreeFont(TestFont);
  CloseVGA;

  WriteLn;
  WriteLn('Test completed successfully!');
end.
