# ⏱️ Timing and Delta Time Design

This document explains timing strategies for frame-rate independent movement and sprite animations in the DOS Game Engine.

## ⚡ Performance Considerations

### CPU Performance (286/386 without FPU)

**Integer math vs. Real (floating-point) math:**
- **Integer operations**: ~1-10 CPU cycles
- **Real operations**: ~100-1000+ CPU cycles (software emulation!)

**Real numbers are 10-100x slower** on typical DOS hardware without a floating-point unit (FPU). Most users don't have a 387 math coprocessor, so Real math is emulated in software.

### Recommendation: Use Integer Math

For time-critical game logic (movement, physics, animations), **always use integer types** (Word, Integer, LongInt) instead of Real.

## 🕐 Time Units Comparison

### Microseconds (LongInt)
- **Precision**: 1 microsecond (0.000001 seconds)
- **Range**: 2,147,483,647 µs = ~35 minutes before overflow
- **Use case**: Too precise, overflows quickly - **not recommended for games**

### Milliseconds (LongInt)
- **Precision**: 1 millisecond (0.001 seconds)
- **Range**: 2,147,483,647 ms = ~24.8 days before overflow
- **Use case**: **RECOMMENDED** - perfect balance of precision and range

### Seconds (Real)
- **Precision**: Floating-point (very high)
- **Range**: Effectively unlimited
- **Use case**: Avoid for game logic - too slow on DOS hardware without FPU

### RTC Ticks (LongInt)
- **Precision**: Depends on RTC frequency (e.g., 1024 Hz = ~0.976ms per tick)
- **Range**: 2,147,483,647 ticks = varies by frequency
- **Use case**: Good for internal timing, but convert to milliseconds for calculations

## 📊 RTC_Ticks Explained

The `RTC_Ticks` variable in **RTCTIMER.PAS** is a **dimensionless tick counter**:

- Each tick = one RTC periodic interrupt
- The time unit depends on initialization frequency
- `GetTimeSeconds = RTC_Ticks / RTC_Freq_Hz`

**Common configurations:**
- **1024 Hz** (typical): Each tick = 1/1024 second ≈ **0.976 milliseconds**
- **512 Hz**: Each tick = 1/512 second ≈ **1.953 milliseconds**
- **2048 Hz**: Each tick = 1/2048 second ≈ **0.488 milliseconds**
- **8192 Hz** (maximum): Each tick = 1/8192 second ≈ **0.122 milliseconds**
- **2 Hz** (minimum): Each tick = **0.5 seconds**

The RTC base frequency is **32768 Hz**, divided by powers of 2:
```
Actual frequency = 32768 >> (RateSelect - 1)
```

## 🎯 Recommended Approach: Milliseconds

Use **LongInt with milliseconds** for frame-rate independent game logic.

### Basic Delta Time Pattern

```pascal
var
  CurrentTimeMS: LongInt;
  LastTimeMS: LongInt;
  DeltaTimeMS: Word;        { Frame time typically < 65535ms }

begin
  { Initialize }
  InitRTC(1024);            { 1024 Hz timer }
  LastTimeMS := 0;

  { Game loop }
  while Running do
  begin
    { Calculate delta time }
    CurrentTimeMS := Round(GetTimeSeconds * 1000);
    DeltaTimeMS := CurrentTimeMS - LastTimeMS;
    LastTimeMS := CurrentTimeMS;

    { Update game logic with DeltaTimeMS }
    UpdateGame(DeltaTimeMS);
    Render;
  end;

  DoneRTC;
end;
```

## 🏃 Frame-Rate Independent Movement

Store velocities as **pixels per second × 1000** to avoid Real math.

