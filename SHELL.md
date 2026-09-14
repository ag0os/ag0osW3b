# ag0os: product requirements

*Draft, 2026-09-14. This file is the PRD for the site's front door. It
supersedes the earlier spec that lived here; everything decided in the
2026-09-14 planning session is captured below so implementation planning can
start from this document alone. The v0 shell described in section 12 is in
the working tree, uncommitted.*

## 1. Summary

The home page boots a terminal. The terminal types `ag0os` the way you would
type `claude`, and the program that launches is not a shell: it is a
conversation with an assistant that knows what the site says about Agustin
and nothing else. A visitor asks in plain words, in English or Spanish, and
gets a grounded answer. Under the conversation the shell is still there for
anyone who wants it: `!ls` runs a command, `/help` talks to the program,
`/exit` drops back to `$`.

Nobody has to learn a command. The engineer who types `!ls` gets the wink.
And the site's argument becomes literal: the front door is an agent harness,
which is what Agustin builds.

## 2. Why

- **The themes alone are not dynamic enough.** Agustin, 2026-09-14: "just
  switching themes is not dynamic enough." The switcher demonstrates craft
  once. A front door that answers demonstrates it every time.
- **It is the argument in `PRODUCT.md`, made operational.** Craft asserted by
  being demonstrated. Proof over claims. Judgment moved earlier into
  constraints. A grounded, constrained assistant is exactly that; a generic
  chat widget is the anti-reference.
- **It resolves the jargon problem.** A shell that requires `cat proof`
  serves engineers and walls off founders, hiring managers and recruiters,
  three of the four audiences in `PRODUCT.md`. Conversational by default,
  commands behind a prefix, serves all four.

## 3. Audiences

| Audience (from `PRODUCT.md`) | What they do here | What success looks like |
|---|---|---|
| Founders and hiring managers | read the greeting, tap "What has he built?", ask about availability, email | an email |
| Consulting clients | ask "what can he do for my team?", read proof, email | an email |
| Peer engineers | type `!ls`, `!cat proof`, read the code path, follow a post | a return visit |
| Recruiters and scanners | read the greeting; never type | contact found in under thirty seconds |

**The Scanner Rule.** The thirty-second visitor never types. The boot sequence
and the greeting have to carry who this is, the proof, and how to reach him
without any input. A change that drops one of those is a regression however
good it looks.

## 4. The experience

### 4.1 Boot

On load the terminal shows a `$` prompt and types, at a human cadence:

```
$ ag0os
```

Enter. A bordered welcome box appears, then the assistant speaks first.

```
┌ ag0os 0.1 ─────────────────────────────────────────┐
│ Ask me anything about Agustin. /help for commands. │
└────────────────────────────────────────────────────┘

  Hi. I'm the assistant on Agustin Calabrese's site.
  He's a senior software engineer in San Isidro, Buenos Aires, GMT-3:
  Rails and backend systems, cloud, AI-native delivery. Thirteen years
  as a DJ, producer and sound engineer before that.

  Selected proof
  - Secure payment workflows for hundreds of sports organizations,
    thousands of daily transactions.
  - ...

  mail agoos@hey.com · github github.com/ag0os

  [ What has he built? ] [ What does he do for clients? ] [ How do I reach him? ]

> _
```

- The box is a CSS border, not box-drawing characters. The self-hosted fonts
  are Latin-only subsets and the corners would fall back to a system face.
- The greeting is content: the `shell_whoami` setting (and its `_es` twin),
  the section `cat proof` resolves to, and the contact settings. It changes
  without a deploy.
- It plays typed once per browser session and instantly after that. Any
  keypress skips it. Under `prefers-reduced-motion` it never animates.
- The prompt glyph is `$` during boot and `>` inside the program. It is a
  token so the terminal preset can keep `$` throughout if that reads better
  there; components never branch on a preset.

### 4.2 Input grammar

Every line typed at `>` is one of three things, decided by its first
character.

| Prefix | Goes to | Examples |
|---|---|---|
| none | the assistant (section 5) | `what has he built?`, `¿está disponible?`, `rates?` |
| `/` | the program | `/help`, `/lang es`, `/theme spec`, `/light`, `/dark`, `/clear`, `/exit` |
| `!` | the shell underneath | `!ls`, `!cat proof`, `!whoami`, `!writing`, `!open work` |

