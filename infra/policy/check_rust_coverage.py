#!/usr/bin/env python3
"""Enforce line and genuine branch coverage for collaboration production code."""

from __future__ import annotations

import json
import pathlib
import sys


MIN_LINES = 85.0
MIN_BRANCHES = 80.0
EXPECTED_SOURCES = frozenset(
    {
        "atelier-sync-bindings/src/ffi.rs",
        "atelier-sync-bindings/src/lib.rs",
        "atelier-sync-protocol/src/anchor.rs",
        "atelier-sync-protocol/src/checkpoint.rs",
        "atelier-sync-protocol/src/document.rs",
        "atelier-sync-protocol/src/types.rs",
    }
)


def suffix(filename: str) -> str:
    normalized = pathlib.PurePosixPath(filename).as_posix()
    marker = "/packages/rust/"
    if marker not in normalized:
        raise ValueError(f"coverage report contains source outside packages/rust: {filename}")
    return normalized.split(marker, 1)[1]


def ratio(metric: dict[str, object], name: str) -> float:
    count = metric.get("count")
    covered = metric.get("covered")
    if not isinstance(count, int) or not isinstance(covered, int) or count <= 0:
        raise ValueError(f"coverage report has no measurable {name}")
    return covered * 100.0 / count


def add_metric(target: dict[str, int], metric: dict[str, object], name: str) -> None:
    count = metric.get("count")
    covered = metric.get("covered")
    if not isinstance(count, int) or not isinstance(covered, int):
        raise ValueError(f"coverage report has invalid {name} totals")
    target["count"] += count
    target["covered"] += covered


def enforce_metrics(label: str, lines: dict[str, int], branches: dict[str, int]) -> None:
    line_coverage = ratio(lines, f"{label} lines")
    branch_coverage = ratio(branches, f"{label} branches")
    if line_coverage < MIN_LINES:
        raise ValueError(
            f"{label} line coverage {line_coverage:.2f}% is below {MIN_LINES:.2f}%"
        )
    if branch_coverage < MIN_BRANCHES:
        raise ValueError(
            f"{label} branch coverage {branch_coverage:.2f}% is below {MIN_BRANCHES:.2f}%"
        )
    print(
        f"{label}: {line_coverage:.2f}% lines ({lines['covered']}/{lines['count']}), "
        f"{branch_coverage:.2f}% branches ({branches['covered']}/{branches['count']})"
    )


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_rust_coverage.py <llvm-coverage-summary.json>", file=sys.stderr)
        return 2
    try:
        report = json.loads(pathlib.Path(sys.argv[1]).read_text())
        data = report.get("data")
        if not isinstance(data, list) or len(data) != 1 or not isinstance(data[0], dict):
            raise ValueError("expected exactly one LLVM coverage data set")
        files = data[0].get("files")
        if not isinstance(files, list):
            raise ValueError("LLVM coverage report is missing files")
        observed = frozenset(
            suffix(file["filename"])
            for file in files
            if isinstance(file, dict) and isinstance(file.get("filename"), str)
        )
        if observed != EXPECTED_SOURCES:
            raise ValueError(
                "coverage source mismatch; "
                f"missing={sorted(EXPECTED_SOURCES - observed)}, "
                f"unexpected={sorted(observed - EXPECTED_SOURCES)}"
            )

        crate_totals: dict[str, dict[str, dict[str, int]]] = {}
        for file in files:
            if not isinstance(file, dict) or not isinstance(file.get("filename"), str):
                raise ValueError("LLVM coverage report contains an invalid file entry")
            source = suffix(file["filename"])
            crate = source.split("/", 1)[0]
            summary = file.get("summary")
            if not isinstance(summary, dict):
                raise ValueError(f"LLVM coverage report is missing a summary for {source}")
            file_lines = summary.get("lines")
            file_branches = summary.get("branches")
            if not isinstance(file_lines, dict) or not isinstance(file_branches, dict):
                raise ValueError(f"LLVM coverage report is missing metrics for {source}")
            crate_summary = crate_totals.setdefault(
                crate,
                {
                    "lines": {"count": 0, "covered": 0},
                    "branches": {"count": 0, "covered": 0},
                },
            )
            add_metric(crate_summary["lines"], file_lines, f"{source} lines")
            add_metric(crate_summary["branches"], file_branches, f"{source} branches")

        totals = data[0].get("totals")
        if not isinstance(totals, dict):
            raise ValueError("LLVM coverage report is missing totals")
        lines = totals.get("lines")
        branches = totals.get("branches")
        if not isinstance(lines, dict) or not isinstance(branches, dict):
            raise ValueError("LLVM coverage report is missing line or branch totals")
        summed_lines = {
            key: sum(summary["lines"][key] for summary in crate_totals.values())
            for key in ("count", "covered")
        }
        summed_branches = {
            key: sum(summary["branches"][key] for summary in crate_totals.values())
            for key in ("count", "covered")
        }
        if summed_lines != {key: lines.get(key) for key in summed_lines} or summed_branches != {
            key: branches.get(key) for key in summed_branches
        }:
            raise ValueError("per-file and aggregate LLVM coverage totals do not match")

        for crate, summary in sorted(crate_totals.items()):
            enforce_metrics(crate, summary["lines"], summary["branches"])
        enforce_metrics("Rust collaboration total", summed_lines, summed_branches)
    except (OSError, json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
        print(f"Rust coverage policy: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
