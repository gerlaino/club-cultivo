# CLAUDE.md — Cultivo Espacial (repo `club-cultivo`)

> Briefing de sesión. Refleja el estado real del código a agosto 2026 — si encontrás una contradicción entre este archivo y el código, el código manda y este archivo debe actualizarse.

---

## 🌿 ¿Qué es este proyecto?

**Cultivo Espacial** es una plataforma SaaS B2B para la gestión integral de organizaciones de cannabis (contexto legal argentino: REPROCANN, ARICCAME).

> **"Club Cultivo" es el nombre del REPOSITORIO, no del producto.** El producto se llama **Cultivo Espacial** y así tiene que aparecer en todo texto visible (mailers, prompt del asistente, encabezados). Se coló en 15 archivos y se corrigió en agosto 2026 — no volver a escribirlo en pantalla.

> **Quién es quién, que se confundía en el código:** **REPROCANN** es el registro del programa de cannabis, lo emite el **Ministerio de Salud de la Nación** y habilita el cultivo para uso medicinal. **ARICCAME** es la agencia que regula la industria (Ley 27.669). **ANMAT** regula medicamentos y no interviene en ninguno de los dos: decir "REPROCANN de ANMAT" es un error.
No es un club: es la **herramienta que usan las organizaciones** para operar — clubes, pero también producción e investigación (por eso el rename de agosto: ver Idioma del código).

Cada organización suscripta es un tenant aislado por `club_id` y gestiona: socios/pacientes, cultivo, post-cosecha, stock, dispensaciones, delivery, módulo médico con turnos, contabilidad, ambiente/IoT, analítica e informes de cumplimiento.

