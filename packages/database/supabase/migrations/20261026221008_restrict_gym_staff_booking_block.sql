-- gym_staff puede monitorear la malla, pero una reserva creada por autoservicio
-- queda restringida al bloque institucional de funcionarios (17:15). Esta
-- guarda también cubre reactivaciones y reemplazos de reserva.
create function private.assert_gym_staff_self_service_booking_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role public.app_role;
begin
  if
    new.admission_source <> 'self_service'
    or new.time_block_id = 7
    or new.status not in ('reserved', 'confirmed')
  then
    return new;
  end if;

  select role into v_role
  from public.app_user
  where user_id = new.user_id;

  if v_role = 'gym_staff' then
    raise exception 'gym staff can only reserve time block 7';
  end if;

  return new;
end;
$$;

create trigger booking_restrict_gym_staff_self_service
before insert or update of user_id, time_block_id, status, admission_source
on public.booking
for each row
execute function private.assert_gym_staff_self_service_booking_block();

revoke all on function private.assert_gym_staff_self_service_booking_block()
from public, anon, authenticated;

-- gym_staff y admin supervisan toda la malla actual. Realtime sigue emitiendo
-- solo invalidaciones privadas, no filas ni datos de participantes.
create or replace function private.can_receive_booking_availability_topic(p_topic text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_topic_parts text[];
  v_booking_date date;
  v_time_block_id smallint;
  v_user public.app_user%rowtype;
begin
  v_topic_parts := regexp_match(
    p_topic,
    $topic$^booking-availability:([0-9]{4}-[0-9]{2}-[0-9]{2}):([1-9])$topic$
  );

  if v_topic_parts is null then
    return false;
  end if;

  v_booking_date := private.parse_strict_iso_date(v_topic_parts[1]);
  v_time_block_id := v_topic_parts[2]::smallint;

  if v_booking_date is null
    or v_booking_date <> (now() at time zone 'America/Santiago')::date
    or extract(isodow from v_booking_date) not between 1 and 5 then
    return false;
  end if;

  select app_user.* into v_user
  from public.app_user
  where app_user.user_id = (select auth.uid())
    and app_user.disabled_at is null;

  if not found then
    return false;
  elsif v_user.role = 'student' then
    return v_time_block_id <> 7;
  elsif v_user.role = 'u_staff' then
    return v_user.allowed_time_block_id = v_time_block_id;
  elsif v_user.role in ('gym_staff', 'admin') then
    return true;
  end if;

  return false;
end;
$$;