- **Forgiveness.** A bare single word that is exactly a program or shell
  command (`help`, `ls`, `clear`, `exit`) is treated as if prefixed. Nobody
  should be told "not a command" for typing `help`.
- **`!` output** renders as a command block inside the conversation, the way a
  coding agent shows a shell result.
- **`/exit`** prints a goodbye and returns the prompt to `$`. In `$` mode
  lines are plain shell commands and `ag0os` relaunches the program. This
  keeps the fiction honest and costs about ten lines of state. It ships in v1
  unless it proves awkward, in which case it is cut, not half-done.

### 4.3 Suggestions

Under the greeting, and under every fallback reply, sit three tappable
suggestions. Tapping one types the phrase and sends it. They are the bridge
for phones and for anyone who would rather click than type, and they are FAQ
entries flagged as suggested, so they are content too.

### 4.4 Voice

- First person as the assistant, third person about Agustin. It never claims
  to be him.
- Calm competence, per `PRODUCT.md`. States what was built, at what scale,
  what was learned, then stops. Short answers; a paragraph at most.
- Answers in the language the question came in. Program strings, the
  greeting and the refusals follow the site locale.
- It only talks about Agustin, his work, his writing, and how to reach him.
  Everything else gets the same in-character refusal in the visitor's
  language, plus the suggestions. No code, no poems, no general answers.

### 4.5 Languages

- English and Spanish. Locale per request: the `locale` cookie set by
  `/lang es`, then `Accept-Language`, then English. The admin stays English.
- Every fixed string has a twin in `config/locales/es.yml`; a test fails if
  the two files disagree.
- Content has a Spanish sibling where it matters: settings by `_es` suffix
  (shipped), sections by a Spanish body (v1), FAQ answers in both languages
  (v1).

### 4.6 Without JavaScript

The input is a real form submitting with GET, so a line is a URL. The server
renders the home page with the exchange after the boot sequence, which is
already printed server-side. Suggestions are links. Nothing on this surface
requires JavaScript to read or to ask.

### 4.7 Presets

One component consuming the semantic tokens like everything else. Terminal
renders the thing itself; workshop a transcript typed on the stock, with the
hand in the margin beside it; console a screen set into the panel; spec a box
on the grid. The one deliberate exception to the focus rule stands: the ring
is the global token at the global width, drawn on the frame through
`:focus-within` rather than around the text field inside it.

## 5. The three routes

Every line without a prefix is tried against these in order. Most never
reach the third.

| Route | Handles | Cost | Status |
|---|---|---|---|
| 1. Commands | `!` lines and `/` lines, plus forgiven bare words | none | v0 shipped; prefixes are v1 |
| 2. FAQ matcher | questions that match a curated entry | none | v1, **required for launch** |
| 3. Grounded model | everything else, on a miss | paid, capped | v2 |

### 5.1 Commands

The interpreter in `app/services/shell.rb` is the `!` backend and stays as it
is: `help`, `whoami`, `cat <page or key>`, page names as shorthand, `ls`,
`writing`, `open <page>`, `lang`. `cat` resolves a section key, then a page
name, then a key suffix, so `cat proof` finds `home_proof`. Browser-only
commands (`theme`, `light`, `dark`, `clear`) are answered by the Stimulus
controller through the existing theme controller, so the switch has one code
path; the server says they need JavaScript when it is off.

### 5.2 FAQ matcher

**A conversational prompt that answers nothing is worse than a shell that
never claimed to.** The first shippable version therefore includes the
matcher and a seeded set of entries.

- **Entry:** trigger phrases per language, an answer per language, a
  `suggested` flag, a position, a hit counter. Managed in the admin like
  sections.
- **Matching:** lowercase, strip accents, tokenize, drop a short stopword list
  per language, score token overlap between the input and each trigger
  phrase, take the best entry above a threshold. Ties go to the entry with
  more hits. Plain Ruby; no embeddings, no vector store, no native gem. For a
  bounded set of a few dozen entries this works better than people expect,
  and it is tuned by editing phrases in the admin, not code.
- **Seed set**, each in English and Spanish:
  1. What does Agustin do?
  2. What has he built?
  3. What is Cosmonauts?
  4. What can he do for my company / for a client?
  5. Is he available? Roles versus consulting.
  6. Where is he based? Which timezone?
  7. What languages does he speak?
  8. What is his background? The audio years.
  9. What is his stack?
  10. How do I reach him?
  11. Does he consult on AI workflows and agents?
  12. What does he write about?
  13. Where is the code?
  14. How is this site built?
  15. What are his rates? Answer: that is an email conversation, with the
      address.

