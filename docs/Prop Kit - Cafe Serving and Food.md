# Prop Kit - Cafe Serving and Food

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Gallery](Gallery.md)

Concept reference only; this sheet does not itself implement models or animation. Generated with the built-in image generation tool.

![Cafe Serving and Food Prop Kit](concepts/Cafe%20Serving%20and%20Food%20Prop%20Kit.png)

## Catalog and reuse

Croissant, muffin, cake slice, cookie, plate, saucer, teacup, takeaway cup/lid, tray, teapot, milk jug, sugar jar/lid, napkin holder, spoon, pastry tongs, and cake dome/base.

Existing café exports already include croissant, muffin, cake slice, plate, takeaway cup, sugar jar, mugs and assembled pastry plates. The room kit has a teapot set and cookie plate. Reuse those where they match rather than duplicating assets. Saucer, serving tray, milk jug, napkin holder, standalone spoon/tongs and cake dome are additional concept targets; component separation still needs review.

## Modular authoring

Keep food, plates, cups, lids and utensils separate. Provide surface-placement pivots and optional grip sockets. Assembled trays are presets referencing the parts, not fused meshes. Support tintable ceramic accents and a separate transparent dome material. Steam attaches above liquid; never bake smoke into the cup mesh. Small tabletop props should use support slots or a tabletop placement layer rather than consuming a full floor cell.

Food and serving gestures are optional decoration/social polish, not confirmation of hunger, purchases, or a café job minigame. See [Animation Kit - Everyday Penguin Interactions](Animation%20Kit%20-%20Everyday%20Penguin%20Interactions.md).
