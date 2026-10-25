# Client, UI, Housing and Assets

[Dev Handoff - Start Here](Dev%20Handoff%20-%20Start%20Here.md) · [Pengloo Party - UI System and Flows](Pengloo%20Party%20-%20UI%20System%20and%20Flows.md) · [Pengloo Party - UI Mockups](Pengloo%20Party%20-%20UI%20Mockups.md)

## Client modules — proposed responsibilities

Keep existing useful code. Separate responsibilities rather than rewriting solely to match names: Session/Net adapter; Room/Travel controller; Player controller; Interaction/occupancy client; Activity coordinator; Appearance/asset registry; Housing editor; UI focus/router; Audio/voice adapter; Media adapter; Save client. A disconnect should not require each screen to invent cleanup logic.

UI router owns input focus and one clear back/close path. Text fields, drawing and activity controls suppress world movement. Read prompts from actual input mapping. Menu overlay is local, not a multiplayer pause. Use Godot Control-based layouts and theme resources with responsive anchors/containers; concept PNGs are references, not runtime UI panels.

## Penguin and animation

Preserve the original round penguin silhouette. One base skeleton, body tint and independent clothing/accessory slots; do not merge a penguin with a hat into the avatar asset. Inspect actual clip names/manifests before wiring animation state. Shared locomotion, emotes, sit/stand, hold and reach clips feed activity-specific states. Props use defined sockets and detach at accepted release events. Clothing follows the same skeleton and stable bone mapping.

Test wide sleeves, hoods, hats, robes and backpacks during movement, fishing, seated cinema and throwing. Feet stay grounded; root travel belongs to gameplay/controller unless explicitly authored otherwise. Cosmetic color choices cannot determine snowball teams. See [Avatar Rig and Animation](Art%20Docs/Avatar%20Rig%20and%20Animation.md), [Sockets and Attachments](Art%20Docs/Sockets%20and%20Attachments.md), [Tint System](Art%20Docs/Tint%20System.md).

## Housing editor contract

User chooses a supported shell, then decorates using integer grid cells, quarter turns and valid-cell mask. Follow actual asset footprint data; do not derive dimensions from concept images. Floor, rug, wall, ceiling and tabletop/support placements are separate layers. Validate overlap, supports, exits and interaction clearance on server as well as client.

Editor state: browsing → preview → valid/invalid placement → place; selecting existing object → move/rotate/tint/remove → save. Move cancellation restores old transform. Remove returns to inventory. Undo tracks local operations; final commit uses expected layout revision. A failed save keeps pending edits and shows Retry. A shell change stages a migration preview, then atomically returns non-fitting items to inventory. Owner-only edits are the proposed first policy; visits respect access settings.

## Art integration

Use the catalog and committed manifests rather than filename guesses. Inspect actual origin/scale, mesh count, tint roles, socket orientation, moving parts and animation libraries. Keep GLBs and editable Blender sources; no requirement to run Blender when opening the game. Use the project's Godot import conventions and preserve relevant `.import`/UID metadata. Avoid shipping all concept images and source art in the gameplay export; define export resource scope without deleting source from Git.

Collision should be simple and match visible walkable/blocking shapes. Do not rely on decorative mesh details for sports collisions. Modular paths/walls/roofs need seam tests and cutaway groups. Hide roofs with their trims/lights as appropriate. Use existing art/Godot helpers only after tests confirm compatibility with the pinned engine version.

Effects: named sockets for smoke/steam/splash, child pivots for doors/curtains/controls, per-instance phase for ambient motion, pooled and bounded effects. See [Engine Specs - Index](Engine%20Specs/Engine%20Specs%20-%20Index.md), [Movable Parts and Effects](Art%20Docs/Movable%20Parts%20and%20Effects.md), [World Assembly - Completion Checklist](World%20Assembly%20-%20Completion%20Checklist.md). Audio should cover footsteps, interaction confirmation, doors, throws/hits, fishing bites/catch, sled motion, arcade results and ambient rooms; keep volume buses independent from voice/movie and prevent duplicate movie audio.

## UI implementation coverage

Use the twelve UI boards and their detailed notes. Required refinements include correct selected tab, consistent key prompts, truthful save/connection state, distinct catch results, team labels rather than player-name headings, and Menu rather than Game Paused online. Screen art and placeholder characters are not a new modeling reference. Missing/error/loading variants may reuse components instead of adding entirely separate scenes.

Implement friends/report/home permissions only when their backing services work. Otherwise hide or mark them unavailable; do not display a fake submitted report. Basic voice mute and gameplay exit remain usable regardless of those services.

## Browser client requirement

Support an eventual browser release on the game's own domain. Prove representative assets under the Compatibility renderer early, and test browser audio permissions, input focus, tab suspension and authoritative resynchronization. Do not assume current Forward Plus effects or native voice/media integrations carry over. See [Dev Handoff - Self Hosting and Browser Release](Dev%20Handoff%20-%20Self%20Hosting%20and%20Browser%20Release.md).
