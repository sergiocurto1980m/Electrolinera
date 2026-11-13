# Electrolinera

App de gestión de puestos de carga para coches eléctricos. Web responsive y
Android, construida con **Ionic 9 + Vue 3 + Vite 8** y conectada a **Supabase**
por API REST y WebSocket (Realtime).

Esta entrega incluye:

- Home pública con el catálogo de estaciones (tipo, poste y toma).
- Estado en tiempo real (libre, ocupado, tiempo, cola) solo para usuarios
  autenticados.
- Resumen por tipo con libres, ocupadas y sin estado al iniciar sesión.
- Panel de avisos con notificación toast en vivo para usuarios autenticados.
- Autenticación: login, registro, edición de perfil y baja de cuenta.
- Menú lateral con las futuras secciones preparadas.
- Tema oscuro con acento verde eléctrico.

## Stack

| Capa | Tecnología |
| --- | --- |
| UI | Ionic 9 · Vue 3.5 · `@ionic/vue` |
| Build | Vite 8 · TypeScript 6 |
| Router | Vue Router 5 + `@ionic/vue-router` |
| Datos | Supabase (PostgREST + Realtime) |
| Cliente | `@supabase/supabase-js` |
| Android | Capacitor 8 |
| Tipografía | Inter Variable (empaquetada, funciona offline) |

## Requisitos

- Node.js **22 o superior** (probado con 24).
- npm.
- Para compilar el APK: **Android Studio**, SDK de Android y **JDK 21**.
  El desarrollo web y `npx cap sync` no necesitan Android Studio.

## Puesta en marcha

```bash
npm install
```

### Variables de entorno

Copia `.env.example` a `.env.local` y rellena los valores:

```dotenv
VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
VITE_SUPABASE_ANON_KEY=sb_publishable_...
VITE_APP_URL=http://localhost:8100
```

- Solo se exponen al frontend las variables con prefijo `VITE_`.
- Usa **únicamente la publishable/anon key**. La `secret key` nunca debe llegar
  al navegador ni al APK: se salta RLS.
- `VITE_APP_URL` es la URL pública que se usa en los enlaces de confirmación
  de Supabase. En desarrollo, `http://localhost:8100`; en producción, tu dominio.
- `.env.local` está en `.gitignore`.

### Preparar Supabase

Ejecuta en **Supabase → SQL Editor**, en este orden:

1. [`supabase/migrations/0001_home.sql`](supabase/migrations/0001_home.sql)
2. [`supabase/migrations/0002_users.sql`](supabase/migrations/0002_users.sql)
3. [`supabase/migrations/0003_home_public.sql`](supabase/migrations/0003_home_public.sql)

La primera prepara la Home:

1. Concede lectura a `anon` y `authenticated`.
2. Crea políticas RLS de solo `SELECT` para las tablas de la Home.
3. Añade `estaciones`, `situacion_estacion`, `lista_espera_estacion` y `avisos`
   a la publicación `supabase_realtime`.
4. Crea índices para el estado actual y la cola.
5. Crea las vistas `v_home_estaciones` y `v_home_avisos`.

La segunda prepara los usuarios:

1. Vincula `public.usuarios.id` con `auth.users.id`.
2. Crea un índice único de email sin distinguir mayúsculas.
3. Instala los triggers que crean el perfil al registrarse y sincronizan el
   email cuando Auth lo confirma.
4. Crea perfiles para los usuarios de Auth que ya existan.
5. Aplica RLS: cada usuario solo puede leer y actualizar su propio perfil.
6. Impide actualizar el email directamente desde el cliente; el cambio se hace
   siempre a través de Supabase Auth.

La tercera separa el catálogo público del estado privado:

1. Crea `v_home_estaciones_publica` con solo `id`, tipo, poste y toma.
2. Deja `v_home_estaciones` y `v_home_avisos` solo para `authenticated`.
3. Revoca el acceso de `anon` a `situacion_estacion`, cola y avisos.
4. Mantiene la lectura pública de estaciones y tipos.
5. Ajusta Realtime para que un invitado solo reciba cambios del catálogo.

> El bloqueo del estado no es solo visual: un invitado tampoco puede leerlo
> llamando directamente a la API de Supabase.

### Configurar autenticación en Supabase

- **Authentication → Providers → Email**: habilitado.
- **Authentication → URL Configuration**:
  - `Site URL`: `http://localhost:8100` en desarrollo, tu dominio en producción.
  - `Redirect URLs`: `http://localhost:8100/**` y `https://tu-dominio/**`.
