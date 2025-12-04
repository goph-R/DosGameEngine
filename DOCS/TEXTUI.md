# TEXTUI - Text Mode UI

Text mode ($B800:0000) menu system for SETUP utility.

## Constants

```pascal
const
  ScreenCols = 80;
  ScreenRows = 25;
```

## Types

```pascal
type
  TMenuItemProc = procedure; {$F+}  { MUST be far call }

  TMenuItem = record
    Text: string;
    Process: TMenuItemProc;
    NextMenuItem: PMenuItem;
    Disabled: Boolean;
  end;
  PMenuItem = ^TMenuItem;

  TMenu = record
    Title: string;
    FirstMenuItem: PMenuItem;
    Col, Row, Width: Integer;
    SelectedIndex: Integer;
  end;
  PMenu = ^TMenu;
```

## Functions

### Cursor
```pascal
procedure HideTextCursor;
procedure ShowTextCursor;
procedure SetTextCursorPosition(Row, Col: Byte);
```

### Text Output
```pascal
procedure PutCharAt(Col, Row: Integer; Ch: Char; Color: Byte);
procedure RenderText(Col, Row: Integer; const Text: string; Color: Byte);
procedure RenderCenterText(Row: Integer; const Text: string; Color: Byte);
procedure RenderEmptyLine(Row: Integer; Color: Byte);
function GetColumnForCenter(const Text: string): Integer;
```

### Box Drawing
```pascal
procedure RenderTextBox(Col, Row, W, H: Integer; BoxColor, ShadowColor: Byte);
procedure RenderTextBackground;
```

### Menu System
```pascal
procedure AddMenuItem(var Menu: TMenu; const Text: string; Proc: TMenuItemProc);
procedure AddEmptyMenuItem(var Menu: TMenu);
function CountMenuItems(var Menu: TMenu): Integer;
function GetMenuItem(var Menu: TMenu; Index: Integer): PMenuItem;
procedure RenderMenu(var Menu: TMenu; Index: Integer; WithBox: Boolean);
procedure FreeMenu(var Menu: TMenu);
procedure SetMenu(Menu: PMenu);
procedure StartMenu;
procedure StopMenu;
```

### Dialog
```pascal
procedure ShowMessage(const Msg, Info: string);
procedure ShowMessageNoWait(const Msg, Info: string);
function ShowInput(Col, Row, Width: Integer; const CurrentValue: string): string;
```

## Example

```pascal
uses TextUI, Crt;

procedure OnTest; {$F+}  { CRITICAL: Far call }
begin
  ShowMessage('Test', 'Button clicked!');
end;

var
  Menu: TMenu;
begin
  HideTextCursor;
  RenderTextBackground;

  FillChar(Menu, SizeOf(Menu), 0);
  Menu.Title := 'Main Menu';
  Menu.Col := 30;
  Menu.Row := 10;
  Menu.Width := 20;

  AddMenuItem(Menu, 'Test', @OnTest);
  AddMenuItem(Menu, 'Quit', nil);

  SetMenu(@Menu);
  StartMenu;  { Blocks until user selects }

  FreeMenu(Menu);
  ShowTextCursor;
end;
```

## Color Values

```
0=Black    1=Blue     2=Green    3=Cyan
4=Red      5=Magenta  6=Brown    7=LightGray
8=DarkGray 9=LightBlue 10=LightGreen 11=LightCyan
12=LightRed 13=LightMagenta 14=Yellow 15=White
```

High nibble = background, low nibble = foreground:
```pascal
Color := (BackgroundColor shl 4) or ForegroundColor;
```

## Critical Notes

1. **Far Calls**: Menu callbacks MUST use `{$F+}` directive
2. **Direct Video Memory**: Writes to $B800:0000 (text mode only)
3. **Arrow Keys**: Up/Down navigate, Enter selects
4. **StartMenu**: Blocking call (returns when item selected)

## Notes

- Used by SETUP utility for configuration
- Not for VGA Mode 13h (use VGAUI instead)
- Box drawing uses IBM CP437 characters (─│┌┐└┘)
