program XiClone;

uses
  GameUnit, GameScr;

var
  Game: TGame;
  GameScreen: PGameScreen;

begin
  { Initialize game }
  Game.Init('..\SETUP\CONFIG.INI', 'DATA\RES.XML');
  Game.Start;

  { Create and register game screen }
  New(GameScreen, Init(@Game));
  Game.AddScreen('game', GameScreen);

  { Set initial screen and run }
  Game.SetScreen('game');
  Game.Run;

  { Cleanup }
  Game.Done;
end.