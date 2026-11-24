-- =====================================================================
-- Ya te llega · Esquema completo de la base de datos (foto del 24-nov-2026)
-- =====================================================================
--
-- QUE ES
-- El estado REAL de la base de datos de Supabase, leido de la base viva el
-- 24 de noviembre de 2026 (solo lectura). Sirve para reconstruirla si el
-- proyecto se pierde o hay que montar uno nuevo. Los archivos 01 a 06 y 07
-- a 10 son la historia de como se llego aqui; este es el resultado.
--
-- OJO
-- Se reconstruyo a partir de lo que la base reporta. NO se ha corrido
-- todavia en un proyecto vacio para comprobarlo. Antes de confiar en el,
-- probarlo en un proyecto de Supabase nuevo y gratis.
--
-- Va en este orden: tablas, seguridad por filas, funciones, disparadores,
-- politicas, permisos, deposito de archivos y la fila de tarifas.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) TABLAS
-- ---------------------------------------------------------------------

create table if not exists public.administradores (
  user_id uuid not null,
  constraint administradores_pkey primary key (user_id),
  constraint administradores_user_id_fkey foreign key (user_id)
    references auth.users(id) on delete cascade
);

create table if not exists public.clientes (
  id              uuid        not null default gen_random_uuid(),
  user_id         uuid        not null,
  nombre          text        not null,
  celular         text        not null,
  correo          text        not null,
  direccion       text        not null,
  barrio          text        not null,
  ciudad          text        not null default 'Cali',
  acepto_terminos boolean     not null default false,
  creado_en       timestamptz not null default now(),
  constraint clientes_pkey primary key (id),
  constraint clientes_user_id_key unique (user_id),
  constraint clientes_user_id_fkey foreign key (user_id)
    references auth.users(id) on delete cascade,
  constraint clientes_celular_check check (celular ~ '^3[0-9]{9}$')
);

-- "moteros" son los conductores. En pantalla se dice conductor; la tabla
-- conserva el nombre viejo para no romper nada.
create table if not exists public.moteros (
  id                     uuid        not null default gen_random_uuid(),
  user_id                uuid        not null,
  nombre                 text        not null,
  cedula                 text        not null,
  celular                text        not null,
  correo                 text        not null,
  direccion              text        not null,
  barrio                 text        not null,
  ciudad                 text        not null default 'Cali',
  placa                  text        not null,
  marca                  text,
  anio                   integer     not null,
  licencia_vence         date,
  soat_vence             date,
  tecnomecanica_vence    date,
  foto_licencia          text,
  foto_tarjeta_propiedad text,
  foto_soat              text,
  foto_tecnomecanica     text,
  estado                 text        not null default 'pendiente',
  conectado              boolean     not null default false,
  creado_en              timestamptz not null default now(),
  modelo                 text,
  color                  text,
  nequi                  text,
  foto_selfie            text,
  foto_moto_placa        text,
  foto_moto_lado         text,
  foto_pasado_judicial   text,
  constraint moteros_pkey primary key (id),
  constraint moteros_user_id_key unique (user_id),
  constraint moteros_user_id_fkey foreign key (user_id)
    references auth.users(id) on delete cascade,
  constraint moteros_anio_check   check (anio >= 1990 and anio <= 2100),
  constraint moteros_cedula_check check (cedula ~ '^[0-9]{6,10}$'),
  constraint moteros_celular_check check (celular ~ '^3[0-9]{9}$'),
  constraint moteros_estado_check check (estado = any (array['pendiente','aprobado','rechazado','suspendido'])),
  constraint moteros_placa_check  check (placa ~ '^[A-Z]{3}[0-9]{2}[A-Z]$')
);

