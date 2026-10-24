# Animation Kit - Basketball

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Animation Kits - Index](Animation%20Kits%20-%20Index.md)

These are proposed animation requirements and visual key poses, not newly implemented clips. Use the shared modular **penguin** rig; clothing and accessories remain separate. Gameplay decides outcomes; animation presents them.

![Animation Kit - Snowballs and Basketball](concepts/Animation%20Kit%20-%20Snowballs%20and%20Basketball.png)

## State flow

join position → ready/charge → shoot → follow-through → result → ready/leave

## Clip inventory

| Clip | Type | Performance |
| --- | --- | --- |
| basket_hold | loop | Hold ball with both flippers, slight breathing. |
| basket_charge | blend pose | Small crouch and upward preparation. |
| basket_shoot | one-shot | Lift, extend, release, follow-through. |
| basket_recover | one-shot | Return to planted stance. |
| basket_score / basket_miss | one-shot | Small cheer or shrug; avoid delaying next accepted shot. |
| basket_pickup / dribble / pass / receive | extension | For possession-based play if selected; separate from the shooting-contest baseline. |

## Props, events, and checks

Ball is separate and switches from grip to accepted trajectory at release; rim/net reacts on actual contact. Gameplay decides scores, not net animation. The proposed initial format is shooting practice/contest. Full team basketball remains a separate open extension. Ensure ball does not pass through the face or sleeves; avoid foot skating during optional hop shots.

Check entry/exit, cancellation, reconnect, outfit clipping, and remote-player presentation. Timing is tuned against responsive gameplay; no fixed duration is approved by the illustration.
