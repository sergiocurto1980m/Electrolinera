-- ============================================================================
-- Electrolinera · 0002_users.sql
--
-- Autenticación y perfiles de usuario sobre Supabase Auth:
--   · FK de public.usuarios.id a auth.users.id
--   · email único (case-insensitive)
--   · trigger que crea el perfil al registrar un usuario
--   · trigger que sincroniza el email cuando Auth lo confirma
--   · RLS: cada usuario solo ve y edita su propio perfil
--
-- Ejecutar en Supabase → SQL Editor después de 0001_home.sql.
-- ============================================================================

-- 1) Limpiar perfiles huérfanos (si existiera alguno) -------------------------
delete from public.usuarios u
where not exists (
  select 1
  from auth.users au
  where au.id = u.id
);

-- 2) FK a auth.users ----------------------------------------------------------
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'usuarios_id_auth_fkey'
      and conrelid = 'public.usuarios'::regclass
  ) then
    alter table public.usuarios
      add constraint usuarios_id_auth_fkey
      foreign key (id) references auth.users(id) on delete cascade;
  end if;
end;
$$;

-- 3) Email único (sin distinguir mayúsculas) ---------------------------------
create unique index if not exists usuarios_email_unique
  on public.usuarios (lower(email));

-- 4) Trigger: crear el perfil al registrar un usuario -------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.usuarios (id, nombre, email, borrado, created_at)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'nombre'), ''),
      split_part(new.email, '@', 1)
    ),
    new.email,
    false,
    new.created_at
  )
  on conflict (id) do update
    set email = excluded.email,
        nombre = coalesce(nullif(public.usuarios.nombre, ''), excluded.nombre);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 5) Trigger: sincronizar el email cuando Auth lo confirma --------------------
create or replace function public.handle_user_email_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email is distinct from old.email then
    update public.usuarios
      set email = new.email
      where id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_email_updated on auth.users;
create trigger on_auth_user_email_updated
  after update of email on auth.users
  for each row execute function public.handle_user_email_update();

-- 6) Perfiles para usuarios de Auth ya existentes -----------------------------
insert into public.usuarios (id, nombre, email, borrado, created_at)
select
  u.id,
  coalesce(
    nullif(trim(u.raw_user_meta_data->>'nombre'), ''),
    split_part(u.email, '@', 1)
  ),
  u.email,
  false,
  u.created_at
from auth.users u
where u.email is not null
on conflict (id) do nothing;

-- 7) RLS y permisos -----------------------------------------------------------
alter table public.usuarios enable row level security;

revoke all on public.usuarios from anon, authenticated;

grant select (id, nombre, email, borrado, created_at)
  on public.usuarios to authenticated;

grant update (nombre, borrado)
  on public.usuarios to authenticated;

drop policy if exists "usuarios_select_propio" on public.usuarios;
create policy "usuarios_select_propio"
  on public.usuarios
  for select
  to authenticated
  using (id = auth.uid());

drop policy if exists "usuarios_update_propio" on public.usuarios;
create policy "usuarios_update_propio"
  on public.usuarios
  for update
  to authenticated
  using (id = auth.uid() and borrado = false)
  with check (id = auth.uid());

-- 8) Recargar el schema cache -------------------------------------------------
notify pgrst, 'reload schema';
