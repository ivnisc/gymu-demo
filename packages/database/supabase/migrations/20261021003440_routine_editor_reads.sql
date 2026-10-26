-- Las escrituras v2 ya permitían crear, asignar y modificar rutinas, pero no
-- existía una lectura para que otro integrante del equipo continuara un
-- borrador o revisara una asignación. Ambas RPC conservan la autorización en
-- la base y quedan disponibles solo a través del backend con service_role.

-- Evita que el backend tenga que enviar un argumento UUID nulo al crear el
-- primer borrador. Supabase genera tipos TypeScript más precisos para esta
-- firma que para el parámetro anulable de la función de actualización.
create function public.create_routine_template_draft(
  p_actor_user_id uuid,
  p_title text,
  p_exercises jsonb
)
returns private.routine_plan
language sql
security definer
set search_path = ''
as $$
  select public.save_routine_template_draft(
    p_actor_user_id,
    null,
    p_title,
    p_exercises
  );
$$;

create function public.list_routine_editor_plans(
  p_actor_user_id uuid,
  p_query text default null
)
returns table (
  routine_plan_id uuid,
  kind private.routine_plan_kind,
  status private.routine_plan_status,
  title text,
  recipient_user_id uuid,
  recipient_user_name text,
  recipient_institutional_username text,
  created_by_user_name text,
  updated_by_user_name text,
  assigned_at timestamptz,
  updated_at timestamptz,
  exercise_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_query text := nullif(lower(trim(p_query)), '');
  v_pattern text;
begin
  perform private.require_current_routine_editor(p_actor_user_id);

  if v_query is not null and char_length(v_query) not between 2 and 120 then
    raise exception 'routine search query must contain between two and 120 characters';
  end if;

  v_pattern := case
    when v_query is null then null
    else '%' || private.escape_like_literal(v_query) || '%'
  end;

  return query
  select
    plan.routine_plan_id,
    plan.kind,
    plan.status,
    plan.title,
    plan.recipient_user_id,
    recipient.user_name,
    recipient_identity.institutional_username,
    creator.user_name,
    updater.user_name,
    plan.assigned_at,
    plan.updated_at,
    count(item.routine_plan_exercise_id)::integer
  from private.routine_plan as plan
  join public.app_user as creator on creator.user_id = plan.created_by_user_id
  join public.app_user as updater on updater.user_id = plan.updated_by_user_id
  left join public.app_user as recipient on recipient.user_id = plan.recipient_user_id
  left join private.user_institutional_identity as recipient_identity
    on recipient_identity.user_id = plan.recipient_user_id
  left join private.routine_plan_exercise as item on item.routine_plan_id = plan.routine_plan_id
  where plan.status in ('draft', 'assigned')
    and (
      v_pattern is null
      or lower(plan.title) like v_pattern escape E'\\'
      or lower(coalesce(recipient.user_name, '')) like v_pattern escape E'\\'
      or lower(coalesce(recipient_identity.institutional_username, '')) like v_pattern escape E'\\'
    )
  group by
    plan.routine_plan_id,
    plan.kind,
    plan.status,
    plan.title,
    plan.recipient_user_id,
    recipient.user_name,
    recipient_identity.institutional_username,
    creator.user_name,
    updater.user_name,
    plan.assigned_at,
    plan.updated_at
  order by plan.updated_at desc, plan.routine_plan_id
  limit 50;
end;
$$;

create function public.get_routine_editor_plan(
  p_actor_user_id uuid,
  p_routine_plan_id uuid
)
returns table (
  routine_plan_id uuid,
  kind private.routine_plan_kind,
  status private.routine_plan_status,
  title text,
  recipient_user_id uuid,
  recipient_user_name text,
  recipient_institutional_username text,
  created_by_user_name text,
  updated_by_user_name text,
  assigned_at timestamptz,
  updated_at timestamptz,
  exercises jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_routine_editor(p_actor_user_id);

  return query
  select
    plan.routine_plan_id,
    plan.kind,
    plan.status,
    plan.title,
    plan.recipient_user_id,
    recipient.user_name,
    recipient_identity.institutional_username,
    creator.user_name,
    updater.user_name,
    plan.assigned_at,
    plan.updated_at,
    coalesce(jsonb_agg(jsonb_build_object(
      'exerciseKey', item.exercise_key,
      'exerciseName', catalog.exercise_name,
      'muscleGroup', catalog.muscle_group,
      'equipment', catalog.equipment,
      'assetPath', catalog.asset_path,
      'displayOrder', item.display_order,
      'totalSets', item.total_sets,
      'effectiveSets', item.effective_sets,
      'repetitionsMin', item.repetitions_min,
      'repetitionsMax', item.repetitions_max,
      'loadKg', item.load_kg,
      'rir', item.rir,
      'restSeconds', item.rest_seconds,
      'observations', item.observations
    ) order by item.display_order) filter (
      where item.routine_plan_exercise_id is not null
    ), '[]'::jsonb)
  from private.routine_plan as plan
  join public.app_user as creator on creator.user_id = plan.created_by_user_id
  join public.app_user as updater on updater.user_id = plan.updated_by_user_id
  left join public.app_user as recipient on recipient.user_id = plan.recipient_user_id
  left join private.user_institutional_identity as recipient_identity
    on recipient_identity.user_id = plan.recipient_user_id
  left join private.routine_plan_exercise as item on item.routine_plan_id = plan.routine_plan_id
  left join private.exercise_catalog as catalog on catalog.exercise_key = item.exercise_key
  where plan.routine_plan_id = p_routine_plan_id
    and plan.status in ('draft', 'assigned')
  group by
    plan.routine_plan_id,
    plan.kind,
    plan.status,
    plan.title,
    plan.recipient_user_id,
    recipient.user_name,
    recipient_identity.institutional_username,
    creator.user_name,
    updater.user_name,
    plan.assigned_at,
    plan.updated_at;
end;
$$;

revoke all on function public.list_routine_editor_plans(uuid, text) from public, anon, authenticated;
revoke all on function public.get_routine_editor_plan(uuid, uuid) from public, anon, authenticated;
revoke all on function public.create_routine_template_draft(uuid, text, jsonb) from public, anon, authenticated;

grant execute on function public.list_routine_editor_plans(uuid, text) to service_role;
grant execute on function public.get_routine_editor_plan(uuid, uuid) to service_role;
grant execute on function public.create_routine_template_draft(uuid, text, jsonb) to service_role;
