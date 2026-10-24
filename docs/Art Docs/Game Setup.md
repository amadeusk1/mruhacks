# Game Setup

How the Godot game (repo `amadeusk1/mruhacks`, Godot 4.7) uses the art pack, and where the town comes from. Hub: [Art Pipeline](../Art%20Pipeline.md). Data format: [World Layout Format](World%20Layout%20Format.md).

## Branches and assets

- **Name:** the game is called **Pengloo Party**.
- **`main`:** the asset branch. Models, anim kits and props are synced and pushed there often (by the coordinator's `../mruhacks-main` worktree). The teammate's gameplay commits also land on `main`.
- **`art/town-map`:** the connected-town and game-setup work. It picks up assets and teammate code with `git fetch origin && git merge origin/main`, and never runs `sync_to_repo.py` itself.

## Autoloads and helpers

| Name | File | Role |
| --- | --- | --- |
| `Net` | `scripts/net.gd` | Teammate's multiplayer (ENet, rooms, seats) |
| `AssetRegistry` | `scripts/assets/asset_registry.gd` | Every `Models/*/manifest.json` by id: `entry`, `scene`, `instantiate`, `size` (Godot axes), `icon`, `sockets`, `parts` |
| `AssetPack` (class) | `scripts/asset_pack.gd` | Teammate's loader: `spawn(kit, asset)` (instancing plus `Tints.prepare`), `mount_bird` (rigged penguin with clothes and clips), room dressing |
| `Tints`, `Sockets` (classes) | `art/godot/tints.gd`, `sockets.gd` | Recolour by tint role, and find `socket_*` nodes (see [Godot Integration](Godot%20Integration.md)) |

The old `Travel` autoload pointed at a script that never existed in git, and nothing used it, so it was removed.

## The town

- **Scene:** `scenes/locations/town.tscn`, location id `town`, title "Town". `LocationCatalog.MAIN` is `town`: new sessions start there, and the sled run returns there. The teammate's plaza is still on the bus as **Shops**.
- **Builder:** `scripts/world/town_builder.gd` reads `res://Models/world/town_layout.json` at load and falls back to `scripts/world/town_layout_stub.json` while the world files are missing. It builds:
  - the terrain GLB, with trimesh colliders on physics layer 1 for every `terrain_*` mesh;
  - placements through `AssetPack.spawn`, plus `tints`;
  - box blockers on layer 2 from the manifest `size_m` for `blocker` tags, and trimesh walk colliders for `walkable` tags;
  - MultiMesh batches for six or more identical, untinted, part-less props;
  - `Marker3D`s named as in the layout, with door `Area3D`s using `doorway.gd` when a door has a `target`.
- **Navmesh:** everything is built under `NavigationRegion3D` before the teammate's `room_nav.gd` bakes it, so click-to-walk works.
- **Bus stop:** a `bus` marker becomes `NavigationRegion3D/BusStop`, which `world.gd` requires. Without one, a stop is placed beside `BusArrival`.
- **Camera:** `camera_for_spawn` reads the layout's optional `camera` block (`center`, `limit_x`, `limit_z`, `height`, `distance`). The defaults are limits 30 / 24, height 15, distance 12.5.
- **Ambient motion:** each instance's `*_sway` / `*_flutter` / `*_spin` clip plays at a random phase and speed, and `glow*` materials breathe ±12% out of phase.

## Penguin

The teammate's `AssetPack.mount_bird` puts the rigged `avatar_base` (from `anim_locomotion`) under the player's `Visual` node, with clothing and a socket item. It aliases `sit` and `wave` from `anim_social` and `anim_emotes`. The body tint comes from `Net.coat_color`.

## Environment

## Doors and interiors

- **Town doors:** the layout's `door` markers become `Interactable`s:
  - `cinema_lobby` → the teammate's `cinema` scene (`InsideLobby`);
  - `cafe_interior` → `cafe`;
  - `arcade_interior` → `arcade`;
  - `home` → the player's igloo (`InsideSpawn`).
  Each door also gets a `<Door>Out` marker just outside, facing away, which interiors use to walk back out.
- **Interiors:** `scenes/locations/cafe.tscn` and `arcade.tscn` (`scripts/world/interior_builder.gd`) assemble the kit shell plus props from its sockets. That covers the counter, coffee station, tables and stools, and the duo cabinet with stations `socket_player_1/2`. They add colliders for the navmesh, an `Inside` spawn and a walk-out `doorway.gd` (now with `location`) back to town. The arcade shell has no authored cutaway, so its front wall is trimmed at load (a shortcut until the kit ships a `*_cutaway`).

## Interactables API (for the UI)

- **Group:** `interactables`. Each one is an `Area3D` (`scripts/world/interactable.gd`) with `prompt_text()` ("Enter Café", "Join Snowball Arena") and `interact(player)`. The F key uses the same objects as the teammate's benches, fishing spots and bus stop.
- **Activities autoload:** connect `Activities.requested(activity, anchor, player)` to run an activity UI. While nobody is connected, the anchor honestly says "<Title> opens soon". `Activities.anchors()` lists all of them.
- **Town anchors:** basketball court, Sketch Club and snowball arena (activity requests); sled start (travels to `sled_hill`); four fishing spots (the teammate's `fishing_spot.gd`, placed from the layout).

## Penguin animation API

`PenguinAnims.attach` loads every kit into the player's `AnimationPlayer` as libraries: `emotes`, `social`, `fishing`, `sledding`, `snowballs`, `basketball`, `arcade`, `drawing`, `cinema`, `home`, `everyday` (88 clips).
- **`penguin.play_emote(name)`:** `"wave"`, `"dance"`, `"emote_cheer"`.
- **`penguin.play_activity(name)`:** `"snow_throw"`, `"fishing/fish_cast"`, `"arcade_play"`. Moving cancels it.
- **Locomotion:** walk and run are chosen and rate-scaled from ground speed.
- **Fishing:** the teammate's fishing phases (cast, wait, bite, reel, catch, miss) drive the `anim_fishing` clips.

## Camera visibility

`scripts/world/occlusion_fader.gd` on `CameraRig`:
- **Fading:** every placement whose world AABB crosses the camera-to-penguin segment dithers to 30% (alpha hash, 0.15 s in, 0.3 s out) and is restored exactly.
- **Roofs:** roofs and cutaways hide while the player is in that building's footprint.
- **Never faded:** the terrain, the room the player is inside, and what they stand on.
- **Silhouette:** a teal overlay shader draws the hidden parts of the penguin, and nametags ignore depth.
- **Batched foliage:** it can't fade per object, so `foliage_batch.gdshader` cuts a dithered circle around the penguin instead.
- **Reduced motion:** `Settings.reduced_motion` makes fades instant.

## Performance and ambient

- **Batching:** trees and shrubs whose only moving part sways are batched into MultiMeshes, with shader sway (678 instances, about 145 fps in the town).
- **Ambient effects:** `AmbientFx` adds smoke, steam and splash emitters from the `fx` meshes at every `socket_fx_*`, plus a camera-following snowfall outdoors.

## Environment

The town swaps in its own `Environment` and sun, and restores the world's on exit:
- `scenes/env/town_env_forward.tres`: warm-horizon procedural sky, Filmic tonemap (white 1.8), light fog, soft glow, saturation 1.15.
- `scenes/env/town_env_compat.tres`: the same without glow, with lower ambient light; the sun is scaled to 0.62×. See the Browser section of [Godot Integration](Godot%20Integration.md).
- The sun direction, colour and energy come from the layout's `sun` block.

## Screenshots

```
Godot --path . res://tools/capture.tscn -- --out=/abs/output/dir/
```

This starts solo, enters the town, and saves `game_play.png` (gameplay camera), `game_overview.png` and `game_side.png`. Latest: `Renders/Details/game_town.png`.
