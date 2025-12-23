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

**XML Attributes:**
- All resources require a `name` attribute for lookup
- `music`, `sound`, `image`, `font` require a `path` attribute
- `image` supports optional `use-palette` attribute (boolean flag)
- `sprite` requires `image` (image resource name) and `duration` (seconds)
- `sprite` frames require `x`, `y`, `width`, `height` attributes

**Note:** Level resources (`<level>`) are not yet implemented and will be metadata-based requiring additional design work.

**Note on Image Resources:**
The `<image>` tag references a PCX file (e.g. `DATA\BG1.PCX`). If the `use-palette` attribute is present, `LoadPCXWithPalette` will be used and `SetPalette` will be called to apply the loaded palette globally. Use this for background images or screens that define the global palette. Omit `use-palette` for sprites, HUD elements, or images that should use the existing palette.
 
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

### Helper Types

```pascal
type
  { Pointer type for HSC_Obj (not defined in PLAYHSC unit) }
  PHSC_Obj = ^HSC_Obj;
```

### Resource Types

```pascal
type
  TResourceType = (
    ResType_Music,    { HSC music files }
    ResType_Sound,    { VOC sound files (via TSoundBank) }
    ResType_Image,    { PCX images }
    ResType_Font,     { Variable-width fonts (TFont from VGAFONT) }
    ResType_Sprite    { Sprite definitions (TSprite) }
    { ResType_Level - Future: Will be metadata-based, requires design }
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
    UsePalette: Boolean;      { For images: whether to load and set palette }
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
    Duration: Real;           { Animation duration (parsed from XML) }
  end;

```

**Note:** Level resources are not yet implemented. They will be metadata-based and require additional design work.

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

    { Descriptors list (for cleanup) }
    Descriptors: TLinkedList; { TResourceDescriptor entries }

    { Sound bank (shared for all sounds) }
    SoundBank: TSoundBank;
    SoundBankInitialized: Boolean;

    { Singleton music resource (only one music in memory at a time) }
    CurrentMusic: PMusicData; { Currently loaded music }
    CurrentMusicName: PShortString; { Name of currently loaded music }

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

    { Manual loading/unloading }
    function LoadResource(const Name: String): Boolean;
    procedure UnloadResource(const Name: String);
    procedure PreloadAll;

    { Cleanup }
    procedure Done;

    { Internal methods }
    private
      function ParseXML(RootNode: PXMLNode): Boolean;
      function ParseSpriteData(XMLNode: PXMLNode; Desc: PResourceDescriptor): Boolean;
      function LoadImageResource(Desc: PResourceDescriptor): Boolean;
      function LoadFontResource(Desc: PResourceDescriptor): Boolean;
      function LoadSpriteResource(Desc: PResourceDescriptor): Boolean;
      function LoadSoundResource(Desc: PResourceDescriptor): Boolean;
      function LoadMusicResource(Desc: PResourceDescriptor): Boolean;
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

  { Initialize descriptor list }
  ListInit(Descriptors);

  { Set loading strategy }
  LazyLoad := UseLazyLoading;

  { Sound bank not initialized yet }
  SoundBankInitialized := False;

  { No music loaded yet }
  CurrentMusic := nil;
  CurrentMusicName := nil;

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

### ParseSpriteData (Helper for Sprite Parsing)

