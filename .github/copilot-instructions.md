# Bookixo Pro: repo-wide instructions for Copilot

Read `docs/PROJECT_SPEC.md` (product rules) and `docs/CODING_STANDARDS.md` (code style, architecture, error handling, testing) before any task.

## Stack and conventions
- Flutter (stable) with null-safe Dart. State: Riverpod. Routing: go_router. HTTP: dio.
- Feature-first structure under `lib/features/<feature>/{data,domain,presentation}`; shared code in `lib/core/`.
- One state approach only. Do not introduce Bloc, Provider, GetX or setState for shared state.
- No business logic in widgets. Widgets watch providers; providers call repositories.
- Use the design tokens in `lib/core/theme/` (blue #1A73E8, orange #F59309). No hard-coded colors or magic numbers in screens.
- Every async screen needs loading, empty and error states. Guard against double taps on submit buttons.
- For anything visual, follow docs/DESIGN.md.
- All non-auth feature screens with a compact header must use the shared `AppInnerHeader` from `lib/core/widgets/app_inner_header.dart`; never create a screen-local header/AppBar or duplicate header layout. Follow the documented back behavior and use its trailing slot for screen-specific content. Home and authentication headers are the only standard exceptions.

## Hard rules
- Employees must never display prices, totals or payment details. A shared API response may include service prices, but employee-facing UI must not render them.
- The user's role comes from the server response. Never decide permissions from locally stored flags alone.
- Never commit secrets, API keys or tokens. Store auth tokens with secure storage only.
- Do not invent API endpoints. If an endpoint is unknown, create a repository interface with a mock implementation and list it as an open question.
- Package APIs change often. Check the installed version in `pubspec.lock` and current docs before using an API; don't rely on memory.

## Workflow
- Work on one screen or one feature at a time.
- Run `flutter analyze` and `flutter test` before saying a task is done.
- Keep changes small and explain what was changed and why.

## Errors
- Convert low-level exceptions into typed `AppFailure`s in the data layer only. Never use an empty `catch`. Never show raw errors to users. Never auto-retry payments, claims or saves. Details in `docs/CODING_STANDARDS.md`.
