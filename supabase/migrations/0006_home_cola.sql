-- ============================================================================
-- Electrolinera · 0006_home_cola.sql
--
-- Expone la cola actual por tipo de estación con el nombre de cada usuario.
--
-- La tabla `usuarios` solo permite leer el perfil propio (RLS), así que la
-- Home no puede resolver los nombres con una consulta directa. Se crea una
-- función `security definer` de solo lectura, accesible únicamente con sesión,
-- que devuelve posición, nombre y si la entrada es del usuario actual.
--
-- Ejecutar después de 0001–0005. Es idempotente.
-- ============================================================================

create or replace function public.cola_actual()
returns table (
  tipo_estacion_id integer,
  posicion integer,
  nombre text,
  es_mio boolean,
  fecha_hora timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with hoy as (
    select (now() at time zone 'Europe/Madrid')::date as dia
  ),
  cola as (
    select
      le.tipo_estacion_id,
      le.usuario_id,
      le.fecha_hora,
      row_number() over (
        partition by le.tipo_estacion_id
        order by le.fecha_hora, le.id
      ) as posicion
    from public.lista_espera_estacion le
    join public.tipo_lista_espera_estacion t
      on t.id = le.tipo_lista_espera_estacion_id
    cross join hoy
    where le.dia = hoy.dia
      and t.nombre = 'En Lista'
  )
  select
    c.tipo_estacion_id,
    c.posicion::int,
    coalesce(nullif(trim(u.nombre), ''), 'Usuario') as nombre,
    c.usuario_id = auth.uid() as es_mio,
    c.fecha_hora
  from cola c
  join public.usuarios u on u.id = c.usuario_id
  where not u.borrado
  order by c.tipo_estacion_id, c.posicion;
$$;

revoke all on function public.cola_actual() from public, anon;
grant execute on function public.cola_actual() to authenticated;

notify pgrst, 'reload schema';
