-- =====================================================================
-- Ya te llega · Finanzas: comisiones, abonos, limite de deuda y auditoria
-- =====================================================================
--
-- QUE HACE
-- 1. libro_comisiones: cada pedido ENTREGADO deja una comision que el
--    conductor le debe a Ya te llega (hoy el conductor cobra todo: efectivo
--    o su propio Nequi). Una sola por pedido, aunque el evento se repita.
--    La comision es la que ya calcula el servidor: precio - ganancia del
--    conductor (margen fijo de la tabla tarifas). No se inventa nada.
-- 2. abonos: lo que el conductor le paga a Ya te llega. Solo los registra un
--    administrador. Nunca se borran: se anulan con motivo.
-- 3. ajustes_cartera: correcciones con motivo (positivas o negativas).
-- 4. config_finanzas: limite de deuda general y umbral de alerta. Empiezan
--    VACIOS = "pendiente de configuracion" (el dueño los define en el panel).
--    limites_moteros: limite individual que reemplaza al general.
-- 5. auditoria: quien hizo que, cuando, antes/despues y motivo.
-- 6. tomar_pedido: si el conductor llego a su limite, no puede aceptar
--    pedidos NUEVOS. Lo que ya lleva lo termina normal.
--
-- RECAUDO ELECTRONICO Y LIQUIDACIONES: hoy Ya te llega no recibe plata del
-- cliente (Nequi va al conductor). Quedan como "pendiente de integracion"
-- en config_finanzas.recaudo_electronico; no se simula ningun pago.
--
-- Las comisiones cuentan desde que se corre este script (comisiones_desde).
-- Los pedidos viejos no se recalculan.
--
-- No borra ni cambia datos existentes. Se puede correr varias veces.
-- =====================================================================

-- ---------- 1) Tablas ----------
create table if not exists public.config_finanzas (
  id                   integer     primary key default 1 check (id = 1),
  limite_deuda_general integer     check (limite_deuda_general is null or limite_deuda_general >= 0),
  umbral_alerta_pct    integer     check (umbral_alerta_pct is null or umbral_alerta_pct between 1 and 100),
  comisiones_desde     timestamptz not null default now(),
  recaudo_electronico  text        not null default 'pendiente_integracion',
  actualizado_en       timestamptz not null default now()
);
insert into public.config_finanzas (id) values (1) on conflict (id) do nothing;

create table if not exists public.limites_moteros (
  motero_id      uuid        primary key references public.moteros(id) on delete cascade,
  limite_cop     integer     check (limite_cop is null or limite_cop >= 0),
  actualizado_en timestamptz not null default now()
);

create table if not exists public.libro_comisiones (
  id          bigserial   primary key,
  pedido_id   uuid        not null unique references public.pedidos(id),
  motero_id   uuid        not null references public.moteros(id),
  forma_pago  text        not null,
  base_cop    integer     not null,
  regla       text        not null,
  valor_cop   integer     not null check (valor_cop >= 0),
  creado_en   timestamptz not null default now()
);
create index if not exists libro_comisiones_motero on public.libro_comisiones (motero_id, creado_en);

create table if not exists public.abonos (
  id               bigserial   primary key,
  motero_id        uuid        not null references public.moteros(id),
  valor_cop        integer     not null check (valor_cop > 0),
  medio            text        not null check (medio in ('efectivo', 'nequi', 'transferencia', 'otro')),
  referencia       text,
  nota             text,
  estado           text        not null default 'verificado' check (estado in ('verificado', 'anulado')),
  registrado_por   uuid        not null,
  creado_en        timestamptz not null default now(),
  anulado_por      uuid,
  anulado_en       timestamptz,
  motivo_anulacion text
);
create index if not exists abonos_motero on public.abonos (motero_id, creado_en);

create table if not exists public.ajustes_cartera (
  id          bigserial   primary key,
  motero_id   uuid        not null references public.moteros(id),
  valor_cop   integer     not null check (valor_cop <> 0),
  motivo      text        not null check (length(trim(motivo)) >= 5),
  pedido_id   uuid        references public.pedidos(id),
  hecho_por   uuid        not null,
  creado_en   timestamptz not null default now()
);

