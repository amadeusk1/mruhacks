# Game Design Context for Codex

**Project:** Working title undecided; a cozy multiplayer social world with customizable bird characters.

**Context date:** October 24, 2026.

**Initial constraint:** A 36-hour hackathon. Preserve the full product vision below while building practical, small versions of the activities.

**Visual references:** The project owner has already supplied the concept images to Codex. Use those images alongside this document. This file explains the intended experience, gameplay, visual rules, and how the systems connect. It does not contain image-transfer instructions.

## 1. How to interpret this brief

There are three different kinds of statements in this document:

- **Confirmed direction:** Features or preferences the owner explicitly requested.
- **Established visual direction:** The design developed through the supplied concept images. Preserve its identity while making the layout and interactions work in an actual game.
- **Proposed prototype default:** A concrete way to implement an otherwise unspecified detail. These defaults let development proceed, but they are not claims that the owner approved every number, control binding, rule, or technology.

The owner's later instructions take priority. Keep useful existing implementation and repository conventions. Inspect the actual repository before choosing an engine, framework, networking library, or persistence solution; none was selected in this design conversation.

This conversation produced concepts and design decisions. It did not establish a working game, live media-server integration, deployed backend, or finished 3D model pack. Verify the repository's actual state rather than assuming a feature exists because it appears in an image.

Text inside concept images, including movie names, connection statuses, scores, usernames, and button bindings, is illustrative unless this document says otherwise. The images establish a visual target, not exact dimensions or collision geometry.

### What the owner wants at a glance

Build a small, welcoming world where friends can walk around as customized characters, talk to nearby people, enter places together, and do activities without leaving the game. The point is the feeling of inhabiting a place with friends: choosing a movie, sitting next to someone, playing a cabinet together, fishing while chatting, having a snowball match, shooting baskets, or laughing through a drawing-telephone reveal.

The user initially considered a Club Penguin-inspired project. The selected visual direction is **low-poly diorama**. Preserve the approachable social structure and expressive customization while creating original characters, assets, UI, and branding.

## 2. Confirmed requests and decisions still open

| Area | Confirmed request | Details not yet fixed by the owner |
| --- | --- | --- |
| Overall game | Club Penguin-inspired multiplayer social world, initially for a 36-hour hackathon | Final name, engine, platform, team size, deployment target |
| Visuals | Low-poly diorama style; model concepts that can be recreated later | Exact polygon budgets, camera controls, final palette values |
| Identity | Customizable items, clothes, and character appearance | Final equipment slots, inventory system, unlock rules |
| Cinema | Walk into an in-game theatre, browse a connected Plex or Emby-style server, choose a movie with friends, and watch together | First provider, playback authority, public versus private screenings, voting rules |
| Voice | Proximity chat in the world | Distance curve, push-to-talk default, voice provider, detailed room rules |
| Arcade | An arcade building; solo play; two people playing the same arcade game at one cabinet | Arcade genres, competitive versus cooperative modes, exact controls |
| Fishing | A real fishing minigame, with a Stardew-inspired feel | Fish roster, precise difficulty, rewards, progression |
| Sledding | A sledding activity | Time trial versus race, player count, exact course rules |
| Snowballs | Snowball fights arranged in a way that makes sense spatially and mechanically | Team size, scoring, round length, respawn rules |
| Basketball | Basketball integrated into the world | Shooting contest versus live possession-based basketball |
| Drawing telephone | Integrated Gartic Phone-type games | Player count, timers, drawing tools, exact round structure |
| Personal spaces | Cottages, customizable rooms, and furniture are established in the concept work | Housing ownership, visitors, placement rules, persistence depth |

The specific arcade game, snowball rules, basketball format, and drawing-game timers later in this file are **proposed defaults**. Keep every requested activity represented in the plan. A reduced hackathon implementation should be identified as such rather than silently redefining the full vision.

## 3. Experience pillars

### 3.1 A place friends inhabit

The world should feel like a shared location. Players arrive, see other people, recognize their outfits, walk toward them, and discover what they are doing. Buildings and activities should be physically reachable, with clear entrances and readable interaction points.

An activity should usually follow this loop:

1. See the activity and the people using it.
2. Walk over.
3. Join, queue, spectate, or start a solo session.
4. Play while your avatar remains visibly present.
5. Finish or leave.
6. Regain normal movement in the same social world.

### 3.2 Shared activities give people a reason to stay

The movie theatre is a particularly clear social anchor: friends show up for movie night, choose something together, sit down, and then wander to another part of town afterward. The arcade, fishing dock, court, snow activities, and drawing table provide other ways to spend time together.

### 3.3 Identity comes from recognizable characters and belongings

Body colors, hats, clothes, accessories, and eventually decorated personal rooms should make players recognizable. A small common character body with distinct attachments is the preferred production approach.

### 3.4 A compact world should feel busy and understandable

Keep important destinations close enough that a small group can encounter one another. A giant empty island is not necessary. Use strong building silhouettes and visible paths so players can orient themselves without studying a map.

### 3.5 Low-pressure participation

Players should be able to hang out, spectate, sit, talk, and leave an activity without being trapped in a competitive progression system. Cosmetic rewards and collections can support the experience, but a large economy is not an established requirement.

## 4. World layout and navigation

### 4.1 Established layout

The latest world concept is a compact waterfront settlement with a snowy hillside. The central plaza stays mostly clear of snow; roofs, rocks, vegetation, and outer activity areas have snow caps. Warm windows and lanterns contrast with cool water and snow.

