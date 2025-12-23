{ GAMEUNIT.PAS - Game framework (backward compatibility wrapper)

  DEPRECATED: This unit is maintained for backward compatibility only.
              New code should use DGECORE and DGESCR directly.

  This unit re-exports TGame from DGECORE.PAS and TScreen from DGESCR.PAS
  to maintain compatibility with existing code.

  Migration Guide:
    Old: uses GameUnit;
    New: uses DGECore, DGEScr;

  The DOS Game Engine (DGE) units provide better separation:
    - DGESCR.PAS: TScreen base object (screen/state management)
    - DGECORE.PAS: TGame framework object (subsystem integration)

  See DOCS\GAMEUNIT.md for complete architecture guide.
}

unit GameUnit;

{$G+}  { Enable 286 instructions }
{$F+}  { Enable far calls for procedural types }

interface

uses
  DGECore, DGEScr;

type
  { Re-export types from DGE units for backward compatibility }
  PGame = DGECore.PGame;
  TGame = DGECore.TGame;
  PScreen = DGEScr.PScreen;
  TScreen = DGEScr.TScreen;

implementation

{ All implementation is in DGECORE and DGESCR }

end.
