# World Assembly - Completion Checklist

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Prop Kits - Master Plan](Prop%20Kits%20-%20Master%20Plan.md) · [Animation Kits - Index](Animation%20Kits%20-%20Index.md)

This is an integration checklist, not a list of additional game mechanics. These invisible pieces matter as much as more decorative models. Items remain unchecked until verified in the actual game.

## Traversal and placement

- [ ] Path, bridge, stair, shoreline and cliff seams meet at consistent heights.
- [ ] Walkable collision agrees with visible surfaces; water and cliff edges have deliberate boundaries.
- [ ] Doorways, seat approaches, fishing spots and sports lanes fit the largest supported outfit.
- [ ] Valid spawn and recovery locations do not intersect props, walls, water or occupied slots.
- [ ] NPC navigation, if used, follows the same safe routes; decorative clutter does not fragment routes.
- [ ] Home furniture footprints and wall/surface/ceiling layers match their saved placement data.
- [ ] Decoration cannot block the only exit or required interaction reach.

## Camera and visibility

- [ ] Roofs, ceilings, beams and matching trims hide together for cutaway views.
- [ ] Tall signs, trees and dividers do not obscure the penguin at the gameplay camera angle.
- [ ] Main destinations read without relying on body color, team color, or a small pictogram alone.
- [ ] Sign/map inserts reflect actual connected destinations and readable labels.

## Interaction plumbing

- [ ] Seats, controls, doors, tool grips and effect sockets have stable names and orientation.
- [ ] Shared cabinet has two independent player stations; all activities have a clean exit.
- [ ] UI focus, movement, camera and occupied slot are restored after cancel, leave or disconnect.
- [ ] No decorative sign or ladder promises an interaction that is absent.
- [ ] Projectile release, hit effects and scores are driven by accepted gameplay events.

## Ambient and rendering

- [ ] Smoke, steam, ripple, snow spray and glow emit from the right location.
- [ ] Indoor rooms suppress outdoor snow and inappropriate exterior effects.
- [ ] Effects have bounded lifetime, emission limits, visibility culling and reduced-effects behavior.
- [ ] Water, glass, foam and smoke render without severe sorting artifacts or coplanar flicker.
- [ ] Repeated props use shared resources; collision and lighting costs stay modest.
- [ ] Ambient sound loops, if added, have distance limits and stop when their room unloads.

## Asset readiness

- [ ] Existing exports are reused before duplicate geometry is built.
- [ ] A concept image, static model, animated model and working gameplay feature have distinct status.
- [ ] Models retain editable source, manifest, export and preview.
- [ ] Required map coverage is reviewed before producing more optional décor variants.

Prioritize readable routes, complete interaction states and seam fixes before decorative radiators, extra trim variants or additional food props. All avatars remain modular penguins matching the original turnaround.
