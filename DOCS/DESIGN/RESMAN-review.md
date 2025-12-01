You’ve got a really solid, very “TP7-ish” design here — nice separation of concerns and it fits the DOS constraints well. I’ll go through it in layers: first the big positives, then concrete problems/bugs, then some design tweaks you might want to consider. ([GitHub][1])

---

## 1. Big picture – what works well

**✅ Central manifest & name-based access**

* Single `RES.XML` manifest, no hardcoded paths in game code.
* All access via `GetImage/GetFont/GetSprite/...` is exactly what you want to keep the game code clean.

**✅ Type-specific structs**

* `TImageData`, `TFontData`, `TSpriteData`, etc. make the later cleanup and usage straightforward.
* Storing the “engine type” (like `TImage`, `TFont`, `TSprite`, `PTileMap`) behind a pointer is idiomatic for TP7.

**✅ Lazy vs eager loading**

* `LazyLoad` boolean + `PreloadAll` is a simple but effective strategy.
* The recommended pattern “lazy by default, preload for loading screens” fits DOS load times well.

**✅ SoundBank and shared subsystems**

* Central `TSoundBank` and `SoundBankInitialized` flag is a good pattern so you don’t initialize the sound system if you never use sounds.

Overall: the architecture is clear, testable, and DOS-friendly.

---

## 2. Concrete issues / likely bugs

### 2.1 Sprite XML pointer becomes dangling

In `ParseXML`, for `<sprite>` entries you do:

```pascal
Desc^.ResType := ResType_Sprite;
Desc^.Path := nil;
Desc^.Data := Child; { Store XML node temporarily }
ListAdd(Descriptors^, Desc);
```

Then in `LoadFromXML` you do:

```pascal
if not ParseXML(RootNode) then begin
  XMLFreeTree(RootNode);
  Exit;
end;
XMLFreeTree(RootNode);
```

But `LoadSpriteResource` later assumes `Desc^.Data` is still a valid `PXMLNode`:

```pascal
XMLNode := PXMLNode(Desc^.Data);
...
FrameNode := XMLFirstChild(XMLNode);
```

After `XMLFreeTree(RootNode)`, all those nodes are freed, so `Desc^.Data` points to freed memory. That’s a use-after-free bug and can cause random crashes or corrupted sprites. ([GitHub][1])

**Fix options:**

1. **Don’t free XML until all sprites are loaded.**

   * Simple but defeats the purpose of lazy loading for sprites.

2. **Copy the sprite definition out of XML during `ParseXML`.**

   * E.g. allocate your own list of frames in `TSpriteData` and store:

     * image name
     * duration
     * frame rects
   * Then you can safely `XMLFreeTree` and still lazily create the `TSprite` object when needed.

3. **Hybrid:** parse only basic attributes in `ParseXML`, keep XML tree alive, and add a `ResMgr.DoneXMLTree` method when you know everything is loaded. That’s more manual and error-prone.

I’d go with (2): make `ParseXML` responsible for extracting all sprite info into engine-owned structures.

---

### 2.2 `UsePalette` for images is never set (and typo)

In `LoadImageResource`:

```pascal
New(ImgData);

{ Load PCX file }
if ImageData^.UsePalette then begin { <-- Also typo: ImageData vs ImgData }
  LoadResult := LoadPCXWithPalette(Desc^.Path^, ImgData^.Image, Palette);
  if LoadResult then SetPalette(Palette);
end else
  LoadResult := LoadPCX(Desc^.Path^, ImgData^.Image);
```

Issues:

1. Variable name typo: `ImageData` vs `ImgData`.
2. `ImgData^.UsePalette` is never initialized anywhere.

   * Doc says `use-palette` attribute exists on `<image>`, but `ParseXML` never reads it nor stores it in the descriptor.

**Fix suggestion:**

* Parse the `use-palette` attribute in `ParseXML`:

  ```pascal
  if TagName = 'image' then begin
    Desc^.ResType := ResType_Image;
    New(Desc^.Path);
    Desc^.Path^ := XMLAttr(Child, 'path')^;

    if XMLHasAttr(Child, 'use-palette') then
      Desc^.Data := Pointer(1)  { or store a small record / flag }
    else
      Desc^.Data := Pointer(0);

    ListAdd(Descriptors^, Desc);
  end;
  ```

* Or better: add a `UsePalette` field to `TResourceDescriptor` itself (or a small union/variant record) so you don’t abuse `Data`.

* Then in `LoadImageResource`:

  ```pascal
  ImgData^.UsePalette := (Desc^.UsePalette);
  if ImgData^.UsePalette then ...
  ```

Right now this code path is undefined and will randomly choose one branch depending on whatever garbage happens to be in that byte.

---

### 2.3 Missing validations on required attributes

You always validate `name`, but for most types you assume `path` is there:

```pascal
New(Desc^.Path);
Desc^.Path^ := XMLAttr(Child, 'path')^;
```

If the XML is malformed and `path` is missing, `XMLAttr` might return `nil` and you dereference it, or the XML unit might assert/crash.

Same for sprite-specific attributes (`image`, `duration`, frame `x/y/width/height`).

**Suggestion:**

* Add defensive checks in `ParseXML`:

  ```pascal
  if not XMLHasAttr(Child, 'path') then begin
    LastError := 'Resource ' + Desc^.Name^ + ' missing path attribute';
    Dispose(Desc^.Name); Dispose(Desc);
    Exit(False);
  end;
  ```

* For sprite: if `duration` is missing, either:

  * default to something like `SprData^.Sprite.Duration := 0.1;`
  * or treat it as an error and set `LastError`.

This will make `LastError` much more useful when something is wrong in XML.

