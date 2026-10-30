# Housing — House Upgrades Plan

Players buy upgrades for their snow dome from **inside their house**. Each tier is the same igloo built bigger, with more floor cells and wall spots for furniture. Furniture carries over. Related notes: [Player Housing - Grid Decoration](Player%20Housing%20-%20Grid%20Decoration.md), [Art Pipeline](Art%20Pipeline.md), [Pets - Concepts](Pets%20-%20Concepts.md) (coins).

## What exists today

| Piece | Where | Notes for upgrades |
| --- | --- | --- |
| House model | `art/blender/kits/homes.py` → `snow_dome()` | Interior radius `Ri = 2.3`, exterior `DOME_R = 2.3`, footprint 7.0 × 6.4 m |
| Dome walls | `dome_blocks()` | Block count comes from the circumference (`2πR / 0.66 m`) and rows are 0.55 m. **A bigger R gives more blocks of the same size**, so the look holds. |
| Room grid | `Room` helper | Takes any inside-the-room test, so joined domes are just a union of circles |
| Interior today | `homes/snow_dome_interior` | **52 cells (48 usable)**, 5 wall slots, 3 ceiling anchors |
| Home location | `scenes/locations/home.tscn`, `scripts/home.gd`, `AssetPack.dress_home` | Interior sits at x = 80. Several sizes are hard-coded: wall ring 2.15 m, exterior ring 2.2 m, camera limits 2.3, shell id `_SHELL` |
| Furniture save | `DecorEditor` → `user://home_<shell>.json` `{shell, items}` | Cells are grid indices with the grid centred on the room. The shared JSON already names its shell. |
| Sharing | `Net.publish_home` / `fetch_home`, `world._share_home` | `_share_home` hard-codes the snow dome path |
| Town house | `town_builder.gd` `Home2Door` | One island dome shared by everyone. It leads to your own `home` location. |

The starter furniture (sofa, armchair, bed, lamp) already uses about 17 of the 48 cells, which is why the dome feels full fast.

## The tiers

All tiers keep the same ice-block size, door, arched and round windows, lantern, barrel and chimney. Only the radius, the block count and some extra dressing change.

| Tier | Name | Price | Interior | Floor cells (approx.) | Wall spots | Ceiling hooks | Exterior footprint |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | **Snow Dome** | owned | one dome, R 2.3 m | 48 | 5 | 3 | 7.0 × 6.4 m |
| 2 | **Big Dome** | **120 coins** | one dome, R 3.0 m | ~90 (≈1.9×) | 8 | 5 | ~8.4 × 7.8 m |
| 3 | **Twin Dome** | **300 coins** | Big Dome + a side dome (R 2.0 m) through an ice arch | ~135 (≈2.8×) | 12 | 8 | ~11 × 8.5 m |

The exact cell counts come from the build, since `Room.meta()` reports them. Put the final numbers in the upgrade screen.

**Exterior changes per tier (so the upgrade shows from outside):**
- **Big Dome:** more and wider block rings, a taller cap, a second round window, a twin-lantern entrance, a woodpile by the tunnel, and a wider snow base with one more snowy fir.
- **Twin Dome:** the Big Dome plus a smaller side dome on the back-left. It's joined by a short block arch with its own arched window and snow-capped crown. The chimney stays on the main dome.

**Interior changes per tier:**
- **Big Dome:** the same plaster ring wall with a wood cap and leaning ice course, two windows, and the door at the same 160° bearing.
- **Twin Dome:** an arched opening through the back-left wall into the side room, framed like the doors. The side room is a cosy nook for a bed or a reading corner.

The visible walls stay back and left and the cutaway lip stays front and right, so the camera rule doesn't change. The side dome sits on the visible back-left side so it's never hidden behind the cutaway.

**Later (not priced yet):** a Tier 4 "Ice Lodge" with a loft, reusing the A-frame's loft and headroom code (`aframe_headroom`, `cells_loft`). Also other shells (cottage, A-frame…) getting their own tier ladders.

