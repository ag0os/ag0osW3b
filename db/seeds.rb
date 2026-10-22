# Idempotent seeds. Run with: bin/rails db:seed
#
# Content below is public-safe copy curated from the private knowledge base.
# It is the website's own source of truth once seeded: edit it in /admin, not here.

# ---- Admin user -------------------------------------------------------------
# The repo is public, so the default password is too: production must set its own.
email = ENV.fetch("ADMIN_EMAIL", "agoos@hey.com")
password = if Rails.env.production?
  ENV["ADMIN_PASSWORD"].presence || raise("Set ADMIN_PASSWORD to seed production: the default admin password is public.")
else
  ENV.fetch("ADMIN_PASSWORD", "change-me-please")
end

admin = User.find_or_initialize_by(email_address: email)
if admin.new_record?
  admin.password = password
  admin.save!
  if Rails.env.production?
    puts "→ Created admin user #{email}"
  else
    puts "→ Created admin user #{email} (password: #{password.inspect}, change it!)"
  end
else
  puts "→ Admin user #{email} already exists"
end

# ---- Sections (static, toggleable content blocks) ---------------------------
sections = [
  # Home
  { page: "home", key: "home_what_i_do", position: 1, note: "The tools are new. The judgment is not.", heading: "What I do", body: <<~MD },
    - I automate the software development lifecycle (SDLC) with agents: plans and context, orchestration, review, and the verification that makes the output trustworthy.
    - I turn vague product intent into ==planned, tested, maintainable systems==.
    - I'm senior across **backend, full-stack and cloud**: Ruby on Rails as my production backbone, TypeScript across my own tooling.
  MD
  { page: "home", key: "home_featured", position: 2, note: "Built it because I needed it.", heading: "Shepherd", body: <<~MD },
    **Shepherd** is what I run every day: one agent per project that keeps the context, tracks the work across sessions and runs the other agents, on Claude Code or Codex. I run a flock of them. It lives in Troupe, my agent toolkit.

    [Troupe on GitHub →](https://github.com/ag0os/troupe)

    Before Shepherd I built **Cosmonauts**, an agent orchestration framework with verification inside the pipeline.

    [Cosmonauts on GitHub →](https://github.com/ag0os/cosmonauts)
  MD
  { page: "home", key: "home_proof", position: 3, note: "Numbers, not adjectives.", heading: "Selected proof", body: <<~MD },
    - Secure payment workflows for **hundreds of sports organizations**, thousands of daily transactions.
    - Expanded an **AWS SQS→Kafka** migration pattern for video platform workflows.
    - Cross-team Kanban features for an internal platform with **10,000+ daily active users**.
    - **45%** frontend bundle reduction; **30%** mainframe storage cut (~$50K/yr).
  MD

  # About
  { page: "about", key: "about_bio", position: 1, note: "San Isidro, GMT-3.", heading: nil, body: <<~MD },
    I'm a software engineer based in Buenos Aires, Argentina (GMT-3). 17 years in IT, 7 in software engineering, across payments, video streaming and enterprise platforms. Ruby on Rails as my production backbone, TypeScript across my own tooling. Claude Certified Architect (Foundations).

    Before software, I spent 13 years as a DJ, music producer, and sound engineer, a creative, technical background I still draw on. I moved into IT and later into full-stack software engineering, and today my work combines strong engineering fundamentals with AI-native delivery: building agent harnesses, workflow systems and verification loops.

    In 2024 the tools changed and I stopped writing code by hand. I spent the next year working out what this way of working needed from me, and since 2025 I build that into systems of my own. I'm interested in roles building agent systems and AI-native products, and I help teams set up the same way of working: [consulting](/consulting).
  MD
  { page: "about", key: "about_how_i_work", position: 2, note: "This is the whole argument.", heading: "How I work", body: <<~MD },
    > AI doesn't remove the need for engineering judgment. It ==moves the judgment earlier==:
    > into planning, architecture, tests, boundaries, and feedback loops.

    I care about both codebase health and agent workflow design: context, constraints, tests,
    verification, and maintainability.
  MD
  { page: "about", key: "about_languages", position: 3, heading: "Languages", body: <<~MD },
    - Spanish: native
    - Portuguese: native / bilingual
    - English: fluent
  MD

  # Work
  { page: "work", key: "work_open_source", position: 1, note: "All of it public.", heading: "Open source", body: <<~MD },
    - **[Troupe](https://github.com/ag0os/troupe)**. My agent toolkit, begun in 2025 as a fork of a workshop project. Home of Shepherd, the agent per project I run every day.
    - **[Cosmonauts](https://github.com/ag0os/cosmonauts)**. Agent orchestration framework, 2026, the predecessor of Shepherd. Development is paused.
    - **[Bright Tauri](https://github.com/ag0os/bright-tauri)**. Early-stage React + Rust/Tauri app.
  MD
  { page: "work", key: "work_experience", position: 2, note: "Most of the rest is private.", heading: "Selected experience", body: <<~MD },
    - **Senior Full-Stack Engineer**. Rails-based fintech/payment systems for a large sports technology platform; secure payment workflows for ==hundreds of organizations== and thousands of daily transactions.
    - **Software Engineer, video streaming**. Expanded an AWS SQS→Kafka migration pattern; improved subscription services (Apple/Google Play receipt validation, AWS Marketplace integrations).
    - **Full-Stack Developer, IBM**. Internal platform with 10,000+ daily active users; reusable Vue components; 45% frontend bundle reduction.
    - **Mainframe automation / compliance lead, IBM**. 30% storage reduction, ~$50K/year saved.
  MD

  # Consulting
  { page: "consulting", key: "consulting_intro", position: 1, heading: nil, body: <<~MD },
    I'm a software engineer. Since 2025 I build the systems that let agents write good software, and I help teams do the same. In 2024 I stopped writing code by hand.
  MD
  { page: "consulting", key: "consulting_agentic", position: 2, heading: "1. Agentic development for software teams", body: <<~MD },
    Your developers already have Claude Code, Codex or Cursor. Getting real work
    out of them is a different thing. I help teams set up how they work with
    agents:

    - Plans before code, and context the next agent can pick up.
    - Review by a different model, so one agent checks another.
    - Coordination when many agents work at once, across several projects.
    - The engineering basics built into the system: tests that mean something,
      a codebase the next person can read, tech debt caught early.

    This is how I work every day, with Shepherd: one agent per project that
    keeps the context, tracks the work and runs the other agents. It is part of
    Troupe, which is public: [github.com/ag0os/troupe](https://github.com/ag0os/troupe).
  MD
  { page: "consulting", key: "consulting_systems", position: 3, heading: "2. Building AI-native systems", body: <<~MD },
    You know your domain. I know how to turn that knowledge into a system that
    works: agents, tools and the checks that make the output trustworthy. I can
    help you design it and build it.
  MD
  { page: "consulting", key: "consulting_background", position: 4, heading: "Background", body: <<~MD },
    16+ years in IT, 6+ in software engineering, across payments, video
    streaming and enterprise platforms. Ruby on Rails, TypeScript. Claude
    Certified Architect (Foundations).
  MD

  # Contact
  { page: "contact", key: "contact_intro", position: 1, note: "I answer email.", heading: nil, body: <<~MD }
    I'm open to roles building agent systems and AI-native products, and to [consulting](/consulting) for teams adopting agents and automating their SDLC.
    The fastest way to reach me is email, or find me on LinkedIn and GitHub below.
  MD
]

# Each section's Spanish, by key. fetch, so a seeded section without its
# Spanish fails here rather than showing English on the Spanish site.
spanish = YAML.load_file(Rails.root.join("db/seeds/sections_es.yml"))

sections.each do |attrs|
  Section.find_or_initialize_by(key: attrs[:key]).update!(attrs.merge(spanish.fetch(attrs[:key]), visible: true))
end
puts "→ Upserted #{sections.size} sections"
