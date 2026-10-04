#!/usr/bin/env bash
#
# verify-docs.sh — the repository's document integrity test.
#
# This repo's only shipped artefact today is its document tree, so this is the test that
# every change runs before it is committed (CLAUDE.md, "Every change is verified").
# It needs nothing installed: bash, grep, sed, awk, find. No network, no git.
#
# Usage:
#   tests/docs/verify-docs.sh          # run every check
#   tests/docs/verify-docs.sh links    # run one check by name
#
# Exit status: 0 = every check passed, 1 = at least one check failed.
# A failure is a defect: fix it, or record it in docs/08-maintenance/defect-log.md.

set -u

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$REPO_ROOT" || exit 1

FAILURES=0
CHECKS_RUN=0
ONLY=${1:-all}

# Markdown files this test owns: the repo root, docs/, and the process contract in .ai/
# (read-only, but its links must still resolve). .git/ and .claude/ are excluded —
# .claude/worktrees/ holds whole copies of the repo and would be scanned many times over.
md_files() {
	find . -name '*.md' \
		-not -path './.git/*' \
		-not -path './.claude/*' \
		-not -path './node_modules/*' \
		| LC_ALL=C sort
}

# Inline code spans are prose, not instructions: `TODO` in a sentence about the TODO rule
# is not a TODO. Strip them before pattern checks.
strip_code_spans() {
	sed 's/`[^`]*`//g'
}

say_fail() {
	printf '  FAIL  %s\n' "$1"
	FAILURES=$((FAILURES + 1))
}

start_check() {
	CHECKS_RUN=$((CHECKS_RUN + 1))
	printf '\n[%s] %s\n' "$1" "$2"
}

wanted() {
	[ "$ONLY" = "all" ] || [ "$ONLY" = "$1" ]
}

