-- =====================================================================
-- Ya te llega · Direcciones aprendidas
-- =====================================================================
--
-- En Cali muchas direcciones no estan en el mapa libre. Cuando un pedido
-- llega con una direccion que el mapa no encontro (calidad 'barrio',
-- 'calle' o 'sin_mapa'), el conductor la encuentra en la calle. Al llegar,
-- su app guarda el punto GPS de ese sitio con la direccion escrita. El
-- siguiente cliente que escriba esa misma direccion la encuentra exacta.
--
-- PRIVACIDAD: la tabla guarda direccion, barrio y punto. NO guarda quien
-- vive ahi ni el cliente. Nadie la puede leer entera: solo se consulta
-- UNA direccion exacta con buscar_direccion_aprendida(texto).
--
-- Se puede correr varias veces sin dañar nada. No toca tablas existentes.
-- =====================================================================

-- 1) Clave de una direccion: "Kra 45 # 56 21" y "Carrera 45 No. 56-21"
--    dan lo mismo: "kr-45-56-21".
create or replace function public.ytl_clave_dir(t text) returns text
language plpgsql immutable
as $function$
declare s text;
begin
  s := ' ' || lower(translate(coalesce(t, ''), 'ÁÉÍÓÚÜÑáéíóúüñ°º', 'AEIOUUNaeiouun  ')) || ' ';
  s := regexp_replace(s, ',.*$', ' ');                                   -- lo que va despues de una coma (ciudad, apto)
  s := regexp_replace(s, '\m(cali|valle del cauca|valle|colombia)\M', ' ', 'g');
  s := regexp_replace(s, '\m(avenida|avda|av)\M\.?', ' av ', 'g');
  s := regexp_replace(s, '\m(carrera|carrea|carera|cra|kra|kr|cr|k)\M\.?', ' kr ', 'g');
  s := regexp_replace(s, '\m(calle|clle|cll|cl)\M\.?', ' cl ', 'g');
  s := regexp_replace(s, '\m(diagonal|diag|dg)\M\.?', ' dg ', 'g');
  s := regexp_replace(s, '\m(transversal|transv|trans|tv|tr)\M\.?', ' tv ', 'g');
  s := regexp_replace(s, '\m(numero|num|nro|no|n)\M\.?', ' # ', 'g');
  s := regexp_replace(s, '([0-9])\s+([a-z])\M', '\1\2', 'g');            -- "12 a" -> "12a"
  s := regexp_replace(s, '([0-9][a-z])\s+([0-9]+)\s*#', '\1\2 #', 'g');  -- "41d 2 #" -> "41d2 #"
  s := regexp_replace(s, '[^a-z0-9]+', '-', 'g');
  return trim(both '-' from s);
end
$function$;

-- 2) La tabla
create table if not exists public.direcciones_aprendidas (
  clave          text primary key,
  direccion      text not null,
  barrio         text,
  lat            double precision not null,
  lng            double precision not null,
  veces          integer not null default 1,
  ultimo_pedido  uuid,
  actualizado_en timestamptz not null default now()
);
alter table public.direcciones_aprendidas enable row level security;
revoke all on table public.direcciones_aprendidas from anon, authenticated;

-- 3) El conductor registra el punto al llegar (recogida) o al entregar
create or replace function public.aprender_direccion(p_id uuid, p_tipo text, p_lat double precision, p_lng double precision)
returns boolean
language plpgsql security definer set search_path to 'public'
as $function$
declare m uuid; r record; d text; b text; k text;
begin
  select id into m from public.moteros where user_id = auth.uid() and estado = 'aprobado';
  if m is null then return false; end if;
  select * into r from public.pedidos where id = p_id and motero_id = m;
  if not found then return false; end if;
  -- Solo puntos dentro de Cali
  if p_lat is null or p_lng is null or p_lat <= 3.28 or p_lat >= 3.56 or p_lng <= -76.62 or p_lng >= -76.44 then
    return false;
  end if;
  if p_tipo = 'recogida'
     and r.estado in ('en_recogida', 'recogido', 'en_entrega', 'entregado')
     and r.calidad_recogida in ('barrio', 'calle', 'sin_mapa') then
    d := r.direccion_recogida; b := r.barrio_recogida;
  elsif p_tipo = 'entrega'
     and r.estado in ('en_entrega', 'entregado')
     and r.calidad_entrega in ('barrio', 'calle', 'sin_mapa') then
    d := r.direccion_entrega; b := r.barrio_entrega;
  else
    return false;
  end if;
  k := public.ytl_clave_dir(d);
  if length(k) < 6 then return false; end if;
  insert into public.direcciones_aprendidas as x (clave, direccion, barrio, lat, lng, ultimo_pedido)
  values (k, d, b, p_lat, p_lng, p_id)
  on conflict (clave) do update
     set lat = excluded.lat, lng = excluded.lng,
         barrio = coalesce(excluded.barrio, x.barrio),
         veces = x.veces + 1, ultimo_pedido = excluded.ultimo_pedido, actualizado_en = now()
   where x.ultimo_pedido is distinct from excluded.ultimo_pedido;
  return true;
end
$function$;

-- 4) El cliente consulta UNA direccion exacta
create or replace function public.buscar_direccion_aprendida(p_texto text)
returns table (lat double precision, lng double precision, direccion text, barrio text, veces integer)
language plpgsql stable security definer set search_path to 'public'
as $function$
declare k text;
begin
  if auth.uid() is null then return; end if;
  k := public.ytl_clave_dir(p_texto);
  if length(k) < 6 then return; end if;
  return query select a.lat, a.lng, a.direccion, a.barrio, a.veces
                 from public.direcciones_aprendidas a where a.clave = k;
end
$function$;

revoke all on function public.aprender_direccion(uuid, text, double precision, double precision) from public, anon;
revoke all on function public.buscar_direccion_aprendida(text) from public, anon;
grant execute on function public.aprender_direccion(uuid, text, double precision, double precision) to authenticated;
grant execute on function public.buscar_direccion_aprendida(text) to authenticated;
grant execute on function public.ytl_clave_dir(text) to authenticated;

-- Comprobacion: las variantes deben dar la misma clave
select public.ytl_clave_dir('Kra 45   # 56 21')        as a,
       public.ytl_clave_dir('Carrera 45 No. 56-21, Cali') as b,
       public.ytl_clave_dir('CL 62  # 11 E 17')         as c,
       public.ytl_clave_dir('Calle 62 # 11E-17')        as d,
       public.ytl_clave_dir('Cra 41 D 2 # 55B-63')      as e,
       public.ytl_clave_dir('Carrera 41D2 N° 55B 63')   as f;
