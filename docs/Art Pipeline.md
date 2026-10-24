# Art Pipeline

How the 3D asset pack is made, the conventions every model follows, and things worth knowing when the game uses it. Visuals live in [Renders](../Renders), and every model is listed in [Models](../Models). Design source: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md), [Gallery](Gallery.md), [Player Housing - Grid Decoration](Player%20Housing%20-%20Grid%20Decoration.md).

## Where things are

| Path | What |
| --- | --- |
| `art/blender/common.py` | Shared toolkit: palette, beveled low-poly parts, shared architecture helpers, export, z-fight fixer |
| `art/blender/kits/<kit>.py` | One script per kit. The code is the source of truth for every model |
| `Models/<kit>/*.glb` | One GLB per asset, for any engine. Obsidian shows them because "Detect all file extensions" is on |
| `Models/<kit>/manifest.json` | Per-asset size, sockets, tint roles, colour variants, placement data |
| `Renders/Kits`, `Renders/Details` | Kit contact sheets and close-ups, shown in [Renders](../Renders) |
| `Models/all_assets.blend` | Every kit in one Blender file, laid out as labelled blocks |
| `art/blender/showcase.py` | Loads kits into the open Blender as labelled blocks |
| `art/godot/` | Godot helper scripts (`tints.gd`, `sockets.gd`) and `verify_in_godot.sh`, which imports the whole pack in Godot and checks it |

Rebuild one or more kits (headless, about 3 s per kit):

```
"$HOME/Library/Application Support/Steam/steamapps/common/Blender/Blender.app/Contents/MacOS/Blender" -b --factory-startup --python art/blender/build.py -- cafe cottage
```

Blender is the Steam install, 5.2 LTS. The Blender MCP add-on must be started in Blender (the MCP for Blender tab, then Connect) before Claude can drive the live scene.

## Conventions

- **Scale:** metres. The bird avatar is about 0.9 m tall, doors about 1.6 m, seats about 0.42 m, tables about 0.6 m. Building modules snap to a 1 m grid; housing decoration uses 0.5 m cells.
- **Orientation:** the front faces −Y in Blender, which becomes +Z forward after glTF's Y-up conversion. Origin is at ground level, centred on the footprint.
- **Sockets:** interaction and attachment points are empty nodes named `socket_*` (`socket_seat_0`, `socket_player_2`, `socket_door`, `socket_fish_1`, `socket_head` and so on). They appear in the GLB node tree and in the manifest.
- **Graphic inserts:** screens, posters, sign faces and chalkboards use `insert_*` materials. Lettering is a texture the game supplies, not geometry, per the brief.
- **Modularity:** roofs and cutaway walls of buildings are separate child meshes (`*_roof`, `*_cutaway`) so the camera can hide them.

## Systems (detailed notes in `Art Docs/`)

| Note | Covers |
| --- | --- |
| [Tint System](Art%20Docs/Tint%20System.md) | Engine-managed colour: `tint_<role>__<default>` materials, baked shade (COLOR_0) so recolours keep variation, family merging, engine code for three.js, Godot and Unity |
| [Sockets and Attachments](Art%20Docs/Sockets%20and%20Attachments.md) | Every `socket_*` name in the pack, avatar attachment slots, seating a bird |
| [Z-Fighting and Clipping](Art%20Docs/Z-Fighting%20and%20Clipping.md) | The automatic coplanar fixer, its limits, engine depth settings, the poke-through audit |
| [Avatar Rig and Animation](Art%20Docs/Avatar%20Rig%20and%20Animation.md) | Skeleton, clothing rebinding, current clips, animation kit conventions |
| [Housing Placement Data](Art%20Docs/Housing%20Placement%20Data.md) | Grid cells, placement layers, surfaces, interior cell masks, saved layout record |
| [Godot Integration](Art%20Docs/Godot%20Integration.md) | Verified Godot 4.7 import results, `Tints` and `Sockets` helper scripts, animation library and clothing setup |
| [Kit Authoring Guide](Art%20Docs/Kit%20Authoring%20Guide.md) | How to add or change a model, Builder parts and helpers, the quality checks |

## Gotchas found while building

- **Water level:** water surfaces sit at z = −0.5 and dock decks at z = 0 (`WATER_Z` in `nature_dock.py`).
- **Docks:** straight dock modules have posts at the far (−Y) end only, so they chain without doubled posts.
- **Snowball arena:** `snowball_arena_blockout` follows brief §13.4 exactly. Origin is the arena corner, and brief Z maps to +Y.
- **Cinema colours:** the cinema kits add some colours to the palette at runtime. Rebuild them together with `cinema` if a palette name goes missing.
- **Cinema screen:** `insert_screen` is emissive and renders near-white until the game puts a video texture on it.
- **Socket names:** Blender object names are global, so the exporter strips `.001`-style suffixes from socket names per asset. The GLBs always have clean `socket_*` names.
- **Hats look sunk in kit layouts:** attachments have their origin at the avatar slot point, so in a raw layout they sit half below the ground. That's expected.
- **Missing shade attribute renders black:** tint materials multiply the `shade` colour attribute. Meshes built outside `Builder` get a neutral one from `common.ensure_shade()`, which runs before every export and render.

## Kits

The town, activity and character pack has 238 assets; per-kit counts are in [Models](../Models). Housing kits (`homes`, `home_themes`, and `room_kit` as the decoration catalogue) are being built from the Player Housing sheets.

| Group | Kits |
| --- | --- |
| Characters | avatar (base bird, 6 hats, 8 outfits, 9 accessories) |
| Town | plaza, nature_dock, buildings (modular walls and roofs), cafe, cottage, world_misc |
| Cinema | cinema (exterior modules), cinema_lobby, cinema_auditorium |
| Arcade | arcade (solo and duo cabinets, building) |
| Activities | fishing, winter (sledding and snowball arena), activities (basketball, Sketch Club) |
| Housing | room_kit, home_themes, homes |
