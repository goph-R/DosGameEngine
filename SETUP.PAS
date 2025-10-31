program Setup;

uses Crt, TextUI, Keyboard, Config;

var
  GameConfig: TConfig;
  MainMenu: TMenu;
  SoundCardMenu: TMenu;
  SoundCardItem: PMenuItem;
  TestMusicItem: PMenuItem;
  TestSoundItem: PMenuItem;

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

{ Far calls required for procedure pointers }
{$F+}  

procedure SelectSoundCard;
begin
  RenderMenu(SoundCardMenu, 0, True);
  RunMenu(SoundCardMenu);
end;

procedure SelectTestMusic;
begin
  { TODO }
  RunMenu(MainMenu);
end;

procedure SelectTestSound;
begin
  { TODO }
  RunMenu(MainMenu);
end;

procedure SelectSaveAndExit;
begin
  SaveConfig(GameConfig);
end;

procedure SelectExitWithoutSaving;
begin
end;

procedure SelectNone;
begin
  SetSoundCard(SoundCard_None);
  RunMenu(MainMenu);
end;

procedure SelectAdlib;
begin
  SetSoundCard(SoundCard_Adlib);
  RunMenu(MainMenu);
end;

procedure SelectSoundBlaster;
begin
  { TODO }
  SetSoundCard(SoundCard_SoundBlaster);
  RunMenu(MainMenu);
end;

{ Restore near calls }
{$F-} 

{ Initialize main menu }
procedure InitMainMenu;
begin
  MainMenu.Title := 'Main Menu';
  MainMenu.FirstMenuItem := nil;
  MainMenu.Col := 24;
  MainMenu.Row := 8;
  MainMenu.Width := 31;

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
  SoundCardMenu.Title := 'Sound Card';
  SoundCardMenu.FirstMenuItem := nil;
  SoundCardMenu.Col := 30;
  SoundCardMenu.Row := 8;
  SoundCardMenu.Width := 20;

  AddMenuItem(SoundCardMenu, SoundCardNames[SoundCard_None], SelectNone);
  AddMenuItem(SoundCardMenu, SoundCardNames[SoundCard_Adlib], SelectAdlib);
  AddMenuItem(SoundCardMenu, SoundCardNames[SoundCard_SoundBlaster], SelectSoundBlaster);
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
  HideCursor;
  LoadConfig(GameConfig);
  InitKeyboard;

  InitMainMenu;
  InitSoundCardMenu;

  RenderTitle;
  RenderFooter;

  { Run }
  RunMenu(MainMenu);

  { Done }
  FreeMenu(MainMenu);
  FreeMenu(SoundCardMenu);

  DoneKeyboard;
  TextMode(LastMode);
end.