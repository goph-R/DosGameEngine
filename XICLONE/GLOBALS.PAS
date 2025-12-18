unit Globals;

interface

uses
  VGA, VGAUI, VGAFont, HiScore, GameUnit;

const
  TileSize = 16;
  HighScoreSalt = 'XICLONE_HIGHSCORE_V1';  { Salt for high score tamper protection }
  MaxDialogButtons = 5;

type
  TCustomUIStyle = object(TUIStyle)
    procedure RenderPanel(const R: TRectangle; Pressed: Boolean; FrameBuffer: PFrameBuffer); virtual;
  end;

  TGemColor = (
    Gem_Empty,       { 0 - No gem }
    Gem_Red,         { 1 - Red gem }
    Gem_Yellow,      { 2 - Yellow gem }
    Gem_Green,       { 3 - Green gem }
    Gem_Blue,        { 4 - Blue gem }
    Gem_Pink,        { 5 - Pink gem }
    Gem_Purple,      { 6 - Purple gem }
    Gem_MagicJewel   { 7 - Special multi-colored gem }
  );

  TDialogType = (
    Dialog_None,
    Dialog_Paused,
    Dialog_GameOver,
    Dialog_ConfirmRestart,
    Dialog_ConfirmQuit
  );

  { Xi Clone game - extends TGame with game-specific resources }
  TXiCloneGame = object(TGame)
    { Game-specific resources }
    GemsImage: PImage;
    FontLarge: PFont;
    FontSmall: PFont;
    UIStyle: TCustomUIStyle;
    DialogUI: TUIManager;
    HighScoreTable: THighScore;
    Palette: PPalette;

    { Dialog resources }
    DialogImage: PImage;
    DialogBackgroundBuffer: PFrameBuffer;

    { Dialog state }
    ConfirmDialogAnswer: Boolean;
    NextDialog: TDialogType;
    PrevDialog: TDialogType;
    BackDialog: TDialogType;
    DialogSavedBgImage: TImage;
    DialogLabel: PLabel;
    DialogButtons: array [0..MaxDialogButtons - 1] of PButton;
    DialogButtonIndex: ShortInt;
    DialogHeight: Word;
    DialogHasTitle: Boolean;

    { Game-specific initialization and cleanup }
    constructor Init(const ConfigIniPath: String; const ResXmlPath: String);
    destructor Done; virtual;
    procedure Start; virtual;

    { Helper methods }
    procedure DrawGem(GemColor: TGemColor; X, Y: Integer);
    procedure SetNextDialog(ND: TDialogType);
  end;

var
  Game: TXiCloneGame;  { Global game instance }

implementation

procedure TCustomUIStyle.RenderPanel(const R: TRectangle; Pressed: Boolean; FrameBuffer: PFrameBuffer);
var
  TC, BC1, BC2, RC: Byte;
begin

  if Pressed then
  begin
    TC := LowColor;
    BC1 := NormalColor;
    BC2 := HighColor;
    RC := LowColor;
  end
  else
  begin
    TC := HighColor;
    BC1 := LowColor;
    BC2 := 12;
    RC := NormalColor;
  end;

  DrawFillRect(R, RC, FrameBuffer);

  DrawHLine(R.X + 1, R.Y + 1, R.Width - 3, TC, FrameBuffer);
  DrawVLine(R.X + 1, R.Y + 1, R.Height - 3, TC, FrameBuffer);

  DrawVLine(R.X + R.Width - 2, R.Y + 1, R.Height - 2, BC1, FrameBuffer);
  DrawHLine(R.X + 2, R.Y + R.Height - 2, R.Width - 3, BC1, FrameBuffer);
  DrawVLine(R.X + R.Width - 1, R.Y, R.Height, BC2, FrameBuffer);
  DrawHLine(R.X + 1, R.Y + R.Height - 1, R.Width - 2, BC2, FrameBuffer);
end;

{ ========== TXiCloneGame Implementation ========== }

constructor TXiCloneGame.Init(const ConfigIniPath: String; const ResXmlPath: String);
var
  I: Integer;
begin
  { Call parent constructor }
  inherited Init(ConfigIniPath, ResXmlPath);

  { Initialize dialog state }
  NextDialog := Dialog_None;
  PrevDialog := Dialog_None;
  BackDialog := Dialog_None;
  ConfirmDialogAnswer := False;
  DialogLabel := nil;
  DialogButtonIndex := -1;
  DialogHeight := 0;
  DialogHasTitle := False;

  { Initialize dialog button array }
  for I := 0 to MaxDialogButtons - 1 do
    DialogButtons[I] := nil;

  { Resources will be loaded in Start after VGA initialization }
  GemsImage := nil;
  FontLarge := nil;
  FontSmall := nil;
  Palette := nil;
  DialogImage := nil;
  DialogBackgroundBuffer := nil;
end;

destructor TXiCloneGame.Done;
begin
  { Free dialog resources }
  if DialogBackgroundBuffer <> nil then
  begin
    FreeFrameBuffer(DialogBackgroundBuffer);
    DialogBackgroundBuffer := nil;
  end;

  { Parent will cleanup resources via ResMan }
  inherited Done;
end;

procedure TXiCloneGame.Start;
begin
  { Call parent Start (initializes VGA, etc.) }
  inherited Start;

  { Load game-specific resources (only once, after VGA init) }
  GemsImage := ResMan.GetImage('gems1');
  FontLarge := ResMan.GetFont('large');
  FontSmall := ResMan.GetFont('small');
  Palette := ResMan.GetPalette('default');

  { Load dialog resources }
  DialogImage := ResMan.GetImage('dialog');
  DialogBackgroundBuffer := CreateFrameBuffer;

  { Initialize UI style }
  UIStyle.Init(186, 188, 189, 15);

  { Initialize high score system }
  InitHighScore(HighScoreTable, HighScoreSalt);
  LoadHighScore('SCORES.XML', HighScoreTable);
end;

procedure TXiCloneGame.DrawGem(GemColor: TGemColor; X, Y: Integer);
var
  GemRect: TRectangle;
  GemIndex: Integer;
begin
  { Step 1: ALWAYS restore the background first }
  { This wipes whatever 'ghost' data (exploded gems, etc) is in this spot }
  GemRect.X := X;
  GemRect.Y := Y;
  GemRect.Width := TileSize;
  GemRect.Height := TileSize;

  CopyFrameBufferRect(BackgroundBuffer, GemRect, BackBuffer, X, GemRect.Y);

  { Step 2: If it's empty, we are done (background is already restored) }
  if GemColor = Gem_Empty then Exit;

  { Calculate gem sprite index }
  GemIndex := Ord(GemColor);

  { Setup source rectangle in gem sprite sheet }
  GemRect.X := GemIndex * TileSize;
  GemRect.Y := 0;

  { Step 3: Draw gem sprite over the clean background }
  PutImageRect(GemsImage^, GemRect, X, Y, True, BackBuffer);
end;

procedure TXiCloneGame.SetNextDialog(ND: TDialogType);
begin
  PrevDialog := NextDialog;
  NextDialog := ND;
end;

end.
