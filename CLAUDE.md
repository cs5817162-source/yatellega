# Ya te llega — guía para quien trabaje en este proyecto

Mandados y domicilios en moto, solo en Cali, Colombia. Tres aplicaciones web
instalables (PWA), sin tiendas de aplicaciones. **Este repositorio es
público**: aquí nunca van contraseñas, llaves privadas ni la llave
`service_role` de Supabase, ni datos personales, ni cifras del negocio.

## Cómo trabajar (reglas del dueño)

- Responder en **español**, tono de Cali, frases cortas. **Un paso y una sola
  pregunta por mensaje.** El dueño no es técnico y prueba en su celular.
- **Solo mejorar: nunca romper ni quitar lo que ya funcionaba.**
- **No publicar en producción** (`cliente.html`, `conductor.html`,
  `panel.html`) sin su aprobación expresa. Lo nuevo se prueba primero en
  copias `*-prueba.html`.
- **Antes de cambiar la base de datos, avisar y esperar respuesta.**
- No gastar plata ni activar servicios de pago sin presentar el costo.
- Nada de Firebase, ni archivos `.bat`, ni pedirle que use una terminal.
- No decir que algo «quedó solucionado» porque el código cambió: decir qué se
  probó de verdad y qué falta probar en el celular.
- Los enlaces se entregan en bloque de código, con `?v=N` nuevo para evitar
  la caché.

## Dos Claude, una sola fuente de verdad

Trabajan en este proyecto **Claude Code** y el chat de claude.ai. La fuente de
verdad es **este repositorio**. Reparto: el chat piensa (negocio, tarifas,
textos, estrategia) y Claude Code construye (código, base de datos,
publicación). Código y base de datos se tocan desde **un solo lado a la vez**.
Antes de empezar: `git fetch` y mirar `git log HEAD..origin/main`.

## Piezas

| Archivo | Qué es |
|---|---|
| `index.html` | Menú de entrada |
| `cliente.html` | Cliente: registro, pedir con mapa, seguir la moto, ver la foto de entrega |
| `conductor.html` | Conductor: registro con documentos, conectarse, ofertas, ruta, entrega con código y foto, ganancias |
| `panel.html` | Administrador: en vivo, resumen, conductores, clientes, incidencias |
| `motero.html` | Solo redirige a `conductor.html` (enlaces viejos) |
| `cliente-prueba.html`, `conductor-prueba.html` | Copias para probar cambios antes de pasarlos a producción. Hoy son iguales a las de producción |
| `ytl.js`, `ytl.css` | Código común: cliente Supabase, sesión por pantalla, sonido |
| `base-de-datos/` | SQL numerados y ya corridos en Supabase |
| `MEJORAS.md` | Lecciones aprendidas de otras apps de domicilios |

Cada pantalla guarda **su propia sesión** (`ytl-<pagina>`), para poder estar
como cliente, conductor y administrador en el mismo celular.

## Base de datos (Supabase, São Paulo, plan gratis)

Tablas: `clientes`, `moteros` (= conductores), `pedidos`, `codigos_entrega`,
`incidencias`, `administradores`, `tarifas`. RLS activada en todas.

- Los cambios de estado de un pedido pasan **solo por funciones**
  (`tomar_pedido`, `avanzar_pedido`, `entregar_pedido`, `cancelar_pedido`,
  `guardar_foto_entrega`, `reportar_posicion`). No hay UPDATE directo.
- El **precio lo calcula el servidor** con triggers sobre `pedidos`. Los
  `BEFORE INSERT` corren en **orden alfabético**: `pedidos_precio` y después
  `t_antes_pedido`. **`antes_pedido()` nunca debe tocar el precio**: lo
  pisaría. Ya pasó una vez.
- Las tarifas viven en la tabla `tarifas` (una sola fila): `tramos`,
  `margen_cop`, `km_extra_cop`, `max_km`, `factor_ruta`. Se cambian desde
  Supabase, sin tocar código. El cliente lee los mismos valores para mostrar
  el precio antes de pedir.
