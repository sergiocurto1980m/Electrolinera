-- ============================================================================
-- Electrolinera · 0004_gestion_diaria.sql
--
-- Gestión diaria de estaciones:
--   · situación diaria y ocupación activa en situacion_estacion
--   · cola por tipo en lista_espera_estacion
--   · avisos dirigidos a los tres primeros de la cola
--   · RPCs transaccionales para engancharse, desengancharse y gestionar cola
--   · vistas diarias para la Home
--
-- Ejecutar después de 0001_home.sql, 0002_users.sql y 0003_home_public.sql.
-- Es idempotente.
-- ============================================================================

-- 1) Situación diaria y ocupación activa ---------------------------------------
alter table public.situacion_estacion
  add column if not exists dia date,
  add column if not exists activo boolean not null default false;

update public.situacion_estacion
set dia = (fecha_hora at time zone 'Europe/Madrid')::date
where dia is null;

alter table public.situacion_estacion
  alter column dia set default ((now() at time zone 'Europe/Madrid')::date);
alter table public.situacion_estacion
  alter column dia set not null;

create index if not exists idx_situacion_estacion_dia_est
  on public.situacion_estacion (dia, estacion_id, fecha_hora desc);

create unique index if not exists uq_situacion_usuario_activo_dia
  on public.situacion_estacion (usuario_id, dia)
  where activo and usuario_id is not null;

create unique index if not exists uq_situacion_estacion_activo_dia
  on public.situacion_estacion (estacion_id, dia)
  where activo;

-- 2) Cola por tipo --------------------------------------------------------------
alter table public.lista_espera_estacion
  add column if not exists tipo_estacion_id integer,
  add column if not exists dia date;

update public.lista_espera_estacion le
set tipo_estacion_id = e.tipo_estacion_id
from public.estaciones e
where le.estacion_id = e.id
  and le.tipo_estacion_id is null;

update public.lista_espera_estacion
set dia = (fecha_hora at time zone 'Europe/Madrid')::date
where dia is null;

alter table public.lista_espera_estacion
  alter column estacion_id drop not null;

alter table public.lista_espera_estacion
  alter column tipo_estacion_id set not null;

alter table public.lista_espera_estacion
  alter column dia set default ((now() at time zone 'Europe/Madrid')::date);
alter table public.lista_espera_estacion
  alter column dia set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'lista_espera_tipo_estacion_fkey'
      and conrelid = 'public.lista_espera_estacion'::regclass
  ) then
    alter table public.lista_espera_estacion
      add constraint lista_espera_tipo_estacion_fkey
      foreign key (tipo_estacion_id) references public.tipo_estacion(id);
  end if;
end;
$$;

create index if not exists idx_lista_tipo_dia_fecha
  on public.lista_espera_estacion (tipo_estacion_id, dia, fecha_hora);

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
    'create unique index if not exists uq_lista_usuario_en_lista_dia
       on public.lista_espera_estacion (usuario_id, dia)
       where tipo_lista_espera_estacion_id = %s',
    v_en_lista
  );
end;
$$;

-- 3) Avisos dirigidos a cada usuario -------------------------------------------
alter table public.avisos
  add column if not exists usuario_id uuid;

update public.avisos a
set usuario_id = le.usuario_id
from public.lista_espera_estacion le
where a.lista_espera_estacion_id = le.id
  and a.usuario_id is null;

alter table public.avisos
  alter column usuario_id set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'avisos_usuario_fkey'
      and conrelid = 'public.avisos'::regclass
  ) then
    alter table public.avisos
      add constraint avisos_usuario_fkey
      foreign key (usuario_id) references public.usuarios(id) on delete cascade;
  end if;
end;
$$;

create index if not exists idx_avisos_usuario_fecha
  on public.avisos (usuario_id, fecha_hora desc);

alter table public.avisos enable row level security;
drop policy if exists "home_lectura" on public.avisos;
drop policy if exists "home_lectura_autenticado" on public.avisos;
drop policy if exists "avisos_select_propio" on public.avisos;
create policy "avisos_select_propio"
  on public.avisos
  for select
  to authenticated
  using (usuario_id = auth.uid());

-- 4) Solo las RPC pueden escribir ----------------------------------------------
revoke insert, update, delete on
  public.situacion_estacion,
  public.lista_espera_estacion,
  public.avisos
from anon, authenticated;

-- 5) RPC: engancharse -----------------------------------------------------------
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

  select e.tipo_estacion_id
  into v_tipo_id
  from public.estaciones e
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

  return jsonb_build_object(
    'ok', true,
    'estacion_id', p_estacion_id,
    'tipo_estacion_id', v_tipo_id,
    'dia', v_dia
  );
end;
$$;

