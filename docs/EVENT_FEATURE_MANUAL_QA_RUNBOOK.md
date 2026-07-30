# Event Feature Manual QA Runbook

Repo: `Bar`  
Scope: hosted event request, admin review, invite acceptance, calendar save, staff event check-in, event wallet, drink charging, notifications, and regressions.

## Purpose

Use this checklist to manually validate the Event feature as implemented in:

- mobile app flows under `lib/screens/events`, `lib/screens/lounge`, and `lib/screens/staff`
- Supabase RPC and data contracts in `supabase/migrations/024_events_mvp.sql`, `025_events_backend_contract.sql`, and `026_event_minimum_pax_contract.sql`
- current admin server routes in `admin-web/server/src/routes`

This is intentionally repo-specific and includes expected backend effects, not just UI expectations.

## Prerequisites

- [ ] Supabase is configured for the mobile app and the latest event migrations are applied:
  - [ ] `024_events_mvp.sql`
  - [ ] `025_events_backend_contract.sql`
  - [ ] `026_event_minimum_pax_contract.sql`
  - [ ] `027_vip_room_session_columns.sql` (required for club session upsert / normal entry; app also retries without these columns if migration is not yet applied)
- [ ] Push infrastructure is configured enough to observe notification fan-out, or at minimum to inspect `member_notifications` and `push_dispatch_queue`.
- [ ] At least 3 accounts exist:
  - [ ] `host_member` with role `member`
  - [ ] `guest_member` with role `member`
  - [ ] `staff_user` with role `staff` or `admin`
- [ ] `host_member` and `guest_member` have valid `profiles` rows.
- [ ] `guest_member` can be signed in on a separate device/emulator from `host_member`.
- [ ] `guest_member` has a venue session available for door scan tests.
- [ ] For check-in tests, the guest session must already be venue checked in, because `staff_check_in_event_guest` rejects sessions with no `entered_at`.
- [ ] Know how to inspect these tables:
  - [ ] `club_events`
  - [ ] `event_invites`
  - [ ] `event_guests`
  - [ ] `event_wallet_transactions`
  - [ ] `drink_orders`
  - [ ] `member_notifications`
  - [ ] `push_dispatch_queue`

## Important Product Gaps Before QA

- [ ] The member app can submit hosted event requests, but I did not find a mobile UI to add guest drafts/invites during request creation. In practice, invite rows likely need manual backend/admin seeding for end-to-end guest acceptance tests.
- [ ] I did not find an implemented admin UI in `admin-web` for calling `admin_review_event_request` or for listing/managing `event_invites` / `event_guests`. Admin approval and invite provisioning are likely manual RPC/SQL actions today.
- [ ] I did not find code in the repo that generates or sends invite deep links from the UI. Token-based acceptance is supported by `/event-invite?token=...`, but obtaining the token currently looks like a backend/admin task.
- [ ] I did not find app-side handling for event-specific notification kinds. The backend inserts them into `member_notifications`, and push enqueue should happen via the existing trigger, but QA may need to verify at the DB/push queue level instead of a dedicated in-app event notification center.

## Suggested Test Data

Use a future event for request and approval tests, then adjust or seed an active event for live wallet/check-in/drink tests.

- Event title: `QA Event <date>`
- Branch: any branch already used by the app, ideally the host's current branch
- Event type: `private_social`
- Start time for request flow: `now + 8 days`
- End time for request flow: `start + 4 hours`
- Minimum pax: `10`
- Initial wallet: `120 minutes`

For active event tests:

- Use the same event after approval and move times so it is currently active, or seed a separate approved event whose window includes the present time.
- Seed exactly 1 invite for `guest_member` to avoid the backend error `Multiple active event guests found. Resolve manually in admin.`

## 1. Host Event Request Creation

### In app

- [ ] Sign in as `host_member`.
- [ ] Open the Events flow at `/events`.
- [ ] Confirm `MY HOSTED EVENTS` renders and existing hosted events can load.
- [ ] In `NEW REQUEST`, enter:
  - [ ] title with at least 3 characters
  - [ ] a valid branch
  - [ ] an event type
  - [ ] start time at least 7 days in the future
  - [ ] end time after start
  - [ ] expected pax `10` or higher
  - [ ] wallet `60` minutes or higher
