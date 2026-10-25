# Decisions Register

[Dev Handoff - Start Here](Dev%20Handoff%20-%20Start%20Here.md)

## Confirmed

The working title is Pengloo Party. Simple original UI. Modular penguins, interchangeable gear and engine tinting. Player-decorated homes with grid placement. Cute movement and emotes. Cinema, arcade, fishing, sledding, snowballs, basketball and drawing telephone. Online server/backend support is needed and will run on the team’s own server. An eventual browser release at `https://pengloo.party` is required; the game domain is confirmed; see [Dev Handoff - Self Hosting and Browser Release](Dev%20Handoff%20-%20Self%20Hosting%20and%20Browser%20Release.md). All mockup/reference work goes into Obsidian and GitHub when committed.

## Resolve before their dependent work

| Decision | Suggested starting point | Must be resolved before |
| --- | --- | --- |
| Release sequence and browser matrix | Native first is proposed; eventual browser support is confirmed; prove both early | Network/media/voice transport, renderer and build pipeline |
| Own-server specifications and connectivity | Confirm OS, hardware, uplink, public reachability, operator and domain/DNS access | Deployment sizing and public endpoint setup |
| Identity model | Invite-only stable guest credential for prototype | Durable profiles, home ownership and join authorization |
| Account recovery/cross-device | Explicitly choose supported or deferred | Public account promises |
| Initial world capacity | Small measured playtest group | Capacity labels and load-test acceptance |
| Server authority model | Authoritative contested actions; plan server movement | Multiplayer activities and validation |
| Voice provider/stack | Prove native and browser integration and remote connectivity | Proximity voice implementation |
| Media playback adapters | plex-watchparty is the base; first live source can be Plex, Emby or Jellyfin; prove native and browser players | Cinema integration and export platform choice |
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


## Plex cinema integration update

The user selected plex-watchparty as the base for the first Plex integration. See [Cinema - Plex Watchparty Integration Plan](Cinema%20-%20Plex%20Watchparty%20Integration%20Plan.md) for verified source behavior, required adaptations and implementation gates. Playback adapters and deployment remain to implement.