| Place | Position and purpose |
| --- | --- |
| Main plaza | Central meeting space with fountain, benches, tables, lamps, and clear walking routes |
| Cinema | Major landmark facing the plaza; obvious marquee and entrance |
| Arcade | Near the cinema, with a readable sign and cabinets visible through the entrance |
| Café | Opens onto the plaza; seating and a low-pressure social interior |
| Cottages | Along the edge of town; personal-space and furniture direction |
| Fishing dock | At the waterfront, connected directly to the plaza by a short path |
| Sledding hill | On the snowy hillside, with a start, descent, finish, and separate return route |
| Snowball arena | A separate level clearing near the hillside; bounded play area and outside waiting space |

### 4.2 New spaces to integrate

**Basketball:** A compact court off a main path, with room for participants and spectators. The initial shooting-contest version can use a half-court and one hoop. Keep snowbanks outside the playable court.

**Drawing telephone:** A communal table in a social room or small pavilion, with players visibly seated together. Reusing a café side room or arcade-adjacent lounge is a proposed shortcut. A new large building is not required to express the activity.

### 4.3 Layout requirements

- Entrances, exits, stairs, and walkable ground must be visually clear.
- Keep the sled course, its return path, and the snowball arena separate.
- Keep snowball spectators and waiting players outside the match boundary.
- Preserve clear space around arcade cabinets, theatre seating, fishing spots, and court positions.
- Decorative objects should not create accidental one-person bottlenecks.
- Visible cover must agree with collision and projectile blocking.
- Indoor and outdoor room boundaries should be explicit for both navigation and voice routing.
- Leave sufficient room for two players to stand side by side at a shared cabinet.

### 4.4 Camera direction

The concept images use an elevated three-quarter or isometric presentation. A mostly fixed or gently following camera is a proposed starting point because it preserves the diorama composition.

The player must remain readable behind foreground walls and scenery. Use camera-aware hiding, fading, or cutaway geometry where necessary. A building interior can be a separate room scene while still feeling connected to its exterior.

Activities may use closer framing or a large local gameplay overlay. A readable minigame takes priority over maintaining a distant world camera throughout every interaction.

## 5. Visual style bible

### 5.1 Selected style

Use the **low-poly diorama** option from the original visual comparison. The other comparison panels were alternatives, not additional styles to mix into the world.

The visual language is:

- Chunky, toy-like 3D forms with broad visible facets.
- Mostly matte, simple materials and restrained surface detail.
- Soft, warm lighting with readable shadows.
- Friendly proportions and clear silhouettes at gameplay distance.
- Compact buildings with cream walls, coral or terracotta roofs, teal doors, and honey-colored wood.
- Cool turquoise water, pale blue-white snow, and warm amber lamps.
- Props designed from reusable simple shapes.

Avoid turning the main world into realistic architecture, smooth clay sculpture, voxel blocks, paper cutouts, or a pixel-art environment. An arcade screen can use deliberately flat or pixel-like game graphics while its cabinet and surrounding world remain in the chosen 3D style.

### 5.2 Palette guidance

Use the supplied images as the primary color reference. The following are **suggested starting swatches**, not colors measured from the images:

| Role | Suggested color |
| --- | --- |
| Cream plaster | `#F3E2C5` |
| Coral roof and upholstery | `#E86D58` |
| Teal doors and accents | `#207D85` |
| Honey wood | `#BC874E` |
| Deep navy UI and dark interiors | `#153447` |
| Snow | `#EEF4F7` |
| Turquoise water | `#69C9D8` |
| Warm light | `#FFC76B` |

Preserve contrast between characters, snow, water, flooring, and interaction highlights. Team affiliation should use more than body color so customized avatars stay recognizable.

### 5.3 Architecture and environmental assets

The model-reference sheets establish a modular approach:

- Separate building shells, roofs, doors, windows, signs, and awnings.
- Reused lanterns, benches, tables, planters, bins, fences, and paving.
- Trees assembled from simple trunks and faceted canopy masses.
- Reused straight and corner dock sections, posts, steps, and water-edge pieces.
- Cinema shell, stepped facade, marquee, double doors, poster frames, and entrance stairs.
- Repeated auditorium chairs, risers, wall panels, curtains, lights, and speakers.
- Repeated arcade cabinet geometry with different colors and screen art.
- Snowbank and snow-wall modules shared between winter areas where appropriate.

Signs, posters, cabinet screens, and movie artwork should generally be flat graphic inserts. Every letter, roof tile, popcorn kernel, and decorative detail does not need an individual mesh.

### 5.4 UI styling

Use readable, compact UI that fits the friendly world: warm ivory panels, dark navy text, teal primary controls, coral accents, rounded corners, and simple icons.

Keep most of the world visible during ordinary play. When an activity needs a large canvas or game board, give it enough space. Fishing should not be reduced to an unreadably small meter, and an arcade game should not be playable only on a tiny distant screen.

World prompts should be contextual. Indicate who is speaking, whether an activity is occupied, and how to join or leave. Avoid turning the normal game view into a dashboard full of permanent panels.

## 6. Characters, clothes, items, and personal spaces

### 6.1 Base character

The established characters are original squat bird/penguin-like avatars with:

- Rounded, visibly faceted bodies.
- Cream face and belly patches.
- Small dark eyes.
- A short orange beak and small orange feet.
- Short flippers rather than human hands.
- A friendly silhouette that remains readable while wearing clothes.

The reference characters include a blue bird with a red beanie, a green bird with a frog-eye hood, a yellow bird with an explorer hat, and a pink bird with a purple star wizard hat. These are visual examples and reusable outfit combinations, not four fixed identities that every player must use.

