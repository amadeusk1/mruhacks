# Decisions Register

[Dev Handoff - Start Here](Dev%20Handoff%20-%20Start%20Here.md)

## Confirmed

Waddle World is the placeholder title. Simple original UI. Modular penguins, interchangeable gear and engine tinting. Player-decorated homes with grid placement. Cute movement and emotes. Cinema, arcade, fishing, sledding, snowballs, basketball and drawing telephone. Online server/backend support is needed. All mockup/reference work goes into Obsidian and GitHub when committed.

## Resolve before their dependent work

| Decision | Suggested starting point | Must be resolved before |
| --- | --- | --- |
| Target platforms | Native desktop first to match current Godot project | Network/media/voice transport and build pipeline |
| Hosting owner, region and budget | One small dedicated world deployment plus application service/DB | Provisioning or purchasing infrastructure |
| Identity model | Invite-only stable guest credential for prototype | Durable profiles, home ownership and join authorization |
| Account recovery/cross-device | Explicitly choose supported or deferred | Public account promises |
| Initial world capacity | Small measured playtest group | Capacity labels and load-test acceptance |
| Server authority model | Authoritative contested actions; plan server movement | Multiplayer activities and validation |
| Voice provider/stack | Prove native Godot integration and remote connectivity | Proximity voice implementation |
| Media provider/player | One verified end-to-end source | Cinema integration and export platform choice |
| Basketball mode | Shooting contest first; full possession remains visible | Final input/UI and gameplay implementation |
| Sled format/collisions | Time trial first, nonblocking racers if shared | Race logic and collision tuning |
| Snowball numbers | Configurable 2v2/timer/hit target proposal | Final balance and lobby limits |
| Drawing size/timers/voice | Configurable roster/timers; quiet rounds proposal | Match rules and voice routing |
| Home access and shell migration | Owner edits; access policy; return displaced items | Persistence and editor behavior |
| Friends/reports | Service-backed or explicitly deferred | Enabling related social buttons |
| Text chat | Inspect existing chat prototype and choose routing/history policy | Expanding beyond current chat behavior |
| Input scheme | Use existing actions, remappable prompts | Finalizing hints/controls; screenshots conflict on T/V |
| Performance target | Set device/capacity budgets from measurements | Release gate |

These are deliberate implementation choices, not reasons to block unrelated work. Continue shared UI, schema tests, asset inspection and baseline cleanup while provider/hosting choices are pending. Do not invent paid services or API capabilities to make the plan look complete.
