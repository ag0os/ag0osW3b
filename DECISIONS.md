# Decisions

Why things are the way they are, with the derivation behind each value. Version control says what changed; a record here says why. Obligations are numbered as in `PRODUCT.md` ("Contract: the Markdown renderer").

## The Markdown renderer

### D-1. The mark is applied to the rendered Markdown, not to the source

**Decision.** Commonmarker renders first; `==phrase==` is found afterwards, in the text of the result.

**Derivation.** Whether `==` is emphasis depends on context the source does not show without parsing it: inside a code span, a fenced block or an indented block it is code (`a == b`, a test assertion). The Markdown parser already knows which text is code. Finding marks in the rendered text, with code excluded, inherits that knowledge instead of re-deriving it with a second, weaker parser. Rewriting the source to `<mark>` before parsing would also need raw HTML enabled (MR-4 forbids it) or a private syntax extension Commonmarker does not offer. Obligations: MR-11, MR-18.

### D-2. Marking never reparses text

**Decision.** Marking moves the existing nodes into the `<mark>` and creates new text nodes for the pieces of split text. The only markup it adds is the `<mark>` element.

**Derivation.** Reading text out of an HTML tree decodes it: `&lt;i&gt;` comes back as `<i>`. Putting it back as markup would turn an author's (or, once the shell answers from the site, a visitor's) escaped text into live HTML, which MR-4 exists to prevent. A text node is escaped when the tree is serialised, so text that stays a text node stays text, and a moved node keeps the attributes the sanitiser left it. `mark` has no tree, so it escapes the whole string before adding marks. Obligations: MR-13, MR-15, MR-17.

### D-3. Commonmarker's own highlighter is off; Rouge runs with classes

**Decision.** Commonmarker is called with `syntax_highlighter: nil`; code blocks are re-highlighted with Rouge's HTML formatter, which emits class names.

**Derivation.** Commonmarker's built-in highlighter (syntect) writes colours as inline `style` attributes from one fixed theme. The site ships four presets in two modes, eight surfaces, and every colour has to come from tokens (`DESIGN.md`, "Don't hardcode"). A class-based formatter lets the `.highlight` rules read `--hl-*` tokens, so seven rules serve eight surfaces, and keeps inline styles out of the output entirely. Rouge emits the short Pygments class names the stylesheet already targets. Obligation: MR-8.

### D-4. The delimiter needs a character other than ASCII whitespace or `=` on its inner side

**Decision.** `==` opens a mark only when followed by a character other than ASCII whitespace (a space, tab or line break) or `=`, and closes one only when preceded by one (the lookarounds in `MARK`).

**Derivation.** Two real inputs contain `==` and are not marks. A line of `====` is a setext heading rule, or a divider someone typed; without the rule it pairs with itself. An operator in prose (`x == y`, `a ==  == b`) has spaces around it. Requiring a non-space inside both ends excludes both and costs nothing a real mark needs, since nobody marks a phrase that starts or ends with a space. This is the same flanking idea CommonMark uses for `*`. A run of `=` of any length is a rule or a divider: with only a non-space rule, `=====` pairs its outer four signs around the fifth. The whitespace is ASCII only, so a non-breaking space or an em space counts as content. That is the shipped behaviour, pinned as it is (2026-10-09). The two cases the rule exists for are typed with ordinary spaces, and a non-breaking space next to `==` is something an author put there on purpose. MR-21 treats Unicode spaces as blank for a different question: whether there is anything to render at all. Obligation: MR-12.

### D-5. Tables get a focusable, labelled scroll region

**Decision.** Each table is wrapped in a `div.table-scroll` with `tabindex="0"`, `role="region"` and an `aria-label`.

**Derivation.** Cells wrap, so column count alone is safe on a phone. What bursts a column is one unbreakable token (an env var name, a long identifier), and then the whole page scrolls sideways. Scrolling the table inside its own box fixes that. A box that scrolls must be reachable from the keyboard, or a keyboard user cannot see the hidden columns (WCAG 2.1.1), so it takes a tab stop; a tab stop with the region role needs an accessible name. Obligation: MR-7.

### D-6. Raw HTML is omitted, and unsafe URLs are emptied

**Decision.** Commonmarker runs with `unsafe: false` and `tagfilter: true`.

