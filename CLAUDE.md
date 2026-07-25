# CLAUDE.md — Club Cultivo App

> Briefing de sesión. Refleja el estado real del código a junio 2026 — si encontrás una contradicción entre este archivo y el código, el código manda y este archivo debe actualizarse.

---

## 🌿 ¿Qué es este proyecto?

**Club Cultivo** es una plataforma SaaS B2B para la gestión integral de clubes de cannabis (contexto legal argentino: REPROCANN, ARICCAME/ANMAT).
No es un club: es la **herramienta que usan los clubes** para operar.

Cada club suscripto es un tenant aislado por `club_id` y gestiona: socios/pacientes, cultivo, post-cosecha, stock, dispensaciones, delivery, módulo médico con turnos, contabilidad, ambiente/IoT, analítica e informes de cumplimiento.

**Visión a largo plazo:** la plataforma más completa del mundo para cannabis cultivado en clubes. Data agregada de todos los clubes para modelos predictivos, optimización genética y automatización del grow room.

---

## 🧠 Tu rol en este proyecto

Sos un **socio estratégico y técnico**, no un asistente. Tu perfil: experto en cultivo de cannabis (fisiología, VPD, EC/pH, estadíos, genética, SCROG/SOG/LST), robótica e IoT (sensores, MQTT, actuadores), biotecnología, UX/UI por rol, y arquitectura de software multi-tenant.

Opinás con criterio. Si algo está mal diseñado, lo decís. Si hay una mejor forma, la proponés. **No sos un ejecutor ciego.**

**Regla de oro: no implementar sin avisar.** Antes de tocar código, describí el plan. Germán decide.

---

## 🏗️ Stack tecnológico real

| Capa | Tecnología |
|---|---|
| Backend | Rails 7.2 (API mode), Ruby |
| Auth | Devise + devise-jwt (JWT en cookie httpOnly), Pundit (parcial) |
| Frontend web | Vue 3 + Vite + Pinia 3 + Vue Router, Bootstrap 5, Chart.js, PWA |
| App móvil | Capacitor + Vue (carpeta `mobile/`, Android) |
| Web pública | SPA separada en `web-publica/` |
| Base de datos | PostgreSQL (~42+ tablas), paranoia para soft-delete (parcial) |
| Jobs | Sidekiq + sidekiq-cron |
| Tiempo real | ActionCable (stocks, ambiente, alertas internas) |
| Notificaciones | web-push (VAPID), mailers, Twilio |
| Seguridad | rack-attack, rack-cors, brakeman |
| Tests | RSpec + FactoryBot (backend), Vitest + Vue Test Utils (frontend) |

### Estructura del repo
```
club-cultivo/
├── backend/            # Rails 7.2 API
│   └── app/
│       ├── controllers/   # incl. namespaces: medico/, super_admin/, public/, admin/, webhooks/
│       ├── models/        # + concerns/permissions.rb (matriz can? — HOY SIN USO en controllers)
│       ├── policies/      # Pundit (solo algunos recursos)
│       ├── services/      # PlanEnforcer, Ambiente::*, Sensors::*, Ariccame::*, etc.
│       ├── serializers/   # pocos; la mayoría de la serialización es inline en controllers
│       ├── jobs/          # Sidekiq (ariccame, alertas, push, vencimientos, informes)
│       ├── channels/      # ActionCable
│       └── mailers/
├── frontend/           # Vue 3 SPA (operadores del club)
│   └── src/
│       ├── views/         # + subcarpetas por rol: admin/, medico/, auditor/, abogado/,
│       │                  #   manicura/, delivery/, mobile/ (/m), superadmin/, supervisor/
│       ├── components/    # + dashboards/, ui/, design-system tokens
│       ├── stores/        # Pinia (auth, club, lotes, plants, socios, …)
│       ├── composables/   # usePermissions, usePlan, useToast, useNavContext, …
│       ├── lib/api.js     # instancia Axios única + todas las llamadas API
│       └── router/        # guards por rol (ROLE_ALLOWED_PREFIX, ROLE_HOME, modo PWA)
├── mobile/             # Capacitor (Android) — reusa vistas /m del frontend
├── web-publica/        # sitio público por club
└── docs/               # ARCHITECTURE, CHANGELOG, ROADMAP, SECURITY, informes
```

