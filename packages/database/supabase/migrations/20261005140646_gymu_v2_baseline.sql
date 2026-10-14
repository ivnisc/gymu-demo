-- GYMU baseline v2. Generated mechanically from reviewed drafts.
-- Apply only to a new, empty Supabase project.


-- ============================================================================
-- Source: docs/database/v2-schema-draft.sql
-- ============================================================================

-- Draft de la fase estructural de la baseline v2.
-- No ejecutar directamente: la migración baseline ensambla este archivo con
-- los drafts de autoridad, operaciones, Realtime y cron en orden estricto.

create extension if not exists pgcrypto;

create schema private;
revoke all on schema private from public;

create type public.app_role as enum ('student', 'u_staff', 'gym_staff', 'admin');
create type public.booking_status as enum ('reserved', 'confirmed', 'present', 'absent', 'cancelled');
create type public.booking_admission_source as enum (
  'self_service',
  'staff_exception',
  'staff_overcapacity'
);
create type public.warning_type as enum ('missed_confirmation', 'missed_qr', 'unbooked_attendance');
create type public.booking_event_type as enum (
  'reserved',
  'reactivated',
  'cancelled',
  'confirmed',
  'expired_to_absent',
  'qr_check_in',
  'visual_check_in',
  'visual_absence',
  'late_qr_authorized',
  'attendance_finalized'
);
create type public.discipline_violation_type as enum (
  'absent',
  'missed_confirmation',
  'missed_qr',
  'unbooked_attendance'
);
create type public.discipline_action_kind as enum ('notice', 'disable');

create type private.reported_sex as enum (
  'masculino',
  'femenino',
  'otro',
  'prefiero_no_decir'
);
create type private.catalog_response_kind as enum (
  'boolean',
  'integer',
  'decimal',
  'date',
  'short_text',
  'single_choice',
  'derived'
);
create type private.research_campaign_status as enum (
  'draft',
  'scheduled',
  'active',
  'closed',
  'cancelled'
);
create type private.routine_plan_kind as enum ('template', 'assignment');
create type private.routine_plan_status as enum ('draft', 'assigned', 'archived');
create type public.news_item_status as enum ('draft', 'published', 'withdrawn');

create table public.time_block (
  time_block_id smallint primary key,
  time_block_t0 time not null,
  time_block_t1 time not null,
  display_order smallint not null unique,
  check (time_block_t0 < time_block_t1)
);

create table public.app_user (
  user_id uuid primary key references auth.users(id) on delete restrict,
  user_name text not null check (char_length(trim(user_name)) between 1 and 120),
  identity_hmac bytea not null unique check (octet_length(identity_hmac) = 32),
  role public.app_role not null default 'student',
  allowed_time_block_id smallint references public.time_block(time_block_id),
  regulation_accepted_at timestamptz,
  theme_preference text not null default 'dark' check (theme_preference in ('dark', 'light')),
  disabled_at timestamptz,
  disabled_reason text check (
    disabled_reason is null or char_length(trim(disabled_reason)) between 3 and 240
  ),
  disabled_by_user_id uuid references public.app_user(user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (role = 'u_staff' and allowed_time_block_id = 7)
    or (role <> 'u_staff' and allowed_time_block_id is null)
  )
);

create table public.system_settings (
  singleton boolean primary key default true check (singleton),
  standard_capacity smallint not null default 15 check (standard_capacity > 0),
  overcapacity_max_above smallint not null default 4 check (overcapacity_max_above >= 0),
  n_sessions_per_day smallint not null default 1 check (n_sessions_per_day > 0),
  statistics_history_start_date date,
  updated_at timestamptz not null default now(),
  updated_by_user_id uuid references public.app_user(user_id) on delete restrict
);

create table private.user_institutional_identity (
  user_id uuid primary key references public.app_user(user_id) on delete restrict,
  institutional_username text not null unique,
  last_verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    char_length(institutional_username) between 1 and 120
    and institutional_username = lower(institutional_username)
    and institutional_username !~ '[@[:space:]]'
  )
);

