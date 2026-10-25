# UI - Controls Accessibility and Service States

[Pengloo Party - UI Mockups](Pengloo%20Party%20-%20UI%20Mockups.md) · [Pengloo Party - UI System and Flows](Pengloo%20Party%20-%20UI%20System%20and%20Flows.md)

![UI - Controls Accessibility and Service States](concepts/UI%20-%20Controls%20Accessibility%20and%20Service%20States.png)

## Screens

Remappable controls; accessibility detail; microphone permission/device; media-source connection states.

## Behavior and implementation notes

Key bindings are illustrative and must read from actual input mapping. Use one push-to-talk binding consistently: the overview sheet says T while the detailed example says V; neither is finalized. Handle duplicate bindings with replace/cancel choices. Scale text/layout together without clipping. Mic access is optional, and Keep muted permits play. Media connection flow depends on selected provider; keep credentials private and show connection state truthfully. Connecting and failure boxes are alternatives, never concurrent states.

Pengloo Party is the game title. These are raster UI concepts, not implemented Godot scenes. World art, player proportions, example data, keys and menus shown are illustrative; the original penguin model reference remains authoritative.
