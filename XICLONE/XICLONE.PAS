program XiClone;

uses
  XiGame, GameScr;

var
  GameScreen: PGameScreen;

begin
  WriteLn('Loading XiClone...');

  { Initialize config }
  GameConfig.Init('CONFIG.INI');

  { Initialize game }
  Game.Init(@GameConfig, 'DATA\RES.XML');
  Game.Start;

  { Create and register screens }
  New(GameScreen, Init);
  Game.AddScreen('game', GameScreen);

  { Run }
  Game.SetNextScreen('game');
  Game.Run;

  { Cleanup }
  Game.Done;
  GameConfig.Done;

  WriteLn('Thanks for playing XiClone!');
end.