create table if not exists public.auditoria (
  id         bigserial   primary key,
  actor      uuid,
  accion     text        not null,
  entidad    text        not null,
  entidad_id text,
  antes      jsonb,
  despues    jsonb,
  motivo     text,
  creado_en  timestamptz not null default now()
);
create index if not exists auditoria_fecha on public.auditoria (creado_en desc);

-- Nadie escribe directo en estas tablas: solo las funciones de abajo.
alter table public.config_finanzas  enable row level security;
alter table public.limites_moteros  enable row level security;
alter table public.libro_comisiones enable row level security;
alter table public.abonos           enable row level security;
alter table public.ajustes_cartera  enable row level security;
alter table public.auditoria        enable row level security;
revoke all on public.config_finanzas, public.limites_moteros, public.libro_comisiones,
              public.abonos, public.ajustes_cartera, public.auditoria from anon, authenticated;
grant select on public.config_finanzas, public.limites_moteros, public.libro_comisiones,
                public.abonos, public.ajustes_cartera, public.auditoria to authenticated;

drop policy if exists fin_admin_lee on public.config_finanzas;
create policy fin_admin_lee on public.config_finanzas for select to authenticated using (true);
drop policy if exists fin_admin_lee on public.limites_moteros;
create policy fin_admin_lee on public.limites_moteros for select to authenticated using (es_admin());
drop policy if exists fin_admin_lee on public.libro_comisiones;
create policy fin_admin_lee on public.libro_comisiones for select to authenticated
  using (es_admin() or motero_id in (select m.id from public.moteros m where m.user_id = auth.uid()));
drop policy if exists fin_admin_lee on public.abonos;
create policy fin_admin_lee on public.abonos for select to authenticated
  using (es_admin() or motero_id in (select m.id from public.moteros m where m.user_id = auth.uid()));
drop policy if exists fin_admin_lee on public.ajustes_cartera;
create policy fin_admin_lee on public.ajustes_cartera for select to authenticated
  using (es_admin() or motero_id in (select m.id from public.moteros m where m.user_id = auth.uid()));
drop policy if exists fin_admin_lee on public.auditoria;
create policy fin_admin_lee on public.auditoria for select to authenticated using (es_admin());

-- ---------- 2) Comision automatica al entregar ----------
create or replace function public.ytl_comision_al_entregar() returns trigger
language plpgsql security definer set search_path to 'public'
as $function$
declare desde timestamptz;
begin
  if new.estado = 'entregado' and old.estado is distinct from 'entregado' and new.motero_id is not null then
    select comisiones_desde into desde from public.config_finanzas where id = 1;
    if desde is null or now() >= desde then
      begin
        insert into public.libro_comisiones (pedido_id, motero_id, forma_pago, base_cop, regla, valor_cop)
        values (new.id, new.motero_id, new.forma_pago, new.precio_cop,
                'margen fijo (precio - ganancia del conductor)',
                greatest(new.precio_cop - new.ganancia_motero_cop, 0))
        on conflict (pedido_id) do nothing;
      exception when others then
        -- Un error aqui nunca debe frenar la entrega: queda anotado para revisarlo
        insert into public.auditoria (actor, accion, entidad, entidad_id, motivo)
        values (auth.uid(), 'error_comision', 'pedido', new.id::text, sqlerrm);
      end;
    end if;
  end if;
  return new;
end
$function$;

drop trigger if exists t_comision on public.pedidos;
create trigger t_comision after update of estado on public.pedidos
  for each row execute function public.ytl_comision_al_entregar();

