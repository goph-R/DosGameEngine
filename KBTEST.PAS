{ KBTEST.PAS - Keyboard handler test program }
{ Demonstrates both IsKeyDown (continuous) and IsKeyPressed (edge) detection }

program KeyboardTest;

uses
  Crt, Keyboard;

var
  Running: Boolean;

begin
  InitKeyboard;

  Running := True;

  { Main loop }
  while Running do
  begin
    { Check for exit }
    if IsKeyDown(Key_Escape) then
      Running := False;

    { Color change with C key (edge - press once) }
    if IsKeyPressed(Key_C) then
      WriteLn('C was pressed');

    if IsKeyDown(Key_Left) then
      WriteLn('Left is down');
    
    ClearKeyPressed;
  end;

  DoneKeyboard;
end.
