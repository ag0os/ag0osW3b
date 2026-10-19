---
component: remove_shell_settings
covers:
  - db/migrate/20261009120000_remove_shell_settings.rb
depends_on: []
tests:
  - test/contract/remove_shell_settings_contract_test.rb
---
Coverage: 4 obligations; 4 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: retiring the shell's settings

A data migration removes the shell's three settings. Seeds are not a deploy step; a stored override outlives its removed default.

### DM-1 Delete only the three shell keys

One migration, `db/migrate/<timestamp>_remove_shell_settings.rb`, defining `RemoveShellSettings`, deletes the rows whose key is `shell_opening`, `shell_whoami` or `shell_whoami_es`, and changes no other row.

**Reason.** A stored row outlives its default, so removing the defaults alone leaves retired shell values in the database. Settings formerly listed every stored key; CO-2 now restricts its fields to an allowlist, so the migration is still needed to remove the values even though they no longer appear as fields. (D-13)

Kind: functional. Proof: test, DM-1 in `test/contract/remove_shell_settings_contract_test.rb`.

### DM-2 Repeatable and safe to roll back

It runs cleanly on a database that never had the rows, and twice in a row. Rolling it back raises nothing and restores nothing.

**Reason.** most databases never stored an override, and copy for a deleted component has nothing to come back to; an irreversible migration would only block rolling back past it. (D-13)

Kind: functional. Proof: test, DM-2 in `test/contract/remove_shell_settings_contract_test.rb`.

### DM-3 Independent of the application model

It works on the table in SQL and never names the `SiteSetting` model.

**Reason.** a migration runs against whatever the model is on the day it runs, and a model it leaned on may since have changed. (D-13)

Kind: functional. Proof: test, DM-3 in `test/contract/remove_shell_settings_contract_test.rb`.

### DM-4 No retired editor or default

Afterwards the admin's settings page offers no field for any of the three, and `SiteSetting` has no value or default for them. The other settings are still offered.

**Reason.** that is where the owner would otherwise meet the shell again. (D-13)

Kind: functional. Proof: test, DM-4 in `test/contract/remove_shell_settings_contract_test.rb`.

## Decisions

- D-13, `docs/decisions/remove_shell_settings.md`: SQL deletion for exactly three keys (DM-1 to DM-4).