-- Auditoria de cambios de estado de un conductor (aprobar, suspender...)
create or replace function public.ytl_audita_motero() returns trigger
language plpgsql security definer set search_path to 'public'
as $function$
begin
  if new.estado is distinct from old.estado then
    insert into public.auditoria (actor, accion, entidad, entidad_id, antes, despues)
    values (auth.uid(), 'estado_conductor', 'motero', new.id::text,
            jsonb_build_object('estado', old.estado), jsonb_build_object('estado', new.estado));
  end if;
  return new;
exception when others then
  return new;
end
$function$;

drop trigger if exists t_audita_motero on public.moteros;
create trigger t_audita_motero after update of estado on public.moteros
  for each row execute function public.ytl_audita_motero();

-- ---------- 3) Saldos ----------
-- Lo que debe un conductor: comisiones - abonos verificados + ajustes
create or replace function public.ytl_saldo(p_motero uuid) returns integer
language sql stable security definer set search_path to 'public'
as $function$
  select (coalesce((select sum(valor_cop) from public.libro_comisiones where motero_id = p_motero), 0)
        - coalesce((select sum(valor_cop) from public.abonos where motero_id = p_motero and estado = 'verificado'), 0)
        + coalesce((select sum(valor_cop) from public.ajustes_cartera where motero_id = p_motero), 0))::integer
$function$;

create or replace function public.ytl_limite(p_motero uuid) returns integer
language sql stable security definer set search_path to 'public'
as $function$
  select coalesce((select limite_cop from public.limites_moteros where motero_id = p_motero),
                  (select limite_deuda_general from public.config_finanzas where id = 1))
$function$;

-- Cartera de todos los conductores (solo administrador)
create or replace function public.cartera_conductores()
returns table (motero_id uuid, nombre text, estado text, conectado boolean,
               comisiones integer, abonos integer, ajustes integer, saldo integer,
               limite integer, limite_propio boolean, pct integer, bloqueado boolean, alerta boolean)
language plpgsql stable security definer set search_path to 'public'
as $function$
declare umbral integer;
begin
  if not es_admin() then raise exception 'Solo el administrador'; end if;
  select umbral_alerta_pct into umbral from public.config_finanzas where id = 1;
  return query
  select m.id, m.nombre::text, m.estado::text, m.conectado,
         coalesce((select sum(c.valor_cop) from public.libro_comisiones c where c.motero_id = m.id), 0)::integer,
         coalesce((select sum(a.valor_cop) from public.abonos a where a.motero_id = m.id and a.estado = 'verificado'), 0)::integer,
         coalesce((select sum(j.valor_cop) from public.ajustes_cartera j where j.motero_id = m.id), 0)::integer,
         public.ytl_saldo(m.id),
         public.ytl_limite(m.id),
         exists (select 1 from public.limites_moteros l where l.motero_id = m.id and l.limite_cop is not null),
         case when public.ytl_limite(m.id) > 0 then (public.ytl_saldo(m.id) * 100 / public.ytl_limite(m.id))::integer end,
         (public.ytl_limite(m.id) is not null and public.ytl_saldo(m.id) >= public.ytl_limite(m.id)),
         (public.ytl_limite(m.id) > 0 and umbral is not null and public.ytl_saldo(m.id) * 100 >= public.ytl_limite(m.id) * umbral)
    from public.moteros m
   order by public.ytl_saldo(m.id) desc;
end
$function$;

-- La cartera propia (para la app del conductor)
create or replace function public.mi_cartera()
returns table (saldo integer, limite integer, pct integer, bloqueado boolean, alerta boolean)
language plpgsql stable security definer set search_path to 'public'
as $function$
declare m uuid; s integer; l integer; u integer;
begin
  select id into m from public.moteros where user_id = auth.uid();
  if m is null then return; end if;
  s := public.ytl_saldo(m); l := public.ytl_limite(m);
  select umbral_alerta_pct into u from public.config_finanzas where id = 1;
  return query select s, l,
    case when l > 0 then (s * 100 / l)::integer end,
    (l is not null and s >= l),
    (l > 0 and u is not null and s * 100 >= l * u);
end
$function$;

