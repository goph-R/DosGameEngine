# CLAUDE.md

Guidance for Claude Code when working with this Turbo Pascal DOS multimedia engine.

## Project Overview

Retro DOS multimedia engine (Turbo Pascal 7.0, 1994-era). VGA Mode 13h graphics (320x200 256-color), HSC (Adlib/OPL2) music, demoscene-style programming with direct hardware access.

## DOS 8.3 Filename Convention

**CRITICAL**: All files MUST use 8.3 format (8 chars + 3 char extension), EXCEPT `DOCS\*` and `TOOLS\*`.
- Valid: A-Z, 0-9, underscore, hyphen only
- Compile batch files: Prefix with `C` (e.g., `CVGATEST.BAT` compiles `VGATEST.PAS`)
- Exceptions: `DOCS\*.md`, `TOOLS\*.*`, `.gitignore`, `README.md`, `CLAUDE.md`, `CHANGES.md`

## Changelog Management

The project maintains `CHANGES.md` (named to comply with 8.3 filename limits) following semantic versioning (major.minor.patch).

**When to update CHANGES.md:**
- When the user requests a new version to be released
- When significant features are added, fixed, or removed
- On user's explicit request to update the changelog

**Version numbering (Semantic Versioning):**
- **Major (x.0.0)**: Breaking changes, major rewrites, incompatible API changes
- **Minor (0.x.0)**: New features, backwards-compatible additions
- **Patch (0.0.x)**: Bug fixes, minor improvements, documentation updates

**Format for new versions (ALWAYS ADD AT TOP):**
```markdown
## [x.y.z] - YYYY-MM-DD

Brief summary of this version.

### Added
- New feature descriptions

### Changed
- Modified functionality descriptions

### Fixed
- Bug fix descriptions

### Removed
- Removed feature descriptions

---
```

**CRITICAL**: New versions MUST be added at the TOP of the file (after the header), not at the bottom. Newest versions always appear first.

## Folder Structure

```
D:\ENGINE\
├── UNITS\      - Core engine units (TPU output)
├── TESTS\      - Test programs + CxxxTEST.BAT scripts
├── SETUP\      - Setup utility + VOC loader
├── DATA\       - Assets (PCX, HSC, VOC)
├── DOCS\       - Format specs + DESIGN\ (game docs)
└── VENDOR\     - Third-party libraries (SBDSP, XMS)
```

## Building

**Requires**: Turbo Pascal 7.0 in DOS (DOSBox-X/FreeDOS/real DOS). AI cannot compile - only write code/batch files.
**Assembly code**: Turbo Pascal inline `asm` blocks. Avoid BP/SP registers, use Pascal variables.

### Compile (automated)
```bash
cd TESTS
CDRWTEST.BAT  CFNTTEST.BAT  CIMGTEST.BAT  CMAPTEST.BAT  CMOUTEST.BAT
CPCXTEST.BAT  CSNDTEST.BAT  CSPRTEST.BAT  CTMXTEST.BAT  CUITEST.BAT
CXMLTEST.BAT
cd ..\SETUP
CSETUP.BAT
```

### Manual compile
```bash
cd UNITS && tpc VGA.PAS && tpc PCX.PAS  # etc
cd ..\TESTS && tpc -U..\UNITS VGATEST.PAS
```

## Core Units (Condensed)

**GENTYPES.PAS** - Generic types
- Pointer types: PByte, PWord, PShortString
- Array types: TByteArray (0..65520), PByteArray, TWordArray (0..32000), PWordArray

**VGA.PAS** - Mode 13h graphics
- Types: TFrameBuffer, PFrameBuffer, TImage, PImage, TRectangle, TPalette, TRGBColor
- Init: InitVGA, CloseVGA, WaitForVSync
- Buffers: CreateFrameBuffer, GetScreenBuffer, ClearFrameBuffer, CopyFrameBuffer, CopyFrameBufferRect (REP MOVSW for 286 speed), RenderFrameBuffer, FreeFrameBuffer
- Palette: SetPalette, SetRGB, GetRGB, RotatePalette, LoadPalette
- Clipping: SetClipRectangle (set rendering bounds)
- Draw: DrawLine, DrawHLine, DrawVLine, DrawFillRect, DrawRect, GetImage, PutImage, PutImageRect, PutFlippedImage, PutFlippedImageRect, ClearImage, FreeImage
- Color 0 = transparent, auto-clip (0-319, 0-199)

