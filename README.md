# Electrolinera

App de gestión de puestos de carga para coches eléctricos. Web responsive y
Android, construida con **Ionic 9 + Vue 3 + Vite 8** y conectada a **Supabase**
por API REST y WebSocket (Realtime).

Esta entrega incluye:

- Home pública con el catálogo de estaciones (tipo, poste y toma).
- Estado diario en tiempo real (libre, ocupado, tiempo y cola) solo para
  usuarios autenticados.
- Enganche y desenganche diario a un poste libre.
- Cola por tipo cuando todos los postes del tipo están ocupados.
- Notificaciones in-app a los tres primeros de la cola al liberarse un puesto.
- Panel de avisos dirigido a cada usuario.
- Autenticación: login, registro, edición de perfil y baja de cuenta.
- Configuración de administración para activar o desactivar la confirmación de
  email desde la app.
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
4. [`supabase/migrations/0004_gestion_diaria.sql`](supabase/migrations/0004_gestion_diaria.sql)
5. [`supabase/migrations/0005_admin_config.sql`](supabase/migrations/0005_admin_config.sql)
6. [`supabase/migrations/0006_home_cola.sql`](supabase/migrations/0006_home_cola.sql)

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

La cuarta activa la gestión diaria:

1. Añade `dia` y `activo` a `situacion_estacion`.
2. Convierte la cola en cola por tipo (`tipo_estacion_id`).
3. Añade `usuario_id` a `avisos` para notificaciones dirigidas.
4. Crea las RPC `engancharse`, `desengancharse`, `entrar_en_cola` y
   `salir_de_cola`.
5. Impide escrituras directas: solo las RPC modifican las tablas.
6. Reemplaza las vistas por versiones diarias y con datos del usuario actual.

La quinta añade la administración de Auth:

1. Añade `usuarios.es_admin`.
2. Marca como administrador a `smcurto@mitma.es`.
3. Permite leer el rol solo al propio usuario.
4. La app muestra **Configuración** únicamente a administradores.

La sexta expone la cola actual de cada tipo de estación:

1. Crea la función `cola_actual()`, de solo lectura.
2. Devuelve posición, nombre del usuario, hora de entrada y si la entrada es
   del usuario actual.
3. Solo los usuarios autenticados pueden ejecutarla; un invitado no ve nombres.
4. La Home muestra la lista de la cola debajo de las tomas de cada tipo.

> El bloqueo del estado no es solo visual: un invitado tampoco puede leerlo
> llamando directamente a la API de Supabase.
>
> La gestión diaria usa la zona horaria `Europe/Madrid`.

### Configurar autenticación en Supabase

- **Authentication → Providers → Email**: habilitado.
- **Authentication → URL Configuration**:
  - `Site URL`: `http://localhost:8100` en desarrollo, tu dominio en producción.
  - `Redirect URLs`: `http://localhost:8100/**` y `https://tu-dominio/**`.
- **Authentication → Providers → Email → Confirm email**:
  - Activado: el alta exige confirmar el correo antes de entrar.
  - Desactivado: la cuenta se activa en la misma creación y la app entra
    directamente.
  - La app lee este ajuste desde `/auth/v1/settings`; no hay que cambiar código
    ni variables de entorno al modificarlo en el dashboard.
- **Signups**: si se desactivan en Supabase, la pantalla de registro queda
  bloqueada automáticamente.
- Ajusta `VITE_APP_URL` a la URL pública que aparecerá en esos enlaces.

> La tabla `usuarios` no se expone a `anon` y cada usuario solo ve su fila.

### Configuración de administración

La cuenta **`smcurto@mitma.es`** es la administradora. Solo ella verá la opción
**Configuración** en el menú lateral.

La pantalla `/ajustes` permite activar o desactivar **Confirmar email en el
registro**. Como `mailer_autoconfirm` es una configuración del proyecto Auth,
no se puede cambiar con la publishable key: se hace mediante una Edge Function
que guarda un personal access token en el servidor.

1. Ejecuta `0005_admin_config.sql`.
2. Crea un **personal access token** en **Supabase → Account → Access Tokens**
   (`sbp_...`). No uses la secret key del proyecto.
3. Configura el secreto de la función. El nombre no puede empezar por
   `SUPABASE_`, así que se llama `MANAGEMENT_ACCESS_TOKEN`:

   ```bash
   npx supabase secrets set MANAGEMENT_ACCESS_TOKEN=sbp_... --project-ref clgtafomlilvvnjlfvab
   ```

   El CLI se autentica aparte con `supabase login` o con su propia variable
   `SUPABASE_ACCESS_TOKEN` (token de despliegue). No confundas esa credencial
   del CLI con el secreto `MANAGEMENT_ACCESS_TOKEN` de la función.

4. Despliega la función:

   ```bash
   npx supabase functions deploy auth-settings --project-ref clgtafomlilvvnjlfvab
   ```

La función:

1. Verifica el JWT del usuario.
2. Comprueba `usuarios.es_admin`.
3. Llama a la Management API de Supabase.
4. Devuelve el estado nuevo.

El PAT queda solo en los secretos de la Edge Function. Nunca debe estar en
`.env.local`, en el frontend ni en el APK.

> Si la Edge Function no está desplegada o falta el secreto, la pantalla de
> configuración muestra el error y no cambia nada.

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
  - Ve el estado diario completo y los avisos en tiempo real.
  - Puede engancharse a un poste libre y desengancharse del suyo.
  - Puede apuntarse a la cola de un tipo cuando todos sus postes están ocupados.
  - Dispone del menú lateral y del acceso a `Mi cuenta` desde el header.
- **Enganche**:
  - Un poste sin registros hoy cuenta como `Libre`.
  - Solo puede haber un poste activo por usuario y día.
  - Mientras está enganchado, solo puede desengancharse de ese poste.
  - Al desengancharse, el poste vuelve a estar libre y puede volver a
    engancharse el mismo día.
