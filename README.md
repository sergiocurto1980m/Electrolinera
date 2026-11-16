# Electrolinera

App de gestión de puestos de carga para coches eléctricos. Web responsive y
Android, construida con **Ionic 9 + Vue 3 + Vite 8** y conectada a **Supabase**
por API REST y WebSocket (Realtime), con notificaciones push mediante **FCM**.

Esta entrega incluye:

- Home pública con el catálogo de estaciones (tipo, poste y toma).
- Estado diario en tiempo real (libre, ocupado, tiempo y cola) solo para
  usuarios autenticados.
- Enganche y desenganche diario a un poste libre.
- Cola por tipo cuando todos los postes del tipo están ocupados.
- Notificaciones in-app a los tres primeros de la cola al liberarse un puesto.
- Notificaciones push con FCM en web y Android para los avisos de cola.
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
| Push | Firebase Cloud Messaging (web + Android) |
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
7. [`supabase/migrations/0007_aviso_enganche.sql`](supabase/migrations/0007_aviso_enganche.sql)
8. [`supabase/migrations/0008_cola_multiple.sql`](supabase/migrations/0008_cola_multiple.sql)
9. [`supabase/migrations/0009_tomas_sin_app.sql`](supabase/migrations/0009_tomas_sin_app.sql)
10. [`supabase/migrations/0010_push_notificaciones.sql`](supabase/migrations/0010_push_notificaciones.sql)

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

La séptima avisa a la cola cuando un puesto se ocupa:

1. Al engancharse alguien, se crea un aviso personal para cada usuario que
   sigue esperando en la cola de ese tipo.
2. El aviso indica tipo de estación, nombre, poste y toma.
3. Aparece en el panel **Avisos** y como toast en tiempo real.

La octava permite combinar carga y colas:

1. Un usuario puede estar cargando y apuntado a una o varias colas, con el
   límite de **una cola por tipo de estación y día**.
2. Al engancharse a un puesto solo se cierra la cola de ese tipo; las demás
   siguen activas.
3. No se permite apuntarse a la cola del tipo en el que ya se está cargando.
4. La cola sigue exigiendo que todos los postes del tipo estén ocupados.

La novena permite ocupar tomas para personas que no usan la app:

1. Separa quién registra el cambio (`usuario_id`) de quién ocupa realmente
   (`usuario_ocupante_id`). Un ocupante `NULL` no tiene cuenta en la app.
2. Cualquier usuario autenticado puede marcar una toma libre como ocupada por
   otra persona.
3. Cualquier usuario autenticado puede marcar como libre una toma ocupada por
   alguien sin app. La ocupación de un usuario registrado solo la libera ese
   usuario.
4. Un usuario puede marcar varias tomas para otros, incluso mientras ocupa una
   él mismo, y esto no le saca de ninguna cola.

La décima añade las notificaciones push con FCM:

1. Crea `dispositivos_push` con un token por instalación o navegador.
2. Añade las RPC `registrar_dispositivo_push` y `eliminar_dispositivo_push`.
3. Crea el trigger `on_aviso_push`, que llama de forma asíncrona a la Edge
   Function `send-push` cada vez que se inserta un aviso personal.
4. Deja Realtime intacto: el push solo cubre la app en segundo plano o cerrada.

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

### Configurar notificaciones push (FCM)

La app usa FCM para avisar de los mismos eventos que ya crea la tabla `avisos`:
puesto ocupado, puesto libre para los tres primeros de la cola y tomas ocupadas
por personas sin app. El WebSocket sigue actualizando la Home en vivo; el push
solo actúa en segundo plano o con la app cerrada.

#### 1. Crear el proyecto en Firebase

1. Crea un proyecto en <https://console.firebase.google.com>.
2. **Añadir app Android** con el package `com.electrolinera.app` y descarga
   `google-services.json`.
3. **Añadir app Web** y copia su configuración:
   `apiKey`, `projectId`, `messagingSenderId` y `appId`.
4. **Configuración del proyecto → Cloud Messaging → Certificados push web**:
   genera un par de claves y copia la clave pública (VAPID).
5. **Configuración del proyecto → Cuentas de servicio → Generar nueva clave
   privada**: descarga el JSON y guárdalo en base64 para Supabase.
6. Comprueba que la **Firebase Cloud Messaging API (V1)** está habilitada.

#### 2. Variables del frontend

Rellena en `.env.local` (y en las variables `vars.*` del repositorio):

