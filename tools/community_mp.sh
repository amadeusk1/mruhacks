#!/bin/zsh
# tools/community_mp.sh: end-to-end community servers on this machine (spec: Engine Specs/Community Servers.md).
#  1. services/lobby on :8196
#  2. a dedicated server with --public (+ a stand-in cinema gateway) registering with that lobby
#  3. two clients joining through ws://127.0.0.1:8196/s/<id> and seeing each other
#  4. a cinema request through /s/<id>/cinema/ reaching the host's gateway, cookie path scoped
#  5. the official path (a plain dedicated server, no --public) still works and isn't listed
# Every process is killed at the end; Godot runs hold the shared lock (one heavy run at a time).
cd "${0:A:h}/.."
G="${GODOT:-$HOME/Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot}"
T=$(mktemp -d); LB=http://127.0.0.1:8196; pids=()
cleanup() { for p in $pids; do kill -9 $p 2>/dev/null; done; }
trap cleanup EXIT
fail() { echo "E2E_FAIL $1"; exit 1; }
(cd services/lobby && go build -o $T/lobby .) || fail "lobby build"
LOBBY_LISTEN=127.0.0.1:8196 $T/lobby > $T/lobby.log 2>&1 & pids+=$!
mkdir -p $T/gw/cinema && print -n "gateway-ok" > $T/gw/cinema/ping.txt
python3 -m http.server 8197 --bind 127.0.0.1 --directory $T/gw > $T/gw.log 2>&1 & pids+=$!
sleep 1
PENGLOO_LOBBY_BASE=$LB PENGLOO_HOST_TOKEN=e2e-community-token-0001 "$G" --headless --path . -- --dedicated --net-ws --net-port=7791 \
  --public "--server-name=E2E Igloo" --max-players=6 --cinema=127.0.0.1:8197 > $T/host.log 2>&1 & pids+=$!
for i in {1..60}; do grep -q "LOBBY listed as" $T/host.log && break; sleep 1; done
grep -q "LOBBY listed as" $T/host.log || { tail -20 $T/host.log; fail "host never listed"; }
LIST=$(curl -s $LB/lobby/servers); echo "list: $LIST"
URL=$(print -r -- $LIST | python3 -c "import json,sys;s=json.load(sys.stdin)['servers'];print(s[0]['url'] if s and s[0]['name']=='E2E Igloo' and s[0]['cinema'] and s[0]['max']==6 else '')")
[ -n "$URL" ] || fail "listing wrong"
print -r -- $LIST | grep -q '127.0.0.1\|"ip"' && fail "listing exposes an address"
for r in a b; do PENGLOO_WS_URL=ws://127.0.0.1:8196$URL "$G" --headless --path . res://tools/community_mp.tscn -- --role=$r > $T/client_$r.log 2>&1 & pids+=$!; done
for i in {1..80}; do [ $(grep -h "COMMUNITY_" $T/client_a.log $T/client_b.log 2>/dev/null | wc -l) -ge 2 ] && break; sleep 1; done
grep -h "COMMUNITY_" $T/client_a.log $T/client_b.log
[ $(grep -h "COMMUNITY_PASS" $T/client_a.log $T/client_b.log | wc -l) -eq 2 ] || fail "relayed clients"
CIN=$(curl -s -D $T/cin.h $LB$URL/cinema/ping.txt); echo "cinema via relay: $CIN"
[ "$CIN" = "gateway-ok" ] || fail "cinema tunnel"
curl -s "$LB/s/nope/cinema/ping.txt" | grep -q offline || fail "unknown server cinema"
# official path: not listed, capped at 1 here; a full refusal carries the reason; the admin code bypasses it
ADMIN=$(openssl rand -hex 12)
PENGLOO_ADMIN_CODE=$ADMIN "$G" --headless --path . -- --dedicated --net-ws --net-port=7792 --max-players=1 > $T/official.log 2>&1 & pids+=$!
sleep 6
PENGLOO_WS_URL=ws://127.0.0.1:7792 "$G" --headless --path . res://tools/community_mp.tscn -- --role=o --want=1 > $T/client_o.log 2>&1 & pids+=$!
sleep 5
PENGLOO_WS_URL=ws://127.0.0.1:7792 "$G" --headless --path . res://tools/community_mp.tscn -- --role=f --expect-full > $T/client_f.log 2>&1 & pids+=$!
PENGLOO_WS_URL=ws://127.0.0.1:7792 "$G" --headless --path . res://tools/community_mp.tscn -- --role=x --want=1 --admin=$ADMIN > $T/client_x.log 2>&1 & pids+=$!
for i in {1..60}; do [ $(grep -h "COMMUNITY_" $T/client_o.log $T/client_f.log $T/client_x.log 2>/dev/null | wc -l) -ge 3 ] && break; sleep 1; done
grep -h "COMMUNITY_" $T/client_o.log $T/client_f.log $T/client_x.log
[ $(grep -h "COMMUNITY_PASS" $T/client_o.log $T/client_f.log $T/client_x.log | wc -l) -eq 3 ] || fail "official server cap/admin"
grep -q "refused full 1/1" $T/client_f.log || fail "full reason"
[ $(curl -s $LB/lobby/servers | python3 -c "import json,sys;print(len(json.load(sys.stdin)['servers']))") -eq 1 ] || fail "official server got listed"
echo "E2E_PASS community servers (logs: $T)"
