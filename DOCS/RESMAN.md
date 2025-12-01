# RESMAN.PAS - Resource Manager

Centralized resource management system for loading and accessing game assets from XML definition files.

## Overview

**Purpose:** Load, cache, and provide named access to all game resources (images, sprites, fonts, sounds, music, palettes) from a single XML manifest file.

**Benefits:**
- Declarative resource definitions (XML instead of code)
- Centralized asset management (one place to see all resources)
- Name-based lookup (no hardcoded paths in game code)
- Automatic dependency resolution (sprites → images)
- Lazy or eager loading strategies
- XML-relative file paths (portable resource folders)
- Proper cleanup on shutdown

## XML Format

**File paths are relative to the XML file location.** If `RES.XML` is in `DATA\`, then `path="TEST.PCX"` loads `DATA\TEST.PCX`.

```xml
<?xml version="1.0" encoding="US-ASCII"?>
<resources>
  <!-- Music (HSC files) -->
  <music name="fantasy" path="FANTASY.HSC" />

  <!-- Sounds (VOC files) -->
  <sound name="explode" path="EXPLODE.VOC" />

  <!-- Images with palette extraction -->
  <image name="test" path="TEST.PCX" palette="test" />
  <image name="player" path="PLAYER.PCX" palette="player" />

  <!-- Standalone palette files -->
  <palette name="default" path="DEFAULT.PAL" />

  <!-- Fonts (XML files) -->
  <font name="small" path="FONT-SM.XML" />
  <font name="large" path="FONT-LG.XML" />

  <!-- Sprites (reference images by name) -->
  <sprite name="player_idle" image="player" duration="0.8">
    <frame x="0" y="0" width="32" height="32" />
    <frame x="32" y="0" width="32" height="32" />
    <frame x="64" y="0" width="32" height="32" />
    <frame x="96" y="0" width="32" height="32" />
  </sprite>

  <sprite name="player_run" image="player" duration="0.5">
    <frame x="0" y="32" width="32" height="32" />
    <frame x="32" y="32" width="32" height="32" />
    <frame x="64" y="32" width="32" height="32" />
    <frame x="96" y="32" width="32" height="32" />
    <frame x="128" y="32" width="32" height="32" />
    <frame x="160" y="32" width="32" height="32" />
  </sprite>
</resources>
```

### XML Attributes

**All resources:**
- `name` - Required. Unique identifier for lookup

**Music, sound, image, font, palette:**
- `path` - Required. File path relative to XML location

**Image:**
- `palette="name"` - Optional. Extract palette from PCX and store as named palette resource

**Palette:**
- `path` - Required. Standalone .PAL file (256 colors, RGB 0-63 format)

**Sprite:**
- `image` - Required. Name of image resource
- `duration` - Required. Animation duration in seconds

**Frame:**
- `x`, `y`, `width`, `height` - Required. Rectangle in sprite sheet

### Palette Handling

**Two types of palette resources:**

1. **Standalone palette files:**
   ```xml
   <palette name="default" path="DEFAULT.PAL" />
   ```
   Loads a 256-color .PAL file (RGB values 0-63).

2. **Image-extracted palettes:**
   ```xml
   <image name="player" path="PLAYER.PCX" palette="player" />
   ```
   Extracts palette from PCX file and stores as named resource "player".

**Usage:**
```pascal
{ Get extracted palette from image }
Pal := ResMgr.GetPalette('player');  { Palette extracted during image load }
if Pal <> nil then
  SetPalette(Pal^);

{ Or get standalone palette }
DefaultPal := ResMgr.GetPalette('default');
```

**Note:** Palettes are automatically applied via `SetPalette` when images with `palette` attribute are loaded.

### XML-Relative Paths

All resource paths are relative to the XML file's directory:

```
DATA\
  RES.XML           <-- LoadFromXML('DATA\RES.XML')
  TEST.PCX          <-- path="TEST.PCX" loads DATA\TEST.PCX
  PLAYER.PCX        <-- path="PLAYER.PCX" loads DATA\PLAYER.PCX
  FONT-SM.XML
```

This makes resource folders portable - move `DATA\` and everything works.

## Data Structures

### Resource Types

```pascal
type
  TResourceType = (
    ResType_Music,    { HSC music files }
    ResType_Sound,    { VOC sound files (via TSoundBank) }
    ResType_Image,    { PCX images }
    ResType_Font,     { Variable-width fonts }
    ResType_Sprite,   { Sprite definitions }
    ResType_Palette   { Palette resources (.PAL or extracted from PCX) }
  );
```

### Type-Specific Data

```pascal
type
  { Palette resource data }
  PPaletteData = ^TPaletteData;
  TPaletteData = record
    Palette: TPalette;  { 256 colors, RGB 0-63 }
  end;

  { Image resource data }
  PImageData = ^TImageData;
  TImageData = record
    Image: TImage;
    PaletteName: PShortString;  { Name of extracted palette, or nil }
  end;

  { Font, sprite, sound, music data... }
```

### Resource Descriptor

```pascal
type
  PResourceDescriptor = ^TResourceDescriptor;
  TResourceDescriptor = record
    Name: PShortString;
    ResType: TResourceType;
    Path: PShortString;
    Loaded: Boolean;
    Data: Pointer;
    PaletteName: PShortString;  { For images: name of extracted palette }
  end;
