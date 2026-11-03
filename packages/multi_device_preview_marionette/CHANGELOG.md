## 1.1.0

- Requires multi_device_preview 1.2.0. The `setDevice` and `addDevice` tools
  take its new `orientation` parameter, and `getState` reports it.

## 1.0.0

- First release: registers the multi_device_preview commands (`getState`,
  `listPresets`, `setSync`, `restart`, `setDevice`, `addDevice`,
  `removeDevice`, `saveScreenshot`, `panZoom`) as Marionette extensions with
  typed input schemas.
