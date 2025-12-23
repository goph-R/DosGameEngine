program SndTest;

{ Test program demonstrating XMS-based sound bank with SBDSP }

uses Keyboard, SBDSP, SndBank, XMS, Delay;

var
  Bank: TSoundBank;
  ExplosionID: Integer;
  Choice: Char;

  { DOSBox-X workaround: Required for Bank.PlaySound to work }
  Dummy1, Dummy2, Dummy3, Dummy4: Integer;
  DummyStr1, DummyStr2: String;

begin
  WriteLn('XMS Sound Bank Test with SBDSP');
  WriteLn('================================');
  WriteLn;

  { Check XMS availability }
  if not XMSinstalled then
  begin
    WriteLn('ERROR: XMS not installed!');
    WriteLn('Load HIMEM.SYS in CONFIG.SYS');
    Halt(1);
  end;

  WriteLn('XMS driver detected - OK');

  { Initialize Sound Blaster }
  WriteLn('Initializing Sound Blaster at port $220, IRQ 5, DMA 1...');
  if not ResetDSP($22, 5, 1, 0) then
  begin
    WriteLn('ERROR: Sound Blaster not detected!');
    Halt(1);
  end;

  WriteLn('Sound Blaster initialized - OK');
  WriteLn;

  { Initialize sound bank }
  if not Bank.Init then
  begin
    WriteLn('ERROR: Failed to initialize sound bank');
    UninstallHandler;
    Halt(1);
  end;

  WriteLn('Sound bank initialized - OK');
  WriteLn;

  { Load sounds into XMS }
  WriteLn('Loading sounds into XMS memory...');

  ExplosionID := Bank.LoadSound('DATA\EXPLODE.VOC');
  if ExplosionID < 0 then
  begin
    WriteLn('ERROR: Failed to load EXPLODE.VOC');
    Bank.Done;
    UninstallHandler;
    Halt(1);
  end;

  WriteLn('  EXPLODE.VOC loaded (ID: ', ExplosionID, ')');
  WriteLn('  Size: ', Bank.Sounds[ExplosionID].Size, ' bytes');
  WriteLn('  Rate: ', Bank.Sounds[ExplosionID].SampleRate, ' Hz');
  WriteLn;

  { Play sounds }
  WriteLn('Press:');
  WriteLn('  [1] - Play explosion sound');
  WriteLn('  [2] - Stop sound');
  WriteLn('  [Q] - Quit');
  WriteLn;

  InitKeyboard;
  repeat
    if IsKeyPressed(Key_1) or IsKeyPressed(Key_2) or IsKeyPressed(Key_Q) then
    begin
      if IsKeyPressed(Key_1) then Choice := '1'
      else if IsKeyPressed(Key_2) then Choice := '2'
      else if IsKeyPressed(Key_Q) then Choice := 'Q'
      else Choice := #0;

      ClearKeyPressed;

      case Choice of
        '1':
          begin
            WriteLn('Playing explosion...');
            if Bank.PlaySound(ExplosionID) then
              WriteLn('  Playing from XMS!')
            else
              WriteLn('  ERROR: Failed to play!');
          end;

        '2':
          begin
            WriteLn('Stopping sound...');
            Bank.StopSound;
          end;

        'Q':
          begin
            WriteLn('Quitting...');
            Break;
          end;
      end;
    end;

    { Allow sound to play in background }
    DelayMS(10);

  until False;

  DoneKeyboard;

  { Cleanup }
  WriteLn;
  WriteLn('Cleaning up...');
  Bank.Done;
  UninstallHandler;

  WriteLn('Done!');
end.
