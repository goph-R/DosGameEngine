# MD5 Hash Bug - 64-bit CPU Real Hardware Issue

## Problem Summary

MD5TEST.EXE fails on Windows 98/DOS machine with 64-bit CPU but works correctly in DOSBox-X emulation.

**Symptoms:**
- Empty string test PASSES (no MD5Transform called)
- All other RFC 1321 test vectors FAIL with consistent wrong hashes
- Same .EXE file works in DOSBox-X, fails on real 64-bit CPU hardware
- Failures are deterministic (same wrong hash every time, not random corruption)

**Test Results:**
- `md5out.txt` - Initial failure on real hardware
- `md5out8.txt` - After complex expression breakdown, still fails
- `md5out9.txt` - After proper recompilation with CMD5TEST.BAT, still fails

## What We've Tried

### 1. Assembly ROL Function
- Converted ROL to pure assembly (bit-by-bit implementation)
- **Result:** No change, still fails

### 2. Assembly Helper Functions
- Converted F, G, H, II functions to assembly
- **Result:** No change, still fails

### 3. Assembly Encode/Decode
- Created DecodeLongInt and EncodeLongInt in assembly
- **Result:** No change, still fails

### 4. Replaced Inc() Calls
- Changed all Inc(var) to explicit addition
- **Result:** No change, still fails

### 5. Complex Expression Breakdown
- Broke down all 64 MD5 rounds from:
  ```pascal
  a := b + ROL(a + F(b, c, d) + x[0] + T[0], 7);
  ```
  Into simple steps:
  ```pascal
  temp := a + F(b, c, d);
  temp := temp + x[0];
  temp := temp + T[0];
  temp := ROL(temp, 7);
  a := b + temp;
  ```
- **Result:** No change, still fails

## Component Tests (All PASS on Both Platforms)

| Test | Purpose | Result |
|------|---------|--------|
| ADDTEST.PAS | LongInt addition | ✓ IDENTICAL |
| PARAMTST.PAS | Assembly parameter access | ✓ IDENTICAL |
| ROLTEST.PAS | ROL function | ✓ IDENTICAL |
| CONSTACC.PAS | Constant array access | ✓ IDENTICAL |
| ARRAYPAR.PAS | Open array parameters | ✓ IDENTICAL |
| MD5STEP.PAS | First MD5 round operation | ✓ IDENTICAL |
| MD5SEQ.PAS | First 4 MD5 rounds | ✓ IDENTICAL |

**Paradox:** Every individual component produces identical results on both platforms, but the full MD5 hash fails only on real hardware.

## Next Steps to Try

### Created but Not Yet Tested:

1. **ENCTEST.PAS** - Test encode/decode LongInt functions
   - Compile with: `CENCTEST.BAT`
   - Tests DecodeLongInt/EncodeLongInt assembly functions
   - Verifies byte order and buffer access
   - **Hypothesis:** Untyped `const buf` parameter might behave differently on 64-bit CPU

2. **MD5FULL.PAS** - Full first transform with detailed logging
   - Compile with: `CMD5FULL.BAT`
   - Runs complete first 4 rounds with state logging
   - Shows initial state, x array, and step-by-step results
   - **Hypothesis:** Will help identify exactly where divergence occurs

## Current Theories

1. **Segment Register Issue:** On 64-bit CPUs in real mode, segment registers or far pointers might work differently than in DOSBox-X emulation

2. **Untyped Parameter Bug:** The `const buf; ofs: Word` parameter in DecodeLongInt uses `les bx, buf` which creates a far pointer - might have addressing issues on 64-bit CPU

3. **Memory Model Issue:** Turbo Pascal's code generation for 16-bit might create instructions that execute differently on 64-bit CPUs

4. **Accumulation Error:** Small rounding or overflow differences accumulate over 64 rounds, but this doesn't explain why individual rounds work correctly

## Files Modified

- **d:\ENGINE\UNITS\MD5.PAS** - Extensively modified with assembly functions
- **d:\ENGINE\TESTS\MD5TEST.PAS** - Main test program
- **d:\ENGINE\TESTS\CMD5TEST.BAT** - Proper compilation script

## Compilation Notes

**CRITICAL:** Must use CMD5TEST.BAT to properly recompile MD5 unit:
```batch
cd ..\UNITS
tpc GENTYPES.PAS
tpc MD5.PAS
cd ..\TESTS
tpc -U..\UNITS MD5TEST.PAS
```

Using `tpc MD5TEST.PAS -u..\units` does NOT recompile the MD5 unit!

## Status

**This is the last bug before 1.0.0 release!**

The bug remains unresolved. All component tests pass, suggesting the issue is either:
- How the full algorithm accumulates operations
- A subtle difference in how compiled code executes on 64-bit hardware
- Something about memory addressing or segment handling specific to real hardware

Next session should:
1. Run ENCTEST.PAS on both platforms
2. Run MD5FULL.PAS on both platforms
3. If those don't reveal the issue, consider using a debugger to trace execution on real hardware
4. May need to examine the actual compiled assembly code (use Turbo Debugger or disassembler)
