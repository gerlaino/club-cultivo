# Changelog

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
