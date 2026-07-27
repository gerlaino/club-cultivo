# Changelog

## Julio 2026 (u) — etiquetas QR en tanda

Etiquetar los lotes recién creados obligaba a entrar a cada uno y disparar una impresión por lote.
Ahora en **Plantas** y en **Lotes** se seleccionan filas y sale **una sola hoja**.

- **"Seleccionar todo" = todo lo FILTRADO, no la página visible** (`useSeleccion`): filtrás esqueje y
  entran los 47 esquejes aunque la tabla muestre 10. La selección **sobrevive al cambio de filtro y
  de página**, así se arma una tanda mixta en dos pasadas; la barra avisa cuántos quedaron fuera del
  filtro actual para que "25 seleccionadas" con 12 filas a la vista no parezca un bug.
- **Mientras genera, la pantalla se bloquea** (`BloqueoProgreso`): clicks, teclas —incluido Escape— y
  el scroll del fondo. Cambiar el filtro a mitad de camino imprimía una hoja que no era la pedida, y
  el botón se podía apretar dos veces.
- **`lib/etiquetaLote.js` es fuente única** de la etiqueta de lote (80×50mm): el HTML estaba inline en
  `LoteDetailView`, así que la tanda habría divergido a la primera corrección. Hoja A4 de 2×5 por
  página, sin partir etiquetas. Las plantas reusan la banderita plegable de `lib/etiquetaPlanta.js`:
  la etiqueta no cambia según de dónde se imprima.
- **Fix del bloqueador de popups:** `window.open()` se disparaba *después* del await de generación, y
  ahí ya no cuenta como gesto del usuario (le pasaba a las etiquetas de plantas de un lote). Ahora la
  ventana se abre en el mismo tick del click con un cartel de "generando" y recibe el HTML al final —
  por eso `useEtiquetasQR` recibe la **función** de config y no el config resuelto: resolverlo antes
  gastaba el gesto. Si igual la bloquean, cae en descarga y no se pierde el trabajo.

## Julio 2026 (t) — tareas pendientes accionables + tres bugs de producción

**Tareas: el listado que faltaba.** El calendario semanal era la única vista, así que las tareas
**sin fecha no se veían en ninguna pantalla** y las vencidas solo navegando a la semana pasada: el
KPI decía "tenés 7 pendientes" y no había forma de saber cuáles. Ahora `tareas#dashboard` devuelve
`pendientes` (el mismo scope `pendientes_al_dia` que el KPI, ordenado por fecha más vieja primero y
las sin fecha al final, tope 100), y `/tareas` lo muestra debajo del calendario agrupado en
**Vencidas / Hoy / Sin fecha**. El ✓ de cada fila la cierra sin pedir horas; con checkboxes aparece
la barra **"N seleccionadas → Completar"** (reusa `completar_masivo`, pensado justo para registrar
retroactivo). Click en la fila abre el panel de detalle de siempre, que es donde se cargan horas y
notas. El KPI Pendientes ahora hace scroll al bloque.

De paso, dos bugs de fecha en esa vista: `toISOString()` es UTC, así que **pasadas las 21hs (AR) las
tareas de hoy se veían como vencidas** y la navegación semanal arrancaba un día corrido. Y a
`TIPO_EMOJI`/`TIPO_META` les faltaban 5 tipos (`nutricion`, `defoliacion`, `scrog_lst`,
`ajuste_luz`, `revision_plagas`): salían con el pill vacío en el detalle.

**Borrar una venta del salón: había una sola puerta y era la equivocada.** `deleteBarVenta` no
estaba conectado a ninguna UI, así que la única forma aparente de deshacer una venta era borrar su
asiento "Venta bar #N" desde Contabilidad — y eso **se llevaba el ingreso del libro sin devolver el
stock** (la mercadería ya había salido al cobrar). `movimientos_contables#destroy` guardaba contra
dispensaciones y compras de insumo, pero no contra ventas del bar. Ahora lo bloquea con el mismo
criterio y explica dónde borrarla, y hay botón 🗑️ en **Salón → Vender → 🧾 Ventas**
(admin/supervisor) que revierte las dos cosas vía `BarVenta#revertir_efectos`.

**Depósitos duplicados: una race condition en la siembra.** En prod aparecían dos "General" y dos
"Cultivo" de la MISMA sede, creados con 1-2 ms de diferencia. La siembra corre desde un
`before_action` (`asegurar_depositos`) que tienen **dos** controllers (`depositos#index` e
`insumos#index`), y el frontend los pide en paralelo desde el mismo `onMounted`: los dos vieron que
faltaba sembrar y los dos sembraron. La unicidad era solo validación de modelo, que no protege de
una race. Cerrado por los dos lados:

- **Lock** de la fila del club en `Finanzas::SembrarDepositos` → el segundo request encuentra lo que
  sembró el primero (más un rescue de `RecordNotUnique` como red).
- **Índice único parcial** `index_depositos_sistema_unico` sobre
  `(club_id, COALESCE(sede_id, 0), clave_sistema)` con `WHERE clave_sistema IS NOT NULL AND
  deleted_at IS NULL`. El `COALESCE` importa: en un índice único los NULL son distintos entre sí, y
  sin eso dos legacy club-wide seguirían pudiendo duplicarse. La migración **deduplica antes** de
  crear el índice (SQL propio: una migración no debe depender de los modelos).
- **`rake depositos:deduplicar`** (con `DRY_RUN=1`) para inspeccionar/limpiar a mano: se queda con
  el id más bajo, le mueve insumos y productos del bar, y retira el resto (soft-delete).

Además, dos cosas que hacían ilegible el caso multi-sede: los tabs del Depósito ahora se
desambiguan con la sede cuando un nombre aparece repetido, y las opciones del filtro de sede se
derivan de los propios depósitos si el store de sedes no cargó (el club se veía como mono-sede: sin
filtro y con los tabs sin etiqueta). Y `Finanzas::SembrarDepositos` tenía un bug que dejaba la
sede-ificación trabada **para siempre**: `Sede` es soft-delete, y un insumo apuntando a una sede
borrada no tenía depósito destino → no se migraba → el depósito club-wide legacy no se podía retirar
nunca. Ahora cae en la sede principal.

**`＋ Comprar`** del Depósito abre el modal de Nuevo movimiento directo (`/contabilidad?nuevo=1`).

## Julio 2026 (s) — dispensar desde lo apartado para un evento + consumo interno

Cierra el ciclo de lo apartado (jul-27 «p»). Antes quedaba un agujero: se apartaba stock para un
evento pero el dispensador **no podía dispensarlo** (el propio apartado lo bloqueaba), y lo
consumido al cerrar no descontaba nada — el inventario quedaba inflado.

**El apartado se reparte en tres destinos, y dos se llenan solos:**

- **DISPENSADO — durante el evento.** El carrito de dispensa muestra lo apartado por eventos
  **en curso** (`stocks#index` expone `apartados_evento`) y el dispensador tilda *«dispensar desde
  lo reservado para Evento X»*. La línea guarda `dispensacion_items.evento_bar_id` (trazabilidad:
  qué evento consumió qué gramos, con su paciente) y la cantidad se **imputa a la provisión**
  (`cantidad_consumida`), liberando el bloqueo en la misma medida — sin doble descuento.
  Es explícito a propósito: **sin tildar, la dispensa sale del stock libre** y no se come lo
  apartado. Solo vale con el evento `en_curso` y con apartado real de ese stock.
- **CONSUMO INTERNO — al cerrar.** Lo que se consumió sin dispensar a nadie identificable
  (degustación, muestra) se declara en el cierre: descuenta de verdad con `StockMovimiento` tipo
  **`consumo_evento`** (tipo propio, no `merma`: no es lo mismo «se consumió en el aniversario»
  que «se pudrió») y es **COGS del evento**. Se recorta al saldo apartado: nunca descuenta de más.
- **LIBERADO.** El resto suelta el bloqueo y vuelve al pozo disponible.

**Contabilidad:** al evento le cuesta **solo el consumo interno**, no lo dispensado — eso tiene su
propio costo e ingreso en la dispensación y contarlo acá sería duplicarlo. Sin asientos nuevos:
es atribución calculada, el criterio que ya usa el módulo.

Migración `add_consumo_evento_a_provisiones_y_dispensas`
(`evento_bar_provisiones.cantidad_consumo_interno` + `dispensacion_items.evento_bar_id`).
Spec `evento_dispensa_apartado_spec` cubre el ciclo completo con el caso real (apartar 250 g,
dispensar 100 durante el evento, consumir 25, liberar 125).

## Julio 2026 (r) — el cierre de período nunca alcanza al día en curso

- **Guard:** `cerrar_periodo` ahora exige `hasta < hoy`. Si se pudiera cerrar el día en curso,
  todo asiento automático (venta del salón, dispensación, compra) nace con fecha de hoy y sería
  rechazado por la validación de período cerrado: el mostrador quedaría sin poder cobrar. La UI ya
  cerraba solo hasta fin del mes anterior; esto lo hace cumplir del lado del servidor.
- **Mensaje claro en vez de 500:** `bar/ventas#create` rescata `RecordInvalid` y explica el motivo
  (antes, con un cierre heredado que incluyera hoy, el POS devolvía un 500 sin explicación).