- [ ] Confirm the `REQUEST CHECK` card shows all checks passing.
- [ ] Tap `SUBMIT HOST EVENT REQUEST`.

### Expected results

- [ ] Success message shows request submitted for pending review.
- [ ] Form resets after success.
- [ ] New event appears in `MY HOSTED EVENTS`.
- [ ] Status badge shows `Pending review`.
- [ ] Minimum pax displays on the hosted event card.
- [ ] Wallet seed displays as the requested hours.

### Expected backend effects

- [ ] `club_events` gets a new row with:
  - [ ] `approval_status = 'pending_review'`
  - [ ] `requested_by = host_member.id`
  - [ ] `host_id = host_member.id`
  - [ ] `minimum_pax = 10` or submitted value
  - [ ] `wallet_seconds = requested_wallet_seconds`
  - [ ] `wallet_total_extended_seconds = 0`
  - [ ] `wallet_consumed_seconds = 0`
  - [ ] `wallet_low_threshold_seconds` set to backend-calculated threshold
- [ ] `event_wallet_transactions` gets an initial `seed` row for the event.
- [ ] If invites were manually included through backend seeding, corresponding `event_invites` rows exist with unique `invite_code` and `invite_token`.

## 2. Host Request Negative Cases

- [ ] Try submitting with start time under 7 days ahead.
  - Expected: UI blocks with `Hosted events must be requested at least 7 days ahead.`
- [ ] Try submitting with end time before start.
  - Expected: UI blocks with `End time must be after the start time.`
- [ ] Try submitting with pax under 10.
  - Expected: UI blocks with `Hosted events need at least 10 expected guests.` or field validation `Minimum pax is 10.`
- [ ] Try submitting with wallet under 60 minutes.
  - Expected: UI blocks with `Event wallet must start at 60 minutes or more.`

## 3. Admin Approval / Rejection / Needs Revision

Because I did not find a working admin review UI for the event RPC, validate using a backend/admin manual action that calls `admin_review_event_request(event_id, decision, notes)`.

### Approve

- [ ] Review the pending event via backend/admin tooling.
- [ ] Call `admin_review_event_request` with:
  - [ ] `p_event_id = <new event id>`
  - [ ] `p_decision = 'approved'`
  - [ ] optional notes

Expected results:

- [ ] Host event status changes from `Pending review` to `Approved` after refresh.
- [ ] Host card remains visible in `MY HOSTED EVENTS`.
- [ ] If the event is currently active, host wallet summary becomes available.

Expected backend effects:

- [ ] `club_events.approval_status = 'approved'`
- [ ] `club_events.reviewed_at` set
- [ ] `club_events.reviewed_by` set
- [ ] `club_events.approved_at` set
- [ ] `club_events.admin_review_notes` populated if supplied
- [ ] `member_notifications` gets a row with `kind = 'event_request_approved'`
- [ ] `push_dispatch_queue` gets a corresponding push-enqueue row if push trigger is working

### Reject

- [ ] Call `admin_review_event_request` with `p_decision = 'rejected'`.

Expected results:

- [ ] Host sees `Rejected` on the hosted event card after refresh.
- [ ] Review notes appear on the card if provided.

Expected backend effects:

- [ ] `club_events.approval_status = 'rejected'`
- [ ] `club_events.rejected_at` set
- [ ] `member_notifications.kind = 'event_request_rejected'`

### Needs revision

- [ ] Call `admin_review_event_request` with `p_decision = 'needs_revision'`.

Expected results:

- [ ] Host sees `Needs revision`.
- [ ] Review notes appear on the hosted event card.

Expected backend effects:

- [ ] `club_events.approval_status = 'needs_revision'`
- [ ] `member_notifications.kind = 'event_request_needs_revision'`

## 4. Guest Invite Acceptance by Code