### 6.2 Customization direction

Support body-color selection and modular equipment. Suggested slots are head, torso, face, neck, back, and held item. Exact slots are an implementation choice.

Existing concepts include:

- **Head items:** red beanie, frog hood, explorer hat, wizard hat, bucket hat, headphones.
- **Clothes:** hoodie, varsity jacket, raincoat, overalls, striped shirt, puffer vest, café apron, wizard robe.
- **Accessories:** backpack, rolled-top backpack, cross-body bag, glasses, scarf, mug, fishing rod, watering can, wand.
- **Color variants:** reuse geometry with different material colors where possible.

Clothes should fit the same base body and animation system. Decide simple compatibility rules for overlapping items. For example, a head-covering hood and a large hat may be mutually exclusive, and an activity rod may temporarily replace a cosmetic held item.

Equipment changes should be visible to other players. Character identity should persist across room changes and activity transitions. The exact account and long-term persistence model remains open.

### 6.3 Animation priorities

Start with a small useful set: idle, walk/waddle, turn, sit, wave, and a basic interaction pose. Add activity-specific poses such as casting, throwing, holding a sled, using a cabinet, and shooting a basketball as needed.

Characters should fit chairs and control stations. Make the seat, hand/flipper targets, and activity anchor positions agree with the actual model scale.

### 6.4 Personal spaces

Cottage and room concepts already show the direction for personal decoration. Reuse one room shell with different furniture arrangements and color schemes.

The furniture concepts include armchairs, sofas, tables, cube shelves, beds, lamps, rugs, framed posters, plants, and small arcade cabinets. Cozy café, night arcade, and plant-room arrangements are examples.

Ownership, visiting permissions, furniture inventory, free placement versus grid placement, and persistent storage are still design decisions. A simple snap-based placement system is a proposed first implementation if housing is included in the playable build.

## 7. Common interaction and session behavior

All activities should use compatible conventions rather than becoming unrelated mini-apps.

### 7.1 Suggested interaction flow

`walking -> nearby prompt -> joining/ready -> playing -> results or leaving -> walking`

Use explicit participation states. Distinguish players, spectators, and people waiting for the next round. Reserve seats or positions atomically so two users cannot claim the same slot.

### 7.2 Input behavior

Suggested bindings in the mockups are WASD for movement, an interaction key such as E, Escape to leave or close, and a configurable push-to-talk key such as V. These are defaults, not owner-mandated bindings.

When an activity or text field has focus, its inputs must not also move the world avatar. Drawing, typing a prompt, controlling a paddle, and operating the fishing bar should all acquire and release input focus correctly.

Every activity needs an obvious way to leave. Closing an overlay must restore camera, movement, cursor, sound, and voice state correctly.

### 7.3 Presence

Keep the avatar visibly stationed at the cabinet, dock, table, seat, or court position during an activity. Nearby friends should be able to tell what that person is doing.

A player should not occupy multiple activities at once. Release occupancy when a player leaves, times out, changes rooms, or disconnects. Where reconnection is supported, restore the correct session state rather than creating a duplicate participant.

### 7.4 Shared versus private information

Shared state includes occupied slots, match phase, score, timer, readiness, visible avatar actions, and public results.

Private state includes another person's unrevealed drawing-telephone prompt or drawing, personal media credentials, and local device preferences. Do not broadcast hidden information merely because the UI would conceal it.

## 8. Proximity voice chat

### Confirmed request

Players should be able to talk to nearby people in the game. Approaching someone should make conversation possible; moving away should reduce how audible they are.

### Proposed first behavior

- Use distance-based volume within a shared audio room.
- Separate outdoor and indoor spaces so a player outside the theatre does not hear every conversation inside it.
- Begin with explicit room boundaries and a simple distance curve. Detailed wall-by-wall acoustic simulation is optional.
- Show a small speaking indicator above an avatar and clear local microphone/mute state.
- Provide self-mute, mute-all/deafen, per-player mute, and a voice-volume control.
- Let people play even if they deny microphone access or have no microphone.
- Treat the push-to-talk key shown in concepts as configurable.

### Activity-specific behavior

| Context | Proposed behavior |
| --- | --- |
| Plaza, dock, café | Normal room-local proximity voice |
| Shared arcade cabinet | Nearby friends remain audible; two participants can talk during play |
| Basketball and winter activities | Normal local voice or a small activity channel if distance makes play awkward |
| Cinema lobby | Normal conversation while choosing a film |
| Cinema auditorium | Independent movie and voice volume, plus a quick mute-voices action |
| Drawing table lobby and reveal | Participants can talk together |
| Drawing table private rounds | Proposed quiet mode to avoid revealing secret prompts and guesses |

The cinema's exact whisper, party-voice, and ducking behavior is still open. Avoid duplicate audio output when rendering a movie both as a world screen and in a close viewing interface.

Preserve the user's microphone preference across activity transitions. Leaving a quiet drawing round must not force an intentionally muted microphone on.

## 9. Cinema and shared movie watching

### 9.1 Required experience

Friends meet in town, walk into the cinema, browse a connected personal media library, choose a film, enter the auditorium, sit together, and watch the same movie. Afterward they can return to the plaza or another activity.

The owner mentioned **Emby or Plex, or a similar server**. Choose the first actual integration deliberately; do not assume both providers must ship simultaneously.

### 9.2 Physical spaces

