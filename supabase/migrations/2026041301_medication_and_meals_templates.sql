create extension if not exists pgcrypto;

create table if not exists public.medication_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  medication_name text not null default '',
  time text,
  dosage text,
  status text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.meals_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  meal_name text not null default '',
  time text,
  meal_type text,
  calories numeric,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists public.medication_logs enable row level security;
alter table if exists public.meals_logs enable row level security;

drop policy if exists medication_logs_select_own on public.medication_logs;
create policy medication_logs_select_own
  on public.medication_logs
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists medication_logs_insert_own on public.medication_logs;
create policy medication_logs_insert_own
  on public.medication_logs
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists medication_logs_update_own on public.medication_logs;
create policy medication_logs_update_own
  on public.medication_logs
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists medication_logs_delete_own on public.medication_logs;
create policy medication_logs_delete_own
  on public.medication_logs
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists meals_logs_select_own on public.meals_logs;
create policy meals_logs_select_own
  on public.meals_logs
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists meals_logs_insert_own on public.meals_logs;
create policy meals_logs_insert_own
  on public.meals_logs
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists meals_logs_update_own on public.meals_logs;
create policy meals_logs_update_own
  on public.meals_logs
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists meals_logs_delete_own on public.meals_logs;
create policy meals_logs_delete_own
  on public.meals_logs
  for delete
  to authenticated
  using (auth.uid() = user_id);

create index if not exists medication_logs_user_day_idx
  on public.medication_logs(user_id, day desc);

create index if not exists meals_logs_user_day_idx
  on public.meals_logs(user_id, day desc);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists medication_logs_touch_updated_at on public.medication_logs;
create trigger medication_logs_touch_updated_at
before update on public.medication_logs
for each row execute function public.touch_updated_at();

drop trigger if exists meals_logs_touch_updated_at on public.meals_logs;
create trigger meals_logs_touch_updated_at
before update on public.meals_logs
for each row execute function public.touch_updated_at();

do $$
declare
  medication_template_id uuid;
  meals_template_id uuid;
begin
  select id into medication_template_id
  from public.log_templates_v2
  where user_id is null and lower(template_key) = 'medication'
  limit 1;

  if medication_template_id is null then
    insert into public.log_templates_v2 (id, user_id, name, template_key, created_at, updated_at)
    values (gen_random_uuid(), null, 'Medication', 'medication', now(), now())
    returning id into medication_template_id;
  else
    update public.log_templates_v2
    set name = 'Medication',
        template_key = 'medication',
        updated_at = now()
    where id = medication_template_id;
  end if;

  delete from public.log_template_fields_v2 where template_id = medication_template_id;

  insert into public.log_template_fields_v2
    (id, template_id, user_id, field_key, label, field_type, options, sort_order, is_hidden, created_at, updated_at)
  values
    (gen_random_uuid(), medication_template_id, null, 'medication_name', 'Medication name', 'text', null, 1, false, now(), now()),
    (gen_random_uuid(), medication_template_id, null, 'time', 'Time', 'time', null, 2, false, now(), now()),
    (gen_random_uuid(), medication_template_id, null, 'dosage', 'Dosage', 'text', null, 3, false, now(), now()),
    (gen_random_uuid(), medication_template_id, null, 'status', 'Status', 'dropdown', 'Taken,Missed,Skipped', 4, false, now(), now()),
    (gen_random_uuid(), medication_template_id, null, 'notes', 'Notes', 'text', null, 5, false, now(), now());

  select id into meals_template_id
  from public.log_templates_v2
  where user_id is null and lower(template_key) = 'meals'
  limit 1;

  if meals_template_id is null then
    insert into public.log_templates_v2 (id, user_id, name, template_key, created_at, updated_at)
    values (gen_random_uuid(), null, 'Meals', 'meals', now(), now())
    returning id into meals_template_id;
  else
    update public.log_templates_v2
    set name = 'Meals',
        template_key = 'meals',
        updated_at = now()
    where id = meals_template_id;
  end if;

  delete from public.log_template_fields_v2 where template_id = meals_template_id;

  insert into public.log_template_fields_v2
    (id, template_id, user_id, field_key, label, field_type, options, sort_order, is_hidden, created_at, updated_at)
  values
    (gen_random_uuid(), meals_template_id, null, 'meal_name', 'Meal name', 'text', null, 1, false, now(), now()),
    (gen_random_uuid(), meals_template_id, null, 'time', 'Time', 'time', null, 2, false, now(), now()),
    (gen_random_uuid(), meals_template_id, null, 'meal_type', 'Meal type', 'dropdown', 'Breakfast,Lunch,Dinner,Snack', 3, false, now(), now()),
    (gen_random_uuid(), meals_template_id, null, 'calories', 'Calories', 'number', null, 4, false, now(), now()),
    (gen_random_uuid(), meals_template_id, null, 'notes', 'Notes', 'text', null, 5, false, now(), now());
end $$;