- Specs: cierre del día en curso rechazado, venta OK con cierre hasta ayer, venta bloqueada con
  mensaje si el cierre incluye hoy.

## Julio 2026 (q) — el mostrador del salón vende de otros depósitos (F4)

- **Antes:** el POS solo vendía `BarProducto` (depósito Salón). Vender una remera del depósito
  General obligaba a recargarla como producto del bar → el mismo ítem en dos lados y el stock
  descuadrado.
- **Ahora:** la línea de venta es **polimórfica** (`bar_venta_items.vendible_type/vendible_id`,
  migración `add_vendible_a_bar_venta_items` con backfill; `bar_producto_id` se conserva por
  compatibilidad). Una venta puede mezclar producto del bar + insumo, y **cada línea descuenta de
  SU depósito**. Borrar la venta repone en cada depósito de origen.
- **REGLA: ningún `Stock` se vende por el mostrador** — ni el propio, ni los derivados, ni el
  externo (merch/bebida). Todo lo trazable sale por **dispensación**, que ya es su canal (el
  carrito de dispensa lista el externo igual que la flor). Dos puertas de salida para el mismo
  ítem = descuadre y confusión sobre qué se maneja dónde.
- **`Bar::ItemVendible`** (nuevo): envoltorio único de "algo vendible/proveíble" — nombre, unidad,
  depósito, disponible, costo, precio, `descontar!`/`reponer!`. El `case` por tipo vive **una sola
  vez** y lo comparten el POS, la provisión de eventos (`EventoBarProvision` ahora delega en él) y
  la reversión de una venta.
- **Precio:** el ítem usa su precio propio (`precio_ars` / `precio_sugerido_ars`); un insumo no
  tiene precio de venta, así que exige **precio a mano — solo admin/supervisor**. El dispensador
  solo ve y cobra lo que ya tiene precio cargado.
- **Regla dura:** el stock **regulatorio** (flor y derivados) **no se vende por el mostrador** —
  sale por dispensación. El buscador nunca lo ofrece y el service lo rechaza.
- Endpoint nuevo `GET /bares/:id/vendibles?q=` (buscador cross-depósito, sin plata para el
  dispensador). Frontend: el buscador del POS suma la sección **“En otros depósitos”**; el carrito
  pasó a líneas genéricas (`{tipo, id, nombre, precio, disponible, deposito}`) con modal de precio
  para los ítems sin precio.

## Julio 2026 (p) — la flor se puede apartar para un evento del salón (F3b) + reserva parcial

- **`Stock` provisionable en eventos, SIEMPRE como APARTADO** (propio, derivados y externo por
  igual). Es **la misma mecánica que una reserva de paciente, con otro destinatario**: reservar
  **no descuenta** el inventario, bloquea la cantidad (`Stock#apartado_para_eventos`, que entra en
  `gramos_reservados` y `cantidad_disponible_real`) para que ninguna dispensa ni reserva de
  paciente la pise, y al cerrar el evento se libera. El stock sale del inventario **solo al
  dispensarse** — no se agregaron tipos de `StockMovimiento`: no hay salida sin dispensación.
- **No suma COGS al evento:** su costo e ingreso viven en la dispensación; contarlos también acá
  inflaría el resultado del evento.
- **Reserva PARCIAL:** `provisiones/reservar` aparta de cada ítem lo que haya y devuelve
  `advertencias` con el faltante (antes era todo-o-nada: un solo faltante bloqueaba la reserva
  entera del evento). Fix de paso: `faltante` ahora descuenta lo ya reservado (antes seguía
  marcando faltante después de reservar).
- Buscador de provisión y UI: el dispensario aparece junto al salón/cultivo/general, con chip
  **apartado** y el aviso de reserva parcial. Sin migración (el polimórfico ya existía).

## Julio 2026 (o) — la sede del movimiento la fija el depósito (no se puede divergir)

- **Guard de integridad multi-sede:** al cargar un movimiento con destino a un depósito, la **sede
  del asiento (y del insumo) la manda el depósito** — ya no se puede quedar en una sede distinta.
  - Backend (`aplicar_deposito!`): `sede_id = deposito.sede_id` (prioritario); actualiza el movimiento
    a esa sede aunque el form haya mandado otra. Spec en `movimiento_deposito_spec`.
  - Frontend (`ModalNuevoMovimiento`): al elegir un depósito, el selector de "Sede" del movimiento
    queda **bloqueado** en la sede del depósito, y el alta de insumo nuevo muestra "va a 📍 {sede}".

## Julio 2026 (ñ) — Depósitos por sede — Fase 2 (frontend sede-aware)

- **Hub Depósito (`InsumosView`):** los tabs se filtran por la **sede elegida** (selector que ya
  existía); con "Todo el club" se ven todos con la **sede en la etiqueta** (`Cultivo · Sede Centro`).
  Las vistas read-only (Salón/Dispensario) reciben la sede del depósito activo.
- **Catálogo por área (`FinanzasCatalogoView`):** cada depósito muestra su **📍 sede**.
- **Nuevo Movimiento (`ModalNuevoMovimiento`):** la opción de depósito muestra su sede, y **elegir un
  depósito fija la sede del movimiento** (cada depósito es de una sede).
- Backend: la serialización del depósito suma `sede_id`/`sede_nombre`; `asegurar_depositos` (también
  en `depositos_controller`) dispara la sede-ificación en el primer acceso. Build + 58 vitest verdes.

## Julio 2026 (n) — Depósitos por SEDE (multi-sede) — Fase 1 (backend)

- **Cambio foundational:** el depósito pasa de ser del CLUB a ser de una **SEDE**. Antes la sede
  vivía en el ítem (`insumo.sede_id`); ahora vive en el depósito. Cada sede tiene sus depósitos.
  - `Deposito.sede_id` (migración `add_sede_a_depositos`); unicidad de sistema por `(club, sede, clave)`.
  - **`SembrarDepositos` por sede:** General en todas; **Cultivo** en producción/mixta; **Salón**
    (con bar) y **Dispensario** en social/mixta. Al crear una sede, estrena sus depósitos.
  - **Sede-ificación de lo legacy (idempotente):** reasigna los insumos de los depósitos club-wide
    (sede_id nil) a su depósito por-sede (por la sede del insumo; los "pool" sin sede → la sede
    principal, la más antigua) y retira los viejos. Corre lazy en el primer acceso a Depósito/Insumos.
  - Specs de `sembrar_depositos` (per-sede por tipo, sede-ificación, migración legacy, idempotencia).
    Suite backend 1193 verde.
- **Pendiente Fase 2 (frontend sede-aware):** el hub Depósito, el catálogo por área y el Nuevo
  Movimiento deben **agrupar/mostrar por sede** (si no, un club multi-sede vería depósitos con nombre
  repetido). Para un club de **una sede** ya se ve igual que antes.

## Julio 2026 (m) — el área "Administración" pasa a llamarse "General"

- **Área del sistema "Administración" → "General"** (nombre visible más claro; el `tipo` interno
  sigue siendo `administracion`). Es el área transversal/administrativa del club — el catch-all para
  categorías genéricas (evita crear un "Sin área" real). Seed actualizado (`SembrarCatalogo`) para
  clubes nuevos + migración de datos `renombrar_administracion_a_general` para los existentes (solo
  renombra las que conservan el nombre por defecto, no pisa nombres personalizados).

## Julio 2026 (l) — Catálogo de Finanzas como mapa por área (acordeón)

- **Rediseño de la tab "Categorías" (Contabilidad → `FinanzasCatalogoView`):** de dos columnas
  paralelas (Categorías | Áreas) a un **acordeón por área**. Cada área del club se despliega y
  muestra **todo lo suyo junto**: sus categorías (madre → subcategoría, con las mismas acciones) y
  sus **depósitos** (read-only; se gestionan en el hub *Depósito*). El área es el eje — tanto las
  categorías como los depósitos responden a un área.
- **Bucket "Sin área":** las categorías sin área asignada caen en un desplegable "Sin área" al final,
  así ninguna queda huérfana. Cada área muestra un resumen ("X categorías · Y depósitos").
- Frontend puro (carga `listDepositos` para el mapa). Build + 58 vitest verdes.

## Julio 2026 (k) — "Depósito" como hub de inventario (gestión, no creación)

- **La sección "Depósito" (`/insumos`) es un hub de solo-gestión, no de creación:**
  - Muestra **todos los depósitos** (Cultivo, General, custom, + Salón y Dispensación read-only).
  - **Se quitó el "＋ Entrada" que creaba productos nuevos.** Los productos **nuevos se compran
    desde Contabilidad → Nuevo Movimiento** (ahí se elige el depósito destino; ya funcionaba).
  - Por producto: **Reponer** (→ genera el egreso), **Reconteo / Merma**, **Editar**, **Desactivar**,
    **Eliminar** (ya existían). El modal de entrada quedó como "Reponer stock" (sin modo "nuevo").
  - **Read-only** (se ven pero se operan desde su lugar): **Salón** (desde el bar) y **Dispensación**
    (su stock viene de cosecha/manicura).
