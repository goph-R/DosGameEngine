program XiClone;

uses
  GameUnit, GameScr;

var
  GameScreen: PGameScreen;

begin
  { Initialize game }
  Game.Init('..\SETUP\CONFIG.INI', 'DATA\RES.XML');
  Game.Start;

  { Create and register game screen }
  New(GameScreen, Init);
  Game.AddScreen('game', GameScreen);

  { Set initial screen and run }
  Game.SetNextScreen('game');
  Game.Run;

  { Cleanup }
  Game.Done;
end.