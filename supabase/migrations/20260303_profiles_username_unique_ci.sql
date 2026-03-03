begin;

-- Enforce username uniqueness case-insensitively.
create unique index if not exists profiles_username_unique_ci_idx
  on public.profiles ((lower(username)))
  where username is not null;

commit;

