# Patrol regression checks

Use the saved `packages/multi_device_preview/example/patrol_test/` suite as the release gate. Tests exercise the
ordinary example with Patrol's test binding; do not run the Marionette automation
entrypoint inside Patrol. Existing widget tests provide quicker feedback and
Marionette remains useful for exploratory inspection.

## Run the suite

Use the repository's pinned Flutter SDK and resolve dependencies first. Patrol and
Patrol CLI are pinned in the example's dev dependencies; there is
no global CLI version to drift from the project. Run from the repository root:

```sh
mise run e2e
```

The host is macOS, matching the package's supported platform. Native automation
in Patrol's macOS support is limited; this suite verifies Flutter UI and
cross-preview synchronization through Dart. It does not validate iOS/Android
native controls, WebViews, or software keyboards.

Require a zero exit code and check the reported case count: no failed or skipped
cases. A successful compile or app launch is not a passing E2E run. Patrol writes
native result bundles under the example's `build/` directory; CI uploads them as
`patrol-results` when available. Inspect failures before retrying and fix causes
rather than adding unconditional sleeps or disabling assertions. Do not mutate
the application's global error handler inside a test to hide failures.

The generated `patrol_test/test_bundle.dart` and `.patrol.env` are ignored.
Formatting uses Git's tracked and non-ignored files so generated runner files do
not break ordinary checks.

## AI-assisted execution

Patrol MCP 0.2.2 is not enabled in this repository. Its develop session only
supports Android and iOS; macOS is explicitly excluded by its device selection
code. Use the pinned local CLI through `mise run e2e` to run regressions from an
AI agent. Existing Marionette entrypoints remain available for exploratory
macOS inspection. Reconsider Patrol MCP when stable macOS develop support is
available; do not point it at an unrelated attached mobile device.

## Release requirement

The tag workflow reuses the CI workflow and requires its Patrol job to succeed
for the exact tagged commit before obtaining publish credentials. Never use
`continue-on-error`, skipped cases, or a manual publish to bypass a failed gate.
Main pushes run validation only; a release requires an explicitly requested tag.

References: [Patrol](https://pub.dev/packages/patrol),
[Patrol MCP](https://pub.dev/packages/patrol_mcp), and the
[official platform setup](https://patrol.leancode.co/documentation).
