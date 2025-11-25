unit PlayIMF;

(*
  IMF (Id Music Format) Player Unit
  ==================================

  Simple polling-based player for IMF music files.
  Used in Commander Keen 4-6, Wolfenstein 3D, Blake Stone, etc.

  Format: [delay word][register byte][data byte] repeated

  Usage:
    var Music: IMF_Obj;

    Music.Init(700);  { 700 Hz for Wolf3D, 560 Hz for Keen }
    if Music.LoadFile('MUSIC.IMF') then
    begin
      Music.Start;
      while Playing do
      begin
        Music.Poll;  { Call this every frame! }
        { ... game logic ... }
      end;
      Music.Done;
    end;
*)

interface

type
  { IMF data chunk: delay + register + data }
  TIMFChunk = record
    Delay: Word;      { Ticks to wait before next chunk }
    Reg: Byte;        { OPL2 register address }
    Data: Byte;       { Value to write to register }
  end;

  PWord = ^Word;

  PIMFChunk = ^TIMFChunk;
  PIMFChunkArray = ^TIMFChunkArray;
  TIMFChunkArray = array[0..8191] of TIMFChunk; { Max 32KB of chunks (~8 minutes at 700 Hz) }

  IMF_Obj = object
    { Public fields }
    Playing: Boolean;
    Looping: Boolean;  { If True, restart when finished }
    ChunkCount: Word;  { Number of chunks loaded (for debugging) }
    CurrentChunk: Word; { Current playback position (for debugging) }
    DelayCounter: Word; { Current delay countdown (for debugging) }
    TickAccumulator: LongInt;  { Debug: Timing accumulator }
    TicksPerUpdate: LongInt;   { Debug: Ticks needed per update }

    { Public methods }
    constructor Init(PlaybackRate: Word);
    function LoadFile(const FileName: string): Boolean;
    procedure LoadMem(MusicAddress: Pointer; MusicSize: LongInt);
    function IsDataLoaded: Boolean;  { Returns True if music data is loaded in memory }
    procedure GetChunkData(Index: Word; var Delay: Word; var Reg, Data: Byte);  { Debug helper }
    procedure Start;
    procedure Stop;
    procedure Poll;  { MUST be called regularly (every frame) }
    destructor Done;

  private
    { Private fields }
    Rate: Word;           { Playback rate in Hz (560, 700, etc.) }
    Chunks: PIMFChunkArray;
    LastTime: LongInt;
    LoadedFromFile: Boolean;

    { Private methods }
    procedure ResetOPL2;
    procedure WriteOPL2(Reg, Data: Byte);
    procedure SilenceOPL2;
  end;

function GetLastIMFError: string;

implementation

uses Dos, StrUtil;

const
  OPL2_ADDR_PORT = $388;
  OPL2_DATA_PORT = $389;

var
  LastError: string;

{ Helper function to get BIOS timer ticks (18.2 Hz) }
function GetBIOSTicks: LongInt;
var
  Regs: Registers;
begin
  Regs.AH := $00;
  Intr($1A, Regs);
  GetBIOSTicks := (LongInt(Regs.CX) shl 16) or Regs.DX;
end;

{ Get last error message }
function GetLastIMFError: string;
begin
  GetLastIMFError := LastError;
end;

{ Constructor - Initialize player }
constructor IMF_Obj.Init(PlaybackRate: Word);
begin
  Playing := False;
  Looping := False;
  Chunks := nil;
  ChunkCount := 0;
  CurrentChunk := 0;
  DelayCounter := 0;
  LoadedFromFile := False;
  LastError := '';

  { Set playback rate }
  if PlaybackRate = 0 then
    Rate := 700  { Default: Wolfenstein 3D rate }
  else
    Rate := PlaybackRate;

  { Calculate ticks per update (BIOS timer is 18.2 Hz) }
  { TicksPerUpdate = (18.2 * 65536) / Rate }
  TicksPerUpdate := (1193046 div Rate);
  TickAccumulator := 0;
  LastTime := GetBIOSTicks;

  { Initialize OPL2 }
  ResetOPL2;
end;

