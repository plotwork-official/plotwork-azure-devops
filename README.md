> The preview of [Plotwork diagrams](https://marketplace.visualstudio.com/items?itemName=plotwork.plotwork-diagrams), version 0.1.0-beta.2: a private extension (`plotwork-diagrams-preview`) shared with test organisations. Its task is `PlotworkDiagramsPreview@1`.

# Plotwork diagrams for Azure Pipelines

Keeps [Plotwork](https://plotwork.dev) diagrams in step in Azure Pipelines. The task `PlotworkDiagramsPreview@1` fails a pull request whose diagram pictures are stale, or whose diagrams made from Terraform, OpenAPI, Compose and other files have drifted, and can write them again. It runs the pinned release of the command line [`@buun_group/plotwork`](https://www.npmjs.com/package/@buun_group/plotwork) with `npx`, so it is the same check you run on your machine.

## TL;DR

| Question | Answer |
|---|---|
| What can it do? | `mode: check` fails on a stale picture under a `diagram` fence. `mode: drift` fails when a diagram made from files differs from what its files make now, and publishes a test run. `mode: generate` writes the diagrams again and keeps a patch as the artifact `plotwork`. |
| What does the agent need? | Node 22 or later with `npx` (add `UseNode@1` first), `git`, and access to the npm registry. |
| Does it need a key? | No, except for `reportDrift`, which takes an organisation key from a Plotwork service connection or the secret variable `PLOTWORK_API_KEY`. |
| Does it send my files anywhere? | No. The command line reads the checkout and makes no request. Only `reportDrift: true` sends a run's metadata (names, paths, statuses, counts and owners, never a diagram or a file) to Plotwork. |

## Check every pull request

```yaml
trigger: none
pr:
  branches:
    include: [main]

pool:
  vmImage: ubuntu-latest

steps:
  - task: UseNode@1
    inputs:
      version: 22.x
  - task: PlotworkDiagramsPreview@1
    inputs:
      mode: check
      paths: |
        README.md
        docs/**/*.md
```

## Fail on drift from files

Name the diagrams made from files in `sources` of `plotwork.config.json`, as [Diagrams as code](https://docs.plotwork.dev/diagrams-as-code) describes, then:

```yaml
steps:
  - task: UseNode@1
    inputs:
      version: 22.x
  - task: PlotworkDiagramsPreview@1
    inputs:
      mode: drift
```

Each generated diagram is a test of the run, failed when it drifted. To send each run to your organisation's drift dashboard, create a Plotwork service connection (Project settings, Service connections, New, Plotwork) with an organisation API key, and:

```yaml
  - task: PlotworkDiagramsPreview@1
    inputs:
      mode: drift
      reportDrift: true
      plotworkConnection: plotwork-acme
```

`plotworkConnection` is the name you gave the service connection.

Or keep the key in a secret variable and map it into the step:

```yaml
  - task: PlotworkDiagramsPreview@1
    inputs:
      mode: drift
      reportDrift: true
    env:
      PLOTWORK_API_KEY: $(PLOTWORK_API_KEY)
```

## Write the diagrams again

```yaml
  - task: PlotworkDiagramsPreview@1
    inputs:
      mode: generate
```

The task writes the diagrams in the workspace, for a later step of yours to commit, and uploads `plotwork.patch` as the artifact `plotwork`.

## Inputs

| Input | Default | Meaning |
|---|---|---|
| `mode` | `check` | `check`, `generate`, or `drift`. |
| `paths` | `**/*.md` | `check` only: the Markdown files, one glob, file, or folder per line. |
| `config` | empty | The settings file. Empty finds `plotwork.config.json`, then `.plotwork/config.json`. |
| `workingDirectory` | `.` | The folder to run in, from `$(System.DefaultWorkingDirectory)`. |
| `since` | empty | `drift` only: check only the sources whose files changed since this git ref. Check out with `fetchDepth: 0`. |
| `publishTestResults` | `true` | `drift` only: publish the JUnit report as a test run. |
| `reportDrift` | `false` | `drift` only: send the run's metadata to the organisation's drift dashboard. |
| `plotworkConnection` | empty | The Plotwork service connection that holds the organisation key. Empty reads `PLOTWORK_API_KEY`. |
| `organization` | empty | The organisation to report to. Empty is the organisation of the key. |
| `apiUrl` | `https://api.plotwork.dev` | The Plotwork API `reportDrift` sends to. |
| `cliVersion` | the release this version was tested with | The release of `@buun_group/plotwork` the task runs. |

| Output variable | Meaning |
|---|---|
| `junitFile` | `drift`: the JUnit report. |
| `patchFile`, `changedFiles` | `generate`: the patch, and a JSON array of the files the run changed. |
| `driftUrl` | `drift` with `reportDrift`: the drift dashboard the run was sent to. |

## Licence

MIT. See [LICENSE](./LICENSE). The bundled packages and their licences are in `tasks/PlotworkDiagrams/dist/THIRD-PARTY-NOTICES.md`. This repository is built from the Plotwork monorepo; changes made here are written over by the next release.
