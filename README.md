# multi_device_preview

Run a Flutter app on several device sizes and text scales side by side in one
macOS window, and mirror input on one device to all the others.

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
