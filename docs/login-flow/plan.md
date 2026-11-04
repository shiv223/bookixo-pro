# Bookixo Pro login flow plan

Date: 2026-10-06
Status: T001-T018 implemented. T019 automated checks/documentation done; native manual evidence pending. Real shop switching remains deferred.
Sources: [Product spec](../PROJECT_SPEC.md), [Coding standards](../CODING_STANDARDS.md), user-provided sign-in contract.

## 1. Goal

Provide validated sign-in, server-token-derived display routing, secure session restoration/renewal and complete logout, without treating client roles as authorization.

### Repository context

At plan approval the repository contained documentation and an HTML mockup, not a Flutter application. The Flutter scaffold and login implementation now exist under the paths below. The original mockup's manually selected role remains demonstration-only and was not carried into authentication.

Flutter stable, null-safe Dart, Riverpod, go_router, dio and flutter_secure_storage are mandated. Verify selected package versions, the resulting lockfile and official APIs before implementation. Do not introduce another shared-state approach. No migration artifacts, constitution or project topology were provided; the repository documents govern this greenfield plan. No framework-migration guidelines apply.

The design below is the approved baseline. Code, test commands and remaining verification gaps are traced in `batch-report.yaml` and `checkpoints/tasks-to-impl.yaml`. See the root README for run instructions. No live backend or native-device verification is claimed.

## 2. Files and folders

| Proposed location | Responsibility |
|---|---|
| `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml` | Scaffold and verified package versions/lints |
| `lib/main.dart`, `lib/app.dart` | ProviderScope, boot initialization, global error boundary |
| `lib/core/config/app_config.dart` | Validated environment/base URL and timeout configuration |
| `lib/core/theme/app_theme.dart`, `lib/core/theme/app_tokens.dart` | Shared light/dark themes and layout tokens |
| `lib/core/localization/app_strings.dart` | Friendly field, error, challenge and session messages |
| `lib/core/errors/app_failure.dart` | Repository-standard typed failures |
| `lib/core/errors/data_failure_mapper.dart` | One low-level exception-to-failure mapper, used only by data layers |
| `lib/core/logging/app_logger.dart`, `lib/core/logging/crash_reporter.dart` | Sanitized context logging and no-op crash hook |
| `lib/core/network/dio_provider.dart`, `lib/core/network/auth_interceptor.dart` | Configured client; confirmed bearer token; coordinated 401 handling |
| `lib/core/routing/app_router.dart` | Boot, login, unsupported-role and role landing redirects |
| `lib/features/auth/domain/role_policy.dart` | AppRole, ordered group rules and landing descriptors in ONE file |
| `lib/features/auth/domain/auth_models.dart` | Immutable session, identity and sign-in outcomes |
| `lib/features/auth/domain/auth_repository.dart` | Sign-in/restore/refresh/logout interface |
| `lib/features/auth/data/sign_in_response_dto.dart` | Typed JSON parsing; optional challenge fields/tokens |
| `lib/features/auth/data/cognito_identity_decoder.dart` | Base64url payload decoding and claim validation; no signature verification |
| `lib/features/auth/data/secure_session_store.dart` | Versioned token bundle storage and serialized write/clear operations |
| `lib/features/auth/data/refresh_transport.dart` | Confirmed dedicated refresh client and injectable test interface |
| `lib/features/auth/data/auth_repository_impl.dart` | Sign-in, DTO/domain mapping, restore and persistence orchestration |
| `lib/features/auth/data/mock_auth_repository.dart` | Deterministic success/challenge/failure and renewal demos |
| `lib/features/auth/presentation/auth_dependencies.dart` | Providers for repository, clock and renewal policy |
| `lib/features/auth/presentation/auth_controller.dart` | Session lifecycle, single-flight renewal, logout and invalidation |
| `lib/features/auth/presentation/login_controller.dart`, `lib/features/auth/presentation/login_screen.dart` | Validated submission state and form |
| `lib/features/auth/presentation/session_gate_screen.dart`, `lib/features/auth/presentation/unsupported_role_screen.dart` | Startup/renewal loading, retry/re-auth and unsupported account state |
| `lib/features/auth/presentation/role_landing_screens.dart` | Role-screen builder registry, separate from role policy |
| `lib/features/auth/presentation/owner_home_screen.dart` | Owner placeholder, no attendance scanner |
| `lib/features/attendance/presentation/employee_scan_screen.dart` | Employee placeholder, no prices and no camera request yet |
| `lib/features/shop_context/domain/shop_context.dart`, `lib/features/shop_context/domain/shop_context_repository.dart` | Price-free shop identity/context and repository interface |
| `lib/features/shop_context/data/shop_context_dto.dart`, `lib/features/shop_context/data/shop_context_repository_impl.dart` | Confirmed shop-context GET and typed mapping |
| `lib/features/shop_context/presentation/shop_context_controller.dart`, `lib/features/shop_context/presentation/shop_context_gate_screen.dart` | Context loading/error/empty gate and validated primary-shop selection |
| `lib/features/shop_context/presentation/demo_shop_switcher.dart` | Explicitly demo-only switching until backend behavior is defined |
| `test/features/auth/`, `test/core/network/`, `test/core/routing/` | Deterministic policy, lifecycle, failure and widget coverage |

