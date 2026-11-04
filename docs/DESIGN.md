# Bookixo Pro: Design Spec

Source of truth for how the app looks. Build the theme from these values; do not read the mockup HTML. Screenshots (if any) live in `docs/design/`. Product rules are in `PROJECT_SPEC.md`; code rules in `CODING_STANDARDS.md`.

Rules for Copilot:
- Keep layout, colors, labels and flows as written here. Do not add features or redesign.
- No hard-coded colors, sizes or strings in screens. Everything below goes into `lib/core/theme/`.
- You may improve implementation quality only: press feedback, haptics, safe areas, keyboard handling, loading skeletons, error/retry states, pull-to-refresh, dark mode, accessibility, transitions under 300 ms.

## 1. Color tokens

| Token | Light | Dark |
|---|---|---|
| primary | #1A73E8 | #1A73E8 |
| primaryDark | #1560C4 | #1560C4 |
| accent (orange) | #F59309 | #F59309 |
| success | #12A150 | #12A150 |
| error | #D93025 | #D93025 |
| background | #F4F6FB | #0F1624 |
| surface (cards) | #FFFFFF | #1A2335 |
| textPrimary | #14213D | #EEF2FA |
| textMuted | #6B778C | #98A4BB |
| border | #E4E8F0 | #2A3550 |

Home tile gradients (each icon box sits inside its full-card gradient):

| Tile | Gradient endpoints (all themes) | Foreground |
|---|---|---|
| Dashboard | #C2410C → #9A3412 | White |
| Offers | #394C9C → #24346E | White |
| Credits & Packages | #25688E → #184660 | White |
| Membership | #75498F → #4D2E60 | White |
| Services | #285C45 → #193C2D | White |
| Shop Users | #85405A → #582A3C | White |
| Shop Settings | #48546D → #2D3548 | White |

Gradients (all linear):
- **headerGradient** 160deg: #4A8DF0 -> #1560C4 (home header, inner headers, login)
- **loginGradient** 170deg: #4A8DF0 -> #1A73E8 (45%) -> #1560C4
- **tileOperations** 135deg: #17A590 -> #0B7D6E (teal)
- **tileDashboard** 135deg: #C2410C -> #9A3412 (deep orange for white-text contrast)
- **tileCustomers** 135deg: #2B3A67 -> #14213D (navy)
- **offerPercent** 160deg: #F7A41D -> #E8820C (orange)
- **offerFlat** 160deg: #4A8DF0 -> #1560C4 (blue)
- **offerFree** 160deg: #9B5DE5 -> #6A3FD1 (purple)
- **offerInactive** 160deg: #C5CCD8 -> #9AA5B8 (gray)

Status badges (background / text):
- Pending, warning: #FFF1DC / #B86100
- Info, in progress, "With you": #E3EEFD / #1560C4
- Active, ready to pay, success: #E3F6EA / #0B7A3B
- Neutral, inactive, "With <name>": border color / textMuted

## 2. Shape, spacing, type
- **Radius:** card 18, tile 22, button 14, input 12, chip and badge fully rounded, back button 12, avatar circle, home header bottom 28, inner header bottom 22.
- **Spacing:** screen horizontal padding 20; card padding 14 (16 for tiles); gaps 10 to 14; section heading margin 14 top, 8 bottom.
- **Type** (system font, Roboto on Android; bundle one font later if wanted): screen title 19 semibold; tile title 18 bold; body 15; caption 13 (textMuted); badge 12 semibold; button 16 semibold; big numbers (KPI, final amount) 24 bold.
- **Sizes:** buttons 48 to 52 high; every tap target at least 48x48; avatars 44; icon squares 36 to 44.
- **Elevation:** cards use a 1 px border, no shadow. Login card and FAB use a soft shadow. Header buttons are translucent white.