**VGAPRINT.PAS** - Embedded 8x8 bitmap font, PrintText(x,y,text,color,fb)

**VGAFONT.PAS** - Variable-width font from PCX sprite sheet + XML
- Types: TFont (Image, Height, Padding, Chars, Loaded), PFont, TCharInfo
- Constants: MaxChars = 128
- LoadFont(xml,font), FreeFont(font), GetLoadFontError
- PrintFontText(x,y,text,font,fb), PrintFontTextCentered(x,y,text,font,fb), PrintFontTextRight(x,y,text,font,fb)
- GetTextWidth(text,font)
- **IMPORTANT**: Font.Padding is only for horizontal character spacing, NOT for vertical line spacing. Use Font.Height for vertical spacing between lines

**PCX.PAS** - PCX image loading and saving (ZSoft PCX v5, Aseprite/GIMP-compatible)
- Types: TPCXHeader
- LoadPCX(file,img), LoadPCXWithPalette(file,img,pal), LoadPCXToFrameBuffer(file,fb), GetLoadPCXError
- SavePCX(file,img,pal), GetSavePCXError
- LoadPCXToFrameBuffer: Optimized direct-to-framebuffer loading (no intermediate TImage)
- Simple RLE decoding, 256-color indexed, palette at EOF-768 bytes
- Handles scanline padding (BytesPerLine), auto-converts palette 0-255 → 0-63 for VGA
- Max 65520 bytes (320×204 for 320-width)

**BMP.PAS** - BMP image loading and saving (Windows BMP, 256-color indexed)
- Types: TBMPFileHeader, TBMPInfoHeader, TBMPRGBQuad
- LoadBMP(file,img), LoadBMPWithPalette(file,img,pal), GetLoadBMPError
- SaveBMP(file,img,pal), GetSaveBMPError
- Uncompressed BMP (BI_RGB), 8-bit indexed color, bottom-up scanlines
- Auto-converts BGRA palette to VGA RGB (0-63)
- Compatible with Windows Paint, Photoshop, GIMP

**SBDSP.PAS** - Sound Blaster driver (1995, Romesh Prakashpalan, VENDOR/SBDSP2B)
- Types: BaseSoundType, SoundType, RPDHeader, PhaseType (Mono/Stereo/Surround)
- Constants: Volume levels (SilentVol..QuadrupleVol), DMA types (EightBitDMA, SixteenBitDMA, HighSpeedDMA, etc.)
- Init: ResetDSP(Base,IRQ,DMA,HighDMA), InstallHandler, UninstallHandler
- Playback: PlaySound(BaseSoundType), PlaySoundRPD(file), PlaySoundDSK(file,freq,type)
- Control: DMAStop, DMAContinue, SpeakerOn, SpeakerOff
- Loading: LoadSoundRPD(file,sound,memalloc)
- Recording: RecordSoundRPD(file,freq), StopRecording
- DAC: WriteDAC(level), ReadDAC
- Globals: Playing (Boolean), Recording (Boolean), CurrentSound (SoundType)
- **CRITICAL**: Call UninstallHandler before exit. Base: 2=$220, IRQ: 5/7, DMA: 1

**VOCLOAD.PAS** - VOC file loader for SBDSP (SETUP\ folder, not UNITS\)
- PlayVOCFile(file), FreeVOCBuffer
- Don't wait `while Playing` if HSC music active (freezes)
- Used by SETUP utility; games should use SNDBANK instead

