Program TestDSP;   (* Tests PLAYBACK of Sound... *)
{$M 65520, 0, 655000}
Uses SBDSP, CRT;

Begin
  Clrscr;
  (* Initialize SB at ports: 220h, IRQ 5, DMA 1, HIGH DMA 5 *)
  (* Note: If you don't have a SB 16, set the High DMA to 0 *)
  ResetDSP (2, 5, 1, 5);
  WriteLn ('Sound Card DSP Version: ', GetDSPVersion);
  Readkey;
  ResetMixer;   (* Reset the Sound Blaster Pro's Mixer Chip *)
  (* Play the RPD file from DISK  *)
  PlaySoundRPD ('TESTREC.RPD');
  (* Set the Sound Blaster Pro's Internal Mixer to FULL Volume, comment it *)
  (* out if your system crashes on any Sound Blaster lower than a Pro      *)
  SetVocVolume (15, 15);
  Repeat
    (* Do whatever you want in here!    *)
  Until ((KeyPressed) or (not Playing));
End.
