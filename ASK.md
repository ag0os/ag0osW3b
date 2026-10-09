# Ask: product requirements

*Draft, 2026-10-01. This file is the PRD for the site's front door. It
replaces `SHELL.md`, whose front end (the terminal, the boot, the prefix
grammar) was dropped on 2026-09-29 as "too obvious" and whose back end (the
FAQ matcher, the grounded model, the guardrails, the transcripts) is carried
across below. A design spike was built and used before this was written;
section 4.11 records what it found and how each finding is resolved here.
Implementation planning can start from this document alone. `PLAN.md` is the
v1 plan.*

## 1. Summary

The home page is the site's copy, and the copy is the interface. It arrives
with a little life, says who Agustin is, what he has built and how to reach
him, and its last line is an invitation that ends in a blinking cursor. The
cursor is a real input. A visitor who types a question watches the copy fold
away into a line of contact details, and a conversation grows where the page
was: the question as a heading, a grounded answer under it, the source named
in the margin.

There is no terminal, no chat window, no bubble, no avatar and no command to
learn. A visitor who never types has read a complete page. A visitor who does
type discovers that the page answers, in English or Spanish, about Agustin
and nothing else.

## 2. Why

- **The themes alone are not dynamic enough.** Agustin, 2026-09-14: "just
  switching themes is not dynamic enough." The switcher demonstrates craft
  once. A front door that answers demonstrates it every time.
- **The shell was too obvious.** Agustin, 2026-09-29. A terminal on an
  engineer's site is the expected move, and it puts the interface in front of
  the content: a visitor meets a prompt before they meet a sentence. Here the
  content comes first and the interface is found inside it.
- **It is the argument in `PRODUCT.md`, made operational.** Craft asserted by
  being demonstrated. Proof over claims. Judgment moved earlier into
  constraints. A page that answers only from what it says is exactly that; a
  generic chat widget is the anti-reference.
- **It serves all four audiences with one surface.** Everyone can read
  prose, and anyone can ask. Nothing has to be learned first.

## 3. Audiences

| Audience (from `PRODUCT.md`) | What they do here | What success looks like |
|---|---|---|
| Founders and hiring managers | read the copy, ask about availability, email or use the form | an email |
| Consulting clients | ask "what can he do for my team?", read the answer and its source, write | an email |
| Peer engineers | notice the page answers, try to break it, read how it is built, follow a post | a return visit |
| Recruiters and scanners | read the first screen; never type | contact found in under thirty seconds |

**The Scanner Rule.** The thirty-second visitor never types. The first screen
has to carry who this is, the proof, and how to reach him without any input,
and "the first screen" includes a 390px phone. A change that drops one of
those is a regression however good it looks. Section 4.1 says how the page
keeps the rule and section 13 says which test fails when it does not.

## 4. The experience

### 4.1 The copy

The home page, top to bottom, inside the usual site header and footer:

```
  Agustin Calabrese            Home  About  Work  Writing  Contact   [themes]
  ────────────────────────────────────────────────────────────────────────────
              Agustin Calabrese · agoos@hey.com · GitHub · contact

  Thirteen    Senior Software Engineer building AI‑native
  years in    software workflows and agent orchestration tools.
  audio
  first.      I've built secure payment workflows for hundreds of sports
              organizations, thousands of transactions a day. ...

  Numbers,    I'm a senior software engineer in San Isidro, Buenos Aires,
  not adj.    GMT-3. Rails and backend systems, cloud, AI-native delivery. ...

              Lately I build Cosmonauts, an agent-first orchestration
              framework. ...

              I'm open to senior and founding roles, and to AI-workflow
              consulting. Email is fastest.

              Ask it anything about Agustin: ▋
```

- **The contact line** is the first row of the text column: the name, the
  email, GitHub and a "contact" link. It is where the copy folds to (4.4),
  and it is what puts the name and the email on a phone's first screen.
