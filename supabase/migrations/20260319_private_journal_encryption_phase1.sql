-- Phase 1 private journal encryption.
-- Security model:
-- 1. Only sensitive journal body content is encrypted.
-- 2. Title and structural metadata stay plaintext for app functionality.
-- 3. Shared recipients read from an explicit shared copy, not the encrypted source.

alter table public.journals
  add column if not exists encrypted_content text,
  add column if not exists iv text,
  add column if not exists encryption_version integer,
  add column if not exists key_version integer,
  add column if not exists is_encrypted boolean not null default false,
  add column if not exists share_source_journal_id uuid references public.journals(id) on delete cascade,
  add column if not exists shared_recipient_id uuid references auth.users(id) on delete cascade;

comment on column public.journals.text is
  'Plaintext journal body only for legacy rows and explicit shared copies. Private source rows must store body in encrypted_content instead.';
comment on column public.journals.title is
  'Plaintext title metadata. Phase 1 encrypts only the sensitive journal body.';
comment on column public.journals.encrypted_content is
  'Base64 AES-GCM ciphertext plus authentication tag for private journal bodies.';
comment on column public.journals.iv is
  'Base64 AES-GCM IV/nonce for encrypted_content.';
comment on column public.journals.share_source_journal_id is
  'References the private source journal when this row is a readable shared copy.';

alter table public.journal_shares
  add column if not exists shared_journal_id uuid references public.journals(id) on delete set null;

create index if not exists journals_share_source_idx
  on public.journals (share_source_journal_id);

create unique index if not exists journals_shared_copy_unique_idx
  on public.journals (share_source_journal_id, shared_recipient_id)
  where share_source_journal_id is not null
    and shared_recipient_id is not null;

create index if not exists journal_shares_shared_journal_idx
  on public.journal_shares (shared_journal_id);

alter table public.journals
  drop constraint if exists journals_private_body_encryption_check;

alter table public.journals
  add constraint journals_private_body_encryption_check
  check (
    is_encrypted = false
    or (
      encrypted_content is not null
      and iv is not null
      and encryption_version is not null
      and text is null
    )
  );

drop policy if exists journals_select_owner_or_shared_recipient on public.journals;
create policy journals_select_owner_or_shared_recipient
  on public.journals
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.journal_shares s
      where (
          s.journal_id = id
          or s.shared_journal_id = id
        )
        and s.recipient_id = auth.uid()
        and (s.expires_at is null or s.expires_at > now())
        and not public.is_blocked_pair(s.sender_id, auth.uid())
    )
  );

drop function if exists public.get_journal_entry_for_view(uuid);

create or replace function public.get_journal_entry_for_view(p_journal_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entry jsonb;
  v_shared_copy_id uuid;
begin
  select to_jsonb(j)
  into v_entry
  from public.journals j
  where j.id = p_journal_id
    and j.user_id = auth.uid();

  if v_entry is not null then
    return v_entry;
  end if;

  select s.shared_journal_id
  into v_shared_copy_id
  from public.journal_shares s
  where s.journal_id = p_journal_id
    and s.recipient_id = auth.uid()
    and (s.expires_at is null or s.expires_at > now())
    and not public.is_blocked_pair(s.sender_id, auth.uid())
  limit 1;

  if v_shared_copy_id is not null then
    select to_jsonb(j)
    into v_entry
    from public.journals j
    where j.id = v_shared_copy_id;

    if v_entry is not null then
      return v_entry || jsonb_build_object('source_journal_id', p_journal_id);
    end if;
  end if;

  select to_jsonb(j)
  into v_entry
  from public.journals j
  where j.id = p_journal_id
    and exists (
      select 1
      from public.journal_shares s
      where s.journal_id = p_journal_id
        and s.recipient_id = auth.uid()
        and (s.expires_at is null or s.expires_at > now())
        and not public.is_blocked_pair(s.sender_id, auth.uid())
    );

  return v_entry;
end;
$$;

grant execute on function public.get_journal_entry_for_view(uuid) to authenticated;
