# UI Implementation

The Pengloo Party core UI in Godot, built as real Control scenes to match the mockup boards ([Pengloo Party - UI Mockups](../Pengloo%20Party%20-%20UI%20Mockups.md), behaviour in [Pengloo Party - UI System and Flows](../Pengloo%20Party%20-%20UI%20System%20and%20Flows.md)). Branch `ui/core` in the game repo. Engine-side brief: [Engine Spec - UI](../Engine%20Specs/Engine%20Spec%20-%20UI.md). Hub: [Art Pipeline](../Art%20Pipeline.md).

Screenshots of every screen are in `Renders/UI/`. Side-by-side comparisons with the mockup panel are in `art/_wip/ui_cmp_<screen>.png`.

## Design tokens (`ui/theme/ui_tokens.gd`)

Colours were sampled from the UI boards with ImageMagick.

| Token | Value | Use |
| --- | --- | --- |
| `PANEL` | `#FCF6EC` | Ivory cards |
| `PANEL_ROW` | `#FFFCF6` | List rows, inner cards |
| `SECONDARY` | `#F0E6D9` | Secondary buttons, unselected tabs |
| `TEAL` | `#1A9CA0` | Primary actions, selected tab, slider fill, toggles on |
| `TEAL_SELECT` | `#EAF6F2` | Selected row fill (with a 3 px teal border) |
| `CORAL` | `#F5776C` | "You"/coral team, accents, errors |
| `NAVY` | `#15274D` | Body text |
| `NAVY_TITLE` | `#0E1C42` | Titles, wordmark, icons |
| `MUTED` | `#8B8F9B` | Secondary text |
| `GREEN` / `BLUE_DOT` / `GREY_DOT` | `#14B28B` / `#4A8BE0` / `#A9ABB2` | Status dots: online, busy, offline |

**Type:** Fredoka variable (`fonts/Fredoka-Variable.ttf`, OFL). Body text is Medium (wght 520), headings are Bold (700). Sizes: Title 52, TitleSmall 46, Heading 32, Body/Subtitle 24, Muted 20, buttons 28–29, wordmark 132. They were measured against the boards at 1280×720.

**Shapes:** cards are 26 px radius with a soft shadow; buttons 16 px (pills 36–40 px); fields 12 px.

## Theme

`ui/theme/pengloo_theme.tres` is the project-wide theme (`gui/theme/custom`). It is **generated**: edit `ui/theme/build_theme.gd` and rerun it.

```
Godot --headless --path . --script res://ui/theme/build_theme.gd
```

Type variations:
- **Labels:** Title, TitleSmall, Heading, Subtitle, Body, Strong, Muted, Eyebrow, Wordmark.
- **Panels:** Card, Row, RowSelected, Inset, Chip, ErrorBox.
- **Buttons:** PrimaryButton, QuietButton, OutlineButton, DangerButton, TabButton, HeroButton, IconButton, DockButton.
- **Fields:** LineEditError.
- **Base types:** sliders, toggles, OptionButton and PopupMenu use the theme defaults.

## Components (`ui/components/`)

| Component | What it gives you |
| --- | --- |
| `UIKit` | Factory functions: `button(text, kind, icon)`, `icon_button`, `dock_button`, `tab_bar`, `field` (+ `set_field_error`), `slider_row`, `toggle_row`, `swatch`, `chip`, `status`, `glyph`, `card`, `pin` (anchor plus offset layout), `full` |
| `IconTextButton` | Icon beside centred text, as drawn on every board. Godot's Button pushes the icon to the edge |
| `UIModal` | Dimmed overlay with one centred card: title, subtitle, back/close, optional brand eyebrow, `body` VBox. `open()`/`close()` go through UIRouter |
| `UIWidgets` | `state_panel` (loading/empty/error with actions), `toast`, `item_card`, `side_panel`, `score_row` |
| `PenguinPreview` | Live rigged penguin (AssetPack bird + idle) in its own lit SubViewport. `set_body(color)`, `play(clip)`. `PenguinPreview.portrait(color)` returns a cached head-and-shoulders render for lists |
| `Portrait`, `PenguinFace`, `Spinner` | Round portrait frame, vector fallback face, dotted loading ring |
| `ui/icons/*.svg` | 50 flat white icons, tinted by the theme |

