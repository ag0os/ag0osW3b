---
component: ci
covers:
  - .github/workflows/
  - .github/CODEOWNERS
  - bin/ci
  - bin/mutant-floor
  - bin/mutant-completeness
  - bin/test-count
  - bin/change-guards
  - bin/exhale
  - bin/mutant-weekly
  - config/ci.rb
  - test/mutant/
  - test/ci/
depends_on: []
tests:
  - test/contract/ci_contract_test.rb
---
Coverage: 16 obligations; 16 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: continuous integration

What a green `ci` check on a pull request means. `bin/ci` runs the steps in `config/ci.rb`, and GitHub runs exactly `bin/ci`. A merge with nobody reading the code rests on this check alone, so it runs every check that would otherwise be run by hand. Obligations run in `test/contract/ci_contract_test.rb`. CI-1 to CI-3 and CI-8 are read from the config files. CI-4, CI-5, CI-7 and CI-9 run the mutation gate's, the guards' and the test count's logic on hand-built inputs. CI-10 to CI-12 are the weekly run on main, which reports and never gates: CI-10 is read from its workflow, and CI-11 and CI-12 run its logic on hand-built inputs and `bin/mutant-weekly` on stand-ins. CI-13 to CI-16 exercise selection completeness on source fixtures and its CLI with process stand-ins. Decisions are in `docs/decisions/ci.md` (D-20 to D-25, D-37, D-38). CI-1 to CI-9 moved from `PRODUCT.md` without changing obligation meanings on 2026-11-04.

### CI-1 bin/ci runs every check, and every step even after one fails

Reworded 2026-11-07 by the mutation selection completeness change (D-38).

`bin/ci` runs these steps in order:
- setup, which also installs exhale's own bundle;
- RuboCop, the gem and import-map audits, and Brakeman;
- the Rails tests and the system tests, each through the test count (`bin/test-count`, CI-9), and the seeds;
- two guards: files exhale doesn't read, and disable directives (`bin/change-guards`);
- selection completeness (`bin/mutant-completeness`), the mutation gate (`bin/mutant-floor`), and two floors: duplication (`bin/exhale dry --introduced-only`) and complexity (`bin/exhale complexity`).

Every step runs even after one fails, and the run fails if any step did.

**Reason.** one run should list every failure, and a check left out of `bin/ci` is a check nobody runs before an unattended merge. (D-20)

Kind: functional. Proof: test, the tests named CI-1 in `test/contract/ci_contract_test.rb`.

### CI-2 GitHub runs bin/ci and nothing else, in one job named ci

GitHub runs one job, named `ci`, on every pull request, with no branch or path filter, and on every push to main. Its only command besides installing libvips is `bin/ci`. It checks out the full history, and keeps the system tests' screenshots and mutant's full output when it fails. Neither the job nor any step carries `continue-on-error`. The only conditions are `if: failure()`, and only on the steps that upload those files. Every action it uses is on a short allowlist.

**Reason.** GitHub counts a skipped job as a passing required check. A job that may continue on error is green whatever `bin/ci` says. Branch protection requires a check by name, and a second list of steps in the workflow would drift from `bin/ci`. The floors diff against the base, so they need its history. (D-20)

Kind: functional. Proof: test, the tests named CI-2 in `test/contract/ci_contract_test.rb`.

### CI-3 The gate, the floors and the guards judge only what changed since a base

Reworded 2026-11-07 by the mutation selection completeness change (D-38).

The mutation gate, the floors and the guards, including mutation selection completeness, judge only what changed since a base:
- on a pull request, the merge base with the target branch;
- on a push to main, the commit main pointed at before the push;
- locally, `origin/main` (fetch first), or `$CI_BASE`.

**Reason.** main compared with itself has nothing to check and passes vacuously. (D-21)

Kind: functional. Proof: test, the tests named CI-3 in `test/contract/ci_contract_test.rb`.

### CI-4 The mutation gate fails on what the change adds over its base

