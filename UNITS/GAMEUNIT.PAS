unit GameUnit;

{$G+}  { Enable 286 instructions }
{$F+}  { Enable far calls for procedural types }

interface

uses
  VGA, Config, StrMap, RTCTimer, Keyboard, Mouse, SBDSP, ResMan, PlayHSC, VGAUI;

type
  { Forward declarations }
  PGame = ^TGame;
  PScreen = ^TScreen;

  { Screen object - abstract base for game states/screens }
  TScreen = object
    DialogLabel: PLabel;

    constructor Init;
    destructor Done; virtual;
    procedure PostInit; virtual;
    procedure Update(DT: Real); virtual;
    procedure Show; virtual;
    procedure Hide; virtual;
    procedure AddDialogLabel(ADialogLabel: PLabel);
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
    NextScreen: PScreen;
    ScreenMap: TStringMap;

    { Framebuffers }
    BackgroundBuffer: PFrameBuffer;
    BackBuffer: PFrameBuffer;
    ScreenBuffer: PFrameBuffer;

    { Internal state }
    VGAInitialized: Boolean;
    MouseInitialized: Boolean;
    SoundInitialized: Boolean;

    constructor Init(const ConfigIniPath: String; const ResXmlPath: String);
    destructor Done;
    procedure Start; virtual;
    procedure Run; virtual;
    procedure Update(DT: Real); virtual;
    procedure Stop;
    procedure ResetTiming;

    { Music control }
    procedure PlayMusic(const Name: String); virtual;
    procedure PauseMusic; virtual;
    procedure StopMusic; virtual;

    { Screen management }
    procedure SetNextScreen(const Name: String); virtual;
    procedure SetScreen; virtual;
    procedure AddScreen(const Name: String; AScreen: PScreen); virtual;
    function GetScreen(const Name: String): PScreen;
  end;

implementation

var
  CurrentGame: PGame;  { Pointer to current game instance for exit handler }

{ ========== TScreen Implementation ========== }

constructor TScreen.Init;
begin
  { Base implementation - override in derived screens }
  DialogLabel := nil;
end;

destructor TScreen.Done;
begin
  { Base implementation - override in derived screens }
end;

procedure TScreen.PostInit;
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

procedure TScreen.AddDialogLabel(ADialogLabel: PLabel);
begin
  DialogLabel := ADialogLabel;
end;

{ ========== TGame Implementation ========== }

{ Cleanup procedure for abnormal exit }
{$F+}
procedure CleanupOnExit; far;
begin
  if CurrentGame <> nil then
    CurrentGame^.Done;
end;
{$F-}

constructor TGame.Init(const ConfigIniPath: String; const ResXmlPath: String);
begin
  { Set current game instance for exit handler }
  CurrentGame := @Self;

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
  VGAInitialized := False;
  CurrentTime := 0.0;
  LastTime := 0.0;
  DeltaTime := 0.0;

  { Initialize screen map }
  MapInit(ScreenMap);
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
  if VGAInitialized then
    CloseVGA;

  { Clear current game pointer }
  CurrentGame := nil;
end;

procedure TGame.Start;
begin
  { InitVGA needs to be right before PostInit! }

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
end;

procedure TGame.Run;
var
  I: Integer;
  ScreenPtr: PScreen;
  Entry: PMapEntry;  
begin
  InitVGA;
  VGAInitialized := True;
  Running := True;

  { PostInit all screen }
  for I := 0 to StrMap.MAX_ENTRIES - 1 do
  begin
    Entry := ScreenMap.Entries[I];
    if (Entry <> nil) and Entry^.Used then
    begin
      ScreenPtr := PScreen(Entry^.Value);
      if ScreenPtr <> nil then
        ScreenPtr^.PostInit;
    end;
  end;

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
  { Set the screen via the NextScreen if needed }
  SetScreen;

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
var
  Music: PHSC_Obj;
begin
  { Exit if no sound card }
  if Config.SoundCard = SoundCard_None then
    Exit;

  { Check if the same music is already loaded and playing }
  if (ResMan.CurrentMusicName <> nil) and
     (ResMan.CurrentMusicName^ = Name) and
     (ResMan.CurrentMusic <> nil) and
     ResMan.CurrentMusic^.Music.Music_Run then
    Exit;  { Same music already playing, don't restart }

  { Get music from resource manager }
  Music := ResMan.GetMusic(Name);
  if Music = nil then
    Exit;

  { Start playing (IRQ mode, no manual polling needed) }
  Music^.Start;
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

procedure TGame.SetNextScreen(const Name: String);
begin
  if MapContains(ScreenMap, Name) then
    NextScreen := PScreen(MapGet(ScreenMap, Name));
end;

procedure TGame.SetScreen;
begin
  if NextScreen = nil then
    Exit;

  { Hide current screen }
  if Screen <> nil then
    Screen^.Hide;

  { Set new screen }
  Screen := NextScreen;

  { Show new screen }
  if Screen <> nil then
    Screen^.Show;

  NextScreen := nil;
end;

function TGame.GetScreen(const Name: String): PScreen;
begin
  if MapContains(ScreenMap, Name) then
    GetScreen := PScreen(MapGet(ScreenMap, Name))
  else
    GetScreen := nil
end;

procedure TGame.AddScreen(const Name: String; AScreen: PScreen);
begin
  MapPut(ScreenMap, Name, AScreen);
end;

procedure TGame.Stop;
begin
  Running := False;
end;

procedure TGame.ResetTiming;
begin
  LastTime := GetTimeSeconds;
end;

end.