- **Cola**:
  - Solo se permite cuando el tipo está completo.
  - Con una cola activa, solo los usuarios apuntados a esa cola pueden
    engancharse a un poste libre del tipo.
  - Al liberarse un poste se avisa a los tres primeros de la cola.
- **Logout**: vuelve a la Home pública, sin salir de la pantalla de inicio.
- **Realtime**:
  - Invitado: solo se suscribe a cambios del catálogo de estaciones.
  - Autenticado: también a estado, cola y avisos.

## Autenticación y usuarios

- **Registro** con nombre, email y contraseña. El comportamiento depende del
  ajuste **Confirm email** de Supabase:
  - Activado: se envía un correo y la cuenta no se activa hasta confirmarlo.
  - Desactivado: la cuenta se activa al crearla y la sesión se inicia
    directamente.
  - La pantalla de registro muestra el modo activo y se adapta al resultado real
    de `signUp`.
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
- **Acciones de estación**: las RPC comprueban sesión, perfil activo, día,
  ocupación y cola antes de escribir. Las tablas de estado y cola no admiten
  escrituras directas del cliente.

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
│  ├─ AvisosPanel.vue      # Avisos dirigidos al usuario
│  ├─ ConnectionBadge.vue  # Estado del canal Realtime
│  ├─ HeaderUser.vue       # Entrar / usuario en el header
│  ├─ StationGroup.vue     # Estado por tipo, cola y acciones
│  ├─ StationRow.vue       # Puesto, enganche y desenganche
│  ├─ TypeSummaryCard.vue  # Resumen por tipo; variante pública con candado
│  └─ icons/               # SVG locales de enchufe y desenchufe
├─ composables/
│  ├─ useAuth.ts           # Sesión, perfil y acciones de cuenta
│  └─ useHomeLive.ts       # Snapshot, canal único, pausa/resync
├─ data/preview.ts         # Datos de vista previa (?preview=1)
├─ router/index.ts         # Rutas + guard de autenticación
├─ services/
│  ├─ auth.service.ts      # Supabase Auth + tabla usuarios
│  ├─ authSettings.service.ts # Ajuste público de confirmación de email
│  ├─ estacion.service.ts  # RPC de enganche, desenganche y cola
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
   ├─ RegisterPage.vue
   └─ SettingsPage.vue     # Configuración (solo admin)
supabase/
├─ functions/
│  └─ auth-settings/
│     └─ index.ts          # Cambia mailer_autoconfirm vía Management API
└─ migrations/
   ├─ 0001_home.sql
   ├─ 0002_users.sql
   ├─ 0003_home_public.sql
   ├─ 0004_gestion_diaria.sql
   ├─ 0005_admin_config.sql
   └─ 0006_home_cola.sql
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
- `situacion_estacion` guarda el histórico diario de estados (`Libre` /
  `Ocupado`), el usuario que realizó el cambio, el día y si la ocupación está
  activa.
- `lista_espera_estacion` guarda la cola por tipo y día. Las entradas de cola
  no llevan una estación concreta; se activan cuando el tipo está completo.
- `avisos` cuelga de una entrada de la cola y lleva `usuario_id` para que cada
  persona reciba solo sus notificaciones.
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
- Las acciones de enganche, desenganche y cola usan RPC y, al terminar, hacen
  un resync inmediato además de esperar el evento Realtime.
- Los avisos de cola son dirigidos: RLS filtra por `usuario_id` y el toast solo
  llega a los destinatarios.
- Los eventos se **agrupan durante 400 ms** y se resuelven con una sola
  recarga de la vista, evitando ráfagas de peticiones.
- Al ocultar la pestaña (`visibilitychange`) o pasar la app a segundo plano
  (`@capacitor/app`), el canal se cierra.
- Al volver, se resuscribe y se hace **un único resync**.
- Si la sesión cambia, la Home recarga la vista correspondiente y reconstruye el
  canal, de modo que el estado aparece o desaparece sin recargar la página.
- Si cambia el día mientras la app está abierta, la Home se recarga
  automáticamente.
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
- `usuarios.es_admin` no lo puede modificar el cliente; solo se cambia por SQL.
- El cambio de `mailer_autoconfirm` se hace desde una Edge Function con un PAT
  guardado como secreto. El frontend nunca recibe el PAT.
- La Edge Function comprueba el JWT y `es_admin` antes de llamar a la Management
  API; un usuario normal recibe `403`.
- El email no se puede escribir directamente desde el cliente; se cambia con
  `auth.updateUser()` y lo sincroniza un trigger.
- La baja de cuenta es lógica (`borrado = true`). Para un borrado definitivo o
  un baneo real se necesita la Admin API/Edge Function con `service_role`.
- La ocupación y la cola se escriben solo mediante RPC con `security definer`;
  el cliente no puede insertar directamente en `situacion_estacion`,
  `lista_espera_estacion` ni `avisos`.
- Los avisos tienen RLS por usuario: cada persona solo ve y recibe los suyos.
- Nunca incluyas `sb_secret_...` en `.env.local` ni en el repositorio.
- Si una secret key se ha compartido, revócala en **Project Settings → API Keys**.

## Créditos de iconos

Los iconos de enchufe y desenchufe son SVG locales basados en
[Lucide](https://lucide.dev/) (`plug-zap` y `unplug`), licencia ISC.

## Próximos pasos

- Secciones de Estaciones, Lista de espera, Usuarios y Avisos.
- Histórico de días anteriores en una pantalla específica.
- Notificaciones push para los avisos de cola.
- Filtros por tipo de estación y búsqueda.
- Recuperación de contraseña y verificación adicional.