Reuse these shared files if another session has already established them; do not create duplicate config, logger, failure or token infrastructure.

## 3. Models and providers

### Models

- `AppRole`: owner, employee, unknown. Keep role definitions and their mapping/priority/landing metadata in `role_policy.dart`.
- `AuthIdentity`: token subject where present, server userId, email, optional name, groups and derived display role. No price fields; no guessed shopId.
- `SessionTokens`: accessToken, idToken, refreshToken, tokenType and derived expiry timestamps. Keep the token bundle internal to auth/network, out of widgets and diagnostic string representations.
- `AuthSession`: identity plus internal session tokens; immutable.
- `SignInOutcome`: authenticated session OR action-required result. A challenge is not a successful session.
- `AuthState`: signedOut, authenticated, actionRequired, unsupportedRole, renewalRequired. Initialization/async errors are exposed through Riverpod `AsyncValue`, not null sentinels.
- `RefreshTransport`: calls the confirmed Bookixo refresh endpoint. Mock transport is available only in an explicitly selected demo/test configuration.
- `ShopContext`: immutable shops (id/name), primaryShopId and primaryShopName; `ShopContextController` owns the selected returned shop ID. No prices or locally inferred shop permissions.

### One role mapper

Evaluate rules in this order:

1. Any of `OWNER`, `shop_admin`, `shop_owner` -> owner.
2. `shop_employee` -> employee (confirmed by the project owner).
3. No recognized group -> unknown.

Use exact, case-sensitive group matching. Missing/empty groups yield unknown; invalid claim types or malformed JWTs yield a typed failure. Extra unknown groups do not override a recognized group. Never infer role from email, userId, shopId, local flags or a selected login button.

The pure role policy has no Flutter/go_router/storage dependencies. It exposes landing descriptors consumed by the router. Adding a role changes only this policy file plus the new screen module/its builder registration; the router and auth controller must not contain role-specific switch statements.

Unknown users see a dedicated unsupported-account screen with contact-admin guidance and logout. They must never fall through to owner content or issue owner/employee feature requests.

Decoding an idToken only supplies a display hint. Neither expiry checks nor redirects prove authenticity. Every protected API operation remains server-authorized, and employee responses must be price-free on the backend. This applies even if a malicious client alters the role hint.

### Providers

- Config, logger, secure store, auth repository, clock and refresh-lead policy providers.
- One auth lifecycle AsyncNotifier initialized on startup; stable provider-backed router updates on session changes.
- Separate scoped login AsyncNotifier for submission/challenge feedback, preserving form input on failure.
- Computed identity/display-role providers; feature providers depend on the active session generation and are invalidated on logout/session replacement.
- Injected clock/timer abstraction for deterministic renewal tests. Cancel timers/subscriptions on disposal.

