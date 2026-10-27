-- Datos y sesiones efímeras exclusivos de la rama demo. Ninguna función se
-- concede al navegador: los Route Handlers usan service_role y un cookie opaco.
create table private.demo_persona_bundle (
  bundle_key text primary key check (bundle_key ~ '^demo-[0-9]{2}$'),
  student_user_id uuid not null references public.app_user(user_id) on delete restrict,
  u_staff_user_id uuid not null references public.app_user(user_id) on delete restrict,
  gym_staff_user_id uuid not null references public.app_user(user_id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (student_user_id),
  unique (u_staff_user_id),
  unique (gym_staff_user_id)
);

create table private.demo_persona_lease (
  demo_persona_lease_id uuid primary key default gen_random_uuid(),
  bundle_key text not null references private.demo_persona_bundle(bundle_key) on delete restrict,
  token_hash bytea not null unique check (octet_length(token_hash) = 32),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (expires_at > created_at),
  unique (bundle_key)
);

create index demo_persona_lease_expires_at_idx
  on private.demo_persona_lease (expires_at);

create function private.reset_demo_personas()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_ids uuid[];
  v_routine_ids uuid[];
begin
  select array_agg(identity.user_id)
  into v_user_ids
  from private.user_institutional_identity as identity
  where identity.institutional_username like 'demo.%';

  if coalesce(array_length(v_user_ids, 1), 0) = 0 then
    delete from private.demo_persona_lease;
    delete from private.demo_persona_bundle;
    return;
  end if;

  select array_agg(plan.routine_plan_id)
  into v_routine_ids
  from private.routine_plan as plan
  where plan.created_by_user_id = any(v_user_ids)
     or plan.updated_by_user_id = any(v_user_ids)
     or plan.recipient_user_id = any(v_user_ids);

  delete from private.check_in_qr_token
  where user_id = any(v_user_ids) or scanned_by_user_id = any(v_user_ids);

  delete from private.staff_block_admission_request where user_id = any(v_user_ids);
  delete from public.disciplinary_action where user_id = any(v_user_ids);
  delete from public.user_warning where user_id = any(v_user_ids) or created_by_user_id = any(v_user_ids);

  delete from public.booking_event
  where booking_id in (select booking_id from public.booking where user_id = any(v_user_ids))
     or actor_user_id = any(v_user_ids);
  delete from public.booking where user_id = any(v_user_ids);

  if coalesce(array_length(v_routine_ids, 1), 0) > 0 then
    delete from private.routine_plan_exercise where routine_plan_id = any(v_routine_ids);
    delete from private.routine_plan where routine_plan_id = any(v_routine_ids);
  end if;

  delete from private.user_profile_revision where user_id = any(v_user_ids);
  delete from private.demo_persona_lease;
  delete from private.demo_persona_bundle;
  delete from private.user_institutional_identity where user_id = any(v_user_ids);
  delete from public.app_user where user_id = any(v_user_ids);
end;
$$;

create function public.seed_demo_personas(p_people jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_person jsonb;
  v_bundle private.demo_persona_bundle%rowtype;
  v_bundle_position integer := 0;
  v_today date := (now() at time zone 'America/Santiago')::date;
  v_future_date date;
  v_history_date date;
  v_absent_date date;
  v_program_id smallint;
  v_routine_id uuid;
begin
  if jsonb_typeof(p_people) <> 'array' or jsonb_array_length(p_people) <> 24 then
    raise exception 'exactly twenty-four demo people are required';
  end if;

  perform private.reset_demo_personas();

  for v_person in select value from jsonb_array_elements(p_people)
  loop
    insert into public.app_user (
      user_id,
      user_name,
      identity_hmac,
      role,
      allowed_time_block_id,
      regulation_accepted_at,
      theme_preference
    )
    values (
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

  insert into private.demo_persona_bundle (
    bundle_key,
    student_user_id,
    u_staff_user_id,
    gym_staff_user_id
  )
  select
    person.value->>'bundleKey',
    max((person.value->>'userId')::uuid) filter (where person.value->>'role' = 'student'),
    max((person.value->>'userId')::uuid) filter (where person.value->>'role' = 'u_staff'),
    max((person.value->>'userId')::uuid) filter (where person.value->>'role' = 'gym_staff')
  from jsonb_array_elements(p_people) as person(value)
  group by person.value->>'bundleKey';

  for v_person in select value from jsonb_array_elements(p_people)
  loop
    select academic_program_id
    into v_program_id
    from private.academic_program
    where is_active
    order by display_order
    offset ((v_person->>'programOffset')::integer % 12)
    limit 1;

    insert into private.user_profile_revision (
      user_id,
      date_of_birth,
      reported_sex,
      height_cm,
      weight_kg,
      academic_program_id,
      career_entry_year,
      recorded_at,
      recorded_by_user_id
    )
    values (
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

  for v_bundle in select * from private.demo_persona_bundle order by bundle_key
  loop
    v_bundle_position := v_bundle_position + 1;

    select day::date into v_future_date
    from generate_series(v_today + 1, v_today + 8, interval '1 day') as day
    where extract(isodow from day) between 1 and 5
    order by day
    limit 1;

    select day::date into v_history_date
    from generate_series(v_today - 42, v_today - 1, interval '1 day') as day
    where extract(isodow from day) between 1 and 5
    order by day desc
    offset v_bundle_position
    limit 1;

    select day::date into v_absent_date
    from generate_series(v_today - 84, v_today - 1, interval '1 day') as day
    where extract(isodow from day) between 1 and 5
    order by day desc
    offset v_bundle_position + 10
    limit 1;

    insert into public.booking (
      user_id, time_block_id, booking_date, status, booked_at, confirmed_at, present_at
    )
    values (
      v_bundle.student_user_id,
      ((v_bundle_position - 1) % 6 + 1)::smallint,
      v_history_date,
      'present',
      v_history_date + time '08:00',
      v_history_date + time '08:30',
      v_history_date + time '09:00'
    );

    insert into public.booking (
      user_id, time_block_id, booking_date, status, booked_at, confirmed_at, absent_at
    )
    values (
      v_bundle.student_user_id,
      ((v_bundle_position % 6) + 1)::smallint,
      v_absent_date,
      'absent',
      v_absent_date + time '08:00',
      v_absent_date + time '08:30',
      v_absent_date + time '10:00'
    );

    insert into public.booking (user_id, time_block_id, booking_date, status, booked_at)
    values (
      v_bundle.student_user_id,
      ((v_bundle_position - 1) % 6 + 1)::smallint,
      v_future_date,
      'reserved',
      clock_timestamp()
    );

    insert into public.booking (user_id, time_block_id, booking_date, status, booked_at)
    values (v_bundle.u_staff_user_id, 7, v_future_date, 'reserved', clock_timestamp());

    insert into private.routine_plan (
      kind, status, title, recipient_user_id, created_by_user_id, updated_by_user_id, assigned_at
    )
    values (
      'assignment',
      'assigned',
      case when v_bundle_position % 2 = 0 then 'Tren inferior' else 'Tren superior' end,
      v_bundle.student_user_id,
      v_bundle.gym_staff_user_id,
      v_bundle.gym_staff_user_id,
      clock_timestamp() - interval '3 days'
    )
    returning routine_plan_id into v_routine_id;

    insert into private.routine_plan_exercise (
      routine_plan_id, exercise_key, display_order, total_sets, effective_sets,
      repetitions_min, repetitions_max, load_kg, rir, rest_seconds
    )
    values
      (v_routine_id, 'bench-press', 1, 4, 3, 8, 12, 30, 2, 90),
      (v_routine_id, 'seated-row', 2, 3, 3, 10, 12, 25, 2, 75),
      (v_routine_id, 'plank', 3, 3, 3, 20, 30, null, 2, 60);

    insert into private.routine_plan (
      kind, status, title, recipient_user_id, created_by_user_id, updated_by_user_id, assigned_at
    )
    values (
      'assignment',
      'assigned',
      'Movilidad y fuerza',
      v_bundle.u_staff_user_id,
      v_bundle.gym_staff_user_id,
      v_bundle.gym_staff_user_id,
      clock_timestamp() - interval '2 days'
    )
    returning routine_plan_id into v_routine_id;

    insert into private.routine_plan_exercise (
      routine_plan_id, exercise_key, display_order, total_sets, effective_sets,
      repetitions_min, repetitions_max, load_kg, rir, rest_seconds
    )
    values
      (v_routine_id, 'goblet-squat', 1, 3, 3, 8, 10, 16, 2, 90),
      (v_routine_id, 'cable-pallof-hold', 2, 3, 3, 10, 12, 10, 2, 60);
  end loop;
end;
$$;

create function public.reset_demo_personas()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.reset_demo_personas();
end;
$$;

create function public.claim_demo_persona(p_token_hash bytea)
returns table (
  bundle_key text,
  student_user_id uuid,
  u_staff_user_id uuid,
  gym_staff_user_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bundle private.demo_persona_bundle%rowtype;
begin
  if octet_length(p_token_hash) <> 32 then
    raise exception 'demo lease token is invalid';
  end if;

  delete from private.demo_persona_lease where expires_at <= clock_timestamp();

  return query
  select bundle.bundle_key, bundle.student_user_id, bundle.u_staff_user_id, bundle.gym_staff_user_id
  from private.demo_persona_lease as lease
  join private.demo_persona_bundle as bundle on bundle.bundle_key = lease.bundle_key
  where lease.token_hash = p_token_hash;

  if found then
    return;
  end if;

  select * into v_bundle
  from private.demo_persona_bundle as bundle
  where not exists (
    select 1
    from private.demo_persona_lease as lease
    where lease.bundle_key = bundle.bundle_key
      and lease.expires_at > clock_timestamp()
  )
  order by bundle.bundle_key
  for update skip locked
  limit 1;

  if not found then
    raise exception 'all demo personas are currently in use';
  end if;

  insert into private.demo_persona_lease (bundle_key, token_hash, expires_at)
  values (v_bundle.bundle_key, p_token_hash, clock_timestamp() + interval '8 hours');

  return query
  select v_bundle.bundle_key, v_bundle.student_user_id, v_bundle.u_staff_user_id, v_bundle.gym_staff_user_id;
end;
$$;

create function public.get_demo_persona_bundle(p_token_hash bytea)
returns table (
  bundle_key text,
  student_user_id uuid,
  u_staff_user_id uuid,
  gym_staff_user_id uuid
)
language sql
security definer
set search_path = ''
stable
as $$
  select bundle.bundle_key, bundle.student_user_id, bundle.u_staff_user_id, bundle.gym_staff_user_id
  from private.demo_persona_lease as lease
  join private.demo_persona_bundle as bundle on bundle.bundle_key = lease.bundle_key
  where lease.token_hash = p_token_hash
    and lease.expires_at > clock_timestamp()
$$;

revoke all on function private.reset_demo_personas() from public, anon, authenticated;
revoke all on function public.seed_demo_personas(jsonb) from public, anon, authenticated;
revoke all on function public.reset_demo_personas() from public, anon, authenticated;
revoke all on function public.claim_demo_persona(bytea) from public, anon, authenticated;
revoke all on function public.get_demo_persona_bundle(bytea) from public, anon, authenticated;

grant execute on function public.seed_demo_personas(jsonb) to service_role;
grant execute on function public.reset_demo_personas() to service_role;
grant execute on function public.claim_demo_persona(bytea) to service_role;
grant execute on function public.get_demo_persona_bundle(bytea) to service_role;
