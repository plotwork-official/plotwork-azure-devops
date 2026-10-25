#!/usr/bin/env bash
# Reads a finished run of the read-only smoke pipeline (.azure-pipelines/plotwork-smoke.yml of plotwork-examples) and passes when
# the extension did all it should. This file is written by the Plotwork monorepo's build (apps/azure-devops/repo/.github/scripts
# there); a change made here is overwritten by the next release.
#
#   smoke-check.sh <timeline.json> <summaries.json>
#
#   timeline.json    GET _apis/build/builds/<id>/timeline
#   summaries.json   GET _apis/build/builds/<id>/attachments/Distributedtask.Core.Summary
#   TASK             the task name the release wrote, such as PlotworkDiagramsPreview
#   TASK_VERSION     its version, such as 1.2.3
#
# It checks that every step of TASK ran at TASK_VERSION; that each passed but the one that must fail, which failed; that the
# known-bad diagram's issue names its file and line; that the step reading the output variables passed; and that each step with
# a summary attached it. Each failure is a GitHub error annotation, and the exit code is the number of failures (capped at 1).
set -euo pipefail

timeline="$1"
summaries="$2"
: "${TASK:?TASK names the task}"
: "${TASK_VERSION:?TASK_VERSION names its version}"

MUST_FAIL='A known-bad diagram fails the step'
BAD='A known-bad diagram is reported on its line'
OUTPUTS='The outputs are as expected'
MIN_STEPS=8

failures=0
fail() {
  echo "::error::$1"
  failures=$((failures + 1))
}

steps=$(jq -c --arg task "$TASK" '[.records[] | select(.type == "Task" and .task.name == $task) | {id, name, result, version: .task.version, issues: (.issues // [])}]' "$timeline")
jq -r '.[] | "\(.name): \(.result), task \(.version)"' <<<"$steps"

count=$(jq 'length' <<<"$steps")
if [ "$count" -lt "$MIN_STEPS" ]; then fail "The run has $count $TASK steps, not $MIN_STEPS."; fi

wrong=$(jq -r --arg v "$TASK_VERSION" '[.[] | select(.version != $v) | .name] | join(", ")' <<<"$steps")
if [ -n "$wrong" ]; then fail "These steps ran $TASK at another version than $TASK_VERSION: $wrong"; fi

failed=$(jq -r --arg must "$MUST_FAIL" '[.[] | select(.name != $must and .result != "succeeded") | "\(.name) (\(.result))"] | join(", ")' <<<"$steps")
if [ -n "$failed" ]; then fail "These Plotwork steps did not pass: $failed"; fi

must=$(jq -r --arg must "$MUST_FAIL" '[.[] | select(.name == $must) | .result] | first // "missing"' <<<"$steps")
case "$must" in
  failed | succeededWithIssues) echo "$MUST_FAIL: $must, as it should." ;;
  *) fail "The step '$MUST_FAIL' is $must; a diagram with an error must fail it." ;;
esac

# An issue's data names its place in lower case (sourcepath, linenumber) or camel case, by the agent's version; both are read.
placed=$(jq -r --arg bad "$BAD" '
  [.[] | select(.name == $bad) | .issues[]
   | select(.type == "error")
   | (.data // {} | with_entries(.key |= ascii_downcase)) as $d
   | select(($d.sourcepath // "") == "smoke-bad/bad.diagram" and (($d.linenumber // "") | tostring) == "3")]
  | length' <<<"$steps")
if [ "$placed" -lt 1 ]; then
  fail "The step '$BAD' has no error issue on smoke-bad/bad.diagram line 3. Its issues: $(jq -c --arg bad "$BAD" '[.[] | select(.name == $bad) | .issues[]]' <<<"$steps")"
else
  echo "$BAD: an error issue on smoke-bad/bad.diagram line 3."
fi

outputs=$(jq -r --arg name "$OUTPUTS" '[.records[] | select(.type == "Task" and .name == $name) | .result] | first // "missing"' "$timeline")
if [ "$outputs" != "succeeded" ]; then fail "The step '$OUTPUTS' is $outputs: an output variable is wrong (its log says which)."; fi

# Each step with a summary (all but the one that must fail) attached one, as an attachment of type Distributedtask.Core.Summary.
want=$(jq --arg must "$MUST_FAIL" '[.[] | select(.name != $must)] | length' <<<"$steps")
total=$(jq -r '.count // (.value // [] | length)' "$summaries")
if [ "$total" -lt "$want" ]; then
  fail "The run has $total Plotwork summaries, not one for each of the $want steps that write one."
else
  echo "The Plotwork steps attached $total summaries."
fi

if [ "$failures" -gt 0 ]; then exit 1; fi
echo "The smoke pipeline passed with $TASK $TASK_VERSION."
