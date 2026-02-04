-- Tracks devices per user for "Devices" in Settings
create table if not exists public.user_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  device_name text,
  platform text,
  last_seen_at timestamptz default now()
);

create unique index if not exists user_sessions_user_device_unique
  on public.user_sessions (user_id, device_id);

alter table public.user_sessions enable row level security;

drop policy if exists "Users can view their devices" on public.user_sessions;
create policy "Users can view their devices"
  on public.user_sessions for select
  using (auth.uid() = user_id);

drop policy if exists "Users can upsert their device" on public.user_sessions;
create policy "Users can upsert their device"
  on public.user_sessions for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their device" on public.user_sessions;
create policy "Users can update their device"
  on public.user_sessions for update
  using (auth.uid() = user_id);
