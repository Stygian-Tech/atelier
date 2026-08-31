# Repository policy checks

`check_bun_coverage.py` runs the Bun tests for `packages/contracts` and
`packages/lexicons`, then gates only hand-authored runtime files at 85% line
coverage and 80% function coverage. The two generated TypeScript catalogs are
required to be present in the report but are excluded from the numerator and
denominator; `check:generated` independently proves that they match the
validated Lexicon source.

Bun 1.3.14 does not emit branch totals in either its text report or LCOV output.
The policy therefore prints that limitation and does not call function coverage
branch coverage. If a future Bun report contains branch totals, the same check
will enforce an 80% branch threshold.

Rust uses `cargo-llvm-cov` 0.9.0 and the date-pinned
`nightly-2026-08-29` toolchain because `-Z coverage-options=branch` is still a
nightly-only compiler capability. Inline unit-test modules use
`#[coverage(off)]`; integration-test files are excluded by cargo-llvm-cov's
default test-file rule. `check_rust_coverage.py` rejects reports containing
anything except production files from `atelier-sync-protocol` and
`atelier-sync-bindings`, then enforces 85% line and 80% real branch coverage for
each crate as well as their aggregate.

`scan_secrets.py` scans tracked and non-ignored untracked text files for a small
set of high-confidence private-key and provider-token formats. It reports only
the file, line, and credential kind, never the matching value.
