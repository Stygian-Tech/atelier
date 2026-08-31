#!/usr/bin/env python3
"""Run and enforce honest Bun coverage for hand-authored domain contracts."""

from __future__ import annotations

import pathlib
import subprocess
import sys
import tempfile
from dataclasses import dataclass


ROOT = pathlib.Path(__file__).resolve().parents[2]
MIN_LINES = 85.0
MIN_FUNCTIONS = 80.0
MIN_BRANCHES = 80.0


@dataclass(frozen=True)
class CoverageScope:
    name: str
    directory: pathlib.Path
    expected_sources: frozenset[str]
    generated_sources: frozenset[str]


SCOPES = (
    CoverageScope(
        name="TypeScript contracts",
        directory=ROOT / "packages/contracts",
        expected_sources=frozenset(
            {
                "src/auth.ts",
                "src/domain.ts",
                "src/index.ts",
                "src/jobs.ts",
                "src/providers.ts",
            }
        ),
        generated_sources=frozenset({"src/generated/lexicons.ts"}),
    ),
    CoverageScope(
        name="Lexicon runtime",
        directory=ROOT / "packages/lexicons",
        expected_sources=frozenset({"src/index.ts"}),
        generated_sources=frozenset({"src/generated/catalog.ts"}),
    ),
)


def percentage(covered: int, total: int) -> float:
    if total <= 0:
        raise ValueError("coverage denominator must be greater than zero")
    return covered * 100.0 / total


def parse_lcov(path: pathlib.Path) -> dict[str, dict[str, int]]:
    records: dict[str, dict[str, int]] = {}
    current: str | None = None
    for raw_line in path.read_text().splitlines():
        key, separator, value = raw_line.partition(":")
        if not separator:
            continue
        if key == "SF":
            current = pathlib.PurePosixPath(value).as_posix()
            records[current] = {"LF": 0, "LH": 0, "FNF": 0, "FNH": 0, "BRF": 0, "BRH": 0}
        elif current is not None and key in records[current]:
            records[current][key] = int(value)
    return records


def enforce_scope(scope: CoverageScope, report: pathlib.Path) -> None:
    records = parse_lcov(report)
    observed = frozenset(records)
    allowed = scope.expected_sources | scope.generated_sources
    if observed != allowed:
        missing = sorted(allowed - observed)
        unexpected = sorted(observed - allowed)
        raise ValueError(
            f"{scope.name}: coverage source mismatch; missing={missing}, unexpected={unexpected}"
        )

    totals = {
        key: sum(records[source][key] for source in scope.expected_sources)
        for key in ("LF", "LH", "FNF", "FNH", "BRF", "BRH")
    }
    line_coverage = percentage(totals["LH"], totals["LF"])
    function_coverage = percentage(totals["FNH"], totals["FNF"])
    if line_coverage < MIN_LINES:
        raise ValueError(
            f"{scope.name}: line coverage {line_coverage:.2f}% is below {MIN_LINES:.2f}%"
        )
    if function_coverage < MIN_FUNCTIONS:
        raise ValueError(
            f"{scope.name}: function coverage {function_coverage:.2f}% is below "
            f"{MIN_FUNCTIONS:.2f}%"
        )

    print(
        f"{scope.name}: {line_coverage:.2f}% lines "
        f"({totals['LH']}/{totals['LF']}), {function_coverage:.2f}% functions "
        f"({totals['FNH']}/{totals['FNF']})"
    )
    if totals["BRF"] == 0:
        print(
            f"{scope.name}: Bun LCOV contains no branch records; "
            f"{MIN_FUNCTIONS:.0f}% function coverage is enforced as the strongest available "
            "additional metric and is not reported as branch coverage."
        )
        return

    branch_coverage = percentage(totals["BRH"], totals["BRF"])
    if branch_coverage < MIN_BRANCHES:
        raise ValueError(
            f"{scope.name}: branch coverage {branch_coverage:.2f}% is below "
            f"{MIN_BRANCHES:.2f}%"
        )
    print(
        f"{scope.name}: {branch_coverage:.2f}% branches "
        f"({totals['BRH']}/{totals['BRF']})"
    )


def main() -> int:
    try:
        bun_version = subprocess.run(
            ["bun", "--version"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        print(f"Bun {bun_version} domain coverage")
        with tempfile.TemporaryDirectory(prefix="atelier-bun-coverage-") as temporary:
            temporary_root = pathlib.Path(temporary)
            for index, scope in enumerate(SCOPES):
                coverage_directory = temporary_root / str(index)
                subprocess.run(
                    [
                        "bun",
                        "test",
                        "test",
                        "--coverage",
                        "--coverage-reporter=text",
                        "--coverage-reporter=lcov",
                        f"--coverage-dir={coverage_directory}",
                    ],
                    cwd=scope.directory,
                    check=True,
                )
                enforce_scope(scope, coverage_directory / "lcov.info")
    except (OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f"domain coverage policy: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
