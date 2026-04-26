create table if not exists public.user_questions (
  id text primary key,
  question text not null default '',
  user_name text not null default '',
  gender text not null default '',
  age integer not null default 0,
  height_cm double precision not null default 0,
  weight_kg double precision not null default 0,
  recent_eating_window text not null default '',
  recent_food text not null default '',
  asked_at timestamptz not null default timezone('utc', now()),
  reply text,
  replied_at timestamptz,
  is_answered boolean not null default false
);

alter table public.user_questions
  add column if not exists gender text not null default '',
  add column if not exists age integer not null default 0,
  add column if not exists height_cm double precision not null default 0,
  add column if not exists weight_kg double precision not null default 0,
  add column if not exists recent_eating_window text not null default '',
  add column if not exists recent_food text not null default '';

alter table public.user_questions
  alter column question set default '',
  alter column user_name set default '',
  alter column asked_at set default timezone('utc', now()),
  alter column is_answered set default false;

alter table public.user_questions
  alter column question set not null,
  alter column user_name set not null,
  alter column gender set not null,
  alter column age set not null,
  alter column height_cm set not null,
  alter column weight_kg set not null,
  alter column recent_eating_window set not null,
  alter column recent_food set not null,
  alter column asked_at set not null,
  alter column is_answered set not null;

alter table public.user_questions enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_questions'
      and policyname = 'Authenticated users can read questions'
  ) then
    create policy "Authenticated users can read questions"
      on public.user_questions
      for select
      to authenticated
      using (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_questions'
      and policyname = 'Authenticated users can insert questions'
  ) then
    create policy "Authenticated users can insert questions"
      on public.user_questions
      for insert
      to authenticated
      with check (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_questions'
      and policyname = 'Authenticated users can update questions'
  ) then
    create policy "Authenticated users can update questions"
      on public.user_questions
      for update
      to authenticated
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_questions'
      and policyname = 'Authenticated users can delete questions'
  ) then
    create policy "Authenticated users can delete questions"
      on public.user_questions
      for delete
      to authenticated
      using (true);
  end if;
end
$$;
