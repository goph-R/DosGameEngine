{ CONFIG.PAS - Configuration management }
{ Handles loading/saving settings to CONFIG.INI }

unit Config;

interface

const
  GameTitle = 'Game Title';
  GameVersion = '1.0.0';

  TileSize = 16;

  SoundCard_None = 0;
  SoundCard_Adlib = 1;
  SoundCard_SoundBlaster = 2;

  SoundCardNames: array[0..2] of string = (
    'None',
    'Adlib',
    'Sound Blaster'
  );    

  ConfigFile = 'CONFIG.INI';

type
  TConfig = record
    SoundCard: Byte;     { 0=None, 1=Adlib, 2=SoundBlaster }
    SBPort: Word;        { SoundBlaster base (1=$210, 2=$220, 3=$230, 4=$240) }
    SBIRQ: Byte;         { SoundBlaster IRQ (e.g., 5) }
    SBDMA: Byte;         { SoundBlaster DMA (e.g., 1) }
  end;

{ Load configuration from CONFIG.INI file }
{ Sets defaults if file doesn't exist }
procedure LoadConfig(var Config: TConfig);

{ Save configuration to CONFIG.INI file }
procedure SaveConfig(const Config: TConfig);

implementation

uses Dos, StrUtil;

{ Load config from INI file }
procedure LoadConfig(var Config: TConfig);
var
  F: Text;
  Line, Key, Value: string;
  EqualPos: Integer;
begin
  { Defaults }
  Config.SoundCard := SoundCard_None;
  Config.SBPort := 2;  { Base value 2 = port $220 (most common) }
  Config.SBIRQ := 5;
  Config.SBDMA := 1;

  { Try to load existing config }
  Assign(F, ConfigFile);
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

        { Parse known keys }
        if Key = 'SoundCard' then
          Config.SoundCard := StrToInt(Value)
        else if Key = 'SBPort' then
          Config.SBPort := StrToInt(Value)
        else if Key = 'SBIRQ' then
          Config.SBIRQ := StrToInt(Value)
        else if Key = 'SBDMA' then
          Config.SBDMA := StrToInt(Value);
      end;
    end;
    Close(F);
  end;
end;

{ Save config to INI file }
procedure SaveConfig(const Config: TConfig);
var
  F: Text;
begin
  Assign(F, ConfigFile);
  {$I-}
  Rewrite(F);
  {$I+}
  if IOResult = 0 then
  begin
    WriteLn(F, '; DOS Game Engine Configuration');
    WriteLn(F, '');
    WriteLn(F, '[Sound]');
    WriteLn(F, 'SoundCard=', Config.SoundCard);
    WriteLn(F, 'SBPort=', Config.SBPort);
    WriteLn(F, 'SBIRQ=', Config.SBIRQ);
    WriteLn(F, 'SBDMA=', Config.SBDMA);
    Close(F);
  end;
end;

end.
