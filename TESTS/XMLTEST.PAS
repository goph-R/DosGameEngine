program XMLTest;

uses
  MiniXML;

var
  Root: PXMLNode;
  Node, Child: PXMLNode;
  AttrValue: string;

{ Helper function to count children }
function CountChildren(Parent: PXMLNode): Integer;
var
  Count: Integer;
  N: PXMLNode;
begin
  Count := 0;
  N := XMLFirstChild(Parent, '');
  while N <> nil do
  begin
    Inc(Count);
    N := XMLNextSibling(N, '');
  end;
  CountChildren := Count;
end;

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
  if Root^.Text <> '' then
  begin
    WriteLn('  Text (first 80 chars): ', Copy(Root^.Text, 1, 80));
  end
  else if Root^.TextBuf <> nil then
  begin
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
    if Node^.Text <> '' then
      Write(' - "', Node^.Text, '"')
    else if Node^.TextBuf <> nil then
      Write(' - [', Node^.TextLen, ' bytes]');

    WriteLn;

    { Show nested children if any }
    Child := XMLFirstChild(Node, '');
    if Child <> nil then
    begin
      WriteLn('    Has ', CountChildren(Node), ' child node(s)');
    end;

    Node := XMLNextSibling(Node, '');
  end;

  WriteLn;
  WriteLn('Test complete. Press ENTER to exit.');

  { Cleanup }
  XMLFreeTree(Root);

  ReadLn;
end.