{ Destructor - Cleanup }
destructor IMF_Obj.Done;
begin
  Stop;
  SilenceOPL2;

  { Free memory if loaded from file }
  if LoadedFromFile and (Chunks <> nil) then
    FreeMem(Chunks, ChunkCount * SizeOf(TIMFChunk));

  Chunks := nil;
  ChunkCount := 0;
end;

{ Reset OPL2 chip }
procedure IMF_Obj.ResetOPL2;
var
  i: Byte;
begin
  { Reset all OPL2 registers to 0 }
  for i := 1 to $F5 do
    WriteOPL2(i, 0);

  { Enable waveform select }
  WriteOPL2($01, $20);
end;

{ Silence all OPL2 voices }
procedure IMF_Obj.SilenceOPL2;
var
  i: Byte;
begin
  { Turn off all channels }
  for i := $B0 to $B8 do
    WriteOPL2(i, 0);
end;

{ Write to OPL2 register }
procedure IMF_Obj.WriteOPL2(Reg, Data: Byte); assembler;
asm
  { Select register }
  mov dx, OPL2_ADDR_PORT
  mov al, Reg
  out dx, al

  { Wait ~3.3 microseconds (6 reads of status port) }
  mov cx, 6
  @wait1:
  in al, dx
  loop @wait1

  { Write data }
  mov dx, OPL2_DATA_PORT
  mov al, Data
  out dx, al

  { Wait ~23 microseconds (35 reads of status port) }
  mov dx, OPL2_ADDR_PORT
  mov cx, 35
  @wait2:
  in al, dx
  loop @wait2
end;

{ Load IMF file from disk }
function IMF_Obj.LoadFile(const FileName: string): Boolean;
var
  F: File;
  FileSize: LongInt;
  Header: Word;
  BytesRead: Word;
  DataSize: LongInt;
  i: Word;
  TempChunk: TIMFChunk;
begin
  LoadFile := False;
  LastError := '';

  { Free previous music if loaded }
  if LoadedFromFile and (Chunks <> nil) then
  begin
    FreeMem(Chunks, ChunkCount * SizeOf(TIMFChunk));
    Chunks := nil;
  end;

  { Open file }
  Assign(F, FileName);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult <> 0 then
  begin
    LastError := 'File not found: ' + FileName;
    Exit;
  end;

  FileSize := System.FileSize(F);
  if FileSize < 4 then
  begin
    LastError := 'File too small to be valid IMF';
    Close(F);
    Exit;
  end;

  { Read first word to check for Type 1 header }
  BlockRead(F, Header, 2, BytesRead);

  { Determine IMF type }
  { Type 1: FileSize % 4 = 2 (due to 2-byte header), Header = FileSize - 2 }
  { Type 0: FileSize % 4 = 0 (chunks only, no header) }
  if ((FileSize mod 4) = 2) and (Header = FileSize - 2) then
  begin
    { Type 1: Has length header }
    DataSize := Header;
  end
  else
  begin
    { Type 0: No header, rewind and read all }
    Seek(F, 0);
    DataSize := FileSize;
  end;

  { Calculate number of chunks (each chunk = 4 bytes) }
  ChunkCount := DataSize div 4;

  if ChunkCount = 0 then
  begin
    LastError := 'No music data in file';
    Close(F);
    Exit;
  end;

  { Allocate memory for chunks }
  GetMem(Chunks, ChunkCount * SizeOf(TIMFChunk));

  { Check if allocation succeeded }
  if Chunks = nil then
  begin
    LastError := 'Out of memory (failed to allocate ' + IntToStr(ChunkCount * 4) + ' bytes)';
    Close(F);
    Exit;
  end;

  { Read all chunks }
  for i := 0 to ChunkCount - 1 do
  begin
    BlockRead(F, TempChunk.Delay, 2, BytesRead);
    BlockRead(F, TempChunk.Reg, 1, BytesRead);
    BlockRead(F, TempChunk.Data, 1, BytesRead);
    Chunks^[i] := TempChunk;
  end;

  Close(F);

  LoadedFromFile := True;
  CurrentChunk := 0;
  DelayCounter := 0;

  LoadFile := True;
end;

{ Load IMF from memory }
procedure IMF_Obj.LoadMem(MusicAddress: Pointer; MusicSize: LongInt);
var
  Header: Word;
  DataPtr: ^Byte;
  DataSize: LongInt;
  i: Word;
