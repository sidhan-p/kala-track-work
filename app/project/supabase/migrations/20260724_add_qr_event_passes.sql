alter table public.registrations
  add column if not exists qr_token uuid not null default gen_random_uuid();

create unique index if not exists registrations_qr_token_key
  on public.registrations(qr_token);

create or replace function public.checkin_registration_by_qr(p_qr_token uuid)
returns table (
  registration_id uuid,
  participant_name text,
  event_name text,
  team_name text,
  checked_in_at timestamptz,
  already_checked_in boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_registration public.registrations%rowtype;
  v_existing public.event_checkins%rowtype;
  v_checkin public.event_checkins%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  select r.*
    into v_registration
  from public.registrations r
  where r.qr_token = p_qr_token
    and r.status = 'approved';

  if not found then
    raise exception 'This QR pass is invalid or the registration is not approved';
  end if;

  if not exists (
    select 1
    from public.festival_members fm
    where fm.festival_id = v_registration.festival_id
      and fm.user_id = (select auth.uid())
  ) then
    raise exception 'You do not have access to this festival';
  end if;

  select ec.*
    into v_existing
  from public.event_checkins ec
  where ec.registration_id = v_registration.id;

  if found then
    return query
    select
      v_registration.id,
      coalesce(p.full_name, v_registration.group_name, 'Entry'),
      e.name,
      coalesce(t.name, 'Unassigned'),
      v_existing.checked_in_at,
      true
    from public.events e
    left join public.participants p on p.id = v_registration.participant_id
    left join public.teams t on t.id = p.team_id
    where e.id = v_registration.event_id;
    return;
  end if;

  insert into public.event_checkins (
    festival_id,
    event_id,
    registration_id,
    checked_in_by
  ) values (
    v_registration.festival_id,
    v_registration.event_id,
    v_registration.id,
    (select auth.uid())
  )
  returning * into v_checkin;

  return query
  select
    v_registration.id,
    coalesce(p.full_name, v_registration.group_name, 'Entry'),
    e.name,
    coalesce(t.name, 'Unassigned'),
    v_checkin.checked_in_at,
    false
  from public.events e
  left join public.participants p on p.id = v_registration.participant_id
  left join public.teams t on t.id = p.team_id
  where e.id = v_registration.event_id;
end;
$$;

revoke execute on function public.checkin_registration_by_qr(uuid)
  from public, anon;
grant execute on function public.checkin_registration_by_qr(uuid)
  to authenticated;
