unit StrMap;

interface

const
  MAX_ENTRIES = 256;

type
  PMapValue = Pointer;

  PMapEntry = ^TMapEntry;
  TMapEntry = record
    Key: string;
    Value: PMapValue;
    Used: Boolean;
  end;

  TStringMap = record
    Entries: array[0..MAX_ENTRIES - 1] of PMapEntry;
  end;

procedure MapInit(var Map: TStringMap);
procedure MapPut(var Map: TStringMap; const Key: string; Value: Pointer);
function  MapGet(var Map: TStringMap; const Key: string): Pointer;
function  MapContains(var Map: TStringMap; const Key: string): Boolean;
procedure MapRemove(var Map: TStringMap; const Key: string);
procedure MapFree(var Map: TStringMap);

implementation

function HashKey(const S: string): Word;
var
  i: Integer;
  h: Word;
begin
  h := 0;
  for i := 1 to Length(S) do
    h := (h * 257 + Ord(S[i])) mod MAX_ENTRIES;
  HashKey := h;
end;

procedure MapInit(var Map: TStringMap);
var
  i: Integer;
begin
  for i := 0 to MAX_ENTRIES - 1 do
    Map.Entries[i] := nil;
end;

procedure MapPut(var Map: TStringMap; const Key: string; Value: Pointer);
var
  idx, start: Word;
  E: PMapEntry;
begin
  idx := HashKey(Key);
  start := idx;
  repeat
    E := Map.Entries[idx];

    { Empty slot or same key }
    if (E = nil) or (E^.Used and (E^.Key = Key)) then
    begin
      if E = nil then
      begin
        New(E);
        E^.Key := Key;
        E^.Used := True;
        Map.Entries[idx] := E;
      end;
      E^.Value := Value;
      Exit;
    end;

    idx := (idx + 1) mod MAX_ENTRIES;
  until idx = start;
end;

function MapGet(var Map: TStringMap; const Key: string): Pointer;
var
  idx, start: Word;
  E: PMapEntry;
begin
  idx := HashKey(Key);
  start := idx;
  repeat
    E := Map.Entries[idx];
    if E = nil then
      Break;
    if E^.Used and (E^.Key = Key) then
    begin
      MapGet := E^.Value;
      Exit;
    end;
    idx := (idx + 1) mod MAX_ENTRIES;
  until idx = start;
  MapGet := nil;
end;

function MapContains(var Map: TStringMap; const Key: string): Boolean;
begin
  MapContains := MapGet(Map, Key) <> nil;
end;

procedure MapRemove(var Map: TStringMap; const Key: string);
var
  idx, start: Word;
  E: PMapEntry;
begin
  idx := HashKey(Key);
  start := idx;
  repeat
    E := Map.Entries[idx];
    if E = nil then
      Break;
    if E^.Used and (E^.Key = Key) then
    begin
      Dispose(E);
      Map.Entries[idx] := nil;
      Exit;
    end;
    idx := (idx + 1) mod MAX_ENTRIES;
  until idx = start;
end;

procedure MapFree(var Map: TStringMap);
var
  i: Integer;
begin
  for i := 0 to MAX_ENTRIES - 1 do
    if Map.Entries[i] <> nil then
    begin
      Dispose(Map.Entries[i]);
      Map.Entries[i] := nil;
    end;
end;

end.
