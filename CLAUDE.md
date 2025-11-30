# CLAUDE.md

Guidance for Claude Code when working with this Turbo Pascal DOS multimedia engine.

## Project Overview

Retro DOS multimedia engine (Turbo Pascal 7.0, 1994-era). VGA Mode 13h graphics (320x200 256-color), HSC (Adlib/OPL2) music, demoscene-style programming with direct hardware access.

## DOS 8.3 Filename Convention

**CRITICAL**: All files MUST use 8.3 format (8 chars + 3 char extension), EXCEPT `DOCS\*` and `TOOLS\*`.
- Valid: A-Z, 0-9, underscore, hyphen only
- Compile batch files: Prefix with `C` (e.g., `CVGATEST.BAT` compiles `VGATEST.PAS`)
- Exceptions: `DOCS\*.md`, `TOOLS\*.*`, `.gitignore`, `README.md`, `CLAUDE.md`

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
CVGATEST.BAT  CDRWTEST.BAT  CFNTTEST.BAT  CSNDTEST.BAT  CIMGTEST.BAT
CTMXTEST.BAT  CSPRTEST.BAT  CMOUTEST.BAT  CMAPTEST.BAT  CXMLTEST.BAT
CPCXTEST.BAT  CIMFTEST.BAT  CUITEST.BAT
cd ..\SETUP
CSETUP.BAT
```

### Manual compile
```bash
cd UNITS && tpc VGA.PAS && tpc PCXLOAD.PAS  # etc
cd ..\TESTS && tpc -U..\UNITS VGATEST.PAS
```

## Core Units (Condensed)

**GENTYPES.PAS** - Generic types (PWord, PShortString, TByteArray, PByteArray, TWordArray, PWordArray)

**VGA.PAS** - Mode 13h graphics
- Types: TFrameBuffer, PFrameBuffer, TImage, PImage, TRectangle, TPalette, TRGBColor
- Init: InitVGA, CloseVGA, WaitForVSync
- Buffers: CreateFrameBuffer, GetScreenBuffer, ClearFrameBuffer, CopyFrameBuffer, CopyFrameBufferRect (REP MOVSW for 286 speed), RenderFrameBuffer, FreeFrameBuffer
- Palette: SetPalette, RotatePalette, LoadPalette
- Draw: DrawLine, GetImage, PutImage, PutImageRect, PutFlippedImage, PutFlippedImageRect, ClearImage, FreeImage
- Color 0 = transparent, auto-clip (0-319, 0-199)

**VGAPRINT.PAS** - Embedded 8x8 bitmap font, PrintText(x,y,text,color,fb)

**VGAFONT.PAS** - Variable-width font from PCX sprite sheet + XML
- LoadFont(xml,img,font), PrintFontText(x,y,text,font,fb), GetLoadFontError, FreeFont

**PCXLOAD.PAS** - PCX image loader (ZSoft PCX v5, Aseprite/GIMP-compatible)
- LoadPCX(file,img), LoadPCXWithPalette(file,img,pal), GetLastErrorMessage
- Simple RLE decoding, 256-color indexed, palette at EOF-768 bytes
- Handles scanline padding (BytesPerLine), auto-converts palette 0-255 → 0-63 for VGA
- Max 65520 bytes (320×204 for 320-width)

**SBDSP.PAS** - Sound Blaster driver (1995, Romesh Prakashpalan, VENDOR/SBDSP2B)
- ResetDSP(Base,IRQ,DMA,HighDMA), PlaySound(BaseSoundType), PlaySoundRPD(file), DMAStop/Continue, SpeakerOn/Off
- InstallHandler/UninstallHandler, global `Playing` flag
- **CRITICAL**: Call UninstallHandler before exit. Base: 2=$220, IRQ: 5/7, DMA: 1

**VOCLOAD.PAS** - VOC file loader for SBDSP
- PlayVOCFile(file), FreeVOCBuffer
- Don't wait `while Playing` if HSC music active (freezes)

**XMS.PAS** - Extended memory (1992, KIV without Co) ✅ WORKING
- XMSinstalled, AllocXMS(KB), FreeXMS(Handle), Mem2Xms/Xms2Mem, MoveXMS, GetXMSmem
- **CRITICAL**: When handle=0 in EMMstruct, offset = pointer (seg:ofs), NOT linear address

**SNDBANK.PAS** - XMS sound bank for SBDSP (2025)
- TSoundBank: Init, LoadSound(file)→ID, PlaySound(ID), StopSound, Done
- DMA-safe allocation (no 64KB boundary crossing)
- Requires HIMEM.SYS + SBDSP.ResetDSP

**PLAYHSC.PAS** - HSC music player (1994, GLAMOROUS RAY)
- HSC_obj: Init(0), LoadFile/LoadMem, Start/Stop/Fade, Done
- Hooks IRQ0 timer. **CRITICAL**: Call Done before exit
- **WARNING**: Don't read PIT Timer 0 or hook IRQ0 while HSC active. Use RTCTimer.PAS (IRQ8)

**PLAYIMF.PAS** - IMF music player (Id Music Format, 2025)
- IMF_obj: Init(rate), LoadFile/LoadMem, Start/Stop, Poll, Done
- Polling-based (no interrupts), safe with HSC/RTC/SBDSP
- Rates: 560 Hz (Keen), 700 Hz (Wolf3D). Call Poll every frame!
- Games: Wolfenstein 3D, Commander Keen 4-6, Blake Stone
- **CRITICAL**: Call Poll in main loop, Done before exit. NO interrupt conflicts

**RTCTIMER.PAS** - RTC high-res timer (2025, IRQ8)
- InitRTC(Freq), DoneRTC, GetTimeSeconds, RTC_Ticks
- IRQ8 on slave PIC - no conflict with HSC (IRQ0)
- **CRITICAL**: Call DoneRTC before exit. NEVER mask IRQ2 (cascade)

**KEYBOARD.PAS** - INT 9h keyboard handler
- InitKeyboard, DoneKeyboard, IsKeyDown(scancode), IsKeyPressed(scancode), ClearKeyPressed
- Constants: Key_A..Key_Z, Key_0..Key_9, Key_F1..Key_F12, Key_Up/Down/Left/Right, Key_Escape/Enter/Space
- **CRITICAL**: Call ClearKeyPressed at end of game loop, DoneKeyboard before exit

**MOUSE.PAS** - INT 33h mouse driver (requires MOUSE.COM/MOUSE.SYS)
- InitMouse, ShowMouse/HideMouse, UpdateMouse, GetMouseX/Y, GetMouseButtons, IsMouseButtonDown(btn), DoneMouse
- Constants: MouseButton_Left/Right/Middle ($01/$02/$04)
- Call UpdateMouse once per frame

**SPRITE.PAS** - Delta-time sprite animation
- TSprite (shared): Image, FrameCount, Duration (ms), PlayType (Forward/PingPong/Once), Frames[0..63]
- TSpriteInstance (per-entity): Sprite, X, Y, FlipX/Y, CurrentTime, Hidden
- UpdateSprite(instance,deltatime), DrawSprite(instance,fb)

**ENTITIES.PAS** - Entity/physics system
- TEntity: X,Y (fixed-point LongInt×256), Width, Height, AlignH/V, SpriteInstance, Physics, Parent
- Methods: Init, GetGlobalX/Y, GetTop/Right/Bottom/Left, PreUpdate/Update/Draw
- TPhysics: velocity, acceleration, gravity, Update(entity,dt)

**MINIXML.PAS** - Lightweight XML parser
- XMLLoadFile(file,root), XMLFreeTree(node)
- XMLAttr/XMLHasAttr/XMLGetText, XMLFirstChild/NextSibling/CountChildren, XMLReadWordArray

**STRMAP.PAS** - String→pointer hash map (256 entries)
- MapInit/Put/Get/Contains/Remove/Free

**STRUTIL.PAS** - String utilities
- StrToInt, IntToStr, Trim, HexStr, HexStrToWord

**LINKLIST.PAS** - Doubly-linked list
- ListInit/Add/Remove/RemoveByValue/Contains/Free

**CONFIG.PAS** - CONFIG.INI management
- LoadConfig/SaveConfig, TConfig record
- Constants: SoundCard_None/Adlib/SoundBlaster (0/1/2), GameTitle/Version, TileSize
- SBPort: 2=$220, 4=$240, 6=$260, 8=$280

**TEXTUI.PAS** - Text mode UI ($B800:0000)
- HideCursor/ShowCursor, PutCharAt, RenderText/CenterText/EmptyLine/Box/Background
- TMenu/TMenuItem: AddMenuItem/EmptyMenuItem, RenderMenu, RunMenu, FreeMenu, ShowMessage
- Menu callbacks need `{$F+}` (far calls)

**TMXLOAD.PAS** - TMX tilemap loader (Tiled Map Editor)
- LoadTileMap(file,map,objgroup_callback), FreeTileMap, GetLoadTileMapError, IsBlockType(x,y,type)
- Merges layers: before 1st objectgroup→Front (0), after→Back (1)
- Blocks layer: custom `blocks` property + "Blocks" tileset → BlocksLayer (PByteArray)
- CSV encoding only, .png→.pcx auto-conversion, max 4 tilesets

**TMXDRAW.PAS** - TMX rendering
- DrawTileMapLayer(map,layer,x,y,w,h,fb)
- Viewport rendering, auto-clip, skips tile ID=0

**VGAUI.PAS** - VGA Mode 13h UI system (2025)
- TUIStyle: Theme/panel rendering (Init, RenderPanel virtual method)
- TWidget: Base object (Init constructor, HandleEvent/Render virtual, Done destructor)
- TLabel: Non-interactive text display
- TButton: Clickable button (Enter/Space activation)
- TCheckbox: Toggle control (Space to toggle, sprite sheet image)
- TLineEdit: Text input (typing, backspace, max length, cursor blink)
- TUIManager: Widget manager (AddWidget, SetFocus, FocusNext/Prev, HandleEvent, RenderAll)
- **CRITICAL**: Use constructor/destructor syntax `New(Button, Init(...))` and `Dispose(Button, Done)` for VMT initialization
- **NOTE**: Widgets use simplified rendering (DrawFillRect + DrawRect) instead of Style.RenderPanel for stability
- Keyboard-only navigation (Tab, Enter, Space), event-driven architecture
- Integrates with LINKLIST, VGAFONT, KEYBOARD, VGA

**LOGGER.PAS** - File-based debug logger (2025)
- InitLogger(path,level), CloseLogger
- LogError/Warning/Info/Debug with log levels 0-3
- **WARNING**: Do NOT use in render loops - file I/O causes stack overflow at 60 FPS
- Safe for startup/shutdown logging only

## File Formats

**PCX**: ZSoft PCX v5 RLE-compressed 256-color (Aseprite/GIMP-compatible, palette 0-255 auto-converted to 0-63)
**HSC**: Adlib OPL2 tracker (embeddable via BINOBJ.EXE→.OBJ)
**IMF**: Id Music Format OPL2 (Wolfenstein 3D 700Hz, Keen 4-6 560Hz, polling-based player)
**VOC**: Creative Voice File (8-bit PCM, 11025/22050 Hz mono)

## Creating PCX Files

**Aseprite**: File → Export → .pcx (8-bit indexed color mode)
**GIMP**: Image → Mode → Indexed (256 colors) → Export as PCX
**Photoshop**: Image → Mode → Indexed Color → Save As PCX (8 bits/pixel)

## Creating IMF Files

**IMFCreator** (MIDI→IMF): https://github.com/adambiser/imf-creator (set rate: 560 or 700 Hz)
**Adlib Tracker II**: https://adlibtracker.net/ → Export IMF
**Extract from games**: See DOCS\MISC\IMFSRC.md (Wolfenstein 3D, Commander Keen music packs)

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

**Music (IMF)**:
```pascal
IMF.Init(700); IMF.LoadFile('X.IMF'); IMF.Start;
while run do IMF.Poll; { MUST call Poll in loop! }
IMF.Done;
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
var Last, Cur, Delta: Real;
UI.Init(BackBuffer, Background); Style.Init(15,7,8,14); UI.SetStyle(@Style);
New(Button, Init(x,y,w,h,'Click',@Font)); { MUST use constructor syntax! }
Button^.SetEventHandler(@OnClick); UI.AddWidget(Button);
InitRTC(1024); Last := GetTimeSeconds;
while run do
  Cur := GetTimeSeconds; Delta := Cur - Last; Last := Cur;
  UI.Update(Delta); UI.RenderDirty; ClearKeyPressed;
