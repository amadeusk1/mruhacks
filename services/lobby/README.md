# Pengloo lobby (community servers)

Lists community servers and relays players to them through pengloo.party, so hosts need no port forwarding, domain or TLS. Design: `docs/Engine Specs/Community Servers.md`. Stdlib-only Go (its own minimal WebSocket in `ws.go`), in-memory: a restart forgets the list and servers re-register within seconds.

```sh
cd services/lobby
go test -race ./...
LOBBY_LISTEN=127.0.0.1:8096 go run .
```

| Route | Who | What |
| --- | --- | --- |
| `GET /lobby/servers` | game menu | `{"servers":[{id,name,players,max,version,region,official,host_ms,url}]}`. Never includes host addresses |
| `wss /host?token=…` | community server | control + data socket (protocol at the top of `main.go`). id = first 12 hex of sha256(token), stable per token |
| `wss /s/<id>` | player | relayed to that server, multiplexed over its host socket |

Environment (all optional): `LOBBY_MAX_PER_IP` (3), `LOBBY_MAX_PER_SERVER` (32), `LOBBY_MAX_CHANNELS` (300 relayed players in total), `LOBBY_SERVER_KBPS` (4000), `LOBBY_GLOBAL_KBPS` (40000), `LOBBY_OFFICIAL_IDS`, `LOBBY_BANNED_IDS` (comma-separated server ids), `LOBBY_BLOCKED_WORDS` (adds to the built-in name filter). Over a bandwidth cap the relay slows down (backpressure) rather than dropping game packets.

Behind nginx, `X-Real-IP` (from Cloudflare's `CF-Connecting-IP`) is trusted only from internal peers, as in the cinema gateway.
