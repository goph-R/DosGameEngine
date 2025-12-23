{ VGAFONT.PAS - Variable-Width Font System }
{ Sprite sheet-based variable-width font renderer for VGA Mode 13h }

unit VGAFont;

interface

uses VGA, GenTypes, PCX, MiniXML, StrUtil;

const
  MaxChars = 128;  { ASCII 0-127 }

type
  TCharInfo = record
    X: Integer;        { X position in sprite sheet }
    Y: Integer;        { Y position in sprite sheet }
    Width: Byte;       { Character width in pixels }
    Defined: Boolean;  { True if character exists in font }
  end;

  TFont = record
    Image: TImage;                            { Font sprite sheet }
    Height: Byte;                             { Height of all characters }
    Padding: Byte;                            { Right padding of all characters }
    ReplaceColor: Byte;                       { Color to replace (0 = no replacement) }
    Chars: array[0..MaxChars-1] of TCharInfo; { Character metadata }
    Loaded: Boolean;                          { True if font successfully loaded }
  end;
  PFont = ^TFont;

{ Load font from PCX image and XML metadata }
function LoadFont(const XMLFile: string; var Font: TFont): Boolean;

{ Get last error message from LoadFont }
function GetLoadFontError: string;

{ Free font resources }
procedure FreeFont(var Font: TFont);

{ Render text using loaded font }
procedure PrintFontText(
  X, Y: Integer;
  const Text: string;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);

{ Calculate text width in pixels }
function GetTextWidth(const Text: string; var Font: TFont): Integer;

{ Draw centered text }
procedure PrintFontTextCentered(
  X, Y: Integer;
  const Text: string;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);

{ Draw right-aligned text }
procedure PrintFontTextRight(
  X, Y: Integer;
  const Text: string;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);

{ Render colored text using loaded font (replaces ReplaceColor with Color) }
procedure PrintFontTextColored(
  X, Y: Integer;
  const Text: string;
  Color: Byte;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);

{ Draw centered colored text }
procedure PrintFontTextCenteredColored(
  X, Y: Integer;
  const Text: string;
  Color: Byte;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);

{ Draw right-aligned colored text }
procedure PrintFontTextRightColored(
  X, Y: Integer;
  const Text: string;
  Color: Byte;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);

implementation

var
  LastError: string;  { Global error message storage }

{ Set error message }
procedure SetError(const Msg: string);
begin
  LastError := Msg;
end;

{ Get last error message }
function GetLoadFontError: string;
begin
  GetLoadFontError := LastError;
end;

{ Load font from PCX image and XML metadata }
function LoadFont(const XMLFile: string;var Font: TFont): Boolean;
var
  FontNode, CharNode: PXMLNode;
  HeightStr, PaddingStr, ReplaceColorStr, CodeStr, XStr, YStr, WidthStr: string;
  Height, Padding, ReplaceColor, Code, X, Y, Width: Integer;
  i: Integer;
  ImageFile: string;
