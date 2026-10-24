# Changelog

All notable changes to this extension are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases follow [semantic versioning](https://semver.org/spec/v2.0.0.html). Betas (`0.2.0-beta.3`) are published as the private preview extension under the Marketplace version `0.2.3`; stable versions as they are. The task's major version, `PlotworkDiagrams@1`, moves only with a change that breaks a pipeline; its minor and patch rise with every release.

## 0.1.0-beta.1

### Added

* The task `PlotworkDiagrams@1` with three modes: `check` (pictures under diagram fences), `generate` (diagrams made from files, with a patch as the artifact `plotwork`), and `drift` (a JUnit test run when a diagram differs from its files).
* `reportDrift` sends a drift run's metadata to an organisation's drift dashboard, with the key from a Plotwork service connection or the secret variable `PLOTWORK_API_KEY`.
* The service connection type Plotwork, which holds an organisation API key.
* `cliVersion` pins the release of `@buun_group/plotwork` the task runs; the default is the stable release this version of the extension was tested with.
