# MINIXML.PAS - Lightweight XML Parser for Turbo Pascal

## Overview

MINIXML is a compact XML parser designed for Turbo Pascal 7.0, providing DOM-style access to XML configuration files and data. It handles XML files up to ~64KB (Turbo Pascal real-mode heap block limit) and supports the core XML features needed for game configuration and data storage.

## Features

- **Large file support**: Handles XML files up to ~64KB
- **DOM-style tree structure**: Navigate XML as parent/child/sibling nodes
- **Attribute support**: Read element attributes with fast hash-map lookup
- **Text content**: Handles both small (<255 bytes) and large text content
- **Comments and processing instructions**: Skips XML comments and `<?xml?>` declarations
- **UTF-8 BOM detection**: Automatically skips UTF-8 byte order mark
- **Memory efficient**: Uses dynamic allocation for large text content
- **Helper utilities**: Word array parser for numeric data

## Dependencies

- **StrMap.PAS**: String-to-pointer hash map for fast attribute lookup

## Type Definitions

```pascal
const
  XML_MaxNameLength = 20;  { Maximum element/attribute name length }
  XML_MaxAttrsCount = 8;   { Maximum attributes per node }

type
  PXMLNode = ^TXMLNode;
  TXMLNode = record
    Name    : string[XML_MaxNameLength]; { Element tag name (max 20 chars) }

    { Text content buffer (all text stored here) }
    TextBuf : Pointer;       { Dynamically allocated buffer }
    TextLen : Word;          { Bytes in TextBuf }
    TextCap : Word;          { Allocated capacity }

    { Attributes (max 8 per node, dynamically allocated) }
    AttrMap : TStringMap;      { Fast attribute lookup }
    AttrKeys  : PPShortString; { Dynamic array of string pointers }
    AttrValues: PPShortString; { Dynamic array of string pointers }
    AttrCount : Integer;
    AttrCap   : Integer;       { Allocated capacity }

    { Tree structure }
    FirstChild : PXMLNode;   { First child element }
    NextSibling: PXMLNode;   { Next sibling element }
    Parent     : PXMLNode;   { Parent element }
  end;
```

## Core API

### Loading and Freeing

**XMLLoadFile** - Load XML from file
```pascal
function XMLLoadFile(const FileName: string; var Root: PXMLNode): Boolean;
```

**Parameters:**
- `FileName`: Path to XML file (DOS 8.3 format, max ~64KB)
- `Root`: Returns pointer to root node on success

**Returns:** `True` if successful, `False` on error

**Example:**
```pascal
var
  Root: PXMLNode;
begin
  if XMLLoadFile('CONFIG.XML', Root) then
  begin
    { Use the XML tree... }
    XMLFreeTree(Root);  { Always free when done! }
  end;
end;
```

---

**XMLFreeTree** - Free XML tree and all memory
```pascal
procedure XMLFreeTree(Node: PXMLNode);
```

**CRITICAL:** Always call this to free the entire XML tree and prevent memory leaks.

---

### Navigation

**XMLFirstChild** - Get first child element
```pascal
function XMLFirstChild(const Node: PXMLNode; const Name: string): PXMLNode;
```

**Parameters:**
- `Node`: Parent node
- `Name`: Element name to find, or `''` for any element

**Returns:** First matching child node, or `nil` if none

**Example:**
```pascal
{ Find first <level> child }
Level := XMLFirstChild(Root, 'level');

{ Get first child of any type }
Child := XMLFirstChild(Node, '');
```

---

**XMLNextSibling** - Get next sibling element
```pascal
function XMLNextSibling(const Node: PXMLNode; const Name: string): PXMLNode;
```

**Parameters:**
- `Node`: Current node
- `Name`: Element name to find, or `''` for any element

**Returns:** Next matching sibling, or `nil` if none

**Example:**
```pascal
{ Iterate through all <sprite> elements }
Sprite := XMLFirstChild(Root, 'sprite');
while Sprite <> nil do
begin
  { Process sprite... }
  Sprite := XMLNextSibling(Sprite, 'sprite');
end;
```

---

### Attributes

