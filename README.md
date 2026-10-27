> The preview of [Plotwork diagrams](https://marketplace.visualstudio.com/items?itemName=plotwork.plotwork-diagrams), version 0.1.3-beta.1: a private extension (`plotwork-diagrams-preview`) shared with test organisations. Its task is `PlotworkDiagramsPreview@1`.

# Plotwork diagrams for Azure Pipelines

Keeps [Plotwork](https://plotwork.dev) diagrams in step in Azure Pipelines. The task `PlotworkDiagramsPreview@1` fails a pull request whose diagram pictures are stale, whose diagrams have errors, or whose diagrams made from Terraform, OpenAPI, Compose and other files have drifted, marks each problem on its line, and can write the diagrams again and open a pull request with them. It runs the pinned release of the command line [`@buun_group/plotwork`](https://www.npmjs.com/package/@buun_group/plotwork) with `npx`, so it is the same check you run on your machine, and it does what the [Plotwork GitHub Action](https://github.com/plotwork-official/plotwork-action) does.

## TL;DR

| Question | Answer |
|---|---|
| What can it do? | `check` fails on a stale picture or a diagram with an error. `validate` reports errors and warnings. `sync` redraws pictures. `render` draws `.diagram` files to SVG. `drift` fails when a diagram made from files differs from what its files make now. `generate` writes those diagrams again and opens a pull request on Azure Repos. |
| Where do problems show? | Each one is an issue on its file and line, in the run and on the pull request, and the run gets a Plotwork summary tab. |
| What does the agent need? | Node 22 or later with `npx` (add `UseNode@1` first), `git`, and access to the npm registry. |
| Does it need a key? | No, except to report drift, publish, or read an organisation's style rules. Then a Plotwork service connection, the secret variable `PLOTWORK_API_KEY`, or no key at all as a trusted publisher. |
| Does it send my files anywhere? | No. The command line reads the checkout and makes no request. Only `reportDrift` (a run's metadata, never a diagram or a file) and `publish` (the generated diagram source only) send anything to Plotwork. |

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
      diagrams: |
        diagrams/**/*.diagram
```

`check` runs `plotwork sync --check` on the Markdown and `plotwork validate` on each `.diagram` file. With style rules in `plotwork.config.json`, or `rulesOrg` naming an organisation, it also runs `plotwork check`. `failOn: warning` also fails on warnings, and `failOn: never` only reports.

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

Each generated diagram is a test of the run, failed when it drifted. On a pull request build in Azure Repos the task also writes one comment with the change table, and edits it on later runs (`comment: auto`).

## Write the diagrams again and open a pull request

```yaml
schedules:
  - cron: '0 6 * * 1'
    branches:
      include: [main]

steps:
  - checkout: self
    fetchDepth: 0
  - task: UseNode@1
    inputs:
      version: 22.x
  - task: PlotworkDiagramsPreview@1
    inputs:
      mode: generate
```

In an Azure Repos repository, the task pushes one commit to `plotwork/diagrams` and opens or updates one pull request into the branch the run is on, with the job's own access token. Grant the project's build service (Project settings, Repositories, the repository, Security, `<project> Build Service (<organisation>)`) Contribute, Create branch, and Contribute to pull requests. When nothing drifts any more, the task abandons its pull request and deletes the branch. In a GitHub or Bitbucket repository it cannot push, so it says why and keeps the files in the workspace and the patch as the artifact `plotwork`, for a later step of yours. The patch is uploaded in every case.

`onDrift: commit` commits to the branch the run is on instead, and does nothing on its own commit. `onDrift: fail` fails, and `onDrift: patch` only keeps the files and the patch.

## Report drift and publish with no key

Add the pipeline as a trusted publisher of your Plotwork organisation (Organisation, Keys & CI, Trusted publishers, Azure Pipelines) with the Azure DevOps organisation, the project, and the pipeline's definition id. Then:

```yaml
  - task: PlotworkDiagramsPreview@1
    inputs:
      mode: generate
      reportDrift: true
      publish: true
```

With no key, the task asks Azure Pipelines for the job's OpenID Connect token, which needs no service connection, and exchanges it for a Plotwork token that lasts 15 minutes. `signedInAs` says as whom.

Or create a Plotwork service connection (Project settings, Service connections, New, Plotwork) with an organisation API key and set `plotworkConnection` to its name, or keep the key in a secret variable and map it into the step:

```yaml
  - task: PlotworkDiagramsPreview@1
    inputs:
      mode: drift
      reportDrift: true
    env:
      PLOTWORK_API_KEY: $(PLOTWORK_API_KEY)
```

## Inputs

| Input | Default | Meaning |
|---|---|---|
| `mode` | `check` | `check`, `validate`, `sync`, `render`, `generate`, or `drift`. |
| `paths` | `**/*.md` | `check`, `validate`, `sync`: the Markdown files, one glob, file, or folder per line; `!` leaves out a match. |
| `diagrams` | `**/*.diagram` | `check`, `validate`, `render`: the `.diagram` files. |
| `outDir` | `plotwork-svg` | `render`: the folder the SVGs go to; each file keeps its folder. |
| `failOn` | `error` | `error`, `warning`, or `never`. |
| `convertMermaid` | `false` | `check` and `sync`: treat each Mermaid fence that converts as a diagram. |
| `since` | empty | `drift` and `generate`: only the sources whose files changed since this git ref. Check out with `fetchDepth: 0`. |
| `publishTestResults` | `true` | `drift`: publish the JUnit report as a test run. |
| `onDrift` | `pr` | `generate`: `pr`, `commit`, `fail`, or `patch`. |
| `prBranch` | `plotwork/diagrams` | `generate`: the branch the task owns and pushes to. |
| `prTitle` | `docs: regenerate diagrams from their sources` | `generate`: the pull request's title. |
| `commitMessage` | `docs: regenerate diagrams from their sources` | `generate`: the commit message; the task adds `Plotwork-Generated: true`. |
| `publish` | `false` | `generate`: publish each source that has a `publish` section. |
| `comment` | `auto` | `drift` and `generate`: the pull request comment, `auto`, `always`, or `never`. |
| `rulesOrg` | empty | `check` and `validate`: apply this organisation's saved style rules. |
| `reportDrift` | `false` | `drift` and `generate`: send the run's metadata to the drift dashboard. |
| `plotworkConnection` | empty | The Plotwork service connection that holds the key. Empty reads `PLOTWORK_API_KEY`, then signs in as a trusted publisher. |
| `organization` | empty | The organisation to report to and sign in to. Empty is `rulesOrg`, then `brand.organization`, then the key's. |
| `config` | empty | The settings file. Empty finds `plotwork.config.json`, then `.plotwork/config.json`. |
| `workingDirectory` | `.` | The folder to run in, from `$(System.DefaultWorkingDirectory)`. |
| `summary` | `true` | Add the Plotwork summary tab to the run. |
| `apiUrl` | `https://api.plotwork.dev` | The Plotwork API. |
| `cliVersion` | the release this version was tested with | The release of `@buun_group/plotwork` the task runs. |

| Output variable | Meaning |
|---|---|
| `stale`, `errors`, `warnings` | The counts the run found. |
| `files` | A JSON array of paths from the repository root: what to sync, what has an error, or what the run wrote. |
| `changes` | `drift` and `generate`: one entry per drifted diagram, with a sentence naming its changes. |
| `pullRequest` | `generate`: the pull request it opened or updated. |
| `published` | `generate` with `publish`: what was published, with links. |
| `commentUrl` | The pull request comment it wrote or edited. |
| `driftUrl` | `reportDrift`: the drift dashboard the run was sent to. |
| `signedInAs` | The organisation and trusted publisher a run with no key signed in as. |
| `junitFile` | `drift`: the JUnit report. |
| `patchFile`, `changedFiles` | `generate`: the patch, and a JSON array of the files the run changed. |

Read an output in a later step by giving the task a `name`, such as `$(plotwork.errors)`.

## Licence

MIT. See [LICENSE](./LICENSE). The bundled packages and their licences are in `tasks/PlotworkDiagrams/dist/THIRD-PARTY-NOTICES.md`. This repository is built from the Plotwork monorepo; changes made here are written over by the next release.