## 3. Components
- **Home header (tall):** headerGradient, padding 20/20/46, rounded bottom 28. Shows logo (42, rounded 12, 2 px white 33% ring), "Welcome back" (13, 85% opacity), shop name and role (17 bold), and a white pill **Log out** button (blue text, bold). On Home only, owners/shop admins with multiple accessible salons tap the shop-name control with a downward chevron to open the shared salon chooser; do not also show a separate storefront button. Its semantic label is "Switch salon, <selected salon name>" and its target is at least 48px high. For employees or a single salon, the shop name is static with no chevron. Content below overlaps the header by 26 px. Long names wrap; move Log out below the profile when needed rather than truncating the salon name or crowding controls.
- **Inner header (compact; canonical for all non-auth feature screens):** implement once as the shared `AppInnerHeader` in `lib/core/widgets/app_inner_header.dart`; every feature screen uses it rather than making a local `AppBar` or custom header row. It owns headerGradient, safe area, padding 16/20/18, rounded bottom 22, a translucent white back button (at least 48x48 tap target, radius 12, white 18% fill), title in white 19 semibold, and optional trailing badge/action content. Back returns to the valid previous route, with a feature-appropriate fallback for root destinations. Pass screen-specific trailing content as a child/slot; do not reimplement the header layout. Home and authentication layouts are intentional exceptions.
- **Selected-shop titles (approved app-wide update):** keep every existing non-Home page title and append ` · <abbreviation>` from the validated selected salon, including top-level, child/detail and recovery headers. Examples: **Operations · GLOW**, **Dashboard · SB**. Shared `ShopHeaderTitle` / `shopAbbreviation` owns presentation: Unicode letter/digit words, punctuation and whitespace as separators, uppercase; one word takes its first four grapheme clusters (or fewer), multiple words take each word's initial. Ignore punctuation-only tokens; null/empty/punctuation-only names leave the original title with no separator. Never substitute primary/cached/unvalidated shop metadata. React to selected-shop changes. Titles wrap to at most two lines with ellipsis to bound very long titles/initials on narrow screens and at large text; trailing content retains the shared stacked layout.
- **Non-Home actions:** no salon-switch controls anywhere outside Home, including demo, booking forms/details, No access and recovery pages. No owner logout controls on these screens. Preserve existing employee logout paths and styling, especially Operations' outlined **Log out** button; do not add employee logout where none existed. Operations keeps its existing role-specific Back behavior and omits the username badge. Keep unrelated actions: Offers' status badge and web-feature upsell/manual recovery refresh. Home's chooser and logout are unchanged.
- **Home feature cards (both permitted roles):** Operations is a full-width teal gradient card, radius 22, padding 22, icon 34 on the left, title 18 bold, subtitle 13 and a decorative forward chevron on the right. Secondary features use distinct full-card gradients from the token table, white titles/icons and high-contrast subtitles; the icon square retains a related solid accent. Cards remain radius 18, padding 16, icon area 44, title 16 semibold and subtitle/badge 13. Web-only badges use a white chip with dark text. Keep gradients and content contrast-safe in light and dark themes. Do not use photographic thumbnails or decorative shadows. A card is one accessible tap target; web-only cards remain tappable, not locked or disabled.
- **Card:** surface color, 1 px border, radius 18, padding 14.
- **Primary button:** full width, primary fill, white text, radius 14. Secondary button: surface fill, primary text, 1 px border. Disabled at 40% opacity. Show an inline spinner while loading and ignore repeat taps.
- **Chips:** pill shape, 1 px border; selected = primary fill with white text and a check mark.
- **Segmented tabs:** surface container, radius 14, padding 4; selected segment = primary fill, white text; label 13 semibold, counts in brackets, for example `Pending (3)`.
- **Inputs:** surface fill, 1 px border, radius 12, padding 13; labels 13 semibold above; required fields get a red asterisk.
- **FAB:** "+ Add walk-in", accent orange, fully rounded, bottom-right 18 px from the edges.
- **Toast:** dark pill, 13, auto-hides after about 1.6 s.
- **Use a consistent icon set** (not emoji). Suggested mapping: Operations = content_cut, Dashboard = bar_chart, Add customers = person_add, Offers = sell, Membership = workspace_premium, Credits = account_balance_wallet, Packages = card_giftcard.

## 4. Screens
Layouts follow the labels and rules in `PROJECT_SPEC.md`. Design-specific notes:

**Login:** loginGradient background; logo 76 with white ring; "BOOKIXO PRO" 21, letter spacing 0.36em; line "Sign in to your shop". White card (radius 24, shadow) with email/phone, password with show/hide, full-width Sign in button, and an inline error line. Faint white line art (scissors, comb, hairdryer, 30% opacity) at the bottom. Hide the line art and shrink the logo area when the keyboard opens. No Sign up. Entrance animation under 600 ms, none if reduce-motion is on.

- Identifier label: **Email or phone**, username autofill and a text keyboard supporting both `@` and international `+`. Validation matches staff backend phone rules in PROJECT_SPEC; passwords and canonical refresh email are unchanged. Existing challenge guidance stays.
- **Salon chooser:** owners/shop admins only with >1 accessible salon, exposed only by Home's shop-name control with its minimum 48px target and existing semantic label. No storefront, labeled or demo switch on any non-Home page, including booking details/new booking, No access or recovery. A scrollable themed **Choose salon** dialog lists accessible names and checks the selected salon. No new route or endpoint. Employee behavior is unchanged.
- Dirty forms, service edits, invalid discounts and payment selections/details require **Discard unsaved work and switch salon?**, with **Keep working** and **Discard and switch**. Cancel leaves the entire form intact. Claim/create/save/discard/payment work disables switching; revalidate scope and busy state after every dialog await. Switching removes prior dialogs/back stack and branch drafts. Secure preference failures show nonblocking friendly feedback and Retry on Home/Queue. Single/zero salons retain existing automatic/gated behavior. Explicit demo uses the same safe chooser with in-memory fixtures.

