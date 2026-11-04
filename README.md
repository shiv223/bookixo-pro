# Bookixo Pro

Flutter Android/iOS login, secure session renewal, shop-context gating,
menu-driven post-login Home and a native read-only Dashboard.
The existing `index.html` remains a separate web mockup.

## Run locally

Flutter stable is required. This implementation was verified with Flutter
3.47.6 / Dart 3.13.5. The existing Windows SDK is `C:\Workstations\flutter`;
add its `bin` directory to PATH for the commands below.

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=https://platform.bookixo.com
# Android emulator (backend running on the host, port 8080)
flutter run --dart-define=API_BASE_URL=http://192.168.1.242:8080
flutter run --dart-define=API_BASE_URL=https://platform.bookixo.com
# Android emulator with the separately hosted Socket.IO gateway
flutter run --dart-define=API_BASE_URL=http://192.168.1.242:8080 --dart-define=SOCKET_BASE_URL=http://192.168.1.242:8090
# iOS simulator (run on macOS with Xcode)
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

For a physical device, supply your backend host's reachable LAN IP and port
8080 in `API_BASE_URL`. Realtime is optional: supply the actual reachable
Socket.IO gateway base URL separately with `SOCKET_BASE_URL`; the sample
`192.168.1.242:8090` is illustrative and must be replaced unless the gateway
really runs there. No production gateway URL has been verified or supplied.
Without that define the queue retains its 15-second REST polling fallback.
Debug builds alone permit HTTP; profile/release require HTTPS for both URLs.
The gateway currently has no handshake authentication or room-membership
authorization. The mobile app intentionally sends no tokens to the socket;
notifications only trigger protected REST queue reads. This is a known
deployment risk, not an authenticated channel. Do not pass credentials or
tokens as Dart defines.

```powershell
# Explicit offline demo; no real network or credential persistence
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/ --dart-define=DEMO_MODE=true
```

Demo accounts: `owner@example.test`, `employee@example.test`,
`challenge@example.test`, or another `.test` email for unsupported-role
feedback. Use any nonempty sample password, never real credentials.
Demo switching uses in-memory sample selection. Production owners/shop admins
use **Switch salon** on Home/Queue and recovery or booking headers. The last-used
accessible salon is saved per account in secure storage; employees cannot switch.
Unsaved work requires confirmation and active mutations block switching.

## Native app branding

Android and iOS launcher icons and startup splash images use
`assets/branding/icon.png`. Android 12+ has a padded splash image to keep the
logo inside the system mask, with light/dark backgrounds. Older Android and
iOS display a centered 120dp/120pt logo.