# ---------------------------------------------------------------------------
# links — every relative markdown link resolves to a file that exists
# ---------------------------------------------------------------------------
check_links() {
	wanted links || return 0
	start_check links "relative markdown links resolve"
	local before=$FAILURES file dir target resolved
	for file in $(md_files); do
		dir=$(dirname "$file")
		# Pull every ](target) out of the file, one per line.
		for target in $(sed -n 's/.*](\([^)]*\)).*/\1/p' "$file" | tr -d '"' ); do
			case "$target" in
				http://*|https://*|mailto:*|'#'*|'') continue ;;
			esac
			# Drop any #anchor; links to a heading are checked as links to the file.
			resolved=${target%%#*}
			[ -n "$resolved" ] || continue
			case "$resolved" in
				/*) say_fail "$file -> $target (absolute path; use a relative link)"; continue ;;
			esac
			[ -e "$dir/$resolved" ] || say_fail "$file -> $target (no such file)"
		done
	done
	[ "$FAILURES" -eq "$before" ] && printf '  ok    all relative links resolve\n'
}

# ---------------------------------------------------------------------------
# status — every document declares its lifecycle state
# ---------------------------------------------------------------------------
# Phase documents open with `**Status**: ...` (CLAUDE.md, "The phase gate").
# ADRs follow .ai/templates/adr.md, which uses a `## Status` heading instead.
# Both are accepted; having neither is not.
check_status() {
	wanted status || return 0
	start_check status "every docs/ document declares a Status"
	local before=$FAILURES file
	for file in $(find docs -name '*.md' | LC_ALL=C sort); do
		case "$file" in
			docs/08-maintenance/defect-template.md) continue ;;
		esac
		if head -12 "$file" | grep -q '^\*\*Status\*\*'; then
			continue
		fi
		if grep -q '^## Status' "$file"; then
			continue
		fi
		say_fail "$file has no '**Status**:' line and no '## Status' heading"
	done
	[ "$FAILURES" -eq "$before" ] && printf '  ok    every document carries a Status\n'
}

# ---------------------------------------------------------------------------
# phases — the phase folders on disk and the table in CLAUDE.md agree
# ---------------------------------------------------------------------------
check_phases() {
	wanted phases || return 0
	start_check phases "phase folders match CLAUDE.md's phase table"
	local before=$FAILURES dir
	for dir in docs/[0-9][0-9]-*; do
		[ -d "$dir" ] || continue
		[ -f "$dir/README.md" ] || say_fail "$dir has no README.md"
		grep -q "$dir/" CLAUDE.md || say_fail "$dir is not listed in CLAUDE.md's phase table"
	done
	# And no table row names a folder that does not exist.
	for dir in $(sed -n 's|.*`docs/\([0-9][0-9]-[a-z-]*\)/`.*|docs/\1|p' CLAUDE.md | LC_ALL=C sort -u); do
		[ -d "$dir" ] || say_fail "CLAUDE.md names $dir/, which does not exist"
	done
	[ "$FAILURES" -eq "$before" ] && printf '  ok    phase folders and CLAUDE.md agree\n'
}

# ---------------------------------------------------------------------------
# adr-index — every ADR file appears in the ADR index
# ---------------------------------------------------------------------------
check_adr_index() {
	wanted adr-index || return 0
	start_check adr-index "every ADR is listed in docs/05-adr/README.md"
	local before=$FAILURES file base
	for file in docs/05-adr/[0-9][0-9][0-9]-*.md; do
		[ -f "$file" ] || continue
		base=$(basename "$file")
		grep -q "$base" docs/05-adr/README.md || say_fail "$base is not referenced in docs/05-adr/README.md"
	done
	[ "$FAILURES" -eq "$before" ] && printf '  ok    the ADR index is complete\n'
}

# ---------------------------------------------------------------------------
# no-todo — unfinished work is a backlog line, never a TODO marker
# ---------------------------------------------------------------------------
check_no_todo() {
	wanted no-todo || return 0
	start_check no-todo "no TODO/FIXME markers outside inline code"
	local before=$FAILURES file hits
	# The checker is exempt from its own marker scan: it must name the markers to detect them.
	for file in $(find docs src tests infrastructure -type f \
		\( -name '*.md' -o -name '*.sh' -o -name '*.rs' -o -name '*.ts' -o -name '*.toml' \) \
		-not -path 'tests/docs/verify-docs.sh' | LC_ALL=C sort); do
		hits=$(strip_code_spans < "$file" | grep -n -E 'TODO|FIXME' | head -3)
		[ -z "$hits" ] || say_fail "$file carries a TODO/FIXME marker: $(printf '%s' "$hits" | tr '\n' ';')"
	done
	[ "$FAILURES" -eq "$before" ] && printf '  ok    no TODO/FIXME markers\n'
}

# ---------------------------------------------------------------------------
# commands — no document claims a command the repo does not have
# ---------------------------------------------------------------------------
# package.json's scripts are scaffold residue: every one is an empty string, and
# CLAUDE.md says so. If a script gains a body, CLAUDE.md's "Commands" section has to
# change in the same commit — this check is what makes that non-optional.
check_commands() {
	wanted commands || return 0
	start_check commands "package.json scripts and CLAUDE.md's Commands section agree"
	local before=$FAILURES nonempty
	nonempty=$(sed -n '/"scripts"/,/}/p' package.json | grep -E '"[a-z:]+": *"[^"]+"' | sed 's/^ *//')
	if [ -n "$nonempty" ]; then
		if grep -q 'There are none yet' CLAUDE.md; then
			say_fail "package.json now has real scripts ($(printf '%s' "$nonempty" | tr '\n' ' ')) but CLAUDE.md still says there are no commands"
		fi
	fi
	# The one command that does exist must stay executable and documented.
	[ -x tests/docs/verify-docs.sh ] || say_fail "tests/docs/verify-docs.sh is not executable"
	grep -q 'tests/docs/verify-docs.sh' CLAUDE.md || say_fail "CLAUDE.md does not name the verification command"
	[ "$FAILURES" -eq "$before" ] && printf '  ok    documented commands match reality\n'
}

# ---------------------------------------------------------------------------
# defects — the defect log is internally consistent
# ---------------------------------------------------------------------------
check_defects() {
	wanted defects || return 0
	start_check defects "docs/08-maintenance/defect-log.md is consistent"
	local before=$FAILURES log id records index dupes
	log=docs/08-maintenance/defect-log.md
	if [ ! -f "$log" ]; then
		say_fail "$log is missing"
		return 0
	fi
	records=$(grep -o '^### D-[0-9][0-9][0-9]' "$log" | awk '{print $2}' | LC_ALL=C sort)
	index=$(grep -o '^| \[D-[0-9][0-9][0-9]\]' "$log" | sed 's/.*\[\(D-[0-9]*\)\].*/\1/' | LC_ALL=C sort)
	dupes=$(printf '%s\n' "$records" | uniq -d)
	[ -z "$dupes" ] || say_fail "duplicate defect records: $(printf '%s' "$dupes" | tr '\n' ' ')"
	for id in $index; do
		printf '%s\n' "$records" | grep -qx "$id" || say_fail "$id is in the index table but has no '### $id' record"
	done
	for id in $records; do
		printf '%s\n' "$index" | grep -qx "$id" || say_fail "$id has a record but is missing from the index table"
		# Every record carries the fields the template requires.
		awk -v id="$id" '
			$0 ~ "^### " id { inrec = 1; next }
			inrec && /^### / { exit }
			inrec { body = body "\n" $0 }
			END {
				n = 0
				if (body ~ /\*\*Severity\*\*/)  n++
				if (body ~ /\*\*Status\*\*/)    n++
				if (body ~ /\*\*Found by\*\*/)  n++
				if (body ~ /\*\*Impact\*\*/)    n++
				if (body ~ /\*\*Fix\*\*/)       n++
				if (n < 5) exit 3
			}
		' "$log" || say_fail "$id is missing one of Severity / Status / Found by / Impact / Fix"
	done
	[ "$FAILURES" -eq "$before" ] && printf '  ok    defect log is consistent\n'
}

# ---------------------------------------------------------------------------
# memory — the shared memory files stay answerable
# ---------------------------------------------------------------------------
check_memory() {
	wanted memory || return 0
	start_check memory "MEMORY.md and LEARN.md are present and dated"
	local before=$FAILURES ids dupes
	[ -f MEMORY.md ] || say_fail "MEMORY.md is missing"
	[ -f LEARN.md ] || say_fail "LEARN.md is missing"
	if [ -f MEMORY.md ]; then
		grep -q '_Last reviewed:' MEMORY.md || say_fail "MEMORY.md has no '_Last reviewed:' line"
	fi
	if [ -f LEARN.md ]; then
		ids=$(grep -o '^### L-[0-9][0-9][0-9]' LEARN.md | awk '{print $2}' | LC_ALL=C sort)
		dupes=$(printf '%s\n' "$ids" | uniq -d)
		[ -z "$dupes" ] || say_fail "duplicate LEARN.md entries: $(printf '%s' "$dupes" | tr '\n' ' ')"
	fi
	[ "$FAILURES" -eq "$before" ] && printf '  ok    shared memory files are in order\n'
}

check_links
check_status
check_phases
check_adr_index
check_no_todo
check_commands
check_defects
check_memory

printf '\n'
if [ "$CHECKS_RUN" -eq 0 ]; then
	printf 'no check named "%s"; valid names: links status phases adr-index no-todo commands defects memory\n' "$ONLY"
	exit 1
fi
if [ "$FAILURES" -eq 0 ]; then
	printf '%s checks passed.\n' "$CHECKS_RUN"
	exit 0
fi
printf '%s failure(s) across %s checks.\n' "$FAILURES" "$CHECKS_RUN"
printf 'Fix them, or record each one in docs/08-maintenance/defect-log.md.\n'
exit 1
