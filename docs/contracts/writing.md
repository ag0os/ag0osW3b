---
component: writing
covers:
  - app/controllers/posts_controller.rb
  - app/views/posts/index.html.erb
  - app/views/posts/feed.atom.builder
  - app/views/shared/_header.html.erb
  - app/views/layouts/application.html.erb
  - config/routes.rb
depends_on:
  - markdown_renderer
tests:
  - test/contract/writing_contract_test.rb
---
Coverage: 5 obligations; 5 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: writing

Where the writing shows before there is any, and the addresses it answers at. A post counts as published when `Post.published` includes it: status published, with a publication date.

## The nav

### WR-1 Writing is in the nav only while something is published

The header's primary nav links to Writing only while at least one post is published, in both languages. With only drafts, or no posts at all, the link is absent; the first published post brings it back with no setting to change. The home page's Writing block follows the same rule (HP-3).

**Reason.** The owner decided on 2026-10-14 that Writing appears by itself when the first post is published, and a nav link to an empty page is a promise the site cannot keep yet. (D-15)

Kind: functional. Proof: test, the four tests named WR-1 in `test/contract/writing_contract_test.rb`.

## The addresses

### WR-2 /writing answers with its empty state

`/writing` stays public and answers 200 with nothing published, showing the editable empty state, whose default is "First essays coming soon." and no post list. Without a nav link (WR-1) it is reached only by its address.

Reworded 2026-10-19 by Copy admin; flagged for owner review.

**Reason.** The address may already be shared or bookmarked, and a 404 there reads as a broken site. (D-15)

Kind: functional. Proof: test, WR-2 in `test/contract/writing_contract_test.rb`.

### WR-3 /feed answers with a valid, empty feed

`/feed` stays public and answers 200 with nothing published: a valid Atom feed (`application/atom+xml`, with an `id`, a `title` and an `updated`) and no entries.

**Reason.** Feed readers poll it, and an error or a malformed document can make a reader drop the subscription before the first post arrives. (D-15)

Kind: functional. Proof: test, WR-3 in `test/contract/writing_contract_test.rb`.

### WR-5 /feed.xml is the same feed; any other format is no address

`/feed.xml` answers 200 with the same document as `/feed`: the same Atom feed, served as `application/atom+xml`, whose self link is `/feed`. A request for the feed in any other format (`/feed.json`, `/feed.rss`, `/feed.html`) answers 404. No format answers with a server error.

**Reason.** `/feed.xml` is an address feed readers and people try when they look for a feed, and it answered 500 in production because only an Atom template exists. A 500 tells a reader the site is broken; a 404 tells it the address does not exist, which for a format the site has no feed in is true. (D-26)

Kind: functional. Proof: test, the two tests named WR-5 in `test/contract/writing_contract_test.rb`.

## The head

### WR-4 The head links to the feed whether or not anything is published

The site layout's head links to the feed (`<link rel="alternate" type="application/atom+xml">`) whether or not anything is published.

**Reason.** The link is for feed readers, not visitors: it adds nothing to the page, and a subscription taken early delivers the first post when it lands. The empty feed is valid (WR-3). Provisional default, pending the owner's decision. (D-16)

Kind: functional. Proof: test, WR-4 in `test/contract/writing_contract_test.rb`.

## Decisions

- D-30 and D-31, `docs/decisions/copy.md`: editable prose and its unchanged defaults.

- D-15, `docs/decisions/writing.md`: Writing hides itself by asking whether anything is published (WR-1 to WR-3).
- D-16, `docs/decisions/writing.md`: the feed link stays in the head when nothing is published, provisional (WR-4).
- D-26, `docs/decisions/writing.md`: the feed answers at `.atom` and `.xml`, and every other format is a 404 (WR-5).