**XMS.PAS** - Extended memory (1992, KIV without Co) ✅ WORKING
- Types: EMMstruct (size, soh, soo, dsh, dso)
- Globals: XMSerror (Byte)
- Detection: XMSinstalled
- Memory: GetXMSmem(total,block), AllocXMS(KB), ReallocXMS(handle,KB), FreeXMS(handle)
- Transfer: MoveXMS(EMMstruct), Mem2Xms(buf,count,handle,offset), Xms2Mem(handle,offset,buf,count)
- Locking: LockBlock(handle,address), UnlockBlock(handle)
- Info: GetXMShandleInfo(handle,lockcount,freehandles,size), XMSerrorMSG(error)
- HMA: RequestHMA(mem), ReleaseHMA
- **CRITICAL**: When handle=0 in EMMstruct, offset = pointer (seg:ofs), NOT linear address

**SNDBANK.PAS** - XMS sound bank for SBDSP (2025)
- Types: TSoundBank (object), TSoundInfo
- Constants: MaxSounds = 32
- TSoundBank methods: Init, LoadSound(file)→ID, PlaySound(ID), StopSound, Done
- DMA-safe allocation (no 64KB boundary crossing)
- Requires HIMEM.SYS + SBDSP.ResetDSP

**PLAYHSC.PAS** - HSC music player (1994, GLAMOROUS RAY)
- HSC_obj: Init(0), LoadFile/LoadMem, Start/Stop/Fade, Done
- Hooks IRQ0 timer. **CRITICAL**: Call Done before exit
- **WARNING**: Don't read PIT Timer 0 or hook IRQ0 while HSC active. Use RTCTimer.PAS (IRQ8)

**RTCTIMER.PAS** - RTC high-res timer (2025, IRQ8)
- Constants: CMOS_PORT ($70), CMOS_DATA ($71), PIC1_OCW1 ($21), PIC2_OCW1 ($A1)
- Globals: RTC_Ticks (LongInt), RTC_Freq_Hz (Word), OldInt70 (Pointer)
- InitRTC(Freq), DoneRTC, GetTimeSeconds
- IRQ8 on slave PIC - no conflict with HSC (IRQ0)
- **CRITICAL**: Call DoneRTC before exit. NEVER mask IRQ2 (cascade)

**DELAY.PAS** - CRT-free delay routine (2025)
- DelayMS(Milliseconds)
- Uses BIOS timer tick at $0040:$006C (~18.2 Hz)
- Fixes Runtime Error 200 (CRT unit bug on fast CPUs >200 MHz)
- No initialization required, always available

**KEYBOARD.PAS** - INT 9h keyboard handler
- InitKeyboard, DoneKeyboard, IsKeyDown(scancode), IsKeyPressed(scancode), ClearKeyPressed
- Constants: Key_A..Key_Z, Key_0..Key_9, Key_F1..Key_F12
- Arrow keys: Key_Up/Down/Left/Right
- Special: Key_Escape, Key_Enter, Key_Space, Key_Backspace, Key_Tab
- Extended: Key_Home/End/PgUp/PgDn/Insert/Delete
- Modifiers: Key_LShift/RShift/LCtrl/LAlt/CapsLock
- Punctuation: Key_Minus/Equals/LBracket/RBracket/Semicolon/Quote/Backquote/Backslash/Comma/Period/Slash
- CharMapNormal, CharMapShift: Scancode→character lookup tables (array[0..127])
- **CRITICAL**: Call ClearKeyPressed at end of game loop, DoneKeyboard before exit

**MOUSE.PAS** - INT 33h mouse driver (requires MOUSE.COM/MOUSE.SYS)
- Constants: MouseButton_Left/Right/Middle ($01/$02/$04)
- Init: InitMouse, DoneMouse
- Visibility: ShowMouse, HideMouse
- Input: UpdateMouse, GetMouseX, GetMouseY, GetMouseButtons, IsMouseButtonDown(btn)
- Range: SetMouseRangeX(minx,maxx), SetMouseRangeY(miny,maxy)
- **CRITICAL**: Call UpdateMouse once per frame

**SPRITE.PAS** - Delta-time sprite animation
- Constants: SpritePlayType_Forward/PingPong/Once (0/1/2), MaxSpriteFrames = 64
- Types: TSprite (PImage, Frames, FrameCount, Width, Height, Duration (seconds), PlayType), PSprite
- TSpriteInstance (Sprite, X, Y, FlipX, FlipY, CurrentTime, Hidden, PlayBackward), PSpriteInstance
- UpdateSprite(instance,deltatime), DrawSprite(instance,fb)

