-- =====================================================================
-- Ya te llega · El precio lo calcula el servidor, no el celular
-- =====================================================================
--
-- QUE RESUELVE
-- Hasta hoy el celular del cliente mandaba el precio escrito en el
-- pedido. Quien supiera abrir las herramientas del navegador podia
-- cambiarlo antes de enviarlo y pagar lo que quisiera. Despues de correr
-- esto, el celular puede mandar lo que sea: la base de datos lo ignora y
-- pone el precio ella misma, con la distancia entre los dos puntos.
--
-- COMO CORRERLO
-- Entre a supabase.com, abra el proyecto, menu izquierdo "SQL Editor",
-- boton "New query", pegue TODO este archivo y toque "Run".
-- Se puede correr varias veces sin dañar nada.
--
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Guardar los puntos que el cliente marca en el mapa
-- ---------------------------------------------------------------------
alter table public.pedidos
  add column if not exists lat_recogida double precision,
  add column if not exists lng_recogida double precision,
  add column if not exists lat_entrega  double precision,
  add column if not exists lng_entrega  double precision,
  add column if not exists distancia_km numeric(6,2);

-- Permitir que la app escriba y lea esas columnas nuevas.
grant insert (lat_recogida, lng_recogida, lat_entrega, lng_entrega)
  on public.pedidos to authenticated;
grant select (lat_recogida, lng_recogida, lat_entrega, lng_entrega, distancia_km)
  on public.pedidos to authenticated;


-- ---------------------------------------------------------------------
-- 2) La tabla de tarifas: una sola fila con los precios
--
--    Aqui es donde usted cambia los precios de ahora en adelante, desde
--    Supabase, sin tocar codigo y sin volver a publicar la app.
--    Table Editor -> tarifas -> editar la fila -> guardar.
-- ---------------------------------------------------------------------
create table if not exists public.tarifas (
  id              smallint primary key default 1,
  base_cop        integer      not null default 4500,  -- vale cualquier mandado
  por_km_cop      integer      not null default 800,   -- se suma por kilometro
  minima_cop      integer      not null default 5000,  -- nunca se cobra menos
  sin_mapa_cop    integer      not null default 7500,  -- si el pedido llega sin puntos
  factor_ruta     numeric(3,2) not null default 1.30,  -- las motos no van derecho
  parte_conductor numeric(3,2) not null default 0.85,  -- 85 % para el conductor
  max_km          integer      not null default 60,    -- mas lejos que esto, se rechaza
  actualizado_en  timestamptz  not null default now(),
  constraint tarifas_una_sola_fila check (id = 1)
);

insert into public.tarifas (id) values (1) on conflict (id) do nothing;

-- La app puede LEER las tarifas, para mostrarle el precio al cliente
-- antes de que pida. No puede cambiarlas.
alter table public.tarifas enable row level security;
drop policy if exists tarifas_lectura on public.tarifas;
create policy tarifas_lectura on public.tarifas
  for select to authenticated using (true);
grant select on public.tarifas to authenticated;


-- ---------------------------------------------------------------------
-- 3) Distancia en kilometros entre dos puntos del mapa
--    (formula del haversine: la distancia sobre la curva de la Tierra)
-- ---------------------------------------------------------------------
create or replace function public.ytl_km(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
) returns numeric
language sql
immutable
as $$
  select round(
    (6371 * 2 * asin(sqrt(
      power(sin(radians(lat2 - lat1) / 2), 2) +
      cos(radians(lat1)) * cos(radians(lat2)) *
      power(sin(radians(lng2 - lng1) / 2), 2)
    )))::numeric, 3);
$$;


-- ---------------------------------------------------------------------
-- 4) El precio, puesto por el servidor en cada pedido nuevo
-- ---------------------------------------------------------------------
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
    raise exception 'Falta la fila de tarifas. Corra de nuevo el archivo 01-precio-por-distancia.sql';
  end if;

  if new.lat_recogida is null or new.lng_recogida is null
     or new.lat_entrega  is null or new.lng_entrega  is null then

    -- Pedido sin puntos en el mapa: pasa con versiones viejas de la app
    -- que el celular todavia tenga guardadas. Se cobra el precio de antes.
    new.distancia_km := null;
    valor := t.sin_mapa_cop;

  else
    km_recto := public.ytl_km(new.lat_recogida, new.lng_recogida,
                              new.lat_entrega,  new.lng_entrega);
    km_ruta  := round(km_recto * t.factor_ruta, 2);

    if km_ruta > t.max_km then
      raise exception 'Ese recorrido es de % km y queda fuera de la zona de Ya te llega.', km_ruta;
    end if;

    new.distancia_km := km_ruta;
    valor := greatest(
      t.minima_cop::numeric,
      round((t.base_cop + t.por_km_cop * km_ruta) / 100.0) * 100
    )::integer;
  end if;

  -- Se pisa lo que haya mandado el celular. Esta es la proteccion.
  new.precio_cop          := valor;
  new.ganancia_motero_cop := round(valor * t.parte_conductor);

  return new;
end;
$$;

drop trigger if exists pedidos_precio on public.pedidos;
create trigger pedidos_precio
  before insert on public.pedidos
  for each row execute function public.ytl_poner_precio();


-- ---------------------------------------------------------------------
-- 5) Comprobacion: debe mostrar la tarifa y unos kilometros de ejemplo
-- ---------------------------------------------------------------------
select
  t.base_cop, t.por_km_cop, t.minima_cop, t.parte_conductor,
  public.ytl_km(3.4516, -76.5320, 3.4200, -76.5000) as km_de_prueba
from public.tarifas t
where t.id = 1;