- **The title** is the `tagline` setting, as today, with its mark.
- **The body is content.** It is the visible `home` sections in order,
  rendered as prose with their margin notes in the rail. A home section's
  heading is not printed; it stays as the section's name in the admin and as
  the source label under an answer (4.4). The seeds are rewritten as first
  person prose, proof first: on a phone the proof paragraph has to begin on
  the first screen, and "proof over claims" is the first design principle
  anyway.
- **The recent-writing list leaves the home page.** The invitation has to be
  the last line. Writing stays in the nav, and the copy links to it in a
  sentence.
- **Nothing here is a terminal.** No prompt glyph, no echoed command, no
  frame, no monospace unless the preset is mono throughout.

### 4.2 The reveal

The copy arrives block by block: each block rises into place, staggered, and
the marked phrases are swept in with their blocks.

- **Fast.** The invitation line is in place within 1.2 seconds of first
  paint in every preset. The delay is capped at the fifth block, so adding
  sections never slows it. A design test fails if a preset's motion tokens
  break that budget.
- **Skippable.** Any key or any click completes it at once. A printable key
  also goes into the question (4.3), so a visitor can simply start typing.
- **Once.** It plays on the first visit of a browser session and not again.
- **Honest.** The content is in the DOM from the first byte and the reveal
  is CSS animation over it. Under `prefers-reduced-motion` nothing animates,
  and without JavaScript nothing is ever hidden.
- **Not a typewriter.** Blocks move as set type. Characters never appear one
  at a time, and nothing blinks except the cursor.

### 4.3 The invitation

The last line of the copy is a sentence that ends in a colon, and after the
colon a block cursor blinks.

- The sentence is a real `<label>`. The cursor sits in a real, focusable text
  field in a form that submits with GET. Default wording, a setting so it can
  be iterated without a deploy: **"Ask it anything about Agustin:"**.
- **Unmistakable without the cursor.** The owner's worry after the spike was
  that a blinking block alone is easy to miss. Three things carry the
  invitation besides the cursor: the sentence says what to do; the field
  sits on a short write-on rule that is always visible, the way a form on
  paper leaves a blank; and the field holds a quiet hint, "type a question",
  to which JavaScript adds ", press Enter", because without it Enter is a
  newline. None of them is a box, a button or a bubble.
- **The field wraps.** It grows on the invitation's line, then moves below
  it and wraps at the full measure. It never scrolls sideways. Enter sends;
  a pasted newline becomes a space; questions are capped at 280 characters.
- **The cursor** is the block while the field is empty. Once there is text
  the field shows its native caret in the accent color, because a drawn block
  cannot honestly follow a caret through wrapped text. The cursor is drawn
  from tokens, so a preset may reshape it later without touching markup.
- **Focus** is the one deliberate exception to the no-restyling rule, taking
  over the exception the shell held: the write-on rule becomes the focus
  indicator, in the global focus color at the global ring width, instead of a
  rectangle around a field that is meant to read as the end of a sentence.
- **Typing anywhere** on the page lands in the field: one printable
  character, with no modifier held and not Space, and never while focus is
  in another editable element or in the contact dialog. The field is not
  focused on load: on a phone that would raise the keyboard over the copy.
- After the first answer the same field sits under the thread and its label
  becomes "Anything else?".

### 4.4 Asking

On the first question:

1. **The copy folds.** Everything below the contact line collapses, and a
   small arrow appears at the fold. The arrow is a disclosure: it expands
   the full copy back above the thread and folds it again, by mouse, touch
   or keyboard. Nothing is lost, and a scanner who asked a question can still
   get back to the proof.
2. **The question becomes a heading** at the top of the thread, and the
   answer arrives under it as prose, with marks and links.
3. **The margin names the source.** Beside an answer that has one the rail
   carries a note, "from Selected proof" or "from Contact"; a section with
   no heading lends its page's name, and an answer with no source gets no
   note. The fallback's reads "not on the page". It is the note primitive
   the copy uses, so every preset already knows how to write it.
4. **The field follows**, under the answer, labelled "Anything else?", with
   focus kept in it.

