uses Keyboard, VGA;

var
  FB: PFrameBuffer;
  i: Integer;

begin
  InitVGA;
  FB := CreateFrameBuffer;

  Randomize;

  while not IsKeyPressed(Key_Escape) do
  begin
    DrawLine(Random(160), Random(100), Random(160) + 160, Random(100) + 100, Random(256), FB);
    RenderFrameBuffer(FB);
  end;
  
  FreeFrameBuffer(FB);
  CloseVGA;
end.