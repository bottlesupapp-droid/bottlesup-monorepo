#!/usr/bin/env python3 -I
"""Builds the production files for the ten social website migrations 20261101100000 .. 20261110100000 (branch feat/social-backend):

  supabase/go-live/apply_social.sql      the ten migrations in ONE paste, each in its own begin/commit, byte for byte the files in supabase/migrations
  supabase/go-live/rollback_social.sql   the undo (built from the same files): refuses while real people's content exists, otherwise removes everything the migrations made
  supabase/audit/22_preflight_social.sql  read-only: lists what would stop the apply (names already taken, prerequisites missing)
  supabase/audit/23_postflight_social.sql read-only: after the apply every row says ok = true

    python3 -I supabase/go-live/build_social.py            write the four files
    python3 -I supabase/go-live/build_social.py --check    exit 1 if any file is not what the migrations say (run it before pasting anything)

The files are generated so they cannot drift from the migrations: change a migration, run this, commit all of it.
Everything the migrations do is additive: new tables, functions, triggers, one storage bucket with three policies, and new columns on site_venues. Nothing existing is replaced.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SITE = ROOT / "apps" / "bottles-up-website-main"
MIG = SITE / "supabase" / "migrations"
OUT = ROOT / "supabase" / "go-live"
AUDIT = ROOT / "supabase" / "audit"

NAMES = [
    "20261101100000_feature_flags",
    "20261101110000_social_profiles",
    "20261102100000_social_posts",
    "20261103100000_explore_reviews",
    "20261104100000_inbox_notifications",
    "20261105100000_safety_moderation",
    "20261106100000_split_payments",
    "20261107100000_service_marketplace",
    "20261108100000_venue_hire_teams",
    "20261109100000_billing_referrals_earnings",
    "20261110100000_recognition_jobs",
]
BUCKET = "social-media"
BAR = "-- " + "=" * 100


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def code_of(sql: str) -> str:
    """The SQL without its comments (so words in a comment are never mistaken for code)."""
    return re.sub(r"--[^\n]*", "", sql)


ALL = {n: read(MIG / f"{n}.sql") for n in NAMES}
CODE = {n: code_of(s) for n, s in ALL.items()}
JOINED = "\n".join(CODE.values())


def created_functions():
    out = []
    for n in NAMES:
        out += re.findall(r"create\s+function\s+public\.([a-z_0-9]+)\s*\(", CODE[n], re.I)
    return out


def created_tables():
    out = []
    for n in NAMES:
        out += re.findall(r"create\s+table\s+public\.([a-z_0-9]+)", CODE[n], re.I)
    return out


def created_triggers():
    """(name, table) of every trigger the migrations create."""
    return re.findall(r"create\s+trigger\s+([a-z_0-9]+)\b[^;]*?\bon\s+((?:public|auth)\.[a-z_0-9]+)", JOINED, re.I | re.S)


def created_policies():
    return re.findall(r'create\s+policy\s+"([^"]+)"\s+on\s+storage\.objects', JOINED, re.I)


def created_indexes():
    """(name, table) of every index the migrations create. Index names are unique per schema, so each one is checked before and after, whichever table it is on."""
    return re.findall(r"create\s+(?:unique\s+)?index\s+(?:if\s+not\s+exists\s+)?([a-z_0-9]+)\s+on\s+(?:only\s+)?public\.([a-z_0-9]+)", JOINED, re.I)


def indexes_on_existing():
    """The indexes on tables that existed before: dropping the new tables does not drop these, so the undo must."""
    own = set(created_tables())
    return [(n, t) for n, t in created_indexes() if t not in own]


def refuse_unknown_kinds():
    """The bundle knows how to check and undo tables, functions, triggers, indexes, storage policies, columns and constraints. Anything else would be missed by the undo: stop here."""
    kinds = re.findall(r"\bcreate\s+(?:or\s+replace\s+)?(?:unique\s+)?(type|domain|view|materialized\s+view|sequence|extension|schema|rule|aggregate|operator|collation|publication)\b", JOINED, re.I)
    if kinds:
        raise SystemExit("build_social.py does not know how to undo: " + ", ".join(sorted(set(k.lower() for k in kinds))) + " (teach it before generating)")


refuse_unknown_kinds()


def altered_existing():
    """(table, [columns added], [constraints added]) for each existing table the migrations alter."""
    own = set(created_tables())
    result = {}
    for m in re.finditer(r"alter\s+table\s+public\.([a-z_0-9]+)\b([^;]*);", JOINED, re.I | re.S):
        table, body = m.group(1), m.group(2)
        if table in own:
            continue
        cols = re.findall(r"add\s+column\s+(?:if\s+not\s+exists\s+)?([a-z_0-9]+)", body, re.I)
        cons = re.findall(r"add\s+constraint\s+([a-z_0-9]+)", body, re.I)
        if cols or cons:
            entry = result.setdefault(table, ([], []))
            entry[0].extend(cols)
            entry[1].extend(cons)
    return result


def feature_keys():
    m = re.search(r"insert\s+into\s+public\.site_feature_flags\s*\(key,\s*note\)\s*values(.*?)\)\s*;\s*\n", CODE[NAMES[0]], re.I | re.S)
    assert m
    return re.findall(r"\(\s*'([a-z_0-9]+)'\s*,", m.group(1))


def grants():
    """Which created functions each role may call, from the migrations' own grant statements."""
    anon, authed, service = set(), set(), set()
    for m in re.finditer(r"grant\s+execute\s+on\s+function\s+(.*?)\s+to\s+([a-z_,\s]+?);", JOINED, re.I | re.S):
        names = re.findall(r"public\.([a-z_0-9]+)\s*\(", m.group(1))
        roles = {r.strip() for r in m.group(2).split(",")}
        if "anon" in roles:
            anon.update(names)
        if "authenticated" in roles:
            authed.update(names)
        if "service_role" in roles:
            service.update(names)
    return anon, authed, service


