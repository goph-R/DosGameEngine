{ ========================================================================== }
{ UITEST.PAS - VGAUI Test Program                                           }
{                                                                            }
{ Tests the VGAUI system with all widget types.                             }
{                                                                            }
{ Controls:                                                                  }
{   Tab          - Focus next widget                                        }
{   Shift+Tab    - Focus previous widget                                    }
{   Arrow Keys   - Focus closest widget in direction (Up/Down/Left/Right)  }
{   Enter        - Activate button / submit text input                      }
{   Space        - Toggle checkbox / activate button                        }
{   Type         - Text input (LineEdit)                                    }
{   Backspace    - Delete character (LineEdit)                              }
{   Escape       - Exit                                                     }
{ ========================================================================== }

program UITest;

uses VGA, VGAFont, VGAUI, Keyboard, PCXLoad, RTCTimer, GenTypes, Crt, Logger;

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
  OldExitProc: Pointer;

{ ========================================================================== }
{ Emergency Cleanup Handler                                                  }
{ ========================================================================== }

{$F+}
procedure CleanupExitProc;
begin
  ExitProc := OldExitProc;  { Restore old exit proc }

  { Emergency cleanup - ensure VGA is closed }
  if ErrorAddr <> nil then
  begin
    LogError('Runtime error occurred!');
    CloseVGA;  { Restore text mode }
    CloseLogger;
    WriteLn('Runtime error at address: ', Seg(ErrorAddr^):4, ':', Ofs(ErrorAddr^):4);
    WriteLn('Error code: ', ExitCode);
  end;
end;
{$F-}

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
  CheckRect: TRectangle;
begin
  LogDebug('InitResources: Starting');

  { Load fonts }
  LogDebug('InitResources: Loading font');
  if not LoadFont('DATA\FONT-SM.XML', 'DATA\FONT-SM.PCX', FontSmall) then
  begin
    LogError('Failed to load font');
    WriteLn('ERROR: Failed to load font - ', GetLoadFontError);
    Halt(1);
  end;
  LogDebug('InitResources: Font loaded OK');

  { Create checkbox image (10x20: unchecked on top, checked on bottom) }
  { For now, create a simple test image }
  LogDebug('InitResources: Creating checkbox image');
  CheckboxImage.Width := 10;
  CheckboxImage.Height := 20;
  GetMem(CheckboxImage.Data, 10 * 20);
  FillChar(CheckboxImage.Data^, 10 * 20, 0);

  { Draw simple checkbox sprites }
  { Top 10x10: unchecked (empty box) }
  CheckRect.X := 0;
  CheckRect.Y := 0;
  CheckRect.Width := 10;
  CheckRect.Height := 10;
  { Draw border for unchecked }
  FillChar(PByteArray(CheckboxImage.Data)^[0], 10, 15);  { Top row }
  FillChar(PByteArray(CheckboxImage.Data)^[9 * 10], 10, 15);  { Bottom row }

  { Bottom 10x10: checked (box with X) }
  CheckRect.Y := 10;
  { Draw border for checked }
  FillChar(PByteArray(CheckboxImage.Data)^[10 * 10], 10, 15);  { Top row }
  FillChar(PByteArray(CheckboxImage.Data)^[19 * 10], 10, 15);  { Bottom row }
  { Draw X pattern - simple diagonal lines }
  PByteArray(CheckboxImage.Data)^[(10 + 2) * 10 + 2] := 15;   { Top-left }
  PByteArray(CheckboxImage.Data)^[(10 + 3) * 10 + 3] := 15;
  PByteArray(CheckboxImage.Data)^[(10 + 4) * 10 + 4] := 15;
  PByteArray(CheckboxImage.Data)^[(10 + 5) * 10 + 5] := 15;
  PByteArray(CheckboxImage.Data)^[(10 + 6) * 10 + 6] := 15;
  PByteArray(CheckboxImage.Data)^[(10 + 7) * 10 + 7] := 15;
  { Other diagonal }
  PByteArray(CheckboxImage.Data)^[(10 + 2) * 10 + 7] := 15;  { Top-right }
  PByteArray(CheckboxImage.Data)^[(10 + 3) * 10 + 6] := 15;
  PByteArray(CheckboxImage.Data)^[(10 + 4) * 10 + 5] := 15;
  PByteArray(CheckboxImage.Data)^[(10 + 5) * 10 + 4] := 15;
  PByteArray(CheckboxImage.Data)^[(10 + 6) * 10 + 3] := 15;
  PByteArray(CheckboxImage.Data)^[(10 + 7) * 10 + 2] := 15;

  LogDebug('InitResources: Complete');
  WriteLn('Resources loaded successfully');
end;

procedure FreeResources;
begin
  FreeFont(FontSmall);
  FreeMem(CheckboxImage.Data, 10 * 20);
end;

procedure CreateUI;
var
  DefaultStyle: TUIStyle;
