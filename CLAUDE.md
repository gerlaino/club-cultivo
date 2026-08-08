# CLAUDE.md — Club Cultivo App

> Briefing de sesión. Refleja el estado real del código a junio 2026 — si encontrás una contradicción entre este archivo y el código, el código manda y este archivo debe actualizarse.

---

## 🌿 ¿Qué es este proyecto?

**Club Cultivo** es una plataforma SaaS B2B para la gestión integral de clubes de cannabis (contexto legal argentino: REPROCANN, ARICCAME).

> **Quién es quién, que se confundía en el código:** **REPROCANN** es el registro del programa de cannabis, lo emite el **Ministerio de Salud de la Nación** y habilita el cultivo para uso medicinal. **ARICCAME** es la agencia que regula la industria (Ley 27.669). **ANMAT** regula medicamentos y no interviene en ninguno de los dos: decir "REPROCANN de ANMAT" es un error.
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
11. **ARICCAME** — reporte de dispensaciones y stock (feature flag por club). La transmisión está SIMULADA: no envía nada de verdad.
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
- **REPROCANN**: registro del Ministerio de Salud de la Nación que habilita el cultivo para uso medicinal. Vencimientos y renovaciones son críticos para el club.
- **ARICCAME**: agencia que regula la industria del cannabis (Ley 27.669). El reporte de dispensaciones y stock está SIMULADO: no se transmite nada.

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

**Cierre jul-27 (b) — inventario unificado, últimos bloques.** Regla de oro que ordena todo esto: **lo trazable (`Stock`: propio, derivados y externo) sale del inventario SOLO por dispensación; el salón vende productos del bar e insumos.** Nada de dos puertas de salida para el mismo ítem.
1. **Stock apartable en eventos (F3b):** `Stock` es provisionable y **siempre se APARTA** — bloquea la cantidad (`Stock#apartado_para_eventos` → entra en `gramos_reservados`/`cantidad_disponible_real`), no descuenta. Es *la misma mecánica que una reserva de paciente, con otro destinatario*. **Reserva parcial** (antes todo-o-nada) con `advertencias`. **El apartado se salda en tres destinos:** (a) **dispensado** — durante el evento `en_curso` el dispensador tilda "dispensar desde lo reservado", la línea guarda `dispensacion_items.evento_bar_id` y se imputa a la provisión (libera el bloqueo, sin doble descuento; sin tildar sale del stock libre); (b) **consumo interno** — lo consumido sin dispensar se declara al cerrar, descuenta con `StockMovimiento` tipo `consumo_evento` y **es el único COGS del evento** (lo dispensado ya tiene costo e ingreso en la dispensación); (c) **liberado** — el resto vuelve al pozo.
2. **POS multi-depósito (F4):** `bar_venta_items.vendible_type/id` (migración `add_vendible_a_bar_venta_items`) → el mostrador vende producto del bar **+ insumo**, cada línea descontando de su depósito; precio a mano solo admin/supervisor (un insumo no tiene precio propio). **Ningún `Stock` se vende por el POS.** `Bar::ItemVendible` centraliza el dispatch por tipo (lo usan POS, provisión de eventos y la reversión de venta). Endpoint `GET /bares/:id/vendibles`.
3. **Cierre de período (F5) ya existía** — se le agregó el guard `hasta < hoy` (cerrar el día en curso dejaba al mostrador sin poder cobrar, porque todo asiento automático nace con fecha de hoy) y mensaje claro en vez de 500.

Suite 1239 ✓ + 58 vitest ✓. **Deploy: sumar `add_vendible_a_bar_venta_items` y `add_consumo_evento_a_provisiones_y_dispensas` al `db:migrate`.**

## 📍 Dónde retomar (7-ago-2026, cierre b)

**1682 rspec + 313 vitest en verde.** Sin commitear (Germán no lo pidió).

**Antes de tocar producción:**
```
db:migrate      # add_leaf_temp_offset_a_salas, add_pulse_api_key_a_clubs, y las de julio
bundle install  # gema nueva pdf-inspector (sólo test)
rake suites:prender_iot_con_dispositivos      # ⚠️ JUNTO CON EL DEPLOY, ver abajo
rake lotes:corregir_finalizados_con_stock     # lotes cerrados que aún tienen producto
rake geneticas:declarar_por_nombre SIMULAR=1  # las que ya traen "- TROPICANA WFC" en el nombre
rake geneticas:sin_declarar                   # (informativo) qué falta declarar ante el INASE
```

