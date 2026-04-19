-- ============================================================================
-- 0001_schema.sql — core tables for the cricket portal
--
-- Conventions:
--   * UUID primary keys (gen_random_uuid from pgcrypto)
--   * timestamptz everywhere
--   * text + CHECK instead of Postgres enum (easier to extend)
--   * public.users.id == auth.users.id, auto-created on signup
--   * RLS policies in 0002, storage buckets in 0003
-- ============================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- shared: updated_at trigger
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- users — 1:1 with auth.users, stores app-level profile
-- ---------------------------------------------------------------------------
create table public.users (
  id                uuid primary key references auth.users(id) on delete cascade,
  email             text not null,
  full_name         text,
  phone_e164        text,
  whatsapp_opt_in   boolean not null default false,
  instagram_handle  text,
  fb_page_id        text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index users_email_idx on public.users (lower(email));

create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

-- Auto-create public.users row on auth.users insert.
-- security definer lets the trigger bypass RLS.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- ---------------------------------------------------------------------------
-- player_profiles — a league account owned by a user
-- ---------------------------------------------------------------------------
create table public.player_profiles (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references public.users(id) on delete cascade,
  league_slug          text not null
                       check (league_slug in ('wclinc', 'neucc', 'crichero')),
  league_player_id     text not null,
  player_display_name  text,
  profile_url          text not null,
  last_scraped_at      timestamptz,
  scrape_status        text not null default 'idle'
                       check (scrape_status in ('idle', 'queued', 'running', 'success', 'failed')),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (league_slug, league_player_id)
);

create index player_profiles_user_idx on public.player_profiles (user_id);

create trigger player_profiles_set_updated_at
  before update on public.player_profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- player_photos — photos used for card overlays
-- ---------------------------------------------------------------------------
create table public.player_photos (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id) on delete cascade,
  photo_url  text not null,
  photo_type text not null
             check (photo_type in ('action', 'headshot', 'celebration')),
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);

create index player_photos_user_idx on public.player_photos (user_id);

-- At most one primary photo per user.
create unique index player_photos_one_primary_per_user
  on public.player_photos (user_id) where is_primary;

-- ---------------------------------------------------------------------------
-- matches — deduplicated league matches
-- ---------------------------------------------------------------------------
create table public.matches (
  id                 uuid primary key default gen_random_uuid(),
  league_slug        text not null
                     check (league_slug in ('wclinc', 'neucc', 'crichero')),
  league_match_id    text not null,
  match_date         date,
  teams              jsonb,              -- {"home": "...", "away": "..."}
  venue              text,
  match_url          text not null,
  raw_scorecard_json jsonb,
  scraped_at         timestamptz not null default now(),
  unique (league_slug, league_match_id)
);

create index matches_date_idx on public.matches (match_date desc);

-- ---------------------------------------------------------------------------
-- innings_performance — per (match, player, role)
-- ---------------------------------------------------------------------------
create table public.innings_performance (
  id                uuid primary key default gen_random_uuid(),
  match_id          uuid not null references public.matches(id) on delete cascade,
  player_profile_id uuid not null references public.player_profiles(id) on delete cascade,
  role              text not null check (role in ('bat', 'bowl')),

  -- batting fields
  runs          integer,
  balls_faced   integer,
  fours         integer,
  sixes         integer,
  strike_rate   numeric(6, 2),
  out_how       text,   -- 'bowled','caught','lbw','run_out','stumped','not_out','did_not_bat'
  bowler_out    text,

  -- bowling fields (overs decimal: 3.4 = 3 overs + 4 balls)
  overs_bowled  numeric(4, 1),
  maidens       integer,
  runs_conceded integer,
  wickets       integer,
  economy       numeric(5, 2),
  dot_balls     integer,

  raw_data_json jsonb,
  created_at    timestamptz not null default now(),

  unique (match_id, player_profile_id, role)
);

create index innings_performance_player_idx on public.innings_performance (player_profile_id);
create index innings_performance_match_idx  on public.innings_performance (match_id);

-- ---------------------------------------------------------------------------
-- generated_cards — one per (innings, template)
-- ---------------------------------------------------------------------------
create table public.generated_cards (
  id                     uuid primary key default gen_random_uuid(),
  innings_performance_id uuid not null references public.innings_performance(id) on delete cascade,
  template_name          text not null,
  image_url              text,
  caption_text           text,
  status                 text not null default 'pending_approval'
                         check (status in ('pending_approval', 'approved', 'rejected', 'posted', 'failed')),
  whatsapp_sent_at       timestamptz,
  approved_at            timestamptz,
  posted_at              timestamptz,
  social_post_ids_json   jsonb,
  error_message          text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

create index generated_cards_innings_idx on public.generated_cards (innings_performance_id);
create index generated_cards_status_idx  on public.generated_cards (status);

create trigger generated_cards_set_updated_at
  before update on public.generated_cards
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- ai_insights — rolling summaries from Claude
-- ---------------------------------------------------------------------------
create table public.ai_insights (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.users(id) on delete cascade,
  period_start      date not null,
  period_end        date not null,
  insight_type      text not null check (insight_type in ('batting', 'bowling', 'overall')),
  summary_text      text,
  strengths_json    jsonb,
  improvements_json jsonb,
  generated_at      timestamptz not null default now(),
  check (period_end >= period_start)
);

create index ai_insights_user_idx on public.ai_insights (user_id, period_end desc);

-- ---------------------------------------------------------------------------
-- scrape_jobs — audit log for every scrape attempt
-- ---------------------------------------------------------------------------
create table public.scrape_jobs (
  id                uuid primary key default gen_random_uuid(),
  player_profile_id uuid references public.player_profiles(id) on delete set null,
  status            text not null default 'running'
                    check (status in ('running', 'success', 'failed', 'partial')),
  started_at        timestamptz not null default now(),
  finished_at       timestamptz,
  error_message     text,
  matches_found     integer not null default 0
);

create index scrape_jobs_profile_idx on public.scrape_jobs (player_profile_id, started_at desc);
