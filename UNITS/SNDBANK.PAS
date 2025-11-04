unit SndBank;

{ Sound Bank - XMS-based sound library manager for SBDSP }
{ Stores multiple VOC files in extended memory, loads on demand }
{ DMA-safe buffer allocation by ChatGPT (2025) }

{ DOSBox-X QUIRK: PlaySound() requires caller to have dummy variables }
{ in their var section or sound cuts off immediately. Works fine in   }
{ 86Box without workaround. Cause unknown after extensive testing.    }
{ See CLAUDE.md Common Pitfall #16 for full investigation.            }

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
    PlayBufferRaw: Pointer;   { the raw block from GetMem }
    PlayBuffer: Pointer;      { the aligned/safe pointer we actually use }
    PlayBufferAllocSize: Word; { requested size }
    PlayBufferSize: Word;
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

type
  TByteArray = array[0..64000] of Byte;
  PByteArray = ^TByteArray;

{ Initialize sound bank }
function TSoundBank.Init: Boolean;
begin
  Count := 0;
  PlayBufferRaw := nil;
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
  RawBlockLen24: LongInt;
  SampleRate: Byte;
  Packing: Byte;
  PCMSize: Word;
  TotalSize: Word;
  TempBuffer: Pointer;
  AllocatedHandle: Word;  { Renamed to avoid "with" scope conflict }
  BytesRead: Word;
  CalcSampleRate: Word;
  P: ^Byte;
begin
  LoadSound := -1;
  if Count >= MaxSounds then Exit;

  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;

  { Read the main VOC header (26 bytes) }
  BlockRead(F, Header, 26, BytesRead);
  if (BytesRead <> 26) or (Header[0] <> $43) or (Header[19] <> $1A) then
  begin
    Close(F);
    Exit;
  end;

  { Read blocks until we find type 1 (sound data) }
  repeat
    BlockRead(F, BlockType, 1, BytesRead);
    if BytesRead <> 1 then Break;
    if BlockType = 0 then Break; { terminator }

    BlockRead(F, BlockSize, 3, BytesRead);
    if BytesRead <> 3 then Break;

    { 24-bit little-endian block length }
    RawBlockLen24 :=
      LongInt(BlockSize[0]) or
      (LongInt(BlockSize[1]) shl 8) or
      (LongInt(BlockSize[2]) shl 16);

    if BlockType = 1 then
    begin
      { VOC block type 1 layout:
        byte 0: blockType (1)
        byte 1..3: block length (24-bit)
        byte 4: sample rate code
        byte 5: packing
        byte 6..: PCM data (RawBlockLen24 - 2 bytes long)
      }

      { Read sample rate code + packing }
      BlockRead(F, SampleRate, 1, BytesRead);
      BlockRead(F, Packing, 1, BytesRead);

      { PCM payload length = blocklen - 2 (rate+packing) }
      PCMSize := RawBlockLen24 - 2;

      { Total buffer we will store in XMS = 6-byte VOC header + PCM data }
      TotalSize := 6 + PCMSize;

      { Allocate XMS block big enough for TotalSize }
      AllocatedHandle := AllocXMS((TotalSize + 1023) div 1024);
      if AllocatedHandle = 0 then
      begin
        Close(F);
        Exit;
      end;

      { Allocate temp buffer in conventional memory to build [header+data] }
      { We also want an even size for XMS transfer later }
      GetMem(TempBuffer, TotalSize + 1);  { +1 is fine, cheap slack }

      { Build the first 6 bytes exactly like a VOC block }
      P := TempBuffer;
      P^ := BlockType;            Inc(P);  { byte 0: 1 }
      P^ := BlockSize[0];         Inc(P);  { bytes 1..3: original 24-bit len }
      P^ := BlockSize[1];         Inc(P);
      P^ := BlockSize[2];         Inc(P);
      P^ := SampleRate;           Inc(P);  { byte 4: VOC time constant }
      P^ := Packing;              Inc(P);  { byte 5: packing method }

      { Read PCM data directly after that header }
      BlockRead(F, P^, PCMSize, BytesRead);
      if BytesRead <> PCMSize then
      begin
        FreeMem(TempBuffer, TotalSize + 1);
        FreeXMS(AllocatedHandle);
        Close(F);
        Exit;
      end;

      { Copy to XMS using standard Mem2Xms function }
      if not Mem2Xms(TempBuffer^, TotalSize, AllocatedHandle, 0) or (XMSerror <> 0) then
      begin
        FreeMem(TempBuffer, TotalSize + 1);
        FreeXMS(AllocatedHandle);
        Close(F);
        Exit;
      end;

      { Free temp buffer }
      FreeMem(TempBuffer, TotalSize + 1);

      { Compute real sample frequency in Hz from VOC time constant }
      CalcSampleRate := 1000000 div (256 - SampleRate);

      { Store info in our table }
      with Sounds[Count] do
      begin
        Name       := FileName;
        XMSHandle  := AllocatedHandle;  { Store the allocated XMS handle }
        XMSOffset  := 0;
        Size       := TotalSize;        { NOTE: includes 6-byte header now }
        SampleRate := CalcSampleRate;   { e.g. 11111 Hz }
        Loaded     := True;
      end;

      LoadSound := Count;
      Inc(Count);
      Break;
    end
    else
    begin
      { Skip non-type-1 blocks }
      Seek(F, FilePos(F) + RawBlockLen24);
    end;
  until False;

  Close(F);
end;


{ Allocate playback buffer in conventional memory }
function TSoundBank.AllocPlayBuffer(Size: Word): Boolean;
var
  RawPtr: Pointer;
  CandidatePtr: Pointer;
  Phys: LongInt;
  OffsetIn64K: Word;
  i: Word;
  Result: Boolean;
  TempOfs: LongInt;     { For safe offset arithmetic }
  NewSeg, NewOfs: Word; { For pointer normalization }
begin
  { If we already have a buffer of the right size, reuse it }
  if (PlayBufferRaw <> nil) and (PlayBufferAllocSize = Size) then
  begin
    AllocPlayBuffer := True;
    Exit;
  end;

  { Otherwise free old buffer first }
  if PlayBufferRaw <> nil then
    FreePlayBuffer;

  { Over-allocate so we can slide inside it.
    Worst case, we might need up to almost 64K extra to find a safe window.
    But your sounds are small (<64K), so +256 or +1024 may be enough.
    We'll be generous: Size + $1000 (4096 bytes).
  }
  GetMem(RawPtr, Size + $1000);
  if RawPtr = nil then
  begin
    AllocPlayBuffer := False;
    Exit;
  end;

  { Now scan forward inside this block to find a safe address }
  PlayBuffer := nil;

  for i := 0 to $0FFF do  { up to 4096 byte shift }
  begin
    { Calculate candidate pointer with proper wraparound handling }
    TempOfs := LongInt(Ofs(RawPtr^)) + i;  { Use LongInt to prevent Word overflow! }
    if TempOfs >= 65536 then
    begin
      { Offset overflowed - normalize to seg:ofs (1 segment = 16 bytes = $10) }
      NewSeg := Seg(RawPtr^) + (TempOfs div 65536) * $1000;  { Add $1000 segs per 64KB }
      NewOfs := TempOfs mod 65536;
      CandidatePtr := Ptr(NewSeg, NewOfs);
    end
    else
      CandidatePtr := Ptr(Seg(RawPtr^), Word(TempOfs));

    { physical linear address = segment * 16 + offset }
    Phys := LongInt(Seg(CandidatePtr^)) * 16 + Ofs(CandidatePtr^);

    { low 16 bits are position within current 64K window }
    OffsetIn64K := Phys and $FFFF;

    { Check: will this block fit without crossing 64K boundary? }
    if OffsetIn64K + Size <= 65536 then
    begin
      { optionally also enforce even physical addr }
      if (Phys and 1) = 0 then
      begin
        PlayBufferRaw := RawPtr;
        PlayBuffer := CandidatePtr;
        PlayBufferAllocSize := Size;

        { DEBUG: Print buffer allocation info }
        WriteLn('DMA Buffer: Phys=', Phys, ' Offset64K=', OffsetIn64K,
                ' Size=', Size, ' End=', OffsetIn64K + Size, ' Shift=', i);

        Break;
      end;
    end;
  end;

  { Did we find one? }
  Result := (PlayBuffer <> nil);
  if not Result then
  begin
    { We failed to find a safe sub-block.
      Clean up to avoid leak.
    }
    WriteLn('ERROR: Could not find DMA-safe buffer in 4K search window!');
    FreeMem(RawPtr, Size + $1000);
    PlayBufferRaw := nil;
    PlayBuffer := nil;
    PlayBufferAllocSize := 0;
  end;
  AllocPlayBuffer := Result;
end;


{ Free playback buffer }
procedure TSoundBank.FreePlayBuffer;
begin
  if PlayBufferRaw <> nil then
  begin
    FreeMem(PlayBufferRaw, PlayBufferAllocSize + $1000);
    PlayBufferRaw := nil;
    PlayBuffer := nil;
    PlayBufferAllocSize := 0;
  end;
end;

{ Play sound by ID - loads from XMS to conventional memory first }
function TSoundBank.PlaySound(SoundID: Integer): Boolean;
var
  Sound: BaseSoundType;
  BufferSize: Word;
begin
  { DOSBox-X fix: Clear Direction Flag - some code (HSC player, interrupts) }
  { may leave DF set, causing XMS transfers and DMA setup to run backwards }
  asm
    cld
  end;

  PlaySound := False;
  if (SoundID < 0) or (SoundID >= Count) then Exit;
  if not Sounds[SoundID].Loaded then Exit;

  { We need a playback buffer big enough for header+PCM }
  BufferSize := Sounds[SoundID].Size;
  if Odd(BufferSize) then Inc(BufferSize);

  if not AllocPlayBuffer(BufferSize) then Exit;

  { Copy full block (header + PCM) from XMS into PlayBuffer }
  if not Xms2Mem(
        Sounds[SoundID].XMSHandle,
        Sounds[SoundID].XMSOffset,
        PlayBuffer^,
        Sounds[SoundID].Size
     ) or (XMSerror <> 0) then
    Exit;

  { Stop anything that was already playing }
  if Playing then
  begin
    DMAStop;
    {Delay(50);}
    SpeakerOff;
    Playing := False;
  end;

  { Tell SBDSP about the sound }
  Sound.Buffer      := PlayBuffer;
  Sound.BufferSize  := Sounds[SoundID].Size;       { includes 6-byte header }
  Sound.Frequency   := Sounds[SoundID].SampleRate; { e.g. 11111 Hz }
  Sound.DACType     := SBDSP.EightBitDMA;          { 8-bit DMA playback }
  Sound.Phase       := SBDSP.Mono;                 { mono for now }

  { Fire it }
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
