# Interior Spacing Standard

Rooms must feel roomy for a group of penguins: nobody bumps shoulders at seats, and nobody queues single-file through a doorway. Measurements are in metres against the shared penguin: **0.98 m wide flipper to flipper, 0.65 m deep, 0.9 m tall**. The game's collision capsule is radius 0.30 m. Hub: [Art Pipeline](../Art%20Pipeline.md) · review findings in [Interior Review](Interior%20Review.md).

## Minimums

| Rule | Value | Why |
| --- | --- | --- |
| Seat centre to seat centre, side by side (stools, cinema seats, bar seats, casino seats) | **1.15 m** | 0.98 m penguin plus a gap, so flippers don't touch during sit, reach and cheer clips |
| Seats around a round table | Ring radius so neighbours are ≥ 1.15 m apart along the arc (4 seats → r ≥ 0.82 m; 6 → r ≥ 1.15 m) | Same |
| Clearance behind a seat (walk-behind) | **1.2 m** | A penguin can pass behind someone seated |
| Main aisle and circulation | **2.0 m** | Two penguins abreast |
| Secondary aisle (between table groups) | **1.4 m** | One penguin passes another sideways |
| Doorway clear width | **1.6 m** (double doors 2.0 m) | Two penguins can cross at the door |
| Entry zone inside the door | 2.5 × 2.5 m free | Arrivals spawn without landing on someone |
| Arcade or slot station front | 1.4 m deep standing zone; duo stations 1.15 m centre to centre | Side-by-side play with spectators behind |
| Spectator band behind play areas | 1.5 m | Watching without blocking players |
| Cinema rows | 1.4 m row pitch on risers, 1.15 m seat pitch, aisle 1.6 m | Legroom and readable sightlines |
| Wall to furniture (anything you walk around) | 0.9 m | No pinch points along walls |

## Room size targets (interior floor)

| Room | Target | Seats |
| --- | --- | --- |
| Café | about 10 × 8 m | 3–4 tables of 4, counter with 3 stools |
| Arcade | about 12 × 9 m | 5 solo cabinets plus 1 duo, token machine, bench |
| Casino | about 16 × 12 m | roulette 4, poker 6, blackjack 5, slots 4, lounge |
| Cinema lobby | about 12 × 10 m | counter, kiosk, lounge 4 |
| Cinema auditorium | about 14 × 12 m | 3 rows × 5–6 seats |
| Home shells | keep the existing cell masks, but every placed seat follows these rules | |

## Checks

1. **Seat spacing:** a script lists every pair of seat sockets closer than 1.15 m. It must report none.
2. **Clear routes:** a navmesh with agent radius **0.5 m** (not the 0.3 m capsule) must connect the door to every seat's approach point.
3. **Animation fit:** play the widest clips (anim_social sit, anim_casino reach_table and small_cheer_seated, emote_cheer) with neighbours seated on both sides. No flipper or body overlap.
4. **Visual check:** top-down screenshot of every room with the penguin footprint drawn at each seat, saved to `art/_wip/spacing_<room>.png`.
