-- Add profile fields needed by signup.
alter table if exists public.profiles
  add column if not exists full_name text,
  add column if not exists date_of_birth date;

-- Shared age check helper.
create or replace function public.is_user_at_least_13(dob date)
returns boolean
language sql
stable
as $$
  select dob <= ((current_date - interval '13 years')::date);
$$;

-- Enforce minimum age whenever date_of_birth is written on profiles.
create or replace function public.enforce_profile_minimum_age()
returns trigger
language plpgsql
as $$
begin
  if new.date_of_birth is not null and not public.is_user_at_least_13(new.date_of_birth) then
    raise exception 'You must be at least 13 years old to use this app.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_profiles_enforce_minimum_age on public.profiles;
create trigger trg_profiles_enforce_minimum_age
before insert or update of date_of_birth
on public.profiles
for each row
execute function public.enforce_profile_minimum_age();

-- Enforce minimum age at auth signup for email/password registrations.
create or replace function public.enforce_auth_signup_minimum_age()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  provider text;
  dob_text text;
  dob date;
  age_confirmed text;
begin
  provider := lower(coalesce(new.raw_app_meta_data ->> 'provider', ''));

  if provider = 'email' then
    dob_text := coalesce(new.raw_user_meta_data ->> 'date_of_birth', '');
    age_confirmed := lower(coalesce(new.raw_user_meta_data ->> 'is_13_or_over', 'false'));

    if age_confirmed not in ('true', '1', 'yes') then
      raise exception 'You must confirm that you are 13 or older.';
    end if;

    if dob_text = '' then
      raise exception 'Date of birth is required.';
    end if;

    begin
      dob := dob_text::date;
    exception
      when others then
        raise exception 'Invalid date of birth.';
    end;

    if not public.is_user_at_least_13(dob) then
      raise exception 'You must be at least 13 years old to use this app.';
    end if;
  end if;

  return new;
end;
$$;

alter function public.enforce_auth_signup_minimum_age() owner to postgres;

do $$
begin
  if to_regclass('auth.users') is not null then
    execute 'drop trigger if exists trg_auth_users_enforce_minimum_age on auth.users';
    execute 'create trigger trg_auth_users_enforce_minimum_age before insert on auth.users for each row execute function public.enforce_auth_signup_minimum_age()';
  end if;
end $$;
