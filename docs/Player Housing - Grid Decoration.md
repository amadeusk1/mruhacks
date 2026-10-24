# Player Housing — Grid Decoration

## Confirmed direction

Players can customize their own house by placing and arranging furniture and decoration props on a grid. Homes are personal spaces to decorate, not fixed furnished scenes. House shapes and interior personalities in the concept sheets are visual explorations, not a locked list of unlocks or purchases.

Read alongside [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md), [Player Housing - Shape and Interior Concepts](Player%20Housing%20-%20Shape%20and%20Interior%20Concepts.md), and [Player Housing - Decoration Prop Catalog](Player%20Housing%20-%20Decoration%20Prop%20Catalog.md). The original brief is preserved unchanged.

## Proposed decorating flow

1. Enter decoration mode in your house; show the placement grid and your furniture inventory.
2. Choose an item and preview it at the cursor, snapped to a valid grid position.
3. Move and rotate the preview; indicate valid versus blocked placement clearly.
4. Place it, then select existing items to move, rotate, recolor where supported, or return to inventory.
5. Save the layout and return to the normal house view with the grid hidden.

These interaction details are proposed defaults. Exact input bindings, cell size, item limits, ownership economy, and unlock rules remain undecided.

## Proposed placement rules

- Use a common square floor grid. Each house shape defines which cells are usable; round houses and irregular rooms use a valid-cell mask rather than forcing every house to be rectangular.
- Start with 90-degree rotation for floor furniture. Rotate its footprint with the object.
- Keep entry/exit space and required interaction clearances usable. Furniture cannot overlap solid walls or another blocking item.
- Use separate placement layers: rugs on the floor beneath furniture; furniture on the floor; wall art/shelves on compatible wall slots; ceiling decorations on ceiling anchors.
- Small objects may sit on defined table or shelf surfaces. Surface placement is separate from floor occupancy, so a mug does not consume a whole floor cell.
- Show a clear rejection reason when placement fails. Moving an existing item should be cancelable without losing its previous position.
- The owner edits by default; visitor editing permissions are a separate future decision.

## Asset requirements

Furniture must remain separate reusable assets. Decorative objects drawn on a table in a concept image are not automatically fused to the table. Define a stable placement origin, footprint, collision bounds, rotation options, placement layer, optional supporting surfaces, interaction points, and recolorable material regions for each item.

Keep meshes chunky and readable in the established low-poly style. Coordinate scale with the shared bird avatar and maintain usable seats, doors, and arcade controls. Body colors and supported furniture colors can be material variants in-engine rather than duplicate meshes.

## Persistence and implementation proposal

Save a house type plus placed-item records containing a stable instance ID, catalog asset ID, grid position, rotation, placement layer, color variant, and optional supporting-item ID/surface offset. Reload should reconstruct the same arrangement. Multiplayer placement should validate ownership and occupancy before synchronizing the accepted layout.

This is design documentation, not a claim that a decoration editor or multiplayer persistence has already been implemented.
