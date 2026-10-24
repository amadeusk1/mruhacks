# Map Art Direction: Handcrafted Pass

What "handcrafted" means for the Pengloo Party town, written against the concepts: [World Map - Island Concepts](../World%20Map%20-%20Island%20Concepts.md) (the overview for mood, the overhead for layout), `Images/World Map Concept.png`, `08 Waterfront Plaza`, `03 Cafe Exterior`, `07 Personal Cottage` and `16 Sledding Hill`. Hub: [Art Pipeline](../Art%20Pipeline.md).

## What reads as procedural today (before shots, 2026-10-24)

1. **Jagged path edges.** Paths are terrain triangles with a paving material, so the edges zig-zag in 1 m triangle steps (clearest in the homes shot). The concepts have soft, curving edges lined with stones and a lip of snow.
2. **Uniform spacing.** Lanterns every 5 m alternating sides, planters at fixed offsets, mailboxes dropped onto paths. Real towns cluster things where people use them.
3. **An empty plaza disc.** The concept plaza has an inner ring around the fountain in a contrasting stone, planters with small trees on that ring, benches facing the fountain from the ring, lamp pairs at the spoke mouths, and bunting overhead. Ours is a big blank cobble disc.
4. **Flat snow.** No drifts, no snow banked against walls, fences or rocks, no snow lips on path edges.
5. **No storytelling.** Nothing shows that penguins live here: no sleds left by doors, no snowmen, no stacked crates, no washing lines, no mugs on café tables.

## Rules

- **Paths are their own meshes:** a smooth ribbon (Catmull-Rom spline, about 0.3 m segments) for each path, with a raised edge-stone curb on both sides (use the plaza_edge and town_connections curb profile) and a soft snow lip overlapping the outer edge. Junctions blend into rounded aprons. Paving slabs are laid along the ribbon, following its curve. Terrain under a path is flattened and hidden. No terrain-material paths.
- **The plaza has a pattern:** an inner fountain ring (radius about 3.2 m) in darker stone, radial courses outward, and a contrasting border band at the rim. The inner ring holds 4 small trees in round planters, 4 benches facing the fountain, and flower beds between them. Lamp pairs flank each spoke mouth. Bunting strings run from lamp to lamp across the cinema approach.
- **Cluster with intent.** Every prop belongs to a vignette with a purpose: rest (bench, lamp, planter, view), shop frontage (chalkboard, crates, barrel, flower pots by the door), home (mailbox at the gate, garden bed, a sled leaning by the door, porch lamp, a little snowman), dock work (crates, rope coils, a bucket, nets, a fish stand) and so on. Vary spacing and rotation by hand, and keep things asymmetric.
- **Planting beds, not dots:** flowers go in edged beds hugging building walls, the plaza ring, gate posts and fence corners. Shrubs anchor building corners. Never put a lone flower in open snow or on paving.
- **Snow drifts:** banked snow (snowbank_small/medium, snow_puff) against the windward wall of every building, along fences and at the base of rocks and trees. Gentle mounds break up flat lawns. Snow lips on cliff tops (snow_overlay_*).
- **Lighting rhythm:** lantern pairs at entrances and junctions, wall_lantern on facades, string lights over the café terrace and plaza approach. Lamps are not on a fixed spacing along paths.
- **Framing:** trees and rocks frame each destination's entrance and views between districts, as in the overview. Keep sight lines from the plaza to the cinema, café and arcade open.
- **Walk zones stay clear:** follow the existing checks. No prop footprint within 0.3 m of a walkable surface edge.

## Vignette list (author these by hand as data in town.py)

| Where | Vignette |
| --- | --- |
| Plaza | Fountain ring set; a cinema-approach bunting canopy; the world map board with a bench by the south spoke; a café terrace (round tables, stools, umbrellas, string lights, menu chalkboard, flower pots) |
| Cinema | Queue lane with stanchions and queue markers, topiaries flanking the stair, posters lit by wall lanterns, a popcorn cart corner (crate, cup props) |
| Arcade | Double control deck outside as a demo, arcade bench, crates of tokens, a neon-feel chalkboard |
| Casino | Lantern pair, planters, a stanchion-rope entry, a coat-stand silhouette by the door |
| Homes | Per lot: a fenced garden bed, mailbox at the gate, a porch or porch_canopy, a sled or shovel by the door, a lit window, and a snowman on one lawn. Different roof tints. Stepping-stone paths from street to door |
| Dock | Crates and barrels by the boathouse, rope coils and cleats on piers, a fish stand with a bucket, the life ring on a post, the rowboat moored with fenders, a dock lantern bracket at the pier head, ice floes in the cove |
| Stream | Stones along the banks, a picnic spot (bench, lantern, crate) by one bridge, rails on the bridge approaches, snow-capped rocks in the water |
| Sled hill | Start gate with pennants and a lit queue, the start light and checkpoint posts, sleds parked at the finish, a warm-up bench with a lantern, a snowman by the run-out, fences following the track curve |
| Arena | Team flags, ready pads, snowball piles, a spectator bench row, the scoreboard, snow walls at the boundary |
| Court | Gate, gear crate, ball rack with balls, benches, shooting spots, a scoreboard, a lamp pair |
| Sketch Club | Outdoor easel, a second small table with stools, a pencil cup, a notice board, bunting |
| Coast | Boulders in grouped clusters, ice floes, a small lighthouse landmark on a point (homes/lighthouse_loft_exterior), and the houseboat in the cove |

## Done when

Side-by-side shots (gameplay camera and overview) of each district, next to the matching concept crop, read as "the same place". Comparisons go in `Renders/Map/handcrafted_<district>.png`.