```dotenv
VITE_FIREBASE_API_KEY=...
VITE_FIREBASE_PROJECT_ID=...
VITE_FIREBASE_MESSAGING_SENDER_ID=...
VITE_FIREBASE_APP_ID=...
VITE_FIREBASE_VAPID_KEY=...
```

Son valores públicos: la `apiKey` de Firebase no da acceso a la base de datos.
Si faltan, la web compila igualmente pero el panel de notificaciones indica que
no están disponibles.

#### 3. Secretos de Supabase

```bash
# Cuenta de servicio en base64 (una sola línea)
# Linux / Git Bash: base64 -w0 service-account.json
# macOS: base64 -i service-account.json | tr -d '\n'
npx supabase secrets set \
  FCM_SERVICE_ACCOUNT_B64="<base64>" \
  PUSH_WEBHOOK_SECRET="<secreto-aleatorio-largo>" \
  --project-ref clgtafomlilvvnjlfvab

npx supabase functions deploy send-push --no-verify-jwt \
  --project-ref clgtafomlilvvnjlfvab
```

Después de ejecutar `0010_push_notificaciones.sql`, guarda la URL de la función
y el mismo secreto en Vault:

```sql
select vault.create_secret(
  'https://clgtafomlilvvnjlfvab.supabase.co/functions/v1/send-push',
  'push_function_url'
);
select vault.create_secret('<secreto-aleatorio-largo>', 'push_webhook_secret');
```

Si ya existen, actualízalos con `update vault.secrets set secret = ... where name = ...`.

#### 4. Android

Coloca `google-services.json` en `android/app/`. Para el APK de CI, guárdalo en
base64 como secreto `GOOGLE_SERVICES_JSON_BASE64`. El workflow lo decodifica
antes de compilar; si falta, el APK se genera sin push pero sin romper el build.

El plugin crea el canal **Avisos** al arrancar. El permiso
`POST_NOTIFICATIONS` se pide la primera vez que hay sesión en Android 13+.

#### 5. Web

- Requiere Chrome o Edge y HTTPS (o `localhost` en desarrollo).
- El service worker `public/push-sw.js` recibe los push en segundo plano.
- El permiso se pide desde **Mi cuenta → Notificaciones → Activar
  notificaciones**, porque Chrome exige un gesto del usuario.
- Con la pestaña abierta y enfocada no se muestra notificación: Realtime ya
  pinta el aviso en la Home.

#### 6. Comprobar que funciona

1. Inicia sesión, activa las notificaciones y verifica que aparece una fila en
   `public.dispositivos_push` con la plataforma correcta.
2. Inserta un aviso de prueba para ese usuario:

   ```sql
   insert into public.avisos (aviso, lista_espera_estacion_id, usuario_id, fecha_hora)
   select 'Prueba de push', le.id, le.usuario_id, now()
   from public.lista_espera_estacion le
   where le.usuario_id = '<uuid-del-usuario>'
   limit 1;
   ```

3. Cierra o minimiza la app y comprueba que llega la notificación.
4. Al pulsarla debe abrir o enfocar la Home.
5. Al cerrar sesión debe desaparecer el token del usuario.

> Si la función no está desplegada o faltan los secretos, el trigger no rompe
> ninguna RPC: simplemente no envía push.

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

- **Resumen por tipo**: el nombre de cada tarjeta (y su enlace **Ver detalle**)
  abre el bloque plegado de ese tipo y desplaza la vista hasta él.
- **Detalle por tipo**: las tarjetas de puestos están **plegadas por defecto**;
  se abren al pulsar su cabecera o desde **Ver detalle** en el resumen.
- **Invitado**:
  - Ve solo el resumen por tipo: nombre y total de puestos.
  - No ve el detalle de los puestos, ni libres/ocupados, tiempo, cola o avisos.
  - Tiene botón `Entrar` en el header y CTA `Crear cuenta` / `Ya tengo cuenta`.
- **Usuario autenticado**:
  - Ve el estado diario completo y los avisos en tiempo real.
  - Tiene un indicador de su situación: **Estás cargando** (estación, poste y
    toma), una fila **En lista de espera** por cada cola (estación y posición),
    una fila **Has marcado una toma** por cada toma ocupada por alguien sin app,
    o **Sin actividad**. Solo aparece con sesión iniciada y se actualiza con
    Realtime.
  - Puede engancharse a un poste libre y desengancharse del suyo.
  - Puede marcar una toma libre como **ocupada por otra persona** que no usa
    la app, y marcarla libre después. Estas tomas aparecen en su panel de
    estado como **Has marcado una toma**.
  - Puede apuntarse a la cola de un tipo cuando todos sus postes están ocupados.
  - Dispone del menú lateral y del acceso a `Mi cuenta` desde el header.
