create table if not exists public.journal_shares (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  viewer_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint journal_shares_distinct_accounts check (owner_id <> viewer_id),
  constraint journal_shares_one_pair unique (owner_id, viewer_id)
);

alter table public.journal_shares enable row level security;
revoke all on public.journal_shares from public, anon, authenticated;
grant select on public.journal_shares to authenticated;
create index if not exists journal_shares_viewer_status_idx
  on public.journal_shares (viewer_id, status);

drop policy if exists "Participants can read their journal requests" on public.journal_shares;
create policy "Participants can read their journal requests"
  on public.journal_shares for select to authenticated
  using ((select auth.uid()) in (owner_id, viewer_id));

create or replace function public.request_journal_access(target_email text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  target_user_id uuid;
begin
  if current_user_id is null then
    raise exception 'Sign in to request journal access';
  end if;
  if target_email is null or length(trim(target_email)) = 0 or length(trim(target_email)) > 320 then
    raise exception 'Enter a valid account email';
  end if;

  select u.id into target_user_id
  from auth.users as u
  where lower(u.email) = lower(trim(target_email))
    and u.email_confirmed_at is not null
  limit 1;

  if target_user_id is null or target_user_id = current_user_id then
    return;
  end if;

  insert into public.journal_shares as existing (owner_id, viewer_id)
  values (target_user_id, current_user_id)
  on conflict (owner_id, viewer_id) do update
    set status = 'pending', created_at = now(), updated_at = now()
    where existing.status = 'declined';
end;
$$;

revoke all on function public.request_journal_access(text) from public, anon;
grant execute on function public.request_journal_access(text) to authenticated;

create or replace function public.list_journal_shares()
returns table (
  share_id uuid,
  owner_id uuid,
  viewer_id uuid,
  status text,
  created_at timestamptz,
  partner_email text,
  partner_display_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select js.id,
         js.owner_id,
         js.viewer_id,
         js.status,
         js.created_at,
         partner.email::text,
         coalesce(partner.raw_user_meta_data ->> 'display_name', '')
  from public.journal_shares as js
  join auth.users as partner
    on partner.id = case
      when js.owner_id = (select auth.uid()) then js.viewer_id
      else js.owner_id
    end
  where js.owner_id = (select auth.uid())
     or js.viewer_id = (select auth.uid())
  order by js.created_at desc;
$$;

revoke all on function public.list_journal_shares() from public, anon;
grant execute on function public.list_journal_shares() to authenticated;

create or replace function public.respond_journal_access(request_id uuid, accept_request boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in to respond to journal requests';
  end if;

  update public.journal_shares
  set status = case when accept_request then 'accepted' else 'declined' end,
      updated_at = now()
  where id = request_id
    and owner_id = (select auth.uid())
    and status = 'pending';

  if not found then
    raise exception 'The journal request is unavailable or has already been handled';
  end if;

  return true;
end;
$$;

revoke all on function public.respond_journal_access(uuid, boolean) from public, anon;
grant execute on function public.respond_journal_access(uuid, boolean) to authenticated;

create or replace function public.remove_journal_access(request_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in to remove journal access';
  end if;

  delete from public.journal_shares
  where id = request_id
    and (owner_id = (select auth.uid()) or viewer_id = (select auth.uid()));

  if not found then
    raise exception 'The journal request or access grant was not found';
  end if;

  return true;
end;
$$;

revoke all on function public.remove_journal_access(uuid) from public, anon;
grant execute on function public.remove_journal_access(uuid) to authenticated;

create or replace function public.get_shared_journal(journal_owner_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  journal jsonb;
begin
  if current_user_id is null or not exists (
    select 1
    from public.journal_shares as js
    where js.owner_id = journal_owner_id
      and js.viewer_id = current_user_id
      and js.status = 'accepted'
  ) then
    raise exception 'This journal is not shared with your account';
  end if;

  select jsonb_build_object(
    'trades', coalesce(j.trades, '[]'::jsonb),
    'currency', coalesce(nullif(j.settings ->> 'cur', ''), '₹')
  )
  into journal
  from public.journal_data as j
  where j.user_id = journal_owner_id;

  return coalesce(journal, jsonb_build_object('trades', '[]'::jsonb, 'currency', '₹'));
end;
$$;

revoke all on function public.get_shared_journal(uuid) from public, anon;
grant execute on function public.get_shared_journal(uuid) to authenticated;
