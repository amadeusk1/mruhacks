# UI - Main Menu and Entry

[Waddle World - UI Mockups](Waddle%20World%20-%20UI%20Mockups.md) · [Waddle World - UI System and Flows](Waddle%20World%20-%20UI%20System%20and%20Flows.md)

![UI - Main Menu and Entry](concepts/UI%20-%20Main%20Menu%20and%20Entry.png)

## Screens

Main menu; first-time penguin setup; world selection; joining/loading.

## Behavior and implementation notes

Play → setup if needed → select world → joining → town. Returning players reuse saved appearance. World names, capacities and player counts are illustrative. Disable full worlds with a reason; refresh, empty list, join failure and cancellation reuse the shared state panel. Display-name validation needs inline feedback. No new authentication system is confirmed.

Waddle World is the user-selected placeholder title. These are raster UI concepts, not implemented Godot scenes. World art, player proportions, example data, keys and menus shown are illustrative; the original penguin model reference remains authoritative.