### Home (approved hybrid redesign; implemented)

Purpose: make the main salon task prominent and secondary features easy to scan without a long stack of equally weighted rectangles. This supersedes the previous all-horizontal Home layout and its `index.html` visual reference; it does not change any other screen.

- **Structure:** retain the branded header, protected shop logo and existing refresh behavior. Below it, render existing menu/preference/logo notices only when applicable, then Operations if permitted, then the secondary feature grid. Keep 20px horizontal screen padding and 12px gaps. Notices participate in layout and never overlap controls.
- **Top/status-bar inset:** the branded background starts at the top/status-bar edge, with no outer top SafeArea gap or automatic ListView top padding. Apply the top safe inset inside the painted Home header so profile/logout content stays below system UI. Keep the outer bottom/side safe insets, existing header padding, body overlap, scrolling and pull-to-refresh; use a transparent status bar with light icons.
- **Operations:** one prominent full-width card with the registry title, existing subtitle and scissors icon. The entire card opens the existing Queue route. Do not add queue counts, payment flags, quick-start actions or Home queue API calls in this redesign.
- **Secondary cards:** Dashboard, Offers, Credits & Packages, Membership, Services, Shop Users, Shop Settings, in registry order after filtering exact permissions. Place the icon above the title, then the native subtitle or the **Web only** badge. Align content to the start. Offers keeps **Schedules & availability**, no Web only/Read only badge, and its existing native details flow. Credits & Packages remains one combined card; both web-only features keep their visible and semantic badges and existing benefits pages with unavailable web CTAs. Services uses **Browse the service catalog**, Shop Users **People at this salon**, Shop Settings **Salon setup information**. All keep distinct dark gradients and white foregrounds in both themes.
- **Responsive grid:** two equal columns when the available body width supports two cards at least 160px wide with a 12px gap. Otherwise use one column. Also use one column when the effective 15px body text scale exceeds 1.3. Keep the body centered within the existing Home maximum width; do not add more columns on tablets. Cards have content-driven height, not a fixed square/aspect ratio; match heights within each two-card row and let all titles, subtitles and badges wrap without clipping. A final unpaired card spans the available row, with no placeholder or empty reserved slot.
- **Permissions and landing:** render only registry-permitted features. Without Operations, start directly with the secondary grid; do not invent a replacement hero. Preserve Operations-only direct Queue landing, zero-tile No access, exact menu keys, routes/deep-link guards, tile tap logging and exclusion of Add customers. Home makes no directory/catalogue reads and introduces no financial information.
- **States and interaction:** preserve pull-to-refresh, manual refresh, cache freshness feedback, resource-specific Retry and nonblocking logo/preference failures. Loading must not reveal unauthorized cards; recoverable refresh failures retain same-scope permitted content. Cards have consistent press feedback, button semantics and at least 48x48 targets; exclude decorative icons/chevrons from duplicate announcements. Honor reduced motion and existing dark-mode/contrast tokens.
- **Icon motion:** secondary icon glyphs fade from 0 to 1 and scale from 0.94 to 1 once per mounted icon over 220ms, ease-out cubic, with no delay, stagger, bounce or loop. The colored square and card surface stay static. Ordinary rebuilds, refresh and theme changes do not replay entrance. Press/highlight gently scales only the glyph to 0.96 over 100ms with the same curve; release/cancel restores it. Keep the whole card's existing ink feedback and fixed layout/tap geometry. When MediaQuery `disableAnimations` or `accessibleNavigation` is enabled, show glyphs fully visible at normal scale immediately, with no entrance or press scaling; enabling it during motion settles immediately, and disabling it does not replay entrance. Operations keeps its existing teal treatment and ink feedback without extra motion.
- **Implementation boundaries:** reuse the shared salon chooser and its busy/dirty/scope protections, logo lifecycle and menu registry. Add Home-specific spacing/type/layout tokens centrally; do not modify global card styles or change Queue headers/tabs as part of this work.
- **Acceptance checks for implementation:** cover all eight tiles, missing Operations, one/odd secondary tile counts (the seventh secondary spans its final row), Operations-only and zero-access landing, permission refresh and salon switching. Check 320px-wide phones, the two-column threshold, long salon/feature names, large system text and light/dark mode. Confirm existing routes, Web only semantics, refresh/Retry and employee price hiding remain unchanged.

Illustrative arrangement when every tile is permitted (labels and subtitles remain registry-owned):

