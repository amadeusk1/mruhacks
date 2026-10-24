# World Kit - Shoreline and Waterfront Details

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Prop Kits - Master Plan](Prop%20Kits%20-%20Master%20Plan.md)

![World Kit - Shoreline and Waterfront Details](concepts/World%20Kit%20-%20Shoreline%20and%20Waterfront%20Details.png)

Concept and assembly guidance, not a claim of newly completed models. Generated with the built-in image generation tool.

## Pieces

Sloped shore bank, inner/outer shore corners, pebble cluster, shallow-water patch, foam edge strip, dock end cap, dock ladder, mooring cleat, rope coil, boat fender and lantern bracket.

## Needed versus optional

Prioritize matching shore seams, closed dock edges and clean water transitions wherever the map exposes them. Ladder, cleat, coil and fender are optional visual dressing; their presence does not introduce swimming, climbing or boat-driving mechanics. Adapt existing `nature_dock`, `fishing` and `town_connections` pieces before making duplicates. Existing water tiles, rock clusters, docks, lamps and stream banks remain reusable.

## Assembly rules

Use the project's established water and deck heights, not the illustrative dotted waterline. Keep bank solid geometry, water, foam and snow overlays separate. Ensure inside/outside corners meet without gaps. A shallow-water material does not make the area traversable automatically. Decide collision and walking boundaries deliberately. Dock ladders should not obstruct fishing slots or suggest a usable route unless implemented. Rope coils can be static low-poly meshes; no rope simulation is required.

Related: [Prop Kit - Town Connections](Prop%20Kit%20-%20Town%20Connections.md), [Animation Kit - Ambient World](Animation%20Kit%20-%20Ambient%20World.md).