**Visión a largo plazo:** la plataforma más completa del mundo para cannabis cultivado en clubes. Data agregada de todas las organizaciones para modelos predictivos, optimización genética y automatización del grow room.

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
│       │                  #   manicura/, delivery/, mobile/ (/m), superadmin/, supervisor/,
│       │                  #   portal/ (lo que ve el paciente, en /portal)
│       ├── components/    # + dashboards/, ui/, design-system tokens
│       ├── stores/        # Pinia (auth, club, lotes, plants, socios, …)
│       ├── composables/   # usePermissions, usePlan, useToast, useNavContext, …
│       ├── lib/api.js     # instancia Axios única + todas las llamadas API
│       └── router/        # guards por rol (ROLE_ALLOWED_PREFIX, ROLE_HOME, modo PWA)
├── mobile/             # Capacitor (Android) — reusa vistas /m del frontend
└── docs/               # ARCHITECTURE, CHANGELOG, ROADMAP, SECURITY, informes
```

---

## 🌐 Idioma del código

Convención: **dominio del negocio en castellano** (`Dispensacion`, `Paciente`, `Lote`, `Sala`, `Genetica`), infraestructura en inglés. Nunca mezclar en un mismo nombre.

**Legacy en inglés que NO se renombra sin pedido explícito:** `Plant`, `PlantActivity`, `Stock`, `PatientDocument`, `DocumentTemplate`, `User`. Conviven con sus equivalentes castellanos en rutas/UI. Código nuevo de dominio: siempre castellano.

**Club → Organización (agosto 2026), misma regla que Socio → Paciente.** El texto VISIBLE dice "organización" en toda la app (frontend, backend, informes, mailers, PDF). Identificadores, rutas, clases CSS, stores, el modelo `Club`, `club_id` y los comentarios quedan como están. Cuidado con la concordancia al escribir texto nuevo: club es masculino y organización femenino ("toda la organización", "cada organización", plural sin acento: organizaciones).

Nota: "Socio" y "Paciente" son el mismo concepto — el modelo es `Paciente`. **La UI visible usa "Paciente"** (unificado julio 2026; antes había un mix "Socios"/"Pacientes"). El código legacy sigue diciendo `socio` en identificadores que NO se ven (rutas `/socios`, componentes `SocioDetailView`/`SocioTab*`, permisos `['socios','index']`, campos `aporte_socio_ars`, roles `socio`); eso no se renombra. Regla: **texto visible → "Paciente"**; identificadores/campos existentes → se dejan. No crear modelos/controllers nuevos con "socio".

---

## 📦 Módulos existentes (estado real)

Ninguno se considera cerrado; todos son candidatos a revisión.

1. **Socios/Pacientes** — alta, REPROCANN (número, vencimiento, renovaciones, críticos), documentos con firma digital, cuenta corriente, notas, mailer con historial. **El alta desde el mostrador (dispensador/supervisor) queda PENDIENTE de aprobación**: existe y se completa, pero no recibe dispensaciones ni reservas hasta que admin o médico la aprueben. El bloqueo vive en los modelos `Dispensacion` y `Reserva`, no en la UI. Un alta nace **aprobada** salvo que venga del mostrador (al revés, una importación de padrón dejaba a todos sin poder retirar).
2. **Módulo médico** — turnos, disponibilidad, check-ins, fichas, indicaciones médicas, prescripción PDF.
3. **Cultivo** — genéticas, lotes (estados/fases), plantas con QR, pesadas, plan de trabajo (+ generación IA), tareas (recurrentes + automáticas por fase), fotos, análisis de laboratorio.
4. **Manicura / post-cosecha** — pesajes, flujo de aprobación admin, curado, stocks de manicura.
5. **Stock** — por sede, movimientos, QR/etiquetas, aprobaciones pendientes.
6. **Dispensaciones** — **multi-stock**: una dispensa abarca varias líneas (`DispensacionItem`); UI = carrito en `ModalNuevaDispensacion` (abierto desde la ficha del socio y el historial; la vista `/dispensar` se eliminó). Medios de pago (efectivo/transferencia/cuenta corriente/no abona/contra-entrega), validación de crédito, descuento sobre el total, reservas (apartar stock a futuro, **fecha ≥ mañana**), CSV. **Edición multi-ítem** (cantidad + precio por línea) con reconciliación de stock/cc; **precio manual por ítem** (admin/sup). (`limite_dispensacion_mensual_g` existe en el schema pero **no es una feature en uso** — ver Dominio.)
7. **Delivery** — paquetes, estados (pendiente/en viaje/entregado/fallido), firma de entrega, reprogramación. **Es un add-on contratable** (antes era un rol suelto): sin el módulo activo, el rol `delivery` no se ofrece ni se acepta, `rutas_entrega` y las acciones de reparto devuelven 403, y `Dispensacion` rechaza al CREAR una dispensa con envío. **`entregar` y `reportar_fallo` quedan SIN gatear a propósito** — ver "Lo que NO hay que romper".
8. **Ambiente / IoT** — dispositivos con webhook token, lecturas, reglas y alertas, setpoints por fase, VPD, drivers (Sonoff, CSV manual, CSV-IA).
9. **Contabilidad** — movimientos contables, costos por lote, P&L.
10. **Analítica e informes** — genéticas/ciclos/pérdidas/comparativa, benchmark, informe semestral, informes auditor (REPROCANN, producción, cumplimiento, plan vs real, trazabilidad).
11. **ARICCAME** — reporte de dispensaciones y stock (feature flag por club). La transmisión está SIMULADA: no envía nada de verdad.
12. **Super admin** — panel de plataforma como **cola de trabajo** (cada pendiente con su acción, agrupado por urgencia: se está perdiendo plata · paga y no le funciona · avisar con tiempo), organizaciones, **dos planes** (`PlanEnforcer`: básico/total, sólo límites), catálogo de módulos (`GET /super_admin/catalogo`), informes de plataforma, historial por organización. **El modo observador está SUSPENDIDO** (`User::OBSERVADOR_HABILITADO = false`). Un super_admin sin contexto que pega a un endpoint de organización recibe **409 explicando qué falta** (`block_super_admin_sin_contexto!`), no un 500.
13. **Notificaciones** — push web, ActionCable, alertas internas por rol.
14. **Portal del paciente** (`vista_paciente`, **add-on**) + carnets digitales. Cada paciente que se da de alta recibe su **cuenta** (`Pacientes::Acceso`): usuario `nombre.apellido@organizacion.paciente` y contraseña generada por paciente y dictable — nunca una fija, que acá sería fatal porque el usuario se deduce del nombre. La cuenta nace cuando el paciente queda ADMITIDO. **Sin el módulo el paciente no puede ni loguearse** (`User::MODULOS_POR_ROL`), como el repartidor sin Delivery.
    **Son DOS llaves y hacen falta las dos:** el add-on CONTRATADO (lo prende el super admin) y el portal ABIERTO (`clubs.vista_paciente_activa`, el interruptor de la organización en Configuración → Portal del paciente). La regla vive en **`Club#portal_paciente_disponible?`** y la preguntan el login (`User#rol_habilitado?`) y `Portal::BaseController` — cerrado, el paciente no entra ni con la sesión abierta. El interruptor existía desde antes y **no lo leía nadie**: se guardaba, se mostraba y no hacía nada. Toda spec que contrate `vista_paciente` tiene que pasar `vista_paciente_activa: true`.
    **EL INICIO ES EL ESTADO DEL PACIENTE, no el boletín.** En orden: su **credencial** (nombre, DNI, número de socio y el REPROCANN como semáforo; a pantalla completa con QR, porque es lo único del producto que se usa PARADO, en la puerta) · **lo suyo** (próximo turno, indicación vigente, cuenta corriente, último retiro) · **del club** en dos renglones. El boletín —novedades, eventos, catálogo, galería— vive entero en `/portal/del-club`: se movió porque está VACÍO en cualquier organización que no publique, que son casi todas casi todas las semanas, y el estado del paciente no está vacío nunca. **El estado del REPROCANN va DENTRO de la credencial**, no en una franja aparte: es la misma pregunta (¿puede retirar?). `PortalAvisos` se quedó sólo con lo urgente.
    **`/portal/mi-salud`** es lo clínico: turnos e indicación médica. Se arma con **lista blanca campo por campo, NUNCA `as_json`** — `Turno#notas_post` son las notas del médico para el médico y no salen jamás; los campos encriptados de `IndicacionMedica` sí, porque son suyos. **No hay sección Contacto**: eran cuatro datos y un formulario que no mandaba nada, y viven en el pie.
    **El portal tiene su propia capa de tokens**, `design-system/portal.css`: define `--p-*` EN FUNCIÓN de los del DS, y `PortalShell` pisa las de marca con el `theme_primary` de cada organización. `portalTokens.test.js` barre las pantallas y falla ante cualquier hex a mano o `bi-*`: **el baseline es CERO y tiene que quedarse en cero**. Es mobile-first, al revés que el resto de la app.
    **La contraseña le llega por mail** (`PacienteMailer#acceso_portal`, mail FIJO — no plantilla editable). Necesita el módulo `mailer` + casilla conectada + mail del paciente; si falta alguna, la ficha lo dice ANTES de crear la cuenta y la contraseña se muestra en pantalla. **No queda en el historial de correo**: el registro dice que se le mandó el acceso, no cuál es. La cuenta se GESTIONA desde la ficha del paciente (tab "Acceso al portal", admin/médico). El paciente ve su cuenta corriente en `/portal/cuenta-corriente`, y el enlace aparece SÓLO si la organización se la abrió. Ve su usuario y cambia su contraseña en `/portal/cuenta`, DENTRO del portal. Siguen sin login, a propósito, el carnet (`/c/:token`) y el pasaporte de dispensa (`/d/:token`), que son links que la persona entrega. **No hay vitrina pública de un club**: lo público de la plataforma es `/bienvenida`; `web-publica/` se retiró (era un Vite aparte sin sesión cuyo backend resolvía el club con `Club.first`).