- El tab de Producción vuelve a llamarse **"Stock"** (para que "Depósito" sea solo el hub del sidebar).

## Julio 2026 (j) — comprobante de venta del bar (no fiscal)

- **Reimprimir comprobante de una venta pasada:** botón **"🧾 Ventas"** en Vender → lista de últimas
  ventas (`listBarVentas`, ya trae ítems/total/medio/fecha) con **🖨️ reimprimir** por fila, que
  reabre el mismo ticket. Frontend puro, sin backend nuevo.
- **Imprimir comprobante tras cobrar:** al cerrar una venta en *Vender*, se ofrece el ticket
  imprimible (`TicketVenta.vue`, ancho tipo térmica) con el detalle: club/salón, fecha·hora·N°,
  ítems (cantidad × nombre · subtotal · precio unitario), total y medio de pago. Leyenda
  obligatoria **"COMPROBANTE NO VÁLIDO COMO FACTURA"**. Imprime con `window.print()` (un `@media
  print` no scoped deja visible solo el ticket). Sin backend: se arma del carrito al cobrar.

## Julio 2026 (i) — stock del bar: una puerta, alta en un paso, y libros que dicen "Bar"

- **Los asientos del bar se leen "Bar / Salón" (no "Otro"):** nueva categoría contable `bar`; la
  compra de mercadería, la venta, y los costos/entradas de eventos ahora se categorizan como `bar`
  (antes `otro`). El rollup "Por categoría", el libro y los reportes muestran "Bar / Salón". La
  compra desde *Nuevo Movimiento* también (`aplicar_salon!`). Nota: los movimientos viejos siguen
  en "Otro" (no es retroactivo).
- **Alta unificada del producto del bar (un paso):** `POST /bares/:id/productos` acepta
  `carga_inicial` (cantidad + costo) y crea el producto **y** registra la primera compra
  (stock + costo promedio + egreso "Bar") en la misma transacción. Adiós al "crear en 0 y después
  ir a Comprar". En *Stock del salón* (sección "Carga inicial") y en el *scan-to-create* de Vender.
- **Detalle al click en el libro:** cada asiento es clickeable → modal con qué/quién/cuándo/dónde;
  los del bar traen link **"Entrar al salón"** (`es_bar` + `bar_id` en la serialización).
- **Una sola puerta:** cartel en Insumos → Entrada avisando que la mercadería del bar se carga
  desde *Salón → Stock del salón* (ahí cayeron por error compras que debían ir al bar).
- Specs: alta unificada (`bar_producto_alta_spec`), compra categorizada `bar` (`bar_producto_spec`).

## Julio 2026 (h) — se guarda el Layout de slots de sala (para retomarlo con 3D)

- **Sacado el Layout de slots por sala:** la asignación a slots era ficticia (el grid metía los
  lotes activos por orden de id en `pots_count` posiciones; no había campo de slot real por lote),
  y con varios lotes por sala mostraba algo engañoso. Se removió la **tab "Layout"** de la ficha de
  sala y el campo **"Slots para lotes"** (`pots_count`) del alta/edición de sala.
- **Shelving reversible:** el componente `SalaLayoutGrid.vue` y la columna `pots_count` quedan
  **dormidos** (sin uso, sin borrar) para retomar la feature bien con la simulación de cultivo 3D.
  Sin migración.

## Julio 2026 (g) — audit log Fase 2 (Paciente/User/Reserva) + scan-to-create

- **Audit log Fase 2:** `include Auditable` en **Paciente, User y Reserva**.
  - **Privacidad primero (allowlist):** el concern suma `auditar_solo :campos` — audita SOLO lo
    listado, así una columna nueva no se filtra por olvido. **Paciente** audita solo `nombre`,
    `apellido`, `fecha_nacimiento`, `reprocann_vencimiento`, `reprocann_estado` — **nunca** los
    campos cifrados at-rest (dni, reprocann_numero, email, teléfono) ni los clínicos (anamnesis,
    diagnósticos, etc.), que descifrados romperían ENC-01 + la privacidad clínica.
  - **User** audita solo `role` (evento de seguridad clave) + nombre/apellido/emails — excluye
    automáticamente el ruido de Devise (login/sign_in tracking, tokens, password) y los cifrados
    (dni, phone). **Reserva** se audita completa (no cifra nada).
  - Endpoint y UI ya soportan los tipos nuevos (Paciente/Usuario/Reserva en el filtro del historial).
  - Specs: `auditable_fase2_spec` (allowlists + wiring: un campo clínico nunca llega al rastro).
- **Scan-to-create (código de barras):** en *Vender*, si un admin escanea (cámara o lector) un
  código **no registrado**, se abre el alta rápida del producto con el código ya cargado
  (nombre/categoría/precio/stock inicial). Así nunca hay que pre-cargar a mano: la primera vez que
  ves un producto, lo escaneás y lo creás. (No-admin: aviso de "código no asignado".)

## Julio 2026 (f) — código de barras en el POS del salón (lector físico + cámara)

- **Infra:** columna `codigo_barras` en `bar_productos` (migración `add_codigo_barras_a_bar_productos`),
  **única por bar** entre productos vivos (índice parcial `codigo_barras IS NOT NULL AND deleted_at IS NULL`).
  Validación de unicidad scopeada al bar (opcional; se reutiliza si el producto se borra).
- **Backend:** `codigo_barras` permitido y serializado en `Bar::ProductosController`.
- **Escaneo — dos modos, mismo handler:**
  - **Lector físico (USB/Bluetooth "keyboard wedge"):** en *Vender*, el buscador acepta el código +
    Enter → agrega el producto al carrito. Cero librería. (Si no matchea código pero hay un único
    resultado por nombre, también lo agrega.)
  - **Cámara (celu/tablet/webcam de escritorio):** componente `BarcodeScanner.vue` con `@zxing/browser`
    (1D EAN/UPC/Code-128 + 2D, cámara trasera por defecto, anti-rebote). Botón 📷 en *Vender* (escaneo
    continuo → agrega varios seguidos) y en el form de *Stock del salón* (scan-to-fill del código).
- **Carga del código:** en *Stock del salón*, el form de producto suma el campo "código de barras"
  (tipeado o escaneado con 📷).
- Spec: unicidad por bar en `bar_producto_spec`. Dep nueva: `@zxing/browser` (frontend).

## Julio 2026 (e) — historial por usuario (audit log, Fase 1)

- **Rastro de actividad por usuario, read-only:** aprovechando la infra ya existente (`Auditoria`
  inmutable + concern `Auditable`), se activó el registro en **Lote, Plant, Stock y Dispensación**
  (`include Auditable`). Cada create/update/delete queda con quién (`Current.user`), qué cambió
  (diff `campo: antes → después`) y cuándo.
- **Señal sobre ruido:** el concern ahora admite `no_auditar :campo`. Se excluyen contadores/derivados:
  `plants_count` en Lote; `cantidad` y `lote_origen_consumido_g` en Stock (los cambios de cantidad
  ya viven en `stock_movimientos` con usuario). Dispensación deriva `club_id` del paciente.
- **Endpoint:** `GET /usuarios/:id/auditorias` (admin-only, tenant-scoped, más recientes primero).
  Filtrable por **rango de fechas** (`desde`/`hasta`) y **tipo**; paginado (`per_page` 10/25/50,
  `total_pages`). Devuelve el diff formateado solo en ediciones.
- **UI:** tab **"Historial de actividad"** en el detalle de usuario (`UsuarioDetail`), read-only:
  **tabla** (Fecha · Acción · Tipo · Registro · Cambios) con **filtros** (desde/hasta/tipo) y
  **paginador**. Muestra antes→después con nombres de campo legibles.
- **Sin migración** (la tabla `auditorias` ya existía). No es retroactivo: registra desde ahora.
- Spec: `usuario_auditorias_spec` (endpoint, paginación, aislamiento de tenant, exclusiones, 403 no-admin).

## Julio 2026 (d) — rediseño del Salón COMPLETO (B3–B6)

- **B3 · Vender = lista + buscador:** `BarPosView` pasó del grid con tabs de categoría a una
  **lista buscable por nombre** (chips de categoría como filtro secundario, "Todas" por defecto) +
  **hueco reservado para el lector de código de barras**. Cada fila: nombre, categoría, precio,
  stock y "+". Carrito igual, a la derecha.
- **B4 · Resumen liviano:** el Panel muestra glanceable lo accionable (resultado del mes, caja del
  turno, KPIs de hoy, **reponer**) y **pliega el análisis** (ventas por hora, top de hoy, lecturas)
  detrás de un toggle "Análisis del salón", cerrado por defecto.
- **Horario del evento:** columna `horario` (texto libre, ej. "22:00 a 05:00", migración
  `add_horario_a_eventos_bar`). Se pide en el modal de alta y se muestra en el listado y la ficha.
- **Cierre — Depósito→solapa Salón read-only:** `DepositoSalon.vue` dejó de duplicar la gestión del
  stock del bar (sacados Comprar / Reconteo / +Producto). Ahora es una **vista de solo lectura**
  (lista valorizada + historial de movimientos) con CTA a **Stock del salón**, único lugar de gestión.
