# Bookixo Pro: New Booking and Complete Booking Flow

Contract and implementation reference for the Bookixo mobile booking flow. Read with `PROJECT_SPEC.md`, `CODING_STANDARDS.md` and `DESIGN.md`. Do not invent endpoints or fields; unresolved backend semantics remain explicit.

## 1. Goals and roles
- Employees and owners can **create a booking** (walk-in) and **start** any Pending booking.
- An employee can open any Pending or In progress booking, **add the services they did** with an optional employee discount, and save. Another employee can open the same booking later and add the services *they* did. Everyone sees who did which service.
- The **owner and shop_admin complete** any In progress booking: add, remove or change any line, see the totals, choose the payment mode and complete.
- Employee screens do not display totals, service prices or payment details. The services API may return prices to the app; employee widgets must not render them.

| Action | Employee | Owner / shop_admin |
|---|---|---|
| New booking (needs feature `SHOP_BOOKINGS_CREATE`) | yes | yes |
| Start a Pending booking (assignee = self) | yes | yes (owner must be an active shop user) |
| Add / edit **own** lines and discount % | yes | yes |
| See other people's lines (service, quantity, who) | read-only, no prices | yes |
| Edit or remove **any** line | no | yes |
| Complete the booking and record payment (also discard the draft) | no | yes |

The mobile UI applies these role rules using the server-issued role. The backend currently does not enforce the mobile-specific edit restrictions; draft writes are therefore limited to the actions described here and no additional override or payment fields are editable by employees.

## 2. States
- Booking status: `PENDING`, `IN_PROGRESS`, then completed (leaves the queue).
- Draft state: `EDITABLE`, `COMPLETION_PENDING` (BOOKIXO payment link sent, read-only until the customer pays), `COMPLETION_RECOVERY_REQUIRED` (a previous attempt left a payment order; show **Retry completion**), `COMPLETED`.
- **"Ready to pay"** is not a status: it means the booking is IN_PROGRESS and its draft has at least one service line.
- **"Awaiting payment"** = draft state `COMPLETION_PENDING`.

## 3. Known API contracts
Paths are relative to the API base and use the authenticated protected client. Include the validated `shopId` only on calls whose confirmed contract lists it.

| Purpose | Call |
|---|---|
| Customer lookup | `GET /api/public/bookings/lookup-app-user?phoneNumber=` -> `{exists, appUserId, phoneNumber, firstName, lastName, gender, dob}` |
| Create walk-in | `POST /api/public/bookings/walk-in` body `{shopId, phoneNumber, firstName, lastName, gender, dateOfBirth}` (`dateOfBirth` as `yyyy-MM-dd`) -> `{bookingId, bookingReference, queueNumber, status, message, ...}` |
| Start | `PUT /api/public/bookings/{id}/start?shopId=&assigneeId=` |
| Queue | `GET /api/public/bookings/queue?shopId=&status=PENDING` and `...status=IN_PROGRESS` (two calls in parallel) |
| Booking details | `GET /api/public/bookings/{id}/details?shopId=` -> `{appUserEmail, appUserId, assigneeId, bookingId, remainingAmountPaid, serviceId, serviceIds, serviceName, servicePrice, shopId, walletCreditUsed}`. Use only booking/customer/assignee/service identifiers in employee UI. |
| Services | `GET /api/public/shops/shop/services/{shopId}` -> `{shopId, services:[{id,parentId,name,description,price,durationMinutes,isBookable,...}]}`. Price may be in the response; employee screens never render it. |
| Payment config | `GET /api/shop-payment-config?shopId=` -> `{shopId,paymentMethods:[{code,name,enabled,hasOptions,options:[{code,name,enabled}]}]}`; omit disabled methods/options and omit WALLET in v1. |
| Staff list | `GET /api/public/bookings/start-users?shopId=` -> staff records with `shopUserId`, `userId`, `email`, `name` |
| Enabled shop features | `GET /api/shop-features/me?shopId=` -> plain array of feature keys, e.g. `["SHOP_BOOKINGS_CREATE", ...]`. Gates the New booking + button |
| Draft read | `GET /api/bookings/{id}/completion-draft` (404 = no draft yet) |
| Draft save | `PUT /api/bookings/{id}/completion-draft` body below. The backend requires `payload.paymentMode` on every save; a services-only save keeps the draft's mode or sends `CASH` as a placeholder |
| Pricing (owner only) | `POST /api/public/bookings/{id}/pricing/calculate?shopId=` body below |
| Complete | `POST /api/bookings/{id}/completion-draft/complete` body `{"expectedRevision": <n>}`. `n` is the revision returned by the draft save made just before (every save increments it). Response is the draft shape with `draftState`, `payload`, `revision`, `schemaVersion`, and `updatedAt`; `draftState` is `COMPLETED` or `COMPLETION_PENDING` for BOOKIXO. |
| Discard draft | `DELETE /api/bookings/{id}/completion-draft` body `{"expectedRevision": n}`. Owner-side UI only |
| Invoice | **Not used in mobile** |

