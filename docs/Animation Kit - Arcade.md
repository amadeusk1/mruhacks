# Animation Kit - Arcade

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Animation Kits - Index](Animation%20Kits%20-%20Index.md)

These are proposed animation requirements and visual key poses, not newly implemented clips. Use the shared modular **penguin** rig; clothing and accessories remain separate. Gameplay decides outcomes; animation presents them.

![Animation Kit - Social Activities](concepts/Animation%20Kit%20-%20Social%20Activities.png)

## State flow

approach → claim station → ready → playing → results → exit

## Clip inventory

| Clip | Type | Performance |
| --- | --- | --- |
| arcade_enter | one-shot | Align to assigned control station. |
| arcade_ready | loop | Flippers hover at controls. |
| arcade_play | loop | Small joystick nudges and button taps. |
| arcade_result | one-shot | Reuse cheer/laugh or shrug. |
| arcade_exit | one-shot | Release controls and step clear. |

## Props, events, and checks

One shared cabinet supports two explicit stations; each penguin has separate grip points. Buttons/joysticks are movable props. Screen gameplay is a live render/UI, never a baked animation of scoring. Keep world-visible busy state even when local overlay opens. No emote may steal the other slot. Puck Rally is a proposed genre; decorative screen art is not a genre decision.

Check entry/exit, cancellation, reconnect, outfit clipping, and remote-player presentation. Timing is tuned against responsive gameplay; no fixed duration is approved by the illustration.