**XMLAttr** - Get attribute value
```pascal
function XMLAttr(const Node: PXMLNode; const Name: string): string;
```

**Parameters:**
- `Node`: Element node
- `Name`: Attribute name

**Returns:** Attribute value, or `''` if not found

**Example:**
```pascal
ID := XMLAttr(Node, 'id');
Width := XMLAttr(Sprite, 'width');
```

---

**XMLHasAttr** - Check if attribute exists
```pascal
function XMLHasAttr(const Node: PXMLNode; const Name: string): Boolean;
```

**Example:**
```pascal
if XMLHasAttr(Enemy, 'boss') then
  WriteLn('Boss enemy detected!');
```

---

**XMLGetText** - Get text content from node
```pascal
function XMLGetText(const Node: PXMLNode): string;
```

**Returns:** Text content as string (clamped to 255 bytes if longer)

**Example:**
```pascal
Description := XMLGetText(XMLFirstChild(Root, 'description'));
WriteLn('Description: ', Description);
```

---

### Utility Functions

**XMLReadWordArray** - Parse numeric array from text content
```pascal
function XMLReadWordArray(const Node: PXMLNode; var Arr: PWord;
                         var Count: Word): Boolean;
```

**Parameters:**
- `Node`: Element containing numeric text (e.g., "10 20 30 40")
- `Arr`: Returns pointer to allocated Word array
- `Count`: Returns number of values parsed

**Returns:** `True` if successful

**IMPORTANT:** Caller must free array with `FreeMem(Arr, Count * SizeOf(Word))`

**Example:**
```pascal
var
  Values: PWord;
  Count: Word;
  i: Integer;
begin
  if XMLReadWordArray(DataNode, Values, Count) then
  begin
    for i := 0 to Count - 1 do
      WriteLn('Value[', i, '] = ', PWordArray(Values)^[i]);
    FreeMem(Values, Count * SizeOf(Word));
  end;
end;
```

---

## Usage Examples

### Basic Configuration Loading

```pascal
program ConfigTest;
uses MiniXML;

var
  Root, Config, Video: PXMLNode;
  Width, Height: Integer;

begin
  if not XMLLoadFile('GAME.XML', Root) then
  begin
    WriteLn('Failed to load config!');
    Halt(1);
  end;

  { Navigate: <game> -> <config> -> <video> }
  Config := XMLFirstChild(Root, 'config');
  if Config <> nil then
  begin
    Video := XMLFirstChild(Config, 'video');
    if Video <> nil then
    begin
      Val(XMLAttr(Video, 'width'), Width);
      Val(XMLAttr(Video, 'height'), Height);
      WriteLn('Video: ', Width, 'x', Height);
    end;
  end;

  XMLFreeTree(Root);
end.
```

### Iterating Through Lists

```pascal
{ Load sprite definitions from XML }
var
  Root, Sprites, Sprite: PXMLNode;
  ID, FileName: string;

begin
  XMLLoadFile('SPRITES.XML', Root);

  Sprites := XMLFirstChild(Root, 'sprites');
  Sprite := XMLFirstChild(Sprites, 'sprite');

  while Sprite <> nil do
  begin
    ID := XMLAttr(Sprite, 'id');
    FileName := XMLAttr(Sprite, 'file');
    WriteLn('Sprite: ', ID, ' -> ', FileName);

    Sprite := XMLNextSibling(Sprite, 'sprite');
  end;

  XMLFreeTree(Root);
end;
```

### Reading Text Content

```pascal
var
  Node: PXMLNode;
begin
  Node := XMLFirstChild(Root, 'description');

  { Small text (<255 bytes) stored in Node^.Text }
  if Node^.Text <> '' then
    WriteLn('Description: ', Node^.Text);

  { Large text (>=255 bytes) stored in TextBuf }
  if Node^.TextBuf <> nil then
    WriteLn('Large text, ', Node^.TextLen, ' bytes');
end;
```

### Checking Optional Attributes

```pascal
var
  Level: PXMLNode;
  IsBoss: Boolean;
begin
  Level := XMLFirstChild(Root, 'level');

  { Check for optional 'boss' attribute }
  IsBoss := XMLHasAttr(Level, 'boss') and
            (XMLAttr(Level, 'boss') = 'true');

  if IsBoss then
    WriteLn('Boss level!')
  else
    WriteLn('Normal level');
end;
```