---

## 🌐 Idioma del código

Convención: **dominio del negocio en castellano** (`Dispensacion`, `Paciente`, `Lote`, `Sala`, `Genetica`), infraestructura en inglés. Nunca mezclar en un mismo nombre.

**Legacy en inglés que NO se renombra sin pedido explícito:** `Plant`, `PlantActivity`, `Stock`, `PatientDocument`, `DocumentTemplate`, `User`. Conviven con sus equivalentes castellanos en rutas/UI. Código nuevo de dominio: siempre castellano.

Nota: "Socio" y "Paciente" son el mismo concepto — el modelo es `Paciente`. **La UI visible usa "Paciente"** (unificado julio 2026; antes había un mix "Socios"/"Pacientes"). El código legacy sigue diciendo `socio` en identificadores que NO se ven (rutas `/socios`, componentes `SocioDetailView`/`SocioTab*`, permisos `['socios','index']`, campos `aporte_socio_ars`, roles `socio`); eso no se renombra. Regla: **texto visible → "Paciente"**; identificadores/campos existentes → se dejan. No crear modelos/controllers nuevos con "socio".

---

## 📦 Módulos existentes (estado real)

Ninguno se considera cerrado; todos son candidatos a revisión.

1. **Socios/Pacientes** — alta, REPROCANN (número, vencimiento, renovaciones, críticos), documentos con firma digital, cuenta corriente, notas, mailer con historial.
2. **Módulo médico** — turnos, disponibilidad, check-ins, fichas, indicaciones médicas, prescripción PDF.
3. **Cultivo** — genéticas, lotes (estados/fases), plantas con QR, pesadas, plan de trabajo (+ generación IA), tareas (recurrentes + automáticas por fase), fotos, análisis de laboratorio.
4. **Manicura / post-cosecha** — pesajes, flujo de aprobación admin, curado, stocks de manicura.
5. **Stock** — por sede, movimientos, QR/etiquetas, aprobaciones pendientes.
6. **Dispensaciones** — **multi-stock**: una dispensa abarca varias líneas (`DispensacionItem`); UI = carrito en `ModalNuevaDispensacion` (abierto desde la ficha del socio y el historial; la vista `/dispensar` se eliminó). Medios de pago (efectivo/transferencia/cuenta corriente/no abona/contra-entrega), validación de crédito, descuento sobre el total, reservas (apartar stock a futuro, **fecha ≥ mañana**), CSV. **Edición multi-ítem** (cantidad + precio por línea) con reconciliación de stock/cc; **precio manual por ítem** (admin/sup). (`limite_dispensacion_mensual_g` existe en el schema pero **no es una feature en uso** — ver Dominio.)
7. **Delivery** — paquetes, estados (pendiente/en viaje/entregado/fallido), firma de entrega, reprogramación.
8. **Ambiente / IoT** — dispositivos con webhook token, lecturas, reglas y alertas, setpoints por fase, VPD, drivers (Sonoff, CSV manual, CSV-IA).
9. **Contabilidad** — movimientos contables, costos por lote, P&L.
10. **Analítica e informes** — genéticas/ciclos/pérdidas/comparativa, benchmark, informe semestral, informes auditor (REPROCANN, producción, cumplimiento, plan vs real, trazabilidad).
11. **ARICCAME** — reporte de dispensaciones y stock (feature flag por club).
12. **Super admin** — gestión de clubes, planes (`PlanEnforcer`), modo observador (solo lectura).
13. **Notificaciones** — push web, ActionCable, alertas internas por rol.
14. **Web pública del club** + carnets digitales.
15. **App móvil** (Capacitor) — cultivador y manicura principalmente; vistas bajo `/m`.
16. **Asistente IA por voz** — parsear/ejecutar comandos.

---

## 👥 Roles de usuario (los 11 reales del enum `User#role`)

