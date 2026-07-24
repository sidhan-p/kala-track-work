create table if not exists public.team_manager_assignments (
  id uuid primary key default gen_random_uuid(),
  festival_id uuid not null references public.festivals(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  manager_id uuid not null references auth.users(id) on delete cascade,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (festival_id, manager_id),
  unique (festival_id, team_id)
);

alter table public.team_manager_assignments enable row level security;

create policy "team_manager_assignments_self_select"
on public.team_manager_assignments for select to authenticated
using (
  manager_id = (select auth.uid())
  or exists (
    select 1 from public.festival_members fm
    where fm.festival_id = team_manager_assignments.festival_id
      and fm.user_id = (select auth.uid())
      and fm.role in ('super_admin', 'fest_admin')
  )
);

create or replace function public.assign_team_manager(
  p_festival_id uuid,
  p_team_id uuid,
  p_email text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_assignment_id uuid;
begin
  if not exists (
    select 1 from public.festival_members fm
    where fm.festival_id = p_festival_id
      and fm.user_id = auth.uid()
      and fm.role in ('super_admin', 'fest_admin')
  ) then
    raise exception 'Only festival admins can assign team managers';
  end if;

  if not exists (
    select 1 from public.teams t
    where t.id = p_team_id and t.festival_id = p_festival_id
  ) then
    raise exception 'The selected team does not belong to this festival';
  end if;

  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = lower(trim(p_email))
    and u.email_confirmed_at is not null;

  if v_user_id is null then
    raise exception 'No verified KalaTrack account exists for this email';
  end if;

  if exists (
    select 1 from public.festival_members fm
    where fm.festival_id = p_festival_id
      and fm.user_id = v_user_id
      and fm.role <> 'team_manager'
  ) then
    raise exception 'This account already has a different festival role';
  end if;

  insert into public.festival_members (festival_id, user_id, role)
  values (p_festival_id, v_user_id, 'team_manager')
  on conflict (festival_id, user_id) do update set role = 'team_manager';

  insert into public.team_manager_assignments
    (festival_id, team_id, manager_id, created_by)
  values
    (p_festival_id, p_team_id, v_user_id, auth.uid())
  on conflict (festival_id, manager_id)
  do update set team_id = excluded.team_id, created_by = auth.uid()
  returning id into v_assignment_id;

  return v_assignment_id;
end;
$$;

revoke all on function public.assign_team_manager(uuid, uuid, text) from public, anon;
grant execute on function public.assign_team_manager(uuid, uuid, text) to authenticated;

create or replace function public.get_my_team_portal()
returns table (
  festival_id uuid,
  festival_name text,
  team_id uuid,
  team_name text,
  team_color text,
  participant_id uuid,
  participant_name text,
  admission_no text,
  event_id uuid,
  event_name text,
  scheduled_start timestamptz,
  venue_name text,
  checked_in_at timestamptz,
  live_status text
)
language sql
security definer
set search_path = ''
stable
as $$
  select
    f.id,
    f.name,
    t.id,
    t.name,
    t.color,
    p.id,
    p.full_name,
    p.admission_no,
    e.id,
    e.name,
    e.scheduled_start,
    v.name,
    ec.checked_in_at,
    coalesce(es.status, case when ec.id is not null then 'checked_in' else 'not_arrived' end)
  from public.team_manager_assignments a
  join public.festivals f on f.id = a.festival_id
  join public.teams t on t.id = a.team_id
  left join public.participants p on p.team_id = a.team_id and p.festival_id = a.festival_id
  left join public.registrations r on r.participant_id = p.id and r.status = 'approved'
  left join public.events e on e.id = r.event_id
  left join public.venues v on v.id = e.venue_id
  left join public.event_checkins ec on ec.registration_id = r.id
  left join public.event_entry_statuses es on es.registration_id = r.id
  where a.manager_id = auth.uid()
  order by e.scheduled_start nulls last, p.full_name;
$$;

revoke all on function public.get_my_team_portal() from public, anon;
grant execute on function public.get_my_team_portal() to authenticated;

drop policy if exists "participants_member_all" on public.participants;
create policy "participants_staff_all"
on public.participants for all to authenticated
using (exists (
  select 1 from public.festival_members fm
  where fm.festival_id = participants.festival_id
    and fm.user_id = (select auth.uid())
    and fm.role in ('super_admin', 'fest_admin', 'event_manager')
))
with check (exists (
  select 1 from public.festival_members fm
  where fm.festival_id = participants.festival_id
    and fm.user_id = (select auth.uid())
    and fm.role in ('super_admin', 'fest_admin', 'event_manager')
));

drop policy if exists "registrations_member_all" on public.registrations;
create policy "registrations_staff_all"
on public.registrations for all to authenticated
using (exists (
  select 1 from public.festival_members fm
  where fm.festival_id = registrations.festival_id
    and fm.user_id = (select auth.uid())
    and fm.role in ('super_admin', 'fest_admin', 'event_manager')
))
with check (exists (
  select 1 from public.festival_members fm
  where fm.festival_id = registrations.festival_id
    and fm.user_id = (select auth.uid())
    and fm.role in ('super_admin', 'fest_admin', 'event_manager')
));

drop policy if exists "events_member_all" on public.events;
create policy "events_member_select"
on public.events for select to authenticated
using (exists (
  select 1 from public.festival_members fm
  where fm.festival_id = events.festival_id
    and fm.user_id = (select auth.uid())
    and fm.role <> 'team_manager'
));
create policy "events_staff_write"
on public.events for all to authenticated
using (exists (
  select 1 from public.festival_members fm
  where fm.festival_id = events.festival_id
    and fm.user_id = (select auth.uid())
    and fm.role in ('super_admin', 'fest_admin', 'event_manager')
))
with check (exists (
  select 1 from public.festival_members fm
  where fm.festival_id = events.festival_id
    and fm.user_id = (select auth.uid())
    and fm.role in ('super_admin', 'fest_admin', 'event_manager')
));

drop policy if exists "event_checkins_member_select" on public.event_checkins;
create policy "event_checkins_staff_select"
on public.event_checkins for select to authenticated
using (exists (
  select 1 from public.festival_members fm
  where fm.festival_id = event_checkins.festival_id
    and fm.user_id = (select auth.uid())
    and fm.role in ('super_admin', 'fest_admin', 'event_manager')
));

drop policy if exists "event_entry_statuses_member_select" on public.event_entry_statuses;
create policy "event_entry_statuses_staff_select"
on public.event_entry_statuses for select to authenticated
using (exists (
  select 1 from public.festival_members fm
  where fm.festival_id = event_entry_statuses.festival_id
    and fm.user_id = (select auth.uid())
    and fm.role in ('super_admin', 'fest_admin', 'event_manager')
));

create index if not exists team_manager_assignments_manager_idx
on public.team_manager_assignments(manager_id);
