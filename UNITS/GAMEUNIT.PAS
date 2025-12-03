unit GameUnit;

{$G+}  { Enable 286 instructions }
{$F+}  { Enable far calls for procedural types }

interface

uses
  VGA, Config, StrMap, RTCTimer, Keyboard, Mouse, SBDSP, ResMan;

type
  { Forward declarations }
  PGame = ^TGame;
  PScreen = ^TScreen;

  { Screen object - abstract base for game states/screens }
  TScreen = object
    Game: PGame;  { Pointer to parent game instance }

    constructor Init(AGame: PGame);
    destructor Done; virtual;
    procedure Update(DT: Real); virtual;
    procedure Show; virtual;
    procedure Hide; virtual;
  end;

  { Main game object }
  TGame = object
    { Configuration & Resources }
    Config: TConfig;
    ConfigFilePath: String;
    ResFilePath: String;
    ResMan: TResourceManager;

    { Timing }
    CurrentTime: Real;
    LastTime: Real;
    DeltaTime: Real;

    { State }
    Running: Boolean;

    { Screen Management }
    Screen: PScreen;
    ScreenMap: TStringMap;

    { Framebuffers }
    BackgroundBuffer: PFrameBuffer;
    BackBuffer: PFrameBuffer;
    ScreenBuffer: PFrameBuffer;

    { Internal state }
    MouseInitialized: Boolean;
    SoundInitialized: Boolean;

    constructor Init(const ConfigIniPath: String; const ResXmlPath: String);
    destructor Done;
    procedure Start; virtual;
    procedure Run; virtual;
    procedure Update(DT: Real); virtual;

    { Music control }
    procedure PlayMusic(const Name: String); virtual;
    procedure PauseMusic; virtual;
    procedure StopMusic; virtual;

    { Screen management }
    procedure SetScreen(const Name: String); virtual;
    procedure AddScreen(const Name: String; AScreen: PScreen); virtual;
  end;

implementation

var
  GameInstance: PGame;  { Global for ExitProc }

{ ========== TScreen Implementation ========== }

constructor TScreen.Init(AGame: PGame);
begin
  Game := AGame;
end;

destructor TScreen.Done;
begin
  { Base implementation - override in derived screens }
end;

procedure TScreen.Update(DT: Real);
begin
  { Base implementation - override in derived screens }
end;

procedure TScreen.Show;
begin
  { Base implementation - override in derived screens }
end;

procedure TScreen.Hide;
begin
  { Base implementation - override in derived screens }
end;

{ ========== TGame Implementation ========== }

{ Cleanup procedure for abnormal exit }
{$F+}
procedure CleanupOnExit; far;
begin
  if GameInstance <> nil then
  begin
    GameInstance^.Done;
    GameInstance := nil;
  end;
end;
{$F-}

constructor TGame.Init(const ConfigIniPath: String; const ResXmlPath: String);
begin
  { Store file paths }
  ConfigFilePath := ConfigIniPath;
  ResFilePath := ResXmlPath;

  { Initialize state }
  Running := False;
  Screen := nil;
  BackgroundBuffer := nil;
  BackBuffer := nil;
  ScreenBuffer := nil;
  MouseInitialized := False;
  SoundInitialized := False;
  CurrentTime := 0.0;
  LastTime := 0.0;
  DeltaTime := 0.0;

  { Initialize screen map }
  MapInit(ScreenMap);

  { Store global instance for ExitProc }
  GameInstance := @Self;
end;

destructor TGame.Done;
var
  I: Integer;
  ScreenPtr: PScreen;
  Entry: PMapEntry;
begin
  { Free framebuffers }
  if BackBuffer <> nil then
  begin
    FreeFrameBuffer(BackBuffer);
    BackBuffer := nil;
  end;

  if BackgroundBuffer <> nil then
  begin
    FreeFrameBuffer(BackgroundBuffer);
    BackgroundBuffer := nil;
  end;

  { Free all screens }
  for I := 0 to StrMap.MAX_ENTRIES - 1 do
  begin
    Entry := ScreenMap.Entries[I];
    if (Entry <> nil) and Entry^.Used then
    begin
      ScreenPtr := PScreen(Entry^.Value);
      if ScreenPtr <> nil then
        Dispose(ScreenPtr, Done);
    end;
  end;

  { Free screen map }
  MapFree(ScreenMap);

  { Uninitialize mouse }
  if MouseInitialized then
  begin
    DoneMouse;
    MouseInitialized := False;
  end;

  { Uninitialize sound }
  if SoundInitialized then
  begin
    UninstallHandler;
    SoundInitialized := False;
  end;

  { Uninitialize keyboard }
  DoneKeyboard;

  { Uninitialize RTC timer }
  DoneRTC;

  { Cleanup resource manager }
  ResMan.Done;

  { Close VGA }
  CloseVGA;

  { Clear global instance }
  GameInstance := nil;