**RESMAN.PAS** - Resource manager (2025)
- TResourceManager: Centralized asset loading from XML manifest
- Types: ResType_Music/Sound/Image/Font/Sprite/Palette
- Methods: Init(lazy), LoadFromXML(file), GetImage/Font/Sprite/Sound/Music/Palette, Done
- Features: Lazy/eager loading, XML-relative paths, dependency resolution, name-based lookup
- See DOCS\RESMAN.md for XML format

**GAMEUNIT.PAS** - Game framework (2025)
- TGame: Main game object (Init, Start, Run, Done, PlayMusic, SetNextScreen, GetScreen, AddScreen)
- TScreen: Abstract screen/state base (Init, Done, Update, Show, Hide, PostInit)
- Auto-initializes: VGA, Config, ResMan, RTC, Keyboard, Mouse, SBDSP, framebuffers
- Screen management via ScreenMap, deferred screen switching, delta-time game loop
- **No global Game variable** - games extend TGame and provide their own global instance
- **PostInit**: Called AFTER VGA initialized - use for SetPalette, RenderFrameBuffer, etc. NOT for loading resources
- **Resource loading**: Load game-specific resources in TGame.Start override, NOT in TScreen.PostInit
- Exit handler: Uses module-level CurrentGame pointer (set in Init, cleared in Done)
- See DOCS\GAMEUNIT.md for architecture

**DRECT.PAS** - Dirty rectangle system (2025)
- Optimized rendering for partial screen updates
- AddDirtyRect(rect), FlushDirtyRects(backbuffer), ClearDirtyRects, GetDirtyCount
- Max 256 rectangles, copies only changed regions to screen

**MINIXML.PAS** - Lightweight XML parser
- Types: PXMLNode, TXMLNode (Name, TextBuf, TextLen, TextCap, AttrKeys, AttrValues, AttrCount, FirstChild, NextSibling, Parent)
- Constants: XML_MaxNameLength = 20, XML_MaxAttrsCount = 8
- Loading: XMLLoadFile(file,root), GetLoadXMLError
- Saving: XMLSaveFile(file,root), GetSaveXMLError
- Query: XMLAttr(node,name), XMLHasAttr(node,name), XMLGetText(node)
- Navigation: XMLFirstChild(node,name), XMLNextSibling(node,name), XMLCountChildren(node,name)
- Data: XMLReadWordArray(node,arr,count)
- Building: XMLInitNode(node), XMLAddChild(parent,child), XMLSetAttr(node,key,value), XMLSetText(node,text), XMLAppendText(node,text), XMLAddChildElement(parent,name)
- Cleanup: XMLFreeTree(node)

**STRMAP.PAS** - String→pointer hash map (256 entries)
- Constants: MAX_ENTRIES = 256
- Types: TStringMap, TMapEntry (Key, Value, Used), PMapEntry, PMapValue
- MapInit(map), MapPut(map,key,value), MapGet(map,key), MapContains(map,key), MapRemove(map,key), MapFree(map)

**STRUTIL.PAS** - String utilities
- StrToInt(s), StrToReal(s), IntToStr(value), Trim(s), HexStr(value,digits), HexStrToWord(s)

**LINKLIST.PAS** - Doubly-linked list
- Types: TLinkedList (First, Last, Count), TListEntry (Next, Prev, Value), PListEntry, PListValue
- ListInit(list), ListAdd(list,value), ListRemove(list,entry), ListRemoveByValue(list,value), ListContains(list,value), ListFree(list)

**CONFIG.PAS** - CONFIG.INI management
- Types: TConfig (SoundCard, SBPort, SBIRQ, SBDMA, UseMouse)
- Constants: GameTitle, GameVersion, TileSize
- Sound card types: SoundCard_None/Adlib/SoundBlaster (0/1/2), SoundCardNames array
- SBPort values: 2=$220, 4=$240, 6=$260, 8=$280
- LoadConfig(config,file), SaveConfig(config,file)

