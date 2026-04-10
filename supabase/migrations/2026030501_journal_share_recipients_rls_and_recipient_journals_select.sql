-- Journal sharing source of truth: public.journal_share_recipients

alter table if exists public.journal_share_recipients enable row level security;

drop policy if exists journal_share_recipients_select_owner_or_recipient on public.journal_share_recipients;
create policy journal_share_recipients_select_owner_or_recipient
  on public.journal_share_recipients
  for select
  to authenticated
  using (
    recipient_id = auth.uid()
    or exists (
      select 1
      from public.journals j
      where j.id = journal_id
        and j.user_id = auth.uid()
    )
  );

drop policy if exists journal_share_recipients_insert_owner_only on public.journal_share_recipients;
create policy journal_share_recipients_insert_owner_only
  on public.journal_share_recipients
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.journals j
      where j.id = journal_id
        and j.user_id = auth.uid()
    )
  );

drop policy if exists journal_share_recipients_update_owner_only on public.journal_share_recipients;
create policy journal_share_recipients_update_owner_only
  on public.journal_share_recipients
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.journals j
      where j.id = journal_id
        and j.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.journals j
      where j.id = journal_id
        and j.user_id = auth.uid()
    )
  );

drop policy if exists journal_share_recipients_delete_owner_only on public.journal_share_recipients;
create policy journal_share_recipients_delete_owner_only
  on public.journal_share_recipients
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.journals j
      where j.id = journal_id
        and j.user_id = auth.uid()
    )
  );

alter table if exists public.journals enable row level security;

drop policy if exists journals_select_owner_or_shared_recipient on public.journals;
create policy journals_select_owner_or_shared_recipient
  on public.journals
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.journal_share_recipients r
      where r.journal_id = id
        and r.recipient_id = auth.uid()
        and (r.expires_at is null or r.expires_at > now())
    )
  );
