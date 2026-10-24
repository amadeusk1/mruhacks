# Animation Kit - Sledding

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Animation Kits - Index](Animation%20Kits%20-%20Index.md)

These are proposed animation requirements and visual key poses, not newly implemented clips. Use the shared modular **penguin** rig; clothing and accessories remain separate. Gameplay decides outcomes; animation presents them.

![Animation Kit - Fishing and Sledding](concepts/Animation%20Kit%20-%20Fishing%20and%20Sledding.png)

## State flow

mount → ready/countdown → ride/lean → brake → finish → dismount or reset

## Clip inventory

| Clip | Type | Performance |
| --- | --- | --- |
| sled_mount | one-shot | Step onto sled, settle into seat socket. |
| sled_ready | loop | Small eager bob, grip rope. |
| sled_ride | loop | Low tucked posture with subtle bumps. |
| sled_lean_left / sled_lean_right | blend poses | Lean with steering; keep seated hips and grip. |
| sled_brake | one-shot | Lean back, feet forward, controlled snow spray. |
| sled_finish / sled_dismount | one-shot | Settle, step clear, optional shared cheer. |

## Props, events, and checks

Sled root travels on the course; penguin animation stays relative to its seat. Rope, runner contact snow and trails remain separate. Start time and race progress drive presentation. Do not use a cheer to delay finish scoring. Reset removes trails and places both sled and penguin at a safe point. Race format and crashes are still design choices; no crash mechanic is implied.

Check entry/exit, cancellation, reconnect, outfit clipping, and remote-player presentation. Timing is tuned against responsive gameplay; no fixed duration is approved by the illustration.
