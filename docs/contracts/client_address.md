---
component: client_address
covers:
  - app/middleware/client_address.rb
  - config/application.rb
depends_on: []
tests:
  - test/contract/client_address_contract_test.rb
---
Coverage: 1 obligation; 1 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: the client address

The request boundary normalizes client-address headers before Rails derives the address used by request logging and authentication.

### CA-1 client-supplied address headers neither break requests nor choose the recorded address

A request with `Client-IP` or `Forwarded` is answered normally. For an IPv4 or IPv6 loopback peer, Rails records the address supplied by the trusted local proxy in `X-Forwarded-For`, regardless of those competing headers. For a direct public peer, a forged `X-Forwarded-For` cannot replace the peer's address.

**Reason.** The production deployment uses a trusted local proxy that replaces untrusted `X-Forwarded-For` with the real client address. Loopback callers are trusted, not uniquely identified as Caddy. This guarantee assumes the proxy's sanitation and actual loopback transport; it does not verify deployment configuration or protect against a local caller fabricating the trusted header. Competing headers otherwise cause a pre-controller 500 or replace the logged and stored address. (D-32)

Kind: functional. Proof: test, the CA-1 request tests in `test/contract/client_address_contract_test.rb`.

## Decisions

- D-32, `docs/decisions/client_address.md`: normalize client-address headers before Rails IP calculation and logging (CA-1).
