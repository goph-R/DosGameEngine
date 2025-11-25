{ IMFTEST.PAS - Test program for IMF music playback }
{ Demonstrates Id Music Format player (Wolfenstein 3D, Commander Keen) }

program IMFTest;

{$M 16384,0,655360}  { Stack: 16KB, MinHeap: 0, MaxHeap: 640KB }

uses
  Crt, Dos, PlayIMF, Keyboard, TextUI, StrUtil;

var
  Music: IMF_Obj;
  Running: Boolean;
  OldExitProc: Pointer;
  MusicFile: string;
  PlaybackRate: Word;
  LoopMusic: Boolean;
  ChunkDelay: Word;
  ChunkReg, ChunkData: Byte;
  i: Integer;

{ Exit procedure - CRITICAL for cleanup on Ctrl+C/Ctrl+Break }
{$F+}
procedure CleanupOnExit;
begin
  ExitProc := OldExitProc;  { Restore previous exit proc }

  { Stop music and cleanup }
  Music.Done;
  DoneKeyboard;

  { Restore text mode cursor }
  ShowTextCursor;
end;
{$F-}

procedure ShowHelp;
begin
  ClrScr;
  WriteLn('IMF Music Player Test');
  WriteLn('=====================');
  WriteLn;
  WriteLn('Usage: IMFTEST <filename.imf> [rate] [loop]');
  WriteLn;
  WriteLn('Parameters:');
  WriteLn('  filename.imf  - IMF music file to play');
  WriteLn('  rate          - Playback rate in Hz (optional)');
  WriteLn('                  560 = Commander Keen 4-6');
  WriteLn('                  700 = Wolfenstein 3D, Blake Stone (default)');
  WriteLn('  loop          - Add "loop" to enable looping');
  WriteLn;
  WriteLn('Examples:');
  WriteLn('  IMFTEST ..\DATA\MUSIC.IMF');
  WriteLn('  IMFTEST ..\DATA\KEEN.IMF 560');
  WriteLn('  IMFTEST ..\DATA\WOLF.IMF 700 loop');
  WriteLn;
  WriteLn('Controls:');
  WriteLn('  SPACE - Pause/Resume');
  WriteLn('  L     - Toggle looping');
  WriteLn('  R     - Restart music');
  WriteLn('  ESC   - Exit');
  WriteLn;
  Halt(1);
end;

procedure ParseCommandLine;
var
  i: Integer;
  Param: string;
begin
  { Default values }
  MusicFile := '';
  PlaybackRate := 700;  { Default: Wolfenstein 3D rate }
  LoopMusic := False;

  { Check if help requested }
  if (ParamCount = 0) or (ParamStr(1) = '/?') or (ParamStr(1) = '-h') or
     (ParamStr(1) = '--help') then
    ShowHelp;

  { Get filename }
  MusicFile := ParamStr(1);

  { Parse optional parameters }
  for i := 2 to ParamCount do
  begin
    Param := ParamStr(i);

    { Check for playback rate }
    if (Param = '560') or (Param = '700') or (Param = '280') or
       (Param = '1400') then
      PlaybackRate := StrToInt(Param)
    { Check for loop flag }
    else if (Param = 'loop') or (Param = 'LOOP') or (Param = '-l') then
      LoopMusic := True;
  end;
end;

procedure ShowStatus;
begin
  GotoXY(1, 10);
  Write('Status: ');
  if Music.Playing then
    Write('PLAYING ')
  else
    Write('STOPPED ');

  GotoXY(1, 11);
  Write('Position: ', Music.CurrentChunk, ' / ', Music.ChunkCount, '    ');

  GotoXY(1, 12);
  Write('Looping: ');
  if Music.Looping then
    WriteLn('ON ')
  else
    WriteLn('OFF');

  GotoXY(1, 13);
  WriteLn('Timing Debug:');
  GotoXY(1, 14);
  Write('  DelayCount: ', Music.DelayCounter, '    ');
  GotoXY(1, 15);
  Write('  TickAccum:  ', Music.TickAccumulator, '    ');
  GotoXY(1, 16);
  Write('  TicksPer:   ', Music.TicksPerUpdate, '    ');
  GotoXY(1, 17);
  if Music.DelayCounter > 0 then
    WriteLn('  Status: WAITING FOR DELAY    ')
  else if Music.TickAccumulator >= Music.TicksPerUpdate then
    WriteLn('  Status: SHOULD PROCESS       ')
  else
    WriteLn('  Status: ACCUMULATING         ');

  { Show next chunk to be processed }
  GotoXY(1, 19);
  if Music.CurrentChunk < Music.ChunkCount then
  begin
    Music.GetChunkData(Music.CurrentChunk, ChunkDelay, ChunkReg, ChunkData);
    WriteLn('Next chunk [', Music.CurrentChunk, ']: Delay=', ChunkDelay,
            ' Reg=$', HexStr(ChunkReg, 2), ' Data=$', HexStr(ChunkData, 2), '    ');
  end
  else
    WriteLn('At end of music data                              ');

  GotoXY(1, 21);
  WriteLn('Controls:');
  WriteLn('  SPACE - Pause/Resume');
  WriteLn('  L     - Toggle looping');
  WriteLn('  R     - Restart music');
  WriteLn('  ESC   - Exit');
