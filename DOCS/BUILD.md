# 🧱 Building from Source

**Automated (recommended):**
```bash
cd TESTS
CBMPTEST.BAT    # BMP image loader test
CVGATEST.BAT    # VGA graphics test
CSNDTEST.BAT    # Sound bank test
CSPRTEST.BAT    # Sprite animation test
CTMXTEST.BAT    # TMX tilemap scrolling test
CXMLTEST.BAT    # XML parser test
```

**Manual compilation:**
```bash
cd UNITS
tpc VGA.PAS
tpc PCX.PAS
tpc SBDSP.PAS
# ... compile other units

cd ..\TESTS
tpc -U..\UNITS VGATEST.PAS
```