15. **App móvil** (Capacitor) — cultivador y manicura principalmente; vistas bajo `/m`.
16. **Asistente IA por voz** — parsear/ejecutar comandos. **Todo el consumo se mide y se cobra**: ver "IA" abajo.
17. **Correo electrónico** — **add-on contratable** (`mailer`, con `require_feature!` real). Pantalla propia en Configuración → Correo: casilla SMTP de la organización + **plantillas que edita su admin** (variables `{{nombre}}` por lista blanca con `gsub`, **nunca ERB**). Bienvenida al alta (admin/médico en el acto; mostrador al aprobar) y **envíos masivos** (`EnvioMasivo` + `EnvioMasivoJob`): **un mail por destinatario, jamás un `To:` múltiple ni BCC** — juntos, cada paciente recibiría el padrón completo (fuga de datos de salud, Ley 25.326). Tope propio de 450/día (`Correo::CupoDiario`), por debajo de los ~500 de Gmail: pasarse **suspende la casilla del cliente**. Se chequea ANTES de crear el envío.

### IA — medición y topes

Toda llamada a la API queda en `ia_llamadas` (organización, persona, función, modelo, tokens y **costo congelado**; también las fallidas). Registran las cinco funciones: asistente parsear/consultar, análisis de lote, plan de trabajo y mapeo de CSV. `Ia::Uso` es la puerta única: `registrar`, `limite_alcanzado`, `resumen_mes`.

- **Manda el tope MENSUAL** (`Club::IA_TIERS[:limite_mes]`: 500 / 2.000 / 10.000 según tier), que se cuenta contra la base y no depende de Redis. El horario es sólo freno de ráfaga, **por organización** (contaba por usuario: cinco personas daban 5× el límite).
- **`club.ia_limite_hora` sobrescribe el horario del tier** cuando es > 0. El mensual **no tiene override**.
- El asistente usa **caché de prompt**: `system` es un array de dos bloques y el fijo lleva `cache_control`. Un byte distinto antes del corte invalida todo. `resumen_mes[:cache_hit]` es el chivato: si queda en 0 con el asistente en uso, algo rompió el prefijo.
- **El consumo se ve** (13-ago): `Ia::Uso.resumen_mes` sale en la ficha del super admin (`ia_uso`, sólo si la organización tiene el add-on) y lo muestra `SAModulos`. Va envuelto en `ActsAsTenant.with_tenant`: el super admin no tiene tenant fijado e `IaLlamada` es tenant con `require_tenant=true`, así que sin eso revienta la ficha entera.
- **El módulo se llama `ia`.** `ia_voz` e `ia_analisis` son las claves VIEJAS y no se chequean más por acción: el candado es un `require_feature!(:ia)` en el controller. `features_expandidas` deriva en los dos sentidos (vieja ⇒ nueva y nueva ⇒ vieja); chequear la vieja con la nueva guardada daba false y dejaba el botón visible y el dictado rechazado.

