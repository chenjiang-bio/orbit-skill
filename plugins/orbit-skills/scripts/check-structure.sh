#!/usr/bin/env bash
set -u -o pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fail() { printf '%s\n' "$1" >&2; exit 1; }

[[ -f "$ROOT/.claude-plugin/plugin.json" ]] || fail 'missing Claude plugin manifest'
[[ -f "$ROOT/.codex-plugin/plugin.json" ]] || fail 'missing Codex plugin manifest'
[[ -f "$ROOT/.cursor-plugin/plugin.json" ]] || fail 'missing Cursor plugin manifest'
grep -Fq '"skills": "./skills/"' "$ROOT/.cursor-plugin/plugin.json" || fail 'Cursor plugin manifest must use canonical skills path'

version_from() {
  grep -m1 -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$1" | cut -d'"' -f4
}

claude_version=$(version_from "$ROOT/.claude-plugin/plugin.json")
codex_version=$(version_from "$ROOT/.codex-plugin/plugin.json")
cursor_version=$(version_from "$ROOT/.cursor-plugin/plugin.json")
[[ -n "$claude_version" && "$claude_version" == "$codex_version" && "$claude_version" == "$cursor_version" ]] || fail 'plugin manifest versions must match'
[[ -f "$ROOT/../../.claude-plugin/marketplace.json" ]] || fail 'missing Claude marketplace manifest'
marketplace_version=$(grep -m1 -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$ROOT/../../.claude-plugin/marketplace.json" | cut -d'"' -f4)
[[ "$claude_version" == "$marketplace_version" ]] || fail 'Claude marketplace version must match plugin manifests'
[[ -f "$ROOT/../../CHANGELOG.md" ]] || fail 'missing CHANGELOG.md'
changelog_version=$(grep -m1 -oE '^## [0-9]+\.[0-9]+\.[0-9]+' "$ROOT/../../CHANGELOG.md" | cut -d' ' -f2)
[[ "$claude_version" == "$changelog_version" ]] || fail 'CHANGELOG latest version must match plugin manifests'
[[ -f "$ROOT/LICENSE" ]] || fail 'missing LICENSE'
[[ -f "$ROOT/references/api-reference.md" ]] || fail 'missing API reference'
[[ -f "$ROOT/references/organoid-api-contract.md" ]] || fail 'missing API contract'
[[ -f "$ROOT/references/researcher-response-contract.md" ]] || fail 'missing researcher response contract'
[[ -f "$ROOT/references/cross-layer-evidence-graph.md" ]] || fail 'missing evidence graph'
[[ -f "$ROOT/references/sample-discovery-and-detail-handoff.md" ]] || fail 'missing handoff reference'
[[ -f "$ROOT/references/orbit-reason-capability-matrix.md" ]] || fail 'missing capability matrix'
[[ -x "$ROOT/scripts/orbit-request.sh" ]] || fail 'wrapper must be executable'
[[ -f "$ROOT/scripts/orbit-request.ps1" ]] || fail 'missing PowerShell wrapper'
[[ -f "$ROOT/scripts/orbit-request.local.env.example" ]] || fail 'missing env example'

skills=(orbit-search orbit-browse orbit-chat orbit-reason orbit-protocol orbit-design orbit-omics orbit-analysis orbit-help)
for skill in "${skills[@]}"; do
  [[ -f "$ROOT/skills/$skill/SKILL.md" ]] || fail "missing skill: $skill"
  grep -Fq 'researcher-response-contract.md' "$ROOT/skills/$skill/SKILL.md" || fail "skill $skill must reference researcher-response-contract.md"
done

# Every current and future skill must opt into the shared response contract.
while IFS= read -r skill_file; do
  grep -Fq 'researcher-response-contract.md' "$skill_file" || fail "skill $(basename "$(dirname "$skill_file")") must reference researcher-response-contract.md"
done < <(find "$ROOT/skills" -mindepth 2 -maxdepth 2 -type f -path '*/SKILL.md' -print)

if [[ -e "$ROOT/scripts/orbit-request.local.env" ]]; then
  fail 'local env must not be part of the release tree'
fi

if grep -R -nE 'tools/http-request|repository root|`(bash|powershell)[^`]*(tools/|\.\./)' "$ROOT/skills" "$ROOT/references" "$ROOT/scripts/README.md" >/dev/null; then
  fail 'stale repository-relative reference found'
fi

printf 'orbit-skills structure: OK\n'