create table if not exists public.pedidos (
  id                    uuid             not null default gen_random_uuid(),
  cliente_id            uuid             not null,
  motero_id             uuid,
  servicio              text             not null,
  direccion_recogida    text             not null,
  barrio_recogida       text,
  direccion_entrega     text             not null,
  barrio_entrega        text,
  detalle               text,
  forma_pago            text             not null,
  precio_cop            integer          not null,
  ganancia_motero_cop   integer          not null,
  pago_confirmado       boolean          not null default false,
  estado                text             not null default 'nuevo',
  creado_en             timestamptz      not null default now(),
  actualizado_en        timestamptz      not null default now(),
  -- puntos del mapa
  lat_recogida          double precision,
  lng_recogida          double precision,
  lat_entrega           double precision,
  lng_entrega           double precision,
  distancia_km          numeric,
  -- seguimiento de la moto
  lat_conductor         double precision,
  lng_conductor         double precision,
  pos_en                timestamptz,
  -- referencias y foto de entrega
  referencia_recogida   text,
  referencia_entrega    text,
  foto_entrega          text,
  -- direcciones por punto (script 09)
  complemento_recogida  text,
  complemento_entrega   text,
  direccion_mapa_recogida text,
  direccion_mapa_entrega  text,
  fuente_recogida       text,
  fuente_entrega        text,
  precision_recogida    integer,
  precision_entrega     integer,
  calidad_recogida      text,
  calidad_entrega       text,
  confirmada_recogida   boolean          not null default false,
  confirmada_entrega    boolean          not null default false,
  constraint pedidos_pkey primary key (id),
  constraint pedidos_cliente_id_fkey foreign key (cliente_id) references public.clientes(id),
  constraint pedidos_motero_id_fkey  foreign key (motero_id)  references public.moteros(id),
  constraint pedidos_estado_check check (estado = any (array['nuevo','aceptado','en_camino','en_recogida','recogido','en_entrega','entregado','cancelado'])),
  constraint pedidos_forma_pago_check check (forma_pago = any (array['efectivo','nequi'])),
  constraint pedidos_servicio_check check (servicio = any (array['paquete','medicamentos','comida','productos'])),
  constraint pedidos_ganancia_motero_cop_check check (ganancia_motero_cop >= 0),
  constraint pedidos_precio_cop_check check (precio_cop >= 0)
);

create table if not exists public.codigos_entrega (
  pedido_id uuid not null,
  codigo    text not null,
  constraint codigos_entrega_pkey primary key (pedido_id),
  constraint codigos_entrega_pedido_id_fkey foreign key (pedido_id)
    references public.pedidos(id) on delete cascade
);

create table if not exists public.incidencias (
  id          uuid        not null default gen_random_uuid(),
  pedido_id   uuid,
  tipo        text        not null,
  descripcion text        not null,
  resuelta    boolean     not null default false,
  creado_en   timestamptz not null default now(),
  referencia  text,
  constraint incidencias_pkey primary key (id),
  constraint incidencias_pedido_id_fkey foreign key (pedido_id) references public.pedidos(id)
);

-- Una sola fila. Aqui se cambian los precios, sin tocar codigo.
-- base_cop, por_km_cop, minima_cop y parte_conductor ya no calculan nada
-- (quedaron de la formula vieja); el precio sale de "tramos".
create table if not exists public.tarifas (
  id              smallint     not null default 1,
  base_cop        integer      not null default 4500,
  por_km_cop      integer      not null default 800,
  minima_cop      integer      not null default 5000,
  sin_mapa_cop    integer      not null default 7500,
  factor_ruta     numeric      not null default 1.30,
  parte_conductor numeric      not null default 0.85,
  max_km          integer      not null default 60,
  actualizado_en  timestamptz  not null default now(),
  margen_cop      integer      not null default 1800,
  tramos          jsonb        not null default '[[3, 8000], [5, 9500], [7, 11500], [10, 14000]]'::jsonb,
  km_extra_cop    integer      not null default 1200,
  constraint tarifas_pkey primary key (id),
  constraint tarifas_una_sola_fila check (id = 1)
);


-- ---------------------------------------------------------------------
-- 2) SEGURIDAD POR FILAS: activada en las siete tablas
-- ---------------------------------------------------------------------
alter table public.administradores enable row level security;
alter table public.clientes        enable row level security;
alter table public.moteros         enable row level security;
alter table public.pedidos         enable row level security;
alter table public.codigos_entrega enable row level security;
alter table public.incidencias     enable row level security;
alter table public.tarifas         enable row level security;


-- ---------------------------------------------------------------------
-- 3) FUNCIONES
-- ---------------------------------------------------------------------

create or replace function public.es_admin() returns boolean
language sql stable security definer set search_path to 'public'
as $function$
  select exists (select 1 from public.administradores where user_id = auth.uid())
$function$;

