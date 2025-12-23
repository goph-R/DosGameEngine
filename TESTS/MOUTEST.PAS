program MouseTest;

uses
  VGA, VGAPrint, Mouse, Keyboard;

var
  FrameBuffer: PFrameBuffer;
  Running: Boolean;
  StatusText: String;
  X, Y: Word;
  Buttons: Byte;
  I: Integer;

procedure DrawCrosshair(X, Y: Word; Color: Byte);
var
  I: Integer;
begin
  { Draw horizontal line }
  if X >= 5 then
    for I := X - 5 to X + 5 do
      if (I < 320) and (Y < 200) then
        FrameBuffer^[Y * 320 + I] := Color;

  { Draw vertical line }
  if Y >= 5 then
    for I := Y - 5 to Y + 5 do
      if (X < 320) and (I < 200) then
        FrameBuffer^[I * 320 + X] := Color;
end;

procedure DrawUI;
begin
  { Display mouse position }
  Str(GetMouseX, StatusText);
  StatusText := 'Mouse X: ' + StatusText;
  PrintText(5, 5, StatusText, 15, FrameBuffer);

  Str(GetMouseY, StatusText);
  StatusText := 'Mouse Y: ' + StatusText;
  PrintText(5, 15, StatusText, 15, FrameBuffer);

  { Display button states }
  Buttons := GetMouseButtons;

  if IsMouseButtonDown(MouseButton_Left) then
    PrintText(5, 30, 'Left: DOWN', 12, FrameBuffer)
  else
    PrintText(5, 30, 'Left: UP  ', 7, FrameBuffer);

  if IsMouseButtonDown(MouseButton_Right) then
    PrintText(5, 40, 'Right: DOWN', 12, FrameBuffer)
  else
    PrintText(5, 40, 'Right: UP  ', 7, FrameBuffer);

  if IsMouseButtonDown(MouseButton_Middle) then
    PrintText(5, 50, 'Middle: DOWN', 12, FrameBuffer)
  else
    PrintText(5, 50, 'Middle: UP  ', 7, FrameBuffer);

  { Instructions }
  PrintText(5, 180, 'Move mouse to test position', 14, FrameBuffer);
  PrintText(5, 190, 'ESC: Exit', 14, FrameBuffer);
end;

begin
  { Initialize mouse }
  WriteLn('Initializing mouse driver...');
  if not InitMouse then
  begin
    WriteLn('ERROR: Mouse driver not found!');
    WriteLn('Make sure MOUSE.COM or MOUSE.SYS is loaded.');
    Halt(1);
  end;

  WriteLn('Mouse driver initialized successfully!');
  WriteLn('Press any key to start...');
  ReadLn;

  { Initialize systems }
  InitKeyboard;
  InitVGA;

  FrameBuffer := CreateFrameBuffer;

  { Hide hardware cursor - we draw our own crosshair }
  HideMouse;

  Running := True;

  { Main loop }
  while Running do
  begin
    { Update mouse state }
    UpdateMouse;

    { Handle keyboard input }
    if IsKeyPressed(Key_Escape) then
      Running := False;

    { Get current mouse position }
    X := GetMouseX;
    Y := GetMouseY;

    { Render }
    ClearFrameBuffer(FrameBuffer);

    { Draw crosshair at mouse position }
    if IsMouseButtonDown(MouseButton_Left) then
      DrawCrosshair(X, Y, 12)  { Red when left button down }
    else if IsMouseButtonDown(MouseButton_Right) then
      DrawCrosshair(X, Y, 9)   { Blue when right button down }
    else
      DrawCrosshair(X, Y, 15); { White normally }

    { Draw UI }
    DrawUI;

    { Display }
    RenderFrameBuffer(FrameBuffer);

    { Clear key states }
    ClearKeyPressed;
  end;

  { Cleanup }
  HideMouse;
  DoneMouse;
  FreeFrameBuffer(FrameBuffer);
  DoneVGA;
  DoneKeyboard;

  WriteLn('Mouse test completed.');
end.