Precondition: approved event exists and an `event_invites` row has been manually seeded for `guest_member`, ideally with `guest_email` matching the guest account email.

- [ ] Sign out the guest if already signed in.
- [ ] Open `/event-invite`.
- [ ] Enter the invite code and tap `PREVIEW INVITE`.
- [ ] Confirm preview loads with event title, branch, host, date, time, and guest name.
- [ ] While signed out, verify the screen asks the guest to sign in or create an account.
- [ ] Sign in as `guest_member`.
- [ ] Return to the invite screen if needed.
- [ ] Tap `ACCEPT INVITE`.

Expected results:

- [ ] Success state changes to `Invite confirmed`.
- [ ] `SAVE TO CALENDAR` button appears.
- [ ] If app state kept the pending code, redirect behavior returns the member to `/event-invite?code=...` until acceptance completes.

Expected backend effects:

- [ ] `event_guests` gets a row linking:
  - [ ] `event_id`
  - [ ] `invite_id`
  - [ ] `member_id = guest_member.id`
  - [ ] `status = 'accepted'`
  - [ ] `accepted_at` set
- [ ] `event_invites.accepted_by = guest_member.id`
- [ ] `event_invites.accepted_at` set
- [ ] `event_invites.status = 'accepted'`

## 5. Guest Invite Acceptance by Deep Link / Token

Precondition: same as above, but use the invite token and route `/event-invite?token=<invite_token>`.

- [ ] Open the deep link route with a real `invite_token`.
- [ ] Confirm preview loads automatically without entering a code.
- [ ] If signed out, sign in as `guest_member`.
- [ ] Tap `ACCEPT INVITE`.

Expected results

- [ ] Acceptance succeeds exactly like the code flow.
- [ ] Guest lands in confirmed state and can save to calendar.

Expected backend effects

- [ ] Same DB changes as the code flow.
- [ ] Acceptance path internally resolves token to invite code and records token-based acceptance semantics in the RPC response.

## 6. Invite Negative Cases

- [ ] Use an unknown invite code.
  - Expected: `That invite code was not found.`
- [ ] Use a valid invite for an event still pending approval.
  - Expected: `This invite is pending admin approval.`
- [ ] Use a valid invite while signed into a different email than `guest_email`.
  - Expected: `Sign in with the invited email to accept this invite.`
- [ ] Accept the same invite from a different member account after it was already claimed.
  - Expected: invite claim fails.
- [ ] Accept an invite after event end time has passed.
  - Expected: acceptance fails as expired.
- [ ] Seed two accepted invites for the same guest across two simultaneously active events.
  - Expected: staff check-in flow later fails with `Multiple active event guests found. Resolve manually in admin.`

## 7. Calendar Save Behavior

Precondition: guest invite has been accepted.

- [ ] From the confirmed invite screen, tap `SAVE TO CALENDAR`.

Expected results

- [ ] Device calendar prompt opens or calendar event is created.
- [ ] App shows `Saved to your device calendar.` on success.
- [ ] If permission or platform save fails, app shows `Could not save the event to your calendar.`

Expected calendar payload

- [ ] Title equals event title.
- [ ] Location equals branch.
- [ ] Description starts with `Hosted by <host name>`.
- [ ] If event description exists, it is appended below host line.
- [ ] End time uses event `ends_at`, or defaults to `starts_at + 2h` if `ends_at` is null.

## 8. Staff Door Scan Event Check-In

Preconditions:

- [ ] Event is approved and currently active.
- [ ] Guest has accepted the invite.
- [ ] Guest has already been venue checked in and has a valid club session with `entered_at`.
- [ ] Staff account can access `/staff`.

### QR path

- [ ] Sign in as `staff_user`.
- [ ] Open the door scanner.
- [ ] Scan the guest's venue QR code.
- [ ] Confirm the pending overlay shows the correct guest and entry/exit action.
- [ ] Tap confirm.

### Manual code path

- [ ] On the same screen, enter the guest session code manually.
- [ ] Tap `LOOKUP`.
- [ ] Confirm guest resolves and staff can confirm the scan.

### Expected results