```pascal
function TResourceManager.ParseSpriteData(XMLNode: PXMLNode; Desc: PResourceDescriptor): Boolean;
var
  SprData: PSpriteData;
  FrameNode: PXMLNode;
  FrameIdx: Byte;
begin
  ParseSpriteData := False;

  { Validate required attributes }
  if not XMLHasAttr(XMLNode, 'image') then
  begin
    LastError := 'Sprite "' + Desc^.Name^ + '" missing image attribute';
    Exit;
  end;

  if not XMLHasAttr(XMLNode, 'duration') then
  begin
    LastError := 'Sprite "' + Desc^.Name^ + '" missing duration attribute';
    Exit;
  end;

  { Allocate sprite data structure }
  New(SprData);
  FillChar(SprData^, SizeOf(TSpriteData), 0);

  { Store image name }
  New(SprData^.ImageName);
  SprData^.ImageName^ := XMLAttr(XMLNode, 'image');

  { Store duration for later use }
  SprData^.Duration := StrToReal(XMLAttr(XMLNode, 'duration'));

  { Parse frame rectangles }
  FrameIdx := 0;
  FrameNode := XMLFirstChild(XMLNode, '');
  while (FrameNode <> nil) and (FrameIdx < MaxSpriteFrames) do
  begin
    if FrameNode^.Name = 'frame' then
    begin
      { Validate frame attributes }
      if not XMLHasAttr(FrameNode, 'x') or not XMLHasAttr(FrameNode, 'y') or
         not XMLHasAttr(FrameNode, 'width') or not XMLHasAttr(FrameNode, 'height') then
      begin
        LastError := 'Sprite "' + Desc^.Name^ + '" frame missing x/y/width/height attributes';
        Dispose(SprData^.ImageName);
        Dispose(SprData);
        Exit;
      end;

      { Store frame rectangle (TSprite.Frames is already allocated in TSpriteData) }
      SprData^.Sprite.Frames[FrameIdx].X := StrToInt(XMLAttr(FrameNode, 'x'));
      SprData^.Sprite.Frames[FrameIdx].Y := StrToInt(XMLAttr(FrameNode, 'y'));
      SprData^.Sprite.Frames[FrameIdx].Width := StrToInt(XMLAttr(FrameNode, 'width'));
      SprData^.Sprite.Frames[FrameIdx].Height := StrToInt(XMLAttr(FrameNode, 'height'));

      Inc(FrameIdx);
    end;
    FrameNode := XMLNextSibling(FrameNode, '');
  end;

  { Store frame count }
  SprData^.Sprite.FrameCount := FrameIdx;

  if FrameIdx = 0 then
  begin
    LastError := 'Sprite "' + Desc^.Name^ + '" has no frames';
    Dispose(SprData^.ImageName);
    Dispose(SprData);
    Exit;
  end;

  { Store in descriptor }
  Desc^.Data := SprData;
  ParseSpriteData := True;
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
  Child := XMLFirstChild(RootNode, '');

  while Child <> nil do
  begin
    TagName := Child^.Name;

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
    Desc^.Name^ := XMLAttr(Child, 'name');
    Desc^.Loaded := False;

    { Parse by type }
    if TagName = 'music' then
    begin
      Desc^.ResType := ResType_Music;
      if not XMLHasAttr(Child, 'path') then
      begin
        LastError := 'Resource "' + Desc^.Name^ + '" missing path attribute';
        Dispose(Desc^.Name); Dispose(Desc);
        Exit;
      end;
      New(Desc^.Path);
      Desc^.Path^ := XMLAttr(Child, 'path');
      ListAdd(Descriptors, Desc);
    end
    else if TagName = 'sound' then
    begin
      Desc^.ResType := ResType_Sound;
      if not XMLHasAttr(Child, 'path') then
      begin
        LastError := 'Resource "' + Desc^.Name^ + '" missing path attribute';
        Dispose(Desc^.Name); Dispose(Desc);
        Exit;
      end;
      New(Desc^.Path);
      Desc^.Path^ := XMLAttr(Child, 'path');
      ListAdd(Descriptors, Desc);
    end
    else if TagName = 'image' then
    begin
      Desc^.ResType := ResType_Image;
      if not XMLHasAttr(Child, 'path') then
      begin
        LastError := 'Resource "' + Desc^.Name^ + '" missing path attribute';
        Dispose(Desc^.Name); Dispose(Desc);
        Exit;
      end;
      New(Desc^.Path);
      Desc^.Path^ := XMLAttr(Child, 'path');
      Desc^.UsePalette := XMLHasAttr(Child, 'use-palette');
      ListAdd(Descriptors, Desc);
    end
    else if TagName = 'font' then
    begin
      Desc^.ResType := ResType_Font;
      if not XMLHasAttr(Child, 'path') then
      begin
        LastError := 'Resource "' + Desc^.Name^ + '" missing path attribute';
        Dispose(Desc^.Name); Dispose(Desc);
        Exit;
      end;
      New(Desc^.Path);
      Desc^.Path^ := XMLAttr(Child, 'path');  { Path to font XML file }
      ListAdd(Descriptors, Desc);
    end
    else if TagName = 'sprite' then
    begin
      { Parse sprite data immediately (don't keep XML pointer) }
      Desc^.ResType := ResType_Sprite;
      Desc^.Path := nil;  { No file path }

      { Allocate sprite data and extract all info from XML }
      if not ParseSpriteData(Child, Desc) then
      begin
        Dispose(Desc^.Name); Dispose(Desc);
        Exit;
      end;

      ListAdd(Descriptors, Desc);
    end
    else if TagName = 'level' then
    begin
      Desc^.ResType := ResType_Level;
      if not XMLHasAttr(Child, 'path') then
      begin
        LastError := 'Resource "' + Desc^.Name^ + '" missing path attribute';
        Dispose(Desc^.Name); Dispose(Desc);
        Exit;
      end;
      New(Desc^.Path);
      Desc^.Path^ := XMLAttr(Child, 'path');
      ListAdd(Descriptors, Desc);
    end
    else
      Dispose(Desc^.Name);
      Dispose(Desc);  { Unknown tag }

    Child := XMLNextSibling(Child, '');
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
  Node: PListEntry;
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
    Node := Descriptors.First;
    while Node <> nil do
    begin
      Desc := PResourceDescriptor(Node^.Value);
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
  ImgData^.UsePalette := Desc^.UsePalette;

  { Load PCX file }
  if ImgData^.UsePalette then
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
    LastError := 'Failed to load image "' + Desc^.Name^ + '" from: ' + Desc^.Path^;
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
  { where the XML file contains the PCX image path internally }
  if not LoadFont(Desc^.Path^, FontData^.Font) then
  begin
    LastError := 'Failed to load font "' + Desc^.Name^ + '" from: ' + Desc^.Path^ + ' - ' + GetLoadFontError;
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

### LoadSpriteResource (Dependency Resolution)

```pascal
function TResourceManager.LoadSpriteResource(Desc: PResourceDescriptor): Boolean;
var
  SprData: PSpriteData;
  ParentImage: PImage;