**Queue item** (`GET .../queue` returns a plain array, not paged). Fields used by the app: `id`, `queueNumber`, `appUserId`, `appUserName` (also `appUserFirstName`, `appUserLastName`), `appUserIdentifier` (phone with country code), `bookingTime` (local time with no zone, for example `2026-10-24T07:44:17`), `status`, `assigneeId`, `assigneeFirstName` (first name only). `serviceId` and `serviceName` are null for walk-ins, and also for In progress bookings whose services live only in the draft.
- Confirmed integration behavior: `PENDING` returns today's bookings; `bookingTime` is in `Asia/Kolkata`. The app resolves the current `shopUserId` by a unique, case-insensitive email match between the authenticated login and `start-users`; it never assumes login `userId` equals `shopUserId`. `SHOP_BOOKINGS_CREATE` is read from `GET /api/shop-features/me?shopId=<shopId>` (a plain array of enabled feature keys, the same source the web queue uses); a navigation `menuKey` with that value is also accepted. If the feature call fails, the + stays hidden. Until shop binding is confirmed, booking API calls include the validated `shopId`.
- **"Mine"** = `assigneeId` equals the current user's `shopUserId`. Show "With <assigneeFirstName>" for others.
- **The queue has no service or draft info,** so it cannot show "Ready to pay" or service names. The app loads the booking draft when a user opens its details, never for every queue card.
- **Privacy:** the response also carries address fields (`addressLine1`, `addressLine2`, `city`, `pincode`, `landmark`, `state`) and the full phone number. The app does not retain or display either addresses or phone numbers for any role. Never log them.
- **Wait time** is computed from `bookingTime`, which has no zone. Interpret it as Asia/Kolkata local time; the app does not retain or display queue phone/address fields.

**Draft save body**
```
{ "expectedRevision": <n>, "schemaVersion": 1,
  "payload": {
    "serviceLines": [ { "serviceId", "quantity", "subtotalOverride": null, "additionalDiscountPercent", "assigneeId" } ],
    "additionalServiceNames": [ "<names of every line after the first>" ],
    "selectedMembershipId": null, "applyGst": true, "manualFinalAmount": null,
    "paymentMode": "CASH", "paymentOption": null, "manualTransactionId": "", "manualPaymentNote": "",
    "selectedWalletId": null, "useWalletCredit": false, "walletAmount": null,
    "walletPackageQuantity": 1, "walletPackageAllocations": [], "selectedWalletPlanId": null,
    "printBill": false } }
```
Response carries `draftState`, `revision`, `updatedAt`, `payload`, and `schemaVersion`. A first save uses `expectedRevision: 0`.

**Draft GET** returns this same shape. A 404 response `{"message":"No completion draft exists for this booking"}` means no draft and is mapped to revision 0 / `EDITABLE`. Preserve all payload fields not owned by the current edit when saving.

**Pricing body (owner only)**
```
{ "serviceId": <first line's serviceId>,
  "services": [ { "serviceId", "quantity", "additionalDiscountPercent" } ],
  "selectedMembershipId": null, "applyGst": true }
```
v1 does not send `editedserviceprice` or `totalAmount` (no price overrides on mobile).

