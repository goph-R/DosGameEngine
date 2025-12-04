# Game Engine Core Architecture

Central game loop framework with screen management, resource loading, and subsystem initialization.

## Global Instance

```pascal
var
  Game: TGame;  { Global game instance }
```

The `Game` variable is a global instance of `TGame` provided by `GameUnit`. Use this instance in your program instead of creating your own.

## TGame Object

**Unit:** `GameUnit`

Main game object that manages the entire application lifecycle.

### Constructor

```pascal
constructor Init(ConfigIniPath: String; ResXmlPath: String);
```

- `ConfigIniPath`: Path to CONFIG.INI file
- `ResXmlPath`: Path to resources XML file (for TResourceManager)

### Methods

```pascal
procedure Start;
```

Initialize all subsystems and prepare for game loop:

1. Set up `CleanupOnExit` procedure (handles Ctrl+C/Break gracefully)
2. Load config: `Config.LoadConfig(ConfigIniPath)`
3. Initialize resource manager: `ResMan.Init(ResXmlPath)`
4. Initialize RTCTimer: `InitRTC(1024)` (1024 Hz for millisecond precision)
5. Initialize keyboard: `InitKeyboard`
6. Initialize Sound Blaster: `ResetDSP(Config.SBPort, Config.SBIRQ, Config.SBDMA, 0)` if `Config.SoundCard = SoundCard_SoundBlaster` (2)
7. Initialize mouse: `InitMouse` if `Config.UseMouse = 1`
8. Create framebuffers:
   - `BackgroundBuffer := CreateFrameBuffer` (cleared once, used for static backgrounds)
   - `BackBuffer := CreateFrameBuffer` (working buffer)
   - `ScreenBuffer := GetScreenBuffer` (VGA display buffer)
9. Clear buffers: `ClearFrameBuffer(BackgroundBuffer)`, `ClearFrameBuffer(BackBuffer)`

```pascal
procedure Run;
```

Main game loop - reads RTC timer, calculates delta time, calls `Update`, handles rendering:

```pascal
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

    { Update (calls SetScreen, UpdateMouse, Screen^.Update, WaitForVSync, ClearKeyPressed) }
    Update(DeltaTime);
  end;
end;
```

**Note:** Screens are responsible for their own rendering. The default `Update` calls `Screen^.Update(DeltaTime)`, which should handle drawing to `Game.BackBuffer` and calling `RenderFrameBuffer`.

```pascal
destructor Done;
```

Shutdown all subsystems (reverse order of `Start`):

1. Free framebuffers: `FreeFrameBuffer(BackgroundBuffer)`, `FreeFrameBuffer(BackBuffer)`
2. Free screens: iterate screen map and call `Dispose(Screen, Done)`
3. Free screen map: `ScreenMap.Free`
4. Uninitialize mouse: `DoneMouse` (if initialized)
5. Uninitialize Sound Blaster: `UninstallHandler` (if initialized)
6. Uninitialize keyboard: `DoneKeyboard`
7. Uninitialize RTC timer: `DoneRTC`
8. Free resource manager: `ResMan.Done`

```pascal
procedure CleanupOnExit;
```

ExitProc handler - ensures `Done` is called on abnormal termination (Ctrl+C, Runtime Error, etc.)

```pascal
procedure PlayMusic(Name: String);
```

- Load and play music track by resource name
- `Exit` immediately if `Config.SoundCard = SoundCard_None` (0)
- Uses ResMan to load music file

```pascal
procedure PauseMusic;
```

- Pause current music playback
- `Exit` if `Config.SoundCard = SoundCard_None`

```pascal
procedure StopMusic;
```

- Stop current music playback
- `Exit` if `Config.SoundCard = SoundCard_None`

```pascal
procedure SetNextScreen(Name: String); virtual;
```

Queue a screen switch (deferred until next `Update`):

1. Look up screen in `ScreenMap` by name
2. Set `NextScreen` field to the found screen

**Note:** Screen switch happens in `Update`, not immediately. This prevents issues with switching screens mid-frame.

```pascal
procedure SetScreen; virtual;
```

