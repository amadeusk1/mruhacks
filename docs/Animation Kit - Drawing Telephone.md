# Animation Kit - Drawing Telephone

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Animation Kits - Index](Animation%20Kits%20-%20Index.md)

These are proposed animation requirements and visual key poses, not newly implemented clips. Use the shared modular **penguin** rig; clothing and accessories remain separate. Gameplay decides outcomes; animation presents them.

![Animation Kit - Social Activities](concepts/Animation%20Kit%20-%20Social%20Activities.png)

## State flow

sit → prompt/thinking → draw → guess → submitted wait → reveal → stand

## Clip inventory

| Clip | Type | Performance |
| --- | --- | --- |
| sketch_sit / sketch_stand | one-shot | Reuse seated entry/exit with table alignment. |
| sketch_think | loop | Tilt and look at pad; keep public expression generic. |
| sketch_draw | loop | Small pencil strokes and intermittent glances. |
| sketch_wait | loop | Pencil rests after submission. |
| sketch_reveal | one-shot | Laugh, surprise or happy bounce constrained to seat. |

## Props, events, and checks

Pencil, pad, paper and cup remain separate props. Private drawings/prompts must not appear on public world pads before reveal; use generic scribbling. Reveal content is synchronized by the activity, not inferred from gestures. Table sockets support configurable seats. Stop drawing when submitted; on leave remove tool and restore movement.

Check entry/exit, cancellation, reconnect, outfit clipping, and remote-player presentation. Timing is tuned against responsive gameplay; no fixed duration is approved by the illustration.
