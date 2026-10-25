#!/usr/bin/env bash
# The write half of the smoke test: generate in write mode opens a pull request on Azure Repos, and abandons it once nothing
# drifts. This file is written by the Plotwork monorepo's build (apps/azure-devops/repo/.github/scripts there); a change made here
# is overwritten by the next release.
#
# Signed in as the Publish workflow's service principal (az login), it
#   1. makes the Azure Repos repository REPO in ORG/PROJECT if it is missing, and the pipeline plotwork-smoke-write from its
#      .azure-pipelines/plotwork-smoke-write.yml if that is missing;
#   2. pushes plotwork-examples (EXAMPLES_REPO) to its main with a made-up service added to compose.yaml, queues the pipeline
#      with expectDrift true, and checks that the run passed and a pull request from plotwork/diagrams is open;
#   3. pushes plotwork-examples again as it is, queues the pipeline with expectDrift false, and checks that the run passed, the
#      pull request is abandoned, and its branch is gone.
# With PLOTWORK_ORG set, both runs also report drift and publish to that organisation as a trusted publisher.
#
# Each push is a new commit on top of the copy's main, so the service principal needs no force push. The pipeline pushes with the
# build service: the owner grants it Contribute, Create branch, and Contribute to pull requests on REPO once.
#
# Environment: ORG, PROJECT, REPO, CHANNEL (preview or stable), CLI (the command line release), TASK and TASK_VERSION, and
# optionally PLOTWORK_ORG, API_URL (https://api-preview.plotwork.dev), EXAMPLES_REPO.
set -euo pipefail

: "${ORG:?}" "${PROJECT:?}" "${REPO:?}" "${CHANNEL:?}" "${CLI:?}" "${TASK:?}" "${TASK_VERSION:?}"
API_URL="${API_URL:-https://api-preview.plotwork.dev}"
EXAMPLES_REPO="${EXAMPLES_REPO:-https://github.com/plotwork-official/plotwork-examples.git}"
PLOTWORK_ORG="${PLOTWORK_ORG:-}"
PIPELINE_NAME=plotwork-smoke-write
PIPELINE_FILE=.azure-pipelines/plotwork-smoke-write.yml
BRANCH=plotwork/diagrams
AZURE_DEVOPS=499b84ac-1321-427f-aa17-267ca6975798
base="https://dev.azure.com/$ORG/$PROJECT"
remote="$base/_git/$REPO"
work="${RUNNER_TEMP:-$(mktemp -d)}/smoke-write"

new_token() {
  token="$(az account get-access-token --resource "$AZURE_DEVOPS" --query accessToken -o tsv)"
  echo "::add-mask::$token"
}
# One REST call: the body to standard output, and its HTTP status kept for `status` (a command substitution is a subshell, so
# the status cannot be a variable).
status_file=$(mktemp)
ado() {
  : >"$status_file.body"
  curl -sS -o "$status_file.body" -w '%{http_code}' -H "Authorization: Bearer $token" -H 'Content-Type: application/json' "$@" >"$status_file" || echo 000 >"$status_file"
  cat "$status_file.body"
}
status() { cat "$status_file"; }
git_auth() { git -c "http.$remote.extraheader=" -c "http.$remote.extraheader=AUTHORIZATION: bearer $token" "$@"; }
owner_step() { echo "::error::$1 The owner's one-time steps are in docs/releasing-the-azure-devops-extension.md of the Plotwork monorepo (Smoke test)."; exit 1; }

new_token

# 1. The repository and the pipeline.
project_id=$(ado "https://dev.azure.com/$ORG/_apis/projects/$PROJECT?api-version=7.1" | jq -r '.id // empty')
[ -n "$project_id" ] || owner_step "The service principal cannot read the project $PROJECT (HTTP $(status))."
repo_json=$(ado "$base/_apis/git/repositories/$REPO?api-version=7.1")
if [ "$(status)" = "404" ]; then
  repo_json=$(ado -X POST "$base/_apis/git/repositories?api-version=7.1" -d "$(jq -n --arg name "$REPO" --arg project "$project_id" '{name: $name, project: {id: $project}}')")
  [ "$(status)" = "201" ] || [ "$(status)" = "200" ] || owner_step "The repository $REPO is missing, and the service principal may not create it (HTTP $(status)): create it in $PROJECT, empty."
  echo "Created the repository $REPO."