begin
  LoadSpriteResource := False;

  if Desc^.Loaded then
  begin
    LoadSpriteResource := True;
    Exit;
  end;

  { Get pre-parsed sprite data (created during ParseXML) }
  SprData := PSpriteData(Desc^.Data);

  { Load parent image (recursive - ensures image is loaded) }
  ParentImage := GetImage(SprData^.ImageName^);
  if ParentImage = nil then
  begin
    LastError := 'Sprite "' + Desc^.Name^ + '" references unknown image: ' + SprData^.ImageName^;
    Exit;
  end;

  { Setup sprite with loaded image }
  SprData^.Sprite.Image := ParentImage;
  SprData^.Sprite.Duration := SprData^.Duration;
  SprData^.Sprite.PlayType := SpritePlayType_Forward;  { Default }

  { Set sprite dimensions from first frame (already parsed) }
  if SprData^.Sprite.FrameCount > 0 then
  begin
    SprData^.Sprite.Width := SprData^.Sprite.Frames[0].Width;
    SprData^.Sprite.Height := SprData^.Sprite.Frames[0].Height;
  end;

  { Store in map }
  MapPut(SpriteMap, Desc^.Name^, SprData);
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
    LastError := 'Failed to load sound "' + Desc^.Name^ + '" from: ' + Desc^.Path^;
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

### Music Resource Loading (Singleton Pattern)

```pascal
function TResourceManager.LoadMusicResource(Desc: PResourceDescriptor): Boolean;
var
  MusicData: PMusicData;
  OldDesc: PResourceDescriptor;
  Node: PListEntry;
begin
  LoadMusicResource := False;

  { Music is singleton - check if this music is already loaded }
  if (CurrentMusic <> nil) and (CurrentMusicName <> nil) and
     (CurrentMusicName^ = Desc^.Name^) then
  begin
    LoadMusicResource := True;
    Exit;
  end;

  { Unload previously loaded music (singleton pattern) }
  if CurrentMusic <> nil then
  begin
    { Stop music if playing }
    CurrentMusic^.Music.Stop;
    CurrentMusic^.Music.Done;
    Dispose(CurrentMusic);

    { Find and mark old descriptor as unloaded }
    if CurrentMusicName <> nil then
    begin
      Node := Descriptors.First;
      while Node <> nil do
      begin
        OldDesc := PResourceDescriptor(Node^.Value);
        if (OldDesc^.ResType = ResType_Music) and
           (OldDesc^.Name^ = CurrentMusicName^) then
        begin
          OldDesc^.Loaded := False;
          OldDesc^.Data := nil;
          Break;
        end;
        Node := Node^.Next;
      end;

      { Remove from map }
      MapRemove(MusicMap, CurrentMusicName^);
      Dispose(CurrentMusicName);
      CurrentMusicName := nil;
    end;

    CurrentMusic := nil;
  end;

  { Allocate music data }
  New(MusicData);

  { Initialize and load HSC music }
  MusicData^.Music.Init(0);
  if not MusicData^.Music.LoadFile(Desc^.Path^) then
  begin
    LastError := 'Failed to load music "' + Desc^.Name^ + '" from: ' + Desc^.Path^;
    MusicData^.Music.Done;
    Dispose(MusicData);
    Exit;
  end;

  { Store as singleton }
  CurrentMusic := MusicData;
  New(CurrentMusicName);
  CurrentMusicName^ := Desc^.Name^;

  { Store in map }
  MapPut(MusicMap, Desc^.Name^, MusicData);
  Desc^.Data := MusicData;
  Desc^.Loaded := True;

  LoadMusicResource := True;
end;
```