### 5.3 Grounded model

Called only on a miss.

- **Corpus:** a curated facts document (sections on a hidden `agent` page)
  plus the visible sections. Kept under about 5,000 tokens; corpus size
  matters more than model choice. Cached.
- **Contract:** the model answers through a JSON schema with `language`,
  `in_scope`, `answer` and `sources`. Sources are validated against real
  section keys on the server. Anything out of scope, or unsourced, prints the
  refusal instead.
- **Rendering:** escaped plain text. An injected script tag is characters on
  a screen.
- **History:** the last two turns only. Input capped short, output capped
  short.
- **Model:** not chosen. Opus 5 for Spanish quality and injection resistance;
  Haiku 4.5 if cost is the tiebreaker. Section 7 has the numbers. The daily
  cap makes the worst case a number Agustin picks either way.

### 5.4 The fallback reply

When nothing matches and the model is not live, or is over budget, the
assistant says in character what it can talk about and shows the suggestions
again, in the visitor's language. That reply is the seam where the model
plugs in later, untouched.

### 5.5 The flywheel

Every free-text exchange is logged with the route that answered it. The admin
shows them newest first with a "promote to FAQ" action. Questions that hit the
model become entries; model spend trends toward zero while answer quality
rises. Route 3 is a bootstrapping tool for route 2.

## 6. Guardrails

The honest threat model: the assistant has no tools, no private data, no
memory across visitors and no write access. Injection cannot exfiltrate
anything because there is nothing to exfiltrate. The two real risks are money
and reputation.

- **Money.** Rails 8's built-in controller rate limit per IP; a small
  per-session cap before it says "email him"; a global daily counter in Solid
  Cache checked against a site setting. Past the cap the model route is off,
  the fallback reply takes over, and routes 1 and 2 keep working. This is the
  control that matters most.
- **Reputation.** Schema-forced scope, refusal in the visitor's language, the
  input and output caps, two turns of history, and the transcript log so what
  it said can be read.
- **Bots.** A signed token minted on page load, so a script has to fetch the
  page before it can ask.
- **Off switch.** An `agent_enabled` setting. Off means route 3 never runs.

## 7. Cost

Per thousand model-answered questions, corpus around 8,000 tokens, short
answers:

| Model | Uncached | Cache hit |
|---|---|---|
| Haiku 4.5 | about $10 | about $3 |
| Sonnet 5 | about $20 | about $6 |
| Opus 5 | about $50 | about $14 |

Caching only pays when questions arrive within five minutes of each other,
which a personal site cannot count on, so plan on the uncached column. A
thousand misses a month is heavy traffic here. The model is not the cost
lever; not calling it is.

**Rejected on cost and latency** (details in `ROADMAP.md`): a self-hosted
small model, and a model running in the visitor's browser.

## 8. Data

| Change | Shape | Stage |
|---|---|---|
| FAQ table | trigger phrases and answer per language, `suggested`, `position`, `hits` | v1 |
| Transcript table | session id, locale, input, route, answer, tokens in/out, cost, created at | v1 |
| Spanish sections | a Spanish body, heading and note on `Section`, or a locale column | v1 |
| Settings | `shell_opening` becomes the boot script; `shell_whoami` and `_es` stay; add `agent_enabled`, `agent_daily_budget` | v1 / v2 |
| Retention | transcripts kept ninety days, then deleted by a recurring job; IPs stored only as a salted hash for rate limiting | v1 |

Transcripts are visitor text. They are read as data in the admin, never as
instructions anywhere.

## 9. Non-functional requirements

- **Accessibility.** The transcript is `role="log"` with polite announcements.
  Suggestions are buttons with visible text. Focus is the global token. No
  meaning by hue alone. Reduced motion is honored throughout. The typed boot
  is decoration over content that is already in the DOM.
- **Performance.** The boot renders server-side; no request leaves the page
  until the visitor types. A route 1 or 2 answer is one small stream. A route
  3 answer holds one Puma thread for a couple of seconds, which the rate limit
  bounds.
