# Decisions: the home page

Why the home page works the way it does, with the derivation behind each choice. The obligations are in `docs/contracts/home_page.md`.

### D-12. Old shell URLs land on the plain home page

**Decision.** `/?line=...` renders the home page as if the parameter were absent. `/shell` is removed with its route and answers 404.

**Derivation.** `/?line=` links were the shell's shareable form and may be in messages and bookmarks; ignoring the parameter costs nothing and lands the visitor on a working page. `/shell` was only ever a form target that redirected or answered a stream, so nothing links to it directly, and a route kept only to redirect would be shell code that outlives the shell. Obligation: HP-5.
