-- =====================================================================
-- Ya te llega · Calificaciones (como en la app del video)
-- =====================================================================
--
-- Al entregar, el cliente califica con 1 a 5 estrellas el PEDIDO (el
-- servicio) y al CONDUCTOR, con un comentario opcional. Una sola vez por
-- pedido, y solo su propio pedido entregado. Nadie escribe directo en la
-- tabla: solo la funcion calificar_pedido.
--
-- Quien ve que:
--   administrador: todas
--   cliente: las suyas
--   conductor: solo su promedio y cuantas tiene (mi_calificacion); no ve
--              quien lo califico.
--
-- No toca tablas existentes. Se puede correr varias veces.
-- =====================================================================

create table if not exists public.calificaciones (
  pedido_id           uuid        primary key references public.pedidos(id),
  cliente_id          uuid        not null references public.clientes(id),
  motero_id           uuid        not null references public.moteros(id),
  estrellas_pedido    smallint    not null check (estrellas_pedido between 1 and 5),
  estrellas_conductor smallint    not null check (estrellas_conductor between 1 and 5),
  comentario          text        check (comentario is null or length(comentario) <= 300),
  creado_en           timestamptz not null default now()
);
create index if not exists calificaciones_motero on public.calificaciones (motero_id, creado_en);

alter table public.calificaciones enable row level security;
revoke all on public.calificaciones from anon, authenticated;
grant select on public.calificaciones to authenticated;
drop policy if exists calif_lee on public.calificaciones;
create policy calif_lee on public.calificaciones for select to authenticated
  using (es_admin() or cliente_id in (select c.id from public.clientes c where c.user_id = auth.uid()));

create or replace function public.calificar_pedido(p_id uuid, p_pedido integer, p_conductor integer, p_comentario text)
returns text
language plpgsql security definer set search_path to 'public'
as $function$
declare r record;
begin
  if p_pedido is null or p_pedido not between 1 and 5 or p_conductor is null or p_conductor not between 1 and 5 then
    return 'estrellas';
  end if;
  select p.id, p.cliente_id, p.motero_id, p.estado into r
    from public.pedidos p join public.clientes c on c.id = p.cliente_id
   where p.id = p_id and c.user_id = auth.uid();
  if not found then return 'permiso'; end if;
  if r.estado <> 'entregado' or r.motero_id is null then return 'estado'; end if;
  insert into public.calificaciones (pedido_id, cliente_id, motero_id, estrellas_pedido, estrellas_conductor, comentario)
  values (r.id, r.cliente_id, r.motero_id, p_pedido, p_conductor, nullif(left(trim(coalesce(p_comentario, '')), 300), ''))
  on conflict (pedido_id) do nothing;
  if not found then return 'ya'; end if;
  return 'ok';
end
$function$;

-- Promedio del conductor (para su app). No revela quien califico.
create or replace function public.mi_calificacion()
returns table (promedio numeric, total integer)
language plpgsql stable security definer set search_path to 'public'
as $function$
declare m uuid;
begin
  select id into m from public.moteros where user_id = auth.uid();
  if m is null then return; end if;
  return query select round(avg(estrellas_conductor)::numeric, 1), count(*)::integer
                 from public.calificaciones where motero_id = m;
end
$function$;

revoke all on function public.calificar_pedido(uuid, integer, integer, text) from public, anon;
revoke all on function public.mi_calificacion() from public, anon;
grant execute on function public.calificar_pedido(uuid, integer, integer, text) to authenticated;
grant execute on function public.mi_calificacion() to authenticated;

select count(*) as calificaciones from public.calificaciones;
