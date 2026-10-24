# Player Animation — Emotes

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Player Animation - Cute Movement](Player%20Animation%20-%20Cute%20Movement.md) · [Animation Production Checklist](Animation%20Production%20Checklist.md)

Confirmed direction: cute social emotes using the same modular player rig. The selection and timing below are proposed production targets. The image is a visual reference, not finished animation.

![Player Animation - Emotes](concepts/Player%20Animation%20-%20Emotes.png)

| Emote | Performance | Playback proposal |
| --- | --- | --- |
| Wave | Lean slightly, lift one flipper, give two small waves, settle | One-shot, 1–1.5 seconds |
| Happy bounce | Anticipation dip, small joyful bounce, soft landing | One-shot, 0.8–1.2 seconds |
| Laugh | Eyes smile, tiny rhythmic body bobs, flippers near belly | Short loop with entry and exit |
| Shy | Tuck flippers inward, glance down, little sideways tilt | One-shot, 1.5–2 seconds |
| Cheer | Lift both flippers, open chest, brief celebratory bounce | One-shot, 1–1.5 seconds |
| Sleepy | Slow blink, droop, gentle sleepy nod | Calm loop; keep movement cancellation immediate |
| Surprised | Quick recoil, wide eyes, flippers out, recover | One-shot, 0.7–1 second |
| Little dance | Alternating side steps and flipper sways with a soft bounce | Seamless 2–3 second loop |

Start with wave, happy bounce, and little dance for a useful social set, then add the remaining emotes. This ordering is a proposal, not a restriction on the final set.

## Behavior and compatibility

- Give each emote a clear entry, readable main pose, and exit to idle. Moving cancels an emote promptly; do not lock the player in place for its full duration.
- Keep emotes in place unless a gameplay system explicitly supports displacement. Avoid drifting across room furniture or other players.
- Reuse the base skeleton and attachment system. Test headwear, wide sleeves, long robes, backpacks, and held objects. Temporarily stow a held prop when it conflicts with an emote instead of letting it clip.
- Blinks and expressive eyes may use a separate face layer. Open-beak expressions shown in the sheet are optional rig scope; body language must read without them.
- For multiplayer, a proposed approach is to replicate emote ID and start time rather than individual bone poses. Define interruption and repeat behavior consistently.

## Review checklist

Cute at gameplay distance; understandable without text or particles; recognizable silhouette; no extreme stretching; feet return to the same position; outfit attachments remain stable; transitions are smooth; loops have no visible pop.

Visual made with the built-in image generation tool: eight three-pose social performances on the same uncostumed low-poly bird. Outfits remain separate reusable assets.