### Cleanup

```pascal
procedure TResourceManager.Done;
var
  Node: PListEntry;
  Desc: PResourceDescriptor;
  ImgData: PImageData;
  FontData: PFontData;
  SprData: PSpriteData;
  SndData: PSoundData;
  MusicData: PMusicData;
begin
  { Free all loaded resources }
  Node := Descriptors.First;
  while Node <> nil do
  begin
    Desc := PResourceDescriptor(Node^.Value);

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
        ResType_Sound:
          begin
            { Sound data freed by SoundBank.Done, but free wrapper }
            SndData := PSoundData(Desc^.Data);
            Dispose(SndData);
          end;
        ResType_Music:
          begin
            { Music cleanup handled by singleton cleanup below }
          end;
      end;
    end
    else
    begin
      { Free unloaded sprite data (parsed but never loaded) }
      if Desc^.ResType = ResType_Sprite then
      begin
        SprData := PSpriteData(Desc^.Data);
        if SprData <> nil then
        begin
          if SprData^.ImageName <> nil then
            Dispose(SprData^.ImageName);
          Dispose(SprData);
        end;
      end;
    end;

    { Free descriptor }
    if Desc^.Name <> nil then Dispose(Desc^.Name);
    if Desc^.Path <> nil then Dispose(Desc^.Path);
    Dispose(Desc);

    Node := Node^.Next;
  end;

  { Free singleton music resource }
  if CurrentMusic <> nil then
  begin
    CurrentMusic^.Music.Stop;
    CurrentMusic^.Music.Done;
    Dispose(CurrentMusic);
    CurrentMusic := nil;
  end;

  if CurrentMusicName <> nil then
  begin
    Dispose(CurrentMusicName);
    CurrentMusicName := nil;
  end;

  { Free sound bank }
  if SoundBankInitialized then
    SoundBank.Done;

  { Free collections }
  ListFree(Descriptors);
  MapFree(MusicMap);
  MapFree(SoundMap);
  MapFree(ImageMap);
  MapFree(FontMap);
  MapFree(SpriteMap);
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
  DoneVGA;

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
{ Note: Don't preload multiple music tracks - only one loads at a time (singleton) }
```

**Music Singleton Impact:**
- `PreloadAll` will only load the **last** music track in the XML (others get replaced)
- Use lazy loading for music - load explicitly when needed via `GetMusic`
- Example: `ResMgr.GetMusic('title')` loads title screen music on demand

### String Map Performance

- STRMAP.PAS uses 256-bucket hash
- Average O(1) lookup for GetXXX methods
- 1000 resources = ~4 resources per bucket

### Dependency Resolution

