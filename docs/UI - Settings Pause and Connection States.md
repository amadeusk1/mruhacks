# UI - Settings Pause and Connection States

[Waddle World - UI Mockups](Waddle%20World%20-%20UI%20Mockups.md) · [Waddle World - UI System and Flows](Waddle%20World%20-%20UI%20System%20and%20Flows.md)

![UI - Settings Pause and Connection States](concepts/UI%20-%20Settings%20Pause%20and%20Connection%20States.png)

## Screens

Pause/options overlay; settings overview; connection loss; leave confirmation.

## Behavior and implementation notes

In multiplayer, opening the menu does not pause the shared world: use Menu rather than Game Paused. The empty-inventory card is a component example and belongs in inventory, not Settings. Confirm leaving only when it interrupts active participation or loses unsaved changes, not every harmless close. Reconnect offers a bounded attempt and useful error feedback. Never let opening settings change mic consent.

Waddle World is the user-selected placeholder title. These are raster UI concepts, not implemented Godot scenes. World art, player proportions, example data, keys and menus shown are illustrative; the original penguin model reference remains authoritative.
