# Post-login menu-driven Home

Status: T001–T012 implemented. Confirmed menu transport, scoped cache/lifecycle, menu-driven Home, mock native features, web benefits and reactive guards are delivered. Deterministic validation and file/task evidence are recorded in batch-report.yaml and checkpoints/tasks-to-impl.yaml. Live backend and native-device sign-off remain outstanding.
Sources: user request, [product spec](../PROJECT_SPEC.md), [coding standards](../CODING_STANDARDS.md).

## 1. Goal

Build post-login navigation exclusively from server-returned menu keys intersected with one mobile registry, with safe scoped cache fallback and guarded routes.

## Existing integration points

Flutter/Riverpod/go_router/dio and auth already exist. Reuse the protected access-token client, typed failures, strings, theme and injected clock. Check installed package APIs before implementation; no new dependency is planned.

`lib/core/routing/app_router.dart` currently redirects every location to `sessionDestination`, so it cannot support navigation among tiles without changing that redirect policy. `RolePolicy` and `role_landing_screens.dart` currently register `/home`, `/scan`, `/unsupported`; remove their role-based landing responsibility for this increment, not their group mapping.

Preserve auth expiry/renewal and the existing no-shop gate. Successful token renewal updates auth-view revisions; those revisions must NOT clear/reload the menu as if a new login occurred. Use explicit stable account/session ownership and login/logout hooks. No migration topology/constitution was supplied; repository standards govern this incremental feature.

Constraints: no prices in queue mock models; no real attendance, claiming, payment, customer creation or shop switching. Client menu guards are UX, never authorization. No framework-migration guidelines apply.

### Confirmed menu API and supplied example

`GET {baseUrl}/api/navigation/me` with query parameter `shopId` equal to the selected validated shop ID, authenticated with `Authorization: Bearer <accessToken>`. Use dio queryParameters, not hand-built string concatenation. Never send a blank shopId; wait for existing shop-context selection/gating.

The supplied read-only response is a top-level JSON array of nodes; each node has a `menuKey` and `children` array (empty for leaves), alongside web-only metadata. Traverse all levels. The example contains 6 root nodes and 34 total nodes, all `isActive: true`. Empty `roles` arrays still do not change mobile behavior.

Matched keys are `bookings-pending`, `bookings-in-progress`, `shopdashboard`, `shop-offers-2`, `shop-credits-packages`, `shop-memberships`. Expected projection: five tiles, Operations with both tabs, landing at Home. Ignore the other 28 keys, but still traverse their children. No implementation dependency on the temporary attachment path; use a trimmed synthetic contract fixture when implementing tests.

## 2. File list

Paths below are proposed new files unless marked existing.