begin
  LogDebug('CreateUI: Starting');

  { Initialize UI Manager }
  LogDebug('CreateUI: Initializing UI Manager');
  UI.Init(BackBuffer);
  LogDebug('CreateUI: Setting style');
  DefaultStyle.Init(15, 7, 8, 14);  { White, gray, dark gray, yellow }
  UI.SetStyle(DefaultStyle);
  LogDebug('CreateUI: Style set');

  { Create Title Label }
  LogDebug('CreateUI: Creating TitleLabel');
  New(TitleLabel, Init(10, 5, 'VGAUI Test Program', @FontSmall));
  LogDebug('CreateUI: Adding TitleLabel');
  UI.AddWidget(TitleLabel);
  LogDebug('CreateUI: TitleLabel added');

  { Create Button 1 }
  LogDebug('CreateUI: Creating Button1');
  New(Button1, Init(10, 20, 140, 12, 'Test Button 1', @FontSmall));
  Button1^.SetEventHandler(@OnButton1Click);
  UI.AddWidget(Button1);
  LogDebug('CreateUI: Button1 added');

  { Create Button 2 }
  LogDebug('CreateUI: Creating Button2');
  New(Button2, Init(10, 35, 140, 12, 'Test Button 2', @FontSmall));
  Button2^.SetEventHandler(@OnButton2Click);
  UI.AddWidget(Button2);
  LogDebug('CreateUI: Button2 added');

  { Create Sound Checkbox }
  LogDebug('CreateUI: Creating SoundCheckbox');
  New(SoundCheckbox, Init(10, 52, 'Sound Effects', @FontSmall, @CheckboxImage, 10, 10));
  SoundCheckbox^.SetEventHandler(@OnSoundCheckbox);
  SoundCheckbox^.SetChecked(True);
  UI.AddWidget(SoundCheckbox);
  LogDebug('CreateUI: SoundCheckbox added');

  { Create Music Checkbox }
  LogDebug('CreateUI: Creating MusicCheckbox');
  New(MusicCheckbox, Init(10, 67, 'Background Music', @FontSmall, @CheckboxImage, 10, 10));
  MusicCheckbox^.SetEventHandler(@OnMusicCheckbox);
  UI.AddWidget(MusicCheckbox);
  LogDebug('CreateUI: MusicCheckbox added');

  { Create Name Input }
  LogDebug('CreateUI: Creating NameInput');
  New(NameInput, Init(10, 84, 140, 12, @FontSmall, 20));
  NameInput^.SetEventHandler(@OnNameInputSubmit);
  NameInput^.SetText('Player Name');
  UI.AddWidget(NameInput);
  LogDebug('CreateUI: NameInput added');

  { Create Quit Button }
  LogDebug('CreateUI: Creating QuitButton');
  New(QuitButton, Init(10, 100, 140, 12, 'Quit (ESC)', @FontSmall));
  QuitButton^.SetEventHandler(@OnQuitButtonClick);
  UI.AddWidget(QuitButton);
  LogDebug('CreateUI: QuitButton added');

  { Focus first interactive widget }
  LogDebug('CreateUI: Setting focus to Button1');
  UI.SetFocus(Button1);
  LogDebug('CreateUI: Complete');
end;

procedure DestroyUI;
begin
  UI.RemoveWidget(TitleLabel); Dispose(TitleLabel, Done);
  UI.RemoveWidget(Button1); Dispose(Button1, Done);
  UI.RemoveWidget(Button2); Dispose(Button2, Done);
  UI.RemoveWidget(SoundCheckbox); Dispose(SoundCheckbox, Done);
  UI.RemoveWidget(MusicCheckbox); Dispose(MusicCheckbox, Done);
  UI.RemoveWidget(NameInput); Dispose(NameInput, Done);
  UI.RemoveWidget(QuitButton); Dispose(QuitButton, Done);
  UI.Done;
end;

{ ========================================================================== }
{ Main Loop                                                                  }
{ ========================================================================== }

procedure MainLoop;
begin
  LogInfo('MainLoop: Starting');
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

    { Dispatch all keyboard events to UI system }
    UI.DispatchKeyboardEvents;

    { Update all widgets (cursor blink, animations, etc.) }
    UI.Update(DeltaTime);

    { Clear background to dark blue }
    ClearFrameBuffer(BackBuffer);

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
  { Initialize logger FIRST }
  InitLogger('UITEST.LOG', LogLevelDebug);
  LogInfo('=== VGAUI Test Program Starting ===');

  WriteLn('VGAUI Test Program');
  WriteLn('==================');
  WriteLn;

  { Install exit handler for emergency cleanup }
  LogDebug('Installing exit handler');
  OldExitProc := ExitProc;
  ExitProc := @CleanupExitProc;

  { Initialize systems }
  WriteLn('Initializing VGA...');
  LogDebug('Initializing VGA');
  InitVGA;
  LogDebug('VGA initialized');

  WriteLn('Creating back buffer...');
  LogDebug('Creating back buffer');
  BackBuffer := CreateFrameBuffer;
  LogDebug('Back buffer created');
  WriteLn('Back buffer created OK');

  WriteLn('Initializing keyboard...');
  LogDebug('Initializing keyboard');
  InitKeyboard;
  LogDebug('Keyboard initialized');

  WriteLn('Initializing RTC timer...');
  LogDebug('Initializing RTC timer');
  InitRTC(1024);
  LogDebug('RTC timer initialized');
  WriteLn('RTC timer initialized OK');

  WriteLn('Loading resources...');
  InitResources;
  WriteLn('Resources loaded OK');

  WriteLn('Creating UI...');
  CreateUI;
  WriteLn('UI created OK');

  WriteLn;
  WriteLn('All initialization complete!');
  WriteLn('Starting main loop...');
  LogInfo('Starting main loop');
  Delay(1000);
  MainLoop;

  { Cleanup }
  LogInfo('Main loop exited, cleaning up');
  WriteLn('Cleaning up...');
  WriteLn('Destroying UI...');
  LogDebug('Destroying UI');
  DestroyUI;
  WriteLn('Freeing resources...');
  LogDebug('Freeing resources');
  FreeResources;
  WriteLn('Done RTC...');
  LogDebug('Done RTC');
  DoneRTC;
  LogDebug('Done keyboard');
  DoneKeyboard;
  WriteLn('Freeing back buffer...');
  LogDebug('Freeing back buffer');
  FreeFrameBuffer(BackBuffer);
  LogDebug('Closing VGA');
  CloseVGA;

  WriteLn('Done!');
  LogInfo('=== VGAUI Test Program Exiting ===');
  CloseLogger;
end.