fi
repo_id=$(jq -r '.id // empty' <<<"$repo_json")
[ -n "$repo_id" ] || owner_step "The repository $REPO could not be read (HTTP $(status))."

rm -rf "$work"
git clone --quiet --depth 1 "$EXAMPLES_REPO" "$work"

# Pushes the examples, with the made-up change when $1 is drift, as one new commit on top of the copy's main.
push_examples() {
  (
    cd "$work"
    git reset --quiet --hard HEAD
    if [ "$1" = "drift" ]; then
      sed -i 's/^services:$/services:\n  smoke-cache:\n    image: redis:7-alpine\n    networks: [data]\n/' compose.yaml
      grep -q 'smoke-cache' compose.yaml
    fi
    git add -A
    tree=$(git write-tree)
    parent=()
    if git_auth fetch --quiet --depth 1 "$remote" main 2>/dev/null; then parent=(-p "$(git rev-parse FETCH_HEAD)"); fi
    commit=$(git -c user.name='Plotwork smoke' -c user.email=noreply@plotwork.dev commit-tree "$tree" "${parent[@]}" -m "smoke: plotwork-examples $(git rev-parse --short HEAD) ($1)")
    git_auth push --quiet "$remote" "$commit:refs/heads/main"
    echo "Pushed $commit ($1) to $REPO main."
  )
}

push_examples drift

pipeline_id=$(ado "$base/_apis/pipelines?api-version=7.1&\$top=1000" | jq -r --arg name "$PIPELINE_NAME" '[.value[]? | select(.name == $name) | .id] | first // empty')
if [ -z "$pipeline_id" ]; then
  body=$(jq -n --arg name "$PIPELINE_NAME" --arg path "/$PIPELINE_FILE" --arg id "$repo_id" --arg repo "$REPO" '{name: $name, folder: "\\", configuration: {type: "yaml", path: $path, repository: {id: $id, name: $repo, type: "azureReposGit"}}}')
  pipeline_id=$(ado -X POST "$base/_apis/pipelines?api-version=7.1" -d "$body" | jq -r '.id // empty')
  [ -n "$pipeline_id" ] || owner_step "The pipeline $PIPELINE_NAME is missing, and the service principal may not create it (HTTP $(status)): create it from $PIPELINE_FILE of $REPO."
  echo "Created the pipeline $PIPELINE_NAME ($pipeline_id)."
fi
echo "::notice::The write smoke runs the pipeline $PIPELINE_NAME, definition id $pipeline_id. A trusted publisher entry for keyless runs names this id."