### Sign-in contract

Send exactly `POST {baseUrl}/api/auth/signin` with `{"email": "...", "password": "..."}`. Do not include tokens or role selections. Trim email whitespace; preserve the password exactly. Validate required email, basic email format and nonempty password; do not invent a new password-strength rule for existing accounts.

Parse the supplied fields: accessToken, idToken, refreshToken, expiresIn, tokenType, userId, email, message, requiresPasswordChange, challengeName and session. Ignore the example values; never use them as application fixtures containing real credentials.

Handle `requiresPasswordChange == true` or a nonempty `challengeName` BEFORE requiring ordinary success tokens. Show localized guidance to complete account setup/sign-in on the existing supported channel or contact the administrator. The exact channel/URL needs confirmation. Do not persist tokens, publish authenticated state or retain the challenge session unnecessarily. No new-password or MFA flow is introduced.

Ordinary success requires well-formed tokens and a usable identity. Validate tokenType and expiresIn rather than silently defaulting malformed responses. Do not show raw `message` text from the backend. Credentials and Cognito challenge session values must never appear in logs.

### Confirmed refresh contract

Call `POST {baseUrl}/api/auth/refresh` with `{"email": "user@example.com", "refreshToken": "<opaque token>"}`. The capital T is confirmed. Send the refresh token only in this body, never as API Bearer. Use a dedicated client without automatic access-token injection or recursive 401 handling.

The response has the supplied sign-in response shape, including fresh accessToken and idToken, expiresIn, tokenType, userId/email and challenge fields. Replace the stored refreshToken when returned; retain the previous one when omitted. An empty or invalid returned token is a malformed response, not omission. Handle challenge responses without publishing an authenticated session. Protected APIs use `Authorization: Bearer <accessToken>`.

### Confirmed shop-context contract

After sign-in and startup restoration with a usable session, call `GET {baseUrl}/api/users/my-shop-context` using the access token. The final t in `context` is confirmed.

Response: `{"shops":[{"id":15,"name":"Fuzion"}],"primaryShopId":15,"primaryShopName":"Fuzion"}`. DTOs map to price-free shop domain models. Only recognized display roles proceed to shop loading; unknown roles stay on their unsupported-account screen.

Use a shop-context gate before the owner/employee landing screen. For a nonempty list, select primaryShopId only when it belongs to the returned shops; inconsistent primary data is a typed contract failure, not an arbitrary first-shop fallback. On a network/server failure show Retry and Logout, not a fabricated empty list. An empty list shows "No shop assigned" with Retry and Logout and blocks shop features.

Multiple shops expose a demo-only mocked switcher until the backend selection contract is confirmed. Production does not imply a shop switch occurred. When real switching is implemented, validate membership, invalidate shop-scoped caches, and guard in-flight responses by shop/session generation. Never guess the endpoint, shopId header or query parameter for future feature APIs. Clear shop context and selection on logout/account changes; do not trust a previous user's saved selection.

### Restore and renewal lifecycle

1. Start behind a session gate; do not briefly render the previous user's landing screen.
2. Read a versioned secure token bundle; derive identity/role afresh from its idToken. Never persist a separate trusted role.
3. Compute access-token expiry from its `exp`, with expiresIn as an additional bound from response receipt. Inspect idToken `exp` independently: display claims must also remain current. JWT parsing is structural only.
4. If tokens are usable and outside the refresh window, publish the session and schedule renewal before the earliest relevant expiry. Proposed injectable lead time: 60 seconds; confirm clock-skew policy with the backend.
5. If near expiry or expired, refresh before exposing protected screens. Missing/invalid credentials lead to signedOut; malformed/storage errors surface typed, friendly failures with retry or clear-session actions, not silent signed-out success.
6. Recompute expiry on app resume and before protected requests; mobile background timers are not reliable. Refresh on resume, not by adding a background service.
7. Deduplicate timer, resume, request and 401 renewal into ONE in-flight operation. Use a separate refresh client or interceptor bypass to avoid recursion.
8. Validate the refresh result, decode current identity/role and persist the entire updated bundle before publishing it. Replace a returned refreshToken; retain the old token when omitted. A removed/changed role invalidates affected user feature and shop state.
9. Use serialized persistence and a session generation guard so an old renewal cannot overwrite a newer login or recreate storage after logout.
10. On confirmed invalid/revoked renewal credentials, clear the session and return to login with friendly feedback. For proactive transient network failure, retain unexpired credentials, report the problem and allow explicit retry; do not pretend renewal succeeded. After expiry, block protected access until successful refresh/re-authentication. Do not erase a still-refreshable session solely because the device is offline.
11. A protected API 401 attempts at most one coordinated refresh, then clears the session and goes to login if recovery fails, per coding standards. Exclude sign-in and refresh themselves from this handler. A 403 is ForbiddenFailure, not a renewal loop.
12. Replay only explicitly safe idempotent reads after successful renewal. Never automatically replay payments, claims, saves or sign-in; preserve input and let the user resubmit after session recovery.

