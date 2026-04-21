# Bug Report — Team-invitation magic-link flow

**Affected area:** `SessionsController#verify`, `ApplicationController` before_action chain.
**Upstream commit the diffs apply cleanly to:** `45d8708` ("Add multitenancy with team-scoped routes") and all descendants that leave those files untouched.
**Severity:** Silent data-loss — invitation tokens get consumed without creating the membership; user is dropped into a full team-creation onboarding instead of the invited team.
**Changes below are additive, single-line, and touch three files. Safe to apply in the upstream; nothing else needs to move.**

---

## Bug 1 — `require_onboarding!` halts the filter chain before `SessionsController#verify` runs

### How to reproduce

1. User A signs up (hits `/session/new`, enters email).
2. User A opens the magic-link email, clicks the link, lands on `/onboarding`.
3. User A closes the tab **without submitting the onboarding form** — `session[:user_id]` is now set, `user.name` is still `nil` (so `user.onboarded? == false`).
4. An admin invites someone else (User B) to a team. The email goes to a different address, but User A opens it in the same browser (common when multiple testers share a browser, or when a user with a stale partial account accepts an invite sent to a forwarding address).
5. User A clicks the invitation link `/auth/<token-for-B>?team=<slug>&invited_by=<id>`.

### Expected

`SessionsController#verify` runs, decodes the token (user B), calls `handle_team_invitation`, sets `session[:user_id] = B.id`, redirects either to `/onboarding` (if B needs a name) or to the team.

### Actual

`ApplicationController#require_onboarding!` fires first, sees `current_user = A` is not onboarded, and redirects to `/onboarding`. The token is never consumed. User B is never logged in. Membership for user B is never created. User A's onboarding form shows full team-creation + company-details, because A has no memberships.

### Root cause

`SessionsController` inherits `before_action :require_onboarding!` from `ApplicationController`. That filter fires on every action in `SessionsController`, including `verify`. Sessions endpoints must always be reachable, because that is how a stuck session gets unstuck.

### Fix — `app/controllers/sessions_controller.rb`

Add one `skip_before_action` at the top of the class.

```diff
 class SessionsController < ApplicationController
+  # Sessions routes must always be reachable. A stale session cookie for a
+  # not-onboarded user would otherwise trigger require_onboarding! and
+  # redirect to /onboarding before #verify can consume the token — silently
+  # dropping invitations and magic-link re-verification.
+  skip_before_action :require_onboarding!
+
   # Short-term: prevent rapid-fire attempts
   rate_limit to: 5, within: 1.minute, name: "sessions/short", only: :create,
     with: -> { redirect_to new_session_path, alert: t("controllers.sessions.rate_limit.short") }
```

That's the entire fix for Bug 1. No other edits to `SessionsController` are needed.

### Test — append to `test/controllers/sessions_controller_test.rb`

```ruby
test "invitation link works even when a stale not-onboarded session cookie is present" do
  # Fixtures assumed: users(:not_onboarded) has no name; users(:two) and
  # teams(:two) exist. Adjust names to match your fixture set.
  stale_user = users(:not_onboarded)
  sign_in(stale_user)

  invitee  = User.create!(email: "fresh-invitee@example.com")
  inviter  = users(:two)
  team     = teams(:two)
  token    = invitee.signed_id(purpose: :magic_link, expires_in: 7.days)

  get verify_magic_link_path(
    token: token,
    team: team.slug,
    invited_by: inviter.id
  )

  assert_redirected_to onboarding_path
  assert_equal invitee.id, session[:user_id]
  assert invitee.reload.member_of?(team)
end
```

Run: `bin/rails test test/controllers/sessions_controller_test.rb`. Before the fix this test fails — verify never ran, so `invitee.member_of?(team)` is false. After the fix it passes.

---

## Bug 2 — `team_scoped_request?` treats query-string `team_slug` as a team-scoped route

### Why it matters in the vanilla template

Today, `Teams::MembersController#create` generates the invite URL with `verify_magic_link_url(token:, team:, invited_by:)` — no `team_slug` in there, so vanilla users are fine. But:

- `params[:team_slug]` merges route params *and* query string. If *anyone* downstream customizes URL generation (e.g., a `default_url_options` override merging team context), the invite URL gains a stray `?team_slug=<slug>` query param. That then hits the invitee before verify runs:
  1. `team_scoped_request?` → `true` (query-string `team_slug`).
  2. `set_current_team` runs with `current_user = nil` (invitee has no session).
  3. `redirect_to teams_path, alert: "team not found"`.
  4. `/teams` fires `authenticate_user!` → `/session/new`.
  5. Invitee never reaches `verify`, token still unconsumed, no membership.
- Even without that downstream, this is a latent robustness bug: any future feature that generates a URL via `url_for(team_slug: ...)` on a non-team-scoped route will trigger the same redirect-to-teams.

The fix is a one-line tightening: only route parameters should count.

### Fix — `app/controllers/application_controller.rb`

```diff
   def team_scoped_request?
-    params[:team_slug].present?
+    # Only route params count. A query-string team_slug must not hijack the
+    # filter chain — e.g. on /auth/:token invitation links that a
+    # default_url_options override may decorate with team context.
+    request.path_parameters[:team_slug].present?
   end
```

`request.path_parameters` is the canonical Rails API for "what the router pulled out of the URL path"; it does not include query-string values. Every team-scoped route in the template uses `:team_slug` as a route segment (`scope "/t/:team_slug"`), so this change keeps existing behavior for legitimate team-scoped requests while closing the query-string loophole.

No test needed for this one on its own — it's preventive. If you want coverage, extend the Bug 1 test with a `team_slug:` query param and assert the same redirect-to-onboarding behavior.

---

## Why these two fixes are the minimum

- **Bug 1** is the real silent-failure path that bites every downstream. Any team on the template with invitations + occasional aborted onboardings will hit it.
- **Bug 2** is a robustness tighten that prevents future downstream customization from reintroducing Bug-1-like behavior through a different door.
- Both are single-line, additive edits that won't conflict on future template upgrades.
- Neither changes any public API, URL shape, mailer signature, or fixture.

## Optional — note for downstreams that merge team context into `default_url_options`

If your app overrides `default_url_options` to merge `Current.team.path_params` (`team_slug`, etc.) into every URL helper on team-scoped pages, you must also strip that context when generating the invitation URL — otherwise the URL ships with a stray `?team_slug=...`. Bug 2 above neutralizes the server-side consequences, but the URL is still ugly. Minimal downstream fix:

```diff
# app/controllers/teams/members_controller.rb
-    invite_url = verify_magic_link_url(token: token, team: current_team.slug, invited_by: current_user.id)
+    invite_url = verify_magic_link_url(
+      token: token,
+      team: current_team.slug,
+      invited_by: current_user.id,
+      team_slug: nil,
+      team_kind: nil  # include any other keys your default_url_options merges
+    )
```

This one belongs in the downstream app, not the template, since the template does not define `default_url_options`.

---

## Files to change in the template, summary

| File | Lines changed | Type |
|---|---|---|
| `app/controllers/sessions_controller.rb` | +5 (one `skip_before_action` + 3-line comment + blank) | Additive |
| `app/controllers/application_controller.rb` | ±1 (+ 3-line comment) | In-place |
| `test/controllers/sessions_controller_test.rb` | +19 (one new test) | Additive |

All three diffs apply cleanly to the template as of `45d8708` through current main (template's `SessionsController` and `ApplicationController` have been untouched since).