## Pricing

Coins come from play and are saved between sessions (`user://wallet.cfg`).

| Source | Coins |
| --- | --- |
| Activity visit / loss (arcade, casino, snowballs, sketch, basketball) | 5 |
| Win (snowballs, basketball) / best sled run | 10 / 15 |
| Fish (Sunny / Drift / Bramble) | 3 / 5 / 8 |
| Solo basketball | 1 per point |

Active play earns roughly **4–6 coins a minute**. Existing prices: clothes 8–32, coat colours 8–18, pets 15–40.

- **Big Dome, 120:** about 20–30 minutes of play, or three pets' worth. It's the first big goal after a couple of outfit pieces.
- **Twin Dome, 300:** about another hour, the long-term goal. It's 2.5× tier 2 for 1.5× more space, so later space costs more per cell, as usual for progression.

Keep both prices in one table (`HomeUpgrades.TIERS`) so they're easy to tune after playtests. Upgrades are never refunded and there's no downgrade.

## Player flow (inside the house)

1. The Home HUD inside the house (`decor_ui.gd`, mode `home`) gets an **Upgrade** button beside Decorate. It's shown only to the owner (hidden on visits) and only when a higher tier exists.
2. **The Upgrade card** (a `UIModal`, in the act_style look):
   - Side-by-side exterior thumbnails of now → next (icons rendered by `render_icons.py`).
   - Big numbers: "48 → 90 floor spaces", "5 → 8 wall spots".
   - Name, price chip, and "Your coins: N".
   - **Upgrade** is the primary button; "Not now" closes the card.
   - Short on coins: the button is disabled with "You need N more coins" (same wording as the pet and wardrobe shops).