---

## 👥 Roles de usuario (los 11 reales del enum `User#role`)

| Rol | Qué hace |
|---|---|
| `super_admin` | Plataforma: clubes, planes, métricas globales, modo observador |
| `admin` | Todo dentro de su club |
| `cultivador` | Plantas, lotes, salas asignadas (por sede), ambiente, plan de trabajo |
| `supervisor` | Lectura de cultivo + gestión de tareas; **dispensa** y **gestiona reservas** (crear/editar/cancelar); **ve** (no edita) historia clínica; **crea pacientes** (quedan pendientes de aprobación) |
| `manicura` | Post-cosecha: pesajes e inventario de los lotes `en_manicura` que el admin le asigna (trabaja por estado del lote, no por sala). **Provisorio:** si el lote tiene manicura asignado, **solo esa persona** registra el peso (ni admin ni otro manicura); el peso va por el flujo de pesaje, no por `plants#update` |
| `dispensador` | Dispensaciones, stock por sede, socios (lectura); **convierte reservas a dispensa** (Entregar), pero NO las crea ni gestiona; **crea pacientes** (quedan pendientes de aprobación, y ninguno de los dos aprueba) |
| `delivery` | Paquetes asignados: iniciar viaje, entregar, reportar fallo. **Sólo existe si el add-on Delivery está activo** |
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

## 📍 Dónde retomar (20-ago-2026)

**2395 rspec (0 fallas, 26 pending del observador suspendido) + 1525 vitest + build limpio.**
Los bloques de agosto están en `docs/CHANGELOG.md` hasta "Agosto 2026 (t)".

**Pendiente de documentar:** **sigue sin entrada en el CHANGELOG lo del 17 y 18 de agosto**
—chatbot del admin, medición de IA en créditos, informe INASE, trazabilidad de aplicaciones—, que
son de otras sesiones. Los bloques (s) y (t) cubren todo lo del 19 y el 20.

**PENDIENTE DE INFRAESTRUCTURA, no de código:** `backend/cookies.txt` y `frontend/cookies.txt`
tenían commiteada una cookie de sesión REAL de staging. Se borraron y se ignoran, pero **el valor
sigue en el historial de git y la sesión sigue viva**: hay que rotar el secreto en Render. Y
`rake seguridad:usuarios_con_password_default` encuentra a los usuarios que quedaron con la clave
vieja (`123456Aa`): hay que correrlo y forzarles el cambio.

**El portal del paciente YA SE VENDE** (20-ago): salió de `Club::ADDONS_INCOMPLETOS`. El tablero
que le faltaba —credencial, estado del REPROCANN, turnos, indicación y retiros— está hecho, y lo
único que depende de la organización es cuánto publique, que no es un módulo a medias. El cajón
queda con `bar`, `eventos` y `chatbot`.

**Lo de la idempotencia de la cola quedó CERRADO sin tocar esquema:** la planta es la clave natural
del pesaje (se pesa una sola vez), así que un reintento no puede duplicar; lo que faltaba era que
el backend lo dijera, y ahora contesta `ya_registrado: true`. Ver "Lo que NO hay que romper".

**`rake categorias:aplanar` YA CORRIÓ en producción (15-ago).** No repetir: es idempotente pero
no tiene nada que hacer. El catálogo quedó de un solo nivel.

### La lección de los bloques (q) y (r)

Casi todo lo que apareció probando con alguien que no escribió la app fue **la misma regla
escrita en dos lugares que dejaron de coincidir**. Vale como criterio antes de agregar nada:

- **Si una regla vive en dos lados, ya está mal.** La matriz de rutas por rol contra los guards
  de cada ruta; el estado del lote contra el tipo de sala; el permiso de completar una tarea de
  a una contra en tanda. Cada divergencia se ve como "la pantalla te deja y el backend te
  rechaza", que es el peor error posible: parece culpa del usuario.
- **Un test que repite la lista de memoria no prueba nada.** El de rutas por rol pasaba en verde
  con el login del manicura roto, porque afirmaba la misma lista equivocada que el código.
  Los tests nuevos leen la fuente real (los sidebars, el router, ESLint sobre `src`).
- **Aterrizar en un lugar prohibido no es "un botón que rebota": es no poder entrar.** El guard
  devuelve al origen, el origen vuelve a mandar al mismo lado y Vue Router aborta.
- **`no-undef` corre como test** (`variablesInexistentes.test.js`). Vite compila una variable
  inexistente sin chistar; la pantalla explota al abrirse. Ya pasó tres veces.

### Reglas de dominio que quedaron fijadas

- **PONER EN MACETA ES PRENDER.** Enraizado ⇔ sin maceta, en `Lote#prender_al_ponerlo_en_maceta`,
  cubriendo alta heredada, desprender, trasplante y edición. **No es una validación**: como
  validación volvía inguardable un lote que ya estaba así.