# Queues the pipeline with expectDrift $1, waits for it, and checks the Plotwork step and the output check passed.
run_pipeline() {
  local expect="$1" body run id link state timeline
  body=$(jq -n --arg channel "$CHANNEL" --arg cli "$CLI" --arg expect "$expect" --arg org "${PLOTWORK_ORG:- }" --arg api "$API_URL" \
    '{resources: {repositories: {self: {refName: "refs/heads/main"}}}, templateParameters: {channel: $channel, cliVersion: $cli, expectDrift: $expect, plotworkOrg: $org, apiUrl: $api}}')
  run=$(ado -X POST "$base/_apis/pipelines/$pipeline_id/runs?api-version=7.1" -d "$body")
  id=$(jq -r '.id // empty' <<<"$run")
  [ -n "$id" ] || { echo "::error::Queuing $PIPELINE_NAME failed (HTTP $(status)): $(head -c 400 <<<"$run")"; return 1; }
  link=$(jq -r '._links.web.href' <<<"$run")
  echo "Queued run $id (expectDrift $expect): $link"
  state=""
  for attempt in $(seq 1 60); do
    if [ $((attempt % 10)) -eq 0 ]; then new_token; fi
    state=$(ado "$base/_apis/pipelines/$pipeline_id/runs/$id?api-version=7.1" | jq -r '.state')
    if [ "$state" = "completed" ]; then break; fi
    sleep 20
  done
  [ "$state" = "completed" ] || { echo "::error::Run $id had not finished after 20 minutes: $link"; return 1; }
  timeline=$(ado "$base/_apis/build/builds/$id/timeline?api-version=7.1")
  jq -r '.records[] | select(.type == "Task") | "\(.name): \(.result)"' <<<"$timeline"
  bad=$(jq -r --arg task "$TASK" --arg v "$TASK_VERSION" '[.records[] | select(.type == "Task" and ((.task.name == $task and (.result != "succeeded" or .task.version != $v)) or (.name == "The outputs are as expected" and .result != "succeeded"))) | "\(.name) (\(.result), \(.task.version))"] | join(", ")' <<<"$timeline")
  steps=$(jq --arg task "$TASK" '[.records[] | select(.type == "Task" and .task.name == $task)] | length' <<<"$timeline")
  if [ "$steps" -lt 1 ] || [ -n "$bad" ]; then
    echo "::error::Run $id of $PIPELINE_NAME (expectDrift $expect) did not pass: ${bad:-no $TASK step}. A push or pull request Azure Repos refused usually means the build service lacks Contribute, Create branch, or Contribute to pull requests on $REPO: $link"
    return 1
  fi
}

# Abandons an open pull request of the task's branch, so a failed run leaves nothing open.
cleanup() {
  local open
  new_token
  open=$(ado "$base/_apis/git/repositories/$repo_id/pullrequests?searchCriteria.sourceRefName=refs/heads/$BRANCH&searchCriteria.status=active&api-version=7.1" | jq -r '.value[]?.pullRequestId')
  for pr in $open; do
    ado -X PATCH "$base/_apis/git/repositories/$repo_id/pullrequests/$pr?api-version=7.1" -d '{"status": "abandoned"}' >/dev/null
    echo "::warning::Abandoned pull request $pr of $REPO, which the run left open (HTTP $(status))."
  done
}
trap 'if [ "$?" -ne 0 ]; then cleanup; fi' EXIT

# 2. A drift opens a pull request.
run_pipeline true
prs=$(ado "$base/_apis/git/repositories/$repo_id/pullrequests?searchCriteria.sourceRefName=refs/heads/$BRANCH&searchCriteria.targetRefName=refs/heads/main&searchCriteria.status=active&api-version=7.1")
pr=$(jq -r '.value[0].pullRequestId // empty' <<<"$prs")
[ -n "$pr" ] || { echo "::error::The run passed, but no pull request from $BRANCH into main is open in $REPO."; exit 1; }
echo "Pull request $pr is open: $(jq -r '.value[0].title' <<<"$prs")"

# 3. Nothing drifts any more: the task abandons its pull request and deletes its branch.
new_token
push_examples clean
run_pipeline false
status=$(ado "$base/_apis/git/repositories/$repo_id/pullrequests/$pr?api-version=7.1" | jq -r '.status')
[ "$status" = "abandoned" ] || { echo "::error::Pull request $pr is $status, not abandoned, after a run with nothing drifted."; exit 1; }
left=$(ado "$base/_apis/git/repositories/$repo_id/refs?filter=heads/$BRANCH&api-version=7.1" | jq -r '[.value[]? | select(.name == "refs/heads/'"$BRANCH"'")] | length')
[ "$left" = "0" ] || { echo "::error::The branch $BRANCH is still in $REPO after the task abandoned its pull request."; exit 1; }
echo "Pull request $pr was abandoned and $BRANCH deleted once nothing drifted."
if [ -z "$PLOTWORK_ORG" ]; then echo "::notice::Keyless drift reports and publishing were not tested: set AZURE_DEVOPS_SMOKE_PLOTWORK_ORG to the Plotwork organisation that trusts $PIPELINE_NAME ($pipeline_id)."; fi
