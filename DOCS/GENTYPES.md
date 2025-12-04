# GENTYPES - Generic Types

Generic pointer and array types for low-level memory operations.

## Types

```pascal
type
  PByte = ^Byte;
  PWord = ^Word;
  PShortString = ^ShortString;

  TByteArray = array[0..65520] of Byte;
  PByteArray = ^TByteArray;

  TWordArray = array[0..32000] of Word;
  PWordArray = ^TWordArray;
```

## Usage

```pascal
var
  Buf: PByteArray;
  W: PWord;
begin
  GetMem(Buf, 1024);
  Buf^[0] := $FF;

  W := @Buf^[100];
  W^ := $1234;

  FreeMem(Buf, 1024);
end;
```

## Notes

- `TByteArray` max size: 65520 bytes (64KB - 16)
- `TWordArray` max size: 32000 words (64KB)
- Use for direct memory access, XMS transfers, DMA buffers
