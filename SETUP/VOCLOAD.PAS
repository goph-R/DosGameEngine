unit VocLoad;

{ Helper unit to load VOC files and play them with SBDSP }

interface

uses SBDSP;

{ Load and play a VOC file using SBDSP }
{ Note: Caller must wait for Playing to become False before freeing memory }
function PlayVOCFile(const FileName: string): Boolean;

{ Free any allocated sound buffer - call after playback completes }
procedure FreeVOCBuffer;

implementation

var
  LastVOCBuffer: Pointer;
  LastVOCBufferSize: Word;

function PlayVOCFile(const FileName: string): Boolean;
var
  F: File;
  Header: array[0..25] of Byte;
  BytesRead: Word;
  BlockType: Byte;
  BlockSize: array[0..2] of Byte;
  SampleRate: Byte;
  Packing: Byte;
  DataSize: Word;
  CalcSampleRate: Word;
  Sound: BaseSoundType;
begin
  PlayVOCFile := False;

  { Open file }
  Assign(F, FileName);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult <> 0 then
    Exit;

  { Read VOC header }
  BlockRead(F, Header, 26, BytesRead);
  if BytesRead <> 26 then
  begin
    Close(F);
    Exit;
  end;

  { Verify signature "Creative Voice File" }
  if (Header[0] <> $43) or (Header[1] <> $72) or (Header[19] <> $1A) then
  begin
    Close(F);
    Exit;
  end;

  { Read data blocks }
  while True do
  begin
    BlockRead(F, BlockType, 1, BytesRead);
    if BytesRead <> 1 then
      Break;

    { Block type 0 = terminator }
    if BlockType = 0 then
      Break;

    { Read block size (24-bit little-endian) }
    BlockRead(F, BlockSize, 3, BytesRead);
    if BytesRead <> 3 then
      Break;

    DataSize := Word(BlockSize[0]) or (Word(BlockSize[1]) shl 8);

    { Block type 1 = sound data }
    if BlockType = 1 then
    begin
      { Read sample rate and packing }
      BlockRead(F, SampleRate, 1, BytesRead);
      BlockRead(F, Packing, 1, BytesRead);

      Dec(DataSize, 2); { Adjust for SR and packing bytes }

      { Allocate buffer for sound data }
      if DataSize > 0 then
      begin
        { Free previous buffer if it exists }
        if LastVOCBuffer <> nil then
          FreeMem(LastVOCBuffer, LastVOCBufferSize);

        { Allocate new buffer }
        GetMem(Sound.Buffer, DataSize);
        LastVOCBuffer := Sound.Buffer;
        LastVOCBufferSize := DataSize;

        BlockRead(F, Sound.Buffer^, DataSize, BytesRead);

        { Calculate actual sample rate: SR = 1000000 / (256 - rate_byte) }
        CalcSampleRate := 1000000 div (256 - SampleRate);

        { Set up BaseSoundType }
        Sound.Frequency := CalcSampleRate;
        Sound.DACType := EightBitDMA;
        Sound.Phase := Mono;
        Sound.BufferSize := DataSize;

        { Play the sample using SBDSP }
        PlaySound(Sound);

        PlayVOCFile := True;
      end;

      Break; { Play only first sound block }
    end
    else
    begin
      { Skip unknown block types }
      Seek(F, FilePos(F) + DataSize);
    end;
  end;

  Close(F);
end;

procedure FreeVOCBuffer;
begin
  if LastVOCBuffer <> nil then
  begin
    FreeMem(LastVOCBuffer, LastVOCBufferSize);
    LastVOCBuffer := nil;
    LastVOCBufferSize := 0;
  end;
end;

begin
  { Initialize globals }
  LastVOCBuffer := nil;
  LastVOCBufferSize := 0;
end.
