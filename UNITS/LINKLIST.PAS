unit LinkList;

{ Generic doubly-linked list container }
{ Stores pointers to any type of data (similar to StrMap but for linked lists) }

interface

type
  PListValue = Pointer;  { Pointer to any data type }

  PListEntry = ^TListEntry;
  TListEntry = record
    Next: PListEntry;
    Prev: PListEntry;
    Value: PListValue;
  end;

  TLinkedList = record
    First: PListEntry;
    Last: PListEntry;
    Count: Word;
  end;

{ Initialize a linked list }
procedure ListInit(var List: TLinkedList);

{ Add a value to the end of the list }
function ListAdd(var List: TLinkedList; Value: PListValue): PListEntry;

{ Remove an entry from the list }
procedure ListRemove(var List: TLinkedList; Entry: PListEntry);

{ Check if a value exists in the list }
function ListContains(const List: TLinkedList; Value: PListValue): Boolean;

{ Free all entries in the list }
procedure ListFree(var List: TLinkedList);

implementation

{ Initialize a linked list }
procedure ListInit(var List: TLinkedList);
begin
  List.First := nil;
  List.Last := nil;
  List.Count := 0;
end;

{ Add a value to the end of the list }
function ListAdd(var List: TLinkedList; Value: PListValue): PListEntry;
var
  Entry: PListEntry;
begin
  { Allocate new entry }
  New(Entry);
  Entry^.Value := Value;
  Entry^.Next := nil;
  Entry^.Prev := nil;

  { Add to list }
  if List.First = nil then
  begin
    { First entry in list }
    List.First := Entry;
    List.Last := Entry;
  end
  else
  begin
    { Append to end }
    Entry^.Prev := List.Last;
    List.Last^.Next := Entry;
    List.Last := Entry;
  end;

  Inc(List.Count);
  ListAdd := Entry;
end;

{ Remove an entry from the list }
procedure ListRemove(var List: TLinkedList; Entry: PListEntry);
begin
  if Entry = nil then
    Exit;

  { Update previous entry's Next pointer }
  if Entry^.Prev <> nil then
    Entry^.Prev^.Next := Entry^.Next
  else
    List.First := Entry^.Next;  { Entry was first }

  { Update next entry's Prev pointer }
  if Entry^.Next <> nil then
    Entry^.Next^.Prev := Entry^.Prev
  else
    List.Last := Entry^.Prev;  { Entry was last }

  { Free the entry }
  Dispose(Entry);
  Dec(List.Count);
end;

{ Check if a value exists in the list }
function ListContains(const List: TLinkedList; Value: PListValue): Boolean;
var
  Entry: PListEntry;
begin
  ListContains := False;
  Entry := List.First;

  while Entry <> nil do
  begin
    if Entry^.Value = Value then
    begin
      ListContains := True;
      Exit;
    end;
    Entry := Entry^.Next;
  end;
end;

{ Free all entries in the list }
procedure ListFree(var List: TLinkedList);
var
  Entry, NextEntry: PListEntry;
begin
  Entry := List.First;
  while Entry <> nil do
  begin
    NextEntry := Entry^.Next;
    Dispose(Entry);
    Entry := NextEntry;
  end;

  List.First := nil;
  List.Last := nil;
  List.Count := 0;
end;

end.
