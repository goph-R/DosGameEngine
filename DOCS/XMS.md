# XMS - Extended Memory Manager

Extended memory (XMS) access via HIMEM.SYS (1992, KIV without Co).

## Types

```pascal
type
  EMMstruct = record
    Size: LongInt;    { Transfer size in bytes }
    SOH: Word;        { Source handle (0=conventional memory) }
    SOO: LongInt;     { Source offset }
    DSH: Word;        { Destination handle (0=conventional memory) }
    DSO: LongInt;     { Destination offset }
  end;
```

## Globals

```pascal
var
  XMSerror: Byte;   { Last error code }
```

## Functions

### Detection
```pascal
function XMSinstalled: Boolean;
```

### Memory Allocation
```pascal
procedure GetXMSmem(var Total, Block: Word);
function AllocXMS(KB: Word): Word;               { Returns handle }
function ReallocXMS(Handle: Word; KB: Word): Boolean;
procedure FreeXMS(Handle: Word);
```

### Transfer
```pascal
procedure MoveXMS(var EMM: EMMstruct);
procedure Mem2Xms(var Buf; Count: Word; Handle: Word; Offset: LongInt);
procedure Xms2Mem(Handle: Word; Offset: LongInt; var Buf; Count: Word);
```

### Locking
```pascal
function LockBlock(Handle: Word; var Address: LongInt): Boolean;
function UnlockBlock(Handle: Word): Boolean;
```

### Info
```pascal
procedure GetXMShandleInfo(Handle: Word; var LockCount, FreeHandles, Size: Word);
function XMSerrorMSG(Error: Byte): string;
```

### HMA
```pascal
function RequestHMA(Mem: Word): Boolean;
procedure ReleaseHMA;
```

## Example (Sound Bank)

```pascal
uses XMS, SBDSP;

var
  Handle: Word;
  Buffer: array[0..16383] of Byte;
begin
  if not XMSinstalled then
  begin
    WriteLn('HIMEM.SYS not loaded!');
    Exit;
  end;

  { Allocate 64KB XMS }
  Handle := AllocXMS(64);
  if Handle = 0 then
  begin
    WriteLn('XMS allocation failed: ', XMSerrorMSG(XMSerror));
    Exit;
  end;

  { Upload sound data }
  Mem2Xms(Buffer, SizeOf(Buffer), Handle, 0);

  { Download to DMA buffer }
  Xms2Mem(Handle, 0, Buffer, SizeOf(Buffer));

  { Free XMS memory }
  FreeXMS(Handle);
end;
```

## Critical: Handle=0 Convention

When `Handle=0` in `EMMstruct`, offset is **pointer** (Seg:Ofs), NOT linear address:

```pascal
var
  EMM: EMMstruct;
  Buf: array[0..1023] of Byte;
begin
  EMM.Size := 1024;
  EMM.SOH := 0;                          { Source = conventional memory }
  EMM.SOO := LongInt(@Buf);              { Pointer (Seg:Ofs) }
  EMM.DSH := XMSHandle;                  { Dest = XMS memory }
  EMM.DSO := 0;                          { Linear offset }
  MoveXMS(EMM);
end;
```

## Error Codes

| Code | Message                      |
|-----:|------------------------------|
| 0x80 | Not implemented              |
| 0x81 | VDISK detected               |
| 0x82 | A20 error                    |
| 0xA0 | All memory allocated         |
| 0xA1 | All handles allocated        |
| 0xA2 | Invalid handle               |
| 0xA3 | Source handle invalid        |
| 0xA4 | Source offset invalid        |
| 0xA5 | Destination handle invalid   |
| 0xA6 | Destination offset invalid   |
| 0xA7 | Length invalid               |
| 0xAB | Block locked                 |
| 0xAC | Block locked                 |

## Requirements

- **HIMEM.SYS** in CONFIG.SYS:
  ```
  DEVICE=C:\DOS\HIMEM.SYS
  ```

## Notes

- Used by SNDBANK for large sound buffers
- Max 286/386 extended memory (above 1MB)
- Handles DMA 64KB boundary crossing automatically in SNDBANK
- `GetXMSmem` returns total and largest block in KB
