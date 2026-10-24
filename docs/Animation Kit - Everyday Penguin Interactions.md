# Animation Kit - Everyday Penguin Interactions

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Gallery](Gallery.md)

Concept reference only; this sheet does not itself implement models or animation. Generated with the built-in image generation tool.

![Animation Kit - Everyday Penguin Interactions](concepts/Animation%20Kit%20-%20Everyday%20Penguin%20Interactions.png)

## Shared interaction clips

| Sequence | Poses | Reuse and contact rules |
| --- | --- | --- |
| Pick up | Look, crouch, grasp, lift | Attach prop at grasp; avoid reaching through body |
| Carry and place | Hold, waddle, lower, release | Hold layer over locomotion; release to validated surface |
| Sit and stand | Align, settle, seated rest, stand clear | Reuse seat sockets and existing social clips |
| Small steps | Approach, lift foot, transfer weight, settle | Match real stair height; movement controller owns travel |
| Sip and rest | Hold, lift, blink, lower | Optional one-shot; mug stays separate, no face clipping |
| Open and reach | Reach, pull, inspect, close | Drawer moves on its own pivot/slide, flipper follows |

Use the same modular penguin rig as movement and emotes. Hats, clothes and held props remain interchangeable. Review the widest sleeves, hood, robe and backpack. Do not replace existing compatible sit, hold or reach clips; extend them only where the contact poses require it.

These are optional interaction concepts, not confirmation of free object carrying, inventory storage, thirst, or a new stair mechanic. Housing can retain instant grid placement; a decorative gesture must not delay it. For cancellation, restore the prop to the last valid state and release any seat/interaction reservation.

The sheet uses the original avatar turnaround as its character reference. Preserve that round penguin silhouette and short flippers; exaggerated storyboard reach must be adapted to the actual rig. Related: [Player Animation - Cute Movement](Player%20Animation%20-%20Cute%20Movement.md), [Player Animation - Emotes](Player%20Animation%20-%20Emotes.md), [Player Housing - Grid Decoration](Player%20Housing%20-%20Grid%20Decoration.md).
