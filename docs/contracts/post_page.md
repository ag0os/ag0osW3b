---
component: post_page
covers:
  - app/views/posts/show.html.erb
depends_on:
  - markdown_renderer
tests:
  - test/contract/post_page_contract_test.rb
---
Coverage: 1 obligation; 1 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: the post page

The public post at `/writing/:slug` renders through the site layout.

## The head

### PP-1 Descriptions are the unmarked excerpt, escaped once

When a post has an excerpt, its description and Open Graph description are that excerpt with `==marks==` removed and HTML escaped exactly once, preserving literal entity text.

**Reason.** Writing travels through link previews, and double escaping makes an excerpt such as `a < b ==c==` read as `a &lt; b c` instead of `a < b c` (pilot finding F-19).

Kind: functional. Proof: test, PP-1 in `test/contract/post_page_contract_test.rb`.
