# Changelog

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