3. **Confirm:** a `ConfirmDialog` reading "Upgrade to Big Dome for 120 coins?"
4. **Build moment (about 2 s):**
   - The screen dips to white with an ice-block "thunk" and a snow puff (reuse the pet pop's tweened chunks).
   - The interior swaps to the new shell with furniture remapped.
   - The bird lands at the new `spawn_inside` and plays `emote_cheer`.
   - A toast: "Your home grew! 42 new spaces to decorate."
5. **The grid is visible right away** on the new cells (DecorEditor's `make_grid()`) for about 3 s, then a "Decorate" nudge appears.

## Data and code

### Tier state
- `scripts/home_upgrades.gd` (`class_name HomeUpgrades`), a static helper like `Pets` and `WardrobeShop`:
  - `TIERS = [{id: 1, name, shell: "snow_dome", price: 0}, {id: 2, name, shell: "snow_dome_t2", price: 120}, {id: 3, …, shell: "snow_dome_t3", price: 300}]`
  - `tier()` / `next_tier()` read `user://home_choice.cfg [home] tier` (default 1).
  - `interior_id()` / `exterior_id()` return `homes/<shell>_interior` / `homes/<shell>_exterior`.
  - `buy_next(tree)` spends the coins, saves the tier and migrates the layout (below). It returns false if you can't afford it.
- **Coins:** move the three spenders (`Pets.buy`, `WardrobeShop._pay`, and this new one) onto one shared `Coins.spend(tree, n)` so they can't drift apart.

### Furniture migration (`DecorEditor.remap_to(new_shell)`)
Grids are centred on the room, so a cell's position relative to the room centre is `origin + (cell + 0.5) * 0.5`.
- **Floor and rug items:** convert each old cell to a position relative to the centre, then to a new cell index. Every tier contains the one before it, so the items land in the same spot.
- **Validation:** run `check()` on each remapped item.
  - An item that now overlaps the new doorway's blocked cells moves with `_nearest_valid()`.
  - If nothing fits, the item goes to a "Moved to storage" list shown once in the decorate panel. Furniture is free today, so in practice it's just re-placed.
- **Wall items:** map each to the free new wall slot nearest its old bearing (angle around the centre). Leftovers go to storage.
- **Ceiling items:** map to the nearest free anchor.
- **Saving:** save as `user://home_<new_shell>.json` and keep the old file as a backup.

### Home location (remove the snow-dome assumptions)
- **`AssetPack.dress_home`:** spawn `HomeUpgrades.interior_id()` / `exterior_id()`.
  - Take the wall-ring radius from manifest meta instead of 2.15 / 2.2. The Twin Dome gets one ring per dome (`rings: [{c, r, openings}]`), with gaps for the door and the arch.
  - Keep the yard bounds check. The Twin Dome exterior needs `_YARD_MAX_X` / `_YARD_MIN_Z` re-checked against `home.tscn`, or the yard fence moved.
- **`scripts/home.gd`:** `_SHELL` becomes `HomeUpgrades.interior_id()`.
  - `camera_for_spawn("Inside…")` scales `limit_x/z`, `height` and `distance` from the shell's `size_m`.
  - Tier 3 centres on the union of both domes.
- **Visits:** the owner's published JSON already carries `"shell"`.
  - In `_on_home_layout`, if the shell differs from the one spawned, respawn the interior for that shell before loading the items.
  - `world._share_home` reads the current shell's path instead of the hard-coded one.
- **Live upgrade:** after buying, call a `HomeLocation.rebuild_interior()` that frees `PackProps`' interior and its walk surface, spawns the new shell, re-runs `_seat()`, rebakes navigation and re-targets the inside markers.
  - Then `Net.publish_home(...)` so friends visiting at the time get the new layout. Add a small `home_changed` broadcast so they respawn the shell.
- **Town island dome:** stays tier 1 for now, since it's one shared landmark.
  - Option for later: each client swaps the island model to their own tier, local only. This is cheap, but two friends would see different houses on the same spot.

### Blender (`homes.py`)
- **Parameters:** turn `snow_dome()` into `snow_dome(tier)`, with `DOME_R` / `Ri` as arguments (`dome_blocks(main, roof, R)`, `dome_roof(roof, R)`).
  - Keep `TH`, `HB`, the 0.66 m block width, door and window sizes fixed.
  - Scale only the radius, the ring count (`phi` stays under 63°), the cap blob, the snow base (`snow_base(rx, ry)`) and the dressing positions.
- **Twin Dome:** a second `dome_blocks` at the side-dome centre with R 2.0. Cut both domes' blocks where they intersect. Add a short barrel-vault passage using the entrance-tunnel code.
  - The interior's inside test is `in_main or in_annex or in_arch`.
  - Pass it to `ring_wall` twice with an arch opening, and use `Room(b, inside, hx, hy)`.
- **Assets:** export `snow_dome_t2_exterior` (+ `_roof`), `snow_dome_t2_interior`, and the same for `t3`.
  - Meta: `tier`, `radius_m`, `rings`, `upgrade_of`, `footprint_m`.
  - Render icons for the upgrade card.
- **Checks (Kit Authoring Guide):**
  - `zfight_remaining == 0`.
  - Four-side + top renders into `art/_wip` next to the current dome, at the same scale, to confirm "same igloo, bigger".
  - Headroom and doorway clearance for the 0.9 m bird.
  - Openings framed (the Twin Dome arch uses `arch_fill`).
  - Wall slots facing into the room.
  - Save a lineup close-up to `Renders/Details/homes_dome_tiers.png`.

## Build order

1. **Blender:** parameterise the dome, build tier 2, review the lineup render, then build tier 3.
2. **HomeUpgrades and shared coins:** the tier table, buying, saving the tier.
3. **Home location:** remove hard-coded sizes (radius, camera, shell id, share path). Tier 1 must behave exactly as today.
4. **Furniture migration,** with a test that upgrades a full tier 1 layout and checks nothing is lost.
5. **The upgrade screen and build moment** in the Home HUD.
6. **Visits:** shell-aware loading and the `home_changed` broadcast.
7. **Tier 3,** then tuning prices after a playtest.

## Done when

- Inside your own house, Upgrade shows the next tier, its price and how much space it adds. Buying takes the coins once and survives a restart.
- The new interior has noticeably more cells and wall spots. Every piece of furniture is still there in the same place relative to the room, or listed as moved to storage.
- The exterior in your yard reads as the same snow dome, only bigger. A side-by-side render shows the same blocks, door and windows.
- Visitors see the owner's tier and layout. You can't upgrade someone else's house.
- Walking, sitting, the decorate grid, the camera framing and the exit door all work at every tier.

## Status

**Big Dome (tier 2) is built.**

- **Blender:** `snow_dome(tier)` with the `DOME_TIERS` table in `homes.py`.
  - The build gave **83 usable floor cells (vs 48)**, 7 wall slots (vs 5) and 5 ceiling hooks (vs 3).
  - Exterior 9.1 × 8.8 m, with twin lanterns, a woodpile, two more windows and back firs.
  - Lineup render: `Renders/Details/homes_dome_tiers.png`.
  - Only the two new GLBs and their manifest entries were added. The existing homes GLBs were left as committed.
- **Game code:**
  - `HomeUpgrades` (tiers, price 120, saved in `home_choice.cfg`) and shared `Coins` (pets, wardrobe and upgrades all spend through it).
  - `HomeUpgradeCard`: the Upgrade button in the Home HUD, the card, and the build moment.
  - `DecorEditor.migrate_from`, `world.reload_room`.
  - Tier-aware `home.gd`, `AssetPack.dress_home` and `_share_home`.
- **Town:** the island dome shows your own tier, local only, with its door kept on `Home2Door`.
- **Visits:** visitors load the owner's tier from the shell named in their layout (one reload).
- **Tested** in Godot 4.7.2:
  - Buying (short / exact / maxed).
  - A full layout migrating with every piece in the same spot.
  - The in-game upgrade flow, and the town island swap.
  - Visits were not tested with two clients.

**All six houses now upgrade, and the house choice works.**

| House | Tier 2 | Floor spaces | Wall spots | Price |
|---|---|---:|---:|---:|
| Snow Dome | Big Dome | 48 → 83 | 5 → 7 | 120 |
| A-frame | Long A-frame | 50 → 82 | 5 → 7 | 110 |
| Cottage | Big Cottage | 40 → 76 | 4 → 5 | 120 |
| Treehouse | Big Treehouse | 25 → 43 | 2 → 2 | 80 |
| Lighthouse | Keeper's Lighthouse | 44 → 81 | 2 → 4 | 120 |
| Houseboat | Big Houseboat | 31 → 50 | 3 → 5 | 80 |

- **Blender:** each house function takes a tier, with its own `*_TIERS` table; `variant()` overrides the shared dimension tables while tier 2 builds. Lineup render: `Renders/Details/homes_house_tiers.png`.
- **A-frame interior:** the roof slopes are gone (they covered the room from the game camera) and the Long A-frame's loft stays at the back. This is the one tier 1 GLB that changed.
- **Fixtures:** interiors list `solids` (stove, stairs, trunk) that `AssetPack` turns into colliders. Square rooms get `_wall_box`.
- **Choosing a house:** Change House in the Home HUD opens Choose Home, and moving is free. `home_choice.cfg` keeps `[home] shell` and each type's tier in `[tiers]`; an old `[home] tier` still counts for the dome.
- **Furniture:** every shell keeps its own layout. A shell with no layout starts from the tier below, otherwise from the house you left (`HomeUpgrades.move_source`).
- **Town:** Home2 shows your house and tier, with its way in on `Home2Door` (the treehouse uses its stair foot). The houseboat sits on the snow plot.
- **Tested** in Godot 4.7.2: every house and tier in the real game (room, walls, door, floor, Edit Home, town island), the Choose Home and Upgrade card paths, and an existing tier 2 dome save. Visits with two clients are still untested.

**Not built yet:** Twin Dome (tier 3), the `home_changed` broadcast for friends already inside during an upgrade, and the "moved to storage" list (items with no room are only logged).
