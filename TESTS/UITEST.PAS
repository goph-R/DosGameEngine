program UITest;

uses VGA, VGAFont, VGAUI, Keyboard, PCXLoad, RTCTimer, GenTypes, Crt;

var
  BackBuffer, BackgroundBuffer: PFrameBuffer;
  FontSmall: TFont;
  CheckboxImage: TImage;
  UI: TUIManager;
  TitleLabel: PLabel;
  Button1, Button2, QuitButton: PButton;
  SoundCheckbox, MusicCheckbox: PCheckbox;
  NameInput: PLineEdit;

{ Example Event Handlers }

{$F+}
procedure OnUpdate;
begin
  if IsKeyPressed(Key_Escape) then
    UI.Stop;
end;

procedure OnQuitButtonClick(var Widget: TWidget; var Event: TEvent);
begin
  if UI.IsEnter(Event) then
    UI.Stop;
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
  if UI.IsEnter(Event) then
  begin
    Input := PLineEdit(@Widget);
    PlayerName := Input^.GetText;
    { Name submitted }
  end;
end;

{$F-}

procedure InitResources;
var
  Img: TImage;
  CheckRect: TRectangle;
begin
  { Load fonts }
  if not LoadFont('DATA\FONT-SM.XML', FontSmall) then
  begin
    WriteLn('ERROR: Failed to load font - ', GetLoadFontError);
    Halt(1);
  end;

  { Create checkbox image (10x20: unchecked on top, checked on bottom) }
  if not LoadPCX('DATA\CHECKBOX.PCX', CheckboxImage) then
  begin
    WriteLn('ERROR: Failed to checkbox iamge - ', PCXLoad.GetLoadPCXError);
    Halt(1);
  end;
end;

procedure FreeResources;
begin
  FreeFont(FontSmall);
  FreeMem(CheckboxImage.Data, 10 * 20);
end;

procedure CreateUI;
begin
  { Initialize UI Manager with background buffer }
  UI.Init(BackBuffer, BackgroundBuffer);

  { Create Title Label }
  New(TitleLabel, Init(10, 5, 140, 12, 'VGAUI Test Program', @FontSmall));
  UI.AddWidget(TitleLabel);

  { Create Button 1 }
  New(Button1, Init(10, 20, 140, 12, 'Test Button 1', @FontSmall));
  UI.AddWidget(Button1);

  { Create Button 2 }
  New(Button2, Init(10, 35, 140, 12, 'Test Button 2', @FontSmall));
  UI.AddWidget(Button2);

  { Create Sound Checkbox }
  New(SoundCheckbox, Init(10, 52, 140, 12, 'Sound Effects', @FontSmall, @CheckboxImage));
  SoundCheckbox^.SetEventHandler(@OnSoundCheckbox);
  SoundCheckbox^.SetChecked(True);
  UI.AddWidget(SoundCheckbox);

  { Create Music Checkbox }
  New(MusicCheckbox, Init(10, 67, 140, 12, 'Background Music', @FontSmall, @CheckboxImage));
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


begin
  InitResources;

  { Initialize systems }
  InitVGA;
  BackBuffer := CreateFrameBuffer;
  BackgroundBuffer := CreateFrameBuffer;

  { Clear background to dark blue }
  ClearFrameBuffer(BackgroundBuffer);
  ClearFrameBuffer(BackBuffer);

  InitKeyboard;
  InitRTC(1024);
  CreateUI;

  { Run UI - handles timing, input, and rendering automatically }
  UI.Run(@OnUpdate, True);

  { Cleanup }
  DestroyUI;
  DoneRTC;
  DoneKeyboard;
  FreeFrameBuffer(BackBuffer);
  FreeFrameBuffer(BackgroundBuffer);
  CloseVGA;

  FreeResources;
end.
