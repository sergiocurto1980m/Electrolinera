-- ============================================================================
-- Electrolinera · 0009_tomas_sin_app.sql
--
-- Permite reflejar tomas ocupadas por personas que no usan la app:
--
--   · situacion_estacion.usuario_id         = quién registra el cambio.
--   · situacion_estacion.usuario_ocupante_id = quién ocupa realmente.
--     NULL significa que el ocupante no tiene cuenta en la app.
--
--   · Cualquier usuario autenticado puede marcar una toma libre como ocupada
--     por otra persona y liberarla después.
--   · La ocupación de un usuario registrado solo la puede liberar ese usuario.
--   · Marcar una toma para otro no saca al usuario de ninguna cola: refleja la
--     realidad física de la estación.
--
-- Ejecutar después de 0001–0008. Es idempotente.
-- ============================================================================

-- 1) Ocupante real de la toma -------------------------------------------------
alter table public.situacion_estacion
  add column if not exists usuario_ocupante_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'situacion_estacion_ocupante_fkey'
      and conrelid = 'public.situacion_estacion'::regclass
  ) then
    alter table public.situacion_estacion
      add constraint situacion_estacion_ocupante_fkey
      foreign key (usuario_ocupante_id) references public.usuarios(id)
      on delete set null;
  end if;
end;
$$;

/*
 * Hasta ahora usuario_id era a la vez quién registraba y quién ocupaba. Las
 * ocupaciones activas existentes pasan a tener un ocupante registrado.
 */
update public.situacion_estacion
set usuario_ocupante_id = usuario_id
where activo
  and usuario_ocupante_id is null;

create index if not exists idx_situacion_ocupante
  on public.situacion_estacion (usuario_ocupante_id)
  where usuario_ocupante_id is not null;

-- 2) Una ocupación activa por ocupante y día ---------------------------------
-- El límite deja de aplicarse a quien registra el cambio y se aplica al
-- ocupante real. Así un usuario puede ocupar una toma y, a la vez, marcar
-- otras tomas para personas sin app.
drop index if exists public.uq_situacion_usuario_activo_dia;

create unique index if not exists uq_situacion_ocupante_activo_dia
  on public.situacion_estacion (usuario_ocupante_id, dia)
  where activo and usuario_ocupante_id is not null;