| Path | Responsibility |
|---|---|
| `lib/features/menu/domain/menu_snapshot.dart` | Immutable normalized keys, scope, fetch time and cache schema |
| `lib/features/menu/domain/menu_repository.dart` | Fetch/read/write/clear interface; no endpoint assumptions |
| `lib/features/menu/data/menu_response_dto.dart` | Validate envelope and recursively flatten children |
| `lib/features/menu/data/menu_repository_impl.dart` | Confirmed GET through existing protected client, failure mapping |
| `lib/features/menu/data/menu_cache_store.dart` | Versioned, scope-checked durable cache and serialized clear/write |
| `lib/features/menu/data/mock_menu_repository.dart` | Explicit demo/test responses matching the confirmed array contract |
| `lib/features/menu/presentation/menu_dependencies.dart` | Repository/cache/clock/throttle wiring |
| `lib/features/menu/presentation/menu_controller.dart` | Initial load, single-flight refresh, stale fallback, lifecycle and logout |
| `lib/features/menu/presentation/mobile_menu_registry.dart` | ONLY key-to-tile mapping, mobile title/icon/route/kind/order and tab keys |
| `lib/features/menu/presentation/menu_projection.dart` | Pure registry intersection, tile deduplication and landing decision |
| `lib/features/menu/presentation/menu_gate_screen.dart` | Initial loading/error + Retry/Logout |
| `lib/features/menu/presentation/no_access_screen.dart` | Successful empty projection + refresh/Logout |
| `lib/features/home/presentation/home_screen.dart` | Permitted tiles, pull-to-refresh and cache notice |
| `lib/features/home/presentation/home_tile.dart` | Reusable token-styled tile widget |
| `lib/features/queue/domain/queue_item.dart` | Price-free immutable mock queue item |
| `lib/features/queue/data/mock_queue_repository.dart` | Deterministic placeholder data, no real booking endpoints |
| `lib/features/queue/presentation/queue_controller.dart` | Mock data and permitted-tab selection |
| `lib/features/queue/presentation/queue_screen.dart` | Only allowed Pending/In progress tabs; clearly placeholder behavior |
| `lib/features/dashboard/presentation/dashboard_screen.dart` | Native placeholder, no fabricated KPI data |
| `lib/features/upsell/presentation/web_feature_screen.dart` | Shared web-only feature benefits and confirmed web destination |
| `lib/core/routing/menu_route_policy.dart` | Pure route/landing/tab checks from projected registry entries |
| `lib/core/routing/app_router.dart` (existing) | Routes, reactive redirects, safe stack replacement on access changes |
| `lib/app.dart` (existing) | Add menu resume coordination alongside existing auth lifecycle |
| `lib/features/auth/presentation/auth_controller.dart` (existing) | Minimal lifecycle cleanup hooks; preserve login/refresh logic |
| `lib/features/auth/domain/role_policy.dart` (existing) | Retain role mapper; retire role-only landing decisions |
| `lib/features/auth/presentation/role_landing_screens.dart` (existing) | Remove obsolete Home/Scan routing registrations |
| `lib/features/shop_context/presentation/shop_context_controller.dart` (existing) | Stable selected-shop/menu scope integration, no real switching |
| `lib/core/localization/app_strings.dart` (existing) | Mobile titles/messages/placeholder and stale-cache strings |
| `lib/core/logging/app_logger.dart` (existing) | Existing logger/event hook for upsell tap events, no personal data |
| `test/features/menu/`, `test/core/routing/`, `test/features/queue/` | Deterministic projection/cache/race/navigation/tab coverage |

Do not create duplicates of core networking, session storage, theme or error vocabulary.

## 3. Registry and models

### Menu domain

- `MenuScope`: account identity plus selected shop ID. Use server userId and Cognito subject where available. The endpoint is shop-scoped; never scope by display role alone.
- `MenuSnapshot`: immutable exact `Set<String> menuKeys`, scope, fetchedAt and schemaVersion. Persist normalized keys, not tokens or the unnecessary web tree.
- `MenuView`: snapshot and refresh status, source (network/cache), last successful refresh time and optional typed failure/stale notice. AsyncValue covers boot/error; background loading must not discard an existing snapshot.
- Repository returns a genuine empty snapshot for a valid empty menu. Null/corrupt response is a typed contract failure, not an empty/no-access success.

### Tree flattening

Recursively visit every node and its children, collecting exact menuKey strings into a set. Traverse unknown parents so recognized children still work. Deduplicate repeated keys. Never derive identity/grouping from id, parentId, label, routePath, icon, featureKey, roles or displayOrder.

Use registry order, not web displayOrder. Do not hide a child because its parent is unregistered. Do not normalize case or invent aliases. Validate the confirmed top-level array, nonempty string menuKeys and children arrays rather than casting blindly; malformed consumed fields should fail explicitly instead of silently yielding no access. Missing/null children behavior is not demonstrated; treat it as a typed contract failure unless the backend documents an alternate leaf representation.

The requested rule is key membership only: no additional client roles/isActive filters. Confirm the server excludes inactive entries; if it returns them, resolve that API inconsistency before adding another predicate.

### ONE mobile registry

Proposed immutable presentation models:

- `MobileTileDefinition`: accepted menuKeys, localized title key, Flutter icon, fixed mobile route, `TileKind.native/webOnly`, order and optional queue-tab descriptors.
- `AvailableTile`: its registry definition plus the matched keys. Operations appears once even when both keys are present.
- `QueueTabDefinition`: its required menuKey, local title and tab selector. Define Pending/In progress bindings in the SAME registry, not another hard-coded key list.

No separate tile ID. Definitions bind menuKeys to fixed mobile UI; route lookup and tile presence derive from those definitions. One key-to-definition registry change enables a supported key without rewriting projection, Home or generic guards; a new native feature additionally supplies its screen/route builder.