-- Distancia en linea recta entre dos puntos (haversine)
create or replace function public.ytl_km(lat1 double precision, lng1 double precision, lat2 double precision, lng2 double precision)
returns numeric language sql immutable
as $function$
  select round(
    (6371 * 2 * asin(sqrt(
      power(sin(radians(lat2 - lat1) / 2), 2) +
      cos(radians(lat1)) * cos(radians(lat2)) *
      power(sin(radians(lng2 - lng1) / 2), 2)
    )))::numeric, 3);
$function$;

-- Precio de un recorrido: el primer tramo donde cabe. Si pasa del ultimo,
-- se cobra el ultimo tramo mas km_extra_cop por cada kilometro adicional.
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

-- El servidor pone el precio y la ganancia del conductor, pisando lo que
-- mande el celular.
create or replace function public.ytl_poner_precio() returns trigger
language plpgsql security definer set search_path to 'public'
as $function$
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
    new.distancia_km := null;
    valor := t.sin_mapa_cop;
  else
    km_recto := public.ytl_km(new.lat_recogida, new.lng_recogida, new.lat_entrega, new.lng_entrega);
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

  new.precio_cop := valor;
  new.ganancia_motero_cop := valor - t.margen_cop;
  return new;
end;
$function$;

-- IMPORTANTE: esta funcion NUNCA debe tocar el precio. Los disparadores BEFORE
-- INSERT corren en orden alfabetico (pedidos_precio, luego t_antes_pedido): si
-- esta tocara el precio, pisaria el calculo. Ya paso una vez con 7.500.
create or replace function public.antes_pedido() returns trigger
language plpgsql
as $function$
begin
  new.estado := 'nuevo';
  new.motero_id := null;
  new.pago_confirmado := false;
  -- estos datos solo los escriben las funciones del conductor (script 11)
  new.foto_entrega := null;
  new.lat_conductor := null;
  new.lng_conductor := null;
  new.pos_en := null;
  return new;
end
$function$;

create or replace function public.crear_codigo() returns trigger
language plpgsql security definer set search_path to 'public'
as $function$
begin
  insert into public.codigos_entrega(pedido_id, codigo)
  values (new.id, lpad((floor(random()*10000))::int::text, 4, '0'));
  return new;
end
$function$;

create or replace function public.tomar_pedido(p_id uuid) returns boolean
language plpgsql security definer set search_path to 'public'
as $function$
declare m uuid; n int;
begin
  select id into m from public.moteros where user_id = auth.uid() and estado = 'aprobado';
  if m is null then return false; end if;
  update public.pedidos set motero_id = m, estado = 'aceptado', actualizado_en = now()
   where id = p_id and estado = 'nuevo' and motero_id is null;
  get diagnostics n = row_count;
  return n = 1;
end
$function$;

create or replace function public.avanzar_pedido(p_id uuid, p_estado text) returns boolean
language plpgsql security definer set search_path to 'public'
as $function$
declare m uuid; n int;
begin
  select id into m from public.moteros where user_id = auth.uid() and estado = 'aprobado';
  if m is null then return false; end if;
  update public.pedidos set estado = p_estado, actualizado_en = now()
   where id = p_id and motero_id = m
     and ((estado = 'aceptado'    and p_estado = 'en_camino')
       or (estado = 'en_camino'   and p_estado = 'en_recogida')
       or (estado = 'en_recogida' and p_estado = 'recogido')
       or (estado = 'recogido'    and p_estado = 'en_entrega'));
  get diagnostics n = row_count;
  return n = 1;
end
$function$;

create or replace function public.entregar_pedido(p_id uuid, p_codigo text, p_pago_ok boolean) returns text
language plpgsql security definer set search_path to 'public'
as $function$
declare m uuid; r record; c text;
begin
  select id into m from public.moteros where user_id = auth.uid() and estado = 'aprobado';
  if m is null then return 'permiso'; end if;
  select * into r from public.pedidos where id = p_id and motero_id = m and estado = 'en_entrega';
  if not found then return 'estado'; end if;
  select codigo into c from public.codigos_entrega where pedido_id = p_id;
  if c is distinct from p_codigo then return 'codigo'; end if;
  if r.forma_pago = 'nequi' and not p_pago_ok then return 'pago'; end if;
  update public.pedidos set estado = 'entregado', pago_confirmado = true, actualizado_en = now() where id = p_id;
  return 'ok';