**Derivation.** The helpers return trusted markup that views insert without escaping, so the renderer is the sanitiser. Omitting raw HTML entirely is simpler and stricter than an allow-list, and the site has no content that needs raw HTML: the mark, the one thing an author would have reached for `<mark>` to do, has its own syntax. Commonmarker's safe mode also empties `javascript:`, `vbscript:` and `file:` URLs, and every `data:` URL except those whose media type starts with `image/png`, `image/gif`, `image/jpeg` or `image/webp`, ignoring case, on links and images alike. The match is a prefix, so `data:image/pngx` and `data:image/png+xml` are kept as well. Keeping what Commonmarker keeps, with no URL filter of our own, was the owner's decision (2026-10-08). A raster image cannot run script. The prefix is harmless because whatever follows it, the media type is still an `image/` type that names no format a browser executes: the browser decodes it as an image or shows nothing. The `data:` types that can carry script, `image/svg+xml` and `text/html`, don't match and stay emptied. Also, browsers block top-level navigation to `data:`, an inline image makes no network request and so can track less than the `https:` images already allowed, and stripping them would take a URL filter the site otherwise doesn't need. `tagfilter` is kept as a second line in case `unsafe` is ever turned on. Obligations: MR-4, MR-5.

### D-7. A mark may span inline formatting (change request)

**Decision.** A mark pairs its `==` across inline elements in the same block and wraps them whole, as long as both ends sit in the same element. A pair that would straddle an element edge does not form, and its equals signs stay visible.

**Derivation.**
- *Why span at all.* A phrase worth marking often contains a stressed word, a link or a code term. Today `==a *b* c==` shows its equals signs, because the mark is found one text node at a time and the emphasis splits the phrase into two nodes. The tree-based approach (D-1) is kept; only the unit of search widens from a text node to an element's inline content.
- *Why formatting is kept inside.* The mark is emphasis layered on the text, not a replacement for its formatting. Dropping the `<em>` or the link would lose the author's other intent.
- *Why both ends in the same element.* `<mark>` must nest properly. A pair straddling an edge could be rescued by splitting it into several marks (one outside the link, one inside), but every preset draws a mark as one instrument (a swipe, a strip of tape), and a split pair draws as two with a seam. Such a pair is almost always a typo in the source. Leaving the equals signs visible shows the author the mistake in the preview, where silently reshaping it would not.
- *Why code is wholly inside or not at all.* A code span is atomic: it is never split, so a mark can contain it whole but cannot open or close inside it (D-1).
- *Why pairing is per element.* `<mark>` must nest properly, so a pair can only form between delimiters in the same element. Counting each child as one non-space character keeps the `mark` rule (D-4) unchanged inside an element, so an author who can predict `mark` on the words around an element can predict the paragraph. Omitted raw HTML counts the same way: it is a node in the tree, and ignoring it lets the two halves of `=<i>=` read as one delimiter. The enclosing element pairs first, so an outer mark wins over a pair inside a child; a mark inside a mark would draw as two instruments over each other. This changes one case that works today: `==a *b* ==c==` now marks `a <em>b</em> ==c` instead of only `c`.
- *Why line breaks are included.* A soft line break is inline content and renders as a space. Posts written at a fixed width break lines mid-phrase, and a mark that silently fails at the wrap point is the same bug as the one this request fixes.

Obligations: MR-17 to MR-20.

## The language

### D-8. The language control is a form that PATCHes, not a link

**Decision.** Each footer button is a `button_to`-style form that posts to `/locale` with `_method=patch`; `LocalesController#update` sets the cookie and answers `303 See Other`.

**Derivation.** Choosing a language changes stored state, so it is not a GET. A link such as `/locale?l=es` would also be followed by things that are not the visitor: Turbo prefetches a link on hover, and crawlers follow every link, so hovering over "Español" could switch the site. A form needs no JavaScript, which `ASK.md` §4.9 requires of the whole surface. The redirect is `303` rather than Rails' default `302` because the follow-up must be a GET whatever method the browser sent, and `303` is the status that says so; Turbo expects it after a form submission. Obligations: LC-6, LC-7, LC-10.

### D-9. Back where the visitor was; home when that is unknown or foreign