end;

procedure TGame.Start;
begin
  { Set up exit handler }
  ExitProc := @CleanupOnExit;

  { Load configuration }
  LoadConfig(Config, ConfigFilePath);

  { Initialize resource manager }
  ResMan.Init(True);  { Lazy loading }
  if not ResMan.LoadFromXML(ResFilePath) then
  begin
    WriteLn('ERROR: Failed to load resources: ', ResMan.LastError);
    Halt(1);
  end;

  { Initialize VGA }
  InitVGA;

  { Initialize RTC timer (1024 Hz) }
  InitRTC(1024);

  { Initialize keyboard }
  InitKeyboard;

  { Initialize Sound Blaster if configured }
  if Config.SoundCard = SoundCard_SoundBlaster then
  begin
    ResetDSP(Config.SBPort, Config.SBIRQ, Config.SBDMA, 0);
    SoundInitialized := True;
  end;

  { Initialize mouse if configured }
  if Config.UseMouse = 1 then
  begin
    InitMouse;
    MouseInitialized := True;
  end;

  { Create framebuffers }
  BackgroundBuffer := CreateFrameBuffer;
  BackBuffer := CreateFrameBuffer;
  ScreenBuffer := GetScreenBuffer;

  { Clear buffers }
  ClearFrameBuffer(BackgroundBuffer);
  ClearFrameBuffer(BackBuffer);
end;

procedure TGame.Run;
begin
  Running := True;
  LastTime := GetTimeSeconds;

  while Running do
  begin
    { Calculate delta time }
    CurrentTime := GetTimeSeconds;
    DeltaTime := CurrentTime - LastTime;
    LastTime := CurrentTime;

    { Update }
    Update(DeltaTime);
  end;
end;

procedure TGame.Update(DT: Real);
begin
  { Update mouse if initialized }
  if MouseInitialized then
    UpdateMouse;

  { Handle exit Mortal Kombat style }
  { TODO: make this optional }
  if (IsKeyDown(Key_LAlt) and IsKeyPressed(Key_Q)) then
    Running := False;

  { Call current screen's update if exists, it should render itself how it wishes }
  if Screen <> nil then
    Screen^.Update(DT);

  { TODO: make this optional }
  WaitForVSync;

  ClearKeyPressed;
end;

procedure TGame.PlayMusic(const Name: String);
begin
  { Exit if no sound card }
  if Config.SoundCard = SoundCard_None then
    Exit;

  { TODO: Implement music loading via ResMan }
  { ResMan.LoadMusic(Name); }
  { Music.Play; }
end;

procedure TGame.PauseMusic;
begin
  { Exit if no sound card }
  if Config.SoundCard = SoundCard_None then
    Exit;

  { TODO: Implement music pause }
  { Music.Pause; }
end;

procedure TGame.StopMusic;
begin
  { Exit if no sound card }
  if Config.SoundCard = SoundCard_None then
    Exit;

  { TODO: Implement music stop }
  { Music.Stop; }
end;

procedure TGame.SetScreen(const Name: String);
var
  NewScreen: PScreen;
begin
  { Look up screen in map }
  if not MapContains(ScreenMap, Name) then
    Exit;

  NewScreen := PScreen(MapGet(ScreenMap, Name));

  { Hide current screen }
  if Screen <> nil then
    Screen^.Hide;

  { Set new screen }
  Screen := NewScreen;

  { Show new screen }
  if Screen <> nil then
    Screen^.Show;
end;

procedure TGame.AddScreen(const Name: String; AScreen: PScreen);
begin
  MapPut(ScreenMap, Name, AScreen);
end;

end.