UI.RemoveWidget(Button); Dispose(Button, Done); UI.Done; DoneRTC;
```

## Common Pitfalls

1. **Interrupts**: Always call Done/Unhook before exit (HSC_obj.Done, DoneKeyboard, DoneRTC, UninstallHandler) or system hangs
2. **IRQ2**: NEVER mask IRQ2 (slave PIC cascade) - disables all IRQ8-15 (mouse, etc.)
3. **ExitProc**: Install handler to unhook on Ctrl+C/Break
4. **Sound buffers**: Don't free while `Playing=True` (DMA read errors)
5. **HSC + Sound**: Don't `while Playing` loop with HSC active (freezes)
6. **VGA cleanup**: Call CloseVGA before exit
7. **Memory**: Match Create/Free pairs
8. **Keyboard**: ClearKeyPressed at END of loop
9. **DMA**: SBDSP handles 64KB boundaries automatically
10. **Palette**: PCX palette values 0-255 auto-converted to 0-63 for VGA DAC
11. **Paths**: DOS 8.3, backslashes
12. **IRQ0 conflict**: Never read PIT Timer 0 or hook IRQ0 with HSC active. Use RTCTimer (IRQ8) - completely isolated
13. **VMT initialization**: Objects with virtual methods MUST use `New(Ptr, Constructor)` syntax, not `New(Ptr); Ptr^.Init`
14. **VGA clipping**: DrawFillRect includes clipping; widgets assume screen bounds (0-319, 0-199)
15. **Logging**: LOGGER.PAS is for startup/shutdown only - file I/O in render loops causes Runtime Error 202 (stack overflow)
16. **DeltaTime convention**: Use Real for DeltaTime in seconds. CurrentTime/LastTime should be Real (from GetTimeSeconds). Calculate DeltaTime as `CurrentTime - LastTime`. InitRTC(1024) provides millisecond precision via RTC_Ticks for accurate sub-second timing

## Technical Constraints

- DOS real mode 16-bit x86, Turbo Pascal 7.0
- VGA Mode 13h (320x200 256-color)
- Adlib/OPL2 (HSC), Sound Blaster (VOC, DMA 0-3)
- Memory: 640KB conventional, XMS via HIMEM.SYS ✅
- Single-threaded, interrupt-driven audio

## Vendor

**VENDOR/SBDSP2B/**: SBDSP v2.0β (1995, Romesh Prakashpalan)
- Includes VOC2RPD.EXE, WAV2RPD.EXE, TESTDSP.PAS, SBDSP.TXT
