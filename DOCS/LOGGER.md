# LOGGER - Debug Logger

File-based debug logging system.

## Constants

```pascal
const
  LogLevelError = 0;
  LogLevelWarning = 1;
  LogLevelInfo = 2;
  LogLevelDebug = 3;
```

## Functions

```pascal
procedure InitLogger(const FilePath: string; Level: Byte);
procedure CloseLogger;
procedure LogError(const Msg: string);
procedure LogWarning(const Msg: string);
procedure LogInfo(const Msg: string);
procedure LogDebug(const Msg: string);
```

## Example

```pascal
uses Logger;

begin
  InitLogger('DEBUG.LOG', LogLevelDebug);

  LogInfo('Application started');
  LogDebug('Loading config...');

  if Error then
    LogError('Failed to load CONFIG.INI');

  CloseLogger;
end;
```

## Log Format

```
[INFO] Application started
[DEBUG] Loading config...
[ERROR] Failed to load CONFIG.INI
```

## Critical Warning

⚠️ **DO NOT use in render loops!**

File I/O causes **Runtime Error 202** (stack overflow) at 60 FPS.

```pascal
{ BAD - Stack overflow! }
while Running do
begin
  LogDebug('Frame rendered');  { ❌ File I/O every frame }
  RenderFrame;
end;

{ GOOD - Startup/shutdown only }
InitLogger('DEBUG.LOG', LogLevelInfo);
LogInfo('Game started');        { ✅ Once at startup }
{ ... game loop ... }
LogInfo('Game exiting');         { ✅ Once at shutdown }
CloseLogger;
```

## Notes

- Level filter: Only logs messages >= specified level
- LogLevelError (0) = errors only
- LogLevelDebug (3) = all messages
- Use for startup/shutdown diagnostics only
