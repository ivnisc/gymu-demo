create function public.seed_demo_current_block_context()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bundle private.demo_persona_bundle%rowtype;
  v_position integer := 0;
  v_today date := (clock_timestamp() at time zone 'America/Santiago')::date;
  v_participant_block_id smallint;
  v_requested_block_id smallint;
begin
  if extract(isodow from v_today) not between 1 and 5 then
    return;
  end if;

  for v_bundle in select * from private.demo_persona_bundle order by bundle_key
  loop
    v_position := v_position + 1;
    v_participant_block_id := ((v_position - 1) % 9 + 1)::smallint;
    v_requested_block_id := (v_position % 9 + 1)::smallint;

    insert into public.booking (
      user_id, time_block_id, booking_date, status, booked_at, confirmed_at
    ) values (
      v_bundle.student_user_id,
      v_participant_block_id,
      v_today,
      'confirmed',
      clock_timestamp() - interval '35 minutes',
      clock_timestamp() - interval '20 minutes'
    )
    on conflict (user_id, time_block_id, booking_date) do nothing;

    insert into public.booking (
      user_id, time_block_id, booking_date, status, booked_at, confirmed_at
    ) values (
      v_bundle.u_staff_user_id,
      7,
      v_today,
      'confirmed',
      clock_timestamp() - interval '35 minutes',
      clock_timestamp() - interval '20 minutes'
    )
    on conflict (user_id, time_block_id, booking_date) do nothing;

    insert into private.staff_block_admission_request (
      user_id, booking_date, time_block_id, requested_at, expires_at
    ) values (
      v_bundle.student_user_id,
      v_today,
      v_requested_block_id,
      clock_timestamp() - interval '2 minutes',
      clock_timestamp() + interval '12 hours'
    )
    on conflict on constraint staff_block_admission_request_user_block_key do nothing;
  end loop;
end;
$$;

revoke all on function public.seed_demo_current_block_context() from public, anon, authenticated;
grant execute on function public.seed_demo_current_block_context() to service_role;
