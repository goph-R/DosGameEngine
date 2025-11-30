# RESMAN.PAS - Resource Manager Design

Centralized resource management system for loading and accessing game assets from XML definition files.

## Overview

**Purpose:** Load, cache, and provide named access to all game resources (images, sprites, fonts, sounds, music, levels) from a single XML manifest file.

**Benefits:**
- Declarative resource definitions (XML instead of code)
- Centralized asset management (one place to see all resources)
- Name-based lookup (no hardcoded paths in game code)
- Automatic dependency resolution (sprites → images)
- Lazy or eager loading strategies
- Proper cleanup on shutdown

## XML Format (RES.XML Example)

```xml
<?xml version="1.0" encoding="US-ASCII"?>
<resources>
  <music name="main" path="DATA\TEST.HSC" />
  <sound name="explode" path="DATA\EXPLODE.VOC" />
  <level name="first" path="DATA\TEST.TMX" />
  <image name="player" path="DATA\PLAYER.PCX" />
  <image name="background" path="DATA\BG1.PCX" use-palette />
  <font name="small" path="DATA\FONT-SM.XML" />

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

**Note on Image Resources:**
The `<image>` tag references a PCX file (e.g. `DATA\BG1.PCX`). If the `use-palette` attribute is present the `LoadPCXWithPalette` will be used, otherwise the `LoadPCX`.
 
**Note on Font Resources:**
The `<font>` tag references an XML file (e.g., `DATA\FONT-SM.XML`) which contains the font definition including the PCX image path. The font XML specifies the image path via an `image` attribute, which is relative to the XML file's location.

Example font XML structure (DATA\FONT-SM.XML):
```xml
<font height="8" padding="1" image="FONT-SM.PCX">
  <char code="32" x="0" y="0" width="4" />
  <char code="33" x="4" y="0" width="3" />
  <!-- ... -->
</font>
```

The `image` attribute path is relative to the XML file's directory. For example, if the font XML is at `DATA\FONT-SM.XML` and `image="FONT-SM.PCX"`, the actual image loaded will be `DATA\FONT-SM.PCX`.

## Data Structures

### Resource Types

```pascal
type
  TResourceType = (
    ResType_Music,    { HSC music files }
    ResType_Sound,    { VOC sound files (via TSoundBank) }
    ResType_Image,    { PCX images }
    ResType_Font,     { Variable-width fonts (TFont from VGAFONT) }
    ResType_Sprite,   { Sprite definitions (TSprite) }
    ResType_Level     { TMX tilemaps }
  );
```

### Base Resource Descriptor

```pascal
type
  PResourceDescriptor = ^TResourceDescriptor;
  TResourceDescriptor = record
    Name: PShortString;       { Resource name for lookup }
    ResType: TResourceType;   { Type of resource }
    Path: PShortString;       { File path (nil for sprites) }
    Loaded: Boolean;          { Is resource currently loaded? }
    Data: Pointer;            { Type-specific data pointer }
  end;
```

### Type-Specific Data

```pascal
type
  { Music resource data }
  PMusicData = ^TMusicData;
  TMusicData = record
    Music: HSC_Obj;           { PLAYHSC music object }
  end;

  { Sound resource data }
  PSoundData = ^TSoundData;
  TSoundData = record
    SoundID: Integer;         { TSoundBank sound ID }
  end;

  { Image resource data }
  PImageData = ^TImageData;
  TImageData = record
    Image: TImage;            { VGA.PAS image }
    UsePalette: Boolean;
  end;

  { Font resource data }
  PFontData = ^TFontData;
  TFontData = record
    Font: TFont;              { VGAFONT.PAS variable-width font }
  end;

  { Sprite resource data }
  PSpriteData = ^TSpriteData;
  TSpriteData = record
    Sprite: TSprite;          { SPRITE.PAS sprite definition }
    ImageName: PShortString;  { Reference to parent image resource }
    FrameCount: Byte;         { Number of frames }
  end;

  { Level resource data }
  PLevelData = ^TLevelData;
  TLevelData = record
    Map: PTileMap;            { TMXLOAD.PAS tilemap }
  end;
