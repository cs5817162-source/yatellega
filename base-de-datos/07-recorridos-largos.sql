-- =====================================================================
-- Ya te llega · Recorridos de mas de 10 km (corrido el 23-nov-2026)
-- =====================================================================
-- Reconstruido el 24-nov desde la base real: el archivo original nunca se
-- guardo. Antes, pasar de 10 km se cotizaba aparte. Ahora un recorrido largo
-- SI se puede pedir: se cobra el ultimo tramo mas km_extra_cop por cada
-- kilometro adicional, hasta max_km.
--
-- Ejemplo con los tramos actuales: 12,3 km = $14.000 + 3 x $1.200 = $17.600
-- =====================================================================

alter table public.tarifas
  add column if not exists km_extra_cop integer not null default 1200;

update public.tarifas set max_km = 40, actualizado_en = now() where id = 1;

create or replace function public.ytl_precio(km numeric) returns integer
language plpgsql stable
as $function$
declare
  t public.tarifas%rowtype;
  r jsonb;
  ult jsonb;
begin
  select * into t from public.tarifas where id = 1;
  for r in select * from jsonb_array_elements(t.tramos) loop
    if km <= (r ->> 0)::numeric then
      return (r ->> 1)::integer;
    end if;
    ult := r;
  end loop;
  if ult is null then return null; end if;
  return (ult ->> 1)::integer + ceil(km - (ult ->> 0)::numeric)::integer * t.km_extra_cop;
end;
$function$;
