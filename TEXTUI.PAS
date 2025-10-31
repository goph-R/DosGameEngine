unit TextUI;

interface

const
  ScreenCols = 80;
  ScreenRows = 25;

type
  PMenuItem = ^TMenuItem;
  TMenuItemProc = procedure;

  TMenuItem = record
    Text: string[40];           { Menu item text }
    Process: TMenuItemProc;     { Procedure to call when selected }
    NextMenuItem: PMenuItem;    { Pointer to next item (nil = last) }
    Disabled: Boolean;          { Is this item disabled? }
  end;

  PMenu = ^TMenu;
  TMenu = record
    Title: string[40];          { Menu title }
    FirstMenuItem: PMenuItem;   { Pointer to first menu item }
    Col: Integer;               { Menu column position }
    Row: Integer;               { Menu row position }
    Width: Integer;             { Menu width }
    SelectedIndex: Integer;     { Index of the selected item }
  end;

var
  VidMem : array[0..3999] of byte absolute $B800:0000;

{ Cursor management }
procedure HideTextCursor;
procedure ShowTextCursor;
procedure SetTextCursorPosition(Row: Integer; Col: Integer);

{ Text rendering }
function GetColumnForCenter(s: string): Integer;
procedure PutCharAt(Col, Row: Integer; Ch: Byte; Color: Byte);
procedure RenderText(Col: Integer; Row: Integer; s: string; Color: Byte);
procedure RenderCenterText(Row: Integer; s: string; Color: Byte);
procedure RenderEmptyLine(Row: Integer; Color: Byte);

{ Box rendering }
procedure RenderTextBox(Col: Integer; Row: Integer; Width: Word; Height: Word;
                    BoxColor: Byte; ShadowColor: Byte);
procedure RenderTextBackground;

{ Menu management }
function AddMenuItem(var Menu: TMenu; const Text: string; Process: TMenuItemProc): PMenuItem;
function AddEmptyMenuItem(var Menu: TMenu): PMenuItem;
function CountMenuItems(var Menu: TMenu): Integer;
function GetMenuItem(var Menu: TMenu; Index: Integer): PMenuItem;
procedure RenderMenu(var Menu: TMenu; SelectedIndex: Integer; WithBox: Boolean);
procedure FreeMenu(var Menu: TMenu);
procedure SetMenu(var Menu: TMenu);
procedure StartMenu;
procedure StopMenu;

{ Dialogs }
function ShowMessage(Message: string; Info: String): Byte;

{ Input }
function ShowInput(Col: Integer; Row: Integer; Width: Integer; CurrentValue: string): string;

implementation

uses Keyboard;

var
  CurrentMenu: PMenu;
  Running: Boolean;

{ Far calls required for procedure pointers }
{$F+}  

procedure DoNothing;
begin
end;

{ Restore near calls }
{$F-} 

procedure HideTextCursor; assembler;
asm
  mov ah, 1
  mov ch, 32
  mov cl, 0
  int 10h
end;

procedure ShowTextCursor; assembler;
asm
  mov ah, 1
  mov ch, 6
  mov cl, 7
  int 10h
end;

procedure SetTextCursorPosition(Row: Integer; Col: Integer); assembler;
asm
  mov ah, 2    { BIOS function: Set cursor position }
  mov bh, 0    { Page number (0 = default) }
  mov dh, byte ptr Row
  mov dl, byte ptr Col
  int 10h
end;

function GetColumnForCenter(s: string): Integer;
var
  Col: Integer;
begin
  Col := (ScreenCols - Length(s)) div 2;
  if Col < 0 then Col := 0;
  GetColumnForCenter := Col;
end;

procedure PutCharAt(Col, Row: Integer; Ch: Byte; Color: Byte);
var
  Offset: Word;
begin
  { Each row has ScreenCols chars. Each char is 2 bytes in B800:0000. }
  Offset := (Row * ScreenCols + Col) * 2;
  VidMem[Offset]     := Ch;
  VidMem[Offset + 1] := Color;
end;

procedure RenderText(Col: Integer; Row: Integer; s: string; Color: Byte);
var
  i: Integer;
