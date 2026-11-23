-- =====================================================================
-- Ya te llega · Tarifas por tramos y margen fijo (segun el plan de negocio)
-- =====================================================================
--
-- QUE CAMBIA
-- Antes: precio = base + valor por kilometro, y el conductor se quedaba
-- con el 85 %.
-- Ahora: el precio sale de TRAMOS de distancia, y a Ya te llega le queda
-- un MARGEN FIJO por pedido. El conductor recibe precio menos margen.
--
--   Hasta  3 km  ->  $8.000
--   Hasta  5 km  ->  $9.500
--   Hasta  7 km  ->  $11.500
--   Hasta 10 km  ->  $14.000
--   Mas de 10 km ->  se cotiza aparte, la app no deja pedirlo
--   Margen de Ya te llega: $1.800 por pedido
--
-- DONDE SE CAMBIA DESPUES, SIN PROGRAMAR
-- Table Editor -> tarifas -> editar la fila:
--   margen_cop = el margen fijo
--   tramos     = lista de [hasta_cuantos_km, precio]. Debe ir de menor a mayor.
--   max_km     = hasta donde se acepta un pedido
--
-- Solo AGREGA columnas y reemplaza dos funciones. No toca pedidos ya hechos.
-- Se puede correr varias veces sin dañar nada.
-- =====================================================================

alter table public.tarifas
  add column if not exists margen_cop integer not null default 1800,
  add column if not exists tramos     jsonb   not null
      default '[[3,8000],[5,9500],[7,11500],[10,14000]]'::jsonb;

update public.tarifas
   set max_km       = 10,
       sin_mapa_cop = 8000,
       actualizado_en = now()
 where id = 1;


-- Precio de un recorrido: el primer tramo donde cabe. Si pasa de todos,
-- devuelve nulo (se cotiza aparte).
create or replace function public.ytl_precio(km numeric)
returns integer
language plpgsql
stable
as $$
declare
  t public.tarifas%rowtype;
  r jsonb;
begin
  select * into t from public.tarifas where id = 1;
  for r in select * from jsonb_array_elements(t.tramos) loop
    if km <= (r ->> 0)::numeric then
      return (r ->> 1)::integer;
    end if;
  end loop;
  return null;
end;
$$;


-- El servidor pone el precio y la ganancia del conductor, pisando lo que
-- mande el celular.
create or replace function public.ytl_poner_precio()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  t        public.tarifas%rowtype;
  km_recto numeric;
  km_ruta  numeric;
  valor    integer;
begin
  select * into t from public.tarifas where id = 1;
  if t.id is null then
    raise exception 'Falta la fila de tarifas.';
  end if;

  if new.lat_recogida is null or new.lng_recogida is null
     or new.lat_entrega is null or new.lng_entrega is null then
    -- Pedido de una version vieja de la app, sin puntos en el mapa
    new.distancia_km := null;
    valor := t.sin_mapa_cop;
  else
    km_recto := public.ytl_km(new.lat_recogida, new.lng_recogida,
                              new.lat_entrega,  new.lng_entrega);
    km_ruta  := round(km_recto * t.factor_ruta, 2);

    if km_ruta > t.max_km then
      raise exception 'Ese recorrido es de % km y pasa de % km. Escríbenos para cotizarlo.', km_ruta, t.max_km;
    end if;

    valor := public.ytl_precio(km_ruta);
    if valor is null then
      raise exception 'Ese recorrido es de % km. Escríbenos para cotizarlo.', km_ruta;
    end if;
    new.distancia_km := km_ruta;
  end if;

  new.precio_cop          := valor;
  new.ganancia_motero_cop := valor - t.margen_cop;
  return new;
end;
$$;


-- Comprobacion: 8 recorridos de ejemplo. El ultimo debe salir sin precio.
select km as kilometros,
       public.ytl_precio(km)                                  as precio_cliente,
       public.ytl_precio(km) - (select margen_cop from public.tarifas where id = 1) as gana_conductor
from unnest(array[1, 3, 3.1, 5, 6.5, 7, 10, 10.5]::numeric[]) as km
order by km;