## UIRouter (autoload)

- **Stack:** `push(control)` shows a control on the overlay layer (layer 50). Escape closes the top entry.
- **Pause:** with nothing open in a world, Escape opens the Menu. It's named "Menu", not "Game Paused", because the online world keeps running.
- **Input lock:** while any blocking panel is open, or a text field has focus, the local penguin's input is locked (`set_typing_locked`). Non-blocking panels set `blocks_world = false`.
- **Settings:** stored in `user://settings.cfg`. Volumes drive audio buses named Music, SFX, Voice and Movie when they exist. Text size and UI scale scale every panel on the stack.

Other UI branches register screens with `UIScreens.register("wardrobe", callable)`. The HUD's Outfit button opens `"wardrobe"` when it's registered; until then it shows a "coming soon" toast.

## Screens

| Screen | File | Notes |
| --- | --- | --- |
| Main menu | `ui/screens/main_menu.tscn` (project main scene) | Live town backdrop with a slow camera drift (still when Reduce motion is on), PENGLOO PARTY wordmark with a penguin head (`ui/icons/penguin_head.svg`) in the first O and a coral spark, live penguin, Play / Settings / Quit |
| Your Penguin → Choose a World → Joining | `scripts/lobby.gd` | Same signals and methods `world.gd` already used. Name validation, 6 coat swatches (`Net.COATS`), profile saved to `user://profile.cfg` so returning players skip setup. The worlds are the real options: Practice Island (solo), Host a World, Join a Friend. A join failure keeps the choice and offers Retry |
| Town HUD | `ui/hud/town_hud.gd` (added by `play_hud.gd`) | Location chip (nearest destination), mic state, Map / Outfit / Home / Friends / Emotes dock, contextual action from the scene builder's `Interactable`s (`prompt_text()`/`interact()`) and the bus stop. Hides the Interactables' floating 3D labels while the HUD is present. Also restyles the teammate's chat box (ivory, navy text, bottom aligned with the dock) and fishing-coin badge (theme chip); their logic is untouched. Location names include Casino. M = map, R = emotes |
| Map | `ui/screens/map_screen.gd` | Angled three-quarter render of the real town (`ui/map/town_map_angled.png`, orthographic at 50° pitch), with the top-down `town_map.png` as fallback. 11 destination chips (Casino from the casino exterior's `socket_door`) and the live player dot are projected through the stored camera (`town_map_angled.json`). No teleport |
| Friends / Player card | `friends_panel.gd`, `player_card.gd` | There is no friends service yet, so this is the players in the current world. Visit home and Invite to my igloo are real; Mute voice, Block and Report are disabled, with the reason in a tooltip |
| Emotes | `emote_picker.gd` | Eight tiles with thumbnails rendered from the real anim_emotes clips, plus the board's little effect marks. Plays through `penguin.play_emote()` |
| Menu, Settings, Controls, Accessibility, Microphone, Connection lost, Leave confirmation | `pause_menu.gd`, `settings_screen.gd`, `controls_screen.gd` (+ `key_capture.gd`), `accessibility_screen.gd`, `microphone_screen.gd`, `connection_lost.gd`, `confirm_dialog.gd` | Controls read and write the live InputMap (`user://controls.cfg`), and Replace/Cancel handles a duplicate key. Voice isn't implemented, so the mic screens store the preference and say so |
| Results | `results_screen.gd` | `ResultsScreen.show_results(title, rows, on_again, on_leave)`, coral/teal rows. Shared by activities |

## Tools

| Tool | What it does |
| --- | --- |
| `tools/ui_capture.tscn -- --out=/dir/ [--only=a,b]` | Screenshots every screen at 1280×720 |
| `tools/map_capture.tscn` | Re-renders both map images (angled and top-down) and the Choose a World thumbnails. Rerun it whenever the town layout changes |
| `tools/emote_thumbs.tscn` | Re-renders the emote thumbnails |
| `ui/tests/compile_all.tscn` | Compiles every script under `ui/`, `tools/` and `scripts/` |

## Known gaps

- **Map style:** the map is a real render of the town, not the mockup's painted illustration.
- **Coins:** fishing awards coins but nothing spends them yet; the badge is kept as a themed chip because it's real gameplay.
- **Social and voice:** the friend list, voice, block and report need backend services.
- **Media library:** connection states belong to the cinema UI (activities branch).
- **Joining colour:** `hello()` carries the worn look, and the host stores that coat instead of assigning one.
- **Settings layout:** the "No items here yet" card on the Settings board belongs in inventory, per the note, so it isn't on Settings.

## Activity, wardrobe, home and casino screens (branch `ui/activities`)

Built on the core theme, tokens and components. Each screen is a Control script under `res://ui/activities/` with `preview(state)` for mock data, and the ones that need a server use `apply_state(dict)` to take state and the `intent(action, value)` signal to send player actions. Open them with `ActivityScreens.open(name)` (autoload): `wardrobe`, `inventory`, `home_edit`, `home_choose`, `home_visitors`, `cinema`, `arcade`, `sketch`, `snowballs`, `basketball`. Town interactables reach them automatically through `Activities.requested`. Mockup comparisons are in `art/_wip/ui_cmp_*.png`; keepers are in `Renders/UI/`.

| Screens | Script | Wired to real gameplay? |
| --- | --- | --- |
| Wardrobe, Color, Outfit Slots, Inventory | `wardrobe/wardrobe.gd`, `wardrobe/inventory.gd`, `outfit.gd`, `components/penguin_view.gd` | Yes. Done saves `user://outfit.cfg`, re-dresses the local penguin, and publishes the look. The host keeps it on the roster so other players dress their copy. |
| Make It Home (home, decorate, blocked, selected and save) | `home/decor_ui.gd` + `home/decor_editor.gd` | Yes. A grid built from the shell's `cells` and `blocked_cells`; quarter turns rotate footprints; move/rotate/colour/remove (back to inventory); undo; Saving/Saved/Save failed. The layout is saved locally in `user://home_<shell>.json`, and validation runs on the client only |
| Choose Home, Home Visitors | `home/home_select.gd`, `components/model_thumb.gd` | Saved locally. Who-can-decorate is locked to Only me (no server enforcement yet) |
| Fishing Ready, Bite, Reel, Result | `scripts/fishing_hud.gd` (teammate's logic, restyled) | Yes. Cast and Cast again are now explicit buttons; the escape inset is shown on its own |
| Movie Library, Watch Party | `cinema/cinema_ui.gd` + `cinema/cinema_source.gd` | A provider-neutral `CinemaSource` seam (Plex/Emby/Demo) per the Plex plan. The demo source is always labelled. Controller-gated play/pause/seek/tracks; movie and voice volume are separate |
| Arcade lobby, Live Puck Rally, Results | `arcade/arcade_ui.gd`, `arcade/puck_board.gd` | Solo against the AI is playable (first to 5). Two-player play needs the host to drive `PuckBoard` |
| Sled Time trial, Run HUD, Finished | `scripts/sled_hud.gd` (restyled; same API as `sled_run.gd`) | Yes. Best time is saved locally. "Next checkpoint" uses a nominal 300 m course until `sled_run` exposes its checkpoints |
| Snowball HUD and lobby, Basketball HUD, Round complete | `winter/winter_ui.gd` | Mock state only (no match or court gameplay yet). The throw readiness is a cooldown, not ammo |
| Sketch Club lobby, Prompt, Draw, Guess, Reveal | `sketch/sketch_ui.gd`, `sketch/sketch_canvas.gd` | Mock assignments. The canvas is real, with normalized strokes, limits, undo and clear-confirm. Each client only ever holds its own assignment |
| Casino roulette, slots, poker, blackjack + reconnecting/waiting/full/insufficient | `casino/*.gd` | Mock state only; there's no casino server. Roulette uses the single-zero board with pending vs accepted bets; poker and blackjack enable only legal actions; hidden cards never appear in state |

Headless check: `ui/tests/compile_all.tscn`. Screenshot harness: `tools/ui_preview.tscn -- --shots=script|state|bg|out;...`.
