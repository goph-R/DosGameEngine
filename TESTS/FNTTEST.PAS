{ FNTTEST.PAS - Variable-Width Font System Test }
{ Tests VGAFONT.PAS with font loading and text rendering }

program FontTest;

uses VGA, VGAFont, ResMan;

var
  ResMgr: TResourceManager;
  LargeFont: PFont;
  SmallFont: PFont;
  ScreenBuffer: PFrameBuffer;
  Running: Boolean;

begin
  WriteLn('VGAFont Test Program');
  WriteLn('====================');
  WriteLn;

  { Initialize resource manager }
  ResMgr.Init(True);  { Lazy loading }
  if not ResMgr.LoadFromXML('DATA\RES.XML') then
  begin
    WriteLn('ERROR: Failed to load resources: ', ResMgr.LastError);
    Halt(1);
  end;

  { Load fonts }
  WriteLn('Loading large font...');
  LargeFont := ResMgr.GetFont('large');
  if LargeFont = nil then
  begin
    WriteLn;
    WriteLn('ERROR: Failed to load large font!');
    WriteLn('Reason: ', ResMgr.LastError);
    Halt(1);
  end;

  WriteLn('Loading small font...');
  SmallFont := ResMgr.GetFont('small');
  if SmallFont = nil then
  begin
    WriteLn;
    WriteLn('ERROR: Failed to load small font!');
    WriteLn('Reason: ', ResMgr.LastError);
    Halt(1);
  end;

  WriteLn('Fonts loaded successfully!');
  WriteLn('Large font height: ', LargeFont^.Height, ' pixels');
  WriteLn('Small font height: ', SmallFont^.Height, ' pixels');
  WriteLn;
  WriteLn('Press enter to continue...');
  ReadLn;

  { Initialize VGA Mode 13h }
  InitVGA;

  { Initalize screen buffer }
  ScreenBuffer := GetScreenBuffer;
  ClearFrameBuffer(ScreenBuffer);

  { Test text rendering at different positions }
  PrintFontText(10, 10, 'Hello World!', LargeFont^, ScreenBuffer);
  PrintFontText(10, 10 + LargeFont^.Height, 'Variable Width Font Test', SmallFont^, ScreenBuffer);

  { Test centered text }
  PrintFontTextCentered(160, 50, 'Centered Text', SmallFont^, ScreenBuffer);

  { Test all letters }
  PrintFontText(10, 70, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', LargeFont^, ScreenBuffer);
  PrintFontText(10, 70 + LargeFont^.Height - 5, 'abcdefghijklmnopqrstuvwxyz', LargeFont^, ScreenBuffer);
  PrintFontText(10, 70 + LargeFont^.Height * 2, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', SmallFont^, ScreenBuffer);
  PrintFontText(10, 70 + LargeFont^.Height * 2 + SmallFont^.Height, 'abcdefghijklmnopqrstuvwxyz', SmallFont^, ScreenBuffer);

  { Test numbers and symbols }
  PrintFontText(10, 130, '0123456789 `~!@#$%^&*()_+-{}[]', LargeFont^, ScreenBuffer);
  PrintFontTextColored(10, 130 + LargeFont^.Height, '0123456789 `~!@#$%^&*()_+-{}[]', 12, SmallFont^, ScreenBuffer);

  { Test right-aligned text }
  PrintFontTextRight(310, 170, 'Right Align', LargeFont^, ScreenBuffer);

  ReadLn;

  { Cleanup }
  CloseVGA;
  ResMgr.Done;

  WriteLn;
  WriteLn('Test completed successfully!');
end.