- **El estado del lote y el tipo de sala son la misma verdad.** La tabla vive en
  `Lote::KINDS_SALA_POR_ESTADO` y **viaja al front en `/me`** (`reglas_cultivo`). No volver a
  copiarla.
- **Dónde se midió el ambiente se DERIVA del estado del lote** (`enraizado` ⇒ incubadora).
- **El DNI es único POR ORGANIZACIÓN.** La regla del REPROCANN es del trámite, no de la base.
- **SALIDA ≠ MERMA.** Cerrar un stock pregunta qué pasó; sólo `destruido` es pérdida. La regla de
  oro sigue: por el mostrador, lo trazable sale sólo por dispensación o consumo de evento.

### El módulo contable, como quedó

**SECTOR → CATEGORÍA, un solo nivel.** Cinco sectores fijos (General, Cultivo, Dispensario,
Buffet, Otro) que **no se crean**, y **un depósito por sector y por sede**, según el tipo de sede.
La CATEGORÍA manda el alta: es obligatoria, va primera, y de ella salen el sector y si la compra
entra a un depósito. **Por "Nuevo movimiento" sólo sale plata**: lo que entra tiene su puerta
(cuenta corriente del paciente, dispensación, mostrador) y lo excepcional tiene su formulario de
cinco campos.

### El modelo comercial, que cambió de raíz

**Dos planes, y el plan dice CUÁNTO, nunca QUÉ.** `PlanEnforcer::PLANES` = `basico` / `total`,
con seis límites (sedes, salas, lotes, plantas, pacientes, usuarios). Qué puede hacer una
organización lo deciden las suites, y no se cruzan. Los cuatro planes viejos siguen mapeados en
`PLANES_LEGACY` por si aparece uno guardado.

**Los límites cuentan lo que EXISTE, no lo activo.** Sedes y salas: apagar una no libera cupo
(se creaba, se apagaba y se creaba otra). El `uso` que ve el super admin cuenta igual que el
tope — si contaran distinto, el panel diría "1 de 1" con tres sedes cargadas.

**Los módulos viven en tres cajones** (`Club`): `SUITES` contratables · `INCLUIDOS_EN_SUITE`
(**sólo el médico**; el correo salió a `ADDONS` el 11-ago) · `ADDONS` (incluye ahora **Delivery
y Correo**, y desde el 19-ago **Portal del paciente**) · `EN_CONSTRUCCION` (hoy VACÍO; el cajón queda para el próximo).
**`Club#estado_modulo` es la pieza clave**: prendido ≠ andando, y devuelve `andando` /
`falta_config` / `apagado` con `falta_para_funcionar` explicando qué le falta a ESA organización.

**Dar de baja un módulo NO lo corta en el acto: fija una fecha** —salvo que el super admin pida **"Cortar ahora"** (`corte_inmediato`), que existe para lo que no es una baja comercial: una organización que se va, una prueba, un módulo prendido por error. El período es MENSUAL: la baja cae a fin del mes en curso, y `plan_activo_hasta` es sólo un TECHO (tomarla como fin de período hacía durar la baja año y medio). `features_baja` guarda hasta
cuándo sigue andando (`plan_activo_hasta`, o fin de mes); `feature?` la respeta y devuelve false
apenas pasa, sin esperar al job. `AplicarBajasModulosJob` apaga la bandera **y ordena lo que el
módulo dejaba colgando** — en Delivery suelta los repartos que no salieron y avisa al admin,
pero **lo que está EN VIAJE no se toca**. Toda migración que mueva un módulo de cajón necesita
**backfill**: al ser derivado, `feature?` daba true sin nada escrito, y sin el UPDATE el día del
deploy se quedan todos sin el módulo.

**El catálogo de qué se vende sale de `GET /super_admin/catalogo`.** No volver a duplicar la
lista de módulos en las vistas: ya había tres copias que se contradecían.

### Lo que NO hay que romper

- **El modo observador está SUSPENDIDO** con `User::OBSERVADOR_HABILITADO = false`. Está
  construido (club efectivo, tenant, gating por módulos del club observado, datos clínicos
  bloqueados) pero apagado: los guards de ROL de 26 controllers lo dejarían navegando secciones
  vacías y 403, y el club lo nota. **Reactivarlo exige darle rol efectivo de admin del club
  observado** — enmascarar `User#role`, que toca el enum de auth. Los specs del modo andando se
  saltan solos y vuelven al prender la bandera.
- **`Auditable` fija el tenant sólo cuando no hay ninguno.** Envolver siempre contaminaba
  `Current.current_tenant` entre ejemplos y el spec siguiente heredaba un club revertido.
- **Un mail por destinatario, siempre.** Ni `To:` múltiple ni BCC en ningún envío: con todos
  juntos, cada paciente recibe el padrón completo de la organización. Hay un spec que verifica
  que cada mensaje entregado tenga UNA sola dirección. El texto se resuelve POR destinatario.
