program XMLTest;

uses
  MiniXML;

var
  Root: PXMLNode;
  Node, Child: PXMLNode;
  AttrValue: string;
  Values: PWord;
  Count: Word;

begin
  WriteLn('MiniXML Test - Loading ..\DATA\TEST.XML');
  WriteLn('=========================================');
  WriteLn;

  { Load the XML file }
  if not XMLLoadFile('..\DATA\TEST.XML', Root) then
  begin
    WriteLn('ERROR: Failed to load XML file!');
    Halt(1);
  end;

  WriteLn('XML file loaded successfully!');
  WriteLn;

  { Display root node information }
  WriteLn('Root node: <', Root^.Name, '>');
  WriteLn;

  { Show attributes if present }
  if XMLHasAttr(Root, 'version') then
  begin
    AttrValue := XMLAttr(Root, 'version');
    WriteLn('  version="', AttrValue, '"');
  end;

  { Display text content if present }
  if Root^.TextBuf <> nil then
  begin
    if Root^.TextLen <= 80 then
      WriteLn('  Text: ', XMLGetText(Root))
    else
      WriteLn('  Text length (in buffer): ', Root^.TextLen, ' bytes');
  end;

  WriteLn;

  { Iterate through child nodes }
  WriteLn('Child nodes:');
  WriteLn('------------');
  Node := XMLFirstChild(Root, '');
  while Node <> nil do
  begin
    Write('  <', Node^.Name, '>');

    { Show attributes }
    if XMLHasAttr(Node, 'id') then
      Write(' id="', XMLAttr(Node, 'id'), '"');
    if XMLHasAttr(Node, 'name') then
      Write(' name="', XMLAttr(Node, 'name'), '"');
    if XMLHasAttr(Node, 'type') then
      Write(' type="', XMLAttr(Node, 'type'), '"');

    { Show text content }
    if Node^.TextBuf <> nil then
    begin
      if Node^.TextLen <= 50 then
        Write(' - "', XMLGetText(Node), '"')
      else
        Write(' - [', Node^.TextLen, ' bytes]');
    end;

    WriteLn;

    { Show nested children if any }
    Child := XMLFirstChild(Node, '');
    if Child <> nil then
    begin
      WriteLn('    Has ', XMLCountChildren(Node, ''), ' child node(s)');
    end;

    Node := XMLNextSibling(Node, '');
  end;

  WriteLn;

  { Test large text content (>255 bytes) with numeric array parsing }
  WriteLn('Large text content test:');
  WriteLn('------------------------');
  Node := XMLFirstChild(Root, 'testdata');
  if Node <> nil then
  begin
    WriteLn('Found <testdata> node');

    { Check text storage type }
    if Node^.TextBuf <> nil then
      WriteLn('  Text stored in buffer: ', Node^.TextLen, ' bytes')
    else
      WriteLn('  No text content');

    { Parse numeric array }
    if XMLReadWordArray(Node, Values, Count) then
    begin
      WriteLn('  Parsed ', Count, ' numbers');
      WriteLn('  First value: ', PWordArray(Values)^[0]);
      WriteLn('  Last value: ', PWordArray(Values)^[Count - 1]);

      { Verify last value is 1234 }
      if PWordArray(Values)^[Count - 1] = 1234 then
        WriteLn('  SUCCESS: Last value is 1234!')
      else
        WriteLn('  ERROR: Last value is not 1234!');

      FreeMem(Values, Count * SizeOf(Word));
    end
    else
      WriteLn('  ERROR: Failed to parse array!');
  end
  else
    WriteLn('ERROR: <testdata> node not found!');

  WriteLn;
  WriteLn('Test complete. Press ENTER to exit.');

  { Cleanup }
  XMLFreeTree(Root);

  ReadLn;
end.
