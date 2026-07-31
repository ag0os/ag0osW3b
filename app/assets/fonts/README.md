# Fonts

Self-hosted webfaces, one pair per theme preset. Fetch them with:

```bash
bin/fetch-fonts
```

Then commit the `.woff2` files. They are open licensed and redistributable, and
self-hosting means the site makes no third-party request at runtime.

| Preset | Display | Body | Mono | License |
|---|---|---|---|---|
| workshop | Alegreya Sans | Alegreya | Sometype Mono | OFL 1.1 |
| console | Archivo | Archivo | Azeret Mono | OFL 1.1 |
| spec | Schibsted Grotesk | Schibsted Grotesk | Geist Mono | OFL 1.1 |
| terminal | Martian Mono | Sometype Mono | Sometype Mono | OFL 1.1 |

All are variable fonts except Alegreya Sans, which ships as two static weights.
Only the latin subset is fetched.

**The site works without them.** Every `--font-*` token in `themes.css` carries a
full system-stack fallback, and `fonts.css` declarations for missing files are
simply ignored by the browser. Running `bin/fetch-fonts` is an upgrade, not a
prerequisite, and a missing file degrades to the system stack rather than
breaking a build: `assets:precompile` leaves unresolvable `url()` references
alone rather than raising.
