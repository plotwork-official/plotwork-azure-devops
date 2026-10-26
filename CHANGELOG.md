# Changelog

All notable changes to this extension are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases follow [semantic versioning](https://semver.org/spec/v2.0.0.html). Betas (`0.2.0-beta.3`) are published as the private preview extension under the Marketplace version `0.2.3`; stable versions as they are. The task's major version, `PlotworkDiagrams@1`, moves only with a change that breaks a pipeline; its minor and patch rise with every release.

## [0.1.1-beta.1](https://github.com/plotwork-official/plotwork-app/compare/azure-devops-v0.1.0...azure-devops-v0.1.1-beta.1) (2026-10-26)


### Fixed

* **azure-devops:** run the command line 0.4.0 by default ([958cef3](https://github.com/plotwork-official/plotwork-app/commit/958cef3332adb98afc7a549692858eaf57d31b74))

## 0.1.0 (2026-10-26)

The stable release of 0.1.0-beta.1, 0.1.0-beta.2, 0.1.0-beta.3. The changes are listed under those versions below.

## [0.1.0-beta.3](https://github.com/plotwork-official/plotwork-app/compare/azure-devops-v0.1.0-beta.2...azure-devops-v0.1.0-beta.3) (2026-10-25)


### Added

* **azure:** bring the task to parity with the GitHub Action ([89cec33](https://github.com/plotwork-official/plotwork-app/commit/89cec339b3d0fec7e39d33115697b35e2dba2ca0))
* storage connectors, ruled status cards, no accent-bar callouts, Azure Pipelines trusted publishers ([821fafe](https://github.com/plotwork-official/plotwork-app/commit/821fafe2f240c82f4f80e90a53c4b10f8920a430))

## [0.1.0-beta.2](https://github.com/plotwork-official/plotwork-app/compare/azure-devops-v0.1.0-beta.1...azure-devops-v0.1.0-beta.2) (2026-10-25)


### Added

* **app:** visual editing on boards, the Look dialog, and three-height sheets on phones ([8040b8d](https://github.com/plotwork-official/plotwork-app/commit/8040b8d41f33695cacf58e6828bcb09dcf71e107))
* board agent chat and animation, folder name rule, mobile fixes ([d01ff71](https://github.com/plotwork-official/plotwork-app/commit/d01ff71583bb20794eb7ec31cf0b78232e329d68))


### Fixed

* **azure:** run [@buun](https://github.com/buun)_group/plotwork 0.3.0 ([b568c69](https://github.com/plotwork-official/plotwork-app/commit/b568c69496581080949e2439a0bac7d87af36758))

## 0.1.0-beta.1

### Added

* The task `PlotworkDiagrams@1` with three modes: `check` (pictures under diagram fences), `generate` (diagrams made from files, with a patch as the artifact `plotwork`), and `drift` (a JUnit test run when a diagram differs from its files).
* `reportDrift` sends a drift run's metadata to an organisation's drift dashboard, with the key from a Plotwork service connection or the secret variable `PLOTWORK_API_KEY`.
* The service connection type Plotwork, which holds an organisation API key.
* `cliVersion` pins the release of `@buun_group/plotwork` the task runs; the default is the stable release this version of the extension was tested with.