**TEXTUI.PAS** - Text mode UI ($B800:0000)
- Constants: ScreenCols = 80, ScreenRows = 25
- Types: TMenu (Title, FirstMenuItem, Col, Row, Width, SelectedIndex), PMenu
- TMenuItem (Text, Process, NextMenuItem, Disabled), PMenuItem, TMenuItemProc
- Globals: VidMem (array at $B800:0000)
- Cursor: HideTextCursor, ShowTextCursor, SetTextCursorPosition(row,col)
- Text: PutCharAt(col,row,ch,color), RenderText(col,row,text,color), RenderCenterText(row,text,color), RenderEmptyLine(row,color), GetColumnForCenter(text)
- Box: RenderTextBox(col,row,w,h,boxcolor,shadowcolor), RenderTextBackground
- Menu: AddMenuItem(menu,text,proc), AddEmptyMenuItem(menu), CountMenuItems(menu), GetMenuItem(menu,idx), RenderMenu(menu,idx,withbox), FreeMenu(menu), SetMenu(menu), StartMenu, StopMenu
- Dialog: ShowMessage(msg,info), ShowMessageNoWait(msg,info), ShowInput(col,row,width,currentvalue)
- **CRITICAL**: Menu callbacks need `{$F+}` (far calls)

**TMXLOAD.PAS** - TMX tilemap loader (Tiled Map Editor)
- Constants: TileMap_MaxTileSets = 4, TileMapLayer_Front/Back (0/1)
- Types: TTileSet (FirstGID, TileWidth, TileHeight, Columns, Image)
- TTileMap (Width, Height, TileSetCount, TileSets[0..3], Layers[0..1], BlocksLayer, BlocksTilesetFirstGID)
- TObjectGroupProc (callback for objectgroups)
- LoadTileMap(file,map,objgroup_callback), FreeTileMap(map), GetLoadTileMapError, IsBlockType(map,x,y,type)
- Merges layers: before 1st objectgroup→Front (0), after→Back (1)
- Blocks layer: custom `blocks` property + "Blocks" tileset → BlocksLayer (PByteArray)
- CSV encoding only, .png→.pcx auto-conversion, max 4 tilesets

**TMXDRAW.PAS** - TMX rendering
- DrawTileMapLayer(map,layer,x,y,w,h,fb)
- Viewport rendering, auto-clip, skips tile ID=0

**VGAUI.PAS** - VGA Mode 13h UI system (2025)
- Event handlers (Delphi-style): TKeyPressEvent = procedure(Sender: PWidget; KeyCode: Byte); TMouseEvent = procedure(Sender: PWidget; X, Y: Integer; Button: Byte); TFocusEvent = procedure(Sender: PWidget)
- TUIStyle object: HighColor, NormalColor, LowColor, FocusColor; Init(high,normal,low,focus), RenderPanel(rect,pressed,fb) virtual
- TWidget object (base): Rectangle, Visible, Enabled, Focused, NeedsRedraw, Tag
  - Event callbacks: OnKeyPress, OnMouseDown, OnMouseUp, OnMouseMove, OnFocus, OnBlur (procedure pointers)
  - Init(x,y,w,h), MarkDirty, SetVisible(value), SetEnabled(value)
  - Do* virtual methods: DoKeyPress(keycode), DoMouseDown/Up/Move(x,y,button), DoFocus, DoBlur (override to intercept events)
  - Update(dt) virtual, Render(fb,style) virtual, RenderFocusRectangle(fb,style), Done virtual
