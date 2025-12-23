# VGAUI Event System Refactor - Delphi-Style Event Handlers

## Overview

This document outlines a refactoring plan to modernize the VGAUI event system from a centralized TEvent dispatch model to individual procedure pointer callbacks similar to Delphi's VCL framework. This change will improve code clarity, reduce coupling, and make event handling more intuitive for widget users.

## Current Architecture (TEvent-based)

### Existing Design

The current system uses a centralized event record:

```pascal
type
  TEventType = (Event_None, Event_KeyPress, Event_MouseDown,
                Event_MouseUp, Event_MouseMove, Event_FocusGain,
                Event_FocusLost);

  TEvent = record
    EventType: TEventType;
    KeyCode: Byte;
    MouseX: Integer;
    MouseY: Integer;
    MouseButton: Byte;
    Handled: Boolean;
  end;

  TEventHandler = procedure(var Widget: TWidget; var Event: TEvent);
```

### Current Widget Base

```pascal
TWidget = object
  EventHandler: Pointer;  { Generic TEventHandler }

  procedure HandleEvent(var Event: TEvent); virtual;
end;
```

### Problems with Current Approach

1. **Generic Handler**: Single EventHandler pointer forces users to implement switch/case logic for different event types
2. **Type Safety**: No compile-time verification of event types - easy to mishandle events
3. **Code Duplication**: Every widget must check `Event.EventType` and extract relevant fields
4. **Poor Discoverability**: Not obvious which events a widget supports
5. **Verbose Usage**: Client code must manually check EventType and cast/access fields
6. **TEvent Overhead**: Large record (10+ bytes) passed by reference for every event

## Proposed Architecture (Delphi-style)

### New Event Handler Types

Replace single `TEventHandler` with specific procedure pointer types:

```pascal
{$F+}  { Far call for procedure pointer compatibility }
type
  TKeyPressEvent = procedure(Sender: PWidget; KeyCode: Byte);
  TMouseEvent = procedure(Sender: PWidget; X, Y: Integer; Button: Byte);
  TFocusEvent = procedure(Sender: PWidget);
{$F-}
```

### New Widget Base

```pascal
TWidget = object
  { Event callbacks (procedure pointers) }
  OnKeyPress: Pointer;   { TKeyPressEvent }
  OnMouseDown: Pointer;  { TMouseEvent }
  OnMouseUp: Pointer;    { TMouseEvent }
  OnMouseMove: Pointer;  { TMouseEvent }
  OnFocus: Pointer;      { TFocusEvent }
  OnBlur: Pointer;       { TFocusEvent }

  { Event trigger methods (protected - called by framework) }
  procedure DoKeyPress(KeyCode: Byte); virtual;
  procedure DoMouseDown(X, Y: Integer; Button: Byte); virtual;
  procedure DoMouseUp(X, Y: Integer; Button: Byte); virtual;
  procedure DoMouseMove(X, Y: Integer; Button: Byte); virtual;
  procedure DoFocus; virtual;
  procedure DoBlur; virtual;
end;
```

### Benefits

1. **Type Safety**: Each event has specific parameters - compile-time verification
2. **Self-Documenting**: Widget fields clearly show which events are supported
3. **Simpler Usage**: No switch/case needed - direct callback assignment
4. **Performance**: Direct procedure calls instead of record dispatch
5. **Familiarity**: Matches Delphi VCL pattern (On* naming convention)
6. **Extensibility**: Subclasses can override Do* methods to intercept events

## Implementation Plan

### Phase 1: Add New Event System (Parallel)

Keep existing TEvent system while adding new callbacks to maintain compatibility.

#### Step 1.1: Define Event Handler Types

Add to VGAUI.PAS interface section (before TWidget):

```pascal
{$F+}
type
  TKeyPressEvent = procedure(Sender: PWidget; KeyCode: Byte);
  TMouseEvent = procedure(Sender: PWidget; X, Y: Integer; Button: Byte);
  TFocusEvent = procedure(Sender: PWidget);
{$F-}
```

#### Step 1.2: Add Fields to TWidget

Add new callback pointers to TWidget (alongside EventHandler):

```pascal
TWidget = object
  { ... existing fields ... }
  EventHandler: Pointer;  { OLD - keep for compatibility }

  { NEW - Delphi-style event callbacks }
  OnKeyPress: Pointer;   { TKeyPressEvent }
  OnMouseDown: Pointer;  { TMouseEvent }
  OnMouseUp: Pointer;    { TMouseEvent }
  OnMouseMove: Pointer;  { TMouseEvent }
  OnFocus: Pointer;      { TFocusEvent }
  OnBlur: Pointer;       { TFocusEvent }
```