> Las migraciones nuevas de esta tanda: `add_fallido_at_a_dispensaciones` y
> `add_declarada_como_a_geneticas`.

### Declaración ante el INASE (ago-08)

Un club cultiva variedades no inscriptas y las **declara** contra una que sí lo está:
`geneticas.declarada_como_id` apunta al catálogo GLOBAL de inscriptas (club_id NULL), que ya
existía. Es opcional. `Genetica#nombre_declarado` / `#numero_inase_declarado` /
`#acreditada_inase?` son la interfaz.

**Regla: el nombre declarado se usa SÓLO en informes regulatorios** (INASE, trazabilidad,
semestral). Las pantallas internas siguen mostrando el nombre real — el cultivador no
reconoce sus lotes por el nombre del registro.

**El guard (`DeclaracionInaseGuard`) bloquea la DESCARGA, nunca la pantalla.** El informe INASE
en pantalla es el que lista los pendientes: bloquearlo dejaría al club sin poder ver su propio
problema. PDF/Excel de INASE, trazabilidad y semestral devuelven 422 con la lista.

> ⚠️ **El rake de IoT no es opcional.** La ingesta de lecturas ahora exige el add-on `iot`, y
> ese add-on NUNCA existió como bandera vieja: ninguna migración lo escribe, así que hoy
> ningún club lo tiene salvo que lo hayan tildado a mano. Sin correr el rake, todo club con
> hardware deja de recibir datos EN SILENCIO (el sensor postea, le contestan 403). El rake
> prende `iot` a quien ya tenga dispositivos cargados; es idempotente y acepta `SIMULAR=1`.

### Bloque "módulo apagado" (#36, #37, #39) — cerrado

La misma pregunta vista de tres lados: qué pasa cuando un club apaga un módulo.

- **#37 Jobs.** Ninguno de los 13 miraba las suites: un club que apagaba un módulo seguía
  recibiendo sus alertas, y `ReprocannVencimientoJob` le manda mail **al paciente**, no al
  club. Ahora se recorre con `ApplicationJob#cada_club_con(:suite)`, que resuelve club
  operativo + suite + tenant + rescue. `AlertaDetectorService` es mixto y filtra adentro
  (4 detectores de cultivo / saldo de CC). La ingesta IoT se corta en el webhook.
- **Tercera capa, que no estaba anotada:** `Club.activos` es `where(deleted_at: nil)` y **un
  club suspendido lo pasaba** — o sea que hasta los 8 jobs que parecían correctos procesaban
  clubes que dejaron de pagar. Scope nuevo `Club.operativos` (ni eliminado ni suspendido).
- **#39 Rol huérfano.** `User::MODULOS_POR_ROL`: un cultivador sin suite Cultivo entraba y
  recibía 403 en todo, sin saber por qué. Ahora lo frena el login con el módulo nombrado, y
  `check_rol_habilitado!` cubre las sesiones ya abiertas (el interceptor del front lo saca
  con el motivo). `admin`/`super_admin`/`auditor`/`abogado` nunca se bloquean. **El
  dispensador requiere `produccion_dispensa` O `bar`**: también atiende el mostrador del
  Buffet, y hay clubes con sólo Buffet.
- **#36 Informes.** No hay informes persistidos: no existe modelo ni tabla, cada apertura los
  recalcula sobre datos vivos. Así que "leer el histórico" es gratis y se deja **sin gating**
  (un club que se dio de baja puede necesitar mostrarle papeles a un auditor); lo que se
  apaga es la **emisión automática**, o sea `InformeSemestralJob`, el único que se manda solo.

**Delivery (pedido de Germán):** el logout pasó del fondo del sidebar —que se esconde en
mobile, y el delivery trabaja siempre desde el celular— al menú de usuario de la topbar, como
el resto de los roles. Las tres listas del dashboard se pliegan, con contador, y la elección
se recuerda; los fallidos arrancan cerrados (no puede hacer nada con ellos).

**Bug preexistente encontrado de paso:** `Dispositivo has_many :lecturas_ambientales` sin
`class_name` → Rails buscaba `LecturasAmbientale`. Borrar un sensor tiraba 500.

### El ciclo del lote (ago-08)

**`finalizado` significa una sola cosa: no queda nada del lote — ni flor ni derivados.** La regla
vive en `Lote#stock_remanente` y la hacen cumplir dos cosas que antes no existían juntas: la
validación `finalizado_exige_stock_agotado` y `finalizar_si_stock_agotado!`. Datos del caso:

- Un lote **no cerraba al dispensarse**: `decrement!(:cantidad)` no cambia el estado del stock y
  el callback escucha el cambio de estado. Ahora la dispensación llama a
  `Stock#marcar_agotado_si_vacio!`.
- **El evento de cierre necesita autor** (`lote_eventos.user_id` es NOT NULL) y nace en un callback
  sin `current_user`: el autor viaja en `Stock#usuario_movimiento`. Si algún llamador nuevo no lo
  informa, se avisa en el log y NO se cierra — no se rompe la transacción que lo llamó.
- Al **elaborar un derivado**, el origen se marca agotado al final de la transacción: si se marcara
  antes, el lote cerraría un instante antes de que el hash exista.
- `LoteEvento#user` pasó a `optional: true` (la columna sigue NOT NULL: para eventos realmente sin
  autor haría falta una migración, no hecha).

**Pendientes que quedan (ago-08):** todo lo que estaba en manos del asistente se cerró — ver
el CHANGELOG (j). Queda del lado de Germán: correr los rakes en prod, declarar a mano las
genéticas sin sufijo, pasar los `numero_registro_inase`, y las decisiones de modelo de precios
y medición de IA. Del lado técnico queda el REDISEÑO VISUAL del modal de nuevo movimiento (no
acordado) y seguir #40 por las superficies que faltan (el super admin ya está).

*(histórico)* **#38** auditoría de utilidad de los 8+ informes y **#40** barrido de design system — que no es un barrido: son 268 `.vue` con
~11.800 hexadecimales, hay que acotarlo a una superficie. Más las decisiones de Germán:
modelo de precios y medición de calls de IA.

### La lección que no hay que repetir

**Un build que pasa no prueba que la pantalla funcione.** En esta sesión escribí el HTML de un
modal con clases CSS que nunca creé: compiló perfecto y Germán lo siguió viendo roto. Y al
gatear las suites verifiqué que el candado estuviera puesto, no que TODAS las puertas lo
tuvieran — hay 23 componentes de navegación y sólo 3 miraban las features.

**Si tocás una pantalla, verificala renderizada.**

---

*Historial hasta 2026-07-28. Cambios julio (ver `docs/CHANGELOG.md`): **etiquetas QR en tanda y en PDF** (`lib/pdfEtiquetas.js` es fuente única; lote 93×60mm 3/fila en A4 apaisada, banderita de planta 160×26mm plegable; jsPDF lazy — dep nueva `jspdf`). Fix seguridad AZ (historia clínica en pacientes#show), backups Postgres→R2, KPIs de stock, edición multi-ítem + cuotas contables, candado de manicura asignada, guía de usuarios (`docs/GUIA_USUARIOS.md`). **Rediseño del Salón COMPLETO (B1–B6):** sub-nav compartida, Stock unificado, Vender = lista+buscador, Resumen liviano, caja de turno con confirmación entre roles, eventos por fases, Depósito→solapa Salón read-only. **Audit log (historial por usuario):** infra `Auditoria`+`Auditable`; Fase 1 (Lote/Plant/Stock/Dispensación) + Fase 2 (Paciente/User/Reserva con allowlist estricto — NUNCA campos encriptados/clínicos) + endpoint + tab en UsuarioDetail. **Código de barras** en productos del bar (lector físico + cámara `@zxing/browser` + scan-to-create). **Comprobante NO fiscal** al cobrar. **Multi-sede: los depósitos son de una SEDE** (`Deposito.sede_id`; `SembrarDepositos` siembra por sede + sede-ifica lo legacy); transferencia entre depósitos; edge case sede-divergente prevenido (el depósito fija la sede del movimiento). **Dashboard área × sede** (`resumen_por_unidad` con desglose por sede). **`vendible`/"no vender"** en mercadería del bar (dispensador solo ve lo vendible; alta desde Nuevo Movimiento; Stock del salón edición-only). **Deploy prod pendiente:** `db:migrate` (incl. `add_sede_a_depositos`, `add_vendible_a_bar_productos`, `add_codigo_barras_a_bar_productos`, caja/horario, `unicidad_depositos_de_sistema` —deduplica y después crea el índice único—) + `npm ci` (deps `@zxing/browser`, `jspdf`). Mantener actualizado: al cerrar un bloque, actualizar "Módulos existentes" acá y `docs/CHANGELOG.md`.*
