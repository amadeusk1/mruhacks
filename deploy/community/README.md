# Host a Pengloo Party server

Your server appears automatically in everyone's **Servers** list on pengloo.party (web and desktop). Players join through the website: your computer dials out to pengloo.party, so there's no port forwarding, domain or certificate to set up.

## Easiest: the desktop app

Open Pengloo Party, press Play, choose **Host a Server**, give it a name and a player limit, and press **Start hosting**. To add movies, fill in the optional Cinema section (your own Emby server, API key, user ID, and a host code and viewer code you make up) and press **Test connection**. The cinema needs `ffmpeg` installed for the big screen. Leave the section empty to host without movies; the cinema then shows "No cinema on this server".

## Always-on: this Linux server package

1. `cp env.example .env` and set `SERVER_NAME` and `MAX_PLAYERS`.
2. `docker compose up -d`. The log shows `LOBBY listed as <id>` once you're in the list.
3. Optional cinema: `cp cinema.env.example cinema.env`, fill it in, `chmod 600 cinema.env`, uncomment `CINEMA_FLAG` in `.env`, then `docker compose --profile cinema up -d`.

Without Docker: `./pengloo.x86_64 --headless -- --dedicated --net-ws --public "--server-name=My Penguin Server" --max-players=16`, adding `--cinema-env=cinema.env` to start the included `pengloo-cinema` helper (install `ffmpeg` first).

## Good to know

- **Same version:** your server must match the version on pengloo.party, or it shows as "Outdated" in the list. Download a new package after a Pengloo Party update.
- **Your listing:** `data/` keeps your server's token, so it keeps the same id after restarts. Delete it to get a new id.
- **Names:** 3-32 letters, numbers and simple punctuation. Names can't impersonate the official server.
- **Cinema credentials:** your Emby details and codes stay on your machine. Sign-ins are per server: a code from one server never works on another, and the official server keeps its own codes.
- **Limits:** relayed bandwidth is capped per server (cinema traffic has its own, smaller cap; players see "Cinema bandwidth limit reached" when it's used up for the hour).
- **Moderation:** community servers aren't run or moderated by Pengloo Party, and players see that when joining.
