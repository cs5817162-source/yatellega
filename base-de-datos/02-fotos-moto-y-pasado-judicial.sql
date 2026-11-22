-- =====================================================================
-- Ya te llega · Fotos de la moto y pasado judicial en el registro
-- =====================================================================
--
-- QUE AGREGA
-- Tres documentos mas que el conductor sube al registrarse, y que el
-- dueño revisa desde el panel antes de aprobarlo:
--   1. Foto de la moto donde se lea la placa (de atras, en diagonal).
--   2. Foto del otro costado, para ver en que estado esta.
--   3. Pasado judicial.
--
-- Solo AGREGA columnas, todas vacias por defecto. No toca ni borra nada
-- de lo que ya esta funcionando. Los conductores ya registrados siguen
-- igual, con esas tres casillas en blanco.
--
-- COMO CORRERLO
-- supabase.com -> su proyecto -> SQL Editor -> New query -> pegar -> Run.
-- Se puede correr varias veces sin dañar nada.
-- =====================================================================

alter table public.moteros
  add column if not exists foto_moto_placa      text,
  add column if not exists foto_moto_lado       text,
  add column if not exists foto_pasado_judicial text;

grant insert (foto_moto_placa, foto_moto_lado, foto_pasado_judicial)
  on public.moteros to authenticated;
grant select (foto_moto_placa, foto_moto_lado, foto_pasado_judicial)
  on public.moteros to authenticated;

-- Comprobacion: deben aparecer las tres
select column_name
from information_schema.columns
where table_schema = 'public' and table_name = 'moteros'
  and column_name in ('foto_moto_placa', 'foto_moto_lado', 'foto_pasado_judicial')
order by column_name;
