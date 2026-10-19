# Decisions: seeded copy

Why the seeded copy works the way it does, with the derivation behind each choice. The obligations are in `docs/contracts/seeded_copy.md`.

### D-28. The Spanish copy lives in one file, which the seeds and a fill-the-blanks migration both read

**Decision.** The Spanish for every seeded section is in `db/seeds/sections_es.yml`, keyed by section key. `db/seeds.rb` merges it into each section and fails on a seeded key the file lacks. The `FillSpanishSections` migration reads the same file and writes each field only where the database's field is blank.

**Derivation.** Production was seeded before there was any Spanish, and seeds are not a deploy step. Running them again would put the seeded English back over the owner's edits in `/admin`, since they upsert every field. A migration runs with the deploy, the same way `RemoveShellSettings` (D-13) carried a settings change to production. Filling only blank fields lets it run against a database the owner has already touched without overwriting anything they wrote, in either language. Keeping the copy in one file, rather than in the seeds and again in the migration, means there is one draft to correct. The migration defines its own model, so it does not depend on `Section` as the app later changes it. The owner chose the migration over pasting the Spanish into `/admin` by hand on 2026-10-19. The drafts translate the seeded English, so any English the owner changed in `/admin` before this deploy should be checked against its Spanish. Obligations: SC-7, SC-8.
