# STRUTIL - String Utilities

String conversion and manipulation functions.

## Functions

```pascal
function StrToInt(const S: string): LongInt;
function StrToReal(const S: string): Real;
function IntToStr(Value: LongInt): string;
function Trim(const S: string): string;
function HexStr(Value: Word; Digits: Byte): string;
function HexStrToWord(const S: string): Word;
```

## Examples

```pascal
uses StrUtil;

var
  I: LongInt;
  R: Real;
  S: string;
begin
  I := StrToInt('1234');           { 1234 }
  R := StrToReal('3.14');          { 3.14 }
  S := IntToStr(42);               { '42' }
  S := Trim('  hello  ');          { 'hello' }
  S := HexStr($A5, 2);             { 'A5' }
  I := HexStrToWord('FF00');       { 65280 }
end;
```

## Notes

- `StrToInt`/`StrToReal` return 0 on invalid input
- `HexStr` pads with zeros to specified digit count
- `HexStrToWord` supports uppercase/lowercase hex digits
