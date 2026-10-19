# Decisions: retiring the shell's settings

### D-13. A data migration, in SQL, for exactly three keys, with a no-op rollback

**Decision.** `RemoveShellSettings` runs one `DELETE` against `site_settings` for the three keys by name. `down` does nothing.

**Derivation.** Removing the defaults from `SiteSetting::DEFAULTS` is not enough: `all_settings` merges stored rows over the defaults, so the original Settings form kept all three as live fields after the owner saved them. Since CO-2, Settings uses an explicit allowlist and no longer lists every stored key. The migration still removes retired values from the database; DM-4's absence of editor fields now also holds independently of the migration. Seeds are not run on deploy, so the change has to be a migration. It names the table and not the model because the model is application code that keeps changing after the migration is written. It names the keys rather than a `shell_%` pattern because a pattern is a guess about rows nobody has looked at. Rollback restores nothing because the rows held copy for a component that is gone; raising `IrreversibleMigration` instead would only stop someone rolling back past it for an unrelated reason. Obligations: DM-1 to DM-4.
