program XiClone;

uses
  GameUnit, GameScr;

var
  GameScreen: PGameScreen;

begin
  WriteLn('Loading XiClone...');

  { Initialize }
  Game.Init('..\SETUP\CONFIG.INI', 'DATA\RES.XML');
  Game.Start;

  { Create and register screens }
  New(GameScreen, Init);
  Game.AddScreen('game', GameScreen);

  { Run }
  Game.SetNextScreen('game');
  Game.Run;

  { Cleanup }
  Game.Done;

  WriteLn('Thanks for playing XiClone!');
end.