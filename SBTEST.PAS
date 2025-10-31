program SBTest;

uses SB, Crt;

var
  SoundCard: TSoundBlaster;
  Ch: Char;

function HexStr(Value: Word; Digits: Byte): string;
const
  HexChars: array[0..15] of Char = '0123456789ABCDEF';
var
  Result: string;
  i: Integer;
begin
  Result := '';
  for i := Digits - 1 downto 0 do
    Result := Result + HexChars[(Value shr (i * 4)) and $F];
  HexStr := Result;
end;

begin
  ClrScr;
  WriteLn('Sound Blaster Detection Test');
  WriteLn('============================');
  WriteLn;

  { Initialize Sound Blaster object }
  FillChar(SoundCard, SizeOf(SoundCard), 0);

  if SoundCard.Init then
  begin
    WriteLn('Sound Blaster detected!');
    WriteLn('Base Port: $', HexStr(SoundCard.BasePort, 3));
    WriteLn('IRQ: ', SoundCard.IRQ);
    WriteLn('DMA: ', SoundCard.DMA);
    WriteLn;

    { Test playing a VOC file if it exists }
    WriteLn('Press any key to play EXPLODE.VOC (or ESC to skip)...');
    Ch := ReadKey;

    if Ch <> #27 then
    begin
      Write('Playing EXPLODE.VOC... ');
      if SoundCard.PlayVOC('DATA\EXPLODE.VOC') then
      begin
        WriteLn('Playing!');
        WriteLn('(Sound is playing via DMA in background)');
        WriteLn;
        WriteLn('Press any key to stop and exit...');
        Ch := ReadKey;
        { Playing flag will be cleared by Done }
      end
      else
      begin
        WriteLn('Failed!');
        WriteLn('(File not found or invalid VOC format)');
        WriteLn;
        WriteLn('Press any key to exit...');
        Ch := ReadKey;
      end;
    end;

    SoundCard.Done;
    WriteLn;
    WriteLn('Sound Blaster shut down. Goodbye!');
  end
  else
  begin
    WriteLn('Sound Blaster NOT detected!');
    WriteLn;
    WriteLn('Possible reasons:');
    WriteLn('  - No Sound Blaster card installed');
    WriteLn('  - Card not at standard ports ($220-$2C0)');
    WriteLn('  - Using DOSBox? Add to dosbox.conf:');
    WriteLn('    [sblaster]');
    WriteLn('    sbtype=sb16');
    WriteLn('    sbbase=220');
    WriteLn('    irq=5');
    WriteLn('    dma=1');
    WriteLn;
    WriteLn('Press any key to exit...');
    Ch := ReadKey;
  end;
end.
