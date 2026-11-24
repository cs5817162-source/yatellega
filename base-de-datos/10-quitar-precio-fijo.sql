-- =====================================================================
-- Ya te llega · Quitar el precio fijo de $7.500 (corrido el 24-nov-2026)
-- =====================================================================
-- Reconstruido el 24-nov desde la base real: el archivo original solo
-- existia en el entorno del chat.
--
-- EL ERROR QUE ARREGLO
-- La funcion antes_pedido() ponia precio_cop := 7500 en cada pedido nuevo.
-- Como los disparadores BEFORE INSERT corren en ORDEN ALFABETICO, primero
-- corria pedidos_precio (que calcula el precio por distancia) y despues
-- t_antes_pedido, que lo pisaba con 7.500. Por eso el precio por tramos
-- parecia funcionar pero nunca se guardaba.
--
-- REGLA: antes_pedido() nunca debe tocar el precio ni la ganancia.
-- Los pedidos hechos antes de este arreglo conservan $7.500.
-- =====================================================================

create or replace function public.antes_pedido() returns trigger
language plpgsql
as $function$
begin
  new.estado := 'nuevo';
  new.motero_id := null;
  new.pago_confirmado := false;
  return new;
end
$function$;