```text
Salon name v                         Log out

[ Operations                              > ]
[ Existing Operations subtitle              ]

[ Dashboard          ] [ Offers             ]
[ Existing subtitle  ] [ Schedules &        ]
[                    ] [ availability       ]

[ Credits & Packages ] [ Membership         ]
[ Web only           ] [ Web only           ]
[ Services           ] [ Shop Users         ]
[ Browse the service ] [ People at this     ]
[ catalog            ] [ salon              ]
[ Shop Settings                             ]
[ Salon setup information                   ]
```

### Read-only Home destinations
- All use `AppInnerHeader` with the selected-shop abbreviation and standard back/fallback behavior. Use scrollable themed surface cards, wrapping text, 48px targets and no owner logout/salon-switch actions.
- **Services:** title **Services**. Parent folder/category heading cards immediately precede indented child service rows; nested indentation is capped at four 16px levels for narrow screens. Non-bookable entries say **Category**; bookable parents remain visible. Orphans, self references and cycles appear safely at root level. Display no prices or mutation controls. Loading spinner; **No services here yet.** empty state; friendly typed failure + **Retry**.
- **Shop Users:** title **Shop Users**. One read-only card per directory record: name (email fallback), email, phone (**Phone not provided** when absent), exact returned role and **Active**, **Inactive** or **Active status unavailable**. Do not infer false from nullable active. Content wraps in both themes at large text; no management buttons. Loading spinner; **No shop users here yet.** empty state; initial error + Retry. **Load more** at the bottom only when page metadata permits; replace with a spinner during its single-flight read. Pagination error shows friendly feedback and Retry while retaining rows. No contact data in logs/durable storage.
- **Shop Settings:** title **Shop Settings**. Recognized immediate menu children appear as icon-led cards with app-owned labels and **Available on Bookixo web** subtitle. No child-edge relation means no child tile; unknown children are ignored. Empty: **No supported settings available.** Child screens use their own labels in the shared header and friendly **Available on Bookixo web** information, with no URL, browser button or configuration action. Both parent key and exact immediate child membership guard every child link.