- Sprites reference images by name
- GetSprite automatically calls GetImage
- No circular dependencies possible (sprites can't reference sprites)

### Music Singleton Pattern

**Design Decision:**
Music is implemented as a singleton resource - only one music track can be loaded in memory at a time.

**Rationale:**
- HSC music files can be large (several KB)
- Only one music track plays at a time
- Automatic memory management prevents accumulation of unused music data
- Simplifies music switching (no manual cleanup needed)

**Behavior:**
- When loading a new music track, the previously loaded music is automatically unloaded
- The old music is stopped (`Music.Stop`), cleaned up (`Music.Done`), and freed
- The descriptor for the old music is marked as unloaded
- Calling `GetMusic` with the same name twice returns the cached instance (no reload)

**Example:**
```pascal
var
  TitleMusic, GameMusic: PHSC_Obj;
begin
  { Load and play title music }
  TitleMusic := ResMgr.GetMusic('title');
  TitleMusic^.Start;

  { Later, switch to gameplay music - title music auto-unloaded }
  GameMusic := ResMgr.GetMusic('level1');
  GameMusic^.Start;

  { TitleMusic pointer is now invalid! }
  { To switch back, call GetMusic again }
  TitleMusic := ResMgr.GetMusic('title');  { Reloads from disk }
  TitleMusic^.Start;
end;
```

**Important Notes:**
- After loading a different music track, previous `PHSC_Obj` pointers become invalid
- Always call `GetMusic` again when switching between tracks
- Music is not affected by `PreloadAll` - still follows singleton pattern
- Lazy loading still applies - music loads on first `GetMusic` call

### Palette Handling Strategy

**Current Implementation:**
- Images with `use-palette` attribute call `SetPalette` when loaded, changing the global VGA palette
- This is intended for full-screen background images that define the game's color scheme

**Best Practices:**
- Use `use-palette` for title screens, backgrounds, or loading screens
- Don't use `use-palette` for sprite sheets, HUD elements, or UI graphics
- Load palette-defining images first (or explicitly) to establish the color scheme
- Ensure all non-palette images are designed to work with the established palette

**Example Loading Order:**
```pascal
{ Establish palette from background }
Background := ResMgr.GetImage('level1_bg');  { has use-palette }

{ Then load sprites/UI (no palette change) }
PlayerSheet := ResMgr.GetImage('player');    { no use-palette }
UIElements := ResMgr.GetImage('hud');         { no use-palette }
```

### Descriptor Lookup Performance

**Current Implementation:**
- When lazy loading, `GetXXX` methods search the descriptor list O(N) to find unloaded resources
- Once loaded, lookups use STRMAP hash table O(1)

**Optimization Opportunity:**
For large resource counts (>100 resources), consider adding a global `DescriptorMap: TStringMap` that maps name → descriptor. This eliminates the O(N) list traversal for lazy loading:

```pascal
{ In Init }
MapInit(DescriptorMap);

{ In ParseXML }
MapPut(DescriptorMap, Desc^.Name^, Desc);

{ In GetImage }
if MapContains(DescriptorMap, Name) then
  Desc := PResourceDescriptor(MapGet(DescriptorMap, Name));
```

Current implementation prioritizes simplicity; optimization only needed if lazy load performance becomes an issue.

## Future Enhancements

1. **Level Resources:** Metadata-based level resource type (requires design - levels will be metadata, not direct TMX loading)
2. **Reference Counting:** Track active sprite instances to enable resource unloading
3. **Resource Groups:** Load/unload sets of resources (e.g., "level1_assets")
4. **Streaming:** Background loading with progress callbacks
5. **Hot Reload:** Reload resources without restarting (development mode)
6. **Compression:** Support for packed/compressed resource files
7. **Palette Management:** Store and apply palettes per-resource
8. **Animation Modes:** Support PlayType attribute (Forward/PingPong/Once)

## Error Handling

All Get methods return `nil` on failure and set `LastError`:

```pascal
Spr := ResMgr.GetSprite('invalid');
if Spr = nil then
  WriteLn('Error: ', ResMgr.LastError);
```

Common errors:
- `"Resource not found: name"` - Name not in XML
- `"Resource \"name\" missing path attribute"` - Malformed XML (missing required path)
- `"Resource \"name\" missing name attribute"` - Malformed XML (missing name)
- `"Failed to load image \"name\" from: path"` - File missing or corrupt
- `"Sprite \"name\" missing image attribute"` - Malformed sprite (no image reference)
- `"Sprite \"name\" missing duration attribute"` - Malformed sprite (no duration)
- `"Sprite \"name\" frame missing x/y/width/height attributes"` - Malformed frame data
- `"Sprite \"name\" has no frames"` - Sprite defined with no frame elements
- `"Sprite \"name\" references unknown image: imagename"` - Sprite references non-existent image
- `"Failed to initialize sound bank"` - No HIMEM.SYS or Sound Blaster
- `"Failed to load font: path - error"` - Font XML or PCX loading failed

All error messages now include the resource name for better debugging context.

## Dependencies

**Required Units:**
- MINIXML (XML parsing)
- STRMAP (name → resource lookups)
- LINKLIST (descriptor storage)
- PCX (image loading and saving)
- VGAFONT (variable-width fonts)
- SPRITE (sprite definitions)
- SNDBANK (sound management)
- PLAYHSC (music playback)
- STRUTIL (StrToInt, StrToReal)

**Memory:**
- ~2KB per resource descriptor
- Maps: 256 pointers × 5 types = ~2.5KB overhead
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
- SPRTEST.PAS → Load image and sprites from XML instead of manual setup
- XiClone → Full game using resource manager for all assets

## Summary

TResourceManager provides:
- ✅ Declarative resource definitions (XML)
- ✅ Name-based access (no hardcoded paths)
- ✅ Automatic dependency resolution (sprites → images)
- ✅ Lazy or eager loading strategies
- ✅ Singleton music management (auto-unload on switch)
- ✅ Centralized cleanup
- ✅ Type-safe accessors (GetImage, GetSprite, etc.)
- ✅ Error tracking with LastError

**Next Steps:**
1. ✅ Update VGAFONT.PAS to support LoadFont(XMLPath, Font) with relative image paths
2. Implement UNITS\RESMAN.PAS
3. Create TESTS\RESMTEST.PAS
4. Update existing tests to use resource manager
5. Add helper for StrToReal to STRUTIL.PAS (currently only has StrToInt)
