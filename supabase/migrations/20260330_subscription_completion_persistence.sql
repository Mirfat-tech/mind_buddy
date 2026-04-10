begin;

update public.profiles
set
  subscription_completed = true,
  completed_at = coalesce(completed_at, now())
where lower(coalesce(subscription_tier, '')) in ('free', 'plus', 'full')
  and coalesce(subscription_completed, false) = false
  and coalesce(terms_version, '') <> ''
  and coalesce(privacy_version, '') <> '';

create or replace function public.set_my_subscription_plan(
  p_tier text,
  p_terms_version text default null,
  p_terms_accepted_at timestamptz default null,
  p_privacy_version text default null,
  p_privacy_accepted_at timestamptz default null
)
returns public.profiles
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_tier text := public.normalize_subscription_tier(p_tier);
  v_row public.profiles;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select u.email into v_email
  from auth.users u
  where u.id = v_uid;

  insert into public.profiles (
    id,
    email,
    subscription_tier,
    subscription_completed,
    completed_at,
    terms_version,
    terms_accepted_at,
    privacy_version,
    privacy_accepted_at
  )
  values (
    v_uid,
    v_email,
    v_tier,
    true,
    now(),
    p_terms_version,
    p_terms_accepted_at,
    p_privacy_version,
    p_privacy_accepted_at
  )
  on conflict (id) do update
    set email = coalesce(excluded.email, public.profiles.email),
        subscription_tier = excluded.subscription_tier,
        subscription_completed = true,
        completed_at = coalesce(public.profiles.completed_at, excluded.completed_at),
        terms_version = coalesce(excluded.terms_version, public.profiles.terms_version),
        terms_accepted_at = coalesce(excluded.terms_accepted_at, public.profiles.terms_accepted_at),
        privacy_version = coalesce(excluded.privacy_version, public.profiles.privacy_version),
        privacy_accepted_at = coalesce(excluded.privacy_accepted_at, public.profiles.privacy_accepted_at)
  returning * into v_row;

  return v_row;
end;
$$;

alter function public.set_my_subscription_plan(text, text, timestamptz, text, timestamptz) owner to postgres;
revoke all on function public.set_my_subscription_plan(text, text, timestamptz, text, timestamptz) from public;
grant execute on function public.set_my_subscription_plan(text, text, timestamptz, text, timestamptz) to authenticated;

commit;
