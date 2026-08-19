# Architecture — Cultivo Espacial

## Overview

Multi-tenant B2B SaaS. Each `Club` is an isolated tenant. Users belong to a club and have a single role that determines what they can see and do.

## Repository structure

```
club-cultivo/
├── backend/                  # Rails 7.2 API (JSON-only)
│   ├── app/
│   │   ├── controllers/      # thin — delegate to services
│   │   ├── models/           # AR models + concerns/permissions.rb
│   │   ├── services/         # PlanEnforcer, business logic
│   │   └── serializers/      # manual hash serializers (no gem)
│   ├── db/migrate/
│   └── spec/                 # RSpec + FactoryBot
└── frontend/                 # Vue 3 SPA
    └── src/
        ├── components/
        │   ├── charts/       # Chart.js wrappers
        │   ├── dashboards/   # per-role dashboard components
        │   ├── plants/       # plant-related sub-components
        │   ├── salas/        # sala sub-components
        │   ├── socios/       # socio sub-components
        │   └── ui/           # Breadcrumb, ConfirmDialog, EmptyState,
        │                     # Lightbox, Paginator, ToastContainer
        ├── composables/      # useConfirm, usePermissions, useQRCode,
        │                     # usePlan, useToast
        ├── lib/              # api.js — Axios instance + all API calls
        ├── router/           # Vue Router (lazy-loaded views)
        ├── stores/           # Pinia: auth, contabilidad, lotes, plants,
        │                     # salas, socios
        ├── utils/            # dates.js, logger.js
        └── views/            # one file per route
```

## Data model (simplified)

```
Club
 ├── User (role: admin | cultivador | manicurador | dispensador |
 │          medico | abogado | auditor | socio | super_admin)
 ├── Sede (physical location)
 │    └── Sala (grow room)
 │         ├── Lote (crop batch, links to Genetica)
 │         │    └── Planta (individual plant)
 │         └── SalaCultivador (join: user ↔ sala)
 ├── Socio (club member, links to User)
 │    ├── Dispensacion
 │    └── CuentaCorriente → CuentaCorrienteMovimiento
 └── SedeInventario → InventarioMovimiento
```

## Permissions

All permission checks live in two places:

- **Backend**: `app/models/concerns/permissions.rb` — `can?(resource, action)` on `User`
- **Frontend**: `src/composables/usePermissions.js` — `can(resource, action)` composable, mirrors backend logic

Role matrix (condensed):

| Resource | admin | cultivador | manicurador | dispensador | medico | socio |
|---|---|---|---|---|---|---|
| socios (CRUD) | ✓ | - | - | r | r | - |
| plantas/lotes | ✓ | ✓ | - | - | - | - |
| salas | ✓ | ✓ | - | - | - | - |
| dispensaciones | ✓ | - | - | ✓ | - | r (own) |
| manicura | ✓ | - | ✓ | - | - | - |
| sede_inventario | ✓ | - | r | - | - | - |
| mi_perfil | all | | | | | |

## Critical flows

### Login
`LoginView` → POST `/users/sign_in` → Devise token → stored in `auth` store (localStorage) → router guard checks `auth.isAuthenticated` before each navigation.

### Dispensacion
`SocioDetailView` → `Dispensaciones` component → POST `/socios/:id/dispensaciones` → `PlanEnforcer` checks plan limits → creates `Dispensacion` + `InventarioMovimiento` + `CuentaCorrienteMovimiento`.

### Cosecha / post-cosecha
`LoteDetailView` → `cambiarCiclo()` → PATCH `/lotes/:id` with new `ciclo` value → backend transitions state, updates `SedeInventario` stock on harvest.

### PDF export
`InformeSemestralView` → click → **lazy imports** `html2pdf.js` (975 kB, not in initial bundle) → generates PDF from DOM.

## Auth & security

- Devise Token Auth (cookie-based, `HttpOnly`, `SameSite=Strict`)
- `authenticate_user!` in `ApplicationController` — all controllers inherit it
- CORS: restricted to known origins in `config/initializers/cors.rb`
- No secrets in repository — `.env*.local` in `.gitignore`

## Bundle chunks (production)

| Chunk | Gzip |
|---|---|
| index (app code) | ~187 kB |
| vendor-vue (Vue + Router + Pinia) | ~42 kB |
| vendor-charts (Chart.js) | ~50 kB |
| vendor-qr (qrcode) | ~10 kB |
| html2pdf (lazy, PDF export only) | ~281 kB |
| per-route views | 1–10 kB each |