**Decision.** The redirect goes to the `Referer` when it is on this host, else to the home page (`redirect_back_or_to root_path`). An unknown code changes nothing and redirects the same way.

**Derivation.** The visitor pressed the button to read the page they were on in another language, so that page is the destination. The `Referer` is supplied by the request, so following it to another host would make `/locale` an open redirect; Rails refuses other hosts in `redirect_back_or_to` and falls back. An unknown code can only come from a stale page or a hand-written request; an error page punishes the first and tells the second nothing, so the request is treated as a no-op. Only the exact codes the buttons send are accepted: `ES` is not one of them, and accepting it would mean the control normalises codes that nothing it renders ever sends. Obligations: LC-7, LC-8, LC-9.

### D-10. `Accept-Language` is read in the order sent

**Decision.** The first entry whose language is a site language wins; `q` weights are not used to re-sort. This is the behaviour the shell shipped, pinned as it is.

**Derivation.** Browsers emit entries already in descending preference, so re-sorting changes nothing for a real browser and only matters for a hand-written header. With two site languages the first match is also the only decision there is to make. Obligation: LC-2.

### D-11. Each button names its language in that language

**Decision.** The buttons read "English" and "Español" on every page, each with `lang`, and the current one is marked with `aria-pressed`.

**Derivation.** The control exists for the visitor who landed in the wrong language (`ASK.md` §4.8: Spanish browsers already get Spanish), so the label they need is the one in the language they read, not a translation into the one they cannot. `lang` on the button lets a screen reader switch voice for the one word. The pressed state is the mode toggle's pattern: one stable name per button plus a state, so the current language is stated in text to assistive technology and never by hue alone. Obligations: LC-10.

## The home page

### D-12. Old shell URLs land on the plain home page

**Decision.** `/?line=...` renders the home page as if the parameter were absent. `/shell` is removed with its route and answers 404.

**Derivation.** `/?line=` links were the shell's shareable form and may be in messages and bookmarks; ignoring the parameter costs nothing and lands the visitor on a working page. `/shell` was only ever a form target that redirected or answered a stream, so nothing links to it directly, and a route kept only to redirect would be shell code that outlives the shell. Obligation: HP-5.

## Retiring the shell's settings

### D-13. A data migration, in SQL, for exactly three keys, with a no-op rollback

**Decision.** `RemoveShellSettings` runs one `DELETE` against `site_settings` for the three keys by name. `down` does nothing.

**Derivation.** Removing the defaults from `SiteSetting::DEFAULTS` is not enough: `all_settings` merges stored rows over the defaults, so a database where the owner ever saved the settings form keeps all three as live fields. Seeds are not run on deploy, so the change has to be a migration. It names the table and not the model because the model is application code that keeps changing after the migration is written. It names the keys rather than a `shell_%` pattern because a pattern is a guess about rows nobody has looked at. Rollback restores nothing because the rows held copy for a component that is gone; raising `IrreversibleMigration` instead would only stop someone rolling back past it for an unrelated reason. Obligations: DM-1 to DM-4.

## The consulting page

### D-14. Seeded sections and a small page template

**Decision (proposed defaults).** Follow the other static pages: a PagesController
action selects visible, ordered consulting Sections, and the view reuses the
section partial. The page heading and dynamic LinkedIn contact sentence live in
the view, as other static page headers and contact links do. The meta description
is derived from the visible intro rather than a second copy.

**Derivation.** The admin already edits and toggles Sections; adding a second
content mechanism would make a small page harder to maintain. LinkedIn must
reflect SiteSetting changes rather than a profile URL captured during seeding.
The owner decided on 2026-10-13 that Consulting is reached from links in the
site's copy rather than the primary nav. This reverses only the nav half of
D5; the page stays as built.
Spanish translation is deferred (D6), so the page copy stays English.
The English content declares its language even under Spanish chrome. Markdown's
existing curly apostrophe is kept rather than changing the renderer's Contract
for a single page. Obligations: CP-1 to CP-5.

## Launch

### D-15. Writing hides itself by asking whether anything is published

**Decision.** The header partial shows the Writing link when `Post.published.exists?`. There is no setting. `/writing` and `/feed` keep their routes and answer with their empty states.

