#!/usr/bin/env python3
"""Validate Atelier's checked-in Railway contracts without contacting Railway."""

from __future__ import annotations

import json
import pathlib
import re
import sys
import tomllib


ROOT = pathlib.Path(__file__).resolve().parents[2]
RAILWAY_ROOT = ROOT / "infra" / "railway"
RAILWAY_IAC = ROOT / ".railway" / "railway.ts"
WEB_BUILD_PROVENANCE_CONTEXT = (
    "!imports/atelier-mail/",
    "!imports/atelier-mail/bun.lock",
    "!imports/atelier-mail/bunfig.toml",
    "!imports/atelier-mail/package.json",
    "!imports/atelier-mail/packages/",
    "!imports/atelier-mail/packages/lexicons/",
    "!imports/atelier-mail/packages/lexicons/package.json",
)
NEXT_PUBLIC_SURFACES = ("home", "notes", "mail", "calendar", "tasks")


def fail(message: str) -> None:
    raise ValueError(message)


def workspace_package_names() -> set[str]:
    root_package = json.loads((ROOT / "package.json").read_text())
    names: set[str] = set()
    for pattern in root_package["workspaces"]:
        for package_path in ROOT.glob(f"{pattern}/package.json"):
            package = json.loads(package_path.read_text())
            if name := package.get("name"):
                names.add(name)
    return names


