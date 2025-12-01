unit StrUtil;

interface

{ Helper: Convert string to integer }
function StrToInt(const S: string): Integer;

{ Helper: Convert string to real }
function StrToReal(const S: string): Real;

{ Helper: Convert integer to string }
function IntToStr(Value: Integer): string;

{ Helper: Trim leading/trailing spaces }
function Trim(const S: string): string;

{ Converts a Word to a hexadecimal string }
function HexStr(Value: Word; Digits: Byte): string;

{ Converts a hexadecimal string to a Word }
function HexStrToWord(const S: string): Word;

implementation

{ Helper: Convert string to integer }
function StrToInt(const S: string): Integer;
var
  i, Code: Integer;
begin
  Val(S, i, Code);
  if Code <> 0 then
    StrToInt := 0
  else
    StrToInt := i;
end;

{ Helper: Convert string to real }
function StrToReal(const S: string): Real;
var
  r: Real;
  Code: Integer;
begin
  Val(S, r, Code);
  if Code <> 0 then
    StrToReal := 0.0
  else
    StrToReal := r;
end;

{ Helper: Convert integer to string }
function IntToStr(Value: Integer): string;
var
  S: string;
begin
  Str(Value, S);
  IntToStr := S;
end;

{ Helper: Trim leading/trailing spaces }
function Trim(const S: string): string;
var
  i, Start, Finish: Integer;
begin
  Start := 1;
  Finish := Length(S);

  { Find first non-space }
  while (Start <= Finish) and (S[Start] = ' ') do
    Inc(Start);

  { Find last non-space }
  while (Finish >= Start) and (S[Finish] = ' ') do
    Dec(Finish);

  if Start > Finish then
    Trim := ''
  else
    Trim := Copy(S, Start, Finish - Start + 1);
end;


function HexStr(Value: Word; Digits: Byte): string;
const
  HexChars: array[0..15] of Char = '0123456789ABCDEF';
var
  Result: string;
  i: Integer;
begin
  Result := '';
  for i := Digits - 1 downto 0 do
    Result := Result + HexChars[(Value shr (i * 4)) and $F];
  HexStr := Result;
end;

function HexStrToWord(const S: string): Word;
var
  Result: Word;
  i: Integer;
  Ch: Char;
  Digit: Byte;
begin
  Result := 0;

  for i := 1 to Length(S) do
  begin
    Ch := S[i];

    { Convert character to hex digit value }
    if (Ch >= '0') and (Ch <= '9') then
      Digit := Ord(Ch) - Ord('0')
    else if (Ch >= 'A') and (Ch <= 'F') then
      Digit := Ord(Ch) - Ord('A') + 10
    else if (Ch >= 'a') and (Ch <= 'f') then
      Digit := Ord(Ch) - Ord('a') + 10
    else
    begin
      { Invalid character - return 0 }
      HexStrToWord := 0;
      Exit;
    end;

    { Shift previous result left by 4 bits and add new digit }
    Result := (Result shl 4) or Digit;
  end;

  HexStrToWord := Result;
end;

end.