program TMXTest;

uses
  MiniXML;

var
  Root: PXMLNode;
  TotalNodes: LongInt;
  TotalAttrs: LongInt;
  TotalTextBytes: LongInt;
  BaseMemory: LongInt;
  AttrMemory: LongInt;
  TextMemory: LongInt;
  TotalMemory: LongInt;

{ Recursively count nodes and memory usage }
procedure CountNodeMemory(Node: PXMLNode);
var
  Child: PXMLNode;
  i: Integer;
  AttrKeyLen, AttrValLen: Integer;
begin
  if Node = nil then Exit;

  { Count this node }
  Inc(TotalNodes);

  { Base node overhead: ~103 bytes }
  Inc(BaseMemory, 103);

  { Count attributes }
  Inc(TotalAttrs, Node^.AttrCount);

  { Calculate attribute memory (pointers + actual strings) }
  if Node^.AttrCount > 0 then
  begin
    { Pointer arrays overhead }
    Inc(AttrMemory, Node^.AttrCap * SizeOf(Pointer) * 2);

    { Individual attribute strings }
    for i := 0 to Node^.AttrCount - 1 do
    begin
      { Each string: 1 byte length + actual chars }
      AttrKeyLen := Length(PPShortStringArray(Node^.AttrKeys)^[i]^);
      AttrValLen := Length(PPShortStringArray(Node^.AttrValues)^[i]^);
      Inc(AttrMemory, 1 + AttrKeyLen);  { Key string }
      Inc(AttrMemory, 1 + AttrValLen);  { Value string }
    end;
  end;

  { Count text buffer }
  if Node^.TextBuf <> nil then
  begin
    Inc(TotalTextBytes, Node^.TextLen);
    Inc(TextMemory, Node^.TextCap);  { Allocated capacity }
  end;

  { Recurse into children }
  Child := Node^.FirstChild;
  while Child <> nil do
  begin
    CountNodeMemory(Child);
    Child := Child^.NextSibling;
  end;
end;

begin
  WriteLn('TMX/XML Memory Usage Analyzer');
  WriteLn('=============================');
  WriteLn;

  { Initialize counters }
  TotalNodes := 0;
  TotalAttrs := 0;
  TotalTextBytes := 0;
  BaseMemory := 0;
  AttrMemory := 0;
  TextMemory := 0;

  { Load TMX file }
  Write('Loading ..\DATA\TEST.TMX... ');
  if not XMLLoadFile('..\DATA\TEST.TMX', Root) then
  begin
    WriteLn('FAILED!');
    WriteLn('Error: Could not load file.');
    Halt(1);
  end;
  WriteLn('OK');
  WriteLn;

  { Analyze memory usage }
  CountNodeMemory(Root);

  { Calculate totals }
  TotalMemory := BaseMemory + AttrMemory + TextMemory;

  { Display statistics }
  WriteLn('Structure Statistics:');
  WriteLn('--------------------');
  WriteLn('Total nodes:           ', TotalNodes);
  WriteLn('Total attributes:      ', TotalAttrs);
  WriteLn('Total text content:    ', TotalTextBytes, ' bytes');
  WriteLn;

  WriteLn('Memory Usage Breakdown:');
  WriteLn('----------------------');
  WriteLn('Base node overhead:    ', BaseMemory, ' bytes  (~', BaseMemory div 1024, ' KB)');
  WriteLn('Attribute storage:     ', AttrMemory, ' bytes  (~', AttrMemory div 1024, ' KB)');
  WriteLn('Text buffers:          ', TextMemory, ' bytes  (~', TextMemory div 1024, ' KB)');
  WriteLn('--------------------------------');
  WriteLn('TOTAL MEMORY:          ', TotalMemory, ' bytes  (~', TotalMemory div 1024, ' KB)');
  WriteLn;

  WriteLn('Per-Node Averages:');
  WriteLn('-----------------');
  if TotalNodes > 0 then
  begin
    WriteLn('Avg memory per node:   ', TotalMemory div TotalNodes, ' bytes');
    WriteLn('Avg attributes/node:   ', TotalAttrs div TotalNodes);
  end;
  WriteLn;

  WriteLn('Estimated OLD Design (pre-optimization):');
  WriteLn('---------------------------------------');
  WriteLn('Old memory per node:   4680 bytes (fixed arrays)');
  WriteLn('Old total memory:      ', TotalNodes * 4680, ' bytes  (~', (TotalNodes * 4680) div 1024, ' KB)');
  WriteLn('MEMORY SAVED:          ', (TotalNodes * 4680) - TotalMemory,' bytes  (~',
    ((TotalNodes * 4680) - TotalMemory) div 1024, ' KB)');
  WriteLn('REDUCTION:             ', 100 - ((TotalMemory * 100) div (TotalNodes * 4680)), '%');
  WriteLn;

  { Cleanup }
  XMLFreeTree(Root);

  WriteLn('Press ENTER to exit.');
  ReadLn;
end.