-- ---------- 4) Acciones del administrador (todas quedan en auditoria) ----------
create or replace function public.registrar_abono(p_motero uuid, p_valor integer, p_medio text, p_referencia text, p_nota text)
returns bigint
language plpgsql security definer set search_path to 'public'
as $function$
declare nid bigint; s0 integer;
begin
  if not es_admin() then raise exception 'Solo el administrador'; end if;
  if p_valor is null or p_valor <= 0 then raise exception 'El valor debe ser mayor que cero'; end if;
  if not exists (select 1 from public.moteros where id = p_motero) then raise exception 'Conductor no existe'; end if;
  -- Misma referencia ya registrada para ese conductor: no se duplica
  if p_referencia is not null and length(trim(p_referencia)) > 0 and exists (
       select 1 from public.abonos where motero_id = p_motero and referencia = trim(p_referencia) and estado = 'verificado') then
    raise exception 'Ya hay un abono con esa referencia';
  end if;
  s0 := public.ytl_saldo(p_motero);
  insert into public.abonos (motero_id, valor_cop, medio, referencia, nota, registrado_por)
  values (p_motero, p_valor, p_medio, nullif(trim(p_referencia), ''), nullif(trim(p_nota), ''), auth.uid())
  returning id into nid;
  insert into public.auditoria (actor, accion, entidad, entidad_id, antes, despues, motivo)
  values (auth.uid(), 'abono', 'motero', p_motero::text,
          jsonb_build_object('saldo', s0),
          jsonb_build_object('saldo', public.ytl_saldo(p_motero), 'abono_id', nid, 'valor', p_valor, 'medio', p_medio),
          p_nota);
  return nid;
end
$function$;

create or replace function public.anular_abono(p_id bigint, p_motivo text) returns boolean
language plpgsql security definer set search_path to 'public'
as $function$
declare a record;
begin
  if not es_admin() then raise exception 'Solo el administrador'; end if;
  if p_motivo is null or length(trim(p_motivo)) < 5 then raise exception 'Escribe el motivo'; end if;
  select * into a from public.abonos where id = p_id and estado = 'verificado';
  if not found then return false; end if;
  update public.abonos set estado = 'anulado', anulado_por = auth.uid(), anulado_en = now(), motivo_anulacion = trim(p_motivo) where id = p_id;
  insert into public.auditoria (actor, accion, entidad, entidad_id, antes, despues, motivo)
  values (auth.uid(), 'anular_abono', 'abono', p_id::text, jsonb_build_object('estado', 'verificado', 'valor', a.valor_cop),
          jsonb_build_object('estado', 'anulado'), trim(p_motivo));
  return true;
end
$function$;

create or replace function public.ajustar_cartera(p_motero uuid, p_valor integer, p_motivo text) returns bigint
language plpgsql security definer set search_path to 'public'
as $function$
declare nid bigint; s0 integer;
begin
  if not es_admin() then raise exception 'Solo el administrador'; end if;
  if p_valor is null or p_valor = 0 then raise exception 'El valor no puede ser cero'; end if;
  if p_motivo is null or length(trim(p_motivo)) < 5 then raise exception 'Escribe el motivo'; end if;
  s0 := public.ytl_saldo(p_motero);
  insert into public.ajustes_cartera (motero_id, valor_cop, motivo, hecho_por) values (p_motero, p_valor, trim(p_motivo), auth.uid())
  returning id into nid;
  insert into public.auditoria (actor, accion, entidad, entidad_id, antes, despues, motivo)
  values (auth.uid(), 'ajuste', 'motero', p_motero::text, jsonb_build_object('saldo', s0),
          jsonb_build_object('saldo', public.ytl_saldo(p_motero), 'valor', p_valor), trim(p_motivo));
  return nid;
end
$function$;