Later questions append to the thread. On a wide screen the contact line
stays pinned under the site header while the thread scrolls, so the email is
never more than a glance away, and the arrow stays at the fold. On a phone,
where two pinned bars would eat the screen, nothing pins. Where the browser
supports view transitions the fold is animated; elsewhere, and under reduced
motion, it simply happens.

The thread lives in the page and nowhere else: leaving and coming back
starts fresh. A question is also a URL, and `/?q=` shows that one exchange,
so an answer can be reloaded or shared. The transcript log (5.4) is the
site's memory, not the visitor's.

### 4.5 Suggestions

When the page cannot answer, the fallback reply (5.3) carries up to three
tappable questions. Tapping one asks it. They are FAQ entries flagged as
suggested, so they are content too. They appear under a fallback and nowhere
else: never under the copy, where they would turn the page into a chatbot's
empty state.

### 4.6 Contact

The "contact" link in the contact line, and any link to the contact page
inside an answer, slides a panel in from the right, or up from the bottom on
a phone. It holds a short form: name, email, message.

- Sending delivers one plain-text email to Agustin with the visitor's
  address as reply-to. The panel then says it was received, and that he
  answers.
- The panel is a native modal dialog: focus is trapped, Escape closes it,
  focus returns to the link that opened it. The email address stays printed
  inside it for anyone who would rather use their own mail client.
- The same form is on the Contact page, which is where the link goes when
  JavaScript is off.
- Messages have no table. One rests in the job queue until it is delivered;
  a transient failure is retried, and a job that fails for good is purged
  within a day.

### 4.7 Voice

- **The copy is Agustin, first person. The answers are the site, third
  person, about him.** The site never speaks as him and never puts a sentence
  in his mouth. It may say "I" only about itself, and rarely needs to.
- The change of voice is made a visible hand-off instead of a seam: the
  invitation says "ask *it*", and every answer cites where on the site it
  came from.
- Calm competence, per `PRODUCT.md`. States what was built, at what scale,
  what was learned, then stops. Short answers; a paragraph at most.
- Answers come in the language the question was asked in. The fallback and
  every fixed string follow the site locale.
- It only talks about Agustin, his work, his writing, and how to reach him.
  Everything else gets the same fallback in the site locale, plus the
  suggestions. No code, no poems, no general answers.

### 4.8 Languages

- English and Spanish. Locale per request: the `locale` cookie, then
  `Accept-Language`, then English. The admin stays English.
- With the shell gone, `lang es` is gone. The cookie is set by a plain
  language control in the footer instead.
- Every fixed string has a twin in `config/locales/es.yml`; a test fails if
  the two files disagree.
- Content has a Spanish sibling: settings by `_es` suffix (shipped), the
  invitation line among them; sections by Spanish columns (v1), which is
  what makes the home copy Spanish; FAQ answers in both languages (v1).
  Posts stay as written.

### 4.9 Without JavaScript

Nothing on this surface requires JavaScript to read, to ask, or to write to
him.

- The copy is server-rendered and never hidden. The reveal is CSS.
- The form submits with GET, so a question is a URL. The server answers with
  the home page already folded: the disclosure closed, the one exchange under
  it, the field after it. The fold is a `<details>` element, so it opens and
  closes on its own.
- The field shows a visible "Ask" button, which JavaScript hides in favor of
  Enter.
- Each suggestion is a small form of its own. The contact link is a link to
  the Contact page, where the form posts normally.
- What is lost: the thread holds one exchange at a time, and the fold is not
  animated.

### 4.10 Presets

One component consuming the semantic tokens, with the same markup in all
four. The rail note already differs per preset, so the source beside an
answer is a hand in workshop, a panel label in console, a callout in spec
and a `#` comment in terminal with no new CSS. The question heading takes no
heading marker, so terminal does not put a prompt in front of it. The
contact panel reads the tokens a card does. Terminal's title used to end on
a blinking cursor; the invitation now owns the page's only cursor, so that
one is retired.

### 4.11 What the spike found

The spike, which the owner used, reported five things that felt wrong and
four open questions. Each is settled here.