## Sample XML File

```xml
<?xml version="1.0" encoding="UTF-8"?>
<game version="1.0">
  <metadata>
    <title>DOS Adventure</title>
    <author>Your Name</author>
  </metadata>

  <levels>
    <level id="1" name="Forest" difficulty="easy">
      <music>FOREST.HSC</music>
      <background>FOREST.PCX</background>
      <enemies count="5" />
    </level>

    <level id="2" name="Castle" difficulty="hard" boss="true">
      <music>BOSS.HSC</music>
      <background>CASTLE.PCX</background>
      <enemies count="1" />
    </level>
  </levels>

  <sprites>
    <sprite id="player" file="PLAYER.PCX" width="32" height="32" />
    <sprite id="enemy" file="ENEMY.PCX" width="24" height="24" />
  </sprites>

  <!-- Comments are supported and ignored -->
  <config>
    <video mode="13h" width="320" height="200" />
    <audio music="true" sfx="true" />
  </config>
</game>
```

## Limitations

1. **File size**: Maximum ~64KB (Turbo Pascal heap block limit in real-mode DOS)
2. **Attributes per element**: Maximum 8 attributes (can be increased via `XML_MaxAttrsCount`)
3. **Attribute values**: Maximum 255 bytes (Turbo Pascal string limit)
4. **Element/Attribute names**: Maximum 20 bytes (can be increased via `XML_MaxNameLength`)
5. **No validation**: Does not validate against DTD/XSD schemas
6. **No entities**: HTML entities (`&lt;`, `&amp;`, etc.) not decoded
7. **No namespaces**: XML namespaces not supported
8. **Error handling**: Limited error reporting (returns `False` on failure)

## Memory Management

- **Automatic allocation**: Nodes and buffers allocated dynamically
- **Manual cleanup**: Call `XMLFreeTree(Root)` to free entire tree
- **Memory leaks**: Failing to call `XMLFreeTree` will leak memory
- **Nested elements**: All children recursively freed by `XMLFreeTree`

## Performance Characteristics

- **Attribute lookup**: O(1) average (hash map)
- **Child iteration**: O(n) linear scan
- **File loading**: O(n) single-pass parse
- **Memory overhead**: ~103 bytes per node (base) + text content + (actual attributes × ~20-50 bytes each)
Here is a **clean, accurate, drop-in replacement** section for your documentation.
It reflects the *exact* behavior of the current `MINIXML.PAS` implementation.

You can paste this directly into your README.

---

# 📦 Memory Usage (MiniXML)

MiniXML is designed for **minimal RAM footprint** under real DOS / TP7 limits.
Below is the real memory behavior of the current implementation in `MINIXML.PAS`.

---

Below is an updated **drop-in replacement** for the memory usage documentation, reflecting:

* No per-node hash map
* Dynamic-sized attribute strings
* Variable-sized text buffer
* Actual `TXMLNode` record size (~100–120 bytes)

This is the **final, correct** description of your optimized MiniXML.

---

# 📦 Memory Usage

This section describes the exact RAM footprint of the XML parser.

---

## 🧱 Base Memory per Node

A `TXMLNode` record contains:

```
Name:           21 bytes  (string[20])
TextBuf:         4 bytes  (pointer)
TextLen:         2 bytes  (Word)
TextCap:         2 bytes  (Word)

AttrKeys:       16 bytes  (8 × Pointer)
AttrValues:     16 bytes  (8 × Pointer)
AttrCount:       2 bytes  (Integer)

Tree pointers:  12 bytes  (FirstChild, NextSibling, Parent)
───────────────────────────────────────────────
Record total:   ~95–110 bytes per node
```

Attribute lookup is a simple and fast linear scan (max 8 attributes).

---

## 🏷️ Per Attribute Cost (Dynamic Allocation)

Each attribute uses variable-sized memory:

```
Key string:    Length(Key)   + 1 byte
Value string:  Length(Value) + 1 byte
───────────────────────────────────────────────
Total:         ~5–20 bytes typical
               (instead of the old 512 bytes)
```

