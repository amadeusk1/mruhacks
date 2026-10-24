# UI - Home Decoration

[Waddle World - UI Mockups](Waddle%20World%20-%20UI%20Mockups.md) · [Waddle World - UI System and Flows](Waddle%20World%20-%20UI%20System%20and%20Flows.md)

![UI - Home Decoration](concepts/UI%20-%20Home%20Decoration.png)

## Screens

Home view; grid editing; blocked placement; selected-object controls and save status.

## Behavior and implementation notes

Grid is visible only while editing. Valid placement uses outline plus checkmark; blocked placement uses icon and specific reason, not just color. Keep exit routes clear. Remove returns the item to inventory; it is not permanent deletion. Confirm saving only after persistence succeeds; expose Saving, Save failed and Retry states. Done finishes edit mode, while Cancel cancels the current placement. Proposed visitors toggle is expanded in the permissions board.

Waddle World is the user-selected placeholder title. These are raster UI concepts, not implemented Godot scenes. World art, player proportions, example data, keys and menus shown are illustrative; the original penguin model reference remains authoritative.
