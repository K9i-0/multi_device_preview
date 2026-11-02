# multi_device_preview (workspace)

Monorepo for [multi_device_preview](packages/multi_device_preview), managed
with [pub workspaces](https://dart.dev/tools/pub/workspaces) and
[mise](https://mise.jdx.dev/).

| Path | Description |
|---|---|
| `packages/multi_device_preview` | The package |
| `packages/multi_device_preview/example` | macOS example app |

## Development

```sh
mise install       # Flutter version pinned in .mise.toml
mise run setup     # flutter pub get (whole workspace)
mise run check     # format-check, analyze, test
mise run example   # run the example on macOS
mise run publish-check
```
