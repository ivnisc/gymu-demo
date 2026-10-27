create function public.enrich_demo_persona_history()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bundle private.demo_persona_bundle%rowtype;
  v_position integer := 0;
  v_today date := (clock_timestamp() at time zone 'America/Santiago')::date;
begin
  for v_bundle in select * from private.demo_persona_bundle order by bundle_key
  loop
    v_position := v_position + 1;

    insert into public.booking (
      user_id, time_block_id, booking_date, status, booked_at, confirmed_at, present_at
    )
    select
      v_bundle.student_user_id,
      ((v_position - 1) % 6 + 1)::smallint,
      occurrence.booking_date,
      'present',
      occurrence.booking_date + time '08:00',
      occurrence.booking_date + time '08:30',
      occurrence.booking_date + time '09:00'
    from (
      select day::date as booking_date
      from generate_series(v_today - 49, v_today - 1, interval '1 day') as day
      where extract(isodow from day) = ((v_position - 1) % 5 + 1)
      order by day desc
      limit 6
    ) as occurrence
    on conflict (user_id, time_block_id, booking_date) do nothing;

    insert into public.booking (
      user_id, time_block_id, booking_date, status, booked_at, confirmed_at, present_at
    )
    select
      v_bundle.u_staff_user_id,
      7,
      occurrence.booking_date,
      'present',
      occurrence.booking_date + time '17:15',
      occurrence.booking_date + time '17:30',
      occurrence.booking_date + time '17:35'
    from (
      select day::date as booking_date
      from generate_series(v_today - 42, v_today - 1, interval '1 day') as day
      where extract(isodow from day) = ((v_position % 5) + 1)
      order by day desc
      limit 5
    ) as occurrence
    on conflict (user_id, time_block_id, booking_date) do nothing;
  end loop;
end;
$$;

revoke all on function public.enrich_demo_persona_history() from public, anon, authenticated;
grant execute on function public.enrich_demo_persona_history() to service_role;
