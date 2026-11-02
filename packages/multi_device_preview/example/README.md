# multi_device_preview example

A small coffee shop app (tabs, a list, a search field, a detail page and a
dialog) running on four devices side by side, with input sync.

```sh
flutter run -d macos                        # the preview
flutter run -d macos -t marionette/main.dart # driven by an AI agent through Marionette
flutter run -d macos -t smoke/main.dart     # drives itself and saves screenshots
```

- [lib/main.dart](lib/main.dart): the preview entry point.
- [lib/app.dart](lib/app.dart): the app itself, unaware of the preview.
