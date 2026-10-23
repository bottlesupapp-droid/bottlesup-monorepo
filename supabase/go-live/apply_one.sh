#!/usr/bin/env bash
# Applies ONE website migration to PRODUCTION inside its own transaction (all of it or none of it), then checks that every function, table and
# storage policy the file creates exists. Stops with a non-zero exit on any failure. ONLY on the user's explicit instruction for that migration.
#
#   WORKDIR=<scratch dir linked to the project> supabase/go-live/apply_one.sh <migration file name without .sql>
#
# Setting up WORKDIR (a throwaway folder, delete it afterwards):  mkdir w && supabase init --workdir w && supabase link --project-ref <ref> --workdir w
# Read-only checks before (names free, prerequisites present) and an audit after (supabase/audit/13_... is the template) are part of the method;
# see HANDOFF "Rules learned". DRY_RUN=1 only prints what the file would create and writes the wrapped file; it touches nothing.
set -uo pipefail
NAME="${1:-}"
[ -n "$NAME" ] || { echo "usage: WORKDIR=<linked dir> $0 <migration name without .sql>"; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../../apps/bottles-up-website-main/supabase/migrations/$NAME.sql"
[ -f "$SRC" ] || { echo "no such migration: $SRC"; exit 2; }
OUT="${TMPDIR:-/tmp}/apply_one_$$"; mkdir -p "$OUT"

# The file exactly as committed, inside one transaction.
{ printf 'begin;\n'; cat "$SRC"; printf '\ncommit;\n'; } > "$OUT/wrapped.sql"

# What this migration creates, read from the file itself.
python3 -I - "$SRC" > "$OUT/present.sql" <<'PY'
import re, sys
code = re.sub(r'--[^\n]*', '', open(sys.argv[1]).read())
funcs = sorted(set(re.findall(r'create\s+function\s+public\.([a-z_0-9]+)', code, re.I)))
tables = sorted(set(re.findall(r'create\s+table\s+public\.([a-z_0-9]+)', code, re.I)))
pols = sorted(set(re.findall(r'create\s+policy\s+"([^"]+)"\s+on\s+storage\.objects', code, re.I)))
arr = lambda xs: "array[" + ",".join("'" + x + "'" for x in xs) + "]::text[]"
print(f"""select kind, name, present from (
  select 'function' as kind, f as name, exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = f) as present from unnest({arr(funcs)}) f
  union all select 'table', t, to_regclass('public.' || t) is not null from unnest({arr(tables)}) t
  union all select 'storage policy', pol, exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = pol) from unnest({arr(pols)}) pol
) q order by present, kind, name""")
PY
echo "== $NAME ($(wc -l < "$SRC" | tr -d ' ') lines): creates $(grep -o "array\[[^]]*\]" "$OUT/present.sql" | grep -o "'" | wc -l | awk '{print $1/2}') objects"
if [ "${DRY_RUN:-}" = "1" ]; then echo "dry run: wrapped file at $OUT/wrapped.sql, nothing sent"; exit 0; fi
[ -n "${WORKDIR:-}" ] || { echo "set WORKDIR to a linked scratch dir (see the header)"; exit 2; }

supabase db query --linked --workdir "$WORKDIR" -f "$OUT/wrapped.sql" > "$OUT/applied.out" 2>&1
STATUS=$?
grep -v "new version of Supabase CLI\|We recommend updating" "$OUT/applied.out" | head -20
if [ $STATUS -ne 0 ] || grep -qiE '"error"|^error|ERROR:|SQLSTATE' "$OUT/applied.out"; then
  echo "!! FAILED (exit $STATUS): nothing from this migration is applied (it ran in one transaction)"; exit 1
fi

# A migration that only changes existing objects (constraints, columns) creates nothing to look for; zero rows would otherwise be reported as a failure.
if [ "$(grep -o "array\[[^]]*\]" "$OUT/present.sql" | grep -o "'" | wc -l | tr -d ' ')" = "0" ]; then
  echo "   applied. It creates no functions, tables or policies, so there is nothing to look for here: run the read-only audit named for it in docs/FINAL_STEPS.md."; exit 0
fi

supabase db query --linked --workdir "$WORKDIR" -f "$OUT/present.sql" > "$OUT/present.json" 2>/dev/null
python3 -I - "$OUT/present.json" <<'PY'
import json, sys
raw = open(sys.argv[1]).read()
rows = json.loads(raw[raw.index('{'):])['rows']
missing = [r for r in rows if not r['present']]
print(f"   objects it creates: {len(rows)}; present: {len(rows) - len(missing)}; MISSING: {len(missing)}")
for r in missing: print("   MISSING:", r['kind'], r['name'])
sys.exit(1 if missing or not rows else 0)
PY
