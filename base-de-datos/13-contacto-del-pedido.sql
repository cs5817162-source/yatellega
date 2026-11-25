-- =====================================================================
-- Ya te llega · Llamar y escribir por WhatsApp durante el pedido
-- =====================================================================
--
-- El cliente necesita el celular del conductor y el conductor el del
-- cliente, para llamarse o escribirse por WhatsApp. Las tablas clientes y
-- moteros NO se abren: esta funcion devuelve SOLO nombre y celular de la
-- otra persona, y SOLO mientras el pedido esta en curso (de aceptado a
-- en_entrega). Antes de que un conductor lo acepte, o despues de entregado
-- o cancelado, no devuelve nada.
--
-- No toca tablas ni funciones existentes. Se puede correr varias veces.
-- =====================================================================

create or replace function public.contacto_pedido(p_id uuid)
returns table (nombre text, celular text, rol text)
language plpgsql stable security definer set search_path to 'public'
as $function$
declare r record;
begin
  if auth.uid() is null then return; end if;
  select p.*, c.user_id as cli_user, c.nombre as cli_nombre, c.celular as cli_cel,
         m.user_id as mot_user, m.nombre as mot_nombre, m.celular as mot_cel
    into r
    from public.pedidos p
    join public.clientes c on c.id = p.cliente_id
    left join public.moteros m on m.id = p.motero_id
   where p.id = p_id;
  if not found then return; end if;
  if r.estado not in ('aceptado', 'en_camino', 'en_recogida', 'recogido', 'en_entrega') then return; end if;
  if r.cli_user = auth.uid() and r.mot_user is not null then
    return query select r.mot_nombre::text, r.mot_cel::text, 'conductor'::text;
  elsif r.mot_user = auth.uid() then
    return query select r.cli_nombre::text, r.cli_cel::text, 'cliente'::text;
  end if;
end
$function$;

revoke all on function public.contacto_pedido(uuid) from public, anon;
grant execute on function public.contacto_pedido(uuid) to authenticated;
