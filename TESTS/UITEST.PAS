{ ========================================================================== }
{ UITEST.PAS - VGAUI Test Program                                           }
{                                                                            }
{ Tests the VGAUI system with all widget types.                             }
{                                                                            }
{ Controls:                                                                  }
{   Tab       - Focus next widget                                           }
{   Shift+Tab - Focus previous widget                                       }
{   Enter     - Activate button / submit text input                         }
{   Space     - Toggle checkbox / activate button                           }
{   Type      - Text input (LineEdit)                                       }
{   Backspace - Delete character (LineEdit)                                 }
{   Escape    - Exit                                                        }
{ ========================================================================== }

program UITest;

uses VGA, VGAFont, VGAUI, Keyboard, PCXLoad, RTCTimer, Crt;

var
  BackBuffer: PFrameBuffer;
  FontSmall: TFont;
  CheckboxImage: TImage;
  UI: TUIManager;
  TitleLabel: PLabel;
  Button1, Button2, QuitButton: PButton;
  SoundCheckbox, MusicCheckbox: PCheckbox;
  NameInput: PLineEdit;
  Running: Boolean;
  LastTime, CurrentTime, DeltaTime: Real;
  Event: TEvent;
  Pal: TPalette;

{ ========================================================================== }
{ Event Handlers                                                             }
{ ========================================================================== }

{$F+}
procedure OnButton1Click(var Widget: TWidget; var Event: TEvent);
begin
  if (Event.EventType = Event_KeyPress) and
     ((Event.KeyCode = $1C) or (Event.KeyCode = $39)) then
  begin
    { Button 1 was clicked }
    PButton(@Widget)^.Pressed := True;
    { In real app, do something here }
  end;
end;

procedure OnButton2Click(var Widget: TWidget; var Event: TEvent);
begin
  if (Event.EventType = Event_KeyPress) and
     ((Event.KeyCode = $1C) or (Event.KeyCode = $39)) then
  begin
    { Button 2 was clicked }
    PButton(@Widget)^.Pressed := True;
  end;
end;

procedure OnQuitButtonClick(var Widget: TWidget; var Event: TEvent);
begin
  if (Event.EventType = Event_KeyPress) and
     ((Event.KeyCode = $1C) or (Event.KeyCode = $39)) then
  begin
    Running := False;
  end;
end;

procedure OnSoundCheckbox(var Widget: TWidget; var Event: TEvent);
var
  CB: PCheckbox;
begin
  if Event.EventType = Event_KeyPress then
  begin
    CB := PCheckbox(@Widget);
    { Checkbox was toggled - state already changed by widget }
  end;
end;

procedure OnMusicCheckbox(var Widget: TWidget; var Event: TEvent);
var
  CB: PCheckbox;
begin
  if Event.EventType = Event_KeyPress then
  begin
    CB := PCheckbox(@Widget);
    { Checkbox was toggled }
  end;
end;

procedure OnNameInputSubmit(var Widget: TWidget; var Event: TEvent);
var
  Input: PLineEdit;
  PlayerName: string;
begin
  if (Event.EventType = Event_KeyPress) and (Event.KeyCode = $1C) then
  begin
    Input := PLineEdit(@Widget);
    PlayerName := Input^.GetText;
    { Name submitted }
  end;
end;
{$F-}

{ ========================================================================== }
{ Initialization and Cleanup                                                 }
{ ========================================================================== }

procedure InitResources;
var
  Img: TImage;
  SmallFontImg: TImage;
  CheckRect: TRectangle;
  ErrorMsg: string;
begin
  { Load fonts }
  ErrorMsg := LoadFont('DATA\FONT-SM.XML', 'DATA\FONT-SM.PCX', SmallFontImg, FontSmall);
  if ErrorMsg <> '' then
  begin
    WriteLn('ERROR: Failed to load font - ', ErrorMsg);
    Halt(1);
  end;

  { Create checkbox image (16x32: unchecked on top, checked on bottom) }
  { For now, create a simple test image }
  CheckboxImage.Width := 16;
  CheckboxImage.Height := 32;
  CheckboxImage.Pitch := 16;
  GetMem(CheckboxImage.Data, 16 * 32);
  FillChar(CheckboxImage.Data^, 16 * 32, 0);

  { Draw simple checkbox sprites }
  { Top 16x16: unchecked (empty box) }
  CheckRect.X := 0;
  CheckRect.Y := 0;
  CheckRect.Width := 16;
  CheckRect.Height := 16;
  { Draw border for unchecked }
  FillChar(CheckboxImage.Data^[0], 16, 15);  { Top row }
  FillChar(CheckboxImage.Data^[15 * 16], 16, 15);  { Bottom row }

  { Bottom 16x16: checked (box with X) }
  CheckRect.Y := 16;
  { Draw border for checked }
  FillChar(CheckboxImage.Data^[16 * 16], 16, 15);  { Top row }
  FillChar(CheckboxImage.Data^[31 * 16], 16, 15);  { Bottom row }
  { Draw X pattern }
  { TODO: Draw actual X marks }

  WriteLn('Resources loaded successfully');
end;

procedure FreeResources;
begin
  FreeFont(FontSmall);
  FreeMem(CheckboxImage.Data, 16 * 32);
end;

procedure CreateUI;
var
  DefaultStyle: TUIStyle;
