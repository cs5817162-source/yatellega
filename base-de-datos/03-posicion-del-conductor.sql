-- =====================================================================
-- Ya te llega · El cliente ve la moto moverse en el mapa
-- =====================================================================
--
-- QUE RESUELVE
-- Hoy el cliente solo ve un texto: "La moto va a recoger". No sabe si
-- esta a dos cuadras o a dos kilometros, y termina llamando. Con esto
-- ve la moto en el mapa mientras va.
--
-- COMO FUNCIONA
-- La posicion se guarda EN EL PEDIDO, no en el conductor. Asi:
--   - El cliente la ve, porque ya puede leer sus propios pedidos.
--   - Nadie mas la ve, porque nadie mas lee ese pedido.
--   - Cuando el pedido se entrega, deja de actualizarse. El cliente no
--     puede seguir al conductor despues de la entrega.
--
-- Solo AGREGA. No toca nada de lo que ya funciona.
--
-- COMO CORRERLO
-- supabase.com -> su proyecto -> SQL Editor -> New query -> pegar -> Run.
-- Se puede correr varias veces sin dañar nada.
-- =====================================================================


-- 1) Donde va la moto, y de cuando es ese dato
alter table public.pedidos
  add column if not exists lat_conductor double precision,
  add column if not exists lng_conductor double precision,
  add column if not exists pos_en        timestamptz;

grant select (lat_conductor, lng_conductor, pos_en)
  on public.pedidos to authenticated;


-- 2) El conductor reporta donde va.
--    La funcion comprueba sola que quien llama sea el conductor asignado
--    a ESE pedido, y que el pedido siga en curso. Si no, no hace nada.
--    p_id va como texto para que sirva sea cual sea el tipo del id.
create or replace function public.reportar_posicion(
  p_id  text,
  p_lat double precision,
  p_lng double precision
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  update public.pedidos p
     set lat_conductor = p_lat,
         lng_conductor = p_lng,
         pos_en        = now()
   where p.id::text = p_id
     and p.estado in ('aceptado', 'en_camino', 'en_recogida', 'recogido', 'en_entrega')
     and p.motero_id = (select m.id from public.moteros m where m.user_id = auth.uid());

  get diagnostics n = row_count;
  return n > 0;
end;
$$;

grant execute on function public.reportar_posicion(text, double precision, double precision)
  to authenticated;


-- 3) Comprobacion: devuelve una fila solo si quedo todo bien
select 'listo' as resultado
where (
  select count(*) from information_schema.columns
  where table_schema = 'public' and table_name = 'pedidos'
    and column_name in ('lat_conductor', 'lng_conductor', 'pos_en')
) = 3
and exists (select 1 from pg_proc where proname = 'reportar_posicion');
