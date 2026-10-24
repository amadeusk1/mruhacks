# Z-Fighting and Clipping

Why textures flicker or poke through, what the build does about it, and what the game still has to watch. Hub: [Art Pipeline](../Art%20Pipeline.md).

## Two different problems

| Problem | Looks like | Handled by |
| --- | --- | --- |
| **Z-fighting** | Two surfaces on the same plane flicker or stripe as the camera moves | Automatic, at build time |
| **Poke-through** | One part sticks out through another (a corner stone through roof tiles, a body through a jacket) | Visual audit from four sides, plus animation poses for clothing |

## Automatic z-fight fixing

Each asset is assembled from many parts in `common.Builder`. Before the parts are welded into one mesh, `fix_coplanar` runs:

1. **Drop duplicates.** A part that exactly repeats another part is deleted. That is always a modelling slip, and it can only flicker.
2. **Find conflicts.** Faces from different parts that face the same way and lie within 1.5 mm of the same plane, whose outlines actually overlap. The overlap is an exact convex-polygon (separating-axis) test on world-aligned axes, so floor tiles with gaps between them don't count.
3. **Colour the conflicts by depth.** The biggest face stays put. Each smaller part's conflicting face grows outward in 4 mm steps to the first depth clear of everything it overlaps. Only that face moves, so a post flush with planks at both top and bottom resolves each end independently.
4. **Cap.** Nothing moves more than 4 steps (16 mm). If no clear depth exists, the part stays put rather than drifting.

Each asset records two custom properties: `zfight_parts_moved` and `zfight_remaining`. `zfight_remaining` is 0 across the whole pack.

**Engine depth precision.** With a 0.1 m near plane, a 24-bit depth buffer resolves about 0.5 mm at 30 m, so 4 mm offsets are safe. Don't set the near plane below about 0.05 m.

## What the build cannot fix (game-side)

- **Between assets.** The fixer only sees parts inside one asset. When the game places assets on the same plane (a rug on a floor, paving under a building's stone base, a poster flat on a wall), keep a few millimetres of offset: rugs at +3 mm, wall art 3 mm off the wall. Or use polygon offset or render order for decals.
- **Skinned clothing.** Clothing and the body are separate meshes. Clothes are shells offset from the body and weighted to the same bones; they are checked in the `waddle`, `sit` and `wave` extreme frames.

## Poke-through audit

Every assembled asset (exteriors, interior shells, prefabs) is rendered close up from azimuths 45°, 135°, 225° and 315° plus top-down, and the renders are reviewed by eye. Problems found and fixed so far:

- **Café:** wall corner stones and timber pegs poked through the roof tiles, and the large side window was covered by solid wall because no opening was cut.
- **Homes (reported by the user):** arched doors and windows sat in rectangular wall openings, showing dark corners above the arch. Every kit is being re-audited for openings that don't match their frames.
- **Cinema lobby:** an early version of the fixer lifted whole floors (fixed by the exact overlap test).

Kit renders used for the audits are in `art/_wip`. Keepers go to `Renders/Details`.
