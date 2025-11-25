unit PCXLoad;

interface

uses VGA, GenTypes;

type
  TPCXHeader = record
    Manufacturer: Byte;      { Always 10 for PCX }
    Version: Byte;           { 5 = 256-color }
    Encoding: Byte;          { 1 = RLE }
    BitsPerPixel: Byte;      { 8 for 256-color }
    XMin: Word;
    YMin: Word;
    XMax: Word;
    YMax: Word;
    HDpi: Word;
    VDpi: Word;
    ColorMap: array[0..47] of Byte;  { EGA palette (not used for 256-color) }
    Reserved: Byte;
    NPlanes: Byte;           { 1 for 256-color }
    BytesPerLine: Word;      { Bytes per scanline (may be padded) }
    PaletteInfo: Word;       { 1 = color }
    HScreenSize: Word;
    VScreenSize: Word;
    Filler: array[0..53] of Byte;  { Reserved, total header = 128 bytes }
  end;

function LoadPCX(const FileName: string; var Image: TImage): Boolean;
function LoadPCXWithPalette(const FileName: string; var Image: TImage;
                            var Palette: TPalette): Boolean;
function GetLastErrorMessage: string;

implementation

uses StrUtil;

var
  LastErrorMessage: string;

function GetLastErrorMessage: string;
begin
  GetLastErrorMessage := LastErrorMessage;
end;

function LoadPCXWithPalette(const FileName: string; var Image: TImage;
                            var Palette: TPalette): Boolean;
var
  F: File;
  Header: TPCXHeader;
  BytesRead: Word;
  Image_size: LongInt;
  Width, Height: Word;
  Pixels_counter: LongInt;
  Byte_read: Byte;
  RunLength: Byte;
  Color: Byte;
  ImageBuffer: PByteArray;
  Y, X: Word;
  ScanlinePos: Word;
  PalMarker: Byte;
  i: Integer;
  TempByte: Byte;
begin
  LoadPCXWithPalette := False;
  LastErrorMessage := '';

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
    LastErrorMessage := 'File not found or cannot open: ' + FileName;
    Exit;
  end;

  { Read 128-byte header }
  BlockRead(F, Header, SizeOf(TPCXHeader), BytesRead);
  if BytesRead <> SizeOf(TPCXHeader) then
  begin
    LastErrorMessage := 'Error reading PCX header';
    Close(F);
    Exit;
  end;

  { Verify PCX signature }
  if Header.Manufacturer <> 10 then
  begin
    LastErrorMessage := 'Invalid PCX signature (not a valid PCX file)';
    Close(F);
    Exit;
  end;

  { Verify 256-color format }
  if (Header.Version <> 5) or (Header.BitsPerPixel <> 8) or (Header.NPlanes <> 1) then
  begin
    LastErrorMessage := 'Unsupported PCX format (requires 256-color, 8-bit, 1 plane)';
    Close(F);
    Exit;
  end;

  { Verify RLE encoding }
  if Header.Encoding <> 1 then
  begin
    LastErrorMessage := 'Unsupported PCX encoding (requires RLE)';
    Close(F);
    Exit;
  end;

  { Calculate dimensions }
  Width := Header.XMax - Header.XMin + 1;
  Height := Header.YMax - Header.YMin + 1;

  { Verify dimensions are valid }
  if (Width = 0) or (Height = 0) then
  begin
    LastErrorMessage := 'Invalid image dimensions (width or height is 0)';
    Close(F);
    Exit;
  end;

  Image_size := LongInt(Width) * LongInt(Height);
  if Image_size > 65520 then  { Maximum GetMem block size in real mode }
  begin
    LastErrorMessage := 'Image too large: ' + IntToStr(Width) + 'x' +
                        IntToStr(Height) + ' (' + IntToStr(Image_size) +
                        ' bytes, max 65520)';
    Close(F);
    Exit;
  end;

  { Set image dimensions and allocate memory }
  Image.Width := Width;
  Image.Height := Height;
  GetMem(Image.Data, Image_size);
  ImageBuffer := Image.Data;

  { Decode RLE pixel data }
  Pixels_counter := 0;
  Y := 0;
  while Y < Height do
  begin
    ScanlinePos := 0;
    while ScanlinePos < Header.BytesPerLine do
    begin
      { Read byte }
      BlockRead(F, Byte_read, 1, BytesRead);
      if BytesRead <> 1 then
      begin
        LastErrorMessage := 'Unexpected end of file while reading pixel data';
        FreeMem(Image.Data, Image_size);
        Image.Data := nil;
        Close(F);
        Exit;
      end;

      { Check if this is a run-length encoded byte }
      if (Byte_read and $C0) = $C0 then
      begin
        { This is a run: lower 6 bits = count }
        RunLength := Byte_read and $3F;

        { Read the color value }
        BlockRead(F, Color, 1, BytesRead);
        if BytesRead <> 1 then
        begin
          LastErrorMessage := 'Unexpected end of file while reading RLE color';
          FreeMem(Image.Data, Image_size);
          Image.Data := nil;
          Close(F);
          Exit;
        end;

        { Write the color RunLength times }
        for i := 1 to RunLength do
        begin
          if ScanlinePos < Width then
          begin
            ImageBuffer^[Pixels_counter] := Color;
            Inc(Pixels_counter);
          end;
          Inc(ScanlinePos);
        end;
      end
      else
      begin
        { This is a literal pixel value }
        if ScanlinePos < Width then
        begin
          ImageBuffer^[Pixels_counter] := Byte_read;
          Inc(Pixels_counter);
        end;
        Inc(ScanlinePos);
      end;
    end;

    Inc(Y);
  end;

  { Read 256-color palette from end of file }
  { Palette is at EOF-768 bytes, preceded by marker byte 0x0C }

  { Seek to palette marker (EOF - 769 bytes) }
  Seek(F, FileSize(F) - 769);

  { Read palette marker }
  BlockRead(F, PalMarker, 1, BytesRead);
  if (BytesRead <> 1) or (PalMarker <> $0C) then
  begin
    LastErrorMessage := 'Warning: No 256-color palette found (marker not 0x0C)';
    { Don't fail - some PCX files may not have palette }
    { Initialize with default grayscale palette }
    for i := 0 to 255 do
    begin
      Palette[i].R := i shr 2;  { Divide by 4 for VGA 0-63 range }
      Palette[i].G := i shr 2;
      Palette[i].B := i shr 2;
    end;
  end
  else
  begin
    { Read 768-byte palette (256 RGB triplets, values 0-255) }
    for i := 0 to 255 do
    begin
      BlockRead(F, TempByte, 1, BytesRead);
      Palette[i].R := TempByte shr 2;  { Convert 0-255 to VGA 0-63 range }

      BlockRead(F, TempByte, 1, BytesRead);
      Palette[i].G := TempByte shr 2;

      BlockRead(F, TempByte, 1, BytesRead);
      Palette[i].B := TempByte shr 2;
    end;
  end;

  Close(F);

  if Pixels_counter <> Image_size then
  begin
    LastErrorMessage := 'Warning: Decoded ' + IntToStr(Pixels_counter) +
                        ' pixels, expected ' + IntToStr(Image_size);
    { Don't fail - we got most of the image }
  end;

  LoadPCXWithPalette := True;
end;

function LoadPCX(const FileName: string; var Image: TImage): Boolean;
var
  DummyPalette: TPalette;
begin
  LoadPCX := LoadPCXWithPalette(FileName, Image, DummyPalette);
end;

end.