- **Cierre — editar evento desde la ficha:** botón **✏️ Editar** en `EventoBarDetailView` (modal
  nombre/fecha/horario/aforo/ingresos estimados). Antes esos campos solo se seteaban al crear.

## Julio 2026 (d.1) — rediseño del Salón: caja con confirmación (B5) + eventos por fases (B6)

- **B5 · Caja de turno con confirmación entre roles:** el ciclo de la caja ahora reparte
  responsabilidades — admin/supervisor **abre** (fondo) → el dispensador **confirma** que la plata
  está → el dispensador **envía el cierre** (cuenta el efectivo, ve el esperado) → admin/supervisor
  **confirma el cierre** (o cierra directo). Estado intermedio `pendiente_cierre` (migración
  `add_confirmacion_a_caja_turnos`, índice único de "caja activa" que incluye el pendiente).
  `Bar::Pulso`/`Barra#caja_activa` exponen la caja pendiente para que gestión la vea; las ventas
  siguen enganchándose solo a `caja_abierta`. Frontend: `CajaSheet.vue` (una pantalla, acción según
  rol+estado) reachable desde el **chip de `BarNav`** en cualquier vista del bar (así el dispensador
  la opera desde Vender/Stock, sin ver el Panel). El chip refleja el estado (Sin caja / Falta
  confirmar / Caja abierta / Cierre pendiente).
- **B6 · Eventos por fases:** el `<select>` de estado se reemplazó por un **stepper**
  (`EventoStepper.vue`: planificado → en venta → en curso → cerrado, con cancelar fuera del carril).
  Backend: guard de transiciones (`EventoBar.transiciones_desde`, validación `transicion_valida`) —
  un evento terminal (finalizado/cancelado) **no se reabre**; el detalle expone `transiciones`. Alta
  de evento pasó a **modal mínimo** (nombre/fecha/aforo/ingresos estimados); el resto se completa
  dentro. Specs: `caja_confirmacion_spec` y `evento_bar_fases_spec` (71 ejemplos del bar en verde).
- **Pendiente del rediseño del Salón:** B3 (Vender lista+buscador) y B4 (Resumen liviano) siguen
  sin hacer. Idea de diseño sin cerrar: un campo `horario` en el evento (requiere migración) —
  el modal de alta hoy no lo pide.

## Julio 2026 (c) — capa de sede, salón inteligente, regalo, limpieza

- **Contexto de sede (UI):** store `sede` + selector en el `AdminTopBar` (gated `multi_sede`) —
  al marcar una sede actual, los módulos de-sede se re-filtran. Cableado en Depósito de insumos
  y en el dashboard de Contabilidad (sincronizado en ambos sentidos).
- **Insumos por sede:** cada insumo vive en una sede (`sede_id`, nullable = pool del club);
  **transferencia entre sedes** (origen baja stock, destino recibe valorizado al promedio del
  origen y recalcula el suyo; crea el insumo si no existe). La compra desde Nuevo Movimiento
  elige sede (default la actual).
- **Salón — panel inteligente (`Bar::Pulso`):** resultado del mes + margen + tendencia,
  ventas por hora, top con margen, "Lecturas del salón" (estrella, agotado que se vendía,
  margen bajo, tendencia), reponer con medidores. Rediseño de `BarPanelView` (acento cobre).
- **Salón — caja de turno:** apertura con fondo inicial y **cierre con arqueo** (efectivo
  contado vs esperado → diferencia). Modelo `CajaTurno`; ventas se enganchan por `caja_turno_id`.
- **Dispensación — regalo:** checkbox "es un regalo" (no cobra, no toca cuenta corriente; el
  stock igual se descuenta; queda trazado). Short-circuit al flujo legacy con `medio_pago='regalo'`.
- **Sedes — capa financiera (MVP):** `Sedes::ResumenFinanciero` — resultado del mes + tendencia
  y capital inmovilizado (stock + insumos valorizados) por sede + consolidado, en el cockpit.
- **Limpieza:** removido el subsistema muerto de inventario de sede (`SedeInventario`/
  `InventarioMovimiento`, tablas ya dropeadas, endpoints sin rutear) y el `ManicuradorDashboard`
  legacy (form roto contra `agregar_stock`; el manicura ya usa `/mnc` + pesaje).
- **Auth cross-site:** verificado que ya está resuelto en código (SPA same-origin desde Rails,
  cookie `jwt_token` first-party). Sin cambios; solo restaba confirmar config de Render.

## Julio 2026 (b) — endurecimiento para escala + pulido de manicura

- **TEN-01b (jobs):** los 16 jobs con datos de club ahora fijan el tenant
  (`ActsAsTenant.with_tenant(club)`) — defensa en profundidad completa en la capa de jobs
  (`jwt_denylist_cleanup` y `push_notification` exentos por ser tenant-agnósticos).
- **Reservas:** cerrado el gate de backend — el dispensador solo `index/show/entregar`; crear/
  editar/cancelar/anular seña = admin/supervisor (espeja el front).
- **Informes:** "plantas por estado" en Producción ya se computa (no venía en 0);
  `dispensaciones_sobre_limite` → `dispensaciones_sin_reprocann` (label honesto).
- **Manicura:** aviso "¿seguir la anterior / empezar una nueva / cancelar?" al pesar con una
  jornada enviada sin confirmar; botón verde + cancelar seguro; se sacó "Nuevo pesaje" (jornada
  vacía redundante); hint "faltan N de M plantas".
- **PlantaDetail:** reconectadas las acciones **Medición (Bluelab BLE, EC/pH)** y **Trasplante**
  (los modales existían pero ningún botón los abría — regresión).
- **Lint:** limpieza de deuda en las vistas tocadas.

## Julio 2026 — seguridad clínica, backups, KPIs de stock, candado de manicura

- **Seguridad AZ (historia clínica):** `pacientes#show/#index` filtraban la historia clínica
  (anamnesis, diagnósticos, evolución, alergias, medicación…) a roles no clínicos (dispensador).
  Se pasó a **allowlist** de campos + `authorize`; `PacientePolicy` decide por rol
  (`ROLES_CLINICA = admin/medico/supervisor`). super_admin y dispensador bloqueados por rol.
- **Backups Postgres → R2:** rake `backup:create/list/prune/restore` + cron diario en
  `render.yaml` + `docs/backups.md`. Retención 30 días.
- **Stock (KPIs):** "Flor seca disponible" usa disponible **real** (resta reservas); nuevo KPI
  "Reservado (flor)"; "flor propia" → "Derivados". Stock bajo y gramos = solo flor seca.
- **Dispensaciones:** edición **multi-ítem** (cantidad + precio por línea) con reconciliación de
  stock/cc; precio manual por ítem (admin/sup); historial desplegable por ítem.
- **Contabilidad:** compras **en cuotas** (medio de pago "En cuotas" en Nuevo movimiento →
  genera N egresos mensuales, backdateable). Se saca "cheque".
- **Manicura (provisorio):** solo el **manicura asignado** registra el peso de un lote asignado
  (el "guardar" del detalle iba por `plants#update`, dejando el peso suelto → ahora va por el
  pesaje). El admin ya no pisa el peso de un lote asignado.
- **Reservas:** la fecha de entrega debe ser **a partir de mañana**.
- **UX admin:** widget de ambiente por sala, KPIs de plantas post-cosecha / cosecha lista,
  semáforo de días por fase, tipo de genética en /lotes, tabs del perfil (primarias + "Más"),
  botón PDF en informes del auditor.
- **Guía de usuarios:** nuevo `docs/GUIA_USUARIOS.md` (+ PDF) con roles y flujos.

## Limpieza del flujo de manicura (web) + estado fantasma `manicura_pendiente` eliminado (2026-06-30)

Relevamiento del flujo del rol **manicura** en la versión web (no PWA) y limpieza integral.

- **`manicura_pendiente` eliminado de toda la base**: era un sub-estado de aprobación que ya
  **nunca se asignaba** (la aprobación vive en `PesajeManicura` enviado→confirmado; el lote sigue
  `en_manicura` hasta pasar a `curado`). Se sacó de `Lote::ESTADOS`/`POST_COSECHA`/`progreso_ciclo`,
  scopes y labels de `lotes_controller`, `lote_serializer` (`puede_aprobar_manicura`, sin
  consumidores), `lote_policy`, `pesada`, `registrar_trasplante`, y de ~13 mapas de display del
  frontend. Verificado: 0 filas con ese estado en DB.
- **Autorización unificada**: `pesajes_manicura#create` ahora exige que el manicura esté **asignado**
  al lote (o que el lote no tenga manicurador), igual que `plants#registrar_peso`. Antes cualquier
  manicura podía pesar cualquier lote `en_manicura`. + 2 specs.
- **Bug funcional corregido**: en `PlantaDetailView`, `canManicura` gateaba sobre `manicura_pendiente`
  (nunca verdadero) → el manicura nunca podía actuar desde la ficha de planta. Ahora `en_manicura`.
- **Badge admin "aprobaciones pendientes"** (`useNavContext`): consultaba `manicura_pendiente`
  (siempre 0). Ahora cuenta los pesajes **enviados** reales.
- **Inventario en web para manicura**: nueva ruta `/mnc/stocks` + ítem "Inventario" en el sidebar
  (`StocksManicuraView` ya existía pero estaba huérfana).
