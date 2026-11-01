create table if not exists public.journal_data (
  user_id uuid primary key references auth.users (id) on delete cascade,
  trades jsonb not null default '[]'::jsonb
    check (jsonb_typeof(trades) = 'array'),
  strategies jsonb not null default '[]'::jsonb
    check (jsonb_typeof(strategies) = 'array'),
  notes jsonb not null default '[]'::jsonb
    check (jsonb_typeof(notes) = 'array'),
  settings jsonb not null default '{}'::jsonb
    check (jsonb_typeof(settings) = 'object')
);

alter table public.journal_data enable row level security;

revoke all on public.journal_data from anon;
grant select, insert, update, delete on public.journal_data to authenticated;

drop policy if exists "Users can read their own journal" on public.journal_data;
create policy "Users can read their own journal"
  on public.journal_data for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their own journal" on public.journal_data;
create policy "Users can create their own journal"
  on public.journal_data for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own journal" on public.journal_data;
create policy "Users can update their own journal"
  on public.journal_data for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own journal" on public.journal_data;
create policy "Users can delete their own journal"
  on public.journal_data for delete to authenticated
  using ((select auth.uid()) = user_id);
