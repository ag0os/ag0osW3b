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

Moved to `docs/decisions/locale.md`.

### D-9. Back where the visitor was; home when that is unknown or foreign

Moved to `docs/decisions/locale.md`.

### D-10. `Accept-Language` is read in the order sent

Moved to `docs/decisions/locale.md`.

### D-11. Each button names its language in that language

Moved to `docs/decisions/locale.md`.

## The home page

### D-12. Old shell URLs land on the plain home page

Moved to `docs/decisions/home_page.md`.

## Retiring the shell's settings

### D-13. A data migration, in SQL, for exactly three keys, with a no-op rollback

Moved to `docs/decisions/remove_shell_settings.md`.

## The consulting page

### D-14. Seeded sections and a small page template

Moved to `docs/decisions/consulting_page.md`.

## Launch

### D-15. Writing hides itself by asking whether anything is published

Moved to `docs/decisions/writing.md`.

### D-16. The feed link stays in the head when nothing is published (provisional)

Moved to `docs/decisions/writing.md`.

### D-26. The feed answers at `.atom` and `.xml`; every other format is a 404

In `docs/decisions/writing.md`.

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

### D-22. Mutation runs every subject, on the change and on its base, and fails on what is new

**Decision.** `bin/mutant-floor` runs mutant on every subject in `config/mutant.yml` twice: on the change, and on the merge base exported with `git archive`. There is no `--since` and no list of paths that widen the run.
- **How the base runs.** The tip's `config/mutant.yml`, `test/mutant/boot.rb` and `test/mutant/hooks.rb` are copied into the export, which runs from its own directory on the tip's bundle. `boot.rb` fixes Minitest's seed for both runs.
- **What the base's own config selects.** That comes from `mutant environment subject list`, run in the export with the base's own config before the tip's is copied over.
- **How survivors are counted.** They are counted per key: the subject, plus the diff's `-` and `+` lines. A key fails when the tip has more survivors than the base, and the base counts only the subjects its own config selected.
- **Carried survivors.** Before counting, a survivor in a subject that ran only at the tip takes up a base survivor with the same lines from a subject that ran only at the base, one for one, and is reported as carried.
- **Subjects missing at the tip.** A subject the base selected that doesn't run at the tip is looked up in the tip's app (`MutantFloor.defined_as`): first through its original class's ancestors, then in every loaded class and module, for a method of that name and kind whose source is under `app/`, `lib/` or `config/`. It passes if tip subjects run every one it finds (moved). If it finds some that no subject runs, it fails, naming where the method lives (left). If it finds none, the method was removed or renamed: it passes when its class or module, by constant, has a subject that ran at the tip and not at the base, and that no other vanished subject has taken (renamed in place: one for one, same method name first, then in name order), and fails otherwise as removed or renamed out of mutation's reach. Either failure passes only when a `config` entry names the subject.
- **The report.** `MutantFloor.report` turns the verdict into the step's lines, and `MutantFloor.judge` assembles the comparison from the two runs, mutant's subject list at the base, the tip's config, the added entries and the `change:` entries the static checks accepted, so that both are under test. The paths the lookup searches and the harness files the static check compares are constants in `test/mutant/floor.rb`, not in the bin, so a test reads them too.

The run also fails on:
- a neutral mutation that fails, aborts or times out;
- a subject with fewer results than mutations;
- an expression that matches no tip subject;
- a change to `config/mutant.yml` outside its subjects and ignores, or to `test/mutant/boot.rb` or `test/mutant/hooks.rb`, unless the change adds a `config` entry to `test/mutant/accepted.yml` that names it (`change: config`, `change: harness`) with a reason, which the report prints with the files it accepts;
- an `accepted.yml` whose lists at the base are not the start of its lists on the change, or an added entry of the wrong shape or without a reason.