#### Step 1.3: Implement Do* Methods in TWidget

Add virtual event trigger methods to TWidget:

```pascal
procedure TWidget.DoKeyPress(KeyCode: Byte);
begin
  if OnKeyPress <> nil then
    TKeyPressEvent(OnKeyPress)(Self, KeyCode);
end;

procedure TWidget.DoMouseDown(X, Y: Integer; Button: Byte);
begin
  if OnMouseDown <> nil then
    TMouseEvent(OnMouseDown)(Self, X, Y, Button);
end;

procedure TWidget.DoMouseUp(X, Y: Integer; Button: Byte);
begin
  if OnMouseUp <> nil then
    TMouseEvent(OnMouseUp)(Self, X, Y, Button);
end;

procedure TWidget.DoMouseMove(X, Y: Integer; Button: Byte);
begin
  if OnMouseMove <> nil then
    TMouseEvent(OnMouseMove)(Self, X, Y, Button);
end;

procedure TWidget.DoFocus;
begin
  if OnFocus <> nil then
    TFocusEvent(OnFocus)(Self);
end;

procedure TWidget.DoBlur;
begin
  if OnBlur <> nil then
    TFocusEvent(OnBlur)(Self);
end;
```

#### Step 1.4: Initialize New Fields in TWidget.Init

```pascal
constructor TWidget.Init(X, Y: Integer; W, H: Word);
begin
  { ... existing initialization ... }
  EventHandler := nil;  { OLD }

  { NEW - initialize all event callbacks to nil }
  OnKeyPress := nil;
  OnMouseDown := nil;
  OnMouseUp := nil;
  OnMouseMove := nil;
  OnFocus := nil;
  OnBlur := nil;
end;
```

### Phase 2: Refactor Widget Subclasses

Update each widget to use new event system while maintaining backward compatibility.

#### Step 2.1: TButton

Current HandleEvent:

```pascal
procedure TButton.HandleEvent(var Event: TEvent);
begin
  if Event.EventType = Event_KeyPress then
  begin
    if (Event.KeyCode = $1C) or (Event.KeyCode = $39) then
    begin
      Pressed := True;
      MarkDirty;
      Event.Handled := True;
      if EventHandler <> nil then
        TEventHandler(EventHandler)(Self, Event);
    end;
  end
  else if Event.EventType = Event_MouseDown then
  begin
    { ... }
  end;
end;
```

Refactored to use Do* methods:

```pascal
procedure TButton.DoKeyPress(KeyCode: Byte);
begin
  { Button-specific behavior: Enter/Space triggers press }
  if (KeyCode = Key_Enter) or (KeyCode = Key_Space) then
  begin
    Pressed := True;
    MarkDirty;

    { Call user callback }
    inherited DoKeyPress(KeyCode);
  end;
end;

procedure TButton.DoMouseDown(X, Y: Integer; Button: Byte);
var
  InBounds: Boolean;
begin
  InBounds := (X >= Rectangle.X) and
              (X < Rectangle.X + Rectangle.Width) and
              (Y >= Rectangle.Y) and
              (Y < Rectangle.Y + Rectangle.Height);

  if InBounds and Enabled then
  begin
    Pressed := True;
    MarkDirty;

    { Call user callback }
    inherited DoMouseDown(X, Y, Button);
  end;
end;

procedure TButton.DoBlur;
begin
  { Reset pressed state when losing focus }
  Pressed := False;
  MarkDirty;
  inherited DoBlur;
end;
```

#### Step 2.2: TCheckbox

```pascal
procedure TCheckbox.DoKeyPress(KeyCode: Byte);
begin
  { Checkbox-specific behavior: Enter/Space toggles state }
  if (KeyCode = Key_Enter) or (KeyCode = Key_Space) then
  begin
    Checked := not Checked;
    MarkDirty;

    { Call user callback }
    inherited DoKeyPress(KeyCode);
  end;
end;

procedure TCheckbox.DoMouseDown(X, Y: Integer; Button: Byte);
var
  InBounds: Boolean;
begin
  InBounds := (X >= Rectangle.X) and
              (X < Rectangle.X + Rectangle.Width) and
              (Y >= Rectangle.Y) and
              (Y < Rectangle.Y + Rectangle.Height);

  if InBounds and Enabled then
  begin
    Checked := not Checked;
    MarkDirty;

    { Call user callback }
    inherited DoMouseDown(X, Y, Button);
  end;
end;
```

#### Step 2.3: TLineEdit

