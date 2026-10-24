# Prop Kit - Ambient Effects

Reference: [Prop Kits - Master Plan](Prop%20Kits%20-%20Master%20Plan.md) · [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md)

![Ambient Effects Prop Kit](concepts/Ambient%20Effects%20Prop%20Kit.png)

## Existing exports to reuse

Folders: `buildings / plaza / nature_dock / cinema_auditorium`. Chimney, lights, trees, doors, fountain, curtains, water and screen meshes exist.

Existence is verified from filenames only; it does not mean every model is art-approved, rigged, or integrated.

## Remaining kit scope

Reusable smoke puff effect; foliage wind masks; separate stream/foam/ripple effects; weather particles; emission masks; explicit door/curtain pivots.

## Authoring and integration

Static mesh existence does not prove effect readiness. Audit pivots/material separation and add emitter sockets. See [Animation Kit - Ambient World](Animation%20Kit%20-%20Ambient%20World.md).

Keep each reusable piece separate, use recolorable materials where appropriate, reserve clear collision/interaction space, and provide a manifest with footprint, pivot, sockets and material roles. Generated labels and staged assemblies are visual references, not exact implementation instructions. All character scale references must use the original penguin proportions.