```pascal
type
  TSprite = record
    X, Y: Integer;              { Position in pixels }
    VelocityX: Integer;         { Pixels per second × 1000 }
    VelocityY: Integer;         { Pixels per second × 1000 }
  end;

procedure UpdateSprite(var Sprite: TSprite; DeltaTimeMS: Word);
begin
  { Movement calculation using integer math only }
  Sprite.X := Sprite.X + (Sprite.VelocityX * DeltaTimeMS) div 1000;
  Sprite.Y := Sprite.Y + (Sprite.VelocityY * DeltaTimeMS) div 1000;
end;

{ Example: Set sprite velocity to 50 pixels per second }
Sprite.VelocityX := 50 * 1000;  { = 50000 }
Sprite.VelocityY := 0;
```

**Why multiply by 1000?**
- Velocity: 50 pixels/second = 50000 (stored as integer)
- Movement in 16ms: `(50000 × 16) div 1000 = 800 div 1000 = 0` pixels (too small!)
- With × 1000 trick: `(50000 × 16) div 1000 = 800000 div 1000 = 800` pixels ❌ Still wrong!

**Correction: Store as pixels per 1000 seconds:**

```pascal
{ CORRECT: Store velocity as (pixels × 1000) per second }
Sprite.VelocityX := 50;  { 50 pixels per second }

{ Movement calculation }
Sprite.X := Sprite.X + (Sprite.VelocityX * DeltaTimeMS) div 1000;

{ At 60 FPS (DeltaTimeMS ≈ 16): }
{ Movement = (50 × 16) div 1000 = 800 div 1000 = 0 pixels }

{ Better: Use higher precision }
Sprite.VelocityX := 50 * 256;  { Fixed-point: 256 = 1.0 }

{ Movement with 8-bit fixed-point }
Sprite.X := Sprite.X + ((Sprite.VelocityX * DeltaTimeMS) div 1000) div 256;
```

**Even better: Fixed-point math (8.8 or 16.16 format)** - see FIXED-POINT.md

## 🎬 Sprite Animation

### Method 1: Delta-Time Based (Frame-Rate Independent)

Use a timer that accumulates milliseconds until the next frame should display.

```pascal
type
  TAnimatedSprite = record
    CurrentFrame: Byte;
    MaxFrames: Byte;
    FrameDurationMS: Word;      { Milliseconds per frame }
    AnimationTimerMS: Word;     { Accumulator }
  end;

procedure UpdateAnimation(var Sprite: TAnimatedSprite; DeltaTimeMS: Word);
begin
  Inc(Sprite.AnimationTimerMS, DeltaTimeMS);

  while Sprite.AnimationTimerMS >= Sprite.FrameDurationMS do
  begin
    { Advance to next frame }
    Sprite.AnimationTimerMS := Sprite.AnimationTimerMS - Sprite.FrameDurationMS;
    Inc(Sprite.CurrentFrame);

    { Loop back to first frame }
    if Sprite.CurrentFrame >= Sprite.MaxFrames then
      Sprite.CurrentFrame := 0;
  end;
end;

{ Example: 10 FPS animation (100ms per frame) }
Sprite.MaxFrames := 8;
Sprite.FrameDurationMS := 100;  { 100ms = 10 frames per second }
Sprite.AnimationTimerMS := 0;
Sprite.CurrentFrame := 0;
```

**Advantages:**
- Frame-rate independent
- Smooth animation at any FPS
- Precise timing

**Disadvantages:**
- Requires delta time calculation
- Slightly more complex

### Method 2: Tick-Based (Frame-Rate Dependent)

Count game frames and advance animation every N frames.

```pascal
type
  TSimpleAnimSprite = record
    CurrentFrame: Byte;
    MaxFrames: Byte;
    FrameCounter: Byte;
    FramesPerAnimFrame: Byte;   { Game frames per sprite frame }
  end;

procedure UpdateSimpleAnimation(var Sprite: TSimpleAnimSprite);
begin
  Inc(Sprite.FrameCounter);

  if Sprite.FrameCounter >= Sprite.FramesPerAnimFrame then
  begin
    Sprite.FrameCounter := 0;
    Inc(Sprite.CurrentFrame);

    if Sprite.CurrentFrame >= Sprite.MaxFrames then
      Sprite.CurrentFrame := 0;
  end;
end;

{ Example: Advance animation every 6 game frames }
{ At 60 FPS: 60/6 = 10 FPS animation }
Sprite.MaxFrames := 8;
Sprite.FramesPerAnimFrame := 6;
Sprite.FrameCounter := 0;
Sprite.CurrentFrame := 0;
```

