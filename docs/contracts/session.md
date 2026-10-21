---
component: session
covers:
  - app/controllers/sessions_controller.rb
  - app/views/sessions/
depends_on: []
tests:
  - test/contract/session_contract_test.rb
---
Coverage: 1 obligation; 1 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: signing in

The admin's sign-in form and the endpoint it posts to, `POST /session`, which starts a session for the one admin user.

### SE-1 a sign-in request without both credentials is refused, not a server error

A sign-in request that the existing rate limiter admits, and that lacks the email address or the password or carries either as anything but a string (a list, a set of fields, a JSON number, boolean or null), is answered 400 Bad Request and starts no session. An admitted request carrying both as strings, even blank, is answered as before: the right pair signs in, any other pair returns to the form with the wrong-credentials message. A request the rate limiter throttles keeps the limiter's answer, a redirect to the form with "Try again later.", and starts no session; malformed requests count towards the limit like any other.

Reworded 2026-10-21 by fix round 1 of this PR: string credentials, and the rate limiter's boundary.

**Reason.** The sign-in form always sends both fields, so a request without them is malformed, and a public endpoint must not answer it with a 500. Blank fields stay a wrong-credentials answer because the form can send them. A JSON body can carry numbers and booleans, which a form never does. The limiter runs first and is unchanged, so throttling stays its own answer.

Kind: functional. Proof: test, the SE-1 tests in `test/contract/session_contract_test.rb`.
