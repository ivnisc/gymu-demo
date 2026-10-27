create function public.seed_demo_personas_v3(p_people jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_person jsonb;
  v_bundle_key text;
  v_bundle private.demo_persona_bundle%rowtype;
  v_bundle_position integer := 0;
  v_program_id smallint;
  v_today date := (now() at time zone 'America/Santiago')::date;
  v_future_date date;
  v_history_date date;
  v_absent_date date;
  v_routine_id uuid;
begin
  if jsonb_typeof(p_people) <> 'array' or jsonb_array_length(p_people) <> 24 then
    raise exception 'exactly twenty-four demo people are required';
  end if;

  perform private.reset_demo_personas();

  for v_person in select value from jsonb_array_elements(p_people)
  loop
    insert into public.app_user (
      user_id, user_name, identity_hmac, role, allowed_time_block_id,
      regulation_accepted_at, theme_preference
    ) values (
      (v_person->>'userId')::uuid,
      v_person->>'userName',
      decode(v_person->>'identityHmac', 'hex'),
      (v_person->>'role')::public.app_role,
      case when v_person->>'role' = 'u_staff' then 7 else null end,
      clock_timestamp() - interval '7 days',
      case when v_person->>'themePreference' = 'light' then 'light' else 'dark' end
    );
    insert into private.user_institutional_identity (user_id, institutional_username)
    values ((v_person->>'userId')::uuid, v_person->>'institutionalUsername');
  end loop;

  for v_bundle_key in select distinct value->>'bundleKey' from jsonb_array_elements(p_people)
  loop
    insert into private.demo_persona_bundle (
      bundle_key, student_user_id, u_staff_user_id, gym_staff_user_id
    ) values (
      v_bundle_key,
      (select (value->>'userId')::uuid from jsonb_array_elements(p_people) where value->>'bundleKey' = v_bundle_key and value->>'role' = 'student'),
      (select (value->>'userId')::uuid from jsonb_array_elements(p_people) where value->>'bundleKey' = v_bundle_key and value->>'role' = 'u_staff'),
      (select (value->>'userId')::uuid from jsonb_array_elements(p_people) where value->>'bundleKey' = v_bundle_key and value->>'role' = 'gym_staff')
    );
  end loop;

  for v_person in select value from jsonb_array_elements(p_people)
  loop
    select academic_program_id into v_program_id
    from private.academic_program
    where is_active
    order by display_order
    offset ((v_person->>'programOffset')::integer % 12)
    limit 1;
    insert into private.user_profile_revision (
      user_id, date_of_birth, reported_sex, height_cm, weight_kg,
      academic_program_id, career_entry_year, recorded_at, recorded_by_user_id
    ) values (
      (v_person->>'userId')::uuid,
      (v_person->>'dateOfBirth')::date,
      (v_person->>'reportedSex')::private.reported_sex,
      (v_person->>'heightCm')::numeric,
      (v_person->>'weightKg')::numeric,
      v_program_id,
      (v_person->>'careerEntryYear')::smallint,
      clock_timestamp() - interval '6 days',
      (v_person->>'userId')::uuid
    );
  end loop;

  select day::date into v_future_date
  from generate_series(v_today + 1, v_today + 8, interval '1 day') as day
  where extract(isodow from day) between 1 and 5
  order by day
  limit 1;

  for v_bundle in select * from private.demo_persona_bundle order by bundle_key
  loop
    v_bundle_position := v_bundle_position + 1;
    select day::date into v_history_date
    from generate_series(v_today - 42, v_today - 1, interval '1 day') as day
    where extract(isodow from day) between 1 and 5
    order by day desc offset v_bundle_position limit 1;
    select day::date into v_absent_date
    from generate_series(v_today - 84, v_today - 1, interval '1 day') as day
    where extract(isodow from day) between 1 and 5
    order by day desc offset v_bundle_position + 10 limit 1;

    insert into public.booking (
      user_id, time_block_id, booking_date, status, booked_at, confirmed_at, present_at
    ) values (
      v_bundle.student_user_id, ((v_bundle_position - 1) % 6 + 1)::smallint, v_history_date,
      'present', v_history_date + time '08:00', v_history_date + time '08:30', v_history_date + time '09:00'
    );
    insert into public.booking (
      user_id, time_block_id, booking_date, status, booked_at, confirmed_at, absent_at
    ) values (
      v_bundle.student_user_id, ((v_bundle_position % 6) + 1)::smallint, v_absent_date,
      'absent', v_absent_date + time '08:00', v_absent_date + time '08:30', v_absent_date + time '10:00'
    );
    insert into public.booking (user_id, time_block_id, booking_date, status, booked_at)
    values (v_bundle.student_user_id, ((v_bundle_position - 1) % 6 + 1)::smallint, v_future_date, 'reserved', clock_timestamp());
    insert into public.booking (user_id, time_block_id, booking_date, status, booked_at)
    values (v_bundle.u_staff_user_id, 7, v_future_date, 'reserved', clock_timestamp());

    insert into private.routine_plan (
      kind, status, title, recipient_user_id, created_by_user_id, updated_by_user_id, assigned_at
    ) values (
      'assignment', 'assigned',
      case when v_bundle_position % 2 = 0 then 'Tren inferior' else 'Tren superior' end,
      v_bundle.student_user_id, v_bundle.gym_staff_user_id, v_bundle.gym_staff_user_id,
      clock_timestamp() - interval '3 days'
    ) returning routine_plan_id into v_routine_id;
    insert into private.routine_plan_exercise (
      routine_plan_id, exercise_key, display_order, total_sets, effective_sets,
      repetitions_min, repetitions_max, load_kg, rir, rest_seconds
    ) values
      (v_routine_id, 'bench-press', 1, 4, 3, 8, 12, 30, 2, 90),
      (v_routine_id, 'seated-row', 2, 3, 3, 10, 12, 25, 2, 75),
      (v_routine_id, 'plank', 3, 3, 3, 20, 30, null, 2, 60);

    insert into private.routine_plan (
      kind, status, title, recipient_user_id, created_by_user_id, updated_by_user_id, assigned_at
    ) values (
      'assignment', 'assigned', 'Movilidad y fuerza', v_bundle.u_staff_user_id,
      v_bundle.gym_staff_user_id, v_bundle.gym_staff_user_id, clock_timestamp() - interval '2 days'
    ) returning routine_plan_id into v_routine_id;
    insert into private.routine_plan_exercise (
      routine_plan_id, exercise_key, display_order, total_sets, effective_sets,
      repetitions_min, repetitions_max, load_kg, rir, rest_seconds
    ) values
      (v_routine_id, 'goblet-squat', 1, 3, 3, 8, 10, 16, 2, 90),
      (v_routine_id, 'cable-pallof-hold', 2, 3, 3, 10, 12, 10, 2, 60);
  end loop;
end;
$$;

revoke all on function public.seed_demo_personas_v3(jsonb) from public, anon, authenticated;
grant execute on function public.seed_demo_personas_v3(jsonb) to service_role;
