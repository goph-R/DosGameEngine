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
# CORRECT - Preserves binary files
* text=auto eol=crlf

# Explicitly mark binary files
*.exe -text
*.obj -text
*.tpu -text
*.pcx -text
# ... etc
```

**Key changes:**
1. `text=auto` instead of `text` - Git auto-detects binary vs text files
2. `-text` instead of `binary` for binary file patterns (modern Git syntax)
3. Added all binary extensions used in the project

## How Git Line Endings Work

### Line Ending Types
- **LF** (`0x0A`): Unix/Linux line ending
- **CRLF** (`0x0D 0x0A`): DOS/Windows line ending

### Git Attributes Explained

| Attribute | Behavior |
|-----------|----------|
| `* text eol=crlf` | **BAD**: Forces CRLF on ALL files (breaks binaries) |
| `* text=auto eol=crlf` | **GOOD**: Auto-detects text, applies CRLF to text only |
| `*.obj binary` | **OLD**: Marks as binary (deprecated syntax) |
| `*.obj -text` | **NEW**: Excludes from text normalization (preferred) |

### Why We Need CRLF

DOS batch files (.BAT) **require** CRLF line endings to work correctly:
- DOS uses CRLF to mark line breaks
- LF-only files cause batch scripts to fail
- `text=auto eol=crlf` ensures .BAT files use CRLF while preserving binaries

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