```

### Resource Manager

```pascal
type
  TResourceManager = object
    { Resource storage - separate maps for each type }
    MusicMap: TStringMap;     { name → PMusicData }
    SoundMap: TStringMap;     { name → PSoundData }
    ImageMap: TStringMap;     { name → PImageData }
    FontMap: TStringMap;      { name → PFontData }
    SpriteMap: TStringMap;    { name → PSpriteData }
    LevelMap: TStringMap;     { name → PLevelData }

    { Descriptors list (for cleanup) }
    Descriptors: PLinkedList; { TResourceDescriptor entries }

    { Sound bank (shared for all sounds) }
    SoundBank: TSoundBank;
    SoundBankInitialized: Boolean;

    { Loading strategy }
    LazyLoad: Boolean;        { True = load on first access, False = preload all }

    { Error tracking }
    LastError: String;

    { Methods }
    procedure Init(UseLazyLoading: Boolean);
    function LoadFromXML(const Filename: String): Boolean;

    { Resource access - lazy load if not loaded }
    function GetImage(const Name: String): PImage;
    function GetFont(const Name: String): PFont;
    function GetSprite(const Name: String): PSprite;
    function GetSound(const Name: String): Integer;  { Returns TSoundBank ID }
    function GetMusic(const Name: String): PHSC_Obj;
    function GetLevel(const Name: String): PTileMap;

    { Manual loading/unloading }
    function LoadResource(const Name: String): Boolean;
    procedure UnloadResource(const Name: String);
    procedure PreloadAll;

    { Cleanup }
    procedure Done;

    { Internal methods }
    private
      function ParseXML(RootNode: PXMLNode): Boolean;
      function LoadImageResource(Desc: PResourceDescriptor): Boolean;
      function LoadFontResource(Desc: PResourceDescriptor): Boolean;
      function LoadSpriteResource(Desc: PResourceDescriptor): Boolean;
      function LoadSoundResource(Desc: PResourceDescriptor): Boolean;
      function LoadMusicResource(Desc: PResourceDescriptor): Boolean;
      function LoadLevelResource(Desc: PResourceDescriptor): Boolean;
  end;
```

## Loading Strategy

### Two Approaches

**1. Eager Loading (Preload All)**
```pascal
ResMgr.Init(False);  { LazyLoad = False }
ResMgr.LoadFromXML('DATA\RES.XML');
{ All resources loaded immediately - longer startup, simpler access }
```

**2. Lazy Loading (Load on Demand)**
```pascal
ResMgr.Init(True);   { LazyLoad = True }
ResMgr.LoadFromXML('DATA\RES.XML');
{ Only XML parsed - resources loaded on first GetXXX call }
```

**Recommendation:** Use lazy loading by default, with explicit `PreloadAll` for loading screens.

## Implementation Details

### Init Procedure

```pascal
procedure TResourceManager.Init(UseLazyLoading: Boolean);
begin
  { Initialize string maps }
  MapInit(MusicMap);
  MapInit(SoundMap);
  MapInit(ImageMap);
  MapInit(FontMap);
  MapInit(SpriteMap);
  MapInit(LevelMap);

  { Initialize descriptor list }
  New(Descriptors);
  ListInit(Descriptors^);

  { Set loading strategy }
  LazyLoad := UseLazyLoading;

  { Sound bank not initialized yet }
  SoundBankInitialized := False;
  LastError := '';
end;
```

### LoadFromXML

```pascal
function TResourceManager.LoadFromXML(const Filename: String): Boolean;
var
  RootNode: PXMLNode;
begin
  LoadFromXML := False;

  if not XMLLoadFile(Filename, RootNode) then
  begin
    LastError := 'Failed to parse XML file';
    Exit;
  end;

  if not ParseXML(RootNode) then
  begin
    XMLFreeTree(RootNode);
    Exit;
  end;

  XMLFreeTree(RootNode);

  { If eager loading, preload all resources }
  if not LazyLoad then
    PreloadAll;

  LoadFromXML := True;
end;
```

### ParseXML (Resource Discovery)

```pascal
function TResourceManager.ParseXML(RootNode: PXMLNode): Boolean;
var
  Child: PXMLNode;
  Desc: PResourceDescriptor;
  TagName: String;
