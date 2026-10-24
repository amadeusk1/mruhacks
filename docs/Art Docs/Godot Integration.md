# Godot Integration

Using the asset pack in Godot 4, which the [Animation Production Checklist](../Animation%20Production%20Checklist.md) names as the review engine. Verified with Godot 4.7.2 (the Steam install). Hub: [Art Pipeline](../Art%20Pipeline.md).

## What was verified in Godot

`art/godot/verify_in_godot.sh` imports every GLB from `Models/` into a throwaway project at `~/Library/Caches/club_penguin_godot_check`, outside the vault so no `.import` files clutter Obsidian, and runs the checks in `art/godot/tests/`:

| Check | Result (295 GLBs) |
| --- | --- |
| Import | All load, none fail |
| Sockets | 312 `socket_*` nodes arrive as named `Node3D`s |
| Rigs | Avatar base and clothing import with `Skeleton3D`; `avatar_base` has its 4 clips in an `AnimationPlayer` |
| Tint materials | Material names survive (`tint_roof__F07E66`), and the shade arrives as a vertex-colour array |
| Shade flag | Godot enables **Vertex Color → Use as Albedo** only when it decides a material needs it. 267 tint surfaces were on; 2 with real shade (`cottage/round_rug`, `home_themes/beanbag`) came in **off**, which loses their variation. Always call `Tints.prepare()` (below) |
| Helper test | `Tints.prepare` + `Tints.apply` recolour one instance without touching another, and the shade flag is on everywhere: PASS |

Headless runs print `Parameter "material" is null` from Godot's dummy renderer. That's noise from running without a GPU, not an asset problem.

Run it again after any rebuild:

```
"art/godot/verify_in_godot.sh"
```

## Helper scripts (copy into the game project)

**`art/godot/tints.gd`** (`class_name Tints`):

```gdscript
var house := preload("res://models/cafe/cafe_exterior.glb").instantiate()
add_child(house)
Tints.prepare(house)                                  # per-instance materials + shade flag on
Tints.apply(house, {"roof": Color("#4a7bd0"), "wall": Color("#f3e2c5")})
print(Tints.roles(house))                             # ["wall", "trim", "door", "awning_a", "awning_b", "roof"]
```

**`art/godot/sockets.gd`** (`class_name Sockets`):

```gdscript
var seat := Sockets.find(sofa, "seat_0")              # Node3D at the sit point, facing out
bird.global_transform = seat.global_transform
var all := Sockets.all(cabinet)                       # {"player_1": Node3D, "player_2": Node3D, "screen": Node3D}
```

## Import notes

- **Up axis:** GLBs are Y-up, as Godot expects. An asset's front faces +Z in Godot (it was −Y in Blender).
- **Roof and cutaway hiding:** `*_roof` and `*_cutaway` come in as child `MeshInstance3D`s. Toggle `visible` to cut away a building for the interior camera.
- **Animation libraries:** the avatar's clips import into an `AnimationPlayer`. The planned animation kits (`anim_locomotion`, `anim_emotes`, `anim_social` and activity sets) are skeleton-plus-clips GLBs. Import each as an **AnimationLibrary** (Advanced Import Settings → save animations to file) and add it to the player's `AnimationPlayer`. Bone names match across all kits.
- **Clothing:** clothing GLBs carry their own copy of the skeleton. To dress a bird, reparent the clothing `MeshInstance3D` under the bird's `Skeleton3D` and set its `skeleton` path to it. Bone names match, so the skin binds directly.
- **Glow:** emissive materials (`glow*`, bulbs, screens) come in with emission enabled. For lanterns to bloom, turn on Glow in the `WorldEnvironment`.

## Browser (Compatibility renderer)

A browser build must use Godot's **Compatibility** renderer ([Dev Handoff - Self Hosting and Browser Release](../Dev%20Handoff%20-%20Self%20Hosting%20and%20Browser%20Release.md)). The same plaza scene (café, arcade, fountain, lantern, tree, two penguins) was rendered under Forward Plus and Compatibility on 2026-10-24:

- **Glow** washes the whole frame out to near white under Compatibility. Use a separate web `Environment` with `glow_enabled = false`, or a much lower glow intensity tested in the browser.
- **Lighting:** Compatibility renders brighter and more saturated, so teal doors read as bright cyan. Matching values from that test: sun `light_energy` 1.3 → **0.8**, ambient energy 0.6 → **0.3**, Filmic tonemap kept. Keep one environment per renderer, picked at startup with `RenderingServer.get_current_rendering_method()`.
- **Baked shade:** the roof's tile-to-tile shade variation reads stronger under Compatibility; the vertex-colour sRGB flag makes no difference. Acceptable as is. If it's too strong in the browser, scale the shade down in a web-only material variant instead of changing the models.
- **Unchanged:** models, tints, sockets and parts.

Test scene: `~/Library/Caches/club_penguin_compat` (`shot.gd`; args `noglow`, `weblight`). The comparison renders are in `art/_wip/`.