begin
  for i := 1 to Length(s) do
  begin
    PutCharAt(Col + (i - 1), Row, Ord(s[i]), Color);
  end;
end;

procedure RenderTextBox(
  Col: Integer; Row: Integer; Width: Word; Height: Word;
  BoxColor: Byte; ShadowColor: Byte);
const
  CH_TL = 201;
  CH_TR = 187;
  CH_BL = 200;
  CH_BR = 188;
  CH_H  = 205;
  CH_V  = 186;
var
  x, y: Integer;
  RightCol, BottomRow: Integer;
begin
  if (Width < 2) or (Height < 2) then Exit;

  RightCol  := Col + Width - 1;
  BottomRow := Row + Height - 1;

  { --- 1) Fill box area first ------------------------------------ }
  for y := Row to BottomRow do
    for x := Col to RightCol do
      PutCharAt(x, y, Ord(' '), BoxColor);

  { --- 2) Draw border on top of fill ----------------------------- }

  { Corners }
  PutCharAt(Col,       Row,       CH_TL, BoxColor);
  PutCharAt(RightCol,  Row,       CH_TR, BoxColor);
  PutCharAt(Col,       BottomRow, CH_BL, BoxColor);
  PutCharAt(RightCol,  BottomRow, CH_BR, BoxColor);

  { Top & bottom edges }
  if Width > 2 then
    for x := Col + 1 to RightCol - 1 do
    begin
      PutCharAt(x, Row,       CH_H, BoxColor);
      PutCharAt(x, BottomRow, CH_H, BoxColor);
    end;

  { Left & right edges }
  if Height > 2 then
    for y := Row + 1 to BottomRow - 1 do
    begin
      PutCharAt(Col,      y, CH_V, BoxColor);
      PutCharAt(RightCol, y, CH_V, BoxColor);
    end;

  { --- 3) Draw drop shadow --------------------------------------- }
  { Right side shadow: one column to the right }
  { from Row+1 down to BottomRow+1 }
  for y := Row + 1 to BottomRow + 1 do
    VidMem[(RightCol + 1 + y * ScreenCols) * 2 + 1] := ShadowColor;
    {PutCharAt(RightCol + 1, y, Ord(' '), ShadowColor);}

  { Bottom side shadow: one row below, from Col+1 to RightCol+1 }
  for x := Col + 1 to RightCol + 1 do
    VidMem[(x + (BottomRow + 1) * ScreenCols) * 2 + 1] := ShadowColor;
    {PutCharAt(x, BottomRow + 1, Ord(' '), ShadowColor);}
end;

procedure RenderCenterText(Row: Integer; s: string; Color: Byte);
begin
  RenderText(GetColumnForCenter(s), Row, s, Color);
end;

procedure RenderTextBackground;
var
  i: Integer;
begin
  for i := 80 to 1919 do        { Skip first and last row }
  begin
    VidMem[i * 2]     := 177;   { ASCII character }
    VidMem[i * 2 + 1] := $17;   { blue, white }
  end;
end;

procedure RenderEmptyLine(Row: Integer; Color: Byte);
var
  i: Integer;
begin
  for i := 0 to ScreenCols - 1 do
  begin
    PutCharAt(i, Row, 32, Color);
  end;
end;


{ Menu management procedures }

{ Create a new menu item }
function CreateMenuItem(const Text: string; Process: TMenuItemProc): PMenuItem;
var
  Item: PMenuItem;
begin
  New(Item);
  Item^.Text := Text;
  Item^.Process := Process;
  Item^.NextMenuItem := nil;
  Item^.Disabled := False;
  CreateMenuItem := Item;
end;

{ Add a menu item to the end of the menu }
function AddMenuItem(var Menu: TMenu; const Text: string; Process: TMenuItemProc): PMenuItem;
var
  NewItem, Current: PMenuItem;
begin
  NewItem := CreateMenuItem(Text, Process);

  if Menu.FirstMenuItem = nil then
    Menu.FirstMenuItem := NewItem
  else
  begin
    Current := Menu.FirstMenuItem;
    while Current^.NextMenuItem <> nil do
      Current := Current^.NextMenuItem;
    Current^.NextMenuItem := NewItem;
  end;

  AddMenuItem := NewItem;