begin
  ParseXML := False;
  Child := XMLFirstChild(RootNode);

  while Child <> nil do
  begin
    TagName := Child^.Tag^;

    { Create descriptor based on tag type }
    New(Desc);
    FillChar(Desc^, SizeOf(TResourceDescriptor), 0);

    { Get name attribute (required for all resources) }
    if not XMLHasAttr(Child, 'name') then
    begin
      LastError := 'Resource missing name attribute';
      Dispose(Desc);
      Exit;
    end;

    New(Desc^.Name);
    Desc^.Name^ := XMLAttr(Child, 'name')^;
    Desc^.Loaded := False;

    { Parse by type }
    if TagName = 'music' then
    begin
      Desc^.ResType := ResType_Music;
      New(Desc^.Path);
      Desc^.Path^ := XMLAttr(Child, 'path')^;
      ListAdd(Descriptors^, Desc);
    end
    else if TagName = 'sound' then
    begin
      Desc^.ResType := ResType_Sound;
      New(Desc^.Path);
      Desc^.Path^ := XMLAttr(Child, 'path')^;
      ListAdd(Descriptors^, Desc);
    end
    else if TagName = 'image' then
    begin
      Desc^.ResType := ResType_Image;
      New(Desc^.Path);
      Desc^.Path^ := XMLAttr(Child, 'path')^;
      ListAdd(Descriptors^, Desc);
    end
    else if TagName = 'font' then
    begin
      Desc^.ResType := ResType_Font;
      New(Desc^.Path);
      Desc^.Path^ := XMLAttr(Child, 'path')^;  { Path to font XML file }
      ListAdd(Descriptors^, Desc);
    end
    else if TagName = 'sprite' then
    begin
      { Sprites are special - store XML node for lazy parsing }
      Desc^.ResType := ResType_Sprite;
      Desc^.Path := nil;  { No file path }
      Desc^.Data := Child;  { Store XML node temporarily }
      ListAdd(Descriptors^, Desc);
    end
    else if TagName = 'level' then
    begin
      Desc^.ResType := ResType_Level;
      New(Desc^.Path);
      Desc^.Path^ := XMLAttr(Child, 'path')^;
      ListAdd(Descriptors^, Desc);
    end
    else
      Dispose(Desc);  { Unknown tag }

    Child := XMLNextSibling(Child);
  end;

  ParseXML := True;
end;
```

### GetImage (Lazy Loading Example)

```pascal
function TResourceManager.GetImage(const Name: String): PImage;
var
  ImgData: PImageData;
  Desc: PResourceDescriptor;
  Node: PLinkedListNode;
begin
  GetImage := nil;

  { Check if already loaded }
  if MapContains(ImageMap, Name) then
  begin
    ImgData := PImageData(MapGet(ImageMap, Name));
    GetImage := @ImgData^.Image;
    Exit;
  end;

  { Lazy load if enabled }
  if LazyLoad then
  begin
    { Find descriptor }
    Node := Descriptors^.Head;
    while Node <> nil do
    begin
      Desc := PResourceDescriptor(Node^.Data);
      if (Desc^.ResType = ResType_Image) and (Desc^.Name^ = Name) then
      begin
        if LoadImageResource(Desc) then
        begin
          ImgData := PImageData(Desc^.Data);
          GetImage := @ImgData^.Image;
        end;
        Exit;
      end;
      Node := Node^.Next;
    end;
  end;

  LastError := 'Image not found: ' + Name;
end;
```

### LoadImageResource

```pascal
function TResourceManager.LoadImageResource(Desc: PResourceDescriptor): Boolean;
var
  ImgData: PImageData;
  LoadResult: Boolean;
  Palette: TPalette;
begin
  LoadImageResource := False;

  if Desc^.Loaded then
  begin
    LoadImageResource := True;
    Exit;
  end;

  { Allocate image data }
  New(ImgData);

  { Load PCX file }
  if ImageData^.UsePalette then
  begin
    { With palette }
    LoadResult := LoadPCXWithPalette(Desc^.Path^, ImgData^.Image, Palette);
    if LoadResult then
      SetPalette(Palette);
  end
  else
    { Without palette }
    LoadResult := LoadPCX(Desc^.Path^, ImgData^.Image);
  
  if not LoadResult then
  begin
    LastError := 'Failed to load image: ' + Desc^.Path^;
    Dispose(ImgData);
    Exit;
  end;

  { Store in map }
  MapPut(ImageMap, Desc^.Name^, ImgData);
  Desc^.Data := ImgData;
  Desc^.Loaded := True;

  LoadImageResource := True;
end;
```

### LoadFontResource

```pascal
function TResourceManager.LoadFontResource(Desc: PResourceDescriptor): Boolean;
var
  FontData: PFontData;
