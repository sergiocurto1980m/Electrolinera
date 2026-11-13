-- ============================================================================
-- Electrolinera · 0003_home_public.sql
--
-- La Home pública muestra el catálogo de estaciones. El estado (libre,
-- ocupado, tiempo, cola y avisos) solo está disponible con sesión iniciada.
--
-- Ejecutar después de 0001_home.sql y 0002_users.sql.
-- Es idempotente.
-- ============================================================================

-- 1) Catálogo público: estaciones y tipos -------------------------------------
-- `estaciones`, `tipo_estacion`, `tipo_poste` y `tipo_toma` siguen siendo
-- legibles por anon. El resto de tablas de estado/cola/avisos se cierran.
revoke select on
  public.situacion_estacion,
  public.tipo_estado_estacion,
  public.lista_espera_estacion,
  public.tipo_lista_espera_estacion,
  public.avisos
from anon;

-- 2) RLS: solo authenticated en estado, cola y avisos -------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'situacion_estacion',
    'tipo_estado_estacion',
    'lista_espera_estacion',
    'tipo_lista_espera_estacion',
    'avisos'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "home_lectura" on public.%I', t);
    execute format('drop policy if exists "home_lectura_autenticado" on public.%I', t);
    execute format(
      'create policy "home_lectura_autenticado" on public.%I for select to authenticated using (true)',
      t
    );
  end loop;
end;
$$;

-- 3) Vistas completas: solo para usuarios autenticados ------------------------
revoke select on public.v_home_estaciones, public.v_home_avisos from anon;
grant select on public.v_home_estaciones, public.v_home_avisos to authenticated;

-- 4) Vista pública del catálogo -----------------------------------------------
create or replace view public.v_home_estaciones_publica
with (security_invoker = true) as
select
  e.id,
  te.nombre as tipo_estacion,
  tp.nombre as tipo_poste,
  tt.nombre as tipo_toma
from public.estaciones e
join public.tipo_estacion te on te.id = e.tipo_estacion_id
join public.tipo_poste tp on tp.id = e.tipo_poste_id
join public.tipo_toma tt on tt.id = e.tipo_toma_id;

grant select on public.v_home_estaciones_publica to anon, authenticated;

-- 5) Recargar el schema cache de PostgREST ------------------------------------
notify pgrst, 'reload schema';