- **Routing legacy**: `/manicura` redirige a `/mnc/pendientes` (antes a una pantalla admin-only);
  `App.vue` (nav link + ROLE_PRIORITY) repuntados.
- **Salas**: se retiró `manicura` del alta de salas (`ModalCrearSala`) — las salas son solo de
  cultivo; la manicura se trabaja por estado del lote, no en una sala. El kind sigue válido en el
  backend para salas existentes (mismo criterio que `cosecha`).
- rspec backend verde · vitest 58/58 · `vite build` OK.

## Entregar reserva = crear dispensación (unificado con el modal y el flujo de cobros) (2026-06-24)

Entregar una reserva ahora reusa el modal de **nueva dispensación** (modo "entregar reserva") y el
**motor de cobros** — antes usaba un modal aparte y el camino viejo de cobro (medio único, sin pago
partido ni contra-entrega).

- **Backend**: el motor de cobros (`cobros_param`, `aplicar_lineas_cobro!`, `afinar_medio_pago!`,
  `acreditar_excedente!`) se movió al concern `DispensacionesFinancieras` para compartirlo.
  `reservas#entregar` ahora cobra el **resto** (total − seña) con ese motor: soporta efectivo,
  transferencia, cuenta corriente, **contra-entrega** y excedente a favor. Mantiene el link de la
  reserva, marca entregada y libera el stock apartado.
- **Frontend**: `ModalNuevaDispensacion` acepta una prop `reserva` → modo "entregar reserva":
  producto/cantidad de la reserva (solo lectura), banner "Seña $X · A cobrar $resto", y el medio
  de pago del resto. `ReservasView` y la tab de dispensaciones del socio abren ese modal (en vez
  de `ModalEntregarReserva`).
- Specs de reservas actualizados al flujo de cobros (incl. contra-entrega y parcial a cuenta).
  Suite backend 775 verde.

## Caja del delivery: efectivo en tránsito + recepción (2026-06-24)

El efectivo que cobra el delivery en las entregas queda "en tránsito": NO se asienta como ingreso
hasta que el admin recibe la caja. Da control de faltantes.

- `cobros.rendido` (default true) + `rendido_at`. El efectivo de entrega se crea `rendido: false`
  y `RegistrarCobro` **no** crea su asiento (lo difiere). Transferencia y cuenta corriente se
  asientan al entregar como siempre.
- `Dispensaciones::RecibirCajaDelivery`: al recibir la caja, asienta el ingreso de cada cobro
  efectivo pendiente y lo marca rendido.
- `GET /usuarios/:id/stats` incluye `caja_delivery` (efectivo en mano, cobros pendientes, en viaje).
- `POST /usuarios/:id/recibir_caja` (admin).
- UsuarioDetail (admin → equipo → delivery): card "Caja del delivery" con efectivo en mano +
  botón "Recibir caja".
- Spec: efectivo no asentado hasta recibir; al recibir se crea el movimiento y se marca rendido.

## Cobros: pagos múltiples / parciales / contra-entrega por dispensa (2026-06-24)

Rediseño completo del cobro de dispensaciones. Una dispensa ahora puede cobrarse con varios medios
(efectivo + transferencia), parcialmente, o dejar el resto en cuenta corriente; y el delivery puede
cobrar al entregar (con foto de comprobante de transferencia).

**Modelo / contabilidad**
- Tabla `cobros` (medio, monto, pagado, contexto, comprobante ActiveStorage) + `dispensaciones.cobrar_en_entrega`.
- `Cobro` + `Dispensacion#saldo_pendiente` / `total_cobrado` / `monto_sin_cobrar` / `usa_cobros?`.
- `Dispensaciones::RegistrarCobro` (service): única fuente de verdad. Registra una línea, valida
  bloqueos y arma la contabilidad (asiento + débito de cuenta corriente) en una transacción.

**Reglas (bloquea cuando corresponde)**
- Lo que no se paga en efectivo/transferencia → cuenta corriente (acotado por el cupo del socio).
- Cuenta corriente exige cuenta activa y cupo suficiente; si no, se bloquea (rollback total).
- **Sobrepago permitido**: si el socio paga de más (transfirió de más, le pagó de más al delivery),
  el excedente se acredita a favor en su cuenta corriente (reusa el asiento `aporte_socio`). Solo se
  bloquea si no tiene cuenta corriente donde acreditarlo. El delivery no es quien lo determina.
- Contra-entrega: al crear no se asienta nada; el delivery cobra al entregar.
- Las dispensas legacy (sin cobros) quedan saldadas y no entran al flujo nuevo.
- Editar el monto de una dispensa con cobros se bloquea (cancelar y rehacer); cancelar revierte
  cobros + cuenta corriente.

**Backfill**: las dispensaciones existentes se espejaron a `cobros` (sin re-ejecutar contabilidad).

**Frontend**
- Dispensar (`DispensarView`): composer de cobro (efectivo + transferencia, resto a cuenta) + toggle
  "cobra el delivery"; se distribuye por ítem del carrito.
- Entrega (`DeliveryDashboard`): muestra "a cobrar", inputs de efectivo/transferencia, resto a cuenta,
  y subida de foto de comprobante; entrega vía multipart.

Tests: service (6) + flujos create/entrega/cancelación (4) + suite backend completa (**770**) verde;
vitest **58** verde.

## Contabilidad / cuenta corriente: 2 fixes de UI (2026-06-24)

- **"Recupero dispensación"** ahora muestra el selector de paciente (opcional) en Contabilidad,
  para atribuir el ingreso a un socio. No toca la cuenta corriente (saldar deuda sigue siendo
  "Registrar cobro" en la ficha del socio).
