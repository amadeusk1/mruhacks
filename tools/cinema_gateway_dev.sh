#!/bin/zsh
# tools/cinema_gateway_dev.sh [port]: (re)start the local cinema gateway from services/cinema and verify
# the NEW process is the one listening. Credentials come from ~/.config/pengloo/cinema.env (never printed).
PORT=${1:-8097}
cd "${0:A:h}/../services/cinema"
for pid in $(lsof -tnP -i :$PORT -sTCP:LISTEN); do kill $pid; done
for i in {1..20}; do [[ -z $(lsof -tnP -i :$PORT -sTCP:LISTEN) ]] && break; sleep 0.25; done
CINEMA_LISTEN=127.0.0.1:$PORT CINEMA_ORIGIN=http://127.0.0.1:$PORT ${CINEMA_WEB_DIR:+CINEMA_WEB_DIR=$CINEMA_WEB_DIR} \
  nohup env GOTOOLCHAIN=auto go run . --env ~/.config/pengloo/cinema.env > /tmp/cinema_gateway_$PORT.log 2>&1 &
for i in {1..120}; do curl -sf -m 1 http://127.0.0.1:$PORT/cinema/health >/dev/null && break; sleep 0.5; done
started=$(ps -o lstart= -p $(lsof -tnP -i :$PORT -sTCP:LISTEN) 2>/dev/null)
echo "gateway on :$PORT started $started"; tail -1 /tmp/cinema_gateway_$PORT.log