-- 3) RPC: entrar en la cola de un tipo ----------------------------------------
-- Solo impide apuntarse a la cola del tipo en el que el usuario ocupa un
-- puesto. Haber marcado tomas para otros no cuenta como estar cargando.
create or replace function public.entrar_en_cola(p_tipo_estacion_id integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_dia date := (now() at time zone 'Europe/Madrid')::date;
  v_en_lista integer;
  v_total integer;
  v_ocupadas integer;
  v_tipo_nombre text;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión.';
  end if;

  if not exists (
    select 1
    from public.usuarios
    where id = v_uid and not borrado
  ) then
    raise exception 'Tu cuenta no está activa.';
  end if;

  select nombre
  into v_tipo_nombre
  from public.tipo_estacion
  where id = p_tipo_estacion_id;

  if v_tipo_nombre is null then
    raise exception 'El tipo de estación no existe.';
  end if;

  select id into v_en_lista
  from public.tipo_lista_espera_estacion
  where nombre = 'En Lista';

  if v_en_lista is null then
    raise exception 'No existe el tipo de lista "En Lista".';
  end if;

  perform pg_advisory_xact_lock(
    hashtext('tipo:' || p_tipo_estacion_id::text)::bigint
  );
  perform pg_advisory_xact_lock(
    hashtext('usuario:' || v_uid::text || ':' || v_dia::text)::bigint
  );

  /*
   * Estar cargando no impide apuntarse a la cola de otros tipos, pero no
   * tiene sentido esperar por el tipo en el que ya se ocupa un puesto.
   */
  if exists (
    select 1
    from public.situacion_estacion s
    join public.estaciones e on e.id = s.estacion_id
    where s.usuario_ocupante_id = v_uid
      and s.dia = v_dia
      and s.activo
      and e.tipo_estacion_id = p_tipo_estacion_id
  ) then
    raise exception 'Ya estás cargando en este tipo de estación.';
  end if;

  if exists (
    select 1
    from public.lista_espera_estacion
    where usuario_id = v_uid
      and tipo_estacion_id = p_tipo_estacion_id
      and dia = v_dia
      and tipo_lista_espera_estacion_id = v_en_lista
  ) then
    raise exception 'Ya estás en la cola de este tipo.';
  end if;

  select count(*)
  into v_total
  from public.estaciones
  where tipo_estacion_id = p_tipo_estacion_id;

  select count(distinct e.id)
  into v_ocupadas
  from public.estaciones e
  join public.situacion_estacion s
    on s.estacion_id = e.id
   and s.dia = v_dia
   and s.activo
  where e.tipo_estacion_id = p_tipo_estacion_id;

  if v_total = 0 then
    raise exception 'No hay postes en este tipo.';
  end if;

  if v_ocupadas < v_total then
    raise exception 'Todavía hay puestos libres en este tipo. No puedes apuntarte a la cola.';
  end if;

  insert into public.lista_espera_estacion (
    estacion_id,
    usuario_id,
    tipo_estacion_id,
    tipo_lista_espera_estacion_id,
    dia
  ) values (
    null,
    v_uid,
    p_tipo_estacion_id,
    v_en_lista,
    v_dia
  );

  return jsonb_build_object(
    'ok', true,
    'tipo_estacion_id', p_tipo_estacion_id,
    'dia', v_dia
  );
end;
$$;

-- 4) RPC: engancharse ----------------------------------------------------------
-- Solo se cierra la cola del tipo en el que se engancha. Las colas de otros
-- tipos siguen activas.
create or replace function public.engancharse(p_estacion_id integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_dia date := (now() at time zone 'Europe/Madrid')::date;
  v_tipo_id integer;
  v_tipo_nombre text;
  v_usuario_nombre text;
  v_ocupado integer;
  v_en_lista integer;
  v_cargando integer;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión.';
  end if;

  if not exists (
    select 1
    from public.usuarios
    where id = v_uid and not borrado
  ) then
    raise exception 'Tu cuenta no está activa.';
  end if;

  select coalesce(nullif(trim(nombre), ''), 'Un usuario')
  into v_usuario_nombre
  from public.usuarios
  where id = v_uid;

  select e.tipo_estacion_id, te.nombre
  into v_tipo_id, v_tipo_nombre
  from public.estaciones e
  join public.tipo_estacion te on te.id = e.tipo_estacion_id
  where e.id = p_estacion_id;

  if v_tipo_id is null then
    raise exception 'La estación no existe.';
  end if;

  select id into v_ocupado
  from public.tipo_estado_estacion
  where nombre = 'Ocupado';

  select id into v_en_lista
  from public.tipo_lista_espera_estacion
  where nombre = 'En Lista';

  select id into v_cargando
  from public.tipo_lista_espera_estacion
  where nombre = 'Cargando';

  if v_ocupado is null
    or v_en_lista is null
    or v_cargando is null then
    raise exception 'Faltan tipos de estado o de cola en la base de datos.';
  end if;

  perform pg_advisory_xact_lock(hashtext('tipo:' || v_tipo_id::text)::bigint);
  perform pg_advisory_xact_lock(
    hashtext('usuario:' || v_uid::text || ':' || v_dia::text)::bigint
  );

  /*
   * Solo bloquea si el usuario ocupa realmente un puesto. Las tomas marcadas
   * para personas sin app no cuentan como ocupación propia.
   */
  if exists (
    select 1
    from public.situacion_estacion
    where usuario_ocupante_id = v_uid and dia = v_dia and activo
  ) then
    raise exception 'Ya estás enganchado a un poste. Desenganchate primero.';
  end if;

  if exists (
    select 1
    from public.situacion_estacion
    where estacion_id = p_estacion_id and dia = v_dia and activo
  ) then
    raise exception 'Ese puesto ya está ocupado.';
  end if;

  if exists (
    select 1
    from public.lista_espera_estacion
    where tipo_estacion_id = v_tipo_id
      and dia = v_dia
      and tipo_lista_espera_estacion_id = v_en_lista
  ) and not exists (
    select 1
    from public.lista_espera_estacion
    where usuario_id = v_uid
      and tipo_estacion_id = v_tipo_id
      and dia = v_dia
      and tipo_lista_espera_estacion_id = v_en_lista
  ) then
    raise exception 'Hay una cola activa para este tipo. Solo pueden engancharse los usuarios apuntados.';
  end if;

  insert into public.situacion_estacion (
    estacion_id,
    tipo_estado_estacion_id,
    usuario_id,
    usuario_ocupante_id,
    dia,
    activo
  ) values (
    p_estacion_id,
    v_ocupado,
    v_uid,
    v_uid,
    v_dia,
    true
  );

  update public.lista_espera_estacion
  set tipo_lista_espera_estacion_id = v_cargando,
      estacion_id = p_estacion_id,
      fecha_hora = now()
  where usuario_id = v_uid
    and tipo_estacion_id = v_tipo_id
    and dia = v_dia
    and tipo_lista_espera_estacion_id = v_en_lista;

  /*
   * Avisamos a quienes siguen en la cola de este tipo de que el puesto acaba
   * de ocuparse. El usuario que se engancha ya no está en "En Lista", pero se
   * excluye explícitamente por claridad.
   */
  insert into public.avisos (
    aviso,
    lista_espera_estacion_id,
    usuario_id,
    estacion_id,
    fecha_hora
  )
  select
    'En ' || v_tipo_nombre || ', ' || v_usuario_nombre
      || ' se ha enganchado al Poste ' || tp.nombre
      || ' · Toma ' || tt.nombre || '.',
    le.id,
    le.usuario_id,
    p_estacion_id,
    now()
  from public.lista_espera_estacion le
  join public.tipo_lista_espera_estacion t
    on t.id = le.tipo_lista_espera_estacion_id
  join public.estaciones e on e.id = p_estacion_id
  join public.tipo_poste tp on tp.id = e.tipo_poste_id
  join public.tipo_toma tt on tt.id = e.tipo_toma_id
  where le.dia = v_dia
    and le.tipo_estacion_id = v_tipo_id
    and t.nombre = 'En Lista'
    and le.usuario_id <> v_uid;

  return jsonb_build_object(
    'ok', true,
    'estacion_id', p_estacion_id,
    'tipo_estacion_id', v_tipo_id,
    'dia', v_dia
  );
end;
$$;

-- 5) RPC: marcar una toma ocupada por otra persona ----------------------------
-- Registra una ocupación sin ocupante de la app. No modifica la cola del
-- usuario que la marca.
create or replace function public.marcar_ocupada_por_otro(p_estacion_id integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_dia date := (now() at time zone 'Europe/Madrid')::date;
  v_tipo_id integer;
  v_tipo_nombre text;
  v_poste_nombre text;
  v_toma_nombre text;
  v_ocupado integer;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión.';
  end if;

  if not exists (
    select 1
    from public.usuarios
    where id = v_uid and not borrado
  ) then
    raise exception 'Tu cuenta no está activa.';
  end if;

  select e.tipo_estacion_id, te.nombre, tp.nombre, tt.nombre
  into v_tipo_id, v_tipo_nombre, v_poste_nombre, v_toma_nombre
  from public.estaciones e
  join public.tipo_estacion te on te.id = e.tipo_estacion_id
  join public.tipo_poste tp on tp.id = e.tipo_poste_id
  join public.tipo_toma tt on tt.id = e.tipo_toma_id
  where e.id = p_estacion_id;

  if v_tipo_id is null then
    raise exception 'La estación no existe.';
  end if;

  select id into v_ocupado
  from public.tipo_estado_estacion
  where nombre = 'Ocupado';

  if v_ocupado is null then
    raise exception 'Falta el tipo de estado "Ocupado" en la base de datos.';
  end if;

  perform pg_advisory_xact_lock(hashtext('tipo:' || v_tipo_id::text)::bigint);
  perform pg_advisory_xact_lock(
    hashtext('estacion:' || p_estacion_id::text)::bigint
  );

  if exists (
    select 1
    from public.situacion_estacion
    where estacion_id = p_estacion_id and dia = v_dia and activo
  ) then
    raise exception 'Ese puesto ya está ocupado.';
  end if;

  insert into public.situacion_estacion (
    estacion_id,
    tipo_estado_estacion_id,
    usuario_id,
    usuario_ocupante_id,
    dia,
    activo
  ) values (
    p_estacion_id,
    v_ocupado,
    v_uid,
    null,
    v_dia,
    true
  );

  /*
   * La toma está físicamente ocupada, así que avisamos a la cola del tipo
   * con un mensaje neutro. No se nombra a ningún usuario porque el ocupante
   * no tiene cuenta en la app.
   */
  insert into public.avisos (
    aviso,
    lista_espera_estacion_id,
    usuario_id,
    estacion_id,
    fecha_hora
  )
  select
    'En ' || v_tipo_nombre || ', se ha ocupado el Poste '
      || v_poste_nombre || ' · Toma ' || v_toma_nombre || '.',
    le.id,
    le.usuario_id,
    p_estacion_id,
    now()
  from public.lista_espera_estacion le
  join public.tipo_lista_espera_estacion t
    on t.id = le.tipo_lista_espera_estacion_id
  where le.dia = v_dia
    and le.tipo_estacion_id = v_tipo_id
    and t.nombre = 'En Lista';

  return jsonb_build_object(
    'ok', true,
    'estacion_id', p_estacion_id,
    'tipo_estacion_id', v_tipo_id,
    'dia', v_dia
  );
end;
$$;

-- 6) RPC: desengancharse / liberar una toma -----------------------------------
-- Libera la ocupación propia o cualquier ocupación de una persona sin app.
-- La ocupación de otro usuario registrado sigue siendo exclusiva de su dueño.
create or replace function public.desengancharse(p_estacion_id integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_dia date := (now() at time zone 'Europe/Madrid')::date;
  v_situacion_id bigint;
  v_ocupante_id uuid;
  v_tipo_id integer;
  v_tipo_nombre text;
  v_libre integer;
  v_en_lista integer;
  v_cargando integer;
  v_desenchufado integer;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión.';
  end if;

  if not exists (
    select 1
    from public.usuarios
    where id = v_uid and not borrado
  ) then
    raise exception 'Tu cuenta no está activa.';
  end if;

  select e.tipo_estacion_id, te.nombre
  into v_tipo_id, v_tipo_nombre
  from public.estaciones e
  join public.tipo_estacion te on te.id = e.tipo_estacion_id
  where e.id = p_estacion_id;

  if v_tipo_id is null then
    raise exception 'La estación no existe.';
  end if;

  select id into v_libre
  from public.tipo_estado_estacion
  where nombre = 'Libre';

  select id into v_en_lista
  from public.tipo_lista_espera_estacion
  where nombre = 'En Lista';

  select id into v_cargando
  from public.tipo_lista_espera_estacion
  where nombre = 'Cargando';

  select id into v_desenchufado
  from public.tipo_lista_espera_estacion
  where nombre = 'Desenchufado';

  if v_libre is null
    or v_en_lista is null
    or v_cargando is null
    or v_desenchufado is null then
    raise exception 'Faltan tipos de estado o de cola en la base de datos.';
  end if;

  perform pg_advisory_xact_lock(hashtext('tipo:' || v_tipo_id::text)::bigint);
  perform pg_advisory_xact_lock(
    hashtext('usuario:' || v_uid::text || ':' || v_dia::text)::bigint
  );

  select s.id, s.usuario_ocupante_id
  into v_situacion_id, v_ocupante_id
  from public.situacion_estacion s
  where s.estacion_id = p_estacion_id
    and s.dia = v_dia
    and s.activo
  for update;

  if v_situacion_id is null then
    raise exception 'Ese puesto no está ocupado.';
  end if;

  /*
   * Cualquier usuario puede liberar una ocupación sin cuenta (ocupante NULL).
   * Si hay ocupante registrado, solo él puede desengancharse.
   */
  if v_ocupante_id is not null and v_ocupante_id <> v_uid then
    raise exception 'Ese puesto lo ocupa otro usuario.';
  end if;

  update public.situacion_estacion
  set activo = false
  where id = v_situacion_id;

  insert into public.situacion_estacion (
    estacion_id,
    tipo_estado_estacion_id,
    usuario_id,
    usuario_ocupante_id,
    dia,
    activo
  ) values (
    p_estacion_id,
    v_libre,
    v_uid,
    null,
    v_dia,
    false
  );

  update public.lista_espera_estacion
  set tipo_lista_espera_estacion_id = v_desenchufado,
      fecha_hora = now()
  where usuario_id = v_uid
    and dia = v_dia
    and tipo_estacion_id = v_tipo_id
    and tipo_lista_espera_estacion_id = v_cargando
    and estacion_id = p_estacion_id;

  /*
   * Avisamos a los tres primeros de la cola del tipo. Se evita duplicar el
   * aviso para la misma entrada de cola durante el mismo día.
   */
  insert into public.avisos (
    aviso,
    lista_espera_estacion_id,
    usuario_id,
    fecha_hora
  )
  select
    'Hay un puesto libre en ' || v_tipo_nombre || '. Puedes engancharte.',
    q.id,
    q.usuario_id,
    now()
  from (
    select le.id, le.usuario_id
    from public.lista_espera_estacion le
    where le.dia = v_dia
      and le.tipo_estacion_id = v_tipo_id
      and le.tipo_lista_espera_estacion_id = v_en_lista
      and not exists (
        select 1
        from public.avisos a
        where a.lista_espera_estacion_id = le.id
          and (a.fecha_hora at time zone 'Europe/Madrid')::date = v_dia
      )
    order by le.fecha_hora, le.id
    limit 3
  ) q;

  return jsonb_build_object(
    'ok', true,
    'estacion_id', p_estacion_id,
    'tipo_estacion_id', v_tipo_id,
    'dia', v_dia
  );
end;
$$;

-- 7) Vista diaria con el ocupante real ----------------------------------------
drop view if exists public.v_home_estaciones;

