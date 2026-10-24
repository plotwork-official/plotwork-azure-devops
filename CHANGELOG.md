# Changelog

All notable changes to this extension are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases follow [semantic versioning](https://semver.org/spec/v2.0.0.html). The extension's version is in `vss-extension.json`; the task's major version, `PlotworkDiagrams@1`, moves only with a change that breaks a pipeline.

## 0.1.0 (unreleased)

### Added

* The task `PlotworkDiagrams@1` with three modes: `check` (pictures under diagram fences), `generate` (diagrams made from files, with a patch as the artifact `plotwork`), and `drift` (a JUnit test run when a diagram differs from its files).
* `reportDrift` sends a drift run's metadata to an organisation's drift dashboard, with the key from a Plotwork service connection or the secret variable `PLOTWORK_API_KEY`.
* The service connection type Plotwork, which holds an organisation API key.
* `cliVersion` pins the release of `@buun_group/plotwork` the task runs; the default is the stable release this version of the extension was tested with.