- [ ] Base venue scan succeeds as normal.
- [ ] If the guest also matches one active approved event, success overlay shows `EVENT GUEST CHECKED IN`.
- [ ] Overlay includes event title and host name.
- [ ] Staff can continue to next guest.

### Expected backend effects

- [ ] `event_guests.status = 'checked_in'`
- [ ] `event_guests.checked_in_at` set
- [ ] `event_guests.checked_in_by = staff_user.id`
- [ ] `event_guests.club_session_id = guest_session.id`
- [ ] `event_invites.status = 'checked_in'`
- [ ] `member_notifications` gets a row with `kind = 'event_guest_checkin'` for the host
- [ ] `push_dispatch_queue` gets an enqueued push row if trigger is active

## 9. Staff Check-In Negative Cases

- [ ] Try check-in before the guest has venue `entered_at`.
  - Expected: backend rejects with `Member has not been venue checked in yet.`
- [ ] Try check-in for a guest with no accepted event invite.
  - Expected: normal venue scan can still succeed, but event check-in result is null and no event success card appears.
- [ ] Try check-in for a guest whose event is not active.
  - Expected: no event check-in result.
- [ ] Try check-in for a guest with multiple active event guest rows.
  - Expected: backend error requiring manual admin resolution.

## 10. Event Wallet Low-Balance / Extend-Time Flow

Precondition: host has an approved, currently active event.

- [ ] Sign in as `host_member`.
- [ ] Open `/events`.
- [ ] Confirm the active hosted event wallet summary is visible once the event is active.
- [ ] Reduce wallet balance through drink fulfillment until it falls at or below the low threshold.
- [ ] Confirm the host sees a low-wallet prompt state:
  - [ ] wallet summary highlighted
  - [ ] CTA changes to `EXTEND NOW` or similar
  - [ ] wallet sheet opens with low-balance messaging
- [ ] From the wallet sheet, extend by `15`, `30`, and `60` minutes in separate passes as needed.

Expected results

- [ ] Remaining balance updates after refresh.
- [ ] Extended amount increments.
- [ ] Prompt is cleared after a successful extension.
- [ ] Sheet can still open when wallet is healthy.

Expected backend effects

- [ ] `club_events.wallet_seconds` increases by selected extension amount in seconds
- [ ] `club_events.wallet_total_extended_seconds` increases accordingly
- [ ] `club_events.wallet_last_extended_at` updates
- [ ] `club_events.wallet_low_notified_at` resets to null on extension
- [ ] `event_wallet_transactions` gets an `extension` row per action

Negative checks

- [ ] Attempt extension under 15 minutes through backend/manual invocation if possible.
  - Expected: `Minimum extension is 15 minutes.`
- [ ] Attempt extension as a non-host, non-admin member.
  - Expected: `Hosted event not found.`

## 11. Event Wallet Drink-Order Charging

Preconditions:

- [ ] Guest is inside the club.
- [ ] Guest has been event checked in.
- [ ] Event is active.
- [ ] Event wallet has enough time to cover the chosen drink.

- [ ] As `guest_member`, order a drink that is not cash, not VIP-room tab, and not a standard included package drink, so the charge source can resolve to event wallet.
- [ ] As staff, move the order to preparing, then delivered.
- [ ] Let the guest device settle the delivered order.

Expected results

- [ ] Order is created with `charge_source = eventWallet`.
- [ ] No deduction happens at order placement time.
- [ ] Deduction happens only after delivery settlement.
- [ ] Guest stays on event coverage if wallet still has balance.
- [ ] Host event wallet summary decreases after settlement.

Expected backend effects

- [ ] `drink_orders` row exists with:
  - [ ] `event_id = active event id`
  - [ ] `charge_source = 'eventWallet'`
  - [ ] `status` progresses `pending -> preparing -> delivered`
- [ ] On settlement, RPC `consume_event_wallet_for_drink` updates:
  - [ ] `club_events.wallet_seconds` decreases
  - [ ] `club_events.wallet_consumed_seconds` increases
  - [ ] `event_wallet_transactions` gets a `drink_charge` row with negative `seconds_delta`
  - [ ] transaction includes `order_id` and `event_guest_id`