def prerequisites():
    """Existing public tables, views and functions the migrations use (every public.<name> that the migrations do not create themselves)."""
    own = set(created_tables()) | set(created_functions())
    # indexes are named in `create index NAME on public.T`: the name has no public. prefix, so nothing to exclude; types are not used
    used = set(re.findall(r"\bpublic\.([a-z_][a-z_0-9]*)", JOINED, re.I))
    return sorted(used - own)


def sql_array(xs):
    return "array[" + ", ".join(f"'{x}'" for x in xs) + "]::text[]"


def build_apply() -> str:
    parts = [
        "-- ALL TEN SOCIAL MIGRATIONS IN ONE PASTE (website branch feat/social-backend, same bytes as apps/bottles-up-website-main/supabase/migrations/20261101100000 .. 20261110100000):\n"
        "-- feature switches, social profiles (usernames, following, blocking), posts and stories and comments and the private media bucket, explore and reviews and venue facts, messages\n"
        "-- and notifications, safety and moderation (reports, the staff queue, suspending a person, the community rules text).\n"
        "-- GENERATED by supabase/go-live/build_social.py: do not edit it by hand (python3 -I supabase/go-live/build_social.py --check says whether it is current).\n"
        "-- EVERYTHING IS ADDITIVE and every feature starts SWITCHED OFF: nothing in the apps changes until a switch is turned on in the website's CMS (Social settings).\n"
        "-- HOW: run supabase/audit/22_preflight_social.sql FIRST (it must return no rows), then paste this whole file into the Supabase dashboard > SQL editor (production project) and Run.\n"
        "-- Each migration is wrapped in its own begin/commit, in this order, so an error rolls back THAT migration and stops the rest (the earlier ones stay applied; send the error\n"
        "-- text, do not edit a file). Then run supabase/audit/23_postflight_social.sql: every row ok = true. THEN deploy the edge functions and schedule the clean-up\n"
        "-- (supabase/go-live/README.md, \"Going live: the social side\").\n"
        "-- UNDO: supabase/go-live/rollback_social.sql. Never use `supabase db push`.\n\n"
    ]
    for name in NAMES:
        body = ALL[name]
        parts.append(f"{BAR}\n-- {name}\n{BAR}\nbegin;\n{body}")
        if not body.endswith("\n"):
            parts.append("\n")
        parts.append("commit;\n\n")
    return "".join(parts).rstrip("\n") + "\n"