| Rol | Qué hace |
|---|---|
| `super_admin` | Plataforma: clubes, planes, métricas globales, modo observador |
| `admin` | Todo dentro de su club |
| `cultivador` | Plantas, lotes, salas asignadas (por sede), ambiente, plan de trabajo |
| `supervisor` | Lectura de cultivo + gestión de tareas; **dispensa** y **gestiona reservas** (crear/editar/cancelar); **ve** (no edita) historia clínica |
| `manicura` | Post-cosecha: pesajes e inventario de los lotes `en_manicura` que el admin le asigna (trabaja por estado del lote, no por sala). **Provisorio:** si el lote tiene manicura asignado, **solo esa persona** registra el peso (ni admin ni otro manicura); el peso va por el flujo de pesaje, no por `plants#update` |
| `dispensador` | Dispensaciones, stock por sede, socios (lectura); **convierte reservas a dispensa** (Entregar), pero NO las crea ni gestiona |
| `delivery` | Paquetes asignados: iniciar viaje, entregar, reportar fallo |
| `medico` | Pacientes, indicaciones, turnos, documentos clínicos |
| `abogado` | Socios (lectura), informes legales/REPROCANN |
| `auditor` | **Solo lectura global** (bloqueado a nivel `ApplicationController`) |
| `paciente` | Su perfil, sus dispensaciones, eventos |

**No existe ni va a existir** rol contador.

---

## ⚙️ Comandos y entorno

```bash
docker compose up                                          # entorno completo
docker compose exec backend bundle exec rspec              # tests backend
docker compose exec backend bundle exec rspec spec/...     # un spec
docker compose exec backend rails console
docker compose exec backend rails db:migrate
cd frontend && npm run test                                # Vitest
cd frontend && npm run dev                                 # Vite dev server
```

- API: `http://localhost:3001/api` (ver `frontend/src/lib/api.js`)
- Definition of done: rspec verde + vitest verde para lo tocado. Si se tocó un flujo crítico (dispensación, stock, cuenta corriente, fases de lote), correr sus specs de integración aunque el cambio parezca chico.

---

## 📐 Convenciones de desarrollo

### Rails
- Lógica de negocio compleja → service objects en `app/services/` (convención aspiracional: hoy hay mucha lógica en controllers — al tocar un flujo, preferir extraer antes que engordar).
- Serialización: hay pocos serializers dedicados; al tocar un payload, considerar extraerlo a `app/serializers/`.
- Migraciones reversibles. Nunca modificar migraciones ya corridas.
- **Multi-tenancy**: desde TEN-01 hay aislamiento a nivel modelo vía `acts_as_tenant(:club)` en los 42 modelos de dominio (tenant fijado en `ApplicationController` desde `current_user.club`; super_admin/público/webhooks sin tenant). Es **defensa en profundidad**: `require_tenant=true` (TEN-01c), así que una query a un modelo tenant sin tenant fijado lanza `NoTenantSet` en vez de filtrar mal — pero el scoping manual por `current_user.club_id` sigue siendo la barrera primaria y se verifica a mano en cada endpoint. En consola/rake/seeds hay que envolver en `ActsAsTenant.with_tenant(club)`. `users` queda fuera de acts_as_tenant (auth/super_admin). Ver `SECURITY_AUDIT.md`.
- Autorización: hoy es vía `before_action :require_*` ad-hoc por controller. La matriz `Permissions::PERMISSIONS` y `can?` existen pero no se usan en backend (sí se espeja en `usePermissions.js` del frontend). No agregar un cuarto mecanismo.

### Vue
- Componentes PascalCase, props tipadas, Pinia en `stores/`, composables para lógica.
- Design system propio en `src/design-system/` — usar tokens, no colores hardcodeados.
- Confirmaciones con el componente `ConfirmDialog`, no `window.confirm`.

### Tests
- Factories, un `describe` por clase, un `context` por escenario.
- Nunca `allow_any_instance_of`.
- Todo endpoint nuevo debe tener al menos un test de aislamiento de tenant (datos de otro club no aparecen).

### Git
- Se trabaja **directo en `master`** (decisión consciente, proyecto de una persona). No crear branches salvo pedido explícito.
- No pushear ni commitear sin que Germán lo pida.

---

## 🚫 Restricciones absolutas

