unit SndBank;

{ Sound Bank - XMS-based sound library manager for SBDSP }
{ Stores multiple VOC files in extended memory, loads on demand }

interface

uses XMS, SBDSP, Crt, Dos;

const
  MaxSounds = 32;  { Maximum sounds in bank }

type
  TSoundInfo = record
    Name: String[12];       { Sound name (e.g., 'EXPLODE.VOC') }
    XMSHandle: Word;        { XMS block handle }
    XMSOffset: LongInt;     { Offset within XMS block (for shared blocks) }
    Size: Word;             { Size in bytes }
    SampleRate: Word;       { Sample rate (extracted from VOC header) }
    Loaded: Boolean;        { True if in XMS }
  end;

  TSoundBank = object
    Sounds: array[0..MaxSounds-1] of TSoundInfo;
    Count: Integer;
    PlayBuffer: Pointer;      { Conventional memory playback buffer }
    PlayBufferSize: Word;     { Current buffer size }
    XMSAvailable: Boolean;

    function Init: Boolean;
    function LoadSound(const FileName: string): Integer;  { Returns sound ID }
    function PlaySound(SoundID: Integer): Boolean;
    procedure StopSound;
    procedure Done;
  private
    function AllocPlayBuffer(Size: Word): Boolean;
    procedure FreePlayBuffer;
  end;

implementation

{ Initialize sound bank }
function TSoundBank.Init: Boolean;
begin
  Count := 0;
  PlayBuffer := nil;
  PlayBufferSize := 0;
  XMSAvailable := XMSinstalled;

  if not XMSAvailable then
  begin
    WriteLn('Warning: XMS not available - sound bank disabled');
    Init := False;
    Exit;
  end;

  Init := True;
end;

{ Load VOC file into XMS memory }
function TSoundBank.LoadSound(const FileName: string): Integer;
var
  F: File;
  Header: array[0..25] of Byte;
  BlockType: Byte;
  BlockSize: array[0..2] of Byte;
  SampleRate: Byte;
  Packing: Byte;
  DataSize: Word;
  TempBuffer: Pointer;
  XMSHandle: Word;
  BytesRead: Word;
  E: EMMstruct;
  TransferSize: LongInt;
  CalcSampleRate: Word;
begin
  LoadSound := -1;  { Error }

  if Count >= MaxSounds then
    Exit;

  { Open VOC file }
  Assign(F, FileName);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult <> 0 then
    Exit;

  { Read and verify VOC header }
  BlockRead(F, Header, 26, BytesRead);
  if (BytesRead <> 26) or (Header[0] <> $43) or (Header[19] <> $1A) then
  begin
    Close(F);
    Exit;
  end;

  { Find sound data block (type 1) }
  repeat
    BlockRead(F, BlockType, 1, BytesRead);
    if BytesRead <> 1 then Break;
    if BlockType = 0 then Break;  { Terminator }

    BlockRead(F, BlockSize, 3, BytesRead);
    DataSize := Word(BlockSize[0]) or (Word(BlockSize[1]) shl 8);

    if BlockType = 1 then
    begin
      { Read sample rate and packing }
      BlockRead(F, SampleRate, 1, BytesRead);
      BlockRead(F, Packing, 1, BytesRead);
      Dec(DataSize, 2);

      { Allocate XMS memory for this sound }
      XMSHandle := AllocXMS((DataSize + 1023) div 1024);  { Round up to KB }
      if XMSHandle = 0 then
      begin
        Close(F);
        Exit;
      end;

      { Allocate temporary buffer in conventional memory }
      { XMS requires even-sized transfers, so round up if odd }
      if Odd(DataSize) then
        GetMem(TempBuffer, DataSize + 1)
      else
        GetMem(TempBuffer, DataSize);

      { Read sound data }
      BlockRead(F, TempBuffer^, DataSize, BytesRead);

      { Verify read was successful }
      if BytesRead <> DataSize then
      begin
        if Odd(DataSize) then
          FreeMem(TempBuffer, DataSize + 1)
        else
          FreeMem(TempBuffer, DataSize);
        FreeXMS(XMSHandle);
        Close(F);
        Exit;
      end;

      { Transfer to XMS using direct MoveXMS (avoid Mem2Xms bug with odd sizes) }
      { Round up to even size for XMS transfer }
      if Odd(DataSize) then
        TransferSize := DataSize + 1
      else
        TransferSize := DataSize;

      with E do
      begin
        size := TransferSize;
        soh := 0;                        { Source: conventional memory }
        { Convert pointer to linear address: (Seg * 16) + Ofs }
        soo := (LongInt(Seg(TempBuffer^)) * 16) + Ofs(TempBuffer^);
        dsh := XMSHandle;                { Destination: XMS }
        dso := 0;                        { Destination offset }
      end;

      if not MoveXMS(E) then
      begin
        { XMS transfer failed }
        if Odd(DataSize) then
          FreeMem(TempBuffer, DataSize + 1)
        else
          FreeMem(TempBuffer, DataSize);
        FreeXMS(XMSHandle);
        Close(F);
        Exit;
      end;

      { Verify XMS transfer succeeded }
      if XMSerror <> 0 then
      begin
        if Odd(DataSize) then
          FreeMem(TempBuffer, DataSize + 1)
        else
          FreeMem(TempBuffer, DataSize);
        FreeXMS(XMSHandle);
        Close(F);
        Exit;
      end;

      { Free temporary buffer }
      if Odd(DataSize) then
        FreeMem(TempBuffer, DataSize + 1)
      else
        FreeMem(TempBuffer, DataSize);

      { Calculate sample rate from VOC byte }
      CalcSampleRate := 1000000 div (256 - SampleRate);

      { Store sound info }
      with Sounds[Count] do
      begin
        Name := FileName;
        XMSHandle := XMSHandle;
        XMSOffset := 0;
        Size := DataSize;
        SampleRate := CalcSampleRate;
        Loaded := True;
      end;

      LoadSound := Count;
      Inc(Count);
      Break;
    end
    else
    begin
      { Skip unknown block }
      Seek(F, FilePos(F) + DataSize);
    end;
  until False;

  Close(F);