- **Las plantillas de correo se interpolan con `gsub` contra lista blanca, NUNCA con ERB.** Es
  texto que escribe un usuario: evaluarlo es ejecución de código en el servidor.
- **El gateo por suite vive en los CONTROLLERS, no en los modelos.** Como validación de modelo
  vuelve inguardable un registro que ya existía cuando se da de baja una suite (no se podría ni
  corregir la dirección de una sede) y rompe los fixtures con features acotadas.
- **El backend valida lo que la UI esconde.** Tareas futuras, roles del alta, aprobación de
  pacientes: si la regla vive sólo en la pantalla, está escondida y no aplicada — por API se
  saltea siempre, y `completar_masivo` hace `update_all`.
- **Cerrar un reparto NO se gatea por módulo.** `entregar` y `reportar_fallo` quedan fuera del
  `require_feature!(:delivery)`: con el módulo apagado el repartidor no puede ni loguearse
  (`check_rol_habilitado!`), así que si el cierre también estuviera bloqueado no quedaría NADIE
  que pudiera registrar cómo terminó un paquete que ya salió — quedan abiertos para siempre.
  Los cierra el admin. Misma lógica que `AplicarBajasModulosJob`, que no toca lo que está en
  viaje. Por eso `Dispensacion#delivery_contratado` es `on: :create`.
- **El portal del paciente necesita DOS llaves: contratado Y abierto.** `Club#portal_paciente_disponible?`
  es el único lugar donde vive, y la preguntan el login y `Portal::BaseController`. El interruptor
  `vista_paciente_activa` existió meses **sin que lo leyera nadie**: se guardaba, se mostraba en
  pantalla y el paciente entraba igual. Toda spec que contrate `vista_paciente` tiene que pasar
  `vista_paciente_activa: true`.
- **Lo clínico del paciente se serializa con LISTA BLANCA campo por campo, nunca `as_json`.**
  `Turno#notas_post` son las notas del médico PARA EL MÉDICO y no salen jamás. Los campos
  encriptados de `IndicacionMedica` sí se le sirven al paciente: son suyos y los pide él. Con
  `as_json`, una columna nueva se filtra sola.
- **SIN SEÑAL NO SE DISPENSA.** Es la única escritura que mueve stock y plata a la vez, y encolarla
  descontaba de una caché local que puede estar vieja: dos dispensadores sin señal entregaban el
  mismo gramo y el sobregiro aparecía al reconectar, con la mercadería ya afuera. Lo que SÍ se
  encola: ambiente, el pesaje del manicura (no genera stock, espera confirmación del admin) y la
  entrega del repartidor (que tiene cola propia: lo que se pierde ahí es la FIRMA). La lista vive
  en `lib/offlineApi.js` y `sinConexion.test.js` la fija.
- **NO HAY CONTRASEÑA POR DEFECTO.** `Club::PASSWORD_DEFAULT` (`123456Aa`, con override por ENV que
  nadie puso) se eliminó el 20-ago: era una credencial fija en código de producción, y el formulario
  del super admin la traía PRECARGADA, así que sabiendo el email de cualquiera se entraba a su club.
  Cada alta genera la suya con `User.password_temporal` —dictable por teléfono— y el endpoint la
  devuelve en claro **a propósito**, porque hay que poder dictarla; la pantalla la muestra una vez.
  El único lugar donde la clave vieja sigue escrita es `rake seguridad:usuarios_con_password_default`,
  que es el que encuentra a los que quedaron con ella: **los usuarios creados ANTES la conservan**.
- **La cola offline NO tiene TTL, y sacarlo fue un arreglo.** Había uno de 48 h "contra entradas
  huérfanas", pero huérfanas no existen: `marcarEnviado` borra el item, así que todo lo que sobrevive
  es trabajo sin enviar. El TTL sólo podía borrar eso, en silencio, al cargar — la manicura que pesaba
  un viernes sin señal y volvía el lunes perdía el pesaje sin enterarse.
- **La PLANTA es la clave de idempotencia del pesaje de manicura**, y por eso no hace falta ninguna
  columna de idempotencia: `distribuir_resto!` sólo toca plantas sin peso, así que un reintento no
  puede duplicar. Cuando el reintento encuentra todo pesado, el backend contesta 422 con
  **`ya_registrado: true`** y la cola lo da por ENVIADO. Sin esa bandera era indistinguible de un
  error de validación: la manicura leía "no pudo sincronizarse" sobre un pesaje que sí había
  entrado, y si lo volvía a cargar ahí sí quedaban dos jornadas. El pesaje encolado se reintenta
  con `force_new` porque el 409 `needs_choice` no se le puede preguntar a nadie desde una cola que
  corre sola.
