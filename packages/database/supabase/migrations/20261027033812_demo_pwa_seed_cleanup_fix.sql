create or replace function private.reset_demo_personas()
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
    delete from private.demo_persona_lease where true;
    delete from private.demo_persona_bundle where true;
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
  delete from private.demo_persona_lease where true;
  delete from private.demo_persona_bundle where true;
  delete from private.user_institutional_identity where user_id = any(v_user_ids);
  delete from public.app_user where user_id = any(v_user_ids);
end;
$$;
