from __future__ import annotations

import contextlib
import io
import pathlib
import sys
import tempfile
import unittest


POLICY_DIRECTORY = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(POLICY_DIRECTORY))

import check_bun_coverage  # noqa: E402
import check_rust_coverage  # noqa: E402
import scan_secrets  # noqa: E402


class BunCoveragePolicyTests(unittest.TestCase):
    def write_lcov(self, contents: str) -> pathlib.Path:
        temporary = tempfile.NamedTemporaryFile(mode="w", suffix=".info", delete=False)
        self.addCleanup(pathlib.Path(temporary.name).unlink, missing_ok=True)
        with temporary:
            temporary.write(contents)
        return pathlib.Path(temporary.name)

    def scope(self) -> check_bun_coverage.CoverageScope:
        return check_bun_coverage.CoverageScope(
            name="fixture",
            directory=POLICY_DIRECTORY,
            expected_sources=frozenset({"src/domain.ts"}),
            generated_sources=frozenset({"src/generated.ts"}),
        )

    def test_generated_files_do_not_inflate_the_threshold(self) -> None:
        report = self.write_lcov(
            "SF:src/domain.ts\nFNF:1\nFNH:1\nLF:10\nLH:9\nend_of_record\n"
            "SF:src/generated.ts\nFNF:100\nFNH:100\nLF:1000\nLH:1000\nend_of_record\n"
        )
        with contextlib.redirect_stdout(io.StringIO()):
            check_bun_coverage.enforce_scope(self.scope(), report)

    def test_branch_totals_are_enforced_when_the_runtime_reports_them(self) -> None:
        report = self.write_lcov(
            "SF:src/domain.ts\nFNF:1\nFNH:1\nLF:10\nLH:10\nBRF:10\nBRH:7\nend_of_record\n"
            "SF:src/generated.ts\nFNF:1\nFNH:1\nLF:1\nLH:1\nBRF:0\nBRH:0\nend_of_record\n"
        )
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(ValueError, "branch coverage"):
                check_bun_coverage.enforce_scope(self.scope(), report)

    def test_missing_source_file_fails_closed(self) -> None:
        report = self.write_lcov(
            "SF:src/generated.ts\nFNF:1\nFNH:1\nLF:1\nLH:1\nend_of_record\n"
        )
        with self.assertRaisesRegex(ValueError, "source mismatch"):
            check_bun_coverage.enforce_scope(self.scope(), report)


class RustCoveragePolicyTests(unittest.TestCase):
    def test_ratios_reject_empty_metrics(self) -> None:
        with self.assertRaisesRegex(ValueError, "no measurable branches"):
            check_rust_coverage.ratio({"count": 0, "covered": 0}, "branches")

    def test_source_paths_must_stay_inside_the_rust_workspace(self) -> None:
        self.assertEqual(
            check_rust_coverage.suffix(
                "/workspace/packages/rust/atelier-sync-protocol/src/types.rs"
            ),
            "atelier-sync-protocol/src/types.rs",
        )
        with self.assertRaisesRegex(ValueError, "outside packages/rust"):
            check_rust_coverage.suffix("/workspace/services/anchor/src/main.rs")

    def test_each_crate_must_meet_the_real_branch_threshold(self) -> None:
        with contextlib.redirect_stdout(io.StringIO()):
            check_rust_coverage.enforce_metrics(
                "passing-crate",
                {"count": 100, "covered": 85},
                {"count": 10, "covered": 8},
            )
            with self.assertRaisesRegex(ValueError, "branch coverage"):
                check_rust_coverage.enforce_metrics(
                    "failing-crate",
                    {"count": 100, "covered": 100},
                    {"count": 10, "covered": 7},
                )


class SecretPatternPolicyTests(unittest.TestCase):
    def test_high_confidence_formats_match_without_embedding_a_credential(self) -> None:
        examples = [
            "AK" + "IA" + "A" * 16,
            "gh" + "p_" + "a" * 36,
            "sk_" + "live_" + "a" * 16,
        ]
        for example in examples:
            self.assertTrue(any(pattern.search(example) for _, pattern in scan_secrets.PATTERNS))

    def test_placeholders_are_not_reported_as_credentials(self) -> None:
        for placeholder in ["changeme", "${API_TOKEN}", "replace-with-client-secret"]:
            self.assertFalse(any(pattern.search(placeholder) for _, pattern in scan_secrets.PATTERNS))


if __name__ == "__main__":
    unittest.main()
