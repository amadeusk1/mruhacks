# Pengloo Party — Developer Handoff

**Working title: Pengloo Party.** The goal is a cozy multiplayer town of customizable penguins, with social activities and player-decorated homes. This handoff consolidates the original design brief and later requests; it is not a claim that the described systems already exist.

## Read in this order

1. [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) — original supplied brief, preserved unchanged.
2. [Dev Handoff - Scope and Current Code](Dev%20Handoff%20-%20Scope%20and%20Current%20Code.md) — confirmed scope, observed code, gaps.
3. [Dev Handoff - Server and Deployment](Dev%20Handoff%20-%20Server%20and%20Deployment.md) — online architecture and operations; [Dev Handoff - Self Hosting and Browser Release](Dev%20Handoff%20-%20Self%20Hosting%20and%20Browser%20Release.md) — own-server deployment and future web release.
4. [Dev Handoff - Data and Network Contracts](Dev%20Handoff%20-%20Data%20and%20Network%20Contracts.md) — identity, persistence, authority and message semantics.
5. [Dev Handoff - Activity Specifications](Dev%20Handoff%20-%20Activity%20Specifications.md) — all seven activities and acceptance requirements.
6. [Dev Handoff - Client UI Housing and Assets](Dev%20Handoff%20-%20Client%20UI%20Housing%20and%20Assets.md) — frontend, character, housing and art integration.
7. [Dev Handoff - Delivery and QA](Dev%20Handoff%20-%20Delivery%20and%20QA.md) — implementation order and release gates.
8. [Dev Handoff - Decisions Register](Dev%20Handoff%20-%20Decisions%20Register.md) — unresolved product and infrastructure choices.

Visual index: [Pengloo Party - UI Mockups](Pengloo%20Party%20-%20UI%20Mockups.md). Models and art: [Art Pipeline](Art%20Pipeline.md), [Models](Models.md), [Renders](Renders.md), [Engine Specs - Index](Engine%20Specs/Engine%20Specs%20-%20Index.md). These asset notes may advance independently of a Git snapshot; inspect the committed files and manifests before assuming a resource exists.

## Definitions of done

A concept is an image/specification. An asset is an inspectable exported resource. A feature is implemented only when it runs through its complete lifecycle in the game. An online feature is verified only after two separate clients on different networks can complete it and recover from a disconnect. A green connection banner, local demo, or static model does not meet those latter definitions.

Later direct user instructions take priority over old proposals. Confirmed: modular penguins, customizable houses with grid decoration, cute movement/emotes, simple UI, all requested activities, an online server on the team’s own hardware, and eventual browser access at the confirmed game domain `pengloo.party`. Proposed: provider choices, player caps, exact controls, rule numbers, deployment component layout, and public account policy. This package specifies them as decisions to resolve, not silently approved purchases or integrations.


## Plex cinema integration update

The user selected plex-watchparty as the base for the first Plex integration. See [Cinema - Plex Watchparty Integration Plan](Cinema%20-%20Plex%20Watchparty%20Integration%20Plan.md) for verified source behavior, required adaptations and implementation gates. Playback adapters and deployment remain to implement.
