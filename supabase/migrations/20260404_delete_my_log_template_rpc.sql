begin;

alter table if exists public.log_templates_v2 enable row level security;
alter table if exists public.log_template_fields_v2 enable row level security;
alter table if exists public.user_template_settings enable row level security;

drop policy if exists log_templates_v2_select_own_or_builtin on public.log_templates_v2;
create policy log_templates_v2_select_own_or_builtin
  on public.log_templates_v2
  for select
  using (user_id is null or auth.uid() = user_id);

drop policy if exists log_templates_v2_insert_own on public.log_templates_v2;
create policy log_templates_v2_insert_own
  on public.log_templates_v2
  for insert
  with check (auth.uid() = user_id);

drop policy if exists log_templates_v2_update_own on public.log_templates_v2;
create policy log_templates_v2_update_own
  on public.log_templates_v2
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists log_templates_v2_delete_own on public.log_templates_v2;
create policy log_templates_v2_delete_own
  on public.log_templates_v2
  for delete
  using (auth.uid() = user_id);

drop policy if exists log_template_fields_v2_select_own_or_builtin on public.log_template_fields_v2;
create policy log_template_fields_v2_select_own_or_builtin
  on public.log_template_fields_v2
  for select
  using (user_id is null or auth.uid() = user_id);

drop policy if exists log_template_fields_v2_insert_own on public.log_template_fields_v2;
create policy log_template_fields_v2_insert_own
  on public.log_template_fields_v2
  for insert
  with check (auth.uid() = user_id);

drop policy if exists log_template_fields_v2_update_own on public.log_template_fields_v2;
create policy log_template_fields_v2_update_own
  on public.log_template_fields_v2
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists log_template_fields_v2_delete_own on public.log_template_fields_v2;
create policy log_template_fields_v2_delete_own
  on public.log_template_fields_v2
  for delete
  using (auth.uid() = user_id);

drop policy if exists user_template_settings_select_own on public.user_template_settings;
create policy user_template_settings_select_own
  on public.user_template_settings
  for select
  using (auth.uid() = user_id);

drop policy if exists user_template_settings_insert_own on public.user_template_settings;
create policy user_template_settings_insert_own
  on public.user_template_settings
  for insert
  with check (auth.uid() = user_id);

drop policy if exists user_template_settings_update_own on public.user_template_settings;
create policy user_template_settings_update_own
  on public.user_template_settings
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists user_template_settings_delete_own on public.user_template_settings;
create policy user_template_settings_delete_own
  on public.user_template_settings
  for delete
  using (auth.uid() = user_id);

create or replace function public.delete_my_log_template(p_template_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_template record;
  v_table_name text;
begin
  if v_user_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select id, template_key
  into v_template
  from public.log_templates_v2
  where id = p_template_id
    and user_id = v_user_id;

  if v_template is null then
    return jsonb_build_object('deleted', false, 'reason', 'not_found');
  end if;

  v_table_name := case lower(coalesce(v_template.template_key, ''))
    when 'goals' then 'goal_logs'
    when 'water' then 'water_logs'
    when 'sleep' then 'sleep_logs'
    when 'cycle' then 'menstrual_logs'
    when 'books' then 'book_logs'
    when 'income' then 'income_logs'
    when 'wishlist' then 'wishlist'
    when 'restaurants' then 'restaurant_logs'
    when 'movies' then 'movie_logs'
    when 'bills' then 'bill_logs'
    when 'expenses' then 'expense_logs'
    when 'places' then 'place_logs'
    when 'tasks' then 'task_logs'
    when 'fast' then 'fast_logs'
    when 'meditation' then 'meditation_logs'
    when 'skin_care' then 'skin_care_logs'
    when 'social' then 'social_logs'
    when 'study' then 'study_logs'
    when 'workout' then 'workout_logs'
    when 'tv_log' then 'tv_logs'
    when 'mood' then 'mood_logs'
    when 'symptoms' then 'symptom_logs'
    else lower(coalesce(v_template.template_key, '')) || '_logs'
  end;

  if v_table_name <> '' and to_regclass('public.' || v_table_name) is not null then
    execute format('delete from public.%I where user_id = $1', v_table_name)
    using v_user_id;
  end if;

  if to_regclass('public.log_entries') is not null then
    execute 'delete from public.log_entries where template_id = $1 and user_id = $2'
    using p_template_id, v_user_id;
  end if;

  delete from public.user_template_settings
  where template_id = p_template_id
    and user_id = v_user_id;

  delete from public.log_template_fields_v2
  where template_id = p_template_id
    and user_id = v_user_id;

  delete from public.log_templates_v2
  where id = p_template_id
    and user_id = v_user_id;

  return jsonb_build_object(
    'deleted',
    not exists (
      select 1
      from public.log_templates_v2
      where id = p_template_id
        and user_id = v_user_id
    )
  );
end;
$$;

alter function public.delete_my_log_template(uuid) owner to postgres;
revoke all on function public.delete_my_log_template(uuid) from public;
grant execute on function public.delete_my_log_template(uuid) to authenticated;

commit;