The mutation gate runs mutant on every subject in `config/mutant.yml`, on every run, twice: on the change, and on its base exported from git. The base runs from its own directory with the change's `config/mutant.yml`, `test/mutant/boot.rb`, `test/mutant/hooks.rb` and bundle, and both runs use one fixed test seed. A survivor is known by its subject and the lines its mutation removes and adds. The gate fails when:
- the change has more survivors for a key than the base has. A subject that the base's own `config/mutant.yml` didn't select counts none at the base;
- a neutral mutation fails its tests, aborts or times out;
- a subject's results are incomplete (fewer than its mutations);
- an expression in `config/mutant.yml` matches no subject;
- a subject that the base's own config selected doesn't run on the change, while the change still defines a method by that name, of the same kind (instance or singleton), with its source under `app/`, `lib/` or `config/`, and no subject runs it there. That covers its original class through its ancestors, and any other class or module. Typical cases are a method moved into a class, concern or module the config doesn't select, one patched in from an initializer, and one redefined with `define_method`. The step names where the method now lives. If the change's config no longer selects the subject at the base, CI-5 covers it as letting mutation cover less. Otherwise it is "left". In both cases only a `config` entry naming the subject excuses it (CI-5).
- a subject that the base's own config selected doesn't run on the change, and the change no longer defines a method by that name and kind under `app/`, `lib/` or `config/`, unless it was renamed in place: its class or module, by constant, has a subject that runs on the change and didn't run at the base. Each such new subject stands for at most one subject that vanished from its constant: one with the same method name first, then the rest in name order. The step names it as removed or renamed out of mutation's reach, and says to add a `subjects:` entry with the reason if it was deleted. Only a `config` entry naming the subject excuses it (CI-5).

Some outcomes pass, and each one prints a line in the step's output:
- **A method renamed in place.** Nothing under `app/`, `lib/` or `config/` defines a method by its name any more, and its class or module runs a subject on the change that didn't run at the base, which no other vanished subject has taken. The line names the new subject.
- **A method moved to where a subject runs it.**
- **A survivor carried across a rename or move.** A survivor in a subject that runs only on the change takes up a base survivor with the same lines from a subject that ran only at the base, one for one. It carries neither into a subject that ran at both, nor from one that still runs.
- **A mutation killed only by a timeout.** That is one alive at the base that only timed out on the change.

When the base itself fails, the step fails and names the base as the gap, not the change. That covers its export, its boot, its subject list, an incomplete result and a failing neutral. The step prints the first error line, and logs every command it ran on the base to `log/mutant-floor.log`. If the change touches `Gemfile`, `Gemfile.lock`, `tools/` or the harness, the step says instead that the base can't run under this change's bundle or harness, and that the code change should land separately. An expression that matches nothing at the base is expected, because its method is new.

**Reason.**

- A survivor is new when the change has it and the base doesn't, and main is reached only through this check.
- A scoped run misses changes that weaken a kill without touching the subject, such as a removed `cover`, a model scope or a fixture. The base run loads its own tests, so it catches them.
- Counting copies stops a duplicated survivor from hiding behind its twin.
- Judging against the base's own selection stops a newly listed method's untested base from vouching for it.
- A method that is still defined but no longer runs has left the gate without a word, wherever it went. Extracting logic into a service object is the commonest way that happens.
- A method the change no longer defines by its name was deleted, or moved under a new name, and the gate can't tell which: extracting it into a service object usually renames it too. Removing what was checked is a decision, as removing a test is (CI-9), so the gate fails closed and a deletion passes with its reason. Matching the moved method's body instead would be evaded by a small edit. A rename within its own class stays where the class's expression reaches, so it passes. Each new subject stands for one vanished subject only: otherwise the one-line delegator an extraction usually leaves behind would stand for every method that left the class. So an honest merge of two methods into one needs a `subjects:` entry for the one it drops.
- A rename or a move into a concern changes the subject's name and nothing else. Carrying its survivors lets the change pay down the shape of the code without accepting anything new. Because each one is carried one for one, and only from a subject that stopped running to one that started, deleting a test that killed one of them still fails.
- A report line that silently disappears is a regression the next change can make, so the lines are part of the obligation.
- The two runs share a harness, a bundle and a seed, so only the code and the tests differ, and a gem bump changes both alike. When the change's bundle is what the base can't run under, the fix is to split the change, and the message should say so.
- A slow runner can turn a survivor into a timeout, which mutant counts as a kill. (D-22)

