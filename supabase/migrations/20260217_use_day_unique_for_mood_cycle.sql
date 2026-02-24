begin;

-- Use existing day column as the single source of truth for daily uniqueness.
-- Keep this migration idempotent for environments that may already have prior indexes.

-- Remove log_date-based unique indexes if they exist.
drop index if exists public.mood_logs_user_id_log_date_unique;
drop index if exists public.menstrual_logs_user_id_log_date_unique;

-- Remove duplicates before adding unique(user_id, day).
with ranked as (
  select
    ctid,
    row_number() over (
      partition by user_id, day
      order by ctid desc
    ) as rn
  from public.mood_logs
  where day is not null
)
delete from public.mood_logs m
using ranked r
where m.ctid = r.ctid
  and r.rn > 1;

with ranked as (
  select
    ctid,
    row_number() over (
      partition by user_id, day
      order by ctid desc
    ) as rn
  from public.menstrual_logs
  where day is not null
)
delete from public.menstrual_logs m
using ranked r
where m.ctid = r.ctid
  and r.rn > 1;

-- Enforce one entry per user per day.
create unique index if not exists mood_logs_user_id_day_unique
  on public.mood_logs (user_id, day);

create unique index if not exists menstrual_logs_user_id_day_unique
  on public.menstrual_logs (user_id, day);

commit;