| Finding | Resolution |
|---|---|
| **Voice switch.** The prose says "I", the answers say "he", and the seam shows. | Kept, on purpose, and labelled (4.7). Answering as "I" would put words in his mouth. The invitation says "it", and the margin cites the source, so the reader is told who is speaking. |
| **"Anything" over-promises.** | The line is scoped: "anything *about Agustin*". The fallback says plainly that the site only answers from what it says, and offers what it can answer plus the email. Wording stays open (11). |
| **The Scanner Rule breaks on phones.** At 390px the first screen showed only name, title and bio. | The contact line, with the name and the email, sits above the title, and proof is the first paragraph (4.1). A system test at phone size fails if the name, the email or the start of the proof leaves the first screen (13). |
| **The collapse is one-way.** | It is a disclosure (4.4). The arrow brings the full copy back above the thread. |
| **An inline input cannot wrap.** | The field is a wrapping one that grows with the question (4.3). |

Its four open questions are closed: answers are third person; the thread
does not survive leaving the page; Spanish gets its own last line, as a
localized setting; the contact form goes to email.

## 5. The routes

Every question is tried against these in order. Most never reach the second.

| Route | Handles | Cost | Status |
|---|---|---|---|
| 1. FAQ matcher | questions that match a curated entry | none | v1, **required for launch** |
| 2. Grounded model | everything else, on a miss | paid, capped | v2 |

When neither answers, the fallback reply does (5.3).

### 5.1 FAQ matcher

**An invitation that answers nothing is worse than a page that never
offered.** The first shippable version therefore includes the matcher and a
seeded set of entries.

- **Entry:** a canonical question, trigger phrases and an answer per
  language, an optional source (a section key, which becomes the margin
  note), a `suggested` flag, a position, a hit counter. Managed in the admin
  like sections.
- **Matching:** lowercase, strip accents, tokenize, drop a short stopword
  list per language, score the token overlap between the input and each
  trigger phrase or canonical question, weighed against both so a one-word
  phrase cannot claim a long question, and take the best entry above a
  threshold. Ties go to the entry with more hits, then to the site locale.
  Both languages are tried whatever the site locale, and the
  answer comes back in the language of the phrase that matched. Plain Ruby;
  no embeddings, no vector store, no native gem. For a bounded set of a few
  dozen entries this works better than people expect, and it is tuned by
  editing phrases in the admin, not code.
- **Seed set**, each in English and Spanish, each answer in the third
  person:
  1. What does Agustin do?
  2. What has he built?
  3. What is Cosmonauts?
  4. What can he do for my company / for a client?
  5. Is he available? Roles versus consulting.
  6. Where is he based? Which timezone?
  7. What languages does he speak?
  8. What is his background? The audio years.
  9. What is his stack?
  10. How do I reach him? The answer links to the contact form.
  11. Does he consult on AI workflows and agents?
  12. What does he write about?
  13. Where is the code?
  14. How is this site built? Including how this page answers.
  15. What are his rates? Answer: that is an email conversation, with the
      address.

### 5.2 Grounded model

Called only on a miss. v2.

- **Corpus:** a curated facts document (sections on a hidden `agent` page)
  plus the visible sections. Kept under about 5,000 tokens; corpus size
  matters more than model choice. Cached.
- **Contract:** the model answers through a JSON schema with `language`,
  `in_scope`, `answer` and `sources`. Sources are validated against real
  section keys on the server, and they are what the margin note prints.
  Anything out of scope, or unsourced, gets the fallback instead.
- **Voice:** the same as route 1. Third person, about Agustin, never as him.
- **Rendering:** escaped plain text. An injected script tag is characters on
  a page.
- **History:** the last two turns only. Input capped short, output capped
  short.
- **Model:** not chosen. The strongest current model for Spanish quality and
  injection resistance; the smallest if cost is the tiebreaker. Section 7 has
  the numbers. The daily cap makes the worst case a number Agustin picks
  either way.

### 5.3 The fallback reply