**Exterior:** Cream stepped facade, coral trim, bright marquee, teal double doors, poster frames, and an obvious place to gather outside.

**Lobby:** Concession counter, popcorn machine, seating, physical movie posters, a browsing kiosk, and auditorium doors. The browsing interface should open from an in-world interaction.

**Auditorium:** Large rectangular screen, coral seats, teal walls, dark stepped floor, simple curtains, speakers, and low aisle lights. Seats face the screen with clear sightlines and a visible path to the exit.

### 9.3 Browsing and selecting

Show real titles, artwork, and available metadata from the connected source when integration is active. Include search and a clear selected title.

The earlier "Suggest to group" concept represents a collaborative selection direction. A practical initial rule is that a host selects the movie, with other participants able to express a preference. Voting, queues, and formal ready checks are optional extensions unless the owner requests them.

Make the difference between browsing, selected film, and playing film clear. Connection status must reflect reality. A demo library or test clip should be labeled as such.

### 9.4 Watching together

Use one shared screening session with explicit state: selected media, playback state, position, authoritative timestamp, host/control authority, and participants.

Design for play, pause, seek, late joining, buffering, leaving, and the controlling participant disconnecting. A proposed simple policy is host-controlled playback with a documented host-transfer rule.

Each client needs access to the actual playable media. Library browsing and synchronized playback are separate integration tasks. Test the complete flow from another participant's machine, including reachable media URLs, authentication, browser playback compatibility, and any conversion needed by the chosen provider.

Keep provider credentials and broad server access out of public multiplayer state. Use the chosen provider's current official documentation when implementing its actual APIs.

### 9.5 Player view

Provide a social room view that shows seated avatars and a closer watch view where the film is large enough to enjoy. Keep chat and reactions away from the film. Show who is watching and provide a clear leave-seat action.

A proposed first build has one screening per cinema instance. Separate screenings or private watch parties can be added without making unrelated groups share one global playback state.

### 9.6 Acceptance checks

- Two clients choose and watch the same film with synchronized shared controls.
- A late joiner receives the current media and playback position.
- Seats and watching status agree between clients.
- Movie and voice volumes can be controlled independently.
- Leaving returns the player to the world without trapping input or continuing duplicate audio.
- A disconnected host does not leave the session permanently unusable.

## 10. Arcade: solo play and two people on one cabinet

### 10.1 Required experience

The arcade needs both solo games and a game that two friends play together at **one cabinet and in one shared session**. Two people independently using neighboring cabinets does not fulfill the shared-cabinet request.

The world-facing cabinet should visibly have room for two characters when it supports two players. A shared cabinet can have a wider control deck, two joysticks, and color-coded positions while reusing the general cabinet design.

### 10.2 Proposed first game: Puck Rally

This is a working example to establish the interaction, not a locked game choice.

Use a simple paddle game on a stylized ice rink:

- One paddle at the left, one at the right, and one puck.
- Score by getting the puck past the opponent.
- Solo mode uses a basic computer-controlled opposing paddle.
- Two-player mode replaces the computer with another connected person.
- Suggested match length: first to five points.
- Suggested input: up/down movement, such as W/S.

This lets solo and shared play reuse the same game board, scoring, collision rules, and cabinet. More arcade games can be added later through the same activity interface.

### 10.3 What the player sees

**Solo:** The player's avatar stands at the left control station. The right station is empty. The game shows the player against a computer opponent, with a large readable field, score, and controls. An empty-station prompt can invite a friend to join the next round.

**Two players:** Two customized avatars stand side by side at the same cabinet, each using their own control station. The single screen shows their shared match with identifiable player sides and a shared score.

Each online participant uses their own computer. The two physical control stations express shared participation; they do not imply two people must share one physical keyboard.

Use a close cabinet camera or a large local game overlay. Keep the actual game readable and the avatars visibly associated with the cabinet. If using an overlay, preserve the world-side busy/playing state for other people.

### 10.4 Session behavior

- Cabinet occupancy has two explicit player slots.
- Claiming a slot is authoritative and cannot succeed for two users simultaneously.
- Use waiting, ready, playing, and results phases.
- A friend joining during a solo rally should queue for a clear transition, such as the next match, rather than unexpectedly stealing control from the computer.
- Spectators can see the cabinet's current public game state without sending gameplay input.
- If someone leaves, resolve the current match or return to a documented waiting/solo state.
- Leaving the game restores ordinary movement and releases the slot.

For shared play, one authority resolves puck collisions and scoring. Do not allow both clients to award the same point independently.

### 10.5 Acceptance checks

- A solo player can complete a match against the computer.
- A second connected player can join the same cabinet in the intended transition state.
- Both players see the same puck, scores, match phase, and result.
- A third player can spectate or wait without taking control.
- Exiting and reconnecting do not leave ghost occupants.

## 11. Fishing with a Stardew-inspired minigame

### 11.1 Required experience

Fishing should be a playable interaction, with the dock and friends still visible. The owner specifically wants a Stardew-inspired feel.

