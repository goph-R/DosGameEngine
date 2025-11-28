{ ========================================================================== }
{ LOGGER.PAS - Simple File Logger                                           }
{                                                                            }
{ Provides simple file-based logging with log levels.                       }
{ ========================================================================== }

unit Logger;

interface

const
  LogLevelError = 0;
  LogLevelWarning = 1;
  LogLevelInfo = 2;
  LogLevelDebug = 3;

procedure InitLogger(const Path: string; Level: Byte);
procedure CloseLogger;
procedure LogError(const Msg: string);
procedure LogWarning(const Msg: string);
procedure LogInfo(const Msg: string);
procedure LogDebug(const Msg: string);

implementation

var
  LogFilePath: string;
  LogLevel: Byte;
  LogInitialized: Boolean;

{ ========================================================================== }
{ Private Helper Functions                                                   }
{ ========================================================================== }

procedure LogToFile(const LevelStr, Msg: string; MsgLevel: Byte);
var
  F: Text;
  FileExists: Boolean;
begin
  { Only log if initialized and message level is <= current log level }
  if not LogInitialized then Exit;
  if MsgLevel > LogLevel then Exit;

  { Check if file exists }
  Assign(F, LogFilePath);
  {$I-}
  Reset(F);
  FileExists := (IOResult = 0);
  if FileExists then
    Close(F);
  {$I+}

  { Append or create file }
  {$I-}
  if FileExists then
    Append(F)
  else
    Rewrite(F);

  if IOResult <> 0 then
  begin
    { Failed to open file - silently ignore }
    Exit;
  end;

  { Write log line }
  WriteLn(F, '[', LevelStr, '] ', Msg);
  Close(F);
  {$I+}
end;

{ ========================================================================== }
{ Public Interface                                                           }
{ ========================================================================== }

procedure InitLogger(const Path: string; Level: Byte);
begin
  LogFilePath := Path;
  LogLevel := Level;
  LogInitialized := True;

  { Write initialization message }
  LogToFile('INFO', 'Logger initialized', LogLevelInfo);
end;

procedure CloseLogger;
begin
  if LogInitialized then
  begin
    LogToFile('INFO', 'Logger closing', LogLevelInfo);
    LogInitialized := False;
  end;
end;

procedure LogError(const Msg: string);
begin
  LogToFile('ERROR', Msg, LogLevelError);
end;

procedure LogWarning(const Msg: string);
begin
  LogToFile('WARN', Msg, LogLevelWarning);
end;

procedure LogInfo(const Msg: string);
begin
  LogToFile('INFO', Msg, LogLevelInfo);
end;

procedure LogDebug(const Msg: string);
begin
  LogToFile('DEBUG', Msg, LogLevelDebug);
end;

begin
  LogInitialized := False;
end.
