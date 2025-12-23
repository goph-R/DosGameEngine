
# ⚠️ Critical Cleanup Rules

Always clean up interrupt handlers before exit, or the system will crash:

```pascal
{ Correct cleanup order - unhook ALL interrupts FIRST before any I/O or cleanup }
Music.Done;       { Unhook music timer (IRQ0) }
Bank.Done;        { Free sound bank XMS memory }
UninstallHandler; { Unhook Sound Blaster (IRQ5/7) }
DoneRTC;          { Unhook RTC timer (IRQ8) }
DoneKeyboard;     { Unhook keyboard (IRQ1, INT 9h) }

{ Now safe to do cleanup and I/O }
DoneVGA;         { Restore text mode }
WriteLn(...);     { Console I/O }
```

**Best practice: Install an ExitProc handler** to ensure cleanup runs even on Ctrl+C/Ctrl+Break:

```pascal
{$F+}
procedure CleanupOnExit;
begin
  ExitProc := OldExitProc;
  if not InterruptsUnhooked then
  begin
    Music.Done;
    UninstallHandler;
    DoneRTC;
    InterruptsUnhooked := True;
  end;
end;
{$F-}

begin
  OldExitProc := ExitProc;
  ExitProc := @CleanupOnExit;
  { ... rest of program ... }
end.
```

**Failure to unhook interrupts will:**
- Cause DOSBox-X to crash
- Hang the DOS system
- Prevent running other programs
- Break mouse/keyboard in subsequent programs

# 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| "XMS not installed" | Load HIMEM.SYS in CONFIG.SYS |
| "Sound Blaster not detected" | Run SETUP.EXE to configure port/IRQ/DMA |
| DOSBox-X crashes after exit | Missing `DoneRTC` or `DoneKeyboard` call |
| Mouse erratic/broken after exit | IRQ2 cascade was masked - use fixed RTCTIMER.PAS (only masks IRQ8) |
| Keyboard stops working after exit | IRQ2 cascade was masked - prevents slave PIC (IRQ8-15) from working |
| Sound cuts off immediately | Use RTCTimer instead of PIT Timer 0 for timing |
| Screen stays in graphics mode | Missing `DoneVGA` call |
| Crackling audio | DMA buffer crossing 64KB boundary (auto-fixed in SBDSP) |