end
$function$;

create or replace function public.cancelar_pedido(p_id uuid) returns boolean
language plpgsql security definer set search_path to 'public'
as $function$
declare n int;
begin
  update public.pedidos set estado = 'cancelado', actualizado_en = now()
   where id = p_id and estado = 'nuevo'
     and cliente_id in (select id from public.clientes where user_id = auth.uid());
  get diagnostics n = row_count;
  return n = 1;
end
$function$;

create or replace function public.reportar_posicion(p_id text, p_lat double precision, p_lng double precision) returns boolean
language plpgsql security definer set search_path to 'public'
as $function$
declare n integer;
begin
  update public.pedidos p
     set lat_conductor = p_lat, lng_conductor = p_lng, pos_en = now()
   where p.id::text = p_id
     and p.estado in ('aceptado','en_camino','en_recogida','recogido','en_entrega')
     and p.motero_id = (select m.id from public.moteros m where m.user_id = auth.uid());
  get diagnostics n = row_count;
  return n > 0;
end;
$function$;

create or replace function public.guardar_foto_entrega(p_id text, p_path text) returns boolean
language plpgsql security definer set search_path to 'public'
as $function$
declare n integer;
begin
  update public.pedidos p
     set foto_entrega = p_path
   where p.id::text = p_id
     and p.estado in ('recogido', 'en_entrega', 'entregado')
     and p.motero_id = (select m.id from public.moteros m where m.user_id = auth.uid())
     and p_path like (auth.uid()::text || '/%');
  get diagnostics n = row_count;
  return n > 0;
end;
$function$;


-- ---------------------------------------------------------------------
-- 4) DISPARADORES sobre pedidos
--    Los BEFORE INSERT corren en orden alfabetico por nombre.
-- ---------------------------------------------------------------------
drop trigger if exists pedidos_precio  on public.pedidos;
drop trigger if exists t_antes_pedido  on public.pedidos;
drop trigger if exists t_codigo        on public.pedidos;

create trigger pedidos_precio  before insert on public.pedidos for each row execute function public.ytl_poner_precio();
create trigger t_antes_pedido  before insert on public.pedidos for each row execute function public.antes_pedido();
create trigger t_codigo        after  insert on public.pedidos for each row execute function public.crear_codigo();


-- ---------------------------------------------------------------------
-- 5) POLITICAS de seguridad (todas para el rol authenticated)
-- ---------------------------------------------------------------------
drop policy if exists admins_ver on public.administradores;
create policy admins_ver on public.administradores for select to authenticated
  using (user_id = auth.uid());

drop policy if exists clientes_propio on public.clientes;
create policy clientes_propio on public.clientes for all to authenticated
  using ((user_id = auth.uid()) or es_admin())
  with check ((user_id = auth.uid()) or es_admin());

drop policy if exists moteros_propio_ver on public.moteros;
create policy moteros_propio_ver on public.moteros for select to authenticated
  using ((user_id = auth.uid()) or es_admin());

drop policy if exists moteros_propio_crear on public.moteros;
create policy moteros_propio_crear on public.moteros for insert to authenticated
  with check ((user_id = auth.uid()) and (estado = 'pendiente'));

-- El conductor edita lo suyo, pero NO puede cambiar su propio estado:
-- solo el administrador aprueba, rechaza o suspende.
drop policy if exists moteros_propio_editar on public.moteros;
create policy moteros_propio_editar on public.moteros for update to authenticated
  using ((user_id = auth.uid()) or es_admin())
  with check (es_admin() or ((user_id = auth.uid()) and (estado = (select m.estado from public.moteros m where m.id = moteros.id))));

drop policy if exists pedidos_crear on public.pedidos;
create policy pedidos_crear on public.pedidos for insert to authenticated
  with check (cliente_id in (select clientes.id from public.clientes where clientes.user_id = auth.uid()));

-- Lo ve: el administrador, el cliente dueño, el conductor asignado, y todo
-- conductor aprobado mientras el pedido siga en "nuevo".
drop policy if exists pedidos_cliente on public.pedidos;
create policy pedidos_cliente on public.pedidos for select to authenticated
  using (
    es_admin()
    or (cliente_id in (select clientes.id from public.clientes where clientes.user_id = auth.uid()))
    or (motero_id in (select moteros.id from public.moteros where moteros.user_id = auth.uid()))
    or ((estado = 'nuevo') and exists (select 1 from public.moteros where moteros.user_id = auth.uid() and moteros.estado = 'aprobado'))
  );