def build_rollback() -> str:
    tables = created_tables()
    fns = sorted(set(created_functions()))
    triggers = created_triggers()
    policies = created_policies()
    altered = altered_existing()
    out = []
    out.append(
        "-- UNDO for the six social website migrations 20261101100000 .. 20261105100000. GENERATED by supabase/go-live/build_social.py: do not edit it by hand. One transaction.\n"
        "--\n"
        "-- IT REFUSES (and changes nothing) while people's content exists: any post, comment, message, review, report or follow. Those are people's words and pictures; switch the features\n"
        "-- off in the CMS (Social settings) instead, which hides the whole social side without deleting anything. This undo is for a launch that never opened (or a test project).\n"
        "-- IT ALSO REFUSES while the media bucket holds files (delete them in the dashboard first: the database cannot delete a file).\n"
        "-- WHAT IT REMOVES: the triggers, the three storage policies and the bucket, every function and table the migrations created (with the data in them: profiles, usernames, blocks,\n"
        "-- notification choices, the community rules text and what people accepted, the feature switches), and the columns and constraints they added to existing tables.\n"
        "-- WHAT STAYS: everything that existed before, and the audit log (it is history).\n"
        "-- AFTER IT: redeploy nothing; the customer app and the CMS pages handle \"not set up on this server yet\" and show nothing social.\n"
        "begin;\n\n"
    )
    checks = [
        ("site_posts", "posts"), ("site_comments", "comments"), ("site_dm_messages", "messages"), ("site_reviews", "reviews"), ("site_reports", "reports"), ("site_follows", "follows"),
        # money and agreements between people: kept for the people and for BottlesUp, never deleted by an undo
        ("site_split_shares", "shares of a bill"), ("site_pro_requests", "requests to professionals"), ("site_pro_payments", "payments for professionals"), ("site_hires", "venue hires"),
        ("site_subscriptions", "subscriptions"), ("site_referral_credits", "referral credits"), ("site_tips", "tips"),
        # recognition and jobs
        ("site_awards", "ranks awarded"), ("site_plaques", "plaque requests"), ("site_jobs", "jobs"), ("site_job_applications", "job applications"),
    ]
    out.append("do $refuse$\nbegin\n")
    for t, label in checks:
        out.append(f"  if to_regclass('public.{t}') is not null and exists (select 1 from public.{t}) then\n    raise exception 'there are {label}: that is people''s content, so it is kept (switch the features off in the CMS instead). Nothing was changed.';\n  end if;\n")
    out.append(
        f"  if exists (select 1 from storage.objects where bucket_id = '{BUCKET}') then\n"
        f"    raise exception 'the {BUCKET} bucket still holds files: delete them in the dashboard first. Nothing was changed.';\n  end if;\n"
        "end\n$refuse$;\n\n"
    )
    out.append("-- triggers\n")
    for name, table in triggers:
        out.append(f"drop trigger if exists {name} on {table};\n")
    out.append("\n-- the storage policies and the bucket\n")
    for p in policies:
        out.append(f'drop policy if exists "{p}" on storage.objects;\n')
    out.append(f"delete from storage.buckets where id = '{BUCKET}';\n\n")
    out.append("-- every function the migrations created (all overloads of each name)\n")
    out.append(
        "do $d$\ndeclare r record;\nbegin\n"
        f"  for r in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = any({sql_array(fns)}) loop\n"
        "    execute 'drop function ' || r.sig;\n  end loop;\nend\n$d$;\n\n"
    )
    out.append("-- every table the migrations created (they only point at each other and at people; nothing else points at them)\n")
    out.append("drop table if exists " + ", ".join(f"public.{t}" for t in tables) + " cascade;\n\n")
    extra_indexes = indexes_on_existing()
    if extra_indexes:
        out.append("-- the indexes they added to tables that existed before (dropping the new tables does not drop these)\n")
        for name, table in extra_indexes:
            out.append(f"drop index if exists public.{name};\n")
        out.append("\n")
    if altered:
        out.append("-- what they added to existing tables\n")
        for table, (cols, cons) in altered.items():
            for c in cons:
                out.append(f"alter table public.{table} drop constraint if exists {c};\n")
            if cols:
                out.append(f"alter table public.{table} " + ", ".join(f"drop column if exists {c}" for c in cols) + ";\n")
    out.append("\ncommit;\n")
    return "".join(out)