- TLabel(TWidget): Text, Font; Init(x,y,w,h,text,font), SetText(text), Render virtual, Done virtual
- TButton(TWidget): Text, Font, Pressed; Init(x,y,w,h,text,font), SetText(text), DoKeyPress/DoMouseDown/DoBlur virtual, Render virtual, Done virtual
- TCheckbox(TWidget): Text, Font, Image, Checked; Init(x,y,w,h,text,font,image), SetText(text), SetChecked(value), IsChecked, DoKeyPress/DoMouseDown virtual, Render virtual, Done virtual
- TLineEdit(TWidget): Text, Font, MaxLength, CursorVisible, CursorTimer; Init(x,y,w,h,maxlen,font), SetText(text), GetText, DoKeyPress/DoMouseDown virtual, Update virtual, Render virtual, Done virtual
- TUIManager: Init(fb,bg), AddWidget, RemoveWidget, SetFocus, Update(dt), RenderDirty, Run(updateproc,vsync), Stop, Done
- **CRITICAL**: Use constructor/destructor syntax `New(Button, Init(...))` and `Dispose(Button, Done)` for VMT initialization
- **CRITICAL**: Event handlers need `{$F+}` (far calls). Assign to OnKeyPress/OnMouseDown/etc fields
- Keyboard + mouse navigation (Tab, arrows, Enter, Space, click), Delphi-style event architecture
- Integrates with LINKLIST, VGAFONT, KEYBOARD, MOUSE, VGA, DRECT, RTCTIMER

**LOGGER.PAS** - File-based debug logger (2025)
- Constants: LogLevelError/Warning/Info/Debug (0/1/2/3)
- InitLogger(path,level), CloseLogger
- LogError(msg), LogWarning(msg), LogInfo(msg), LogDebug(msg)
- **WARNING**: Do NOT use in render loops - file I/O causes stack overflow at 60 FPS
- Safe for startup/shutdown logging only

**MD5.PAS** - MD5 cryptographic hash (1992, RFC 1321)
- Types: TMD5Digest (array[0..15] of Byte), TMD5Context
- Core: MD5Init(ctx), MD5Update(ctx,buf,len), MD5Final(digest,ctx)
- Convenience: MD5String(s), MD5File(path,digest), MD5DigestToHex(digest), MD5DigestEqual(a,b)
- 128-bit hash, returns 32-char hex string
- Use cases: Asset verification, save game checksums, file integrity
- Performance: Instant for strings, ~0.5-1s for full-screen images on 286
- Era-appropriate (1992), period-accurate for retro engine

## File Formats

**PCX**: ZSoft PCX v5 RLE-compressed 256-color (Aseprite/GIMP-compatible, palette 0-255 auto-converted to 0-63)
**BMP**: Windows BMP uncompressed 256-color (Paint/Photoshop/GIMP-compatible, BGRA palette auto-converted to VGA RGB 0-63)
**HSC**: Adlib OPL2 tracker (embeddable via BINOBJ.EXE→.OBJ)
**VOC**: Creative Voice File (8-bit PCM, 11025/22050 Hz mono)

## Creating PCX Files

**Aseprite**: File → Export → .pcx (8-bit indexed color mode)
**GIMP**: Image → Mode → Indexed (256 colors) → Export as PCX
**Photoshop**: Image → Mode → Indexed Color → Save As PCX (8 bits/pixel)

## Creating BMP Files

**Windows Paint**: Image → Resize → 256 colors → Save As (24-bit BMP, auto-converts to 8-bit)
**GIMP**: Image → Mode → Indexed (256 colors) → Export as BMP (8 bits, no color space)
**Photoshop**: Image → Mode → Indexed Color → Save As BMP (8 bits/pixel, Windows format)

## Creating VOC Files

**Audacity**: Import → Mix to Mono → Resample 11025Hz → Export (VOC, Unsigned 8-bit PCM)
**FFmpeg**: `ffmpeg -i input.wav -ar 11025 -ac 1 -acodec pcm_u8 output.voc`

## Development Patterns

**Graphics**:
```pascal
InitVGA; fb := CreateFrameBuffer;
// Draw to fb^...
RenderFrameBuffer(fb); CloseVGA; FreeFrameBuffer(fb);
```

**Music (HSC)**:
```pascal
Music.Init(0); Music.LoadFile('X.HSC'); Music.Start; Music.Done;
```

**Sound (simple)**:
```pascal
ResetDSP(2,5,1,0); PlayVOCFile('X.VOC'); UninstallHandler; FreeVOCBuffer;
```

