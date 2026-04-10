-- Canonical journal share/reply/block flow.
-- Entry ownership table is public.journals with owner column user_id.

create extension if not exists pgcrypto;

create table if not exists public.blocked_users (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint blocked_users_no_self_block check (user_id <> blocked_user_id),
  constraint blocked_users_user_blocked_unique unique (user_id, blocked_user_id)
);

-- Backfill from legacy table when present.
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'user_blocks'
  ) then
    insert into public.blocked_users (user_id, blocked_user_id, created_at)
    select ub.blocker_id, ub.blocked_user_id, coalesce(ub.created_at, now())
    from public.user_blocks ub
    on conflict (user_id, blocked_user_id) do nothing;
  end if;
end $$;

alter table public.blocked_users enable row level security;

drop policy if exists blocked_users_select_own on public.blocked_users;
create policy blocked_users_select_own
  on public.blocked_users
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists blocked_users_insert_own on public.blocked_users;
create policy blocked_users_insert_own
  on public.blocked_users
  for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists blocked_users_delete_own on public.blocked_users;
create policy blocked_users_delete_own
  on public.blocked_users
  for delete
  to authenticated
  using (user_id = auth.uid());

create or replace function public.is_blocked_pair(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.blocked_users bu
    where (bu.user_id = a and bu.blocked_user_id = b)
       or (bu.user_id = b and bu.blocked_user_id = a)
  );
$$;

create or replace function public.get_block_status(other_user_id uuid)
returns table(blocked_by_me boolean, blocked_by_them boolean, blocked_either boolean)
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1
      from public.blocked_users bu
      where bu.user_id = auth.uid()
        and bu.blocked_user_id = other_user_id
    ) as blocked_by_me,
    exists (
      select 1
      from public.blocked_users bu
      where bu.user_id = other_user_id
        and bu.blocked_user_id = auth.uid()
    ) as blocked_by_them,
    exists (
      select 1
      from public.blocked_users bu
      where (bu.user_id = auth.uid() and bu.blocked_user_id = other_user_id)
         or (bu.user_id = other_user_id and bu.blocked_user_id = auth.uid())
    ) as blocked_either;
$$;

grant usage on schema public to authenticated;
grant execute on function public.is_blocked_pair(uuid, uuid) to authenticated;
grant execute on function public.get_block_status(uuid) to authenticated;

alter table if exists public.journal_shares
  add column if not exists journal_id uuid,
  add column if not exists sender_id uuid,
  add column if not exists recipient_id uuid,
  add column if not exists can_comment boolean not null default false,
  add column if not exists media_visible boolean not null default true,
  add column if not exists expires_at timestamptz;

-- Backfill canonical columns from legacy journal_shares shape.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'journal_shares' and column_name = 'entry_id'
  ) then
    update public.journal_shares
      set journal_id = coalesce(journal_id, entry_id)
    where journal_id is null;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'journal_shares' and column_name = 'owner_id'
  ) then
    update public.journal_shares
      set sender_id = coalesce(sender_id, owner_id)
    where sender_id is null;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'journal_shares' and column_name = 'recipient_user_id'
  ) then
    update public.journal_shares
      set recipient_id = coalesce(recipient_id, recipient_user_id)
    where recipient_id is null;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'journal_shares' and column_name = 'permission'
  ) then
    update public.journal_shares
      set can_comment = (permission = 'comment')
    where permission is not null;
  end if;
end $$;

-- Backfill canonical shares from legacy table when present.
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'journal_share_recipients'
  ) then
    insert into public.journal_shares (
      journal_id,
      sender_id,
      recipient_id,
      can_comment,
      media_visible,
      expires_at,
      created_at
    )
    select
      r.journal_id,
      r.owner_id,
      r.recipient_id,
      coalesce(r.can_comment, false),
      coalesce(r.media_visible, true),
      r.expires_at,
      coalesce(r.created_at, now())
    from public.journal_share_recipients r
    where r.journal_id is not null
      and r.owner_id is not null
      and r.recipient_id is not null
    on conflict (journal_id, recipient_id)
    do update set
      sender_id = excluded.sender_id,
      can_comment = excluded.can_comment,
      media_visible = excluded.media_visible,
      expires_at = excluded.expires_at;
  end if;
end $$;

alter table public.journal_shares
  alter column journal_id set not null,
  alter column sender_id set not null,
  alter column recipient_id set not null;

alter table public.journal_shares
  drop constraint if exists journal_shares_journal_id_fkey;
alter table public.journal_shares
  add constraint journal_shares_journal_id_fkey
  foreign key (journal_id) references public.journals(id) on delete cascade;

alter table public.journal_shares
  drop constraint if exists journal_shares_sender_id_fkey;
alter table public.journal_shares
  add constraint journal_shares_sender_id_fkey
  foreign key (sender_id) references auth.users(id) on delete cascade;

alter table public.journal_shares
  drop constraint if exists journal_shares_recipient_id_fkey;
alter table public.journal_shares
  add constraint journal_shares_recipient_id_fkey
  foreign key (recipient_id) references auth.users(id) on delete cascade;

alter table public.journal_shares
  drop constraint if exists journal_shares_unique_entry_recipient;
alter table public.journal_shares
  drop constraint if exists journal_shares_journal_recipient_unique;
