-- User blocking model.
-- Blocking does NOT hide existing shared history. It only prevents new shares/replies.

create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_user_id)
);

alter table public.user_blocks enable row level security;

-- Compatibility: if an old column name exists, backfill into blocked_user_id once.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='user_blocks' and column_name='blocked_id'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='user_blocks' and column_name='blocked_user_id'
  ) then
    alter table public.user_blocks add column blocked_user_id uuid;
    update public.user_blocks set blocked_user_id = blocked_id where blocked_user_id is null;
  end if;
end $$;

create index if not exists user_blocks_blocker_idx on public.user_blocks(blocker_id);
create index if not exists user_blocks_blocked_idx on public.user_blocks(blocked_user_id);

-- Optional cleanup from legacy table if present.
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'journal_share_blocks'
  ) then
    insert into public.user_blocks (blocker_id, blocked_user_id, created_at)
    select blocker_id, blocked_id, coalesce(created_at, now())
    from public.journal_share_blocks
    on conflict (blocker_id, blocked_user_id) do nothing;
  end if;
end $$;

drop policy if exists "user_blocks_select_own" on public.user_blocks;
create policy "user_blocks_select_own"
on public.user_blocks
for select
to authenticated
using (blocker_id = auth.uid());

drop policy if exists "user_blocks_insert_own" on public.user_blocks;
create policy "user_blocks_insert_own"
on public.user_blocks
for insert
to authenticated
with check (blocker_id = auth.uid());

drop policy if exists "user_blocks_delete_own" on public.user_blocks;
create policy "user_blocks_delete_own"
on public.user_blocks
for delete
to authenticated
using (blocker_id = auth.uid());

create or replace function public.is_blocked_pair(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_blocks ub
    where (ub.blocker_id = a and ub.blocked_user_id = b)
       or (ub.blocker_id = b and ub.blocked_user_id = a)
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
      select 1 from public.user_blocks ub
      where ub.blocker_id = auth.uid() and ub.blocked_user_id = other_user_id
    ) as blocked_by_me,
    exists (
      select 1 from public.user_blocks ub
      where ub.blocker_id = other_user_id and ub.blocked_user_id = auth.uid()
    ) as blocked_by_them,
    exists (
      select 1 from public.user_blocks ub
      where (ub.blocker_id = auth.uid() and ub.blocked_user_id = other_user_id)
         or (ub.blocker_id = other_user_id and ub.blocked_user_id = auth.uid())
    ) as blocked_either;
$$;

grant usage on schema public to authenticated;
grant execute on function public.is_blocked_pair(uuid, uuid) to authenticated;
grant execute on function public.get_block_status(uuid) to authenticated;

-- Shares: keep old visibility; prevent NEW inserts/updates when blocked either direction.
alter table if exists public.journal_share_recipients enable row level security;

drop policy if exists journal_share_recipients_insert_owner_only on public.journal_share_recipients;
create policy journal_share_recipients_insert_owner_only
  on public.journal_share_recipients
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.journals j
      where j.id = journal_id and j.user_id = auth.uid()
    )
    and not public.is_blocked_pair(auth.uid(), recipient_id)
  );

drop policy if exists journal_share_recipients_update_owner_only on public.journal_share_recipients;
create policy journal_share_recipients_update_owner_only
  on public.journal_share_recipients
  for update
  to authenticated
  using (
    exists (
      select 1 from public.journals j
      where j.id = journal_id and j.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.journals j
      where j.id = journal_id and j.user_id = auth.uid()
    )
    and not public.is_blocked_pair(auth.uid(), recipient_id)
  );

-- Journal selects: owner or valid share recipient (no block filter so history stays visible).
alter table if exists public.journals enable row level security;

drop policy if exists journals_select_owner_or_shared_recipient on public.journals;
create policy journals_select_owner_or_shared_recipient
  on public.journals
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.journal_share_recipients r
      where r.journal_id = id
        and r.recipient_id = auth.uid()
        and (r.expires_at is null or r.expires_at > now())
    )
  );

-- Replies: allow reads to owner/recipient; block NEW inserts when blocked.
alter table if exists public.journal_share_replies enable row level security;

drop policy if exists journal_share_replies_select_owner_or_recipient on public.journal_share_replies;
create policy journal_share_replies_select_owner_or_recipient
  on public.journal_share_replies
  for select
  to authenticated
  using (
    exists (
      select 1 from public.journals j
      where j.id = journal_id
        and (
          j.user_id = auth.uid()
          or exists (
            select 1 from public.journal_share_recipients r
            where r.journal_id = j.id
              and r.recipient_id = auth.uid()
              and (r.expires_at is null or r.expires_at > now())
          )
        )
    )
  );

drop policy if exists journal_share_replies_insert_recipient_only on public.journal_share_replies;
create policy journal_share_replies_insert_recipient_only
  on public.journal_share_replies
  for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and exists (
      select 1 from public.journals j
      where j.id = journal_id
        and exists (
          select 1 from public.journal_share_recipients r
          where r.journal_id = j.id
            and r.recipient_id = auth.uid()
            and r.can_comment = true
            and (r.expires_at is null or r.expires_at > now())
        )
        and not public.is_blocked_pair(j.user_id, auth.uid())
    )
  );