A new survivor that a change lists, with a reason, under `equivalents` in that file passes, and is reported. A failure of the base run is reported as a gap at the base, with its first error line, and the base's commands are logged; when the change touched the bundle or the harness, the gap says to land the code change separately. `test/mutant/baseline.yml` records main's survivors as of its newest anchor: the gate doesn't read it, but changing it still needs an anchor with a reason.

**Derivation.**
- *Why every subject.* The first version scoped the run with `--since` and widened it when a list of paths changed. Review found that both missed changes:
  - removing a test's `cover` line didn't widen the run, because the file no longer declared it;
  - a default scope on `Post` made a new survivor in `HomeController#show` without touching it.

  Models, views, routes, locales and test helpers all change what kills a mutation, and no list of paths keeps up. A scoped run needed someone to read the diff, and the grant removes that reader. The base run is a whole run too, with the base's own tests, so a lost `cover` line shows as a survivor the base doesn't have.
- *Why compare with the base rather than a list.* The first version of this gate matched survivors against a committed baseline and failed on an entry a test now killed, so that a killed entry couldn't be spent later as a credit. But that made a change that only adds a killing test re-record an owned file. It also made every rename or move of a mutated method re-record one. Both push a good change out of G1. On 2026-10-17 the owner ruled that a finding is new when it is present at the change's tip and absent at its merge base. The base is main's code, which the change can't alter, so there is no credit to spend: a test killed by a later change brings its survivor back above the base's count.
- *Why the tip's harness, bundle and seed.* The harness must be copied in, not referenced: `boot.rb` loads the app next to it with `require_relative`, and the config's `includes` and `requires` resolve from the working directory. Pointing the base at the tip's harness would mutate the tip twice and find nothing new. On the base's own lockfile, a mutant or Minitest bump would make the two runs disagree. A random seed would let order-dependent tests kill a mutation in one run and not the other. A change that makes the base unable to boot under the tip's gems is the base's gap, reported as such, not a finding against the change.
- *Why count, and why the base's own selection.* With a set, a change that copied an untested line inside a subject that already had that survivor would pass. A method newly added to `config/mutant.yml` runs at the base too, under the tip's config, mostly with no test that covers it, so nearly all of its mutations survive there. Counting that would let the change pass however weak its new tests are. So the base counts only what the base's own config selected.
- *Why carry across a rename or move.* A rename, or a move into a concern, changes a subject's name and nothing else. Without carrying, each of its survivors on main would count as new, so the cleanup the duplication floor is meant to pay for would fail with no fix, short of an equivalents entry per survivor. Carrying matches by the lines alone, one for one, and only from a subject that stopped running to one that started. So it accepts no more survivors than main has, and a test deleted in the same change still fails.
- *Why "gone" versus "left".* mutant selects nothing for an expression that matches no subject and exits 0, and a namespace expression keeps matching a class's other methods. Moving `SiteController#switch_locale` into a concern took it out of mutation that way, with a planted survivor. Failing every subject that stops running would also fail a method renamed in its own class, and no edit could fix that. Asking the tip's app whether the method is still defined, and where, tells the two apart. The first version asked only the original class, so review found two moves that passed as "no longer defined": the locale methods extracted into a `LocaleNegotiator` service under `app/services`, with the one test that killed `downcase` weakened in the same change, and `accept_language` patched back into `SiteController` from a `config/initializers` file. So the lookup also searches every loaded class and module for a method of that name and kind, and counts source under `config/` too. An inherited Rails or `Object` method still counts as not defined, and so does a rename, whose new name the old one can't find. The search can't tell a moved method from an unrelated one with the same name, such as two controllers' `show`. Then deleting one of them fails as left, and a `config` entry naming the subject is the way through. That trade fails closed.
- *Why a removed subject fails closed.* The search made a moved method fail only when it kept its name. Review then extracted `SiteController#preferred_locale` and `#accept_language` into `LocaleNegotiator#locale` and `#language_tags`, inlined `MarkdownRenderer.unmark` into `MarkdownHelper#unmarked`, and weakened the one test that killed `downcase`; all three passed as "no longer defined". Extracting into a service object usually renames the method, so a gate that passes a vanished name passes the commonest way out. Matching bodies was suggested and not built: the copy in that very case had already changed `MARK` to `MarkdownRenderer::MARK`, and any small edit evades it. So the gate stops guessing. A vanished subject passes when its own class gained a subject in the same change, which is a rename the class's expression still reaches, and otherwise needs a `subjects` entry with the reason. That mirrors `test/ci/test_removals.yml`: removing what was checked is a decision, and its reason goes in an owned file. It replaces the first version's "a deleted method passes". The cost is an entry for every deleted method, and the hole is a deletion paired with an unrelated method added to the same class, which passes as a rename.
- *Why a rename pairs one for one.* The first version let any new subject in a class stand for every subject that vanished from it. Review then made the same extraction leave the usual private delegator behind, `SiteController#locale`, and both extracted methods passed as renamed beside it, with the `downcase` kill lost. Each new subject now stands for one vanished subject: one with the same method name first, so a switch between an instance and a singleton method pairs with itself, then the rest in name order, so the result doesn't depend on the order mutant lists them. Comparing mutation counts as size evidence was suggested and not built: it is a threshold to tune, and a delegator can be padded. The cost is that an honest merge of two methods into one needs a `subjects:` entry for the one it drops, which is the price of a change that drops a subject.
- *What this leaves to review.* Mutation selects the explicit list in `config/mutant.yml`. An extraction that keeps a one-line delegate under the old method's name, so that no subject vanishes, moves the logic into a class the list doesn't select, and the gate can't see it: the delegate still runs, and its few mutations are killed. Only the review of the pull request sees that. Making the selection complete by default, with every constant under `app/` and `lib/` either selected or listed as excluded in an owned file, would close it; that is the owner's to choose, and not built.
- *Why the config and the harness need a reason.* Both runs read the tip's `config/mutant.yml` and the tip's `boot.rb` and `hooks.rb`. So a narrowed expression, an added `ignore`, lighter operators, or a timeout that turns every survivor into a kill weakens both runs alike, and the comparison can't see it. Review showed the same of the harness: one added line in `boot.rb`, skipping the integration tests, took both runs from 67 survivors to 306, and the gate passed. The selection is checked against the base's own config, so removing an expression is judged as the methods it selected there: one still defined fails as deselected, and one deleted fails as removed, unless an entry names it. Anything outside the subjects and ignores is compared whole, and the two harness files byte for byte. An accepted change prints the files it touches and its entry's reason, since an acceptance nobody sees in the run is one the owner can't weigh; this pull request's own seed change is the first.
- *Why an entry names what it excuses.* The first version let any one `config` entry excuse every deselection and every config change in its pull request, so a reason about one subject covered another it never named. Each entry now names its subjects, or `change: config` or `change: harness`. A subject that left the selection, and not only one the config stopped selecting, can be excused the same way, which allows an honest switch from a `def` to an `attr_reader` or a `delegate`.
- *Why only added entries count, and why append-only.* An entry that kept counting after its own change merged would be a credit, which a later change could spend on a second copy of the survivor. `test/ci/test_removals.yml` works the same way. The first version found added entries by comparing whole entries, so rewording an old one counted as adding it, and its reason excused a new narrowing. The base's lists must now be the start of the change's, and only what follows counts. Matching an equivalent ignores trailing whitespace, because YAML's `|` keeps a final newline that `|-` drops, and a malformed entry fails with a message rather than an exception.
- *Why a timed-out neutral fails.* mutant counts a timeout as a kill, the neutral mutation included. A slow test covering a subject would otherwise turn all of its mutations into tolerated timeouts. A survivor that only times out is still tolerated, and reported, because a slower runner can do that to it.
- *Why the session result.* mutant's exit status can't separate survivors from a crash, so the gate reads the session result, and an incomplete subject must fail rather than pass the mutations it lacks.
- *Why this key, and what it costs.* mutant identifies a mutation by file, line and a hash of the mutated method, and editing anything above it changes all three. The removed and added lines change only when the mutated code does. The known cost: an edit to a line that has a survivor re-keys it, even a cosmetic one such as renaming a block variable, and the survivor counts as new. The remedy is to kill it, or an `equivalents` entry. Pairing survivors on the mutation's own token edit was considered and not built.
- *Why the cost.* A full run takes about 35 to 45 seconds on 14 local cores, and 2.5 to 3.7 minutes on GitHub's 4, so the second run roughly doubles the step. The owner accepted that cost in choosing this design. A cache of main's run could win it back later, but it needs a new action on CI-2's allowlist and a key that includes `Gemfile.lock`.

