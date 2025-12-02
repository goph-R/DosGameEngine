program XMLMemTest;

uses
  MiniXML, Strings;

var
  Root: PXMLNode;
  NodeCount   : LongInt;
  NodeBytes   : LongInt;
  TextBytes   : LongInt;
  AttrBytes   : LongInt;

procedure AddNodeStats(Node: PXMLNode;
  var NodeCount, NodeBytes, TextBytes, AttrBytes: LongInt);
var
  Child: PXMLNode;
  i: Integer;
begin
  if Node = nil then Exit;

  { Count this node }
  Inc(NodeCount);

  { Base record size (all fields inside TXMLNode) }
  Inc(NodeBytes, SizeOf(TXMLNode));

  { Text buffer: count allocated capacity, not just used length }
  if Node^.TextBuf <> nil then
    Inc(TextBytes, Node^.TextCap);

  { Attributes: each key/value is a dynamically sized PChar now }
  for i := 0 to Node^.AttrCount - 1 do
  begin
    if Node^.AttrKeys[i] <> nil then
      Inc(AttrBytes, StrLen(Node^.AttrKeys[i]) + 1);
    if Node^.AttrValues[i] <> nil then
      Inc(AttrBytes, StrLen(Node^.AttrValues[i]) + 1);
  end;

  { Recurse into children }
  Child := Node^.FirstChild;
  while Child <> nil do
  begin
    AddNodeStats(Child, NodeCount, NodeBytes, TextBytes, AttrBytes);
    Child := Child^.NextSibling;
  end;
end;

var
  TotalBytes: LongInt;
  FileName: string;

begin
  WriteLn('MiniXML memory usage test');
  WriteLn('-------------------------');

  { Check arguments }
  if ParamCount < 1 then
  begin
    WriteLn('Usage: XMLMemTest <filename.xml>');
    Halt(1);
  end;

  FileName := ParamStr(1);

  { Load XML }
  if not XMLLoadFile(FileName, Root) then
  begin
    WriteLn('ERROR loading "', FileName, '": ', GetLoadXMLError);
    Halt(1);
  end;

  { Init counters }
  NodeCount := 0;
  NodeBytes := 0;
  TextBytes := 0;
  AttrBytes := 0;

  { Collect statistics }
  AddNodeStats(Root, NodeCount, NodeBytes, TextBytes, AttrBytes);

  TotalBytes := NodeBytes + TextBytes + AttrBytes;

  WriteLn;
  WriteLn('Nodes          : ', NodeCount);
  WriteLn('Node records   : ', NodeBytes, ' bytes');
  WriteLn('Text buffers   : ', TextBytes, ' bytes (allocated capacity)');
  WriteLn('Attributes     : ', AttrBytes, ' bytes');
  WriteLn('-----------------------------------------------');
  WriteLn('Approx total   : ', TotalBytes, ' bytes');
  WriteLn('≈ ', (TotalBytes + 512) div 1024, ' KB');

  { Free everything }
  XMLFreeTree(Root);

  WriteLn;
  WriteLn('Done. Press ENTER to exit.');
  ReadLn;
end.
