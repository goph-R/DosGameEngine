unit MiniXML;

interface

uses
  StrMap;

const
  XML_MaxNameLength = 20;  { Maximum element/attribute name length }
  XML_MaxAttrsCount = 8;   { Maximum attributes per node }
  MAX_ATTRS = XML_MaxAttrsCount; { Backward compatibility }
  MAX_CHILDREN_HINT = 0;   { Not used, kept for clarity }

type
  PShortString = ^string;
  PWord = ^Word;
  TWordArray = array[0..32000] of Word;
  PWordArray = ^TWordArray;

type
  PPShortString = ^PShortString;
  TPShortStringArray = array[0..7] of PShortString;  { Max XML_MaxAttrsCount }
  PPShortStringArray = ^TPShortStringArray;

  PXMLNode = ^TXMLNode;
  TXMLNode = record
    Name    : string[XML_MaxNameLength];

    { Text content buffer (all text stored here) }
    TextBuf : Pointer;   { points to a byte buffer }
    TextLen : Word;      { number of bytes in TextBuf }
    TextCap : Word;      { allocated capacity in bytes }

    AttrMap : TStringMap;
    AttrKeys  : PPShortString;  { Dynamic array of string pointers }
    AttrValues: PPShortString;  { Dynamic array of string pointers }
    AttrCount : Integer;
    AttrCap   : Integer;        { Allocated capacity }

    FirstChild : PXMLNode;
    NextSibling: PXMLNode;
    Parent     : PXMLNode;
  end;


{ Loading / freeing }
function XMLLoadFile(const FileName: string; var Root: PXMLNode): Boolean;
procedure XMLFreeTree(Node: PXMLNode);

{ Query helpers }
function XMLAttr(const Node: PXMLNode; const Name: string): string;
function XMLHasAttr(const Node: PXMLNode; const Name: string): Boolean;
function XMLGetText(const Node: PXMLNode): string;
function XMLFirstChild(const Node: PXMLNode; const Name: string): PXMLNode;
function XMLNextSibling(const Node: PXMLNode; const Name: string): PXMLNode;
function XMLCountChildren(const Node: PXMLNode; const Name: string): Integer;
function XMLReadWordArray(const Node: PXMLNode; var Arr: PWord; var Count: Word): Boolean;

{ Debug / convenience }
procedure XMLInitNode(var N: TXMLNode);
procedure XMLAddChild(Parent, Child: PXMLNode);
procedure XMLSetAttr(Node: PXMLNode; const Key, Value: string);

implementation

uses
  Dos;

{ ===== Utility: whitespace & small helpers ===== }

