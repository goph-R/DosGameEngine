{ ========================================================================== }
{ UITEST.PAS - VGAUI Test Program                                           }
{                                                                            }
{ Tests the VGAUI system with all widget types.                             }
{                                                                            }
{ Controls:                                                                  }
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
  BackBuffer, BackgroundBuffer: PFrameBuffer;
  FontSmall: TFont;
  CheckboxImage: TImage;
  UI: TUIManager;
  TitleLabel: PLabel;
  Button1, Button2, QuitButton: PButton;
  SoundCheckbox, MusicCheckbox: PCheckbox;
  NameInput: PLineEdit;
  Running: Boolean;
  LastTime, CurrentTime: Real;
  DeltaTime: LongInt;
  Event: TEvent;
  Pal: TPalette;

{ ========================================================================== }
{ Example Event Handlers                                                     }
{ ========================================================================== }

{$F+}
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
  { Load fonts }
  if not LoadFont('DATA\FONT-SM.XML', 'DATA\FONT-SM.PCX', FontSmall) then
  begin
    LogError('Failed to load font');
    WriteLn('ERROR: Failed to load font - ', GetLoadFontError);
    Halt(1);
  end;

  { Create checkbox image (10x20: unchecked on top, checked on bottom) }
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
  { Initialize UI Manager with background buffer }
  UI.Init(BackBuffer, BackgroundBuffer);
  DefaultStyle.Init(15, 7, 8, 14);  { White, gray, dark gray, yellow }
  UI.SetStyle(DefaultStyle);

  { Create Title Label }
  New(TitleLabel, Init(10, 5, 'VGAUI Test Program', @FontSmall));
  UI.AddWidget(TitleLabel);

  { Create Button 1 }
  New(Button1, Init(10, 20, 140, 12, 'Test Button 1', @FontSmall));
  UI.AddWidget(Button1);

  { Create Button 2 }
  New(Button2, Init(10, 35, 140, 12, 'Test Button 2', @FontSmall));
  UI.AddWidget(Button2);

  { Create Sound Checkbox }
  New(SoundCheckbox, Init(10, 52, 'Sound Effects', @FontSmall, @CheckboxImage));
  SoundCheckbox^.SetEventHandler(@OnSoundCheckbox);
  SoundCheckbox^.SetChecked(True);
  UI.AddWidget(SoundCheckbox);

  { Create Music Checkbox }
  New(MusicCheckbox, Init(10, 67, 'Background Music', @FontSmall, @CheckboxImage));
  UI.AddWidget(MusicCheckbox);

  { Create Name Input }
  New(NameInput, Init(10, 84, 140, 12, @FontSmall, 20));
  NameInput^.SetEventHandler(@OnNameInputSubmit);
  NameInput^.SetText('Player Name');
  UI.AddWidget(NameInput);

  { Create Quit Button }
  New(QuitButton, Init(10, 100, 140, 12, 'Quit (ESC)', @FontSmall));
  QuitButton^.SetEventHandler(@OnQuitButtonClick);
  UI.AddWidget(QuitButton);

  { Focus first interactive widget }
  UI.SetFocus(Button1);
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
  Running := True;
  LastTime := GetTimeSeconds;

  while Running do
  begin
    { Calculate delta time in milliseconds }
    CurrentTime := GetTimeSeconds;
    DeltaTime := Round((CurrentTime - LastTime) * 1000);
    LastTime := CurrentTime;

    { Handle input }
    if IsKeyPressed(Key_Escape) then
      Running := False;

    { Update all widgets (cursor blink, animations, etc.) }
    UI.Update(DeltaTime);

    { Render with automatic dirty rectangles - FAST! }
    UI.RenderDirty;

    { Display (RenderDirty already flushed to VGA) }
    WaitForVSync;

    { Clear key states }
    ClearKeyPressed;

    { Small delay to prevent 100% CPU usage }
    Delay(10);  { ~100 FPS }
  end;
end;

{ ========================================================================== }
{ Entry Point                                                                }
{ ========================================================================== }

begin
  { Initialize systems }
  InitVGA;
  BackBuffer := CreateFrameBuffer;
  BackgroundBuffer := CreateFrameBuffer;

  { Clear background to dark blue }
  ClearFrameBuffer(BackgroundBuffer);
  ClearFrameBuffer(BackBuffer);

  InitKeyboard;
  InitRTC(1024);
  InitResources;
  CreateUI;

  MainLoop;

  { Cleanup }
  DestroyUI;
  FreeResources;
  DoneRTC;
  DoneKeyboard;
  FreeFrameBuffer(BackBuffer);
  FreeFrameBuffer(BackgroundBuffer);
  CloseVGA;
end.