In the pricing response, `gstApplied` controls GST parsing. When false, ignore
`gstAmount`, `gstPercentage` and `gstTaxMode` (including missing/null fields),
and use zero GST amount/percentage with no inclusion flag. When true, GST
amount and percentage must be valid finite numbers or numeric strings.

## 4. Calls per screen
| Screen | Calls |
|---|---|
| **App start / login** | menu, enabled features, then both permitted queue calls |
| **Queue** | both queue calls in parallel; pull-to-refresh; live updates (socket while open, polling every 10 to 15 s as fallback) |
| **New booking** | lookup (automatically, once, when the phone number becomes a complete 10-digit number, including a pasted `+91` number; never per keystroke and never repeated for the same number; editing the number clears the old result; only the latest lookup may update the form; a failed lookup shows Retry and never blocks creating) -> walk-in -> optional start. Add the new booking to the list locally, then refresh in the background |
| **Employee opens Pending** | start (assignee = own `shopUserId`), then booking details, draft `GET` (usually 404), and service catalogue |
| **Employee opens In progress** | booking details, draft `GET`, and service catalogue |
| **Employee saves** | draft `PUT` (see section 5) |
| **Owner opens Complete** | booking details, draft `GET`, service catalogue, payment config (cached for the authenticated shop) -> `pricing/calculate` (debounce 350 ms after each edit). Do **not** call memberships, member-pricing, GST settings or wallets in v1 |
| **Owner completes** | draft `PUT` with the payment fields -> `POST .../completion-draft/complete` with the revision returned by that `PUT` -> if `COMPLETED`, show the confirmation; if `COMPLETION_PENDING`, show Awaiting payment |

## 5. Draft rules in the app
- **One draft per booking, lines carry their own `assigneeId`.** Every line the mobile app creates carries the current user's `shopUserId`. Existing null assignees are preserved and treated as read-only for employees; the backend's crediting semantics remain unknown.
- **Employee save:** read the latest draft, keep every other person's lines and all non-line fields exactly as received, replace only lines whose `assigneeId` is the caller's, send `expectedRevision` from the read. On a revision conflict, re-read, re-apply own lines, retry **once**, then show "Someone else just changed this booking" and reload. The mobile client enforces this behavior; the backend currently permits employee and owner draft operations without the mobile-specific restrictions.
- A service already on the booking (by another person) cannot be added again by an employee. Existing lines remain read-only; only the owner can change quantity or remove them. The app avoids duplicate service lines because the web may merge them during calculation.
- `additionalServiceNames` = names of every line after the first, in order. It is used for fallbacks and warnings when a service is later removed.
- `printBill` is always sent as `false`. Invoices and printing are not part of the mobile app.
- If a saved line refers to a service or staff member that no longer exists, show a warning on that line and block completion until the owner fixes it.
- **Discount:** whole numbers or two decimals, 0 to 100, per line. No separate employee discount cap is configured.
- **First save by an employee** does not set payment fields. `applyGst` defaults to `true`.

## 6. Owner payment screen
Show only server-calculated values from `pricing/calculate`. Never compute totals on the phone.
- Lines: service, quantity, line subtotal, `additionalDiscountPercent` and `additionalDiscountAmount`, who did it.
- Summary, in this order: **Subtotal** (`servicePrice`), **Employee discount** (`perServiceDiscountAmount`, shown if above 0), **Other discounts** (membership and offers: `discountAmount`, shown if above 0), **GST** (`gstAmount`, with the percent and "added" or "included" from `gstTaxMode`, shown if `gstApplied`), **Final amount** (`finalAmount`).
- `appliedRules` strings go inside a collapsed "Applied pricing rules" section.
- If `hasActiveMembership` is true but `membershipApplied` is false, show a small note: "<name> member: no membership discount on these services."
- **Payment modes** come from the config: enabled methods, excluding `WALLET` in v1. `CARD` requires one of its enabled `options` (bank code goes in `paymentOption`). `UPI` has optional `manualTransactionId` and `manualPaymentNote`. `BOOKIXO` sends a payment link, so completion ends in `COMPLETION_PENDING`.
- The Complete button stays disabled while pricing is loading, if the last calculation does not match the current lines, if CARD has no option chosen, or while the draft is not `EDITABLE`.
- `COMPLETION_RECOVERY_REQUIRED` shows a read-only screen with **Retry completion**.

