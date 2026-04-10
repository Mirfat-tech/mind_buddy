-- Ensure owner + valid recipients can read reply rows.

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
            select 1
            from public.journal_share_recipients r
            where r.journal_id = j.id
              and r.recipient_id = auth.uid()
              and (r.expires_at is null or r.expires_at > now())
          )
        )
    )
  );

-- Optional compatibility for projects using public.journal_replies naming.
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'journal_replies'
  ) then
    execute 'alter table public.journal_replies enable row level security';
    execute 'drop policy if exists journal_replies_select_owner_or_recipient on public.journal_replies';
    execute $policy$
      create policy journal_replies_select_owner_or_recipient
        on public.journal_replies
        for select
        to authenticated
        using (
          exists (
            select 1 from public.journals j
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
        )
    $policy$;
  end if;
end $$;