- **Las URLs que se encolan van SIN `/api`:** el `baseURL` de axios ya lo trae. Con el prefijo, el
  reintento pegaba a `/api/api/...` → 404, y como un 404 tiene `response` la cola lo marcaba
  FALLIDO en vez de reintentar. Nada de lo encolado llegó nunca al servidor.
- **El service worker necesita `NavigationRoute`.** Sin él la PWA instalada NO ABRE sin internet:
  `start_url` es `/m` y esa navegación no matchea la entrada `index.html` del precache. En
  producción lo tapa el `spa_fallback` de Rails; offline no hay servidor, que es justo cuando hace
  falta. `/me` sigue SIN cachearse a propósito (servido del caché, tras un logout devolvía el
  usuario viejo).
- **Un módulo se pide por su clave NUEVA y en un solo lugar.** Chequear la vieja (`ia_voz`) con
  la nueva guardada (`ia`) daba false: `feature?` resuelve viejo ⇒ nuevo, no al revés. Rompía el
  registro por voz de toda organización moderna con el botón a la vista.

### Pendientes de Germán

- **Su socio tiene que dar de alta una organización sin ayuda**, y anotar dónde se traba. Es la
  prueba que vale más que todo lo demás.
- Decisión: **modelo de precios** — sin eso no hay MRR real (`mrr` y `churn_30d` siguen en 0).
  (La medición de IA está hecha —`ia_llamadas` + `Ia::Uso`, 11-ago— y desde el 13-ago **se ve**
  en la ficha del super admin.)
- Un **segundo nivel de super_admin** (rol comercial sin borrar organizaciones ni ver datos de
  pacientes): hoy es todo o nada. Toca el enum de roles, no se hizo.

### Antes de tocar producción

**La infraestructura está documentada en `docs/DEPLOY.md`** (20-ago): qué es cada servicio de
Render —incluido que **`cultivo-staging-api` ES PRODUCCIÓN**, el nombre quedó de cuando se levantó
apurado—, las 25+ variables de entorno con qué se rompe si falta cada una, y qué NUNCA se comparte
entre ambientes. `render.yaml` declara **sólo preproducción** a propósito: aplicar un blueprint
sobre servicios de producción configurados a mano es cómo se rompió la última vez.

**Las migraciones NO son un pendiente: se corren solas al deployar.** `bin/render-build.sh`
hace `bundle install`, `npm ci`, build del front y `rails db:migrate` como Build Command de
Render, con `set -o errexit` (si una migración falla, falla el deploy entero). No volver a
listar "pendiente `db:migrate`" al cerrar un bloque.

**Los rakes SÍ son manuales** — corren a mano, una sola vez, y ninguno se dispara al deployar.

**Sin correr desde el 12-ago, ninguno urgente:**

```
bundle exec rake lotes:corregir_finalizados_con_stock SIMULAR=1  # mirar los 6 del club 1
bundle exec rake geneticas:declarar_por_nombre SIMULAR=1         # resuelve ~44 de un saque
bundle exec rake geneticas:sin_declarar                          # informativo
bundle exec rake pacientes:normalizar_nombres SIMULAR=1          # capitalización de cargas masivas
```

Todos aceptan `SIMULAR=1`. **Ya corridos, no repetir:** `geneticas:inase_faltantes` (20-ago: completó
el catálogo GLOBAL del INASE de 8 a 9 sumando CAT3), `categorias:aplanar` (15-ago: aplanó el
catálogo contable, promoviendo las subcategorías a categorías con su sector y sus movimientos), y
del 10-ago:
`suites:prender_iot_con_dispositivos` (dio "nada que hacer" — todas las organizaciones con
dispositivos ya tenían el add-on) y `dispensaciones:recalcular_medio_pago` (5 mixtas, 4
corregidas a `efectivo`; era una etiqueta, no movió plata).

### Pendientes de Germán (no de código)

- ~~Cargar los `numero_registro_inase` de las 8 variedades del catálogo~~ — **no existe ese dato.**
  El INASE identifica cada variedad por su NOMBRE en el Catálogo Nacional de Cultivares y no le
  asigna un número propio; lo que consta aparte es la RESOLUCIÓN que la inscribió (las de 2022
  son la 2, 3, 27, 28, 55 y las 84/85 de las dos primeras). La columna y el KPI "Falta N°" se
  sacaron del informe: era un pendiente imposible de cerrar, y un aviso que nunca se apaga
  entrena a ignorar todos los demás. Si algún día se consigue el par variedad↔resolución, ESO es
  lo que vale la pena mostrar. **El catálogo global quedó completo en 9** (`rake
  geneticas:inase_faltantes` sumó CAT3, que faltaba).
- Declarar a mano las ~18 genéticas que no traen el par en el nombre.
- Decisión: **modelo de precios**.

### Deuda técnica conocida

- **155 clases CSS sin estilo** en 81 archivos, congeladas en
  `frontend/src/__tests__/clasesSinEstilo.baseline.json`. El test impide que la lista crezca y
  falla si arreglás una sin sacarla del baseline. NO todas son bugs (hay nombres de
  `<transition>` y marcadores semánticos): distinguirlas exige ver la pantalla renderizada.

