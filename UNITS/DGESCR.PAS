{ DGESCR.PAS - DOS Game Engine Screen/State Management

  Purpose: Base screen/state object for game state machines. Provides
           lifecycle hooks for initialization, rendering, and cleanup.

  TScreen Object:
    Abstract base class for game states (menu, gameplay, settings, etc.)
    Extend this to create your game's screens.

  Screen Lifecycle:
    1. Init: Constructor - initialize state variables
    2. PostInit: Called AFTER VGA initialized - use for SetPalette, rendering setup
    3. Show: Called when screen becomes active
    4. Update(DT): Called every frame with delta time
    5. Hide: Called when screen becomes inactive
    6. Done: Destructor - cleanup resources

  Important Notes:
    - PostInit runs AFTER InitVGA, safe for palette/rendering operations
    - Update receives delta time in seconds (Real)
    - DialogLabel: Optional label widget for dialog integration

  Usage Example:
    type
      PMenuScreen = ^TMenuScreen;
      TMenuScreen = object(TScreen)
        procedure PostInit; virtual;
        procedure Update(DT: Real); virtual;
      end;

    New(Menu, Init);
    Game.AddScreen('menu', Menu);
}

unit DGEScr;

{$F+}  { Enable far calls for virtual methods }

interface

uses
  VGAUI;  { For PLabel type }

type
  PScreen = ^TScreen;

  { Screen object - abstract base for game states/screens }
  TScreen = object
    DialogLabel: PLabel;

    constructor Init;
    destructor Done; virtual;
    procedure PostInit; virtual;
    procedure Update(DT: Real); virtual;
    procedure Show; virtual;
    procedure Hide; virtual;
    procedure AddDialogLabel(ADialogLabel: PLabel);
  end;

implementation

{ ========== TScreen Implementation ========== }

constructor TScreen.Init;
begin
  { Base implementation - override in derived screens }
  DialogLabel := nil;
end;

destructor TScreen.Done;
begin
  { Base implementation - override in derived screens }
end;

procedure TScreen.PostInit;
begin
  { Base implementation - override in derived screens }
end;

procedure TScreen.Update(DT: Real);
begin
  { Base implementation - override in derived screens }
end;

procedure TScreen.Show;
begin
  { Base implementation - override in derived screens }
end;

procedure TScreen.Hide;
begin
  { Base implementation - override in derived screens }
end;

procedure TScreen.AddDialogLabel(ADialogLabel: PLabel);
begin
  DialogLabel := ADialogLabel;
end;

end.
