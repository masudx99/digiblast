-- ============================================================================
-- 0002_rls.sql — row-level security
--
-- Rule: users see only their own rows. The service role key bypasses RLS by
-- default (Supabase), so scrapers/renderers running with SERVICE_ROLE_KEY can
-- write freely without explicit INSERT policies.
-- ============================================================================

alter table public.users               enable row level security;
alter table public.player_profiles     enable row level security;
alter table public.player_photos       enable row level security;
alter table public.matches             enable row level security;
alter table public.innings_performance enable row level security;
alter table public.generated_cards     enable row level security;
alter table public.ai_insights         enable row level security;
alter table public.scrape_jobs         enable row level security;

-- ---------------------------------------------------------------------------
-- users: row is "mine" iff id = auth.uid()
-- Insert handled by the handle_new_auth_user trigger (security definer).
-- ---------------------------------------------------------------------------
create policy users_self_select on public.users
  for select using (id = auth.uid());

create policy users_self_update on public.users
  for update using (id = auth.uid()) with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- player_profiles / player_photos: owned directly via user_id
-- ---------------------------------------------------------------------------
create policy player_profiles_self_all on public.player_profiles
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy player_photos_self_all on public.player_photos
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- matches: readable if the user has an innings in this match.
-- Writes are service-role-only (scraper).
-- ---------------------------------------------------------------------------
create policy matches_self_select on public.matches
  for select using (
    exists (
      select 1
      from public.innings_performance ip
      join public.player_profiles pp on pp.id = ip.player_profile_id
      where ip.match_id = matches.id
        and pp.user_id  = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- innings_performance: readable via player_profile ownership.
-- Writes are service-role-only.
-- ---------------------------------------------------------------------------
create policy innings_performance_self_select on public.innings_performance
  for select using (
    exists (
      select 1 from public.player_profiles pp
      where pp.id = innings_performance.player_profile_id
        and pp.user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- generated_cards: readable via innings → profile → user.
-- Status transitions (approved/rejected/posted) go through the service role.
-- ---------------------------------------------------------------------------
create policy generated_cards_self_select on public.generated_cards
  for select using (
    exists (
      select 1
      from public.innings_performance ip
      join public.player_profiles pp on pp.id = ip.player_profile_id
      where ip.id = generated_cards.innings_performance_id
        and pp.user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- ai_insights: owned directly via user_id
-- ---------------------------------------------------------------------------
create policy ai_insights_self_select on public.ai_insights
  for select using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- scrape_jobs: show jobs tied to this user's profiles (or orphaned jobs)
-- ---------------------------------------------------------------------------
create policy scrape_jobs_self_select on public.scrape_jobs
  for select using (
    player_profile_id is null
    or exists (
      select 1 from public.player_profiles pp
      where pp.id = scrape_jobs.player_profile_id
        and pp.user_id = auth.uid()
    )
  );
