unit MiniXML;

interface

uses
  GenTypes, Strings;

const
  XML_MaxNameLength = 20;  { Maximum element/attribute name length }
  XML_MaxAttrsCount = 8;   { Maximum attributes per node }
  MAX_ATTRS = XML_MaxAttrsCount; { Backward compatibility }
  MAX_CHILDREN_HINT = 0;   { Not used, kept for clarity }

type
  PAttrString = PChar;
  TPAttrStringArray = array[0..XML_MaxAttrsCount - 1] of PAttrString;

  PXMLNode = ^TXMLNode;
  TXMLNode = record
    Name    : string[XML_MaxNameLength];

    { Text content buffer (all text stored here) }
    TextBuf : Pointer;   { points to a byte buffer }
    TextLen : Word;      { number of bytes in TextBuf }
    TextCap : Word;      { allocated capacity in bytes }

    AttrKeys  : TPAttrStringArray;
    AttrValues: TPAttrStringArray;
    AttrCount : Integer;

    FirstChild : PXMLNode;
    NextSibling: PXMLNode;
    Parent     : PXMLNode;
  end;


{ Loading / freeing }
function XMLLoadFile(const FileName: string; var Root: PXMLNode): Boolean;
function GetLoadXMLError: string;
procedure XMLFreeTree(Node: PXMLNode);

{ Saving }
function XMLSaveFile(const FileName: string; Root: PXMLNode): Boolean;
function GetSaveXMLError: string;
  
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

procedure XMLSetText(Node: PXMLNode; const S: string);
procedure XMLAppendText(Node: PXMLNode; const S: string);
function  XMLAddChildElement(Parent: PXMLNode; const Name: string): PXMLNode;

implementation

uses
  Dos;

{ ===== Error reporting ===== }
var
  XMLLoadError: string;
  XMLSaveError: string;

function GetLoadXMLError: string;
begin
  GetLoadXMLError := XMLLoadError;
end;

function GetSaveXMLError: string;
begin
  GetSaveXMLError := XMLSaveError;
end;

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
var
  i: Integer;
begin
  N.Name := '';
  N.TextBuf := nil;
  N.TextLen := 0;
  N.TextCap := 0;
  N.AttrCount := 0;
  for i := 0 to XML_MaxAttrsCount - 1 do
  begin
    N.AttrKeys[i] := nil;
    N.AttrValues[i] := nil;
  end;
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

function AttrEquals(P: PAttrString; const S: string): Boolean;
var
  i, L: Integer;
begin
  if P = nil then
  begin
    AttrEquals := False;
    Exit;
  end;

  L := Length(S);
  if StrLen(P) <> L then
  begin
    AttrEquals := False;
    Exit;
  end;

  for i := 0 to L - 1 do
    if P[i] <> S[i + 1] then
    begin
      AttrEquals := False;
      Exit;
    end;

  AttrEquals := True;
end;

function FindAttrIndex(const Node: PXMLNode; const Name: string): Integer;
var
  i: Integer;
begin
  FindAttrIndex := -1;
  if Node = nil then Exit;

  for i := 0 to Node^.AttrCount - 1 do
    if AttrEquals(Node^.AttrKeys[i], Name) then
    begin
      FindAttrIndex := i;
      Exit;
    end;
end;

procedure SetAttrString(var Dest: PAttrString; const S: string);
var
  L: Integer;
begin
  { Free old string if present }
  if Dest <> nil then
  begin
    FreeMem(Dest, StrLen(Dest) + 1);
    Dest := nil;
  end;

  L := Length(S);
  if L = 0 then Exit;  { keep nil for empty strings }

  GetMem(Dest, L + 1);
  Move(S[1], Dest^, L);
  Dest[L] := #0;
end;

procedure XMLSetAttr(Node: PXMLNode; const Key, Value: string);
var
  idx: Integer;
begin
  if Node = nil then Exit;

  { If attribute already exists, overwrite value }
  idx := FindAttrIndex(Node, Key);
  if idx >= 0 then
  begin
    SetAttrString(Node^.AttrValues[idx], Value);
    Exit;
  end;

  { New attribute }
  if Node^.AttrCount >= XML_MaxAttrsCount then Exit;

  idx := Node^.AttrCount;

  SetAttrString(Node^.AttrKeys[idx], Key);
  SetAttrString(Node^.AttrValues[idx], Value);

  Inc(Node^.AttrCount);
end;

function XMLAttr(const Node: PXMLNode; const Name: string): string;
var
  idx: Integer;
