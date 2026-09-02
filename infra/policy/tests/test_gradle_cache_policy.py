from __future__ import annotations

import pathlib
import re
import unittest


REPOSITORY_ROOT = pathlib.Path(__file__).resolve().parents[3]


class GradleCachePolicyTests(unittest.TestCase):
    def test_gradle_action_uses_open_source_cache(self) -> None:
        workflow = (REPOSITORY_ROOT / ".github/workflows/ci.yml").read_text()
        setup_steps = re.findall(
            r"(?m)^      - uses: gradle/actions/setup-gradle@[^\n]+\n"
            r"((?:^        [^\n]*\n)*)",
            workflow,
        )
        self.assertEqual(len(setup_steps), 1)
        self.assertIn("          cache-provider: basic\n", setup_steps[0])


if __name__ == "__main__":
    unittest.main()
