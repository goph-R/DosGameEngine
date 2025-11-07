unit PKMLoad;

interface

uses VGA;

type
  TPKMHeader = record
    Signature: array[0..2] of Char;
    Version: Byte;
    Pack_byte: Byte;
    Pack_word: Byte;
    Width: Word;
    Height: Word;
    PH_size: Word;
  end;

function LoadPKM(const FileName: string; var Image: TImage;
                 var Palette: TPalette): Boolean;

implementation

function LoadPKM(const FileName: string; var Image: TImage;
                 var Palette: TPalette): Boolean;
type
  PByteArray = ^TByteArray;
  TByteArray = array[0..65520] of Byte;
var
  F: File;
  Header: TPKMHeader;
  BytesRead: Word;
  Image_size: LongInt;
  Data_size: LongInt;
  Packed_data_counter: LongInt;
  Pixels_counter: LongInt;
  Byte_read: Byte;
  Color: Byte;
  Word_read: Word;
  Counter: Word;
  i: Integer;
  FileSizeBytes: LongInt;
  TempByte: Byte;
  ImageBuffer: PByteArray;
begin
  LoadPKM := False;

  { Initialize Image structure }
  Image.Width := 0;
  Image.Height := 0;
  Image.Data := nil;
  
  { Open file }
  Assign(F, FileName);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult <> 0 then
    Exit;
  
  { Get file size }
  FileSizeBytes := FileSize(F);
  
  { Read header - signature }
  BlockRead(F, Header.Signature, 3, BytesRead);
  if (BytesRead <> 3) or (Header.Signature <> 'PKM') then
  begin
    Close(F);
    Exit;
  end;
  
  { Read header - version }
  BlockRead(F, Header.Version, 1, BytesRead);
  if BytesRead <> 1 then
  begin
    Close(F);
    Exit;
  end;
  
  { Read header - pack bytes }
  BlockRead(F, Header.Pack_byte, 1, BytesRead);
  BlockRead(F, Header.Pack_word, 1, BytesRead);
  
  { Read header - dimensions (Intel byte order: low byte first) }
  BlockRead(F, Header.Width, 2, BytesRead);
  BlockRead(F, Header.Height, 2, BytesRead);
  
  { Verify dimensions are valid and within 64K limit }
  if (Header.Width = 0) or (Header.Height = 0) then
  begin
    Close(F);
    Exit;
  end;

  Image_size := LongInt(Header.Width) * LongInt(Header.Height);
  if Image_size > 65520 then  { Maximum GetMem block size in real mode }
  begin
    Close(F);
    Exit;
  end;

  { Read palette (768 bytes = 256 colors * 3 components) }
  BlockRead(F, Palette, 768, BytesRead);
  if BytesRead <> 768 then
  begin
    Close(F);
    Exit;
  end;

  { Read post-header size }
  BlockRead(F, Header.PH_size, 2, BytesRead);
  if BytesRead <> 2 then
  begin
    Close(F);
    Exit;
  end;

  { Skip post-header data if present }
  if Header.PH_size > 0 then
  begin
    for i := 1 to Header.PH_size do
    begin
      BlockRead(F, TempByte, 1, BytesRead);
      if BytesRead <> 1 then
      begin
        Close(F);
        Exit;
      end;
    end;
  end;
  
  { Set image dimensions and allocate memory }
  Image.Width := Header.Width;
  Image.Height := Header.Height;
  GetMem(Image.Data, Image_size);
  ImageBuffer := Image.Data;  

  { Calculate data size }
  Data_size := FileSizeBytes - (780 + Header.PH_size);
  
  Packed_data_counter := 0;
  Pixels_counter := 0;
  
  { Depacking loop }
  while (Pixels_counter < Image_size) and (Packed_data_counter < Data_size) do
  begin
    BlockRead(F, Byte_read, 1, BytesRead);
    if BytesRead <> 1 then
      Break;
    
    { If it is not a packet recognizer, it's a raw pixel }
    if (Byte_read <> Header.Pack_byte) and (Byte_read <> Header.Pack_word) then
    begin
      ImageBuffer^[Pixels_counter] := Byte_read;
      Inc(Pixels_counter);
      Inc(Packed_data_counter);
    end
    else
    begin
      { Is the number of pixels to repeat coded with 1 byte }
      if Byte_read = Header.Pack_byte then
      begin
        BlockRead(F, Color, 1, BytesRead);
        if BytesRead <> 1 then
          Break;
        BlockRead(F, Byte_read, 1, BytesRead);
        if BytesRead <> 1 then
          Break;
        
        { Repeat color Byte_read times }
        for Counter := 0 to Byte_read - 1 do
        begin
          if Pixels_counter + Counter < Image_size then
            ImageBuffer^[Pixels_counter + Counter] := Color;
        end;
        
        Inc(Pixels_counter, Byte_read);
        Inc(Packed_data_counter, 3);
      end
      else  { coded with 2 bytes }
      begin
        BlockRead(F, Color, 1, BytesRead);
        if BytesRead <> 1 then
          Break;
        
        { Read word in big-endian format (high byte first) }
        BlockRead(F, Byte_read, 1, BytesRead);
        if BytesRead <> 1 then
          Break;
        Word_read := Word(Byte_read) shl 8;
        
        BlockRead(F, Byte_read, 1, BytesRead);
        if BytesRead <> 1 then
          Break;
        Word_read := Word_read or Byte_read;
        
        { Repeat color Word_read times }
        for Counter := 0 to Word_read - 1 do
        begin
          if Pixels_counter + Counter < Image_size then
            ImageBuffer^[Pixels_counter + Counter] := Color;
        end;
        
        Inc(Pixels_counter, Word_read);
        Inc(Packed_data_counter, 4);
      end;
    end;
  end;
  
  Close(F);
  LoadPKM := (Pixels_counter = Image_size);
end;

end.