# Waddle World - UI System and Flows

[Waddle World - UI Mockups](Waddle%20World%20-%20UI%20Mockups.md) · [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Player Housing - Grid Decoration](Player%20Housing%20-%20Grid%20Decoration.md)

## Confirmed direction

The user requested simple UI, inspired by Club Penguin's approachable menus, with **Waddle World** as a placeholder title. Use original layouts and assets. This batch creates mockups and specifications only; it does not replace the game's current scenes or rename its project configuration.

## Shared visual language

Ivory panels, navy text, teal primary actions, small coral accents, softly rounded corners, simple icons with labels, one obvious primary action per task. Avoid decorative wood borders, currency bars, shop prompts and constant dashboards. Use the same button, tab, field, slider, item card and modal components across all menus. Keep normal HUD small; expand only where the activity needs a readable canvas or board.

Use consistent back/close placement, visible selected and keyboard-focus states, disabled controls with explanations, and text/icons alongside color feedback. UI sizing is a prototype tuning task: test at the real viewport and enlarged text size. These mockups are not measured pixel-perfect layouts. Render actual UI with Godot controls and editable text; do not ship entire raster mockups as menus.

## Entry and navigation

Main menu → Play → first-time name/color setup when needed → world list → joining → town. Cancel returns to world selection. A returning player reuses saved identity. Joining failure preserves selection and offers Retry or Back. World list is a proposal; match the actual multiplayer architecture rather than inventing permanent servers.

Town HUD opens Map, Outfit, Home, Friends and Emotes. Contextual actions represent proximity, availability and occupancy. Map selection highlights a place; teleportation is not implied. Keep voice status and current speaker feedback visible without opening a large social panel.

## Shared activity lifecycle

Join/claim slot → lobby/ready if required → instructions/countdown → active play → results → replay or leave. Menus capture input so typing/drawing does not move the penguin. Every phase has a working exit. Leaving restores movement, camera, cursor and voice preference and frees the slot. Rejoining never duplicates a participant. Menu overlay does not pause online matches.

Fishing uses a vertical tracking band and separate catch progress. Arcade uses one shared cabinet and a readable local play board. Cinema distinguishes demo library, connection, selected film, playback and buffering. Sledding exposes retry/reset safely. Snowballs show teams, aim, throw readiness and respawn. Basketball uses proposed shooting-contest UI, with full possession play still an open extension. Drawing completes prompt → draw → guess → reveal, with a submitted/waiting state and honest skipped-turn presentation.

## Housing and wardrobe

Wardrobe previews modular items and colors, then saves on Done. Home decoration snaps to valid floor/wall/surface/ceiling placement; expose Move, Rotate, Color, Remove, Undo and Done. Remove returns to inventory. Cancel restores the previous valid object transform. Save errors retain the local edit and offer Retry. A shell change must preserve the old layout until accepted and handle non-fitting furniture explicitly. Visitor permissions and house ownership must be enforced beyond the UI.

## State and accessibility checklist

- Loading: short explanation and cancel where safe; avoid indefinite spinners.
- Empty: explain why and offer a relevant next action, such as clearing a filter.
- Error: retain user input and offer Retry/Back; no fabricated success state.
- Confirmation: only for meaningful interruption or loss, not routine navigation.
- Controls: remappable inputs, visible focus, consistent prompts from live bindings.
- Accessibility: scalable text/UI, contrast, non-color indicators, reduced motion; check the actual rendering before claiming conformance.
- Voice: optional access, device choice, persistent mute, separate voice/movie volume.
- Social: respect permissions; report/block/friend actions require functioning services and truthful completion feedback.
- Private content: drawings, assignments and media credentials are never exposed through public state.

## Coverage and remaining validation

The boards cover main menu, identity, world selection/loading, HUD/map, friends/player card/emotes, wardrobe/color/slots/inventory, house grid editing/selection/permissions, cinema/arcade, fishing, sledding/snowballs/basketball, drawing rounds, settings/input/accessibility, connection recovery, report/friend request and result dialogs. Visual alternatives are not approval of new gameplay systems, economies or services.

Before implementation, test a clickable prototype at actual game resolution. Check text overflow, gamepad/keyboard navigation if supported, empty/error/loading states, activity cancellation and persistence. Do not copy illustrative counts, keys, capacities, genre names, selected-tab errors or character redesigns from the image boards. Individual notes identify known mockup inconsistencies.
