PROGRAM TestHscUnit;

(* Demo program for PLAYHSC unit by GLAMOROUS RAY^RADiCAL RHYTHMS     *)
(* The enclosed songs are copyrighted. CRYSTAL2  (c) Chris Korte,     *)
(* FANTASY (linked as object) (c) NEO Software                        *)

USES PLAYHSC,CRT;

VAR
  Music : HSC_obj;

{$F+}                            (* Declaration                  *)
{$L MUSIC.OBJ}                   (*          for                 *)
PROCEDURE MUSIC_DATA; EXTERNAL;  (*             external         *)
{$F-}                            (*                   sound data *)

PROCEDURE WaitKey;
VAR
  Dummy : CHAR;
BEGIN
  REPEAT UNTIL KeyPressed;
  WHILE KeyPressed DO Dummy := ReadKey;
END;

BEGIN
  Music.Init(0);

  Music.LoadMem (@MUSIC_DATA); (* included file, using binobj.exe  *)
  Music.Start;
  WaitKey;

  IF Music.LoadFile ('CRYSTAL2.HSC') THEN BEGIN
    Music.Start;
    WaitKey;
  END;

  Music.Fade;
  Delay (4000);
  Music.Done;
END.