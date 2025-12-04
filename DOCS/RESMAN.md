# RESMAN - Resource Manager

Centralized resource loading from XML manifest.

## XML Format

```xml
<?xml version="1.0" encoding="US-ASCII"?>
<resources>
  <music name="theme" path="THEME.HSC" />
  <sound name="explode" path="EXPLODE.VOC" />
  <image name="player" path="PLAYER.PCX" palette="player" />
  <palette name="default" path="DEFAULT.PAL" />
  <font name="small" path="FONT-SM.XML" />

  <sprite name="player_run" image="player" duration="0.6">
    <frame x="0" y="0" width="32" height="32" />
    <frame x="32" y="0" width="32" height="32" />
    <frame x="64" y="0" width="32" height="32" />
  </sprite>
</resources>
```

**Paths are relative to XML location.** If `RES.XML` is in `DATA\`, then `path="TEST.PCX"` loads `DATA\TEST.PCX`.

## Types

```pascal
type
  TResourceType = (ResType_Music, ResType_Sound, ResType_Image,
                   ResType_Font, ResType_Sprite, ResType_Palette);

  TResourceManager = object
    procedure Init(UseLazyLoading: Boolean);
    function LoadFromXML(const Filename: String): Boolean;

    { Resource access }
    function GetImage(const Name: String): PImage;
    function GetFont(const Name: String): PFont;
    function GetSprite(const Name: String): PSprite;
    function GetSound(const Name: String): Integer;  { Returns sound ID }
    function GetMusic(const Name: String): PHSC_Obj;
    function GetPalette(const Name: String): PPalette;

    { Manual resource management }
    function LoadResource(const Name: String): Boolean;
    procedure UnloadResource(const Name: String);  { Free individual resource }

    procedure Done;
  end;
```

## Example

```pascal
uses ResMan, VGA, Sprite;

var
  ResMgr: TResourceManager;
  PlayerSprite: PSprite;
  PlayerPalette: PPalette;
  Player: TSpriteInstance;

begin
  { Initialize with lazy loading }
  ResMgr.Init(True);
  if not ResMgr.LoadFromXML('DATA\RES.XML') then
  begin
    WriteLn('ERROR: ', ResMgr.LastError);
    Halt(1);
  end;

  { Get resources (auto-loads on first access) }
  PlayerSprite := ResMgr.GetSprite('player_run');
  if PlayerSprite = nil then
  begin
    WriteLn('ERROR: ', ResMgr.LastError);
    Halt(1);
  end;

  { Get extracted palette }
  PlayerPalette := ResMgr.GetPalette('player');
  if PlayerPalette <> nil then
    SetPalette(PlayerPalette^);

  { Setup sprite instance }
  Player.Sprite := PlayerSprite;
  Player.X := 100;
  Player.Y := 50;
  Player.CurrentTime := 0.0;

  { Game loop... }
  UpdateSprite(Player, DeltaTime);
  DrawSprite(Player, BackBuffer);

  { Cleanup }
  ResMgr.Done;  { Frees all resources }
end.
```

## Palettes

**Two types:**

1. **Standalone palette:**
   ```xml
   <palette name="default" path="DEFAULT.PAL" />
   ```

2. **Image-extracted palette:**
   ```xml
   <image name="player" path="PLAYER.PCX" palette="player" />
   ```

**Usage:**
```pascal
{ Get extracted palette }
Pal := ResMgr.GetPalette('player');
if Pal <> nil then
  SetPalette(Pal^);
```

## Music Singleton

Only one music track loads at a time:

```pascal
{ Load title music }
TitleMusic := ResMgr.GetMusic('title');
TitleMusic^.Start;

{ Load level music (title auto-unloaded) }
GameMusic := ResMgr.GetMusic('level1');
GameMusic^.Start;
{ TitleMusic pointer now invalid! }
```

## Manual Resource Unloading

Free individual resources when no longer needed:

```pascal
{ Load level assets }
BgImage := ResMgr.GetImage('level1_bg');
EnemySprite := ResMgr.GetSprite('enemy1');

{ Use them... }

{ Switch to next level - free old assets }
ResMgr.UnloadResource('level1_bg');
ResMgr.UnloadResource('enemy1');

{ Load new level assets }
BgImage := ResMgr.GetImage('level2_bg');
EnemySprite := ResMgr.GetSprite('enemy2');
```

**Supported:**
- Images, fonts, sprites, palettes, music

**Not supported:**
- Sounds (managed by SoundBank as a group)

**Behavior:**
- Frees memory immediately
- Marks resource as unloaded (can be re-loaded via lazy loading)
- Invalidates all pointers to that resource

⚠️ **Warning:** After unloading, any existing pointers become invalid!

```pascal
Img := ResMgr.GetImage('player');
ResMgr.UnloadResource('player');
PutImage(0, 0, Img, FB);  { ❌ CRASH - pointer invalid! }
```

## Critical Notes

1. **XML-relative paths** - All paths relative to XML file location
2. **Lazy vs eager loading** - `Init(True)` for lazy, `Init(False)` for eager
3. **Music cleanup** - Don't call `Music^.Done` manually, let `ResMgr.Done` handle it
4. **Dependency resolution** - Sprites auto-load parent images
5. **Error handling** - Check `ResMgr.LastError` when `GetXXX` returns nil

## Error Handling

```pascal
Img := ResMgr.GetImage('invalid');
if Img = nil then
  WriteLn('Error: ', ResMgr.LastError);
```

Common errors:
- `"Resource not found: name"` - Name not in XML
- `"Failed to load image"` - File missing or corrupt
- `"Sprite references unknown image"` - Missing dependency

## Benefits

- Declarative resource definitions (XML, not code)
- Name-based lookup (no hardcoded paths)
- Automatic dependency resolution
- Palette extraction and management
- Centralized cleanup

## Dependencies

- MINIXML (XML parsing)
- STRMAP (name lookup)
- PCX, VGAFONT, SPRITE, SNDBANK, PLAYHSC
