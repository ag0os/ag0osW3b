# Fonts

Self-hosted webfaces, one pair per theme preset. Fetch them with:

```bash
bin/fetch-fonts
```

Then commit the `.woff2` files. They are open licensed and redistributable, and
self-hosting means the site makes no third-party request at runtime.

| Preset | Display | Body | Mono | License |
|---|---|---|---|---|
| workshop | Bricolage Grotesque | Alegreya | Sometype Mono | OFL 1.1 |
| console | Archivo | Archivo | Azeret Mono | OFL 1.1 |
| spec | Schibsted Grotesk | Schibsted Grotesk | Geist Mono | OFL 1.1 |
| terminal | Martian Mono | Sometype Mono | Sometype Mono | OFL 1.1 |

Workshop carries a fourth face: **Shantell Sans** (OFL 1.1), the hand that
writes its margin notes. It is fetched with its `BNCE` and `INFM` axes intact,
because `--hand-variation` sets informality on it; requesting weight alone
returns a face pinned to the axis defaults and the marginalia comes out set
rather than written.

All are variable fonts. Only the latin subset is fetched.

**The site works without them.** Every `--font-*` token in `themes.css` carries a
full system-stack fallback, and `fonts.css` declarations for missing files are
simply ignored by the browser. Running `bin/fetch-fonts` is an upgrade, not a
prerequisite, and a missing file degrades to the system stack rather than
breaking a build: `assets:precompile` leaves unresolvable `url()` references
alone rather than raising.
