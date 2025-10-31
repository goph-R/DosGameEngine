uses VGA, PKMLoad;

var
  FrameBuffer: PFrameBuffer;
  Music: HSC_obj;
  Width, Height: Word;
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