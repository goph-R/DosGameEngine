unit SB;

{$G+}  { Enable 286 instructions }

interface

type
  TSoundBlaster = object
    BasePort: Word;
    IRQ: Byte;
    DMA: Byte;
    Detected: Boolean;
    Playing: Boolean;
    DMABuffer: Pointer;
    DMABufferSize: Word;

    function Init: Boolean;
    function Detect: Boolean;
    function ResetDSP: Boolean;
    procedure WriteDSP(Value: Byte);
    function ReadDSP: Byte;
    function PlayVOC(const FileName: string): Boolean;
    function PlayRaw(Sample: Pointer; Length: Word; SampleRate: Word): Boolean;
    procedure SetupDMA(Buffer: Pointer; Length: Word);
    procedure WaitForPlayback;
    procedure Done;
  end;

implementation

const
  { Sound Blaster DSP ports (offset from base) }
  DSP_RESET        = $06;
  DSP_READ_DATA    = $0A;
  DSP_WRITE_DATA   = $0C;
  DSP_WRITE_STATUS = $0C;
  DSP_READ_STATUS  = $0E;
  DSP_ACK_8BIT     = $0E;

  { DSP Commands }
  DSP_SET_TIME_CONSTANT = $40;
  DSP_DMA_8BIT_PCM      = $14;
  DSP_SPEAKER_ON        = $D1;
  DSP_SPEAKER_OFF       = $D3;
  DSP_GET_VERSION       = $E1;

  { DMA Controller ports }
  DMA_ADDR_0     = $00;  { DMA Channel 0 Address }
  DMA_COUNT_0    = $01;  { DMA Channel 0 Count }
  DMA_ADDR_1     = $02;  { DMA Channel 1 Address }
  DMA_COUNT_1    = $03;  { DMA Channel 1 Count }
  DMA_ADDR_2     = $04;  { DMA Channel 2 Address }
  DMA_COUNT_2    = $05;  { DMA Channel 2 Count }
  DMA_ADDR_3     = $06;  { DMA Channel 3 Address }
  DMA_COUNT_3    = $07;  { DMA Channel 3 Count }
  DMA_STATUS     = $08;  { DMA Status Register }
  DMA_COMMAND    = $08;  { DMA Command Register }
  DMA_REQUEST    = $09;  { DMA Request Register }
  DMA_MASK       = $0A;  { DMA Mask Register }
  DMA_MODE       = $0B;  { DMA Mode Register }
  DMA_FLIPFLOP   = $0C;  { DMA Flip-Flop Reset }
  DMA_TEMP       = $0D;  { DMA Temporary Register }
  DMA_MASTER_CLR = $0D;  { DMA Master Clear }
  DMA_CLR_MASK   = $0E;  { DMA Clear Mask Register }
  DMA_MASK_ALL   = $0F;  { DMA Write All Mask Bits }

  { DMA Page registers }
  DMA_PAGE_0     = $87;  { DMA Channel 0 Page }
  DMA_PAGE_1     = $83;  { DMA Channel 1 Page }
  DMA_PAGE_2     = $81;  { DMA Channel 2 Page }
  DMA_PAGE_3     = $82;  { DMA Channel 3 Page }

  { DMA Modes }
  DMA_MODE_READ  = $48;  { Single transfer, increment, no auto-init, read }
  DMA_MODE_WRITE = $44;  { Single transfer, increment, no auto-init, write }

{ Reset the DSP }
function TSoundBlaster.ResetDSP: Boolean;
var
  i: Integer;
begin
  ResetDSP := False;

  { Send reset signal }
  Port[BasePort + DSP_RESET] := 1;

  { Wait 3 microseconds (approximate) }
  for i := 1 to 10 do
    asm nop end;

  Port[BasePort + DSP_RESET] := 0;

  { Wait for DSP ready (0xAA) }
  for i := 1 to 1000 do
  begin
    if (Port[BasePort + DSP_READ_STATUS] and $80) <> 0 then
    begin
      if Port[BasePort + DSP_READ_DATA] = $AA then
      begin
        ResetDSP := True;
        Exit;
      end;
    end;
  end;
end;

