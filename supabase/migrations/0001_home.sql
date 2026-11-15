-- ============================================================================
-- Electrolinera · 0001_home.sql
--
-- Prepara Supabase para la Home:
--   · lectura pública (RLS) para los tipos y tablas que consume la Home
--   · publicación Realtime de las tablas que alimentan los datos en vivo
--   · índices para las consultas de estado actual y cola
--   · vistas agregadas v_home_estaciones y v_home_avisos
--
-- Ejecutar en Supabase → SQL Editor. Es idempotente.
-- NO se toca la tabla `usuarios`: la Home solo muestra agregados y nunca emails.
-- ============================================================================

-- 1) Permisos de lectura ------------------------------------------------------
grant select on
  public.tipo_estado_estacion,
  public.tipo_estacion,
  public.tipo_poste,
  public.tipo_toma,
  public.tipo_lista_espera_estacion,
  public.estaciones,
  public.situacion_estacion,
  public.lista_espera_estacion,
  public.avisos
to anon, authenticated;    

-- 2) Políticas RLS de solo lectura -------------------------------------------
do $$ 
declare
  t text; 
begin
  foreach t in array array[
    'tipo_estado_estacion',
    'tipo_estacion',
    'tipo_poste',
    'tipo_toma',
    'tipo_lista_espera_estacion',
    'estaciones',
    'situacion_estacion',
    'lista_espera_estacion',
    'avisos'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "home_lectura" on public.%I', t);
    execute format(
      'create policy "home_lectura" on public.%I for select to anon, authenticated using (true)',
      t
    );
  end loop;
end;
$$;

-- 3) Publicación Realtime -----------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'estaciones',
    'situacion_estacion',
    'lista_espera_estacion',
    'avisos'
  ]
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception
      when duplicate_object then null;
    end;
  end loop;
end;
$$;

-- 4) Índices ------------------------------------------------------------------
create index if not exists idx_situacion_estacion_est_fecha
  on public.situacion_estacion (estacion_id, fecha_hora desc);

create index if not exists idx_lista_espera_usuario_fecha
  on public.lista_espera_estacion (usuario_id, fecha_hora desc);

create index if not exists idx_lista_espera_estacion_est
  on public.lista_espera_estacion (estacion_id);

create index if not exists idx_avisos_fecha
  on public.avisos (fecha_hora desc);

-- 5) Vista agregada por estación ---------------------------------------------
create or replace view public.v_home_estaciones
with (security_invoker = true) as
with ultima_situacion as (
  select distinct on (s.estacion_id)
    s.estacion_id,
    s.tipo_estado_estacion_id,
    s.fecha_hora
  from public.situacion_estacion s
  order by s.estacion_id, s.fecha_hora desc, s.id desc
),
cola_actual as (
  select distinct on (le.usuario_id)
    le.usuario_id,
    le.estacion_id,
    le.tipo_lista_espera_estacion_id
  from public.lista_espera_estacion le
  order by le.usuario_id, le.fecha_hora desc, le.id desc
),
cola_por_estacion as (
  select
    c.estacion_id,
    count(*) filter (where t.nombre = 'En Lista')::int as en_cola,
    count(*) filter (where t.nombre = 'Cargando')::int as cargando
  from cola_actual c
  join public.tipo_lista_espera_estacion t
    on t.id = c.tipo_lista_espera_estacion_id
  group by c.estacion_id
)
select
  e.id,
  te.nombre as tipo_estacion,
  tp.nombre as tipo_poste,
  tt.nombre as tipo_toma,
  se.nombre as estado,
  us.fecha_hora as estado_desde,
  coalesce(cpe.en_cola, 0) as en_cola,
  coalesce(cpe.cargando, 0) as cargando
from public.estaciones e
join public.tipo_estacion te on te.id = e.tipo_estacion_id
join public.tipo_poste tp on tp.id = e.tipo_poste_id
join public.tipo_toma tt on tt.id = e.tipo_toma_id
left join ultima_situacion us on us.estacion_id = e.id
left join public.tipo_estado_estacion se on se.id = us.tipo_estado_estacion_id
left join cola_por_estacion cpe on cpe.estacion_id = e.id;

-- 6) Vista de avisos ----------------------------------------------------------
create or replace view public.v_home_avisos
with (security_invoker = true) as
select
  a.id,
  a.aviso,
  a.fecha_hora,
  e.id as estacion_id,
  te.nombre as tipo_estacion,
  tp.nombre as tipo_poste,
  tt.nombre as tipo_toma
from public.avisos a
join public.lista_espera_estacion le on le.id = a.lista_espera_estacion_id
join public.estaciones e on e.id = le.estacion_id
join public.tipo_estacion te on te.id = e.tipo_estacion_id
join public.tipo_poste tp on tp.id = e.tipo_poste_id
join public.tipo_toma tt on tt.id = e.tipo_toma_id;

-- 7) Permisos sobre las vistas ------------------------------------------------
grant select on public.v_home_estaciones, public.v_home_avisos
to anon, authenticated;

-- 8) Recargar el schema cache de PostgREST -----------------------------------
notify pgrst, 'reload schema';
