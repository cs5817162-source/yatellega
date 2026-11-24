-- =====================================================================
-- Ya te llega · Recogida y entrega independientes (corrido el 23-nov-2026)
-- =====================================================================
-- Reconstruido el 24-nov desde las columnas reales de la base: el archivo
-- original solo existia en el entorno del chat. Por cada punto (recogida y
-- entrega) se guarda de donde salio, que tan exacto fue y si el cliente lo
-- confirmo, aparte de lo que el cliente escribio. Hoy solo las llena
-- cliente-prueba.html.
--
-- Solo agrega columnas, todas vacias por defecto.
-- =====================================================================

alter table public.pedidos
  add column if not exists complemento_recogida     text,
  add column if not exists complemento_entrega      text,
  add column if not exists direccion_mapa_recogida  text,
  add column if not exists direccion_mapa_entrega   text,
  add column if not exists fuente_recogida          text,   -- gps | texto | mapa | compartida
  add column if not exists fuente_entrega           text,
  add column if not exists precision_recogida       integer, -- metros
  add column if not exists precision_entrega        integer,
  add column if not exists calidad_recogida         text,   -- exacta | aproximada | gps | gps-aprox | mapa | compartida | lugar
  add column if not exists calidad_entrega          text,
  add column if not exists confirmada_recogida      boolean not null default false,
  add column if not exists confirmada_entrega       boolean not null default false;
