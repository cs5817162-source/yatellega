-- =====================================================================
-- Ya te llega · Referencia del punto
-- =====================================================================
--
-- QUE RESUELVE
-- En Cali las direcciones no alcanzan. "Carrera 41D2 # 55B-63" no sale
-- en ningun mapa, y el GPS del celular a veces falla por cuadras. Lo que
-- de verdad hace que el domiciliario encuentre es la referencia:
-- "casa de porton verde, al lado de la tienda, segundo piso".
--
-- Dos campos de texto, uno para donde recoge y otro para donde entrega.
-- Solo AGREGA. No toca nada de lo que ya funciona.
--
-- COMO CORRERLO
-- supabase.com -> su proyecto -> SQL Editor -> New query -> pegar -> Run.
-- Se puede correr varias veces sin dañar nada.
-- =====================================================================

alter table public.pedidos
  add column if not exists referencia_recogida text,
  add column if not exists referencia_entrega  text;

grant insert (referencia_recogida, referencia_entrega) on public.pedidos to authenticated;
grant select (referencia_recogida, referencia_entrega) on public.pedidos to authenticated;

-- Comprobacion: devuelve una fila solo si quedaron las dos
select 'listo' as resultado
where (select count(*) from information_schema.columns
       where table_schema = 'public' and table_name = 'pedidos'
         and column_name in ('referencia_recogida', 'referencia_entrega')) = 2;