When nothing matches and the model is not live, or is over budget, the site
says so in its own voice: it does not say, it only answers from what it
says, here is what it can answer, and here is the email. The suggestions
follow, in the site locale, and the margin reads "not on the page". That
reply is the seam where the model plugs in later, untouched. A question
opened as a URL gets route 1 or this reply and never route 2, so a reload or
a link preview cannot spend money.

### 5.4 The flywheel

Every question asked through the form is logged with the route that
answered it; a question URL merely opened is not. The admin shows them
newest first with a "promote to FAQ" action. Questions that fall
through, and later questions that reach the model, become entries; model
spend trends toward zero while answer quality rises. Route 2 is a
bootstrapping tool for route 1.

## 6. Guardrails

The honest threat model: the site's answerer has no tools, no private data,
no memory across visitors and no write access. Injection cannot exfiltrate
anything because there is nothing to exfiltrate. The real risks are money,
reputation, and now an inbox.

- **Money.** Rails 8's built-in controller rate limit per IP; a small
  per-session cap before it says "email him"; a global daily counter in Solid
  Cache checked against a site setting. Past the cap the model route is off,
  the fallback reply takes over, and route 1 keeps working. This is the
  control that matters most. All of it is v2 except the rate limit, which
  ships in v1 to protect the transcript table.
- **Reputation.** Schema-forced scope, the fallback in the site locale, the
  input and output caps, two turns of history, and the
  transcript log so what it said can be read.
- **The inbox.** The contact form is rate limited per IP, carries a honeypot
  field that real visitors never see and bots fill, caps every field, and
  sends plain text only. A tripped honeypot gets the same "received" reply and
  no email. No CAPTCHA, no third-party script.
- **Bots.** A signed token minted on page load, so a script has to fetch the
  page before it can reach the model. v2.
- **Off switch.** An `agent_enabled` setting. Off means route 2 never runs.

## 7. Cost

Per thousand model-answered questions, corpus around 8,000 tokens, short
answers. Figures are from the 2026-09-14 planning session; re-check prices
and the current model line-up when v2 starts.

| Model | Uncached | Cache hit |
|---|---|---|
| Haiku 4.5 | about $10 | about $3 |
| Sonnet 5 | about $20 | about $6 |
| Opus 5 | about $50 | about $14 |

Caching only pays when questions arrive within five minutes of each other,
which a personal site cannot count on, so plan on the uncached column. A
thousand misses a month is heavy traffic here. The model is not the cost
lever; not calling it is.

Route 1 and the contact form cost nothing per use: the matcher is Ruby, and
the mail volume sits far inside a transactional provider's smallest tier.

**Rejected on cost and latency** (details in `ROADMAP.md`): a self-hosted
small model, and a model running in the visitor's browser.

## 8. Data

| Change | Shape | Stage |
|---|---|---|
| FAQ table | question, trigger phrases and answer per language, optional source key, `suggested`, `position`, `hits` | v1 |
| Transcript table | session token (a browser-session cookie), locale, input, route (`faq`, `fallback`, `model`), matched entry, reply, tokens in/out, cost, created at | v1 |
| Spanish sections | a Spanish body, heading and note on `Section` | v1 |
| Home sections | rewritten in the seeds as first-person prose, proof first | v1 |
| Settings | `ask_invitation` and `_es` added; `shell_opening`, `shell_whoami` and `_es` removed, their content now a home section | v1 |
| Settings | `agent_enabled`, `agent_daily_budget` | v2 |
| Credentials | Mailgun SMTP login and the sender address, in Rails credentials | v1 |
| Retention | transcripts kept ninety days, failed contact jobs one day, both deleted by recurring jobs | v1 |
| Contact messages | no table | v1 |

No raw IP address is written to the database. The rate limiter's counters
live in Solid Cache, which is a database, so they are keyed by an HMAC of
the IP, and they expire with the cache.

Transcripts are visitor text. They are read as data in the admin, never as
instructions anywhere.

## 9. Non-functional requirements