**Derivation.** The owner decided on 2026-10-14 that Writing appears automatically with the first published post. The home page already decides its Writing block from the published posts, so the nav asks the same question with the same scope, and the two cannot disagree. A setting would be a second switch for something the content already says. The routes stay because hiding a link is not the same as withdrawing an address: a shared `/writing` link or a feed reader's poll should land on a working page. Obligations: WR-1 to WR-3, and SC-6, which removes the sample post that would otherwise keep Writing visible.

### D-16. The feed link stays in the head when nothing is published (provisional)

**Decision.** `<link rel="alternate">` for the feed is rendered on every page of the site layout, posts or not.

**Derivation.** Rule WR-1 is about what a visitor sees; the alternate link is read only by feed readers and browser extensions. Keeping it costs nothing, because the empty feed is valid Atom (WR-3), and it lets an early subscriber receive the first post. Hiding it would also be defensible, as consistency with the nav. This is a default the owner has not settled. Obligation: WR-4.

### D-17. Production seeding requires `ADMIN_PASSWORD`, always

**Decision.** In production, `db/seeds.rb` raises before its first write when `ADMIN_PASSWORD` is unset or blank, even if the admin user exists. It never prints the password there. Development and test keep `change-me-please` and print it.

**Derivation.** The repository is public, so its default password is everyone's. Generating a random password instead would have to be printed to be useful, and printing is what PD-2 forbids. Checking only when the admin is about to be created would let a re-seed proceed without the variable, but would make the rule depend on database state the operator cannot see from the deploy screen; one rule with no exceptions is easier to trust. A blank value counts as unset because `has_secure_password` would reject it anyway, after the error message had lost the variable's name. Raising rather than `abort` makes `db:seed` exit nonzero with the message, so a deploy script stops. Obligations: PD-1 to PD-3.

### D-18. Mail links use `agoos.dev`, pinned by booting production

**Decision.** `config.action_mailer.default_url_options = { host: "agoos.dev" }` in `config/environments/production.rb`. Its test runs `bin/rails runner` with `RAILS_ENV=production` and `SECRET_KEY_BASE_DUMMY=1` and builds the password-reset URL with `PasswordsMailer`.

**Derivation.** The host is the domain the owner owns. The protocol needs no setting: with `force_ssl` on, Rails defaults Action Mailer's protocol to `https`, which `.dev` requires (HSTS preloaded). The test builds a real mail URL rather than reading the config line, so it also fails if the protocol default stops applying or an initializer overrides the host. Booting takes a few seconds and opens no database. The dummy secret is what `assets:precompile` uses for the same reason, so the test needs no master key. Obligation: PD-4.

### D-19. www redirects to the apex from the first route, in every environment

**Decision.** The first block in `config/routes.rb` is `constraints host: "www.agoos.dev"` around `match "(*path)", via: :all`, redirecting to `"https://agoos.dev#{request.fullpath}"`. `redirect` answers 301 by default.

**Derivation.** The owner chose the app over Caddy on 2026-10-16, after finding no Hatchbox setting for it, and Hatchbox documents this pattern. Being first means no other route can answer for www. The host is matched exactly, and the target is written out rather than derived by stripping `www.` from the request, so the redirect can only ever point at the domain the owner owns. `request.fullpath` carries the path and the query string as they arrived. `via: :all` covers every method because "any request" includes a form post or a feed reader's `HEAD`. A 301 lets a browser repeat a `POST` as a `GET`, which a 308 would not; nothing on the site is posted to from www, and the owner asked for 301, so 301 stands. The constraint applies in every environment: nothing reaches `www.agoos.dev` locally, so it changes nothing in development, and in test it lets `test/contract/canonical_host_contract_test.rb` run against the real route table. A production-only route could only be tested by booting production. `force_ssl` does not matter here: with `assume_ssl` on, Rails treats every request as https and never redirects one itself. Caddy upgrades http before the app sees it, so a visitor to `http://www.agoos.dev` takes Caddy's hop to https and then this one to the apex. Obligation: PD-5.

## Continuous integration

### D-20. One job that runs `bin/ci`, and the protection it assumes