def build_preflight() -> str:
    tables = created_tables()
    fns = sorted(set(created_functions()))
    triggers = created_triggers()
    policies = created_policies()
    altered = altered_existing()
    cols = [f"{t}.{c}" for t, (cs, _) in altered.items() for c in cs]
    cons = [(t, c) for t, (_, cs) in altered.items() for c in cs]
    rows = []
    rows.append(f"""select 'function already exists' as problem, p.proname::text as name
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = any({sql_array(fns)})""")
    rows.append(f"""select 'table already exists', t from unnest({sql_array(tables)}) t where to_regclass('public.' || t) is not null""")
    rows.append(f"""select 'column already exists', x from unnest({sql_array(cols)}) x
  where exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = split_part(x, '.', 1) and c.column_name = split_part(x, '.', 2))""")
    if cons:
        values = ", ".join(f"('{t}', '{c}')" for t, c in cons)
        rows.append(f"""select 'constraint already exists', x.c from (values {values}) as x(t, c)
  where exists (select 1 from pg_constraint k where k.conname = x.c and k.conrelid = to_regclass('public.' || x.t))""")
    rows.append(f"""select 'index already exists', i.indexname::text from pg_indexes i where i.schemaname = 'public' and i.indexname = any({sql_array([n for n, _ in created_indexes()])})""")
    rows.append(f"""select 'trigger already exists', t.tgname::text from pg_trigger t where not t.tgisinternal and t.tgname = any({sql_array([n for n, _ in triggers])})""")
    rows.append(f"""select 'storage policy already exists', p.policyname::text from pg_policies p where p.schemaname = 'storage' and p.tablename = 'objects' and p.policyname = any({sql_array(policies)})""")
    rows.append(f"""select 'storage bucket already exists', b.id::text from storage.buckets b where b.id = '{BUCKET}'""")
    prereq = prerequisites()
    rows.append(f"""select 'MISSING prerequisite (a table, view or function the migrations use)', n from unnest({sql_array(prereq)}) n
  where to_regclass('public.' || n) is null and not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = n)""")
    rows.append("""select 'MISSING prerequisite', 'storage schema (buckets, objects)' where to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null""")
    rows.append("""select 'MISSING prerequisite', 'auth.users' where to_regclass('auth.users') is null""")
    body = "\nunion all\n".join(rows)
    return f"""-- 22: PRE-FLIGHT for the six social website migrations 20261101100000 .. 20261105100000 (branch feat/social-backend). Read-only. It lists problems; ROWS = STOP.
-- GENERATED by supabase/go-live/build_social.py: do not edit it by hand.
--   * something these files create already exists (the files are plain CREATEs: they would fail), including the {BUCKET} bucket and its policies;
--   * something they rely on is missing (the earlier migrations, or an object that exists only in production).
-- A missing COLUMN of an existing table is not listed here: it stops that migration (nothing from it is applied) with a plain error, which is the same safe outcome.
-- On a database built from the repository's migrations before these six, it returns no rows.
{body};
"""