- **Accessibility.** The thread is `role="log"` with polite announcements.
  The invitation is a label on a field. The fold is a native disclosure and
  the contact panel a native modal dialog. Suggestions are buttons with
  visible text. A folded page keeps its `<h1>`. No meaning by hue alone. Reduced motion is honored
  throughout. The reveal is decoration over content that is already in the
  DOM. The write-on rule and the hint clear AA in all eight surfaces.
- **Performance.** The page renders server-side; no request leaves it until
  the visitor asks. A route 1 answer is one small stream. A route 2 answer
  holds one Puma thread for a couple of seconds, which the rate limit bounds.
  Mail is sent from a job, never in the request.
- **Stack.** Vanilla Rails, plain CSS, no Node. v1 adds no gem: the mail goes
  out through Action Mailer over SMTP. Route 2 adds exactly one, the official
  `anthropic` client, and nothing else.
- **Privacy.** No account, no tracking, no third-party request from the
  browser. The transcript log is the only data kept about a visitor, and it
  expires; questions and messages are filtered out of the request log. A
  contact message leaves through the mail provider because the visitor
  asked for it to be sent. The provider keeps its own copy for a time; this
  server keeps none once it is delivered.

## 10. Success measures

The site is not live yet, so these are what the transcript table will show
once it is.

- Visitors ask at all: some share of home page visits produce a question.
  If nobody types, the invitation is being missed, and 4.3 is what to
  revisit.
- The share of questions answered by route 1 rises month over month as
  entries are promoted; the fallback rate falls below one in ten.
- Once route 2 is live, spend stays under the daily cap without the cap ever
  being the thing that answered a real visitor.
- And the two from `PRODUCT.md`: a founder emails, now possibly through the
  form; an engineer returns.

## 11. Decisions

**Made**

- No shell, no command grammar, no boot, no banner, no `/exit`. The v0 shell
  (commit d995227) is replaced; the `Shell` service and its tests go.
- The copy is the interface, and it is complete for someone who never types.
- The reveal is fast, completes on any key or click, is off under reduced
  motion, and never reads as a terminal or a chat widget.
- The Scanner Rule holds on a 390px phone.
- The last line is an invitation, unmistakable even if the cursor is
  missed: a real, labelled, focusable, wrapping field in a form that works
  without JavaScript.
- Answers are third person, never as Agustin. The site says "I" only about
  itself.
- The first question folds the copy to the contact line; an arrow expands it
  back above the thread.
- The contact line prints the name, though the site brand sits above it.
  (default, 2026-10-01)
- The contact line pins on a wide screen; the arrow stays at the fold.
  (default, 2026-10-01)
- A question is a shareable URL: `/?q=` shows that one exchange, unlogged,
  and never calls route 2. (default, 2026-10-01)
- Suggestions appear under the fallback reply only.
- The thread does not survive navigation in v1.
- All of this copy is localized, the invitation included, and v1 puts every
  public page's chrome in Spanish, not only the front door's. (default,
  2026-10-01)
- Production runs Solid Queue inside Puma on one server
  (`SOLID_QUEUE_IN_PUMA=1`), behind a proxy trusted for the visitor's IP.
  Both are deploy prerequisites for the recurring jobs, the mail and the
  rate limits. (default, 2026-10-01)
- "Contact" slides in a form (name, email, message) that sends through
  Action Mailer over Mailgun SMTP, credentials in Rails credentials, no
  Mailgun gem. Spam protection is a rate limit and a honeypot; no CAPTCHA.
- FAQ matcher in v1, required for launch. Grounded model in v2 on the same
  seam. Transcripts with promote-to-FAQ in v1.
- Self-hosted and in-browser models are rejected.

**Open**, each with the default the plan will use unless overridden

- **The invitation's wording.** Default "Ask it anything about Agustin:" and
  "Preguntale lo que quieras sobre Agustin:". It is a setting, so it can be
  changed after launch against what the transcripts show.
- **What makes the invitation unmistakable.** Default: the always-visible
  write-on rule and the hint text. The spike iteration also proposed a single
  pulse of the cursor when the reveal ends; it can be added on top if the
  first two are not enough in the browser.