**Decision.** `.github/workflows/ci.yml` has a single job, `ci`, which installs libvips, checks out the full history and runs `bin/ci`. Rails' generated workflow had five jobs, each running some of the checks. The job carries no `if:` and no `continue-on-error`; the only conditions are `if: failure()` on the two uploads.

**Derivation.** A merge grant needs one required check, and that check has to be the whole gate. Five jobs listed the steps a second time, and two lists drift: the generated jobs never ran the seeds, and `bin/ci` never ran the system tests. With one job, running `bin/ci` locally gives the same verdict as the check. The cost is that the jobs no longer run in parallel. Chrome comes from the runner image, as it did for the generated system-test job. GitHub counts a skipped job as a passing required check, and a job that may continue on error is green whatever `bin/ci` returns. That is why CI-2's test refuses both, and allows a condition only on an upload.

**What this CI assumes of branch protection on main** (set outside the repository, by the owner):
- the `ci` check is required;
- branches must be up to date before merging, so the check ran on what will land;
- review from code owners is required (CI-8);
- the settings and the account question are settled with the owner at G1.

Without the second, a green check can describe a combination main has since moved away from. Without the third, a pull request can edit its own gate. Obligations: CI-1, CI-2, CI-8.

### D-21. On a push to main, the floors compare with the previous main: an alarm, not a gate

**Decision.** `CI_BASE` is `origin/<target>` on a pull request and `github.event.before` on a push to main.

**Derivation.** The floors judge a change, and a push to main compared with `origin/main` is a change of nothing, so they would pass without checking anything. Comparing with the commit main pointed at before the push checks the merged result. But merging to main deploys it: Hatchbox deploys main within about a minute of a push, and this run takes several. So the push run finishes after production already has the code. It is an alarm that something got through, not a gate. The gate is the pull request's run on a branch that is up to date with main (D-20). Obligation: CI-3.

### D-22. Mutation runs every subject, every time, and the baseline must be exact

**Decision.** `bin/mutant-floor` runs mutant on every subject in `config/mutant.yml`; there is no `--since` and no list of paths that widen the run. Survivors are matched against `test/mutant/baseline.yml` by subject and the diff's `-` and `+` lines, each entry accepting one survivor. The run fails on:
- a survivor the baseline doesn't list;
- a neutral mutation that fails;
- a subject with fewer results than mutations;
- an expression in `config/mutant.yml`, or a baseline subject, that matches no subject;
- a subject the baseline records as having run that doesn't run;
- an entry whose mutation a test now kills, or that mutant no longer makes.

It tolerates, and reports, an entry killed only by a timeout.

**Derivation.**
- *Why every subject.* The first version scoped the run with `--since` and widened it when a list of paths changed. Review found that both missed changes. Removing a test's `cover` line didn't widen the run, because the file no longer declared it. A default scope on `Post` made a new survivor in `HomeController#show` without touching it. Models, views, routes, locales and test helpers all change what kills a mutation, and no list of paths keeps up. A full run takes about 35 seconds on 14 local cores, and an estimated 2 to 2.5 minutes on GitHub's 4. The owner settles this cost in the pull request. A scoped run needed someone to read the diff, and the grant removes that reader.
- *Why matching must be exact.* mutant selects nothing for an expression that matches no subject, and exits 0, so a renamed subject would leave mutation silently. Checking expressions isn't enough on its own. Moving `SiteController#switch_locale` into a concern took it out of mutation, with a planted survivor, while `SiteController*` still matched the class's other methods. So `--record` writes every subject that ran, and one that stops running fails. A new subject isn't held to the list; it is judged like any other and recorded at the next re-anchor. Letting coverage shrink needs a new anchor and its reason, in an owned file. An entry left in the baseline after a test kills its mutation is a credit: a later change that deletes the test brings the survivor back and spends it. So a killed entry fails, and the change that kills it re-records. A timeout is the exception, because a slower runner can turn a survivor into one, and mutant counts it as a kill; `criteria_result` tells the two apart. mutant's exit status can't separate survivors from a crash, so the floor reads the session result, and an incomplete subject must fail rather than pass the mutations it lacks.
- *Why this key.* mutant identifies a mutation by file, line and a hash of the mutated method, and editing anything above it changes all three. The removed and added lines change only when the mutated code does. The baseline lists every survivor rather than a count, because a count lets a new survivor hide behind a killed one.