### Cómo quedaron los informes (decisiones, no detalles)

Se ordenaron **por pregunta**, no por entidad, separando tres lectores: el organismo (lo que se
presenta), el dueño (análisis) y el que opera hoy (pendientes accionables).

- **REPROCANN declara la población REGISTRADA**: sin los que no iniciaron trámite (se informan
  aparte) y **sin corte por sede — un paciente es del club**, no de una sede.
- **Producción** separa "del período" de "hoy en el cultivo".
- **Trazabilidad** cierra el balance: producido − dispensado − merma = en stock.
- **INASE** agrupa por variedad acreditable, no por genética del club.
- **Pérdidas** es informe nuevo: plantas descartadas por motivo, merma, vencido en góndola.
- **Todos llevan una reseña** de qué contestan: sin eso, dos informes que cortan el mismo dato
  distinto parecen contradecirse.
- **El padrón de pacientes vive en Pacientes**, no en Informes, y cuenta sobre LA NÓMINA.

### La lección que no hay que repetir

**Un build que pasa no prueba que la pantalla funcione.** Pasó cuatro veces: el modal contable
sin estilos, los botones de "Método de aplicación" como `<button>` crudos, el modal con clases
CSS que nunca creé, y **`PlantaQrView` llamando a `usePWA()` sin importarlo** — Vite no sabe si
es un global del navegador o un olvido, así que compila feliz y la pantalla explota en
producción cuando alguien escanea un QR. Hay dos tests que barren esto (clases CSS contra el
`<style>` del componente; `useAlgo(` contra sus imports en 322 archivos), pero **si tocás una
pantalla, verificala renderizada**.

**Verificar que el candado esté puesto no es verificar que TODAS las puertas lo tengan.** Al
gatear las suites había 23 componentes de navegación y sólo 3 miraban las features; con el tope
de sedes el backend rechazaba pero el botón seguía invitando a llenar el formulario entero.

**Si tocás una pantalla, verificala renderizada.**

---

*Historial hasta 2026-07-28. Cambios julio (ver `docs/CHANGELOG.md`): **etiquetas QR en tanda y en PDF** (`lib/pdfEtiquetas.js` es fuente única; lote 93×60mm 3/fila en A4 apaisada, banderita de planta 160×26mm plegable; jsPDF lazy — dep nueva `jspdf`). Fix seguridad AZ (historia clínica en pacientes#show), backups Postgres→R2, KPIs de stock, edición multi-ítem + cuotas contables, candado de manicura asignada, guía de usuarios (`docs/GUIA_USUARIOS.md`). **Rediseño del Salón COMPLETO (B1–B6):** sub-nav compartida, Stock unificado, Vender = lista+buscador, Resumen liviano, caja de turno con confirmación entre roles, eventos por fases, Depósito→solapa Salón read-only. **Audit log (historial por usuario):** infra `Auditoria`+`Auditable`; Fase 1 (Lote/Plant/Stock/Dispensación) + Fase 2 (Paciente/User/Reserva con allowlist estricto — NUNCA campos encriptados/clínicos) + endpoint + tab en UsuarioDetail. **Código de barras** en productos del bar (lector físico + cámara `@zxing/browser` + scan-to-create). **Comprobante NO fiscal** al cobrar. **Multi-sede: los depósitos son de una SEDE** (`Deposito.sede_id`; `SembrarDepositos` siembra por sede + sede-ifica lo legacy); transferencia entre depósitos; edge case sede-divergente prevenido (el depósito fija la sede del movimiento). **Dashboard área × sede** (`resumen_por_unidad` con desglose por sede). **`vendible`/"no vender"** en mercadería del bar (dispensador solo ve lo vendible; alta desde Nuevo Movimiento; Stock del salón edición-only). Migraciones y `npm ci` los corre solo `bin/render-build.sh` en el deploy (deps nuevas de julio: `@zxing/browser`, `jspdf`) — no listarlos como pendiente. Mantener actualizado: al cerrar un bloque, actualizar "Módulos existentes" acá y `docs/CHANGELOG.md`.*

*Agosto 2026 (ver `docs/CHANGELOG.md`, entradas (g) a (o)): informes reordenados por pregunta, INASE, pérdidas, panel de super admin y modelo comercial de dos planes, **Club → Organización** en texto visible, **medición y tope de IA** (`ia_llamadas` + `Ia::Uso` + caché de prompt), **Correo y Delivery como add-ons** con baja programada, **correo con plantillas por organización y envíos masivos**, **alta desde el mostrador pendiente de aprobación**, contabilidad (el total manda, categorías reales, flujos y catálogo coexistiendo), onboarding y sedes alineados con las suites, y el fix del QR de planta con su test de composables sin importar.*
