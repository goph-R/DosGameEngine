unit BMP;

interface

uses VGA, GenTypes;

type
  TBMPFileHeader = record
    Signature: Word;         { 'BM' = $4D42 }
    FileSize: LongInt;       { Total file size in bytes }
    Reserved1: Word;         { 0 }
    Reserved2: Word;         { 0 }
    DataOffset: LongInt;     { Offset to pixel data from file start }
  end;

  TBMPInfoHeader = record
    Size: LongInt;           { Size of this header (40 bytes) }
    Width: LongInt;          { Image width in pixels }
    Height: LongInt;         { Image height in pixels (positive = bottom-up) }
    Planes: Word;            { 1 }
    BitCount: Word;          { 8 for 256-color }
    Compression: LongInt;    { 0 = BI_RGB (uncompressed) }
    ImageSize: LongInt;      { Size of pixel data (can be 0 for uncompressed) }
    XPelsPerMeter: LongInt;  { Horizontal resolution }
    YPelsPerMeter: LongInt;  { Vertical resolution }
    ColorsUsed: LongInt;     { Number of colors in palette (0 = all 256) }
    ColorsImportant: LongInt;{ Number of important colors (0 = all) }
  end;

  TBMPRGBQuad = record
    Blue: Byte;
    Green: Byte;
    Red: Byte;
    Reserved: Byte;          { Always 0 }
  end;

function LoadBMP(const FileName: string; var Image: TImage): Boolean;
function LoadBMPWithPalette(const FileName: string; var Image: TImage;
                            var Palette: TPalette): Boolean;
function GetLoadBMPError: string;

function SaveBMP(const FileName: string; const Image: TImage; const Palette: TPalette): Boolean;
function GetSaveBMPError: string;

implementation

uses StrUtil;

var
  LoadBMPError: string;
  SaveBMPError: string;

function GetLoadBMPError: string;
begin
  GetLoadBMPError := LoadBMPError;
end;

function GetSaveBMPError: string;
begin
  GetSaveBMPError := SaveBMPError;
end;

function LoadBMPWithPalette(const FileName: string; var Image: TImage;
                            var Palette: TPalette): Boolean;
var
  F: File;
  FileHeader: TBMPFileHeader;
  InfoHeader: TBMPInfoHeader;
  BytesRead: Word;
  Image_size: LongInt;
  Width, Height: Word;
  ImageBuffer: PByteArray;
  Y, X: Word;
  RowSize: LongInt;
  Padding: Word;
  i: Integer;
  RGBQuad: TBMPRGBQuad;
  ScanLine: array[0..319] of Byte;  { Max width we support }
  AbsHeight: LongInt;
  BottomUp: Boolean;
