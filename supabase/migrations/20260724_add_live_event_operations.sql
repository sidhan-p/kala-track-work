create table if not exists public.event_entry_statuses (
  id uuid primary key default gen_random_uuid(),
  festival_id uuid not null references public.festivals(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  registration_id uuid not null references public.registrations(id) on delete cascade,
  status text not null default 'checked_in'
    check (status in ('checked_in', 'call_room', 'ready', 'completed', 'absent')),
  updated_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now(),
  unique (registration_id)
);

create index if not exists event_entry_statuses_festival_id_idx
  on public.event_entry_statuses(festival_id);
create index if not exists event_entry_statuses_event_id_idx
  on public.event_entry_statuses(event_id);

alter table public.event_entry_statuses enable row level security;

create policy "event_entry_statuses_member_select"
on public.event_entry_statuses for select to authenticated
using (exists (
  select 1 from public.festival_members fm
  where fm.festival_id = event_entry_statuses.festival_id
    and fm.user_id = (select auth.uid())
));

create policy "event_entry_statuses_member_insert"
on public.event_entry_statuses for insert to authenticated
with check (
  updated_by = (select auth.uid())
  and exists (
    select 1 from public.festival_members fm
    where fm.festival_id = event_entry_statuses.festival_id
      and fm.user_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.event_checkins ec
    where ec.registration_id = event_entry_statuses.registration_id
      and ec.festival_id = event_entry_statuses.festival_id
      and ec.event_id = event_entry_statuses.event_id
  )
);

create policy "event_entry_statuses_member_update"
on public.event_entry_statuses for update to authenticated
using (exists (
  select 1 from public.festival_members fm
  where fm.festival_id = event_entry_statuses.festival_id
    and fm.user_id = (select auth.uid())
))
with check (
  updated_by = (select auth.uid())
  and exists (
    select 1 from public.festival_members fm
    where fm.festival_id = event_entry_statuses.festival_id
      and fm.user_id = (select auth.uid())
  )
);

grant select, insert, update on public.event_entry_statuses to authenticated;