begin
  LoadFontResource := False;

  if Desc^.Loaded then
  begin
    LoadFontResource := True;
    Exit;
  end;

  { Allocate font data }
  New(FontData);

  { Load font from XML file }
  { NOTE: VGAFONT.PAS will be updated to support LoadFont(XMLPath, Font) }
  { where the XML file contains the PCX image path internally }
  if not LoadFont(Desc^.Path^, FontData^.Font) then
  begin
    LastError := 'Failed to load font: ' + Desc^.Path^ + ' - ' + GetLoadFontError;
    Dispose(FontData);
    Exit;
  end;

  { Store in map }
  MapPut(FontMap, Desc^.Name^, FontData);
  Desc^.Data := FontData;
  Desc^.Loaded := True;

  LoadFontResource := True;
end;
```

**Note:** VGAFONT.PAS has been updated with the `LoadFont(XMLPath, Font)` signature that:
1. Parses the font XML file
2. Reads the `image` attribute from the `<font>` element
3. Resolves the image path relative to the XML file's directory
4. Loads the PCX internally
5. Returns the loaded TFont

The font XML uses an `image` attribute (e.g., `<font image="FONT-SM.PCX">`) with a path relative to the XML file's location.

### LoadSpriteResource (Dependency Resolution)

```pascal
function TResourceManager.LoadSpriteResource(Desc: PResourceDescriptor): Boolean;
var
  SprData: PSpriteData;
  XMLNode: PXMLNode;
  FrameNode: PXMLNode;
  ImgName: String;
  ParentImage: PImage;
  FrameIdx: Byte;
begin
  LoadSpriteResource := False;

  if Desc^.Loaded then
  begin
    LoadSpriteResource := True;
    Exit;
  end;

  { Allocate sprite data }
  New(SprData);

  { Get XML node (stored during ParseXML) }
  XMLNode := PXMLNode(Desc^.Data);

  { Get parent image name }
  if not XMLHasAttr(XMLNode, 'image') then
  begin
    LastError := 'Sprite missing image attribute';
    Dispose(SprData);
    Exit;
  end;

  ImgName := XMLAttr(XMLNode, 'image')^;
  New(SprData^.ImageName);
  SprData^.ImageName^ := ImgName;

  { Load parent image (recursive - ensures image is loaded) }
  ParentImage := GetImage(ImgName);
  if ParentImage = nil then
  begin
    Dispose(SprData^.ImageName);
    Dispose(SprData);
    Exit;
  end;

  { Setup sprite }
  SprData^.Sprite.Image := ParentImage;
  SprData^.Sprite.Duration := StrToReal(XMLAttr(XMLNode, 'duration')^);
  SprData^.Sprite.PlayType := SpritePlayType_Forward;  { Default }

  { Parse frames }
  FrameIdx := 0;
  FrameNode := XMLFirstChild(XMLNode);
  while (FrameNode <> nil) and (FrameIdx < MaxSpriteFrames) do
  begin
    if FrameNode^.Tag^ = 'frame' then
    begin
      SprData^.Sprite.Frames[FrameIdx].X := StrToInt(XMLAttr(FrameNode, 'x')^);
      SprData^.Sprite.Frames[FrameIdx].Y := StrToInt(XMLAttr(FrameNode, 'y')^);
      SprData^.Sprite.Frames[FrameIdx].Width := StrToInt(XMLAttr(FrameNode, 'width')^);
      SprData^.Sprite.Frames[FrameIdx].Height := StrToInt(XMLAttr(FrameNode, 'height')^);

      { Set sprite dimensions from first frame }
      if FrameIdx = 0 then
      begin
        SprData^.Sprite.Width := SprData^.Sprite.Frames[0].Width;
        SprData^.Sprite.Height := SprData^.Sprite.Frames[0].Height;
      end;

      Inc(FrameIdx);
    end;
    FrameNode := XMLNextSibling(FrameNode);
  end;

  SprData^.Sprite.FrameCount := FrameIdx;
  SprData^.FrameCount := FrameIdx;

  { Store in map }
  MapPut(SpriteMap, Desc^.Name^, SprData);
  Desc^.Data := SprData;
  Desc^.Loaded := True;

  LoadSpriteResource := True;
end;
```

### Sound Resource Loading

```pascal
function TResourceManager.LoadSoundResource(Desc: PResourceDescriptor): Boolean;
var
  SndData: PSoundData;
