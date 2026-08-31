# Contributing

1. Never work directly on `main` or `dev`.
2. Reuse the current issue branch when one already exists; otherwise create a
   `feature/`, `fix/`, `chore/`, `refactor/`, or `test/` branch.
3. Keep the matching Linear issue in sync with scope, blockers, review, and
   completion state.
4. Make small interstitial commits that explain why a change exists.
5. Add deterministic unit and integration tests with every behavior change.
6. Run the relevant TypeScript, Swift, Kotlin, Rust, container, migration, and
   accessibility checks before review.
7. Never add secrets, provider tokens, signing material, or user content.
8. Do not promote Development to Production or change production DNS without
   explicit approval.

Pull requests must describe the intent, implementation, verification evidence,
risks, migrations, external provisioning, and rollback path.
