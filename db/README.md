# Database — Supabase

Postgres schema, RLS, and storage buckets for the cricket portal.

## Files

| File                          | Purpose                                     |
| ----------------------------- | ------------------------------------------- |
| `migrations/0001_schema.sql`  | Tables, indexes, `updated_at` + auth triggers |
| `migrations/0002_rls.sql`     | Row-level security policies                 |
| `migrations/0003_storage.sql` | Storage buckets + bucket policies           |
| `verify.sql`                  | Post-apply sanity checks (run in SQL editor) |

Apply in order: `0001 → 0002 → 0003`.

## How to apply (one-time, in order)

### Option A — Supabase dashboard (easiest)

1. Open your project → **SQL Editor** → **New query**
2. Paste the contents of `0001_schema.sql`, hit **Run**
3. Repeat for `0002_rls.sql`, then `0003_storage.sql`
4. Run `verify.sql` and compare to the expected rows in that file

### Option B — Supabase CLI

```bash
# from the repo root
supabase db push --db-url "postgresql://postgres:<password>@<host>:5432/postgres"
# or just apply each file manually:
psql "$DB_URL" -f db/migrations/0001_schema.sql
psql "$DB_URL" -f db/migrations/0002_rls.sql
psql "$DB_URL" -f db/migrations/0003_storage.sql
psql "$DB_URL" -f db/verify.sql
```

Your `DB_URL` is at **Project Settings → Database → Connection string (URI)**.

## Design notes

**Identity.** `public.users.id` is the same UUID as `auth.users.id`. A trigger
(`on_auth_user_created`) inserts the public row automatically the moment a user
completes Supabase magic-link signup — the frontend never has to create it.

**Enums are text + CHECK.** Postgres enums require `ALTER TYPE ... ADD VALUE`
for new values, which can't run in a transaction on older versions. Text with
a CHECK constraint is easier to evolve when we add leagues (`wclinc` → `neucc`
→ `crichero` → whatever's next).

**Idempotent scraping.** Three unique constraints make re-runs safe:

- `matches(league_slug, league_match_id)` — same match won't get two rows
- `innings_performance(match_id, player_profile_id, role)` — same innings
  for the same player won't get two rows
- `player_profiles(league_slug, league_player_id)` — one profile per league id

**RLS.** Every `public.*` table has RLS on. End users see only their own rows,
joining through `player_profiles.user_id` when needed. The **service role key**
(used by the Node core service) bypasses RLS entirely — that's how the scraper
writes matches/innings without per-row policies.

**Storage layout.**

- `player-photos/<user_id>/<filename>` — private, owner CRUD
- `generated-cards/<card_id>.png` — public read, service-role write

## Test it end-to-end (quick)

After applying migrations, from the SQL editor:

```sql
-- simulate a user signup (normally Supabase Auth does this)
-- you can just create one via the Auth UI and then:
select id, email from public.users;

-- confirm RLS blocks cross-user reads:
-- (run as anon key from the REST API, not as sql editor which is service role)
```

For a full RLS check, hit the REST API with a real user JWT after signing up
one test user. That's a phase-6 integration task — not required to move off
phase 1.

## Rollback

There's no down-migration by design at MVP stage. If you need to start over
in a dev project:

```sql
drop schema public cascade;
create schema public;
grant all on schema public to postgres;
grant all on schema public to public;
```

Then re-run all three files. **Do not do this on a project with real users.**