**Advantages:**
- Very simple and fast
- No multiplication/division
- Minimal memory usage

**Disadvantages:**
- Animation speed tied to frame rate
- Less precise timing
- May look jerky if frame rate varies

## 🎯 Recommendations

### For Movement and Physics:
✅ **Use LongInt milliseconds with delta time**
- Fast integer math
- Good precision (1ms resolution)
- Frame-rate independent
- No overflow issues for gameplay sessions

### For Simple Animations:
✅ **Use Word tick counters** (Method 2)
- Fastest performance
- Simplest code
- Good for fixed-rate animations

### For Complex Animations:
✅ **Use millisecond timers** (Method 1)
- Frame-rate independent
- More predictable behavior
- Better for cutscenes or important animations

## ⚠️ Common Pitfalls

### 1. Delta Time Too Large
If delta time exceeds 1000ms (1 second), your game logic may break:
```pascal
{ Clamp delta time to prevent huge jumps }
if DeltaTimeMS > 100 then
  DeltaTimeMS := 100;  { Max 100ms = 10 FPS minimum }
```

### 2. Integer Overflow in Movement
Large velocities × large delta times can overflow:
```pascal
{ BAD: May overflow }
NewX := X + (VelocityX * DeltaTimeMS) div 1000;

{ GOOD: Check range first }
if Abs(VelocityX) < 30000 then  { Safe range }
  NewX := X + (VelocityX * DeltaTimeMS) div 1000;
```

### 3. Accumulator Drift
Don't reset timers to zero - subtract duration to preserve fractional time:
```pascal
{ BAD: Loses fractional time }
if Timer >= Duration then
  Timer := 0;

{ GOOD: Preserves remainder }
if Timer >= Duration then
  Timer := Timer - Duration;
```

## 📚 Related Documentation

- **RTCTIMER.PAS**: High-resolution RTC timer unit (IRQ8)
- **SPRTEST.PAS**: Example of delta-time movement and FPS calculation
- **XiClone**: Full game implementation with delta-time physics
- **MATHUTIL.PAS**: Fixed-point math utilities (16.16 format)

## 🔧 Future Improvements

Consider creating a **DELTATIME.PAS** helper unit:
```pascal
unit DeltaTime;

interface

uses RTCTimer;

var
  DeltaTimeMS: Word;      { Current frame delta time }
  LastTimeMS: LongInt;    { Last frame timestamp }

procedure InitDeltaTime;
procedure UpdateDeltaTime;
function GetDeltaTimeMS: Word;

implementation

procedure InitDeltaTime;
begin
  InitRTC(1024);
  LastTimeMS := Round(GetTimeSeconds * 1000);
  DeltaTimeMS := 0;
end;

procedure UpdateDeltaTime;
var
  CurrentTimeMS: LongInt;
  Delta: LongInt;
begin
  CurrentTimeMS := Round(GetTimeSeconds * 1000);
  Delta := CurrentTimeMS - LastTimeMS;

  { Clamp to reasonable range (10-100 FPS) }
  if Delta > 100 then Delta := 100;
  if Delta < 10 then Delta := 10;

  DeltaTimeMS := Delta;
  LastTimeMS := CurrentTimeMS;
end;

function GetDeltaTimeMS: Word;
begin
  GetDeltaTimeMS := DeltaTimeMS;
end;

end.
```

This would simplify game code to just call `UpdateDeltaTime` once per frame.