alter table public.journal_shares
  add constraint journal_shares_journal_recipient_unique
  unique (journal_id, recipient_id);

create index if not exists journal_shares_sender_idx on public.journal_shares(sender_id);
create index if not exists journal_shares_recipient_idx on public.journal_shares(recipient_id);
create index if not exists journal_shares_journal_idx on public.journal_shares(journal_id);

alter table public.journal_shares enable row level security;

drop policy if exists journal_shares_select_owner_or_recipient on public.journal_shares;
drop policy if exists journal_shares_select_sender_or_recipient on public.journal_shares;
create policy journal_shares_select_sender_or_recipient
  on public.journal_shares
  for select
  to authenticated
  using (
    sender_id = auth.uid()
    or (
      recipient_id = auth.uid()
      and not public.is_blocked_pair(sender_id, auth.uid())
    )
  );

drop policy if exists journal_shares_insert_owner_only on public.journal_shares;
drop policy if exists journal_shares_insert_sender_only on public.journal_shares;
create policy journal_shares_insert_sender_only
  on public.journal_shares
  for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.journals j
      where j.id = journal_id
        and j.user_id = auth.uid()
    )
    and not exists (
      select 1
      from public.blocked_users bu
      where (bu.user_id = auth.uid() and bu.blocked_user_id = recipient_id)
         or (bu.user_id = recipient_id and bu.blocked_user_id = auth.uid())
    )
  );

drop policy if exists journal_shares_update_owner_only on public.journal_shares;
drop policy if exists journal_shares_update_sender_only on public.journal_shares;
create policy journal_shares_update_sender_only
  on public.journal_shares
  for update
  to authenticated
  using (sender_id = auth.uid())
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.journals j
      where j.id = journal_id
        and j.user_id = auth.uid()
    )
    and not exists (
      select 1
      from public.blocked_users bu
      where (bu.user_id = auth.uid() and bu.blocked_user_id = recipient_id)
         or (bu.user_id = recipient_id and bu.blocked_user_id = auth.uid())
    )
  );

drop policy if exists journal_shares_delete_owner_only on public.journal_shares;
drop policy if exists journal_shares_delete_sender_only on public.journal_shares;
create policy journal_shares_delete_sender_only
  on public.journal_shares
  for delete
  to authenticated
  using (sender_id = auth.uid());

alter table public.journals enable row level security;

drop policy if exists journals_select_owner_or_shared_recipient on public.journals;
create policy journals_select_owner_or_shared_recipient
  on public.journals
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.journal_shares s
      where s.journal_id = id
        and s.recipient_id = auth.uid()
        and (s.expires_at is null or s.expires_at > now())
        and not public.is_blocked_pair(s.sender_id, auth.uid())
    )
  );

alter table public.journal_share_replies enable row level security;

drop policy if exists jsr_select_author on public.journal_share_replies;
drop policy if exists jsr_select_owner on public.journal_share_replies;
drop policy if exists jsr_select_recipient on public.journal_share_replies;
drop policy if exists jsr_insert_recipient on public.journal_share_replies;
drop policy if exists journal_share_replies_select_owner_or_recipient on public.journal_share_replies;
drop policy if exists journal_share_replies_insert_recipient_only on public.journal_share_replies;

create policy journal_share_replies_select_author
  on public.journal_share_replies
  for select
  to authenticated
  using (author_id = auth.uid());

create policy journal_share_replies_select_owner
  on public.journal_share_replies
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.journals j
      where j.id = journal_id
        and j.user_id = auth.uid()
    )
  );

create policy journal_share_replies_select_recipient
  on public.journal_share_replies
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.journal_shares s
      where s.journal_id = journal_share_replies.journal_id
        and s.recipient_id = auth.uid()
        and (s.expires_at is null or s.expires_at > now())
        and not public.is_blocked_pair(s.sender_id, auth.uid())
    )
  );

create policy journal_share_replies_insert_recipient
  on public.journal_share_replies
  for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and exists (
      select 1
      from public.journal_shares s
      where s.journal_id = journal_share_replies.journal_id
        and s.recipient_id = auth.uid()
        and coalesce(s.can_comment, true) = true
        and (s.expires_at is null or s.expires_at > now())
        and not public.is_blocked_pair(s.sender_id, auth.uid())
    )
  );

drop function if exists public.get_journal_replies_for_entry(uuid);

create or replace function public.get_journal_replies_for_entry(p_journal_id uuid)
returns table (
  id uuid,
  journal_id uuid,
  author_id uuid,
  text text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select r.id, r.journal_id, r.author_id, r.text, r.created_at
  from public.journal_share_replies r
  where r.journal_id = p_journal_id
    and (
      exists (
        select 1
        from public.journals e
        where e.id = p_journal_id
          and e.user_id = auth.uid()
      )
      or exists (
        select 1
        from public.journal_shares s
        where s.journal_id = p_journal_id
          and s.recipient_id = auth.uid()
          and (s.expires_at is null or s.expires_at > now())
          and not public.is_blocked_pair(s.sender_id, auth.uid())
      )
      or exists (
        select 1
        from public.journal_share_replies author_rows
        where author_rows.journal_id = p_journal_id
          and author_rows.author_id = auth.uid()
      )
    )
  order by r.created_at asc;
$$;

grant execute on function public.get_journal_replies_for_entry(uuid) to authenticated;
