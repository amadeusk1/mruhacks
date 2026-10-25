#!/usr/bin/env bash
# Invite end-to-end: dedicated server + owner + guest on a spare port. Exit 0 = all checks passed.
set -u
cd "$(dirname "$0")/.."
: "${GODOT:?Set GODOT to the Godot 4.7.2 executable}"
PORT=${PORT:-7791}
LOG=${LOG_DIR:-/tmp}
"$GODOT" --headless --path . -- --net-host --dedicated --net-port=$PORT > $LOG/invite_server.log 2>&1 &
SERVER=$!
trap 'kill -9 $SERVER ${OWNER:-} 2>/dev/null' EXIT  # never leave a Godot behind
# the server builds the town before it can answer hellos (clients give up after 6 s)
for i in $(seq 120); do grep -q "Snow navmesh polygons" $LOG/invite_server.log && break; sleep 1; done
sleep 2
"$GODOT" --headless --path . res://tools/invite_mp.tscn -- --net-join --net-name=Owner --net-port=$PORT --role=owner > $LOG/invite_owner.log 2>&1 &
OWNER=$!
sleep 1
"$GODOT" --headless --path . res://tools/invite_mp.tscn -- --net-join --net-name=Guest --net-port=$PORT --role=guest > $LOG/invite_guest.log 2>&1
GUEST_RC=$?
wait $OWNER; OWNER_RC=$?
grep -h "INVITE_MP\|SCRIPT ERROR" $LOG/invite_owner.log $LOG/invite_guest.log
[ $GUEST_RC -eq 0 ] && [ $OWNER_RC -eq 0 ]
