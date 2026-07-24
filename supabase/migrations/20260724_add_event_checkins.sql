create table if not exists public.event_checkins (
  id uuid primary key default gen_random_uuid(),
  festival_id uuid not null references public.festivals(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  registration_id uuid not null references public.registrations(id) on delete cascade,
  checked_in_by uuid not null references auth.users(id),
  checked_in_at timestamptz not null default now(),
  notes text,
  unique (registration_id)
);

create index if not exists event_checkins_festival_id_idx on public.event_checkins(festival_id);
create index if not exists event_checkins_event_id_idx on public.event_checkins(event_id);
create index if not exists event_checkins_checked_in_by_idx on public.event_checkins(checked_in_by);
alter table public.event_checkins enable row level security;

create policy "event_checkins_member_select" on public.event_checkins for select to authenticated
using (exists (
  select 1 from public.festival_members fm
  where fm.festival_id = event_checkins.festival_id
    and fm.user_id = (select auth.uid())
));

create policy "event_checkins_member_insert" on public.event_checkins for insert to authenticated
with check (
  checked_in_by = (select auth.uid())
  and exists (
    select 1 from public.festival_members fm
    where fm.festival_id = event_checkins.festival_id
      and fm.user_id = (select auth.uid())
  )
  and exists (
    select 1 from public.registrations r
    where r.id = event_checkins.registration_id
      and r.festival_id = event_checkins.festival_id
      and r.event_id = event_checkins.event_id
      and r.status = 'approved'
  )
);

create policy "event_checkins_member_delete" on public.event_checkins for delete to authenticated
using (exists (
  select 1 from public.festival_members fm
  where fm.festival_id = event_checkins.festival_id
    and fm.user_id = (select auth.uid())
));