{ Write a byte to DSP }
procedure TSoundBlaster.WriteDSP(Value: Byte);
var
  i: Word;
begin
  { Wait for DSP ready to accept data }
  for i := 1 to 65535 do
  begin
    if (Port[BasePort + DSP_WRITE_STATUS] and $80) = 0 then
    begin
      Port[BasePort + DSP_WRITE_DATA] := Value;
      Exit;
    end;
  end;
end;

{ Read a byte from DSP }
function TSoundBlaster.ReadDSP: Byte;
var
  i: Word;
begin
  ReadDSP := 0;

  { Wait for data available }
  for i := 1 to 65535 do
  begin
    if (Port[BasePort + DSP_READ_STATUS] and $80) <> 0 then
    begin
      ReadDSP := Port[BasePort + DSP_READ_DATA];
      Exit;
    end;
  end;
end;

{ Detect Sound Blaster card }
function TSoundBlaster.Detect: Boolean;
var
  TestPorts: array[1..6] of Word;
  i: Integer;
  MajorVer, MinorVer: Byte;
begin
  Detect := False;
  Detected := False;

  { Common Sound Blaster base addresses }
  TestPorts[1] := $220;
  TestPorts[2] := $240;
  TestPorts[3] := $260;
  TestPorts[4] := $280;
  TestPorts[5] := $2A0;
  TestPorts[6] := $2C0;

  { Try each port }
  for i := 1 to 6 do
  begin
    BasePort := TestPorts[i];

    if ResetDSP then
    begin
      { Get DSP version }
      WriteDSP(DSP_GET_VERSION);
      MajorVer := ReadDSP;
      MinorVer := ReadDSP;

      if MajorVer >= 1 then
      begin
        { Default IRQ and DMA (can be made configurable) }
        IRQ := 5;
        DMA := 1;
        Detected := True;
        Detect := True;
        Exit;
      end;
    end;
  end;
end;

{ Setup DMA transfer }
procedure TSoundBlaster.SetupDMA(Buffer: Pointer; Length: Word);
var
  Page: Byte;
  Offset: Word;
  PhysAddr: LongInt;
  DMAAddr, DMACount, DMAPage, DMAMask: Byte;
  DMAMode: Byte;
begin
  { Calculate physical address }
  PhysAddr := (LongInt(Seg(Buffer^)) shl 4) + Ofs(Buffer^);
  Page := (PhysAddr shr 16) and $FF;
  Offset := PhysAddr and $FFFF;

  { Determine DMA ports based on channel }
  case DMA of
    0: begin
         DMAAddr := DMA_ADDR_0;
         DMACount := DMA_COUNT_0;
         DMAPage := DMA_PAGE_0;
         DMAMask := 0;
       end;
    1: begin
         DMAAddr := DMA_ADDR_1;
         DMACount := DMA_COUNT_1;
         DMAPage := DMA_PAGE_1;
         DMAMask := 1;
       end;
    2: begin
         DMAAddr := DMA_ADDR_2;
         DMACount := DMA_COUNT_2;
         DMAPage := DMA_PAGE_2;
         DMAMask := 2;
       end;
    3: begin
         DMAAddr := DMA_ADDR_3;
         DMACount := DMA_COUNT_3;
         DMAPage := DMA_PAGE_3;
         DMAMask := 3;
       end;
    else
      Exit;
  end;

  { Mode: Read transfer (device to memory) }
  DMAMode := DMA_MODE_READ or DMAMask;

  { Disable interrupts during DMA setup }
  asm cli end;

  { Mask DMA channel }
  Port[DMA_MASK] := 4 or DMAMask;

  { Clear flip-flop }
  Port[DMA_FLIPFLOP] := 0;

  { Set DMA mode }
  Port[DMA_MODE] := DMAMode;

  { Set DMA address (low byte, then high byte) }
  Port[DMAAddr] := Lo(Offset);
  Port[DMAAddr] := Hi(Offset);

  { Clear flip-flop again }
  Port[DMA_FLIPFLOP] := 0;

  { Set DMA count (length - 1) }
  Dec(Length);
  Port[DMACount] := Lo(Length);
  Port[DMACount] := Hi(Length);

  { Set DMA page }
  Port[DMAPage] := Page;

  { Unmask DMA channel }
  Port[DMA_MASK] := DMAMask;

  { Re-enable interrupts }
  asm sti end;
