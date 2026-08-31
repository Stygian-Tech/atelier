#!/usr/bin/env python3
"""Scan repository text files for high-confidence credential patterns."""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[2]
MAX_TEXT_FILE_BYTES = 5 * 1024 * 1024
PATTERNS = (
    ("private key", re.compile(r"-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----")),
    ("AWS access key", re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("GitHub token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,255}\b")),
    ("GitHub fine-grained token", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{40,255}\b")),
    ("Google API key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("Slack token", re.compile(r"\bxox[baprs]-[0-9A-Za-z-]{10,}\b")),
    ("Stripe live secret", re.compile(r"\b(?:sk|rk)_live_[0-9A-Za-z]{16,}\b")),
    ("npm access token", re.compile(r"\bnpm_[A-Za-z0-9]{36}\b")),
)


def repository_files() -> list[pathlib.Path]:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    return [ROOT / path.decode() for path in result.stdout.split(b"\0") if path]


def main() -> int:
    findings: list[tuple[pathlib.Path, int, str]] = []
    inspected = 0
    try:
        for path in repository_files():
            if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_TEXT_FILE_BYTES:
                continue
            contents = path.read_bytes()
            if b"\0" in contents:
                continue
            inspected += 1
            text = contents.decode("utf-8", errors="replace")
            for line_number, line in enumerate(text.splitlines(), start=1):
                for name, pattern in PATTERNS:
                    if pattern.search(line):
                        findings.append((path.relative_to(ROOT), line_number, name))
    except (OSError, subprocess.CalledProcessError, UnicodeError) as error:
        print(f"secret pattern policy: {error}", file=sys.stderr)
        return 1

    if findings:
        for path, line_number, name in findings:
            print(f"secret pattern policy: {path}:{line_number}: possible {name}", file=sys.stderr)
        return 1

    print(f"Secret pattern policy OK: {inspected} repository text files inspected")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
