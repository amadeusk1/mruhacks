# Animation Production Checklist

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Gallery](Gallery.md) · [Player Animation - Cute Movement](Player%20Animation%20-%20Cute%20Movement.md) · [Player Animation - Emotes](Player%20Animation%20-%20Emotes.md)

Planning checklist only: unchecked items are not claimed to be implemented. This inventory covers the concept activities; confirm each feature's gameplay scope before producing all its clips.

## Shared player foundation

- [ ] Shared skeleton, clothing skinning convention, and rigid accessory attachment points
- [ ] Idle breathing and occasional blink/curious variation
- [ ] Waddle walk loop
- [ ] Bouncy run loop
- [ ] Responsive starts, stops, and turns
- [ ] Hop and landing, if gameplay uses hopping
- [ ] Sit entry, seated idle, and stand exit for chairs/cinema seating
- [ ] Generic reach/interact and held-item poses
- [ ] Wave, happy bounce, laugh, shy, cheer, sleepy, surprised, and little dance

## Activity-specific clips

| Activity | Animation candidates | Shared or separate pieces |
| --- | --- | --- |
| Fishing | Cast, hold/wait, reel, catch celebration | Rod grip; line, bobber, ripple, and fish motion handled separately |
| Sledding | Mount, seated ride, left/right lean, brake, dismount | Bird and sled remain separate assets |
| Snowballs | Gather/ready, aim, throw, small hit reaction | Spawn/release snowball at a defined animation event; separate snow puff |
| Basketball | Hold, dribble, shoot/pass, receive | Ball travel and possession handled by gameplay |
| Arcade | Enter play pose, flipper button taps, exit | Cabinet and screen feedback separate from bird |
| Drawing | Seated/standing draw loop, tool grip | Tool attachment and drawing surface separate |
| Cinema | Seated watch idle; optional snack gesture | Reuse shared sitting; optional popcorn prop |
| Home decoration | Optional place/confirm gesture | Grid placement must work without waiting for a character gesture |

## World and prop motion

- [ ] Doors: open/close pivots and interaction timing
- [ ] Water/ripples: shader or effects animation rather than skeletal clips
- [ ] Lanterns/signs/screens: subtle light and screen effects
- [ ] Trees, flags, curtains: restrained optional sway
- [ ] Fountain, snow impacts, and celebration effects: separate effects assets
- [ ] Interactive furniture: define movable parts only where gameplay needs them

## Delivery and acceptance

Suggested clip names include `idle`, `walk`, `run`, `sit_enter`, `sit_idle`, `sit_exit`, and `emote_wave`. Final naming should follow the game's actual import convention.

Deliver editable source, exported clips, loop flags, durations, attachment requirements, and any gameplay event markers. Review in Godot at the real camera scale and movement speed. Check contacts, loop seams, transitions, interruptions, multiplayer timing, and clipping across representative outfits. The generated sheets are art direction references; they are not rig-ready animation data.

Housing requirements are recorded separately in [Player Housing - Grid Decoration](Player%20Housing%20-%20Grid%20Decoration.md), [Player Housing - Shape and Interior Concepts](Player%20Housing%20-%20Shape%20and%20Interior%20Concepts.md), and [Player Housing - Decoration Prop Catalog](Player%20Housing%20-%20Decoration%20Prop%20Catalog.md).

## Expanded activity and world kits

- [Animation Kits - Index](Animation%20Kits%20-%20Index.md)
- [Prop Kits - Master Plan](Prop%20Kits%20-%20Master%20Plan.md)
