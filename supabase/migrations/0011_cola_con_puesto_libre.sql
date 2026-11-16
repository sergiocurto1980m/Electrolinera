-- ============================================================================
-- Electrolinera · 0011_cola_con_puesto_libre.sql
--
-- Permite que un usuario se apunte a una cola activa aunque en ese momento
-- haya algún puesto libre.
--
-- Regla:
--   · Si no hay cola y hay puestos libres, el usuario debe engancharse
--     directamente (no tiene sentido apuntarse a una cola inexistente).
--   · Si ya hay una cola activa para ese tipo y día, se puede entrar en ella
--     aunque se haya liberado un puesto. Así un usuario que se desconecta y
--     quiere volver no queda atrapado: se apunta a la cola y después puede
--     engancharse.
--
-- No cambia `engancharse`: si hay cola, sigue siendo obligatorio estar
-- apuntado para ocupar un puesto libre.
--
-- Ejecutar después de 0001–0010. Es idempotente.
-- ============================================================================

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
  v_cola_activa boolean;
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

  select exists (
    select 1
    from public.lista_espera_estacion
    where tipo_estacion_id = p_tipo_estacion_id
      and dia = v_dia
      and tipo_lista_espera_estacion_id = v_en_lista
  )
  into v_cola_activa;

  if v_total = 0 then
    raise exception 'No hay postes en este tipo.';
  end if;

  /*
   * Sin cola previa, solo se puede abrir una cola cuando el tipo está
   * completo. Con una cola ya activa, se permite entrar aunque haya puestos
   * libres: es la cola la que reserva el acceso al puesto.
   */
  if v_ocupadas < v_total and not v_cola_activa then
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
    'dia', v_dia,
    'cola_activa', v_cola_activa
  );
end;
$$;

revoke all on function public.entrar_en_cola(integer) from public, anon;
grant execute on function public.entrar_en_cola(integer) to authenticated;

notify pgrst, 'reload schema';