**Sound (bank)**:
```pascal
ResetDSP(2,5,1,0); Bank.Init; ID:=Bank.LoadSound('X.VOC'); Bank.PlaySound(ID); Bank.Done; UninstallHandler;
```

**Keyboard**:
```pascal
InitKeyboard;
while run do
  if IsKeyDown(Key_W) then MoveUp;
  if IsKeyPressed(Key_Space) then Fire;
  ClearKeyPressed;
DoneKeyboard;
```

**Sprites (with DeltaTime)**:
```pascal
var Last, Cur, Delta: Real;
InitRTC(1024); Last := GetTimeSeconds;
while run do
  Cur := GetTimeSeconds; Delta := Cur - Last; Last := Cur;
  UpdateSprite(Spr, Delta); DrawSprite(Spr, fb);
DoneRTC;
```

**UI (VGAUI)**:
```pascal
{$F+}
procedure OnButtonClick(Sender: PWidget; KeyCode: Byte);
begin
  if (KeyCode = Key_Enter) or (KeyCode = Key_Space) then
    { Handle click }
end;
{$F-}

var Last, Cur, Delta: Real;
UI.Init(BackBuffer, Background); Style.Init(15,7,8,14); UI.SetStyle(@Style);
New(Button, Init(x,y,w,h,'Click',@Font)); { MUST use constructor syntax! }
Button^.OnKeyPress := @OnButtonClick; UI.AddWidget(Button);
InitRTC(1024); Last := GetTimeSeconds;
while run do
  Cur := GetTimeSeconds; Delta := Cur - Last; Last := Cur;
  UI.Update(Delta); UI.RenderDirty; ClearKeyPressed;
UI.RemoveWidget(Button); Dispose(Button, Done); UI.Done; DoneRTC;
```

**Resources (RESMAN)**:
```pascal
ResMan.Init(True); { Lazy loading }
ResMan.LoadFromXML('DATA\RES.XML');
img := ResMan.GetImage('player'); { Auto-loads on first access }
spr := ResMan.GetSprite('walk'); { Resolves image dependency }
id := ResMan.GetSound('explode');
ResMan.Done; { Cleanup all resources }
```

**Game Framework (GAMEUNIT)**:
```pascal
{ GLOBALS.PAS - Extend TGame with game-specific resources }
unit Globals;
interface
uses GameUnit, VGA, VGAFont;

type
  TMyGame = object(TGame)
    { Game-specific resources }
    PlayerSprite: PImage;
    TitleFont: PFont;

    constructor Init(const ConfigIniPath: String; const ResXmlPath: String);
    destructor Done; virtual;
    procedure Start; virtual;
  end;

var
  Game: TMyGame;  { Global game instance }

implementation

constructor TMyGame.Init(const ConfigIniPath: String; const ResXmlPath: String);
begin
  inherited Init(ConfigIniPath, ResXmlPath);
end;

destructor TMyGame.Done;
begin
  inherited Done;
end;

procedure TMyGame.Start;
begin
  inherited Start;  { Initialize framework }
  { Load game-specific resources here }
  PlayerSprite := ResMan.GetImage('player');
  TitleFont := ResMan.GetFont('title');
end;

end.

{ MAIN.PAS - Define screens and run game }
program Main;
uses Globals;

type
  PMenuScreen = ^TMenuScreen;
  TMenuScreen = object(TScreen)
    procedure Update(DT: Real); virtual;
  end;

var Menu: PMenuScreen;

begin
  Game.Init('CONFIG.INI', 'DATA\RES.XML');
  New(Menu, Init); Game.AddScreen('menu', Menu);
  Game.Start; { Initialize subsystems + load resources }
  Game.SetNextScreen('menu'); { Queue initial screen }
  Game.Run; { Auto delta-time loop }
  Game.Done;
end.
```

**Dirty Rectangles (DRECT)**:
```pascal
{ In render code }
AddDirtyRect(ButtonRect);
AddDirtyRect(SpriteRect);
FlushDirtyRects(BackBuffer); { Copy only changed regions to screen }
ClearDirtyRects; { Prepare for next frame }
```

