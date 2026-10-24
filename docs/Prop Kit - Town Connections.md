# Prop Kit - Town Connections

Reference: [Prop Kits - Master Plan](Prop%20Kits%20-%20Master%20Plan.md) · [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md)

![Town Connections Prop Kit](concepts/Town%20Connections%20Prop%20Kit.png)

## Existing exports to reuse

Folders: `plaza / world_misc / nature_dock / winter`. Paving, plaza edges, bridge, signpost, mailbox, stairs, rocks and waterfall_step exist.

Existence is verified from filenames only; it does not mean every model is art-approved, rigged, or integrated.

## Remaining kit scope

Matching path corners/junctions, cliff straight/corner/cap modules, stream straights/bends, bridge approach landing and optional snow overlays.

## Authoring and integration

Set a shared seam grid, height increments and traversable slopes before modeling. Paths, river surfaces, collision and decoration separate; no step-sized seams in walking routes.

Keep each reusable piece separate, use recolorable materials where appropriate, reserve clear collision/interaction space, and provide a manifest with footprint, pivot, sockets and material roles. Generated labels and staged assemblies are visual references, not exact implementation instructions. All character scale references must use the original penguin proportions.
