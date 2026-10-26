-- El catálogo de la aplicación usa slugs con guiones como identidad estable de
-- cada ejercicio y como parte de la ruta de sus imágenes. La baseline v2 creó
-- la columna con una expresión que solo admitía guiones bajos; se amplía antes
-- de sembrar para no introducir una segunda traducción entre UI y base.
alter table private.exercise_catalog
  drop constraint if exists exercise_catalog_exercise_key_check;

alter table private.exercise_catalog
  add constraint exercise_catalog_exercise_key_check
  check (exercise_key ~ '^[a-z][a-z0-9-]{2,99}$');

-- Solo se persisten ejercicios disponibles en la Sala de Musculación. El slug
-- coincide con el catálogo local y `asset_path` apunta a su directorio público
-- de frames, sin almacenar imágenes duplicadas en Supabase Storage.
insert into private.exercise_catalog (
  exercise_key,
  exercise_name,
  muscle_group,
  equipment,
  asset_path,
  display_order
)
values
  ('bench-press', 'Press de banca', 'Pecho', 'Barra', '/routine-exercises/bench-press', 1),
  ('incline-bench-press', 'Press de banca inclinado', 'Pecho', 'Barra', '/routine-exercises/incline-bench-press', 2),
  ('dumbbell-bench-press', 'Press de banca con mancuernas', 'Pecho', 'Mancuernas', '/routine-exercises/dumbbell-bench-press', 3),
  ('cable-fly', 'Aperturas en polea', 'Pecho', 'Polea', '/routine-exercises/cable-fly', 4),
  ('push-up', 'Flexiones', 'Pecho', 'Peso corporal', '/routine-exercises/push-up', 5),
  ('overhead-press', 'Press militar', 'Hombros', 'Barra', '/routine-exercises/overhead-press', 6),
  ('seated-dumbbell-press', 'Press militar sentado con mancuernas', 'Hombros', 'Mancuernas', '/routine-exercises/seated-dumbbell-press', 7),
  ('lateral-raise', 'Elevación lateral', 'Hombros', 'Mancuernas', '/routine-exercises/lateral-raise', 8),
  ('face-pull', 'Face pull', 'Espalda alta', 'Polea', '/routine-exercises/face-pull', 9),
  ('upright-row', 'Remo al mentón', 'Hombros', 'Barra', '/routine-exercises/upright-row', 10),
  ('deadlift', 'Peso muerto', 'Cadena posterior', 'Barra', '/routine-exercises/deadlift', 11),
  ('romanian-deadlift', 'Peso muerto rumano', 'Isquiotibiales', 'Barra', '/routine-exercises/romanian-deadlift', 12),
  ('barbell-row', 'Remo con barra', 'Espalda', 'Barra', '/routine-exercises/barbell-row', 13),
  ('seated-row', 'Remo sentado en polea', 'Espalda', 'Polea', '/routine-exercises/seated-row', 14),
  ('straight-arm-pulldown', 'Jalón con brazos rectos', 'Dorsales', 'Polea', '/routine-exercises/straight-arm-pulldown', 15),
  ('pull-up', 'Dominadas', 'Dorsales', 'Peso corporal', '/routine-exercises/pull-up', 16),
  ('squat', 'Sentadilla con barra', 'Cuádriceps', 'Barra', '/routine-exercises/squat', 17),
  ('hack-squat', 'Sentadilla hack', 'Cuádriceps', 'Máquina', '/routine-exercises/hack-squat', 18),
  ('leg-press', 'Prensa de piernas', 'Cuádriceps', 'Máquina', '/routine-exercises/leg-press', 19),
  ('bulgarian-split-squat', 'Sentadilla búlgara', 'Cuádriceps', 'Mancuernas', '/routine-exercises/bulgarian-split-squat', 20),
  ('leg-extension', 'Extensión de piernas', 'Cuádriceps', 'Máquina', '/routine-exercises/leg-extension', 21),
  ('hip-thrust', 'Hip thrust', 'Glúteos', 'Barra', '/routine-exercises/hip-thrust', 22),
  ('glute-bridge', 'Puente de glúteos', 'Glúteos', 'Peso corporal', '/routine-exercises/glute-bridge', 23),
  ('good-morning', 'Buenos días', 'Isquiotibiales', 'Barra', '/routine-exercises/good-morning', 24),
  ('bicep-curl', 'Curl de bíceps', 'Bíceps', 'Mancuernas', '/routine-exercises/bicep-curl', 25),
  ('hammer-curl', 'Curl martillo', 'Bíceps', 'Mancuernas', '/routine-exercises/hammer-curl', 26),
  ('preacher-curl', 'Curl predicador', 'Bíceps', 'Máquina', '/routine-exercises/preacher-curl', 27),
  ('cable-curl', 'Curl en polea', 'Bíceps', 'Polea', '/routine-exercises/cable-curl', 28),
  ('reverse-curl', 'Curl inverso', 'Antebrazos', 'Barra', '/routine-exercises/reverse-curl', 29),
  ('wrist-curl', 'Curl de muñeca', 'Antebrazos', 'Barra', '/routine-exercises/wrist-curl', 30),
  ('tricep-pushdown', 'Extensión de tríceps en polea', 'Tríceps', 'Polea', '/routine-exercises/tricep-pushdown', 31),
  ('overhead-tricep-extension', 'Extensión de tríceps sobre la cabeza', 'Tríceps', 'Polea', '/routine-exercises/overhead-tricep-extension', 32),
  ('skull-crusher', 'Rompecráneos', 'Tríceps', 'Barra', '/routine-exercises/skull-crusher', 33),
  ('plank', 'Plancha', 'Core', 'Peso corporal', '/routine-exercises/plank', 34),
  ('side-plank', 'Plancha lateral', 'Core', 'Peso corporal', '/routine-exercises/side-plank', 35),
  ('running', 'Carrera', 'Piernas', 'Cardio', '/routine-exercises/running', 36),
  ('walking', 'Caminata', 'Piernas', 'Cardio', '/routine-exercises/walking', 37),
  ('cycling', 'Ciclismo', 'Piernas', 'Cardio', '/routine-exercises/cycling', 38),
  ('rowing', 'Remo', 'Espalda', 'Cardio', '/routine-exercises/rowing', 39),
  ('landmine-press', 'Press landmine', 'Hombros', 'Barra', '/routine-exercises/landmine-press', 40),
  ('wide-grip-lat-pulldown', 'Jalón al pecho con agarre ancho', 'Dorsales', 'Polea', '/routine-exercises/wide-grip-lat-pulldown', 41),
  ('goblet-squat', 'Sentadilla goblet', 'Cuádriceps', 'Mancuernas', '/routine-exercises/goblet-squat', 42),
  ('single-leg-glute-bridge', 'Puente de glúteos unilateral', 'Glúteos', 'Peso corporal', '/routine-exercises/single-leg-glute-bridge', 43),
  ('dumbbell-hip-thrust', 'Hip thrust con mancuerna', 'Glúteos', 'Mancuernas', '/routine-exercises/dumbbell-hip-thrust', 44),
  ('leg-press-calf-raise', 'Elevación de pantorrillas en prensa', 'Pantorrillas', 'Máquina', '/routine-exercises/leg-press-calf-raise', 45),
  ('wall-sit', 'Sentadilla isométrica en pared', 'Cuádriceps', 'Peso corporal', '/routine-exercises/wall-sit', 46),
  ('jump-squat', 'Sentadilla con salto', 'Cuádriceps', 'Peso corporal', '/routine-exercises/jump-squat', 47),
  ('ez-bar-curl', 'Curl con barra EZ', 'Bíceps', 'Barra', '/routine-exercises/ez-bar-curl', 48),
  ('spider-curl', 'Curl araña', 'Bíceps', 'Mancuernas', '/routine-exercises/spider-curl', 49),
  ('rope-hammer-curl', 'Curl martillo con cuerda', 'Bíceps', 'Polea', '/routine-exercises/rope-hammer-curl', 50),
  ('rope-tricep-pushdown', 'Extensión de tríceps con cuerda', 'Tríceps', 'Polea', '/routine-exercises/rope-tricep-pushdown', 51),
  ('single-arm-dumbbell-tricep-extension', 'Extensión de tríceps unilateral con mancuerna', 'Tríceps', 'Mancuernas', '/routine-exercises/single-arm-dumbbell-tricep-extension', 52),
  ('reverse-crunch', 'Crunch inverso', 'Core', 'Peso corporal', '/routine-exercises/reverse-crunch', 53),
  ('russian-twist', 'Giro ruso', 'Core', 'Peso corporal', '/routine-exercises/russian-twist', 54),
  ('bicycle-crunch', 'Crunch bicicleta', 'Core', 'Peso corporal', '/routine-exercises/bicycle-crunch', 55),
  ('mountain-climber', 'Escalador', 'Core', 'Peso corporal', '/routine-exercises/mountain-climber', 56),
  ('dead-bug', 'Dead bug', 'Core', 'Peso corporal', '/routine-exercises/dead-bug', 57),
  ('bird-dog', 'Bird dog', 'Core', 'Peso corporal', '/routine-exercises/bird-dog', 58),
  ('cable-pallof-hold', 'Pallof isométrico en polea', 'Core', 'Polea', '/routine-exercises/cable-pallof-hold', 59),
  ('elliptical', 'Elíptica', 'Piernas', 'Cardio', '/routine-exercises/elliptical', 60),
  ('treadmill-incline-walk', 'Caminata inclinada en cinta', 'Piernas', 'Cardio', '/routine-exercises/treadmill-incline-walk', 61),
  ('knee-push-up', 'Flexiones de rodillas', 'Pecho', 'Peso corporal', '/routine-exercises/knee-push-up', 62),
  ('wide-push-up', 'Flexiones abiertas', 'Pecho', 'Peso corporal', '/routine-exercises/wide-push-up', 63),
  ('diamond-push-up', 'Flexiones diamante', 'Tríceps', 'Peso corporal', '/routine-exercises/diamond-push-up', 64),
  ('bodyweight-squat', 'Sentadilla sin carga', 'Cuádriceps', 'Peso corporal', '/routine-exercises/bodyweight-squat', 65),
  ('forward-lunge', 'Zancada frontal', 'Cuádriceps', 'Peso corporal', '/routine-exercises/forward-lunge', 66);
