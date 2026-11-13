-- ============================================================================
-- Electrolinera · 0005_admin_config.sql
--
-- Añade el rol de administrador para la configuración de Auth.
-- Solo smcurto@mitma.es queda como administrador.
--
-- Ejecutar después de 0001–0004.
-- Es idempotente.
-- ============================================================================

alter table public.usuarios
  add column if not exists es_admin boolean not null default false;

grant select (es_admin) on public.usuarios to authenticated;

update public.usuarios
set es_admin = true
where lower(email) = lower('smcurto@mitma.es');

notify pgrst, 'reload schema';