Apply queued screen switch (called automatically in `Update`):

1. Exit if `NextScreen = nil`
2. If current `Screen <> nil`: call `Screen^.Hide`
3. Set `Screen := NextScreen`
4. If new `Screen <> nil`: call `Screen^.Show`
5. Set `NextScreen := nil`

**Note:** This is called internally by `Update`. Don't call directly unless you need immediate screen switching.

```pascal
function GetScreen(Name: String): PScreen;
```

Retrieve a screen by name from `ScreenMap`:

- Returns `PScreen` if found
- Returns `nil` if not found

```pascal
procedure AddScreen(Name: String; AScreen: PScreen); virtual;
```

Register a screen in the screen map: `MapPut(ScreenMap, Name, AScreen)`

```pascal
procedure Update(DeltaTime: Real); virtual;
```

**Virtual method** - can be overridden in derived game objects.

Default implementation:
1. Call `SetScreen` to apply queued screen switch (if `NextScreen <> nil`)
2. Update mouse if initialized: `UpdateMouse`
3. Handle exit shortcut: `Alt+Q` stops the game (sets `Running := False`)
4. If `Screen <> nil`: call `Screen^.Update(DeltaTime)`
5. Wait for VSync: `WaitForVSync`
6. Clear keyboard state: `ClearKeyPressed`

### Properties

```pascal
type
  PGame = ^TGame;
  TGame = object
    { Configuration & Resources }
    Config: TConfig;                 { Game configuration (see CONFIG.PAS) }
    ConfigFilePath: String;          { Path to CONFIG.INI }
    ResFilePath: String;             { Path to resources XML }
    ResMan: TResourceManager;        { Resource manager (see RESMAN.PAS) }

    { Timing }
    CurrentTime: Real;               { Current time in seconds (from GetTimeSeconds) }
    LastTime: Real;                  { Previous frame time in seconds }
    DeltaTime: Real;                 { Time elapsed since last frame (seconds) }

    { State }
    Running: Boolean;                { Main loop control flag }

    { Screen Management }
    Screen: PScreen;                 { Current active screen }
    NextScreen: PScreen;             { Next screen to switch to (queued) }
    ScreenMap: TStringMap;           { Name -> PScreen mapping }

    { Framebuffers }
    BackgroundBuffer: PFrameBuffer;  { Static background (cleared once) }
    BackBuffer: PFrameBuffer;        { Working render buffer }
    ScreenBuffer: PFrameBuffer;      { VGA display buffer (from GetScreenBuffer) }

    { Internal state }
    MouseInitialized: Boolean;       { Mouse driver initialized }
    SoundInitialized: Boolean;       { Sound Blaster initialized }
  end;
```

## TScreen Object

**Unit:** `GameUnit`

Abstract screen/state object for menu screens, gameplay, etc.

### Constructor

```pascal
constructor Init;
```

Base constructor - override in derived screens. No parameters needed since screens access the global `Game` instance.

### Methods

```pascal
destructor Done; virtual;
```

Cleanup screen resources. **Virtual** - override to free screen-specific resources.

```pascal
procedure Update(DeltaTime: Real); virtual;
```

Per-frame update logic. **Virtual** - override for game-specific logic.

```pascal
procedure Show; virtual;
```

Called when screen becomes active. **Virtual** - override to:
- Initialize screen-specific resources
- Load screen assets
- Reset screen state

```pascal
procedure Hide; virtual;
```

Called when screen becomes inactive. **Virtual** - override to:
- Save screen state if needed
- Pause screen-specific timers
- Optionally free screen assets

### Properties

```pascal
type
  PScreen = ^TScreen;
  TScreen = object
    { No fields in base - add fields in derived screens }
  end;
```

## Usage Example

