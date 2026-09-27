#!/usr/bin/env bash
#
# Create (or update) the label taxonomy this repo's issue forms rely on.
# Idempotent: re-running it refreshes colours and descriptions without duplicating labels.
#
# Requires: gh (https://cli.github.com), authenticated with write access to the repo.
# Usage:    ./.github/bootstrap-labels.sh [owner/repo]
#           Defaults to the repo of the current directory.

set -euo pipefail

REPO="${1:-}"
if [[ -z "$REPO" ]]; then
  if ! REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)"; then
    echo "error: not inside a GitHub repo and no owner/repo argument given" >&2
    exit 1
  fi
fi

# name|colour|description
LABELS=(
  "type:story|0e8a16|A unit of user-visible value"
  "type:defect|d73a4a|Behaviour contradicting an approved document or acceptance criterion"
  "type:task|c5def5|Scaffolding, tooling, CI, refactor, or spike — no direct user value"

  "P0|b60205|Must have — the release does not ship without it"
  "P1|fbca04|Should have"
  "P2|d4c5f9|Nice to have"

  "S1|5319e7|An action that should be denied is allowed, or the sandbox is bypassed"
  "S2|5319e7|A legitimate action is wrongly blocked, or the agent is unusable"
  "S3|5319e7|Wrong error code, misleading message, or missing audit entry"
  "S4|5319e7|Cosmetic or documentation-only"

  "status:needs-triage|ededed|Filed, not yet accepted into the backlog"
  "status:ready|0052cc|Triaged, estimated, and unblocked"
  "status:blocked|000000|Waiting on another issue or an open question"
  "status:needs-adr|1d76db|Cannot proceed until a decision is recorded in docs/05-adr/"

  "area:interceptor|bfd4f2|Agent hooks, MCP proxy, process interception"
  "area:policy-engine|bfd4f2|Rule matching, decisions, error codes"
  "area:local-model|bfd4f2|Local inference runtime and classifiers"
  "area:sandbox|bfd4f2|Filesystem, network, and process confinement"
  "area:masking|bfd4f2|PII, secret, and keyword handling"
  "area:audit-log|bfd4f2|Append-only decision record"
  "area:ui|bfd4f2|Policy editor and audit log viewer"
  "area:config|bfd4f2|Rule file format, loading, validation"
  "area:infra|bfd4f2|CI/CD, packaging, distribution"
  "area:docs|bfd4f2|Phase documents, ADRs, README"

  "phase:01-discovery|e99695|Traces to docs/01-discovery/"
  "phase:02-ux-design|e99695|Traces to docs/02-ux-design/"
  "phase:03-system-design|e99695|Traces to docs/03-system-design/"
  "phase:04-solution-design|e99695|Traces to docs/04-solution-design/"
  "phase:06-infrastructure|e99695|Traces to docs/06-infrastructure/"
  "phase:07-implementation|e99695|Traces to docs/07-implementation/"
)

for entry in "${LABELS[@]}"; do
  IFS='|' read -r name colour description <<<"$entry"
  if gh label create "$name" --repo "$REPO" --color "$colour" --description "$description" --force; then
    printf '  ok  %s\n' "$name"
  else
    printf 'FAIL  %s\n' "$name" >&2
    exit 1
  fi
done

echo
echo "Labels synced on $REPO."