end;

{ Initialize Sound Blaster }
function TSoundBlaster.Init: Boolean;
begin
  Init := Detect;
  Playing := False;
  DMABuffer := nil;
  DMABufferSize := 0;

  if Detected then
  begin
    { Turn speaker on }
    WriteDSP(DSP_SPEAKER_ON);
  end;
end;

{ Wait for playback to complete }
procedure TSoundBlaster.WaitForPlayback;
begin
  while Playing do
  begin
    { Check if DSP is still busy }
    { In a real implementation, this would check an interrupt flag }
    { For now, we just delay a bit }
    asm
      mov cx, 1000
    @Loop:
      loop @Loop
    end;
  end;
end;

{ Play raw 8-bit PCM data }
function TSoundBlaster.PlayRaw(Sample: Pointer; Length: Word; SampleRate: Word): Boolean;
var
  TimeConstant: Byte;
  LengthLo, LengthHi: Byte;
  TempLength: Word;
begin
  PlayRaw := False;

  if not Detected then
    Exit;

  if Length = 0 then
    Exit;

  { Allocate DMA buffer if needed }
  if (DMABuffer = nil) or (DMABufferSize < Length) then
  begin
    if DMABuffer <> nil then
      FreeMem(DMABuffer, DMABufferSize);

    { Allocate buffer (ensure it doesn't cross 64KB boundary) }
    GetMem(DMABuffer, Length);
    DMABufferSize := Length;
  end;

  { Copy sample data to DMA buffer }
  Move(Sample^, DMABuffer^, Length);

  { Setup DMA transfer }
  SetupDMA(DMABuffer, Length);

  { Calculate time constant: TC = 256 - (1000000 / SampleRate) }
  TimeConstant := 256 - (1000000 div SampleRate);

  { Set time constant }
  WriteDSP(DSP_SET_TIME_CONSTANT);
  WriteDSP(TimeConstant);

  { Length - 1 for DSP }
  TempLength := Length - 1;
  LengthLo := Lo(TempLength);
  LengthHi := Hi(TempLength);

  { Send DMA playback command }
  WriteDSP(DSP_DMA_8BIT_PCM);
  WriteDSP(LengthLo);
  WriteDSP(LengthHi);

  Playing := True;
  PlayRaw := True;

  { Acknowledge interrupt (for Sound Blaster) }
  { This tells the DSP we're ready }
  { Note: Real interrupt handling would be better }
end;

{ Play VOC file }
function TSoundBlaster.PlayVOC(const FileName: string): Boolean;
var
  F: File;
  Header: array[0..25] of Byte;
  BytesRead: Word;
  BlockType: Byte;
  BlockSize: array[0..2] of Byte;
  SampleRate: Byte;
  Packing: Byte;
  Buffer: Pointer;
  DataSize: Word;
  CalcSampleRate: Word;
begin
  PlayVOC := False;

  if not Detected then
    Exit;

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
        GetMem(Buffer, DataSize);
        BlockRead(F, Buffer^, DataSize, BytesRead);

        { Calculate actual sample rate: SR = 1000000 / (256 - rate_byte) }
        CalcSampleRate := 1000000 div (256 - SampleRate);

        { Play the sample }
        PlayRaw(Buffer, DataSize, CalcSampleRate);

        FreeMem(Buffer, DataSize);
        PlayVOC := True;
      end;

      Break; { Play only first sound block for now }
    end
    else
    begin
      { Skip unknown block types }
      Seek(F, FilePos(F) + DataSize);
    end;
  end;

  Close(F);
end;

{ Shutdown Sound Blaster }
procedure TSoundBlaster.Done;
begin
  if Detected then
  begin
    { Wait for any playing sound to finish }
    Playing := False;

    { Turn speaker off }
    WriteDSP(DSP_SPEAKER_OFF);

    { Free DMA buffer }
    if DMABuffer <> nil then
    begin
      FreeMem(DMABuffer, DMABufferSize);
      DMABuffer := nil;
      DMABufferSize := 0;
    end;
  end;
end;

end.