Obligations: CI-4, CI-5.

### D-23. Duplication gates on what the change introduces; exhale runs from its own bundle

**Decision.** `exhale dry --introduced-only` against the base, and no `contract/` directory yet. The five copies on main stay warnings: the admin post and section forms and their `create` actions, and the section lists on the About and Work pages. Exhale is installed from `tools/Gemfile` and its own lockfile. `tools/boot.rb`, which `bin/exhale` and `bin/change-guards` load, installs that bundle when it is missing (`bin/setup` calls `bin/exhale` for that). It points Bundler there, naming the lockfile too, with `BUNDLE_FROZEN=true`. It starts the process again outside the app's bundle when it finds itself inside it. The request was to add exhale to the app's Gemfile; this departs from it.

**Derivation.**
- *Why `--introduced-only`.* A `parallel` clause accepting the five copies was tried, and it made main sweep clean. But a clause names whole units, so it would also accept any new copy between the same two forms. `--introduced-only` judges each copied fragment pair, so a new pair fails even between files that already share code. Its baseline is the merge base, not a file. That is honest, because main is reached only through this check. A deliberate new copy still needs a written reason: a `parallel` clause, which exhale marks "NEW CLAUSE, review its reason". `exhale complexity` already compares each method with its own score at the base.
- *Why its own bundle.* Exhale pins `bigdecimal ~> 3.1` on purpose, for fingerprints that come out identical on every platform. In the app's bundle that moved production's `bigdecimal` from 4.1.2 back to 3.3.1. It would have held it there, past any fix released only in 4.x, which `bundler-audit` would then fail on with no way out. Exhale is static analysis and never loads the app, so nothing needs it in the app's bundle. Naming the lockfile matters. Bundler 4 hands a bundled process's children `BUNDLE_LOCKFILE` and a `RUBYOPT` that loads the bundle. A first version installed the tools bundle from `bin/setup` under `bin/ci`, and `bundle check` wrote exhale's resolution over the app's `Gemfile.lock`. CI-6's test now starts `bin/exhale` with that inherited environment. Frozen, a `tools/Gemfile` edited without its lockfile fails instead of quietly resolving a different exhale.

Obligation: CI-6.

### D-24. Guards for what switches a check off from inside, and owners for the gate

**Decision.** `bin/change-guards` runs in exhale's bundle and fails a change in two cases.
- **Unlisted files.** A Ruby or HTML ERB file under `app/` or `lib/` that exhale doesn't read, where at the base exhale read it or it didn't exist. The guard asks `Exhale::SourceFiles.list` about the working tree, and about the base's `app/` and `lib/` exported from git.
- **Directives.** Any file holds more RuboCop disable or todo directives, or more `mutant:disable` comments, than at the base. The mutant pattern is mutant's own `DISABLE_REGEXP`, copied; a test compares the two. It is applied with every `#` read as a space, as mutant applies it to a comment's text after the `#`.

`.github/CODEOWNERS` names the owner on the paths that decide the gate, including every file a gate tool reads without being told to.

