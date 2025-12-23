# RTCTIMER - RTC High-Resolution Timer

Real-Time Clock (IRQ8) timer for delta-time game loops. No conflict with HSC (IRQ0).

## Constants

```pascal
const
  CMOS_PORT = $70;
  CMOS_DATA = $71;
  PIC1_OCW1 = $21;
  PIC2_OCW1 = $A1;
```

## Globals

```pascal
var
  RTC_Ticks: LongInt;      { Tick counter }
  RTC_Freq_Hz: Word;       { Current frequency }
  OldInt70: Pointer;       { Original IRQ8 handler }
```

## Functions

```pascal
procedure InitRTC(Freq: Word);               { Freq: 2-8192 Hz (power of 2) }
procedure DoneRTC;
function GetTimeSeconds: Real;               { Current time in seconds }
```

## Example (Delta-Time Game Loop)

```pascal
uses RTCTimer, VGA, Sprite;

var
  LastTime, CurrentTime, DeltaTime: Real;
  Player: TSpriteInstance;
begin
  InitRTC(1024);                             { 1024 Hz = ~1ms precision }
  InitVGA;

  LastTime := GetTimeSeconds;
  while Running do
  begin
    CurrentTime := GetTimeSeconds;
    DeltaTime := CurrentTime - LastTime;     { Time in seconds }
    LastTime := CurrentTime;

    UpdateSprite(Player, DeltaTime);         { Animate sprite }
    DrawSprite(@Player, GetScreenBuffer);

    { Cap at 60 FPS }
    while GetTimeSeconds - CurrentTime < 0.0166 do;
  end;

  DoneVGA;
  DoneRTC;                                   { CRITICAL: Restore IRQ8 }
end;
```

## Frequency Values

| Freq (Hz) | Precision | Use Case              |
|----------:|----------:|-----------------------|
|         2 |    500 ms | Low-precision timers  |
|        64 |  ~15.6 ms | 60 FPS cap (~16ms)    |
|       256 |   ~3.9 ms | General game loops    |
|      1024 |   ~0.98 ms| High-precision timing |
|      8192 |   ~0.12 ms| Benchmark/profiling   |

## Critical Notes

1. **Call DoneRTC**: MUST call before exit or system hangs
2. **IRQ8 Isolation**: No conflict with HSC (IRQ0) - use for delta-time with music
3. **IRQ2 Never Mask**: IRQ2 is PIC cascade - masking disables all IRQ8-15 (mouse, RTC, etc.)
4. **ExitProc**: Install handler to call `DoneRTC` on Ctrl+C

## Comparison: RTC vs PIT

| Feature           | PIT Timer 0 (IRQ0) | RTC (IRQ8)        |
|-------------------|--------------------|-------------------|
| **Frequency**     | 18.2 Hz (fixed)    | 2-8192 Hz         |
| **HSC Conflict**  | ❌ YES              | ✅ NO              |
| **Precision**     | ~55ms              | <1ms at 1024 Hz   |
| **Use Case**      | System tick        | Game delta-time   |

## Notes

- RTC uses CMOS registers (ports $70/$71)
- IRQ8 on slave PIC (IRQ15-8)
- GetTimeSeconds returns `RTC_Ticks / RTC_Freq_Hz`
- DeltaTime convention: Use Real type, seconds (not milliseconds)