-- El codigo de entrega lo ve solo el cliente. El conductor NO puede leerlo.
drop policy if exists codigo_cliente on public.codigos_entrega;
create policy codigo_cliente on public.codigos_entrega for select to authenticated
  using (exists (select 1 from public.pedidos p join public.clientes c on c.id = p.cliente_id
                  where p.id = codigos_entrega.pedido_id and c.user_id = auth.uid()));

drop policy if exists incidencias_admin on public.incidencias;
create policy incidencias_admin on public.incidencias for all to authenticated
  using (es_admin()) with check (es_admin());

drop policy if exists tarifas_lectura on public.tarifas;
create policy tarifas_lectura on public.tarifas for select to authenticated using (true);

-- Deposito de archivos
drop policy if exists doc_subir on storage.objects;
create policy doc_subir on storage.objects for insert to authenticated
  with check (bucket_id = 'documentos' and (storage.foldername(name))[1] = (auth.uid())::text);

drop policy if exists doc_ver on storage.objects;
create policy doc_ver on storage.objects for select to authenticated
  using (bucket_id = 'documentos' and ((storage.foldername(name))[1] = (auth.uid())::text or es_admin()));

drop policy if exists entrega_cliente_lee on storage.objects;
create policy entrega_cliente_lee on storage.objects for select to authenticated
  using (bucket_id = 'documentos' and exists (
    select 1 from public.pedidos p join public.clientes c on c.id = p.cliente_id
     where c.user_id = auth.uid() and p.foto_entrega = objects.name));


-- ---------------------------------------------------------------------
-- 6) PERMISOS. El rol anonimo no puede leer ni escribir nada.
--    El rol authenticated, solo lo que se lista (las politicas filtran filas).
-- ---------------------------------------------------------------------
revoke all on public.administradores, public.clientes, public.moteros, public.pedidos,
              public.codigos_entrega, public.incidencias, public.tarifas from anon;

grant select                 on public.administradores to authenticated;
grant select, insert, update on public.clientes        to authenticated;
grant select, insert, update on public.moteros         to authenticated;
grant select, insert         on public.pedidos         to authenticated;
grant select                 on public.codigos_entrega to authenticated;
grant select, insert, update on public.incidencias     to authenticated;
grant select                 on public.tarifas         to authenticated;

grant execute on function public.tomar_pedido(uuid)                          to authenticated;
grant execute on function public.avanzar_pedido(uuid, text)                  to authenticated;
grant execute on function public.entregar_pedido(uuid, text, boolean)        to authenticated;
grant execute on function public.cancelar_pedido(uuid)                       to authenticated;
grant execute on function public.reportar_posicion(text, double precision, double precision) to authenticated;
grant execute on function public.guardar_foto_entrega(text, text)            to authenticated;


-- ---------------------------------------------------------------------
-- 7) DEPOSITO de archivos: privado, sin limite de tamaño ni de tipo
--    (el limite de 15 MB esta solo en el codigo del conductor)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('documentos', 'documentos', false)
on conflict (id) do nothing;


-- ---------------------------------------------------------------------
-- 8) FILA DE TARIFAS (la unica). Margen de Ya te llega: $1.800 por pedido.
-- ---------------------------------------------------------------------
insert into public.tarifas (id, tramos, margen_cop, km_extra_cop, max_km, factor_ruta, sin_mapa_cop)
values (1, '[[3, 8000], [5, 9500], [7, 11500], [10, 14000]]'::jsonb, 1800, 1200, 40, 1.30, 8000)
on conflict (id) do nothing;


-- ---------------------------------------------------------------------
-- NOTAS
-- * La RLS automatica en tablas nuevas la da Supabase con un disparador de
--   evento (ensure_rls / rls_auto_enable). No se recrea aqui.
-- * Extensiones activas en la base real: pgcrypto, uuid-ossp,
--   pg_stat_statements, supabase_vault. NO esta instalada pg_cron.
-- * Autenticacion por correo y contraseña, con "Confirm email" apagado.
--   Eso se configura en el panel de Supabase, no con SQL.
-- =====================================================================
