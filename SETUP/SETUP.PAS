program Setup;

uses TextUI, Keyboard, Config, PlayHSC, SBDSP, VocLoad, StrUtil;

const
  TestMusic = '..\TESTS\DATA\FANTASY.HSC';
  TestSound = '..\TESTS\DATA\EXPLODE.VOC';

{ Custom text mode functions to replace CRT unit }
function GetTextMode: Byte; assembler;
asm
  mov ah, 0Fh    { BIOS function: Get current video mode }
  int 10h        { Call BIOS video services }
  { AL contains the current video mode }
end;

procedure SetTextMode(Mode: Byte); assembler;
asm
  mov ah, 00h    { BIOS function: Set video mode }
  mov al, Mode   { AL = desired mode }
  int 10h        { Call BIOS video services }
end;

var
  GameConfig: TConfig;
  Music: HSC_obj;
  SBInitialized: Boolean;
  InitialTextMode: Byte;

  MainMenu: TMenu;
  TestMusicItem: PMenuItem;
  TestSoundItem: PMenuItem;
  SoundCardItem: PMenuItem;
  
  SoundCardMenu: TMenu;
  
  SoundBlasterMenu: TMenu;
  SBPortItem: PMenuItem;
  SBDMAItem: PMenuItem;
  SBIRQItem: PMenuItem;

procedure AdjustSoundItems;
var
  ValidSoundCard: Byte;
begin
  { Sound card menu item  }
  if GameConfig.SoundCard <= High(SoundCardNames) then
    ValidSoundCard := GameConfig.SoundCard
  else
    ValidSoundCard := 0;
  SoundCardItem^.Text := 'Sound Card: ' + SoundCardNames[ValidSoundCard];

  { Test menu items }
  TestMusicItem^.Disabled := GameConfig.SoundCard = SoundCard_None;
  TestSoundItem^.Disabled := GameConfig.SoundCard <> SoundCard_SoundBlaster;
end;

procedure SetSoundCard(SoundCard: Byte);
begin
  GameConfig.SoundCard := SoundCard;
  AdjustSoundItems;
end;

procedure AdjustSoundBlasterItems;
begin
  { Display actual port value, e.g., Base 2 -> $220 }
  { Formula: Port = Base * $10 + $200 }
  SBPortItem^.Text := 'Port:  ' + HexStr(GameConfig.SBPort * $10 + $200, 3);
  SBDMAItem^.Text  := 'DMA:   ' + IntToStr(GameConfig.SBDMA);
  SBIRQItem^.Text  := 'IRQ:   ' + IntToStr(GameConfig.SBIRQ);
end;

procedure SetSoundBlasterPort(Port: Word);
begin
  GameConfig.SBPort := Port;
  AdjustSoundBlasterItems;
end;

procedure SetSoundBlasterDMA(DMA: Byte);
begin
  GameConfig.SBDMA := DMA;
  AdjustSoundBlasterItems;
end;

procedure SetSoundBlasterIRQ(IRQ: Byte);
begin
  GameConfig.SBIRQ := IRQ;
  AdjustSoundBlasterItems;
end;

{ Helper: Generic input for Sound Blaster settings }
function InputNumericValue(Row: Integer; Width: Integer; CurrentValue: Word; IsHex: Boolean): Word;
var
  s: string;
  v: Word;
  m: string;
begin
  repeat
    if IsHex then
    begin
      s := ShowInput(37, Row, Width, HexStr(CurrentValue, Width));
      if (s <> '220') and (s <> '240') and (s <> '260') and (s <> '280') then
      begin
        m := 'Please use 220, 240, 260 or 280!';
        v := 0;
      end
      else
        v := HexStrToWord(s);
    end
    else
    begin
      s := ShowInput(37, Row, Width, IntToStr(CurrentValue));
      m := 'Please give a number!';
      v := StrToInt(s);
    end;

    { Validate }
    if v = 0 then
    begin
      ShowMessage(m, 'Press any key');
      RenderMenu(SoundBlasterMenu, SoundBlasterMenu.SelectedIndex, True);
    end;
  until v <> 0;

  InputNumericValue := v;
end;

{ Far calls required for procedure pointers }
{$F+}