- **Enganche**:
  - Un poste sin registros hoy cuenta como `Libre`.
  - Solo puede haber un puesto ocupado por el mismo usuario y día. Las tomas
    marcadas para personas sin app no cuentan como ocupación propia.
  - Mientras está enganchado, solo puede desengancharse de ese poste.
  - Al desengancharse, el poste vuelve a estar libre y puede volver a
    engancharse el mismo día.
  - Una toma puede marcarse como ocupada por una persona sin app. En ese caso
    el ocupante registrado es `NULL` y cualquiera puede volver a marcarla
    libre. El usuario que la marca no queda enganchado ni sale de la cola.
- **Cola**:
  - Solo se permite cuando el tipo está completo.
  - Un usuario puede estar en varias colas a la vez (una por tipo), incluso
    mientras está cargando en otro tipo.
  - El resumen de cada tipo muestra **Ponerse en la cola** cuando todos sus
    puestos están ocupados y el usuario aún no está apuntado, y **Salir de la
    cola** cuando ya está dentro.
  - Se puede entrar, salir y volver a entrar en la misma cola varias veces el
    mismo día: cada entrada crea una posición nueva. Solo se sale al pulsar
    **Salir de la cola** o al engancharse a un puesto; recibir un aviso no
    saca de la cola.
  - Al engancharse a un puesto solo se cierra la cola de ese tipo; las colas
    de otros tipos se mantienen.
  - Con una cola activa, solo los usuarios apuntados a esa cola pueden
    engancharse a un poste libre del tipo. Marcar una toma para otra persona no
    está limitado por la cola.
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
| `npm run build:pages` | Build + descarga del último APK a `dist/downloads/` |
| `npm run preview` | Sirve el build de producción |
| `npm run typecheck` | Solo comprobación de tipos con `vue-tsc` |
| `npm run cap:sync` | Build + copia los assets a Android |
| `npm run android` | Abre el proyecto Android en Android Studio |

## Distribución del APK

Cada push a `main` ejecuta `.github/workflows/android-apk.yml`:

1. Compila la web y sincroniza Capacitor.
2. Firma un APK de release con el keystore de los secretos.
3. Publica `electrolinera.apk` y `latest.json` en la release rodante
   `apk-latest` de GitHub.
4. Llama al deploy hook de Cloudflare Pages.

Cloudflare Pages usa `npm run build:pages`: además de compilar la web, descarga
el último APK y lo deja en `dist/downloads/`. Queda disponible en:

- `/downloads/electrolinera.apk`
- `/descargar` (versión y botón de descarga)
- enlace “Descargar app Android” en el pie de la Home y en el menú lateral.

