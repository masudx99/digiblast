-- ============================================================================
-- verify.sql — sanity checks after running migrations.
-- Run in the Supabase SQL editor; every row should look "as expected".
-- ============================================================================

-- 1) All expected tables exist.
select tablename
from pg_tables
where schemaname = 'public'
  and tablename in (
    'users', 'player_profiles', 'player_photos', 'matches',
    'innings_performance', 'generated_cards', 'ai_insights', 'scrape_jobs'
  )
order by tablename;
-- expect: 8 rows

-- 2) RLS is enabled on every one of them.
select c.relname as table,
       c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in (
    'users', 'player_profiles', 'player_photos', 'matches',
    'innings_performance', 'generated_cards', 'ai_insights', 'scrape_jobs'
  )
order by c.relname;
-- expect: rls_enabled = true for all 8

-- 3) Storage buckets exist and flags match.
select id, public
from storage.buckets
where id in ('player-photos', 'generated-cards');
-- expect: player-photos public=false, generated-cards public=true

-- 4) Auth trigger is wired up.
select tgname, tgrelid::regclass
from pg_trigger
where tgname = 'on_auth_user_created';
-- expect: 1 row on auth.users

-- 5) Uniqueness constraints that matter for idempotent scraping.
select conname, conrelid::regclass
from pg_constraint
where conname in (
  'matches_league_slug_league_match_id_key',
  'innings_performance_match_id_player_profile_id_role_key',
  'player_profiles_league_slug_league_player_id_key'
);
-- expect: 3 rows