Negative checks

- [ ] Deliver a drink when the guest is accepted but not event checked in.
  - Expected: event-wallet settlement should fail and no event-wallet deduction should occur.
- [ ] Deliver a drink after wallet drops below the drink cost.
  - Expected: settlement fails for event wallet; app should not deduct event time.
- [ ] Confirm fallback selection behavior:
  - [ ] if event wallet cannot cover the drink at order time, charge source should fall back to `personalTime`
  - [ ] if `payWithCash = true`, charge source must be `cashAtBar`
  - [ ] if in VIP room, charge source should prefer `vipRoomTab`
  - [ ] if drink is standard/included, charge source should prefer `packageAllowance`

## 12. Notification Expectations

Validate first at the DB level, then in push queue if applicable.

### Approval / rejection / needs revision

- [ ] Approve, reject, and needs-revision each create a `member_notifications` row to the host/requester.
- [ ] Notification `kind` values:
  - [ ] `event_request_approved`
  - [ ] `event_request_rejected`
  - [ ] `event_request_needs_revision`
- [ ] `metadata` includes `event_id`, `event_title`, `approval_status`, and review notes.

### Guest check-in

- [ ] Event check-in creates `member_notifications.kind = 'event_guest_checkin'`.
- [ ] `metadata` includes event id/title, guest id/name, member id, and session id.

### Low wallet

- [ ] When a drink charge crosses into or lands within low-wallet threshold, `member_notifications.kind = 'event_wallet_low'` is created for the host.
- [ ] `metadata` includes event id/title, remaining seconds, and order id.
- [ ] Repeated drink charges below the threshold should not spam repeated low-wallet notifications unless the wallet was extended and later dropped low again.
- [ ] Confirm `club_events.wallet_low_notified_at` is set after the low-wallet notification and reset after extension.

### Push enqueue

- [ ] Each inserted event-related `member_notifications` row should also enqueue a row in `push_dispatch_queue` through the existing trigger on `member_notifications`.
- [ ] If the queue row is created but no device push is observed, treat that as a push-delivery/configuration issue, not necessarily an event feature logic failure.

## 13. Regression Checklist

- [ ] Normal event request submission still works after approving or rejecting other events.
- [ ] Door scanning still works for non-event guests.
- [ ] Manual session code lookup still works for non-event guests.
- [ ] Drink orders still work for non-event charge sources: personal time, package drinks, VIP tab, and cash at bar.
- [ ] Event wallet charges do not deduct from personal time simultaneously.
- [ ] Accepting an event invite does not bypass venue entry requirements.
- [ ] Event check-in does not happen before venue check-in.
- [ ] Realtime/state refresh on the member app still loads hosted events, accepted invites, and active attendance without crashing when one of those lists is empty.

## 14. Manual Backend / Admin Actions Likely Required Today

- [ ] Approve/reject/revise requests by calling `admin_review_event_request(...)` directly.
- [ ] Inspect or seed `event_invites` manually because the host mobile UI does not appear to expose invite creation or link/code sharing yet.
- [ ] Obtain `invite_token` directly from `event_invites` to test deep-link acceptance.
- [ ] Adjust event times manually if you need an approved event to become active during the test window.
- [ ] Use DB inspection rather than admin-web UI for `event_guests`, `event_wallet_transactions`, and event notification verification, because I did not find dedicated admin pages for those artifacts.

## Exit Criteria

- [ ] Host can submit a valid request and sees pending state.
- [ ] Admin/backend review changes state correctly and creates notification records.
- [ ] Guest can accept via invite code.
- [ ] Guest can accept via token deep link.
- [ ] Accepted guest can save the event to device calendar.
- [ ] Staff event check-in marks the guest checked in and notifies the host.
- [ ] Event wallet can be depleted, low-wallet notification triggers, and host can extend it.
- [ ] Delivered drinks can charge against the event wallet only after event guest check-in.
- [ ] Negative cases above behave as expected without breaking non-event flows.
