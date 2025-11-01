Program RecTestDSP;
{$M 65520, 0, 655000}
Uses SBDSP, CRT;

Begin
  Clrscr;
  (* Initialize SB at ports: 220h, IRQ 5, DMA 1, HIGH DMA 5 *)
  ResetDSP (2, 5, 1, 5);
  WriteLn ('Sound Card DSP Version: ', GetDSPVersion);
  WriteLn ('Press any key to start...');
  Readkey;
  WriteLn ('Recording...');
  ResetMixer;   (* Reset the Sound Blaster Pro's Mixer Chip *)
  (* Record a RPD file TO Disk, at 11Khz in 8 bit mono... *)
  SetInputSource (NoFilter, Mic1Input); (* Recording source = Microphone...*)
  SetMicVolume (7);           (* MAX volume on Mic In..          *)
  RecordSoundRPD ('TESTREC.RPD', 11000);
  (* Set the Sound Blaster Pro's Internal Mixer to FULL Volume, comment it *)
  (* out if your system crashes on any Sound Blaster lower than a Pro      *)
  SetVocVolume (15, 15);
  Repeat
  Until ((KeyPressed));
  StopRecording;
  SetMicVolume (0);
End.