end;

function AddEmptyMenuItem(var Menu: TMenu): PMenuItem;
var
  Result: PMenuItem;
begin
  Result := AddMenuItem(Menu, '', DoNothing);
  Result^.Disabled := True;
  AddEmptyMenuItem := Result;
end;

{ Count menu items }
function CountMenuItems(var Menu: TMenu): Integer;
var
  Current: PMenuItem;
  Count: Integer;
begin
  Count := 0;
  Current := Menu.FirstMenuItem;
  while Current <> nil do
  begin
    Inc(Count);
    Current := Current^.NextMenuItem;
  end;
  CountMenuItems := Count;
end;

{ Get menu item by index (0-based) }
function GetMenuItem(var Menu: TMenu; Index: Integer): PMenuItem;
var
  Current: PMenuItem;
  i: Integer;
begin
  Current := Menu.FirstMenuItem;
  i := 0;
  while (Current <> nil) and (i < Index) do
  begin
    Current := Current^.NextMenuItem;
    Inc(i);
  end;
  GetMenuItem := Current;
end;

{ Render a menu }
procedure RenderMenu(var Menu: TMenu; SelectedIndex: Integer; WithBox: Boolean);
var
  Current: PMenuItem;
  Index: Integer;
  ItemColor: Byte;
  MenuHeight: Integer;
  i: Integer;
begin
  MenuHeight := CountMenuItems(Menu) + 4;

  { Draw box }
  if WithBox then
  begin
    RenderTextBackground;
    RenderTextBox(Menu.Col, Menu.Row, Menu.Width, MenuHeight, $1F, $08);
  end;

  { Draw title }
  RenderText(Menu.Col + 3, Menu.Row + 1, Menu.Title, $1E);

  { Draw menu items }
  Index := 0;
  Current := Menu.FirstMenuItem;
  while Current <> nil do
  begin
    { Determine color }
    if Current^.Disabled then
      ItemColor := $17  { Gray - disabled }
    else if Index = SelectedIndex then
      ItemColor := $71  { White on blue - selected }
    else
      ItemColor := $1F; { White on blue - normal }

    for i := Menu.Col + 2 to Menu.Col + Menu.Width - 3 do
      PutCharAt(i, Menu.Row + 3 + Index, Ord(' '), ItemColor);

    RenderText(Menu.Col + 2, Menu.Row + 3 + Index, ' ' + Current^.Text, ItemColor);

    Current := Current^.NextMenuItem;
    Inc(Index);
  end;
end;

{ Free all menu items }
procedure FreeMenu(var Menu: TMenu);
var
  Current, Next: PMenuItem;
begin
  Current := Menu.FirstMenuItem;
  while Current <> nil do
  begin
    Next := Current^.NextMenuItem;
    Dispose(Current);
    Current := Next;
  end;
  Menu.FirstMenuItem := nil;
end;

{ Runs a menu, sets the TMenu.SelectedIndex at the end }
procedure RunMenu(var Menu: TMenu);
var
  SelectedIndex: Integer;
  ItemCount: Integer;
  Done: Boolean;
  SelectedItem: PMenuItem;
  RunProcess: Boolean;