**Derivation.**
- *Unlisted files: ask exhale, don't imitate it.* The first version looked for a generator's header with exhale's pattern, copied. Review found that exhale also drops a file whose name or directory looks like a test, even under `app/`. `app/models/ab_test.rb` is an ordinary model name, and the `spec` preset invites a `spec/` directory. Exhale also drops dot segments and symlinks. Asking `Exhale::SourceFiles.list` covers every reason it has, now and in a later version, and needs no copied pattern. The API is a public `module_function`, pinned by the frozen lockfile at 0.2.0. CI-7 runs it on the cases this guard relies on, so an upgrade that changes it fails the build. A file that exhale didn't read at the base either isn't new, so the guard judges only the change.
- *Directives.* An inline directive switches RuboCop off with no change to `.rubocop.yml`. mutant drops any subject whose comments match its pattern, silently, and a namespace expression still matches the class's other methods, so the floor's unmatched-subject check doesn't fire. Counting per file, rather than reading added lines, lets a directive move within a file without failing. Reading `#` as a space catches `#mutant:disable` with no space after the `#`, which mutant honours.
- *The owners.* GitHub runs a pull request's own copy of the workflow and of everything it calls. A change can edit `bin/ci`, the baseline, `config/mutant.yml` or the Contract test that pins them, and pass its own check. Code-owner review moves those edits to the owner. The app's `Gemfile.lock` is the one dependency file left out: on 2026-10-17 the owner allowed Dependabot patch and minor bumps that touch only the lockfile to merge under G1 once `bin/ci` is green, and under required code-owner review an owned lockfile could never merge that way. The `Gemfile` stays owned, so adding or loosening a dependency still needs the owner, and every lockfile change still runs the full suite, bundler-audit and the mutation floor.
- *Files read without being told to.* A sweep of the gate's tools found these:
  - Brakeman loads `config/brakeman.yml`, where `:skip_checks` silences it.
  - RuboCop reads a `.rubocop` options file even though `bin/rubocop` forces `--config`. `--only Lint/Syntax` there turned three offenses into none.
  - Bundler reads a committed `.bundle/config`, and with setup-ruby's `vendor/bundle` path a committed gem there could be taken as already installed (not tried).
  - `.gitattributes` can change what `git diff` and `git grep` report (not tried).
  - exhale caches the base's sweep in `tmp/exhale/` under a key a change can compute, so a committed cache file could pass off a new copy as already there.

  All of these are owned. The others fail closed, and review checked them: a nested `.rubocop.yml` (ignored under the forced `--config`), a second mutant config (mutant refuses), and bundler-audit (given its config explicitly).
- *The harness.* The test helper, `test/test_helpers/`, the system test case, the test environment, `config/boot.rb` (which `bin/ci` itself loads), the `Rakefile` and `lib/tasks/` decide what `bin/rails test` runs, so they are owned. Code-owner review doesn't reach every file the gate executes: any loaded file can still interfere, which D-25 and PRODUCT.md state.

Obligations: CI-7, CI-8.

### D-25. Tests pass on their own summary and the base's count

**Decision.** `bin/test-count` runs `bin/rails test` or `bin/rails test:system` and reads its output. The process doing the reading loads nothing from the app. It passes only on:
- a zero exit;
- a final Minitest summary line, with 0 failures and 0 errors;
- exactly the skips that `test/ci/test_removals.yml` lists under `skips` for that suite, each with a reason;
- at least as many runs as the base has tests, less what the change adds to `test/ci/test_removals.yml` for that suite, each entry with a reason.

The base's count comes from exporting the base's tree from git, loading its test files with this bundle, and summing Minitest's `runnable_methods` without running them. The export checks git's own status (`git archive -o`, then `tar`), and a count of 0 fails.

**Derivation.**
- *Why read the output.* Any file the app loads can end the process with `at_exit { exit!(0) }`, and then the tests, the system tests and the seeds all exit 0 without running. Requiring the summary line catches that.
- *Why the base's count.* A deleted test is otherwise invisible: the remaining tests pass.
- *Why load the base, not count text.* Tests made in a loop (`SeededCopyContractTest` makes 16 from two `test` lines) make a text count fall short of the run count by 14. Loading the files counts what Minitest would run, and costs about 2 seconds per suite. Running the base's suite instead would add the system tests' 33 seconds. The base is main's code, which the change can't alter.
- *Why skips must be listed.* Minitest counts a skipped test as a run, so skipping every test in the admin suite left the count, and the check, green. Skipping a failing test is the cheapest way to pass. Both suites run with no skips, so requiring each one to be listed, with a reason, costs nothing today. The list must match the run exactly, so a skip that is fixed comes off it, and a stale entry can't excuse a later skip.
- *Why the export checks git.* `git archive … | tar -x` reports tar's status, and tar exits 0 on empty input. A failed export would have counted an empty tree and made the floor 0 tests. A base with no tests can't be right for this app, so 0 fails too.
- *Why a removals file.* Removing tests is sometimes right. It is a decision, so its reason goes in an owned file (`test/ci/` is in CODEOWNERS), and an entry counts only for the change that adds it.

**What it doesn't stop.** This is a tripwire, not a proof. App code that prints a convincing summary line before exiting would pass it. So would a test that asserts nothing in place of one that did. Those are deliberate deceptions, and the escaped-defect lapse and the M-task reviewer are what answer them.

Obligation: CI-9.
