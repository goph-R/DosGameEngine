{ PCXTEST.PAS - Test program for PCX image loading }
{ Loads and displays a PCX file with its palette }

program PCXTest;

uses VGA, PCXLoad, Crt;

var
  FrameBuffer: PFrameBuffer;
  TestImage: TImage;
  Palette: TPalette;

begin
  ClrScr;
  WriteLn('PCX Image Loader Test');
  WriteLn('=====================');
  WriteLn;

  { Load PCX image with palette }
  WriteLn('Loading TEST.PCX...');
  if not LoadPCXWithPalette('DATA\TEST.PCX', TestImage, Palette) then
  begin
    WriteLn('Error: Could not load TEST.PCX');
    WriteLn(GetLastErrorMessage);
    Halt(1);
  end;

  WriteLn('Loaded successfully!');
  WriteLn('Dimensions: ', TestImage.Width, 'x', TestImage.Height);
  WriteLn;
  WriteLn('Press any key to display image...');
  ReadKey;

  { Initialize VGA and set palette }
  InitVGA;
  SetPalette(Palette);

  { Create framebuffer and render image to it }
  FrameBuffer := CreateFrameBuffer;
  PutImage(TestImage, 0, 0, False, FrameBuffer);
  RenderFrameBuffer(FrameBuffer);

  { Wait for keypress }
  ReadKey;

  { Cleanup }
  CloseVGA;
  FreeFrameBuffer(FrameBuffer);
  FreeImage(TestImage);

  WriteLn;
  WriteLn('PCX test completed successfully!');
end.
