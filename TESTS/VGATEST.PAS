uses VGA, PKMLoad;

var
  FrameBuffer: PFrameBuffer;
  TestImage: TImage;
  Palette: TPalette;

begin
  { Load image }
  if not LoadPKMWithPalette('..\DATA\TEST.PKM', TestImage, Palette) then
  begin
    WriteLn('Error: Could not load TEST.PKM');
    Halt(1);
  end;

  { Initialize VGA and set palette }
  InitVGA;
  SetPalette(Palette);

  { Create framebuffer and render image to it }
  FrameBuffer := CreateFrameBuffer;
  PutImage(TestImage, 0, 0, False, FrameBuffer);
  RenderFrameBuffer(FrameBuffer);

  ReadLn;

  { Cleanup }
  CloseVGA;
  FreeFrameBuffer(FrameBuffer);
  FreeImage(TestImage);
end.