Keeping a session alive depends on refresh-token validity, connectivity and server policy; it cannot be guaranteed indefinitely.

### Logout

Immediately block protected screens, advance the generation, cancel renewal and invalidate all user-scoped providers/caches. Serialize secure-store deletion after any existing writes, then publish signedOut. If deletion fails, remain locked, show a typed failure and allow retry; do not report logout as complete while credentials may still restore on restart. No server revocation endpoint is assumed.

## 4. Steps in order

Tasks were executed sequentially, one increment at a time. Checked items have code and deterministic verification evidence; native manual validation in T019 remains outstanding.

### P1.1 Foundation and configuration

Requirements: REQ-008, REQ-010.

- [x] T001 [Plan:1.1] Scaffold Flutter Android/iOS with `pubspec.yaml`, resolve mandated packages into `pubspec.lock`, enable `analysis_options.yaml`, and confirm installed APIs.
- [x] T002 [Plan:1.1] Establish `lib/core/config/app_config.dart`, `lib/core/theme/app_theme.dart`, `lib/core/theme/app_tokens.dart` and `lib/core/localization/app_strings.dart`; reject missing/invalid base URLs.
- [x] T003 [Plan:1.1] Establish `lib/core/errors/app_failure.dart`, `lib/core/errors/data_failure_mapper.dart`, `lib/core/logging/app_logger.dart`, `lib/core/logging/crash_reporter.dart` and global boundary wiring in `lib/main.dart`.

Base URL is external configuration, for example `--dart-define=API_BASE_URL=...`, not platform guesses in a widget. Confirmed local base URL is `http://localhost:8080/`; use `http://10.0.2.2:8080/` on Android emulator, and a supplied LAN IP with port 8080 on physical devices. Normalize the trailing slash to avoid duplicate path separators. Local HTTP is an approved development-only standards exception: use Android debug-only cleartext configuration and iOS Debug-only transport exceptions, never release exceptions. App config must reject HTTP in release. Production HTTPS base URL remains to be supplied.

### P2.1 Auth contracts, role policy and secure data layer

Requirements: REQ-002, REQ-003, REQ-004, REQ-005.

- [x] T004 [Plan:2.1] Define `lib/features/auth/domain/auth_models.dart`, `lib/features/auth/domain/auth_repository.dart` and `lib/features/auth/domain/role_policy.dart` using the outcomes and priority rules above.
- [x] T005 [Plan:2.1] Add `lib/features/auth/data/sign_in_response_dto.dart` and `lib/features/auth/data/cognito_identity_decoder.dart`; distinguish challenges, structural token failures and unknown groups.
- [x] T006 [Plan:2.1] Add `lib/features/auth/data/secure_session_store.dart`, `lib/features/auth/data/refresh_transport.dart`, `lib/features/auth/data/mock_auth_repository.dart` and `lib/features/auth/presentation/auth_dependencies.dart`; secure-store full bundles without standalone role flags.
- [x] T007 [Plan:2.1] Implement `lib/features/auth/data/auth_repository_impl.dart` and configure `lib/core/network/dio_provider.dart` for the supplied sign-in endpoint, timeout/failure mapping and sanitized logging; implement confirmed refresh transport in P5.1.

