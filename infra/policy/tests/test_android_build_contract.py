from __future__ import annotations

import pathlib
import re
import unittest


ANDROID_DIRECTORY = pathlib.Path(__file__).resolve().parents[3] / "apps/android"
APPLICATIONS = {"app-atelier", "app-notes", "app-mail", "app-calendar", "app-tasks"}
LIBRARIES = {"core", "contracts", "persistence", "collaboration", "design", "editor", "app-ui"}


class AndroidBuildContractTests(unittest.TestCase):
    def test_toolchain_updates_preserve_runtime_sdk_contract(self) -> None:
        modules = {path.parent.name: path for path in ANDROID_DIRECTORY.glob("*/build.gradle.kts")}
        self.assertEqual(set(modules), APPLICATIONS | LIBRARIES)
        for name, path in modules.items():
            with self.subTest(module=name):
                contents = path.read_text()
                self.assertEqual(re.findall(r"\bminSdk\s*=\s*(\d+)", contents), ["29"])
                expected_targets = ["35"] if name in APPLICATIONS else []
                self.assertEqual(re.findall(r"\btargetSdk\s*=\s*(\d+)", contents), expected_targets)

    def test_modules_use_agp_builtin_kotlin(self) -> None:
        for path in ANDROID_DIRECTORY.glob("**/*.gradle.kts"):
            with self.subTest(path=path.relative_to(ANDROID_DIRECTORY)):
                contents = path.read_text()
                self.assertNotIn("libs.plugins.kotlin.android", contents)
                self.assertNotIn('"org.jetbrains.kotlin.android"', contents)
        properties = (ANDROID_DIRECTORY / "gradle.properties").read_text()
        self.assertNotRegex(properties, r"android\.(builtInKotlin|newDsl)\s*=\s*false")

    def test_kotlin_and_compose_compilers_share_catalog_version(self) -> None:
        catalog = (ANDROID_DIRECTORY / "gradle/libs.versions.toml").read_text()
        for alias in ("kotlin-gradle-plugin", "kotlin-compose"):
            with self.subTest(alias=alias):
                self.assertRegex(catalog, rf'(?m)^{alias} = .*version.ref = "kotlin"')
        root_build = (ANDROID_DIRECTORY / "build.gradle.kts").read_text()
        self.assertIn("classpath(libs.kotlin.gradle.plugin)", root_build)


if __name__ == "__main__":
    unittest.main()
