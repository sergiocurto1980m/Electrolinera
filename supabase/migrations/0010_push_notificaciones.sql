-- ============================================================================
-- Electrolinera · 0010_push_notificaciones.sql
--
-- Notificaciones push con Firebase Cloud Messaging (FCM):
--
--   · Tabla `dispositivos_push` con los tokens de cada usuario y plataforma.
--   · RPC para registrar y borrar el token del dispositivo actual.
--   · Trigger `on_aviso_push` que, al insertar un aviso personal, llama de
--     forma asíncrona (pg_net) a la Edge Function `send-push`.
--   · Realtime sigue siendo la fuente de datos en vivo: el push solo cubre
--     el caso de app en segundo plano o cerrada.
--
-- Antes de ejecutarla hay que configurar los secretos en Vault:
--
--   select vault.create_secret(
--     'https://<project-ref>.supabase.co/functions/v1/send-push',
--     'push_function_url'
--   );
--   select vault.create_secret('<secreto-aleatorio>', 'push_webhook_secret');
--
-- Ejecutar después de 0001–0009. Es idempotente.
-- ============================================================================

-- 1) Tokens de dispositivo -----------------------------------------------------
create table if not exists public.dispositivos_push (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  token text not null,
  plataforma text not null,
  user_agent text,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'dispositivos_push_token_key'
      and conrelid = 'public.dispositivos_push'::regclass
  ) then
    alter table public.dispositivos_push
      add constraint dispositivos_push_token_key unique (token);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'dispositivos_push_plataforma_check'
      and conrelid = 'public.dispositivos_push'::regclass
  ) then
    alter table public.dispositivos_push
      add constraint dispositivos_push_plataforma_check
      check (plataforma in ('web', 'android'));
  end if;
end;
$$;

create index if not exists idx_dispositivos_push_usuario
  on public.dispositivos_push (usuario_id)
  where activo;

-- 2) RLS: cada usuario solo ve sus tokens --------------------------------------
alter table public.dispositivos_push enable row level security;

revoke all on public.dispositivos_push from anon, authenticated;

grant select (id, usuario_id, token, plataforma, activo, created_at, last_seen_at)
  on public.dispositivos_push to authenticated;

drop policy if exists "dispositivos_push_select_propio" on public.dispositivos_push;
create policy "dispositivos_push_select_propio"
  on public.dispositivos_push
  for select
  to authenticated
  using (usuario_id = auth.uid());

-- 3) RPC: registrar el token del dispositivo -----------------------------------
create or replace function public.registrar_dispositivo_push(
  p_token text,
  p_plataforma text,
  p_user_agent text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_token text := trim(coalesce(p_token, ''));
  v_plataforma text := lower(trim(coalesce(p_plataforma, '')));
  v_id uuid;
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

  if length(v_token) < 20 or length(v_token) > 4096 then
    raise exception 'El token de notificaciones no es válido.';
  end if;

  if v_plataforma not in ('web', 'android') then
    raise exception 'La plataforma debe ser web o android.';
  end if;

  /*
   * El mismo navegador o móvil puede cambiar de usuario: el token se reasigna
   * al usuario que lo registra y se reactiva. La clave única es el token.
   */
  insert into public.dispositivos_push (
    usuario_id,
    token,
    plataforma,
    user_agent,
    activo,
    last_seen_at
  ) values (
    v_uid,
    v_token,
    v_plataforma,
    nullif(trim(coalesce(p_user_agent, '')), ''),
    true,
    now()
  )
  on conflict (token) do update
    set usuario_id = excluded.usuario_id,
        plataforma = excluded.plataforma,
        user_agent = excluded.user_agent,
        activo = true,
        last_seen_at = now()
  returning id into v_id;

  return jsonb_build_object(
    'ok', true,
    'id', v_id,
    'plataforma', v_plataforma
  );
end;
$$;

revoke all on function public.registrar_dispositivo_push(text, text, text)
  from public, anon;
grant execute on function public.registrar_dispositivo_push(text, text, text)
  to authenticated;

-- 4) RPC: borrar el token del dispositivo al cerrar sesión ---------------------
create or replace function public.eliminar_dispositivo_push(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_token text := trim(coalesce(p_token, ''));
  v_deleted integer;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión.';
  end if;

  delete from public.dispositivos_push
  where token = v_token
    and usuario_id = v_uid;

  get diagnostics v_deleted = row_count;

  return jsonb_build_object('ok', true, 'deleted', v_deleted);
end;
$$;

revoke all on function public.eliminar_dispositivo_push(text)
  from public, anon;
grant execute on function public.eliminar_dispositivo_push(text)
  to authenticated;

-- 5) Envío asíncrono a la Edge Function `send-push` ----------------------------
-- pg_net viene instalado en Supabase. Si el proyecto no lo tuviera, todo el
-- trigger está protegido para no romper las RPC de enganche y cola.
do $$
begin
  create extension if not exists pg_net;
exception
  when others then
    raise notice 'No se pudo crear pg_net: %', sqlerrm;
end;
$$;

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
   * Todo el envío va dentro de un bloque protegido: si Vault no está
   * configurado, falta pg_net o la red falla, el aviso y la RPC que lo creó
   * siguen funcionando con normalidad.
   */
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

drop trigger if exists on_aviso_push on public.avisos;
create trigger on_aviso_push
  after insert on public.avisos
  for each row execute function public.notificar_aviso_push();

-- 6) Recargar el schema cache --------------------------------------------------
notify pgrst, 'reload schema';