### P3.1 Login screen and challenge feedback

Requirements: REQ-001, REQ-002, REQ-004.

- [x] T008 [US1] [Plan:3.1] Implement `lib/features/auth/presentation/login_controller.dart` and `lib/features/auth/presentation/login_screen.dart`; validate input, disable/ignore repeated submits, show loading, friendly field errors and challenge guidance.

Keep form input on failed submits; never persist passwords. Use theme/string tokens, accessible 48x48 targets, autofill/password obscuring and large-text-safe layout. Empty fields are the initial form state, not a blank data screen. No role chooser.

### P4.1 Session state, routing and placeholders

Requirements: REQ-003, REQ-005, REQ-007, REQ-009.

- [x] T009 [US2] [Plan:4.1] Implement `lib/features/auth/presentation/auth_controller.dart` and `lib/features/auth/presentation/session_gate_screen.dart` for initialization, restore, user-scoped invalidation and race-safe logout.
- [x] T010 [US2] [Plan:4.1] Wire `lib/core/routing/app_router.dart`, `lib/features/auth/presentation/unsupported_role_screen.dart`, `lib/features/auth/presentation/role_landing_screens.dart` and `lib/app.dart`; descriptor-based redirects preserve unknown/loading/error states.
- [x] T011 [US2] [Plan:4.1] Add `lib/features/auth/presentation/owner_home_screen.dart` and `lib/features/attendance/presentation/employee_scan_screen.dart` with logout. These are placeholders only; no camera, attendance API, price fields or live operations.

Signed-out protected/deep links go to login. Authenticated owner starts at Home; employee starts at Scan. Unsupported roles stay on their restricted screen. Login redirects away only after a complete usable session is published. Do not restore a deep link into the wrong role's screen. Redirects are UX, never permission checks.

**Smallest demo:** T001-T011 with an explicitly selected fake repository demonstrate validation, owner/employee/unknown outcomes, challenge messages and logout. Real session renewal follows in P5.1 and real shop-context gating in P5.2. Do not label a mock-backed increment production-complete.

### P5.1 Production refresh and authenticated networking

Requirements: REQ-005, REQ-006, REQ-007, REQ-008.

Endpoint/request/response, bearer-token choice and refresh-token omission/rotation rules are now confirmed; this phase is unblocked.

- [x] T012 [US3] [Plan:5.1] Implement the confirmed contract in `lib/features/auth/data/refresh_transport.dart` and integrate `lib/features/auth/data/auth_repository_impl.dart`; replace demo transport only in configured production dependencies.
- [x] T013 [US3] [Plan:5.1] Complete `lib/features/auth/presentation/auth_controller.dart` with injected clock/timers, single-flight renewal, boot/resume/pre-request expiry checks, rotated-token persistence and generation-safe cancellation.
- [x] T014 [US3] [Plan:5.1] Implement `lib/core/network/auth_interceptor.dart` with the confirmed bearer token, one-refresh 401 behavior, 403 mapping and no unsafe automatic mutation replay.

### P5.2 Shop-context gate and mocked switching

Requirements: REQ-007, REQ-009, REQ-011.

- [x] T015 [US4] [Plan:5.2] Define `lib/features/shop_context/domain/shop_context.dart` and `lib/features/shop_context/domain/shop_context_repository.dart`; add `lib/features/shop_context/data/shop_context_dto.dart` and `lib/features/shop_context/data/shop_context_repository_impl.dart` for the confirmed access-token-authenticated GET.
- [x] T016 [US4] [Plan:5.2] Implement `lib/features/shop_context/presentation/shop_context_controller.dart` and `lib/features/shop_context/presentation/shop_context_gate_screen.dart`; wire `lib/core/routing/app_router.dart` for loading/error/no-shop states before role landing and clear context on logout/account replacement.
- [x] T017 [US4] [Plan:5.2] Add `lib/features/shop_context/presentation/demo_shop_switcher.dart` only in explicit demo configuration; leave production switching deferred rather than fabricating backend selection.