The reference mechanic is a moving fish marker that must be kept within a player-controlled vertical band while catch progress fills. Use original art, UI, fish, sound, and tuning for this game. Reference: [Stardew Valley Wiki: Fishing](https://stardewvalleywiki.com/Fishing).

### 11.2 Proposed interaction loop

`approach spot -> cast -> wait for bite -> hook -> reel minigame -> catch or escape -> fish again or leave`

Keep the first implementation focused on one skill interaction rather than adding several competing meters.

### 11.3 Active catch interface

- Keep the player, rod, dock, bobber, water, and nearby friends visible.
- Open a substantial side panel with a tall vertical track.
- Put one moving fish marker in that track.
- The player controls a shorter catch band: hold to raise it and release to let it fall.
- Keeping the fish inside fills a separate catch-progress meter.
- Losing the fish from the band drains progress.
- Fill progress to catch; empty progress to lose the fish.
- Suggested controls: hold Space or the primary pointer button, release to lower, Escape to cancel.

The vertical tracking area and the catch-progress meter must be visually distinct. The earlier illustrative "68%" is a mockup state, not a game rule. Start attempts with a little progress or a grace period so a player has time to understand the interaction.

### 11.4 Fish and social presentation

Begin with a few fish variants, using the simple orange, teal, and purple fish concepts as examples. Difficulty can come from movement speed, how often direction changes, and how long the player must maintain tracking.

Other players see casting, rod movement, waiting, and catch celebration. They do not need the local player's catch panel. People should be able to chat while fishing beside each other.

A catch card can show the fish, name, and size. A collection log or cosmetic rewards are proposed additions; a large fishing economy is not required.

### 11.5 Session and exit behavior

Track the current fishing state and any reserved spot. Cancel or suspend cleanly if the player leaves, disconnects, or closes the activity. Do not leave the avatar permanently locked in a casting animation.

Keep the cast line visually connected to the rod and bobber. Place interaction spots so people are not fishing through railings or standing inside one another.

### 11.6 Acceptance checks

- The complete cast-to-result loop works.
- The input clearly moves the catch band in the indicated direction.
- Catch progress responds consistently to overlap.
- Different fish behavior produces understandable differences in difficulty.
- Nearby friends remain visible and voice stays usable.
- Leaving restores movement and releases the fishing spot.

## 12. Sledding

### Confirmed request

Add sledding to the world. The images show a small snowy hill, wooden sleds, start/finish markers, and a route back uphill.

### Proposed first version

Use one short course with a start platform, a broad descent, one or two gentle turns, a finish, and a flat stopping area. Give it a separate walking return path.

Solo time trials are a practical starting mode. A small shared race can use the same course and start/finish logic. The owner has not selected a required race format or player count.

Controls can be simple left/right steering with automatic downhill movement. Authored movement along a course is acceptable for the first build; realistic sled physics is not required by the vision.

Provide a countdown, timer, finish result, retry, and leave action. If the player becomes stuck or leaves the course, offer a reliable reset.

For multiplayer, share race start time, participant state, progress/checkpoints, and finish results. Decide explicitly whether sleds collide with one another; non-blocking racers are a proposed simplification.

### Acceptance checks

- The start, direction of travel, finish, and return route are visually obvious.
- A player can complete a run and retry.
- Resetting never traps the player inside terrain.
- A race or time-trial result uses consistent start and finish conditions.
- The course does not run through the snowball arena or the normal pedestrian route.

## 13. Snowball fights with a sensible arena

### 13.1 Required direction

The owner specifically wants snowball fights arranged in a way that makes sense. Treat arena layout, participation, throwing, cover, and scoring as one design.

### 13.2 Proposed first format

Use a compact **2v2 hit-scoring match** with quick respawns. Coral and teal identify teams. This is a prototype default rather than a confirmed player-count requirement.

### 13.3 Spatial layout

The arena is a level rectangular snow clearing with a clear boundary. Coral starts on the left; teal starts on the right.

- Each team has a recessed spawn area.
- A short snow wall in front of each spawn blocks the direct line across the arena.
- Both ends of each wall stay open, giving players two exits.
- Two small central snowbanks are offset and mirrored around the center.
- Leave an open upper flank, a weaving middle route, and an open lower flank.
- Avoid a wall spanning the entire field, a single mandatory choke point, or dead ends behind decorative objects.
- Trees, rocks, lamps, and village props sit outside the playing boundary.
- A near-side gate leads to waiting pads and a spectator bench outside the field.

The snowball concept image is an aesthetic reference. This topology should take priority over any decorative layout that would make actual play confusing.

### 13.4 Suggested blockout coordinates

These are **illustrative local coordinates for a prototype**, not final world dimensions. Let the long axis be X, from 0 to 12, and the short axis be Z, from 0 to 8. Scale them to the actual avatar.

| Element | Suggested position or span |
| --- | --- |
| Coral spawn | Around X=1, Z=4 |
| Teal spawn | Around X=11, Z=4 |
| Coral spawn wall | Around X=2.5; spans approximately Z=2.5 to 5.5 |
| Teal spawn wall | Around X=9.5; same span |
| Central bank A | Around X=5, Z=5 |
| Central bank B | Around X=7, Z=3 |
| Upper route | Keep a continuous lane near Z=7 |
| Lower route | Keep a continuous lane near Z=1 |
| Neutral entrance | Near X=6, Z=0, with queue/spectators farther outside |

Keep the central banks small enough that the middle route stays open. Verify the actual colliders, camera, and player widths rather than trusting coordinates alone.

### 13.5 Proposed rules

1. Players choose a team/ready pad outside the arena. Start after a short countdown when the match is ready.
2. Move with ordinary game controls, aim with the cursor, and click to throw.
3. Use one consistent throw behavior, a short cooldown, and unlimited snowballs initially.
4. A valid opponent hit scores one point. Friendly fire does not score or stun.
5. Snow walls and banks block throws according to their visible shape.
6. A hit gives a playful snow-puff effect and a short respawn, such as three seconds.
7. Brief spawn protection ends when the player throws. Make its active state visible.
8. Suggested round end: first to ten hits or the highest score after two minutes.

Keep these numbers configurable. On a tied timed result, a draw is a simple first policy; overtime is optional.

### 13.6 Readability and fairness

Preserve the player's own body color and outfit. Add a team scarf, foot ring, badge, or similar marker. Do not make a green body automatically mean the teal team.

Show a compact team score, timer, aiming feedback, and throw availability. Spectators cannot take hits or interfere with projectile collisions. Queue mid-round arrivals for the next match.

Use one authority for projectile resolution and scoring. Ignore duplicate hits and reject throws from outside the active match. Stop scoring once results begin.

If someone disconnects, use a documented policy such as ending an unbalanced match early or allowing a short reconnect window. Do not leave remaining players trapped in an unwinnable session.

### 13.7 Acceptance checks

- Both sides have matching starts and usable exits.
- All three routes are traversable.
- Visible cover consistently blocks snowballs.
- Participants, queued players, and spectators are distinct.
- Hits, score, respawn, and match end agree across clients.
- Leaving and replaying reset team assignment and input cleanly.

## 14. Basketball

### 14.1 Confirmed request

Include basketball as an activity inside the world. The owner has not specified whether this means a shooting contest or a complete possession-based game with dribbling, passing, and defense.

### 14.2 Proposed hackathon default: shared shooting contest

Build a small half-court with one hoop, marked shooting positions, a scoreboard, and spectator space. Support solo practice and a timed contest with a small group, for example up to four players.

Suggested rules:

- Each participant claims a shooting position.
- Each controls their own shot attempts; balls do not collide with one another.
- Hold a shoot control to move a power indicator and release within a target band.
- The server evaluates the accepted shot input and determines success.
- Clients animate a matching made or missed trajectory.
- Each successful shot earns two points in the initial format.
- Use a short cooldown and a configurable round duration, such as 60 seconds.
- Show shared standings and a result at the end.

These are proposed defaults. This version is a recognizable basketball activity, but it should not be presented as a full live team-basketball game.

### 14.3 Player view

Keep the court, hoop, avatar, and nearby competitors visible. Show a clear power meter, remaining time, personal score, and compact standings. Use readable ball arcs, a basket sound, and a short score effect.

Spectators should stand outside shooting positions and retain normal voice access. A leave-contest action restores world movement.

### 14.4 Session behavior

Use waiting, countdown, playing, and results phases. Lock the contestant list at the start; late arrivals can watch and join the next contest.

Identify shot requests with a player, session, and sequence number. Verify the phase, membership, timing, and cooldown. Never accept a client-submitted final score as authoritative, and do not award points twice for a retried request.

Leaving should release that shooting position without resetting everyone else's round.

### 14.5 Full basketball as a separate extension

If the owner wants live 1v1 or 2v2 basketball, it needs explicit shared ball possession, pickup, passing, dribbling, release, flight, scoring, defense, and out-of-bounds rules. That is a materially different implementation from independent shooting attempts.

Keep this extension visible in the plan. Do not silently equate the shooting-contest default with approval to permanently omit full basketball.

### 14.6 Acceptance checks

- A player joins, shoots, receives scores, finishes, and returns to the world.
- Two clients see the same accepted shots, timer, standings, and result.
- Duplicate input cannot award extra points.
- A spectator cannot acquire a participant's shooting controls.
- Repeated rounds reset cleanly.

## 15. Integrated drawing telephone

### 15.1 Confirmed request

Add a Gartic Phone-type drawing-and-guessing game integrated into this world. It should feel like friends sitting down to a party game together. A plain external website link does not deliver the intended integration.

Use original branding and UI. **Sketch Relay** is an optional working name, not the game's final title.

### 15.2 Physical setting

Use a communal table with visible seats, notebooks or drawing pads, and a small room or pavilion. Players walk to the table and join its lobby. Their avatars stay seated while the local activity UI is open.

A proposed starting capacity is three to eight participants. The exact minimum, maximum, and table layout are configurable.

### 15.3 Proposed game flow

Every player starts a separate chain, and people contribute simultaneously:

1. Write a short initial prompt.
2. Receive another player's prompt and draw it.
3. Receive a drawing and describe what it depicts.
4. Continue alternating drawing and interpretation.
5. Reveal the chains together in order.

For N participants, a straightforward first format uses N chains with N contributions each. The initial prompt counts as the first contribution. Lock a player order at the beginning and rotate chain assignments by one position per round so each player contributes once to each chain.

Example with four players:

`prompt -> drawing -> guess -> drawing -> shared reveal`

The last contribution may be text or a drawing depending on group size. Reveal the actual chain rather than forcing every group to end on the same content type.

### 15.4 Suggested timers and tools

Starting values, all configurable:

- Prompt: 30 seconds.
- Drawing: 75 seconds.
- Guess: 30 seconds.
- Advance when everyone submits or the deadline expires.

Provide a large drawing canvas, a small color palette, a few brush sizes, eraser, undo, clear, timer, and submit. Prompt/guess screens need a text field, a clear instruction, and the relevant assigned content.

Submitting locks the contribution for that round. Show readiness counts without exposing anyone's unfinished work.

### 15.5 Hidden information

Each player receives only the content needed for their current task. During a draw round, show the immediately preceding text. During a guess round, show the immediately preceding drawing.

Do not send every chain to every client and rely on hiding it in the interface. Keep unrevealed prompts, drawings, guesses, and private assignments on the appropriate server/private channel until they should be shown.

Normalized stroke data is a practical first drawing representation. Store color, brush width, and points relative to canvas dimensions. Set reasonable limits on stroke and point counts. Submitted raster images are another option if the existing stack already handles them well.

### 15.6 Shared reveal

Show one chain at a time, revealing entries in order with contributor names. Synchronize the current chain and reveal position across participants. Include next-entry, next-chain, and play-again controls, with a defined host/control policy.

The reveal is the social payoff. Give the drawings enough screen space and restore conversation so people can react together.

### 15.7 Voice proposal

Use conversation in the lobby and reveal, with quiet private rounds as the proposed first rule. During prompt, drawing, and guessing phases, participants stop transmitting and receiving table/proximity voice, with a visible explanation such as "Quiet round; voice returns at reveal."

This rule is a design proposal to reduce accidental spoilers, not an owner-confirmed requirement. If open-mic chaos is preferred, make that an explicit room option. Preserve each user's chosen microphone state when the phase changes.

### 15.8 Joining, leaving, and missed turns

- Allow free joining while the table is in its lobby.
- Lock the roster and rotation at game start.
- Late arrivals wait for the next game or watch the reveal.
- Preserve a disconnected participant's position in the rotation.
- Reconnection before the deadline restores the correct assigned task.
- On timeout, write an explicit skipped-entry record and continue.
- If the next player receives a skipped entry, show a clear fallback instruction for the expected content type.
- Reveal skipped turns honestly so the chain remains understandable.
- Do not reindex everyone mid-game when one person leaves.

### 15.9 Acceptance checks

- A group completes prompt, drawing, interpretation, and synchronized reveal.
- Every round sends the correct private assignment to each player.
- Hidden content is not broadcast early.
- A disconnect or missed deadline cannot stall the whole session indefinitely.
- Reconnection restores the current private task.
- Starting again clears old private data and assignments.
- Leaving restores the world and the user's previous microphone preference.

## 16. Technical structure to preserve the experience

This is a technology-neutral design. Use the repository's existing stack where it can support the requirements. The conversation did not choose a specific engine, frontend framework, multiplayer service, voice provider, database, or hosting platform.

### 16.1 Useful boundaries

Separate these responsibilities logically, even if they live in one application:

| Responsibility | Examples |
| --- | --- |
| World and rendering | Scene, camera, avatars, movement presentation, collisions, interaction prompts |
| Identity and customization | Player identity, display name, equipment, appearance, preferences |
| Multiplayer authority | Presence, positions, room membership, slot reservations, authoritative activity state |
| Activities | Cinema, cabinets, fishing, sledding, snowballs, basketball, drawing telephone |
| Voice routing | Device state, audio rooms, proximity gains, activity overrides, mute preferences |
| Media provider | Library metadata, authorized playback access, provider-specific connection behavior |
| Persistence | Saved customization and any deliberately included progress or room data |

Do not assume this requires microservices. A small coherent application and game server are a valid prototype shape.

### 16.2 Shared identity and activity records

Suggested concepts, to adapt to the actual stack:

```text
Player
  id, displayName, appearance, roomId
  worldPosition, facing, animationState
  activitySessionId, activityRole, activitySlotId

ActivitySession
  id, type, worldAnchorId, roomId
  phase, participants, spectators, queuedPlayers
  startsAt, endsAt, revision, activitySpecificState

CinemaState
  mediaId, providerRef, playbackState
  mediaPosition, stateTimestamp, controllerId

ArcadeState
  mode, playerSlots, readiness
  paddles, puck, scores, matchPhase

FishingState
  playerId, spotId, phase, fishDefinition
  catchProgress, attemptId

SnowballState
  teams, scores, projectiles
  respawnTimes, spawnProtection, matchPhase

BasketballState
  positions, scores, phase
  latestAcceptedShotSequenceByPlayer, shotEvents

DrawingTelephoneState
  fixedParticipantOrder, phase, roundIndex, deadline
  privateAssignments, chains, submittedPlayers
  revealChainIndex, revealEntryIndex
```

Private assignments and credentials are not part of a public broadcast snapshot. Exact fields and storage formats remain implementation choices.

### 16.3 Authority and timing

Use shared session time for match deadlines and synchronized media state. Let clients interpolate presentation, while one authority resolves contested actions such as occupying a slot, scoring, hitting a player, advancing a drawing round, or changing the selected movie.

Attach sequence or request identifiers where duplicated actions could produce duplicate results. Keep public state revisions understandable for reconnection and late joins.

### 16.4 Integration honesty

If a provider, backend, or other dependency is unavailable, show an explicitly identified demo mode. A successful-looking connection banner does not substitute for working integration.

Verify actual current APIs and SDK behavior when implementation begins. This brief does not assert that a particular provider exposes a particular endpoint or that every source video can be played directly in every browser.

## 17. Hackathon implementation plan

### 17.1 Preserve the full vision, reduce individual depth

The feature list has grown beyond a single minigame. Keep the full destination list and interaction vision, but make each initial activity small. Do not spend the whole hackathon building a large account system, economy, furniture catalog, physics engine, or many variations of the same arcade game.

No exact team size has been confirmed. Assign work based on the actual available team rather than treating a suggested division as a staffing fact.

### 17.2 Proposed build order

1. **World foundation:** One recognizable plaza, base avatar, movement, camera, collision, room transitions, and two-client presence.
2. **Shared interactions:** Contextual prompts, authoritative activity slots, ready/playing/results states, input focus, clean leave behavior, and consistent player identity.
3. **Social anchor:** Proximity voice and a cinema flow with a verified playable source. Validate the media integration early because it involves external dependencies.
4. **Small playable activities:** One arcade game with solo and two-player modes; one fishing loop; one bounded snowball arena; one short sled course.
5. **New requested activities:** A small basketball implementation and the complete drawing-telephone loop. These can run in parallel once the common session layer is stable.
6. **Customization and polish:** A modest set of clothes and color options, clear activity feedback, sound mixing, visual consistency, and replay/reconnect behavior.

This order is a recommendation, not a promise that every feature will fit into every team's 36 hours. If scope must change, identify which requested feature is reduced, what remains playable, and the intended next step.

### 17.3 Proposed limited versions

| Feature | Small complete version | Further depth |
| --- | --- | --- |
| World | One compact hub with activity entrances | Additional districts and larger islands |
| Customization | Body colors plus a few modular hats/clothes | Larger wardrobe, shops, unlocks |
| Cinema | One provider and one shared screening session | Multiple providers, multiple screenings, formal voting |
| Voice | Room-local proximity, clear mute controls | Detailed acoustic occlusion and richer party routing |
| Arcade | One game supporting solo and two people | More genres and cabinet variants |
| Fishing | Cast, bite, tracking minigame, catch result | Larger fish catalog, collection goals, equipment |
| Sledding | One short course with retry and results | Multiple courses and richer racing |
| Snowballs | One balanced small arena and short matches | More maps and game modes |
| Basketball | Practice and a shared shooting contest | Possession-based 1v1/2v2 |
| Drawing telephone | One complete prompt/draw/guess/reveal format | Custom modes and larger groups |
| Personal spaces | Small room and a few placement options if feasible | Persistent housing, visiting permissions, extensive furniture |

### 17.4 Art production priorities

Use one base bird rig, modular clothing, repeated building pieces, one family of furniture, one reusable cabinet, and repeated theatre seating. Keep outdoor snow and water visually simple enough to render smoothly alongside multiple avatars.

Treat high-detail concept lighting and decoration as a target mood. Preserve the silhouette, palette, layout, and readability first when translating it into real-time assets.

## 18. Verification and completion criteria

Use meaningful multi-client checks, not only a single local browser looking correct.

### Core world

- Two people can enter the same world and recognize one another's appearance.
- Movement and room changes remain coherent to both.
- Interacting, sitting, playing, and leaving are visible states.
- Input returns correctly after closing every activity.
- Disconnected users do not leave permanently occupied slots.

### Social and media

- Voice changes appropriately with proximity and room membership.
- Mute preferences survive activity transitions.
- Microphone denial does not prevent ordinary gameplay.
- A real movie source, or an honestly labeled demo source, works for more than the host machine.
- Playback controls and late joining are handled consistently.

### Games

- A solo arcade round and a two-client shared-cabinet round both complete.
- Fishing has an understandable active minigame and a clean result/exit.
- Sledding has a complete start-to-finish path and reliable reset.
- Snowball routes, blocking, scores, respawns, and spectator boundaries work together.
- Basketball has the chosen complete ruleset, synchronized scoring, and clean replay.
- Drawing telephone completes all phases without leaking hidden contributions or stalling on a missed turn.

### Presentation

- The result is recognizably the supplied low-poly diorama world.
- Players remain readable against snow, water, walls, and effects.
- The game being played is large enough to see, not merely decorative screen art.
- Nearby friends and their participation remain visible.
- The HUD communicates current state and available actions without overwhelming the scene.

## 19. Open decisions to resolve deliberately

These decisions remain open. Infer from the actual repository and owner guidance where possible; use the proposed defaults for reversible prototype work.

| Decision | Current position |
| --- | --- |
| Final title and branding | Undecided; working activity names are placeholders |
| Engine/platform/stack | Not selected in this conversation |
| Server and account model | Not selected; needs consistent player identity |
| First media provider | Plex or Emby-style integration requested; choose one actual target first |
| Public versus private world | Not fixed; friend-focused sessions are a reasonable first scenario |
| Cinema control and selection | Host selection/control proposed; voting and ready checks optional |
| Voice defaults | Proximity confirmed; key bindings, radius, and special activity rules proposed |
| Arcade genre | Puck Rally proposed to demonstrate both solo and shared play |
| Sled format | Time trial and small race are options |
| Snowball parameters | 2v2, two minutes, ten hits, and short respawns proposed |
| Basketball format | Shooting contest proposed first; full team play remains an open expansion |
| Drawing-game format | Three to eight players and alternating timed rounds proposed |
| Rewards and economy | Cosmetic/collection possibilities; no detailed economy approved |
| Housing depth | Established visual direction; ownership and persistence details open |

## 20. Handoff instructions for Codex

You already have the concept images. Use this brief to connect those visuals to actual gameplay.

1. Inspect the existing repository, assets, and working features.
2. Identify the selected low-poly visual references and preserve their identity.
3. State any major technical assumptions briefly. Do not present proposed game rules as explicit owner requirements.
4. Build on the existing stack when practical.
5. Establish the shared world, player identity, activity lifecycle, and reliable multiplayer behavior before multiplying special-case interfaces.
6. Keep every requested activity visible in the implementation plan, with a clear small playable version.
7. Use real interactions and state. Label any temporary demo data or unavailable integration honestly.
8. Test with multiple clients, including joins, leaves, late arrivals, and repeated rounds.
9. Report what works, what is incomplete, and which proposed defaults were chosen.

The target experience is a cozy, recognizable place where friends can show up as themselves, talk, play, watch things together, and move naturally from one shared activity to another.
