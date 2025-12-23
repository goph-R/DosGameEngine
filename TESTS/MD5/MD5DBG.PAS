{ MD5DBG.PAS - Debug MD5 to find where divergence happens }

program MD5Debug;

uses MD5;

procedure TestSingleRound;
var
  a, b, c, d: LongInt;
  x: LongInt;
  t: LongInt;
  result: LongInt;
begin
  WriteLn('Testing single MD5 round operation');
  WriteLn('===================================');
  WriteLn;

  { Test the first round operation from MD5 }
  { a := b + ROL(a + F(b, c, d) + x[0] + T[0], 7); }

  { Use initial MD5 state }
  a := LongInt($67452301);
  b := LongInt($efcdab89);
  c := LongInt($98badcfe);
  d := LongInt($10325476);
  x := $61;  { 'a' as first byte, rest zeros }
  t := LongInt($d76aa478);  { T[0] }

  WriteLn('Initial values:');
  WriteLn('a = $67452301');
  WriteLn('b = $efcdab89');
  WriteLn('c = $98badcfe');
  WriteLn('d = $10325476');
  WriteLn('x[0] = $00000061');
  WriteLn('T[0] = $d76aa478');
  WriteLn;

  { This should match what happens in the actual MD5 }
  result := MD5String('a');
  WriteLn('MD5("a") = ', result);
  WriteLn('Expected = 0cc175b9c0f1b6a831c399e269772661');
  WriteLn;
end;

begin
  TestSingleRound;
end.