- **Stack.** Vanilla Rails, plain CSS, no Node. Route 3 adds exactly one gem,
  the official `anthropic` client, and nothing else.
- **Privacy.** No account, no tracking, no third-party request at runtime.
  The transcript log and the hashed IP are the only data stored about a
  visitor, and both expire.

## 10. Success measures

The site is not live yet, so these are what the transcript table will show
once it is.

- The share of questions answered by route 2 rises month over month as
  entries are promoted; the share reaching route 3 falls.
- The fallback rate falls below one in ten questions.
- Spend stays under the daily cap without the cap ever being the thing that
  answered a real visitor.
- And the two from `PRODUCT.md`: a founder emails; an engineer returns.

## 11. Decisions

**Made**

- The program is `ag0os`. The boot types it; the banner names it.
- Conversational by default. Commands behind `!`, the program behind `/`.
- The assistant speaks first person about itself, third person about
  Agustin, and never as him.
- The FAQ ships with the conversation, not after it.
- The hero title is set at headline size so the terminal arrives above a
  laptop's fold. The display step in the type scale is unused until
  something earns it.
- Self-hosted and in-browser models are rejected.
- The prompt glyph is a token: `$` for boot and the shell, `>` for the
  program.

**Open**

- Which model for route 3. Inputs: section 7, Spanish quality, injection
  resistance.
- The daily budget number and the per-session cap.
- Whether `/exit` shell mode survives v1.
- Spanish sections as columns or as a locale table.
- Whether the greeting's proof block is the whole `home_proof` section or a
  shorter cut of it.

## 12. Staging

| Stage | Contents | State |
|---|---|---|
| v0 | the shell: typed opening, `help` `whoami` `cat` `ls` `writing` `open` `lang`, browser-side `theme` `light` `dark` `clear`, two languages, works without JavaScript | built 2026-09-14, uncommitted |
| v1 | `ag0os` boot and banner, `>` prompt, `/` and `!` grammar, forgiveness, suggestions, FAQ table with admin and seeds, transcript table with promote-to-FAQ, Spanish sections, in-character fallback, `/exit` | next; the launch candidate |
| v2 | route 3 behind the rate limit, session cap, daily budget and off switch; the facts page; the model decision | after v1 has collected real questions |

v0 stays in place under v1: its interpreter becomes the `!` backend and its
opening becomes the boot script. Nothing in v0 is thrown away.

## 13. Test plan

- **Unit.** The prefix parser (bare, `/`, `!`, forgiveness, `$` mode). The
  matcher: accents, stopwords, threshold, ties, both languages. The seed set
  matches its own trigger phrases.
- **Integration.** Every route over HTTP with and without JavaScript, the
  locale rules, the transcript being written, the promote action, the rate
  limit and budget responses, the locale files agreeing.
- **System.** The boot plays and is skippable, a suggestion sends, `!ls`
  renders as a command block, `/theme spec` changes the design and the
  switcher agrees, `/lang es` reloads in Spanish, `/exit` and relaunch, and
  the whole surface at a real 390px viewport under device emulation. The
  existing narrow-screen tests resize to 500px because Chrome refuses to go
  smaller; they should move to emulation as part of v1.
- **Design.** The existing guards in `test/design/` stay the gate: no
  hardcoded colors, no preset branches, contrast on every pair in all eight
  surfaces.

## 14. Implementation map

| Piece | Where (v0) | v1 change |
|---|---|---|
| interpreter | `app/services/shell.rb` | becomes the `!` backend; a new router splits bare, `/`, `!` |
| matcher | | new, plain Ruby, next to the interpreter |
| endpoint | `ShellController#show`, `GET /shell?line=` | unchanged shape; writes a transcript row for free text |
| markup | `app/views/shell/` | boot and banner partials, suggestion chips, command block |
| browser | `shell_controller.js` | boot sequence, chip sending, `$` mode |
| styles | the shell block in `components.css` | banner, chips, command block |
| strings | `config/locales/en.yml`, `es.yml` | program strings, fallback, banner |
| content | `SiteSetting::DEFAULTS` | boot script, budget, enabled flag |
| admin | | FAQ CRUD, transcripts list, promote action |

**Adding a `/` command:** add a branch to the program's router, a partial, and
its help line in both locale files. **Adding a `!` command:** add a branch to
`Shell#run` as today. **Adding an answer:** the admin, no deploy.
