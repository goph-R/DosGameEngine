program Setup;

uses Crt, TextUI, Keyboard, Config, PlayHSC, SB, StrUtil;

const
  TestMusic = 'FANTASY.HSC';
  TestSound = 'EXPLODE.VOC';

var
  GameConfig: TConfig;
  Music: HSC_obj;
  SoundBlaster: TSoundBlaster;

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
  SBPortItem^.Text := 'Port:  ' + HexStr(GameConfig.SBPort, 3);
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

{ Far calls required for procedure pointers }
{$F+}  

procedure SelectSoundCard;
begin
  SoundCardMenu.SelectedIndex := GameConfig.SoundCard;
  SetMenu(SoundCardMenu);
end;

procedure SelectTestMusic;
begin
  Music.Init(0);
  if Music.LoadFile('DATA\' + TestMusic) then
  begin
    Music.Start;
    ShowMessage(
      'Music ' + TestMusic + ' is playing...',
      'Press any key to stop'
    );
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
  FillChar(SoundBlaster, SizeOf(SoundBlaster), 0);
  
  { TODO }
  {
  SoundBlaster.BasePort := GameConfig.SBPort;
  SoundBlaster.IRQ := GameConfig.SBIRQ;
  SoundBlaster.DMA := GameConfig.SBDMA;
  }

  if SoundBlaster.Init then
  begin
    if SoundBlaster.PlayVOC('DATA\' + TestSound) then
      ShowMessage(
        'Sound ' + TestSound + ' is playing...',
        'Press any key to stop'
       )
    else
      ShowMessage(
        'Could NOT load ' + TestSound + '!',
        'Press any key'
      );
  end
  else
    ShowMessage(
      'Sound Blaster NOT detected!',
      'Press any key'
    );
  SoundBlaster.Done;
  SetMenu(MainMenu);
end;

procedure SelectSaveAndExit;
begin
  SaveConfig(GameConfig);
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
  s: string;
  v: Word;
begin
  repeat
    s := ShowInput(37, 11, 3, HexStr(GameConfig.SBPort, 3));
    v := HexStrToWord(s);
    if v = 0 then
    begin
      ShowMessage('Please give a hexadecimal number!', 'Press any key');
      RenderMenu(SoundBlasterMenu, SoundBlasterMenu.SelectedIndex, True);
    end;
  until v <> 0;
  GameConfig.SBPort := v;
  AdjustSoundBlasterItems;
  SetMenu(SoundBlasterMenu);
end;

procedure SelectSoundBlasterDMA;
var
  s: string;
  v: Byte;
begin
  repeat
    s := ShowInput(37, 12, 1, IntToStr(GameConfig.SBDMA));
    v := StrToInt(s);
    if v = 0 then
    begin
      ShowMessage('Please give a number!', 'Press any key');
      RenderMenu(SoundBlasterMenu, SoundBlasterMenu.SelectedIndex, True);
    end;
  until v <> 0;
  GameConfig.SBDMA := v;
  AdjustSoundBlasterItems;
  SetMenu(SoundBlasterMenu);
end;

procedure SelectSoundBlasterIRQ;
var
  s: string;
  v: Byte;
begin
  repeat
    s := ShowInput(37, 13, 1, IntToStr(GameConfig.SBIRQ));
    v := StrToInt(s);
    if v = 0 then
    begin
      ShowMessage('Please give a number!', 'Press any key');
      RenderMenu(SoundBlasterMenu, SoundBlasterMenu.SelectedIndex, True);
    end;
  until v <> 0;
  GameConfig.SBIRQ := v;
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
  MainMenu.Row := 7;
  MainMenu.Width := 33;

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
  SoundCardMenu.Row := 9;
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
  SoundBlasterMenu.Row := 8;
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
  TextMode(CO80);
  HideTextCursor;
  LoadConfig(GameConfig);
  InitKeyboard;

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
  TextMode(LastMode);
end.