do $$
declare
  fk record;
begin
  if to_regclass('public.reminders') is null then
    return;
  end if;

  for fk in
    select
      con.conname as constraint_name,
      cls.relname as table_name
    from pg_constraint con
    join pg_class cls on cls.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = cls.relnamespace
    where con.contype = 'f'
      and con.confrelid = 'public.reminders'::regclass
      and nsp.nspname = 'public'
      and cls.relname in ('reminders_done', 'reminders_skips')
  loop
    execute format(
      'alter table public.%I drop constraint if exists %I',
      fk.table_name,
      fk.constraint_name
    );
  end loop;

  begin
    execute 'alter table public.reminders alter column id drop identity if exists';
  exception
    when others then null;
  end;

  begin
    execute 'alter table public.reminders alter column id drop default';
  exception
    when others then null;
  end;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'reminders'
      and column_name = 'id'
      and data_type <> 'text'
  ) then
    execute 'alter table public.reminders alter column id type text using id::text';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'reminders_done'
      and column_name = 'reminder_id'
      and data_type <> 'text'
  ) then
    execute 'alter table public.reminders_done alter column reminder_id type text using reminder_id::text';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'reminders_skips'
      and column_name = 'reminder_id'
      and data_type <> 'text'
  ) then
    execute 'alter table public.reminders_skips alter column reminder_id type text using reminder_id::text';
  end if;

  begin
    execute 'alter table public.reminders alter column id set default gen_random_uuid()::text';
  exception
    when others then null;
  end;

  if to_regclass('public.reminders_done') is not null then
    begin
      execute $sql$
        alter table public.reminders_done
        add constraint reminders_done_reminder_id_fkey
        foreign key (reminder_id)
        references public.reminders(id)
        on delete cascade
      $sql$;
    exception
      when duplicate_object then null;
    end;
  end if;

  if to_regclass('public.reminders_skips') is not null then
    begin
      execute $sql$
        alter table public.reminders_skips
        add constraint reminders_skips_reminder_id_fkey
        foreign key (reminder_id)
        references public.reminders(id)
        on delete cascade
      $sql$;
    exception
      when duplicate_object then null;
    end;
  end if;
end
$$;
