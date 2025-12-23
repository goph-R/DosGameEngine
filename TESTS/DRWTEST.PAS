uses Keyboard, VGA, VGAPrint;

var
  FB: PFrameBuffer;
  Mode: Integer;
  R: TRectangle;

procedure DrawModeIndicator;
begin
  { Draw mode indicator at top of screen }
  case Mode of
    1: PrintText(10, 10, '1: DrawLine Test', 15, FB);
    2: PrintText(10, 10, '2: DrawFillRect Test', 15, FB);
    3: PrintText(10, 10, '3: DrawRect Test', 15, FB);
  end;
  PrintText(10, 20, 'Press 1-3 to switch modes, ESC to exit', 14, FB);
end;

begin
  InitVGA;
  InitKeyboard;
  FB := CreateFrameBuffer;
  Randomize;

  Mode := 1;  { Start with DrawLine test }
  ClearFrameBuffer(FB);
  DrawModeIndicator;

  while not IsKeyPressed(Key_Escape) do
  begin
    { Check for mode switch }
    if IsKeyPressed(Key_1) then
    begin
      Mode := 1;
      ClearFrameBuffer(FB);
      DrawModeIndicator;
    end;

    if IsKeyPressed(Key_2) then
    begin
      Mode := 2;
      ClearFrameBuffer(FB);
      DrawModeIndicator;
    end;

    if IsKeyPressed(Key_3) then
    begin
      Mode := 3;
      ClearFrameBuffer(FB);
      DrawModeIndicator;
    end;

    { Draw based on current mode }
    case Mode of
      1: { DrawLine test }
        DrawLine(Random(160), Random(100), Random(160) + 160, Random(100) + 100, Random(256), FB);

      2: { DrawFillRect test }
        begin
          R.X := Random(280);
          R.Y := Random(40) + 40;  { Avoid top text area }
          R.Width := Random(40) + 5;
          R.Height := Random(40) + 5;
          DrawFillRect(R, Random(256), FB);
        end;

      3: { DrawRect test }
        begin
          R.X := Random(280);
          R.Y := Random(40) + 40;  { Avoid top text area }
          R.Width := Random(40) + 5;
          R.Height := Random(40) + 5;
          DrawRect(R, Random(256), FB);
        end;
    end;

    RenderFrameBuffer(FB);
    ClearKeyPressed;
  end;

  DoneKeyboard;
  FreeFrameBuffer(FB);
  DoneVGA;
end.