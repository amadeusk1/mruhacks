# UI - Wardrobe and Inventory

[Pengloo Party - UI Mockups](Pengloo%20Party%20-%20UI%20Mockups.md) · [Pengloo Party - UI System and Flows](Pengloo%20Party%20-%20UI%20System%20and%20Flows.md)

![UI - Wardrobe and Inventory](concepts/UI%20-%20Wardrobe%20and%20Inventory.png)

## Screens

Wardrobe; body color; independent outfit slots; inventory.

## Behavior and implementation notes

Preview changes reversibly; Done saves accepted selection, closing cancels unapplied changes. Body tint does not recolor cream face or equipment. Hats, clothing and accessories remain separate. Fix the first panel tab: Hats should be selected when hat cards are shown, not Color. Items pictured are placeholders; do not treat camera, shovel or new hats as approved gameplay. Inventory actions depend on item type: Equip for wearable/held items, Place in home for furniture.

Pengloo Party is the game title. These are raster UI concepts, not implemented Godot scenes. World art, player proportions, example data, keys and menus shown are illustrative; the original penguin model reference remains authoritative.