- Las fotos y documentos van al depósito **privado** `documentos`, en la
  carpeta `<auth.uid()>/`. Se ven con URL firmada.
- El plan gratis **se pausa** tras ~1 semana sin actividad: entrar a Supabase
  y pulsar «Resume project».

### Finanzas (script 14)

- `libro_comisiones`: se llena sola al quedar un pedido `entregado` (trigger
  `t_comision`, una por pedido). Comisión = precio − ganancia del conductor.
- `abonos` y `ajustes_cartera`: solo por funciones de administrador
  (`registrar_abono`, `anular_abono`, `ajustar_cartera`). Nada se borra.
- `config_finanzas` (límite general y alerta, vacíos = pendiente) y
  `limites_moteros`. `tomar_pedido` no deja tomar pedidos nuevos al conductor
  que llegó a su límite; lo que ya lleva lo termina.
- `auditoria`: registro de acciones. El panel la muestra en Finanzas.
- Recaudo electrónico y liquidaciones: pendiente de integración (hoy el
  conductor cobra todo).
- `contacto_pedido` (script 13): celular de la otra parte solo con el pedido
  en curso.

### Calificaciones (script 15)

- `calificaciones`: una por pedido entregado, estrellas del pedido y del
  conductor (1 a 5) y comentario opcional. Solo por `calificar_pedido` (el
  cliente dueño). El conductor ve su promedio con `mi_calificacion`; el panel
  las ve todas (promedios y calificaciones bajas en Resumen).

### Cómo cambiar la base de datos

1. Avisar al dueño y esperar su OK.
2. Escribir un archivo `base-de-datos/NN-nombre.sql` que se pueda correr
   varias veces sin dañar nada, y terminarlo con una consulta de comprobación.
3. Probar en el editor SQL de Supabase con una transacción que se deshace
   (`raise exception` al final), insertando un pedido de prueba, **antes** de
   afirmar que funciona.
4. Guardar el `.sql` en este repositorio.

## Mapas y direcciones

Leaflet + OpenStreetMap, todo gratis. Rutas con el OSRM público, que es solo
de demostración. En Cali el mapa libre casi no tiene número de casa: el **GPS
y las coordenadas** mandan, el texto es una etiqueta que nunca se pisa. A
Waze y Google Maps se les manda el punto, no la dirección escrita.

- **Dirección escrita → punto:** `cliente.html` interpreta la nomenclatura de
  Cali ("Cra 41D 2 # 55B-63"), busca la geometría de las dos calles en
  Nominatim y calcula dónde se cruzan. Tarda unos 5 s. Si no encuentra el
  número, queda en la esquina o en la calle y lo dice.
- **GPS → texto:** acepta hasta 50 m; hasta 150 m lo acepta pidiendo revisar
  el marcador; más de 150 m lo rechaza. Sin número de casa, sondea con
  Nominatim las calles de al lado y escribe "Calle 55A entre Carrera 41E y
  Carrera 41C".
- **No usar Overpass** (el servicio público de calles): se cae con
  frecuencia (502 y tiempos agotados). Nominatim permite 1 consulta por
  segundo; el código ya las espacia con `turno()`.
- Cada punto guarda de dónde salió, la precisión y si el cliente lo
  confirmó (columnas de `pedidos`, script 09).
- **Dirección que el mapa no tiene:** se pide igual. El punto sale del barrio,
  de la calle o de un toque del cliente en el mapa (solo para el precio por
  distancia); `calidad_*` queda en `barrio`, `calle` o `sin_mapa` y el
  conductor navega por el texto. Al llegar, su GPS la guarda en
  `direcciones_aprendidas` (script 12) y el próximo cliente la encuentra
  exacta con `buscar_direccion_aprendida(texto)`. Esa tabla no se lee entera.

## Para probar sin dañar nada

Servidor local de pruebas: `node` con un servidor estático sobre la carpeta;
las copias con inicio de sesión falso nunca se suben. Cambiar el enlace con
`?v=N` para saltarse la caché del celular.
