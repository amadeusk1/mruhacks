# Prop Kits - Master Plan

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Gallery](Gallery.md) · [Models](../Models) · [Animation Kits - Index](Animation%20Kits%20-%20Index.md)

Initial audit found 295 GLB exports across 16 folders. The commit snapshot includes 310 GLBs across 19 folders, including newly available locomotion, emote and social animation exports, plus `Models/all_assets.blend`. Existing files are preserved as current work, not certified final assets. **Penguins** remain the character direction. No images were remade after the user requested keeping them.

## Full game kit coverage

| Kit | Existing model folders | Concept coverage | Remaining scope / checks |
| --- | --- | --- | --- |
| Avatar and wardrobe | avatar | 01, 02, 09 sheets; separate hats/clothes/accessories | Original sheet 10 missing from saved files; do not recreate without request. Check rig/outfit clipping. |
| Cafe | cafe + plaza | 03–04 sheets; counter, display, coffee station, mugs, tables | Optional separate pastries, plates, takeaway cups and coffee steam; functional inserts and sockets. |
| Cinema exterior/lobby/auditorium | cinema + cinema_lobby + cinema_auditorium | 12–14 sheets plus movie scenes | Separate snacks and drink props, reservation markers; screen playback, door/curtain state and aisle effects. |
| Arcade | arcade | 15 sheet and social scene; solo and duo cabinet | Verify two-player control stations, independent screen/control pieces; optional token as separate pickup only if gameplay needs it. |
| Fishing | fishing + avatar | 17 sheet; rod, fish, bobber, docks, bucket | Connected line, line endpoints, bobber/ripple/splash effects; optional catch display. |
| Sledding | winter | 16 sheet; sled, slopes, gate, flags | Checkpoint/start-light/timer concepts; test stopping area and safe dismount. |
| Snowball arena | winter | 18 sheet; cover, flags, snowball, ready pads, arena | Team badge/ring, score display, hit/respawn/protection effects; preserve balanced traversable arena layout. |
| Basketball | activities | New dedicated basketball sheet | See [Prop Kit - Basketball](Prop%20Kit%20-%20Basketball.md). |
| Drawing telephone | activities | New dedicated drawing-club sheet | See [Prop Kit - Drawing Club](Prop%20Kit%20-%20Drawing%20Club.md). |
| Player homes | buildings + cottage + home_themes | House variants/interiors and new shell sheet | See [Prop Kit - Modular Houses](Prop%20Kit%20-%20Modular%20Houses.md). |
| Decoration | room_kit + home_themes | 11 sheet, home decor sheet and interior personalities | Optional curtains, clocks, tabletop food, cushions, storage variants; grid footprints/support slots for every item. |
| Plaza and waterfront | plaza + nature_dock + world_misc | 05–08 sheets and map | See [Prop Kit - Town Connections](Prop%20Kit%20-%20Town%20Connections.md); inspect cliff/stream seams and elevation links. |
| Ambient world | multiple kits | New animation and effect component sheets | See [Prop Kit - Ambient Effects](Prop%20Kit%20-%20Ambient%20Effects.md); effects are not implemented by a static prop catalog. |

## New detailed kit notes

- [Prop Kit - Basketball](Prop%20Kit%20-%20Basketball.md)
- [Prop Kit - Drawing Club](Prop%20Kit%20-%20Drawing%20Club.md)
- [Prop Kit - Activity Interactions](Prop%20Kit%20-%20Activity%20Interactions.md)
- [Prop Kit - Ambient Effects](Prop%20Kit%20-%20Ambient%20Effects.md)
- [Prop Kit - Modular Houses](Prop%20Kit%20-%20Modular%20Houses.md)
- [Prop Kit - Town Connections](Prop%20Kit%20-%20Town%20Connections.md)

## Delivery priorities

1. Reuse and inspect existing models before creating duplicates. Fill playable interaction gaps first: attachment/seat points, controls, ball/line/projectile separation, and clear collision.
2. Build missing structural families: homes and world path/cliff/stream connections, using measured shared seams and valid floor masks.
3. Add ambient effects and optional set dressing after functional clearance works. A café menu, cinema poster, timer and scoreboard use replaceable inserts, not fixed lettering meshes.

Each model needs stable ID, source, export, dimensions, pivot, collision plan, attachment/interaction sockets, tint roles, footprint/placement layer, moving-part names, and preview. Each effect needs emitter position, bounds, lifetime/loop behavior, trigger, cleanup, distance limits and reduced-motion behavior. Test at gameplay camera scale against the original mockups. A new concept sheet is not a completed model kit.

## Visual interpretation notes

Generic bird motifs and small perched birds in the latest generated sheets are retained image content, not a change to penguin avatars. The house sheet's structural assembly is an authoring guide, not confirmation of player wall-building. The interaction sheet's line anchor post is decorative; the fishing line must attach to the rod tip. The drawing pad stays blank publicly until reveal. Keep original design brief unchanged and treat these notes as later clarifications.
