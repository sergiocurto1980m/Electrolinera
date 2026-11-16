-- ============================================================================
-- Electrolinera · 0012_push_solo_puesto_libre.sql
--
-- Restringe las notificaciones push a un único caso:
--   · Cuando se libera una toma y el usuario está entre los tres primeros de
--     la lista de espera de ese tipo.
--
-- El resto de avisos (puesto ocupado, toma ocupada por una persona sin app)
-- siguen apareciendo en el panel Avisos y en el toast de Realtime, pero ya no
-- generan notificación push.
--
-- Ejecutar después de 0001–0011. Es idempotente.
-- ============================================================================

-- 1) Marca de aviso que debe generar push -------------------------------------
alter table public.avisos
  add column if not exists enviar_push boolean not null default false;

-- 2) RPC desengancharse --------------------------------------------------------
-- Copia de 0009. Solo cambia el INSERT de avisos de "puesto libre": esos son
-- los únicos que se marcan con enviar_push = true.
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
   * Avisamos a los tres primeros de la cola del tipo cada vez que se libera
   * una toma, aunque ya hayan recibido un aviso antes ese mismo día: si siguen
   * esperando, deben saber que hay otra oportunidad.
   *
   * Estos avisos son los únicos que generan push: enviar_push = true.
   */
  insert into public.avisos (
    aviso,
    lista_espera_estacion_id,
    usuario_id,
    fecha_hora,
    enviar_push
  )
  select
    'Hay un puesto libre en ' || v_tipo_nombre || '. Puedes engancharte.',
    q.id,
    q.usuario_id,
    now(),
    true
  from (
    select le.id, le.usuario_id
    from public.lista_espera_estacion le
    where le.dia = v_dia
      and le.tipo_estacion_id = v_tipo_id
      and le.tipo_lista_espera_estacion_id = v_en_lista
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

revoke all on function public.desengancharse(integer) from public, anon;
grant execute on function public.desengancharse(integer) to authenticated;

-- 3) Trigger: solo llama a send-push para avisos marcados ---------------------
create or replace function public.notificar_aviso_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_secret text;
begin
  /*
   * El resto de avisos (puesto ocupado, toma ocupada por persona sin app)
   * se quedan en la app y en Realtime, sin push.
   */
  if not new.enviar_push then
    return new;
  end if;

  begin
    select decrypted_secret
    into v_url
    from vault.decrypted_secrets
    where name = 'push_function_url'
    order by created_at desc
    limit 1;

    select decrypted_secret
    into v_secret
    from vault.decrypted_secrets
    where name = 'push_webhook_secret'
    order by created_at desc
    limit 1;

    if v_url is null or v_secret is null then
      return new;
    end if;

    perform net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-push-secret', v_secret
      ),
      body := jsonb_build_object(
        'aviso_id', new.id,
        'usuario_id', new.usuario_id,
        'mensaje', new.aviso
      ),
      timeout_milliseconds := 5000
    );
  exception
    when others then
      null;
  end;

  return new;
end;
$$;

-- 4) Recargar el schema cache --------------------------------------------------
notify pgrst, 'reload schema';
