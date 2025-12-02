# Game Engine Core Architecture

Central game loop framework with screen management, resource loading, and subsystem initialization.

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

    { Update current screen }
    Update(DeltaTime);

    { Render }
    CopyFrameBuffer(BackgroundBuffer, BackBuffer);  { Start with background }
    if Screen <> nil then
      Screen^.Render(BackBuffer);  { Screen draws to BackBuffer }
    RenderFrameBuffer(BackBuffer);  { Blit to VGA }

    { Handle exit }
    if IsKeyPressed(Key_Escape) then
      Running := False;

    ClearKeyPressed;
  end;
end;
```

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
procedure SetScreen(Name: String);
```

Switch to a different screen:

1. Look up screen in `ScreenMap` by name
2. If current `Screen <> nil`: call `Screen^.Hide`
3. Set `Screen := NewScreen`
4. If new `Screen <> nil`: call `Screen^.Show`

```pascal
procedure AddScreen(Name: String; Screen: PScreen);
```

Register a screen in the screen map: `ScreenMap.Put(Name, Screen)`

```pascal
procedure Update(DeltaTime: Real); virtual;
```

**Virtual method** - can be overridden in derived game objects.

Default implementation:
- If `Screen <> nil`: call `Screen^.Update(DeltaTime)`

### Properties

```pascal
type
  PGame = ^TGame;
  TGame = object
    { Configuration & Resources }
    Config: TConfig;              { Game configuration (see CONFIG.PAS) }
    ResMan: TResourceManager;     { Resource manager (see RESMAN.PAS) }

    { Timing }
    CurrentTime: Real;            { Current time in seconds (from GetTimeSeconds) }
    LastTime: Real;               { Previous frame time in seconds }
    DeltaTime: Real;              { Time elapsed since last frame (seconds) }

    { State }
    Running: Boolean;             { Main loop control flag }

    { Screen Management }
    Screen: PScreen;              { Current active screen }
    ScreenMap: TStringMap;        { Name -> PScreen mapping }

    { Framebuffers }
    BackgroundBuffer: PFrameBuffer;  { Static background (cleared once) }
    BackBuffer: PFrameBuffer;        { Working render buffer }
    ScreenBuffer: PFrameBuffer;      { VGA display buffer (from GetScreenBuffer) }
  end;
```

## TScreen Object

**Unit:** `GameUnit` (or separate `ScreenUnit`)

Abstract screen/state object for menu screens, gameplay, etc.

### Constructor

```pascal
constructor Init(Game: PGame);
```

- `Game`: Pointer to parent TGame instance (for accessing config, buffers, etc.)

### Methods

```pascal
destructor Done;
```

Cleanup screen resources.

```pascal
procedure Update(DeltaTime: Real);
```

Per-frame update logic (game-specific, typically overridden).

```pascal
procedure Show;
```

Called when screen becomes active:
- Initialize screen-specific resources
- Load screen assets
- Reset screen state

```pascal
procedure Hide;
```

Called when screen becomes inactive:
- Save screen state if needed
- Pause screen-specific timers
- Optionally free screen assets

### Properties

```pascal
type
  PScreen = ^TScreen;
  TScreen = object
    Game: PGame;  { Pointer to parent game instance }
  end;
```

## Usage Example

```pascal
program MyGame;

uses
  GameUnit, Config;

type
  PMenuScreen = ^TMenuScreen;
  TMenuScreen = object(TScreen)
    procedure Update(DeltaTime: Real);
    procedure Show;
    procedure Hide;
  end;

var
  Game: TGame;
  MenuScreen: PMenuScreen;

procedure TMenuScreen.Update(DeltaTime: Real);
begin
  { Handle menu input }
  if IsKeyPressed(Key_Enter) then
    Game^.SetScreen('gameplay');
end;

procedure TMenuScreen.Show;
begin
  { Load menu assets, show cursor, etc. }
end;

procedure TMenuScreen.Hide;
begin
  { Hide cursor, etc. }
end;

begin
  { Initialize game }
  Game.Init('CONFIG.INI', 'DATA\RES.XML');

  { Create and register screens }
  New(MenuScreen, Init(@Game));
  Game.AddScreen('menu', MenuScreen);

  { Start and run }
  Game.Start;
  Game.SetScreen('menu');
  Game.Run;

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

- **Virtual methods**: Only `Update` is virtual. Screens override `Update`, `Show`, `Hide` as needed.
- **ExitProc**: `CleanupOnExit` must be installed with Turbo Pascal's `ExitProc` mechanism to ensure cleanup on abnormal exit.
- **DeltaTime convention**: Real (seconds), calculated as `CurrentTime - LastTime` via `GetTimeSeconds`.
- **Sound card checks**: Music functions exit early if `Config.SoundCard = SoundCard_None` to avoid unnecessary work.
- **Screen lifecycle**: Screens are created by the game, registered with `AddScreen`, and switched with `SetScreen`. The game owns and frees all screens in `Done`.
- **Framebuffer usage**:
  - `BackgroundBuffer`: Static content (cleared once, never redrawn)
  - `BackBuffer`: Composed frame (background + dynamic content)
  - `ScreenBuffer`: VGA hardware buffer (blit target)

## Future Enhancements

- **TResourceManager**: Load music/sound/graphics by name from RES.XML
- **Screen transitions**: Fade in/out, wipes, etc.
- **Screen stack**: Push/pop screens for pause menus, dialogs
- **Fixed timestep**: Decouple update rate from render rate for deterministic physics
