-- Explicit journal_share_replies policies for author, owner, and recipient.
-- Uses public.journal_share_recipients as share source of truth.

alter table if exists public.journal_share_replies enable row level security;

drop policy if exists jsr_select_author on public.journal_share_replies;
create policy jsr_select_author
  on public.journal_share_replies
  for select
  to authenticated
  using (author_id = auth.uid());

drop policy if exists jsr_select_owner on public.journal_share_replies;
create policy jsr_select_owner
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

drop policy if exists jsr_select_recipient on public.journal_share_replies;
create policy jsr_select_recipient
  on public.journal_share_replies
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.journal_share_recipients s
      where s.journal_id = journal_share_replies.journal_id
        and s.recipient_id = auth.uid()
        and (s.expires_at is null or s.expires_at > now())
    )
  );

drop policy if exists jsr_insert_recipient on public.journal_share_replies;
create policy jsr_insert_recipient
  on public.journal_share_replies
  for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and exists (
      select 1
      from public.journal_share_recipients s
      where s.journal_id = journal_share_replies.journal_id
        and s.recipient_id = auth.uid()
        and coalesce(s.can_comment, true) = true
        and (s.expires_at is null or s.expires_at > now())
    )
  );