end;

{ Allocate playback buffer in conventional memory }
function TSoundBank.AllocPlayBuffer(Size: Word): Boolean;
begin
  { Free old buffer if different size }
  if (PlayBuffer <> nil) and (PlayBufferSize <> Size) then
    FreePlayBuffer;

  { Allocate new buffer if needed }
  if PlayBuffer = nil then
  begin
    GetMem(PlayBuffer, Size);
    PlayBufferSize := Size;
  end;

  AllocPlayBuffer := (PlayBuffer <> nil);
end;

{ Free playback buffer }
procedure TSoundBank.FreePlayBuffer;
begin
  if PlayBuffer <> nil then
  begin
    FreeMem(PlayBuffer, PlayBufferSize);
    PlayBuffer := nil;
    PlayBufferSize := 0;
  end;
end;

{ Play sound by ID - loads from XMS to conventional memory first }
function TSoundBank.PlaySound(SoundID: Integer): Boolean;
var
  Sound: BaseSoundType;
  BufferSize: Word;
  E: EMMstruct;
begin
  PlaySound := False;

  if (SoundID < 0) or (SoundID >= Count) then
    Exit;

  if not Sounds[SoundID].Loaded then
    Exit;

  { Allocate playback buffer (round up to even size for XMS) }
  BufferSize := Sounds[SoundID].Size;
  if Odd(BufferSize) then
    Inc(BufferSize);

  if not AllocPlayBuffer(BufferSize) then
    Exit;

  { Copy sound from XMS using direct MoveXMS }
  with E do
  begin
    size := BufferSize;
    soh := Sounds[SoundID].XMSHandle;     { Source: XMS }
    soo := Sounds[SoundID].XMSOffset;     { Source offset }
    dsh := 0;                             { Destination: conventional memory }
    { Convert pointer to linear address: (Seg * 16) + Ofs }
    dso := (LongInt(Seg(PlayBuffer^)) * 16) + Ofs(PlayBuffer^);
  end;

  { Disable interrupts during XMS transfer to prevent SB IRQ conflicts }
  if not MoveXMS(E) then
  begin
    Exit;
  end;

  { Verify XMS retrieval succeeded }
  if XMSerror <> 0 then
    Exit;

  { Ensure DSP is stopped before playing new sound }
  if Playing then
  begin
    DMAStop;
    Delay(50);
    SpeakerOff;
    Playing := False;
  end;

  { Set up SBDSP sound structure }
  Sound.Buffer := PlayBuffer;
  Sound.BufferSize := Sounds[SoundID].Size;
  Sound.Frequency := Sounds[SoundID].SampleRate;
  Sound.DACType := EightBitDMA;
  Sound.Phase := 0;  { Mono }

  { Play via SBDSP }
  SBDSP.PlaySound(Sound);

  PlaySound := True;
end;

{ Stop currently playing sound }
procedure TSoundBank.StopSound;
begin
  if Playing then
  begin
    DMAStop;
    Delay(50);    { Give DMA time to stop }
    SpeakerOff;
    Playing := False;
  end;
end;

{ Cleanup - free all XMS blocks and buffers }
procedure TSoundBank.Done;
var
  i: Integer;
begin
  { Stop any playing sound }
  StopSound;

  { Free all XMS blocks }
  for i := 0 to Count - 1 do
  begin
    if Sounds[i].Loaded then
      FreeXMS(Sounds[i].XMSHandle);
  end;

  { Free playback buffer }
  FreePlayBuffer;

  Count := 0;
end;

end.
