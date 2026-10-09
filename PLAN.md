# v1 implementation plan

*Working document for the v1 stage of `ASK.md`. Delete it when v1 ships; git
remembers. Each task below is one commit that leaves `bin/rails test`,
`bin/rails test:system` and `bin/rubocop` green, and each can be reviewed on
its own. Sizes are rough: S is an hour or two, M half a day, L a day.*

## Sequencing

The order is chosen so that every task is visible the moment it lands and
nothing waits on a later task to make sense:

1. the shell comes out, on its own, so the largest deletion is reviewed
   apart from the largest addition;
2. the copy, because it is the page a scanner reads; the phone gate arrives
   with it, so every later task is checked against the Scanner Rule;
3. the question over HTTP, because the form, the fold and the fallback work
   end to end as plain page loads;
4. the invitation in the browser, which turns those page loads into the
   interface;
5. the matcher, because an invitation must answer on day one;
6. the seed set and the suggestions, which make it answer the questions
   people will actually ask;
7. the admin for answers, so they are edited rather than seeded;
8. transcripts, so the FAQ can grow from real questions;
9. Spanish, so the copy and every public page read in Spanish, not only
   their chrome;
10. the contact form on its own page, the one piece that needs an outside
    account;
11. the contact panel over the home page;
12. the rest of the phone-width tests;
13. the docs sweep.

Tasks 8, 9 and 10 are independent of each other; they can be reordered if
one is blocked on content or on credentials. After task 1 the home page is
its title and sections for one commit, and after task 2 it is a complete
page with no input, which is a state the PRD requires anyway.

## Decisions taken by default

Each of these is an open item in `ASK.md` §11, or a choice the PRD leaves to
the plan, resolved here so no task blocks. Override any by editing this list
before its task starts.

| Decision | Default | Why |
|---|---|---|
| Invitation wording | "Ask it anything about Agustin:" / "Preguntale lo que quieras sobre Agustin:" | the owner's line; it is a setting, so it changes without a deploy |
| What makes the invitation unmistakable | an always-visible write-on rule under the field, plus hint text | both survive without JavaScript and neither is a box; the cursor pulse from the spike iteration is added only if these fail in the browser |
| Recent-writing list on home | removed; the copy links to Writing in a sentence | the invitation has to be the last line |
| Cursor shape | a block in all four presets, drawn from `:root` tokens | the owner's words; the tokens leave room for a per-preset instrument later |
| Reveal | plays once per browser session | a page that performs on every return visit is the opposite of unhurried |
| Reveal budget | invitation in place within 1.2s, asserted per preset | "well under two seconds", with room for a slow device |
| Language control | two buttons in the footer | Spanish browsers already get Spanish; the control is for the exception |
| Spanish sections | three columns on `sections`: `body_es`, `heading_es`, `note_es` | smallest change; a locale table earns its keep only with a third language |
| Phone first screen | 390 by 664, the visible area of a 390 by 844 phone under browser chrome | the Scanner Rule is about what is seen, not about the glass |
| Transcript retention | ninety days, deleted by a recurring job | long enough to promote from, short enough to be a non-issue |
| IP addresses | never written raw; rate-limit keys are an HMAC of the IP under the app secret | Solid Cache is a database, and its keys would otherwise hold the address |
| Rate limit on `/ask` | thirty questions a minute per IP | generous for a person, tight for a script; only guards the transcript table until v2 |
| Rate limit on the contact form | five messages an hour per IP | nobody writes to him six times an hour |
| Contact messages | no table; a delivery job that retries transient failures, failed jobs purged nightly | no retention question, and a dead job does not keep a stranger's message forever |
| Production runtime | Solid Queue inside Puma on one server (`SOLID_QUEUE_IN_PUMA=1`); the proxy trusted so `remote_ip` is the visitor's | **deploy prerequisites, outside this repo, before tasks 8 and 10 mean anything in production**: without the first no recurring job or mail runs, without the second every visitor shares one rate limit |
| Mailgun | US endpoint `smtp.mailgun.org:587`; login and sender address under `mailgun` in credentials | **needs the owner's account for task 10's production smoke check** |
| Seed answers and Spanish copy | drafted from the existing sections, for Agustin to correct in the admin | the voice is already on the page |

## Tasks

### 1. The shell comes out (M)

