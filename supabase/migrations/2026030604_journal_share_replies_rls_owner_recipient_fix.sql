-- Ensure both sender(owner) and valid recipients can read reply rows.

alter table if exists public.journal_share_replies enable row level security;

drop policy if exists journal_share_replies_select_owner_or_recipient on public.journal_share_replies;
create policy journal_share_replies_select_owner_or_recipient
  on public.journal_share_replies
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.journals j
      where j.id = journal_id
        and (
          j.user_id = auth.uid()
          or exists (
            select 1
            from public.journal_share_recipients r
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
      select 1
      from public.journals j
      where j.id = journal_id
        and exists (
          select 1
          from public.journal_share_recipients r
          where r.journal_id = j.id
            and r.recipient_id = auth.uid()
            and r.can_comment = true
            and (r.expires_at is null or r.expires_at > now())
        )
    )
  );
