uses vga, playhsc, pkmload;

var
  FrameBuffer: PFrameBuffer;
  Music: HSC_obj;
  Width, Height: Word;
  Palette: TPalette;

begin
  Music.Init(0);
  if Music.LoadFile('FANTASY.HSC') then
  begin
    FrameBuffer := CreateFrameBuffer;
    LoadPKM('TEST.PKM', FrameBuffer, Palette);
    InitVGA;
    SetPalette(Palette);
    Music.Start;
    RenderFrameBuffer(FrameBuffer);
    ReadLn;
    Music.Done;
    CloseVGA;
    FreeFrameBuffer(FrameBuffer);
  end;
end.