### Secretos del repositorio (GitHub)
- `ANDROID_KEYSTORE_BASE64`: keystore en base64.
- `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
- `CLOUDFLARE_DEPLOY_HOOK_URL`: deploy hook del proyecto de Pages.

Variables (no secretas): `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` y
`VITE_APP_URL`.

### Cloudflare Pages
- Build command: `npm run build:pages`.
- El hook se encarga de reconstruir el sitio cuando el APK ya está publicado,
  evitando que la web sirva la versión anterior.

La versión del APK es la de `package.json` más el número de ejecución
(`0.1.0+123`), y `versionCode` es ese mismo número: siempre crece para que
Android acepte la actualización. El keystore debe conservarse: sin él no se
pueden publicar actualizaciones sobre instalaciones existentes.

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
│  ├─ useHomeLive.ts       # Snapshot, canal único, pausa/resync
│  └─ usePushNotifications.ts # Permiso, token FCM y deep link
├─ data/preview.ts         # Datos de vista previa (?preview=1)
├─ router/index.ts         # Rutas + guard de autenticación
├─ services/
│  ├─ auth.service.ts      # Supabase Auth + tabla usuarios
│  ├─ authSettings.service.ts # Ajuste público de confirmación de email
│  ├─ estacion.service.ts  # RPC de enganche, desenganche y cola
│  ├─ firebase.ts          # Init web de Firebase Messaging
│  ├─ home.service.ts      # Consultas a las vistas
│  ├─ push.service.ts      # Token FCM, RPC de dispositivos y desregistro
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
   ├─ DownloadPage.vue     # Descarga del APK (/descargar)
   ├─ HomePage.vue
   ├─ LoginPage.vue
   ├─ RegisterPage.vue
   └─ SettingsPage.vue     # Configuración (solo admin)
public/
└─ push-sw.js              # Service worker de web push
scripts/
└─ fetch-apk.mjs           # Copia el último APK a dist/downloads en Pages
.github/workflows/
└─ android-apk.yml         # Build del APK firmado + release
supabase/
├─ functions/
│  ├─ auth-settings/
│  │  └─ index.ts          # Cambia mailer_autoconfirm vía Management API
│  └─ send-push/
│     └─ index.ts          # Envía los avisos por FCM HTTP v1
└─ migrations/
   ├─ 0001_home.sql
   ├─ 0002_users.sql
   ├─ 0003_home_public.sql
   ├─ 0004_gestion_diaria.sql
   ├─ 0005_admin_config.sql
   ├─ 0006_home_cola.sql
   ├─ 0007_aviso_enganche.sql
   ├─ 0008_cola_multiple.sql
   ├─ 0009_tomas_sin_app.sql
   └─ 0010_push_notificaciones.sql
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
  `Ocupado`), el usuario que realizó el cambio, el ocupante real, el día y si
  la ocupación está activa. `usuario_id` es quien registra el cambio y
  `usuario_ocupante_id` es quien ocupa. Si el ocupante es `NULL`, la toma está
  siendo usada por alguien sin cuenta en la app.
- `lista_espera_estacion` guarda la cola por tipo y día. Las entradas de cola
  no llevan una estación concreta; se activan cuando el tipo está completo. Un
  usuario puede tener una entrada activa por tipo y día, además de estar
  cargando.
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
- Si el canal se cae (`CHANNEL_ERROR`, `TIMED_OUT` o `CLOSED`), se reintenta con
  esperas de 2 s, 5 s, 15 s, 30 s y 60 s; al recuperarlo se relee el snapshot,
  porque Realtime no reenvía los eventos perdidos.
- Al recuperar o perder la red (`online`/`offline`) se reconstruye el canal y se
  hace un resync.
- El botón **Actualizar** solo aparece en la web; en la app nativa se refresca
  con el gesto de pull-to-refresh.
- Si la sesión cambia, la Home recarga la vista correspondiente y reconstruye el
  canal, de modo que el estado aparece o desaparece sin recargar la página.
- Si cambia el día mientras la app está abierta, la Home se recarga
  automáticamente.
- `eventsPerSecond: 10` limita la presión de eventos.
- **Push**: el trigger de `avisos` llama a `send-push` mediante `pg_net` de
  forma asíncrona. Cada token recibe un único mensaje FCM. Si el token ya no es
  válido, la función lo desactiva; un fallo de FCM nunca revierte la RPC que
  creó el aviso.

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
- Las tomas ocupadas por personas sin app se registran con
  `usuario_ocupante_id = NULL`. Cualquier usuario autenticado puede marcarlas
  libres; las de usuarios registrados solo las libera su ocupante.
- Los avisos tienen RLS por usuario: cada persona solo ve y recibe los suyos.
- Los tokens de push viven en `dispositivos_push`; cada usuario solo puede leer
  los suyos y las escrituras pasan por RPC.
- La cuenta de servicio de Firebase solo existe como secreto de la Edge
  Function (`FCM_SERVICE_ACCOUNT_B64`). El frontend nunca la recibe.
- El secreto compartido entre `pg_net` y `send-push` está en Vault y en los
  secretos de la función; no se guarda en el repositorio.
- Nunca incluyas `sb_secret_...` en `.env.local` ni en el repositorio.
- Si una secret key se ha compartido, revócala en **Project Settings → API Keys**.

## Créditos de iconos

Los iconos de enchufe y desenchufe son SVG locales basados en
[Lucide](https://lucide.dev/) (`plug-zap` y `unplug`), licencia ISC.

## Próximos pasos

- Secciones de Estaciones, Lista de espera, Usuarios y Avisos.
- Histórico de días anteriores en una pantalla específica.
- Push en iOS mediante APNs (requiere app nativa y PWA instalada en Safari).
- Filtros por tipo de estación y búsqueda.
- Recuperación de contraseña y verificación adicional.
