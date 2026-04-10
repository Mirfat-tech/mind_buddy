create table if not exists public.journal_folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  color text not null default 'pink',
  icon_style text not null default 'bubble_folder',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists journal_folders_user_updated_idx
  on public.journal_folders (user_id, updated_at desc);

alter table public.journals
  add column if not exists folder_id uuid references public.journal_folders(id) on delete set null;

create index if not exists journals_user_folder_created_idx
  on public.journals (user_id, folder_id, created_at desc);

alter table public.journal_folders enable row level security;

drop policy if exists journal_folders_select_own on public.journal_folders;
create policy journal_folders_select_own
  on public.journal_folders
  for select
  using (auth.uid() = user_id);

drop policy if exists journal_folders_insert_own on public.journal_folders;
create policy journal_folders_insert_own
  on public.journal_folders
  for insert
  with check (auth.uid() = user_id);

drop policy if exists journal_folders_update_own on public.journal_folders;
create policy journal_folders_update_own
  on public.journal_folders
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists journal_folders_delete_own on public.journal_folders;
create policy journal_folders_delete_own
  on public.journal_folders
  for delete
  using (auth.uid() = user_id);

create or replace function public.touch_journal_folder_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists journal_folders_touch_updated_at on public.journal_folders;
create trigger journal_folders_touch_updated_at
before update on public.journal_folders
for each row
execute function public.touch_journal_folder_updated_at();

create or replace function public.delete_journal_folder(p_folder_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  update public.journals
  set folder_id = null
  where user_id = v_user_id
    and folder_id = p_folder_id;

  delete from public.journal_folders
  where id = p_folder_id
    and user_id = v_user_id;
end;
$$;

revoke all on function public.delete_journal_folder(uuid) from public;
grant execute on function public.delete_journal_folder(uuid) to authenticated;