end;

begin
  { Install exit procedure FIRST }
  OldExitProc := ExitProc;
  ExitProc := @CleanupOnExit;

  { Parse command line }
  ParseCommandLine;

  ClrScr;
  WriteLn('IMF Music Player Test');
  WriteLn('=====================');
  WriteLn;
  WriteLn('File: ', MusicFile);
  WriteLn('Rate: ', PlaybackRate, ' Hz');
  WriteLn;

  { Initialize keyboard handler }
  InitKeyboard;

  { Initialize IMF player }
  Music.Init(PlaybackRate);
  Music.Looping := LoopMusic;

  { Load IMF file }
  WriteLn('Loading IMF file...');
  if not Music.LoadFile(MusicFile) then
  begin
    WriteLn('ERROR: ', GetLastIMFError);
    WriteLn;
    Music.Done;
    DoneKeyboard;
    Halt(1);
  end;

  WriteLn('Loaded successfully!');
  WriteLn('Chunks loaded: ', Music.ChunkCount);
  WriteLn('Data size: ', Music.ChunkCount * 4, ' bytes');
  WriteLn;

  { Verify data is actually loaded in memory }
  WriteLn('Data loaded in memory: ', Music.IsDataLoaded);
  if not Music.IsDataLoaded then
  begin
    WriteLn('ERROR: Data failed to load into memory!');
    WriteLn('This usually means GetMem failed (out of heap memory)');
    Music.Done;
    DoneKeyboard;
    Halt(1);
  end;
  WriteLn;

  { Debug: Show first 3 chunks }
  WriteLn('First 3 chunks:');
  for i := 0 to 2 do
  begin
    Music.GetChunkData(i, ChunkDelay, ChunkReg, ChunkData);
    WriteLn('  [', i, '] Delay=', ChunkDelay, ' Reg=$', HexStr(ChunkReg, 2),
            ' Data=$', HexStr(ChunkData, 2));
  end;
  WriteLn;

  { Start playback }
  Music.Start;

  WriteLn('Music.Playing = ', Music.Playing);
  WriteLn;
  WriteLn('Timing values:');
  WriteLn('  TicksPerUpdate = ', Music.TicksPerUpdate);
  WriteLn('  Rate = ', PlaybackRate, ' Hz');
  WriteLn;
  WriteLn('Starting main loop...');
  WriteLn;

  { Small delay to see the output }
  Delay(500);

  { Hide cursor for cleaner display }
  HideTextCursor;

  { Main playback loop }
  Running := True;
  while Running do
  begin
    { Poll music player - CRITICAL! Must be called every frame }
    Music.Poll;

    { Update status display }
    ShowStatus;

    { Handle keyboard input }
    if IsKeyPressed(Key_Escape) then
      Running := False;

    if IsKeyPressed(Key_Space) then
    begin
      if Music.Playing then
        Music.Stop
      else
        Music.Start;
    end;

    if IsKeyPressed(Key_L) then
      Music.Looping := not Music.Looping;

    if IsKeyPressed(Key_R) then
      Music.Start;  { Restart from beginning }

    { Clear pressed keys }
    ClearKeyPressed;

    { Small delay to reduce CPU usage }
    { Without this, Poll() is called thousands of times per second }
    { but BIOS timer only updates at 18.2 Hz, so most calls do nothing }
    Delay(10);
  end;

  { Cleanup }
  CleanupOnExit;

  { Show exit message }
  ClrScr;
  WriteLn('IMF playback stopped.');
  WriteLn;
  WriteLn('Format Info:');
  WriteLn('  IMF (Id Music Format) was created by Id Software in 1991');
  WriteLn('  Used in: Commander Keen 4-6, Wolfenstein 3D, Blake Stone');
  WriteLn('  Format: Simple OPL2 register dumps with timing delays');
  WriteLn;
  WriteLn('See DOCS\MISC\IMFSRC.md for sources of IMF music files.');
  WriteLn;
end.