create view public.v_home_estaciones
with (security_invoker = true) as
with hoy as (
  select (now() at time zone 'Europe/Madrid')::date as dia
),
ultima_situacion as (
  select distinct on (s.estacion_id)
    s.estacion_id,
    s.tipo_estado_estacion_id,
    s.fecha_hora
  from public.situacion_estacion s
  cross join hoy
  where s.dia = hoy.dia
  order by s.estacion_id, s.fecha_hora desc, s.id desc
),
activa as (
  select
    s.estacion_id,
    s.usuario_id,
    s.usuario_ocupante_id
  from public.situacion_estacion s
  cross join hoy
  where s.dia = hoy.dia and s.activo
),
cola_por_tipo as (
  select
    le.tipo_estacion_id,
    count(*)::int as en_cola
  from public.lista_espera_estacion le
  join public.tipo_lista_espera_estacion t
    on t.id = le.tipo_lista_espera_estacion_id
  cross join hoy
  where le.dia = hoy.dia
    and t.nombre = 'En Lista'
  group by le.tipo_estacion_id
)
select
  e.id,
  te.id as tipo_estacion_id,
  te.nombre as tipo_estacion,
  tp.nombre as tipo_poste,
  tt.nombre as tipo_toma,
  coalesce(se.nombre, 'Libre') as estado,
  us.fecha_hora as estado_desde,
  coalesce(cpt.en_cola, 0) as en_cola_tipo,
  case when a.usuario_id is not null then 1 else 0 end as cargando,
  coalesce(a.usuario_ocupante_id = auth.uid(), false) as es_mio,
  exists (
    select 1
    from public.lista_espera_estacion le
    join public.tipo_lista_espera_estacion t
      on t.id = le.tipo_lista_espera_estacion_id
    cross join hoy
    where le.dia = hoy.dia
      and le.tipo_estacion_id = te.id
      and le.usuario_id = auth.uid()
      and t.nombre = 'En Lista'
  ) as mi_en_cola,
  coalesce(
    a.usuario_id = auth.uid() and a.usuario_ocupante_id is null,
    false
  ) as marcada_por_mi,
  coalesce(
    a.estacion_id is not null and a.usuario_ocupante_id is null,
    false
  ) as ocupada_por_otro
from public.estaciones e
join public.tipo_estacion te on te.id = e.tipo_estacion_id
join public.tipo_poste tp on tp.id = e.tipo_poste_id
join public.tipo_toma tt on tt.id = e.tipo_toma_id
left join ultima_situacion us on us.estacion_id = e.id
left join public.tipo_estado_estacion se on se.id = us.tipo_estado_estacion_id
left join cola_por_tipo cpt on cpt.tipo_estacion_id = te.id
left join activa a on a.estacion_id = e.id;

grant select on public.v_home_estaciones to authenticated;

-- 8) Permisos -----------------------------------------------------------------
revoke all on function public.marcar_ocupada_por_otro(integer) from public, anon;
revoke all on function public.engancharse(integer) from public, anon;
revoke all on function public.desengancharse(integer) from public, anon;
revoke all on function public.entrar_en_cola(integer) from public, anon;

grant execute on function public.marcar_ocupada_por_otro(integer) to authenticated;
grant execute on function public.engancharse(integer) to authenticated;
grant execute on function public.desengancharse(integer) to authenticated;
grant execute on function public.entrar_en_cola(integer) to authenticated;

-- 9) Recargar el schema cache -------------------------------------------------
notify pgrst, 'reload schema';
