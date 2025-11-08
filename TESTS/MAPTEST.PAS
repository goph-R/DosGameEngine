program TestMap;
uses
  StrMap;

var
  Map: TStringMap;
  S: ^String;
  S2: ^String;
begin
  MapInit(Map);

  New(S);
  S^ := 'Hello from DOS!';
  MapPut(Map, 'greeting', S);

  if MapContains(Map, 'greeting') then
  begin
    S2 := MapGet(Map, 'greeting');
    WriteLn('Found: ', S2^);
  end
  else
    WriteLn('Not found');

  Dispose(S);
  MapFree(Map);
end.