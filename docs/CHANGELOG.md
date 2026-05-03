# Changelog

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
