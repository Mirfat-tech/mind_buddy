-- Canonical replies RPC: uses public.journal_share_replies.text and journal_id.

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
        from public.journals j
        where j.id = p_journal_id
          and j.user_id = auth.uid()
      )
      or exists (
        select 1
        from public.journal_share_recipients s
        where s.journal_id = p_journal_id
          and s.recipient_id = auth.uid()
          and (s.expires_at is null or s.expires_at > now())
      )
      or r.author_id = auth.uid()
    )
  order by r.created_at asc;
$$;

grant execute on function public.get_journal_replies_for_entry(uuid) to authenticated;