begin
  LoadBMPWithPalette := False;
  LoadBMPError := '';

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
  begin
    LoadBMPError := 'File not found or cannot open: ' + FileName;
    Exit;
  end;

  { Read 14-byte file header }
  BlockRead(F, FileHeader, SizeOf(TBMPFileHeader), BytesRead);
  if BytesRead <> SizeOf(TBMPFileHeader) then
  begin
    LoadBMPError := 'Error reading BMP file header';
    Close(F);
    Exit;
  end;

  { Verify BMP signature 'BM' }
  if FileHeader.Signature <> $4D42 then
  begin
    LoadBMPError := 'Invalid BMP signature (not a valid BMP file)';
    Close(F);
    Exit;
  end;

  { Read 40-byte info header }
  BlockRead(F, InfoHeader, SizeOf(TBMPInfoHeader), BytesRead);
  if BytesRead <> SizeOf(TBMPInfoHeader) then
  begin
    LoadBMPError := 'Error reading BMP info header';
    Close(F);
    Exit;
  end;

  { Verify header size (should be 40 for BITMAPINFOHEADER) }
  if InfoHeader.Size <> 40 then
  begin
    LoadBMPError := 'Unsupported BMP header size (requires BITMAPINFOHEADER)';
    Close(F);
    Exit;
  end;

  { Verify 8-bit format }
  if InfoHeader.BitCount <> 8 then
  begin
    LoadBMPError := 'Unsupported BMP format (requires 8-bit/256-color)';
    Close(F);
    Exit;
  end;

  { Verify uncompressed }
  if InfoHeader.Compression <> 0 then
  begin
    LoadBMPError := 'Unsupported BMP compression (requires uncompressed BI_RGB)';
    Close(F);
    Exit;
  end;

  { Check height (negative = top-down, positive = bottom-up) }
  if InfoHeader.Height < 0 then
  begin
    AbsHeight := -InfoHeader.Height;
    BottomUp := False;
  end
  else
  begin
    AbsHeight := InfoHeader.Height;
    BottomUp := True;
  end;

  { Calculate dimensions }
  Width := InfoHeader.Width;
  Height := AbsHeight;

  { Verify dimensions are valid }
  if (Width = 0) or (Height = 0) then
  begin
    LoadBMPError := 'Invalid image dimensions (width or height is 0)';
    Close(F);
    Exit;
  end;

  { Verify width is not too large }
  if Width > 320 then
  begin
    LoadBMPError := 'Image too wide (max 320 pixels)';
    Close(F);
    Exit;
  end;

  Image_size := LongInt(Width) * LongInt(Height);
  if Image_size > 65520 then  { Maximum GetMem block size in real mode }
  begin
    LoadBMPError := 'Image too large: ' + IntToStr(Width) + 'x' +
                        IntToStr(Height) + ' (' + IntToStr(Image_size) +
                        ' bytes, max 65520)';
    Close(F);
    Exit;
  end;

  { Read 256-color palette (256 RGBQUADs = 1024 bytes) }
  for i := 0 to 255 do
  begin
    BlockRead(F, RGBQuad, SizeOf(TBMPRGBQuad), BytesRead);
    if BytesRead <> SizeOf(TBMPRGBQuad) then
    begin
      LoadBMPError := 'Error reading BMP palette';
      Close(F);
      Exit;
    end;
    { Convert 0-255 to VGA 0-63 range }
    Palette[i].R := RGBQuad.Red shr 2;
    Palette[i].G := RGBQuad.Green shr 2;
    Palette[i].B := RGBQuad.Blue shr 2;
  end;

  { Set image dimensions and allocate memory }
  Image.Width := Width;
  Image.Height := Height;
  GetMem(Image.Data, Image_size);
  ImageBuffer := Image.Data;

  { Seek to pixel data }
  Seek(F, FileHeader.DataOffset);

  { BMP rows are padded to 4-byte boundaries }
  RowSize := Width;
  Padding := (4 - (RowSize mod 4)) mod 4;

  { Read pixel data }
  { BMP stores pixels bottom-up by default (unless height is negative) }
  for Y := 0 to Height - 1 do
  begin
    { Read scanline }
    BlockRead(F, ScanLine, Width, BytesRead);
    if BytesRead <> Width then
    begin
      LoadBMPError := 'Unexpected end of file while reading pixel data';
      FreeMem(Image.Data, Image_size);
      Image.Data := nil;
      Close(F);
      Exit;
    end;

    { Skip padding bytes }
    if Padding > 0 then
    begin
      Seek(F, FilePos(F) + Padding);
    end;

    { Copy scanline to image buffer }
    if BottomUp then
    begin
      { Bottom-up: reverse Y coordinate }
      for X := 0 to Width - 1 do
        ImageBuffer^[(Height - 1 - Y) * Width + X] := ScanLine[X];
    end
    else
    begin
      { Top-down: normal Y coordinate }
      for X := 0 to Width - 1 do
        ImageBuffer^[Y * Width + X] := ScanLine[X];
    end;
  end;

  Close(F);
  LoadBMPWithPalette := True;
end;

function LoadBMP(const FileName: string; var Image: TImage): Boolean;
var
  DummyPalette: TPalette;
begin
  LoadBMP := LoadBMPWithPalette(FileName, Image, DummyPalette);
end;

function SaveBMP(const FileName: string; const Image: TImage; const Palette: TPalette): Boolean;
var
  F: File;
  FileHeader: TBMPFileHeader;
  InfoHeader: TBMPInfoHeader;
  BytesWritten: Word;
  Width, Height: Word;
  RowSize: LongInt;
  Padding: Word;
  Y, X: Word;
  RGBQuad: TBMPRGBQuad;
  i: Integer;
  ScanLine: array[0..319] of Byte;
  PadByte: Byte;
  ImageBuffer: PByteArray;

  procedure WriteBytes(var Buf; Count: Word; var Ok: Boolean);
  begin
    if not Ok then Exit;
    BlockWrite(F, Buf, Count, BytesWritten);
    if BytesWritten <> Count then
    begin
      SaveBMPError := 'Error writing BMP file.';
      Ok := False;
    end;
  end;