begin
  LoadFont := False;

  { Initialize font structure }
  for i := 0 to MaxChars - 1 do
  begin
    Font.Chars[i].X := 0;
    Font.Chars[i].Y := 0;
    Font.Chars[i].Width := 0;
    Font.Chars[i].Defined := False;
  end;
  Font.Loaded := False;
  Font.Height := 0;
  Font.Padding := 0;
  Font.ReplaceColor := 0;

  { Load XML }
  if not XMLLoadFile(XMLFile, FontNode) then
  begin
    SetError('XML file could not be loaded: ' + XMLFile);
    Exit;
  end;

  { Read height attribute }
  HeightStr := XMLAttr(FontNode, 'height');
  if HeightStr = '' then
  begin
    SetError('Missing height attribute in <font> element');
    XMLFreeTree(FontNode);
    Exit;
  end;

  Height := StrToInt(HeightStr);
  if (Height <= 0) or (Height > 255) then
  begin
    SetError('Invalid height: ' + HeightStr);
    XMLFreeTree(FontNode);
    Exit;
  end;

  Font.Height := Height;

  { Read padding attribute (default to 0 if not specified) }
  Padding := 0;  { Initialize to default value }
  PaddingStr := XMLAttr(FontNode, 'padding');
  if PaddingStr <> '' then
  begin
    Padding := StrToInt(PaddingStr);
    if (Padding < 0) or (Padding > 255) then
    begin
      SetError('Invalid padding: ' + PaddingStr + ' (must be 0-255)');
      XMLFreeTree(FontNode);
      Exit;
    end;
  end;

  Font.Padding := Padding;

  { Read replace-color attribute (default to 0 if not specified) }
  ReplaceColorStr := XMLAttr(FontNode, 'replace-color');
  if ReplaceColorStr <> '' then
  begin
    ReplaceColor := StrToInt(ReplaceColorStr);
    if (ReplaceColor < 0) or (ReplaceColor > 255) then
    begin
      SetError('Invalid replace-color: ' + ReplaceColorStr + ' (must be 0-255)');
      XMLFreeTree(FontNode);
      Exit;
    end;
    Font.ReplaceColor := ReplaceColor;
  end;

  { Parse each <char> element }
  CharNode := FontNode^.FirstChild;
  while CharNode <> nil do
  begin
    if CharNode^.Name = 'char' then
    begin
      { Read attributes }
      CodeStr := XMLAttr(CharNode, 'code');
      XStr := XMLAttr(CharNode, 'x');
      YStr := XMLAttr(CharNode, 'y');
      WidthStr := XMLAttr(CharNode, 'width');

      { Validate required attributes }
      if (CodeStr = '') or (XStr = '') or (YStr = '') or (WidthStr = '') then
      begin
        SetError('Missing required attribute in <char> element');
        XMLFreeTree(FontNode);
        Exit;
      end;

      { Parse values }
      Code := StrToInt(CodeStr);
      X := StrToInt(XStr);
      Y := StrToInt(YStr);
      Width := StrToInt(WidthStr);

      { Validate ranges }
      if (Code < 0) or (Code > 127) then
      begin
        SetError('Invalid character code: ' + CodeStr + ' (must be 0-127)');
        XMLFreeTree(FontNode);
        Exit;
      end;

      if (Width < 0) or (Width > 255) then
      begin
        SetError('Invalid width: ' + WidthStr + ' (must be 0-255)');
        XMLFreeTree(FontNode);
        Exit;
      end;

      { Store character info }
      Font.Chars[Code].X := X;
      Font.Chars[Code].Y := Y;
      Font.Chars[Code].Width := Width;
      Font.Chars[Code].Defined := True;
    end;

    CharNode := CharNode^.NextSibling;
  end;

  { Get image path from 'image' attribute (relative to XML file) }
  ImageFile := XMLAttr(FontNode, 'image');
  if ImageFile = '' then
  begin
    SetError('Missing required image attribute in <font> element');
    XMLFreeTree(FontNode);
    Exit;
  end;

  { Make path relative to XML file's directory }
  { Find last backslash in XMLFile path }
  i := Length(XMLFile);
  while (i > 0) and (XMLFile[i] <> '\') do
    Dec(i);

  if i > 0 then
    ImageFile := Copy(XMLFile, 1, i) + ImageFile;

  { Cleanup }
  XMLFreeTree(FontNode);

  { Load image }
  if not LoadPCX(ImageFile, Font.Image) then
  begin
    SetError(GetLoadPCXError);
    Exit;
  end;

  Font.Loaded := True;
  LoadFont := True;
end;

{ Free font resources }
procedure FreeFont(var Font: TFont);
var
  i: Integer;
begin
  if not Font.Loaded then
    Exit;

  FreeImage(Font.Image);

  { Clear character metadata }
  for i := 0 to MaxChars - 1 do
  begin
    Font.Chars[i].X := 0;
    Font.Chars[i].Y := 0;
    Font.Chars[i].Width := 0;
    Font.Chars[i].Defined := False;
  end;

  Font.Height := 0;
  Font.ReplaceColor := 0;
  Font.Loaded := False;
end;

{ Render text using loaded font }
procedure PrintFontText(
  X, Y: Integer;
  const Text: string;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);
var
  i: Integer;
  CharCode: Byte;
  CharInfo: TCharInfo;
  SourceRect: TRectangle;
  CursorX: Integer;
begin
  if not Font.Loaded then Exit;

  CursorX := X;

  for i := 1 to Length(Text) do
  begin
    CharCode := Ord(Text[i]);

    { Skip extended ASCII }
    if CharCode > 127 then Continue;

    CharInfo := Font.Chars[CharCode];

    { Skip undefined characters }
    if not CharInfo.Defined then Continue;

    { Setup source rectangle }
    SourceRect.X := CharInfo.X;
    SourceRect.Y := CharInfo.Y;
    SourceRect.Width := CharInfo.Width;
    SourceRect.Height := Font.Height;

    { Draw character }
    PutImageRect(
      Font.Image,      { Source sprite sheet }
      SourceRect,      { Source rectangle }
      CursorX, Y,      { Destination position }
      True,            { Transparent (color 0) }
      FrameBuffer      { Target buffer }
    );

    { Advance cursor }
    CursorX := CursorX + CharInfo.Width + Font.Padding;
  end;
end;

{ Calculate text width in pixels }
function GetTextWidth(const Text: string; var Font: TFont): Integer;
var
  i, Width: Integer;
  CharCode: Byte;
begin
  Width := 0;
  for i := 1 to Length(Text) do
  begin
    CharCode := Ord(Text[i]);
    if (CharCode <= 127) and Font.Chars[CharCode].Defined then
      Width := Width + Font.Chars[CharCode].Width + Font.Padding;
  end;
  GetTextWidth := Width;
end;

{ Draw centered text }
procedure PrintFontTextCentered(
  X, Y: Integer;
  const Text: string;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);
var
  TextWidth: Integer;
begin
  TextWidth := GetTextWidth(Text, Font);
  PrintFontText(X - (TextWidth div 2), Y, Text, Font, FrameBuffer);
end;

{ Draw right-aligned text }
procedure PrintFontTextRight(
  X, Y: Integer;
  const Text: string;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);
var
  TextWidth: Integer;
begin
  TextWidth := GetTextWidth(Text, Font);
  PrintFontText(X - TextWidth, Y, Text, Font, FrameBuffer);
end;

{ Internal: Render single character with color replacement }
procedure RenderCharColored(
  var Font: TFont;
  const CharInfo: TCharInfo;
  X, Y: Integer;
  Color: Byte;
  FrameBuffer: PFrameBuffer
);
var
  SrcX, SrcY: Integer;
  DestX, DestY: Integer;
  PixelColor: Byte;
  SrcOffset, DestOffset: Word;
  ImageData: PByteArray;
begin
  { Early exit if ReplaceColor is 0 (no replacement) }
  if Font.ReplaceColor = 0 then
  begin
    { Use the fast non-colored rendering }
    Exit;
  end;

  ImageData := PByteArray(Font.Image.Data);

  { Loop through each pixel in the character }
  for SrcY := 0 to Font.Height - 1 do
  begin
    for SrcX := 0 to CharInfo.Width - 1 do
    begin
      DestX := X + SrcX;
      DestY := Y + SrcY;

      { Clip check }
      if (DestX < 0) or (DestX >= 320) or (DestY < 0) or (DestY >= 200) then
        Continue;

      { Calculate source pixel offset }
      SrcOffset := Word(CharInfo.Y + SrcY) * Font.Image.Width + Word(CharInfo.X + SrcX);
      PixelColor := ImageData^[SrcOffset];

      { Skip transparent pixels (color 0) }
      if PixelColor = 0 then
        Continue;

      { Replace if matches ReplaceColor }
      if PixelColor = Font.ReplaceColor then
        PixelColor := Color;

      { Draw pixel to framebuffer }
      DestOffset := Word(DestY) * 320 + Word(DestX);
      FrameBuffer^[DestOffset] := PixelColor;
    end;
  end;
end;

{ Render colored text using loaded font }
procedure PrintFontTextColored(
  X, Y: Integer;
  const Text: string;
  Color: Byte;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);
var
  i: Integer;
  CharCode: Byte;
  CharInfo: TCharInfo;
  SourceRect: TRectangle;
  CursorX: Integer;
begin
  if not Font.Loaded then Exit;

  { If ReplaceColor is 0, use normal non-colored rendering }
  if Font.ReplaceColor = 0 then
  begin
    PrintFontText(X, Y, Text, Font, FrameBuffer);
    Exit;
  end;

  CursorX := X;

  for i := 1 to Length(Text) do
  begin
    CharCode := Ord(Text[i]);

    { Skip extended ASCII }
    if CharCode > 127 then Continue;

    CharInfo := Font.Chars[CharCode];

    { Skip undefined characters }
    if not CharInfo.Defined then Continue;

    { Render character with color replacement }
    RenderCharColored(Font, CharInfo, CursorX, Y, Color, FrameBuffer);

    { Advance cursor }
    CursorX := CursorX + CharInfo.Width + Font.Padding;
  end;
end;

{ Draw centered colored text }
procedure PrintFontTextCenteredColored(
  X, Y: Integer;
  const Text: string;
  Color: Byte;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);
var
  TextWidth: Integer;
begin
  TextWidth := GetTextWidth(Text, Font);
  PrintFontTextColored(X - (TextWidth div 2), Y, Text, Color, Font, FrameBuffer);
end;

{ Draw right-aligned colored text }
procedure PrintFontTextRightColored(
  X, Y: Integer;
  const Text: string;
  Color: Byte;
  var Font: TFont;
  FrameBuffer: PFrameBuffer
);
var
  TextWidth: Integer;
begin
  TextWidth := GetTextWidth(Text, Font);
  PrintFontTextColored(X - TextWidth, Y, Text, Color, Font, FrameBuffer);
end;

end.