```pascal
program MyGame;

uses
  GameUnit, Keyboard;

type
  PMenuScreen = ^TMenuScreen;
  TMenuScreen = object(TScreen)
    procedure Update(DeltaTime: Real); virtual;
    procedure Show; virtual;
    procedure Hide; virtual;
  end;

  PGameplayScreen = ^TGameplayScreen;
  TGameplayScreen = object(TScreen)
    procedure Update(DeltaTime: Real); virtual;
    procedure Show; virtual;
    procedure Hide; virtual;
  end;

var
  MenuScreen: PMenuScreen;
  GameplayScreen: PGameplayScreen;

{ MenuScreen implementation }
procedure TMenuScreen.Update(DeltaTime: Real);
begin
  { Handle menu input - queue screen switch }
  if IsKeyPressed(Key_Enter) then
    Game.SetNextScreen('gameplay');  { Deferred switch }
end;

procedure TMenuScreen.Show;
begin
  { Load menu assets, show cursor, etc. }
end;

procedure TMenuScreen.Hide;
begin
  { Hide cursor, etc. }
end;

{ GameplayScreen implementation }
procedure TGameplayScreen.Update(DeltaTime: Real);
begin
  { Game logic here }
  if IsKeyPressed(Key_Escape) then
    Game.SetNextScreen('menu');  { Return to menu }
end;

procedure TGameplayScreen.Show;
begin
  { Load level assets }
end;

procedure TGameplayScreen.Hide;
begin
  { Pause game, etc. }
end;

begin
  { Initialize game (uses global Game instance) }
  Game.Init('CONFIG.INI', 'DATA\RES.XML');

  { Create and register screens }
  New(MenuScreen, Init);
  Game.AddScreen('menu', MenuScreen);

  New(GameplayScreen, Init);
  Game.AddScreen('gameplay', GameplayScreen);

  { Start and run }
  Game.Start;                  { Initialize all subsystems }
  Game.SetNextScreen('menu');  { Queue initial screen }
  Game.Run;                    { Main loop }

  { Cleanup }
  Game.Done;
end.
```

## Dependencies

- **CONFIG**: TConfig, LoadConfig, SoundCard constants
- **RESMAN**: TResourceManager (future)
- **RTCTIMER**: InitRTC, DoneRTC, GetTimeSeconds
- **KEYBOARD**: InitKeyboard, DoneKeyboard, IsKeyPressed, ClearKeyPressed
- **SBDSP**: ResetDSP, UninstallHandler
- **MOUSE**: InitMouse, DoneMouse
- **VGA**: CreateFrameBuffer, FreeFrameBuffer, GetScreenBuffer, ClearFrameBuffer, CopyFrameBuffer, RenderFrameBuffer
- **STRMAP**: TStringMap (screen name -> PScreen mapping)

## Notes

- **Global instance**: `Game` is a global variable in `GameUnit`. Use this instead of creating your own instance.
- **Virtual methods**: All `TScreen` methods are virtual. Override `Update`, `Show`, `Hide` as needed.
- **Deferred screen switching**: Use `SetNextScreen('name')` to queue screen switches. The switch happens in the next `Update` call. This prevents issues with switching screens mid-frame.
- **ExitProc**: `CleanupOnExit` is automatically installed by `Start` to ensure cleanup on abnormal exit (Ctrl+C, Runtime Error).
- **DeltaTime convention**: Real (seconds), calculated as `CurrentTime - LastTime` via `GetTimeSeconds`.
- **Exit shortcut**: `Alt+Q` stops the game (Mortal Kombat style). TODO: Make this optional.
- **Sound card checks**: Music functions exit early if `Config.SoundCard = SoundCard_None` to avoid unnecessary work.
- **Screen lifecycle**: Screens are created by the program, registered with `AddScreen`, and switched with `SetNextScreen`. The game owns and frees all screens in `Done`.
- **Framebuffer usage**:
  - `BackgroundBuffer`: Static content (cleared once, never redrawn)
  - `BackBuffer`: Working buffer for compositing
  - `ScreenBuffer`: VGA hardware buffer (pointer, don't free)

## Future Enhancements

- **TResourceManager**: Load music/sound/graphics by name from RES.XML
- **Screen transitions**: Fade in/out, wipes, etc.
- **Screen stack**: Push/pop screens for pause menus, dialogs
- **Fixed timestep**: Decouple update rate from render rate for deterministic physics