Kind: functional. Proof: test, the tests named CI-4 in `test/contract/ci_contract_test.rb`.

### CI-5 What lets mutation accept a survivor or cover less needs a reason in an owned file

Some changes need a reason, recorded in an owned file, `test/mutant/accepted.yml`:
- **An equivalent survivor.** A new survivor that no test can kill passes only with an `equivalents` entry, giving its subject, its change and the reason. Trailing whitespace is ignored on both sides. Each entry accepts one survivor, which is reported.
- **Letting mutation cover less.** Each kind of change needs a `config` entry with the reason, and each entry excuses only what it names. Whatever an entry excuses is reported: the subjects it names, or the change a `change:` entry accepts, with the files it touches and the entry's reason.
  - a subject the base's own config selected that no subject runs on the change (CI-4): one the change still defines, whether `config/mutant.yml` no longer selects it or the method left the selection, and one the change removed without renaming it in place. The entry names it in `subjects`. This also allows an honest switch from a `def` to an `attr_reader` or a `delegate`, and the deletion of a method with its tests.
  - any change to `config/mutant.yml` outside its subjects and ignores, such as operators, the timeout, coverage criteria, or what it requires, includes or hooks: `change: config`;
  - any change to `test/mutant/boot.rb` or `test/mutant/hooks.rb`: `change: harness`.
- **Re-anchoring.** `test/mutant/baseline.yml` records the survivors on main as of its newest anchor, and the gate doesn't read it. A change to its survivors or to the subjects it records must append an anchor giving the reason. `bin/mutant-floor --record "REASON"` runs every subject and writes it.

`accepted.yml` is append-only:
- each of its lists at the base must be the start of the same list on the change, or the step fails;
- the entries after it are the ones the change adds, and only those count;
- an entry without a reason, or of the wrong shape, fails with a message, and so does an equivalent that matches no new survivor, or a file the gate reads that isn't valid YAML.

These checks, and the anchor's, run before either mutant run, and a failure stops the step there.

**Reason.**

- Accepting a survivor is a decision, and so is letting mutation cover less.
- A config or harness change weakens both runs alike, so the comparison can't see it.
- If an entry still counted after its own change merged, or an edited one counted as new, it would be a credit that a later regression could spend.
- An entry that excused everything in its change would let one reason cover what it never names.
- The reasons belong in files only the owner may change (CI-8). (D-22)

Kind: functional. Proof: test, the tests named CI-5 in `test/contract/ci_contract_test.rb`.

### CI-6 The duplication and complexity floors judge the change, from exhale's own bundle

