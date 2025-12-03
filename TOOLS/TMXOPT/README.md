# TMX Optimizer

DOS tool for optimizing multi-layer Tiled TMX files into atlas-based 2-layer maps.

## Purpose

Converts complex TMX maps with many layers into optimized maps with:
- Exactly 2 visual layers (Back + Front)
- 1-4 atlas tilesets containing pre-merged tile stacks
- Preserved Blocks and Objects tilesets
- Preserved objectgroups

This dramatically reduces DOS memory usage and rendering overhead.

## Building

In DOSBox/FreeDOS:

```
CD TOOLS\TMXOPT
CTMXOPT.BAT
```

## Usage

```
TMXOPT <input.tmx> <output.tmx>
```

Example:

```
TMXOPT ..\..\DATA\LEVEL1.TMX ..\..\DATA\LEVEL1O.TMX
```

## Output

- `<mapname>_AT1.PCX` - First atlas tileset (up to 240 tiles)
- `<mapname>_AT2.PCX` - Second atlas (if needed)
- `<mapname>_AT3.PCX` - Third atlas (if needed)
- `<mapname>_AT4.PCX` - Fourth atlas (if needed)
- `<output>.TMX` - Optimized TMX file

## How It Works

1. **Phase A**: Load TMX file, resolve external TSX tilesets, and load all tileset images
2. **Phase B**: Build tile stacks for each cell (merge layers bottom-to-top)
3. **Phase C**: Deduplicate stacks and assign composite tile indices
4. **Phase D**: Build atlas tilesets, render composites, save PCX files
5. **Phase E**: Update TMX structure (new tilesets + layers)
6. **Phase F**: Save optimized TMX and cleanup

## Constraints

- Max 16 raw input layers
- Max 8 tiles per stack
- Max 4096 unique tile combinations
- Max 4 atlas tilesets (240 tiles each @ 16x16)
- CSV encoding only
- Requires PCX tileset images
- Supports external TSX tilesets (firstgid preserved from TMX reference)

## Memory Requirements

Approximately:
- Map data: `Width × Height × 2 × 2 bytes` (Back + Front)
- Stacks: `Width × Height × 2 × ~10 bytes` (temporary)
- Atlas images: `256 × 240 × AtlasCount bytes`

For a 64×64 map: ~100KB conventional memory needed.

## Notes

- Color 0 is always treated as transparent
- Blocks and Objects tilesets are preserved with updated FirstGIDs
- Objectgroup tile references (gid attributes) are automatically updated
- External TSX tilesets are fully supported (loaded, processed, merged)
- The runtime engine (TMXLOAD.PAS) needs no changes

## See Also

- DOCS/DESIGN/TILEMRG.md - Full specification
- DOCS/TILEMAP.md - TMX format documentation