After replacing the source logo, regenerate the native PNGs on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File tools\generate_branding.ps1
```

Rebuild and reinstall the app to see native branding changes; hot reload does
not update launcher icons or launch screens. Verify a cold launch on Android
before and after Android 12, and on iOS with Xcode.

## Verify

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

Tests use injected storage, HTTP adapters, repositories and clocks; no live
backend credentials are used. Native secure storage, HTTP transport and app
lifecycle still require an Android/iOS device smoke check. iOS builds require
macOS/Xcode and provisioning for the configured Keychain entitlements.
Configure production Android signing before distribution; the generated
scaffold's signing setup is not a production release configuration.

## Scope and contracts

- `POST /api/auth/signin`: `{identifier: trimmed email or staff phone, password}`;
  no legacy `email` field is sent. Existing passwords remain required. Refresh
  uses canonical response email, never the entered phone. Backend phone approval
  must be enabled; no phone verification/new-password completion UI is added.
- `POST /api/auth/refresh`: exact `email` and `refreshToken` keys.
- `GET /api/users/my-shop-context`: access-token Bearer authentication.
- Only explicit safe GET reads can be replayed once after a protected 401.
  Mutations are never automatically replayed; 403 does not trigger renewal.
- JWT display claims are structurally decoded, **not signature-verified**.
  Routing is UX only; the backend must enforce authorization and price-free
  employee responses.
- Empty shop lists block features with Retry/Logout. An inconsistent primary
  shop produces a contract failure, not an arbitrary default.
- `GET /api/navigation/me` uses the protected access-token client and dio
  `queryParameters: {'shopId': selectedShopId}`. The response is a top-level tree
  array with nonempty `menuKey` strings and recursive `children` arrays.
- Home logo: confirmed `GET /api/shops/{shopId}/logo` uses the same protected
  ACCESS Bearer client. 200 JSON supplies an HTTPS `logoUrl`; 204/no body is
  absence. Failures remain typed (including 403), with bounded existing 401
  recovery/logout. The 42px rounded header displays real shop artwork or the
  bundled Bookixo default during loading/absence/failure, with nonblocking Retry.
  External JPEG/PNG image fetches use Flutter's image transport with **no login
  auth headers**, not protected Dio; file extensions are not required.
- Presigned logo URLs never enter durable storage or logs. Stable account/login
  ownership + validated shop scope rejects old responses; cleanup evicts only
  owned image-cache keys. Manual Home refresh and each foreground entry refetch;
  usable AWS signing metadata schedules expiry refresh. One expired/403 image
  recovery GET per refresh chain, no guessed 900s lifetime or 60s menu coupling.
- One mobile registry recognizes six exact keys and projects five tiles:
  Operations (Pending / In progress independently), Dashboard, Offers,
  combined Credits & Packages, and Membership. Unknown/web metadata is ignored.
  Add customers is excluded, including the demo.
- All Home tiles use regular horizontal cards. Offers, combined Credits &
  Packages and Membership show a visible accessible **Web only** badge before
  tapping. No separate web heading/grid; keys, tile kinds, landing and route
  guards are unchanged. Benefits pages say **Currently available on Bookixo web**.
- Sole Operations lands at Queue; other nonempty combinations at Home; empty
  mobile permissions at No access. All routes, tabs, deep links, pushed screens
  and feature dialogs are guarded and removed when access is revoked.
- Menu keys are cached durably under a separate secure-storage key, owned by
  stable user ID/subject and selected shop. Login/startup refresh first; resume
  uses a 60-second threshold and attempt throttle; manual refresh bypasses it.
  No periodic menu polling is added. Recoverable failures may show older
  same-scope cache with a stale notice. 403 fails closed; 401 uses existing
  bounded renewal/logout. Token rotation alone does not reload shop/menu.
- Fresh empty permissions replace saved access. Persistence failure keeps fresh
  in-memory permissions, never rolls back revocations, and exposes Retry.
- Dashboard reports use protected read-only GETs for booking metrics, orders,
  assignee performance, booking statuses, current inventory, wallet purchases
  and membership sales. Dates follow Asia/Kolkata; request scopes include the
  selected shop/range and stale responses are discarded after identity, shop,
  access or range changes. Status/inventory/optional feature reports load
  lazily. See `docs/DESIGN.md` for exact contracts and calculations.
- Queue, walk-in, booking services and owner payments use authenticated APIs
  outside demo; employee booking UI remains price-free. Production owner salon
  switching is local validated API scoping, not a switch endpoint. Attendance
  remains deferred. Dashboard uses validated live report responses; backend
  credentials and live API/device validation were not available in this task.
- Queue Socket.IO uses the separately configured gateway URL, websocket
  transport, and `/socket.io`; it is not derived from the API URL. Current
  gateway contract is unauthenticated, with no membership authorization. Queue
  REST reads remain protected and authoritative; missing socket configuration
  falls back to 15-second polling. No live gateway address or production
  handshake/security verification is claimed.
- Web-only pages show benefits and an explicit unavailable CTA. Approved URLs
  are still needed; no guessed URLs, browser dependency or token handoff exists.
  Tile/button events use fixed sanitized logger contexts.
- Logout immediately blocks navigation and serializes durable session/menu
  cleanup. Deletion failures remain locked with Retry. Late requests cannot
  recreate old-user cache. No unconfirmed logout endpoint is called.

Implementation evidence: `docs/login-flow/batch-report.yaml` and
`docs/login-flow/checkpoints/tasks-to-impl.yaml`. Product rules and architecture
remain in `docs/PROJECT_SPEC.md`, `docs/CODING_STANDARDS.md` and
`docs/login-flow/plan.md`.

Post-login implementation evidence and the exact changed-file/task mapping:
`docs/post-login-home/batch-report.yaml` and
`docs/post-login-home/checkpoints/tasks-to-impl.yaml`.
The approved plan is `docs/post-login-home/plan.md`. No live backend or native
device sign-off is implied by deterministic tests. Remaining follow-ups are
approved web destinations, attendance, full customer management, and live backend
and native-device validation. No test credentials were supplied.

## Deploy
- flutter build appbundle --release --dart-define=API_BASE_URL=https://platform.bookixo.com
- flutter build ipa --release --dart-define=API_BASE_URL=https://api.yourdomain.com