The duplication floor fails on a copy the change introduces, or one it pushes over the threshold (exhale's defaults: a score of 0.80, 4 lines, 20 normalised nodes). Copies already on main are listed as warnings. A deliberate copy passes only with a `parallel` clause in exhale's Contract (`contract/<primitive>/duplication.md`), whose section gives the reason. The complexity floor fails when a method's cognitive complexity rises above 8, or a new method starts above it, unless a `ceiling` clause gives a reason. Exhale runs from its own bundle (`tools/Gemfile`), never the app's, and that bundle is frozen: a Gemfile that no longer matches its lockfile fails instead of resolving again. Installing and running it leaves the app's `Gemfile.lock` as it was, even from inside the app's bundle as `bin/ci` runs it, and it installs where its gems are missing, as on a fresh runner.

**Reason.** both floors judge the change, not the codebase, and the merge base is the floor: main only gets there through this check. Exhale's dependencies stay out of production. Bundler hands a bundled process's children the app's lockfile, and a tool that writes its own resolution there replaces the app's. It also hands them `BUNDLER_SETUP`, which RubyGems loads at startup, so a `bundle install` started with it loads the bundle it is about to install and stops because the gems are missing. And with a bundle path, such as setup-ruby's `vendor/bundle`, it hands them a `GEM_HOME` and `GEM_PATH` that hide the installed Bundler. (D-23)

Kind: functional. Proof: test, the tests named CI-6 in `test/contract/ci_contract_test.rb`.

### CI-7 The guards fail what switches a check off from inside

The guards fail a change when:
- a Ruby or HTML ERB file under `app/` or `lib/` is one that exhale doesn't read, and at the base it was read or didn't exist. The guard asks exhale itself (`Exhale::SourceFiles.list`, in exhale's bundle) about the change and about the base. That covers a generator's header in the first five lines, a name or directory that looks like a test (`ab_test.rb`, `spec/`), a dot segment and a symlink.
- any file holds more RuboCop disable or todo directives than it did at the base;
- any file holds more `mutant:disable` comments (mutant's own pattern, applied to comment text) than it did at the base.

**Reason.** exhale silently leaves such a file out of both floors, an inline RuboCop directive switches a cop off where no config file shows it, and mutant drops any subject whose comments disable it, without a word. (D-24)

Kind: functional. Proof: test, the tests named CI-7 in `test/contract/ci_contract_test.rb`.

### CI-8 CODEOWNERS names the owner on every path that decides the gate

Reworded 2026-11-07 by the mutation selection completeness change (D-38).

`.github/CODEOWNERS` names the owner on every path that decides the gate:
- the workflow, and `bin/` (which holds `bin/ci`, the mutation gate, the floors, the guards and the test count);
- the CI and mutant config, the baseline, the survivor and selection accepted lists, the gate's, guards' and test count's logic, and the CI Contract test;
- exhale's Contract, its bundle and its cache;
- every file a gate tool reads without being told to: `.rubocop.yml` and a `.rubocop` options file, `config/brakeman.yml` and `config/brakeman.ignore`, `config/bundler-audit.yml`, a committed `.bundle/` or `vendor/bundle/`, and `.gitattributes`;
- the test harness: `test/test_helper.rb`, `test/test_helpers/`, `test/application_system_test_case.rb`, `config/environments/test.rb`, `config/boot.rb`, the `Rakefile` and `lib/tasks/`;
- the Gemfile.

The app's `Gemfile.lock` is deliberately not owned.

**Reason.** a pull request runs its own copy of the gate, and with code-owner review required, a change to the gate needs the owner's hand. Brakeman reads `config/brakeman.yml` and RuboCop reads `.rubocop` without being asked, and either can switch checks off. A Dependabot patch or minor bump that touches only the lockfile may merge on a green check (G1), and an owned lockfile never could. The check still runs every step on such a bump, the gem audit and the mutation gate included. (D-20, D-24)

Kind: functional. Proof: test, the tests named CI-8 in `test/contract/ci_contract_test.rb`.

### CI-9 The tests pass on their own summary and the base's count

The Rails tests and the system tests pass only when the output of each run ends with Minitest's summary line, showing 0 failures, 0 errors, exactly the skips `test/ci/test_removals.yml` lists for that suite, and at least as many runs as the base has tests. The output is read by a process that doesn't load the app. The base's count comes from loading the base's own test files, exported from git, and counting their tests without running them. An export git doesn't complete, or a count of 0, fails. A change that removes tests on purpose adds an entry to `test/ci/test_removals.yml`, naming the suite, how many and why. Each entry the change adds lowers the count by its number for that suite, and an entry without a reason fails. A test that stays skipped is listed under `skips`, with its suite, how many and why. The list must match the run exactly, so a skip that is fixed comes off the list.

**Reason.** any file the app loads can make the test process exit 0 without running a test (`at_exit { exit!(0) }`), and a deleted test is otherwise invisible. Minitest counts a skipped test as a run, and skipping a test that fails is the easiest way to make a suite pass. The base is main's code, which the change can't alter. A removal is a decision, so its reason goes in an owned file. (D-25)

Kind: functional. Proof: test, the tests named CI-9 in `test/contract/ci_contract_test.rb`.

## The weekly run on main

### CI-10 A weekly workflow runs every subject on main, with the least it needs, and adds no check

`.github/workflows/mutation-weekly.yml` runs on a schedule, Mondays at 06:00 UTC, and by hand (`workflow_dispatch`), and on nothing else, so it adds no check to a pull request or a push. It has one job, which runs only for `refs/heads/main`, in one concurrency group. Its permissions are exactly `contents: read` and `issues: write`. It installs libvips and sets up Ruby as `ci.yml` does, and its only commands besides that install are `bin/mutant-weekly`, then `bin/mutant-weekly --issue`. Checkout authenticates with the job's token but keeps no credential behind (`persist-credentials: false`), so no credential remains on the runner for the steps that run the app's tests; only the second step is given the run's `GITHUB_TOKEN`, as `GH_TOKEN`. Every action it uses is on CI-2's allowlist. Nothing in it carries `continue-on-error`, and the only condition is `if: failure()` on the upload of mutant's full output.

**Reason.** the PR gate compares each change with its merge base, so a survivor already on main stays invisible until someone re-anchors, and a full run on main is what shows it. A report needs to read the code and write one issue, and no more, and the app's own tests never need the token. Checkout persists its token for later steps by default, so leaving it in place would hand the tests a credential that can write issues whatever the steps' environments say. Two runs at once could each find no open issue and open one. Setting up apart from `ci.yml` would measure a different main from the one the gate measures. (D-37)

Kind: functional. Proof: test, the tests named CI-10 in `test/contract/ci_contract_test.rb`.

### CI-11 The run reports the survivors on main that the anchor and the accepted list don't account for

`bin/mutant-weekly` runs mutant on every subject in `config/mutant.yml`, through a wrapper that calls mutant's CLI in its own process, and reads its session result. A survivor is known by the key the gate uses (CI-4): its subject and the lines its mutation removes and adds, trailing whitespace ignored. For each key, every survivor the newest anchor in `test/mutant/baseline.yml` records, and every `equivalents` entry in `test/mutant/accepted.yml`, takes up one survivor; `config` entries take up none. The rest is the delta. The report gives the commit, the anchor's commit and the size of the delta; then the run's subjects, mutations, survivors, mutations killed only by a timeout, and how long mutant and the step took; then the delta by subject in name order, each survivor with mutant's identification and its lines; then, under "Killed since the anchor", the anchor's survivors the run didn't find alive. The step saves the report for the issue step only from a run that completed: mutant's CLI returned, and did not raise, so the wrapper exited 0 or 1 (1 when mutations survive) with its line for that exit as the last thing printed, where any exception, however late, exits 3 without it, and a signal or any other exit counts as not returned; mutant printed its final report, whose results equal its mutations and the results the session holds; and `mutant environment subject list` exited successfully, and the session's subjects are exactly those it prints for `config/mutant.yml`, so a subject missing under a wildcard that still matches another counts. A run with none of that, no session result, a subject with fewer results than mutations, a neutral mutation that fails, aborts or times out, or an expression in `config/mutant.yml` that matched no subject fails the step, removes any report saved before, and leaves nothing for the issue step, which then fails without calling GitHub. A session file read with `--session` is a preview, and saves nothing.

**Reason.** the weekly run and the gate must mean the same thing by a survivor, or one would report what the other accepts. Every entry in the accepted list counts here, not only the ones a change adds, because the run judges main as a whole and the list is main's. The killed ones are what a re-anchor would drop. A run that can't be trusted must not close the issue as clean. mutant writes its session file as it goes, so a file left by a run that crashed or was killed looks like a result; mutant also prints its final report before it writes the session for the last time, so an exception after the report still exits 1, as survivors do; only the CLI's normal return, the final report and mutant's own list of what the config selects, from a listing that itself succeeded, show the run covered everything. The baseline's subject list can't be that list: it is as old as its anchor. (D-37)

Kind: functional. Proof: test, the tests named CI-11 in `test/contract/ci_contract_test.rb`.

### CI-12 One issue labelled mutation-weekly carries the report: the run acts on the oldest open one and never opens a second

`bin/mutant-weekly --issue` finds the oldest open issue labelled `mutation-weekly` in the repository's own issue list (`GET /repos/{owner}/{repo}/issues`, oldest first), not in search: it reads page after page, past pull requests, which that list holds too, until it meets an issue or the list ends, so neither a page limit nor an issue search hasn't indexed yet can hide it. With a non-empty delta and one open, it replaces the body of that issue with the report and comments on it with the commit and the size of the delta. With a non-empty delta and none open, it opens one with the report, creating the label first if it is missing. With an empty delta and one open, it comments that main is clean at the commit and closes it. With an empty delta and none open, it writes nothing. It never opens an issue while one is open; after one is closed, a later non-empty delta opens a new one. Other open issues with the label, such as ones a person opened by hand, are left as they are. A `gh` call that fails stops the step there, with no call after it. Triage, and any re-anchor, are left to a person.

**Reason.** one place to read what main carries, and a report that piles up issues stops being read. Replacing the body keeps it current, and the comment tells whoever watches it that the run happened. Search can lag behind an issue just opened, and deciding from search that none is open would open a second. (D-37)

Kind: functional. Proof: test, the tests named CI-12 in `test/contract/ci_contract_test.rb`.

## Selection completeness

### CI-13 Changed application constants need actual mutation reach

Reworded 2026-11-08 after reviews of a11298e and 8431911 (D-38).

For added or modified code paths under `app/` and `lib/`, every declared class or module containing an ordinary definition or executable block outside CI-15's macro exception must have at least one subject in mutant's own enumeration for the current `config/mutant.yml`, resolving to that constant and that source file, unless CI-14 or CI-15 accepts it. Namespace-only module wrappers do not independently need a subject. Multiple constants in one file are judged separately. An extraction behind an unchanged delegate into an unlisted class fails. An unreached constant's failure names the path and constant and says to list its subject in `config/mutant.yml` or add a dated path acceptance. Ruby with unattributed executable code, including dynamically constructed classes, fails unless accepted by path. Foreign receiver context follows non-self calls through their blocks and arguments. Definitions, singleton-class bodies, reflective calls and evaluation calls reached in that context are unattributed. A singleton-class body on a non-self receiver, and a non-self definition, reflective call or source evaluation, are also unattributed directly. Entering ordinary method, class and module definitions gives their bodies a fresh receiver context. A fresh anonymous `Module.new` preserves the incoming context without retargeting it itself: self-extension remains self-scoped, while extension of a foreign receiver stays unattributed. Ruby syntax errors always fail.

Every file under those two roots is a candidate except the non-code allowlist: `.woff`, `.woff2`, `.ttf`, `.otf`, `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.avif`, `.svg`, `.ico`, `.md`, `.keep`, plus the `.keep` placeholder basename. Today the non-code files present under `app/` are `.woff2` fonts, the `.md` font README and `.keep` placeholders; `lib/` has only a `.keep` placeholder. Unknown suffixes or suffixless files fail with "unknown code type" unless accepted by dated path. `.rb` is parsed as Ruby, `.rake` requires acceptance, and `.erb`, `.builder`, `.jbuilder`, `.js` and `.css` have named tool limits. `config/`, `db/`, `bin/`, `test/` and `tools/` remain a declared scope boundary, not code mutation proves.

**Reason.** A delegate can retain its selected name while its logic moves outside mutation. Actual enumeration and source resolution stop a selector string or an unrelated constant from vouching for that logic. (D-38)

Kind: functional. Proof: test, the tests named CI-13 in `test/contract/ci_contract_test.rb`.

### CI-14 Only controller files at or below 100 lines receive the directory exemption

Reworded 2026-11-08 after reviews of a11298e and 8431911 (D-38).

Classes with names ending in `Controller` and a static constant superclass name ending in `Controller` or exactly `ActionController::Base` or `ActionController::API` (with an optional leading `::`), in `app/controllers/**/*_controller.rb`, excluding `app/controllers/concerns/`, are exempt only when their combined file bodies measure at most 100 lines by RuboCop's ClassLength and ModuleLength counting, excluding comments and blank lines, with no folded constructs. Nested class and module bodies contribute once. Namespace-only wrappers contribute no body lines of their own; top-level load directives count toward the cap. Unattributed code cannot take this exemption. The check verifies only the path, class-name suffix and static superclass name; it does not prove Rails controller ancestry or routing. An over-cap file loses the exemption and follows CI-13 and CI-15. The exemption prints its path, measured size and cap. There is no method-length cap and this check does not enable RuboCop Metrics cops. Lines are counted as RuboCop counts them: a line of any length counts once, and a one-line class body counts zero.

**Reason.** Thin controllers are allowed to orchestrate Rails conventions, while extracting logic into a concern must not silently gain the same exemption. File aggregation prevents splitting the body into nested definitions to evade the cap. (D-38)

Kind: functional. Proof: test, the tests named CI-14 in `test/contract/ci_contract_test.rb`.

### CI-15 Every accepted gap is named and dated path acceptances are owned

Reworded 2026-11-08 after reviews of a11298e and 8431911 (D-38).

ERB, Builder, Jbuilder, JavaScript and CSS paths are named tool limits, reported for each changed path. A Ruby constant receives the declarations/macro tool limit only when its parse has no ordinary definition, reflective definition/evaluation call, or executable block outside the following closed macro exception. A block passed to a listed macro, or a literal lambda or bare/self `lambda` or `proc` callable passed in that macro's arguments, may use the exception only when the macro send has no receiver or receiver `self`. Nested blocks in its body are independently inspected; an ordinary definition within a macro block still requires reach. Any other block, lambda, proc, numbered-parameter block or implicit-parameter block is executable. `send` or `public_send` with a literal definition/evaluation method symbol, and evaluation calls with source arguments, also require reach or acceptance. Method-table manipulation is executable wherever it appears: `alias`, `alias_method`, `remove_method`, `undef_method`, `define_method`, `define_singleton_method` and `instance_variable_set`, and `send`, `public_send` or `__send__` whose first argument is a literal symbol naming one of them. Ordinary Ruby `undef` is treated the same way. `.rake` task source is not a verified automatic tool limit and requires a dated path acceptance.

The macro exception allows straight-line logic inside a listed macro's own lambda or block, and callables built without any block. The parse does not prove those bodies are trivial or mutated.

The closed macro names are: `scope`, `validate`, `validates`, `validates!`, `validates_each`, `validates_with`, `validates_absence_of`, `validates_acceptance_of`, `validates_associated`, `validates_comparison_of`, `validates_confirmation_of`, `validates_exclusion_of`, `validates_format_of`, `validates_inclusion_of`, `validates_length_of`, `validates_numericality_of`, `validates_presence_of`, `validates_size_of`, `validates_uniqueness_of`, `before_validation`, `after_validation`, `before_save`, `around_save`, `after_save`, `before_create`, `around_create`, `after_create`, `before_update`, `around_update`, `after_update`, `before_destroy`, `around_destroy`, `after_destroy`, `before_commit`, `after_commit`, `after_rollback`, `after_create_commit`, `after_update_commit`, `after_destroy_commit`, `after_save_commit`, `after_touch`, `after_find`, `after_initialize`, `before_action`, `after_action`, `around_action`, `before_enqueue`, `after_enqueue`, `around_enqueue`, `before_perform`, `after_perform`, `around_perform`, `included`, `class_methods`, `prepended`, `belongs_to`, `has_one`, `has_many`, `has_and_belongs_to_many`, `normalizes`, `enum`, `delegate`.

`test/mutant/selection_accepted.yml`, under existing CODEOWNERS protection, contains only a `paths` list. Every entry has exactly an exact repository-relative code `path`, a quoted real ISO `date`, and a nonblank `reason`. Glob paths, directory paths, duplicate paths and malformed documents fail. An unquoted YAML date rejected by Psych is reported as "date must be a quoted string". Every YAML mapping key must be a String before key comparison; a rejected non-String key is named. The whole file is validated, including old entries. The merge base's list must be the start of the current list, so entries may only be appended. An accepted path remains accepted on later touches, so a new unreached constant added to an accepted file is not caught. Each applicable entry prints its path, date and reason on every run. These acceptances are separate from survivor credits and do not change CI-4 or CI-5.

**Reason.** Mutant's method inventory cannot represent every Rails declaration or frontend language. Gaps must be visible, and deliberately leaving enumerable code outside selection is an owned decision tied to a named path. (D-38)

Kind: functional. Proof: test, the tests named CI-15 in `test/contract/ci_contract_test.rb`.

### CI-16 Completeness runs before mutation and fails closed on an untrustworthy inventory

`bin/ci` runs `Guard: Mutation selection completeness` immediately before `Gate: Mutation`. `bin/mutant-completeness` accepts the shared base argument, defaulting to `$CI_BASE` then `origin/main`, and compares current added and modified paths, including rename destinations, against the merge base with HEAD. Paths are NUL-delimited; deleted paths have no current constant to judge. Local untracked application candidates are included too.

The step runs exactly `bundle exec mutant environment subject list` with the current config, without replacing its subjects. Its exit must succeed and its complete listing count must match. Every listed method must resolve to a source location in a separate eager-loaded Rails process. Git failures, listing failures, malformed or incomplete inventories, lookup failures, unreadable files and symlinks fail the step. It reports all path findings and named gaps and returns nonzero on any failure. It does not run mutations or change the existing two-run survivor gate.

**Reason.** A missing subject or a failed discovery process must not silently count as proof of reach, and an independent step must join the single CI job to be enforced. (D-38)

Kind: functional. Proof: test, the tests named CI-16 in `test/contract/ci_contract_test.rb`.

## What this does not cover

Mutation runs only on the subjects listed in `config/mutant.yml`, with tests declaring `cover`. Selection completeness checks changed application files per constant, not per method or executable expression. `PagesController#consulting` reaches `PagesController` while its other three actions remain unselected. A selected constant may therefore still contain unmutated methods, class-body DSL or an extraction into an already reached constant. Unchanged unlisted files are not forced into selection by an unrelated PR. Controller exemptions, named tool limits and persistent path acceptances are explicit remaining gaps.

A pull request runs its own code, so a test that rewrites the test framework could pass anything. CODEOWNERS covers the gate's files, not every file the gate executes. A harness change weakens both runs alike and needs the CI-5 reason and owner review. Deleting one method while adding an unrelated selected method in the same constant can still pass as a rename under CI-4's one-for-one rule. The test count is a tripwire, not a proof: app code that prints a convincing summary before exiting could pass it.

## Decisions

- D-20, `docs/decisions/ci.md`: one job that runs `bin/ci`, and the protection it assumes (CI-1, CI-2, CI-8).
- D-21, `docs/decisions/ci.md`: on a push to main, the floors compare with the previous main: an alarm, not a gate (CI-3).
- D-22, `docs/decisions/ci.md`: mutation runs every subject, on the change and on its base, and fails on what is new (CI-4, CI-5).
- D-23, `docs/decisions/ci.md`: duplication gates on what the change introduces; exhale runs from its own bundle (CI-6).
- D-24, `docs/decisions/ci.md`: guards for what switches a check off from inside, and owners for the gate (CI-7, CI-8).
- D-25, `docs/decisions/ci.md`: tests pass on their own summary and the base's count (CI-9).
- D-37, `docs/decisions/ci.md`: a weekly full run on main reports what the anchor and accepted.yml don't account for, in one issue (CI-10 to CI-12).
- D-38, `docs/decisions/ci.md`: changed application constants need actual enumerated reach, with bounded controllers and named accepted gaps (CI-13 to CI-16).
