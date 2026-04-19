-- ============================================================================
-- 0003_storage.sql — Supabase storage buckets + policies
--
-- Bucket conventions:
--   player-photos    private, owner writes/reads their own folder (user_id/...)
--   generated-cards  public-read, service role writes
-- ============================================================================

insert into storage.buckets (id, name, public)
  values ('player-photos', 'player-photos', false)
  on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
  values ('generated-cards', 'generated-cards', true)
  on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- player-photos: owner-only CRUD.
-- Upload path must start with the user's uuid: "<user_id>/filename.jpg"
-- ---------------------------------------------------------------------------
create policy "player_photos_owner_select" on storage.objects
  for select using (
    bucket_id = 'player-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "player_photos_owner_insert" on storage.objects
  for insert with check (
    bucket_id = 'player-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "player_photos_owner_update" on storage.objects
  for update using (
    bucket_id = 'player-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "player_photos_owner_delete" on storage.objects
  for delete using (
    bucket_id = 'player-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- generated-cards: public read (Instagram/Facebook need to fetch the PNG).
-- Writes are service-role-only (card renderer).
-- ---------------------------------------------------------------------------
create policy "generated_cards_public_read" on storage.objects
  for select using (bucket_id = 'generated-cards');
