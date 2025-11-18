
# 🎨 Save the Current VGA Palette from DOSBox-X

DOSBox-X’s built-in debugger can display the full **256-color VGA DAC palette** (perfect for mode 13h).

## 1️⃣ Start DOSBox-X with the debugger

Open `Debug` > `Start the DOSBox-X debugger`

## 2️⃣ Dump the current VGA palette

`Once the debugger window is open and your game/program is at the desired point, enter:

```text
VGA DACPAL
```

This prints all **256 DAC entries** in `RRGGBB` hex format (each channel is 0–3F).
Copy this output and save it as a text file, e.g. `dacpal.txt`.

## 3️⃣ Convert the text dump to a `.PAL` file

Run your converter tool:

```text
python txt2pal.py dacpal.txt
```

If successful, you’ll see:

```
Wrote dacpal.pal (768 bytes)
```

🎉 Your Mode 13h VGA palette is now saved in standard 768-byte raw PAL format.