begin
  SelectedIndex := Menu.SelectedIndex;
  ItemCount := CountMenuItems(Menu);
  Done := False;
  RunProcess := False;

  { Ensure first item is never disabled }
  if Menu.FirstMenuItem <> nil then
    Menu.FirstMenuItem^.Disabled := False;

  RenderMenu(Menu, Menu.SelectedIndex, True);

  while not Done do
  begin
    { Handle input }
    if IsKeyPressed(Key_Up) then
    begin
      if SelectedIndex > 0 then
      begin
        Dec(SelectedIndex);
        { Skip disabled items }
        SelectedItem := GetMenuItem(Menu, SelectedIndex);
        while (SelectedItem <> nil) and SelectedItem^.Disabled and (SelectedIndex > 0) do
        begin
          Dec(SelectedIndex);
          SelectedItem := GetMenuItem(Menu, SelectedIndex);
        end;
      end;
      RenderMenu(Menu, SelectedIndex, False);
    end;

    if IsKeyPressed(Key_Down) then
    begin
      if SelectedIndex < ItemCount - 1 then
      begin
        Inc(SelectedIndex);
        { Skip disabled items }
        SelectedItem := GetMenuItem(Menu, SelectedIndex);
        while (SelectedItem <> nil) and SelectedItem^.Disabled and (SelectedIndex < ItemCount - 1) do
        begin
          Inc(SelectedIndex);
          SelectedItem := GetMenuItem(Menu, SelectedIndex);
        end;
      end;
      RenderMenu(Menu, SelectedIndex, False);
    end;

    if IsKeyPressed(Key_Enter) then
    begin
      SelectedItem := GetMenuItem(Menu, SelectedIndex);
      if (SelectedItem <> nil) and (not SelectedItem^.Disabled) then
      begin
        RunProcess := True;
        Done := True;
      end;
    end;

    ClearKeyPressed;
  end;

  Menu.SelectedIndex := SelectedIndex;

  if RunProcess then
    SelectedItem^.Process;
end;

function ShowMessage(Message: string; Info: String): Byte;
var
  Height: Integer;
  Row: Integer;
begin
  if Info <> '' then
    Height := 4
  else
    Height := 3;
  Row := 11 - Height div 2;
  RenderTextBox(10, Row, 60, Height, $1F, $08);
  RenderCenterText(Row + 1, Message, $1F);
  if Info <> '' then
    RenderCenterText(Row + 2, Info, $17);
  ShowMessage := WaitForAnyKeyPress;
end;

function ShowInput(Col: Integer; Row: Integer; Width: Integer; CurrentValue: string): string;
var
  Value: string;
  PrevValue: string;
  Done: Boolean;
  ShiftPressed: Boolean;
  i: Integer;
  ScanCode: Byte;
  Ch: Char;
begin
  Value := CurrentValue;
  if Length(Value) > Width then
    Value := Copy(Value, 1, Width);
  Done := False;
  PrevValue := '';

  { Show text cursor }
  ShowTextCursor;

  { Initial render }
  for i := 0 to Width - 1 do
    PutCharAt(Col + i, Row, Ord(' '), $71);
  RenderText(Col, Row, Value, $71);
  SetTextCursorPosition(Row, Col + Length(Value));

  while not Done do
  begin
    { Check shift state }
    ShiftPressed := IsKeyDown(Key_LShift) or IsKeyDown(Key_RShift);

    { Backspace - delete last character }
    if IsKeyPressed(Key_Backspace) then
    begin
      if Length(Value) > 0 then
        Delete(Value, Length(Value), 1);
    end;

    { Enter - confirm input }
    if IsKeyPressed(Key_Enter) then
      Done := True;

    { Character input - scan through all possible keys }
    if Length(Value) < Width then
    begin
      for ScanCode := 0 to 127 do
      begin
        if IsKeyPressed(ScanCode) then
        begin
          { Look up character from appropriate map }
          if ShiftPressed then
            Ch := CharMapShift[ScanCode]
          else
            Ch := CharMapNormal[ScanCode];

          { Add character if printable }
          if Ch <> #0 then
            Value := Value + Ch;
        end;
      end;
    end;

    { Only re-render if value changed }
    if Value <> PrevValue then
    begin
      { Clear input field }
      for i := 0 to Width - 1 do
        PutCharAt(Col + i, Row, Ord(' '), $71);

      { Render current value }
      RenderText(Col, Row, Value, $71);

      { Position cursor at end of text }
      SetTextCursorPosition(Row, Col + Length(Value));

      PrevValue := Value;
    end;

    ClearKeyPressed;
  end;

  { Hide text cursor }
  HideTextCursor;

  ShowInput := Value;
end;


procedure SetMenu(var Menu: TMenu);
begin
  CurrentMenu := @Menu;
end;


procedure StartMenu;
begin
  Running := True;
  while Running do
  begin
    RunMenu(CurrentMenu^);
  end;
end;

procedure StopMenu;
begin
  Running := False;
end;

end.