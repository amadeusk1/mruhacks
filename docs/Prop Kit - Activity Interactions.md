# Prop Kit - Activity Interactions

Reference: [Prop Kits - Master Plan](Prop%20Kits%20-%20Master%20Plan.md) · [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md)

![Activity Interaction Prop Kit](concepts/Activity%20Interaction%20Prop%20Kit.png)

## Existing exports to reuse

Folders: `fishing / winter / arcade / avatar`. Rod, bobber, fish, sled, flags, ready pads, snowball, duo cabinet already have exported counterparts.

Existence is verified from filenames only; it does not mean every model is art-approved, rigged, or integrated.

## Remaining kit scope

Start light, checkpoint marker, finish timer, team badge, optional catch stand, snack/drink props, reservation marker. Reuse existing models wherever possible.

## Authoring and integration

Fishing line endpoint is a socket at rod tip, not the decorative mooring post pictured. Keep countdown/sign text in engine. Checkpoints never put a solid rope across the sled route. Projectiles, props and results remain separate. Catch stands/snacks are optional polish.

Keep each reusable piece separate, use recolorable materials where appropriate, reserve clear collision/interaction space, and provide a manifest with footprint, pivot, sockets and material roles. Generated labels and staged assemblies are visual references, not exact implementation instructions. All character scale references must use the original penguin proportions.
