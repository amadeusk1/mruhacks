# UI - Settings Pause and Connection States

[Pengloo Party - UI Mockups](Pengloo%20Party%20-%20UI%20Mockups.md) · [Pengloo Party - UI System and Flows](Pengloo%20Party%20-%20UI%20System%20and%20Flows.md)

![UI - Settings Pause and Connection States](concepts/UI%20-%20Settings%20Pause%20and%20Connection%20States.png)

## Screens

Pause/options overlay; settings overview; connection loss; leave confirmation.

## Behavior and implementation notes

In multiplayer, opening the menu does not pause the shared world: use Menu rather than Game Paused. The empty-inventory card is a component example and belongs in inventory, not Settings. Confirm leaving only when it interrupts active participation or loses unsaved changes, not every harmless close. Reconnect offers a bounded attempt and useful error feedback. Never let opening settings change mic consent.

Pengloo Party is the game title. These are raster UI concepts, not implemented Godot scenes. World art, player proportions, example data, keys and menus shown are illustrative; the original penguin model reference remains authoritative.
