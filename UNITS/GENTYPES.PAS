unit GenTypes;

{ Generic type definitions for common pointer and array types }
{ Used across multiple units to avoid duplication }

interface

type
  { Generic pointer types }
  PByte = ^Byte;
  PWord = ^Word;
  PShortString = ^string;

  { Generic large array types for pointer-based access }
  TByteArray = array[0..65520] of Byte;  { Max size for pointer access }
  PByteArray = ^TByteArray;

  TWordArray = array[0..32000] of Word;  { Max size: 32000 * 2 = 64000 bytes }
  PWordArray = ^TWordArray;

implementation

end.
