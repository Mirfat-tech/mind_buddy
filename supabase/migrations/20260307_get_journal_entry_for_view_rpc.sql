-- Canonical viewer-safe journal entry loader with entry-table auto-detection.

drop function if exists public.get_journal_entry_for_view(uuid);

create or replace function public.get_journal_entry_for_view(p_journal_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entry jsonb;
  entry_table text;
  has_is_active boolean;
  can_view_as_recipient boolean;
begin
  if to_regclass('public.journals') is not null then
    entry_table := 'public.journals';
  elsif to_regclass('public.journal_entries') is not null then
    entry_table := 'public.journal_entries';
  else
    return null;
  end if;

  -- owner path
  execute format(
    'select to_jsonb(e) from %s e where e.id = $1 and e.user_id = auth.uid()',
    entry_table
  )
  into v_entry
  using p_journal_id;

  if v_entry is not null then
    return v_entry;
  end if;

  select exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'journal_shares'
      and c.column_name = 'is_active'
  )
  into has_is_active;

  if has_is_active then
    execute $qry$
      select exists (
        select 1
        from public.journal_shares s
        where s.journal_id = $1
          and s.recipient_id = auth.uid()
          and coalesce(s.is_active, true) = true
      )
    $qry$
    into can_view_as_recipient
    using p_journal_id;
  else
    select exists (
      select 1
      from public.journal_shares s
      where s.journal_id = p_journal_id
        and s.recipient_id = auth.uid()
        and (s.expires_at is null or s.expires_at > now())
    )
    into can_view_as_recipient;
  end if;

  if can_view_as_recipient then
    execute format(
      'select to_jsonb(e) from %s e where e.id = $1',
      entry_table
    )
    into v_entry
    using p_journal_id;

    return v_entry;
  end if;

  return null;
end;
$$;

grant execute on function public.get_journal_entry_for_view(uuid) to authenticated;
