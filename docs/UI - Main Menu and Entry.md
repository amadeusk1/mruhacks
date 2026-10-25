# UI - Main Menu and Entry

[Pengloo Party - UI Mockups](Pengloo%20Party%20-%20UI%20Mockups.md) · [Pengloo Party - UI System and Flows](Pengloo%20Party%20-%20UI%20System%20and%20Flows.md)

![UI - Main Menu and Entry](concepts/UI%20-%20Main%20Menu%20and%20Entry.png)

## Screens

Main menu; first-time penguin setup; world selection; joining/loading.

## Behavior and implementation notes

Play → setup if needed → select world → joining → town. Returning players reuse saved appearance. World names, capacities and player counts are illustrative. Disable full worlds with a reason; refresh, empty list, join failure and cancellation reuse the shared state panel. Display-name validation needs inline feedback. No new authentication system is confirmed.

Pengloo Party is the game title. These are raster UI concepts, not implemented Godot scenes. World art, player proportions, example data, keys and menus shown are illustrative; the original penguin model reference remains authoritative.
