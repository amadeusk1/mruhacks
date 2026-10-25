# UI - Houses Visitors and Player Actions

[Pengloo Party - UI Mockups](Pengloo%20Party%20-%20UI%20Mockups.md) · [Pengloo Party - UI System and Flows](Pengloo%20Party%20-%20UI%20System%20and%20Flows.md)

![UI - Houses Visitors and Player Actions](concepts/UI%20-%20Houses%20Visitors%20and%20Player%20Actions.png)

## Screens

House selection; visitor permissions; report-player form; friend request.

## Behavior and implementation notes

House change previews must show the selected shell accurately; generated selected cottage/preview mismatch is not intended. Before applying a smaller/different floor plan, preserve the old layout and explain displaced furniture returning to inventory. Only owner edits by proposed default. Visitor permissions require server enforcement. Report sends once, then shows acknowledged or retry state; no success claim before response. These are proposed social features, not claims of an existing moderation service.

Pengloo Party is the game title. These are raster UI concepts, not implemented Godot scenes. World art, player proportions, example data, keys and menus shown are illustrative; the original penguin model reference remains authoritative.
