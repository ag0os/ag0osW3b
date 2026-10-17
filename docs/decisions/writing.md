# Decisions: writing

Why writing works the way it does, with the derivation behind each choice. The obligations are in `docs/contracts/writing.md`.

### D-15. Writing hides itself by asking whether anything is published

**Decision.** The header partial shows the Writing link when `Post.published.exists?`. There is no setting. `/writing` and `/feed` keep their routes and answer with their empty states.

**Derivation.** The owner decided on 2026-10-14 that Writing appears automatically with the first published post. The home page already decides its Writing block from the published posts, so the nav asks the same question with the same scope, and the two cannot disagree. A setting would be a second switch for something the content already says. The routes stay because hiding a link is not the same as withdrawing an address: a shared `/writing` link or a feed reader's poll should land on a working page. Obligations: WR-1 to WR-3, and SC-6, which removes the sample post that would otherwise keep Writing visible.

### D-16. The feed link stays in the head when nothing is published (provisional)

**Decision.** `<link rel="alternate">` for the feed is rendered on every page of the site layout, posts or not.

**Derivation.** Rule WR-1 is about what a visitor sees; the alternate link is read only by feed readers and browser extensions. Keeping it costs nothing, because the empty feed is valid Atom (WR-3), and it lets an early subscriber receive the first post. Hiding it would also be defensible, as consistency with the nav. This is a default the owner has not settled. Obligation: WR-4.

### D-26. The feed answers at `.atom` and `.xml`; every other format is a 404

**Decision.** The feed route accepts only the `atom` and `xml` formats. The action always renders the Atom template, and the feed names `/feed` as its self link at either address. Any other extension on `/feed` matches no route.

**Derivation.** The route had no format constraint, so `/feed.xml` reached the action, which rendered for the request's format, found no `feed.xml` template and raised. In production that is a 500 (found live on 2026-10-17). `.xml` is worth answering: it is where feed readers and people guess a feed lives, many sites publish theirs there, and an Atom feed is XML, so the document is truthful at that address. Other formats get a 404 because the site has no feed in them. Rendering Atom for `/feed.json` would put a document of the wrong type at an address that names one. A route constraint is how Rails says an address does not exist, so the 404 comes from routing and needs no code in the action. The self link is fixed to `/feed` so that a reader that subscribed at `/feed.xml` gets the same document, byte for byte, and learns the canonical address. The entry ids and the feed id did not depend on the extension, because `atom_feed` strips it, so no existing subscriber sees its entries as new. Serving `.xml` was chosen as the default when the bug was fixed. Answering 404 there as well would also be defensible, and it is a one-word change to the constraint. Obligation: WR-5.