---

### 2.4 Sounds leak their small wrapper record

In `Done` you free the sound *data* via `SoundBank.Done`, but you don’t free the `PSoundData` wrapper itself:

```pascal
ResType_Sound: begin
  { Sounds freed by SoundBank.Done }
end;
```

Each sound has a `PSoundData` allocated in `LoadSoundResource`. The sound bank frees the underlying sound buffers, but the `PSoundData` records themselves will leak.

**Fix:**

```pascal
ResType_Sound: begin
  SndData := PSoundData(Desc^.Data);
  Dispose(SndData);
end;
```

(SoundBank.Done will still free the internal data.)

---

### 2.5 Minor clean-up & consistency issues

* `TResourceManager.Done` only frees `Desc^.Data` when `Desc^.Loaded = True`. For sprites that were *never* loaded, `Desc^.Data` still points to the XML node (which is already freed). You don’t deref it, so it’s not a crash, just a stale pointer. Once you stop storing XML nodes there, that goes away.
* `LoadLevelResource`: you free via `FreeTileMap(LevelData^.Map^)`. Make sure `FreeTileMap` really takes the *record* by reference and not a pointer; naming suggests it probably wants a `PTileMap`. If it expects a pointer, you should pass `LevelData^.Map`.

---

## 3. Design suggestions / improvements

### 3.1 Descriptor lookup optimization

`GetImage` does:

```pascal
if MapContains(ImageMap, Name) then ...
{ else }
Node := Descriptors^.Head;
while Node <> nil do begin
  Desc := PResourceDescriptor(Node^.Data);
  if (Desc^.ResType = ResType_Image) and (Desc^.Name^ = Name) then ...
```

So you have:

* Map: `name -> loaded data`
* List: all descriptors, used to find descriptor by name when not loaded.

For N resources, that “find descriptor” step is O(N), which is probably fine for a few hundred assets, but you could avoid it by:

* Making the maps store the **descriptor** instead of the type-specific data:

  * e.g. `ImageMap: TStringMap` where value is `PResourceDescriptor`.
  * `Desc^.Data` points to `PImageData` when loaded.
* Or having an extra global `DescriptorMap: TStringMap` that maps name → descriptor (type-agnostic).

Not vital for DOS, but it simplifies logic and you don’t need to traverse the linked list every time for lazy load.

---

### 3.2 Configuration per resource/group, not just global `LazyLoad`

You already mention “Resource Groups” in “Future Enhancements”. ([GitHub][1])

You might later want:

* `<resource-group name="level1" preload="true"> ... </resource-group>`
* `<image name="logo" preload="true" ... />`

Then:

* `ParseXML` assigns a `Group` and `Preload` flag to each `TResourceDescriptor`.
* `PreloadAll` could be extended to preload a specific group.
* A separate API like `ResMgr.PreloadGroup('level1_assets');`.

Your current design already makes this easy: descriptors list is central, so you just add a couple of fields to `TResourceDescriptor`.

---

### 3.3 XML example + formalization

The doc’s XML example is currently empty in the snippet (just a ` ```xml ``` ` block). It’d help future-you to have:

* A full mini example:

  ```xml
  <resources>
    <image name="player" path="DATA\PLAYER.PCX" use-palette="true" />
    <font name="font_small" path="DATA\FONT-SM.XML" />
    <sound name="jump" path="DATA\JUMP.VOC" />
    <music name="title" path="DATA\TITLE.HSC" />
    <sprite name="player_idle" image="player" duration="0.12">
      <frame x="0" y="0" width="16" height="16" />
      <frame x="16" y="0" width="16" height="16" />
    </sprite>
    <level name="level1" path="DATA\LEVEL1.TMX" />
  </resources>
  ```

* A short description of optional vs required attributes.

Helps keep the implementation and XML aligned as you evolve both.

---

### 3.4 Palette handling strategy

Right now, `LoadImageResource` conditionally calls `SetPalette(Palette)` when `UsePalette` is true:

* That’s fine for whole-screen background images.
* But for HUD images or sprites, you might *not* want to change the global palette when they load.

Later you might want:

* A global “current game palette” managed by another unit.
* Or a per-resource palette stored in `PImageData`, and a function `ApplyImagePalette(ImageName)` to intentionally change it.

For now, it may be enough to document that `use-palette` is meant for “this image defines the global palette”.

---

### 3.5 Error reporting details

You already have `LastError` and a list of common messages. You might:

* Include more specific context:
  `"Failed to load image: DATA\BG1.PCX (image 'bg1')"`
* In `ParseXML`, when you abort on the first error, you might also note line/column if MINIXML can give that.

Not required, but super helpful when debugging RES.XML typos.

---

## 4. Summary

Short version:

* **Architecture is strong** and matches your DOS engine style: central manifest, type-specific maps, lazy vs eager loading.
* The **major issue** is the sprite XML node pointer surviving after `XMLFreeTree` — that needs redesign (copy data out or keep XML alive longer).
* **Minor but important bug**: `UsePalette` never initialized + variable name typo.
* A few **safety checks & small leaks** to fix (missing `path` validation, freeing `PSoundData`, level free call double-check).
* You’ve left room for nice future features (groups, ref counting, streaming), and the current structure supports those well.

If you want, next step I can help you rewrite `ParseXML` + `LoadSpriteResource` in actual TP7 code with the “copy frames out of XML immediately” approach so lazy loading of sprites doesn’t rely on the XML tree staying in memory.

[1]: https://raw.githubusercontent.com/goph-R/DOS-Game-Engine/refs/heads/main/DOCS/DESIGN/RESMAN.md "raw.githubusercontent.com"