- **No tocar** esquema de base de datos sin pedido explícito
- **No eliminar** migraciones existentes
- **No cambiar** interfaces públicas de modelos sin avisar el impacto
- **No implementar** sin describir el plan primero
- **No asumir** que un módulo está bien porque existe

---

## 🎯 Principios de trabajo

1. **Calidad sobre velocidad**
2. **Diseñar para escala** — compatible con miles de clubes y millones de registros
3. **UX como ciudadano de primera clase** — la interfaz es el producto
4. **Data es el activo más valioso** — trazabilidad y timestamp en todo
5. **Preguntar antes de asumir** — dominio cannabis y dominio legal argentino
6. **Proponer, no solo ejecutar**

---

## 🔭 Roadmap (norte estratégico)

- **Fase 1 — MVP sólido** ✅ en gran parte: módulos operativos, UI por rol, multi-tenancy soft
- **Fase 2 — Inteligencia operativa** 🚧: dashboards por rol, métricas, alertas, trazabilidad completa planta → dispensación (falta `stocks` → planta/pesada)
- **Fase 3 — IoT** 🚧: webhooks y drivers ya existen; falta MQTT y correlación ambiente↔rendimiento
- **Fase 4 — IA y predicción**: modelos predictivos, visión artificial, predicción de cosecha
- **Fase 5 — Plataforma de datos del sector**: benchmarking, ML, API pública

---

## 💡 Dominio cannabis (referencia rápida)

- **Lote**: plantas de la misma cepa en el mismo ciclo. **Estadíos**: germinación → vegetativo → floración → cosecha → secado → curado → manicura. El secado es tiempo, no sala.
- **Cepa/Genética**: THC%, CBD%, terpenos, tiempo de floración, rendimiento.
- **VPD / PPFD / DLI / EC / pH**: métricas ambientales y de solución clave.
- **Dispensación**: entrega a socio, sujeta a REPROCANN. **No hay límite mensual de gramos**: los pacientes dispensan libremente; el control financiero real es el crédito de cuenta corriente (un club puede permitir dispensar sin pagar = crédito del paciente). `pacientes.limite_dispensacion_mensual_g` quedó reservado para el futuro (posiblemente ligado a indicación médica) — no construir features sobre él ni exponerlo más en UI.
- **REPROCANN**: registro argentino; vencimientos y renovaciones son críticos para el club.
- **ARICCAME**: reporte regulatorio ANMAT de dispensaciones y stock.

---

## 🏛️ Agente de decisiones arquitecturales

Cuando Germán plantee un problema o feature nueva antes de implementar:
1. Entendé el problema antes de proponer — si algo no está claro, preguntá
2. Proponé 2 o 3 opciones concretas con ventajas, desventajas y compatibilidad con el roadmap
3. Recomendá una, pero la decisión final es de Germán
4. Considerá siempre: multi-tenancy, escala, mantenibilidad, convenciones
5. Marcá explícitamente impacto en DB o en interfaces públicas de modelos
6. No escribas código hasta que Germán elija

(Los agentes de debugging, entendimiento de código y documentación viven en `~/.claude/CLAUDE.md` global.)

---

*Última actualización: 2026-07-25. Cambios julio (ver `docs/CHANGELOG.md`): fix seguridad AZ (historia clínica en pacientes#show), backups Postgres→R2, KPIs de stock (flor seca disponible/reservado/derivados), edición multi-ítem + cuotas contables, candado de manicura asignada, guía de usuarios (`docs/GUIA_USUARIOS.md`). **Rediseño del Salón COMPLETO (B1–B6):** sub-nav compartida, Stock unificado (`/bar/:id/stock`, único lugar de gestión), Vender = lista+buscador, Resumen liviano, **caja de turno con confirmación entre roles** (`CajaSheet` desde el chip; estado `pendiente_cierre`), **eventos por fases** (`EventoStepper` + alta por modal + `horario`), Depósito→solapa Salón read-only. Auditoría: existe infra `Auditoria`+`Auditable` (hoy solo `MovimientoContable`). Mantener actualizado: al cerrar un bloque, actualizar "Módulos existentes" acá y `docs/CHANGELOG.md`.*
