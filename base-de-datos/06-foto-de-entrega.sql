-- =====================================================================
-- Ya te llega · Foto de entrega
-- =====================================================================
--
-- QUE RESUELVE
-- Antes de cerrar un pedido, el conductor toma una foto de lo entregado.
-- Queda guardada en el pedido. La ven:
--   - El conductor que la tomo.
--   - El cliente de ESE pedido, para confirmar que llego.
--   - El administrador, en el panel, para responder un reclamo.
-- Nadie mas. Las fotos van al deposito privado "documentos", el mismo de
-- las fotos de licencia y SOAT.
--
-- Solo AGREGA. No toca nada de lo que ya funciona. Los pedidos viejos
-- quedan sin foto.
--
-- COMO CORRERLO
-- supabase.com -> su proyecto -> SQL Editor -> New query -> pegar -> Run.
-- Se puede correr varias veces sin dañar nada.
-- =====================================================================

-- 1) Donde se guarda la ruta de la foto
alter table public.pedidos
  add column if not exists foto_entrega text;

grant select (foto_entrega) on public.pedidos to authenticated;


-- 2) El conductor guarda la ruta de su foto. La funcion comprueba que quien
--    llama sea el conductor de ESE pedido, y que el pedido ya vaya por
--    recogido, en entrega o entregado.
create or replace function public.guardar_foto_entrega(p_id text, p_path text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  update public.pedidos p
     set foto_entrega = p_path
   where p.id::text = p_id
     and p.estado in ('recogido', 'en_entrega', 'entregado')
     and p.motero_id = (select m.id from public.moteros m where m.user_id = auth.uid())
     -- la foto tiene que estar en la carpeta del propio conductor
     and p_path like (auth.uid()::text || '/%');

  get diagnostics n = row_count;
  return n > 0;
end;
$$;

grant execute on function public.guardar_foto_entrega(text, text) to authenticated;


-- 3) El cliente puede abrir la foto de SUS pedidos, y solo esa.
drop policy if exists entrega_cliente_lee on storage.objects;
create policy entrega_cliente_lee on storage.objects
  for select to authenticated
  using (
    bucket_id = 'documentos'
    and exists (
      select 1
      from public.pedidos p
      join public.clientes c on c.id = p.cliente_id
      where c.user_id = auth.uid()
        and p.foto_entrega = storage.objects.name
    )
  );


-- 4) Comprobacion: devuelve una fila solo si quedo todo
select 'listo' as resultado
where exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'pedidos'
                and column_name = 'foto_entrega')
  and exists (select 1 from pg_proc where proname = 'guardar_foto_entrega')
  and exists (select 1 from pg_policies
              where schemaname = 'storage' and policyname = 'entrega_cliente_lee');