### P6.1 Validation and contract documentation

Requirements: REQ-001 through REQ-011.

- [x] T018 [Plan:6.1] Add role/outcome/storage/lifecycle tests under `test/features/auth/`, recovery tests under `test/core/network/`, widget/redirect tests under `test/core/routing/` and `test/features/auth/`, and shop-context tests under `test/features/shop_context/` using fake repositories, storage and time.
- [ ] T019 [Plan:6.1] Update `docs/PROJECT_SPEC.md` and this plan with confirmed contracts/configuration; format touched Dart files, run `flutter analyze` and `flutter test`, and record manual emulator/simulator/device evidence without secrets.

Repository standards require role and failure tests even though this request is planning-only. Implementation completion requires:

- All four owner aliases/group combinations (three aliases individually plus owner/employee overlap), employee-only, extra unknown groups, empty/missing groups and case mismatch.
- JWT base64url padding, malformed payload/types, absent/invalid expiry and expired access/id tokens.
- Ordinary sign-in, invalid credentials, validation/network failures, challenges without tokens, failed secure writes and retained form input.
- Restore without a role flag; refresh before expiry; short lifetimes; app resume; concurrent 401/timer/request renewal producing one call; refresh rotation; expired/revoked renewal.
- Transient proactive failure before/after expiry, 401 failure clearing session, 403 not refreshing, refresh/sign-in excluded from interception.
- No automatic payment/claim/save replay.
- Exact refresh request keys; returned/omitted/invalid refreshToken handling; access-token Bearer on shop-context GET, never refresh-token Bearer.
- One/multiple/no shops, primary ID not in list, malformed context, retryable load failures, logout during context loading, demo-only switching and no cross-account/shop cache leakage.
- Debug local HTTP works; release rejects HTTP and has no development transport exceptions.
- Logout during sign-in/refresh/storage writes, failed secure deletion, rapid account changes and no old-user state leakage.
- Login loading/double taps, startup gate, unsupported-role guidance and role-correct deep links.
- Manual light/dark and enlarged-text checks. Placeholder employee screen has no prices; owner screen never launches attendance.

T019 automated checks are recorded in the batch report. No Android/iOS device was connected in this Windows environment. Native manual light/dark, secure-storage, HTTP and resume checks remain pending; deterministic widget tests cover light/dark and enlarged text but do not substitute for native evidence.

## 5. Risks and open questions

1. **Real shop switching (deferred):** Backend behavior is not decided. Keep switching mocked in demo mode only. Confirm whether selection is local or server-side and how feature requests identify the selected shop before implementing real switching.
2. **Primary shop consistency:** Valid primaryShopId is the initial selection. If a nonempty list lacks a valid primary, show a typed contract failure until a selection policy is confirmed. Empty list behavior is confirmed as blocking Retry/Logout.
3. **Renewal policy (nonblocking configurable proposal):** Use the previously proposed injectable 60-second refresh window, bounded for shorter token lifetimes; recompute on resume/requests. Refresh-token lifetime and invalid/revoked-token status codes should be verified during backend integration. Do not guess token lifetime or log raw backend messages.
4. **Challenge next step (nonblocking):** Use friendly contact-administrator guidance for now; a supported web URL may be supplied later.
5. **Deployment config (nonblocking locally):** Local HTTP port 8080 is confirmed; production HTTPS URL and physical-device LAN IP remain deployment inputs.
6. **Logout scope:** Local logout only; no server revocation endpoint is assumed.

Core login, refresh and shop-context loading are implemented and deterministically tested. Production shop switching remains deferred; native manual verification is still required before T019 and production sign-off can be completed.

## Requirement mapping

These local IDs trace the user's requested login increment; they are not pre-existing IDs in the product spec.

