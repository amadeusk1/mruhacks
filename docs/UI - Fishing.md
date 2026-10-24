# UI - Fishing

[Waddle World - UI Mockups](Waddle%20World%20-%20UI%20Mockups.md) · [Waddle World - UI System and Flows](Waddle%20World%20-%20UI%20System%20and%20Flows.md)

![UI - Fishing](concepts/UI%20-%20Fishing.png)

## Screens

Ready/cast; bite/hook; active reeling; caught/escaped result alternatives.

## Behavior and implementation notes

The fish track and moving catch band are distinct from the horizontal progress bar. Only one fish marker is active; faded fish in the image are illustrative movement hints, not multiple targets. Caught and escaped are mutually exclusive states, despite both appearing on the comparison board. Keep Leave available during bite as well as reeling. Other players see world animation, not the local catch panel. Names and sizes are sample data.

Waddle World is the user-selected placeholder title. These are raster UI concepts, not implemented Godot scenes. World art, player proportions, example data, keys and menus shown are illustrative; the original penguin model reference remains authoritative.