Obligations: CI-4, CI-5.

### D-23. Duplication gates on what the change introduces; exhale runs from its own bundle

**Decision.** `exhale dry --introduced-only` against the base, and no `contract/` directory yet. The five copies on main stay warnings: the admin post and section forms and their `create` actions, and the section lists on the About and Work pages. Exhale is installed from `tools/Gemfile` and its own lockfile. `tools/boot.rb`, which `bin/exhale` and `bin/change-guards` load, installs that bundle when it is missing (`bin/setup` calls `bin/exhale` for that). It points Bundler there, naming the lockfile too, with `BUNDLE_FROZEN=true`. It starts the process again outside the app's bundle when it finds itself inside it. The request was to add exhale to the app's Gemfile; this departs from it.

**Derivation.**
- *Why `--introduced-only`.* A `parallel` clause accepting the five copies was tried, and it made main sweep clean. But a clause names whole units, so it would also accept any new copy between the same two forms. `--introduced-only` judges each copied fragment pair, so a new pair fails even between files that already share code. Its baseline is the merge base, not a file. That is honest, because main is reached only through this check. A deliberate new copy still needs a written reason: a `parallel` clause, which exhale marks "NEW CLAUSE, review its reason". `exhale complexity` already compares each method with its own score at the base.
- *Why its own bundle.* Exhale pins `bigdecimal ~> 3.1` on purpose, for fingerprints that come out identical on every platform. In the app's bundle that moved production's `bigdecimal` from 4.1.2 back to 3.3.1. It would have held it there, past any fix released only in 4.x, which `bundler-audit` would then fail on with no way out. Exhale is static analysis and never loads the app, so nothing needs it in the app's bundle. Naming the lockfile matters. Bundler 4 hands a bundled process's children `BUNDLE_LOCKFILE` and a `RUBYOPT` that loads the bundle. A first version installed the tools bundle from `bin/setup` under `bin/ci`, and `bundle check` wrote exhale's resolution over the app's `Gemfile.lock`. CI-6's test now starts `bin/exhale` with that inherited environment. The children also get `BUNDLER_SETUP`, which RubyGems requires at startup whenever it is set. The first GitHub run (39000455112) had no tools gems installed, and `bundle check` and `bundle install` both loaded the tools bundle before doing anything, then stopped on `GemNotFound`. Locally the gems were already there, so nothing showed. Clearing `BUNDLER_SETUP` alone was not enough. With setup-ruby's `vendor/bundle` path, the app's bundle also hands its children `GEM_HOME` set to that path and an empty `GEM_PATH`. The tools' `bundle` then can't see the Bundler setup-ruby installed, and stops on `CorruptBundlerInstallError`. So `tools/boot.rb` now starts again outside the app's bundle first, in Bundler's unbundled environment, which restores the variables from before the app's bundle and drops the rest. Only then does it check and install. A CI-6 test installs a stand-in tools bundle from a local cache, started from a stand-in app bundle with a bundle path. It fails on both causes. Frozen, a `tools/Gemfile` edited without its lockfile fails instead of quietly resolving a different exhale.

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
