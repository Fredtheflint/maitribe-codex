-- MaiTribe hotfix: ensure authenticated users can read their own users row.
-- Safe to run multiple times.

alter table public.users enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'users_select_own'
  ) then
    create policy "users_select_own"
      on public.users
      for select
      using (auth.uid() = id);
  end if;
end $$;
