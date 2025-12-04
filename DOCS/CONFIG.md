# CONFIG - Configuration Management

Loads/saves CONFIG.INI for sound card settings.

## Types

```pascal
const
  SoundCard_None = 0;
  SoundCard_Adlib = 1;
  SoundCard_SoundBlaster = 2;

const
  SoundCardNames: array[0..2] of string = (
    'None',
    'AdLib',
    'Sound Blaster'
  );

const
  GameTitle = 'My Game';
  GameVersion = '1.0';
  TileSize = 16;

type
  TConfig = record
    SoundCard: Byte;
    SBPort: Byte;    { 2=$220, 4=$240, 6=$260, 8=$280 }
    SBIRQ: Byte;     { 5 or 7 }
    SBDMA: Byte;     { 0-3 }
    UseMouse: Boolean;
  end;
```

## Functions

```pascal
procedure LoadConfig(var Config: TConfig; const FileName: string);
procedure SaveConfig(const Config: TConfig; const FileName: string);
```

## Example

```pascal
uses Config, SBDSP, PlayHSC;

var
  Cfg: TConfig;
begin
  LoadConfig(Cfg, 'CONFIG.INI');

  if Cfg.SoundCard = SoundCard_SoundBlaster then
    ResetDSP(Cfg.SBPort, Cfg.SBIRQ, Cfg.SBDMA, 0);

  if Cfg.SoundCard >= SoundCard_Adlib then
  begin
    HSC_obj.Init(0);
    HSC_obj.LoadFile('MUSIC.HSC');
  end;
end;
```

## CONFIG.INI Format

```ini
SoundCard=2
SBPort=2
SBIRQ=5
SBDMA=1
UseMouse=1
```

## Notes

- Created by SETUP utility
- GAMEUNIT auto-loads CONFIG.INI on Init
- Default values: SoundCard=None, SBPort=2, SBIRQ=5, SBDMA=1, UseMouse=True
