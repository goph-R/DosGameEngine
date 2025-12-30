# Git Attributes Configuration

## The Problem

The original `.gitattributes` file had a critical bug that corrupted **ALL binary files** during git operations (clone, checkout, pull):

```gitattributes
# WRONG - This corrupts binary files!
* text eol=crlf
*.obj binary
```

**Why this was broken:**
1. `* text eol=crlf` forced CRLF line-ending conversion on ALL files (including binaries)
2. The `*.obj binary` rules below were ignored because the wildcard rule took precedence
3. Git converted every `0x0A` (LF) byte to `0x0D 0x0A` (CRLF) in binary files
4. This corrupted: .OBJ, .PCX, .PNG, .VOC, .HSC, .DLL, and other binary files

**Symptoms:**
- `Error 47: Invalid object file record (HSCOBJ.OBJ)` during Turbo Pascal compilation
- Corrupted images (PCX/PNG files)
- Corrupted sound files (VOC files)
- Compilation failures in DOSBox

## The Solution

The corrected `.gitattributes`:

```gitattributes
# CORRECT - Simple and safe
# No line-ending conversion, just protect binary files

# Mark binary files to prevent any conversion
*.exe -text
*.obj -text
*.tpu -text
*.pcx -text
# ... etc
```

**Key changes:**
1. Removed ALL line-ending rules (no `eol=crlf`)
2. `-text` marks binary files to prevent any conversion
3. Text files use whatever line endings are committed (LF in our case)
4. Simple, explicit, and safe

## How Git Line Endings Work

### Line Ending Types
- **LF** (`0x0A`): Unix/Linux line ending
- **CRLF** (`0x0D 0x0A`): DOS/Windows line ending

### Git Attributes Explained

| Attribute | Behavior |
|-----------|----------|
| `* text eol=crlf` | **BAD**: Forces CRLF on ALL files (breaks binaries) |
| `* text=auto eol=crlf` | **COMPLEX**: Auto-detects text, applies CRLF (can still cause issues) |
| `*.obj binary` | **OLD**: Marks as binary (deprecated syntax) |
| `*.obj -text` | **BEST**: Simple - just prevent conversion |
| *(nothing)* | **CURRENT**: No wildcard rule = Git preserves what's committed |

### Why We Use LF (Not CRLF)

**Decision: All text files use LF (Unix standard)**

- DOSBox and DOSBox-X handle LF in .BAT files correctly
- Development is primarily on Linux
- Simpler .gitattributes = less chance of corruption
- No forced line-ending conversion = safer for everyone

## For Contributors

### Fresh Clone
When you clone the repository, Git will now:
1. Auto-detect text vs binary files
2. Convert text files to CRLF in your working directory
3. **Preserve binary files exactly** (no conversion)

### Verifying Binary Files

After cloning, verify critical binary files are not corrupted:

```bash
# Check HSCOBJ.OBJ MD5 (should be b8eb924a8f89d237d437c2e877d801ff)
md5sum UNITS/HSCOBJ.OBJ

# Check for CRLF corruption in binary files (should show no matches)
hexdump -C UNITS/HSCOBJ.OBJ | grep "0d 0a"
```

**Clean OBJ file** (correct):
```
00000000  80 0c 00 0a 68 73 63 6f  62 6a 2e 41 53 4d e2 88  |....hscobj.ASM..|
                   ^^^ LF (0x0A) - CORRECT
```

**Corrupted OBJ file** (wrong):
```
00000000  80 0c 00 0d 0a 68 73 63  6f 62 6a 2e 41 53 4d e2  |.....hscobj.ASM.|
                   ^^^^^^^ CRLF (0x0D 0x0A) - CORRUPTED
```

### If You Encounter Corruption

If you cloned the repository **before** this fix, your binary files may be corrupted:

```bash
# Re-extract all files with corrected .gitattributes
git rm -rf --cached .
git reset --hard HEAD
```

Or for a completely fresh start:
```bash
rm -rf ENGINE
git clone <repository-url>
```

## Testing Compilation

After fixing the binary files, test compilation in DOSBox:

```
cd C:\ENGINE\XICLONE
CXICLONE.BAT
```

If successful, you should see:
```
Compiling PLAYHSC.PAS...
PLAYHSC.PAS(373)
373 lines, 2xxx bytes code, xx bytes data.
...
Build successful!
```

## References

- Git Attributes Documentation: https://git-scm.com/docs/gitattributes
- Git Line Endings Guide: https://git-scm.com/book/en/v2/Customizing-Git-Git-Attributes
- Why `text=auto`: https://stackoverflow.com/questions/10418975

## History

- **2025-12-30**: Fixed `.gitattributes` to use `text=auto` and `-text`
- **Before**: All binary files were corrupted by forced CRLF conversion
