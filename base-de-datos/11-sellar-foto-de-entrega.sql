-- =====================================================================
-- Ya te llega · Sellar la foto de entrega (corrido el 24-nov-2026)
-- =====================================================================
--
-- EL PROBLEMA
-- La politica entrega_cliente_lee (script 06) deja a un cliente abrir el
-- archivo del deposito "documentos" cuya ruta coincida con foto_entrega de
-- UN PEDIDO SUYO. Pero al crear un pedido, el cliente podia escribir lo que
-- quisiera en foto_entrega: si conocia la ruta de un documento ajeno, podia
-- crear un pedido apuntando ahi y abrirlo. La ruta lleva el identificador
-- del dueño y una marca de tiempo, asi que no se adivina; aun asi, habia
-- que cerrarlo.
--
-- EL ARREGLO
-- Al crear un pedido se vacian foto_entrega y la posicion del conductor.
-- Esos datos solo los escriben las funciones del conductor
-- (guardar_foto_entrega y reportar_posicion), y guardar_foto_entrega solo
-- acepta rutas de la carpeta del propio conductor. El cliente no tiene
-- permiso de UPDATE sobre pedidos, asi que no hay otra forma de llenarlos.
--
-- LO QUE NO FUNCIONO (para no repetirlo)
-- Se probo tambien endurecer la politica exigiendo que el archivo fuera de
-- la carpeta del conductor del pedido, uniendo con la tabla moteros. Eso
-- ROMPIO el uso normal: la politica consulta moteros con los permisos del
-- cliente, y un cliente no puede leer esa tabla, asi que dejo de ver la foto
-- de su propia entrega. La politica quedo como en el script 06.
--
-- antes_pedido() sigue SIN tocar el precio ni la ganancia.
-- Se puede correr varias veces sin dañar nada.
--
-- COMPROBADO el 24-nov con un pedido de prueba dentro de una transaccion que
-- se deshizo, actuando como cliente:
--   foto inyectada que quedo guardada ......... NULL
--   archivo ajeno visible para el cliente ..... 0
--   foto de su propia entrega visible ......... 1
--   precio guardado (recorrido corto) ......... 8000
-- =====================================================================

create or replace function public.antes_pedido() returns trigger
language plpgsql
as $function$
begin
  new.estado := 'nuevo';
  new.motero_id := null;
  new.pago_confirmado := false;
  -- estos datos solo los escriben las funciones del conductor
  new.foto_entrega := null;
  new.lat_conductor := null;
  new.lng_conductor := null;
  new.pos_en := null;
  return new;
end
$function$;