```

### Resource Manager

```pascal
type
  TResourceManager = object
    { Resource storage }
    MusicMap: TStringMap;
    SoundMap: TStringMap;
    ImageMap: TStringMap;
    FontMap: TStringMap;
    SpriteMap: TStringMap;
    PaletteMap: TStringMap;   { name → PPaletteData }

    { XML base path for relative file loading }
    BasePath: String;

    { Sound bank and singleton music }
    SoundBank: TSoundBank;
    SoundBankInitialized: Boolean;
    CurrentMusic: PMusicData;
    CurrentMusicName: PShortString;

    { Loading strategy and error tracking }
    LazyLoad: Boolean;
    LastError: String;
    Descriptors: TLinkedList;

    { Public methods }
    procedure Init(UseLazyLoading: Boolean);
    function LoadFromXML(const Filename: String): Boolean;

    { Resource access }
    function GetImage(const Name: String): PImage;
    function GetFont(const Name: String): PFont;
    function GetSprite(const Name: String): PSprite;
    function GetSound(const Name: String): Integer;
    function GetMusic(const Name: String): PHSC_Obj;
    function GetPalette(const Name: String): PPalette;

    { Cleanup }
    procedure Done;
  end;
```

## Usage Example

```pascal
program MyGame;

uses VGA, ResMan, Sprite, Keyboard, RTCTimer;

var
  ResMgr: TResourceManager;
  PlayerSprite: PSprite;
  PlayerPalette: PPalette;
  Player: TSpriteInstance;
  BackBuffer: PFrameBuffer;

begin
  { Initialize resource manager with lazy loading }
  ResMgr.Init(True);
  if not ResMgr.LoadFromXML('DATA\RES.XML') then
  begin
    WriteLn('ERROR: ', ResMgr.LastError);
    Halt(1);
  end;

  { Load sprite (automatically loads parent image + extracts palette) }
  PlayerSprite := ResMgr.GetSprite('player_idle');
  if PlayerSprite = nil then
  begin
    WriteLn('ERROR: ', ResMgr.LastError);
    Halt(1);
  end;

  { Get extracted palette and apply it }
  PlayerPalette := ResMgr.GetPalette('player');
  if PlayerPalette <> nil then
    SetPalette(PlayerPalette^);

  { Setup sprite instance }
  Player.Sprite := PlayerSprite;
  Player.X := 144;
  Player.Y := 84;
  Player.CurrentTime := 0.0;

  { Initialize VGA and render }
  InitVGA;
  BackBuffer := CreateFrameBuffer;

  { Game loop... }
  DrawSprite(Player, BackBuffer);
  RenderFrameBuffer(BackBuffer);

  { Cleanup }
  FreeFrameBuffer(BackBuffer);
  CloseVGA;
  ResMgr.Done;  { Frees all resources }
end.
```

## Important Notes

### Music Cleanup

**CRITICAL:** Games using music should NOT call `Music^.Done` manually. Let `ResMgr.Done` handle cleanup:

```pascal
{ CleanupOnExit (for interrupt unhooking) }
if Music <> nil then
  Music^.Stop;  { Stop playback only, don't call Done }

{ Later... }
ResMgr.Done;  { This calls Music^.Done }
```

Calling `Music^.Done` manually and then `ResMgr.Done` causes double-cleanup (Runtime Error 204).

### Music Singleton Pattern

Only one music track loads at a time. Loading a new track auto-unloads the previous one:

```pascal
TitleMusic := ResMgr.GetMusic('title');
TitleMusic^.Start;

{ Later - title music auto-unloaded }
GameMusic := ResMgr.GetMusic('level1');
GameMusic^.Start;

{ TitleMusic pointer now invalid! }
```

### Palette Workflow

1. **Define palette in XML:**
   - Standalone: `<palette name="x" path="X.PAL" />`
   - Extracted: `<image name="y" path="Y.PCX" palette="z" />`

2. **Load image:** Palette is automatically extracted and applied
3. **Get palette:** `Pal := ResMgr.GetPalette('z')`
4. **Apply later:** `SetPalette(Pal^)` when switching screens

## Performance

### Memory Usage

- **Lazy loading:** Lower initial memory, load on first access
- **Eager loading:** All resources preloaded, higher startup time

**Recommendation:** Use lazy loading (`Init(True)`) with explicit preloading:
```pascal
ResMgr.LoadResource('player_idle');
ResMgr.LoadResource('level1_bg');
```

### Lookup Performance

- String maps use 256-bucket hash: O(1) average lookup
- Lazy loading searches descriptor list: O(N) on first access, then O(1)

## Dependencies

**Required Units:**
- MINIXML (XML parsing)
- STRMAP (string → pointer hash map)
- LINKLIST (descriptor storage)
- PCX (image loading and saving)
- VGAFONT (variable-width fonts)
- SPRITE (sprite system)
- SNDBANK (XMS sound bank)
- PLAYHSC (HSC music)
- STRUTIL (string utilities)
- VGA (palette management)

## Error Handling

All `GetXXX` methods return `nil` on failure and set `LastError`:

```pascal
Img := ResMgr.GetImage('invalid');
if Img = nil then
  WriteLn('Error: ', ResMgr.LastError);
```

Common errors:
- `"Resource not found: name"` - Name not in XML
- `"Failed to load image \"name\" from: path"` - File missing or corrupt
- `"Sprite \"name\" references unknown image: img"` - Missing dependency
- `"Failed to load palette \"name\" from: path"` - Invalid .PAL file

## Summary

TResourceManager provides:
- ✅ Declarative XML resource definitions
- ✅ Name-based access (no hardcoded paths)
- ✅ Automatic dependency resolution (sprites → images)
- ✅ Palette extraction and management
- ✅ XML-relative file paths (portable resource folders)
- ✅ Lazy or eager loading strategies
- ✅ Singleton music management
- ✅ Centralized cleanup
- ✅ Type-safe accessors with error tracking

**See also:** SPRTEST.PAS, FNTTEST.PAS, IMGTEST.PAS for complete examples
