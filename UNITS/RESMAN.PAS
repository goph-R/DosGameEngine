unit ResMan;

interface

uses
  GenTypes, VGA, VGAFont, Sprite, PlayHSC, SndBank, MiniXML,
  StrMap, LinkList, StrUtil, PCXLOAD;

type
  { Pointer type for HSC_Obj (not defined in PLAYHSC) }
  PHSC_Obj = ^HSC_Obj;

  TResourceType = (
    ResType_Music,    { HSC music files }
    ResType_Sound,    { VOC sound files (via TSoundBank) }
    ResType_Image,    { PCX images }
    ResType_Font,     { Variable-width fonts (TFont from VGAFONT) }
    ResType_Sprite    { Sprite definitions (TSprite) }
  );

  { Music resource data }
  PMusicData = ^TMusicData;
  TMusicData = record
    Music: HSC_Obj;
  end;

  { Sound resource data }
  PSoundData = ^TSoundData;
  TSoundData = record
    SoundID: Integer;
  end;

  { Image resource data }
  PImageData = ^TImageData;
  TImageData = record
    Image: TImage;
    UsePalette: Boolean;
  end;

  { Font resource data }
  PFontData = ^TFontData;
  TFontData = record
    Font: TFont;
  end;

  { Sprite resource data }
  PSpriteData = ^TSpriteData;
  TSpriteData = record
    Sprite: TSprite;
    ImageName: PShortString;
    Duration: Real;
  end;

  { Base resource descriptor }
  PResourceDescriptor = ^TResourceDescriptor;
  TResourceDescriptor = record
    Name: PShortString;
    ResType: TResourceType;
    Path: PShortString;
    Loaded: Boolean;
    Data: Pointer;
    UsePalette: Boolean;
  end;

  { Resource Manager }
  TResourceManager = object
    { Resource storage - separate maps for each type }
    MusicMap: TStringMap;
    SoundMap: TStringMap;
    ImageMap: TStringMap;
    FontMap: TStringMap;
    SpriteMap: TStringMap;

    { Descriptors list (for cleanup) }
    Descriptors: TLinkedList;

    { Sound bank (shared for all sounds) }
    SoundBank: TSoundBank;
    SoundBankInitialized: Boolean;

    { Singleton music resource (only one music in memory at a time) }
    CurrentMusic: PMusicData;
    CurrentMusicName: PShortString;

    { Loading strategy }
    LazyLoad: Boolean;

    { Error tracking }
    LastError: String;

    { Methods }
    procedure Init(UseLazyLoading: Boolean);
    function LoadFromXML(const Filename: String): Boolean;

    { Resource access - lazy load if not loaded }
    function GetImage(const Name: String): PImage;
    function GetFont(const Name: String): PFont;
    function GetSprite(const Name: String): PSprite;
    function GetSound(const Name: String): Integer;
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

implementation

{ TResourceManager.Init }
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

{ TResourceManager.LoadFromXML }
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

{ TResourceManager.ParseSpriteData }
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

      { Store frame rectangle }
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