```pascal
procedure TLineEdit.DoKeyPress(KeyCode: Byte);
var
  Ch: Char;
  OldText: string;
begin
  OldText := Text^;

  { Backspace }
  if KeyCode = Key_Backspace then
  begin
    if Length(Text^) > 0 then
    begin
      Delete(Text^, Length(Text^), 1);
      if Text^ <> OldText then
        MarkDirty;
    end;
    { Don't call inherited - backspace is fully handled here }
    Exit;
  end
  { Enter - pass to user callback }
  else if KeyCode = Key_Enter then
  begin
    { Call user callback - let them handle submit }
    inherited DoKeyPress(KeyCode);
    Exit;
  end
  { Character input }
  else
  begin
    Ch := ScancodeToChar(KeyCode);
    if (Ch <> #0) and (Length(Text^) < MaxLength) then
    begin
      Text^ := Text^ + Ch;
      if Text^ <> OldText then
        MarkDirty;
    end;
  end;
end;

procedure TLineEdit.DoMouseDown(X, Y: Integer; Button: Byte);
var
  InBounds: Boolean;
begin
  InBounds := (X >= Rectangle.X) and
              (X < Rectangle.X + Rectangle.Width) and
              (Y >= Rectangle.Y) and
              (Y < Rectangle.Y + Rectangle.Height);

  if InBounds and Enabled then
  begin
    { LineEdit just accepts focus on click - no other action needed }
    { Call user callback if they want to know about clicks }
    inherited DoMouseDown(X, Y, Button);
  end;
end;
```

### Phase 3: Update TUIManager Event Dispatch

Modify TUIManager to call Do* methods instead of HandleEvent.

#### Step 3.1: Update SetFocus

```pascal
procedure TUIManager.SetFocus(Widget: PWidget);
begin
  { Unfocus old widget }
  if FocusedWidget <> nil then
  begin
    FocusedWidget^.Focused := False;
    FocusedWidget^.MarkDirty;
    FocusedWidget^.DoBlur;  { NEW - call DoBlur }
  end;

  { Focus new widget }
  if (Widget <> nil) and Widget^.Enabled then
  begin
    FocusedWidget := Widget;
    Widget^.Focused := True;
    Widget^.MarkDirty;
    Widget^.DoFocus;  { NEW - call DoFocus }
  end
  else
  begin
    FocusedWidget := nil;
  end;
end;
```

#### Step 3.2: Update DispatchKeyboardEvents

```pascal
procedure TUIManager.DispatchKeyboardEvents;
var
  ScanCode: Byte;
begin
  if FocusedWidget = nil then Exit;

  { Check all scan codes }
  for ScanCode := 1 to 127 do
  begin
    if IsKeyPressed(ScanCode) then
    begin
      FocusedWidget^.DoKeyPress(ScanCode);  { NEW - direct call }

      { Handle Tab navigation }
      if ScanCode = Key_Tab then
      begin
        if IsKeyDown(Key_LShift) or IsKeyDown(Key_RShift) then
          FocusInDirection(0, -1)  { Shift+Tab = previous }
        else
          FocusInDirection(0, 1);  { Tab = next }
      end;
    end;
  end;
end;
```

#### Step 3.3: Update DispatchMouseEvents

```pascal
procedure TUIManager.DispatchMouseEvents;
var
  Buttons: Byte;
  X, Y: Integer;
  Node: PListEntry;
  Widget: PWidget;
  InBounds: Boolean;
begin
  UpdateMouse;

  X := GetMouseX;
  Y := GetMouseY;
  Buttons := GetMouseButtons;

  { Mouse down events }
  if (Buttons <> 0) and (LastMouseButtons = 0) then
  begin
    { Find widget under cursor and give it focus }
    Node := Widgets.First;
    while Node <> nil do
    begin
      Widget := PWidget(Node^.Value);
      if Widget^.Visible and Widget^.Enabled then
      begin
        InBounds := (X >= Widget^.Rectangle.X) and
                    (X < Widget^.Rectangle.X + Widget^.Rectangle.Width) and
                    (Y >= Widget^.Rectangle.Y) and
                    (Y < Widget^.Rectangle.Y + Widget^.Rectangle.Height);

        if InBounds then
        begin
          SetFocus(Widget);
          Widget^.DoMouseDown(X, Y, Buttons);  { NEW }
          Break;
        end;
      end;
      Node := Node^.Next;
    end;
  end;

  { Mouse up events }
  if (Buttons = 0) and (LastMouseButtons <> 0) then
  begin
    if FocusedWidget <> nil then
      FocusedWidget^.DoMouseUp(X, Y, LastMouseButtons);  { NEW }
  end;

  { Mouse move events (if any button is down) }
  if Buttons <> 0 then
  begin
    if FocusedWidget <> nil then
      FocusedWidget^.DoMouseMove(X, Y, Buttons);  { NEW }
  end;

  LastMouseButtons := Buttons;
end;
```

