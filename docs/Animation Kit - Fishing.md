# Animation Kit - Fishing

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Animation Kits - Index](Animation%20Kits%20-%20Index.md)

These are proposed animation requirements and visual key poses, not newly implemented clips. Use the shared modular **penguin** rig; clothing and accessories remain separate. Gameplay decides outcomes; animation presents them.

![Animation Kit - Fishing and Sledding](concepts/Animation%20Kit%20-%20Fishing%20and%20Sledding.png)

## State flow

approach → equip → cast → wait → bite → hook/reel → catch or escape → retry/leave

## Clip inventory

| Clip | Type | Performance |
| --- | --- | --- |
| fish_equip | one-shot | Reach for rod; attach grip without snapping. |
| fish_cast | one-shot | Anticipate, swing, release line, follow through; short body lean. |
| fish_wait | loop | Gentle breathing and flipper adjustment; feet planted. |
| fish_hook | one-shot | Quick surprised tug; transition to reel. |
| fish_reel | loop | Flippers work reel, slight opposing body lean; vary tension. |
| fish_catch / fish_escape | one-shot | Proud display or small disappointed slump, then settle. |
| fish_stow | one-shot | Clear rod and return to idle. |

## Props, events, and checks

Rod grip, reel pivot, rod-tip line endpoint, bobber and fish are separate. Drive the line between rod tip and bobber; bobber dip, ripple and splash use effects. A cast-release event starts the visual cast trajectory; authoritative bite/result state starts reactions. The local vertical-band minigame is UI, not a character clip. Cancel must release the fishing slot and clear line/props. Check rail clearance and nearby players.

Check entry/exit, cancellation, reconnect, outfit clipping, and remote-player presentation. Timing is tuned against responsive gameplay; no fixed duration is approved by the illustration.
