-- ============================================================================
-- Electrolinera · 0008_cola_multiple.sql
--
-- Permite que un usuario esté cargando y, a la vez, apuntado a una o varias
-- colas: como máximo una por tipo de estación y día.
--
--   · La cola sigue exigiendo que el tipo esté completo.
--   · Al engancharse a un puesto solo se cierra la cola de ese tipo; las
--     colas de otros tipos se mantienen.
--   · Se impide apuntarse a la cola del tipo en el que ya se está cargando.
--
-- Ejecutar después de 0001–0007. Es idempotente.
-- ============================================================================

-- 1) Una cola por tipo y día ----------------------------------------------------
drop index if exists public.uq_lista_usuario_en_lista_dia;

do $$
declare
  v_en_lista integer;
begin
  select id into v_en_lista
  from public.tipo_lista_espera_estacion
  where nombre = 'En Lista';

  if v_en_lista is null then
    raise exception 'No existe el tipo de lista "En Lista".';
  end if;

  execute format(
    'create unique index if not exists uq_lista_usuario_tipo_en_lista_dia
       on public.lista_espera_estacion (usuario_id, tipo_estacion_id, dia)
       where tipo_lista_espera_estacion_id = %s',
    v_en_lista
  );
end;
$$;

-- 2) RPC: entrar en la cola de un tipo ------------------------------------------
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
    where s.usuario_id = v_uid
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

-- 3) RPC: engancharse ------------------------------------------------------------
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

  if exists (
    select 1
    from public.situacion_estacion
    where usuario_id = v_uid and dia = v_dia and activo
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
    dia,
    activo
  ) values (
    p_estacion_id,
    v_ocupado,
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

-- 4) Permisos --------------------------------------------------------------------
revoke all on function public.entrar_en_cola(integer) from public, anon;
revoke all on function public.engancharse(integer) from public, anon;

grant execute on function public.entrar_en_cola(integer) to authenticated;
grant execute on function public.engancharse(integer) to authenticated;

-- 5) Recargar el schema cache ----------------------------------------------------
notify pgrst, 'reload schema';
