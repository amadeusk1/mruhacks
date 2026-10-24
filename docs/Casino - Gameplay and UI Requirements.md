# Casino - Gameplay and UI Requirements

[Casino - Concept Index](Casino%20-%20Concept%20Index.md) · [Dev Handoff - Data and Network Contracts](Dev%20Handoff%20-%20Data%20and%20Network%20Contracts.md) · [Dev Handoff - Self Hosting and Browser Release](Dev%20Handoff%20-%20Self%20Hosting%20and%20Browser%20Release.md)

Casino is new requested scope: roulette, slots, poker and blackjack. Keep its room and game sessions separate from the existing arcade. This note is a proposed implementation contract, not an implemented feature.

## Decisions before implementation

Choose final rules, table capacities, timers, play-chip allocation/persistence and departure/disconnect policy. Concept assumptions: single-zero roulette; three-reel themed slots; community-card poker (Texas Hold'em proposed); dealer blackjack. Confirm poker betting structure, blinds, side-pot rules and minimum players. Confirm blackjack deck count, dealer soft-17 behavior, payouts, double/split availability and any surrender rule. Slot symbol weights and outcome table require explicit data. Do not infer mechanics, probabilities, seat limits or reward values from images.

Play chips are used in the mockups. No money purchase, cash-out or redemption flow is specified. Whether chips reset per session or persist remains an open product decision.

## Shared lifecycle

Approach -> inspect rules/availability -> join/spectate -> server reserves seat -> receive current state -> ready or wait for next round -> make legal actions -> server settles -> show result -> play again or leave.

Show occupancy, rules/help, clear play-chip balance if used, reconnecting, waiting, unavailable, full-table and insufficient-chip states. Include keyboard focus, selected-action confirmation, audio controls and reduced motion. Never hide the exit. Leaving mid-hand must explain the selected rule rather than silently deleting a committed action.

## Game state and controls

| Game | Server phase flow | UI / required exceptional states |
| --- | --- | --- |
| Roulette | Betting open -> lock -> spin presentation -> result -> settlement -> reopen | Choose chip and bet region; undo accepted bets only before lock; pending vs accepted state; late bet rejected; last result |
| Slots | Idle -> accepted spin -> result determined -> reel presentation -> settled | Show cost/rules if applicable; spin disabled pending; repeat request deduplicated; reconnect restores outcome |
| Poker | Seats/ready -> blinds/deal -> betting streets -> showdown -> settlement | Private hole cards, public board, pot, turn timer; fold/check/call/raise conditional on legality; raise amount validation; all-in and side pots if enabled |
| Blackjack | Bets/ready -> deal -> player turns -> dealer turn -> settlement | Hidden dealer card until reveal; hit/stand; double/split only when legal and implemented; per-hand totals, bust, push, result |

Use actual engine UI for cards/numerals/controls, not flattened concept screenshots. Keep players' hidden cards private on the network, including spectator snapshots, logs and reconnect payloads.

## Server authority and persistence

Server owns shuffle/random results, turn order, deadlines, legal actions, accepted commitments, chip totals and settlement. Clients send intent with session/round/action identifiers; validate seat identity, phase, balance and action legality. Use idempotency to prevent repeated debit/settlement on retry. Never trust client animation, reel state, wheel physics, displayed card or reported win as proof of a result.

If balances persist, record accepted rounds and settlement transactionally with recovery rules. If they are session-only, state reset behavior clearly. Define restart handling for unresolved rounds; never silently duplicate or lose a settled balance. Reconnect returns current public state plus only the returning player's authorized private state. A disconnected tab must not stop the table clock.

## Acceptance gates

Two clients race for one seat; only one succeeds. Duplicate actions settle once. Bets after lock and out-of-turn actions fail visibly. A hidden card is absent from other clients' payloads. Reconnect during spin/deal restores the same result. Timers remain server-owned when a browser tab sleeps. Rule fixtures cover ties, exhausted resources, invalid actions and the selected game's edge cases. Native and browser clients share one session with matching final state. Test the chip persistence/restart policy once chosen.
