# Agent operating rules

- Work only on a feature or issue branch; never mutate `main` or `dev` directly.
- Reuse an existing issue branch instead of creating another branch.
- Track implementation in Linear when an Atelier team/project is available.
- Use interstitial commits as reviewable waypoints and explain why they exist.
- Preserve user-owned dirty work and unrelated changes.
- Add tests with behavior changes and run the broadest safe verification suite.
- Keep PDS-public versus protected-provider data boundaries explicit in code,
  UI, tests, and documentation.
- Keep MyContextProtocol integration deferred; the Atelier MCP backplane itself
  remains in scope.
- Never provision Production, promote `main`, activate production Marque DNS,
  archive source repositories, or upload store builds without explicit approval.