| Accepted exact menuKey(s) | Mobile title | Mobile icon | Route | Kind | Order |
|---|---|---|---|---|---|
| `bookings-pending`, `bookings-in-progress` (ANY) | Operations | content_cut | `/queue` | native/mock screen | 10 |
| `shopdashboard` | Dashboard / KPI | bar_chart | `/dashboard` | native placeholder | 20 |
| `shop-offers-2` | Offers | local_offer_outlined | `/web/offers` | webOnly | 30 |
| `shop-credits-packages` | Credits & Packages | card_giftcard | `/web/credits-packages` | webOnly | 40 |
| `shop-memberships` | Membership | diamond_outlined | `/web/membership` | webOnly | 50 |

Operations tab membership: Pending requires `bookings-pending`; In progress requires `bookings-in-progress`. If only one key exists, show only that tab, not a disabled unauthorized tab. Default to first permitted registry tab; an unauthorized tab deep link redirects to that default.

**Add customers:** confirmed out of scope for now. Absent from the registry and hidden, including demos. Do not infer permission from owner role or Dashboard/Operations keys.

### Home visual reference

Use the current `index.html` landing screen as reference, not its role-selection/demo logic:

- Compact profile row: existing 42px rounded logo crop, "Welcome back", validated shop name and server-derived display role, with a white Logout pill. Use the current HTML's defined CSS 160-degree header gradient (`#4A8DF0` -> `#1560C4`) and 28px rounded bottom corners. The confirmed shop-logo contract below replaces local-only artwork without changing geometry.
- Rounded prominent native tiles: Operations teal gradient `#17A590` -> `#0B7D6E`; Dashboard orange gradient `#F7A41D` -> `#E8820C`, each at CSS 135 degrees with shared gradient tokens.
- Tile subtitles "Queue and services" and "Today's performance" remain mobile-owned localized strings.
- Registered webOnly tiles are regular horizontal cards with a visible, semantic **Web only** badge; remove the "More on Bookixo web" heading and mini-card grid. Retain existing benefits routes, logging and unavailable CTA; the benefits page says **Currently available on Bookixo web**.
- Keep exactly one Credits & Packages card. The HTML has separate Credits and Packages; the requested registry takes precedence. Omit Add customers completely.
- Preserve registry sorting in one unified list; do not use server labels/icons/order or the mockup's membership-first order. The registry owns each card's shared background definition, alongside unchanged keys/kinds/routes/tabs.
- At 390x780: 20px body margins, 8px header/card overlap, horizontal 22px-padded cards with 34px icons, 18px bold titles / 15px body copy, 14px card gaps and 22px radii. Web tiles are full-width regular cards using shared blue/purple palette tokens and high-contrast badges.
- Match light/dark palette through core tokens, not inline screen constants. Header and cards grow at large text sizes, including 2.5x on 320px screens. Always-scrollable content supports pull-to-refresh with few tiles; minimum 48px targets. Manual refresh remains below cards; transient notices remain above cards without adding default spacing.
- Necessary accessibility deviations: Logout is at least 48px tall (HTML is smaller), long shop names/text may wrap, large text uses a stacked profile, and Dashboard uses dark ink on orange for readable contrast. Operations follows the current HTML's later teal override (`#17A590` -> `#0B7D6E`) rather than the earlier blue product statement.

Add Home gradient/layout tokens to existing `lib/core/theme/app_tokens.dart` and styles to `lib/core/theme/app_theme.dart` only where needed; no separate theme system.

### Confirmed Home logo increment (2026-10-06)

- Domain repository and immutable logo model in `lib/features/home/domain/`; status/body DTO and protected Dio repository in `data/`; scoped AsyncValue controller and widgets in `presentation/`.
- `GET api/shops/{shopId}/logo`, authenticated with the existing ACCESS Bearer protected client: 200 JSON with a valid HTTPS `logoUrl`; 204/no body is absence. Other failures retain the shared typed mapper; 401 uses existing bounded recovery/logout; 403 is never fabricated absence.
- No widget JSON/network-client logic. Built-in Flutter image loading is separate from protected Dio and receives no auth headers. Support actual JPEG/PNG bytes with query strings and no extension filtering.
- Default Bookixo artwork during loading/absence/failures. API/image failures use fixed logger contexts, typed provider errors and friendly nonblocking Retry.
- Presigned URLs are ephemeral memory-only values. Stable account + explicit login ownership + validated shop scope, single-flight refresh, late-response guards and targeted image eviction prevent old-account/shop artwork. No global cache clearing.
- Home pull/button refresh and each foreground entry refetch independently of menu freshness. Optional usable AWS signing metadata schedules expiry refresh; no assumed 900-second lifetime. One API retry after expired/403 image failure per refresh chain, none after ordinary decoding failure; explicit refresh resets the recovery budget.
- Deterministic contract, auth, scope/logout races, expiry/foreground/manual refresh, decoder and header/badge/permission regression tests are recorded in the current increment section of `batch-report.yaml`. Existing native mocks and unconfirmed web destinations remain unchanged.