begin
  idx := FindAttrIndex(Node, Name);
  if (idx >= 0) and (Node^.AttrValues[idx] <> nil) then
    XMLAttr := StrPas(Node^.AttrValues[idx])
  else
    XMLAttr := '';
end;

function XMLHasAttr(const Node: PXMLNode; const Name: string): Boolean;
begin
  XMLHasAttr := FindAttrIndex(Node, Name) >= 0;
end;

function XMLGetText(const Node: PXMLNode): string;
var
  Len: Word;
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
  { Fast block copy using Move }
  Move(Node^.TextBuf^, Result[1], Len);

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

  { Free dynamically allocated attribute strings }
  for i := 0 to Node^.AttrCount - 1 do
  begin
    if Node^.AttrKeys[i] <> nil then
    begin
      FreeMem(Node^.AttrKeys[i], StrLen(Node^.AttrKeys[i]) + 1);
      Node^.AttrKeys[i] := nil;
    end;
    if Node^.AttrValues[i] <> nil then
    begin
      FreeMem(Node^.AttrValues[i], StrLen(Node^.AttrValues[i]) + 1);
      Node^.AttrValues[i] := nil;
    end;
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

{ ===== XML writer ===== }

procedure WriteStrToFile(var F: Text; const S: string);
begin
  if Length(S) > 0 then
    Write(F, S);
end;

procedure WriteCharToFile(var F: Text; C: Char);
begin
  Write(F, C);
end;

procedure WriteEscapedString(var F: Text; const S: string; ForAttr: Boolean);
var
  i, start: Integer;
  c: Char;
  tmp: string;