{ TResourceManager.ParseXML }
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
      Desc^.Path^ := XMLAttr(Child, 'path');
      ListAdd(Descriptors, Desc);
    end
    else if TagName = 'sprite' then
    begin
      { Parse sprite data immediately (don't keep XML pointer) }
      Desc^.ResType := ResType_Sprite;
      Desc^.Path := nil;

      { Allocate sprite data and extract all info from XML }
      if not ParseSpriteData(Child, Desc) then
      begin
        Dispose(Desc^.Name); Dispose(Desc);
        Exit;
      end;

      ListAdd(Descriptors, Desc);
    end
    else
    begin
      Dispose(Desc^.Name);
      Dispose(Desc);
    end;

    Child := XMLNextSibling(Child, '');
  end;

  ParseXML := True;
end;

{ TResourceManager.GetImage }
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

{ TResourceManager.LoadImageResource }
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

{ TResourceManager.GetFont }
function TResourceManager.GetFont(const Name: String): PFont;
var
  FontData: PFontData;
  Desc: PResourceDescriptor;
  Node: PLinkedListNode;
begin
  GetFont := nil;

  { Check if already loaded }
  if MapContains(FontMap, Name) then
  begin
    FontData := PFontData(MapGet(FontMap, Name));
    GetFont := @FontData^.Font;
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
      if (Desc^.ResType = ResType_Font) and (Desc^.Name^ = Name) then
      begin
        if LoadFontResource(Desc) then
        begin
          FontData := PFontData(Desc^.Data);
          GetFont := @FontData^.Font;
        end;
        Exit;
      end;
      Node := Node^.Next;
    end;
  end;

  LastError := 'Font not found: ' + Name;
end;

{ TResourceManager.LoadFontResource }
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

{ TResourceManager.GetSprite }
function TResourceManager.GetSprite(const Name: String): PSprite;
var
  SprData: PSpriteData;
  Desc: PResourceDescriptor;
  Node: PLinkedListNode;
begin
  GetSprite := nil;

  { Check if already loaded }
  if MapContains(SpriteMap, Name) then
  begin
    SprData := PSpriteData(MapGet(SpriteMap, Name));
    GetSprite := @SprData^.Sprite;
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
      if (Desc^.ResType = ResType_Sprite) and (Desc^.Name^ = Name) then
      begin
        if LoadSpriteResource(Desc) then
        begin
          SprData := PSpriteData(Desc^.Data);
          GetSprite := @SprData^.Sprite;
        end;
        Exit;
      end;
      Node := Node^.Next;
    end;
  end;

  LastError := 'Sprite not found: ' + Name;
end;

{ TResourceManager.LoadSpriteResource }
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
  SprData^.Sprite.PlayType := SpritePlayType_Forward;

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

{ TResourceManager.GetSound }
function TResourceManager.GetSound(const Name: String): Integer;
var
  SndData: PSoundData;
  Desc: PResourceDescriptor;
  Node: PLinkedListNode;
begin
  GetSound := -1;

  { Check if already loaded }
  if MapContains(SoundMap, Name) then
  begin
    SndData := PSoundData(MapGet(SoundMap, Name));
    GetSound := SndData^.SoundID;
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
      if (Desc^.ResType = ResType_Sound) and (Desc^.Name^ = Name) then
      begin
        if LoadSoundResource(Desc) then
        begin
          SndData := PSoundData(Desc^.Data);
          GetSound := SndData^.SoundID;
        end;
        Exit;
      end;
      Node := Node^.Next;
    end;
  end;

  LastError := 'Sound not found: ' + Name;
end;

{ TResourceManager.LoadSoundResource }
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

{ TResourceManager.GetMusic }
function TResourceManager.GetMusic(const Name: String): PHSC_Obj;
var
  MusicData: PMusicData;
  Desc: PResourceDescriptor;
  Node: PLinkedListNode;
begin
  GetMusic := nil;

  { Check if already loaded }
  if MapContains(MusicMap, Name) then
  begin
    MusicData := PMusicData(MapGet(MusicMap, Name));
    GetMusic := @MusicData^.Music;
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
      if (Desc^.ResType = ResType_Music) and (Desc^.Name^ = Name) then
      begin
        if LoadMusicResource(Desc) then
        begin
          MusicData := PMusicData(Desc^.Data);
          GetMusic := @MusicData^.Music;
        end;
        Exit;
      end;
      Node := Node^.Next;
    end;
  end;

  LastError := 'Music not found: ' + Name;
end;

{ TResourceManager.LoadMusicResource }
function TResourceManager.LoadMusicResource(Desc: PResourceDescriptor): Boolean;
var
  MusicData: PMusicData;
  OldDesc: PResourceDescriptor;
  Node: PLinkedListNode;
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

{ TResourceManager.LoadResource }
function TResourceManager.LoadResource(const Name: String): Boolean;
var
  Desc: PResourceDescriptor;
  Node: PLinkedListNode;
begin
  LoadResource := False;

  { Find descriptor }
  Node := Descriptors.First;
  while Node <> nil do
  begin
    Desc := PResourceDescriptor(Node^.Value);
    if Desc^.Name^ = Name then
    begin
      { Load based on type }
      case Desc^.ResType of
        ResType_Image: LoadResource := LoadImageResource(Desc);
        ResType_Font: LoadResource := LoadFontResource(Desc);
        ResType_Sprite: LoadResource := LoadSpriteResource(Desc);
        ResType_Sound: LoadResource := LoadSoundResource(Desc);
        ResType_Music: LoadResource := LoadMusicResource(Desc);
      end;
      Exit;
    end;
    Node := Node^.Next;
  end;

  LastError := 'Resource not found: ' + Name;
end;

{ TResourceManager.UnloadResource }
procedure TResourceManager.UnloadResource(const Name: String);
begin
  { Not implemented - resources are unloaded only on Done }
  LastError := 'UnloadResource not implemented';
end;

{ TResourceManager.PreloadAll }
procedure TResourceManager.PreloadAll;
var
  Node: PLinkedListNode;
  Desc: PResourceDescriptor;
begin
  Node := Descriptors.First;
  while Node <> nil do
  begin
    Desc := PResourceDescriptor(Node^.Value);
    if not Desc^.Loaded then
    begin
      case Desc^.ResType of
        ResType_Image: LoadImageResource(Desc);
        ResType_Font: LoadFontResource(Desc);
        ResType_Sprite: LoadSpriteResource(Desc);
        ResType_Sound: LoadSoundResource(Desc);
        ResType_Music: LoadMusicResource(Desc);
      end;
    end;
    Node := Node^.Next;
  end;
end;

{ TResourceManager.Done }
procedure TResourceManager.Done;
var
  Node: PLinkedListNode;
  Desc: PResourceDescriptor;
  ImgData: PImageData;
  FontData: PFontData;
  SprData: PSpriteData;
  SndData: PSoundData;
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

end.