*PRD §4.8, §11, §12.* Nothing new on the page yet: the home page is its
title, its sections and its post list, and the language control replaces
`lang`.

- Delete the shell: `app/services/shell.rb`, `ShellController`, the `shell`
  route, `app/views/shell/`, `shell_controller.js`, `ShellHelper`, the four
  shell test files, the `shell.*` locale keys, `shell_opening` and
  `shell_whoami` in `SiteSetting::DEFAULTS`, the shell block in
  `components.css`, and the comments that mention it in `SiteController`,
  `theme_controller.js` and `themes.css`. `home/show` and `HomeController`
  drop the shell and its `@opening` and `@exchanges`.
- A data migration deletes the stored `shell_opening`, `shell_whoami` and
  `shell_whoami_es` setting rows, in SQL so it does not depend on the model.
  Seeds are not a deploy step; a migration is.
- Language: `LocalesController#update` sets the `locale` cookie and redirects
  back; `resource :locale, only: :update`; two `button_to`s in
  `shared/_footer`. The locale tests move from `test/integration/shell_test.rb`
  to `test/integration/locale_test.rb` (cookie, `Accept-Language`, fallback,
  admin stays English, the two files agree).
- `AGENTS.md`: the shell section, already stale, becomes a pointer to
  `ASK.md` so no agent builds on a shell that is gone. Task 13 writes the
  full section.
- Tests: the locale tests above, the footer control switching language over
  HTTP, and the migration leaving other settings alone. The layout and theme
  system tests are untouched: the home page still has its headings and its
  post list.
- Done when the home page renders without the shell, the footer switches
  language, and `grep -ri shell app test config` finds nothing.

### 2. The copy (L)

*PRD §4.1, §4.2, §4.10, the Scanner Rule.* The home page becomes the copy,
arriving with life.