## 4. Route table and guards

Guard precedence: locked/loading/error auth -> session gate; signed out -> Login; valid session but unusable shop context -> Shop gate; menu unavailable -> menu gate; then resolve permitted destination. Retain unknown-role unsupported handling for now, pending the question below; no role-based tile filtering is introduced.

| Route | Guard / behavior |
|---|---|
| `/` | Existing session initialization/recovery only |
| `/login` | Signed-out/action-required only; valid session proceeds through shop/menu gates |
| `/unsupported` | Existing unsupported-account handling, not role-specific Home |
| `/shop` | Existing shop loading/error/no-shop gate before menu/feature access |
| `/menu` | Initial menu loading or failure without usable scoped cache; Retry/Logout |
| `/no-access` | Valid projection contains zero registered tiles; refresh/Logout |
| `/home` | At least one tile AND not sole Operations; only Operations redirects to `/queue` |
| `/queue` | Operations exists; tabs independently guarded by their keys |
| `/dashboard` | Dashboard tile exists |
| `/web/offers` | Offers tile exists; renders upsell, not web management |
| `/web/credits-packages` | Credits & Packages tile exists |
| `/web/membership` | Membership tile exists |
| `/scan` (legacy) | Never enter attendance; redirect to current permitted landing |
| Unknown routes | Friendly not-found or safe landing; never interpret server routePath |

Landing projection: zero -> `/no-access`; exactly one Operations -> `/queue`; any other nonempty combination -> `/home` (even a sole Dashboard or webOnly tile).

Do not keep the current unconditional redirect-to-landing on every navigation: allow an already permitted route to remain. Gate arbitrary deep links before building protected content; after loading a usable snapshot, preserve the requested route only if permitted. Never send tokens through deep-link query parameters or web URLs.

Listen for menu/auth/shop changes. Replace inaccessible feature stacks with the safe current landing using router navigation-stack semantics verified for installed go_router. Root redirects alone must not leave removed screens resident underneath an overlay: prune/reset stacks, dismiss feature dialogs, invalidate removed-feature providers and re-check on pop/back. Also check the current queue tab when one key disappears but Operations remains.

Revocation to zero keys must immediately remove all feature routes. A successful empty network response REPLACES old cache; do not use fallback just because it produced no tiles.

## Cache and refresh policy

1. After every successful login, attempt network refresh before landing; use only a cache owned by the same account/scope on recoverable failure. Startup restoration follows the same refresh-first flow.
2. Persist versioned normalized keys with scope/time using an injectable durable cache store. Proposed reuse of secure storage avoids a new package; menu keys are not auth credentials. Storage choice is configurable, never a global unscoped cache.
3. Deduplicate refreshes. Confirmed freshness/refresh interval: 60 seconds. On resume, first let auth recovery run; refresh menu when its scope is ready, the snapshot is at least 60 seconds old and the resume-attempt throttle permits. Measure age and attempts with injected clock. Login/startup/manual pull/Retry bypass the resume throttle. This is trigger-based refresh, not new continuous polling.
4. Home uses always-scrollable pull-to-refresh, including a short tile list. Queue/no-access provide a refresh action because sole Operations has no Home.
5. On recoverable network/server/contract failure, use an existing validated same-scope snapshot and display a friendly stale-data notice with retry. Log sanitized failure context. With no cache, expose typed failure plus Retry/Logout. Never default to all tiles.
6. A successful fresh response replaces keys and reevaluates routes even if empty. If persistence fails after fresh data arrives, surface the storage failure but retain fresh keys for in-memory guards; do not roll back revocations to older cached keys.
7. Auth 401 recovery uses existing access-token refresh behavior. If the session is cleared/locked, clear/block menu too; do NOT bypass that with cached permissions. A menu 403 should block access rather than silently restoring cached access; confirm API error semantics.
8. Confirmed: 60 seconds is a refresh threshold, NOT a hard maximum fallback age. On recoverable failure allow an older validated same-account/same-shop snapshot with a stale warning. No hard age cutoff is specified. Server authorization remains mandatory; never use out-of-scope/corrupt snapshots or bypass invalid authentication with cache.
9. Logout immediately blocks projection, cancels pending work and increments menu ownership generation. Serialize cache writes/deletes so a late response cannot recreate old data. Clear durable menu cache and all menu/feature state before reporting logout complete; surface deletion failures and remain locked for retry.
10. Account/scope changes discard old in-memory keys before loading. Token rotation alone does not change ownership. Stale request completion must not populate the new user's/shop's cache.