var
  Ok: Boolean;
begin
  SaveBMP := False;
  SaveBMPError := '';

  Width := Image.Width;
  Height := Image.Height;

  if (Width = 0) or (Height = 0) then
  begin
    SaveBMPError := 'Cannot save BMP: image width or height is 0.';
    Exit;
  end;

  if Width > 320 then
  begin
    SaveBMPError := 'Cannot save BMP: image width exceeds 320 pixels.';
    Exit;
  end;

  if Image.Data = nil then
  begin
    SaveBMPError := 'Cannot save BMP: image data is nil.';
    Exit;
  end;

  ImageBuffer := Image.Data;

  { Calculate row size with padding to 4-byte boundary }
  RowSize := Width;
  Padding := (4 - (RowSize mod 4)) mod 4;

  { Fill file header }
  FillChar(FileHeader, SizeOf(FileHeader), 0);
  FileHeader.Signature := $4D42;  { 'BM' }
  FileHeader.DataOffset := SizeOf(TBMPFileHeader) + SizeOf(TBMPInfoHeader) + 1024;  { 14 + 40 + 1024 palette }
  FileHeader.FileSize := FileHeader.DataOffset + LongInt(Height) * (RowSize + Padding);

  { Fill info header }
  FillChar(InfoHeader, SizeOf(InfoHeader), 0);
  InfoHeader.Size := 40;
  InfoHeader.Width := Width;
  InfoHeader.Height := Height;  { Positive = bottom-up }
  InfoHeader.Planes := 1;
  InfoHeader.BitCount := 8;
  InfoHeader.Compression := 0;  { BI_RGB = uncompressed }
  InfoHeader.ImageSize := 0;    { Can be 0 for uncompressed }
  InfoHeader.XPelsPerMeter := 0;
  InfoHeader.YPelsPerMeter := 0;
  InfoHeader.ColorsUsed := 256;
  InfoHeader.ColorsImportant := 0;

  { Create file }
  Assign(F, FileName);
  {$I-}
  Rewrite(F, 1);
  {$I+}
  if IOResult <> 0 then
  begin
    SaveBMPError := 'Cannot create BMP file: ' + FileName;
    Exit;
  end;

  Ok := True;

  { Write file header }
  WriteBytes(FileHeader, SizeOf(FileHeader), Ok);
  if not Ok then
  begin
    Close(F);
    Exit;
  end;

  { Write info header }
  WriteBytes(InfoHeader, SizeOf(InfoHeader), Ok);
  if not Ok then
  begin
    Close(F);
    Exit;
  end;

  { Write palette (256 RGBQUADs) }
  for i := 0 to 255 do
  begin
    { Convert VGA 0-63 to 0-255 range }
    RGBQuad.Blue := Palette[i].B shl 2;
    RGBQuad.Green := Palette[i].G shl 2;
    RGBQuad.Red := Palette[i].R shl 2;
    RGBQuad.Reserved := 0;
    WriteBytes(RGBQuad, SizeOf(RGBQuad), Ok);
    if not Ok then
    begin
      Close(F);
      Exit;
    end;
  end;

  { Write pixel data (bottom-up) }
  PadByte := 0;
  for Y := 0 to Height - 1 do
  begin
    { Build scanline (reversed Y for bottom-up) }
    for X := 0 to Width - 1 do
      ScanLine[X] := ImageBuffer^[(Height - 1 - Y) * Width + X];

    { Write scanline }
    WriteBytes(ScanLine, Width, Ok);
    if not Ok then
    begin
      Close(F);
      Exit;
    end;

    { Write padding bytes }
    for i := 1 to Padding do
    begin
      WriteBytes(PadByte, 1, Ok);
      if not Ok then
      begin
        Close(F);
        Exit;
      end;
    end;
  end;

  Close(F);
  SaveBMP := True;
end;

end.