begin
  LoadSoundResource := False;

  if Desc^.Loaded then
  begin
    LoadSoundResource := True;
    Exit;
  end;

  { Initialize sound bank on first sound load }
  if not SoundBankInitialized then
  begin
    if not SoundBank.Init then
    begin
      LastError := 'Failed to initialize sound bank';
      Exit;
    end;
    SoundBankInitialized := True;
  end;

  { Allocate sound data }
  New(SndData);

  { Load into sound bank }
  SndData^.SoundID := SoundBank.LoadSound(Desc^.Path^);
  if SndData^.SoundID < 0 then
  begin
    LastError := 'Failed to load sound: ' + Desc^.Path^;
    Dispose(SndData);
    Exit;
  end;

  { Store in map }
  MapPut(SoundMap, Desc^.Name^, SndData);
  Desc^.Data := SndData;
  Desc^.Loaded := True;

  LoadSoundResource := True;
end;
```

### Cleanup

```pascal
procedure TResourceManager.Done;
var
  Node: PLinkedListNode;
  Desc: PResourceDescriptor;
  ImgData: PImageData;
  FontData: PFontData;
  SprData: PSpriteData;
  MusicData: PMusicData;
  LevelData: PLevelData;
begin
  { Free all loaded resources }
  Node := Descriptors^.Head;
  while Node <> nil do
  begin
    Desc := PResourceDescriptor(Node^.Data);

    if Desc^.Loaded then
    begin
      case Desc^.ResType of
        ResType_Image:
          begin
            ImgData := PImageData(Desc^.Data);
            FreeImage(ImgData^.Image);
            Dispose(ImgData);
          end;
        ResType_Font:
          begin
            FontData := PFontData(Desc^.Data);
            FreeFont(FontData^.Font);
            Dispose(FontData);
          end;
        ResType_Sprite:
          begin
            SprData := PSpriteData(Desc^.Data);
            Dispose(SprData^.ImageName);
            Dispose(SprData);
          end;
        ResType_Music:
          begin
            MusicData := PMusicData(Desc^.Data);
            MusicData^.Music.Done;
            Dispose(MusicData);
          end;
        ResType_Level:
          begin
            LevelData := PLevelData(Desc^.Data);
            FreeTileMap(LevelData^.Map^);
            Dispose(LevelData);
          end;
        { Sounds freed by SoundBank.Done }
      end;
    end;

    { Free descriptor }
    if Desc^.Name <> nil then Dispose(Desc^.Name);
    if Desc^.Path <> nil then Dispose(Desc^.Path);
    Dispose(Desc);

    Node := Node^.Next;
  end;

  { Free sound bank }
  if SoundBankInitialized then
    SoundBank.Done;

  { Free collections }
  ListFree(Descriptors^);
  Dispose(Descriptors);
  MapFree(MusicMap);
  MapFree(SoundMap);
  MapFree(ImageMap);
  MapFree(FontMap);
  MapFree(SpriteMap);
  MapFree(LevelMap);
end;
```

## Usage Example

### Simple Game

```pascal
program MyGame;

uses VGA, ResMan, Sprite, Keyboard, RTCTimer;

var
  ResMgr: TResourceManager;
  PlayerSprite: PSprite;
  Player: TSpriteInstance;
  Running: Boolean;
  CurrentTime, LastTime, DeltaTime: Real;
  BackBuffer: PFrameBuffer;

begin
  { Initialize resource manager with lazy loading }
  ResMgr.Init(True);
  if not ResMgr.LoadFromXML('DATA\RES.XML') then
  begin
    WriteLn('Error: ', ResMgr.LastError);
    Halt(1);
  end;

  { Get sprite (loads image + sprite automatically) }
  PlayerSprite := ResMgr.GetSprite('player_idle');
  if PlayerSprite = nil then
  begin
    WriteLn('Error: ', ResMgr.LastError);
    Halt(1);
  end;

  { Setup sprite instance }
  Player.Sprite := PlayerSprite;
  Player.X := 144;
  Player.Y := 84;
  Player.Hidden := False;
  Player.FlipX := False;
  Player.FlipY := False;
  Player.CurrentTime := 0.0;

  { Initialize systems }
  InitVGA;
  BackBuffer := CreateFrameBuffer;
  InitKeyboard;
  InitRTC(1024);

  Running := True;
  LastTime := GetTimeSeconds;

  { Game loop }
  while Running do
  begin
    CurrentTime := GetTimeSeconds;
    DeltaTime := CurrentTime - LastTime;
    LastTime := CurrentTime;

    if IsKeyPressed(Key_Escape) then
      Running := False;

    if IsKeyPressed(Key_Space) then
      Player.Sprite := ResMgr.GetSprite('player_run');

    UpdateSprite(Player, DeltaTime);

    ClearFrameBuffer(BackBuffer);
    DrawSprite(Player, BackBuffer);
    RenderFrameBuffer(BackBuffer);

    WaitForVSync;
    ClearKeyPressed;
  end;

  { Cleanup }
  DoneRTC;
  DoneKeyboard;
  FreeFrameBuffer(BackBuffer);
  CloseVGA;

  ResMgr.Done;