def parse_env_example(path: pathlib.Path) -> dict[str, str]:
    variables: dict[str, str] = {}
    for line_number, raw_line in enumerate(path.read_text().splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            fail(f"{path.relative_to(ROOT)}:{line_number}: expected KEY=value")
        name, value = line.split("=", 1)
        if name in variables:
            fail(f"{path.relative_to(ROOT)}:{line_number}: duplicate {name}")
        variables[name] = value
    return variables


def validate_environment_contract() -> None:
    contract_path = RAILWAY_ROOT / "environment-contract.toml"
    contract = tomllib.loads(contract_path.read_text())
    declarations = contract.get("variable", [])
    names = [item["name"] for item in declarations]
    if len(names) != len(set(names)):
        fail("infra/railway/environment-contract.toml contains duplicate variables")

    examples = sorted((RAILWAY_ROOT / "environments").glob("*.env.example"))
    if not examples:
        fail("infra/railway/environments contains no environment examples")
    expected = set(names)
    for path in examples:
        actual = set(parse_env_example(path))
        if actual != expected:
            missing = sorted(expected - actual)
            extra = sorted(actual - expected)
            fail(f"{path.relative_to(ROOT)} contract drift: missing={missing}, extra={extra}")

    contract_by_name = {item["name"]: item for item in declarations}
    for gate in ("ATELIER_ANCHOR_READY",):
        declaration = contract_by_name.get(gate)
        if declaration is None:
            fail(f"environment contract is missing fail-closed gate {gate}")
        if declaration.get("development") != "0" or declaration.get("production") != "0":
            fail(f"{gate} must default to 0 in Development and Production")

    activation_gate = contract_by_name.get("ATELIER_PRODUCTION_ACTIVATION_APPROVED")
    if activation_gate is None:
        fail("environment contract is missing Production activation release guard")
    if activation_gate.get("development") != "0" or activation_gate.get("production") != "1":
        fail(
            "ATELIER_PRODUCTION_ACTIVATION_APPROVED must remain 0 in Development "
            "and record the explicit 2026-08-30 Production approval as 1"
        )


def validate_service_contracts() -> None:
    package_names = workspace_package_names()
    stale_paths = (
        "--package-path services/atelier-api",
        "/services/atelier-api/**",
        "services/atelier-api/.build",
        "/packages/design-tokens/**",
    )
    readiness_services = {"atelier-api", "mcp-backplane", "notes-sync-anchor"}
    service_paths = sorted((RAILWAY_ROOT / "services").glob("*.toml"))
    if not service_paths:
        fail("infra/railway/services contains no service contracts")

    for path in service_paths:
        relative_path = path.relative_to(ROOT).as_posix()
        text = path.read_text()
        for stale_path in stale_paths:
            if stale_path in text:
                fail(f"{relative_path} contains stale source path {stale_path}")

        config = tomllib.loads(text)
        build = config.get("build")
        deploy = config.get("deploy")
        if not isinstance(build, dict) or not isinstance(deploy, dict):
            fail(f"{relative_path} must define [build] and [deploy]")

        watch_patterns = build.get("watchPatterns", [])
        if f"/{relative_path}" not in watch_patterns:
            fail(f"{relative_path} must watch its own config file")

        build_command = build.get("buildCommand", "")
        if package_match := re.search(r"--filter=([^ ]+)", build_command):
            package_name = package_match.group(1)
            if package_name not in package_names:
                fail(f"{relative_path} references unknown workspace package {package_name}")

        if swift_match := re.search(r"--package-path ([^ ]+)", build_command):
            swift_path = swift_match.group(1)
            manifest = ROOT / swift_path / "Package.swift"
            if not manifest.exists():
                expected_gate = f"test -f {swift_path}/Package.swift && "
                if not build_command.startswith(expected_gate):
                    fail(f"{relative_path} must fail closed until {manifest.relative_to(ROOT)} exists")
                start_command = deploy.get("startCommand", "")
                if not start_command.startswith(f"test -x {swift_path}/.build/release/"):
                    fail(f"{relative_path} must gate its unavailable release executable")

        dockerfile: pathlib.Path | None = None
        if dockerfile_path := build.get("dockerfilePath"):
            dockerfile = ROOT / dockerfile_path.lstrip("/")
            if not dockerfile.is_file():
                fail(f"{relative_path} references missing Dockerfile {dockerfile_path}")

        if path.stem in NEXT_PUBLIC_SURFACES:
            if dockerfile is None:
                fail(f"{relative_path} must reference its Next.js Dockerfile")
            if "startCommand" in deploy:
                fail(
                    f"{relative_path} must let its Dockerfile own startup so Next.js "
                    "reads Railway's PORT environment variable directly"
                )
            if "$PORT" in text:
                fail(f"{relative_path} must not pass a literal $PORT argument")

            package_manifest = json.loads(
                (ROOT / "apps" / "web" / path.stem / "package.json").read_text()
            )
            if package_manifest.get("scripts", {}).get("start") != "next start":
                fail(f"apps/web/{path.stem}/package.json must start with next start")

            expected_command = (
                f'CMD ["bun", "run", "--cwd", "apps/web/{path.stem}", "start"]'
            )
            dockerfile_text = dockerfile.read_text()
            commands = [
                line.strip()
                for line in dockerfile_text.splitlines()
                if line.strip().startswith("CMD ")
            ]
            if commands != [expected_command]:
                fail(
                    f"{dockerfile.relative_to(ROOT)} must contain only {expected_command}"
                )
            if "ENV HOSTNAME=0.0.0.0" not in dockerfile_text:
                fail(f"{dockerfile.relative_to(ROOT)} must bind Next.js to 0.0.0.0")

        if path.stem in readiness_services and deploy.get("healthcheckPath") != "/readyz":
            fail(f"{relative_path} must use its fail-closed /readyz rollout probe")


def validate_iac_contract() -> None:
    if not RAILWAY_IAC.is_file():
        fail(".railway/railway.ts is missing")

    text = RAILWAY_IAC.read_text()
    if 'from "railway/iac"' not in text:
        fail(".railway/railway.ts must use Railway Infrastructure as Code")
    for legacy_field in ("railwayConfigFile", "configFile"):
        if legacy_field in text:
            fail(f".railway/railway.ts must not use legacy {legacy_field}")
    if re.search(r"\bdomains\s*:", text):
        fail(
            ".railway/railway.ts must not declare custom domains; "
            "Railway project-level IaC does not support their registration"
        )

    excluded_services = (
        "atelier-api",
        "worker",
        "mail-sync",
        "calendar-sync",
        "notes-sync-anchor",
        "mcp-backplane",
        "postgres",
        "redis",
    )
    for service_name in excluded_services:
        quoted_names = (f'"{service_name}"', f"'{service_name}'")
        if any(quoted_name in text for quoted_name in quoted_names):
            fail(f".railway/railway.ts must not provision {service_name} yet")


def validate_web_build_context() -> None:
    dockerignore_path = ROOT / ".dockerignore"
    entries = [
        line.strip()
        for line in dockerignore_path.read_text().splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    if "imports" in entries:
        fail(
            ".dockerignore must not exclude the imports parent; web container builds need "
            "the preserved Atelier Mail package manifests"
        )
    if "imports/**" not in entries:
        fail(".dockerignore must exclude imported source by default with imports/**")

    actual_exceptions = tuple(entry for entry in entries if entry.startswith("!imports/"))
    if actual_exceptions != WEB_BUILD_PROVENANCE_CONTEXT:
        fail(
            ".dockerignore must expose only the exact Atelier Mail manifests "
            f"required by web container builds: expected={WEB_BUILD_PROVENANCE_CONTEXT}, "
            f"actual={actual_exceptions}"
        )
    ignore_index = entries.index("imports/**")
    if any(entries.index(exception) < ignore_index for exception in actual_exceptions):
        fail(".dockerignore web-build manifest exceptions must follow imports/**")


def main() -> int:
    validate_environment_contract()
    validate_service_contracts()
    validate_iac_contract()
    validate_web_build_context()
    print("Railway contracts OK")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, TypeError, ValueError, tomllib.TOMLDecodeError) as error:
        print(f"Railway contract validation failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