create table private.academic_program (
  academic_program_id smallint generated always as identity primary key,
  program_name text not null unique check (char_length(trim(program_name)) between 3 and 160),
  is_active boolean not null default true,
  display_order smallint not null unique check (display_order > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table private.user_profile_revision (
  user_profile_revision_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_user(user_id) on delete restrict,
  date_of_birth date,
  reported_sex private.reported_sex,
  height_cm numeric(5, 2),
  weight_kg numeric(5, 2),
  academic_program_id smallint references private.academic_program(academic_program_id) on delete restrict,
  career_entry_year smallint,
  recorded_at timestamptz not null default clock_timestamp(),
  recorded_by_user_id uuid not null references public.app_user(user_id) on delete restrict,
  check (date_of_birth is null or date_of_birth < recorded_at::date),
  check (height_cm is null or height_cm between 120 and 230),
  check (weight_kg is null or weight_kg between 35 and 300),
  check (career_entry_year is null or career_entry_year between 2017 and 2100)
);

create table public.booking (
  booking_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_user(user_id) on delete restrict,
  time_block_id smallint not null references public.time_block(time_block_id) on delete restrict,
  booking_date date not null,
  status public.booking_status not null default 'reserved',
  is_overcapacity boolean not null default false,
  admission_source public.booking_admission_source not null default 'self_service',
  booked_at timestamptz not null default now(),
  confirmed_at timestamptz,
  late_qr_authorized_at timestamptz,
  present_at timestamptz,
  absent_at timestamptz,
  cancelled_at timestamptz,
  qr_scanned_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, time_block_id, booking_date),
  check (extract(isodow from booking_date) between 1 and 5),
  check (
    (is_overcapacity and admission_source = 'staff_overcapacity')
    or (not is_overcapacity and admission_source <> 'staff_overcapacity')
  ),
  check (late_qr_authorized_at is null or confirmed_at is not null)
);

create table public.booking_event (
  booking_event_id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.booking(booking_id) on delete restrict,
  event_type public.booking_event_type not null,
  actor_user_id uuid references public.app_user(user_id) on delete restrict,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

create table public.user_warning (
  user_warning_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_user(user_id) on delete restrict,
  booking_id uuid references public.booking(booking_id) on delete restrict,
  warning_type public.warning_type not null,
  created_by_user_id uuid references public.app_user(user_id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.time_block_closure (
  time_block_closure_id uuid primary key default gen_random_uuid(),
  closure_date date not null,
  time_block_id smallint not null references public.time_block(time_block_id) on delete restrict,
  reason text not null check (char_length(trim(reason)) between 3 and 240),
  created_at timestamptz not null default now(),
  created_by_user_id uuid not null references public.app_user(user_id) on delete restrict,
  unique (closure_date, time_block_id),
  check (extract(isodow from closure_date) between 1 and 5)
);

create table public.weekly_time_block_closure (
  weekly_time_block_closure_id uuid primary key default gen_random_uuid(),
  iso_weekday smallint not null check (iso_weekday between 1 and 5),
  time_block_id smallint not null references public.time_block(time_block_id) on delete restrict,
  reason text not null check (char_length(trim(reason)) between 3 and 240),
  created_at timestamptz not null default now(),
  created_by_user_id uuid not null references public.app_user(user_id) on delete restrict,
  unique (iso_weekday, time_block_id)
);

create table public.full_day_closure_period (
  full_day_closure_period_id uuid primary key default gen_random_uuid(),
  closure_start_date date not null,
  closure_end_date date not null,
  reason text not null check (char_length(trim(reason)) between 3 and 240),
  created_at timestamptz not null default now(),
  created_by_user_id uuid not null references public.app_user(user_id) on delete restrict,
  check (closure_start_date <= closure_end_date),
  exclude using gist (daterange(closure_start_date, closure_end_date, '[]') with &&)
);

create table public.discipline_rule (
  discipline_rule_id uuid primary key default gen_random_uuid(),
  violation_type public.discipline_violation_type not null,
  occurrence_threshold smallint not null check (occurrence_threshold > 0),
  window_days smallint not null default 30 check (window_days between 1 and 365),
  action_kind public.discipline_action_kind not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by_user_id uuid not null references public.app_user(user_id) on delete restrict,
  updated_by_user_id uuid not null references public.app_user(user_id) on delete restrict,
  unique (violation_type, occurrence_threshold, window_days)
);

create table public.disciplinary_action (
  disciplinary_action_id uuid primary key default gen_random_uuid(),
  discipline_rule_id uuid not null references public.discipline_rule(discipline_rule_id) on delete restrict,
  user_id uuid not null references public.app_user(user_id) on delete restrict,
  source_event_id uuid not null,
  violation_type public.discipline_violation_type not null,
  action_kind public.discipline_action_kind not null,
  occurrence_count smallint not null check (occurrence_count > 0),
  applied_at timestamptz not null default now(),
  unique (discipline_rule_id, source_event_id)
);

create table private.check_in_qr_token (
  check_in_qr_token_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_user(user_id) on delete restrict,
  booking_date date not null,
  time_block_id smallint not null references public.time_block(time_block_id) on delete restrict,
  token_hash bytea not null unique check (octet_length(token_hash) = 32),
  expires_at timestamptz not null,
  scanned_at timestamptz,
  scanned_by_user_id uuid references public.app_user(user_id) on delete restrict,
  revoked_at timestamptz,
  scan_result text check (
    scan_result is null
    or scan_result in ('checked_in', 'already_present', 'no_current_booking', 'session_ended')
  ),
  created_at timestamptz not null default now(),
  check (expires_at > created_at),
  check (
    (scanned_at is null and scanned_by_user_id is null and scan_result is null)
    or (scanned_at is not null and scanned_by_user_id is not null and scan_result is not null)
  ),
  check (revoked_at is null or revoked_at >= created_at)
);

create table private.staff_block_admission_request (
  staff_block_admission_request_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_user(user_id) on delete restrict,
  booking_date date not null,
  time_block_id smallint not null references public.time_block(time_block_id) on delete restrict,
  requested_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check (expires_at > requested_at),
  constraint staff_block_admission_request_user_block_key
    unique (user_id, booking_date, time_block_id)
);

create sequence private.research_question_display_order_seq as smallint;

create table private.research_question_catalog (
  question_key text primary key check (question_key ~ '^[a-z][a-z0-9_]{2,99}$'),
  source_code text not null unique check (source_code ~ '^[A-Z][0-9]+(_[0-9]+|c)?$'),
  section_key text not null check (section_key ~ '^[a-z][a-z0-9_]{2,99}$'),
  response_kind private.catalog_response_kind not null,
  prompt text not null check (char_length(trim(prompt)) between 3 and 500),
  help_text text check (help_text is null or char_length(trim(help_text)) between 3 and 800),
  validation jsonb not null default '{}'::jsonb check (jsonb_typeof(validation) = 'object'),
  is_campaign_selectable boolean not null default false,
  sets_preventive_attention boolean not null default false,
  is_derived boolean not null default false,
  formula_description text check (
    formula_description is null or char_length(trim(formula_description)) between 3 and 500
  ),
  display_order smallint not null unique
    default nextval('private.research_question_display_order_seq'::regclass)
    check (display_order > 0),
  source_revision smallint not null default 1 check (source_revision > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (is_derived and response_kind = 'derived' and formula_description is not null
      and is_campaign_selectable = false and sets_preventive_attention = false)
    or (not is_derived and response_kind <> 'derived' and formula_description is null)
  )
);

create table private.research_question_option (
  question_key text not null references private.research_question_catalog(question_key) on delete restrict,
  option_key text not null check (option_key ~ '^[a-z][a-z0-9_]{1,79}$'),
  label text not null check (char_length(trim(label)) between 1 and 240),
  display_order smallint not null check (display_order > 0),
  primary key (question_key, option_key),
  unique (question_key, display_order)
);

create table private.research_campaign (
  research_campaign_id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) between 3 and 160),
  purpose text not null check (char_length(trim(purpose)) between 10 and 2000),
  data_use_notice text not null check (char_length(trim(data_use_notice)) between 10 and 3000),
  consent_text text not null check (char_length(trim(consent_text)) between 10 and 5000),
  status private.research_campaign_status not null default 'draft',
  opens_at timestamptz,
  closes_at timestamptz,
  created_by_user_id uuid not null references public.app_user(user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (closes_at is null or opens_at is not null and closes_at > opens_at),
  check ((status = 'draft' and opens_at is null and closes_at is null) or status <> 'draft')
);

create table private.research_campaign_target_role (
  research_campaign_id uuid not null references private.research_campaign(research_campaign_id) on delete restrict,
  target_role public.app_role not null check (target_role in ('student', 'u_staff')),
  primary key (research_campaign_id, target_role)
);

create table private.research_campaign_question (
  research_campaign_id uuid not null references private.research_campaign(research_campaign_id) on delete restrict,
  question_key text not null references private.research_question_catalog(question_key) on delete restrict,
  is_required boolean not null default false,
  display_order smallint not null check (display_order > 0),
  question_snapshot jsonb not null check (
    jsonb_typeof(question_snapshot) = 'object'
    and question_snapshot ?& array[
      'sourceCode',
      'sectionKey',
      'responseKind',
      'prompt',
      'validation',
      'setsPreventiveAttention',
      'options'
    ]
  ),
  primary key (research_campaign_id, question_key),
  unique (research_campaign_id, display_order)
);

create table private.research_campaign_submission (
  research_campaign_submission_id uuid primary key default gen_random_uuid(),
  research_campaign_id uuid not null references private.research_campaign(research_campaign_id) on delete restrict,
  user_id uuid not null references public.app_user(user_id) on delete restrict,
  consented_at timestamptz not null,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (research_campaign_id, user_id),
  check (submitted_at is null or submitted_at >= consented_at)
);

create table private.research_campaign_response (
  research_campaign_submission_id uuid not null references private.research_campaign_submission(research_campaign_submission_id) on delete restrict,
  question_key text not null references private.research_question_catalog(question_key) on delete restrict,
  boolean_value boolean,
  integer_value integer,
  decimal_value numeric(10, 2),
  date_value date,
  text_value text check (text_value is null or char_length(trim(text_value)) between 1 and 2000),
  option_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (research_campaign_submission_id, question_key),
  check (num_nonnulls(boolean_value, integer_value, decimal_value, date_value, text_value, option_key) = 1)
);

create table private.exercise_catalog (
  exercise_key text primary key check (exercise_key ~ '^[a-z][a-z0-9_]{2,99}$'),
  exercise_name text not null unique check (char_length(trim(exercise_name)) between 3 and 120),
  muscle_group text not null check (char_length(trim(muscle_group)) between 3 and 80),
  equipment text not null check (char_length(trim(equipment)) between 3 and 80),
  asset_path text not null unique check (char_length(trim(asset_path)) between 3 and 300),
  is_active boolean not null default true,
  display_order smallint not null unique check (display_order > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table private.routine_plan (
  routine_plan_id uuid primary key default gen_random_uuid(),
  kind private.routine_plan_kind not null,
  status private.routine_plan_status not null default 'draft',
  title text not null check (char_length(trim(title)) between 3 and 160),
  recipient_user_id uuid references public.app_user(user_id) on delete restrict,
  source_template_id uuid references private.routine_plan(routine_plan_id) on delete restrict,
  created_by_user_id uuid not null references public.app_user(user_id) on delete restrict,
  updated_by_user_id uuid not null references public.app_user(user_id) on delete restrict,
  assigned_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (kind = 'template'
      and recipient_user_id is null
      and source_template_id is null
      and assigned_at is null
      and status in ('draft', 'archived'))
    or (kind = 'assignment'
      and recipient_user_id is not null
      and ((status = 'draft' and assigned_at is null)
        or (status in ('assigned', 'archived') and assigned_at is not null)))
  ),
  check (source_template_id is null or kind = 'assignment')
);

create table private.routine_plan_exercise (
  routine_plan_exercise_id uuid primary key default gen_random_uuid(),
  routine_plan_id uuid not null references private.routine_plan(routine_plan_id) on delete restrict,
  exercise_key text not null references private.exercise_catalog(exercise_key) on delete restrict,
  display_order smallint not null check (display_order > 0),
  total_sets smallint not null check (total_sets between 1 and 5),
  effective_sets smallint not null check (effective_sets between 0 and 5 and effective_sets <= total_sets),
  repetitions_min smallint not null check (repetitions_min between 1 and 20),
  repetitions_max smallint not null check (repetitions_max between 1 and 20 and repetitions_max >= repetitions_min),
  load_kg numeric(5, 2) check (load_kg between 0.5 and 150),
  rir smallint check (rir between 0 and 5),
  rest_seconds smallint check (rest_seconds between 1 and 360),
  observations text check (observations is null or char_length(trim(observations)) between 1 and 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (routine_plan_id, display_order),
  unique (routine_plan_id, exercise_key)
);

create table public.news_item (
  news_item_id uuid primary key default gen_random_uuid(),
  caption text not null check (char_length(trim(caption)) between 3 and 500),
  storage_path text not null unique check (char_length(trim(storage_path)) between 3 and 300),
  status public.news_item_status not null default 'draft',
  published_at timestamptz,
  withdrawn_at timestamptz,
  created_by_user_id uuid not null references public.app_user(user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'published') = (published_at is not null)),
  check (withdrawn_at is null or published_at is not null and withdrawn_at >= published_at)
);

create index user_institutional_identity_username_prefix_idx
  on private.user_institutional_identity (institutional_username text_pattern_ops);
-- Las búsquedas operativas también deben resolver cuentas creadas por un
-- proveedor futuro que no entregue un alias institucional utilizable. El GIN
-- permite buscar por nombre o apellido, no solo por el primer término.
create index app_user_name_token_search_idx
  on public.app_user using gin (to_tsvector('simple', user_name));
create index user_profile_revision_user_recorded_idx
  on private.user_profile_revision (user_id, recorded_at desc);
create index booking_block_status_idx
  on public.booking (booking_date, time_block_id, status);
-- Los jobs de mantenimiento solo inspeccionan estados transitorios. Índices
-- parciales evitan recorrer el historial de presentes, ausentes y canceladas.
create index booking_reserved_maintenance_idx
  on public.booking (booking_date, time_block_id)
  where status = 'reserved';
create index booking_confirmed_maintenance_idx
  on public.booking (booking_date, time_block_id)
  where status = 'confirmed';
create index booking_user_history_idx
  on public.booking (user_id, booking_date desc);
create index booking_active_standard_capacity_idx
  on public.booking (booking_date, time_block_id)
  where status in ('reserved', 'confirmed', 'present') and is_overcapacity = false;
create index booking_active_overcapacity_idx
  on public.booking (booking_date, time_block_id)
  where status in ('reserved', 'confirmed', 'present') and is_overcapacity = true;
create index booking_event_booking_created_idx
  on public.booking_event (booking_id, created_at desc);
create index user_warning_user_created_idx
  on public.user_warning (user_id, created_at desc);
create index full_day_closure_period_created_by_user_idx
  on public.full_day_closure_period (created_by_user_id);
create index discipline_rule_active_violation_idx
  on public.discipline_rule (violation_type, occurrence_threshold)
  where enabled;
create index disciplinary_action_user_history_idx
  on public.disciplinary_action (user_id, applied_at desc);
create unique index user_warning_booking_type_once_idx
  on public.user_warning (booking_id, warning_type)
  where booking_id is not null;
create index check_in_qr_token_active_idx
  on private.check_in_qr_token (user_id, booking_date, time_block_id, expires_at)
  where scanned_at is null and revoked_at is null;
create index staff_block_admission_request_window_idx
  on private.staff_block_admission_request (booking_date, time_block_id, expires_at);
create index staff_block_admission_request_expiry_idx
  on private.staff_block_admission_request (expires_at);
create index research_campaign_status_idx
  on private.research_campaign (status, opens_at, closes_at);
create index research_campaign_submission_user_idx
  on private.research_campaign_submission (user_id, research_campaign_id);
create index routine_plan_recipient_idx
  on private.routine_plan (recipient_user_id, assigned_at desc)
  where kind = 'assignment';
create index news_item_feed_idx
  on public.news_item (published_at desc)
  where status = 'published' and withdrawn_at is null;

insert into public.time_block (time_block_id, time_block_t0, time_block_t1, display_order)
values
  (1, '08:50', '09:40', 1),
  (2, '09:40', '11:05', 2),
  (3, '11:05', '12:15', 3),
  (4, '12:15', '13:40', 4),
  (5, '14:40', '15:50', 5),
  (6, '15:50', '17:15', 6),
  (7, '17:15', '18:40', 7),
  (8, '18:40', '19:40', 8),
  (9, '19:40', '21:05', 9);

insert into public.system_settings (singleton) values (true);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'gymu-news',
  'gymu-news',
  false,
  5242880,
  array['image/webp']::text[]
);

insert into private.academic_program (program_name, display_order)
values
  ('Ing. Ejec. en Mec. de Proc. y Mant. Ind.', 1),
  ('Ing. Ejec. en Prev. de Riesgos', 2),
  ('Ing. Ejec. Control e Instr. Ind.', 3),
  ('Ing. Ejec. Gestión Industrial', 4),
  ('Ing. Ejec. Gestión de la calidad', 5),
  ('Ing. Ejec. Mantenimiento Ind.', 6),
  ('Ing. Ejec. Química', 7),
  ('Ing. Ejec. Software', 8),
  ('T.U Dibujante Proyectista', 9),
  ('T.U Administración de Empresas', 10),
  ('T.U Automatización y Control', 11),
  ('T.U Biotecnología', 12),
  ('T.U Ciencia de Datos', 13),
  ('T.U Computación e Informática', 14),
  ('T.U Construcción', 15),
  ('T.U Construcción Civil', 16),
  ('T.U Control de Alimentos', 17),
  ('T.U Control del Medio Ambiente', 18),
  ('T.U Electricidad', 19),
  ('T.U Electrónica', 20),
  ('T.U Estructuras', 21),
  ('T.U Industrial Madereras', 22),
  ('T.U Ind. M. Mec. de Mantenimiento', 23),
  ('T.U Informática', 24),
  ('T.U Mantenimiento Industrial', 25),
  ('T.U Mec. de Proc. y Mant. Ind.', 26),
  ('T.U Mecánica Automotriz', 27),
  ('T.U Mecánica Automotriz Diesel', 28),
  ('T.U Mecánica Estructural', 29),
  ('T.U Mecánica Industrial', 30),
  ('T.U Mecánica de Mantenimiento', 31),
  ('T.U Prevención de Riesgos', 32),
  ('T.U Proyecto y Diseño Estructural', 33),
  ('T.U Proyectos de Ingeniería', 34),
  ('T.U Química Analítica', 35),
  ('T.U Química Industrial', 36),
  ('T.U Química Mención Química Ind.', 37),
  ('T.U Robótica y Mecatrónica', 38),
  ('T.U Sistemas Electrónicos', 39),
  ('T.U Telecomunicaciones y Redes', 40),
  ('T.U Topografía', 41),
  ('Ing Mantenimiento Industrial', 42),
  ('Ing. Prev. de Riesgos Lab. y Amb.', 43),
  ('Ing Biotecnología', 44),
  ('Ing Construcción', 45),
  ('Ing Informática', 46),
  ('Subtéc. Mecánica en Mantenimiento', 47),
  ('Subtéc. Química Analítica', 48),
  ('Subtéc. Electrotecnia', 49),
  ('Subtéc. Electrónica Industrial', 50),
  ('Subtéc. Mecánica Estructural', 51),
  ('Ing Prevención de riesgos', 52),
  ('Posgrado', 53),
  ('Otro programa', 54);

alter table public.time_block enable row level security;
alter table public.app_user enable row level security;
alter table public.system_settings enable row level security;
alter table public.booking enable row level security;
alter table public.booking_event enable row level security;
alter table public.user_warning enable row level security;
alter table public.time_block_closure enable row level security;
alter table public.weekly_time_block_closure enable row level security;
alter table public.full_day_closure_period enable row level security;
alter table public.discipline_rule enable row level security;
alter table public.disciplinary_action enable row level security;
alter table public.news_item enable row level security;
alter table private.user_institutional_identity enable row level security;
alter table private.academic_program enable row level security;
alter table private.user_profile_revision enable row level security;
alter table private.check_in_qr_token enable row level security;
alter table private.staff_block_admission_request enable row level security;
alter table private.research_question_catalog enable row level security;
alter table private.research_question_option enable row level security;
alter table private.research_campaign enable row level security;
alter table private.research_campaign_target_role enable row level security;
alter table private.research_campaign_question enable row level security;
alter table private.research_campaign_submission enable row level security;
alter table private.research_campaign_response enable row level security;
alter table private.exercise_catalog enable row level security;
alter table private.routine_plan enable row level security;
alter table private.routine_plan_exercise enable row level security;

revoke all on all tables in schema private from public, anon, authenticated;
revoke all on all tables in schema public from anon, authenticated;

-- "Automatically expose new tables" queda desactivado en el proyecto v2. Los
-- Route Handlers que todavía resuelven lectura agregada o login mediante el
-- cliente de servidor necesitan grants explícitos para service_role. No se
-- conceden estos privilegios a anon ni authenticated: el navegador opera por
-- RPCs con grants propios.
grant usage on schema public to service_role;
grant select, insert, update on public.app_user to service_role;
grant select on public.system_settings to service_role;
grant select on public.booking to service_role;
grant select on public.time_block to service_role;
grant select on public.time_block_closure to service_role;
grant select on public.full_day_closure_period to service_role;
grant select on public.weekly_time_block_closure to service_role;


-- ============================================================================
-- Source: docs/database/v2-authority-draft.sql
-- ============================================================================

-- Draft de funciones v2: identidad, reglamento y perfil.
-- Requiere v2-schema-draft.sql. Aún no es ejecutable como migración final.

create function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create function private.parse_strict_iso_date(p_value text)
returns date
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_date date;
begin
  if p_value !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    return null;
  end if;

  v_date := to_date(p_value, 'FXYYYY-MM-DD');

  if to_char(v_date, 'YYYY-MM-DD') <> p_value then
    return null;
  end if;

  return v_date;
end;
$$;

create function private.require_active_user(p_user_id uuid)
returns public.app_user
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user public.app_user%rowtype;
begin
  select app_user.* into v_user
  from public.app_user
  where app_user.user_id = p_user_id
    and app_user.disabled_at is null;

  if not found then
    raise exception 'active application user is required';
  end if;

  return v_user;
end;
$$;

create function private.require_regulation_accepted_user(p_user_id uuid)
returns public.app_user
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user public.app_user%rowtype;
begin
  select app_user.* into v_user
  from public.app_user
  where app_user.user_id = p_user_id
    and app_user.disabled_at is null
    and app_user.regulation_accepted_at is not null;

  if not found then
    raise exception 'regulation acceptance is required';
  end if;

  return v_user;
end;
$$;

create function private.require_current_staff(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.app_user
    where app_user.user_id = p_user_id
      and app_user.role in ('gym_staff', 'admin')
      and app_user.disabled_at is null
      and app_user.regulation_accepted_at is not null
  ) then
    raise exception 'active gym staff user with regulation acceptance is required';
  end if;
end;
$$;

create function private.require_current_admin(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.app_user
    where app_user.user_id = p_user_id
      and app_user.role = 'admin'
      and app_user.disabled_at is null
      and app_user.regulation_accepted_at is not null
  ) then
    raise exception 'active administrator with regulation acceptance is required';
  end if;
end;
$$;

-- Escapa los metacaracteres de LIKE. Los consumidores construyen después una
-- búsqueda de prefijo deliberada; nunca interpretan la consulta del operador
-- como patrón SQL.
create function private.escape_like_literal(p_value text)
returns text
language sql
immutable
strict
security invoker
set search_path = ''
as $$
  select replace(replace(replace(p_value, E'\\', E'\\\\'), '%', E'\\%'), '_', E'\\_');
$$;

-- Primitiva única para los selectores de personas. La identidad SIGA es
-- opcional: una cuenta creada después con OAuth sigue siendo localizable por
-- su nombre visible y no obliga a que CSV ni la operación dependan de claims.
create function private.search_user_directory(
  p_query text,
  p_include_disabled boolean,
  p_allowed_roles public.app_role[],
  p_limit integer
)
returns table (
  user_id uuid,
  user_name text,
  institutional_username text,
  user_role public.app_role,
  allowed_time_block_id smallint,
  disabled_at timestamptz,
  disabled_reason text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_query text := lower(regexp_replace(trim(p_query), E'\\s+', ' ', 'g'));
  v_pattern text;
  v_name_query text;
begin
  if char_length(v_query) not between 2 and 120 then
    raise exception 'the user search query must contain between two and 120 characters';
  elsif p_limit not between 1 and 25 then
    raise exception 'the user search limit must be between one and twenty-five';
  end if;

  v_pattern := private.escape_like_literal(v_query) || '%';

  -- El alias institucional puede contener puntos, guiones o subrayados. Para
  -- esos casos se conserva solo la coincidencia literal de alias y no se
  -- reinterpretan sus caracteres como una consulta de texto completo.
  if v_query ~ '^[[:alnum:][:space:]]+$' then
    select string_agg(search_term || ':*', ' &')
    into v_name_query
    from regexp_split_to_table(v_query, E'\\s+') as search_term;
  end if;

  return query
  with raw_matches as (
    select identity.user_id, 0 as match_rank
    from private.user_institutional_identity as identity
    where identity.institutional_username like v_pattern escape E'\\'

    union all

    select app_user.user_id, 1 as match_rank
    from public.app_user
    where v_name_query is not null
      and to_tsvector('simple', app_user.user_name) @@ to_tsquery('simple', v_name_query)
  ),
  deduplicated_matches as (
    select raw_matches.user_id, min(raw_matches.match_rank) as match_rank
    from raw_matches
    group by raw_matches.user_id
  )
  select
    app_user.user_id,
    app_user.user_name,
    identity.institutional_username,
    app_user.role,
    app_user.allowed_time_block_id,
    app_user.disabled_at,
    app_user.disabled_reason
  from deduplicated_matches
  join public.app_user on app_user.user_id = deduplicated_matches.user_id
  left join private.user_institutional_identity as identity
    on identity.user_id = app_user.user_id
  where (p_include_disabled or app_user.disabled_at is null)
    and (p_allowed_roles is null or app_user.role = any(p_allowed_roles))
  order by
    deduplicated_matches.match_rank,
    app_user.user_name,
    app_user.user_id
  limit p_limit;
end;
$$;

create function private.has_required_booking_profile(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select
      latest.date_of_birth is not null
        and latest.reported_sex is not null
        and latest.height_cm is not null
        and latest.weight_kg is not null
        and latest.academic_program_id is not null
        and latest.career_entry_year is not null
    from private.user_profile_revision as latest
    where latest.user_id = p_user_id
    order by latest.recorded_at desc, latest.user_profile_revision_id desc
    limit 1
  ), false);
$$;

create function private.required_booking_profile_missing_fields(p_user_id uuid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  with latest as (
    select *
    from private.user_profile_revision
    where user_id = p_user_id
    order by recorded_at desc, user_profile_revision_id desc
    limit 1
  )
  select array_remove(array[
    case when latest.user_profile_revision_id is null or latest.date_of_birth is null then 'dateOfBirth' end,
    case when latest.user_profile_revision_id is null or latest.reported_sex is null then 'reportedSex' end,
    case when latest.user_profile_revision_id is null or latest.height_cm is null then 'heightCm' end,
    case when latest.user_profile_revision_id is null or latest.weight_kg is null then 'weightKg' end,
    case when latest.user_profile_revision_id is null or latest.academic_program_id is null then 'academicProgramId' end,
    case when latest.user_profile_revision_id is null or latest.career_entry_year is null then 'careerEntryYear' end
  ], null)
  from latest
  right join (select true as singleton) as required on true;
$$;

create function private.current_streak_weeks(p_user_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  with recursive
  attended_weeks as (
    select distinct date_trunc('week', booking.booking_date)::date as week_start
    from public.booking
    where booking.user_id = p_user_id
      and booking.status = 'present'
  ),
  current_week as (
    select date_trunc('week', (now() at time zone 'America/Santiago')::date)::date as week_start
  ),
  closure_exempt_weeks as (
    select date_trunc('week', closed_day.closed_day)::date as week_start
    from public.full_day_closure_period
    cross join lateral generate_series(
      closure_start_date,
      closure_end_date,
      interval '1 day'
    ) as closed_day(closed_day)
    where extract(isodow from closed_day.closed_day) between 1 and 5
    group by date_trunc('week', closed_day.closed_day)::date
    having count(*) = 5
  ),
  boundaries as (
    select
      coalesce((select min(week_start) from attended_weeks), current_week.week_start) as first_week,
      current_week.week_start as last_week
    from current_week
  ),
  eligible_weeks as (
    select calendar_week.week_start::date as week_start
    from boundaries
    cross join lateral generate_series(first_week, last_week, interval '7 days') as calendar_week(week_start)
    where not exists (
      select 1 from closure_exempt_weeks
      where closure_exempt_weeks.week_start = calendar_week.week_start::date
    )
  ),
  anchor as (
    select max(eligible_weeks.week_start) as week_start
    from eligible_weeks
    where eligible_weeks.week_start in (
      select week_start from eligible_weeks order by week_start desc limit 2
    )
      and exists (
        select 1 from attended_weeks
        where attended_weeks.week_start = eligible_weeks.week_start
      )
  ),
  streak as (
    select anchor.week_start, 1 as count_weeks
    from anchor
    where anchor.week_start is not null

    union all

    select previous_week.week_start, streak.count_weeks + 1
    from streak
    cross join lateral (
      select max(eligible_weeks.week_start) as week_start
      from eligible_weeks
      where eligible_weeks.week_start < streak.week_start
    ) as previous_week
    where exists (
      select 1 from attended_weeks
      where attended_weeks.week_start = previous_week.week_start
    )
  )
  select coalesce(max(count_weeks), 0)::integer from streak;
$$;

create function public.get_current_access_state()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when (select auth.uid()) is null then 'unauthenticated'
    when not exists (
      select 1 from public.app_user
      where user_id = (select auth.uid())
    ) then 'unauthenticated'
    when exists (
      select 1 from public.app_user
      where user_id = (select auth.uid()) and disabled_at is not null
    ) then 'disabled'
    else 'active'
  end;
$$;

create function public.has_accepted_regulation()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.app_user
    where app_user.user_id = (select auth.uid())
      and app_user.disabled_at is null
      and app_user.regulation_accepted_at is not null
  );
$$;

create function public.accept_regulation()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  perform private.require_active_user(v_user_id);

  update public.app_user
  set
    regulation_accepted_at = now()
  where app_user.user_id = v_user_id;
end;
$$;

create function public.upsert_institutional_identity(
  p_user_id uuid,
  p_institutional_username text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_username text := lower(trim(p_institutional_username));
begin
  perform private.require_active_user(p_user_id);

  if v_username is null
    or char_length(v_username) not between 1 and 120
    or v_username ~ '[@[:space:]]' then
    raise exception 'institutional username is invalid';
  end if;

  insert into private.user_institutional_identity (
    user_id,
    institutional_username,
    last_verified_at
  )
  values (p_user_id, v_username, now())
  on conflict (user_id) do update
  set
    institutional_username = excluded.institutional_username,
    last_verified_at = excluded.last_verified_at;
end;
$$;

create function public.update_current_user_theme_preference(
  p_actor_user_id uuid,
  p_theme_preference text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_theme_preference not in ('dark', 'light') then
    raise exception 'theme preference is invalid';
  end if;

  perform private.require_active_user(p_actor_user_id);

  update public.app_user
  set theme_preference = p_theme_preference
  where user_id = p_actor_user_id;

  return p_theme_preference;
end;
$$;

create function public.get_academic_programs()
returns table (
  academic_program_id smallint,
  program_name text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_active_user((select auth.uid()));

  return query
  select program.academic_program_id, program.program_name
  from private.academic_program as program
  where program.is_active
  order by program.display_order;
end;
$$;

create function public.get_profile_monthly_attendance(
  p_actor_user_id uuid,
  p_target_user_id uuid,
  p_month_start date
)
returns table (
  booking_date date,
  attendance_status public.booking_status
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor public.app_user%rowtype;
  v_current_month date := date_trunc('month', (now() at time zone 'America/Santiago')::date)::date;
begin
  v_actor := private.require_active_user(p_actor_user_id);

  if p_actor_user_id <> p_target_user_id and v_actor.role not in ('gym_staff', 'admin') then
    raise exception 'actor cannot read this attendance history';
  elsif p_month_start <> date_trunc('month', p_month_start)::date then
    raise exception 'month start must be the first calendar day of a month';
  elsif p_month_start > v_current_month then
    raise exception 'future months have no attendance history';
  end if;

  perform private.require_active_user(p_target_user_id);

  return query
  select
    booking.booking_date,
    case
      when bool_or(booking.status = 'present') then 'present'::public.booking_status
      else 'absent'::public.booking_status
    end
  from public.booking
  where booking.user_id = p_target_user_id
    and booking.booking_date >= p_month_start
    and booking.booking_date < (p_month_start + interval '1 month')::date
    and booking.status in ('present', 'absent')
  group by booking.booking_date
  order by booking.booking_date;
end;
$$;

create function public.get_profile_overview(
  p_actor_user_id uuid,
  p_target_user_id uuid
)
returns table (
  user_name text,
  role public.app_role,
  institutional_username text,
  date_of_birth date,
  reported_sex text,
  height_cm numeric,
  weight_kg numeric,
  academic_program_id smallint,
  academic_program_name text,
  career_entry_year smallint,
  booking_profile_complete boolean,
  booking_profile_missing_fields text[],
  streak_weeks integer,
  theme_preference text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor public.app_user%rowtype;
begin
  v_actor := private.require_active_user(p_actor_user_id);

  if p_actor_user_id <> p_target_user_id and v_actor.role not in ('gym_staff', 'admin') then
    raise exception 'actor cannot read this profile';
  end if;

  perform private.require_active_user(p_target_user_id);

  return query
  select
    target.user_name,
    target.role,
    identity.institutional_username,
    revision.date_of_birth,
    revision.reported_sex::text,
    revision.height_cm,
    revision.weight_kg,
    revision.academic_program_id,
    program.program_name,
    revision.career_entry_year,
    private.has_required_booking_profile(p_target_user_id),
    private.required_booking_profile_missing_fields(p_target_user_id),
    private.current_streak_weeks(p_target_user_id),
    target.theme_preference
  from public.app_user as target
  left join private.user_institutional_identity as identity on identity.user_id = target.user_id
  left join lateral (
    select *
    from private.user_profile_revision
    where user_id = target.user_id
    order by recorded_at desc, user_profile_revision_id desc
    limit 1
  ) as revision on true
  left join private.academic_program as program
    on program.academic_program_id = revision.academic_program_id
  where target.user_id = p_target_user_id;
end;
$$;

-- Búsqueda para abrir el reverso operativo del perfil. No devuelve atributos
-- personales: get_profile_overview conserva la autorización de lectura.
create function public.search_staff_profile_users(
  p_actor_user_id uuid,
  p_query text
)
returns table (
  user_id uuid,
  user_name text,
  institutional_username text,
  user_role public.app_role
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_staff(p_actor_user_id);

  return query
  select
    candidate.user_id,
    candidate.user_name,
    candidate.institutional_username,
    candidate.user_role
  from private.search_user_directory(
    p_query,
    false,
    array['student', 'u_staff']::public.app_role[],
    15
  ) as candidate;
end;
$$;

create function public.record_profile_data_from_payload(
  p_actor_user_id uuid,
  p_target_user_id uuid,
  p_profile_data jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current private.user_profile_revision%rowtype;
  v_date_of_birth date;
  v_reported_sex private.reported_sex;
  v_height_cm numeric(5, 2);
  v_weight_kg numeric(5, 2);
  v_academic_program_id smallint;
  v_career_entry_year smallint;
  v_current_year smallint := extract(year from now() at time zone 'America/Santiago')::smallint;
  v_has_current boolean := false;
begin
  if p_actor_user_id <> p_target_user_id then
    raise exception 'a user can only edit their own profile';
  end if;

  perform private.require_regulation_accepted_user(p_actor_user_id);

  if not exists (
    select 1
    from public.app_user
    where user_id = p_actor_user_id
      and role in ('student', 'u_staff')
  ) then
    raise exception 'only students and university staff can edit their own profile';
  end if;

  if p_profile_data is null or jsonb_typeof(p_profile_data) <> 'object' then
    raise exception 'profile data must be an object';
  end if;

  if not (p_profile_data ?| array[
    'dateOfBirth', 'reportedSex', 'heightCm', 'weightKg', 'academicProgramId', 'careerEntryYear'
  ]) then
    raise exception 'profile data must include at least one known field';
  end if;

  if exists (
    select 1
    from jsonb_object_keys(p_profile_data) as payload_key
    where payload_key not in (
      'dateOfBirth', 'reportedSex', 'heightCm', 'weightKg', 'academicProgramId', 'careerEntryYear'
    )
  ) then
    raise exception 'profile data includes an unknown field';
  end if;

  select * into v_current
  from private.user_profile_revision
  where user_id = p_target_user_id
  order by recorded_at desc, user_profile_revision_id desc
  limit 1;
  v_has_current := found;

  v_date_of_birth := case
    when not (p_profile_data ? 'dateOfBirth') then v_current.date_of_birth
    when p_profile_data -> 'dateOfBirth' = 'null'::jsonb then null
    when jsonb_typeof(p_profile_data -> 'dateOfBirth') = 'string'
      and p_profile_data ->> 'dateOfBirth' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      then private.parse_strict_iso_date(p_profile_data ->> 'dateOfBirth')
    else null
  end;

  if p_profile_data ? 'dateOfBirth'
    and p_profile_data -> 'dateOfBirth' <> 'null'::jsonb
    and (jsonb_typeof(p_profile_data -> 'dateOfBirth') <> 'string' or v_date_of_birth is null) then
    raise exception 'date of birth is invalid';
  end if;

  v_reported_sex := case
    when not (p_profile_data ? 'reportedSex') then v_current.reported_sex
    when p_profile_data -> 'reportedSex' = 'null'::jsonb then null
    when p_profile_data ->> 'reportedSex' in ('masculino', 'femenino', 'otro', 'prefiero_no_decir')
      then (p_profile_data ->> 'reportedSex')::private.reported_sex
    else null
  end;

  if p_profile_data ? 'reportedSex'
    and p_profile_data -> 'reportedSex' <> 'null'::jsonb
    and v_reported_sex is null then
    raise exception 'reported sex is invalid';
  end if;

  v_height_cm := case
    when not (p_profile_data ? 'heightCm') then v_current.height_cm
    when p_profile_data -> 'heightCm' = 'null'::jsonb then null
    when jsonb_typeof(p_profile_data -> 'heightCm') = 'number'
      then round((p_profile_data ->> 'heightCm')::numeric, 2)
    else null
  end;

  if p_profile_data ? 'heightCm'
    and p_profile_data -> 'heightCm' <> 'null'::jsonb
    and (
      v_height_cm is null
      or p_profile_data ->> 'heightCm' !~ '^[0-9]{1,3}(\.[0-9]{1,2})?$'
      or v_height_cm not between 120 and 230
    ) then
    raise exception 'height must be between 120 and 230 cm';
  end if;

  v_weight_kg := case
    when not (p_profile_data ? 'weightKg') then v_current.weight_kg
    when p_profile_data -> 'weightKg' = 'null'::jsonb then null
    when jsonb_typeof(p_profile_data -> 'weightKg') = 'number'
      then round((p_profile_data ->> 'weightKg')::numeric, 2)
    else null
  end;

  if p_profile_data ? 'weightKg'
    and p_profile_data -> 'weightKg' <> 'null'::jsonb
    and (
      v_weight_kg is null
      or p_profile_data ->> 'weightKg' !~ '^[0-9]{1,3}(\.[0-9]{1,2})?$'
      or v_weight_kg not between 35 and 300
    ) then
    raise exception 'weight must be between 35 and 300 kg';
  end if;

  v_academic_program_id := case
    when not (p_profile_data ? 'academicProgramId') then v_current.academic_program_id
    when p_profile_data -> 'academicProgramId' = 'null'::jsonb then null
    when jsonb_typeof(p_profile_data -> 'academicProgramId') = 'number'
      then (p_profile_data ->> 'academicProgramId')::smallint
    else null
  end;

  if p_profile_data ? 'academicProgramId'
    and p_profile_data -> 'academicProgramId' <> 'null'::jsonb
    and not exists (
      select 1 from private.academic_program
      where academic_program_id = v_academic_program_id and is_active
    ) then
    raise exception 'academic program is invalid';
  end if;

  v_career_entry_year := case
    when not (p_profile_data ? 'careerEntryYear') then v_current.career_entry_year
    when p_profile_data -> 'careerEntryYear' = 'null'::jsonb then null
    when jsonb_typeof(p_profile_data -> 'careerEntryYear') = 'number'
      then (p_profile_data ->> 'careerEntryYear')::smallint
    else null
  end;

  if p_profile_data ? 'careerEntryYear'
    and p_profile_data -> 'careerEntryYear' <> 'null'::jsonb
    and (v_career_entry_year is null or v_career_entry_year not between 2017 and v_current_year) then
    raise exception 'career entry year is invalid';
  end if;

  if v_has_current
    and row(v_date_of_birth, v_reported_sex, v_height_cm, v_weight_kg, v_academic_program_id, v_career_entry_year)
      is not distinct from row(
        v_current.date_of_birth,
        v_current.reported_sex,
        v_current.height_cm,
        v_current.weight_kg,
        v_current.academic_program_id,
        v_current.career_entry_year
      ) then
    return;
  end if;

  insert into private.user_profile_revision (
    user_id,
    date_of_birth,
    reported_sex,
    height_cm,
    weight_kg,
    academic_program_id,
    career_entry_year,
    recorded_by_user_id
  )
  values (
    p_target_user_id,
    v_date_of_birth,
    v_reported_sex,
    v_height_cm,
    v_weight_kg,
    v_academic_program_id,
    v_career_entry_year,
    p_actor_user_id
  );
end;
$$;

create trigger app_user_set_updated_at
before update on public.app_user
for each row
execute function private.set_updated_at();

create trigger system_settings_set_updated_at
before update on public.system_settings
for each row
execute function private.set_updated_at();

create trigger user_institutional_identity_set_updated_at
before update on private.user_institutional_identity
for each row
execute function private.set_updated_at();

create trigger academic_program_set_updated_at
before update on private.academic_program
for each row
execute function private.set_updated_at();

create trigger booking_set_updated_at
before update on public.booking
for each row
execute function private.set_updated_at();

create trigger discipline_rule_set_updated_at
before update on public.discipline_rule
for each row
execute function private.set_updated_at();

create trigger research_question_catalog_set_updated_at
before update on private.research_question_catalog
for each row
execute function private.set_updated_at();

create trigger research_campaign_set_updated_at
before update on private.research_campaign
for each row
execute function private.set_updated_at();

create trigger research_campaign_submission_set_updated_at
before update on private.research_campaign_submission
for each row
execute function private.set_updated_at();

create trigger research_campaign_response_set_updated_at
before update on private.research_campaign_response
for each row
execute function private.set_updated_at();

create trigger exercise_catalog_set_updated_at
before update on private.exercise_catalog
for each row
execute function private.set_updated_at();

create trigger routine_plan_set_updated_at
before update on private.routine_plan
for each row
execute function private.set_updated_at();

create trigger routine_plan_exercise_set_updated_at
before update on private.routine_plan_exercise
for each row
execute function private.set_updated_at();

create trigger news_item_set_updated_at
before update on public.news_item
for each row
execute function private.set_updated_at();

revoke all on function private.set_updated_at() from public, anon, authenticated;
revoke all on function private.parse_strict_iso_date(text) from public, anon, authenticated;
revoke all on function private.require_active_user(uuid) from public, anon, authenticated;
revoke all on function private.require_regulation_accepted_user(uuid) from public, anon, authenticated;
revoke all on function private.require_current_staff(uuid) from public, anon, authenticated;
revoke all on function private.require_current_admin(uuid) from public, anon, authenticated;
revoke all on function private.escape_like_literal(text) from public, anon, authenticated;
revoke all on function private.search_user_directory(text, boolean, public.app_role[], integer) from public, anon, authenticated;
revoke all on function private.has_required_booking_profile(uuid) from public, anon, authenticated;
revoke all on function private.required_booking_profile_missing_fields(uuid) from public, anon, authenticated;
revoke all on function private.current_streak_weeks(uuid) from public, anon, authenticated;
revoke all on function public.get_profile_overview(uuid, uuid) from public, anon;
revoke all on function public.search_staff_profile_users(uuid, text) from public, anon, authenticated;
revoke all on function public.record_profile_data_from_payload(uuid, uuid, jsonb) from public, anon, authenticated;
revoke all on function public.get_academic_programs() from public, anon;
revoke all on function public.has_accepted_regulation() from public, anon;
revoke all on function public.accept_regulation() from public, anon;
revoke all on function public.upsert_institutional_identity(uuid, text) from public, anon, authenticated;
revoke all on function public.update_current_user_theme_preference(uuid, text) from public, anon, authenticated;
revoke all on function public.get_profile_monthly_attendance(uuid, uuid, date) from public, anon, authenticated;
revoke all on function public.get_current_access_state() from public, anon;

grant execute on function public.get_current_access_state() to authenticated;
grant execute on function public.has_accepted_regulation() to authenticated;
grant execute on function public.accept_regulation() to authenticated;
grant execute on function public.get_academic_programs() to authenticated;
grant execute on function public.get_profile_overview(uuid, uuid) to service_role;
grant execute on function public.search_staff_profile_users(uuid, text) to service_role;
grant execute on function public.record_profile_data_from_payload(uuid, uuid, jsonb) to service_role;
grant execute on function public.upsert_institutional_identity(uuid, text) to service_role;
grant execute on function public.update_current_user_theme_preference(uuid, text) to service_role;
grant execute on function public.get_profile_monthly_attendance(uuid, uuid, date) to service_role;


-- ============================================================================
-- Source: docs/database/v2-booking-draft.sql
-- ============================================================================

-- Draft de funciones v2: reserva y disponibilidad.
-- Requiere v2-schema-draft.sql y v2-authority-draft.sql.

create function private.block_starts_at(p_booking_date date, p_time_block_id smallint)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select (p_booking_date + time_block_t0) at time zone 'America/Santiago'
  from public.time_block
  where time_block_id = p_time_block_id;
$$;

create function private.block_ends_at(p_booking_date date, p_time_block_id smallint)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select (p_booking_date + time_block_t1) at time zone 'America/Santiago'
  from public.time_block
  where time_block_id = p_time_block_id;
$$;

create function private.get_time_block_closure_reason(
  p_booking_date date,
  p_time_block_id smallint
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select closure.reason
  from (
    select full_day_closure_period.reason, 1 as priority
    from public.full_day_closure_period
    where p_booking_date between closure_start_date and closure_end_date

    union all

    select time_block_closure.reason, 2 as priority
    from public.time_block_closure
    where closure_date = p_booking_date
      and time_block_id = p_time_block_id

    union all

    select weekly_time_block_closure.reason, 3 as priority
    from public.weekly_time_block_closure
    where iso_weekday = extract(isodow from p_booking_date)::smallint
      and time_block_id = p_time_block_id
  ) as closure
  order by closure.priority
  limit 1;
$$;

create function private.is_time_block_closed(
  p_booking_date date,
  p_time_block_id smallint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.get_time_block_closure_reason(p_booking_date, p_time_block_id) is not null;
$$;

create function private.require_bookable_time_block(
  p_user_id uuid,
  p_booking_date date,
  p_time_block_id smallint,
  p_checked_at timestamptz
)
returns public.app_user
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user public.app_user%rowtype;
  v_start timestamptz;
  v_today date := (p_checked_at at time zone 'America/Santiago')::date;
begin
  if p_checked_at is null then
    raise exception 'booking validation timestamp is required';
  end if;

  v_user := private.require_regulation_accepted_user(p_user_id);

  if not private.has_required_booking_profile(p_user_id) then
    raise exception 'required booking profile is incomplete';
  end if;

  if p_booking_date < v_today or p_booking_date > v_today + 7 then
    raise exception 'booking date must be within the next seven days';
  end if;

  if extract(isodow from p_booking_date) not between 1 and 5 then
    raise exception 'weekends cannot be reserved';
  end if;

  if p_time_block_id = 7 and v_user.role not in ('u_staff', 'gym_staff', 'admin') then
    raise exception 'time block 7 is restricted to university staff';
  elsif v_user.role = 'u_staff' and v_user.allowed_time_block_id <> p_time_block_id then
    raise exception 'u_staff is restricted to its assigned time block';
  end if;

  v_start := private.block_starts_at(p_booking_date, p_time_block_id);
  if v_start is null then
    raise exception 'time block does not exist';
  elsif p_checked_at >= v_start then
    raise exception 'past blocks cannot be reserved';
  elsif private.is_time_block_closed(p_booking_date, p_time_block_id) then
    raise exception 'time block is closed';
  end if;

  return v_user;
end;
$$;

create function private.lock_booking_slot(p_booking_date date, p_time_block_id smallint)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select pg_advisory_xact_lock(
    hashtextextended(p_booking_date::text || ':' || p_time_block_id::text, 0)
  );
$$;

create function private.lock_user_booking_day(p_user_id uuid, p_booking_date date)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select pg_advisory_xact_lock(
    hashtextextended(p_user_id::text || ':' || p_booking_date::text, 0)
  );
$$;

create function private.lock_booking_closure_scope()
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select pg_advisory_xact_lock(hashtextextended('booking-closure-scope', 0));
$$;

create function public.create_booking(p_time_block_id smallint, p_booking_date date)
returns public.booking
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_booking public.booking%rowtype;
  v_start timestamptz;
  v_standard_capacity smallint;
  v_daily_limit smallint;
  v_standard_count integer;
  v_daily_count integer;
  v_reactivate boolean := false;
  v_auto_confirm boolean;
  v_checked_at timestamptz;
begin
  perform private.lock_booking_closure_scope();
  perform private.lock_user_booking_day(v_user_id, p_booking_date);
  perform private.lock_booking_slot(p_booking_date, p_time_block_id);

  v_checked_at := clock_timestamp();
  perform private.require_bookable_time_block(
    v_user_id,
    p_booking_date,
    p_time_block_id,
    v_checked_at
  );

  v_start := private.block_starts_at(p_booking_date, p_time_block_id);
  v_auto_confirm := v_checked_at >= v_start - interval '1 hour';

  select * into v_booking
  from public.booking
  where user_id = v_user_id
    and time_block_id = p_time_block_id
    and booking_date = p_booking_date
  for update;

  if found and v_booking.status = 'reserved' and v_auto_confirm then
    insert into public.user_warning (user_id, warning_type)
    values (v_user_id, 'missed_confirmation');

    delete from public.booking_event where booking_id = v_booking.booking_id;
    delete from public.booking where booking_id = v_booking.booking_id;
  elsif found then
    if v_booking.status <> 'cancelled' then
      raise exception 'booking already exists for this block and date';
    end if;
    v_reactivate := true;
  end if;

  select standard_capacity, n_sessions_per_day
  into v_standard_capacity, v_daily_limit
  from public.system_settings
  where singleton;

  select count(*) into v_daily_count
  from public.booking
  where user_id = v_user_id
    and booking_date = p_booking_date
    and status <> 'cancelled';

  if v_daily_count >= v_daily_limit then
    raise exception 'daily booking limit reached';
  end if;

  select count(*) into v_standard_count
  from public.booking
  where booking_date = p_booking_date
    and time_block_id = p_time_block_id
    and status in ('reserved', 'confirmed', 'present')
    and is_overcapacity = false;

  if v_standard_count >= v_standard_capacity then
    raise exception 'standard capacity reached';
  end if;

  if v_reactivate then
    update public.booking
    set
      status = (case when v_auto_confirm then 'confirmed' else 'reserved' end)::public.booking_status,
      is_overcapacity = false,
      admission_source = 'self_service',
      booked_at = v_checked_at,
      confirmed_at = case when v_auto_confirm then coalesce(v_booking.confirmed_at, v_checked_at) else null end,
      late_qr_authorized_at = null,
      present_at = null,
      absent_at = null,
      cancelled_at = null,
      qr_scanned_at = null
    where booking_id = v_booking.booking_id
    returning * into v_booking;
  else
    insert into public.booking (
      user_id,
      time_block_id,
      booking_date,
      status,
      confirmed_at
    )
    values (
      v_user_id,
      p_time_block_id,
      p_booking_date,
      (case when v_auto_confirm then 'confirmed' else 'reserved' end)::public.booking_status,
      case when v_auto_confirm then v_checked_at else null end
    )
    returning * into v_booking;
  end if;

  insert into public.booking_event (booking_id, event_type, actor_user_id, metadata)
  values (
    v_booking.booking_id,
    (case when v_reactivate then 'reactivated' when v_auto_confirm then 'confirmed' else 'reserved' end)::public.booking_event_type,
    v_user_id,
    case when v_auto_confirm then '{"source":"late_booking"}'::jsonb else '{}'::jsonb end
  );

  if v_reactivate and v_auto_confirm then
    insert into public.booking_event (booking_id, event_type, actor_user_id, metadata)
    values (v_booking.booking_id, 'confirmed', v_user_id, '{"source":"late_booking"}'::jsonb);
  end if;

  return v_booking;
end;
$$;

create function public.confirm_booking(p_booking_id uuid)
returns public.booking
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_booking public.booking%rowtype;
  v_start timestamptz;
  v_checked_at timestamptz;
begin
  perform private.require_regulation_accepted_user(v_user_id);
  if not private.has_required_booking_profile(v_user_id) then
    raise exception 'required booking profile is incomplete';
  end if;

  perform private.lock_booking_closure_scope();

  select * into v_booking
  from public.booking
  where booking_id = p_booking_id and user_id = v_user_id
  for update;

  if not found then
    raise exception 'booking not found';
  elsif v_booking.status <> 'reserved' then
    raise exception 'only reserved bookings can be confirmed';
  end if;

  v_checked_at := clock_timestamp();
  v_start := private.block_starts_at(v_booking.booking_date, v_booking.time_block_id);
  if v_checked_at < v_start - interval '4 hours' or v_checked_at >= v_start - interval '1 hour' then
    raise exception 'confirmation is outside its window';
  end if;

  update public.booking
  set status = 'confirmed', confirmed_at = v_checked_at
  where booking_id = p_booking_id
  returning * into v_booking;

  insert into public.booking_event (booking_id, event_type, actor_user_id)
  values (p_booking_id, 'confirmed', v_user_id);

  return v_booking;
end;
$$;

create function public.cancel_booking(p_booking_id uuid)
returns public.booking
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_booking public.booking%rowtype;
  v_start timestamptz;
  v_checked_at timestamptz;
begin
  perform private.require_active_user(v_user_id);
  perform private.lock_booking_closure_scope();

  select * into v_booking
  from public.booking
  where booking_id = p_booking_id and user_id = v_user_id
  for update;

  if not found then
    raise exception 'booking not found';
  elsif v_booking.status not in ('reserved', 'confirmed') then
    raise exception 'booking cannot be cancelled from its current status';
  end if;

  v_checked_at := clock_timestamp();
  v_start := private.block_starts_at(v_booking.booking_date, v_booking.time_block_id);
  if v_checked_at >= v_start then
    raise exception 'past bookings cannot be cancelled';
  elsif v_booking.status = 'confirmed' and v_checked_at >= v_start - interval '1 hour' then
    raise exception 'confirmed bookings cannot be cancelled during the final hour';
  end if;

  update public.booking
  set status = 'cancelled', cancelled_at = v_checked_at
  where booking_id = p_booking_id
  returning * into v_booking;

  insert into public.booking_event (booking_id, event_type, actor_user_id)
  values (p_booking_id, 'cancelled', v_user_id);

  return v_booking;
end;
$$;

create function public.get_booking_week_availability(p_week_start date)
returns table (
  booking_date date,
  time_block_id smallint,
  time_block_t0 time,
  time_block_t1 time,
  standard_capacity smallint,
  n_sessions_per_day smallint,
  standard_count integer,
  current_booking_id uuid,
  current_booking_status public.booking_status,
  current_booking_is_overcapacity boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_today date := (now() at time zone 'America/Santiago')::date;
  v_current_week date := date_trunc('week', v_today::timestamp)::date;
begin
  perform private.require_active_user(v_user_id);

  if p_week_start not in (v_current_week - 7, v_current_week, v_current_week + 7) then
    raise exception 'week is outside the calendar range';
  end if;

  return query
  with booking_days as (
    select generate_series(p_week_start, p_week_start + 4, interval '1 day')::date as booking_date
  )
  select
    booking_days.booking_date,
    time_block.time_block_id,
    time_block.time_block_t0,
    time_block.time_block_t1,
    system_settings.standard_capacity,
    system_settings.n_sessions_per_day,
    count(booking.booking_id) filter (
      where booking.status in ('reserved', 'confirmed', 'present')
        and booking.is_overcapacity = false
    )::integer,
    own_booking.booking_id,
    own_booking.status,
    own_booking.is_overcapacity
  from booking_days
  cross join public.time_block
  cross join public.system_settings
  left join public.booking
    on booking.booking_date = booking_days.booking_date
    and booking.time_block_id = time_block.time_block_id
  left join lateral (
    select candidate.booking_id, candidate.status, candidate.is_overcapacity
    from public.booking as candidate
    where candidate.user_id = v_user_id
      and candidate.booking_date = booking_days.booking_date
      and candidate.time_block_id = time_block.time_block_id
  ) as own_booking on true
  group by
    booking_days.booking_date,
    time_block.time_block_id,
    time_block.time_block_t0,
    time_block.time_block_t1,
    time_block.display_order,
    system_settings.standard_capacity,
    system_settings.n_sessions_per_day,
    own_booking.booking_id,
    own_booking.status,
    own_booking.is_overcapacity
  order by booking_days.booking_date, time_block.display_order;
end;
$$;

revoke all on function private.block_starts_at(date, smallint) from public, anon, authenticated;
revoke all on function private.block_ends_at(date, smallint) from public, anon, authenticated;
revoke all on function private.get_time_block_closure_reason(date, smallint) from public, anon, authenticated;
revoke all on function private.is_time_block_closed(date, smallint) from public, anon, authenticated;
revoke all on function private.require_bookable_time_block(uuid, date, smallint, timestamptz) from public, anon, authenticated;
revoke all on function private.lock_booking_slot(date, smallint) from public, anon, authenticated;
revoke all on function private.lock_user_booking_day(uuid, date) from public, anon, authenticated;
revoke all on function private.lock_booking_closure_scope() from public, anon, authenticated;
revoke all on function public.create_booking(smallint, date) from public, anon;
revoke all on function public.confirm_booking(uuid) from public, anon;
revoke all on function public.cancel_booking(uuid) from public, anon;
revoke all on function public.get_booking_week_availability(date) from public, anon;

grant execute on function public.create_booking(smallint, date) to authenticated;
grant execute on function public.confirm_booking(uuid) to authenticated;
grant execute on function public.cancel_booking(uuid) to authenticated;
grant execute on function public.get_booking_week_availability(date) to authenticated;

-- Se declara después de create_booking porque conserva exactamente sus reglas
-- de elegibilidad, cierre y auto-confirmación, pero cancela la fuente y crea el
-- destino en una sola transacción.
create function public.replace_daily_booking(
  p_source_booking_id uuid,
  p_time_block_id smallint,
  p_booking_date date
)
returns public.booking
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_source public.booking%rowtype;
  v_target public.booking%rowtype;
  v_source_start timestamptz;
  v_target_start timestamptz;
  v_capacity smallint;
  v_standard_count integer;
  v_reactivate boolean := false;
  v_auto_confirm boolean;
  v_checked_at timestamptz;
begin
  perform private.lock_booking_closure_scope();
  perform private.lock_user_booking_day(v_user_id, p_booking_date);
  perform private.lock_booking_slot(p_booking_date, p_time_block_id);

  v_checked_at := clock_timestamp();
  perform private.require_bookable_time_block(
    v_user_id,
    p_booking_date,
    p_time_block_id,
    v_checked_at
  );

  select * into v_source
  from public.booking
  where booking_id = p_source_booking_id and user_id = v_user_id
  for update;

  if not found then
    raise exception 'source booking not found';
  elsif v_source.booking_date <> p_booking_date then
    raise exception 'source booking must belong to the target date';
  elsif v_source.time_block_id = p_time_block_id then
    raise exception 'target time block must differ from source';
  elsif v_source.status not in ('reserved', 'confirmed') then
    raise exception 'source booking cannot be replaced from its current status';
  end if;

  v_source_start := private.block_starts_at(v_source.booking_date, v_source.time_block_id);
  v_target_start := private.block_starts_at(p_booking_date, p_time_block_id);
  if v_checked_at >= v_source_start then
    raise exception 'past bookings cannot be replaced';
  elsif v_source.status = 'confirmed' and v_checked_at >= v_source_start - interval '1 hour' then
    raise exception 'confirmed booking cannot be replaced during the final hour';
  end if;

  v_auto_confirm := v_checked_at >= v_target_start - interval '1 hour';

  select * into v_target
  from public.booking
  where user_id = v_user_id
    and booking_date = p_booking_date
    and time_block_id = p_time_block_id
  for update;

  if found and v_target.status = 'reserved' and v_auto_confirm then
    insert into public.user_warning (user_id, warning_type)
    values (v_user_id, 'missed_confirmation');
    delete from public.booking_event where booking_id = v_target.booking_id;
    delete from public.booking where booking_id = v_target.booking_id;
  elsif found then
    if v_target.status <> 'cancelled' then
      raise exception 'target booking already exists';
    end if;
    v_reactivate := true;
  end if;

  select standard_capacity into v_capacity
  from public.system_settings
  where singleton;

  select count(*) into v_standard_count
  from public.booking
  where booking_date = p_booking_date
    and time_block_id = p_time_block_id
    and status in ('reserved', 'confirmed', 'present')
    and is_overcapacity = false;

  if v_standard_count >= v_capacity then
    raise exception 'standard capacity reached';
  end if;

  update public.booking
  set status = 'cancelled', cancelled_at = v_checked_at
  where booking_id = v_source.booking_id;

  if v_reactivate then
    update public.booking
    set
      status = (case when v_auto_confirm then 'confirmed' else 'reserved' end)::public.booking_status,
      is_overcapacity = false,
      admission_source = 'self_service',
      booked_at = v_checked_at,
      confirmed_at = case when v_auto_confirm then coalesce(v_target.confirmed_at, v_checked_at) else null end,
      late_qr_authorized_at = null,
      present_at = null,
      absent_at = null,
      cancelled_at = null,
      qr_scanned_at = null
    where booking_id = v_target.booking_id
    returning * into v_target;
  else
    insert into public.booking (user_id, time_block_id, booking_date, status, confirmed_at)
    values (
      v_user_id,
      p_time_block_id,
      p_booking_date,
      (case when v_auto_confirm then 'confirmed' else 'reserved' end)::public.booking_status,
      case when v_auto_confirm then v_checked_at else null end
    )
    returning * into v_target;
  end if;

  insert into public.booking_event (booking_id, event_type, actor_user_id, metadata)
  values (
    v_source.booking_id,
    'cancelled',
    v_user_id,
    jsonb_build_object('reason', 'daily_booking_replacement', 'replacement_booking_id', v_target.booking_id)
  );

  insert into public.booking_event (booking_id, event_type, actor_user_id, metadata)
  values (
    v_target.booking_id,
    (case when v_reactivate then 'reactivated' when v_auto_confirm then 'confirmed' else 'reserved' end)::public.booking_event_type,
    v_user_id,
    jsonb_build_object('source', 'daily_booking_replacement', 'replaced_booking_id', v_source.booking_id)
  );

  if v_reactivate and v_auto_confirm then
    insert into public.booking_event (booking_id, event_type, actor_user_id, metadata)
    values (
      v_target.booking_id,
      'confirmed',
      v_user_id,
      jsonb_build_object('source', 'daily_booking_replacement', 'replaced_booking_id', v_source.booking_id)
    );
  end if;

  return v_target;
end;
$$;

revoke all on function public.replace_daily_booking(uuid, smallint, date) from public, anon;
grant execute on function public.replace_daily_booking(uuid, smallint, date) to authenticated;

-- Jobs internos. No se conceden a authenticated: pg_cron los invoca con el
-- rol propietario. Una reserva que omitió reconfirmación deja solo un warning
-- sin booking; una reserva confirmada que no registró QR termina como absent.
create function public.expire_unconfirmed_bookings()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_candidate record;
  v_booking public.booking%rowtype;
  v_count integer := 0;
  v_today date := (now() at time zone 'America/Santiago')::date;
  v_checked_at timestamptz;
begin
  for v_candidate in
    select booking_id, booking_date, time_block_id
    from public.booking
    where status = 'reserved'
      -- Un bloque futuro nunca puede expirar. El predicado permite que el
      -- índice parcial limite el trabajo a días que ya pudieron vencer.
      and booking_date <= v_today
      and private.block_starts_at(booking_date, time_block_id) - interval '1 hour' <= now()
  loop
    perform private.lock_booking_slot(v_candidate.booking_date, v_candidate.time_block_id);

    select * into v_booking
    from public.booking
    where booking_id = v_candidate.booking_id and status = 'reserved'
    for update skip locked;

    if not found then
      continue;
    end if;

    v_checked_at := clock_timestamp();
    if private.block_starts_at(v_booking.booking_date, v_booking.time_block_id) - interval '1 hour' > v_checked_at then
      continue;
    end if;

    insert into public.user_warning (user_id, warning_type)
    values (v_booking.user_id, 'missed_confirmation');

    delete from public.booking_event where booking_id = v_booking.booking_id;
    delete from public.booking where booking_id = v_booking.booking_id;
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

create function private.finalize_confirmed_booking_after_end(
  p_booking_id uuid,
  p_finalization_source text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.booking%rowtype;
  v_checked_at timestamptz;
begin
  if p_finalization_source not in (
    'qr_issue_after_block_end',
    'qr_scan_after_block_end',
    'staff_admission_after_block_end',
    'fallback_after_grace'
  ) then
    raise exception 'invalid attendance finalization source';
  end if;

  perform private.lock_booking_closure_scope();

  select * into v_booking
  from public.booking
  where booking_id = p_booking_id
  for update;

  v_checked_at := clock_timestamp();

  if not found
    or v_booking.status <> 'confirmed'
    or private.block_ends_at(v_booking.booking_date, v_booking.time_block_id) > v_checked_at then
    return false;
  end if;

  update public.booking
  set status = 'absent', absent_at = v_checked_at
  where booking_id = v_booking.booking_id;

  insert into public.user_warning (user_id, booking_id, warning_type)
  values (v_booking.user_id, v_booking.booking_id, 'missed_qr')
  on conflict (booking_id, warning_type) where booking_id is not null do nothing;

  insert into public.booking_event (booking_id, event_type, metadata)
  values (
    v_booking.booking_id,
    'attendance_finalized',
    jsonb_build_object('source', p_finalization_source)
  );

  return true;
end;
$$;

create function public.finalize_due_attendance()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.booking%rowtype;
  v_count integer := 0;
  v_today date := (now() at time zone 'America/Santiago')::date;
begin
  for v_booking in
    select *
    from public.booking
    where status = 'confirmed'
      -- Conserva además la recuperación de un cron detenido: incluye todo
      -- día pasado, pero excluye el horizonte futuro de reservas.
      and booking_date <= v_today
      and private.block_ends_at(booking_date, time_block_id) + interval '15 minutes' <= now()
    for update skip locked
  loop
    if private.finalize_confirmed_booking_after_end(
      v_booking.booking_id,
      'fallback_after_grace'
    ) then
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.expire_unconfirmed_bookings() from public, anon, authenticated;
revoke all on function public.finalize_due_attendance() from public, anon, authenticated;
revoke all on function private.finalize_confirmed_booking_after_end(uuid, text) from public, anon, authenticated;

-- Realtime solo transmite una invalidación privada. Nunca replica filas de
-- booking ni expone identidad, estado o conteos por WebSocket.
create function private.can_receive_booking_availability_topic(p_topic text)
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
  end if;

  return false;
end;
$$;

create function private.broadcast_booking_availability_invalidation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current public.booking%rowtype;
begin
  if tg_op = 'DELETE' then
    v_current := old;
  else
    v_current := new;
  end if;

  perform realtime.send(
    '{}'::jsonb,
    'invalidate',
    format('booking-availability:%s:%s', v_current.booking_date, v_current.time_block_id),
    true
  );

  if tg_op = 'UPDATE'
    and (old.booking_date, old.time_block_id) is distinct from (new.booking_date, new.time_block_id) then
    perform realtime.send(
      '{}'::jsonb,
      'invalidate',
      format('booking-availability:%s:%s', old.booking_date, old.time_block_id),
      true
    );
  end if;

  return null;
end;
$$;

create trigger booking_availability_invalidation
after insert or delete or update of status, is_overcapacity, booking_date, time_block_id
on public.booking
for each row
execute function private.broadcast_booking_availability_invalidation();

-- La política usa realtime.topic(), no payloads confiados por el navegador. El
-- único EXECUTE concedido sobre el helper permite que PostgreSQL lo evalúe en
-- la RLS de realtime.messages; el esquema private continúa sin USAGE público.
revoke all on function private.can_receive_booking_availability_topic(text) from public, anon;
revoke all on function private.broadcast_booking_availability_invalidation() from public, anon, authenticated;
grant execute on function private.can_receive_booking_availability_topic(text) to authenticated;

create policy booking_availability_broadcast_select
on realtime.messages
for select
to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and private.can_receive_booking_availability_topic((select realtime.topic()))
);

comment on function private.broadcast_booking_availability_invalidation() is
  'Broadcasts private per-date and per-block availability invalidations without exposing booking rows.';


-- ============================================================================
-- Source: docs/database/v2-qr-draft.sql
-- ============================================================================

-- Draft v2: emisión y consumo de QR. Requiere schema, authority y booking.
-- Los Route Handlers lo invocan con service_role tras resolver al actor desde
-- la sesión; ningún cliente recibe privilegios de escritura sobre estas tablas.

create function private.current_active_time_block(p_checked_at timestamptz)
returns table (
  booking_date date,
  time_block_id smallint,
  block_starts_at timestamptz,
  block_ends_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    (p_checked_at at time zone 'America/Santiago')::date,
    time_block.time_block_id,
    private.block_starts_at(
      (p_checked_at at time zone 'America/Santiago')::date,
      time_block.time_block_id
    ),
    private.block_ends_at(
      (p_checked_at at time zone 'America/Santiago')::date,
      time_block.time_block_id
    )
  from public.time_block
  where extract(isodow from p_checked_at at time zone 'America/Santiago') between 1 and 5
    and p_checked_at >= private.block_starts_at(
      (p_checked_at at time zone 'America/Santiago')::date,
      time_block.time_block_id
    )
    and p_checked_at < private.block_ends_at(
      (p_checked_at at time zone 'America/Santiago')::date,
      time_block.time_block_id
    )
  order by time_block.display_order
  limit 1;
$$;

create function private.require_qr_eligible_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_regulation_accepted_user(p_user_id);

  if not private.has_required_booking_profile(p_user_id) then
    raise exception 'required booking profile is incomplete';
  end if;
end;
$$;

create function private.finalize_ended_confirmed_bookings_for_user(
  p_user_id uuid,
  p_finalization_source text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.booking%rowtype;
  v_count integer := 0;
begin
  for v_booking in
    select *
    from public.booking
    where user_id = p_user_id
      and status = 'confirmed'
      and private.block_ends_at(booking_date, time_block_id) <= now()
    order by booking_date, time_block_id
    for update
  loop
    if private.finalize_confirmed_booking_after_end(
      v_booking.booking_id,
      p_finalization_source
    ) then
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

create function private.revoke_unscanned_check_in_qr_tokens(
  p_user_id uuid,
  p_booking_date date,
  p_time_block_id smallint
)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update private.check_in_qr_token
  set revoked_at = now()
  where user_id = p_user_id
    and booking_date = p_booking_date
    and time_block_id = p_time_block_id
    and scanned_at is null
    and revoked_at is null;
$$;

create function public.issue_check_in_qr(
  p_user_id uuid,
  p_token_hash bytea
)
returns table (
  state text,
  check_in_qr_token_id uuid,
  booking_date date,
  time_block_id smallint,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_active_block record;
  v_booking public.booking%rowtype;
  v_token private.check_in_qr_token%rowtype;
  v_finalized_count integer;
  v_is_ordinary_window boolean;
  v_is_late_authorized boolean;
  v_has_booking boolean;
  v_checked_at timestamptz;
begin
  if octet_length(p_token_hash) <> 32 then
    raise exception 'check-in token hash must have exactly 32 bytes';
  end if;

  perform private.require_qr_eligible_user(p_user_id);
  v_finalized_count := private.finalize_ended_confirmed_bookings_for_user(
    p_user_id,
    'qr_issue_after_block_end'
  );

  select * into v_active_block from private.current_active_time_block(clock_timestamp());
  if not found then
    return query select
      case when v_finalized_count > 0 then 'session_ended' else 'outside_window' end,
      null::uuid,
      null::date,
      null::smallint,
      null::timestamptz;
    return;
  end if;

  perform private.lock_booking_closure_scope();
  perform private.lock_booking_slot(
    v_active_block.booking_date,
    v_active_block.time_block_id
  );

  select * into v_booking
  from public.booking as booking
  where booking.user_id = p_user_id
    and booking.booking_date = v_active_block.booking_date
    and booking.time_block_id = v_active_block.time_block_id
  for update;

  v_has_booking := found;

  v_checked_at := clock_timestamp();
  if v_checked_at >= v_active_block.block_ends_at then
    return query select 'outside_window'::text, null::uuid, null::date, null::smallint, null::timestamptz;
    return;
  end if;

  v_is_ordinary_window := v_checked_at < v_active_block.block_starts_at + interval '15 minutes';
  v_is_late_authorized := v_has_booking
    and v_booking.status = 'confirmed'
    and v_booking.late_qr_authorized_at is not null
    and v_checked_at < v_booking.late_qr_authorized_at + interval '5 minutes';

  if not v_has_booking or v_booking.status <> 'confirmed' then
    return query select 'no_current_booking'::text, null::uuid, null::date, null::smallint, null::timestamptz;
    return;
  elsif not v_is_ordinary_window and not v_is_late_authorized then
    return query select 'arrived_too_late'::text, null::uuid, null::date, null::smallint, null::timestamptz;
    return;
  end if;

  perform private.revoke_unscanned_check_in_qr_tokens(
    p_user_id,
    v_active_block.booking_date,
    v_active_block.time_block_id
  );

  insert into private.check_in_qr_token (
    user_id,
    booking_date,
    time_block_id,
    token_hash,
    expires_at
  )
  values (
    p_user_id,
    v_active_block.booking_date,
    v_active_block.time_block_id,
    p_token_hash,
    least(
      v_checked_at + interval '45 seconds',
      case
        when v_is_ordinary_window then v_active_block.block_starts_at + interval '15 minutes'
        else v_booking.late_qr_authorized_at + interval '5 minutes'
      end,
      v_active_block.block_ends_at
    )
  )
  returning * into v_token;

  return query select
    'ready'::text,
    v_token.check_in_qr_token_id,
    v_token.booking_date,
    v_token.time_block_id,
    v_token.expires_at;
end;
$$;

create function public.get_check_in_qr_status(
  p_user_id uuid,
  p_check_in_qr_token_id uuid
)
returns table (state text, scanned_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token private.check_in_qr_token%rowtype;
begin
  perform private.require_regulation_accepted_user(p_user_id);

  select * into v_token
  from private.check_in_qr_token
  where check_in_qr_token_id = p_check_in_qr_token_id
    and user_id = p_user_id;

  if not found then
    return query select 'not_found'::text, null::timestamptz;
  elsif v_token.scanned_at is not null then
    return query select v_token.scan_result, v_token.scanned_at;
  elsif v_token.revoked_at is not null or now() >= v_token.expires_at then
    return query select 'expired'::text, null::timestamptz;
  end if;

  return query select 'pending'::text, null::timestamptz;
end;
$$;

create function public.consume_check_in_qr(
  p_scanner_user_id uuid,
  p_token_hash bytea
)
returns table (state text, scanned_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token private.check_in_qr_token%rowtype;
  v_booking public.booking%rowtype;
  v_active_block record;
  v_scanned_at timestamptz;
  v_state text;
  v_has_booking boolean;
begin
  if octet_length(p_token_hash) <> 32 then
    return query select 'invalid_token'::text, null::timestamptz;
    return;
  end if;

  perform private.require_current_staff(p_scanner_user_id);
  perform private.lock_booking_closure_scope();

  select * into v_token
  from private.check_in_qr_token
  where token_hash = p_token_hash
  for update;

  if not found then
    return query select 'invalid_token'::text, null::timestamptz;
    return;
  end if;

  v_scanned_at := clock_timestamp();

  if v_token.scanned_at is not null then
    return query select 'token_used'::text, v_token.scanned_at;
    return;
  elsif v_token.revoked_at is not null or v_scanned_at >= v_token.expires_at then
    return query select 'token_expired'::text, null::timestamptz;
    return;
  end if;

  select * into v_booking
  from public.booking
  where user_id = v_token.user_id
    and booking_date = v_token.booking_date
    and time_block_id = v_token.time_block_id
  for update;

  v_has_booking := found;

  if v_has_booking and v_booking.status = 'confirmed'
    and private.block_ends_at(v_booking.booking_date, v_booking.time_block_id) <= v_scanned_at then
    perform private.finalize_confirmed_booking_after_end(
      v_booking.booking_id,
      'qr_scan_after_block_end'
    );
    v_state := 'session_ended';
  else
    select * into v_active_block from private.current_active_time_block(clock_timestamp());

    if not found
      or v_active_block.booking_date <> v_token.booking_date
      or v_active_block.time_block_id <> v_token.time_block_id then
      update private.check_in_qr_token
      set revoked_at = v_scanned_at
      where check_in_qr_token_id = v_token.check_in_qr_token_id;

      return query select 'token_expired'::text, null::timestamptz;
      return;
    elsif v_has_booking and v_booking.status = 'confirmed' then
      update public.booking
      set status = 'present', present_at = v_scanned_at, qr_scanned_at = v_scanned_at
      where booking_id = v_booking.booking_id;

      insert into public.booking_event (booking_id, event_type, actor_user_id)
      values (v_booking.booking_id, 'qr_check_in', p_scanner_user_id);

      v_state := 'checked_in';
    elsif v_has_booking and v_booking.status = 'present' then
      v_state := 'already_present';
    else
      v_state := 'no_current_booking';
    end if;
  end if;

  update private.check_in_qr_token
  set
    scanned_at = v_scanned_at,
    scanned_by_user_id = p_scanner_user_id,
    scan_result = v_state
  where check_in_qr_token_id = v_token.check_in_qr_token_id;

  return query select v_state, v_scanned_at;
end;
$$;

revoke all on function private.current_active_time_block(timestamptz) from public, anon, authenticated;
revoke all on function private.require_qr_eligible_user(uuid) from public, anon, authenticated;
revoke all on function private.finalize_ended_confirmed_bookings_for_user(uuid, text) from public, anon, authenticated;
revoke all on function private.revoke_unscanned_check_in_qr_tokens(uuid, date, smallint) from public, anon, authenticated;
revoke all on function public.issue_check_in_qr(uuid, bytea) from public, anon, authenticated;
revoke all on function public.get_check_in_qr_status(uuid, uuid) from public, anon, authenticated;
revoke all on function public.consume_check_in_qr(uuid, bytea) from public, anon, authenticated;

grant execute on function public.issue_check_in_qr(uuid, bytea) to service_role;
grant execute on function public.get_check_in_qr_status(uuid, uuid) to service_role;
grant execute on function public.consume_check_in_qr(uuid, bytea) to service_role;


-- ============================================================================
-- Source: docs/database/v2-staff-admission-draft.sql
-- ============================================================================

-- Draft v2: operaciones presenciales de /bloque.
-- Requiere schema, authority, booking y QR. Solo Route Handlers con service_role
-- pueden invocar las RPCs públicas que reciben actor o usuario objetivo.

create function public.request_current_block_admission(p_user_id uuid)
returns table (
  booking_date date,
  time_block_id smallint,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_active_block record;
begin
  perform private.require_qr_eligible_user(p_user_id);

  select * into v_active_block from private.current_active_time_block(clock_timestamp());
  if not found then
    raise exception 'an active time block is required';
  elsif private.is_time_block_closed(
    v_active_block.booking_date,
    v_active_block.time_block_id
  ) then
    raise exception 'the active time block is closed';
  end if;

  if exists (
    select 1
    from public.booking as booking
    where booking.user_id = p_user_id
      and booking.booking_date = v_active_block.booking_date
      and booking.time_block_id = v_active_block.time_block_id
      and booking.status in ('confirmed', 'present')
  ) then
    raise exception 'a current confirmed booking already exists';
  end if;

  insert into private.staff_block_admission_request (
    user_id,
    booking_date,
    time_block_id,
    expires_at
  )
  values (
    p_user_id,
    v_active_block.booking_date,
    v_active_block.time_block_id,
    v_active_block.block_ends_at
  )
  on conflict on constraint staff_block_admission_request_user_block_key do nothing;

  return query
  select
    request.booking_date,
    request.time_block_id,
    request.expires_at
  from private.staff_block_admission_request as request
  where request.user_id = p_user_id
    and request.booking_date = v_active_block.booking_date
    and request.time_block_id = v_active_block.time_block_id;
end;
$$;

create function public.get_current_staff_block_context(p_actor_user_id uuid)
returns table (
  booking_date date,
  time_block_id smallint,
  block_starts_at timestamptz,
  block_ends_at timestamptz,
  standard_capacity smallint,
  confirmed_standard_count integer,
  overcapacity_max_above smallint,
  confirmed_overcapacity_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_active_block record;
begin
  perform private.require_current_staff(p_actor_user_id);

  select * into v_active_block from private.current_active_time_block(clock_timestamp());
  if not found then
    raise exception 'an active time block is required';
  elsif private.is_time_block_closed(
    v_active_block.booking_date,
    v_active_block.time_block_id
  ) then
    raise exception 'the active time block is closed';
  end if;

  return query
  select
    v_active_block.booking_date,
    v_active_block.time_block_id,
    v_active_block.block_starts_at,
    v_active_block.block_ends_at,
    system_settings.standard_capacity,
    count(booking.booking_id) filter (
      where booking.status in ('confirmed', 'present')
        and not booking.is_overcapacity
    )::integer,
    system_settings.overcapacity_max_above,
    count(booking.booking_id) filter (
      where booking.status in ('confirmed', 'present')
        and booking.is_overcapacity
    )::integer
  from public.system_settings
  left join public.booking
    on booking.booking_date = v_active_block.booking_date
    and booking.time_block_id = v_active_block.time_block_id
  where system_settings.singleton
  group by
    system_settings.standard_capacity,
    system_settings.overcapacity_max_above;
end;
$$;

create function public.get_current_staff_block_candidates(p_actor_user_id uuid)
returns table (
  user_id uuid,
  user_name text,
  booking_status public.booking_status,
  is_overcapacity boolean,
  admission_source public.booking_admission_source,
  requested_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_active_block record;
begin
  perform private.require_current_staff(p_actor_user_id);

  select * into v_active_block from private.current_active_time_block(clock_timestamp());
  if not found then
    raise exception 'an active time block is required';
  elsif private.is_time_block_closed(
    v_active_block.booking_date,
    v_active_block.time_block_id
  ) then
    raise exception 'the active time block is closed';
  end if;

  return query
  with requested_user as (
    select request.user_id, request.requested_at
    from private.staff_block_admission_request as request
    where request.booking_date = v_active_block.booking_date
      and request.time_block_id = v_active_block.time_block_id
      and request.expires_at > now()
  ), participant as (
    select
      booking.user_id,
      booking.status as booking_status,
      booking.is_overcapacity,
      booking.admission_source,
      requested_user.requested_at
    from public.booking
    left join requested_user on requested_user.user_id = booking.user_id
    where booking.booking_date = v_active_block.booking_date
      and booking.time_block_id = v_active_block.time_block_id

    union all

    select
      requested_user.user_id,
      null::public.booking_status,
      null::boolean,
      null::public.booking_admission_source,
      requested_user.requested_at
    from requested_user
    where not exists (
      select 1
      from public.booking
      where booking.user_id = requested_user.user_id
        and booking.booking_date = v_active_block.booking_date
        and booking.time_block_id = v_active_block.time_block_id
    )
  )
  select
    participant.user_id,
    app_user.user_name,
    participant.booking_status,
    participant.is_overcapacity,
    participant.admission_source,
    participant.requested_at
  from participant
  join public.app_user on app_user.user_id = participant.user_id
  order by
    case participant.booking_status
      when 'confirmed' then 1
      when 'present' then 2
      when 'reserved' then 3
      when 'absent' then 4
      when 'cancelled' then 5
      else 6
    end,
    participant.requested_at nulls last,
    app_user.user_name;
end;
$$;

create function public.search_current_staff_block_users(
  p_actor_user_id uuid,
  p_query text
)
returns table (
  user_id uuid,
  user_name text,
  institutional_username text,
  booking_status public.booking_status
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_active_block record;
begin
  perform private.require_current_staff(p_actor_user_id);

  select * into v_active_block from private.current_active_time_block(clock_timestamp());
  if not found then
    raise exception 'an active time block is required';
  end if;

  return query
  select
    app_user.user_id,
    app_user.user_name,
    identity.institutional_username,
    booking.status
  from private.search_user_directory(
    p_query,
    false,
    array['student', 'u_staff']::public.app_role[],
    10
  ) as candidate
  join public.app_user as app_user on app_user.user_id = candidate.user_id
  left join private.user_institutional_identity as identity on identity.user_id = app_user.user_id
  left join public.booking as booking
    on booking.user_id = app_user.user_id
    and booking.booking_date = v_active_block.booking_date
    and booking.time_block_id = v_active_block.time_block_id
  where app_user.regulation_accepted_at is not null
  order by candidate.user_name, candidate.user_id;
end;
$$;

create function public.admit_current_staff_block_user(
  p_actor_user_id uuid,
  p_target_user_id uuid,
  p_admission_source public.booking_admission_source
)
returns public.booking
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_active_block record;
  v_target public.app_user%rowtype;
  v_booking public.booking%rowtype;
  v_settings public.system_settings%rowtype;
  v_standard_count integer;
  v_overcapacity_count integer;
  v_has_current_booking boolean;
  v_checked_at timestamptz;
begin
  perform private.require_current_staff(p_actor_user_id);
  perform private.require_qr_eligible_user(p_target_user_id);

  if p_admission_source not in ('staff_exception', 'staff_overcapacity') then
    raise exception 'staff admission source is required';
  end if;

  select * into v_active_block from private.current_active_time_block(clock_timestamp());
  if not found then
    raise exception 'an active time block is required';
  elsif private.is_time_block_closed(
    v_active_block.booking_date,
    v_active_block.time_block_id
  ) then
    raise exception 'the active time block is closed';
  end if;

  perform private.finalize_ended_confirmed_bookings_for_user(
    p_target_user_id,
    'staff_admission_after_block_end'
  );

  v_target := private.require_regulation_accepted_user(p_target_user_id);
  if v_active_block.time_block_id = 7 and v_target.role not in ('u_staff', 'gym_staff', 'admin') then
    raise exception 'time block 7 is restricted to university staff';
  elsif v_target.role = 'u_staff' and v_target.allowed_time_block_id <> v_active_block.time_block_id then
    raise exception 'u_staff is restricted to its assigned time block';
  end if;

  if exists (
    select 1
    from public.booking
    where user_id = p_target_user_id
      and booking_date = v_active_block.booking_date
      and status = 'present'
      and time_block_id <> v_active_block.time_block_id
  ) then
    raise exception 'a second attendance cannot be admitted on the same day';
  end if;

  perform private.lock_booking_closure_scope();
  perform private.lock_booking_slot(
    v_active_block.booking_date,
    v_active_block.time_block_id
  );

  v_checked_at := clock_timestamp();
  if v_checked_at >= v_active_block.block_ends_at then
    raise exception 'the active time block ended before admission could be authorized';
  end if;

  select * into v_booking
  from public.booking
  where user_id = p_target_user_id
    and booking_date = v_active_block.booking_date
    and time_block_id = v_active_block.time_block_id
  for update;

  v_has_current_booking := found;

  if v_has_current_booking and v_booking.status = 'present' then
    raise exception 'attendance is already registered';
  elsif v_has_current_booking and v_booking.status = 'confirmed' then
    raise exception 'use late QR reauthorization for a confirmed attendee';
  end if;

  select * into v_settings
  from public.system_settings
  where singleton;

  select
    count(*) filter (where not booking.is_overcapacity),
    count(*) filter (where booking.is_overcapacity)
  into v_standard_count, v_overcapacity_count
  from public.booking
  where booking_date = v_active_block.booking_date
    and time_block_id = v_active_block.time_block_id
    and status in ('confirmed', 'present')
    and booking_id is distinct from v_booking.booking_id;

  if p_admission_source = 'staff_exception' and v_standard_count >= v_settings.standard_capacity then
    raise exception 'standard capacity is exhausted; use staff_overcapacity';
  elsif p_admission_source = 'staff_overcapacity' and v_standard_count < v_settings.standard_capacity then
    raise exception 'standard capacity remains; use staff_exception';
  elsif p_admission_source = 'staff_overcapacity'
    and v_overcapacity_count >= v_settings.overcapacity_max_above then
    raise exception 'overcapacity limit is reached';
  end if;

  if v_has_current_booking then
    update public.booking
    set
      status = 'confirmed',
      is_overcapacity = p_admission_source = 'staff_overcapacity',
      admission_source = p_admission_source,
      confirmed_at = coalesce(v_booking.confirmed_at, v_checked_at),
      late_qr_authorized_at = v_checked_at,
      present_at = null,
      absent_at = null,
      cancelled_at = null,
      qr_scanned_at = null
    where booking_id = v_booking.booking_id
    returning * into v_booking;
  else
    insert into public.booking (
      user_id,
      time_block_id,
      booking_date,
      status,
      is_overcapacity,
      admission_source,
      confirmed_at,
      late_qr_authorized_at
    )
    values (
      p_target_user_id,
      v_active_block.time_block_id,
      v_active_block.booking_date,
      'confirmed',
      p_admission_source = 'staff_overcapacity',
      p_admission_source,
      v_checked_at,
      v_checked_at
    )
    returning * into v_booking;
  end if;

  if p_admission_source = 'staff_exception' then
    insert into public.user_warning (
      user_id,
      booking_id,
      warning_type,
      created_by_user_id
    )
    values (
      p_target_user_id,
      v_booking.booking_id,
      'unbooked_attendance',
      p_actor_user_id
    )
    on conflict (booking_id, warning_type) where booking_id is not null do nothing;
  end if;

  insert into public.booking_event (booking_id, event_type, actor_user_id, metadata)
  values (
    v_booking.booking_id,
    'confirmed',
    p_actor_user_id,
    jsonb_build_object('admission_source', p_admission_source)
  );

  delete from private.staff_block_admission_request
  where user_id = p_target_user_id
    and booking_date = v_active_block.booking_date
    and time_block_id = v_active_block.time_block_id;

  return v_booking;
end;
$$;

create function public.reauthorize_current_staff_block_qr(
  p_actor_user_id uuid,
  p_target_user_id uuid
)
returns public.booking
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_active_block record;
  v_booking public.booking%rowtype;
  v_checked_at timestamptz;
begin
  perform private.require_current_staff(p_actor_user_id);
  perform private.require_qr_eligible_user(p_target_user_id);

  select * into v_active_block from private.current_active_time_block(clock_timestamp());
  if not found then
    raise exception 'an active time block is required';
  elsif private.is_time_block_closed(
    v_active_block.booking_date,
    v_active_block.time_block_id
  ) then
    raise exception 'the active time block is closed';
  elsif clock_timestamp() < v_active_block.block_starts_at + interval '15 minutes' then
    raise exception 'late QR reauthorization opens after the ordinary QR window';
  end if;

  select * into v_booking
  from public.booking
  where user_id = p_target_user_id
    and booking_date = v_active_block.booking_date
    and time_block_id = v_active_block.time_block_id
    and status = 'confirmed'
  for update;

  if not found then
    raise exception 'a confirmed booking is required';
  end if;

  v_checked_at := clock_timestamp();
  if v_checked_at >= v_active_block.block_ends_at then
    raise exception 'the active time block ended before QR could be reauthorized';
  end if;

  update public.booking
  set late_qr_authorized_at = v_checked_at
  where booking_id = v_booking.booking_id
  returning * into v_booking;

  insert into public.booking_event (booking_id, event_type, actor_user_id, metadata)
  values (
    v_booking.booking_id,
    'late_qr_authorized',
    p_actor_user_id,
    jsonb_build_object('expires_at', v_booking.late_qr_authorized_at + interval '5 minutes')
  );

  return v_booking;
end;
$$;

revoke all on function public.request_current_block_admission(uuid) from public, anon, authenticated;
revoke all on function public.get_current_staff_block_context(uuid) from public, anon, authenticated;
revoke all on function public.get_current_staff_block_candidates(uuid) from public, anon, authenticated;
revoke all on function public.search_current_staff_block_users(uuid, text) from public, anon, authenticated;
revoke all on function public.admit_current_staff_block_user(
  uuid,
  uuid,
  public.booking_admission_source
) from public, anon, authenticated;
revoke all on function public.reauthorize_current_staff_block_qr(uuid, uuid) from public, anon, authenticated;

grant execute on function public.request_current_block_admission(uuid) to service_role;
grant execute on function public.get_current_staff_block_context(uuid) to service_role;
grant execute on function public.get_current_staff_block_candidates(uuid) to service_role;
grant execute on function public.search_current_staff_block_users(uuid, text) to service_role;
grant execute on function public.admit_current_staff_block_user(
  uuid,
  uuid,
  public.booking_admission_source
) to service_role;
grant execute on function public.reauthorize_current_staff_block_qr(uuid, uuid) to service_role;


-- ============================================================================
-- Source: docs/database/v2-admin-draft.sql
-- ============================================================================

-- Draft v2: configuración, cierres, disciplina y acceso administrativo.
-- Requiere schema, authority y booking. Las RPCs públicas reciben el actor
-- resuelto por el Route Handler y se conceden exclusivamente a service_role.

create function private.assert_open_time_block_for_booking()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Sincroniza reservas y cierres administrativos. El volumen previsto es
  -- bajo y este lock global evita que una reserva y un cierre se crucen entre
  -- la validación y el INSERT/UPDATE correspondiente.
  perform private.lock_booking_closure_scope();

  if new.status in ('reserved', 'confirmed', 'present')
    and private.is_time_block_closed(new.booking_date, new.time_block_id) then
    raise exception 'time block is closed for this date';
  end if;

  return new;
end;
$$;

create trigger booking_reject_closed_time_block
before insert or update of booking_date, time_block_id, status on public.booking
for each row
execute function private.assert_open_time_block_for_booking();

create function public.get_booking_closure_reasons(
  p_actor_user_id uuid,
  p_start_date date,
  p_end_date date
)
returns table (
  closure_date date,
  time_block_id smallint,
  reason text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_active_user(p_actor_user_id);

  if p_end_date < p_start_date or p_end_date > p_start_date + 31 then
    raise exception 'closure range must be between one and thirty-two days';
  end if;

  return query
  select
    calendar_day.closure_date::date,
    time_block.time_block_id,
    private.get_time_block_closure_reason(
      calendar_day.closure_date::date,
      time_block.time_block_id
    )
  from generate_series(p_start_date, p_end_date, interval '1 day') as calendar_day(closure_date)
  cross join public.time_block
  where private.get_time_block_closure_reason(
    calendar_day.closure_date::date,
    time_block.time_block_id
  ) is not null
  order by calendar_day.closure_date, time_block.display_order;
end;
$$;

create function public.get_admin_configuration(p_actor_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'America/Santiago')::date;
begin
  perform private.require_current_admin(p_actor_user_id);

  return (
    select jsonb_build_object(
      'settings', jsonb_build_object(
        'nSessionsPerDay', system_settings.n_sessions_per_day,
        'overcapacityMaxAbove', system_settings.overcapacity_max_above,
        'standardCapacity', system_settings.standard_capacity
      ),
      'timeBlocks', coalesce((
        select jsonb_agg(jsonb_build_object(
          'timeBlockId', time_block.time_block_id,
          'startTime', time_block.time_block_t0::text,
          'endTime', time_block.time_block_t1::text
        ) order by time_block.display_order)
        from public.time_block
      ), '[]'::jsonb),
      'dateClosures', coalesce((
        select jsonb_agg(jsonb_build_object(
          'closureId', closure.time_block_closure_id,
          'date', closure.closure_date,
          'timeBlockId', closure.time_block_id,
          'reason', closure.reason
        ) order by closure.closure_date, closure.time_block_id)
        from public.time_block_closure as closure
        where closure.closure_date >= v_today
      ), '[]'::jsonb),
      'weeklyClosures', coalesce((
        select jsonb_agg(jsonb_build_object(
          'closureId', closure.weekly_time_block_closure_id,
          'isoWeekday', closure.iso_weekday,
          'timeBlockId', closure.time_block_id,
          'reason', closure.reason
        ) order by closure.iso_weekday, closure.time_block_id)
        from public.weekly_time_block_closure as closure
      ), '[]'::jsonb),
      'fullDayClosures', coalesce((
        select jsonb_agg(jsonb_build_object(
          'closureId', closure.full_day_closure_period_id,
          'startDate', closure.closure_start_date,
          'endDate', closure.closure_end_date,
          'reason', closure.reason
        ) order by closure.closure_start_date, closure.closure_end_date)
        from public.full_day_closure_period as closure
        where closure.closure_end_date >= v_today
      ), '[]'::jsonb)
    )
    from public.system_settings
    where singleton
  );
end;
$$;

create function public.update_admin_operational_settings(
  p_actor_user_id uuid,
  p_n_sessions_per_day smallint,
  p_overcapacity_max_above smallint
)
returns public.system_settings
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_settings public.system_settings%rowtype;
begin
  perform private.require_current_admin(p_actor_user_id);

  if p_n_sessions_per_day <= 0 then
    raise exception 'daily session limit must be positive';
  elsif p_overcapacity_max_above < 0 then
    raise exception 'overcapacity maximum cannot be negative';
  end if;

  update public.system_settings
  set
    n_sessions_per_day = p_n_sessions_per_day,
    overcapacity_max_above = p_overcapacity_max_above,
    updated_by_user_id = p_actor_user_id
  where singleton
  returning * into v_settings;

  return v_settings;
end;
$$;

create function private.require_unreserved_time_block_closure(
  p_booking_date date,
  p_time_block_id smallint
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.booking
    where booking_date = p_booking_date
      and time_block_id = p_time_block_id
      and status in ('reserved', 'confirmed')
  ) then
    raise exception 'active bookings must be resolved before closing a time block';
  end if;
end;
$$;

create function public.upsert_admin_date_time_block_closure(
  p_actor_user_id uuid,
  p_time_block_id smallint,
  p_closure_date date,
  p_reason text
)
returns public.time_block_closure
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := trim(p_reason);
  v_today date := (now() at time zone 'America/Santiago')::date;
  v_closure public.time_block_closure%rowtype;
begin
  perform private.require_current_admin(p_actor_user_id);

  perform private.lock_booking_closure_scope();

  if p_closure_date < v_today then
    raise exception 'past dates cannot be closed';
  elsif char_length(v_reason) not between 3 and 240 then
    raise exception 'closure reason must contain between three and 240 characters';
  elsif not exists (select 1 from public.time_block where time_block_id = p_time_block_id) then
    raise exception 'time block not found';
  end if;

  perform private.lock_booking_slot(p_closure_date, p_time_block_id);
  perform private.require_unreserved_time_block_closure(p_closure_date, p_time_block_id);

  insert into public.time_block_closure (
    closure_date,
    time_block_id,
    reason,
    created_by_user_id
  )
  values (p_closure_date, p_time_block_id, v_reason, p_actor_user_id)
  on conflict (closure_date, time_block_id) do update
  set reason = excluded.reason, created_by_user_id = excluded.created_by_user_id
  returning * into v_closure;

  return v_closure;
end;
$$;

create function public.upsert_admin_weekly_time_block_closure(
  p_actor_user_id uuid,
  p_time_block_id smallint,
  p_iso_weekday smallint,
  p_reason text
)
returns public.weekly_time_block_closure
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := trim(p_reason);
  v_closure public.weekly_time_block_closure%rowtype;
  v_today date := (now() at time zone 'America/Santiago')::date;
begin
  perform private.require_current_admin(p_actor_user_id);

  perform private.lock_booking_closure_scope();

  if p_iso_weekday not between 1 and 5 then
    raise exception 'weekday must use ISO numbering from one through five';
  elsif char_length(v_reason) not between 3 and 240 then
    raise exception 'closure reason must contain between three and 240 characters';
  elsif not exists (select 1 from public.time_block where time_block_id = p_time_block_id) then
    raise exception 'time block not found';
  end if;

  if exists (
    select 1
    from public.booking
    where booking_date >= v_today
      and time_block_id = p_time_block_id
      and extract(isodow from booking_date)::smallint = p_iso_weekday
      and status in ('reserved', 'confirmed')
  ) then
    raise exception 'active bookings must be resolved before closing a weekly time block';
  end if;

  insert into public.weekly_time_block_closure (
    iso_weekday,
    time_block_id,
    reason,
    created_by_user_id
  )
  values (p_iso_weekday, p_time_block_id, v_reason, p_actor_user_id)
  on conflict (iso_weekday, time_block_id) do update
  set reason = excluded.reason, created_by_user_id = excluded.created_by_user_id
  returning * into v_closure;

  return v_closure;
end;
$$;

create function public.upsert_admin_full_day_closure_period(
  p_actor_user_id uuid,
  p_start_date date,
  p_end_date date,
  p_reason text
)
returns public.full_day_closure_period
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := trim(p_reason);
  v_today date := (now() at time zone 'America/Santiago')::date;
  v_closure public.full_day_closure_period%rowtype;
begin
  perform private.require_current_admin(p_actor_user_id);

  perform private.lock_booking_closure_scope();

  if p_start_date < v_today then
    raise exception 'past dates cannot be closed';
  elsif p_end_date < p_start_date or p_end_date > p_start_date + 365 then
    raise exception 'closure period must be between one and three hundred sixty-six days';
  elsif char_length(v_reason) not between 3 and 240 then
    raise exception 'closure reason must contain between three and 240 characters';
  elsif exists (
    select 1
    from public.booking
    where booking_date between p_start_date and p_end_date
      and status in ('reserved', 'confirmed')
  ) then
    raise exception 'active bookings must be resolved before closing a date period';
  end if;

  select * into v_closure
  from public.full_day_closure_period
  where closure_start_date = p_start_date
    and closure_end_date = p_end_date
  for update;

  if found then
    update public.full_day_closure_period
    set reason = v_reason, created_by_user_id = p_actor_user_id
    where full_day_closure_period_id = v_closure.full_day_closure_period_id
    returning * into v_closure;
  else
    insert into public.full_day_closure_period (
      closure_start_date,
      closure_end_date,
      reason,
      created_by_user_id
    )
    values (p_start_date, p_end_date, v_reason, p_actor_user_id)
    returning * into v_closure;
  end if;

  return v_closure;
end;
$$;

create function public.remove_admin_time_block_closure(
  p_actor_user_id uuid,
  p_time_block_closure_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_admin(p_actor_user_id);

  delete from public.time_block_closure
  where time_block_closure_id = p_time_block_closure_id;

  return found;
end;
$$;

create function public.remove_admin_weekly_time_block_closure(
  p_actor_user_id uuid,
  p_weekly_time_block_closure_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_admin(p_actor_user_id);

  delete from public.weekly_time_block_closure
  where weekly_time_block_closure_id = p_weekly_time_block_closure_id;

  return found;
end;
$$;

create function public.remove_admin_full_day_closure_period(
  p_actor_user_id uuid,
  p_full_day_closure_period_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_admin(p_actor_user_id);

  delete from public.full_day_closure_period
  where full_day_closure_period_id = p_full_day_closure_period_id;

  return found;
end;
$$;

create function private.apply_discipline_rules(
  p_user_id uuid,
  p_violation_type public.discipline_violation_type,
  p_source_event_id uuid,
  p_occurred_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rule public.discipline_rule%rowtype;
  v_count integer;
  v_action_id uuid;
begin
  for v_rule in
    select *
    from public.discipline_rule
    where violation_type = p_violation_type and enabled
    order by occurrence_threshold
  loop
    if p_violation_type = 'absent' then
      select count(*) into v_count
      from public.booking
      where user_id = p_user_id
        and status = 'absent'
        and absent_at > p_occurred_at - make_interval(days => v_rule.window_days)
        and absent_at <= p_occurred_at;
    else
      select count(*) into v_count
      from public.user_warning
      where user_id = p_user_id
        and warning_type::text = p_violation_type::text
        and created_at > p_occurred_at - make_interval(days => v_rule.window_days)
        and created_at <= p_occurred_at;
    end if;

    if v_count <> v_rule.occurrence_threshold then
      continue;
    end if;

    insert into public.disciplinary_action (
      discipline_rule_id,
      user_id,
      source_event_id,
      violation_type,
      action_kind,
      occurrence_count
    )
    values (
      v_rule.discipline_rule_id,
      p_user_id,
      p_source_event_id,
      p_violation_type,
      v_rule.action_kind,
      v_count
    )
    on conflict (discipline_rule_id, source_event_id) do nothing
    returning disciplinary_action_id into v_action_id;

    if v_action_id is not null and v_rule.action_kind = 'disable' then
      update public.app_user
      set
        disabled_at = now(),
        disabled_reason = format('Sanción automática: %s en %s días.', p_violation_type, v_rule.window_days),
        disabled_by_user_id = null
      where user_id = p_user_id
        and role <> 'admin'
        and disabled_at is null;
    end if;
  end loop;
end;
$$;

create function private.apply_discipline_from_warning()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.apply_discipline_rules(
    new.user_id,
    new.warning_type::text::public.discipline_violation_type,
    new.user_warning_id,
    new.created_at
  );
  return new;
end;
$$;

create function private.apply_discipline_from_absence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.apply_discipline_rules(new.user_id, 'absent', new.booking_id, new.absent_at);
  return new;
end;
$$;

create trigger user_warning_apply_discipline
after insert on public.user_warning
for each row
execute function private.apply_discipline_from_warning();

create trigger booking_absence_apply_discipline
after update of status on public.booking
for each row
when (old.status is distinct from new.status and new.status = 'absent')
execute function private.apply_discipline_from_absence();

create function public.get_admin_discipline_rules(p_actor_user_id uuid)
returns setof public.discipline_rule
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_admin(p_actor_user_id);

  return query
  select *
  from public.discipline_rule
  order by violation_type, window_days, occurrence_threshold;
end;
$$;

create function public.upsert_admin_discipline_rule(
  p_actor_user_id uuid,
  p_violation_type public.discipline_violation_type,
  p_occurrence_threshold smallint,
  p_window_days smallint,
  p_action_kind public.discipline_action_kind
)
returns public.discipline_rule
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rule public.discipline_rule%rowtype;
begin
  perform private.require_current_admin(p_actor_user_id);

  if p_occurrence_threshold <= 0 then
    raise exception 'discipline threshold must be positive';
  elsif p_window_days not between 1 and 365 then
    raise exception 'discipline window must contain between one and 365 days';
  end if;

  insert into public.discipline_rule (
    violation_type,
    occurrence_threshold,
    window_days,
    action_kind,
    created_by_user_id,
    updated_by_user_id
  )
  values (
    p_violation_type,
    p_occurrence_threshold,
    p_window_days,
    p_action_kind,
    p_actor_user_id,
    p_actor_user_id
  )
  on conflict (violation_type, occurrence_threshold, window_days) do update
  set
    action_kind = excluded.action_kind,
    enabled = true,
    updated_by_user_id = excluded.updated_by_user_id
  returning * into v_rule;

  return v_rule;
end;
$$;

create function public.remove_admin_discipline_rule(
  p_actor_user_id uuid,
  p_discipline_rule_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_admin(p_actor_user_id);

  update public.discipline_rule
  set enabled = false, updated_by_user_id = p_actor_user_id
  where discipline_rule_id = p_discipline_rule_id;

  return found;
end;
$$;

create function public.search_admin_users(
  p_actor_user_id uuid,
  p_query text
)
returns table (
  user_id uuid,
  institutional_username text,
  user_name text,
  user_role public.app_role,
  allowed_time_block_id smallint,
  disabled_at timestamptz,
  disabled_reason text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_admin(p_actor_user_id);

  return query
  select
    candidate.user_id,
    candidate.institutional_username,
    candidate.user_name,
    candidate.user_role,
    candidate.allowed_time_block_id,
    candidate.disabled_at,
    candidate.disabled_reason
  from private.search_user_directory(p_query, true, null::public.app_role[], 15) as candidate;
end;
$$;

create function public.update_admin_user_access(
  p_actor_user_id uuid,
  p_target_user_id uuid,
  p_role public.app_role
)
returns public.app_user
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.app_user%rowtype;
begin
  perform private.require_current_admin(p_actor_user_id);

  if p_actor_user_id = p_target_user_id then
    raise exception 'an administrator cannot change their own access from this screen';
  end if;

  select * into v_target
  from public.app_user
  where user_id = p_target_user_id
  for update;

  if not found then
    raise exception 'target user not found';
  elsif v_target.role = 'admin' then
    raise exception 'administrator access cannot be changed from this screen';
  end if;

  update public.app_user
  set
    role = p_role,
    allowed_time_block_id = case when p_role = 'u_staff' then 7 else null end
  where user_id = p_target_user_id
  returning * into v_target;

  return v_target;
end;
$$;

create function public.disable_admin_user(
  p_actor_user_id uuid,
  p_target_user_id uuid,
  p_reason text
)
returns public.app_user
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.app_user%rowtype;
  v_reason text := trim(p_reason);
begin
  perform private.require_current_admin(p_actor_user_id);

  if p_actor_user_id = p_target_user_id then
    raise exception 'an administrator cannot disable their own account';
  elsif char_length(v_reason) not between 3 and 240 then
    raise exception 'the suspension reason must contain between three and 240 characters';
  end if;

  select * into v_target
  from public.app_user
  where user_id = p_target_user_id
  for update;

  if not found then
    raise exception 'target user not found';
  elsif v_target.role = 'admin' then
    raise exception 'administrator accounts cannot be disabled from this screen';
  end if;

  update public.app_user
  set
    disabled_at = now(),
    disabled_reason = v_reason,
    disabled_by_user_id = p_actor_user_id
  where user_id = p_target_user_id
  returning * into v_target;

  return v_target;
end;
$$;

create function public.restore_admin_user(
  p_actor_user_id uuid,
  p_target_user_id uuid
)
returns public.app_user
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.app_user%rowtype;
begin
  perform private.require_current_admin(p_actor_user_id);

  update public.app_user
  set disabled_at = null, disabled_reason = null, disabled_by_user_id = null
  where user_id = p_target_user_id
    and role <> 'admin'
  returning * into v_target;

  if not found then
    raise exception 'target user was not found or cannot be restored from this screen';
  end if;

  return v_target;
end;
$$;

-- Las tres exportaciones consultan una fotografía de perfil en el instante
-- operacional del registro. Nunca exponen HMAC, RUT ni correo completo.
create function private.get_profile_snapshot_at(
  p_user_id uuid,
  p_as_of timestamptz
)
returns table (
  date_of_birth date,
  reported_sex text,
  height_cm numeric,
  weight_kg numeric,
  academic_program_name text,
  career_entry_year smallint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    revision.date_of_birth,
    revision.reported_sex::text,
    revision.height_cm,
    revision.weight_kg,
    program.program_name,
    revision.career_entry_year
  from private.user_profile_revision as revision
  left join private.academic_program as program
    on program.academic_program_id = revision.academic_program_id
  where revision.user_id = p_user_id
    and revision.recorded_at <= p_as_of
  order by revision.recorded_at desc, revision.user_profile_revision_id desc
  limit 1;
$$;

create function private.assert_admin_export_range(
  p_start_date date,
  p_end_date date
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_start_date is null or p_end_date is null
    or p_end_date < p_start_date
    or p_end_date > p_start_date + 31 then
    raise exception 'export range must be between one and thirty-two days';
  end if;
end;
$$;

create function public.get_admin_booking_export(
  p_actor_user_id uuid,
  p_start_date date,
  p_end_date date
)
returns table (
  booking_date date,
  time_block_id smallint,
  block_starts_at timestamptz,
  block_ends_at timestamptz,
  participant_id uuid,
  participant_label text,
  user_role public.app_role,
  booking_status public.booking_status,
  admission_source public.booking_admission_source,
  is_overcapacity boolean,
  booked_at timestamptz,
  confirmed_at timestamptz,
  late_qr_authorized_at timestamptz,
  present_at timestamptz,
  absent_at timestamptz,
  cancelled_at timestamptz,
  qr_scanned_at timestamptz,
  warning_types text,
  date_of_birth date,
  reported_sex text,
  height_cm numeric,
  weight_kg numeric,
  academic_program_name text,
  career_entry_year smallint
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_admin(p_actor_user_id);
  perform private.assert_admin_export_range(p_start_date, p_end_date);

  return query
  select
    booking.booking_date,
    booking.time_block_id,
    private.block_starts_at(booking.booking_date, booking.time_block_id),
    private.block_ends_at(booking.booking_date, booking.time_block_id),
    app_user.user_id,
    app_user.user_name,
    app_user.role,
    booking.status,
    booking.admission_source,
    booking.is_overcapacity,
    booking.booked_at,
    booking.confirmed_at,
    booking.late_qr_authorized_at,
    booking.present_at,
    booking.absent_at,
    booking.cancelled_at,
    booking.qr_scanned_at,
    warnings.warning_types,
    profile.date_of_birth,
    profile.reported_sex,
    profile.height_cm,
    profile.weight_kg,
    profile.academic_program_name,
    profile.career_entry_year
  from public.booking as booking
  join public.app_user as app_user on app_user.user_id = booking.user_id
  left join lateral (
    select string_agg(warning.warning_type::text, '| ' order by warning.created_at) as warning_types
    from public.user_warning as warning
    where warning.booking_id = booking.booking_id
  ) as warnings on true
  left join lateral private.get_profile_snapshot_at(
    booking.user_id,
    private.block_starts_at(booking.booking_date, booking.time_block_id)
  ) as profile on true
  where booking.booking_date between p_start_date and p_end_date
  order by booking.booking_date, booking.time_block_id, app_user.user_name;
end;
$$;

create function public.get_admin_standalone_warning_export(
  p_actor_user_id uuid,
  p_start_date date,
  p_end_date date
)
returns table (
  warning_created_at timestamptz,
  participant_id uuid,
  participant_label text,
  user_role public.app_role,
  warning_type public.warning_type,
  date_of_birth date,
  reported_sex text,
  height_cm numeric,
  weight_kg numeric,
  academic_program_name text,
  career_entry_year smallint
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_admin(p_actor_user_id);
  perform private.assert_admin_export_range(p_start_date, p_end_date);

  return query
  select
    warning.created_at,
    app_user.user_id,
    app_user.user_name,
    app_user.role,
    warning.warning_type,
    profile.date_of_birth,
    profile.reported_sex,
    profile.height_cm,
    profile.weight_kg,
    profile.academic_program_name,
    profile.career_entry_year
  from public.user_warning as warning
  join public.app_user as app_user on app_user.user_id = warning.user_id
  left join lateral private.get_profile_snapshot_at(warning.user_id, warning.created_at) as profile on true
  where warning.booking_id is null
    and warning.created_at >= p_start_date::timestamp at time zone 'America/Santiago'
    and warning.created_at < (p_end_date + 1)::timestamp at time zone 'America/Santiago'
  order by warning.created_at, app_user.user_name;
end;
$$;

create function public.get_admin_disciplinary_action_export(
  p_actor_user_id uuid,
  p_start_date date,
  p_end_date date
)
returns table (
  applied_at timestamptz,
  participant_id uuid,
  participant_label text,
  user_role public.app_role,
  violation_type public.discipline_violation_type,
  action_kind public.discipline_action_kind,
  occurrence_count smallint,
  date_of_birth date,
  reported_sex text,
  height_cm numeric,
  weight_kg numeric,
  academic_program_name text,
  career_entry_year smallint
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_admin(p_actor_user_id);
  perform private.assert_admin_export_range(p_start_date, p_end_date);

  return query
  select
    action.applied_at,
    app_user.user_id,
    app_user.user_name,
    app_user.role,
    action.violation_type,
    action.action_kind,
    action.occurrence_count,
    profile.date_of_birth,
    profile.reported_sex,
    profile.height_cm,
    profile.weight_kg,
    profile.academic_program_name,
    profile.career_entry_year
  from public.disciplinary_action as action
  join public.app_user as app_user on app_user.user_id = action.user_id
  left join lateral private.get_profile_snapshot_at(action.user_id, action.applied_at) as profile on true
  where action.applied_at >= p_start_date::timestamp at time zone 'America/Santiago'
    and action.applied_at < (p_end_date + 1)::timestamp at time zone 'America/Santiago'
  order by action.applied_at, app_user.user_name;
end;
$$;

revoke all on function private.assert_open_time_block_for_booking() from public, anon, authenticated;
revoke all on function private.require_unreserved_time_block_closure(date, smallint) from public, anon, authenticated;
revoke all on function private.apply_discipline_rules(uuid, public.discipline_violation_type, uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.apply_discipline_from_warning() from public, anon, authenticated;
revoke all on function private.apply_discipline_from_absence() from public, anon, authenticated;
revoke all on function private.get_profile_snapshot_at(uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.assert_admin_export_range(date, date) from public, anon, authenticated;
revoke all on function public.get_booking_closure_reasons(uuid, date, date) from public, anon, authenticated;
revoke all on function public.get_admin_configuration(uuid) from public, anon, authenticated;
revoke all on function public.update_admin_operational_settings(uuid, smallint, smallint) from public, anon, authenticated;
revoke all on function public.upsert_admin_date_time_block_closure(uuid, smallint, date, text) from public, anon, authenticated;
revoke all on function public.upsert_admin_weekly_time_block_closure(uuid, smallint, smallint, text) from public, anon, authenticated;
revoke all on function public.upsert_admin_full_day_closure_period(uuid, date, date, text) from public, anon, authenticated;
revoke all on function public.remove_admin_time_block_closure(uuid, uuid) from public, anon, authenticated;
revoke all on function public.remove_admin_weekly_time_block_closure(uuid, uuid) from public, anon, authenticated;
revoke all on function public.remove_admin_full_day_closure_period(uuid, uuid) from public, anon, authenticated;
revoke all on function public.get_admin_discipline_rules(uuid) from public, anon, authenticated;
revoke all on function public.upsert_admin_discipline_rule(uuid, public.discipline_violation_type, smallint, smallint, public.discipline_action_kind) from public, anon, authenticated;
revoke all on function public.remove_admin_discipline_rule(uuid, uuid) from public, anon, authenticated;
revoke all on function public.search_admin_users(uuid, text) from public, anon, authenticated;
revoke all on function public.update_admin_user_access(uuid, uuid, public.app_role) from public, anon, authenticated;
revoke all on function public.disable_admin_user(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.restore_admin_user(uuid, uuid) from public, anon, authenticated;
revoke all on function public.get_admin_booking_export(uuid, date, date) from public, anon, authenticated;
revoke all on function public.get_admin_standalone_warning_export(uuid, date, date) from public, anon, authenticated;
revoke all on function public.get_admin_disciplinary_action_export(uuid, date, date) from public, anon, authenticated;

grant execute on function public.get_booking_closure_reasons(uuid, date, date) to service_role;
grant execute on function public.get_admin_configuration(uuid) to service_role;
grant execute on function public.update_admin_operational_settings(uuid, smallint, smallint) to service_role;
grant execute on function public.upsert_admin_date_time_block_closure(uuid, smallint, date, text) to service_role;
grant execute on function public.upsert_admin_weekly_time_block_closure(uuid, smallint, smallint, text) to service_role;
grant execute on function public.upsert_admin_full_day_closure_period(uuid, date, date, text) to service_role;
grant execute on function public.remove_admin_time_block_closure(uuid, uuid) to service_role;
grant execute on function public.remove_admin_weekly_time_block_closure(uuid, uuid) to service_role;
grant execute on function public.remove_admin_full_day_closure_period(uuid, uuid) to service_role;
grant execute on function public.get_admin_discipline_rules(uuid) to service_role;
grant execute on function public.upsert_admin_discipline_rule(uuid, public.discipline_violation_type, smallint, smallint, public.discipline_action_kind) to service_role;
grant execute on function public.remove_admin_discipline_rule(uuid, uuid) to service_role;
grant execute on function public.search_admin_users(uuid, text) to service_role;
grant execute on function public.update_admin_user_access(uuid, uuid, public.app_role) to service_role;
grant execute on function public.disable_admin_user(uuid, uuid, text) to service_role;
grant execute on function public.restore_admin_user(uuid, uuid) to service_role;
grant execute on function public.get_admin_booking_export(uuid, date, date) to service_role;
grant execute on function public.get_admin_standalone_warning_export(uuid, date, date) to service_role;
grant execute on function public.get_admin_disciplinary_action_export(uuid, date, date) to service_role;


-- ============================================================================
-- Source: docs/database/v2-content-draft.sql
-- ============================================================================

-- Draft v2: autoridad persistente de rutinas y noticias.
-- Requiere schema y authority. Las rutas siguen sin conexión hasta que se
-- escriban sus Route Handlers sobre estas RPCs.

create function private.require_current_routine_editor(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.app_user
    where app_user.user_id = p_user_id
      and app_user.role in ('gym_staff', 'admin')
      and app_user.disabled_at is null
      and app_user.regulation_accepted_at is not null
  ) then
    raise exception 'gym staff access with regulation acceptance is required to edit routines';
  end if;
end;
$$;

-- Selector común de destinatarios de rutina. Solo los roles que pueden recibir
-- una rutina aparecen; la asignación vuelve a validar el destinatario para no
-- depender de esta consulta de conveniencia.
create function public.search_routine_assignment_recipients(
  p_actor_user_id uuid,
  p_query text
)
returns table (
  user_id uuid,
  user_name text,
  institutional_username text,
  user_role public.app_role
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_routine_editor(p_actor_user_id);

  return query
  select
    candidate.user_id,
    candidate.user_name,
    candidate.institutional_username,
    candidate.user_role
  from private.search_user_directory(
    p_query,
    false,
    array['student', 'u_staff']::public.app_role[],
    15
  ) as candidate;
end;
$$;

create function private.replace_routine_plan_exercises(
  p_routine_plan_id uuid,
  p_items jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item_count integer;
begin
  if jsonb_typeof(p_items) <> 'array' then
    raise exception 'routine exercises must be an array';
  end if;

  v_item_count := jsonb_array_length(p_items);
  if v_item_count > 30 then
    raise exception 'a routine may contain at most thirty exercises';
  end if;

  delete from private.routine_plan_exercise
  where routine_plan_id = p_routine_plan_id;

  insert into private.routine_plan_exercise (
    routine_plan_id,
    exercise_key,
    display_order,
    total_sets,
    effective_sets,
    repetitions_min,
    repetitions_max,
    load_kg,
    rir,
    rest_seconds,
    observations
  )
  select
    p_routine_plan_id,
    item.exercise_key,
    item.display_order,
    item.total_sets,
    item.effective_sets,
    item.repetitions_min,
    item.repetitions_max,
    item.load_kg,
    item.rir,
    item.rest_seconds,
    nullif(trim(item.observations), '')
  from jsonb_to_recordset(p_items) as item(
    exercise_key text,
    display_order smallint,
    total_sets smallint,
    effective_sets smallint,
    repetitions_min smallint,
    repetitions_max smallint,
    load_kg numeric(5, 2),
    rir smallint,
    rest_seconds smallint,
    observations text
  )
  join private.exercise_catalog as catalog
    on catalog.exercise_key = item.exercise_key
    and catalog.is_active;

  if (select count(*) from private.routine_plan_exercise where routine_plan_id = p_routine_plan_id)
    <> v_item_count then
    raise exception 'routine contains an unknown or inactive exercise';
  end if;
end;
$$;

create function public.save_routine_template_draft(
  p_actor_user_id uuid,
  p_routine_plan_id uuid,
  p_title text,
  p_exercises jsonb
)
returns private.routine_plan
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_plan private.routine_plan%rowtype;
  v_title text := trim(p_title);
begin
  perform private.require_current_routine_editor(p_actor_user_id);

  if char_length(v_title) not between 3 and 160 then
    raise exception 'routine title must contain between three and 160 characters';
  end if;

  if p_routine_plan_id is null then
    insert into private.routine_plan (
      kind,
      status,
      title,
      created_by_user_id,
      updated_by_user_id
    )
    values ('template', 'draft', v_title, p_actor_user_id, p_actor_user_id)
    returning * into v_plan;
  else
    select * into v_plan
    from private.routine_plan
    where routine_plan_id = p_routine_plan_id
      and kind = 'template'
      and status = 'draft'
    for update;

    if not found then
      raise exception 'editable routine template was not found';
    end if;

    update private.routine_plan
    set title = v_title, updated_by_user_id = p_actor_user_id
    where routine_plan_id = v_plan.routine_plan_id
    returning * into v_plan;
  end if;

  perform private.replace_routine_plan_exercises(v_plan.routine_plan_id, p_exercises);
  return v_plan;
end;
$$;

create function public.assign_routine_template(
  p_actor_user_id uuid,
  p_template_routine_plan_id uuid,
  p_recipient_user_id uuid,
  p_title text
)
returns private.routine_plan
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_template private.routine_plan%rowtype;
  v_assignment private.routine_plan%rowtype;
  v_title text := trim(p_title);
begin
  perform private.require_current_routine_editor(p_actor_user_id);

  if char_length(v_title) not between 3 and 160 then
    raise exception 'routine title must contain between three and 160 characters';
  end if;

  select * into v_template
  from private.routine_plan
  where routine_plan_id = p_template_routine_plan_id
    and kind = 'template'
    and status = 'draft'
  for share;

  if not found then
    raise exception 'assignable routine template was not found';
  end if;

  if not exists (
    select 1
    from public.app_user
    where user_id = p_recipient_user_id
      and role in ('student', 'u_staff')
      and disabled_at is null
  ) then
    raise exception 'routine recipient must be an active student or university staff user';
  end if;

  insert into private.routine_plan (
    kind,
    status,
    title,
    recipient_user_id,
    source_template_id,
    created_by_user_id,
    updated_by_user_id,
    assigned_at
  )
  values (
    'assignment',
    'assigned',
    v_title,
    p_recipient_user_id,
    v_template.routine_plan_id,
    p_actor_user_id,
    p_actor_user_id,
    now()
  )
  returning * into v_assignment;

  insert into private.routine_plan_exercise (
    routine_plan_id,
    exercise_key,
    display_order,
    total_sets,
    effective_sets,
    repetitions_min,
    repetitions_max,
    load_kg,
    rir,
    rest_seconds,
    observations
  )
  select
    v_assignment.routine_plan_id,
    exercise_key,
    display_order,
    total_sets,
    effective_sets,
    repetitions_min,
    repetitions_max,
    load_kg,
    rir,
    rest_seconds,
    observations
  from private.routine_plan_exercise
  where routine_plan_id = v_template.routine_plan_id
  order by display_order;

  return v_assignment;
end;
$$;

create function public.update_assigned_routine(
  p_actor_user_id uuid,
  p_routine_plan_id uuid,
  p_title text,
  p_exercises jsonb
)
returns private.routine_plan
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment private.routine_plan%rowtype;
  v_title text := trim(p_title);
begin
  perform private.require_current_routine_editor(p_actor_user_id);

  if char_length(v_title) not between 3 and 160 then
    raise exception 'routine title must contain between three and 160 characters';
  end if;

  select * into v_assignment
  from private.routine_plan
  where routine_plan_id = p_routine_plan_id
    and kind = 'assignment'
    and status = 'assigned'
  for update;

  if not found then
    raise exception 'assigned routine was not found';
  end if;

  update private.routine_plan
  set title = v_title, updated_by_user_id = p_actor_user_id
  where routine_plan_id = v_assignment.routine_plan_id
  returning * into v_assignment;

  perform private.replace_routine_plan_exercises(v_assignment.routine_plan_id, p_exercises);
  return v_assignment;
end;
$$;

create function public.get_own_routine_assignments()
returns table (
  routine_plan_id uuid,
  title text,
  assigned_at timestamptz,
  created_by_name text,
  exercises jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  perform private.require_active_user(v_user_id);

  return query
  select
    plan.routine_plan_id,
    plan.title,
    plan.assigned_at,
    creator.user_name,
    coalesce(jsonb_agg(jsonb_build_object(
      'exerciseKey', item.exercise_key,
      'name', catalog.exercise_name,
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
  left join private.routine_plan_exercise as item on item.routine_plan_id = plan.routine_plan_id
  left join private.exercise_catalog as catalog on catalog.exercise_key = item.exercise_key
  where plan.kind = 'assignment'
    and plan.status = 'assigned'
    and plan.recipient_user_id = v_user_id
  group by plan.routine_plan_id, plan.title, plan.assigned_at, creator.user_name
  order by plan.assigned_at desc;
end;
$$;

create function private.require_current_news_editor(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_admin(p_user_id);
end;
$$;

create function public.create_admin_news_item_draft(
  p_actor_user_id uuid,
  p_caption text
)
returns public.news_item
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.news_item%rowtype;
  v_caption text := trim(p_caption);
  v_news_item_id uuid := gen_random_uuid();
begin
  perform private.require_current_news_editor(p_actor_user_id);

  if char_length(v_caption) not between 3 and 500 then
    raise exception 'news caption must contain between three and 500 characters';
  end if;

  insert into public.news_item (
    news_item_id,
    caption,
    storage_path,
    created_by_user_id
  )
  values (
    v_news_item_id,
    v_caption,
    'news/' || v_news_item_id::text || '.webp',
    p_actor_user_id
  )
  returning * into v_item;

  return v_item;
end;
$$;

create function public.publish_admin_news_item(
  p_actor_user_id uuid,
  p_news_item_id uuid
)
returns public.news_item
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.news_item%rowtype;
begin
  perform private.require_current_news_editor(p_actor_user_id);

  select * into v_item
  from public.news_item
  where news_item_id = p_news_item_id
  for update;

  if not found then
    raise exception 'news item was not found';
  elsif v_item.status <> 'draft' then
    raise exception 'only a draft news item can be published';
  elsif not exists (
    select 1
    from storage.objects
    where bucket_id = 'gymu-news' and name = v_item.storage_path
  ) then
    raise exception 'news image has not been uploaded';
  end if;

  update public.news_item
  set status = 'published', published_at = now(), withdrawn_at = null
  where news_item_id = v_item.news_item_id
  returning * into v_item;

  return v_item;
end;
$$;

create function public.withdraw_admin_news_item(
  p_actor_user_id uuid,
  p_news_item_id uuid
)
returns public.news_item
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.news_item%rowtype;
begin
  perform private.require_current_news_editor(p_actor_user_id);

  update public.news_item
  set status = 'withdrawn', withdrawn_at = now()
  where news_item_id = p_news_item_id
    and status = 'published'
  returning * into v_item;

  if not found then
    raise exception 'published news item was not found';
  end if;

  return v_item;
end;
$$;

create function public.delete_admin_news_item(
  p_actor_user_id uuid,
  p_news_item_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_storage_path text;
begin
  perform private.require_current_news_editor(p_actor_user_id);

  delete from public.news_item
  where news_item_id = p_news_item_id
    and status in ('draft', 'withdrawn')
  returning storage_path into v_storage_path;

  if v_storage_path is null then
    raise exception 'only draft or withdrawn news items can be deleted';
  end if;

  return v_storage_path;
end;
$$;

create function public.get_published_news_feed()
returns table (
  news_item_id uuid,
  caption text,
  storage_path text,
  published_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  perform private.require_active_user(v_user_id);

  return query
  select item.news_item_id, item.caption, item.storage_path, item.published_at
  from public.news_item as item
  where item.status = 'published'
    and item.withdrawn_at is null
  order by item.published_at desc;
end;
$$;

revoke all on function private.require_current_routine_editor(uuid) from public, anon, authenticated;
revoke all on function private.replace_routine_plan_exercises(uuid, jsonb) from public, anon, authenticated;
revoke all on function private.require_current_news_editor(uuid) from public, anon, authenticated;
revoke all on function public.save_routine_template_draft(uuid, uuid, text, jsonb) from public, anon, authenticated;
revoke all on function public.search_routine_assignment_recipients(uuid, text) from public, anon, authenticated;
revoke all on function public.assign_routine_template(uuid, uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.update_assigned_routine(uuid, uuid, text, jsonb) from public, anon, authenticated;
revoke all on function public.get_own_routine_assignments() from public, anon;
revoke all on function public.create_admin_news_item_draft(uuid, text) from public, anon, authenticated;
revoke all on function public.publish_admin_news_item(uuid, uuid) from public, anon, authenticated;
revoke all on function public.withdraw_admin_news_item(uuid, uuid) from public, anon, authenticated;
revoke all on function public.delete_admin_news_item(uuid, uuid) from public, anon, authenticated;
revoke all on function public.get_published_news_feed() from public, anon;

grant execute on function public.get_own_routine_assignments() to authenticated;
grant execute on function public.get_published_news_feed() to authenticated;
grant execute on function public.save_routine_template_draft(uuid, uuid, text, jsonb) to service_role;
grant execute on function public.search_routine_assignment_recipients(uuid, text) to service_role;
grant execute on function public.assign_routine_template(uuid, uuid, uuid, text) to service_role;
grant execute on function public.update_assigned_routine(uuid, uuid, text, jsonb) to service_role;
grant execute on function public.create_admin_news_item_draft(uuid, text) to service_role;
grant execute on function public.publish_admin_news_item(uuid, uuid) to service_role;
grant execute on function public.withdraw_admin_news_item(uuid, uuid) to service_role;
grant execute on function public.delete_admin_news_item(uuid, uuid) to service_role;


-- ============================================================================
-- Source: docs/database/v2-research-catalog-draft.sql
-- ============================================================================

-- Draft v2: catálogo fiel de la hoja Bateria de DEFIDER.
-- A1 y A2 se excluyen: nombre y RUN ya tienen una fuente de identidad separada.
-- Ninguna pregunta se habilita para campañas al iniciar el proyecto.

insert into private.research_question_catalog (
  question_key,
  source_code,
  section_key,
  response_kind,
  prompt,
  validation,
  is_campaign_selectable,
  sets_preventive_attention,
  is_derived,
  formula_description
)
values
  ('birth_date', 'A3', 'administration', 'date', 'Fecha de nacimiento', '{}', false, false, false, null),
  ('declared_sex', 'A4', 'administration', 'single_choice', 'Sexo', '{}', false, false, false, null),
  ('institutional_relationship', 'A5', 'administration', 'single_choice', 'Vínculo institucional', '{}', false, false, false, null),
  ('contact_phone', 'A6', 'administration', 'short_text', 'Teléfono de contacto', '{}', false, false, false, null),
  ('emergency_contact_name', 'A7', 'administration', 'short_text', 'Contacto de emergencia: nombre completo', '{}', false, false, false, null),
  ('emergency_contact_phone', 'A8', 'administration', 'short_text', 'Contacto de emergencia: teléfono', '{}', false, false, false, null),
  ('height_cm', 'B1', 'initial_assessment', 'decimal', 'Estatura en cm', '{"minimum":120,"maximum":230}', false, false, false, null),
  ('weight_kg', 'B2', 'initial_assessment', 'decimal', 'Masa corporal en kg', '{"minimum":35,"maximum":300}', false, false, false, null),
  ('waist_circumference_cm', 'B8', 'initial_assessment', 'decimal', 'Perímetro de cintura en cm, protocolo ISAK', '{}', false, false, false, null),
  ('initial_assessment_date', 'B9', 'initial_assessment', 'date', 'Fecha de la evaluación inicial', '{}', false, false, false, null),
  ('assessment_recorded_by', 'B10', 'initial_assessment', 'derived', 'Profesional que registra', '{}', false, false, true, 'Se deriva del actor institucional que registra la evaluación.'),
  ('strength_training_history', 'C1', 'strength_experience', 'single_choice', '¿Ha entrenado con sobrecarga anteriormente?', '{}', false, false, false, null),
  ('strength_training_months', 'C2', 'strength_experience', 'single_choice', 'Meses acumulados de práctica con sobrecarga', '{}', false, false, false, null),
  ('sustained_weekly_strength_frequency', 'C3', 'strength_experience', 'single_choice', 'Frecuencia semanal máxima que logró sostener al menos tres meses', '{}', false, false, false, null),
  ('technical_familiarity_squat', 'C4_1', 'strength_experience', 'single_choice', 'Familiaridad técnica: sentadilla', '{}', false, false, false, null),
  ('technical_familiarity_deadlift', 'C4_2', 'strength_experience', 'single_choice', 'Familiaridad técnica: peso muerto', '{}', false, false, false, null),
  ('technical_familiarity_bench_press', 'C4_3', 'strength_experience', 'single_choice', 'Familiaridad técnica: press de banca', '{}', false, false, false, null),
  ('technical_familiarity_overhead_press', 'C4_4', 'strength_experience', 'single_choice', 'Familiaridad técnica: press militar', '{}', false, false, false, null),
  ('technical_familiarity_row', 'C4_5', 'strength_experience', 'single_choice', 'Familiaridad técnica: remo', '{}', false, false, false, null),
  ('technical_familiarity_pull_up', 'C4_6', 'strength_experience', 'single_choice', 'Familiaridad técnica: dominada', '{}', false, false, false, null),
  ('structured_program_history', 'C5', 'strength_experience', 'single_choice', '¿Ha seguido programas estructurados?', '{}', false, false, false, null),
  ('rir_rpe_familiarity', 'C6', 'strength_experience', 'single_choice', '¿Conoce y utiliza la escala RIR/RPE para regular la intensidad?', '{}', false, false, false, null),
  ('pain_shoulder', 'C7_1', 'strength_experience', 'boolean', 'Molestia o lesión activa: hombro', '{}', false, false, false, null),
  ('pain_elbow_wrist', 'C7_2', 'strength_experience', 'boolean', 'Molestia o lesión activa: codo o muñeca', '{}', false, false, false, null),
  ('pain_cervical_spine', 'C7_3', 'strength_experience', 'boolean', 'Molestia o lesión activa: columna cervical', '{}', false, false, false, null),
  ('pain_lumbar_spine', 'C7_4', 'strength_experience', 'boolean', 'Molestia o lesión activa: columna lumbar', '{}', false, false, false, null),
  ('pain_hip', 'C7_5', 'strength_experience', 'boolean', 'Molestia o lesión activa: cadera', '{}', false, false, false, null),
  ('pain_knee', 'C7_6', 'strength_experience', 'boolean', 'Molestia o lesión activa: rodilla', '{}', false, false, false, null),
  ('pain_ankle_foot', 'C7_7', 'strength_experience', 'boolean', 'Molestia o lesión activa: tobillo o pie', '{}', false, false, false, null),
  ('pain_intensity_eva', 'C8', 'strength_experience', 'integer', 'Intensidad del dolor durante la última semana, EVA', '{"minimum":0,"maximum":10}', false, false, false, null),
  ('primary_goal', 'D1', 'goals', 'single_choice', 'Objetivo principal', '{}', false, false, false, null),
  ('secondary_goal_hypertrophy', 'D2_1', 'goals', 'boolean', 'Objetivo secundario: hipertrofia muscular', '{"selectionGroup":"secondary_goals","maximumSelected":2}', false, false, false, null),
  ('secondary_goal_strength', 'D2_2', 'goals', 'boolean', 'Objetivo secundario: fuerza máxima', '{"selectionGroup":"secondary_goals","maximumSelected":2}', false, false, false, null),
  ('secondary_goal_fat_reduction', 'D2_3', 'goals', 'boolean', 'Objetivo secundario: reducción de masa grasa', '{"selectionGroup":"secondary_goals","maximumSelected":2}', false, false, false, null),
  ('secondary_goal_general_health', 'D2_4', 'goals', 'boolean', 'Objetivo secundario: salud general y acondicionamiento', '{"selectionGroup":"secondary_goals","maximumSelected":2}', false, false, false, null),
  ('secondary_goal_sport_performance', 'D2_5', 'goals', 'boolean', 'Objetivo secundario: rendimiento en un deporte específico', '{"selectionGroup":"secondary_goals","maximumSelected":2}', false, false, false, null),
  ('secondary_goal_post_injury', 'D2_6', 'goals', 'boolean', 'Objetivo secundario: reacondicionamiento post-lesión', '{"selectionGroup":"secondary_goals","maximumSelected":2}', false, false, false, null),
  ('goal_time_horizon', 'D3', 'goals', 'single_choice', 'Horizonte temporal en que espera resultados', '{}', false, false, false, null),
  ('competitive_sport', 'D4', 'goals', 'single_choice', '¿Practica algún deporte con competencia?', '{}', false, false, false, null),
  ('competitive_sport_name', 'D5', 'goals', 'short_text', 'Deporte que practica con competencia', '{}', false, false, false, null),
  ('weekly_vigorous_activity', 'E1', 'physical_activity', 'integer', 'Ejercicio vigoroso por semana', '{"minimum":0}', false, false, false, null),
  ('weekly_moderate_activity', 'E2', 'physical_activity', 'integer', 'Ejercicio moderado por semana', '{"minimum":0}', false, false, false, null),
  ('weekly_light_activity', 'E3', 'physical_activity', 'integer', 'Ejercicio leve por semana', '{"minimum":0}', false, false, false, null),
  ('godin_total_score', 'E4', 'physical_activity', 'derived', 'Puntaje total Godin', '{}', false, false, true, '9 × vigoroso + 5 × moderado + 3 × leve.'),
  ('godin_classification', 'E5', 'physical_activity', 'derived', 'Clasificación Godin', '{}', false, false, true, 'Activo desde 24; moderadamente activo desde 14; insuficientemente activo bajo 14.'),
  ('daily_sedentary_hours', 'E6', 'physical_activity', 'single_choice', 'Horas diarias sentado/a en un día laboral', '{}', false, false, false, null),
  ('sleep_duration', 'F1', 'recovery_habits', 'single_choice', 'Horas de sueño en una noche habitual', '{}', false, false, false, null),
  ('sleep_quality', 'F2', 'recovery_habits', 'single_choice', 'Calidad de sueño percibida', '{}', false, false, false, null),
  ('daily_main_meals', 'F3', 'recovery_habits', 'single_choice', 'Comidas principales al día', '{}', false, false, false, null),
  ('supplement_protein', 'F4_1', 'recovery_habits', 'boolean', 'Consume actualmente proteína en polvo', '{}', false, false, false, null),
  ('supplement_creatine', 'F4_2', 'recovery_habits', 'boolean', 'Consume actualmente creatina', '{}', false, false, false, null),
  ('supplement_caffeine_preworkout', 'F4_3', 'recovery_habits', 'boolean', 'Consume actualmente cafeína o pre-entreno', '{}', false, false, false, null),
  ('supplement_multivitamin', 'F4_4', 'recovery_habits', 'boolean', 'Consume actualmente multivitamínico', '{}', false, false, false, null),
  ('supplement_other', 'F4_5', 'recovery_habits', 'boolean', 'Consume actualmente otro suplemento', '{}', false, false, false, null),
  ('supplement_other_detail', 'F5', 'recovery_habits', 'short_text', 'Otro suplemento que consume actualmente', '{}', false, false, false, null),
  ('tobacco_or_vaping', 'F6', 'recovery_habits', 'single_choice', 'Consumo de tabaco o vapeo', '{}', false, false, false, null),
  ('alcohol_frequency', 'F7', 'recovery_habits', 'single_choice', 'Frecuencia de consumo de alcohol', '{}', false, false, false, null),
  ('professional_nutrition_guidance', 'F8', 'recovery_habits', 'single_choice', '¿Ha recibido orientación nutricional profesional?', '{}', false, false, false, null),
  ('availability_monday', 'G1_1', 'availability', 'boolean', 'Disponibilidad para asistir: lunes', '{}', false, false, false, null),
  ('availability_tuesday', 'G1_2', 'availability', 'boolean', 'Disponibilidad para asistir: martes', '{}', false, false, false, null),
  ('availability_wednesday', 'G1_3', 'availability', 'boolean', 'Disponibilidad para asistir: miércoles', '{}', false, false, false, null),
  ('availability_thursday', 'G1_4', 'availability', 'boolean', 'Disponibilidad para asistir: jueves', '{}', false, false, false, null),
  ('availability_friday', 'G1_5', 'availability', 'boolean', 'Disponibilidad para asistir: viernes', '{}', false, false, false, null),
  ('availability_saturday', 'G1_6', 'availability', 'boolean', 'Disponibilidad para asistir: sábado', '{}', false, false, false, null),
  ('availability_sunday', 'G1_7', 'availability', 'boolean', 'Disponibilidad para asistir: domingo', '{}', false, false, false, null),
  ('availability_day_count', 'G1c', 'availability', 'derived', 'Total de días disponibles marcados', '{}', false, false, true, 'Conteo de respuestas afirmativas entre G1_1 y G1_7.'),
  ('attendance_barrier_time', 'H1_1', 'adherence', 'boolean', 'Barrera percibida: falta de tiempo', '{"selectionGroup":"attendance_barriers","maximumSelected":3}', false, false, false, null),
  ('attendance_barrier_technical_knowledge', 'H1_2', 'adherence', 'boolean', 'Barrera percibida: desconocimiento técnico', '{"selectionGroup":"attendance_barriers","maximumSelected":3}', false, false, false, null),
  ('attendance_barrier_pain_injury', 'H1_3', 'adherence', 'boolean', 'Barrera percibida: dolor o lesión', '{"selectionGroup":"attendance_barriers","maximumSelected":3}', false, false, false, null),
  ('attendance_barrier_motivation', 'H1_4', 'adherence', 'boolean', 'Barrera percibida: falta de motivación', '{"selectionGroup":"attendance_barriers","maximumSelected":3}', false, false, false, null),
  ('attendance_barrier_gym_hours', 'H1_5', 'adherence', 'boolean', 'Barrera percibida: horarios de la sala', '{"selectionGroup":"attendance_barriers","maximumSelected":3}', false, false, false, null),
  ('attendance_barrier_discomfort', 'H1_6', 'adherence', 'boolean', 'Barrera percibida: incomodidad o inseguridad frente a otras personas', '{"selectionGroup":"attendance_barriers","maximumSelected":3}', false, false, false, null),
  ('attendance_barrier_none', 'H1_7', 'adherence', 'boolean', 'Barrera percibida: ninguna', '{"selectionGroup":"attendance_barriers","maximumSelected":3}', false, false, false, null),
  ('attendance_barrier_count', 'H1c', 'adherence', 'derived', 'Número de barreras marcadas', '{}', false, false, true, 'Conteo de respuestas afirmativas entre H1_1 y H1_7; el formulario fuente limita el máximo a tres.'),
  ('attendance_confidence', 'H2', 'adherence', 'integer', 'Confianza en asistir tres veces por semana durante los próximos tres meses', '{"minimum":0,"maximum":10}', false, false, false, null),
  ('anonymous_research_authorization', 'I1', 'declarations', 'boolean', 'Autoriza el uso de datos anonimizados con fines estadísticos e investigación institucional', '{}', false, false, false, null),
  ('photo_audiovisual_authorization', 'I2', 'declarations', 'boolean', 'Autoriza el registro fotográfico o audiovisual durante las sesiones', '{}', false, false, false, null),
  ('battery_application_date', 'I3', 'declarations', 'derived', 'Fecha de aplicación de esta batería', '{}', false, false, true, 'Se deriva del instante de envío de la batería.');

-- Opciones de menú de la hoja Listas. Las preguntas booleanas usan true/false
-- y por ello no tienen filas de opción.
with option_template as (
  select *
  from (
    values
      ('declared_sex', 'hombre', 'Hombre', 1),
      ('declared_sex', 'mujer', 'Mujer', 2),
      ('declared_sex', 'prefiero_no_responder', 'Prefiero no responder', 3),
      ('institutional_relationship', 'estudiante_pregrado', 'Estudiante pregrado', 1),
      ('institutional_relationship', 'estudiante_postgrado', 'Estudiante postgrado', 2),
      ('institutional_relationship', 'academico', 'Académico/a', 3),
      ('institutional_relationship', 'funcionario', 'Funcionario/a', 4),
      ('institutional_relationship', 'externo', 'Externo/a', 5),
      ('strength_training_history', 'nunca', 'Nunca', 1),
      ('strength_training_history', 'mas_de_12_meses', 'Sí, hace más de 12 meses', 2),
      ('strength_training_history', 'ultimos_12_meses_intermitente', 'Sí, en los últimos 12 meses de forma intermitente', 3),
      ('strength_training_history', 'continuo_actual', 'Sí, de forma continua hasta hoy', 4),
      ('strength_training_months', 'menos_de_1', 'Menos de 1', 1),
      ('strength_training_months', 'uno_a_seis', '1 a 6', 2),
      ('strength_training_months', 'siete_a_doce', '7 a 12', 3),
      ('strength_training_months', 'trece_a_veinticuatro', '13 a 24', 4),
      ('strength_training_months', 'mas_de_veinticuatro', 'Más de 24', 5),
      ('sustained_weekly_strength_frequency', 'one', '1', 1),
      ('sustained_weekly_strength_frequency', 'two', '2', 2),
      ('sustained_weekly_strength_frequency', 'three', '3', 3),
      ('sustained_weekly_strength_frequency', 'four', '4', 4),
      ('sustained_weekly_strength_frequency', 'five_or_more', '5 o más', 5),
      ('sustained_weekly_strength_frequency', 'never_three_months', 'Nunca sostuvo 3 meses', 6),
      ('structured_program_history', 'usual', 'Sí, habitualmente', 1),
      ('structured_program_history', 'occasional', 'Sí, ocasionalmente', 2),
      ('structured_program_history', 'known_unused', 'Los conozco pero no los he usado', 3),
      ('structured_program_history', 'unknown', 'No los conozco', 4),
      ('rir_rpe_familiarity', 'regular_use', 'La uso regularmente', 1),
      ('rir_rpe_familiarity', 'known_not_used', 'La conozco pero no la uso', 2),
      ('rir_rpe_familiarity', 'unknown', 'No la conozco', 3),
      ('primary_goal', 'hypertrophy', 'Hipertrofia muscular', 1),
      ('primary_goal', 'maximum_strength', 'Fuerza máxima', 2),
      ('primary_goal', 'fat_reduction', 'Reducción de masa grasa', 3),
      ('primary_goal', 'general_health', 'Salud general y acondicionamiento', 4),
      ('primary_goal', 'sport_performance', 'Rendimiento en un deporte específico', 5),
      ('primary_goal', 'post_injury', 'Reacondicionamiento post-lesión', 6),
      ('goal_time_horizon', 'under_three_months', 'Menos de 3 meses', 1),
      ('goal_time_horizon', 'three_to_six_months', '3 a 6 meses', 2),
      ('goal_time_horizon', 'six_to_twelve_months', '6 a 12 meses', 3),
      ('goal_time_horizon', 'more_than_twelve_months', 'Más de 12 meses', 4),
      ('competitive_sport', 'no', 'No', 1),
      ('competitive_sport', 'recreational', 'Sí, recreativo', 2),
      ('competitive_sport', 'federated_university', 'Sí, federado o universitario', 3),
      ('competitive_sport', 'national_team', 'Sí, selección nacional', 4),
      ('daily_sedentary_hours', 'under_four', 'Menos de 4', 1),
      ('daily_sedentary_hours', 'four_to_six', '4 a 6', 2),
      ('daily_sedentary_hours', 'six_to_eight', '6 a 8', 3),
      ('daily_sedentary_hours', 'over_eight', 'Más de 8', 4),
      ('sleep_duration', 'under_five', 'Menos de 5', 1),
      ('sleep_duration', 'five_to_six', '5 a 6', 2),
      ('sleep_duration', 'six_to_seven', '6 a 7', 3),
      ('sleep_duration', 'seven_to_eight', '7 a 8', 4),
      ('sleep_duration', 'over_eight', 'Más de 8', 5),
      ('sleep_quality', 'very_poor', 'Muy mala', 1),
      ('sleep_quality', 'poor', 'Mala', 2),
      ('sleep_quality', 'regular', 'Regular', 3),
      ('sleep_quality', 'good', 'Buena', 4),
      ('sleep_quality', 'very_good', 'Muy buena', 5),
      ('daily_main_meals', 'one', '1', 1),
      ('daily_main_meals', 'two', '2', 2),
      ('daily_main_meals', 'three', '3', 3),
      ('daily_main_meals', 'four', '4', 4),
      ('daily_main_meals', 'five_or_more', '5 o más', 5),
      ('tobacco_or_vaping', 'never', 'Nunca', 1),
      ('tobacco_or_vaping', 'former', 'Exfumador/a', 2),
      ('tobacco_or_vaping', 'occasional', 'Ocasional', 3),
      ('tobacco_or_vaping', 'daily', 'Diario', 4),
      ('alcohol_frequency', 'never', 'Nunca', 1),
      ('alcohol_frequency', 'monthly_or_less', '1 vez al mes o menos', 2),
      ('alcohol_frequency', 'two_to_four_monthly', '2 a 4 veces al mes', 3),
      ('alcohol_frequency', 'two_to_three_weekly', '2 a 3 veces por semana', 4),
      ('alcohol_frequency', 'four_or_more_weekly', '4 o más veces por semana', 5),
      ('professional_nutrition_guidance', 'current', 'Sí, actualmente', 1),
      ('professional_nutrition_guidance', 'past', 'Sí, en el pasado', 2),
      ('professional_nutrition_guidance', 'never', 'Nunca', 3)
  ) as options(question_key, option_key, label, display_order)
),
technical_familiarity as (
  select question_key, option_key, label, display_order
  from unnest(array[
    'technical_familiarity_squat',
    'technical_familiarity_deadlift',
    'technical_familiarity_bench_press',
    'technical_familiarity_overhead_press',
    'technical_familiarity_row',
    'technical_familiarity_pull_up'
  ]) as questions(question_key)
  cross join (
    values
      ('unknown', 'No lo conozco', 1),
      ('assisted_only', 'Lo he ejecutado solo con asistencia', 2),
      ('light_load', 'Lo ejecuto solo/a con carga ligera', 3),
      ('high_load_technical', 'Lo ejecuto con carga alta manteniendo la técnica', 4)
  ) as options(option_key, label, display_order)
)
insert into private.research_question_option (question_key, option_key, label, display_order)
select question_key, option_key, label, display_order from option_template
union all
select question_key, option_key, label, display_order from technical_familiarity;


-- ============================================================================
-- Source: docs/database/v2-research-draft.sql
-- ============================================================================

-- Draft v2: campañas académicas. El catálogo se carga por separado desde la
-- hoja Bateria; ninguna campaña queda publicada al crear el proyecto.

create function private.validate_research_campaign_question()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_selectable boolean;
  v_campaign_status private.research_campaign_status;
begin
  select catalog.is_campaign_selectable, campaign.status
  into v_selectable, v_campaign_status
  from private.research_campaign as campaign
  join private.research_question_catalog as catalog
    on catalog.question_key = new.question_key
  where campaign.research_campaign_id = new.research_campaign_id;

  if not found then
    raise exception 'research campaign or question was not found';
  elsif v_campaign_status <> 'draft' then
    raise exception 'published research campaign questions are immutable';
  elsif v_selectable is distinct from true then
    raise exception 'question is not available for research campaigns';
  end if;

  return new;
end;
$$;

create trigger research_campaign_question_validate
before insert or update on private.research_campaign_question
for each row
execute function private.validate_research_campaign_question();

create function private.validate_research_campaign_response()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_kind private.catalog_response_kind;
  v_validation jsonb;
  v_snapshot jsonb;
begin
  select
    (campaign_question.question_snapshot ->> 'responseKind')::private.catalog_response_kind,
    campaign_question.question_snapshot -> 'validation',
    campaign_question.question_snapshot
  into v_kind, v_validation, v_snapshot
  from private.research_campaign_submission as submission
  join private.research_campaign_question as campaign_question
    on campaign_question.research_campaign_id = submission.research_campaign_id
    and campaign_question.question_key = new.question_key
  where submission.research_campaign_submission_id = new.research_campaign_submission_id;

  if not found then
    raise exception 'question does not belong to the campaign';
  elsif v_kind = 'boolean'
    and new.boolean_value is not null
    and new.integer_value is null
    and new.decimal_value is null
    and new.date_value is null
    and new.text_value is null
    and new.option_key is null then
    return new;
  elsif v_kind = 'integer'
    and new.boolean_value is null
    and new.integer_value is not null
    and new.decimal_value is null
    and new.date_value is null
    and new.text_value is null
    and new.option_key is null then
    if (v_validation ? 'minimum' and new.integer_value < (v_validation ->> 'minimum')::integer)
      or (v_validation ? 'maximum' and new.integer_value > (v_validation ->> 'maximum')::integer) then
      raise exception 'integer response is outside the catalog range';
    end if;
    return new;
  elsif v_kind = 'decimal'
    and new.boolean_value is null
    and new.integer_value is null
    and new.decimal_value is not null
    and new.date_value is null
    and new.text_value is null
    and new.option_key is null then
    if (v_validation ? 'minimum' and new.decimal_value < (v_validation ->> 'minimum')::numeric)
      or (v_validation ? 'maximum' and new.decimal_value > (v_validation ->> 'maximum')::numeric) then
      raise exception 'decimal response is outside the catalog range';
    end if;
    return new;
  elsif v_kind = 'date'
    and new.boolean_value is null
    and new.integer_value is null
    and new.decimal_value is null
    and new.date_value is not null
    and new.text_value is null
    and new.option_key is null then
    return new;
  elsif v_kind = 'short_text'
    and new.boolean_value is null
    and new.integer_value is null
    and new.decimal_value is null
    and new.date_value is null
    and new.text_value is not null
    and new.option_key is null then
    if v_validation ? 'maxLength'
      and char_length(trim(new.text_value)) > (v_validation ->> 'maxLength')::integer then
      raise exception 'text response exceeds the catalog length';
    end if;
    return new;
  elsif v_kind = 'single_choice'
    and new.boolean_value is null
    and new.integer_value is null
    and new.decimal_value is null
    and new.date_value is null
    and new.text_value is null
    and new.option_key is not null then
    if not exists (
      select 1
      from jsonb_array_elements(v_snapshot -> 'options') as option_item(value)
      where option_item.value ->> 'optionKey' = new.option_key
    ) then
      raise exception 'option does not belong to the campaign question';
    end if;
    return new;
  end if;

  raise exception 'response value does not match the catalog response kind';
end;
$$;

create trigger research_campaign_response_validate
before insert or update on private.research_campaign_response
for each row
execute function private.validate_research_campaign_response();

-- The campaign snapshot, not the mutable catalog, is the historical authority
-- for a submitted answer. The validator below therefore checks option keys
-- against the snapshot and the response table intentionally has no FK to the
-- live option table.

create function private.require_current_research_admin(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_admin(p_user_id);
end;
$$;

create function private.require_current_research_recipient(p_user_id uuid)
returns public.app_user
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user public.app_user%rowtype;
begin
  v_user := private.require_regulation_accepted_user(p_user_id);

  if v_user.role not in ('student', 'u_staff') then
    raise exception 'student or u_staff recipient is required';
  end if;

  return v_user;
end;
$$;

create function public.create_admin_research_campaign_draft(
  p_actor_user_id uuid,
  p_title text,
  p_purpose text,
  p_data_use_notice text,
  p_consent_text text,
  p_target_roles jsonb,
  p_questions jsonb
)
returns private.research_campaign
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaign private.research_campaign%rowtype;
  v_title text := trim(p_title);
  v_purpose text := trim(p_purpose);
  v_notice text := trim(p_data_use_notice);
  v_consent text := trim(p_consent_text);
  v_target_count integer;
  v_question_count integer;
begin
  perform private.require_current_research_admin(p_actor_user_id);

  if char_length(v_title) not between 3 and 160
    or char_length(v_purpose) not between 10 and 2000
    or char_length(v_notice) not between 10 and 3000
    or char_length(v_consent) not between 10 and 5000 then
    raise exception 'campaign content is outside its permitted length';
  elsif jsonb_typeof(p_target_roles) <> 'array' or jsonb_typeof(p_questions) <> 'array' then
    raise exception 'campaign roles and questions must be arrays';
  end if;

  v_target_count := jsonb_array_length(p_target_roles);
  v_question_count := jsonb_array_length(p_questions);
  if v_target_count not between 1 and 2 then
    raise exception 'campaign must target one or both permitted roles';
  elsif v_question_count not between 1 and 60 then
    raise exception 'campaign must contain between one and sixty questions';
  end if;

  insert into private.research_campaign (
    title,
    purpose,
    data_use_notice,
    consent_text,
    created_by_user_id
  )
  values (v_title, v_purpose, v_notice, v_consent, p_actor_user_id)
  returning * into v_campaign;

  insert into private.research_campaign_target_role (research_campaign_id, target_role)
  select v_campaign.research_campaign_id, target_role::public.app_role
  from jsonb_array_elements_text(p_target_roles) as roles(target_role);

  if (select count(*) from private.research_campaign_target_role
      where research_campaign_id = v_campaign.research_campaign_id) <> v_target_count then
    raise exception 'campaign target roles must be student or u_staff without duplicates';
  end if;

  insert into private.research_campaign_question (
    research_campaign_id,
    question_key,
    is_required,
    display_order,
    question_snapshot
  )
  select
    v_campaign.research_campaign_id,
    item.question_key,
    coalesce(item.is_required, false),
    item.display_order,
    jsonb_build_object(
      'sourceCode', catalog.source_code,
      'sectionKey', catalog.section_key,
      'responseKind', catalog.response_kind,
      'prompt', catalog.prompt,
      'helpText', catalog.help_text,
      'validation', catalog.validation,
      'setsPreventiveAttention', catalog.sets_preventive_attention,
      'options', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'optionKey', option.option_key,
            'label', option.label,
            'displayOrder', option.display_order
          )
          order by option.display_order
        )
        from private.research_question_option as option
        where option.question_key = catalog.question_key
      ), '[]'::jsonb)
    )
  from jsonb_to_recordset(p_questions) as item(
    question_key text,
    is_required boolean,
    display_order smallint
  )
  join private.research_question_catalog as catalog
    on catalog.question_key = item.question_key;

  if (select count(*) from private.research_campaign_question
      where research_campaign_id = v_campaign.research_campaign_id) <> v_question_count then
    raise exception 'campaign questions are malformed or duplicated';
  end if;

  return v_campaign;
end;
$$;

create function public.get_admin_research_question_catalog(p_actor_user_id uuid)
returns table (
  question_key text,
  source_code text,
  section_key text,
  response_kind private.catalog_response_kind,
  prompt text,
  help_text text,
  validation jsonb,
  is_campaign_selectable boolean,
  sets_preventive_attention boolean,
  is_derived boolean,
  options jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_current_research_admin(p_actor_user_id);

  return query
  select
    catalog.question_key,
    catalog.source_code,
    catalog.section_key,
    catalog.response_kind,
    catalog.prompt,
    catalog.help_text,
    catalog.validation,
    catalog.is_campaign_selectable,
    catalog.sets_preventive_attention,
    catalog.is_derived,
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'optionKey', option.option_key,
          'label', option.label,
          'displayOrder', option.display_order
        )
        order by option.display_order
      )
      from private.research_question_option as option
      where option.question_key = catalog.question_key
    ), '[]'::jsonb)
  from private.research_question_catalog as catalog
  order by catalog.section_key, catalog.source_code;
end;
$$;

create function public.set_admin_research_question_campaign_availability(
  p_actor_user_id uuid,
  p_question_key text,
  p_is_campaign_selectable boolean
)
returns private.research_question_catalog
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_catalog private.research_question_catalog%rowtype;
begin
  perform private.require_current_research_admin(p_actor_user_id);

  update private.research_question_catalog
  set is_campaign_selectable = p_is_campaign_selectable
  where question_key = p_question_key
    and not is_derived
    and question_key not in ('birth_date', 'declared_sex', 'height_cm', 'weight_kg')
  returning * into v_catalog;

  if not found then
    raise exception 'campaign-eligible catalog question was not found';
  end if;

  return v_catalog;
end;
$$;

create function public.schedule_admin_research_campaign(
  p_actor_user_id uuid,
  p_research_campaign_id uuid,
  p_opens_at timestamptz,
  p_closes_at timestamptz
)
returns private.research_campaign
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaign private.research_campaign%rowtype;
begin
  perform private.require_current_research_admin(p_actor_user_id);

  if p_opens_at is null or p_closes_at is null or p_closes_at <= p_opens_at then
    raise exception 'campaign opening and closing timestamps are invalid';
  end if;

  update private.research_campaign
  set
    status = (case when p_opens_at <= now() then 'active' else 'scheduled' end)::private.research_campaign_status,
    opens_at = p_opens_at,
    closes_at = p_closes_at
  where research_campaign_id = p_research_campaign_id
    and status = 'draft'
  returning * into v_campaign;

  if not found then
    raise exception 'draft campaign was not found';
  end if;

  return v_campaign;
end;
$$;

create function public.advance_research_campaign_statuses()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update private.research_campaign
  set status = 'active'
  where status = 'scheduled'
    and opens_at <= now()
    and closes_at > now();

  update private.research_campaign
  set status = 'closed'
  where status in ('scheduled', 'active')
    and closes_at <= now();
end;
$$;

create function public.get_own_active_research_campaigns(p_user_id uuid)
returns table (
  research_campaign_id uuid,
  title text,
  purpose text,
  data_use_notice text,
  consent_text text,
  closes_at timestamptz,
  submitted_at timestamptz,
  questions jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user public.app_user%rowtype;
begin
  v_user := private.require_current_research_recipient(p_user_id);

  return query
  select
    campaign.research_campaign_id,
    campaign.title,
    campaign.purpose,
    campaign.data_use_notice,
    campaign.consent_text,
    campaign.closes_at,
    submission.submitted_at,
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'questionKey', campaign_question.question_key,
          'prompt', campaign_question.question_snapshot ->> 'prompt',
          'helpText', campaign_question.question_snapshot ->> 'helpText',
          'responseKind', campaign_question.question_snapshot ->> 'responseKind',
          'isRequired', campaign_question.is_required,
          'displayOrder', campaign_question.display_order,
          'options', campaign_question.question_snapshot -> 'options'
        )
        order by campaign_question.display_order
      )
      from private.research_campaign_question as campaign_question
      where campaign_question.research_campaign_id = campaign.research_campaign_id
    ), '[]'::jsonb)
  from private.research_campaign as campaign
  left join private.research_campaign_submission as submission
    on submission.research_campaign_id = campaign.research_campaign_id
    and submission.user_id = v_user.user_id
  where campaign.status in ('scheduled', 'active')
    and campaign.opens_at <= now()
    and campaign.closes_at > now()
    and exists (
      select 1
      from private.research_campaign_target_role as target
      where target.research_campaign_id = campaign.research_campaign_id
        and target.target_role = v_user.role
    )
  order by campaign.closes_at, campaign.created_at;
end;
$$;

create function public.submit_own_research_campaign(
  p_user_id uuid,
  p_research_campaign_id uuid,
  p_responses jsonb
)
returns private.research_campaign_submission
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user public.app_user%rowtype;
  v_campaign private.research_campaign%rowtype;
  v_submission private.research_campaign_submission%rowtype;
begin
  v_user := private.require_current_research_recipient(p_user_id);

  if jsonb_typeof(p_responses) <> 'array' then
    raise exception 'campaign responses must be an array';
  end if;

  select campaign.* into v_campaign
  from private.research_campaign as campaign
  where campaign.research_campaign_id = p_research_campaign_id
    and campaign.status in ('scheduled', 'active')
    and campaign.opens_at <= now()
    and campaign.closes_at > now()
    and exists (
      select 1
      from private.research_campaign_target_role as target
      where target.research_campaign_id = campaign.research_campaign_id
        and target.target_role = v_user.role
    )
  for share;

  if not found then
    raise exception 'active research campaign is not available to this user';
  elsif exists (
    select 1
    from private.research_campaign_submission as submission
    where submission.research_campaign_id = v_campaign.research_campaign_id
      and submission.user_id = v_user.user_id
      and submission.submitted_at is not null
  ) then
    raise exception 'research campaign was already submitted';
  end if;

  insert into private.research_campaign_submission (
    research_campaign_id,
    user_id,
    consented_at,
    submitted_at
  )
  values (
    v_campaign.research_campaign_id,
    v_user.user_id,
    now(),
    now()
  )
  returning * into v_submission;

  insert into private.research_campaign_response (
    research_campaign_submission_id,
    question_key,
    boolean_value,
    integer_value,
    decimal_value,
    date_value,
    text_value,
    option_key
  )
  select
    v_submission.research_campaign_submission_id,
    response.question_key,
    response.boolean_value,
    response.integer_value,
    response.decimal_value,
    response.date_value,
    nullif(trim(response.text_value), ''),
    response.option_key
  from jsonb_to_recordset(p_responses) as response(
    question_key text,
    boolean_value boolean,
    integer_value integer,
    decimal_value numeric,
    date_value date,
    text_value text,
    option_key text
  );

  if exists (
    select 1
    from private.research_campaign_question as campaign_question
    where campaign_question.research_campaign_id = v_campaign.research_campaign_id
      and campaign_question.is_required
      and not exists (
        select 1
        from private.research_campaign_response as response
        where response.research_campaign_submission_id = v_submission.research_campaign_submission_id
          and response.question_key = campaign_question.question_key
      )
  ) then
    raise exception 'all required campaign questions must have a response';
  end if;

  if exists (
    with selection_group_limit as (
      select
        campaign_question.question_snapshot -> 'validation' ->> 'selectionGroup' as selection_group,
        max((campaign_question.question_snapshot -> 'validation' ->> 'maximumSelected')::integer) as maximum_selected
      from private.research_campaign_question as campaign_question
      where campaign_question.research_campaign_id = v_campaign.research_campaign_id
        and (campaign_question.question_snapshot -> 'validation') ? 'selectionGroup'
      group by campaign_question.question_snapshot -> 'validation' ->> 'selectionGroup'
    ),
    selection_count as (
      select
        campaign_question.question_snapshot -> 'validation' ->> 'selectionGroup' as selection_group,
        count(*) filter (where response.boolean_value) as selected_count
      from private.research_campaign_response as response
      join private.research_campaign_question as campaign_question
        on campaign_question.research_campaign_id = v_campaign.research_campaign_id
        and campaign_question.question_key = response.question_key
      where response.research_campaign_submission_id = v_submission.research_campaign_submission_id
        and (campaign_question.question_snapshot -> 'validation') ? 'selectionGroup'
      group by campaign_question.question_snapshot -> 'validation' ->> 'selectionGroup'
    )
    select 1
    from selection_group_limit
    join selection_count using (selection_group)
    where selection_count.selected_count > selection_group_limit.maximum_selected
  ) then
    raise exception 'campaign selection group exceeds its maximum';
  end if;

  return v_submission;
end;
$$;

create function private.user_has_preventive_attention(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.research_campaign_submission as submission
    join private.research_campaign as campaign
      on campaign.research_campaign_id = submission.research_campaign_id
    join private.research_campaign_response as response
      on response.research_campaign_submission_id = submission.research_campaign_submission_id
    join private.research_campaign_question as campaign_question
      on campaign_question.research_campaign_id = submission.research_campaign_id
      and campaign_question.question_key = response.question_key
    where submission.user_id = p_user_id
      and submission.submitted_at is not null
      and campaign.status in ('scheduled', 'active', 'closed')
      and campaign.opens_at <= now()
      and (campaign_question.question_snapshot ->> 'setsPreventiveAttention')::boolean
      and response.boolean_value is true
  );
$$;

revoke all on function private.validate_research_campaign_question() from public, anon, authenticated;
revoke all on function private.validate_research_campaign_response() from public, anon, authenticated;
revoke all on function private.require_current_research_admin(uuid) from public, anon, authenticated;
revoke all on function private.require_current_research_recipient(uuid) from public, anon, authenticated;
revoke all on function private.user_has_preventive_attention(uuid) from public, anon, authenticated;
revoke all on function public.create_admin_research_campaign_draft(uuid, text, text, text, text, jsonb, jsonb) from public, anon, authenticated;
revoke all on function public.get_admin_research_question_catalog(uuid) from public, anon, authenticated;
revoke all on function public.set_admin_research_question_campaign_availability(uuid, text, boolean) from public, anon, authenticated;
revoke all on function public.schedule_admin_research_campaign(uuid, uuid, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function public.advance_research_campaign_statuses() from public, anon, authenticated;
revoke all on function public.get_own_active_research_campaigns(uuid) from public, anon, authenticated;
revoke all on function public.submit_own_research_campaign(uuid, uuid, jsonb) from public, anon, authenticated;

grant execute on function public.create_admin_research_campaign_draft(uuid, text, text, text, text, jsonb, jsonb) to service_role;
grant execute on function public.get_admin_research_question_catalog(uuid) to service_role;
grant execute on function public.set_admin_research_question_campaign_availability(uuid, text, boolean) to service_role;
grant execute on function public.schedule_admin_research_campaign(uuid, uuid, timestamptz, timestamptz) to service_role;
grant execute on function public.get_own_active_research_campaigns(uuid) to service_role;
grant execute on function public.submit_own_research_campaign(uuid, uuid, jsonb) to service_role;


-- ============================================================================
-- Source: docs/database/v2-operations-draft.sql
-- ============================================================================

-- Draft v2: mantenimiento temporal y retención de pg_cron.
-- Requiere booking, QR y admisión presencial. Se instala una sola vez dentro
-- de la migración baseline, sobre un proyecto vacío.

create extension if not exists pg_cron;

-- pg_cron puede operar en GMT en proyectos gestionados. Esta condición mantiene
-- la regla de negocio en America/Santiago incluso ante cambios de horario de verano.
create function private.is_gym_maintenance_window()
returns boolean
language sql
stable
set search_path = ''
as $$
  select
    extract(isodow from now() at time zone 'America/Santiago') between 1 and 5
    and (now() at time zone 'America/Santiago')::time >= time '07:00'
    and (now() at time zone 'America/Santiago')::time < time '22:00';
$$;

create function public.delete_expired_staff_block_admission_requests()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted_count integer;
begin
  delete from private.staff_block_admission_request
  where expires_at <= now();

  get diagnostics v_deleted_count = row_count;
  return v_deleted_count;
end;
$$;

create function public.run_booking_maintenance()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_gym_maintenance_window() then
    return;
  end if;

  perform public.expire_unconfirmed_bookings();
  perform public.finalize_due_attendance();
  perform public.delete_expired_staff_block_admission_requests();
end;
$$;

create function public.run_research_campaign_maintenance()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_gym_maintenance_window() then
    return;
  end if;

  perform public.advance_research_campaign_statuses();
end;
$$;

create function public.prune_cron_job_run_details()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted_count integer;
begin
  delete from cron.job_run_details
  where end_time < now() - interval '3 days';

  get diagnostics v_deleted_count = row_count;
  return v_deleted_count;
end;
$$;

select cron.schedule(
  'gymu-booking-maintenance-daytime',
  '* 10-23 * * 1-5',
  $job$select public.run_booking_maintenance();$job$
);

-- Cubre las últimas horas de cada día local. La condición anterior descarta
-- cualquier minuto que no corresponda a la ventana de Santiago.
select cron.schedule(
  'gymu-booking-maintenance-evening',
  '* 0-1 * * 2-6',
  $job$select public.run_booking_maintenance();$job$
);

select cron.schedule(
  'gymu-research-campaign-maintenance-daytime',
  '*/15 10-23 * * 1-5',
  $job$select public.run_research_campaign_maintenance();$job$
);

select cron.schedule(
  'gymu-research-campaign-maintenance-evening',
  '*/15 0-1 * * 2-6',
  $job$select public.run_research_campaign_maintenance();$job$
);

select cron.schedule(
  'gymu-prune-cron-run-details',
  '17 12 * * 1',
  $job$select public.prune_cron_job_run_details();$job$
);

revoke all on function private.is_gym_maintenance_window() from public;
revoke all on function public.delete_expired_staff_block_admission_requests() from public, anon, authenticated;
revoke all on function public.run_booking_maintenance() from public, anon, authenticated;
revoke all on function public.run_research_campaign_maintenance() from public, anon, authenticated;
revoke all on function public.prune_cron_job_run_details() from public, anon, authenticated;
