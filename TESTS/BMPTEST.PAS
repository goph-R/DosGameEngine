{ BMPTEST.PAS - Test program for BMP image loading }
{ Loads and displays a BMP file with its palette }

program BMPTest;

uses VGA, BMP, Keyboard;

var
  FrameBuffer: PFrameBuffer;
  TestImage: TImage;
  Palette: TPalette;

begin
  WriteLn('BMP Image Loader Test');
  WriteLn('=====================');
  WriteLn;

  { Load BMP image with palette }
  WriteLn('Loading TEST.BMP...');
  if not LoadBMPWithPalette('DATA\TEST.BMP', TestImage, Palette) then
  begin
    WriteLn('Error: Could not load TEST.BMP');
    WriteLn(GetLoadBMPError);
    Halt(1);
  end;

  WriteLn('Loaded successfully!');
  WriteLn('Dimensions: ', TestImage.Width, 'x', TestImage.Height);
  WriteLn;
  WriteLn('Press any key to save image...');
  InitKeyboard;
  repeat until IsKeyPressed(Key_Space) or IsKeyPressed(Key_Enter) or IsKeyPressed(Key_Escape);
  ClearKeyPressed;

  { Save BMP image with palette }
  WriteLn('Saving TEST-OUT.BMP...');
  if not SaveBMP('DATA\TEST-OUT.BMP', TestImage, Palette) then
  begin
    WriteLn('Error: Could not save TEST-OUT.BMP');
    WriteLn(GetSaveBMPError);
    FreeImage(TestImage);
    Halt(1);
  end;

  { Initialize VGA and set palette }
  InitVGA;
  SetPalette(Palette);

  { Create framebuffer and render image to it }
  FrameBuffer := CreateFrameBuffer;
  PutImage(TestImage, 0, 0, False, FrameBuffer);
  RenderFrameBuffer(FrameBuffer);

  { Wait for keypress }
  repeat until IsKeyPressed(Key_Space) or IsKeyPressed(Key_Enter) or IsKeyPressed(Key_Escape);
  ClearKeyPressed;

  { Cleanup }
  DoneVGA;
  DoneKeyboard;
  FreeFrameBuffer(FrameBuffer);
  FreeImage(TestImage);

  WriteLn;
  WriteLn('BMP test completed successfully!');
end.