begin
  start := 1;
  i := 1;
  while i <= Length(S) do
  begin
    c := S[i];

    if (c = '&') or (c = '<') or (c = '>') or
       (ForAttr and ((c = '"') or (c = ''''))) then
    begin
      { flush pending normal chars }
      if i > start then
      begin
        tmp := Copy(S, start, i - start);
        WriteStrToFile(F, tmp);
      end;

      case c of
        '&': WriteStrToFile(F, '&amp;');
        '<': WriteStrToFile(F, '&lt;');
        '>': WriteStrToFile(F, '&gt;');
        '"': WriteStrToFile(F, '&quot;');
        '''': WriteStrToFile(F, '&apos;');
      end;

      Inc(i);
      start := i;
    end
    else
      Inc(i);
  end;

  { flush any remaining chars }
  if start <= Length(S) then
  begin
    tmp := Copy(S, start, Length(S) - start + 1);
    WriteStrToFile(F, tmp);
  end;
end;

procedure WriteEscapedTextBuf(var F: Text; Node: PXMLNode);
var
  i: Word;
  p: ^Byte;
  c: Char;
begin
  if (Node = nil) or (Node^.TextBuf = nil) or (Node^.TextLen = 0) then
    Exit;

  p := Node^.TextBuf;

  { Walk every byte in the TextBuf and stream it out char-by-char,
    escaping special XML characters. No temporary strings, no 255 limit. }
  for i := 1 to Node^.TextLen do
  begin
    c := Char(p^);

    case c of
      '&': WriteStrToFile(F, '&amp;');
      '<': WriteStrToFile(F, '&lt;');
      '>': WriteStrToFile(F, '&gt;');
      '"': WriteStrToFile(F, '&quot;');
      '''': WriteStrToFile(F, '&apos;');
    else
      WriteCharToFile(F, c);
    end;

    Inc(p);
  end;
end;


procedure WriteIndent(var F: Text; Level: Integer);
var
  i: Integer;
begin
  for i := 1 to Level do
    WriteStrToFile(F, '  ');  { 2 spaces per level }
end;

procedure WriteNodeRecursive(var F: Text; Node: PXMLNode; Indent: Integer);
var
  i: Integer;
  child: PXMLNode;
  hasChildren, hasText: Boolean;
begin
  if Node = nil then
    Exit;

  { skip synthetic document root in recursion (handled in XMLSaveFile) }
  if Node^.Name = '#document' then
  begin
    child := Node^.FirstChild;
    while child <> nil do
    begin
      WriteNodeRecursive(F, child, Indent);
      child := child^.NextSibling;
    end;
    Exit;
  end;

  hasChildren := Node^.FirstChild <> nil;
  hasText := (Node^.TextBuf <> nil) and (Node^.TextLen > 0);

  { Opening tag }
  WriteIndent(F, Indent);
  WriteCharToFile(F, '<');
  WriteStrToFile(F, Node^.Name);

  { Attributes }
  for i := 0 to Node^.AttrCount - 1 do
  begin
    if Node^.AttrKeys[i] <> nil then
    begin
      WriteCharToFile(F, ' ');
      WriteStrToFile(F, StrPas(Node^.AttrKeys[i]));
      WriteCharToFile(F, '=');
      WriteCharToFile(F, '"');
      if Node^.AttrValues[i] <> nil then
        WriteEscapedString(F, StrPas(Node^.AttrValues[i]), True)
      else
        WriteEscapedString(F, '', True);
      WriteCharToFile(F, '"');
    end;
  end;

  if (not hasChildren) and (not hasText) then
  begin
    { Self-closing empty element }
    WriteStrToFile(F, '/>');
    WriteStrToFile(F, #13#10);
    Exit;
  end;

  WriteCharToFile(F, '>');
  { Text content (if any) }
  if hasText then
    WriteEscapedTextBuf(F, Node);

  { Child elements }
  if hasChildren then
  begin
    WriteStrToFile(F, #13#10);
    child := Node^.FirstChild;
    while child <> nil do
    begin
      WriteNodeRecursive(F, child, Indent + 1);
      child := child^.NextSibling;
    end;
    WriteIndent(F, Indent);
  end;

  { Closing tag }
  WriteStrToFile(F, '</');
  WriteStrToFile(F, Node^.Name);
  WriteCharToFile(F, '>');
  WriteStrToFile(F, #13#10);
end;

function XMLSaveFile(const FileName: string; Root: PXMLNode): Boolean;
var
  F: Text;
  Top: PXMLNode;
begin
  XMLSaveError := '';
  XMLSaveFile := False;

  if Root = nil then
  begin
    XMLSaveError := 'Root node is nil.';
    Exit;
  end;

  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  if IOResult <> 0 then
  begin
    XMLSaveError := 'Cannot create XML file: ' + FileName;
    Exit;
  end;

  { XML declaration – you can change encoding if you like }
  WriteStrToFile(F, '<?xml version="1.0" encoding="US-ASCII"?>');
  WriteStrToFile(F, #13#10);

  { If Root is a synthetic #document, write its children as top-level elements }
  if Root^.Name = '#document' then
    Top := Root^.FirstChild
  else
    Top := Root;

  if Top = nil then
  begin
    { empty document – technically allowed, but odd }
    Close(F);
    XMLSaveFile := True;
    Exit;
  end;

  if Root^.Name = '#document' then
  begin
    while Top <> nil do
    begin
      WriteNodeRecursive(F, Top, 0);
      Top := Top^.NextSibling;
    end;
  end
  else
    WriteNodeRecursive(F, Top, 0);

  Close(F);
  XMLSaveFile := True;
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
  SrcPtr: Pointer;
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

  { Fast block copy using Move }
  SrcPtr := Ptr(Seg(B.Data^), Ofs(B.Data^) + StartPos - 1);
  Move(SrcPtr^, Result[1], Len);

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
var
  P: ^Byte;
  ch: Char;
begin
  { Inline BEOF, BPeek, and IsWhite for speed }
  while B.Pos <= B.Len do
  begin
    P := Ptr(Seg(B.Data^), Ofs(B.Data^) + B.Pos - 1);
    ch := Char(P^);
    if not ((ch = ' ') or (ch = #9) or (ch = #10) or (ch = #13)) then Exit;
    Inc(B.Pos);
  end;
end;

function StartsWithAt(var B: TBuf; const Pat: string; idx: Integer): Boolean;
var
  Len: Byte;
  P: ^Byte;
  PatPtr: ^Byte;
  i: Integer;
begin
  StartsWithAt := False;
  Len := Length(Pat);
  if (Len = 0) or (idx + Len - 1 > B.Len) then Exit;

  P := Ptr(Seg(B.Data^), Ofs(B.Data^) + idx - 1);
  PatPtr := @Pat[1];

  { Optimize for common cases first (unrolled loop) }
  if Len >= 1 then if P^ <> PatPtr^ then Exit;
  if Len >= 2 then
  begin
    Inc(P); Inc(PatPtr);
    if P^ <> PatPtr^ then Exit;
    Inc(P); Inc(PatPtr);
  end;

  { Handle remaining characters if any }
  for i := 3 to Len do
  begin
    if P^ <> PatPtr^ then Exit;
    Inc(P);
    Inc(PatPtr);
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
  start: Integer;
  P: ^Byte;
  ch: Char;
begin
  start := B.Pos;
  { Inline BEOF and BPeek for speed }
  while B.Pos <= B.Len do
  begin
    P := Ptr(Seg(B.Data^), Ofs(B.Data^) + B.Pos - 1);
    ch := Char(P^);
    if (ch in ['a'..'z','A'..'Z','0'..'9','_','-','.',':']) then
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
  XMLLoadError := '';

  { Read the whole file into dynamically allocated buffer }
  Assign(F, FileName);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult <> 0 then
  begin
    XMLLoadError := 'File not found: ' + FileName;
    XMLLoadFile := False;
    Exit;
  end;

  sz := FileSize(F);

  { Hard cap for single near-pointer block in TP7 real mode }
  if sz <= 0 then
  begin
    Close(F);
    XMLLoadError := 'Empty file';
    XMLLoadFile := False;
    Exit;
  end;

  if sz > 65500 then
  begin
    Close(F);
    XMLLoadError := 'File too large (max 65500 bytes)';
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
        if Root^.Name <> '#document' then  { Root is already non-nil in else block }
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

  if Root = nil then
  begin
    XMLLoadError := 'No valid XML elements found';
    XMLLoadFile := False;
  end
  else
    XMLLoadFile := True;
end;

function XMLReadWordArray(const Node: PXMLNode; var Arr: PWord; var Count: Word): Boolean;
var
  SrcPtr: Pointer;
  SrcLen: Word;
  p: ^Byte;
  ch: Char;
  inNum: Boolean;
  tmpVal: LongInt;
  idx: Word;
  MaxCount: Word;
  ArrAccess: PWordArray;
  i: Word;
begin
  Arr := nil; Count := 0;

  { Early exit checks }
  if (Node = nil) or (Node^.TextBuf = nil) or (Node^.TextLen = 0) then
  begin
    XMLReadWordArray := False;
    Exit;
  end;

  SrcPtr := Node^.TextBuf;
  SrcLen := Node^.TextLen;

  { Estimate max count: worst case is every other char is a separator }
  MaxCount := (SrcLen + 1) shr 1;  { Divide by 2 using shift }
  if MaxCount = 0 then MaxCount := 1;

  { Allocate for estimated max }
  GetMem(Arr, MaxCount * SizeOf(Word));
  ArrAccess := PWordArray(Arr);

  { Single-pass parsing }
  idx := 0;
  inNum := False;
  tmpVal := 0;
  p := SrcPtr;

  for i := 1 to SrcLen do
  begin
    ch := Char(p^);
    if (ch >= '0') and (ch <= '9') then
    begin
      inNum := True;
      tmpVal := tmpVal * 10 + Ord(ch) - Ord('0');
      if tmpVal > 65535 then tmpVal := 65535; { clamp to Word }
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

  { Handle trailing number }
  if inNum then
  begin
    ArrAccess^[idx] := Word(tmpVal);
    Inc(idx);
  end;

  Count := idx;

  if Count = 0 then
  begin
    FreeMem(Arr, MaxCount * SizeOf(Word));
    Arr := nil;
    XMLReadWordArray := False;
  end
  else
    XMLReadWordArray := True;
end;

procedure XMLSetText(Node: PXMLNode; const S: string);
var
  L: Word;
begin
  if Node = nil then Exit;

  { We reuse existing buffer if it's big enough, so just reset length }
  Node^.TextLen := 0;

  L := Length(S);
  if L = 0 then Exit;   { empty text => no buffer needed }

  EnsureBuf(Node, L);   { alloc/grow buffer if needed }

  { copy string (1-based) into TextBuf }
  Move(S[1], Node^.TextBuf^, L);
  Node^.TextLen := L;
end;

procedure XMLAppendText(Node: PXMLNode; const S: string);
var
  L: Word;
  Dest: Pointer;
begin
  if (Node = nil) or (S = '') then Exit;

  L := Length(S);
  EnsureBuf(Node, L);   { make sure we have room for appending L bytes }

  { write after existing text }
  Dest := Ptr(Seg(Node^.TextBuf^), Ofs(Node^.TextBuf^) + Node^.TextLen);
  Move(S[1], Dest^, L);
  Inc(Node^.TextLen, L);
end;

function XMLAddChildElement(Parent: PXMLNode; const Name: string): PXMLNode;
var
  P: PXMLNode;
  N: string[XML_MaxNameLength];
begin
  XMLAddChildElement := nil;
  if Parent = nil then Exit;

  New(P);
  XMLInitNode(P^);

  { clamp name to XML_MaxNameLength }
  N := Copy(Name, 1, XML_MaxNameLength);
  P^.Name := N;

  XMLAddChild(Parent, P);
  XMLAddChildElement := P;
end;

end.
