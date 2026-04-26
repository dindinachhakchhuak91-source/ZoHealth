create table if not exists public.growth_tracker_states (
  user_id uuid primary key references auth.users (id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.micronutrition_tracker_states (
  user_id uuid primary key references auth.users (id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists growth_tracker_states_updated_at_idx
  on public.growth_tracker_states (updated_at desc);

create index if not exists micronutrition_tracker_states_updated_at_idx
  on public.micronutrition_tracker_states (updated_at desc);

alter table public.growth_tracker_states enable row level security;
alter table public.micronutrition_tracker_states enable row level security;

drop policy if exists "Users can read their own growth tracker state"
  on public.growth_tracker_states;
create policy "Users can read their own growth tracker state"
  on public.growth_tracker_states
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own growth tracker state"
  on public.growth_tracker_states;
create policy "Users can insert their own growth tracker state"
  on public.growth_tracker_states
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own growth tracker state"
  on public.growth_tracker_states;
create policy "Users can update their own growth tracker state"
  on public.growth_tracker_states
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own growth tracker state"
  on public.growth_tracker_states;
create policy "Users can delete their own growth tracker state"
  on public.growth_tracker_states
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read their own micronutrition tracker state"
  on public.micronutrition_tracker_states;
create policy "Users can read their own micronutrition tracker state"
  on public.micronutrition_tracker_states
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own micronutrition tracker state"
  on public.micronutrition_tracker_states;
create policy "Users can insert their own micronutrition tracker state"
  on public.micronutrition_tracker_states
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own micronutrition tracker state"
  on public.micronutrition_tracker_states;
create policy "Users can update their own micronutrition tracker state"
  on public.micronutrition_tracker_states
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own micronutrition tracker state"
  on public.micronutrition_tracker_states;
create policy "Users can delete their own micronutrition tracker state"
  on public.micronutrition_tracker_states
  for delete
  to authenticated
  using (auth.uid() = user_id);