- El proyecto tiene activada la confirmación de email (`Confirm email`), así que
  al registrarse se envía un enlace al correo indicado. Hasta confirmarlo no se
  puede iniciar sesión.
- Ajusta `VITE_APP_URL` a la URL pública que aparecerá en esos enlaces.

> La tabla `usuarios` no se expone a `anon` y cada usuario solo ve su fila.

### Desarrollo

```bash
npm run dev
```

Abre <http://localhost:8100>.

La **Home es pública**: muestra el catálogo de estaciones a cualquier visitante.
El estado de cada puesto, la cola y los avisos solo aparecen al iniciar sesión.
`/cuenta` y las futuras secciones de gestión requieren sesión; `/login` y
`/registro` son públicas.

Sin sesión, el header muestra `En directo` + `Entrar` y la Home incluye un CTA
para crear cuenta. Con sesión, el menú lateral aparece y el header muestra el
usuario a la derecha.

Si aún no has ejecutado las migraciones, la Home mostrará un aviso explicándolo.

### Vista previa sin datos

Para revisar el diseño de la Home sin depender de Supabase:

```
http://localhost:8100/?preview=1
```

Usa datos de ejemplo en memoria (`src/data/preview.ts`); no toca la base de datos.
Sin sesión se ve la variante pública (sin estado). Con sesión se ve el dashboard
completo con los datos de ejemplo.

### Home pública y estado privado

- **Invitado**:
  - Ve las estaciones agrupadas por tipo, con el total de puestos.
  - No ve libres/ocupadas, tiempo, cola ni avisos.
  - Tiene botón `Entrar` en el header y CTA `Crear cuenta` / `Ya tengo cuenta`.
- **Usuario autenticado**:
  - Ve el estado completo y los avisos en tiempo real.
  - Dispone del menú lateral y del acceso a `Mi cuenta` desde el header.
- **Logout**: vuelve a la Home pública, sin salir de la pantalla de inicio.
- **Realtime**:
  - Invitado: solo se suscribe a cambios del catálogo de estaciones.
  - Autenticado: también a estado, cola y avisos.

## Autenticación y usuarios

- **Registro** con nombre, email y contraseña. Supabase Auth envía un correo de
  confirmación; hasta confirmarlo no se puede entrar.
- **Login** con email y contraseña.
- **Email único**: lo garantiza Supabase Auth y un índice único en
  `public.usuarios (lower(email))`.
- **Edición del perfil**: el usuario puede cambiar su nombre y solicitar un
  cambio de email. El email se confirma por correo y después se sincroniza en
  `public.usuarios` mediante un trigger.
- **Baja de cuenta**: se marca `borrado = true`, se cierra la sesión y la app
  bloquea nuevos accesos con un aviso. Es una baja lógica: un administrador
  puede reactivar la cuenta con `update public.usuarios set borrado = false`.
  Para un borrado definitivo hace falta usar la Admin API o una Edge Function
  con `service_role`, nunca desde el frontend.
- **Cerrar sesión** desde el pie del menú lateral.
- **RLS**: cada usuario solo puede leer y modificar su propia fila. El email no
  se puede escribir directamente; solo el trigger de Auth lo actualiza.
- **Home pública**: el catálogo se lee con la anon key; el estado, la cola y los
  avisos exigen sesión y están cerrados también a nivel de RLS/permisos.

## Scripts

| Script | Descripción |
| --- | --- |
| `npm run dev` | Servidor de desarrollo en el puerto 8100 |
| `npm run build` | Typecheck + build de producción en `dist/` |
| `npm run preview` | Sirve el build de producción |
| `npm run typecheck` | Solo comprobación de tipos con `vue-tsc` |
| `npm run cap:sync` | Build + copia los assets a Android |
| `npm run android` | Abre el proyecto Android en Android Studio |

## Estructura

