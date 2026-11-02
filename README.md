# multi_device_preview

Run a Flutter app on several device sizes and text scales side by side in one
macOS window, and mirror input on one device to all the others.

https://github.com/user-attachments/assets/aa92b3e4-ab8a-411a-95d7-f48cdba56362

| Package | |
|---|---|
| [multi_device_preview](packages/multi_device_preview) | The preview, input sync, commands and the `init` command |
| [multi_device_preview_marionette](packages/multi_device_preview_marionette) | Marionette MCP tools for AI agents |

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