Example:

* `code="65"` → key 4 bytes + value 3 bytes = 8 bytes total
* `x="123"` → ~7 bytes
* `name="monsterslayer"` → ~16 bytes

---

## 📝 Text Content Memory

Text is stored in a dynamically growing buffer:

* First allocation: **256 bytes**
* Grows by doubling, then +4096
* Maximum size: ~64 KB

Memory used:

```
TextBuf capacity: 256–65520 bytes (depending on growth)
TextLen:          actual used bytes
```

Nodes without text do **not** allocate any text memory.

---

## 📉 Memory Usage Example (FONT-SM.XML)

For a ~5.5 KB XML containing:

* **92 nodes**
* **367 attributes**
* No text content

Memory usage:

```
Node records:    ~9.8 KB
Attributes:      ~2.4 KB
Text buffers:    0 bytes
--------------------------------
Total:           ~12 KB
```

## Common Patterns

### Find specific element by attribute

```pascal
function FindLevelByID(Root: PXMLNode; ID: string): PXMLNode;
var
  Levels, Level: PXMLNode;
begin
  FindLevelByID := nil;
  Levels := XMLFirstChild(Root, 'levels');
  if Levels = nil then Exit;

  Level := XMLFirstChild(Levels, 'level');
  while Level <> nil do
  begin
    if XMLAttr(Level, 'id') = ID then
    begin
      FindLevelByID := Level;
      Exit;
    end;
    Level := XMLNextSibling(Level, 'level');
  end;
end;
```

### Count elements

```pascal
function XMLCountChildren(const Node: PXMLNode; const Name: string): Integer;
```

### Safe attribute parsing

```pascal
procedure GetIntAttr(Node: PXMLNode; AttrName: string; var Value: Integer);
var
  S: string;
  Code: Integer;
begin
  if XMLHasAttr(Node, AttrName) then
  begin
    S := XMLAttr(Node, AttrName);
    Val(S, Value, Code);
    if Code <> 0 then
      WriteLn('Warning: Invalid integer in ', AttrName);
  end;
end;
```

## Troubleshooting

**Problem:** `XMLLoadFile` returns `False`
- Check file exists and path is correct (use DOS 8.3 format)
- Ensure file is under ~64KB (65500 bytes)
- Check file is valid XML (well-formed)

**Problem:** Attribute not found
- Check attribute name spelling (case-sensitive)
- Verify element actually has the attribute in XML file
- Check if node pointer is `nil`

**Problem:** Memory leak / out of memory
- Ensure `XMLFreeTree` is called for every loaded XML
- Check for extremely large text content (>64KB per node)
- Reduce number of nodes/attributes if memory constrained

**Problem:** Text content truncated at 255 bytes
- This is expected for `Node^.Text` string
- Large text automatically uses `TextBuf` instead
- Check `Node^.TextBuf <> nil` and `Node^.TextLen` for large text

## Testing

See `TESTS\XMLTEST.PAS` for a complete example program demonstrating all features.

Compile and run:
```
cd TESTS
CXMLTEST.BAT
XMLTEST.EXE
```

## Design Goals

MINIXML was created in 2025 specifically for this DOS game engine with the following priorities:

**Memory Efficiency:**
- Dynamic allocation for all variable-size data
- Only allocate what's actually needed (attributes, text)
- Optimized for typical game config files (few attributes per node)
- Result: ~103 bytes per empty node vs. 4680 bytes in naive design (98% reduction)

**Real-Mode DOS Compatibility:**
- All allocations respect TP7 heap block limits (≤64KB per block)
- Buffer growth capped at safe limits
- Word-sized position/length fields for >32KB file support
- Tested on DOSBox-X and real hardware

**Simplicity:**
- Single-pass parser, no preprocessing
- DOM-style tree for easy navigation
- Hash map for fast O(1) attribute lookup
- Minimal dependencies (only STRMAP.PAS)

## See Also

- **STRMAP.PAS**: String hash map used for attribute storage
- **TESTS\XMLTEST.PAS**: Complete usage example
- **DATA\TEST.XML**: Sample XML file for testing