- **Whether the recent-writing list stays on the home page.** Default: it
  goes, and the copy links to Writing in a sentence.
- **The cursor's shape.** Default: a block in all four presets, drawn from
  tokens. The alternative with more character is each preset's own
  instrument (a proofreader's caret in workshop, a block in terminal), which
  the tokens leave room for.
- **Where the language control lives.** Default: the footer.
- **The Mailgun region and sender address.** Default: the US endpoint, and a
  sender on the Mailgun domain named in credentials. Needs the owner's
  account details before the contact task can be verified end to end.
- **Which model for route 2**, the daily budget and the per-session cap. v2.
  Inputs: section 7, Spanish quality, injection resistance.

## 12. Staging

| Stage | Contents | State |
|---|---|---|
| v0 | the shell: typed opening, commands, two languages, works without JavaScript | committed (d995227); replaced by v1 |
| v1 | the copy as the interface: reveal, contact line, invitation and wrapping field, fold and thread, source notes, fallback with suggestions; FAQ table with admin and seeds; transcript table with promote-to-FAQ; Spanish sections; contact form and mailer; footer language control | next; the launch candidate |
| v2 | route 2 behind the rate limit, session cap, daily budget and off switch; the facts page; the signed page token; the model decision | after v1 has collected real questions |

What survives from v0: the locale switch in `SiteController`, the GET form
that makes a line a URL, the Turbo Stream append, and the two-language test.
Everything named "shell" is deleted.

## 13. Test plan

- **Unit.** The matcher: accents, stopwords, threshold, ties, both
  languages, the language of the answer, and questions it must not claim.
  The seed set matches its own trigger phrases and a handful of
  paraphrases. The contact message's validations.
- **Integration.** A hit, a miss and a clicked suggestion over HTTP, with
  and without JavaScript; the folded page for a question in the URL; the
  locale rules and the footer control; every public page in Spanish; the
  transcript being written; promote; the rate limits and their 429 replies;
  the contact form sending one email, the honeypot sending none; the locale
  files agreeing.
- **System.** The reveal plays and a key completes it; typing anywhere lands
  in the field; a long question wraps; asking folds the copy and the arrow
  brings it back; Back after asking lands on a whole page; a suggestion
  sends; the contact panel opens, traps focus,
  sends and closes; and the whole surface at a real phone viewport under
  device emulation, where the Scanner Rule is asserted: the name, the email
  and the first line of proof are inside the first screen. The existing
  narrow-screen tests resize to 500px because Chrome refuses to go smaller;
  they move to emulation as part of v1.
- **Design.** The existing guards in `test/design/` stay the gate: no
  hardcoded colors, no preset branches, contrast on every pair in all eight
  surfaces. One guard is added: every preset's motion tokens land the copy
  inside the reveal budget.

## 14. Implementation map

| Piece | v0, to delete | v1 |
|---|---|---|
| interpreter | `app/services/shell.rb` | none; the matcher is a class method on the FAQ model |
| endpoint | `ShellController#show`, `GET /shell?line=` | `AskController#show`, `GET /ask?q=`: a Turbo Stream appending the exchange, or a redirect to `/?q=` |
| markup | `app/views/shell/` | `app/views/ask/`: the form, an exchange, the fallback, suggestions; `home/show` renders the copy |
| browser | `shell_controller.js` | `ask_controller.js` (type-anywhere, Enter, grow, fold, focus) and `contact_controller.js` (the panel) |
| styles | the shell block in `components.css` | the copy, the ask and the contact panel blocks in `components.css` |
| strings | `shell.*` in the locale files | `ask.*` and `contact.*` |
| content | `shell_opening`, `shell_whoami` | home sections, `ask_invitation` |
| language | the `lang` command | a footer control and a small controller that sets the cookie |
| contact | | a form object, `ContactMailer` with a retrying delivery job, SMTP settings from credentials |
| admin | | FAQ CRUD, transcripts list, promote action |

**Adding an answer:** the admin, no deploy. **Changing the copy:** the home
sections in the admin. **Changing the invitation:** the settings page.
