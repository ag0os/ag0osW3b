# Idempotent seeds. Run with: bin/rails db:seed
#
# Content below is public-safe copy curated from the private knowledge base.
# It is the website's own source of truth once seeded — edit it in /admin, not here.

# ---- Admin user -------------------------------------------------------------
email    = ENV.fetch("ADMIN_EMAIL", "agoos@hey.com")
password = ENV.fetch("ADMIN_PASSWORD", "change-me-please")

admin = User.find_or_initialize_by(email_address: email)
if admin.new_record?
  admin.password = password
  admin.save!
  puts "→ Created admin user #{email} (password: #{password.inspect} — change it!)"
else
  puts "→ Admin user #{email} already exists"
end

# ---- Sections (static, toggleable content blocks) ---------------------------
sections = [
  # Home
  { page: "home", key: "home_what_i_do", position: 1, heading: "What I do", body: <<~MD },
    - I build **AI-native software workflows and agent orchestration tools** — not just AI as autocomplete.
    - I turn vague product intent into **planned, tested, maintainable systems**.
    - I'm senior across **backend, full-stack, cloud, and AI-assisted delivery**.
  MD
  { page: "home", key: "home_featured", position: 2, heading: "Featured: Cosmonauts", body: <<~MD },
    **Cosmonauts** is an agent-first AI orchestration framework built on Pi. Declare agents,
    compose prompts and skills, and wire workflows that run automatically — as chains, drive
    runs, or side-by-side sessions.

    [View on GitHub →](https://github.com/ag0os/cosmonauts)
  MD
  { page: "home", key: "home_proof", position: 3, heading: "Selected proof", body: <<~MD },
    - Secure payment workflows for **hundreds of sports organizations**, thousands of daily transactions.
    - Expanded an **AWS SQS→Kafka** migration pattern for video platform workflows.
    - Cross-team Kanban features for an internal platform with **10,000+ daily active users**.
    - **45%** frontend bundle reduction; **30%** mainframe storage cut (~$50K/yr).
  MD

  # About
  { page: "about", key: "about_bio", position: 1, heading: nil, body: <<~MD },
    I'm a senior full-stack, product-minded software engineer based in San Isidro, Buenos Aires
    (GMT-3). My core background is Ruby/Rails, backend systems, cloud platforms, and product
    engineering across fintech/payments, video streaming, and enterprise tools.

    Before software, I spent 13 years as a DJ, music producer, and sound engineer — a creative,
    technical background I still draw on. I moved into IT and later into full-stack software
    engineering, and today my work combines strong engineering fundamentals with AI-native
    delivery: building agent harnesses, workflow systems, prompts, skills, and verification loops.

    I'm most interested in AI-forward product engineering, developer tools, agentic workflow
    consulting, and early-stage / founding engineering work.
  MD
  { page: "about", key: "about_how_i_work", position: 2, heading: "How I work", body: <<~MD },
    > AI doesn't remove the need for engineering judgment. It moves the judgment earlier:
    > into planning, architecture, tests, boundaries, and feedback loops.

    I care about both codebase health and agent workflow design — context, constraints, tests,
    verification, and maintainability.
  MD
  { page: "about", key: "about_languages", position: 3, heading: "Languages", body: <<~MD },
    - Spanish — native
    - Portuguese — native / bilingual
    - English — fluent
  MD

  # Work
  { page: "work", key: "work_open_source", position: 1, heading: "Open source", body: <<~MD },
    - **[Cosmonauts](https://github.com/ag0os/cosmonauts)** — agent-first AI orchestration framework built on Pi.
    - **[Claude Forge](https://github.com/ag0os/claude-forge)** — earlier Bun-based agent harness; predecessor to Cosmonauts.
    - **[Bright Tauri](https://github.com/ag0os/bright-tauri)** — early-stage React + Rust/Tauri app.
  MD
  { page: "work", key: "work_experience", position: 2, heading: "Selected experience", body: <<~MD },
    - **Senior Full-Stack Engineer** — Rails-based fintech/payment systems for a large sports technology platform; secure payment workflows for hundreds of organizations and thousands of daily transactions.
    - **Software Engineer, video streaming** — expanded an AWS SQS→Kafka migration pattern; improved subscription services (Apple/Google Play receipt validation, AWS Marketplace integrations).
    - **Full-Stack Developer, IBM** — internal platform with 10,000+ daily active users; reusable Vue components; 45% frontend bundle reduction.
    - **Mainframe automation / compliance lead, IBM** — 30% storage reduction, ~$50K/year saved.
  MD

  # Contact
  { page: "contact", key: "contact_intro", position: 1, heading: nil, body: <<~MD }
    I'm open to senior / founding product-engineering roles and AI-workflow consulting.
    The fastest way to reach me is email — or find me on LinkedIn and GitHub below.
  MD
]

sections.each do |attrs|
  Section.find_or_initialize_by(key: attrs[:key]).update!(attrs.merge(visible: true))
end
puts "→ Upserted #{sections.size} sections"

# ---- Sample post ------------------------------------------------------------
Post.find_or_initialize_by(slug: "welcome").update!(
  title: "Welcome",
  status: :published,
  published_at: Time.current,
  excerpt: "Why this site exists and what I'll write about here.",
  tags: "meta, ai",
  body: <<~MD
    This is the first note on a site I'll grow over time.

    I build **AI-native software workflows and agent orchestration tools**, grounded in years of
    Rails/backend product engineering. I'll write here about:

    - agent orchestration and AI-native software delivery
    - context engineering — prompts, skills, tools, and constraints
    - shifting human attention from line-by-line coding toward planning, architecture, and verification

    ```ruby
    # the kind of thing I think about
    def ship(intent)
      plan  = design(intent)
      tests = verify(plan)
      build(plan, guardrails: tests)
    end
    ```

    More soon.
  MD
)
puts "→ Upserted sample post (/writing/welcome)"