procedure SelectSoundCard;
begin
  SoundCardMenu.SelectedIndex := GameConfig.SoundCard;
  SetMenu(SoundCardMenu);
end;

procedure SelectTestMusic;
var
  Waiting: Boolean;
  i: Integer;
begin
  Music.Init(0);
  if Music.LoadFile(TestMusic) then
  begin

    Music.Start;
    ShowMessageNoWait(
      'Music ' + TestMusic + ' is playing...',
      'Press any key to stop'
    );
    
    { Wait for keypress (music plays automatically via IRQ) }
    Waiting := True;
    ClearAllKeyStates;
    while Waiting do
    begin
      for i := 0 to 127 do
        if IsKeyPressed(i) then
        begin
          Waiting := False;
        end;
    end;
    ClearAllKeyStates;

  end
  else
    ShowMessage(
      'Could NOT load ' + TestMusic + '!',
      'Press any key'
    );

  Music.Done;
  SetMenu(MainMenu);
end;

procedure SelectTestSound;
begin
  { Uninstall old handler if already initialized (config may have changed) }
  if SBInitialized then
  begin
    UninstallHandler;
    SBInitialized := False;
  end;

  { Initialize Sound Blaster with current configuration }
  { Note: SBPort is stored as base value (2=$220, 4=$240, 6=$260, 8=$280) }
  if not ResetDSP(GameConfig.SBPort, GameConfig.SBIRQ, GameConfig.SBDMA, 0) then
  begin
    ShowMessage(
      'Sound Blaster NOT detected at port ' + HexStr(GameConfig.SBPort * $10 + $200, 3) + '!',
      'Press any key'
    );
    SetMenu(MainMenu);
    Exit;
  end;

  SBInitialized := True;

  { Play the VOC sound file }
  if PlayVOCFile(TestSound) then
  begin
    { Show message immediately - sound plays in background }
    ShowMessage(
      'Sound ' + TestSound + ' is playing...',
      'Press any key to stop'
    );

    { Stop sound immediately after key press }
    if Playing then
    begin
      DMAStop;      { Stop DMA transfer }
      SpeakerOff;   { Turn off speaker }
      Playing := False;  { Mark as not playing }
    end;

    { Don't free buffer here - let it stay allocated! }
    { VOCLOAD will free it when next sound plays or program exits }

  end
  else
  begin
    ShowMessage(
      'Could NOT load ' + TestSound + '!',
      'Press any key'
    );
  end;

  SetMenu(MainMenu);
end;

procedure SelectSaveAndExit;
begin
  SaveConfig(GameConfig, 'CONFIG.INI');
  StopMenu;
end;

procedure SelectExitWithoutSaving;
begin
  StopMenu;
end;

procedure SelectNone;
begin
  SetSoundCard(SoundCard_None);
  SetMenu(MainMenu);
end;

procedure SelectAdlib;
begin
  SetSoundCard(SoundCard_Adlib);
  SetMenu(MainMenu);
end;

procedure SelectSoundBlaster;
begin
  SetSoundCard(SoundCard_SoundBlaster);
  SoundBlasterMenu.SelectedIndex := 0;
  SetMenu(SoundBlasterMenu);
end;

procedure SelectSoundBlasterPort;
var
  DisplayValue: Word;
begin
  { Show actual port value to user (e.g., $220) }
  { Formula: Port = Base * $10 + $200 }
  DisplayValue := GameConfig.SBPort * $10 + $200;
  DisplayValue := InputNumericValue(10, 3, DisplayValue, True);
  { Convert back to base value for storage (e.g., $220 -> Base 2) }
  { Formula: Base = (Port - $200) div $10 }
  GameConfig.SBPort := (DisplayValue - $200) div $10;
  AdjustSoundBlasterItems;
  SetMenu(SoundBlasterMenu);
end;

procedure SelectSoundBlasterDMA;
begin
  GameConfig.SBDMA := InputNumericValue(11, 2, GameConfig.SBDMA, False);
  AdjustSoundBlasterItems;
  SetMenu(SoundBlasterMenu);
end;

procedure SelectSoundBlasterIRQ;
begin
  GameConfig.SBIRQ := InputNumericValue(12, 2, GameConfig.SBIRQ, False);
  AdjustSoundBlasterItems;
  SetMenu(SoundBlasterMenu);
end;

procedure SelectSoundBlasterDone;
begin
  SetMenu(MainMenu);
end;

{ Restore near calls }
{$F-} 

{ Initialize main menu }
procedure InitMainMenu;
begin
  MainMenu.Title := 'Main Menu';
  MainMenu.FirstMenuItem := nil;
  MainMenu.Col := 24;
  MainMenu.Row := 6;
  MainMenu.Width := 32;

  SoundCardItem := AddMenuItem(MainMenu, 'Sound card: None', SelectSoundCard);
  TestMusicItem := AddMenuItem(MainMenu, 'Test music', SelectTestMusic);
  TestSoundItem := AddMenuItem(MainMenu, 'Test sound', SelectTestSound);
  AddEmptyMenuItem(MainMenu);
  AddMenuItem(MainMenu, 'Save and Exit', SelectSaveAndExit);
  AddMenuItem(MainMenu, 'Exit Without Saving', SelectExitWithoutSaving);
  
  AdjustSoundItems;
end;

procedure InitSoundCardMenu;
begin
  SoundCardMenu.Title := 'Sound Card Setup';
  SoundCardMenu.FirstMenuItem := nil;
  SoundCardMenu.Col := 27;
  SoundCardMenu.Row := 8;
  SoundCardMenu.Width := 26;

  AddMenuItem(SoundCardMenu, SoundCardNames[SoundCard_None], SelectNone);
  AddMenuItem(SoundCardMenu, SoundCardNames[SoundCard_Adlib], SelectAdlib);
  AddMenuItem(SoundCardMenu, SoundCardNames[SoundCard_SoundBlaster], SelectSoundBlaster);
end;

procedure InitSoundBlasterMenu;
begin
  SoundBlasterMenu.Title := 'Sound Blaster Setup';
  SoundBlasterMenu.FirstMenuItem := nil;
  SoundBlasterMenu.Col := 27;
  SoundBlasterMenu.Row := 7;
  SoundBlasterMenu.Width := 26;

  SBPortItem := AddMenuItem(SoundBlasterMenu, 'Port:  220', SelectSoundBlasterPort);
  SBDMAItem := AddMenuItem(SoundBlasterMenu, 'DMA:   1', SelectSoundBlasterDMA);
  SBIRQItem := AddMenuItem(SoundBlasterMenu, 'IRQ:   5', SelectSoundBlasterIRQ);
  AddEmptyMenuItem(SoundBlasterMenu);
  AddMenuItem(SoundBlasterMenu, 'Done', SelectSoundBlasterDone);

  AdjustSoundBlasterItems;
end;

procedure RenderTitle;
begin
  RenderEmptyLine(0, $1F);
  RenderCenterText(0, GameTitle + ' ' + GameVersion + ' Setup', $1F);
end;

procedure RenderFooter;
begin
  RenderEmptyLine(24, $17);
  RenderText(64, 24, 'Dynart (C) 2025', $17);
  RenderText(1, 24, 'Up / Down', $1B);
  RenderText(11, 24, '- Move ' + Chr(179), $1F);
  RenderText(20, 24, 'Enter', $1B);
  RenderText(26, 24, '- Select', $1F);  
end;

begin
  { Init }

  InitialTextMode := GetTextMode;
  SetTextMode(3);  { Mode 3 = 80x25 color text mode }
  HideTextCursor;
  LoadConfig(GameConfig, 'CONFIG.INI');
  InitKeyboard;
  SBInitialized := False;


  InitMainMenu;
  InitSoundCardMenu;
  InitSoundBlasterMenu;

  RenderTitle;
  RenderFooter;

  { Run }
  SetMenu(MainMenu);
  StartMenu;

  { Done }
  FreeMenu(SoundBlasterMenu);
  FreeMenu(SoundCardMenu);
  FreeMenu(MainMenu);

  DoneKeyboard;

  { Cleanup Sound Blaster if initialized }
  if SBInitialized then
    UninstallHandler;

  { Free any remaining VOC buffer }
  FreeVOCBuffer;

  SetTextMode(InitialTextMode);
end.