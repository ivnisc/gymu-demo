# GYMU

GYMU es una aplicación web progresiva para la gestión operativa de la Sala de
Musculación UTFSM Concepción. Centraliza reservas, control de asistencia,
administración de capacidad y herramientas de apoyo para el personal autorizado
por DEFIDER.

La plataforma está diseñada para usuarios institucionales UTFSM. La integración
con el sistema de autenticación institucional se encuentra en proceso de
evaluación. La aplicación no almacena contraseñas institucionales.

### Arquitectura

- Aplicación: Next.js 16 con App Router y TypeScript.
- Base de datos, autenticación y control de acceso: Supabase y PostgreSQL.
- Interfaz: PWA responsive, orientada principalmente a uso móvil.
- Monorepo: pnpm 9 y Turborepo.

La aplicación vigente vive en `apps/weightroom`. Los paquetes compartidos viven
en `packages/`.

### Desarrollo local

Requiere Node.js 24 o superior y `pnpm@9`.

```sh
pnpm install
pnpm exec turbo dev --filter=@gusm/weightroom
```

### Variables de entorno

Crear `apps/weightroom/.env.local` con las credenciales del proyecto Supabase
del entorno que se va a utilizar:

```sh
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
SUPABASE_SECRET_KEY=
```

`SUPABASE_SECRET_KEY` es exclusiva del servidor y no debe exponerse al
navegador, repositorio ni registros de aplicación. Cada entorno usa sus propias
credenciales; `.env.local` está excluido de Git.

#### Modo presentación local

Para una demostración local controlada, agregar la siguiente variable y
reiniciar la aplicación:

```sh
NEXT_PUBLIC_GYMU_PRESENTATION_LOGIN_BYPASS=enabled
```

Con el flag activo, el formulario de acceso inicia una sesión de demostración
interna sin verificar credenciales. Nunca debe habilitarse en un deployment
remoto ni en un entorno con usuarios reales.

### Verificación

```sh
pnpm lint
pnpm check-types
pnpm format:check
pnpm --filter @gusm/weightroom build
```

### Supabase y esquema

Supabase CLI se ejecuta desde el paquete de base de datos:

```sh
pnpm --filter @gusm/database exec supabase login
pnpm --filter @gusm/database exec supabase link --project-ref "<project-ref>"
pnpm db:push
pnpm db:types
```

El scheme se versiona mediante migraciones SQL. Cada proyecto Supabase debe
enlazarse explícitamente antes de aplicar cambios. Las migraciones ya aplicadas
no se editan: una corrección se expresa en una migración posterior. El archivo
generado `packages/database/src/database.types.ts` se actualiza únicamente con
`pnpm db:types`.

Las reglas de seguridad, acceso y operación se implementan en la base de datos
mediante RLS y funciones transaccionales, así que la interfaz no es autoridad para
autorizar operaciones sensibles.

## Despliegue

GYMU contempla dos alternativas de hosting:

1. **Vercel**, asociado al repositorio Git, para despliegues automáticos desde
   la rama definida como producción. Esta capa gratuita de [Vercel Hobby](https://vercel.com/home) está sujeto a sus condiciones de uso personal y no comercial.
2. **Infraestructura de la sede**, mediante un servicio o clúster
   facilitado por la Universidad, con un origen HTTPS público.

La decisión final de hosting debe preceder la configuración definitiva de la
autenticación institucional y de las capacidades PWA que dependan del origen
público, como notificaciones push.

