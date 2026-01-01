{ CONFIG.PAS - Configuration management }
{ Handles loading/saving settings to CONFIG.INI }

unit Config;

{$F+}  { Enable far calls for virtual methods }

interface

const
  GameTitle = 'Game Title';
  GameVersion = '1.0.0';

  TileSize = 16;

  SoundCard_None = 0;
  SoundCard_AdLib = 1;
  SoundCard_SoundBlaster = 2;

  SoundCardNames: array[0..2] of string = (
    'None',
    'AdLib',
    'Sound Blaster'
  );

type
  PConfig = ^TConfig;

  TConfig = object
    { Configuration file path }
    Path: String;

    { Core engine settings }
    SoundCard: Byte;     { 0=None, 1=AdLib, 2=SoundBlaster }
    SBPort: Word;        { SoundBlaster base (2=$220, 4=$240, 6=$260, 8=$280) }
    SBIRQ: Byte;         { SoundBlaster IRQ (e.g., 5 or 7) }
    SBDMA: Byte;         { SoundBlaster DMA (1, 2, 3, or 4) }
    UseMouse: Byte;      { 0=No, 1=Yes }

    constructor Init(const ConfigIniPath: String);
    destructor Done; virtual;
    procedure Load; virtual;
    procedure Save; virtual;
    procedure SetDefaults; virtual;
    procedure ParseKeyValue(const Key, Value: String); virtual;
    procedure WriteSettings(var F: Text); virtual;
  end;

{ Load configuration from file }
{ Sets defaults if file doesn't exist }
procedure LoadConfig(var Config: TConfig; const ConfigFile: String);

{ Save configuration to file }
procedure SaveConfig(var Config: TConfig; const ConfigFile: String);

implementation

uses Dos, StrUtil;

{ TConfig - Object implementation }

constructor TConfig.Init(const ConfigIniPath: String);
begin
  Path := ConfigIniPath;
  SetDefaults;
end;

destructor TConfig.Done;
begin
  { Base implementation - override in derived configs if needed }
end;

procedure TConfig.SetDefaults;
begin
  SoundCard := SoundCard_None;
  SBPort := 2;  { Base value 2 = port $220 (most common) }
  SBIRQ := 5;
  SBDMA := 1;
  UseMouse := 0;  { Mouse disabled by default }
end;

procedure TConfig.ParseKeyValue(const Key, Value: String);
begin
  if Key = 'SoundCard' then
    SoundCard := StrToInt(Value)
  else if Key = 'SBPort' then
    SBPort := StrToInt(Value)
  else if Key = 'SBIRQ' then
    SBIRQ := StrToInt(Value)
  else if Key = 'SBDMA' then
    SBDMA := StrToInt(Value)
  else if Key = 'UseMouse' then
    UseMouse := StrToInt(Value);
  { Derived classes can override to handle additional keys }
end;

procedure TConfig.Load;
var
  F: Text;
  Line, Key, Value: string;
  EqualPos: Integer;
begin
  { Set defaults first }
  SetDefaults;

  { Try to load existing config }
  Assign(F, Path);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult = 0 then
  begin
    while not Eof(F) do
    begin
      ReadLn(F, Line);
      Line := Trim(Line);

      { Skip empty lines, comments, and section headers }
      if (Length(Line) = 0) or (Line[1] = ';') or (Line[1] = '[') then
        Continue;

      { Parse key=value }
      EqualPos := Pos('=', Line);
      if EqualPos > 0 then
      begin
        Key := Trim(Copy(Line, 1, EqualPos - 1));
        Value := Trim(Copy(Line, EqualPos + 1, Length(Line)));

        { Call virtual method for parsing }
        ParseKeyValue(Key, Value);
      end;
    end;
    Close(F);
  end;
end;

procedure TConfig.WriteSettings(var F: Text);
begin
  WriteLn(F, '[Sound]');
  WriteLn(F, 'SoundCard=', SoundCard);
  WriteLn(F, 'SBPort=', SBPort);
  WriteLn(F, 'SBIRQ=', SBIRQ);
  WriteLn(F, 'SBDMA=', SBDMA);
  WriteLn(F, '');
  WriteLn(F, '[Input]');
  WriteLn(F, 'UseMouse=', UseMouse);
  { Derived classes can override to write additional settings }
end;

procedure TConfig.Save;
var
  F: Text;
begin
  Assign(F, Path);
  {$I-}
  Rewrite(F);
  {$I+}
  if IOResult = 0 then
  begin
    WriteLn(F, '; DOS Game Engine Configuration');
    WriteLn(F, '');
    WriteSettings(F);
    Close(F);
  end;
end;

{ Backward-compatible standalone procedures }

procedure LoadConfig(var Config: TConfig; const ConfigFile: String);
begin
  { For backward compatibility, initialize if needed, then load }
  Config.Init(ConfigFile);
  Config.Load;
end;

procedure SaveConfig(var Config: TConfig; const ConfigFile: String);
var
  OldPath: String;
begin
  { Save current path, temporarily change it, save, restore }
  OldPath := Config.Path;
  Config.Path := ConfigFile;
  Config.Save;
  Config.Path := OldPath;
end;

end.
