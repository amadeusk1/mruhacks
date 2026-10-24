# UI - Activity Play Guess and Results

[Waddle World - UI Mockups](Waddle%20World%20-%20UI%20Mockups.md) · [Waddle World - UI System and Flows](Waddle%20World%20-%20UI%20System%20and%20Flows.md)

![UI - Activity Play Guess and Results](concepts/UI%20-%20Activity%20Play%20Guess%20and%20Results.png)

## Screens

Live arcade; drawing guess; snowball lobby; reusable match results.

## Behavior and implementation notes

Arcade needs a large playable board, not only the distant cabinet screen. Lobby column headings must be Coral and Teal; generated You/Milo headings are illustrative mistakes. Team results use team names and icons; individual court standings use player names. Both can reuse one result component with correct data. Ready/spectate must follow real occupancy and phase. Guess screen sees one assigned drawing only.

Waddle World is the user-selected placeholder title. These are raster UI concepts, not implemented Godot scenes. World art, player proportions, example data, keys and menus shown are illustrative; the original penguin model reference remains authoritative.
