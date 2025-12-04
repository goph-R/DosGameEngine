# LINKLIST - Linked List

Generic doubly-linked list for pointer values.

## Types

```pascal
type
  PListValue = Pointer;

  TListEntry = record
    Next, Prev: PListEntry;
    Value: PListValue;
  end;
  PListEntry = ^TListEntry;

  TLinkedList = record
    First, Last: PListEntry;
    Count: Word;
  end;
```

## Functions

```pascal
procedure ListInit(var List: TLinkedList);
function ListAdd(var List: TLinkedList; Value: PListValue): PListEntry;
procedure ListRemove(var List: TLinkedList; Entry: PListEntry);
function ListRemoveByValue(var List: TLinkedList; Value: PListValue): Boolean;
function ListContains(var List: TLinkedList; Value: PListValue): Boolean;
procedure ListFree(var List: TLinkedList);
```

## Example

```pascal
uses LinkList;

var
  List: TLinkedList;
  Item: PListEntry;
  MyData: Pointer;
begin
  ListInit(List);

  ListAdd(List, Ptr($1234));
  ListAdd(List, Ptr($5678));

  Item := List.First;
  while Item <> nil do
  begin
    MyData := Item^.Value;
    { Process MyData... }
    Item := Item^.Next;
  end;

  ListRemoveByValue(List, Ptr($1234));
  ListFree(List);
end;
```

## Notes

- Stores generic pointers (`Pointer`), cast to your type
- `ListFree` disposes entries but NOT the values (caller's responsibility)
- O(1) add/remove, O(n) search
