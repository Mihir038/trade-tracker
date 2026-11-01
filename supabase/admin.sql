create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.users u
    where u.id = (select auth.uid())
      and lower(u.email) = 'admin@jaymaharaj.in'
      and u.email_confirmed_at is not null
  );
$$;

revoke all on function public.is_site_admin() from public, anon;
grant execute on function public.is_site_admin() to authenticated;

drop policy if exists "Admins can manage all journals" on public.journal_data;
create policy "Admins can manage all journals"
  on public.journal_data for all to authenticated
  using ((select public.is_site_admin()))
  with check ((select public.is_site_admin()));

create table if not exists public.site_content (
  id text primary key check (id = 'learning'),
  content jsonb not null
    check (jsonb_typeof(content) = 'object'),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null
);

alter table public.site_content enable row level security;

revoke all on public.site_content from anon;
grant select, insert, update on public.site_content to authenticated;

drop policy if exists "Signed-in users can read site content" on public.site_content;
create policy "Signed-in users can read site content"
  on public.site_content for select to authenticated
  using (true);

drop policy if exists "Admins can create site content" on public.site_content;
create policy "Admins can create site content"
  on public.site_content for insert to authenticated
  with check ((select public.is_site_admin()));

drop policy if exists "Admins can update site content" on public.site_content;
create policy "Admins can update site content"
  on public.site_content for update to authenticated
  using ((select public.is_site_admin()))
  with check ((select public.is_site_admin()));

create or replace function public.admin_list_users()
returns table (
  user_id uuid,
  email text,
  display_name text,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  has_journal boolean
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_site_admin() then
    raise exception 'Not authorized';
  end if;

  return query
    select u.id,
           u.email::text,
           coalesce(u.raw_user_meta_data ->> 'display_name', ''),
           u.created_at,
           u.last_sign_in_at,
           (j.user_id is not null)
    from auth.users u
    left join public.journal_data j on j.user_id = u.id
    order by u.created_at desc;
end;
$$;

revoke all on function public.admin_list_users() from public, anon;
grant execute on function public.admin_list_users() to authenticated;

create or replace function public.admin_delete_user(target_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_site_admin() then
    raise exception 'Not authorized';
  end if;

  if target_user_id = (select auth.uid()) then
    raise exception 'The admin account cannot delete itself';
  end if;

  delete from auth.users
  where id = target_user_id
    and lower(email) <> 'admin@jaymaharaj.in';

  if not found then
    raise exception 'User not found or protected';
  end if;

  return true;
end;
$$;

revoke all on function public.admin_delete_user(uuid) from public, anon;
grant execute on function public.admin_delete_user(uuid) to authenticated;
