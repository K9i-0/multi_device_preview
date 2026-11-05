## 1.1.1

- README: the setup passes the devices to the controller and initializes
  Marionette before any other binding.

## 1.1.0

- Requires multi_device_preview 1.2.0. The `setDevice` and `addDevice` tools
  take its new `orientation` parameter, and `getState` reports it.

## 1.0.0

- First release: registers the multi_device_preview commands (`getState`,
  `listPresets`, `setSync`, `restart`, `setDevice`, `addDevice`,
  `removeDevice`, `saveScreenshot`, `panZoom`) as Marionette extensions with
  typed input schemas.
