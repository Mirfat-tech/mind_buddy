-- RLS-safe canonical replies fetch for owner + valid recipients.

create or replace function public.get_journal_replies_for_entry(p_journal_id uuid)
returns table(
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
  with allowed as (
    select 1
    from public.journals j
    where j.id = p_journal_id
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
  select r.id, r.journal_id, r.author_id, r.text, r.created_at
  from public.journal_share_replies r
  where r.journal_id = p_journal_id
    and exists (select 1 from allowed)
  order by r.created_at asc;
$$;

grant usage on schema public to authenticated;
grant execute on function public.get_journal_replies_for_entry(uuid) to authenticated;
