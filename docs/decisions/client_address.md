# Client-address decisions

### D-32. Normalize client-address headers before Rails IP calculation and logging

**Decision.** A small `ClientAddress` middleware in `app/middleware/` deletes `HTTP_CLIENT_IP` and `HTTP_FORWARDED`. It also deletes `HTTP_X_FORWARDED_FOR` unless `REMOTE_ADDR` is in IPv4 loopback (`127.0.0.0/8`) or IPv6 loopback (`::1`). Insert it before `ActionDispatch::RemoteIp`, which precedes the request logger in the application's real stack. Explicitly require the file during boot and exclude its directory from the reloadable autoloader: the stack retains its class for the process lifetime.

**Derivation.** A conflicting `Client-IP` causes `IpSpoofAttackError` when Rails' logger evaluates the address before any controller runs. Rack 3.2.6 prefers `Forwarded` to `X-Forwarded-For`, allowing a supplied header to replace the logged address and the session's `ip_address`. A controller rescue is too late; disabling spoof detection leaves the competing input. Normalizing these inputs at the middleware boundary fixes both paths without changing production environment configuration.

The trusted-local-proxy assumption is essential: Caddy must replace untrusted XFF and reach Puma with a loopback peer. Any local caller is trusted by this policy. Private nonloopback and IPv4-mapped loopback peers conservatively lose XFF. The request tests exercise the application stack, not the live proxy configuration, and the ordering assertion covers RemoteIp and Rails' request logger rather than every possible upstream consumer.

Obligation: CA-1.