- **Cuenta corriente**: tipografía uniformada con Contabilidad — se sacó el `monospace` ("máquina
  de escribir"); números con `tabular-nums` y el valor grande igual al KPI de Contabilidad.

## Fix REAL: QR de planta se colgaba cargando (endpoint autenticado) (2026-06-23)

La causa de fondo de por qué **lote andaba y planta no**: `LoteQrView` usa `getLotePorQR` →
`api.get('/lotes/por_qr/...')` (instancia **api autenticada**, mismo baseURL/cookie/CORS que todo
lo demás). `PlantaQrView`, en cambio, hacía `auth.ensureBootstrapped()` (podía colgarse en
cold-start) + un `axios.get` **crudo cross-origin** al endpoint público raíz `/p/...`. En
producción el front y la API están en hosts onrender distintos, así que ese fetch quedaba colgado
(CORS / cross-site) → pantalla trabada en "cargando".

- **Nuevo endpoint autenticado** `GET /api/plants/por_qr/:codigo_qr` (`plants#por_qr`), scoped al
  club, espejo de `lotes#por_qr`. Devuelve `id`, `estado` y `lote.estado`.
- `PlantaQrView` ahora resuelve con `getPlantaPorQR` (instancia `api`), **sin** `ensureBootstrapped`
  ni axios crudo — exactamente el patrón de `LoteQrView`. El nombre/logo del club salen del store.
- Spec con aislamiento de tenant (no expone plantas de otro club).

## QR de planta: comportamiento por rol × estado (2026-06-23)

Al escanear el QR de una planta, el destino ahora depende del rol y de la fase de la planta:

| Rol | Planta pre-cosecha | Planta cosechada+ | Lote en manicura/secado |
|---|---|---|---|
| **admin / supervisor** | → detalle | → detalle | → detalle |
| **cultivador** | → detalle | tarjeta "Planta cosechada — sin permisos" | tarjeta "sin permisos" |
| **manicura** | tarjeta "Aún no en manicura" | tarjeta según fase | **→ pesaje por QR** |
| **otros** | detalle si tiene permiso `plantas:show`; si no, "sin permisos" | | |

**Causa del bug que quedaba en blanco**: `PlantaQrView` llamaba a `getPlant()` (instancia `api`)
para todos antes de decidir. En el navegador del celular sin cookie cross-site, el 401 disparaba
el interceptor (→ `/login`) a la vez que el `catch` redirigía al detalle: dos navegaciones en
carrera = pantalla en blanco. Ahora la decisión se toma **solo con la data pública** (sin llamada
autenticada previa) y la navegación es una sola.

- Backend: `GET /p/:codigo_qr` ahora incluye `lote.estado` (additivo) para poder decidir sin
  segunda llamada.
- `getPlant()` se llama únicamente en el flujo de pesaje de manicura (que ya está dentro de la
  ventana en_manicura/secado).
- Nuevos estados de tarjeta: `mensaje` (cosechada/sin permisos/aún no en manicura) reutilizando el
  estilo existente.

## Delivery: entrega secuencial por orden de ruta (2026-06-23)

El delivery solo puede cerrar (entregar / reportar problema) el despacho que es la **siguiente
parada en camino** de su ruta. No puede saltear: si la 1ra y 2da siguen abiertas, no puede tocar
la 3ra. Recién al cerrar una parada (entregada **o** fallida — un problema cuenta como resuelto:
llegó al lugar y no pudo entregar) se habilita la siguiente.

- **Backend (autoritativo)**: `Dispensacion.siguiente_de_ruta` / `siguiente_en_ruta?` calculan la
  primera parada `en_viaje` por `orden_entrega` dentro del grupo de ruta (mismo `ruta_entrega_id`,
  o despachos sueltos del delivery si no hay ruta). `dispensaciones_controller#entregar` y
  `#reportar_fallo` devuelven **422** si no es la siguiente. El **admin queda exento** (puede
  corregir fuera de orden).
- **Frontend**: en "En camino", solo la primera parada (orden de ruta) muestra los botones
  Entregado/Problema y el chip "▶ Siguiente"; las demás quedan atenuadas con candado
  ("Cerrá primero la parada anterior").
- Specs: saltear → 422; cerrar en orden habilita la siguiente; fallido habilita la siguiente;
  admin puede saltear. (7 ejemplos verdes.)

## Fix: el delivery (en PWA) veía la vista admin de despachos (2026-06-23)

`MOBILE_HOME.delivery` apuntaba a `/m/delivery/despachos`, que renderizaba `DespachoListView`
(la vista de **admin**: KPIs, reasignar/cancelar, despachos de todos los repartidores) en lugar
del `DeliveryDashboard` del propio repartidor. Por eso el delivery en la PWA no veía ninguna de
las mejoras (firma, "siguiente", botón verde, Llamar/Ir) — estaban en su dashboard, que nunca
se mostraba. Ahora `/m/delivery/despachos` y `/m/delivery/historial` renderizan `DeliveryDashboard`.

## Delivery: firma, "siguiente", touch targets, acciones por parada (2026-06-23)

- **Fix de la firma de entrega**: el canvas tenía resolución interna fija (400×120) distinta del tamaño mostrado → en mobile la firma quedaba corrida/escalada. Ahora se ajusta al tamaño real (× devicePixelRatio) y el trazo mapea 1:1 con el dedo; canvas más alto (150px) para firmar cómodo.
- **"Siguiente"**: la primera entrega pendiente se resalta (borde verde + chip "▶ Siguiente").
- **Touch targets mobile**: botones más grandes (≥46px), texto de nombre/dirección más legible.
- Botón "Ruta en Maps" en **paleta verde** (outline).
- Cada parada suma **"Llamar"** (tel:) e **"Ir"** (Maps a esa única dirección) — para usar stop por stop.

## Fix: el delivery no podía marcar entregado (422 + 500 latente) (2026-06-23)

Dos bugs encadenados en `PATCH /dispensaciones/:id/entregar`:
- **422**: `delivery_fields_presentes` (exige dirección/contacto de envío) corría en **cada** save, no solo al crear → al re-guardar para marcar entregado, un despacho con algún campo de envío vacío rompía. Ahora la validación es `on: :create`.
- **500 latente** (lo tapaba el 422): `NotificacionDeliveryService` hacía `dispensacion.club`, pero `Dispensacion` no tiene esa asociación (el club va por `sede`). Corregido a `dispensacion.sede&.club`.
- Spec `despacho_entregar_spec` (entrega normal + despacho con campo de envío vacío).

## Delivery: reordenar su ruta + ruta en Google Maps (2026-06-23)

- **El repartidor puede reordenar sus entregas** (flechas ↑↓ en su dashboard) **solo si el club NO fijó el orden** (ruta no bloqueada). Backend: `rutas_entrega#ordenar` ahora permite al delivery ordenar su propia ruta no bloqueada (sigue bloqueado para staff-only el candado). Specs nuevos.
- **Botón "Ruta en Maps"**: arma la ruta en Google Maps (directions, modo conducción) con las direcciones **de los despachos seleccionados** (o todos los pendientes en orden si no hay selección). En la vista admin se agregaron **checkboxes** a los pendientes (en modo ruta) para elegir cuáles mandar a Maps; el dashboard del repartidor ya tenía selección.
- Ícono "con envío" del historial y de la lista del paciente: **camión** (consistente con despachos).

## Guard de cambio de rol (2026-06-23)

El cambio de rol queda permitido (el historial se atribuye por FK al usuario, no al rol, así que persiste), con dos resguardos:
- **Backend (`club_users#update`)**: bloquea cambiar el rol de un **delivery con despachos pendientes/en viaje** hasta reasignarlos (error con el número). Spec `cambio_rol_guard_spec`.
- **Frontend (`UsuariosView`)**: al cambiar el rol pide confirmación ("los permisos cambian de inmediato, el historial se conserva, revisá asignaciones").

## Ajustes UI: despachos, historial, equipo (2026-06-23)

- **Despachos**: la ruta solo reordena **pendientes** (la hoja de ruta se arma con esos); hint para descubrir la ruta cuando no hay repartidor filtrado; acciones de cada despacho agrupadas en **Etiqueta · Acciones ▾ (completar/fallo/reprogramar/reasignar) · Cancelar**.
- **Historial**: el ícono de "con envío" volvió a **camión** (lucide `Truck`), consistente con despachos.
- **Equipo**: la fila del usuario es clickeable → va al detalle; se quitó el ícono "ver perfil".

## Ruta de entrega: orden + candado (2026-06-23)

El admin puede fijar el orden en que el repartidor entrega los despachos y bloquearlo.
- **Backend**: migración `20260623000001` — tabla `rutas_entrega` (delivery+fecha+`bloqueada`, una por repartidor/día) + `ruta_entrega_id`/`orden_entrega` en `dispensaciones`. Modelo `RutaEntrega`. Controller `RutasEntregaController` (`#show`, `#ordenar`, `#bloqueo`). El serializer expone `orden_entrega`/`ruta_bloqueada`; `mis_paquetes` ordena por `orden_entrega`. Specs (`rutas_entrega_spec`: ordenar, bloquear, aislamiento de tenant, permisos).
- **Admin (`DespachoListView`)**: al filtrar por repartidor aparece la barra de ruta con **selector de fecha** (hoy o futura), flechas ↑↓ por despacho y toggle "Respetar orden" (candado). La ruta se trae/guarda por (repartidor, fecha elegida).
- **Delivery (`DeliveryDashboard`)**: los paquetes vienen en el orden de la ruta, con número visible; si está bloqueada, banner "orden fijado por el club".

## Fix: etiqueta de despacho en PWA + sin QR (2026-06-23)

- Tocar "Etiqueta" en PWA rebotaba a la home mobile: el guard de PWA no permitía la ruta. Se permiten las rutas que terminan en `/etiqueta` y el link abre in-app (sin `target="_blank"`, que rompe en PWA standalone).
- La etiqueta de despacho quedó **sin QR** (decisión de seguridad): club, destinatario, dirección, teléfono y código de paquete. Imprimible + descargable como PDF (`html2pdf.js`).

## Etiqueta de despacho con QR + dos direcciones del paciente (2026-06-22)

### Etiqueta de despacho (sin QR — decisión de seguridad)
- Vista nueva `EtiquetaDespachoView` en `/despachos/:id/etiqueta`: logo+nombre del club, **destinatario**, dirección de entrega, teléfono y **código de paquete**. **Sin QR**: un QR a la app interna en cada paquete que va a la calle era superficie de ataque innecesaria (exponía el login). Imprimible + **descargable como PDF** (`html2pdf.js`, igual que el carnet).
- `DespachoListView`: botón "Etiqueta" por despacho (abre en pestaña nueva).
- Redise UI: bordes de KPIs/inputs más visibles; "Dispensadas desde" y "Hasta" agrupadas en una fila alineada.

### Dos direcciones del paciente
- Migración `20260622000003`: `envio_*` (calle/altura/piso/depto/barrio/ciudad) en `pacientes` = dirección de entrega opcional.
- Domicilio del paciente ahora **requerido** (calle) en alta y edición; entrega **opcional** (sección desplegable "Dirección de entrega distinta").
- `Paciente#direccion_entrega`: usa la de envío si está cargada, si no el domicilio. Al dispensar/reservar con envío, el snapshot sale de ahí (`dispensaciones_controller`, `reservas_controller`).

## Fixes UI varios (2026-06-22)

- **/salas**: editar/eliminar desde las cards (grid) redirigía a dashboard. Los botones estaban dentro del `RouterLink` con `@click.stop` pero sin `.prevent` → el ancla navegaba igual. Ahora `@click.stop.prevent`.
- **/historial**: las dispensaciones con envío mostraban un badge celeste poco legible (ícono Truck chico). Ahora ícono de moto (`bi-scooter`) más grande y centrado.
- **Forms de paciente**: el campo de domicilio existía en crear y editar pero con rótulos distintos (en editar parecía "solo entrega"). Unificados: "Domicilio del paciente · se usa también para entregas". Es **un solo** domicilio que sirve de dirección y de entrega por defecto (no hay dos direcciones separadas).
- Doc nuevo: `docs/DOMINIO-SETUP.md` (pasos para el dominio propio).

## Andamiaje para dominio propio (inerte hasta setear ENV) (2026-06-22)

Preparación para mañana (dominio cultivoespacial.com). Todo inerte: sin las ENV nuevas, el comportamiento es idéntico al actual.
- **`lib/cable.js`** (frontend): helper único `cableUrl()` que deriva la URL del WebSocket del origen actual cuando `VITE_API_URL` es relativa (`/api`) — así el cable sigue al dominio que sirve la app. Reemplaza las 3 copias en composables.
- **`jwt_cookie_middleware.rb`** + **`sessions_controller#destroy`**: `COOKIE_DOMAIN` opcional (set y delete usan el mismo domain). Solo necesario si alguna vez se separan front/API en subdominios distintos.
- **`cors.rb`**: orígenes parametrizados por `FRONTEND_URL` + `EXTRA_CORS_ORIGINS` (lista por comas). Agregar dominio = setear ENV, sin tocar código.
- Recordatorio: el build ya usa `VITE_API_URL=/api` (relativo) y Rails sirve la SPA same-origin → al apuntar el dominio al mismo web service, todo (login/logout/cable/cookie) sigue al dominio solo.

## Fixes: detalle de planta (500) + aplicar plan (404) (2026-06-22)

- **500 en `GET /plants/:id`**: `serialize_plant_detail` accedía a `plant.lote.sala.id` sin nil-check; los lotes finalizados quedan sin sala (`sala_id: nil`) → reventaba. Ahora es nil-safe (igual que el serializer de lista). Spec `plant_show_sin_sala_spec.rb`.
- **404 "Plan no encontrado" al aplicar un plan a un lote**: `aplicar_plan`/`preview_plan` exigen `.publicados`, pero el modal listaba plantillas en cualquier estado (incluido borrador). Ahora `LoteAplicarPlanModal` lista solo planes **publicados**, con empty-state que explica que hay que publicarlo. Además `PlanTrabajoView` suma botón **"Publicar"** para borradores (antes solo se podía publicar al crear).

## Fix: editar estado del lote no refrescaba plantas ni historial (2026-06-22)

Al editar un lote por el modal (cambiar estado esqueje→vegetativo + fecha) el historial no se actualizaba sola (había que refrescar) y el listado de plantas quedaba con el estado viejo.
- **Backend (`lotes_controller#update`)**: si la edición cambia el `estado`, ahora propaga el nuevo estado a las plantas (mismo criterio que la máquina de estados: `FASE_A_PLANT_STATE`, sin tocar descartadas/cosechadas). Antes el update directo no las tocaba.
- **Frontend (`LoteDetailView`)**: `@saved` del modal ahora refresca lote + historial (`loadEventos`) + plantas (`plants.fetchByLote`) + gráficos. Antes solo refrescaba el lote.
- **Frontend (`stores/lotes.js`)**: `fetchOne` ahora sincroniza el lote en `items` / `itemsBySala`, así la lista `/lotes` (y la de la sala) no quedan con el estado viejo tras editar (antes `fetchOne` solo tocaba `current`).

## Fix: redirect post-login desde QR (2026-06-22)

Al escanear un QR (ej. de stock, `/s/:codigo_qr`) sin sesión, el login redirigía a inicio en vez de volver a la página del QR. **Causa**: el interceptor 401 de axios (`api.js`) hacía `window.location.href = '/login'` sin preservar la ruta, pisando el `?redirect=` que el router sí armaba — y el 401 del bootstrap (`/me`) lo disparaba siempre.
- **`api.js`**: el 401 del bootstrap (`/me`) ya no fuerza redirect (lo maneja `router.beforeEach`, que preserva la ruta). Otros 401 mandan a `/login?redirect=<ruta+query>`.
- **`stores/auth.js`**: `login()` respeta el `redirect` para **todos** los roles (antes lo ignoraba para super_admin/auditor/medico/abogado/delivery). Si el rol no tiene permiso, `beforeEach` lo reencauza a su home.

## Stock: cantidad inicial + listados enriquecidos (2026-06-22)

- **`stocks.cantidad_inicial`** (migración `20260622000002`): "lo que entró" vs cantidad actual. Se setea en `before_create` (externo/derivado nacen con su cantidad) y se acumula en `PesajeManicura#confirmar!` (manicura nace en 0). Backfill = suma de movimientos `produccion` o `cantidad`. Expuesto en `serialize_stock`.
- **`/stock` (dispensador)**: columna "Ingresó" (fecha), N° de producto y chip Propio/Externo bajo el producto, e "Inicial" como subtexto de Disponible (`420g · de 500g`). Info secundaria oculta en mobile.
- **`/admin/stock`** (tab Inventario): reescrito de cards a **tabla real** (Tipo · Cepa · Lote · Sede · Ingresó · Total cosechado · Actual) con **paginado y filtros server-side** (tipo / sede / rango de fecha) vía nuevo endpoint `GET /stocks/inventario` (`{ stocks, meta, totales }`). Los KPIs del header respetan el filtro activo. Spec `stocks_inventario_spec.rb` (paginado, filtros, aislamiento de tenant).

## Unificación del flujo de manicura (2026-06-22)

Se eliminó la convivencia de tres caminos para "manicura → stock" (pesajes nuevo, batch legacy, aprobación legacy) que colisionaban y producían el error de "asignar sede al confirmar". Ahora hay **un solo flujo**: `PesajeManicura` (borrador → enviado → confirmado).

### Backend
- **Modelo `Lote`**: eliminados `aprobar_manicura!`, `rechazar_manicura!`, `aprobar_y_finalizar!`, `completar_manicura_directa!` y el callback `push_manicura_pendiente`. El estado `manicura_pendiente` deja de usarse (queda en el enum por compatibilidad).
- **`PesajeManicura`**: `peso_calculado_g`/`plantas_registradas_count` soportan carga manual (sin QR) vía `peso_total_g`/`plantas_count`; nuevo `cargar_manual!`; `enviar!` dispara push al admin (reemplaza el push viejo a `/aprobaciones`).
- **`plants#registrar_peso`**: solo flujo `PesajeManicura` (se quitó la rama legacy de `Pesada` borrador); auto-transición `secado → en_manicura` al primer pesaje.
- **`pesajes_manicura#create`**: acepta carga manual (`plantas_count` + `peso_total_g` + `enviar`).
- **`lotes_controller`**: `transiciones` ya no carga manicura (422 si `manicurado`); retiradas las acciones `aprobar_manicura`, `rechazar_manicura`, `completar_manicura`, `finalizar_pesaje_manicura` y sus rutas. `LotePolicy`: scope de manicura = `secado` + `en_manicura` propios.
- **`Club`**: agregado `has_many :stocks` (faltaba; `PesajeManicura#confirmar!` lo usaba).
- **Migración `20260622000001`**: reconvierte lotes `manicura_pendiente` en vuelo al flujo nuevo (genera `PesajeManicura` enviado y los devuelve a `en_manicura`).

### Frontend
- `MncPesajesView`: botón **"Cerrar pesaje y mandar a confirmar"** (antes "Cerrar día y enviar"); copy "jornada/día" → "pesaje".
- `MncLoteDetailView` + `CompletarManicuraModal`: la carga por lote (sin QR) crea un `PesajeManicura` y lo manda a confirmar (sin sede; la sede se asigna en Stock).
- Alerta de Home y mobile admin repuntadas a `/admin/pesajes-manicura`; `/aprobaciones` y `/manicura` ahora redirigen ahí. Vista `AdminAprobacionesView` eliminada; ítem "Manicura" del sidebar con hint.
- API: eliminadas `aprobarManicura`, `rechazarManicura`, `completarManicura`, `finalizarPesajeManicura`.

### Tests
- 730 backend verde (nuevos specs de flujo unificado en `lote_machine_spec` y `pesajes_manicura_flujo_spec`; `dsfix7` reescrito al scope nuevo). 58 frontend verde.

---

## Housekeeping pre-IoT (2026-04-30, sesión 4)

### Deuda técnica eliminada
- **`Socio` + `SociosController` eliminados**: `Socio` mapeaba a tabla `socios` inexistente — model y controller muertos borrados. Rutas `/socios` ya apuntaban a `PacientesController` (sin cambio en comportamiento)
- **`SocioNota` eliminado**: alias redundante de `PacienteNota` usando la misma tabla `paciente_notas`
- **`SocioNotum` eliminado**: modelo zombie generado por Rails al singularizar mal `SocioNotas`
- **Tabla `socio_nota` droppeada**: migración `20260430000001_drop_socio_nota` — tabla huérfana sin controller ni UI

### Tests Bloque H (24 nuevos, 292 total)
- `spec/requests/cuenta_corrientes_spec.rb` — GET show, POST cargar, POST ajuste, auth 403, cross-club 404
- `spec/models/dispensacion_debitar_cc_spec.rb` — debita CC, crea movimiento, referencia dispensacion, saldo anterior/nuevo, created_by, no-op con aporte=0, no-op sin CC, transaccionalidad (rollback si movimiento falla)
- Nuevas factories: `stocks`, `cuenta_corrientes`

---

## Bloque H — Contabilidad: H4 integración CC + H5 PDF P&L (2026-04-30, sesión 3)

### H4 — Integración automática dispensación → CuentaCorriente
- `Dispensacion`: `after_create :debitar_cuenta_corriente`
  - Si `aporte_socio_ars > 0` y el paciente tiene CC: decrementa `saldo_disponible` y crea `CuentaCorrienteMovimiento` con `tipo:'debito'`, `dispensacion:self`, `created_by: user`
  - Opera dentro de la misma transacción que el `create` — rollback automático si falla
  - El `credito_suficiente` (validate on: :create) ya bloqueaba dispensaciones sin saldo; el after_create cierra el ciclo con el débito efectivo

### H5 — PDF del P&L de producción
- `ContabilidadView`: botón "Exportar PDF" en la barra de sub-tabs del P&L
  - Lazy import de `html2pdf.js` (sin impacto en bundle inicial)
  - Genera PDF en A4 landscape con escala 2x de la vista activa (Por lote o Por cepa)
  - Nombre de archivo automático: `PL_produccion_[subtab]_[fecha].pdf`
  - Spinner durante generación, botón deshabilitado mientras procesa

---

## Ola DS-FIX-9 — Admin hamburger responsive (2026-04-30)
- AdminTopBar: botón hamburguesa (`<Menu>`) oculto en desktop, visible en ≤1023px
- App.vue: `adminDrawerOpen` ref + Teleport drawer overlay con `AdminSidebar` reutilizada
- App.vue: fix bottom nav — excluye todos los roles con sidebar+drawer (admin, manicura, médico, abogado, auditor)
- AdminTopBar emite `toggle-drawer`, App.vue cierra el drawer en cambio de ruta

## Ola DS-FIX-8 — Design System cleanup (2026-04-30)
- Eliminada ruta `/manicura` del admin (ahora redirige a `/aprobaciones`)
- Tokens CSS unificados: `--c-role-*` = background canónico de cada sidebar (12 roles)
- `UsuariosView`: badges de rol consumen tokens via `roleStyle()` / `roleColor()` — sin colores hardcodeados
- Todos los sidebars actualizados a `var(--c-role-X)` (AdminSidebar, CultivadorSidebar, DispensadorSidebar, ManicuraSidebar, MedicoSidebar, AbogadoSidebar, AuditorSidebar, SuperAdminLayout)

## Ola DS-FIX-7 — Flujo aprobación manicura (2026-04-29)
- Estado `manicura_pendiente`: manicura registra pesada → queda pendiente de aprobación admin
- Vistas manicura: `MncPendientesView` (registrar pesada de secado) + `MncEsperaView` (solo lectura)
- Vista admin: `AdminAprobacionesView` (aprobar/rechazar con motivo) + `AdminCuradoView` (wizard 2 pasos: pesada curado + ingreso a stock)
- Backend: acciones `aprobar_manicura` / `rechazar_manicura` en LotesController
- Super admin sidebar: `var(--c-role-superadmin)` = `#1A1F36`
- 268 tests RSpec

## Ola DS-FIX-6 — Roles externos (2026-04-28)
- Layouts completos con sidebar + topbar + drawer para: médico, abogado, auditor
- Vistas: `MedicoLayout`, `AbogadoLayout`, `AuditorLayout` con rutas protegidas
- Backend: lockdown por rol en todos los controllers

## Ola DS-FIX-1 a DS-FIX-5 — Design System Ola 1 (2026-04-27)
- AdminSidebar dark con tokens `--c-role-admin`
- AdminTopBar con breadcrumb dinámico, notificaciones, avatar dropdown
- Design System primitivos: Avatar, Dropdown, EmptyState, Stat, Card, Badge, Banner, Button, Spinner
- App.vue bifurcado por rol (admin-shell, mnc-shell, dpv-shell, med-shell, abg-shell, aud-shell)
- Mobile: drawer con hamburguesa para dispensador, manicura, médico, abogado, auditor

## Bloque H — Contabilidad: CuentaCorriente + P&L por cepa (2026-04-30, sesión 2)

### H2 — CuentaCorriente de socios
- Backend: `CuentaCorrientesController` — `GET /pacientes/:id/cuenta_corriente`, `POST cargar`, `POST ajuste`
- Rutas anidadas bajo `/pacientes` en routes.rb
- API frontend: `getCuentaCorriente`, `cargarCreditoCC`, `ajustarCC`
- `SocioDetailView`: nuevo tab "Cuenta corriente" (solo admin)
  - Header con saldo disponible y límite de crédito
  - Barra de consumo con colores (verde/ámbar/rojo según porcentaje)
  - Form inline para cargar crédito y ajuste manual (valores +/-)
  - Historial de movimientos con tipo coloreado, monto, saldo resultante

### H3 — P&L por cepa
- `ContabilidadView` tab P&L: sub-tabs "Por lote" | "Por cepa"
- Vista "Por cepa": agrupa `todosLotes` por `genetica_id`, computa promedio/mín/máx de costo/g y gramos totales
- Sin llamadas adicionales al backend (usa datos del `listLotes()` ya cargado)

## Bloque H — Contabilidad: P&L por lote (2026-04-30)
- LoteDetailView: card "Costos de producción" en aside — carga/edita `CostoLote` inline
  - Campos: insumos, energía, mano de obra, prorrateado, gramos producidos
  - Muestra costo total y costo/gramo en tiempo real
- ContabilidadView: nuevo tab "P&L por lote"
  - Lista todos los lotes con costos cargados, ordenados por costo/g asc
  - Columnas: código, cepa, estado, costo total, gramos, $/g
  - Links al detalle del lote
- Backend: `serialize_lote` incluye `costo_total` y `gramos_producidos` + eager load `:costo_lote`
- AdminDashboard: fix endpoint `/inventario/pendiente` (404) → `listLotes({ estado: 'manicura_pendiente' })`
- AdminDashboard: card "Pipeline post-cosecha" (lotes en manicura_pendiente + curado)
- AdminDashboard: card "Stock disponible" agrupado por forma_producto
- AdminDashboard: acciones rápidas contextuales (Aprobaciones + Cerrar curado con badge count)

## Bloque G — Housekeeping (2026-04-28)

### G1 — Logger wrapper
- Created `src/utils/logger.js` — DEV-only wrapper around `console.*`
- Replaced all 50+ `console.log/error/warn/debug` calls across 24 files
- Production builds emit zero console output

### G2 — Dependency audit
- `npm audit fix` — reduced vulnerabilities from 18 to 4 (remaining 4 are build-time only in `vite-plugin-pwa`)
- Applied non-breaking minor/patch updates

### G3 — Test suite
- Added 58 unit tests across 9 test files
- Coverage: EmptyState, Paginator, Breadcrumb, Lightbox, ConfirmDialog, useConfirm, useToast, usePermissions, App
- Fixed `<Teleport to="body">` test pattern — use `document.querySelector()` instead of `w.find()`

### G4 — Docs
- Rewrote `frontend/README.md` (stack, credentials, commands)
- Created `docs/ARCHITECTURE.md` (folder structure, data model, permissions, critical flows, bundle breakdown)
- Created `docs/CHANGELOG.md` (this file)
- Created `docs/ROADMAP.md` (blocks H–K)

### G5 — Bundle optimization
- Added `manualChunks` in `vite.config.js`: vue, charts, qr split into separate chunks
- Converted `html2pdf.js` to lazy dynamic import in `InformeSemestralView`
- Main chunk: 1,948 kB → 676 kB (gzip: 575 kB → 187 kB)

### G6 — Security
- Verified: CORS restricted, HttpOnly cookies, `authenticate_user!` on all controllers
- Verified: no secrets committed, `.env*.local` in `.gitignore`
- 4 remaining audit warnings are build-time only (vite-plugin-pwa rollup deps)

### G7 — Dead code removal
- Deleted 6 unreferenced components: `BaseModal.vue`, `SalaModal.vue`, `ImpersonationBanner.vue`, `AgricultorDashboard.vue`, `PlantsByGeneticaChart.vue`, `UsuarioSedesManager.vue`
- No remaining TODO/FIXME markers

---

## Bloque F — UX polish (2026-04)

- Replaced all `alert()` with `useToast` / `useConfirm`
- Renamed `/socios` → `/pacientes` (canonical) with `/socios` alias for backward-compat
- Breadcrumb chains: added Sede segment via backend serializer (`includes(sala: :sede)`)
- Lightbox component added to photo galleries (LoteDetailView, PlantaDetailView)
- Paginator component replaces "Ver más" incremental pattern
- useToast / useConfirm wired into 4 detail views

---

## Bloque E — Roles & permissions (2026-04)

- `usePermissions` composable with full role matrix
- Backend `permissions.rb` concern mirrors frontend checks
- `PlanEnforcer` service enforces plan-level limits

---

## Bloque D — Salas & Lotes (2026-04)

- SalaDetailView, LoteDetailView, PlantaDetailView with full CRUD
- GraficosLote component (Chart.js)
- Sala → Cultivador assignment (SalaCultivadoresManager)

---

## Bloque C — Socios & Dispensaciones (2026-04)

- SocioDetailView, SocioNuevoView
- Dispensaciones component with limits display
- IndicacionesMedicas, PacienteDocumentos sub-components

---

## Bloque B — Auth & multi-tenant (2026-04)

- Devise Token Auth integration
- Auth store (Pinia), router guards
- Role-based dashboard routing (DashboardView)

---

## Bloque A — Foundation (2026-04)

- Vue 3 + Vite + Pinia + Vue Router scaffold
- Bootstrap 5 base layout
- Docker Compose full-stack setup
