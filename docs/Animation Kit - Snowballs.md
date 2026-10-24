# Animation Kit - Snowballs

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Animation Kits - Index](Animation%20Kits%20-%20Index.md)

These are proposed animation requirements and visual key poses, not newly implemented clips. Use the shared modular **penguin** rig; clothing and accessories remain separate. Gameplay decides outcomes; animation presents them.

![Animation Kit - Snowballs and Basketball](concepts/Animation%20Kit%20-%20Snowballs%20and%20Basketball.png)

## State flow

ready → move/aim → windup → release → recover; hit → respawn

## Clip inventory

| Clip | Type | Performance |
| --- | --- | --- |
| snow_ready | loop | Hold separate snowball, soft alert posture. |
| snow_aim | blend pose | Flipper aim and modest torso turn over locomotion. |
| snow_throw | one-shot | Readable short windup, release, follow-through. |
| snow_hit | one-shot | Playful recoil and blink, no violent fall. |
| snow_respawn | one-shot | Reappear and settle; protection indicator separate. |
| snow_result | one-shot | Reuse cheer or gentle disappointed emote. |

## Props, events, and checks

At accepted release, hide the held ball and show the gameplay projectile exactly once. Hit puff is a separate pooled effect; it does not determine hits. Preserve chosen body colors; separate team scarf/badge/ring. Ducking pictured in the sheet is optional and must not change hitboxes unless explicitly implemented. Unlimited snowballs in the proposed rules do not require a long pickup animation. Check throws around cover and interruption during respawn.

Check entry/exit, cancellation, reconnect, outfit clipping, and remote-player presentation. Timing is tuned against responsive gameplay; no fixed duration is approved by the illustration.
