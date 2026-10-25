# UI - Town HUD Map and Social

[Pengloo Party - UI Mockups](Pengloo%20Party%20-%20UI%20Mockups.md) · [Pengloo Party - UI System and Flows](Pengloo%20Party%20-%20UI%20System%20and%20Flows.md)

![UI - Town HUD Map and Social](concepts/UI%20-%20Town%20HUD%20Map%20and%20Social.png)

## Screens

Town HUD; map; friend list; player card and emote picker.

## Behavior and implementation notes

Keep ordinary HUD compact. Show only the nearest valid contextual action, plus occupied/busy state. Map markers should locate destinations; they do not imply teleportation. Friend statuses reflect actual state, and home visits respect permissions. Mic state and nearby speaker indicators should remain legible. Friend requests and reporting need working backend paths before exposing active buttons.

Pengloo Party is the game title. These are raster UI concepts, not implemented Godot scenes. World art, player proportions, example data, keys and menus shown are illustrative; the original penguin model reference remains authoritative.
