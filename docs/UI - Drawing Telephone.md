# UI - Drawing Telephone

[Pengloo Party - UI Mockups](Pengloo%20Party%20-%20UI%20Mockups.md) · [Pengloo Party - UI System and Flows](Pengloo%20Party%20-%20UI%20System%20and%20Flows.md)

![UI - Drawing Telephone](concepts/UI%20-%20Drawing%20Telephone.png)

## Screens

Drawing lobby; prompt entry; drawing canvas; shared reveal.

## Behavior and implementation notes

Add guess phase from the companion board. Submit locks the contribution and enters a submitted/waiting state. Clear asks confirmation only when it would discard strokes; Undo is immediate. Private rounds expose only assigned content. Reveal controls follow session authority and do not leak later entries. Quiet rounds are proposed; restoring voice must preserve the user’s earlier mute choice. Character counter must be calculated from actual text, not copied from art.

Pengloo Party is the game title. These are raster UI concepts, not implemented Godot scenes. World art, player proportions, example data, keys and menus shown are illustrative; the original penguin model reference remains authoritative.