## 5. Ordered implementation sessions

Tasks below are implemented. Demo and Queue data stay explicitly mock-only.

### P1.1 Contracts and scoped menu foundation
Requirements: REQ-001, REQ-002, REQ-005, REQ-009.
- [x] T001 [Plan:1.1] Define `lib/features/menu/domain/menu_snapshot.dart` and `lib/features/menu/domain/menu_repository.dart` using confirmed account/selected-shop scope and 60-second freshness.
- [x] T002 [Plan:1.1] Implement `lib/features/menu/data/menu_response_dto.dart` and `lib/features/menu/data/mock_menu_repository.dart` for recursive flattening of the confirmed top-level array; the supplied keys must project to five tiles.

### P2.1 Single mobile registry and projection
Requirements: REQ-002, REQ-003, REQ-004, REQ-007.
- [x] T003 [Plan:2.1] Add `lib/features/menu/presentation/mobile_menu_registry.dart`, `lib/features/menu/presentation/menu_projection.dart` and mobile titles in `lib/core/localization/app_strings.dart`; keep Add customers absent.

### P3.1 Cache-backed menu lifecycle
Requirements: REQ-001, REQ-005, REQ-006, REQ-009.
- [x] T004 [US1] [Plan:3.1] Add `lib/features/menu/data/menu_cache_store.dart` and `lib/features/menu/data/menu_repository_impl.dart`; call `api/navigation/me` with selected `shopId` via queryParameters using the existing access-token-authenticated protected client.
- [x] T005 [US1] [Plan:3.1] Add `lib/features/menu/presentation/menu_dependencies.dart` and `lib/features/menu/presentation/menu_controller.dart`; coordinate login/restore/resume in `lib/app.dart`, auth logout in `lib/features/auth/presentation/auth_controller.dart` and shop scope without token-rotation reloads.

### P4.1 Home and access gates
Requirements: REQ-004, REQ-006, REQ-010.
- [x] T006 [US2] [Plan:4.1] Add `lib/features/menu/presentation/menu_gate_screen.dart`, `lib/features/menu/presentation/no_access_screen.dart` and localized loading/error/stale/no-access strings.
- [x] T007 [US2] [Plan:4.1] Add `lib/features/home/presentation/home_screen.dart` and `lib/features/home/presentation/home_tile.dart` matching the HTML landing reference, with registry-derived tiles and pull-to-refresh; extend existing `lib/core/theme/app_tokens.dart` and `lib/core/theme/app_theme.dart` for shared tile/header styling.

### P5.1 Mock Queue and Dashboard
Requirements: REQ-003, REQ-010.
- [x] T008 [US3] [Plan:5.1] Add `lib/features/queue/domain/queue_item.dart`, `lib/features/queue/data/mock_queue_repository.dart`, `lib/features/queue/presentation/queue_controller.dart` and `lib/features/queue/presentation/queue_screen.dart`; no prices or live mutation buttons.
- [x] T009 [US3] [Plan:5.1] Add `lib/features/dashboard/presentation/dashboard_screen.dart` as a clear native placeholder.

### P6.1 Web-only tiles
Requirements: REQ-003, REQ-010.
- [x] T010 [US4] [Plan:6.1] Add `lib/features/upsell/presentation/web_feature_screen.dart` using mobile-owned benefits and existing sanitized event hook; use a confirmed web URL only, otherwise explicitly unavailable CTA.

### P7.1 Reactive route guards and legacy landing removal
Requirements: REQ-004, REQ-007, REQ-008, REQ-009.
- [x] T011 [Plan:7.1] Add `lib/core/routing/menu_route_policy.dart`; update `lib/core/routing/app_router.dart`, `lib/features/auth/domain/role_policy.dart` and `lib/features/auth/presentation/role_landing_screens.dart` for allowed navigation, loading gates, safe deep links/back stacks and deferred `/scan`.

### P8.1 Validation and handoff
Requirements: REQ-001 through REQ-010.
- [x] T012 [Plan:8.1] Extend `test/features/menu/`, `test/core/routing/` and `test/features/queue/` for the acceptance matrix; update `docs/PROJECT_SPEC.md` and `README.md`, run formatting, `flutter analyze` and `flutter test`.