**Queue:** inner header titled **Operations · <abbreviation>**, no username badge (an employee retains the outlined **Log out** button, the owner has the back arrow). Tabs `Pending (n)` and `In progress (n)`, a "Today · <date>" caption with a Refresh link, and pull-to-refresh. Each row is a card: avatar with initials, `#<queue number> · <name>`, a one-line subtitle and a status badge on the right. Pending shows the wait time and retains its explicit **Start booking** action; it is not opened by tapping the card. In progress shows `With you` (the booking's `assigneeId` is yours), `With <first name>`, `Ready to pay` (the draft has services) or `Awaiting payment` (Bookixo link sent; not tappable). The entire In progress card is tappable to open Booking Details; do not add a separate Open booking button. Never show addresses. Employees see names only; the owner sees the phone masked to the last 4 digits. A round **+** button (56 px, accent orange, bottom right) opens New booking; hide it if the shop lacks the `SHOP_BOOKINGS_CREATE` feature.

**Queue realtime connection and states:** when `SOCKET_BASE_URL` is explicitly configured, use the maintained Socket.IO client (Socket.IO 3.x, Engine.IO 4 compatible) with websocket transport and path `/socket.io`. Send `subscribe` with `{targetType: "SHOP", targetId: "<validated shop ID>"}` and wait for an exact `subscribed` acknowledgement before reporting live status or stopping the 15-second REST polling fallback. Re-subscribe and fetch the protected REST queue after each connection. Only the four confirmed booking event types (`NEW_BOOKING`, `BOOKING_STARTED`, `BOOKING_CANCELLED`, `BOOKING_COMPLETED`) for `targetType=SHOP` and the selected shop invalidate the separately permitted Pending/In progress tabs. Debounce 400 ms; never overlap refreshes, and run a trailing read if an event arrives during a read. Notifications never provide display data, alter drafts or trigger mutations. Pull-to-refresh remains available.

Show a quiet inline status: live updates on after acknowledgement; while connecting or unavailable explain that the queue checks every 15 seconds and offer Retry after a transient failure; when no socket URL was configured, explain that polling remains active. Hide the notice for demo/no-access scopes. Stop polling only while the acknowledged subscription is active. Disconnect/unsubscribe on background, logout, shop/account/menu-permission change and disposal; on resume reconnect/resubscribe and use REST to recover missed events. Explicit demo never opens a socket.

**Known gateway limitation (accepted for this client):** the confirmed Socket.IO gateway has neither handshake authentication nor room-membership authorization. The app does not send mobile tokens or credentials to it. CORS is not authorization; an internet-reachable gateway can expose shop notifications to clients that can subscribe. Realtime is therefore an unauthenticated invalidation hint, not a protected data source; all displayed queue data is fetched from the existing access-token REST APIs. This limitation must not be described as authenticated realtime security.
 
**New booking:** inner header titled "New booking". Phone number first. There is no Continue button: the lookup runs automatically once the number has 10 digits. After the lookup show a status line: looking up; found (green, details filled in and editable); new customer (orange: "A Bookixo account is created and an SMS invite is sent."); or failed (red, with a Retry text button). Fields: first name (required), last name, gender chips (optional), date of birth (optional, not in the future). Checkbox "Start service right after creating", ticked by default. Button **Create booking**; a failed lookup never blocks creating.
 
**Add services:** customer card with the status badge; search box; "Your usual" chips; "Also added" chips. Selecting a service adds it to a **Selected services** card with one row per service: name, a quantity stepper (− n +) and an optional discount % box (0 to 100, capped by the shop's limit). Lines done by other staff appear read-only with the person's name (for example `Facial · Rahul`), and a service another person already added cannot be added again by an employee. No prices anywhere for employees. Optional notes. The button shows the count, for example `Save 2 services`.

### Booking-service picker
- Preserve the existing **Your usual** and **Services** sections. Inside each, show service badges under headings named by their parent service, resolved using optional `parentId` from the existing service response. Resolve against the full catalogue before filtering.
- Missing, invalid, self-referencing or absent-from-catalogue parents leave services as ungrouped roots. No extra API calls or category fields. A non-bookable parent supplies a heading only; a bookable parent is also an option in its group.
- Search is case-insensitive and trims surrounding whitespace. Match service names and parent names: a parent match shows its options, a child match retains its parent heading. Omit empty sections/groups; show the existing no-matches message when nothing matches.
- Keep chip selection semantics: selecting adds once, selected chips cannot be tapped again, and employees cannot add services already added by other staff. Retain existing loading/error/Retry and submit-disabled behavior. Never show employee prices.
 
**Complete payment (owner and shop_admin):** customer card with "Served by <name>"; **Services** card listing each line with quantity, who did it, the line price and `Discount 10% · −40.00` when set. A secondary **Edit services** button opens the Add services screen where the owner can add, remove or change any line. **Summary card**, in this order, with rows hidden when zero: Subtotal; Employee discount (−); Other discounts (−, membership and offers); GST (`GST (18% added)` or `included`, +); **Final amount** (24 bold, primary); then a collapsed "Applied pricing rules (n)". If the customer has a membership that did not apply, show a muted note: "<Name> member: no membership discount on these services." **Payment mode** chips come from the shop's payment config (leave out Credits in v1): Cash; Card (requires a bank chip from the config's enabled options); UPI (optional transaction ID and note); Bookixo (info card: a payment link is sent and the booking completes when the customer pays). The button reads `Mark as paid · <amount>`, or `Send payment link · <amount>` for Bookixo, and stays disabled until a mode (and card bank) is chosen and pricing is current. After completing, show a confirmation screen (no invoice or sharing in mobile). Bookixo shows "Payment link sent" and the booking stays In progress as "Awaiting payment". A draft in recovery state shows a read-only screen with **Retry completion**.

### Offers list (read-only compact colored tickets)
Purpose: permitted users see offers and aggregated rule activity at a glance. All creation, editing and activation stays on Bookixo web.

- **Header:** compact inner header, title "Offers", right badge `<n> offers with active rules`, counting offer cards, never individual rules. Pending/failed/capped rule reads show `Status unavailable` rather than definitive zero. Badge wraps within bounded width.
- **Info banner:** themed info card, info icon, "Create or edit offers and schedules on Bookixo web.", small visibly disabled **Open web — unavailable** button (no URL supplied).
- **Filter tabs:** `All (5) / Active (2) / Inactive (3)` count loaded offer cards. Complete rules: any related raw rule active -> Active; at least one and all false -> Inactive; no rules -> No rules (All-only). Pending/failed/capped -> Status unavailable (All-only), activity chip counts `—`. Parent activation and dates never drive these counts. Multiple active rules count one offer; all false yields header zero. Raw invalid/unknown schedules still contribute activity and retain diagnostic feedback.
- **One card per offer** (radius 18, 1 px border). Never create a card per raw rule or duplicate an offer when its rules merge. The whole card is tappable and opens the existing Offer details route.
  - **Heading:** title upper-left in the right content, aggregated Active/Inactive/No rules/Status unavailable badge upper-right; no "Offer eligibility" heading. No service/target names in list.
  - **Right content:** merged schedule immediately under title, then validity at bottom. Same-window weekly rules merge to one Sunday-first set of day circles (`S M T W T F S`) and short labels (`Weekdays`, `Weekends`, `Sun`, `Mon, Wed`); different windows remain separate rows. Restricted windows, monthly (`Day N of each month`) and DATE rules are text. Seven-day weekly sets and ALWAYS all-day show `Every day`, never "Always". A complete successful load with no rules may show "No schedule rules"; pending/failed/capped reads stay explicit, never imply empty/every-day. Unknown/invalid schedules retain diagnostics.
  - **Ticket value:** full-height left panel, 90px wide at normal scale, FLAT blue `n / FLAT OFF`, PERCENT orange `n% / OFF`, white centered 26px bold value and 10px label. Trim fractional trailing zeros; unknown neutral. No list dimming from parent/date or rule inactivity. Compact content-driven height, not fixed tall cards. At large text stack the value above expandable content, never overflow or truncate schedules/validity.
  - **Read-only:** no raw rule IDs, switches, individual duplicate schedule rows, master toggle or Undo. Whole card opens existing details; merged summaries/diagnostics preserved.
- **Order:** aggregated Active first when known, alphabetical within groups; unavailable cards alphabetical.
- **States:** loading = 4 gray skeleton tickets; empty = "No offers here. Create one on Bookixo web." with Open web button; error = friendly message with Retry; pull-to-refresh.
- **Do not** show a refresh or logout icon on this screen, and no debug banner in release builds.
- **Access:** tile and both list/details routes require exact `shop-offers-2` through existing centralized guards. Unauthorized routes redirect normally, never an Offers upsell; do not invent a role-based viewing gate.
- **Data states:** three concurrent page-0 GETs (`shop-offers`, `offer-targets`, `offer-schedule-rules`), all with validated shopId, page and size=100. Independently drain through `last=true`, at most 0–9. Render first offers page immediately and append progressively; a short page is not complete. Caps/errors/pending resources are explicit, loaded offers survive failure, Retry is resource-specific. Account/login/shop/permission changes reject late results.

### Dashboard (read-only)
Purpose: answer "how is my shop doing?" in about five seconds. It is a phone summary, not a port of the web dashboard. One column, vertical scroll, pull-to-refresh. No "Full Screen" buttons.
 
**Order, top to bottom** (build in this order; each block loads and renders on its own):
1. **Date tabs:** segmented control `Today / 7 days / 30 days` at the top of the body (inner header above it, title "Dashboard"). Today is the default. 7 and 30 days are inclusive rolling ranges ending today. Changing range rejects late results and reloads the blocks. No custom dates.
2. **Net revenue hero card:** dark card (gradient 135deg #14213D -> #0F1B2E), radius 22, padding 18, white text. Label `NET REVENUE` (12, letter spacing 0.08em, 70% opacity), the amount 34 bold, then a comparison badge only when a nonzero previous-period baseline exists.
3. **Four key numbers**, 2x2 grid of cards: Service revenue, Product revenue, Average bill, Bills. Each shows the label (muted 13), the value (24 bold) and the change versus the immediately preceding equal-length period as a small colored arrow and percentage (12 semibold; success green up, error red down). Suppress comparisons without a nonzero previous baseline.
4. **Insight card:** light blue (#E3EEFD, text #1560C4, radius 18), a light-bulb icon and one sentence: "<top service> is your top service this period, bringing in <amount>." Hide it after a successful empty services read.
5. **Revenue trend:** one card with simple rounded bars and small muted labels, with no gridlines. Today is one gross total bar: scheduled start time is not a collection timestamp. 7 days uses daily buckets; 30 days uses weekly buckets. Gross trend is booking finalAmount plus product grandTotal, distinct from net revenue. Empty reads "No sales in this period".
6. **Payment modes:** one card with a single horizontal split bar (height 14, radius 8) and a legend underneath with each mode and its amount. This is booking-only `remainingAmountPaid` grouped by payment mode (not gross and not wallet redemptions). Colors: Cash #17A590, UPI #1A73E8, Card #F59309; other modes use muted grays.
7. **Appointments:** one stacked bar and counts beneath. Completed #12A150, Pending #F59309, Cancelled #D93025; In progress remains distinct, Confirmed is explicit, Rejected displays as No Show, and unknown statuses remain visible. Zero values take no width.
8. **Top services:** top 5 as ranked rows: name and amount on one line, a thin bar under it (accent orange on a border-color track, width relative to the top service). A "See all" link opens the full list.
9. **Top staff:** top 4 as rows with a 44 px initials avatar, name, client count (muted) and revenue on the right, separated by 1 px dividers. "See all" opens the full list. Average bill and rating appear only on the detail screen.
10. **Low stock tile:** one tappable card with a package icon, "<n> products low on stock", the first product names in muted text, and a chevron. Opens the product list.
11. **More:** a horizontally scrolling row of small cards (min width 140): Credits used, Packages sold, Credits sold, Memberships sold. Show this row only for the features the shop has.
**Left out on purpose** (do not add): peak business hours grid, staff utilisation (estimated figures look wrong to owners), new versus returning customer donut, and the web "Full Screen" and "Refresh" buttons.
 
**Formatting:**
- Currency `₹` with Indian digit grouping (`₹1,00,000`); no decimals; abbreviate very large values on small cards.
- Percent change is rounded to a whole number; hide the arrow if there is no previous period to compare.
- Dates use `Asia/Kolkata` regardless of device timezone. Previous periods are immediately preceding and equal in length.
**Loading and states:**
- Fetch the top blocks (steps 1 to 4) first; load lower blocks only when they scroll near the screen. Show gray skeleton placeholders per block.
- A failed block shows a small error with Retry and does not break the others.
- Empty block: a short muted message; never blank axes.
- Pull-to-refresh reloads the current date range.
**Access:** the Dashboard tile appears only if the menu API returns `shopdashboard`.
 
**Approved data and service contract:**
- Access is centralized under exact `shopdashboard`; child routes inherit this menu guard. No additional role-based UI gate is added. The local backend source confirms the dashboard menu should be the access boundary, but its wallet-purchase and membership-metrics report annotations currently include `shop_employee`. Employee denial at those financial endpoints therefore remains unverified and must be resolved by backend policy before release; this native feature does not change the backend.
- Protected ACCESS-token GETs: `/api/public/bookings/audit/booking-metrics/tabularview`, `/api/public/bookings/audit/assignee-performance/tabularview`, `/api/public/bookings/audit/booking-status-rows/tabularview`, `/api/public/orders/metrics/tabularview`, `/api/products/inventory-alerts/tabularview`, `/api/wallet-purchases/metrics/tabularview`, and `/api/membership-enrollments/metrics/tabularview`. Date reports send validated `shopId`, `startDate`, `endDate`; inventory is a current snapshot and sends only `shopId`. Parse a row array or `{columns, rows, summaryMetrics}`; malformed envelopes or required values are failures, never successful empty reports.
- Booking net is completed `remainingAmountPaid` plus product `grandTotal`; service revenue is completed `finalAmount`, product revenue is `grandTotal`, Bills counts distinct completed booking IDs, and Average bill is service revenue / Bills. Payment mode is booking-only `remainingAmountPaid`. Trend instead uses booking finalAmount plus order grandTotal. No customer report is requested.
- Top services aggregate assignee `servicePrice` by `catalogServices`. Staff totals group `servicePrice` by assignee identity, display `assigneeName` only (never email as a substitute), and count unique booking clients. Staff details show average bill and explicitly unavailable Rating.
- More-row wallet purchases sum amount by PACKAGE/CREDIT; rows expose `purchaseId`, `purchaseDate`, `walletType`, `walletPlanName` and `amount`. Credits used sum booking `walletCreditUsed`. Membership rows expose `registrationId`, `enrollmentDate`, `membershipName` and `amount`; the current backend query takes that amount from the plan's current price, not a stored historical sale price. Wallet/Package/Membership reports are fetched only when the corresponding exact menu key is present.
- Inventory rows require product name, currentStock, lowStockThreshold and stockColor. Only danger/warning rows or a verified at/below-threshold comparison count. The list is current stock, not date-filtered, and read-only.
- Reads load independently: bookings/orders/staff provide top content first; lower status, inventory and feature reports load only near their viewport. Reads are shared per scope/range/resource. Retry is resource-specific and retains valid same-scope data with visible failure feedback. Logout, ownership, shop, permission and range changes reject stale responses.
- Dashboard and child screens are read-only; no booking/payment/product-management drilldown is introduced. Contracts were checked against sibling `platform-ui` service references and `platform` backend row DTOs. Live backend/device validation remains outstanding.

### Offer details (cards only)
Opened by tapping the whole offer ticket. Existing `/web/offers` deep link remains; nested `/web/offers/:offerId` is guarded. Show **voucher cards, one per eligible target record**, with resource-state feedback only, no management sections or switches. Details/export uses parent `isActive` and phone-local validity, independently of list rule-activity badges. An Active list badge never authorizes sharing a disabled, expired, upcoming or invalid parent.

How offers work on web: (1) an **offer** defines the discount (amount and type); (2) **targets** attach it to the whole shop or to selected services, and one offer can have several targets; (3) **rules** define when it runs (days, months, time window).

- **Header:** inner header; the title is the offer's name; back returns to the list.
- **One card per target record.** Example: an offer "Testing offer" with a combo target (Hair Cut + Hair Spa) and a whole-shop target shows **two cards**, stacked vertically, 22 px apart. An offer with one target shows one card.
- **Voucher card** (full width, minimum 190 px high, radius 18, soft shadow): ticket shape with 70 px stub, 2 px dashed line, two 18 px notch circles. Adapt height for accessibility and hide decorative stub at large text rather than overflow. Main area: validated-context shop name (10 bold), value (44 bold, 34 for long), promotional label (13 bold), offer name (15 bold), target line (two-line ellipsis), schedule and validity dates (small text). Stub has decorative barcode-style stripes (34x110), explicitly not a fabricated redemption code.
- **Target line text:** SHOP = `On all services`, including no names; SERVICE with usable names only. Combo = `Combo: Hair Cut + Hair Spa`; ANY = `On Hair Cut or Hair Spa`; ALL = `On Hair Cut and Hair Spa`; missing/unknown mode = neutral `On Hair Cut, Hair Spa`. Ignore unknown target types and empty service targets. Distinct records with same names remain separate.
- **Designs:** four templates defined in code, assigned to the cards in order and cycling (card 1 Gift, card 2 Ocean, card 3 Sunset, card 4 Classic, then Gift again), so each card on the screen looks different.
  - Gift: 135deg #4B2AA8 -> #7B3FE4 -> #B45FE9, white text, pink accent #FF6FB8.
  - Ocean: 135deg #1560C4 -> #2AA3E8, white text, yellow accent #FFD166.
  - Sunset: 135deg #F7A41D -> #E8456B, white text, white accent.
  - Classic: white, 1 px border, dark text #14213D, primary blue value.
- **Under each card:** a row with **Share** (primary) and **Save image** (secondary). Share renders that card to a PNG and opens the system share sheet. Save writes the PNG to the gallery. Render at 2x to 3x pixel ratio. Request gallery permission only when Save is tapped. Check the current maintained packages for sharing and widget-to-image capture on pub.dev before adding them.
- **Owner-only warning:** if the target has `hasAnotherOfferForSameService = true`, show a small orange line under the buttons: "Another offer also applies to these services". Never draw this inside the card, because the card is what customers see and share.
- **Export safety:** Off/Expired/Upcoming cards at 55% opacity and export disabled, with accurate state-specific note (activation web-only, never "turn on from list"). Missing/invalid/reversed dates and unknown discounts cannot export. Any pending/error/capped offers/targets/rules or unusable diagnosed schedule disables export conservatively; do not claim eligibility from partial data. Share/Save are per-target single-flight and scope/eligibility are rechecked after capture/permission awaits. PNG capture is 3x; Share never asks for gallery permission, Save does. Native adapters isolate plugins and return typed friendly failures.
- **States:** loading skeleton cards; error with Retry; if the offer has no targets, show "No targets set up yet. Set this up on Bookixo web."

Data mapping (from the web API; confirm before building). One target record looks like: `id`, `offerId`, `offerTitle`, `targetType` (`SERVICE` or `SHOP`), `serviceMatchMode` (`ALL`, `ANY`, or null for SHOP), `isCombo`, `targetIds[]`, `targetNames[]`, `hasAnotherOfferForSameService`. Group the records by `offerId`; each record becomes one card. A SHOP target has empty `targetIds` and `targetNames` and null mode. Use `targetNames` (array) and ignore the single `targetId` and `targetName`, which only repeat the first item. The discount value and type come from the offer record, and the schedule from the offer's rules; neither is in the target record.

Confirmed GET contracts and schedule-rule-only PUT status exception are in `PROJECT_SPEC.md`. Schedule rules retain raw metadata and isActive without filtering, deduplicate identity/semantics for summaries while retaining distinct IDs for controls. Sunday=1…Saturday=7. End one second before start modulo midnight is all-day; other modular durations under 60 seconds invalid, 60 valid. Equal start/end remains unresolved and is ignored explicitly, never guessed 24h. No usable rules shows validity only. No currency, nullable-date eligibility, unsupported types or unconfigured web destination is inferred. Native share/gallery and backend checks remain device-verification work.

## 5. States, motion, accessibility, dark mode
- **Every async screen** has loading (skeleton cards), empty, error with Retry, and success states. Pull-to-refresh on Queue, Home and Offers.
- **Motion:** short transitions under 300 ms, a quick check animation after saving. No looping animations. Respect the system reduce-motion setting.
- **Accessibility:** support larger system text without overflow; semantic labels on icon-only buttons; contrast at least 4.5:1 for text (check white text on each tile gradient on a real phone in bright light).
- **Dark mode:** use the dark column in section 1 for background, surface, text and border. Keep gradients, accent and status colors; check badge contrast on dark surfaces.
- **Status bar:** match the header color with light icons on gradient screens. Respect safe areas on all screens; forms scroll above the keyboard.
- **Never** hard-code colors or sizes in screens, add features that are not listed, or change labels without updating this file.
