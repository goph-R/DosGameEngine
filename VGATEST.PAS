uses VGA, PKMLoad;

var
  FrameBuffer: PFrameBuffer;
  Palette: TPalette;

begin
  FrameBuffer := CreateFrameBuffer;
  LoadPKM('DATA\TEST.PKM', FrameBuffer, Palette);
  InitVGA;
  SetPalette(Palette);
  RenderFrameBuffer(FrameBuffer);
  
  ReadLn;

  CloseVGA;
  FreeFrameBuffer(FrameBuffer);
end.