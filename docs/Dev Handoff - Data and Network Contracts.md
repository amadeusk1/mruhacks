# Data and Network Contracts

[Dev Handoff - Start Here](Dev%20Handoff%20-%20Start%20Here.md) · [Dev Handoff - Server and Deployment](Dev%20Handoff%20-%20Server%20and%20Deployment.md)

These are proposed interfaces to implement and adapt to the existing code, not live endpoints or existing schemas.

## Durable records

| Record | Minimum fields | Ownership and invariants |
| --- | --- | --- |
| PlayerProfile | stable playerId, displayName, appearance, revision, schemaVersion | Identity-owned; display name is not the primary key |
| Appearance | bodyColorId, equipped item IDs by slot | Catalog allowlist; keep body tint and clothing independent |
| ItemDefinition | stable assetId, version, category, slots, tint roles, placement footprint/layer, support slots | Server-known catalog; no arbitrary file paths from clients |
| PlayerInventory | playerId, item ownership/availability, revision | Server decides permission; prototype may grant a shared starter catalog |
| Home | homeId, ownerId, shellId, access policy, layout revision, schemaVersion | Owner edits; visitor access checked server-side |
| PlacedItem | instanceId, assetId, integer grid position, quarter-turn rotation, layer, color variant, optional parent/support slot | Unique IDs; acyclic support relations; bounded transforms |
| Preferences | audio volumes, input bindings, UI scale, motion preference, microphone intent | Usually device-local; do not publish microphone/device details in roster |
| Social records | friend state, block state, report ID/status | Optional service-backed features; private visibility as appropriate |

Changing a shell validates the complete resulting layout. Return non-fitting items to inventory in one transaction; do not silently delete furniture. Saved schema migrations must preserve old IDs or map them deliberately. Unknown retired assets should be recoverable as missing-item placeholders, not corrupt the whole home.

## Session records

World: worldId, build/protocol version, room registry, capacity and server clock. Player session: stable playerId, connection ID, room ID, authoritative transform/state, active activity ID and slot. Activity: sessionId, type, anchorId, phase, revision, participant slots, spectators, queue and deadlines. Only one active activity per player; slot reservations expire/release on leave and disconnect policy.

Game-specific state follows [Dev Handoff - Activity Specifications](Dev%20Handoff%20-%20Activity%20Specifications.md). Private drawing chains and media credentials are excluded from public snapshots. Separate public, participant-private and server-only serialization types rather than broadcasting one giant record and hiding fields in UI.

## Proposed HTTPS surface

| Operation | Input | Result / important errors |
| --- | --- | --- |
| Establish identity | supported guest/account credential | player identity/session; invalid or expired credentials |
| List worlds | client build/protocol | compatible records; no worlds or service unavailable |
| Request join ticket | worldId, requestId | ticket and endpoint; full, draining, incompatible |
| Read profile/home | authenticated identity and homeId | revisioned record; forbidden/not found |
| Update appearance | expectedRevision, permitted item/color IDs | accepted revision; conflict or invalid catalog item |
| Commit home edit | homeId, expectedRevision, requestId, bounded edit batch | accepted layout/revision; conflict, forbidden, invalid placement |
| Request provider access | authorized activity/session context | scoped voice/media access; provider unavailable |

Route names, language/framework and account provider are open. Use authenticated HTTPS, bounded payloads, versioned schemas and machine-readable error codes with short UI copy. Never return a success result before persistence/authorization succeeds.

## Realtime message envelope and authority

A client request carries requestId, sessionId, expectedRevision where relevant, action and bounded payload. The server derives player identity from the connection; it never trusts an actor field. Responses carry requestId, accepted/rejected, error code and resulting revision. Public events carry sessionId, monotonic event sequence, authoritative timestamp and event type.

Reliable messages: join/leave, reservation, ready, phase transitions, accepted shots/results, appearance changes and save acknowledgements. Frequent pose/input updates may use ordered lossy delivery where appropriate; newer snapshots supersede stale ones. Handle out-of-order revisions and duplicate requests. Cosmetic particles are reconstructed from event IDs, not networked individually.

Validate room/phase membership, finite numbers, range, cooldowns, item ownership and payload limits. The proposed authoritative target simulates contested movement/projectiles server-side. If client-produced movement remains temporarily, document bounds checks and its trust limitations; do not claim cheat-resistant gameplay. Remote clients interpolate snapshots; local prediction/reconciliation is an implementation decision to test against the chosen model.

## Persistence transaction rules

Home save: verify owner → load expected revision → validate shell, footprints, supports and clear exits → atomically apply edit plus revision increment → acknowledge. A repeated requestId returns the same outcome without duplicating furniture. A stale revision returns conflict with latest revision; UI can reload or offer an explicit merge, not silently overwrite another device. Keep request-ID retention bounded and defined.

Activity results that persist rewards/progress, if introduced, need an exactly-once result ledger keyed by session/attempt ID. The current scope does not require an economy. Do not persist every pose. Debounce ordinary preferences, and durably acknowledge appearance/home edits before showing Saved.

## Clock and reconnect

Use server time/deadlines for countdowns and match end; clients estimate display time and never decide victory from local clocks. Reconnect revalidates identity, restores a current snapshot and sends only the player's authorized private assignment. Expired sessions return to a safe room state. Duplicate tabs/connections need an explicit policy: reject the second or replace the first cleanly. Never leave phantom seats, cabinet stations or fishing spots.
