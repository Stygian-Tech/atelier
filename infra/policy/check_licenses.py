#!/usr/bin/env python3
"""Fail closed on missing workspace licenses and disallowed JS dependency licenses."""

from __future__ import annotations

import json
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[2]
NODE_MODULES = ROOT / "node_modules"
DISALLOWED = re.compile(
    r"(?:^|[^A-Z])(?:A?GPL(?:-[0-9.]+)?|SSPL(?:-[0-9.]+)?|BUSL(?:-[0-9.]+)?|COMMONS-CLAUSE|POLYFORM)(?:$|[^A-Z])",
    re.IGNORECASE,
)


def declared_license(package: dict[str, object]) -> str | None:
    value = package.get("license")
    if isinstance(value, str) and value.strip():
        return value.strip()
    if isinstance(value, dict):
        legacy_type = value.get("type")
        if isinstance(legacy_type, str) and legacy_type.strip():
            return legacy_type.strip()
    legacy_values = package.get("licenses")
    if isinstance(legacy_values, list):
        values = [
            item.get("type", "") if isinstance(item, dict) else item
            for item in legacy_values
        ]
        normalized = [item.strip() for item in values if isinstance(item, str) and item.strip()]
        if normalized:
            return " OR ".join(normalized)
    return None


def license_from_file(package_manifest: pathlib.Path) -> str | None:
    for pattern in ("LICENSE*", "LICENCE*", "COPYING*"):
        for candidate in sorted(package_manifest.parent.glob(pattern)):
            if not candidate.is_file():
                continue
            try:
                opening = candidate.read_text(errors="replace")[:512].upper()
            except OSError:
                continue
            if "MIT LICENSE" in opening or "PERMISSION IS HEREBY GRANTED, FREE OF CHARGE" in opening:
                return "MIT (license file)"
            if "APACHE LICENSE" in opening:
                return "Apache (license file)"
            if "BSD" in opening or "REDISTRIBUTION AND USE IN SOURCE AND BINARY FORMS" in opening:
                return "BSD (license file)"
            if "ISC LICENSE" in opening:
                return "ISC (license file)"
    return None


def workspace_manifests() -> list[pathlib.Path]:
    root_manifest = json.loads((ROOT / "package.json").read_text())
    manifests = [ROOT / "package.json"]
    for pattern in root_manifest["workspaces"]:
        manifests.extend(ROOT.glob(f"{pattern}/package.json"))
    return sorted(set(manifests))


def dependency_manifests() -> list[pathlib.Path]:
    if not NODE_MODULES.is_dir():
        raise ValueError("node_modules is missing; run bun install --frozen-lockfile first")
    return sorted(NODE_MODULES.rglob("package.json"))


def main() -> int:
    problems: list[str] = []
    for path in workspace_manifests():
        package = json.loads(path.read_text())
        if declared_license(package) != "MIT":
            problems.append(f"{path.relative_to(ROOT)} must declare license MIT")

    inspected: set[tuple[str, str]] = set()
    for path in dependency_manifests():
        try:
            package = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            problems.append(f"cannot parse dependency manifest {path.relative_to(ROOT)}")
            continue
        name = package.get("name")
        version = package.get("version")
        if not isinstance(name, str) or not isinstance(version, str):
            continue
        identity = (name, version)
        if identity in inspected:
            continue
        inspected.add(identity)
        license_expression = declared_license(package) or license_from_file(path)
        if license_expression is None:
            problems.append(f"{name}@{version} does not declare a license")
        elif DISALLOWED.search(license_expression):
            problems.append(f"{name}@{version} uses disallowed license {license_expression}")

    if problems:
        for problem in problems:
            print(f"license policy: {problem}", file=sys.stderr)
        return 1

    print(f"License policy OK: {len(inspected)} unique JS dependencies inspected")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
