# Engine Units - Quick Reference

Complete reference for all DOS Game Engine units. For detailed documentation, see individual unit files.

## Table of Contents

- [Graphics Units](#graphics-units)
- [Sound Units](#sound-units)
- [Input Units](#input-units)
- [Utility Units](#utility-units)
- [Data Structure Units](#data-structure-units)
- [Tilemap Units](#tilemap-units)

---

## Graphics Units

### VGA.PAS ⭐ [Full Docs](VGA.md)

Low-level VGA Mode 13h graphics driver (320×200, 256 colors).

**Key Functions:**
- `InitVGA` / `DoneVGA` - Mode switching
- `CreateFrameBuffer` / `RenderFrameBuffer` - Double-buffering
- `SetPalette` / `RotatePalette` / `GetRGB` / `SetRGB` - Palette control
- `DrawLine` / `DrawHLine` / `DrawVLine` - Line drawing
- `DrawRect` / `DrawFillRect` - Rectangle drawing
- `PutImage` / `PutFlippedImageRect` - Image rendering

**See:** [VGA.md](VGA.md) for complete API documentation.

---

### PCX.PAS

PCX image file loading and saving (ZSoft PCX v5 format, Aseprite-compatible).

**Functions:**
```pascal
function LoadPCX(const FileName: string; var Image: TImage): Boolean;
function LoadPCXWithPalette(const FileName: string; var Image: TImage;
                            var Palette: TPalette): Boolean;
function GetLoadPCXError: string;
function SavePCX(const FileName: string; const Image: TImage; const Palette: TPalette): Boolean;
function GetSavePCXError: string;
```

**Example:**
```pascal
var
  Sprite: TImage;
  Pal: TPalette;
begin
  if LoadPCXWithPalette('PLAYER.PCX', Sprite, Pal) then
  begin
    SetPalette(Pal);
    PutImage(Sprite, 100, 100, True, FrameBuffer);
    FreeImage(Sprite);
  end
  else
    WriteLn(GetLoadPCXError);
end;
```

**Notes:**
- Supports 256-color PCX (8-bit indexed, 1 plane, RLE compressed)
- Automatically converts palette from 0-255 to VGA 0-63 range
- Handles scanline padding (BytesPerLine)
- Palette located at EOF-768 bytes (marked by 0x0C byte)
- Max image size: 65520 bytes (real-mode limit)
- Export from Aseprite: File → Export → .pcx (8-bit indexed)

---

### VGAPRINT.PAS

Bitmap font text renderer for VGA Mode 13h.

**Function:**
```pascal
procedure PrintText(X, Y: Integer; const Text: string; Color: Byte;
                    FrameBuffer: PFrameBuffer);
```

**Example:**
```pascal
PrintText(10, 10, 'Score: 1000', 15, BackBuffer);
PrintText(10, 20, 'Lives: 3', 14, BackBuffer);
```

**Features:**
- 8×8 embedded bitmap font
- Supports printable ASCII (32-127)
- Automatic screen clipping
- No external font file needed

---

### SPRITE.PAS

Delta-time sprite animation system.

**Types:**
```pascal
type
  TSprite = record
    Image: PImage;
    Frames: array[0..63] of TRectangle;
    FrameCount: Byte;
    Duration: Word;  { Total duration in milliseconds }
    PlayType: Byte;  { Forward, PingPong, Once }
  end;

  TSpriteInstance = record
    Sprite: PSprite;
    X, Y: Integer;
    FlipX, FlipY: Boolean;
    CurrentTime: Integer;
    Hidden: Boolean;
  end;
```

**Functions:**
```pascal
procedure UpdateSprite(var Instance: TSpriteInstance; DeltaTimeMS: Word);
procedure DrawSprite(const Instance: TSpriteInstance; FrameBuffer: PFrameBuffer);
```

**Example:**
```pascal
var
  PlayerIdle: TSprite;
  Player: TSpriteInstance;

begin
  { Setup sprite }
  PlayerIdle.Image := @SpriteSheet;
  PlayerIdle.FrameCount := 4;
  PlayerIdle.Duration := 800;  { 0.8 seconds }
  PlayerIdle.PlayType := SpritePlayType_Forward;

  { Setup instance }
  Player.Sprite := @PlayerIdle;
  Player.X := 100;
  Player.Y := 50;

  { Game loop }
  while Running do
  begin
    UpdateSprite(Player, DeltaTimeMS);
    DrawSprite(Player, BackBuffer);
  end;
end;
```

---

## Sound Units

### SBDSP.PAS ⭐ [Full Docs](SBDSP.md)

Professional Sound Blaster DSP driver with DMA playback.

**Key Functions:**
- `ResetDSP(Base, IRQ, DMA, HighDMA)` - Initialize
- `PlaySound(BaseSoundType)` - Play sample (up to 64KB)
- `PlaySoundRPD(Filename)` - Stream RPD file
- `UninstallHandler` - Cleanup (CRITICAL!)

**See:** [SBDSP.md](SBDSP.md) for complete API documentation.

---

### SNDBANK.PAS

XMS-based sound library manager for efficient sound effects.

**Type:**
```pascal
type
  TSoundBank = object
    function Init: Boolean;
    function LoadSound(const Filename: string): Integer;
    procedure PlaySound(ID: Integer);
    procedure StopSound;
    procedure Done;
  end;
```

**Example:**
```pascal
var
  Bank: TSoundBank;
  ExplosionID, LaserID: Integer;

begin
  ResetDSP(2, 5, 1, 0);
  Bank.Init;

  { Load sounds into XMS }
  ExplosionID := Bank.LoadSound('EXPLODE.VOC');
  LaserID := Bank.LoadSound('LASER.VOC');

  { Play instantly - no disk I/O! }
  Bank.PlaySound(ExplosionID);

  Bank.Done;
  UninstallHandler;
end;
```

**Features:**
- Stores sounds in XMS (extended memory)
- DMA-safe buffer allocation
- No disk I/O during playback
- Requires HIMEM.SYS

---

### PLAYHSC.PAS

HSC music player wrapper (Adlib/OPL2).

**Type:**
```pascal
type
  HSC_obj = object
    procedure Init(AdlibAddress: Word);
    function LoadFile(const Filename: string): Boolean;
    function LoadMem(DataPtr: Pointer): Boolean;
    procedure Start;
    procedure Stop;
    procedure Fade;
    procedure Poll;
    procedure Done;
  end;
```

**Example:**
```pascal
var
  Music: HSC_obj;

begin
  Music.Init(0);  { Auto-detect Adlib at $388 }
  if Music.LoadFile('MUSIC.HSC') then
  begin
    Music.Start;

    { Game loop }
    while Running do
    begin
      Music.Poll;  { MUST call every frame! }
      UpdateGame;
    end;

    Music.Done;  { CRITICAL! }
  end;
end;
```

**CRITICAL:**
- Call `Music.Poll` every frame
- Call `Music.Done` before exit (unhooks IRQ0)
- Compatible with SBDSP (different interrupts)

---

## Input Units

### KEYBOARD.PAS ⭐ [Full Docs](KEYBOARD.md)

Low-level keyboard handler via INT 9h interrupt.

**Key Functions:**
- `InitKeyboard` / `DoneKeyboard` - Setup/cleanup
- `IsKeyDown(ScanCode)` - Check if key held
- `IsKeyPressed(ScanCode)` - Edge detection (once per press)
- `ClearKeyPressed` - MUST call at end of game loop

**See:** [KEYBOARD.md](KEYBOARD.md) for complete API documentation.

---

### MOUSE.PAS

DOS mouse driver support via INT 33h.

**Functions:**
```pascal
function InitMouse: Boolean;
procedure ShowMouse;
procedure HideMouse;
procedure UpdateMouse;  { MUST call once per frame }
function GetMouseX: Integer;  { 0-319 }
function GetMouseY: Integer;  { 0-199 }
function GetMouseButtons: Byte;
function IsMouseButtonDown(Button: Byte): Boolean;
procedure DoneMouse;
```

**Constants:**
```pascal
const
  MouseButton_Left   = $01;
  MouseButton_Right  = $02;
  MouseButton_Middle = $04;
```

**Example:**
```pascal
begin
  if not InitMouse then Halt;

  ShowMouse;

  while Running do
  begin
    UpdateMouse;  { MUST call first! }

    if IsMouseButtonDown(MouseButton_Left) then
      FireWeapon(GetMouseX, GetMouseY);

    if IsMouseButtonDown(MouseButton_Right) then
      WriteLn('Right click at ', GetMouseX, ',', GetMouseY);
  end;

  DoneMouse;
end;
```

**Notes:**
- Requires MOUSE.COM or MOUSE.SYS loaded
- Coordinates auto-scaled to 320×200
- Call `UpdateMouse` once per frame before reading state

---

## Utility Units

### CONFIG.PAS

Configuration file management (INI format).

**Type:**
```pascal
type
  TConfig = record
    SoundCard: Byte;     { 0=None, 1=Adlib, 2=SoundBlaster }
    SBPort: Word;        { Base value (1=$210, 2=$220, etc.) }
    SBIRQ: Byte;
    SBDMA: Byte;
  end;
```

**Functions:**
```pascal
procedure LoadConfig(var Config: TConfig);
procedure SaveConfig(const Config: TConfig);
```

**Example:**
```pascal
var
  GameConfig: TConfig;

begin
  LoadConfig(GameConfig);  { Loads CONFIG.INI or sets defaults }

  if GameConfig.SoundCard = SoundCard_SoundBlaster then
    ResetDSP(GameConfig.SBPort, GameConfig.SBIRQ, GameConfig.SBDMA, 0);

  { ... }

  SaveConfig(GameConfig);
end;
```

---

### TEXTUI.PAS

Text mode UI library for menus and dialogs.

**Types:**
```pascal
type
  TMenu = record
    Title: string[40];
    FirstMenuItem: PMenuItem;
    Col, Row, Width: Integer;
    SelectedIndex: Integer;
  end;

  TMenuItem = record
    Text: string[40];
    Process: TMenuItemProc;
    NextMenuItem: PMenuItem;
    Disabled: Boolean;
  end;
```

**Key Functions:**
```pascal
{ Menu management }
function AddMenuItem(var Menu: TMenu; const Text: string;
                     Process: TMenuItemProc): PMenuItem;
function AddEmptyMenuItem(var Menu: TMenu): PMenuItem;
procedure RenderMenu(var Menu: TMenu; SelectedIndex: Integer; WithBox: Boolean);
procedure FreeMenu(var Menu: TMenu);
procedure SetMenu(var Menu: TMenu);
procedure StartMenu;
procedure StopMenu;

{ Dialogs }
function ShowMessage(Message, Info: string): Byte;
function ShowInput(Col, Row, Width: Integer; CurrentValue: string): string;

{ Text rendering }
procedure RenderText(Col, Row: Integer; s: string; Color: Byte);
procedure RenderTextBox(Col, Row: Integer; Width, Height: Word;
                        BoxColor, ShadowColor: Byte);
```

**Example:**
```pascal
{$F+}  { Far calls required for menu callbacks }
procedure NewGame;
begin
  StartNewGame;
  StopMenu;
end;

procedure QuitGame;
begin
  StopMenu;
end;
{$F-}

var
  MainMenu: TMenu;

begin
  MainMenu.Title := 'Main Menu';
  MainMenu.Col := 20;
  MainMenu.Row := 8;
  MainMenu.Width := 40;

  AddMenuItem(MainMenu, 'New Game', NewGame);
  AddMenuItem(MainMenu, 'Quit', QuitGame);

  SetMenu(MainMenu);
  StartMenu;

  FreeMenu(MainMenu);
end;
```

---

### RTCTIMER.PAS

Real-Time Clock interrupt timer (IRQ8) for high-resolution timing.

**Functions:**
```pascal
procedure InitRTC(Freq: Word);  { 2-8192 Hz, typical: 1024 Hz }
procedure DoneRTC;  { CRITICAL! }
function GetTimeSeconds: Real;
```

**Global:**
```pascal
var
  RTC_Ticks: LongInt;  { Increments at configured frequency }
```

**Example:**
```pascal
var
  LastTimeMS, CurrentTimeMS, DeltaTimeMS: LongInt;

begin
  InitRTC(1024);  { 1024 Hz }

  LastTimeMS := Round(GetTimeSeconds * 1000);

  while Running do
  begin
    CurrentTimeMS := Round(GetTimeSeconds * 1000);
    DeltaTimeMS := CurrentTimeMS - LastTimeMS;
    LastTimeMS := CurrentTimeMS;

    UpdateSprite(Player, DeltaTimeMS);  { Delta-time animation }
  end;

  DoneRTC;  { CRITICAL! }
end;
```

**Advantages:**
- IRQ8 (separate from IRQ0) - no conflict with HSC music
- High resolution (up to 8192 Hz)
- Frame-rate independent timing

---

### XMS.PAS

Extended Memory Specification (XMS) interface via HIMEM.SYS.

**Functions:**
```pascal
function XMSinstalled: Boolean;
function AllocXMS(KB: Word): Word;  { Returns handle }
procedure FreeXMS(Handle: Word);
procedure Mem2Xms(var Source; Handle: Word; Offset, Count: LongInt);
procedure Xms2Mem(Handle: Word; Offset: LongInt; var Dest; Count: LongInt);
function GetXMSmem: LongInt;  { Available XMS in KB }
```

**Example:**
```pascal
var
  XMSHandle: Word;
  BigData: array[0..32767] of Byte;

begin
  if not XMSinstalled then Halt;

  { Allocate 64KB in XMS }
  XMSHandle := AllocXMS(64);
  if XMSHandle = 0 then Halt;

  { Transfer to XMS }
  Mem2Xms(BigData, XMSHandle, 0, 32768);

  { Transfer back from XMS }
  Xms2Mem(XMSHandle, 0, BigData, 32768);

  FreeXMS(XMSHandle);
end;
```

**Use cases:**
- Store large assets (sprites, maps) in extended memory
- Save conventional memory (640KB limit)
- Used by SNDBANK.PAS

---

## Data Structure Units

### LINKLIST.PAS

Generic doubly-linked list container.

**Types:**
```pascal
type
  PListValue = Pointer;  { Generic pointer }
  TLinkedList = record
    First: PListEntry;
    Last: PListEntry;
    Count: Integer;
  end;
```

**Functions:**
```pascal
procedure ListInit(var List: TLinkedList);
function ListAdd(var List: TLinkedList; Value: PListValue): PListEntry;
procedure ListRemove(var List: TLinkedList; Entry: PListEntry);
function ListRemoveByValue(var List: TLinkedList; Value: PListValue): Boolean;
function ListContains(const List: TLinkedList; Value: PListValue): Boolean;
procedure ListFree(var List: TLinkedList);
```

**Example:**
```pascal
var
  EntityList: TLinkedList;
  Enemy: PEnemy;

begin
  ListInit(EntityList);

  New(Enemy);
  ListAdd(EntityList, Enemy);

  { Iterate }
  Current := EntityList.First;
  while Current <> nil do
  begin
    UpdateEnemy(PEnemy(Current^.Value));
    Current := Current^.Next;
  end;

  ListFree(EntityList);  { Frees entries, not values }
end;
```

---

### STRMAP.PAS

String-keyed dictionary (hash map).

**Type:**
```pascal
type
  TStringMap = object
    procedure Init;
    procedure Put(const Key: string; Value: Pointer);
    function Get(const Key: string): Pointer;
    function Contains(const Key: string): Boolean;
    procedure Remove(const Key: string);
    procedure Done;
  end;
```

**Example:**
```pascal
var
  ResourceMap: TStringMap;
  Image: PImage;

begin
  ResourceMap.Init;

  { Store resources }
  ResourceMap.Put('player', @PlayerSprite);
  ResourceMap.Put('enemy', @EnemySprite);

  { Retrieve }
  Image := ResourceMap.Get('player');
  if Image <> nil then
    PutImage(Image^, 100, 100, True, FB);

  ResourceMap.Done;
end;
```

---

### GENTYPES.PAS

Generic type definitions to avoid duplication.

**Types:**
```pascal
type
  { Pointer types }
  PWord = ^Word;
  PShortString = ^string;

  { Array types }
  TByteArray = array[0..65520] of Byte;
  PByteArray = ^TByteArray;

  TWordArray = array[0..32000] of Word;
  PWordArray = ^TWordArray;
```

**Usage:**
```pascal
uses GenTypes;

var
  Buffer: PByteArray;
  Indices: PWordArray;

begin
  GetMem(Buffer, 65520);
  GetMem(Indices, 64000);

  Buffer^[0] := 255;
  Indices^[0] := 1000;

  FreeMem(Buffer, 65520);
  FreeMem(Indices, 64000);
end;
```

---

## Tilemap Units

### TMXLOAD.PAS

TMX tilemap loader (Tiled Map Editor format).

**Functions:**
```pascal
procedure LoadTileMap(const FilePath: string; var TileMap: TTileMap;
                      ObjectGroupCallback: TObjectGroupProc);
function GetLoadTileMapError: string;
procedure FreeTileMap(var TileMap: TTileMap);
function IsBlockType(const TileMap: TTileMap; X, Y: Integer;
                     BlockType: Byte): Boolean;
```

**Example:**
```pascal
var
  Map: TTileMap;

{$F+}
procedure HandleObjects(const Name: string; Count: Integer;
                       const Objects: TObjectArray);
begin
  { Process object layer }
end;
{$F-}

begin
  LoadTileMap('MAP.TMX', Map, HandleObjects);

  { Check collision }
  if IsBlockType(Map, PlayerX, PlayerY, 1) then
    WriteLn('Collision!');

  FreeTileMap(Map);
end;
```

**Features:**
- Supports CSV encoding
- Up to 4 tilesets per map
- Layer merging (front/back)
- Blocks layer for collision
- Object groups via callback

---

### TMXDRAW.PAS

TMX tilemap rendering.

**Function:**
```pascal
procedure DrawTileMapLayer(const TileMap: TTileMap; Layer: Byte;
                          X, Y, Width, Height: Integer;
                          FrameBuffer: PFrameBuffer);
```

**Constants:**
```pascal
const
  TileMapLayer_Front = 0;
  TileMapLayer_Back = 1;
```

**Example:**
```pascal
var
  Map: TTileMap;
  CameraX, CameraY: Integer;

begin
  LoadTileMap('LEVEL1.TMX', Map, nil);

  while Running do
  begin
    { Draw background layer }
    DrawTileMapLayer(Map, TileMapLayer_Back,
                     CameraX, CameraY, 320, 200, BackBuffer);

    { Draw player }
    DrawSprite(Player, BackBuffer);

    { Draw foreground layer }
    DrawTileMapLayer(Map, TileMapLayer_Front,
                     CameraX, CameraY, 320, 200, BackBuffer);

    RenderFrameBuffer(BackBuffer);
  end;

  FreeTileMap(Map);
end;
```

---

## Additional Units

### STRUTIL.PAS

String utility functions.

**Functions:**
```pascal
function Trim(const S: string): string;
function StrToInt(const S: string): Integer;
function IntToStr(Value: Integer): string;
function HexStr(Value: Word; Digits: Byte): string;
function HexStrToWord(const S: string): Word;
```

---

### MINIXML.PAS

Minimal XML parser.

---

## Quick Start Examples

### Minimal Game

```pascal
uses VGA, Keyboard;

var
  FB: PFrameBuffer;
  Running: Boolean;

begin
  InitVGA;
  InitKeyboard;
  FB := CreateFrameBuffer;

  Running := True;
  while Running do
  begin
    ClearFrameBuffer(FB);

    { Game logic here }

    if IsKeyPressed(Key_Escape) then
      Running := False;

    RenderFrameBuffer(FB);
    ClearKeyPressed;
  end;

  FreeFrameBuffer(FB);
  DoneKeyboard;
  DoneVGA;
end.
```

---

### Game with Sound

```pascal
uses VGA, Keyboard, SBDSP, SndBank;

var
  Bank: TSoundBank;
  LaserID: Integer;

begin
  InitVGA;
  InitKeyboard;

  if ResetDSP(2, 5, 1, 0) then
  begin
    Bank.Init;
    LaserID := Bank.LoadSound('LASER.VOC');

    while Running do
    begin
      if IsKeyPressed(Key_Space) then
        Bank.PlaySound(LaserID);

      ClearKeyPressed;
    end;

    Bank.Done;
    UninstallHandler;
  end;

  DoneKeyboard;
  DoneVGA;
end.
```

---

## Unit Dependencies

```
VGA.PAS
├── PCX.PAS (requires VGA, GenTypes)
├── VGAPRINT.PAS (requires VGA)
├── SPRITE.PAS (requires VGA)
└── TMXDRAW.PAS (requires VGA, TMXLOAD, GenTypes)

SBDSP.PAS
├── SNDBANK.PAS (requires SBDSP, XMS)
└── PLAYHSC.PAS (independent, compatible with SBDSP)

KEYBOARD.PAS
├── TEXTUI.PAS (requires Keyboard)
└── MOUSE.PAS (independent)

TMXLOAD.PAS (requires VGA, GenTypes, MiniXML, StrUtil, LinkList)
CONFIG.PAS (requires StrUtil)
```

---

## See Also

- [VGA.md](VGA.md) - Complete VGA graphics API
- [SBDSP.md](SBDSP.md) - Complete Sound Blaster API
- [KEYBOARD.md](KEYBOARD.md) - Complete keyboard API
- [PCX.md](PCX.md) - PCX file format specification
- [HSC.md](HSC.md) - HSC music format specification
- [TILEMAP.md](TILEMAP.md) - TMX tilemap format and usage