**MD5 Hashing**:
```pascal
{ Quick string hash }
hash := MD5String('hello world');
WriteLn('Hash: ', hash);

{ File integrity check }
if MD5File('DATA\FONT.PCX', digest) then
  WriteLn('Hash: ', MD5DigestToHex(digest));

{ Incremental hashing }
MD5Init(ctx);
MD5Update(ctx, @buffer1, len1);
MD5Update(ctx, @buffer2, len2);
MD5Final(digest, ctx);
```

## Common Pitfalls

1. **Interrupts**: Always call Done/Unhook before exit (HSC_obj.Done, DoneKeyboard, DoneRTC, UninstallHandler) or system hangs
2. **IRQ2**: NEVER mask IRQ2 (slave PIC cascade) - disables all IRQ8-15 (mouse, etc.)
3. **CRT Unit**: NEVER use Crt unit - causes Runtime Error 200 on fast CPUs (>200 MHz). Use Delay.DelayMS instead of Crt.Delay, Keyboard.IsKeyPressed instead of Crt.KeyPressed
4. **ExitProc**: Install handler to unhook on Ctrl+C/Break
5. **Sound buffers**: Don't free while `Playing=True` (DMA read errors)
6. **HSC + Sound**: Don't `while Playing` loop with HSC active (freezes)
7. **VGA cleanup**: Call CloseVGA before exit
8. **Memory**: Match Create/Free pairs
9. **Keyboard**: ClearKeyPressed at END of loop
10. **DMA**: SBDSP handles 64KB boundaries automatically
11. **Palette**: PCX palette values 0-255 auto-converted to 0-63 for VGA DAC
12. **Paths**: DOS 8.3, backslashes
13. **IRQ0 conflict**: Never read PIT Timer 0 or hook IRQ0 with HSC active. Use RTCTimer (IRQ8) - completely isolated
14. **VMT initialization**: Objects with virtual methods MUST use `New(Ptr, Constructor)` syntax, not `New(Ptr); Ptr^.Init`
15. **VGA clipping**: DrawFillRect includes clipping; widgets assume screen bounds (0-319, 0-199)
16. **Logging**: LOGGER.PAS is for startup/shutdown only - file I/O in render loops causes Runtime Error 202 (stack overflow)
17. **DeltaTime convention**: Use Real for DeltaTime in seconds. CurrentTime/LastTime should be Real (from GetTimeSeconds). Calculate DeltaTime as `CurrentTime - LastTime`. InitRTC(1024) provides millisecond precision via RTC_Ticks for accurate sub-second timing
18. **ReadKey conflict**: NEVER use ReadKey or other CRT input functions when KEYBOARD.PAS unit is active - it hooks INT 9h and manages keyboard state. Use IsKeyPressed/IsKeyDown instead. For debugging, use LOGGER.PAS instead of WriteLn/ReadKey
19. **Shift overflow**: Integer literals are 16-bit by default. Large shifts like `320 shl 10` overflow to 0. Cast to LongInt first: `LongInt(320) shl 10` for fixed-point math
20. **Record return types**: NEVER use records as function return types - Turbo Pascal 7.0 copies the entire structure on return. Use a procedure with `var` parameter (usually last) instead. Example: `procedure MergeRects(R1, R2: TRect; var Result: TRect)` instead of `function MergeRects(R1, R2: TRect): TRect`

## Technical Constraints

- DOS real mode 16-bit x86, Turbo Pascal 7.0
- VGA Mode 13h (320x200 256-color)
- Adlib/OPL2 (HSC), Sound Blaster (VOC, DMA 0-3)
- Memory: 640KB conventional, XMS via HIMEM.SYS ✅
- Single-threaded, interrupt-driven audio
- **Performance**: Targets 286 CPUs (8-25 MHz). Avoid full framebuffer copies/renders unless absolutely necessary. Use dirty rectangles (DRECT.PAS) and viewport rendering for optimal performance

## Vendor

**VENDOR/SBDSP2B/**: SBDSP v2.0β (1995, Romesh Prakashpalan)
- Includes VOC2RPD.EXE, WAV2RPD.EXE, TESTDSP.PAS, SBDSP.TXT