- `db/seeds.rb`: the home sections rewritten as first-person prose in this
  order: `home_proof`, `home_intro` (the bio the shell's `whoami` held),
  `home_featured`, `home_contact` (availability, email, and a sentence
  linking to Writing). Headings stay as names. The seeds delete
  `home_what_i_do`, whose content folds into the others; sections are
  content, so on a deployed database this is an edit in the admin.
- `app/views/home/show.html.erb`: the contact line (the name, email, GitHub,
  a "contact" link to `contact_path`), the title, then `home/_copy`
  rendering each section's body, as `.prose`, and its note, without its
  heading. The recent-posts block goes, and `@recent_posts` with it.
- The reveal: the copy's blocks take the existing `.enter` stagger. The
  pre-paint script in `layouts/application.html.erb` adds a `revealed` class
  when `sessionStorage` says it has played; a small `reveal_controller.js`
  completes it on the first key or pointer press and records that it played.
  All hiding is behind the `js` class and the reduced-motion query.
- `components.css`: a copy block and the contact line; `.hero__title::after`
  goes, so terminal no longer blinks a cursor on the title (task 3 gives the
  page its one cursor). Keep the `blink` keyframes and `--cursor-anim` for
  the end mark.
- Fixtures, because the home page no longer has an `h2` or a post list and
  no other page has sections in test: `test/fixtures/sections.yml` puts
  `home_proof` first, keeps a marked phrase in a home body and keeps the
  hidden section, and gains two About sections, one with a heading, a note
  and a marked phrase, one with neither heading nor note.
- The system tests that leaned on the home page are rebuilt on the pages
  that carry the elements. In `layout_test.rb`: the shared-edge test checks
  `h1` and the copy on home, `h1`, `h2` and `.prose` on About, `h1` and the
  post-list link on Writing; the margin-note test moves to About; the mark
  and reading-measure tests stay on home. In `theme_switching_test.rb`, the
  rhythm test visits About, where `section_spacing` finds its `h2`.
- New tests: integration asserts the home page carries the contact line, the
  title and every visible home section body, and no section heading;
  `test/design/stylesheet_test.rb` gains the reveal budget (four staggers
  plus `--dur-enter` within 1.2s in every preset); system asserts a key
  completes the reveal and that it does not replay in the same session.
- The phone gate: `test/phone_system_test_case.rb`, a second base class
  driving headless Chrome with device metrics at 390 by 664, and the Scanner
  Rule on it: on load, with no input, the name, the email link and the first
  line of the proof paragraph are inside the first screen, in all four
  presets.
- Done when a fresh visit shows the contact line, the title and the prose
  arriving inside the budget in all four presets, and the Scanner test
  passes at phone size.

### 3. The question over HTTP (M)

*PRD §4.3, §4.4, §4.9, §5.3.* The last line takes a question and the page
comes back folded with the fallback. No JavaScript in this task.

- `SiteSetting::DEFAULTS`: `ask_invitation` and `ask_invitation_es`.
- `get "ask", to: "ask#show"`. `AskController < SiteController` cleans `q`
  with the rule `Shell#clean` had, copied from `d995227` since task 1
  deleted it (control characters to spaces, squeezed, capped at 280),
  redirects home on a blank one, and otherwise redirects to
  `root_path(q:, anchor: "thread")`. `HomeController` reads `q`, cleans it
  the same way and renders the folded state with that one exchange. Every
  question gets the fallback for now.
- `app/views/ask/`: `_form` (the `<label>`, a one-row `<textarea name="q">`
  with `enterkeyhint="send"` and the hint "type a question" as placeholder,
  the cursor span hidden from assistive tech, a visible "Ask" button),
  `_exchange` (rail note, the question as an `<h2>`, the answer),
  `_fallback`.
- `home/show`: the contact line and the `<h1>` sit outside the fold, so a
  folded page still has its heading; folded, the `<h1>` is visually hidden.
  The rest of the copy sits in a `<details open>` whose `<summary>` is the
  arrow, in the flow directly under the contact line and hidden until a
  question has been asked; then `#thread` (`role="log"`, polite); then the
  form. One form and one field for the whole page: before a question it
  reads as the copy's last line, after one its label is "Anything else?".
  With `q` in the URL the server renders `<details>` closed. The form takes
  the capped fifth stagger delay, so it arrives with the last block of the
  copy and not ahead of the prose.
- `components.css` and `themes.css`: the ask block, all of it CSS. The field
  grows on the label's line by `field-sizing: content`, then moves below it
  and wraps at the full measure; where that is unsupported it starts on the
  line below. The write-on rule, the hint, the block cursor from `:root`
  tokens while the field is empty, the accent caret after. Focus turns the
  rule into the focus indicator.
- Locale files: the follow-up label, the hint, the button, the fallback, the
  "not on the page" note, the fold's labels, the thread's label.
- Tests: integration for the invitation text from the setting in both
  languages, the redirect and the folded page with its `<h1>`, a blank and
  an over-long question, and a `/?q=` reload showing the same one exchange.
- Done when, with JavaScript off, a typed question and the "Ask" button
  bring back the folded page with the fallback under the question's own
  heading, and the arrow restores the copy.

### 4. The invitation in the browser (M)

*PRD §4.3, §4.4.* The same question, answered in place.

- The form gains `data-turbo-stream`, so its GET asks for a stream.
  `AskController` answers one with `show.turbo_stream.erb`: append the
  exchange to `#thread`, swap the label.
- `ask_controller.js`: Enter submits and never inserts a newline; the hint
  gains ", press Enter"; the `js` class visually hides the "Ask" button.
  Type-anywhere takes one printable character, with no modifier and not
  Space, and never while focus is in an editable element or a dialog. On a
  settled submit it clears the field, keeps focus, closes the fold, and
  scrolls the new question under the header, inside a view transition where
  one is available and motion is allowed.
- The home page sets `turbo-cache-control: no-cache`, so Back restores a
  whole fresh page instead of a folded one with its thread stripped.
- `components.css`: the contact line pins under the header at widths where
  the header is one row; the arrow does not.
- Tests: integration for a stream for a question; system for typing anywhere
  and its exclusions, Enter folding the copy, the arrow bringing it back, a
  long question wrapping without sideways scroll, and `go_back` after asking
  landing on an unfolded page with the invitation as its label.
- Done when a typed question folds the copy and gets the fallback in place,
  focus stays in the field, and Back and return both start fresh.

### 5. The matcher (L)

*PRD §5.1, §5.3, §4.7.* Questions get answers.

- Migration `create_answers`: `question_en`, `question_es`, `patterns_en`,
  `patterns_es` (text, one phrase per line), `answer_en`, `answer_es`
  (Markdown), `source_key` (string, nullable), `suggested` (boolean, default
  false), `position` (integer), `hits` (integer, default 0), timestamps.
- `app/models/answer.rb`: validations, `scope :suggested`, `ordered`,
  `Answer.normalize(text, locale)` and `Answer.match(text)`. Normalisation:
  `I18n.transliterate`, downcase, split on non-letters, drop a short stopword
  list per locale (in the model, not a gem). No stemming: a suffix rule that
  joins "rate" and "rates" also joins "new" and "news", so a plural is a
  second phrase in the admin. Scoring: for each phrase and each `question_*`
  in either language, the Dice score of its tokens against the input's
  (twice the overlap over the two counts), so a one-word phrase cannot claim
  a long question; best above `0.6` wins; ties by `hits`, then `position`,
  then the language that is `I18n.locale`, then id. `match` returns the
  entry and the locale of the phrase that won, or nil, and changes nothing;
  `hit!` increments.
- `AskController` and `HomeController`: a match renders the answer in the
  matched locale through `MarkdownRenderer`; a miss renders the fallback.
  The rail note is "from" plus the source section's
  `heading.presence || t("nav.#{page}")`; a nil `source_key`, or one naming
  no section, gets no note. Only `AskController` counts the hit.
- Seeds and `test/fixtures/answers.yml`: three entries in both languages,
  third person, the three that task 6 will flag as suggested, so the page
  answers something the day this lands.
- Tests: unit for normalisation (accents, stopwords, and "news" not matching
  "new" nor "rails" "rail"), scoring, threshold, each step of the tie order,
  a canonical question matching itself, a Spanish question answered in
  Spanish on the English site, and "interest rates in Argentina" not getting
  the rates answer. Integration for a hit and a miss through `/ask`, as a
  redirect and as a stream, and for `/?q=` with a matching question
  rendering the answer and its source note through `HomeController` while
  counting no hit.
- Done when "what has he built?" and "¿qué construyó?" both answer with
  their source in the margin, on `/ask` and on a `/?q=` URL, and a nonsense
  line still gets the fallback.

### 6. The seed set and the suggestions (M)

*PRD §5.1, §4.5.* The page answers what people will actually ask, and says
what it can answer when it cannot.

- Seeds: the other twelve entries from the PRD, third person, drafted from
  the existing sections in both languages; three of the fifteen
  `suggested`. "How do I reach him?" links to the contact page.
- `app/views/ask/_suggestions.html.erb`: up to three chips, each its own GET
  form to `/ask` with a hidden `q` and `data-turbo-stream`. A button on the
  page's form would submit beside the empty textarea's `q`, and the blank
  one wins. Rendered under the fallback and nowhere else.
- Tests: the seed set, loaded in the test, matches each of its own phrases
  and a handful of paraphrases in both languages; no English seed answer
  contains a first-person "I"; integration for a chip clicked through
  `rack_test`; system for tapping a chip.
- Done when a nonsense line gets the fallback with three chips, and a chip
  answers with JavaScript on and off.

### 7. Answers in the admin (M)

*PRD §5.1, §14.* No more seeding to change an answer.

- `resources :answers, except: :show` under `admin`, with `patch :toggle`
  on the member for `suggested`. `Admin::AnswersController` and views,
  modelled on sections: index ordered by position with hit counts, new,
  edit, destroy, the source as a select of section keys.
- An "Answers" link in the nav of `layouts/admin.html.erb`, and the
  dashboard count.
- Tests: the existing admin CRUD pattern in `site_flow_test.rb`.
- Done when an answer can be added, edited, marked suggested and removed
  from `/admin/answers`, reached from the admin nav.

### 8. Transcripts (L)

*PRD §5.4, §6, §8.* The flywheel, and the only guard the free route needs.

- Migration `create_exchanges`: `session_token`, `locale`, `input`,
  `route` (integer), `answer_id` (nullable), `reply` (text), `tokens_in`,
  `tokens_out`, `cost_cents` (nullable, for v2), timestamps. Index on
  `created_at`.
- `app/models/exchange.rb`: `enum :route` (`faq`, `fallback`, `model`),
  `belongs_to :answer, optional: true`, presence of `input`, and an
  `expired` scope for rows older than ninety days. A fixture file with one
  row per route.
- `AskController`: writes one row per question; a random session token in a
  browser-session cookie.
- The rate limit: `rate_limit to: 30, within: 1.minute`, keyed `by:` an HMAC
  of `request.remote_ip` under the app secret (one private method on
  `SiteController`, reused by task 10). Over the limit the reply is the
  "email him" line with status 429, as a stream or as the folded page, and
  it writes no row and counts no hit. The limiter's `store:` is the cache in
  production and a dedicated `MemoryStore` in test, cleared in `setup`: the
  test cache is a null store that never counts, and every test arrives from
  127.0.0.1.
- `config/initializers/filter_parameter_logging.rb`: add `/\Aq\z/`, so
  questions stay out of the request log. A bare `:q` would also filter
  "request".
- `config/recurring.yml`: under `production:`, a nightly command,
  `Exchange.expired.delete_all`.
- `resources :exchanges, only: :index` under `admin`, a "Transcripts" link
  in the admin nav. `Admin::ExchangesController#index`: newest first,
  grouped by session, with route and reply. "Promote to FAQ" is a link to
  `new_admin_answer_path(exchange_id:)`, which opens the new-answer form
  prefilled with the input as question and first phrase in the exchange's
  locale and saves nothing until the other language is filled in. Visitor
  text is escaped everywhere it is shown.
- Tests: unit for the enum, the optional answer and the scope; a row is
  written for a hit and for a miss, and none for a page rendered from
  `/?q=`; the rate limit trips with 429 and no row, and recovers; the
  retention command deletes only old rows, and `recurring.yml` holds it
  under `production:`; promote opens a prefilled form and creates nothing.
- Done when a question typed on the site appears in `/admin/exchanges` and
  one click opens it as a new answer ready to complete.

### 9. Spanish (L)

*PRD §4.8, §8.* Every public page reads in Spanish, copy and chrome.

- Migration: `body_es`, `heading_es`, `note_es` on `sections`.
- `Section#localized(:body)` and siblings, falling back to English;
  `home/_copy`, `shared/_section` and the answer's source note use them.
- Admin section form gains the three fields.
- Seeds: Spanish for every seeded section, drafted for correction.
- The strings still literal in English move to the locale files:
  - layout chrome: the footer's "Elsewhere" label and "Email" link, the
    theme-control labels;
  - `pages/*`: every page title and `<h1>`, the Work subtitle, the About
    and Work empty states;
  - `posts/index`: the title, `<h1>`, subtitle and empty state;
  - `posts/show`: the "All writing" link;
  - dates in `posts/index` and `posts/show`, through `l` with named formats
    and Spanish month names in `es.yml` (no `rails-i18n` gem);
  - the feed: its `language` from the locale, its title, and its subtitle
    from the localized tagline, unmarked.
- Tests: fallback when a Spanish field is blank. One integration test
  requests every public page in Spanish (home, About, Work, Writing with and
  without posts, a post, Contact, the feed) and fails if any English value
  from `en.yml` whose Spanish differs appears in the response. One static
  test reads every public template and partial and fails on a literal word
  in text or in an `aria-label`, `title`, `placeholder` or `alt`, outside a
  short list of proper nouns, so a string this list missed, or one added
  later, cannot pass.
- Done when the whole site reads in Spanish after the footer control except
  posts, which stay as written, and both tests above pass.

### 10. The contact form (M)

*PRD §4.6, §6.* The Contact page sends an email. No JavaScript in this task.

- `app/models/contact_message.rb`: an `ActiveModel::Model` with `name`,
  `email` and `message`; presence, an email format, a length cap on each.
- `post "contact", to: "contact_messages#create"`.
  `ContactMessagesController < SiteController`: `rate_limit to: 5, within:
  1.hour`, keyed and stored as in task 8, answering 429 inside the form's
  frame; a filled honeypot field gets the "received" reply and sends
  nothing; a valid message goes to
  `ContactMailer.inquiry(name, email, message).deliver_later`, as strings;
  an invalid one re-renders the form with 422. The form lives in a Turbo
  Frame, so the reply replaces it in place.
- `ContactMailer#inquiry`: plain text only, to `SiteSetting["email"]`,
  reply-to the visitor, from the sender in credentials, falling back to the
  site email where there are none. `ApplicationMailer`'s default `from`
  stops being `from@example.com`.
- Delivery: `ContactMailer.delivery_job` is a small subclass of
  `ActionMailer::MailDeliveryJob` with `retry_on` for SMTP and timeout
  errors, because neither the stock job nor Solid Queue retries. A nightly
  command in `recurring.yml`, under `production:`, discards failed contact
  jobs, so a dead one does not keep the message.
- `config/environments/production.rb`: SMTP delivery to Mailgun with the
  login from `credentials.dig(:mailgun, ...)`, and delivery errors raised so
  the job sees them. No gem.
- `filter_parameter_logging.rb`: add `:message`.
- Views: `contact_messages/_form` and `_received`; `pages/contact` renders
  the form in its frame. Locale files: `contact.*` in both languages.
- Tests: unit for the validations; integration, with jobs performed, for one
  message in `ActionMailer::Base.deliveries` with the right recipient and
  reply-to after a form post through `rack_test`, none for the honeypot, 422
  for a blank message, 429 over the limit; the delivery job retries a
  transient SMTP error; `recurring.yml` holds the purge; a mailer test and
  preview.
- Done when, in the test environment, a message posted from the Contact
  page with JavaScript off lands in the test mailbox with the visitor as
  reply-to.
- Production smoke check, manual, once the owner's Mailgun credentials are
  in: send one message from the live Contact page and see it arrive. It is
  a release step, not a gate on this commit.

### 11. The contact panel (M)

*PRD §4.6, §9.* "Contact" slides the same form in over the home page.

- The home page renders `contact_messages/_form` in its frame inside a
  `<dialog>`. `contact_controller.js` opens it with `showModal` for links
  to the contact page inside `main` only, so the nav's Contact still
  navigates, closes it, and returns focus to the link that opened it.
- `components.css`: the panel, in from the inline end, up from the bottom
  below the fold breakpoint, still under reduced motion. It reads the card
  and form tokens; nothing new in `themes.css`.
- Tests, system: the panel opens from the contact line and from a contact
  link inside an answer; the nav link does not open it; focus is trapped,
  so Tab from the last control and Shift+Tab from the first stay inside the
  dialog and never reach the page behind; Escape closes it and returns
  focus; a sent message shows the received state in place and delivers one
  email.
- Done when a message can be written and sent from the panel without
  leaving the home page, and the page behind it cannot be reached by
  keyboard while it is open.

### 12. Phone-width tests (S)

*PRD §3, §13.* Chrome refuses to resize a window below 500px, so the narrow
cases in `layout_test.rb` measure a tablet. Task 2 brought the base class
and the Scanner Rule; this finishes the move.

- Move the two narrow assertions in `layout_test.rb` onto
  `PhoneSystemTestCase` and add the front door: no horizontal scroll, a long
  question wraps, the chips wrap, the contact panel fits and comes from the
  bottom.
- Done when the suite fails if any part of the front door overflows a phone.

### 13. Docs sweep (M)

- `AGENTS.md`: the pointer from task 1 becomes the section: the copy from
  home sections, `AskController`, `Answer` and `Exchange`, the contact form
  and mailer, the footer language control, the recurring jobs, the new test
  files.
- `DESIGN.md`: the shell component section becomes the copy, the invitation
  and the contact panel; the focus exception and the Scanner Rule are
  restated; the display-size note stops mentioning the shell.
- `README.md`: the paragraph about the shell describes the page that
  answers, and points at `ASK.md`.
- `ROADMAP.md`: the shell entry shrinks to the v2 pointer; "A shell as the
  front door" joins Rejected with the reason; the two model rejections point
  at `ASK.md`.
- `ASK.md`: §12 marks v1 shipped; §11 moves the defaults above into "made".
- Delete `SHELL.md`. Confirm nothing named shell is left in `app`, `test` or
  `config`; task 1 removed the code, this is the check.
- Delete this file.

## Out of scope for v1

Everything in `ASK.md` §5.2 and the model-facing parts of §6: the
`anthropic` gem, the facts page, the schema, the daily budget, the session
cap, the signed page token, `agent_enabled`. The transcript table and the
fallback reply are built so v2 slots into them without touching the shape.
Also out: a thread that survives navigation, storing contact messages, and
per-preset cursor shapes.