```
src/
├─ components/
│  ├─ AppMenu.vue          # Menú lateral + usuario + cerrar sesión
│  ├─ AuthShell.vue        # Layout de login/registro
│  ├─ AvisosPanel.vue      # Últimos avisos (solo autenticados)
│  ├─ ConnectionBadge.vue  # Estado del canal Realtime
│  ├─ HeaderUser.vue       # Entrar / usuario en el header
│  ├─ StationGroup.vue     # Sección de un tipo; lista pública o por estado
│  ├─ StationRow.vue       # Fila compacta de un puesto
│  └─ TypeSummaryCard.vue  # Resumen por tipo; variante pública con candado
├─ composables/
│  ├─ useAuth.ts           # Sesión, perfil y acciones de cuenta
│  └─ useHomeLive.ts       # Snapshot, canal único, pausa/resync
├─ data/preview.ts         # Datos de vista previa (?preview=1)
├─ router/index.ts         # Rutas + guard de autenticación
├─ services/
│  ├─ auth.service.ts      # Supabase Auth + tabla usuarios
│  ├─ home.service.ts      # Consultas a las vistas
│  └─ supabase.ts          # Cliente singleton
├─ styles/
│  ├─ forms.css            # Inputs, botones y mensajes de formulario
│  └─ global.css
├─ theme/variables.css     # Tema oscuro verde
├─ types/
│  ├─ auth.ts
│  ├─ home.ts
│  └─ router.d.ts
├─ utils/
│  ├─ authErrors.ts
│  ├─ format.ts
│  └─ url.ts
└─ views/
   ├─ AccountPage.vue      # Mi cuenta
   ├─ HomePage.vue
   ├─ LoginPage.vue
   └─ RegisterPage.vue
supabase/migrations/
├─ 0001_home.sql
├─ 0002_users.sql
└─ 0003_home_public.sql
```

## Modelo de datos

```
tipo_estacion ─┐
tipo_poste ────┼──< estaciones >──< situacion_estacion >── tipo_estado_estacion
tipo_toma ─────┘                          (histórico)
                     │
                     └──< lista_espera_estacion >── usuarios
                                  │           └── tipo_lista_espera_estacion
                                  └──< avisos
```

- `estaciones` representa un punto físico: tipo de estación + poste + toma.
- `situacion_estacion` guarda el histórico de estados (`Libre` / `Ocupado`).
- `lista_espera_estacion` guarda la cola por usuario y estación.
- `avisos` cuelga de una entrada de la lista de espera.
- `usuarios` es el perfil público de cada usuario de `auth.users` (`id`, `nombre`,
  `email`, `borrado`, `created_at`). Se mantiene sincronizado con triggers.

> El esquema actual **no tiene** potencia, energía, dirección ni precio, por lo
> que la Home no muestra kW, kWh ni mapa. Si se añaden esas columnas, se pueden
> incorporar nuevos KPIs.

## Realtime y consumo de datos

- **Invitado**: una consulta a `v_home_estaciones_publica` y un canal suscrito
  solo a `estaciones` para mantener el catálogo al día. No se consultan estado,
  cola ni avisos.
- **Autenticado**: carga inicial de `v_home_estaciones` + `v_home_avisos` y un
  canal suscrito a las 4 tablas.
- Los eventos se **agrupan durante 400 ms** y se resuelven con una sola
  recarga de la vista, evitando ráfagas de peticiones.
- Al ocultar la pestaña (`visibilitychange`) o pasar la app a segundo plano
  (`@capacitor/app`), el canal se cierra.
- Al volver, se resuscribe y se hace **un único resync**.
- Si la sesión cambia, la Home recarga la vista correspondiente y reconstruye el
  canal, de modo que el estado aparece o desaparece sin recargar la página.
- `eventsPerSecond: 10` limita la presión de eventos.

## Android

El proyecto nativo ya está generado en `android/`.

```bash
npm run cap:sync   # build web + copia los assets y plugins
npm run android    # abre Android Studio
```

- App ID: `com.electrolinera.app`
- Nombre: `Electrolinera`
- Versión: `0.1.0`
- Splash y status bar en `capacitor.config.ts`.

Si alguna vez eliminas la carpeta `android/`, vuelve a crearla con
`npx cap add android`.

Para generar el APK desde consola, con Android Studio y el SDK instalados:

```bash
npm run cap:sync
cd android
./gradlew assembleDebug
```

El APK queda en `android/app/build/outputs/apk/debug/app-debug.apk`.

## Seguridad

- La publishable key es pública por diseño; la protección real está en las
  políticas RLS.
- Supabase Auth gestiona las contraseñas y la unicidad del email. El frontend
  nunca almacena contraseñas.
- `public.usuarios` tiene RLS y solo permite leer/editar la fila propia.
- El email no se puede escribir directamente desde el cliente; se cambia con
  `auth.updateUser()` y lo sincroniza un trigger.
- La baja de cuenta es lógica (`borrado = true`). Para un borrado definitivo o
  un baneo real se necesita la Admin API/Edge Function con `service_role`.
- Nunca incluyas `sb_secret_...` en `.env.local` ni en el repositorio.
- Si una secret key se ha compartido, revócala en **Project Settings → API Keys**.

## Próximos pasos

- Secciones de Estaciones, Lista de espera, Usuarios y Avisos.
- Acciones sobre la cola y los avisos.
- Filtros por tipo de estación y búsqueda.
- Recuperación de contraseña y verificación adicional.