#### Step 3.4: Remove HandleEvent Method

Once all widgets are refactored, remove:

1. `TUIManager.HandleEvent` method (no longer needed)
2. `TWidget.HandleEvent` virtual method (replaced by Do* methods)
3. `TEvent` record and `TEventType` enum (obsolete)
4. `TEventHandler` procedure type (obsolete)
5. `EventHandler` field from TWidget (obsolete)

### Phase 4: Update Test Programs and Examples

Update all existing test programs to use new event handlers.

#### Before (Old Event System):

```pascal
{$F+}
procedure OnButtonClick(var Widget: TWidget; var Event: TEvent);
begin
  if Event.EventType = Event_KeyPress then
    WriteLn('Button pressed with keyboard')
  else if Event.EventType = Event_MouseDown then
    WriteLn('Button pressed with mouse');
end;
{$F-}

begin
  New(Btn, Init(10, 10, 100, 20, 'Click Me', @Font));
  Btn^.SetEventHandler(@OnButtonClick);
end;
```

#### After (New Event System):

```pascal
{$F+}
procedure OnButtonKeyPress(Sender: PWidget; KeyCode: Byte);
begin
  WriteLn('Button pressed with key: ', KeyCode);
end;

procedure OnButtonMouseDown(Sender: PWidget; X, Y: Integer; Button: Byte);
begin
  WriteLn('Button pressed at (', X, ',', Y, ')');
end;
{$F-}

begin
  New(Btn, Init(10, 10, 100, 20, 'Click Me', @Font));
  Btn^.OnKeyPress := @OnButtonKeyPress;
  Btn^.OnMouseDown := @OnButtonMouseDown;
end;
```

### Phase 5: Documentation Updates

Update documentation to reflect new event system:

1. **CLAUDE.md**: Update VGAUI section with new event handler examples
2. **DOCS/VGAUI.md** (create if missing): Full API reference with examples
3. **Code comments**: Add documentation to Do* virtual methods
4. **Migration guide**: Document how to convert old EventHandler code

## Migration Strategy

### Backward Compatibility Period

To avoid breaking existing code immediately:

1. **Phase 1-3**: Keep both systems (TEvent + new callbacks) working in parallel
2. **Deprecation**: Add comments marking TEvent system as deprecated
3. **Dual dispatch**: In Do* methods, check both old EventHandler and new callbacks
4. **Grace period**: Allow both systems to coexist for testing
5. **Final removal**: After all tests/examples updated, remove TEvent system

### Testing Checklist

- [ ] TESTS/UITEST.PAS - Update to use new event handlers
- [ ] XICLONE (if using VGAUI) - Update event handlers
- [ ] Verify all widgets work with keyboard navigation
- [ ] Verify all widgets work with mouse input
- [ ] Test focus events (OnFocus/OnBlur)
- [ ] Test Tab/Shift+Tab navigation still works
- [ ] Verify dirty rectangle rendering still optimizes correctly
- [ ] Memory leak check (ensure all widgets cleanup properly)

## Performance Impact

### Expected Improvements

1. **Smaller stack frames**: No large TEvent record passed around
2. **Direct calls**: Virtual method dispatch instead of switch/case
3. **Less branching**: No EventType checks in user code
4. **Better inlining**: Simple Do* methods can be inlined by compiler

### Measurements to Track

- Memory per widget instance (before/after)
- Event dispatch latency (cycles per event)
- Code size of compiled test programs
- Stack usage during event cascades

## Alternative Designs Considered

### 1. Keep TEvent but add type-specific fields

**Rejected** - Still requires switch/case logic, doesn't solve core issues

### 2. Use object-oriented event objects (inheritance)

**Rejected** - Too heavyweight for DOS/TP7.0, dynamic allocation overhead

### 3. Function pointers returning Boolean (handled flag)

**Rejected** - Delphi-style procedures are simpler, "handled" concept not needed with direct callbacks

## References

- Delphi VCL TControl.OnClick, OnKeyPress, OnMouseDown patterns
- Turbo Vision event system (alternative approach)
- Current VGAUI.PAS implementation (lines 42-61, 99, 108, 356-361)

## Estimated Effort

- Phase 1 (Add new system): 2-3 hours
- Phase 2 (Refactor widgets): 3-4 hours
- Phase 3 (Update TUIManager): 2-3 hours
- Phase 4 (Update tests): 2-3 hours
- Phase 5 (Documentation): 2-3 hours
- **Total**: 11-16 hours of focused development work

## Conclusion

This refactoring will modernize VGAUI to follow familiar Delphi patterns, improve type safety, reduce code duplication, and make the framework more intuitive to use. The phased approach ensures backward compatibility during migration and allows incremental testing of each component.
