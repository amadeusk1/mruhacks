# Animation Kit - Cinema

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Animation Kits - Index](Animation%20Kits%20-%20Index.md)

These are proposed animation requirements and visual key poses, not newly implemented clips. Use the shared modular **penguin** rig; clothing and accessories remain separate. Gameplay decides outcomes; animation presents them.

![Animation Kit - Social Activities](concepts/Animation%20Kit%20-%20Social%20Activities.png)

## State flow

choose film → approach seat → sit → watch → stand/leave

## Clip inventory

| Clip | Type | Performance |
| --- | --- | --- |
| cinema_sit / cinema_stand | one-shot | Reuse shared seat transitions, clear neighboring seats. |
| cinema_watch | loop | Very subtle breathing/blink, eyes toward screen. |
| cinema_snack | optional one-shot | Lift popcorn or drink, then rest; separate prop. |
| cinema_reaction | optional | Small seated emotes, user triggered rather than fake movie analysis. |

## Props, events, and checks

Seat reservation and placement are authoritative. Screen is synchronized media playback, not part of a character animation. Curtain opening, dimming and aisle lights are separate scene effects. Preserve intelligible movement paths; returning to world clears seating/props. Do not animate frequent distracting reactions during films.

Check entry/exit, cancellation, reconnect, outfit clipping, and remote-player presentation. Timing is tuned against responsive gameplay; no fixed duration is approved by the illustration.