begin
  { Initialize UI Manager }
  UI.Init(BackBuffer);
  DefaultStyle.Init(15, 7, 8, 14);  { White, gray, dark gray, yellow }
  UI.SetStyle(DefaultStyle);

  { Create Title Label }
  New(TitleLabel);
  TitleLabel^.Init(100, 20, 'VGAUI Test Program', @FontSmall);
  UI.AddWidget(TitleLabel);

  { Create Button 1 }
  New(Button1);
  Button1^.Init(80, 60, 160, 24, 'Test Button 1', @FontSmall);
  Button1^.SetEventHandler(@OnButton1Click);
  UI.AddWidget(Button1);

  { Create Button 2 }
  New(Button2);
  Button2^.Init(80, 90, 160, 24, 'Test Button 2', @FontSmall);
  Button2^.SetEventHandler(@OnButton2Click);
  UI.AddWidget(Button2);

  { Create Sound Checkbox }
  New(SoundCheckbox);
  SoundCheckbox^.Init(80, 130, 'Sound Effects', @FontSmall, @CheckboxImage, 16, 16);
  SoundCheckbox^.SetEventHandler(@OnSoundCheckbox);
  SoundCheckbox^.SetChecked(True);
  UI.AddWidget(SoundCheckbox);

  { Create Music Checkbox }
  New(MusicCheckbox);
  MusicCheckbox^.Init(80, 155, 'Background Music', @FontSmall, @CheckboxImage, 16, 16);
  MusicCheckbox^.SetEventHandler(@OnMusicCheckbox);
  UI.AddWidget(MusicCheckbox);

  { Create Name Input }
  New(NameInput);
  NameInput^.Init(80, 185, 160, 24, @FontSmall, 20);
  NameInput^.SetEventHandler(@OnNameInputSubmit);
  NameInput^.SetText('Player Name');
  UI.AddWidget(NameInput);

  { Create Quit Button }
  New(QuitButton);
  QuitButton^.Init(80, 220, 160, 24, 'Quit (ESC)', @FontSmall);
  QuitButton^.SetEventHandler(@OnQuitButtonClick);
  UI.AddWidget(QuitButton);

  { Focus first interactive widget }
  UI.SetFocus(Button1);

  WriteLn('UI created successfully');
end;

procedure DestroyUI;
begin
  UI.RemoveWidget(TitleLabel); TitleLabel^.Done; Dispose(TitleLabel);
  UI.RemoveWidget(Button1); Button1^.Done; Dispose(Button1);
  UI.RemoveWidget(Button2); Button2^.Done; Dispose(Button2);
  UI.RemoveWidget(SoundCheckbox); SoundCheckbox^.Done; Dispose(SoundCheckbox);
  UI.RemoveWidget(MusicCheckbox); MusicCheckbox^.Done; Dispose(MusicCheckbox);
  UI.RemoveWidget(NameInput); NameInput^.Done; Dispose(NameInput);
  UI.RemoveWidget(QuitButton); QuitButton^.Done; Dispose(QuitButton);
  UI.Done;
end;

{ ========================================================================== }
{ Main Loop                                                                  }
{ ========================================================================== }

procedure MainLoop;
begin
  Running := True;
  LastTime := GetTimeSeconds;

  while Running do
  begin
    { Calculate delta time }
    CurrentTime := GetTimeSeconds;
    DeltaTime := CurrentTime - LastTime;
    LastTime := CurrentTime;

    { Handle input }
    if IsKeyPressed(Key_Escape) then
      Running := False;

    if IsKeyPressed(Key_Tab) then
      UI.FocusNext;

    { Check for any key press and dispatch to UI }
    if IsKeyPressed(Key_Enter) then
    begin
      Event.EventType := Event_KeyPress;
      Event.KeyCode := $1C;  { Enter }
      Event.Handled := False;
      UI.HandleEvent(Event);
    end;

    if IsKeyPressed(Key_Space) then
    begin
      Event.EventType := Event_KeyPress;
      Event.KeyCode := $39;  { Space }
      Event.Handled := False;
      UI.HandleEvent(Event);
    end;

    { Update LineEdit cursor blink }
    if NameInput <> nil then
      NameInput^.Update(DeltaTime);

    { Clear background }
    ClearFrameBuffer(BackBuffer, 1);  { Dark blue background }

    { Render UI }
    UI.RenderAll;

    { Render to screen }
    WaitForVSync;
    RenderFrameBuffer(BackBuffer);

    { Clear key states }
    ClearKeyPressed;

    { Small delay to prevent 100% CPU usage }
    Delay(16);  { ~60 FPS }
  end;
end;

{ ========================================================================== }
{ Entry Point                                                                }
{ ========================================================================== }

begin
  WriteLn('VGAUI Test Program');
  WriteLn('==================');
  WriteLn;

  { Initialize systems }
  WriteLn('Initializing VGA...');
  InitVGA;

  WriteLn('Creating back buffer...');
  BackBuffer := CreateFrameBuffer;

  WriteLn('Initializing keyboard...');
  InitKeyboard;

  WriteLn('Initializing RTC timer...');
  InitRTC(1024);

  WriteLn('Loading resources...');
  InitResources;

  WriteLn('Creating UI...');
  CreateUI;

  WriteLn;
  WriteLn('Press ESC to exit');
  WriteLn('Tab to cycle focus');
  WriteLn('Enter/Space to activate widgets');
  WriteLn;
  WriteLn('Starting main loop...');
  Delay(1000);

  { Run main loop }
  MainLoop;

  { Cleanup }
  WriteLn('Cleaning up...');
  DestroyUI;
  FreeResources;
  DoneRTC;
  DoneKeyboard;
  FreeFrameBuffer(BackBuffer);
  CloseVGA;

  WriteLn('Done!');
end.
