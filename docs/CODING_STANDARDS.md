# Bookixo Pro: Coding Standards and Error Handling

All agents and contributors follow this file. If a rule here conflicts with something Copilot suggests, this file wins.

## 1. Code style
- Enable `flutter_lints` (or stricter) in `analysis_options.yaml`. `flutter analyze` must report zero issues before a task is done.
- Format with `dart format`. Files `snake_case.dart`, classes `PascalCase`, members `camelCase`, constants `lowerCamelCase`.
- Prefer `const` constructors and widgets. Prefer `final`. Models are immutable (use `copyWith`; a code generator such as freezed is optional, decide once).
- No `print`. Use one logger wrapper in `lib/core/logging/`.
- Avoid the `!` force-unwrap and `dynamic`. Handle null explicitly. Every `late` needs a reason.
- Keep widgets small: if a `build` method passes about 80 lines, split it into widgets (not helper methods returning widgets).
- No hard-coded colors, sizes, strings or URLs in screens. Use theme tokens, constants and config.
- User-facing strings go in one place (ready for localisation later).
- Use `ListView.builder` for lists. Dispose controllers and cancel subscriptions. After an `await` in a widget, check `context.mounted` before using `context`.
- Comments explain why, not what. Public classes and non-obvious functions get a short doc comment.
- No dead code, no commented-out code, no unused packages or imports.

## 2. Architecture rules
- Layers: `presentation` (widgets, providers) -> `domain` (models, repository interfaces) -> `data` (API, storage). Dependencies point inward only.
- Widgets never call dio, storage or parse JSON. Repositories do.
- DTOs (JSON models) are separate from domain models. Mapping happens in `data/`.
- Employee domain models can have price fields.

## 3. Error handling
**One error vocabulary.** Define a sealed `AppFailure` in `lib/core/errors/` with at least:
`NetworkFailure` (no connection, timeout), `UnauthorizedFailure` (401), `ForbiddenFailure` (403), `NotFoundFailure` (404), `ConflictFailure` (409, e.g. customer already claimed), `ValidationFailure` (400/422, with field messages), `ServerFailure` (5xx), `UnknownFailure`.

**Where errors are converted.** Only the data layer catches low-level exceptions (`DioException`, `FormatException`, storage errors) and converts them into `AppFailure` in one mapper. Nothing above the data layer sees a `DioException`.

**How they flow.**
- Repositories throw or return typed failures. Never return `null` to mean "something went wrong".
- Providers expose `AsyncValue` so every screen has loading, data and error states.
- Never swallow an exception with an empty `catch`. Either handle it, convert it, or rethrow. Never `catch (e)` without a stack trace being kept or logged.
- Catch specific types, not everything, except at the app boundary below.

**What the user sees.**
- Plain, friendly messages with a next step. No stack traces, status codes or raw server text.
- Network error: "No connection. Check your internet and try again." with a Retry button.
- Conflict on claim: "Already with <name>" and refresh the queue.
- Validation: show the message next to the field.
- 401: try one token refresh, then clear the session and go to login.
- Failed submits keep the user's input; never lose a filled form.

**Safety around requests.**
- Set connect and receive timeouts.
- Retry automatically only for idempotent GET requests, with limited attempts and backoff. Never auto-retry payments, claims or service saves.
- Disable the submit button while a request runs, and ignore repeat taps.
- Validate input on the client for UX, and assume the server validates again.

**App boundary (global handlers).** In `main()` set `FlutterError.onError`, `PlatformDispatcher.instance.onError` and run inside a guarded zone. Log the error through the logger and send it to the crash reporting hook (a no-op interface until a service is chosen). Show a friendly fallback screen instead of a red error screen in release builds.

**Logging.** Log events and failures with a short context. Never log tokens, passwords, phone numbers or customer names.

## 4. State management (Riverpod)
- One approach everywhere. Providers are small and single-purpose. Use `ref.watch` in `build`, `ref.read` in callbacks.
- Keep UI state (selected chips, form text) local or in a scoped notifier. Keep server data in repository-backed providers.
- Dispose or invalidate provider state on logout so one user's data never appears for the next.

## 5. Security
- Tokens only in secure storage. HTTPS only. No secrets or keys in the repo or app.
- Role and permissions come from the server. Employee booking screens must never render service prices, totals or payment details, even when shared API responses contain them. Booking draft edit restrictions are enforced in the mobile UI because the backend does not add mobile-specific role checks. Validate discounts from 0 to 100 for user experience; the server remains the source of pricing and final totals.
- Request only needed permissions (camera for QR).

## 6. Testing
- Every rule in `PROJECT_SPEC.md` that affects money, roles or claiming has a test.
- Failure paths are tested too: network error, 401, 409, validation error.
- Tests are deterministic (no real network, no real time). Use fakes for repositories.
- Do not weaken or delete a failing test to get a green run; fix the cause or report the bug.

## 7. Git hygiene
- Small focused commits with clear messages (for example `feat(queue): claim customer on tap`).
- One feature per branch and pull request. Run `flutter analyze` and `flutter test` first.
- Never commit generated secrets, keystores, `.env` files or build output.

## 8. Accessibility and UX
- Tap targets at least 48x48. Sufficient contrast in light and dark mode. Support larger system text without overflow. Add semantic labels to icon-only buttons.
- **Screen headers are a shared component, not a per-screen design.** Every new non-auth screen and every updated screen with a compact inner header must use the shared `AppInnerHeader` component and the canonical pattern in `docs/DESIGN.md`. Do not create a screen-local `AppBar`, gradient header, back button, title row, or right-side badge/action layout. The shared component owns the header gradient, safe area, spacing, shape, title typography, back-button semantics, and optional trailing content; use centralized strings and design tokens for all content and dimensions.
- Use the shared header's standard back behavior: return to the valid previous route, with an explicit feature-appropriate fallback when the screen is a navigation root. Pass screen-specific trailing content through the shared component rather than duplicating its layout. Home and authentication screens are intentional exceptions because they use their separately specified layouts. Any additional exception must be documented in `docs/DESIGN.md` before implementation.
