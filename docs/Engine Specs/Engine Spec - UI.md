# Engine Spec: UI

**Built in Godot with real Control nodes and editable text. Never ship the raster mockups as menus.** Sources: [Pengloo Party - UI System and Flows](../Pengloo%20Party%20-%20UI%20System%20and%20Flows.md), [Pengloo Party - UI Mockups](../Pengloo%20Party%20-%20UI%20Mockups.md) and the twelve `UI - …` notes. Those notes already define behaviour, states and known mockup mistakes. This spec adds what the **art pack supplies** for each screen and the hookups the engine must make. Index: [Engine Specs - Index](Engine%20Specs%20-%20Index.md).

## What the art pack provides for UI

| UI need | Asset | Where |
| --- | --- | --- |
| Item cards (wardrobe, inventory, decoration catalogue, café items, fish cards) | 256×256 transparent PNG thumbnail per asset, front three-quarter view, consistent framing. Wearables (torso, back, neck, face) are shown on a neutral grey penguin; hats and held items alone | `Models/<kit>/icons/<asset>.png`. Each manifest entry has an `icon` path. Kits: avatar, room_kit, home_themes, cafe, fishing, interaction_props |
| Penguin preview (setup, wardrobe, player card) | The live rigged `avatar_base` plus clothing GLBs, tinted with `Tints.apply(bird, {"body": color})`, idle clip from `anim_locomotion` | Render in a `SubViewport` with its own camera and light, not a pre-rendered image |
| Body colour swatches | `color_variants` on `avatar/avatar_base` (blue, green, yellow, pink, red, orange, purple, teal, black, white) | Avatar manifest |
| Equip slots and exclusions | `slot` (head, torso, face, neck, back, hand) and `excludes` per item | Avatar manifest |
| Decoration categories, footprints and blocked placement | `placement` meta (layer, footprint, rotations, clearance) plus shell `cells`, `blocked_cells`, `wall_slots`, `ceiling_anchors` | room_kit, home_themes, homes manifests. See [Housing Placement Data](../Art%20Docs/Housing%20Placement%20Data.md) |
| Emote picker poses | The 8 emote clips in `anim_emotes` | Icons for the picker are UI art (flat icons), or capture each clip's key pose in a SubViewport at load |
| Fish result card | `fishing/fish_round`, `fish_slim` and `fish_spiky` icons; tint `body` per species | fishing manifest |
| Map screen | Not provided. The map image must come from the playable level (top-down capture or authored art), never the concept map | Engine and level |

## Hookups per screen group

- **Main menu and entry:** the setup preview uses the live bird. Colour swatches call `Tints.apply` on the preview bird immediately, which is reversible until Continue.
- **Town HUD, map and social:** the contextual action reads the nearest interaction socket (`socket_door`, `socket_seat_*`, `socket_player_*`, `socket_fish_*` and so on) within reach, plus occupancy from the session. Speaker indicators attach above the head socket (`socket_head` + 0.45 m).
- **Wardrobe and inventory:**
  - **Cards:** show `icon`.
  - **Equip:** attaches by `slot` (see [Sockets and Attachments](../Art%20Docs/Sockets%20and%20Attachments.md)) and respects `excludes`.
  - **Body tint:** changes only `tint_body`. The face, belly and equipment are separate materials, so they're unaffected.
  - **Item actions:** Equip for avatar items; "Place in home" for anything with `placement` meta.
- **Home decoration:**
  - **Grid:** only visible while editing; cells come from the shell's `cells`.
  - **Ghost preview:** a translucent copy of the item with an override material (valid = teal outline plus check, blocked = coral plus icon plus reason text).
  - **Blocked reasons:** the cell is in `blocked_cells` ("Keep the doorway clear"), off-mask, overlapping, or on the wrong layer.
  - **Color:** lists `Tints.roles(item)`.
  - **Remove:** returns the item to inventory.
- **Cinema and arcade:** the watch view is a full-screen video `TextureRect`. The in-world screen uses the same texture on `insert_cinema_screen`; mute the world audio while the close view is open, to avoid duplicate sound. The arcade board is a local `SubViewport` game, and the cabinet's `insert_arcade` shows the same viewport texture for spectators.
- **Fishing:** the panel is UI only. World presentation uses the `anim_fishing` clips plus [Engine Spec - Gameplay Effects](Engine%20Spec%20-%20Gameplay%20Effects.md).
- **Sledding, snowballs, basketball:** HUD only. Team identity uses the team badge and foot ring (`interaction_props`) as well as colour. The snowball throw indicator is a cooldown, not ammo.
- **Drawing telephone:**
  - **Canvas:** a Control-based canvas.
  - **World pads:** `drawing_pad` inserts stay blank until reveal, then can show the revealed drawing texture.
  - **Easel:** `easel_display` shows the shared reveal.
- **Settings, controls, accessibility:** prompts read live `InputMap` bindings, so no key is hard-coded from the mockups. Text scale applies to a global `Theme` font size.

## Shared components (build once)

Button (primary teal, secondary, quiet), tab bar, text field with inline error, slider, swatch, item card (icon + name + state), modal, side panel, state panel (loading / empty / error with Retry and Back), toast. Theme colours come from the palette: ivory panel #FAF1DD, navy text #153447, teal #207D85, coral #E86D58. One `Theme` resource holds all of them.

## Done when

- Every screen in the twelve boards exists as Godot scenes using the shared components.
- Item cards show the real `icon` thumbnails, and previews use the live penguin.
- The state and accessibility checklist in [Pengloo Party - UI System and Flows](../Pengloo%20Party%20-%20UI%20System%20and%20Flows.md) passes at the real resolution and at enlarged text size.