function IsWhite(c: Char): Boolean;
begin
  IsWhite := (c = ' ') or (c = #9) or (c = #10) or (c = #13);
end;

function TrimStr(const s: string): string;
var
  i1, i2: Integer;
begin
  i1 := 1; i2 := Length(s);
  while (i1 <= i2) and IsWhite(s[i1]) do Inc(i1);
  while (i2 >= i1) and IsWhite(s[i2]) do Dec(i2);
  if i2 >= i1 then TrimStr := Copy(s, i1, i2 - i1 + 1) else TrimStr := '';
end;

procedure EnsureBuf(Node: PXMLNode; Need: Word);
var
  NewCap: Word;
  NewPtr: Pointer;
begin
  if Node^.TextCap = 0 then
  begin
    NewCap := Need;
    if NewCap < 256 then NewCap := 256;
    { Cap at 64KB for TP7 real-mode GetMem limit }
    if NewCap > 65520 then
    begin
      NewCap := 65520;
      if Need > NewCap then Exit; { Cannot allocate }
    end;
    GetMem(Node^.TextBuf, NewCap);
    Node^.TextCap := NewCap;
    Node^.TextLen := 0;
    Exit;
  end;

  if Node^.TextLen + Need <= Node^.TextCap then Exit;

  NewCap := Node^.TextCap;
  while Node^.TextLen + Need > NewCap do
  begin
    if NewCap < 4096 then Inc(NewCap, NewCap) else Inc(NewCap, 4096);
    { Hard cap at 64KB for TP7 real-mode GetMem limit }
    if NewCap > 65520 then
    begin
      NewCap := 65520;
      if Node^.TextLen + Need > NewCap then Exit; { Cannot grow further }
    end;
  end;

  GetMem(NewPtr, NewCap);
  Move(Node^.TextBuf^, NewPtr^, Node^.TextLen);
  FreeMem(Node^.TextBuf, Node^.TextCap);
  Node^.TextBuf := NewPtr;
  Node^.TextCap := NewCap;
end;

procedure AppendSliceToBufNode(Node: PXMLNode; BufPtr: Pointer; StartIdx, Len: Word);
var
  Dest: Pointer;
  Src: Pointer;
begin
  if Len = 0 then Exit;
  EnsureBuf(Node, Len);
  Dest := Ptr(Seg(Node^.TextBuf^), Ofs(Node^.TextBuf^) + Node^.TextLen);
  Src := Ptr(Seg(BufPtr^), Ofs(BufPtr^) + StartIdx - 1);
  Move(Src^, Dest^, Len);
  Inc(Node^.TextLen, Len);
end;


{ ===== Node basics ===== }

procedure XMLInitNode(var N: TXMLNode);
begin
  N.Name := '';

  N.TextBuf := nil;
  N.TextLen := 0;
  N.TextCap := 0;

  N.AttrKeys := nil;
  N.AttrValues := nil;
  N.AttrCount := 0;
  N.AttrCap := 0;
  MapInit(N.AttrMap);
  N.FirstChild := nil;
  N.NextSibling := nil;
  N.Parent := nil;
end;

procedure XMLAddChild(Parent, Child: PXMLNode);
var
  p: PXMLNode;
begin
  if (Parent = nil) or (Child = nil) then Exit;
  Child^.Parent := Parent;
  if Parent^.FirstChild = nil then
    Parent^.FirstChild := Child
  else
  begin
    p := Parent^.FirstChild;
    while p^.NextSibling <> nil do p := p^.NextSibling;
    p^.NextSibling := Child;
  end;
end;

procedure XMLSetAttr(Node: PXMLNode; const Key, Value: string);
var
  idx, NewCap, i: Integer;
  NewKeys, NewValues: PPShortStringArray;
  pKey, pVal: PShortString;
  OldKeys, OldValues: PPShortStringArray;
begin
  if (Node = nil) or (Node^.AttrCount >= MAX_ATTRS) then Exit;

  { Grow arrays if needed }
  if Node^.AttrCount >= Node^.AttrCap then
  begin
    if Node^.AttrCap = 0 then
      NewCap := 2
    else
      NewCap := Node^.AttrCap * 2;
    if NewCap > MAX_ATTRS then NewCap := MAX_ATTRS;

    { Allocate new arrays }
    GetMem(NewKeys, NewCap * SizeOf(PShortString));
    GetMem(NewValues, NewCap * SizeOf(PShortString));

    { Copy existing pointers }
    if Node^.AttrCap > 0 then
    begin
      OldKeys := PPShortStringArray(Node^.AttrKeys);
      OldValues := PPShortStringArray(Node^.AttrValues);
      for i := 0 to Node^.AttrCount - 1 do
      begin
        NewKeys^[i] := OldKeys^[i];
        NewValues^[i] := OldValues^[i];
      end;
      FreeMem(Node^.AttrKeys, Node^.AttrCap * SizeOf(PShortString));
      FreeMem(Node^.AttrValues, Node^.AttrCap * SizeOf(PShortString));
    end;

    Node^.AttrKeys := PPShortString(NewKeys);
    Node^.AttrValues := PPShortString(NewValues);
    Node^.AttrCap := NewCap;
  end;

  { Allocate strings for key and value }
  idx := Node^.AttrCount;
  New(pKey);
  New(pVal);
  pKey^ := Key;
  pVal^ := Value;

  PPShortStringArray(Node^.AttrKeys)^[idx] := pKey;
  PPShortStringArray(Node^.AttrValues)^[idx] := pVal;

  MapPut(Node^.AttrMap, Key, Pointer(pVal));

  Inc(Node^.AttrCount);
end;

function XMLAttr(const Node: PXMLNode; const Name: string): string;
var
  p: Pointer;
begin
  if Node = nil then begin XMLAttr := ''; Exit; end;
  p := MapGet(Node^.AttrMap, Name);
  if p <> nil then
    XMLAttr := PShortString(p)^
  else
    XMLAttr := '';
end;

function XMLHasAttr(const Node: PXMLNode; const Name: string): Boolean;
begin
  if Node = nil then XMLHasAttr := False
  else XMLHasAttr := MapContains(Node^.AttrMap, Name);
end;

function XMLGetText(const Node: PXMLNode): string;
var
  Len: Word;
  P: ^Byte;
  i: Integer;
  Result: string;
begin
  Result := '';
  if (Node = nil) or (Node^.TextBuf = nil) or (Node^.TextLen = 0) then
  begin
    XMLGetText := '';
    Exit;
  end;

  { Clamp to string max length (255) }
  Len := Node^.TextLen;
  if Len > 255 then Len := 255;

  Result[0] := Char(Len);
  P := Node^.TextBuf;
  for i := 1 to Len do
  begin
    Result[i] := Char(P^);
    Inc(P);
  end;

  XMLGetText := Result;
end;

function XMLFirstChild(const Node: PXMLNode; const Name: string): PXMLNode;
var
  c: PXMLNode;
begin
  c := Node^.FirstChild;
  while c <> nil do
  begin
    if (Name = '') or (c^.Name = Name) then
    begin XMLFirstChild := c; Exit; end;
    c := c^.NextSibling;
  end;
  XMLFirstChild := nil;
end;

function XMLNextSibling(const Node: PXMLNode; const Name: string): PXMLNode;
var
  s: PXMLNode;
begin
  s := Node^.NextSibling;
  while s <> nil do
  begin
    if (Name = '') or (s^.Name = Name) then
    begin XMLNextSibling := s; Exit; end;
    s := s^.NextSibling;
  end;
  XMLNextSibling := nil;
end;

function XMLCountChildren(const Node: PXMLNode; const Name: string): Integer;
var
  Count: Integer;
  Child: PXMLNode;
begin
  Count := 0;
  if Node <> nil then
  begin
    Child := XMLFirstChild(Node, Name);
    while Child <> nil do
    begin
      Inc(Count);
      Child := XMLNextSibling(Child, Name);
    end;
  end;
  XMLCountChildren := Count;
end;

procedure FreeNodeRecursive(Node: PXMLNode);
var
  c, nxt: PXMLNode;
  i: Integer;
begin
  if Node = nil then Exit;

  { Free children first }
  c := Node^.FirstChild;
  while c <> nil do
  begin
    nxt := c^.NextSibling;
    FreeNodeRecursive(c);
    c := nxt;
  end;

  { Free attribute map entries (keys) }
  MapFree(Node^.AttrMap);

  { Free dynamically allocated attribute strings }
  if Node^.AttrCap > 0 then
  begin
    for i := 0 to Node^.AttrCount - 1 do
    begin
      Dispose(PPShortStringArray(Node^.AttrKeys)^[i]);
      Dispose(PPShortStringArray(Node^.AttrValues)^[i]);
    end;
    FreeMem(Node^.AttrKeys, Node^.AttrCap * SizeOf(PShortString));
    FreeMem(Node^.AttrValues, Node^.AttrCap * SizeOf(PShortString));
  end;

  { Free large text buffer if used }
  if Node^.TextBuf <> nil then
  begin
    FreeMem(Node^.TextBuf, Node^.TextCap);
    Node^.TextBuf := nil;
    Node^.TextLen := 0;
    Node^.TextCap := 0;
  end;

  Dispose(Node);
end;

procedure XMLFreeTree(Node: PXMLNode);
begin
  FreeNodeRecursive(Node);
end;

{ ====== Tiny tokenizer over a memory buffer ====== }

type
  TBuf = record
    Data: Pointer; { whole file buffer (dynamically allocated) }
    Pos : Word;    { Current position (1-based, max 65535) }
    Len : Word;    { Total buffer length (max 65535) }
  end;

procedure BInit(var B: TBuf; P: Pointer; Size: LongInt);
begin
  B.Data := P;
  B.Pos := 1;
  { Clamp to Word range (max 65535) }
  if Size > 65535 then Size := 65535;
  B.Len := Word(Size);
end;

function BCopy(var B: TBuf; StartPos, Len: Integer): string;
var
  P: ^Byte;
  i: Integer;
  Result: string;
begin
  Result := '';
  if (Len <= 0) or (StartPos > B.Len) then
  begin
    BCopy := '';
    Exit;
  end;

  { Clamp length to available data }
  if StartPos + Len - 1 > B.Len then
    Len := B.Len - StartPos + 1;

  { Clamp to string max length (255) }
  if Len > 255 then Len := 255;

  Result[0] := Char(Len);  { Set string length }
  P := Ptr(Seg(B.Data^), Ofs(B.Data^) + StartPos - 1);

  for i := 1 to Len do
  begin
    Result[i] := Char(P^);
    Inc(P);
  end;

  BCopy := Result;
end;

function BEOF(var B: TBuf): Boolean;
begin
  BEOF := B.Pos > B.Len;
end;

function BPeek(var B: TBuf): Char;
var
  P: ^Byte;
begin
  if B.Pos <= B.Len then
  begin
    P := Ptr(Seg(B.Data^), Ofs(B.Data^) + B.Pos - 1);
    BPeek := Char(P^);
  end
  else
    BPeek := #0;
end;

function BGet(var B: TBuf): Char;
var
  P: ^Byte;
begin
  if B.Pos <= B.Len then
  begin
    P := Ptr(Seg(B.Data^), Ofs(B.Data^) + B.Pos - 1);
    BGet := Char(P^);
    Inc(B.Pos);
  end
  else
    BGet := #0;
end;

procedure BSkipWS(var B: TBuf);
begin
  while (not BEOF(B)) and IsWhite(BPeek(B)) do Inc(B.Pos);
end;

function StartsWithAt(var B: TBuf; const Pat: string; idx: Integer): Boolean;
var
  i: Integer;
  P: ^Byte;
begin
  StartsWithAt := False;
  if idx + Length(Pat) - 1 > B.Len then Exit;
  P := Ptr(Seg(B.Data^), Ofs(B.Data^) + idx - 1);
  for i := 1 to Length(Pat) do
  begin
    if Char(P^) <> Pat[i] then Exit;
    Inc(P);
  end;
  StartsWithAt := True;
end;

procedure SkipComment(var B: TBuf);
begin
  { assumes we just consumed '<!' and next two chars are '--' }
  while (not BEOF(B)) and (not StartsWithAt(B, '-->', B.Pos)) do Inc(B.Pos);
  if StartsWithAt(B, '-->', B.Pos) then Inc(B.Pos, 3);
end;

function ParseName(var B: TBuf): string;
var
  c: Char; start: Integer;
begin
  start := B.Pos;
  while (not BEOF(B)) do
  begin
    c := BPeek(B);
    if (c in ['a'..'z','A'..'Z','0'..'9','_','-','.',':']) then
      Inc(B.Pos)
    else
      Break;
  end;
  ParseName := BCopy(B, start, B.Pos - start);
end;

function ParseAttrValue(var B: TBuf): string;
var
  q, c: Char;
  start: Integer;
begin
  ParseAttrValue := '';
  BSkipWS(B);
  q := BGet(B); { quote }
  if (q <> '"') and (q <> '''') then
  begin
    { unquoted fallback until whitespace or '>' or '/' }
    start := B.Pos - 1;
    while (not BEOF(B)) do
    begin
      c := BPeek(B);
      if IsWhite(c) or (c = '>') or (c = '/') then Break;
      Inc(B.Pos);
    end;
    ParseAttrValue := BCopy(B, start, B.Pos - start);
    Exit;
  end;

  start := B.Pos;
  while (not BEOF(B)) and (BPeek(B) <> q) do Inc(B.Pos);
  ParseAttrValue := BCopy(B, start, B.Pos - start);
  if (not BEOF(B)) and (BPeek(B) = q) then Inc(B.Pos);
end;

function ParseUntilLT(var B: TBuf): string;
var
  start: Integer;
begin
  start := B.Pos;
  while (not BEOF(B)) and (BPeek(B) <> '<') do Inc(B.Pos);
  ParseUntilLT := BCopy(B, start, B.Pos - start);
end;

{ ====== Recursive-descent-ish parser ====== }

function NewNode(const Name: string): PXMLNode;
var
  p: PXMLNode;
begin
  New(p);
  XMLInitNode(p^);
  p^.Name := Name;
  NewNode := p;
end;

function ParseElement(var B: TBuf; Parent: PXMLNode): PXMLNode; forward;

procedure ParseAttributes(var B: TBuf; Node: PXMLNode);
var
  attrName, attrVal: string;
  c: Char;
begin
  while not BEOF(B) do
  begin
    BSkipWS(B);
    c := BPeek(B);
    if (c = '/') or (c = '>') then Exit; { end of start-tag }
    attrName := ParseName(B);
    BSkipWS(B);
    if BPeek(B) = '=' then
    begin
      BGet(B); { consume '=' }
      BSkipWS(B);
      attrVal := ParseAttrValue(B);
    end
    else
      attrVal := ''; { boolean-like attribute }

    XMLSetAttr(Node, attrName, attrVal);
  end;
end;

function ParseElement(var B: TBuf; Parent: PXMLNode): PXMLNode;
var
  name, endname: string;
  node, child: PXMLNode;
  c: Char;
  sStart: Integer;
  segLen: Word;
begin
  ParseElement := nil;

  { assumes current char is '<' }
  if BPeek(B) <> '<' then Exit;
  BGet(B); { consume '<' }

  { Comments / declarations }
  if (BPeek(B) = '!') then
  begin
    Inc(B.Pos);
    if StartsWithAt(B, '--', B.Pos) then
    begin
      Inc(B.Pos, 2);
      SkipComment(B);
      ParseElement := nil;
      Exit;
    end
    else
    begin
      { skip generic <! ... > }
      while (not BEOF(B)) and (BGet(B) <> '>') do ;
      ParseElement := nil;
      Exit;
    end;
  end
  else if (BPeek(B) = '?') then
  begin
    { processing instruction <? ... ?> }
    while (not BEOF(B)) and (not StartsWithAt(B, '?>', B.Pos)) do Inc(B.Pos);
    if StartsWithAt(B, '?>', B.Pos) then Inc(B.Pos, 2);
    ParseElement := nil;
    Exit;
  end
  else if (BPeek(B) = '/') then
  begin
    { stray close-tag (should be handled by caller) }
    ParseElement := nil;
    Exit;
  end;

  { Start-tag name }
  name := ParseName(B);
  node := NewNode(name);

  { Attributes }
  ParseAttributes(B, node);

  { Self-closing? <tag ... /> }
  BSkipWS(B);
  if BPeek(B) = '/' then
  begin
    BGet(B); { '/' }
    if BPeek(B) = '>' then BGet(B);
    ParseElement := node;
    Exit;
  end;

  { Expect '>' }
  if BPeek(B) = '>' then BGet(B);

  { Content loop: text and child elements until </name> }
  repeat
    BSkipWS(B);
    if BEOF(B) then Break;

    if BPeek(B) = '<' then
    begin
      { closing tag? }
      if StartsWithAt(B, '</', B.Pos) then
      begin
        Inc(B.Pos, 2);           { consume '</' }
        endname := ParseName(B); { closing name }
        { skip until '>' }
        while (not BEOF(B)) and (BGet(B) <> '>') do ;
        { accept even if mismatched, but ideally should match }
        Break;
      end
      else
      begin
        { child element or comment/PI }
        child := ParseElement(B, node);
        if child <> nil then XMLAddChild(node, child);
      end;
    end
    else
    begin
      sStart := B.Pos;
      while (not BEOF(B)) and (BPeek(B) <> '<') do Inc(B.Pos);
      segLen := B.Pos - sStart;
      if segLen = 0 then Continue;

      { Append all text to buffer }
      AppendSliceToBufNode(node, B.Data, sStart, segLen);
    end;

  until BEOF(B);

  ParseElement := node;
end;

function XMLLoadFile(const FileName: string; var Root: PXMLNode): Boolean;
var
  F: File;
  sz: LongInt;
  FileBuf: Pointer;
  B: TBuf;
  n, child: PXMLNode;
  ch: Char;
  P: ^Byte;
begin
  Root := nil;
  FileBuf := nil;

  { Read the whole file into dynamically allocated buffer }
  Assign(F, FileName);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult <> 0 then begin XMLLoadFile := False; Exit; end;

  sz := FileSize(F);

  { Hard cap for single near-pointer block in TP7 real mode }
  if (sz <= 0) or (sz > 65500) then
  begin
    Close(F);
    XMLLoadFile := False;
    Exit;
  end;

  GetMem(FileBuf, sz);
  BlockRead(F, FileBuf^, sz);
  Close(F);

  { Parse }
  BInit(B, FileBuf, sz);
  { Skip BOM if present (naive) }
  if sz >= 3 then
  begin
    P := FileBuf;
    if (Char(P^) = #$EF) then
    begin
      Inc(P);
      if (Char(P^) = #$BB) then
      begin
        Inc(P);
        if (Char(P^) = #$BF) then
          B.Pos := 4;
      end;
    end;
  end;

  while (not BEOF(B)) do
  begin
    { find next '<' }
    while (not BEOF(B)) and (BPeek(B) <> '<') do Inc(B.Pos);
    if BEOF(B) then Break;

    n := ParseElement(B, nil);
    if n <> nil then
    begin
      if Root = nil then Root := n
      else
      begin
        { wrap multiple top-level nodes in a synthetic root }
        if (Root <> nil) and (Root^.Name <> '#document') then
        begin
          child := Root;
          New(Root);
          XMLInitNode(Root^);
          Root^.Name := '#document';
          XMLAddChild(Root, child);
        end;
        XMLAddChild(Root, n);
      end;
    end;
  end;

  { Free the file buffer }
  if FileBuf <> nil then
    FreeMem(FileBuf, sz);

  XMLLoadFile := Root <> nil;
end;

function XMLReadWordArray(const Node: PXMLNode; var Arr: PWord; var Count: Word): Boolean;
var
  SrcPtr: Pointer;
  SrcLen: Word;

  function GetSrc(var P: Pointer; var L: Word): Boolean;
  begin
    if (Node = nil) or (Node^.TextBuf = nil) or (Node^.TextLen = 0) then
    begin
      GetSrc := False;
      Exit;
    end;

    P := Node^.TextBuf;
    L := Node^.TextLen;
    GetSrc := True;
  end;

  function IsDigit(ch: Char): Boolean;
  begin
    IsDigit := (ch >= '0') and (ch <= '9');
  end;

var
  p: ^Byte;
  ch: Char;
  inNum: Boolean;
  tmpVal: LongInt;
  tmpCount: Word;

  procedure FirstPassCount;
  var
    i: Word;
  begin
    tmpCount := 0; inNum := False; tmpVal := 0;
    p := SrcPtr;
    for i := 1 to SrcLen do
    begin
      ch := Char(p^);
      if IsDigit(ch) then
      begin
        inNum := True;
        tmpVal := tmpVal * 10 + Ord(ch) - Ord('0');
        if tmpVal > 65535 then tmpVal := 65535; { clamp to Word }
      end
      else
      begin
        if inNum then
        begin
          Inc(tmpCount);
          inNum := False;
          tmpVal := 0;
        end;
      end;
      Inc(p);
    end;
    if inNum then Inc(tmpCount); { trailing number }
  end;

  procedure SecondPassFill;
  var
    i: Word;
    idx: Word;
    ArrAccess: PWordArray;
  begin
    ArrAccess := PWordArray(Arr);
    idx := 0; inNum := False; tmpVal := 0;
    p := SrcPtr;
    for i := 1 to SrcLen do
    begin
      ch := Char(p^);
      if IsDigit(ch) then
      begin
        inNum := True;
        tmpVal := tmpVal * 10 + Ord(ch) - Ord('0');
        if tmpVal > 65535 then tmpVal := 65535;
      end
      else
      begin
        if inNum then
        begin
          ArrAccess^[idx] := Word(tmpVal);
          Inc(idx);
          inNum := False;
          tmpVal := 0;
        end;
      end;
      Inc(p);
    end;
    if inNum then
    begin
      ArrAccess^[idx] := Word(tmpVal);
    end;
  end;

begin
  Arr := nil; Count := 0;
  if not GetSrc(SrcPtr, SrcLen) then
  begin
    XMLReadWordArray := False;
    Exit;
  end;

  FirstPassCount;
  if tmpCount = 0 then
  begin
    XMLReadWordArray := False;
    Exit;
  end;

  GetMem(Arr, tmpCount * SizeOf(Word));
  Count := tmpCount;

  SecondPassFill;
  XMLReadWordArray := True;
end;

end.
