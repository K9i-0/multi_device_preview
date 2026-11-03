# multi_device_preview

[![pub package](https://img.shields.io/pub/v/multi_device_preview.svg)](https://pub.dev/packages/multi_device_preview)
[![CI](https://github.com/K9i-0/multi_device_preview/actions/workflows/ci.yml/badge.svg)](https://github.com/K9i-0/multi_device_preview/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Run a Flutter app on several device sizes and text scales side by side in one
macOS window, and mirror input on one device to all the others.

https://github.com/user-attachments/assets/aa92b3e4-ab8a-411a-95d7-f48cdba56362

- Each device runs its own instance of your app; taps, scrolls and text on
  the first device are mirrored to the same elements on the others.
- device_preview frames and presets, plus the iPhone Duo closed and open.
- App Store screenshots at the exact pixel size, with a settable status bar
  time (`9:41` by default).
- AI agents can drive it through Marionette MCP.

| Package | pub.dev | |
|---|---|---|
| [multi_device_preview](packages/multi_device_preview) | [![pub](https://img.shields.io/pub/v/multi_device_preview.svg)](https://pub.dev/packages/multi_device_preview) | The preview, input sync, commands and the `init` command |
| [multi_device_preview_marionette](packages/multi_device_preview_marionette) | [![pub](https://img.shields.io/pub/v/multi_device_preview_marionette.svg)](https://pub.dev/packages/multi_device_preview_marionette) | Marionette MCP tools for AI agents |

## Quick start

```sh
flutter pub add dev:multi_device_preview
dart run multi_device_preview:init
flutter run -d macos -t multi_device_preview/main.dart
```

See the [package README](packages/multi_device_preview/README.md) for the
separate host app setup, input sync and automation.

The example lives in [packages/multi_device_preview/example](packages/multi_device_preview/example),
and the design notes in [docs/design_notes.md](docs/design_notes.md) (Japanese).

## Development

The repository is a [pub workspace](https://dart.dev/tools/pub/workspaces);
the Flutter version is pinned with [mise](https://mise.jdx.dev/).

```sh
mise install          # Flutter from .mise.toml
mise run setup        # flutter pub get for the whole workspace
mise run check        # format-check, analyze, test
mise run example      # run the example on macOS
mise run smoke        # drive the example on macOS, screenshots in tmp/smoke
mise run publish-check
```

## Workflow

Maintainers push directly to `main`; contributions come in as pull requests.
CI runs on both. Nothing is published from `main` itself.

## Releasing

Each package is released by pushing its tag; the
[Publish workflow](.github/workflows/publish.yml) runs the checks and publishes
to pub.dev with GitHub OIDC (no secrets).

1. Bump `version` in the package's `pubspec.yaml` and add a `## <version>`
   section to its `CHANGELOG.md`. Commit and push to `main`.
2. Tag and push:

   ```sh
   git tag multi_device_preview-v1.0.1
   git push origin multi_device_preview-v1.0.1
   ```

   For the adapter, use `multi_device_preview_marionette-v<version>`.

The workflow fails when the tag does not match the pubspec version or the
CHANGELOG has no section for it.

Release `multi_device_preview` before `multi_device_preview_marionette` when
the adapter needs the new version.

### First release and setup

pub.dev enables automated publishing only for packages that already exist, so
the first version of each package is published by hand:

```sh
cd packages/multi_device_preview && flutter pub publish
cd ../multi_device_preview_marionette && flutter pub publish
```

Then, on each package's **Admin** page on pub.dev, transfer the package to
the verified publisher [k9i.app](https://pub.dev/publishers/k9i.app/packages)
and enable *Automated
publishing* from GitHub Actions with repository `K9i-0/multi_device_preview`
and tag pattern `multi_device_preview-v{{version}}` (or
`multi_device_preview_marionette-v{{version}}`).

### Release regression gate

Run `mise run e2e` before a release. The macOS Patrol suite verifies preview
interactions and synchronization, and must pass with no failures or skipped tests.
The package-tag workflow repeats the same CI and E2E checks before publishing.
See [Patrol regression checks](docs/patrol.md) and the
[release procedure](.claude/skills/release/SKILL.md).