begin
  { Free previous music if loaded from file }
  if LoadedFromFile and (Chunks <> nil) then
  begin
    FreeMem(Chunks, ChunkCount * SizeOf(TIMFChunk));
    Chunks := nil;
  end;

  DataPtr := MusicAddress;

  { Check for Type 1 header }
  Header := PWord(DataPtr)^;

  { Type 1: MusicSize % 4 = 2 (due to 2-byte header), Header = MusicSize - 2 }
  { Type 0: MusicSize % 4 = 0 (chunks only, no header) }
  if ((MusicSize mod 4) = 2) and (Header = MusicSize - 2) then
  begin
    { Type 1: Skip header }
    Inc(DataPtr, 2);
    DataSize := Header;
  end
  else
  begin
    { Type 0: No header }
    DataSize := MusicSize;
  end;

  { Point to external data (not copied, not freed) }
  Chunks := PIMFChunkArray(DataPtr);
  ChunkCount := DataSize div 4;
  LoadedFromFile := False;
  CurrentChunk := 0;
  DelayCounter := 0;
end;

{ Check if music data is loaded in memory }
function IMF_Obj.IsDataLoaded: Boolean;
begin
  IsDataLoaded := (Chunks <> nil) and (ChunkCount > 0);
end;

{ Get chunk data for debugging }
procedure IMF_Obj.GetChunkData(Index: Word; var Delay: Word; var Reg, Data: Byte);
begin
  if (Chunks = nil) or (Index >= ChunkCount) then
  begin
    Delay := 0;
    Reg := 0;
    Data := 0;
  end
  else
  begin
    Delay := Chunks^[Index].Delay;
    Reg := Chunks^[Index].Reg;
    Data := Chunks^[Index].Data;
  end;
end;

{ Start playback }
procedure IMF_Obj.Start;
begin
  if Chunks = nil then
    Exit;

  CurrentChunk := 0;
  DelayCounter := 0;
  TickAccumulator := 0;
  LastTime := GetBIOSTicks;
  Playing := True;
end;

{ Stop playback }
procedure IMF_Obj.Stop;
begin
  Playing := False;
  SilenceOPL2;
end;

{ Poll - MUST be called every frame to update playback }
procedure IMF_Obj.Poll;
var
  CurrentTime: LongInt;
  DeltaTicks: LongInt;
  UpdatesNeeded: Word;
  i: Word;
begin
  if not Playing then
    Exit;

  if Chunks = nil then
  begin
    Playing := False;
    Exit;
  end;

  { Calculate time delta }
  CurrentTime := GetBIOSTicks;
  DeltaTicks := CurrentTime - LastTime;
  LastTime := CurrentTime;

  { Handle timer wraparound (midnight) }
  if DeltaTicks < 0 then
    DeltaTicks := DeltaTicks + $1800B0;

  { Accumulate ticks }
  TickAccumulator := TickAccumulator + (DeltaTicks * 65536);

  { Process updates }
  while TickAccumulator >= TicksPerUpdate do
  begin
    TickAccumulator := TickAccumulator - TicksPerUpdate;

    { Update delay counter }
    if DelayCounter > 0 then
    begin
      Dec(DelayCounter);
    end
    else
    begin
      { Process next chunk }
      if CurrentChunk >= ChunkCount then
      begin
        { End of music }
        if Looping then
        begin
          CurrentChunk := 0;
          DelayCounter := 0;
        end
        else
        begin
          Playing := False;
          SilenceOPL2;
          Exit;
        end;
      end;

      { Get current chunk }
      with Chunks^[CurrentChunk] do
      begin
        { Check for end marker }
        if Delay = 0 then
        begin
          { End of music or loop point }
          if Looping then
          begin
            CurrentChunk := 0;
            DelayCounter := 0;
          end
          else
          begin
            Playing := False;
            SilenceOPL2;
            Exit;
          end;
        end
        else
        begin
          { Write register }
          WriteOPL2(Reg, Data);

          { Set delay for next chunk }
          DelayCounter := Delay;

          { Move to next chunk }
          Inc(CurrentChunk);
        end;
      end;
    end;
  end;
end;

end.