end.
```

## Performance Considerations

### Memory Usage

**Eager Loading:**
- Higher startup memory usage
- All resources loaded upfront
- Simpler, no runtime loading delays

**Lazy Loading:**
- Lower initial memory footprint
- First access has loading penalty
- Better for large asset libraries

**Recommendation:** Use lazy loading with preload zones:
```pascal
{ Before level 1 }
ResMgr.LoadResource('player_idle');
ResMgr.LoadResource('player_run');
ResMgr.LoadResource('level1');
```

### String Map Performance

- STRMAP.PAS uses 256-bucket hash
- Average O(1) lookup for GetXXX methods
- 1000 resources = ~4 resources per bucket

### Dependency Resolution

- Sprites reference images by name
- GetSprite automatically calls GetImage
- No circular dependencies possible (sprites can't reference sprites)

## Future Enhancements

1. **Reference Counting:** Track active sprite instances to enable resource unloading
2. **Resource Groups:** Load/unload sets of resources (e.g., "level1_assets")
3. **Streaming:** Background loading with progress callbacks
4. **Hot Reload:** Reload resources without restarting (development mode)
5. **Compression:** Support for packed/compressed resource files
6. **Palette Management:** Store and apply palettes per-resource
7. **Animation Modes:** Support PlayType attribute (Forward/PingPong/Once)

## Error Handling

All Get methods return `nil` on failure and set `LastError`:

```pascal
Spr := ResMgr.GetSprite('invalid');
if Spr = nil then
  WriteLn('Error: ', ResMgr.LastError);
```

Common errors:
- "Resource not found: name" - Name not in XML
- "Failed to load image: path" - File missing or corrupt
- "Sprite missing image attribute" - Malformed XML
- "Failed to initialize sound bank" - No HIMEM.SYS or Sound Blaster

## Dependencies

**Required Units:**
- MINIXML (XML parsing)
- STRMAP (name → resource lookups)
- LINKLIST (descriptor storage)
- PCXLOAD (image loading)
- VGAFONT (variable-width fonts)
- SPRITE (sprite definitions)
- SNDBANK (sound management)
- PLAYHSC (music playback)
- TMXLOAD (level loading)
- STRUTIL (StrToInt, StrToReal)

**Memory:**
- ~2KB per resource descriptor
- Maps: 256 pointers × 6 types = ~3KB overhead
- Actual resource data: images, fonts, sprites, etc.

## Testing Strategy

**Unit Test (TESTS\RESMTEST.PAS):**
1. Load RES.XML with lazy loading
2. Access each resource type (image, font, sprite, sound, music, level)
3. Verify lazy loading (descriptors loaded, data not loaded until accessed)
4. Test error cases (missing file, invalid XML, missing dependency)
5. Verify cleanup (all resources freed)

**Integration Test:**
Use resource manager in existing tests:
- SPRTEST.PAS → Load sprites from XML instead of manual setup
- IMGTEST.PAS → Load images from XML
- MAPTEST.PAS → Load tilemaps from XML

## Summary

TResourceManager provides:
- ✅ Declarative resource definitions (XML)
- ✅ Name-based access (no hardcoded paths)
- ✅ Automatic dependency resolution (sprites → images)
- ✅ Lazy or eager loading strategies
- ✅ Centralized cleanup
- ✅ Type-safe accessors (GetImage, GetSprite, etc.)
- ✅ Error tracking with LastError

**Next Steps:**
1. ✅ Update VGAFONT.PAS to support LoadFont(XMLPath, Font) with relative image paths
2. Implement UNITS\RESMAN.PAS
3. Create TESTS\RESMTEST.PAS
4. Update existing tests to use resource manager
5. Add helper for StrToReal to STRUTIL.PAS (currently only has StrToInt)
