-- Subscription-based limits and policies

create or replace function public.is_full_support(uid uuid)
returns boolean
language sql
stable
as $$
  select lower(coalesce((select subscription_tier from public.profiles where id = uid), '')) in
    ('full','full_support','full support','full_support_mode','full support mode');
$$;

create or replace function public.is_pending_support(uid uuid)
returns boolean
language sql
stable
as $$
  select lower(coalesce((select subscription_tier from public.profiles where id = uid), '')) in
    ('', 'pending');
$$;

create or replace function public.message_limit(uid uuid)
returns int
language sql
stable
as $$
  select case
    when public.is_pending_support(uid) then 0
    when public.is_full_support(uid) then 100
    else 10
  end;
$$;

create or replace function public.journal_limit(uid uuid)
returns int
language sql
stable
as $$
  select case
    when public.is_pending_support(uid) then 0
    when public.is_full_support(uid) then 10
    else 3
  end;
$$;

create or replace function public.device_limit(uid uuid)
returns int
language sql
stable
as $$
  select case when public.is_full_support(uid) then 5 else 1 end;
$$;

-- Allow multiple chats for Full Support (remove hard unique constraint)
drop index if exists public.chats_user_day_unique;

alter table public.chats enable row level security;
drop policy if exists "Chat daily limit" on public.chats;
create policy "Chat daily limit"
  on public.chats for insert
  with check (
    auth.uid() = user_id
    and (
      public.is_full_support(auth.uid())
      or (
        select count(*) from public.chats
        where user_id = auth.uid()
          and day_id = current_date
          and is_archived = false
      ) < 1
    )
    and not public.is_pending_support(auth.uid())
  );

alter table public.chat_messages enable row level security;
drop policy if exists "Chat message limit" on public.chat_messages;
create policy "Chat message limit"
  on public.chat_messages for insert
  with check (
    auth.uid() = user_id
    and (
      select count(*) from public.chat_messages
      where user_id = auth.uid()
        and created_at >= date_trunc('day', now())
        and created_at < date_trunc('day', now()) + interval '1 day'
    ) < public.message_limit(auth.uid())
    and not public.is_pending_support(auth.uid())
  );

alter table public.journals enable row level security;
drop policy if exists "Journal daily limit" on public.journals;
create policy "Journal daily limit"
  on public.journals for insert
  with check (
    auth.uid() = user_id
    and (
      select count(*) from public.journals
      where user_id = auth.uid()
        and created_at >= date_trunc('day', now())
        and created_at < date_trunc('day', now()) + interval '1 day'
    ) < public.journal_limit(auth.uid())
    and not public.is_pending_support(auth.uid())
  );

alter table public.log_templates_v2 enable row level security;
drop policy if exists "Full users can create templates" on public.log_templates_v2;
create policy "Full users can create templates"
  on public.log_templates_v2 for insert
  with check (
    auth.uid() = user_id
    and public.is_full_support(auth.uid())
  );

alter table public.user_sessions enable row level security;
drop policy if exists "Users can upsert their device" on public.user_sessions;
create policy "Users can upsert their device"
  on public.user_sessions for insert
  with check (
    auth.uid() = user_id
    and (
      select count(*) from public.user_sessions
      where user_id = auth.uid()
    ) < public.device_limit(auth.uid())
  );