-- 6) RPC: desengancharse --------------------------------------------------------
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

  select s.id
  into v_situacion_id
  from public.situacion_estacion s
  where s.usuario_id = v_uid
    and s.estacion_id = p_estacion_id
    and s.dia = v_dia
    and s.activo
  for update;

  if v_situacion_id is null then
    raise exception 'No estás enganchado a ese poste.';
  end if;

  update public.situacion_estacion
  set activo = false
  where id = v_situacion_id;

  insert into public.situacion_estacion (
    estacion_id,
    tipo_estado_estacion_id,
    usuario_id,
    dia,
    activo
  ) values (
    p_estacion_id,
    v_libre,
    v_uid,
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

-- 7) RPC: entrar en la cola de un tipo -----------------------------------------
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

  if exists (
    select 1
    from public.situacion_estacion
    where usuario_id = v_uid and dia = v_dia and activo
  ) then
    raise exception 'Estás enganchado a un poste. Desenganchate antes de apuntarte a la cola.';
  end if;

  if exists (
    select 1
    from public.lista_espera_estacion
    where usuario_id = v_uid
      and dia = v_dia
      and tipo_lista_espera_estacion_id = v_en_lista
  ) then
    raise exception 'Ya estás en una cola.';
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

-- 8) RPC: salir de la cola -------------------------------------------------------
create or replace function public.salir_de_cola(p_tipo_estacion_id integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_dia date := (now() at time zone 'Europe/Madrid')::date;
  v_en_lista integer;
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

  select id into v_en_lista
  from public.tipo_lista_espera_estacion
  where nombre = 'En Lista';

  select id into v_desenchufado
  from public.tipo_lista_espera_estacion
  where nombre = 'Desenchufado';

  if v_en_lista is null or v_desenchufado is null then
    raise exception 'Faltan los tipos de cola en la base de datos.';
  end if;

  perform pg_advisory_xact_lock(
    hashtext('tipo:' || p_tipo_estacion_id::text)::bigint
  );
  perform pg_advisory_xact_lock(
    hashtext('usuario:' || v_uid::text || ':' || v_dia::text)::bigint
  );

  update public.lista_espera_estacion
  set tipo_lista_espera_estacion_id = v_desenchufado,
      fecha_hora = now()
  where usuario_id = v_uid
    and tipo_estacion_id = p_tipo_estacion_id
    and dia = v_dia
    and tipo_lista_espera_estacion_id = v_en_lista;

  if not found then
    raise exception 'No estás en la cola de ese tipo.';
  end if;

  return jsonb_build_object(
    'ok', true,
    'tipo_estacion_id', p_tipo_estacion_id,
    'dia', v_dia
  );
end;
$$;

-- 9) Permisos de las RPC ---------------------------------------------------------
revoke all on function public.engancharse(integer) from public, anon;
revoke all on function public.desengancharse(integer) from public, anon;
revoke all on function public.entrar_en_cola(integer) from public, anon;
revoke all on function public.salir_de_cola(integer) from public, anon;

grant execute on function public.engancharse(integer) to authenticated;
grant execute on function public.desengancharse(integer) to authenticated;
grant execute on function public.entrar_en_cola(integer) to authenticated;
grant execute on function public.salir_de_cola(integer) to authenticated;

-- 10) Vistas diarias -------------------------------------------------------------
drop view if exists public.v_home_estaciones;
drop view if exists public.v_home_avisos;
drop view if exists public.v_home_estaciones_publica;

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
  select s.estacion_id, s.usuario_id
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
  coalesce(a.usuario_id = auth.uid(), false) as es_mio,
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
  ) as mi_en_cola
from public.estaciones e
join public.tipo_estacion te on te.id = e.tipo_estacion_id
join public.tipo_poste tp on tp.id = e.tipo_poste_id
join public.tipo_toma tt on tt.id = e.tipo_toma_id
left join ultima_situacion us on us.estacion_id = e.id
left join public.tipo_estado_estacion se on se.id = us.tipo_estado_estacion_id
left join cola_por_tipo cpt on cpt.tipo_estacion_id = te.id
left join activa a on a.estacion_id = e.id;

create view public.v_home_avisos
with (security_invoker = true) as
select
  a.id,
  a.aviso,
  a.fecha_hora,
  le.estacion_id,
  te.nombre as tipo_estacion,
  tp.nombre as tipo_poste,
  tt.nombre as tipo_toma
from public.avisos a
join public.lista_espera_estacion le on le.id = a.lista_espera_estacion_id
join public.tipo_estacion te on te.id = le.tipo_estacion_id
left join public.estaciones e on e.id = le.estacion_id
left join public.tipo_poste tp on tp.id = e.tipo_poste_id
left join public.tipo_toma tt on tt.id = e.tipo_toma_id
where a.usuario_id = auth.uid()
  and (a.fecha_hora at time zone 'Europe/Madrid')::date
      = (now() at time zone 'Europe/Madrid')::date;

create view public.v_home_estaciones_publica
with (security_invoker = true) as
select
  e.id,
  te.id as tipo_estacion_id,
  te.nombre as tipo_estacion,
  tp.nombre as tipo_poste,
  tt.nombre as tipo_toma
from public.estaciones e
join public.tipo_estacion te on te.id = e.tipo_estacion_id
join public.tipo_poste tp on tp.id = e.tipo_poste_id
join public.tipo_toma tt on tt.id = e.tipo_toma_id;

revoke select on public.v_home_estaciones, public.v_home_avisos from anon;
grant select on public.v_home_estaciones, public.v_home_avisos to authenticated;
grant select on public.v_home_estaciones_publica to anon, authenticated;

-- 11) Recargar el schema cache ---------------------------------------------------
notify pgrst, 'reload schema';
