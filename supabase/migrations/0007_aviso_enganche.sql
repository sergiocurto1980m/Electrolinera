-- ============================================================================
-- Electrolinera · 0007_aviso_enganche.sql
--
-- Avisa a las personas que siguen esperando en la cola de un tipo cuando otro
-- usuario ocupa un puesto de ese tipo.
--
-- El aviso se guarda como una entrada personal de `avisos` por cada persona
-- que sigue en la cola, de modo que aparece en el panel Avisos y en el toast
-- en tiempo real. El texto incluye tipo de estación, nombre, poste y toma.
--
-- Ejecutar después de 0001–0006. Es idempotente.
-- ============================================================================

-- 1) Estación asociada al aviso ------------------------------------------------
-- Permite que el aviso conserve el poste y la toma del momento del evento,
-- aunque después la entrada de cola del destinatario cambie de estación.
alter table public.avisos
  add column if not exists estacion_id integer;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'avisos_estacion_fkey'
      and conrelid = 'public.avisos'::regclass
  ) then
    alter table public.avisos
      add constraint avisos_estacion_fkey
      foreign key (estacion_id) references public.estaciones(id)
      on delete set null;
  end if;
end;
$$;

-- 2) RPC: engancharse ----------------------------------------------------------
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

  select id into v_desenchufado
  from public.tipo_lista_espera_estacion
  where nombre = 'Desenchufado';

  if v_ocupado is null
    or v_en_lista is null
    or v_cargando is null
    or v_desenchufado is null then
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
  set tipo_lista_espera_estacion_id = case
        when tipo_estacion_id = v_tipo_id then v_cargando
        else v_desenchufado
      end,
      estacion_id = case
        when tipo_estacion_id = v_tipo_id then p_estacion_id
        else estacion_id
      end,
      fecha_hora = now()
  where usuario_id = v_uid
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

revoke all on function public.engancharse(integer) from public, anon;
grant execute on function public.engancharse(integer) to authenticated;

-- 3) Vista de avisos con la estación del evento --------------------------------
create or replace view public.v_home_avisos
with (security_invoker = true) as
select
  a.id,
  a.aviso,
  a.fecha_hora,
  coalesce(a.estacion_id, le.estacion_id) as estacion_id,
  te.nombre as tipo_estacion,
  tp.nombre as tipo_poste,
  tt.nombre as tipo_toma
from public.avisos a
join public.lista_espera_estacion le on le.id = a.lista_espera_estacion_id
join public.tipo_estacion te on te.id = le.tipo_estacion_id
left join public.estaciones e
  on e.id = coalesce(a.estacion_id, le.estacion_id)
left join public.tipo_poste tp on tp.id = e.tipo_poste_id
left join public.tipo_toma tt on tt.id = e.tipo_toma_id
where a.usuario_id = auth.uid()
  and (a.fecha_hora at time zone 'Europe/Madrid')::date
      = (now() at time zone 'Europe/Madrid')::date;

revoke select on public.v_home_avisos from anon;
grant select on public.v_home_avisos to authenticated;

-- 4) Recargar el schema cache ---------------------------------------------------
notify pgrst, 'reload schema';