## 7. Safety, errors, concurrency
- All money logic stays on the server. The app never calculates tax, discount or totals.
- Idempotency keys on walk-in create, start and complete (**recommended**), and the button is disabled and repeat taps ignored while a request runs. Never auto-retry create, start, save or complete (a manual retry after a conflict is the only exception).
- Start can fail because another person started it first: show "Already started by <name>" and refresh the queue.
- Typed failures as in `CODING_STANDARDS.md`: network, 401 (one refresh, then logout), 403, 404 (draft none), 409 (conflict), validation (400/422), server.
- Phone numbers: send the 10-digit Indian number for lookup and create; the backend adds `+91`. Strip formatting and a supplied `+91` prefix before sending. The lookup response may return E.164 (for example `+91...`), so normalise both sides before comparing.
- Gender: the walk-in endpoint accepts `Male` and `Female`; accept API casing on read and normalize in one place.
- Never log phone numbers, names or tokens.

## 8. Backend behavior and mobile enforcement
1. Backend currently does not enforce mobile-specific own-line editing restrictions. Mobile employees may edit only their own lines, cannot edit other staff lines, and cannot access owner payment/completion controls. Owner-side screens may edit any line and use pricing/payment APIs.
2. Draft writes must preserve existing non-line payload fields and include the complete payload shape. The app uses expectedRevision=0 when creating the first draft and increments from returned revisions.
3. Pricing calculation is available to both roles, but the app requests and renders it only for owners.

**Follow-ups**
4. Queue response can add `hasDraft`, `draftServiceNames[]` and `lastUpdatedAt`; stop sending address/full phone to employees and add server time/shop timezone.
5. Add idempotency keys and a clear 409 start response with current assignee name.
6. Add live events for start, line save and completion.
7. Expose shop currency/format settings. Until then, owner amounts use INR (`₹`) with two decimal places, as confirmed by the product owner.
8. Optionally add one owner completion-context API for draft, pricing and payment config.

## 9. Remaining backend questions
1. What does an existing `assigneeId: null` mean, and who receives service credit? The app preserves such lines and does not let employees edit them.
2. How does the backend treat duplicate `serviceId` lines and `additionalServiceNames`? Employees cannot add a duplicate service; owner calculations remain server-driven.
3. Shop currency/number-format settings are not present in the confirmed payment/pricing responses. The product owner confirmed INR display; owner amounts use `₹` with two decimal places until shop-specific formatting is exposed.

## 10. Original build order
1. Models and repository interfaces with mock implementations (booking, draft, lines, pricing, payment config, staff).
2. Queue screen: both calls, Pending and In progress tabs, pull-to-refresh, queue number, status badges.
3. New booking: lookup, create, optional start, New-customer SMS notice.
4. Start and Add services (employee): service search and badges, quantity, per-line discount, save as own lines, show other people's lines read-only.
5. Owner Complete: draft read, pricing, line edit and remove, payment mode, complete.
6. Awaiting payment and Retry completion.
7. Live updates (socket or polling), cache refresh on resume.
8. Tests: role rules, own-lines merge, revision conflict retry, discount cap, payment validation (CARD option), the pricing summary display order, pending and recovery states.

## Confirmed mobile integration boundary
- Outside explicit demo mode, queue, customer lookup, walk-in create, staff-list, start, booking details, services, draft read/save, pricing, payment config, completion and discard use the confirmed authenticated APIs.
- Queue DTOs discard phone/address fields; wait time interprets the zone-less booking timestamp as `Asia/Kolkata`.
- Service DTOs discard catalog price data. Employee presentation shows no prices, totals, or payment details. Server-calculated prices are requested and rendered only for the owner workflow.