def build_postflight() -> str:
    tables = created_tables()
    fns = sorted(set(created_functions()))
    triggers = created_triggers()
    policies = created_policies()
    altered = altered_existing()
    cols = [f"{t}.{c}" for t, (cs, _) in altered.items() for c in cs]
    anon, authed, service = grants()
    anon_set = sorted(anon & set(fns))
    signed_in = sorted((authed - anon) & set(fns))
    service_only = sorted((service - authed - anon) & set(fns))
    internal = sorted(set(fns) - anon - authed - service)
    flags = feature_keys()
    checks = []

    def add(name, actual, expected, ok):
        checks.append((name, actual, expected, ok))

    add("every table was created", f"(select count(*) from unnest({sql_array(tables)}) t where to_regclass('public.' || t) is not null)::text", f"'{len(tables)}'",
        f"(select count(*) from unnest({sql_array(tables)}) t where to_regclass('public.' || t) is not null) = {len(tables)}")
    add("row level security is on for every one of them", f"(select count(*) from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = any({sql_array(tables)}) and c.relrowsecurity)::text", f"'{len(tables)}'",
        f"(select count(*) from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = any({sql_array(tables)}) and c.relrowsecurity) = {len(tables)}")
    add("visitors and signed-in people have no direct access to any of them",
        f"(select count(*) from unnest({sql_array(tables)}) t, (values ('anon'), ('authenticated')) r(role), (values ('select'), ('insert'), ('update'), ('delete')) p(priv) where to_regclass('public.' || t) is not null and has_table_privilege(r.role, 'public.' || t, p.priv))::text", "'0'",
        f"(select count(*) from unnest({sql_array(tables)}) t, (values ('anon'), ('authenticated')) r(role), (values ('select'), ('insert'), ('update'), ('delete')) p(priv) where to_regclass('public.' || t) is not null and has_table_privilege(r.role, 'public.' || t, p.priv)) = 0")
    add("every function was created", f"(select count(distinct p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any({sql_array(fns)}))::text", f"'{len(fns)}'",
        f"(select count(distinct p.proname) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = any({sql_array(fns)})) = {len(fns)}")
    fn = "pg_proc p where p.pronamespace = 'public'::regnamespace"
    add(f"only these {len(anon_set)} can be called by a visitor: {', '.join(anon_set)}",
        f"(select string_agg(p.proname, ', ' order by p.proname) from {fn} and p.proname = any({sql_array(fns)}) and has_function_privilege('anon', p.oid, 'execute'))", f"'{', '.join(anon_set)}'",
        f"coalesce((select string_agg(p.proname, ', ' order by p.proname) from {fn} and p.proname = any({sql_array(fns)}) and has_function_privilege('anon', p.oid, 'execute')), '') = '{', '.join(anon_set)}'")
    add(f"the {len(signed_in)} functions the apps call can be called by a signed-in person",
        f"(select count(*) from {fn} and p.proname = any({sql_array(signed_in)}) and has_function_privilege('authenticated', p.oid, 'execute'))::text", f"'{len(signed_in)}'",
        f"(select count(*) from {fn} and p.proname = any({sql_array(signed_in)}) and has_function_privilege('authenticated', p.oid, 'execute')) = {len(signed_in)}")
    hidden = sorted(set(service_only) | set(internal))
    add(f"the {len(hidden)} internal and service-only functions cannot be called by a visitor or a signed-in person",
        f"(select count(*) from {fn} and p.proname = any({sql_array(hidden)}) and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute')))::text", "'0'",
        f"(select count(*) from {fn} and p.proname = any({sql_array(hidden)}) and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))) = 0")
    add(f"the {len(service_only)} service-only functions can be called by the service role",
        f"(select count(*) from {fn} and p.proname = any({sql_array(service_only)}) and has_function_privilege('service_role', p.oid, 'execute'))::text", f"'{len(service_only)}'",
        f"(select count(*) from {fn} and p.proname = any({sql_array(service_only)}) and has_function_privilege('service_role', p.oid, 'execute')) = {len(service_only)}")
    add("every trigger exists and is enabled", f"(select count(*) from pg_trigger t where not t.tgisinternal and t.tgname = any({sql_array([n for n, _ in triggers])}) and t.tgenabled = 'O')::text", f"'{len(triggers)}'",
        f"(select count(*) from pg_trigger t where not t.tgisinternal and t.tgname = any({sql_array([n for n, _ in triggers])}) and t.tgenabled = 'O') = {len(triggers)}")
    all_indexes = [n for n, _ in created_indexes()]
    add(f"all {len(all_indexes)} indexes exist", f"(select count(*) from pg_indexes i where i.schemaname = 'public' and i.indexname = any({sql_array(all_indexes)}))::text", f"'{len(all_indexes)}'",
        f"(select count(*) from pg_indexes i where i.schemaname = 'public' and i.indexname = any({sql_array(all_indexes)})) = {len(all_indexes)}")
    add(f"the {BUCKET} bucket exists and is private", f"coalesce((select case when b.public then 'public' else 'private' end from storage.buckets b where b.id = '{BUCKET}'), 'missing')", "'private'",
        f"coalesce((select not b.public from storage.buckets b where b.id = '{BUCKET}'), false)")
    add(f"its {len(policies)} storage policies exist", f"(select count(*) from pg_policies p where p.schemaname = 'storage' and p.tablename = 'objects' and p.policyname = any({sql_array(policies)}))::text", f"'{len(policies)}'",
        f"(select count(*) from pg_policies p where p.schemaname = 'storage' and p.tablename = 'objects' and p.policyname = any({sql_array(policies)})) = {len(policies)}")
    if cols:
        add("the new columns exist", f"(select count(*) from unnest({sql_array(cols)}) x where exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = split_part(x, '.', 1) and c.column_name = split_part(x, '.', 2)))::text", f"'{len(cols)}'",
            f"(select count(*) from unnest({sql_array(cols)}) x where exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = split_part(x, '.', 1) and c.column_name = split_part(x, '.', 2))) = {len(cols)}")
    add(f"all {len(flags)} feature switches exist", "(select count(*) from public.site_feature_flags)::text", f"'{len(flags)}'", f"(select count(*) from public.site_feature_flags) = {len(flags)}")
    add("...and every one is OFF (nothing changes in the apps until you switch one on)", "(select count(*) from public.site_feature_flags where enabled)::text", "'0'", "(select count(*) from public.site_feature_flags where enabled) = 0")
    add("a visitor can ask which are on", "(select count(*) from jsonb_object_keys(public.site_features()))::text", f"'{len(flags)}'", f"(select count(*) from jsonb_object_keys(public.site_features())) = {len(flags)}")
    add("the community rules are at version 1 with no text yet (the app shows its own draft)", "(public.rules_current())::text", "'{\"body\": null, \"version\": 1}'", "(public.rules_current())::text = '{\"body\": null, \"version\": 1}'")
    refuses = (
        "(select count(*) from pg_constraint c where c.contype = 'f' and c.confdeltype in ('a', 'r') "
        f"and replace(c.conrelid::regclass::text, 'public.', '') = any({sql_array(tables)}) "
        "and c.confrelid in ('auth.users'::regclass, 'public.profiles'::regclass, 'public.site_profiles'::regclass))"
    )
    add("no foreign key from the new tables into a person refuses an account deletion", f"{refuses}::text", "'0'", f"{refuses} = 0")

    lines = []
    for i, (name, actual, expected, ok) in enumerate(checks, 1):
        label = name.replace("'", "''")
        lines.append(f"  select {i} as n, '{label}' as check_name, {actual} as actual, {expected} as expected, {ok} as ok" if i == 1 else f"  union all select {i}, '{label}', {actual}, {expected}, {ok}")
    body = "\n".join(lines)
    return f"""-- 23: POST-FLIGHT for the six social website migrations 20261101100000 .. 20261105100000. Read-only. Every row should say ok = true.
-- GENERATED by supabase/go-live/build_social.py: do not edit it by hand. If a row says false, send me the whole grid.
select * from (
{body}
) x order by n;
"""


FILES = {
    OUT / "apply_social.sql": build_apply,
    OUT / "rollback_social.sql": build_rollback,
    AUDIT / "22_preflight_social.sql": build_preflight,
    AUDIT / "23_postflight_social.sql": build_postflight,
}


def main() -> int:
    check = "--check" in sys.argv
    stale = []
    for path, build in FILES.items():
        text = build()
        if check:
            if not path.exists() or read(path) != text:
                stale.append(path.relative_to(ROOT))
        else:
            path.write_text(text, encoding="utf-8")
            print("wrote", path.relative_to(ROOT), f"({len(text.splitlines())} lines)")
    if check:
        if stale:
            print("NOT CURRENT (run python3 -I supabase/go-live/build_social.py):", *stale, sep="\n  ")
            return 1
        print("all four files are current")
    return 0


if __name__ == "__main__":
    sys.exit(main())
