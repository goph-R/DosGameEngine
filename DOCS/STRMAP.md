# STRMAP - String Map

Hash map for string→pointer lookups (256 entries max).

## Types

```pascal
const
  MAX_ENTRIES = 256;

type
  PMapValue = Pointer;

  TMapEntry = record
    Key: string;
    Value: PMapValue;
    Used: Boolean;
  end;

  TStringMap = record
    Entries: array[0..MAX_ENTRIES-1] of TMapEntry;
  end;
```

## Functions

```pascal
procedure MapInit(var Map: TStringMap);
procedure MapPut(var Map: TStringMap; const Key: string; Value: PMapValue);
function MapGet(var Map: TStringMap; const Key: string): PMapValue;
function MapContains(var Map: TStringMap; const Key: string): Boolean;
procedure MapRemove(var Map: TStringMap; const Key: string);
procedure MapFree(var Map: TStringMap);
```

## Example

```pascal
uses StrMap, VGA;

var
  Images: TStringMap;
  Img: PImage;
begin
  MapInit(Images);

  New(Img);
  MapPut(Images, 'player', Img);

  Img := PImage(MapGet(Images, 'player'));
  if Img <> nil then
    PutImage(0, 0, Img, GetScreenBuffer);

  MapFree(Images); { Does NOT free values! }
end;
```

## Notes

- Max 256 unique keys (linear probe collision resolution)
- `MapFree` clears map but does NOT free values (caller must free)
- Case-sensitive keys
- Used by RESMAN for resource lookups