create or replace function public.configurar_finanzas(p_limite_general integer, p_umbral integer, p_motivo text) returns boolean
language plpgsql security definer set search_path to 'public'
as $function$
declare c record;
begin
  if not es_admin() then raise exception 'Solo el administrador'; end if;
  if p_motivo is null or length(trim(p_motivo)) < 5 then raise exception 'Escribe el motivo'; end if;
  select * into c from public.config_finanzas where id = 1;
  update public.config_finanzas set limite_deuda_general = p_limite_general, umbral_alerta_pct = p_umbral, actualizado_en = now() where id = 1;
  insert into public.auditoria (actor, accion, entidad, entidad_id, antes, despues, motivo)
  values (auth.uid(), 'config_finanzas', 'config', '1',
          jsonb_build_object('limite_general', c.limite_deuda_general, 'umbral_pct', c.umbral_alerta_pct),
          jsonb_build_object('limite_general', p_limite_general, 'umbral_pct', p_umbral), trim(p_motivo));
  return true;
end
$function$;

create or replace function public.limite_conductor(p_motero uuid, p_limite integer, p_motivo text) returns boolean
language plpgsql security definer set search_path to 'public'
as $function$
declare antes integer;
begin
  if not es_admin() then raise exception 'Solo el administrador'; end if;
  if p_motivo is null or length(trim(p_motivo)) < 5 then raise exception 'Escribe el motivo'; end if;
  select limite_cop into antes from public.limites_moteros where motero_id = p_motero;
  insert into public.limites_moteros (motero_id, limite_cop, actualizado_en) values (p_motero, p_limite, now())
  on conflict (motero_id) do update set limite_cop = excluded.limite_cop, actualizado_en = now();
  insert into public.auditoria (actor, accion, entidad, entidad_id, antes, despues, motivo)
  values (auth.uid(), 'limite_conductor', 'motero', p_motero::text,
          jsonb_build_object('limite', antes), jsonb_build_object('limite', p_limite), trim(p_motivo));
  return true;
end
$function$;

-- ---------- 5) Bloqueo por limite al tomar un pedido nuevo ----------
-- Igual que antes, mas una revision: si llego a su limite, no toma pedidos nuevos.
create or replace function public.tomar_pedido(p_id uuid) returns boolean
language plpgsql security definer set search_path to 'public'
as $function$
declare m uuid; n int; lim integer;
begin
  select id into m from public.moteros where user_id = auth.uid() and estado = 'aprobado';
  if m is null then return false; end if;
  lim := public.ytl_limite(m);
  if lim is not null and public.ytl_saldo(m) >= lim then return false; end if;
  update public.pedidos set motero_id = m, estado = 'aceptado', actualizado_en = now()
   where id = p_id and estado = 'nuevo' and motero_id is null;
  get diagnostics n = row_count;
  return n = 1;
end
$function$;

revoke all on function public.cartera_conductores() from public, anon;
revoke all on function public.mi_cartera() from public, anon;
revoke all on function public.registrar_abono(uuid, integer, text, text, text) from public, anon;
revoke all on function public.anular_abono(bigint, text) from public, anon;
revoke all on function public.ajustar_cartera(uuid, integer, text) from public, anon;
revoke all on function public.configurar_finanzas(integer, integer, text) from public, anon;
revoke all on function public.limite_conductor(uuid, integer, text) from public, anon;
revoke all on function public.ytl_saldo(uuid) from public, anon, authenticated;
revoke all on function public.ytl_limite(uuid) from public, anon, authenticated;
grant execute on function public.cartera_conductores() to authenticated;
grant execute on function public.mi_cartera() to authenticated;
grant execute on function public.registrar_abono(uuid, integer, text, text, text) to authenticated;
grant execute on function public.anular_abono(bigint, text) to authenticated;
grant execute on function public.ajustar_cartera(uuid, integer, text) to authenticated;
grant execute on function public.configurar_finanzas(integer, integer, text) to authenticated;
grant execute on function public.limite_conductor(uuid, integer, text) to authenticated;

-- Comprobacion
select (select count(*) from public.config_finanzas) as config,
       (select comisiones_desde from public.config_finanzas where id = 1) as comisiones_desde,
       (select count(*) from public.libro_comisiones) as comisiones;