| REQ ID | Requirement | Plan items | Planned implementation evidence |
|---|---|---|---|
| REQ-001 | Login validation, loading and duplicate-submit prevention | P3.1, P6.1 | login_controller.dart, login_screen.dart, widget tests |
| REQ-002 | Exact supplied sign-in request and typed success parsing | P2.1, P3.1, P6.1 | response DTO, repository implementation, repository tests |
| REQ-003 | One extensible role mapper, owner priority, safe unknown fallback, hint only | P2.1, P4.1, P6.1 | role_policy.dart, router, policy/deep-link tests |
| REQ-004 | Friendly challenge/password-change feedback; no completion flow | P2.1, P3.1, P6.1 | SignInOutcome, response DTO, login tests |
| REQ-005 | Secure tokens and startup restoration | P2.1, P4.1, P5.1, P6.1 | secure_session_store.dart, auth_controller.dart, storage/restore tests |
| REQ-006 | Proactive renewal, resume recovery and bounded 401 handling | P5.1, P6.1 | refresh_transport.dart, controller, interceptor, fake-time tests |
| REQ-007 | Logout clears persistent credentials and user-scoped state | P4.1, P5.1, P5.2, P6.1 | controller/store, shop context, race and invalidation tests |
| REQ-008 | Configurable base URL for emulator/simulator/device; HTTPS policy | P1.1, P5.1, P6.1 | app_config.dart, configured clients, config checks |
| REQ-009 | Owner Home and price-free employee Scan placeholders | P4.1, P5.2, P6.1 | shop gate, landing screen registry, placeholder screens, routing/widget tests |
| REQ-010 | Mandated layering, state, failures, tokens, accessibility and logging | P1.1, P6.1 | shared core, analyzers, failure tests and manual UX evidence |
| REQ-011 | Fetch shop context, validate primary selection, block no-shop users, mock switching only | P5.2, P6.1 | shop-context repository/controller/gate, demo switcher and tests |

## Visual increment — 2026-10-06

This presentation-only increment does not replace the original login batch evidence in `batch-report.yaml` or `checkpoints/tasks-to-impl.yaml`.

- Shared Material3 light/dark themes retain the `#1A73E8` seeded extra roles, with exact `index.html` palette overrides and centralized control/card/text/spacing/radius tokens. Login matches CSS `linear-gradient(170deg,#4a8df0 0%,#1a73e8 45%,#1560c4 100%)`; endpoints use the rendered box dimensions and CSS corner projections, not a fixed Flutter diagonal. CSS 170 degrees runs nearly downward with a slight rightward tilt.
- Subtitle opacity is 0.92 to preserve the existing large-text contrast threshold on the updated brightest gradient stop.
- Login reuses `assets/branding/icon.png` in place and adds original white scissors/comb/hairdryer line art in `assets/login_tools.svg`. Both assets are declared. `flutter_svg` 2.3.0 was verified against pub.dev usage docs and the resolved lockfile; it is the only added direct dependency.
- The gradient login has a brand lockup, short subtitle, white rounded card with its own light form theme in either global brightness, local labelled password visibility toggle, full-width loading/Retry button, and friendly live-region feedback. No sign-up or role UI was introduced.
- Auth/session controllers, repositories/domain models, dependency providers, app theme wiring and routing remain unchanged (15 relevant files verified byte-identical with SHA256). Existing challenge, field validation, input retention and duplicate-submit behavior remain covered.
- Automated evidence: 35 existing auth/routing regressions passed; 12 new theme/login tests passed; the complete suite passed 103 tests. New tests check declared asset rendering, gradient, light/dark form contrast, visibility/loading/errors, minimum 48×48 toggle/submit targets, and 320×568 at 2.5× text with/without a 240-pixel keyboard inset. Submit and inline errors remain reachable through scrolling with no overflow exceptions. Illustration visibility reads the keyboard inset above Scaffold because its resized body consumes that inset.
- Remaining validation: no running Flutter app was connected, so no hot reload or native screenshot/manual review was performed. Real-device keyboard, autofill, screen-reader and final visual review remain pending. Existing backend/demo boundaries and native sign-off gaps are unchanged; no new mocked business behavior was added.
