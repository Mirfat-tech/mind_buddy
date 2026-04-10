create table if not exists public.journal_shares (
  id bigserial primary key,
  entry_id uuid not null references public.journals(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  permission text not null default 'view',
  created_at timestamptz not null default now(),
  constraint journal_shares_permission_check check (permission in ('view', 'comment')),
  constraint journal_shares_unique_entry_recipient unique (entry_id, recipient_user_id)
);

alter table public.journal_shares enable row level security;

drop policy if exists "journal_shares_select_owner_or_recipient" on public.journal_shares;
create policy "journal_shares_select_owner_or_recipient"
  on public.journal_shares
  for select
  to authenticated
  using (owner_id = auth.uid() or recipient_user_id = auth.uid());

drop policy if exists "journal_shares_insert_owner_only" on public.journal_shares;
create policy "journal_shares_insert_owner_only"
  on public.journal_shares
  for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    and exists (
      select 1
      from public.journals j
      where j.id = entry_id
        and j.user_id = auth.uid()
    )
  );

drop policy if exists "journal_shares_update_owner_only" on public.journal_shares;
create policy "journal_shares_update_owner_only"
  on public.journal_shares
  for update
  to authenticated
  using (
    owner_id = auth.uid()
    and exists (
      select 1
      from public.journals j
      where j.id = entry_id
        and j.user_id = auth.uid()
    )
  )
  with check (
    owner_id = auth.uid()
    and exists (
      select 1
      from public.journals j
      where j.id = entry_id
        and j.user_id = auth.uid()
    )
  );

drop policy if exists "journal_shares_delete_owner_only" on public.journal_shares;
create policy "journal_shares_delete_owner_only"
  on public.journal_shares
  for delete
  to authenticated
  using (
    owner_id = auth.uid()
    and exists (
      select 1
      from public.journals j
      where j.id = entry_id
        and j.user_id = auth.uid()
    )
  );