Dependencies: P1.1 -> P2.1/P3.1; P2.1 + P3.1 -> P4.1; P2.1 -> P5.1/P6.1; gates/screens/lifecycle -> P7.1; all -> P8.1. Core menu fetch integration is now unblocked; live verification still requires a reachable backend and safe test account.

Acceptance matrix required by repository standards:
- Nested unknown parents/known children, duplicate/unknown keys, web metadata ignored, malformed envelope and valid empty tree.
- Both Operations keys/each alone; deterministic registry order; Add customers absent; sole non-Operations still Home.
- Cold/no-cache failure, scoped fallback notice, wrong-user/shop rejection, cache corruption/storage errors, fresh empty revocation.
- Login/restore/resume throttle/manual bypass/concurrent refresh and token refresh without login reload.
- Exact GET path/shopId query/access-token Bearer; supplied example -> five tiles and Home; 59-second/60-second freshness boundary; older same-scope fallback when refresh fails.
- Logout during fetch/write/delete and new-account replacement; no prior-user tiles or unsafe cache restoration.
- Every direct route/deep link/back pop/dialog stack after key revocation; individual queue-tab revocation.
- Price-free mock queue, attendance never entered; webOnly tile events/URL handling.
- Light/dark, large text, short-list refresh, 48px tap targets and loading/error/empty states.

## 6. Open questions and blockers

Resolved: GET `api/navigation/me?shopId=<selectedShopId>`, top-level tree array, account/shop-scoped cache, 60-second refresh threshold with older-cache fallback, Add customers excluded, HTML Home visual reference.

Remaining nonblocking follow-ups:

1. **Inactive keys:** The supplied nodes are all active. Verify the server excludes inactive entries; projection remains key-presence-only with no client roles/isActive filter.
2. **Tree variations:** Confirm if leaves ever omit `children` or use null; current contract requires arrays as supplied.
3. **Shop changes:** Invalidate/reload by selected shop when real switching is eventually added. Its backend selection behavior remains deferred.
4. **Web-only destinations:** Supply approved HTTPS URLs. Until then use benefits/explicitly unavailable CTA, no invented link or token handoff.
5. **Unknown AppRole:** Preserve existing unsupported-account handling until a menu-only override policy is requested.
6. **Menu 403:** Proposed fail-closed behavior blocks cached feature access; verify backend error semantics during integration.

Application implementation is complete for this bounded increment. This is not
live integration or native-device sign-off. QueueRepository remains mock-only;
Dashboard is a placeholder; no approved web URL exists. The existing unsupported
role gate remains. Inactive/tree-variation/403 server semantics still need live
contract confirmation. No dependency, commit, nested agent or server launch was
added during this implementation.

## Requirement mapping

Local REQ IDs apply to this increment only.

| REQ | Requirement | Plan items | Planned evidence |
|---|---|---|---|
| REQ-001 | Authenticated confirmed menu GET; no invented contract | P1.1, P3.1, P8.1 | menu repository/DTO/contract tests |
| REQ-002 | Recursive exact keys and ONE mobile registry | P1.1, P2.1, P8.1 | registry/projection/flattening tests |
| REQ-003 | Listed tile mapping and independent Operations tabs | P2.1, P5.1, P6.1, P8.1 | registry, queue and web screens/tests |
| REQ-004 | Sole Operations/other nonempty/empty landing rules | P2.1, P4.1, P7.1, P8.1 | projection/gates/router tests |
| REQ-005 | Durable scoped menu cache with safe fallback | P1.1, P3.1, P8.1 | cache store/controller/race tests |
| REQ-006 | Login/resume/pull refresh and explicit failures | P3.1, P4.1, P8.1 | lifecycle/controller/Home tests |
| REQ-007 | Route, tab, deep-link and back-stack guards | P2.1, P7.1, P8.1 | route policy/revocation tests |
| REQ-008 | Menu UI only; server API authorization | P7.1, P8.1 | protected networking preserved, documented tests |
| REQ-009 | Logout clears cache/state with race protection | P1.1, P3.1, P7.1, P8.1 | cache ownership/logout tests |
| REQ-010 | Hidden Add customers, mock Queue, deferred attendance, standards | P4.1, P5.1, P6.1, P8.1 | screens, analyzer, widget/price-free tests |
