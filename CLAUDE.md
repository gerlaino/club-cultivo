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
6b. **Mostrador** (`/mostrador`) — **el punto de venta del dispensario**, hermano de `Barra`.
    NO es un módulo contratable ni un interruptor: viene con Producción y dispensa, y **es dónde
    opera el dispensador**.
    **LA MESA ES DEL MOSTRADOR Y ES PERMANENTE; EL TURNO ES EL ARQUEO.** Son dos cosas distintas
    y de personas distintas, y estuvieron atadas hasta sep-2026: abrir el turno ERA poner la
    mercadería, así que el admin no podía gobernar la mesa a distancia —que es el punto entero
    del módulo— y lo que volviera de noche no tenía dónde caer.
    · **Qué hay sobre la mesa** (`MostradorItem`) lo decide **administración**, cuando quiera y
      desde donde esté, escribiendo cuánto tiene que haber de cada producto **y por qué**
      (`Mostradores::Cargar`, motivo obligatorio). Cada subida y bajada deja su
      `MostradorMovimiento` con autor: "hay 300 g" sin historial es un número que apareció, y
      monitorear a distancia sin historial es mirar una foto.
    · **El arqueo** (`TurnoMostrador`) lo hace **quien atiende**: abre contando lo que encuentra
      y la plata (`AbrirCaja`), y cierra contando de nuevo (`CerrarCaja`). **Con lo esperado a la
      vista** — ver "Lo que NO hay que romper". **Cierra en el acto,
      sin esperar al admin.** **Cerrar y volver a abrir ES el arqueo** — varias veces por día.
    **ABRIR ES CONTAR: no hay recepción separada.** Era la misma verificación pedida dos veces,
    con un botón que nadie miraba. Y **no bloquea por diferencia**: pone lo que contó y arranca,
    la diferencia queda anotada con su nombre. El conteo de APERTURA corrige la mesa pero **no
    toca el inventario** (el producto puede estar en el depósito); el del CIERRE sí, como
    `ajuste` con motivo y **nunca** como `merma`.
    **LO CARGADO SE APARTA, NO SE DESCUENTA** — misma mecánica que la provisión de un evento: la
    fila `Stock` sigue siendo una sola con su ST-xx y su QR, porque lo trazable sale del
    inventario por dispensación y nunca por cambiar de mesa. Cargar y bajar no generan
    `StockMovimiento`; el rastro vive en `MostradorMovimiento`. El único movimiento es el
    **ajuste del conteo**. Y el apartado **no depende de que haya turno abierto**: el producto
    está ahí a las tres de la tarde y a la medianoche.
    **La mesa se edita en una TABLA** (`components/mostrador/TablaMostrador.vue`), la misma con
    la que después se dispensa: buscador, orden por columna, y **se escribe el TOTAL que tiene
    que quedar, no el delta** — pedirle al usuario la resta es pedirle la cuenta que hace la
    máquina. Sin paginación a propósito: el listado viaja completo y paginar perdería lo escrito
    al cambiar de página. Para quien atiende la tabla es de LECTURA —él nunca elige qué hay— con
    un botón **"Contar"** por fila (`ModalContarItem`) para verificar un producto sin cerrar la
    caja. Administración guarda desde el pie de la tabla, y el motivo se pide en el modal de
    confirmación (`ModalCargarMesa`), con la lista de lo que cambia delante.
    Vive en `/mostrador`, y en la PWA **`/m/mostrador` DESPACHA POR ROL**
    (`MMostradorDispatch`): administración entra a la de escritorio —la tabla es su herramienta y
    se asoma al teléfono de vez en cuando—, y **quien atiende tiene su propia pantalla**
    (`views/mobile/MMostradorView.vue`), porque él vive ahí. Servirle la de escritorio le dejaba
    cada producto como una tarjeta de SIETE renglones, así que con quince frascos eran cien
    renglones de scroll para contestar "¿tenés Northern?", que es la pregunta que más veces
    contesta por día, de pie y con alguien enfrente. La suya es lista de una línea por producto
    —qué es y cuánto hay— con el resto de los datos y "Contar" a un toque, en una hoja; la caja
    arriba con la acción a ancho completo; y lo que movió administración, colapsado.
    **El ESTADO es UNO SOLO** (`composables/useMostrador.js`): cargar, guardar, contar, abrir,
    cerrar, mover plata, la sede inicial y el canal. Lo único que difiere es la PRESENTACIÓN —si
    la regla viviera dos veces, un día las dos pantallas dirían distinto de la misma mesa.
    `gestionaMostrador` decide a la vez cuál pantalla se sirve y qué se ve adentro, por lo mismo.
    Es una pantalla de CONSULTA y ARQUEO, no de operación: **dispensar sigue por su flujo**.
    **EN PANTALLA NO EXISTE LA PALABRA "TURNO": SE ABRE Y SE CIERRA LA CAJA, Y CADA CICLO ES UN
    CIERRE.** El modelo se sigue llamando `TurnoMostrador` y los identificadores no se tocan (misma
    regla que Club → Organización), pero el texto visible dice **cierre** — "turno" ya significa
    otra cosa en la app (el turno MÉDICO, la cita del paciente) y encima chocaba con el botón de al
    lado, que dice "Cerrar caja". Lo preguntó Germán probando: *"no vamos a abrir o cerrar turnos,
    solo abrimos y cerramos caja"*.
    **TRES solapas** (12-sep-2026, acordado con Germán sobre una maqueta navegable): **Hoy** ·
    **Cierres** (los hechos; administración ve todos, el que atiende ve LOS SUYOS — el filtro es
    del backend) · **Merma**, sólo administración. Eran cinco y tres contestaban la misma pregunta
    —¿se me está yendo producto?— en tres unidades y tres marcos de tiempo: **«Producto por
    producto» era Merma con otro corte y otro filtro de fecha** y pasó a ser el detalle de cada
    fila de Merma (tocás el producto y se abre su gráfico, `GraficoProducto`, uno por frasco con su
    escala); **«Rendiciones» no es del mostrador** —es plata del delivery— y vive en Comercial →
    Rendiciones (`/delivery/rendiciones`); en el mostrador queda la tarjeta del repartidor que está
    rindiendo a ESTA caja. La solapa de Merma está ordenada **POR PREGUNTA**: **① ¿cómo viene?**
    (el veredicto contra el patrón de esa organización + la tendencia semanal, **y la plata**: lo
    que faltó en la caja, neto, en su propia oración) · **② de qué falta** (UNA lista con un corte
    a la vez: producto, sede o persona; la fila de producto se abre). **LA PLATA ES MOTIVO DE
    REVISIÓN** (`caja` en `Mostradores::MotivosDeRevision`, sale de los asientos `diferencia_caja`):
    un cierre con $8.500 menos en el cajón decía «Sin novedad» y no entraba en «Para mirar». Manda
    sobre el producto en la fila. **CIERRES ES UN CALENDARIO** (idea de Germán, 12-sep): fechas, no
    tarjetas —«los números así sueltos no se entiende por qué son»—; el estado es una marca debajo
    del número (ámbar = faltó producto o plata), el mes viaja entero (`turnos?mes=YYYY-MM`, sin
    paginar) y el detalle del día va AL LADO con los cierres ya desplegados y sus botones — no un
    modal con otro modal adentro. «Para mirar» es una franja ARRIBA de la grilla, nunca puntitos
    dispersos. **«Corregir» sólo en el último cierre**: `bloqueo_correccion` viaja en el resumen y
    el panel lo dice en vez de esconder el botón. Las oraciones de un cierre viven en
    `lib/hechosDelCierre.js`, que leen la ficha y el panel. **MERMA HABLA DE PRODUCTO, NO DE PLATA**
    (pedido de Germán, 12-sep): el titular suma por forma («27 g de flor seca y 4 prerolls»), la
    lista es **por frasco** con la cantidad grande y la plata en la segunda línea, ordenada por
    proporción sobre lo entregado (lo único que compara flor con prerolls), y los frascos enteros
    se listan igual, al final: que uno no aparezca no es lo mismo que que esté bien.
    Un turno entra a esa lista por **cuatro** razones —faltante, **sobrante**, **corrección al
    abrir**, o **administración movió la mesa durante el turno**— y cada renglón dice cuál: un
    pendiente que no dice qué mirar obliga a abrirlo para descubrir que no era nada.
    **La caja del dispensario se abre y se cierra SÓLO por acá.** `caja/abrir`,
    `confirmar_apertura`, `solicitar_cierre`, `confirmar_cierre` y `cerrar` se retiraron: abrir
    declarando sólo un fondo salteaba la mitad del arqueo. En `cajas#*` queda mover plata
    (salida/ingreso) y **anular** una abierta por error.
7. **Delivery** — paquetes, estados (pendiente/en viaje/entregado/fallido), firma de entrega, reprogramación. **Su PWA son tres solapas: Despachos · Caja · Historial** — el inicio es a dónde va ahora, la plata vive en Caja (cuánto lleva encima, el desglose y rendir) y el historial trae las entregas y **cómo cerró cada caja que rindió**. **Es un add-on contratable** (antes era un rol suelto): sin el módulo activo, el rol `delivery` no se ofrece ni se acepta, `rutas_entrega` y las acciones de reparto devuelven 403, y `Dispensacion` rechaza al CREAR una dispensa con envío. **`entregar` y `reportar_fallo` quedan SIN gatear a propósito** — ver "Lo que NO hay que romper".
8. **Ambiente / IoT** — dispositivos con webhook token, lecturas, reglas y alertas, setpoints por fase, VPD, drivers (Sonoff, CSV manual, CSV-IA).
9. **Contabilidad** — movimientos contables, costos por lote, P&L.
10. **Analítica e informes** — genéticas/ciclos/pérdidas/comparativa, benchmark, informe semestral, informes auditor (REPROCANN, producción, cumplimiento, plan vs real, trazabilidad).
10b. **Informes del auditor, revisados uno por uno (sep-2026):** Producción, Trazabilidad (frasco y lote), Dispensaciones, Pérdidas, Plan vs. real y REPROCANN viven en `app/services/informes/*` (y `Stocks::Trazabilidad`, `Lotes::Trazabilidad`); pantalla, PDF y Excel leen el mismo hash. **Cumplimiento se retiró** (ruta redirige a REPROCANN). Reglas que valen para todos: por línea y por unidad, nunca `updated_at` como fecha de un hecho, la descarga pide el mismo período que la pantalla (`SelectorPeriodo`), DNI en 3 dígitos en pantalla y entero en el archivo. **Faltan revisar:** INASE, Semestral, Analítica.
11. **ARICCAME** — reporte de dispensaciones y stock (feature flag por club). La transmisión está SIMULADA: no envía nada de verdad.
12. **Super admin** — panel de plataforma como **cola de trabajo** (cada pendiente con su acción, agrupado por urgencia: se está perdiendo plata · paga y no le funciona · avisar con tiempo), organizaciones, **dos planes** (`PlanEnforcer`: básico/total, sólo límites), catálogo de módulos (`GET /super_admin/catalogo`), informes de plataforma, historial por organización. **El modo observador está SUSPENDIDO** (`User::OBSERVADOR_HABILITADO = false`). Un super_admin sin contexto que pega a un endpoint de organización recibe **409 explicando qué falta** (`block_super_admin_sin_contexto!`), no un 500.
13. **Notificaciones** — push web, ActionCable, alertas internas por rol.
14. **Portal del paciente** (`vista_paciente`, **add-on**) + carnets digitales. Cada paciente que se da de alta recibe su **cuenta** (`Pacientes::Acceso`): usuario `nombre.apellido@organizacion.paciente` y contraseña generada por paciente y dictable — nunca una fija, que acá sería fatal porque el usuario se deduce del nombre. La cuenta nace cuando el paciente queda ADMITIDO. **Sin el módulo el paciente no puede ni loguearse** (`User::MODULOS_POR_ROL`), como el repartidor sin Delivery.
    **Son DOS llaves y hacen falta las dos:** el add-on CONTRATADO (lo prende el super admin) y el portal ABIERTO (`clubs.vista_paciente_activa`, el interruptor de la organización en Configuración → Portal del paciente). La regla vive en **`Club#portal_paciente_disponible?`** y la preguntan el login (`User#rol_habilitado?`) y `Portal::BaseController` — cerrado, el paciente no entra ni con la sesión abierta. El interruptor existía desde antes y **no lo leía nadie**: se guardaba, se mostraba y no hacía nada. Toda spec que contrate `vista_paciente` tiene que pasar `vista_paciente_activa: true`.
    **"¿PUEDE RETIRAR?" LO CONTESTA EL ESTADO DE SU CUENTA, NO EL REPROCANN.** `Dispensacion` valida
    dos cosas sobre la persona —`es_paciente?` (activa) y `aprobado?`— y **el REPROCANN no está entre
    ellas**: hoy no bloquea nada. La credencial lo usaba igual y mentía en los dos sentidos (al
    vencido le decía que no podía cuando sí podía; a uno vigente pero dado de baja o pendiente, que
    sí, y lo rebotaban en la puerta). El REPROCANN se sigue mostrando con su fecha y su color —es su
    trámite y renovarlo lleva semanas— pero como dato aparte. Si algún día pasa a bloquear, el
    cambio va en `Dispensacion` y la credencial lo refleja sola.
    **EL INICIO ES EL ESTADO DEL PACIENTE, no el boletín.** En orden: su **credencial** (nombre, DNI, número de socio y el REPROCANN como semáforo; a pantalla completa con QR, porque es lo único del producto que se usa PARADO, en la puerta) · **lo suyo** (próximo turno, indicación vigente, cuenta corriente, último retiro) · **del club** en dos renglones. El boletín —novedades, eventos, catálogo, galería— vive entero en `/portal/del-club`: se movió porque está VACÍO en cualquier organización que no publique, que son casi todas casi todas las semanas, y el estado del paciente no está vacío nunca. **El estado del REPROCANN va DENTRO de la credencial**, no en una franja aparte: es la misma pregunta (¿puede retirar?). `PortalAvisos` se quedó sólo con lo urgente.
    El boletín vive en **`/portal/organizacion`** y en pantalla se llama **"Mi organización"**: el
    texto visible nunca dice "club".
    **`/portal/mi-salud`** es lo clínico: turnos e indicación médica. Se arma con **lista blanca campo por campo, NUNCA `as_json`** — `Turno#notas_post` son las notas del médico para el médico y no salen jamás; los campos encriptados de `IndicacionMedica` sí, porque son suyos. **No hay sección Contacto**: eran cuatro datos y un formulario que no mandaba nada, y viven en el pie.
    **El portal tiene su propia capa de tokens**, `design-system/portal.css`: define `--p-*` EN FUNCIÓN de los del DS, y `PortalShell` pisa las de marca con el `theme_primary` de cada organización. `portalTokens.test.js` barre las pantallas y falla ante cualquier hex a mano o `bi-*`: **el baseline es CERO y tiene que quedarse en cero**. Es mobile-first, al revés que el resto de la app.
    **La contraseña le llega por mail** (`PacienteMailer#acceso_portal`, mail FIJO — no plantilla editable). Necesita el módulo `mailer` + casilla conectada + mail del paciente; si falta alguna, la ficha lo dice ANTES de crear la cuenta y la contraseña se muestra en pantalla. **No queda en el historial de correo**: el registro dice que se le mandó el acceso, no cuál es. La cuenta se GESTIONA desde la ficha del paciente (tab "Acceso al portal", admin/médico). El paciente ve su cuenta corriente en `/portal/cuenta-corriente`, y el enlace aparece SÓLO si la organización se la abrió. Ve su usuario y cambia su contraseña en `/portal/cuenta`, DENTRO del portal. Siguen sin login, a propósito, el carnet (`/c/:token`) y el pasaporte de dispensa (`/d/:token`), que son links que la persona entrega. **No hay vitrina pública de un club**: lo público de la plataforma es `/bienvenida`; `web-publica/` se retiró (era un Vite aparte sin sesión cuyo backend resolvía el club con `Club.first`).
15. **App móvil** (Capacitor) — cultivador y manicura principalmente; vistas bajo `/m`.
16. **Asistente IA por voz** — parsear/ejecutar comandos. **Todo el consumo se mide y se cobra**: ver "IA" abajo.
17. **Correo electrónico** — **add-on contratable** (`mailer`, con `require_feature!` real). Pantalla propia en Configuración → Correo: casilla SMTP de la organización + **plantillas que edita su admin** (variables `{{nombre}}` por lista blanca con `gsub`, **nunca ERB**). Bienvenida al alta (admin/médico en el acto; mostrador al aprobar) y **envíos masivos** (`EnvioMasivo` + `EnvioMasivoJob`): **un mail por destinatario, jamás un `To:` múltiple ni BCC** — juntos, cada paciente recibiría el padrón completo (fuga de datos de salud, Ley 25.326). Tope propio de 450/día (`Correo::CupoDiario`), por debajo de los ~500 de Gmail: pasarse **suspende la casilla del cliente**. Se chequea ANTES de crear el envío.

### IA — medición y topes

Toda llamada a la API queda en `ia_llamadas` (organización, persona, función, modelo, tokens y **costo congelado**; también las fallidas). Registran las cinco funciones: asistente parsear/consultar, análisis de lote, plan de trabajo y mapeo de CSV. `Ia::Uso` es la puerta única: `registrar`, `limite_alcanzado`, `resumen_mes`.

- **Manda el tope MENSUAL y SALE DEL PLAN** (`Club::IA_TIERS`: Básico 500 / Total 2.000), que se
  cuenta contra la base y no depende de Redis. Eran TRES tramos elegibles a mano y la misma
  organización podía tener plan Total con la IA en Básico: la misma decisión en dos lugares.
  **`ia_tier` sigue en la tabla y en la auditoría pero NO LO LEE NADIE.** El horario es sólo freno
  de ráfaga, **por organización** (contaba por usuario: cinco personas daban 5× el límite).
- **Lo que se vende aparte son CRÉDITOS** (`IaRecarga`, 25-ago): una fila por venta con fecha,
  cuántos, para qué y quién la cargó. Aplican al mes en curso y **no se acumulan** — con un número
  suelto en `clubs` habría que ponerlo en cero el día 1 a mano, y a fin de mes se facturaría de
  memoria. `resumen_mes` informa `base` / `extra` / **`extra_usado`**, que es el número que se
  factura. Se cargan desde `POST /super_admin/clubs/:id/ia_recarga`.
- **`club.ia_limite_hora` sobrescribe el horario del tramo** cuando es > 0. El mensual **no tiene override**.
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
| `supervisor` | Lectura de cultivo + gestión de tareas; **dispensa** y **gestiona reservas** (crear/editar/cancelar); **ve** (no edita) historia clínica; **crea pacientes** (quedan pendientes de aprobación). **Es administración, no "el que atiende"**: dispensa del depósito entero, con o sin mostrador abierto |
| `manicura` | Post-cosecha: pesajes e inventario de los lotes `en_manicura` que el admin le asigna (trabaja por estado del lote, no por sala). **Provisorio:** si el lote tiene manicura asignado, **solo esa persona** registra el peso (ni admin ni otro manicura); el peso va por el flujo de pesaje, no por `plants#update` |
| `dispensador` | Dispensaciones, stock por sede, socios (lectura); **convierte reservas a dispensa** (Entregar), pero NO las crea ni gestiona; **crea pacientes** (quedan pendientes de aprobación, y ninguno de los dos aprueba). **Es el único que pasa por el mostrador**: dispensa sólo lo que está sobre la mesa y con el número de la mesa |
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
cd frontend && npm run e2e                                 # punta a punta en el navegador
docker compose exec backend bundle exec rspec              # tests backend
docker compose exec backend bundle exec rspec spec/...     # un spec
docker compose exec backend rails console
docker compose exec backend rails db:migrate
cd frontend && npm run test                                # Vitest
cd frontend && npm run dev                                 # Vite dev server
```

- API: `http://localhost:3001/api` (ver `frontend/src/lib/api.js`)
- **Pruebas de punta a punta**: `frontend/e2e/` (Playwright). Cada archivo siembra su escenario
  con `rake e2e:seed` / `e2e:reparto` sobre una organización **aparte** (`slug: 'e2e'`) — nunca
  sobre datos reales. Un solo worker: los casos comparten el mostrador, que es uno por sede igual
  que en la vida real. `entrar()` VERIFICA con quién quedó la sesión: sin eso, un login que no
  cambió de usuario se descubre tres pasos después con un error que no tiene nada que ver.
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
- **Un derivado puede tener MÁS unidades que gramos consumidos**: de 100 g de flor salen 200
  prerolls de medio gramo o 400 cápsulas. El tope contra la materia que aparece de la nada (de
  100 g no salen 120 g de hash) vale **sólo cuando el resultado se mide en gramos**.
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

## 📍 Dónde retomar (11-sep-2026)

**Lo que encontró el socio de Germán probando, y el repaso del PWA del repartidor.** 9 commits,
**pusheados** (`a9bf0965` → `b420c429`). Bloque (bd) del CHANGELOG.

- **Los 4 del socio:** editar una dispensa rebotaba con «hay 0.0g» (el techo de la edición restaba
  la mesa entera) · «Cuenta corriente sin límite» con el crédito ya habilitado (el historial no le
  pasaba la CC al modal) · el libro diario **no avanzaba de página** y **el buscador miraba sólo
  los diez renglones cargados** · el stock decía «18 g disponible» arriba y «0.0g» en rojo abajo.
- **La rendición:** va dirigida a una persona y cae en un cajón. El admin veía el botón de una
  rendición que era del dispensador, y con dos mostradores abiertos la plata **no entraba a ningún
  arqueo**.
- **El PWA del repartidor:** solapa **Caja** (por fin ve cuánto lleva antes de rendir), inicio
  limpio, historial con las cajas rendidas, las dos fotos del modal con nombre propio, y
  `mis_paquetes` acotado a lo que está en la calle.

**3014 rspec ✓ · 1999 vitest ✓ · build limpio · 3 pruebas de navegador de rendición ✓.** Todo
verificado renderizado, a 390 px lo del repartidor.

**SIGUE:** el socio iba a seguir probando — **lo que aparezca arranca la próxima sesión**. Y sigue
pendiente lo de Germán: repasar informe por informe y analítica por analítica.

**Y el libro diario perdió la columna «Subcategoría»**, que decía "—" en todos los renglones de
todas las organizaciones desde que se aplanó el catálogo: la ruta entera («Bienes de Uso ›
Herramientas») va en la celda de Categoría, así que no se pierde el dato el día que alguien cree
una. La tabla igual **sigue sin entrar a 1280 px: sobran 52**, y son 9 columnas.

**Los cuatro cabos que habían quedado, CERRADOS:**
- **Del libro se baja lo que estás mirando**: el export respeta los mismos filtros que la pantalla
  (salen del mismo método) y el encabezado del Excel dice con qué se filtró.
- **Un punto en la solapa Caja** cuando el repartidor lleva efectivo sin rendir: es lo único que
  se lo recuerda desde que la plata salió del inicio. Sale del mismo dato que la pantalla
  (`stores/cajaDelivery`), así que se apaga solo al rendir.
- `saldo_a_cuenta_ars` salió de `mi_caja`: lo dice la tarjeta de rendición con su propio dato.
- **`/delivery/caja` es del repartidor**: un admin que escribía la URL caía en una pantalla que
  sólo sabía decirle que no se pudo cargar. Ahora vuelve a su inicio.

**3018 rspec ✓ · 2002 vitest ✓.**

**Pendientes suyos (no de código), sin cambios:** rotar el secreto de Render · los 5 usuarios con
la clave vieja · `rake stocks:balance_descuadrado` · `rake auditorias:limpiar_blobs` · declarar 8
variedades del INASE a mano.

**Pendiente de código, sin cambios:** las **2 pruebas de navegador rotas desde el 8-sep**
(`e2e/mostrador.spec.js`) afirman `.mrm__veredicto`, «Dónde se va» y «Cierre por cierre» — nada de
eso existe desde que se rehizo la solapa de Merma. **No reescribirlas mirando el código**:
preguntarle a Germán cómo quedó.

---

## 📍 Dónde retomar (10-sep-2026)

**Repaso del delivery, la auditoría y los informes, con la app corriendo.** 2 commits, pusheados
(`fe402003`, `3b5b4f22`). Todo lo que apareció era la misma clase de error —**la pantalla diciendo
algo distinto de lo que el dato dice**— y **ninguna suite lo veía**:

- **La tarjeta "Tu próxima entrega" estaba pegada DOS veces** y la copia mala quedó adentro del
  cartel de cobro del modal del repartidor: aparecía en mitad del formulario justo cuando efectivo
  + transferencia cubrían el total, y se comía el "Cubierto ✓". El template compila igual: el bug
  es DÓNDE está dibujado.
- **`[object Object]` y firmas en base64 en el historial de actividad** — `Dispensacion` era el
  único de 13 modelos auditados sin `auditar_solo`.
- **El PDF de trazabilidad no salía**, y la pantalla decía "reintentá en un momento" sobre un 422
  que explicaba exactamente qué hacer.
- **Contar de más creaba stock**: la causa real del balance descuadrado de la trazabilidad.
- **`toISOString()` es UTC**: dispensar rebotaba con "la fecha no puede ser futura" **todas las
  noches entre las 21:00 y las 00:00 ART**. 60 usos en 48 archivos.

**2970 rspec ✓ · 1960 vitest ✓ · build limpio · eslint en su baseline.**

**SIGUE:** el socio de Germán estuvo probando la app y encontró cosas mal — eso arranca la próxima
sesión. Y Germán iba a repasar informe por informe y analítica por analítica.

**Pendientes suyos (no de código):** rotar el secreto de Render · los 5 usuarios con la clave vieja
(`rake seguridad:usuarios_con_password_default`) · `rake stocks:balance_descuadrado` (8 stocks, pero
**sólo 1 es el bug del mostrador**; las orgs 3 y 6 tienen los mismos tres descuadres idénticos, o
sea una **clonación** que copió el problema) · `rake auditorias:limpiar_blobs` (315 filas / 531 KB) ·
declarar 8 variedades del INASE a mano.

**Pendiente de código:** **2 pruebas de navegador rotas desde el 8-sep** (`e2e/mostrador.spec.js`)
afirman `.mrm__veredicto`, "Dónde se va" y "Cierre por cierre" — **nada de eso existe** desde que
se rehizo la solapa de Merma. **No reescribirlas mirando el código**: preguntarle a Germán cómo
quedó. Y la suite de navegador es **inestable**: en cuatro corridas falló un test distinto cada vez
y cada archivo pasa solo.

---

## 📍 Dónde retomar (7-sep-2026)

**Dos días probando el mostrador en producción, con el celular en la mano.** 12 commits, todos
pusheados (bloques (ag) a (an) del CHANGELOG). Lo que rompía de verdad **pasó todas las suites en
verde** y apareció mirando la app corriendo:

- **La PWA recién instalada abría en NEGRO** — y le pasaba a cualquiera que la instalara por
  primera vez. `render file:` no existe en modo API y devuelve vacío en silencio, así que `/m` —el
  `start_url`— servía una página sin nada; sin JS no se registraba el service worker y no había
  salida. Lo tapaba el precache mientras el SW ya estuviera instalado.
- **"Entregar reserva" estaba MUERTO**, también en el escritorio: dos guards borran el producto
  elegido si no está en la lista visible, y lo reservado nunca está ahí.
- **El porcentaje de merma salía inflado**: lo dispensado de un producto bajado a la mesa después
  de abrir la caja no sumaba al arqueo. El faltante cuadraba igual, así que no se veía.
- Y un arreglo deployado que **no llegaba al teléfono**: la PWA sólo preguntaba por versión nueva
  al arrancar en frío, y una app instalada casi nunca arranca en frío.

**RESERVAR ELIGIENDO DE LA MESA — HECHO** (bloque (ao) del CHANGELOG). Las cuatro piezas están:
la lista al reservar es la de la mesa de esa sede; lo reservado se descuenta del carrito del
dispensador y la fila dice cuánto es; se dejó de restar dos veces contra el depósito
(`max(mesa, reservas)`, sin columna nueva); y el número físico de la mesa no se toca. Decisión de
Germán sobre lo que está sólo en el depósito: **se baja a la mesa la cantidad a reservar y ahí se
reserva** — así queda bloqueado para la dispensa Y lo entrega el dispensador sin depender de
admin ni supervisor. El cartel de mesa vacía dice exactamente eso, con el link.

Pendiente menor: los **cierres como tarjetas desplegables** en el teléfono (hoy es una tabla).

**1854 vitest ✓ · sin correr en el navegador todavía: la lista de reservar hay que verla
renderizada.**

---

## 📍 Dónde retomar (4-sep-2026)

**Repaso del mostrador rol por rol, con la app corriendo** (bloque (ab) del CHANGELOG). Casi todo
lo que apareció era la misma clase de error: la pantalla ofrecía un camino que el backend termina
rechazando, o una regla escrita en un lado y leída en otro. Lo gordo lo encontró **mirar la
pantalla renderizada**, no los tests: al que atiende se le mostraba el disponible del DEPÓSITO
(1.000 g) cuando sobre la mesa había 300, y lo dejaba cargar de más para rebotar al confirmar.
También: la caja cerrada se avisa ahora al abrir el carrito y no al final; en la PWA instalada
"Ir al mostrador" volvía a la misma pantalla; `Mostradores::Contar` tenía servicio y ruta pero
**ninguna pantalla**; y el motivo de un cambio de mesa se pide con la lista de cambios delante.
**2772 rspec ✓ · 1748 vitest ✓ · 7 pruebas de navegador ✓** (una de ellas estaba roja en master
por un locator ambiguo, no por la app).

**Pendiente de decisión (mío):** si administración debería poder contar a distancia (hoy no: su
gesto sobre la mesa es decir cuánto tiene que haber, que mueve producto del depósito).

---

## 📍 Dónde retomar (3-sep-2026)

**La MESA dejó de ser del turno** (bloque (x) del CHANGELOG). El mostrador tiene contenido propio
y permanente (`MostradorItem` + `MostradorMovimiento`) que gobierna administración desde donde
esté; el turno se quedó con el arqueo, y **abrir es contar**: la recepción separada desapareció,
junto con `caja/abrir` y toda la ceremonia de confirmar apertura y cierre cruzado. **La papelera se
retiró** (restaurar re-aplicaba efectos sobre el estado de HOY: le sacaba producto a la mesa de
hoy). Se repasó **rol por rol** —admin, dispensador y repartidor— con la app corriendo, y una
segunda pasada cerró los cinco pendientes que había dejado abiertos (ver bloque (y) del
CHANGELOG): la migración de limpieza, los gramos ocultos detrás del modal de cierre, las tres
razones de revisión unificadas en un solo lugar, el admin llegando directo al mostrador de una
sede (`?sede=`), y un agujero real que apareció en el camino — el PRIMER día, sin ningún cierre
anterior del que heredar el fondo, se podía abrir la caja sin contar nada y el turno quedaba SIN
caja: lo cobrado en efectivo no tenía dónde caer. Ahora lo exige, y sólo ese día.
**2761 rspec ✓ · 1707 vitest ✓ · 7 pruebas de navegador ✓.**

**Sin correr:** nada. Las migraciones las corre solo el deploy.

**Pendiente de decisión (mío, no de código):**
- Si el mostrador debe aplicarle también al **admin** para DISPENSAR (hoy no, ver
  `User#atiende_mostrador?`) — esto es distinto de VER el mostrador de una sede, que ya andaba y
  ahora además tiene atajo directo.

---

## 📍 Dónde retomar (25-ago-2026)

**El alta de organizaciones se rediseñó para que la use alguien que no escribió la app** (bloque
(u) del CHANGELOG): módulos antes que el plan, adicionales agrupados por la suite que extienden,
paso de resumen, topes del Básico nuevos, usuarios por rol, IA de dos tramos derivados del plan y
créditos extra con rastro (`ia_recargas`). **La prueba con el socio es lo que sigue**: anotar dónde
se traba.

**2448 rspec (0 fallas, 26 pending del observador suspendido) + 1574 vitest + build limpio.**
Los bloques de agosto están en `docs/CHANGELOG.md` hasta "Agosto 2026 (u)".

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

- **FLORACIÓN → VEGETATIVO CON LOTES ADENTRO ES DESHACER, NO REVEGETAR** (`Salas::CambiarFase`,
  12-sep-2026, decisión de Germán). Nadie revegeta a propósito una planta que ya recibió 12/12:
  una sala vuelve a vegetativo o vacía o por error de click. Como avance dejaba al lote con un
  ciclo falso («estuvo un día en floración y revegetó») que contaminaba días por etapa, Plan vs
  real y la analítica de ciclos. Se BORRA el paso: el evento de entrada a floración (define la
  fecha de inicio y los relojes), el estado de las plantas y las tareas automáticas de floración
  pendientes; **fotos, notas, riegos y registros QUEDAN** (son hechos reales) y queda una `nota`
  en el lote diciendo qué se deshizo. Con lotes adentro, **las dos direcciones piden confirmación**
  lote por lote con los días (el error es simétrico); una sala vacía se da vuelta sin preguntar.
  **Una regla para las dos puertas** —editar el `kind` y el botón «Cambiar fase»—; el botón no
  preguntaba nada. El texto del guard vive en `lib/textoCambioDeFase.js`.
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

**Dos planes, y el plan dice CUÁNTO, nunca QUÉ.** `PlanEnforcer::PLANES` = `basico` / `total`.
Qué puede hacer una organización lo deciden las suites, y no se cruzan. Los cuatro planes viejos
siguen mapeados en `PLANES_LEGACY` por si aparece uno guardado.

**El Básico son `1 sede · 3 salas · lotes SIN LÍMITE · 450 plantas · 50 pacientes`** (25-ago).
- **Los lotes no se limitan a propósito**: el lote es una unidad de ORGANIZACIÓN, no de capacidad.
  Ponerle tope empuja a meter todo en un lote gigante para no chocarlo, y eso rompe la
  trazabilidad, que es el activo del producto. La capacidad real la miden las plantas.
- **Los usuarios no son un número: es UNO DE CADA ROL** (`usuarios_por_rol`). "5 usuarios" no se
  vende ni se explica, y dejaba dar de alta cinco cultivadores y ningún dispensador. En Total no
  hay tope. **El `admin` queda FUERA del cupo** (`PlanEnforcer::ROLES_SIN_TOPE`): no es un puesto
  de trabajo, es quien contrata —dos socios más veces de las que es uno solo— y con tope de uno,
  el día que el único admin se va hay que meter mano en la base para devolver el control.
- **Qué roles puede tener depende de los MÓDULOS** (`Club::MODULO_POR_ROL`): cultivador y manicura
  piden Cultivo; dispensador y médico, Producción y dispensa; delivery, su add-on. Antes esto
  cubría sólo a `delivery`. Un cultivador en una organización sin Cultivo loguea a una app sin una
  sola pantalla, y el que lo descubre es el cliente.

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

- **LOS AJUSTES DE CONTEO SE NETEAN POR CIERRE** (sep-2026, Germán: «si me equivoqué al tipear no
  hubo esa diferencia real»). Trazabilidad y Pérdidas suman los `ajuste` con el mismo
  `turno_mostrador_id` y frasco; neto cero no aparece. `CorregirCierre` pide `causa`
  (`error_conteo` / `faltaba`) y **quien cerró corrige su propio último cierre** — esperar al
  admin dejaba el error en el inventario hasta el día siguiente.
- **UN PAGO DICE CÓMO, CUÁNDO Y DE QUÉ CAJA** (sep-2026, pedido de Germán). `fecha` es la del gasto
  y no se mueve; `fecha_pago` es cuándo salió la plata (`completar_fecha_pago`: lo que nace pagado
  se pagó ese día). En efectivo se elige entre las cajas ABIERTAS (`useCajasAbiertas`, la misma
  lista que el carrito del admin) y «de ninguna» es válido: el asiento se escribe igual y no entra a
  ningún arqueo. **`CajaTurno#salidas` cuenta cualquier egreso en efectivo atado a la caja**, no sólo
  `salida_caja` — pagar un proveedor con plata del cajón antes daba faltante o se asentaba dos veces.
  `diferencia_caja` se excluye a propósito. **Las cuotas nacen todas pendientes** y editar la compra
  conserva los pagos por `cuota_numero`.
- **UN RETIRO PUEDE NACER «GUARDADO EN LA ORGANIZACIÓN»**: `retiro_caja` con
  `saldado_como: 'organizacion'` (`MovimientoContable.atributos_guardado_en_organizacion`). Sale del
  cajón, no es deuda de nadie, no es gasto. Sin «cuenta del club» a propósito.
- **NO EXISTE «STOCK VENCIDO»** (Germán, sep-2026): Pérdidas no lo muestra. `fecha_vencimiento_est`
  sigue en la tabla pero no es una pérdida ni algo por perderse.
- **LA DESCARGA DE UN INFORME PIDE EL MISMO PERÍODO QUE LA PANTALLA** (sep-2026). `@click="exportarPdf"`
  sin paréntesis mandaba el `MouseEvent` como parámetros y el PDF bajaba siempre «mes actual».
  El período vive en `SelectorPeriodo` (emite `{periodo}` o `{desde,hasta}`) y la vista pasa esos
  mismos `params` a `exportarPdf(params)`; `periodo_rango` acepta el rango para todos los informes.
- **UN INFORME CUENTA POR LÍNEA Y POR UNIDAD** (`Informes::Dispensaciones`). `dispensaciones.cantidad`
  es la suma de las líneas en la unidad de cada una y `stock_id` es la primera línea: ninguno de
  los dos sirve para contar. Gramos, unidades y ml van cada uno en lo suyo, nunca sumados.
- **LA PLATA DEL ADMIN VA A LA CAJA QUE ÉL DICE, Y LA DE LA MESA A LA DE SU MOSTRADOR**
  (`Dispensacion#caja_para_cobros`, sep-2026, decisión de Germán). Quien atiende cobra en la
  suya. Administración: si algo del carrito está sobre una mesa, la caja de ese mostrador sin
  preguntar; si todo sale del depósito, la que eligió en el modal (`caja_turno_id`, entre las
  abiertas) o **ninguna** — el asiento se escribe igual, la plata no entra a ningún arqueo. Antes
  caía siempre en la caja de la sede y el dispensador cerraba con un faltante que no era suyo.
- **UNA VENTA EN EFECTIVO CREA SU `Cobro`, AUNQUE SEA UN SOLO MEDIO.** El arqueo suma `cobros`;
  el camino legacy de `medio_pago` único asentaba sin crear ninguno y la venta simple —casi
  todas— no existía para la caja. Efectivo y transferencia pasan por `aplicar_lineas_cobro!`
  también con un medio; cuenta corriente y gramos siguen por el legacy. Editar una dispensa con
  ese único cobro de creación lo rehace (`cobro_simple_de`); los partidos siguen sin editarse.
- **SE BAJA DE LA MESA LO QUE HABÍA ARRIBA; EL RESTO SALE DEL DEPÓSITO.** Administración dispensa
  contra depósito + mesa, e `imputar_a_mostrador` restaba la línea entera: 50 g con 40 arriba
  rebotaba con «No hay tanto sobre la mesa».
- **EN UN DISPENSARIO NO SE CULTIVA** (`Sala#sede_de_cultivo`): toda sala pide sede de producción
  o mixta, al crear o al cambiar de sede. En specs, una sede con salas es `mixta`, no `social`.
- **EL PESAJE SE SUMA AL FRASCO DE AYER** también en el PWA (`MAdminAprobacionView`): el backend
  ya aceptaba `stock_id` y el teléfono creaba uno nuevo cada día.
- **EL TECHO DE UNA DISPENSA ES EL MISMO AL CREAR Y AL EDITAR** (`Stock#techo_para_dispensa`,
  sep-2026). Lo libre del depósito, MÁS lo que la mesa de ese mostrador tiene arriba —para quien
  dispensa desde ahí no es un bloqueo, es su stock— MÁS lo apartado del evento del que sale la
  línea. Estaba escrito TRES veces y la tercera se quedó atrás: la edición validaba contra
  `cantidad_disponible_real` a secas, que resta la mesa entera, así que con el producto arriba
  —el caso normal del dispensario— daba SIEMPRE cero y editar rebotaba con «hay 0.0g» aunque no
  se tocara la cantidad. Cambiarle el medio de pago a la dispensa de ayer era imposible.
- **UNA RENDICIÓN VA DIRIGIDA A UNA PERSONA Y CAE EN UN CAJÓN** (sep-2026, decisión de Germán).
  Las dos mitades estaban rotas. `puedo_recibir` decía «cualquiera que no sea el repartidor», así
  que la que el repartidor le entregaba al dispensador le aparecía con su botón al admin, al
  supervisor y a todos los dispensadores — y `Recibir` **pisaba el receptor con el que apretaba**,
  o sea que elegir a quién rendirle no significaba nada. Y la caja se DEDUCÍA de las sedes del que
  recibía: con un admin (que no tiene sede) y dos mostradores abiertos daba `nil`, el cobro se
  marcaba rendido, el asiento se escribía y **no entraba a ningún arqueo**.
  **El destino lo dice una persona**, y quién lo dice depende del rol: el **dispensador no elige**
  (cae en la caja de SU mostrador; sin caja abierta no recibe y el cartel dice qué hacer) y
  **administración elige** entre los mostradores abiertos. Con un cajón disponible **no existe
  «queda en la organización»**: si se la lleva, la recibe en la caja y la **saca** después —eso es
  un retiro, ya existe, queda a su nombre y se salda cuando la trae—. Son dos registros en vez de
  una desaparición. **Sin ninguna caja abierta sí** entra a la organización: obligar ahí dejaría
  al repartidor volviéndose a su casa con la recaudación, que es peor.
  La regla vive en **`Rendiciones::DestinoEfectivo`** porque la preguntan las DOS puertas: la
  rendición que arranca el repartidor y el **«Recibir caja» de su ficha** (`club_users#recibir_caja`,
  sólo admin), que es la de «se fue sin rendir». Esa puerta también pregunta ahora en qué caja; el
  SERVICIO conserva la deducción para los llamadores internos, que no tienen pantalla donde
  preguntar.
- **EL REPARTIDOR TIENE QUE VER CUÁNTO LLEVA ENCIMA** (`GET /rendiciones/mi_caja`, sep-2026). El
  monto de la rendición lo pone el sistema —pedirle que se acuerde de lo que cobró en doce puertas
  es pedirle un error— pero nunca se lo mostrábamos: rendía a ciegas, sin poder contar los
  billetes contra nada, y si el que recibía contaba distinto se enteraba al día siguiente con la
  diferencia anotada a su nombre. Sale de la **misma consulta** que arma lo declarado
  (`Rendiciones::Rendir.cobros_en_transito_de`): escrita dos veces, un día dicen distinto y el que
  descubre la diferencia es él, contando billetes con alguien esperando. **Lo cobrado por
  transferencia va aparte y NO suma**: esa plata ya entró a la organización, y sumarla sería
  pedirle billetes que nunca tuvo.
- **LA PLATA NO VA EN EL INICIO DEL REPARTIDOR** (sep-2026, decisión de Germán: *"la caja que no
  se vea en el inicio… recordemos que esto es el celu, deberíamos ser simples"*). Esa pantalla se
  abre cuarenta veces por día para saber A DÓNDE IR, y arrancaba con la tarjeta de rendición
  —«Rendiste $200.000, esperando que la reciban»—, que es un recibo, no una tarea. Todo lo de la
  caja vive en su solapa. Y el contador «Entregados» era de TODA SU VIDA al lado de dos que eran
  de hoy: eso se mira en Historial, que tiene período. Por lo mismo `mis_paquetes` trae lo que
  está en la calle y no todos los paquetes que le asignaron desde siempre.
- **DOS FOTOS DISTINTAS NO PUEDEN TENER EL MISMO BOTÓN** (sep-2026). El modal de entrega decía
  «Subir / tomar foto» dos veces, con el mismo ícono y a quince renglones una de otra. Son dos
  cosas de verdad distintas —el comprobante de PAGO cuelga del `Cobro` y no se borra nunca; la
  foto de la ENTREGA se purga a los 30 días— así que no se saca ninguna: se las nombra («Subir
  comprobante» / «Subir / tomar foto»), y la de la transferencia aparece **sólo si hay
  transferencia**. Cobrando en efectivo no hay nada que fotografiar, y ése era el botón que
  sobraba nueve de cada diez veces. Si se borra el monto, la foto se descarta con él.
- **CONTAR NUNCA SUBE EL INVENTARIO, LO CUENTE QUIEN LO CUENTE** (sep-2026). Contar de más
  significa que sobre la mesa hay producto no anotado, y ese producto **salió del depósito**: ya
  estaba en el `Stock`, sólo cambió de lugar. `ajustar_inventario!` se lo SUMABA al `Stock` —
  producto trazable sin origen, disparado con un dedazo— y así se rompía el balance de la
  Trazabilidad: **"en stock" mayor que "producido"** y una **merma NEGATIVA**, porque el informe
  deduce la merma por resta y no tiene casillero para algo que entró. El candado existía desde
  septiembre pero **sólo miraba a quien atiende**; administración pasaba de largo por Contar y por
  Cerrar caja. **Subir la mesa es APARTAR**, y `mover!` tiene ahora el mismo tope que `Cargar`: no
  se aparta más de lo que hay libre (`devolucion` exenta: el paquete que vuelve ya se le devolvió
  al `Stock`). El **sobrante del arqueo** se anota y no se aplica, de nadie —el cierre no se traba
  nunca—; **contar de a uno** sí deja a administración subir la mesa, con el tope real. Para sumar
  stock de verdad está **editar el stock**, que es la puerta que deja el origen.
  `rake stocks:balance_descuadrado` encuentra lo que ya entró así.
- **UN INFORME SE DESCARGA SIEMPRE; PRESENTARLO ES OTRA COSA** (sep-2026, decisión de Germán). La
  app no es un canal oficial, así que lo que se baja es material de trabajo: negarle la descarga a
  la organización la dejaba sin poder ver su propia realidad. Son **dos caminos** y los pide quien
  descarga (`para_presentar`): normal → sale con la **salvedad impresa** nombrando qué no se puede
  acreditar; **para presentar** → valida y no sale si falta algo. Presentables: **INASE, semestral
  y REPROCANN**; **trazabilidad NO** —la pide un auditor en una inspección— y su salvedad nombra
  **sólo las variedades de ESA cadena**. **NO se vinculan genéticas automáticamente**:
  `declarada_como` **renombra la planta en el informe regulatorio**, así que vincular a ciegas es
  una declaración falsa firmada por un rake.
- **EL PIE DE LOS PDF NO LLEVA LA MARCA DE LA PLATAFORMA.** El documento es de la organización y
  lo firma ella; quién lo generó es asunto nuestro, no del auditor que lo recibe.
- **CON `responseType: 'blob'` EL ERROR TAMBIÉN LLEGA COMO BLOB**, así que ni el interceptor de
  `api.js` puede normalizarlo: hay que parsearlo (`await e.response.data.text()`). Estaba resuelto
  en `useInformePdf` y **tres vistas más se bajaban archivos por su cuenta con un `catch` pelado**,
  mostrando "reintentá en un momento" sobre un 422 que decía qué hacer. Vive en `lib/descargas.js`.
- **`toISOString()` ES UTC: NUNCA PARA DECIR "HOY"** (sep-2026). En Argentina da **mañana desde las
  21:00**, y el backend valida contra `Time.zone.today` en Buenos Aires — dispensar rebotaba con
  "la fecha no puede ser futura" todas las noches, en las horas de más movimiento del dispensario.
  Se dice con **`hoyISO()`** / **`toISO(fecha)`** de `utils/dates.js`, que arman la fecha con los
  componentes LOCALES, y con **`paraInputDatetime()`** para los `datetime-local` (ahí el desfase es
  de tres horas). Lo fija `hoyLocal.test.js`, que congela el reloj a las 23:30 ART: es un bug de
  tres horas por día y no se encuentra probando a mano.
- **EL RASTRO DICE QUÉ HIZO LA PERSONA, NO QUÉ FILAS ESCRIBIÓ LA APP EN SU NOMBRE** (sep-2026). La
  fila nombra el hecho —**"Entregó"**, no "Editó": `update` es el verbo de Rails, no el de nadie
  más— y **cuando el cambio se puede nombrar, los campos que lo componen no se repiten**. Vive en
  `AuditoriaSerializer` porque son dos consumidores. Los asientos contables que la app escribe
  detrás de cada dispensa (los que tienen `dispensacion_id`) se piden aparte: tapaban 8 de cada 10
  filas. Y **las imágenes de una entrega viven 30 días** (`PurgarAdjuntosEntregaJob`): se borra la
  imagen, nunca el registro, y queda el evento en `historial_envio` — si el hueco no hablara, una
  entrega vieja se vería idéntica a una donde nadie firmó. **El comprobante de PAGO no se toca**:
  lo trajo el paciente, no se regenera, y cuelga del `Cobro`, que usan también el mostrador y las
  reservas.
- **EL MOSTRADOR APARTA, NO DESCUENTA — y la dispensa TIENE QUE BAJAR LA MESA.** Si aparta y la
  dispensa no baja el `MostradorItem`, cae `cantidad` Y sigue apartado: el disponible baja el
  doble y el stock cargado se vuelve indispensable. Es el mismo bug que ya pasó con los eventos, y
  `Dispensacion#imputar_a_mostrador` es el gemelo exacto de `imputar_a_apartado_evento`. Hace DOS
  cosas y son distintas: baja la mesa (el estado permanente, lo que queda para el próximo
  paciente) y suma al contador del turno (el arqueo de esta jornada).
- **LO RESERVADO SALE DE LA MESA, NO DEL DEPÓSITO — y se cuenta UNA vez**
  (`Stock#apartado_para_mesa_y_reservas`, sep-2026). La reserva la hace administración y la
  mercadería se enfrasca recién AL ENTREGAR: entre una cosa y la otra el producto sigue
  físicamente sobre la mesa, **adentro** de los gramos que el mostrador ya tiene apartados.
  Restarlos otra vez contra el depósito los bloqueaba dos veces —1.000 en la fila, 110 arriba,
  reserva de 15, y el depósito quedaba en **875 donde hay 890**—. Es `max(mesa, reservas)` y no
  la suma: los dos apartados se pisan hasta donde llega el más chico, y si lo reservado supera
  lo que hay arriba el excedente sí bloquea depósito. **Sin columna nueva**: no hace falta marcar
  la reserva, la aritmética lo resuelve y las viejas se comportan igual. **La mesa NO se toca** —
  `MostradorItem#cantidad` sigue siendo lo que se pesa a la noche; lo que cambia es contra qué se
  descuenta. Y **la entrega ya bajaba la mesa** (`imputar_a_mostrador` corre también con
  `desde_reserva`), así que el invariante cierra solo: el depósito libre es 890 antes y después.
- **LO RESERVADO NO ES DE QUIEN ATIENDE PARA ENTREGAR** (`Stock#libre_en_mostrador`). Su carrito
  mostraba los 110 enteros con 15 apartados a nombre de un paciente: se lo llevaba el que llegaba
  primero y la reserva no se podía cumplir. Ve **lo libre** (95) en los DOS campos —muestra y
  valida contra `cantidad`— y la fila dice `reservado`, porque un número que baja sin motivo se
  lee como un error de la app. Mostrar 110 y que reste él es pedirle la cuenta que hace la
  máquina. Lo mismo suman `Dispensacion#stock_disponible` y `#lineas_validas`.
- **LA LISTA AL RESERVAR ES LA DE LA MESA DE ESA SEDE**, del mismo endpoint que la pantalla del
  mostrador — la mesa es una sola y preguntarla por otra puerta sería la misma verdad escrita dos
  veces. Si lo que se quiere reservar está en el depósito, **el camino es bajarlo a la mesa
  primero**, y el cartel de lista vacía lo dice con el link al lado: así queda bloqueado para la
  dispensa **y lo entrega el dispensador sin depender de admin ni supervisor**, que es el punto.
  (Decisión de Germán, sep-2026.) El payload de la mesa habla otro idioma (`stock_id`, `forma`,
  `genetica` como texto) y se traduce en `cargarMesa`, en un solo lugar.
- **EN EL PIE DEL TELÉFONO, EL TOTAL VA EN SU PROPIO RENGLÓN.** Eran tres cosas en una fila
  —`Cancelar`, el total, el botón— y el total es un número que NO se puede partir: con seis cifras
  no entra a ningún ancho, se salía de su caja y empujaba el botón fuera de la pantalla. Quedaba
  cortado justo el número que la persona le dice en voz alta al paciente. Lo cuida
  `e2e/pieDispensaTelefono.spec.js` a 320/360/390.
- **UN TEST DE ESTILOS SCOPED TIENE QUE VERIFICAR QUE EL CSS APLICÓ.** Los estilos de un componente
  Vue llevan `[data-v-xxxx]`: en un markup armado a mano sin ese atributo no aplica NI UNA regla y
  se termina midiendo el layout por defecto del navegador — verde por la razón equivocada. El caso
  saca el scope del propio CSS compilado y afirma `aplicaElCss` antes de medir nada.
- **LOS MODALES DEL MOSTRADOR NO SE CIERRAN AL TOCAR AFUERA.** Ahí se cuenta plata y mercadería:
  un click al costado borraba todo lo escrito sin preguntar y sin vuelta atrás. Se sale por
  **Cancelar o Escape** (`composables/useEscape.js`, en un solo lugar — cuatro listeners copiados
  sobre `document` son cuatro oportunidades de olvidarse de sacarlo al desmontar).
- **CORREGIR UN CIERRE INCLUYE LA PLATA, y asienta la corrección AL LADO.** El efectivo se cuenta
  mal igual que los gramos, y quedaba con el número equivocado para siempre —con su asiento de
  faltante en el libro—. Misma regla que el stock: el movimiento viejo no se borra, se anota la
  diferencia. Se puede corregir sólo la plata, sin tocar ningún producto.
- **ENTREGAR UNA RESERVA SE PUEDE COBRAR EN PARTES.** Estaba excluido con el argumento de que "la
  seña de una reserva es un pago único", que mezcla dos cosas: la seña se cobra al CREARLA; al
  entregarla se cobra el RESTO, que es una cobranza como cualquier otra. Lo que se reparte es el
  resto (`totalACobrar`), no el total de lo que se lleva.
- **UN SOLO TOAST POR ACCIÓN, Y LO CANTA QUIEN SABE SI SALIÓ BIEN.** La vista de reservas del
  teléfono festejaba además del modal: el mensaje salía dos veces y se leía como que la dispensa
  se registró dos veces. El susto es peor que el bug.
- **`npm run build | tail -N && …` SIGUE DE LARGO AUNQUE EL BUILD FALLE.** El estado de salida de
  una tubería es el del ÚLTIMO comando —`tail`, que siempre da 0—, así que la suite corre en verde
  sobre el `dist/` viejo y las verificaciones de navegador prueban el bundle anterior. Ya pasó:
  el build estaba roto por un `}` de más en un CSS y sólo se descubrió porque una solapa nueva no
  aparecía en pantalla. Correr `npm run build` sin tubería, o mirar el exit code.
- **EL GRÁFICO DEL MOSTRADOR ES UNO POR PRODUCTO, CADA UNO CON SU ESCALA** (`evolucion`,
  sep-2026, idea de Germán). Por producto **no hay nada que sumar** —un total mezclaría gramos de
  flor con unidades de preroll, que es el problema que arrastra todo el módulo— y la escala propia
  es lo que hace visible **el goteo**: un gramo que falta casi todos los días, que en un eje
  compartido con la flor a 400 g no existe y es el que sangra sin disparar ninguna alarma. Un
  gráfico con todas las líneas juntas se descartó: muestra el peso relativo del stock, que la
  tabla de la mesa ya da con números exactos, y esconde la pregunta de la pantalla.
- **CIERRES SE AGRUPA POR DÍA, Y EL DETALLE VA EN LA FICHA DEL CIERRE.** El encabezado del día
  trae el saldo, así el caso normal —un cierre— no obliga a abrir nada. Y la ficha es **la misma
  donde se corrige**: qué pasó y los números para arreglarlo en un solo lugar.
- **EL ADMIN SABE DE CULTIVAR, NO DE ARQUEOS.** Es la regla que ordena el texto de todo el
  módulo: «cuadró», «arqueo», «a costo», «esperado» son palabras de contador y cada una es un
  peaje. Se dice `no falta nada`, `el conteo`, `producirlos costó $X`, `lo que tenía que haber`. Y
  el porcentaje se dice como se dice: **`se pierden 7 de cada 1.000 que salen`**, no `0,7%`. Se
  quedan **merma** (palabra de campo) y **cierre** (lo eligió Germán). Decisión de sep-2026, sobre
  un prototipo navegable que revisó antes de que se escribiera código.
- **CADA CIERRE CUENTA QUÉ PASÓ, CON LA CUENTA A LA VISTA.** No `$27.636,6 · en 1 producto` —cinco
  celdas sin sujeto y el dato accionable ausente— sino *«Faltan 23 g de Critical Kush L-26-017.
  Sobre la mesa tenía que haber 46 g y al contar aparecieron 23»*. **El producto por su nombre** es
  lo único con lo que se puede ir a buscar algo, y sin el esperado el número no se puede
  comprobar. Por eso el payload manda `faltaron`/`sobraron` (CUÁLES, con esperado y contado) y el
  detalle de la caja (fondo y esperado), no sólo totales.
- **UNA CAJA PUEDE CRUZAR LA MEDIANOCHE.** `14:02–12:03` se leía como que cerró antes de abrir:
  se mostraba sólo la fecha del CIERRE con las dos horas al lado. Se dice `del sábado` cuando
  abrió otro día. Una fila imposible hace desconfiar de toda la tabla.
- **LA SOLAPA DE MERMA ES UNA LÍNEA Y UNA LISTA** (sep-2026, rediseño acordado con Germán). El
  titular **arranca por el número** —`Faltaron $10.000 en 1 cierre.` / `Cuadró todo.`— y la
  comparación contra el historial va debajo y **sólo cuando dice algo**: antes el cuadro empezaba
  diciendo que el porcentaje no significaba nada, con los pesos faltantes escondidos en un pie
  gris. La lista se **ordena por PLATA**, que es lo único comparable entre productos y que existe
  siempre; el % es contexto de la fila, nunca una columna, porque desaparece cuando no se vendió
  nada y dejaba la tabla llena de `–%`. Y **faltar producto de algo con CERO entregado no es
  merma**: la fila lo dice ("no se entregó nada de esto"), porque es producto que desapareció sin
  venderse y es más urgente que cualquier porcentaje.
- **LA LISTA DE TRABAJO VIVE EN CIERRES, NO EN MERMA.** "Para mirar" era la misma lista de cierres,
  filtrada, con otro nombre y en la solapa de análisis. Es un filtro (`Todos` / `Para mirar N`) con
  el motivo en la fila y "Ya lo miré" al lado de "Corregir conteo". **Un chip, el que manda**
  (`faltante > sobrante > mesa_movida > corregido`): tres juntos obligan a leer los tres para saber
  cuál importa. Los ids salen del MISMO `Mostradores::MotivosDeRevision` que el badge — si el
  filtro decidiera por su cuenta, un día el badge diría 2 y la lista otra cosa.
- **SI UNA PANTALLA NECESITA DEFENDER SU PROPIO ORDEN, NO ES EVIDENTE.** Las dos frases más largas
  de la solapa de Merma explicaban por qué la lista se ordenaba así y por qué la sección se llamaba
  así. Eran verdad las dos y las dos se cayeron con el rediseño: ordenar por plata no necesita
  explicación. Vale como olfato — texto que justifica una decisión de diseño es el síntoma, no la
  cura.
- **`reservado` ES DEL PRODUCTO, NO DE LA MESA — y por eso tiene columna propia.** Colgado como
  cartelito debajo del input de Mostrador decía «mostrador 0 · 15 reservados», que es imposible:
  esos 15 g están en el depósito (que ya los descontó). Un número correcto en la columna
  equivocada se lee como un error de la app. Van `Reservado` y `Libre` como columnas, sólo para
  administración —mismo criterio que Costo y Depósito—, y **`Libre` es EL MISMO número que el
  carrito** (`disponible_para_entregar`): si significara otra cosa acá, la misma palabra diría dos
  verdades en dos pantallas.
- **EL KPI DE LA MESA DICE CUÁNTO HAY, NO CUÁNTO VALE**, y **agrupado por unidad**: 300 g de flor
  más 12 prerolls no son 312 de nada. El valor en pesos no es una decisión que se tome en el
  mostrador, y al lado de "en caja tendría que haber" se leía como plata a contar. Sin desglose
  plegable: la tabla de abajo ya es el detalle.
- **ORDENANDO POR LA COLUMNA MOSTRADOR SE APAGA EL AGRUPADO PREVIO.** La tabla pone arriba lo que
  está sobre la mesa, pero si el orden pedido ES esa columna, ese agrupado lo rompe: de menor a
  mayor daría `40, 200, 0, 0`. Y ordena por lo GUARDADO, nunca por lo que se está escribiendo en
  el input — la fila saltaría de lugar mientras se tipea.
- **EN DESARROLLO, `localhost:5173` PUEDE SER `vite preview` Y NO `vite dev`**: sirve el `dist/`,
  no el código. Toda verificación con Playwright necesita `npm run build` antes, o se está
  probando el bundle viejo y las conclusiones son basura. Ya costó media sesión.
- **LA APP NO ELIGE POR VOS EN QUÉ MOSTRADOR ESTÁS** (sep-2026). Se entra directo sólo cuando no
  hay nada que adivinar: una sola sede que atienda, la suya (`dispensario_sede`), la que vino por
  `?sede=`, o la última que eligió (recordada en `localStorage`). Con varias y ninguna razón para
  preferir una, **se pregunta** — antes caía en `sedes[0]`, la primera alfabética, en la pantalla
  donde se carga la mesa y se abre y cierra caja. Y no era un caso raro: `dispensario_sede` nace
  en null. **Elegir no es un peaje**: cada sede se ofrece con su estado (caja abierta desde cuándo
  y con quién, qué hay arriba, cuántos cierres para mirar), que es lo que administración viene a
  buscar cuando entra a monitorear. Sale de `GET /mostradores`, que cuelga del CLUB y no de una
  sede: «¿cómo viene cada uno?» es la pregunta que no se puede hacer parado dentro de una.
- **UN `watch` NO DISPARA DE `null` A `null`.** Al dejar `sedeId` sin resolver a propósito, nadie
  recalculaba `cargando` y la pantalla quedaba en el esqueleto para siempre, con la lista de sedes
  lista e invisible detrás. Todo estado que se deja deliberadamente en su valor inicial necesita
  que alguien vuelva a pasar por el cálculo a mano.
- **CUÁL ES "MI MOSTRADOR" LO CONTESTA `sedeDeMostrador`, Y NADIE MÁS** (sep-2026). La suya
  (`dispensario_sede`) si atiende público; si no tiene asignada —**la columna nace en null y casi
  nadie la carga**— la primera que atienda. El carrito de la dispensa la resolvía por su cuenta
  leyendo `dispensario_sede` a secas: con la columna vacía cortaba antes de preguntar y daba la
  caja por ABIERTA, mientras la lista de productos aparecía igual (el backend la arma con
  `sedes_visibles_ids`). El dispensador cargaba el carrito entero con la caja cerrada y se
  enteraba al confirmar, con el admin viendo "Caja cerrada" en su pantalla. Vive exportada al lado
  de `gestionaMostrador`, por lo mismo: son las dos preguntas que no pueden tener dos respuestas.
- **EL TECHO DE UNA DISPENSA ES `disponible_para_entregar`, NUNCA `cantidad`.** La fila del stock
  puede tener gramos apartados para un evento o reservados a nombre de un paciente: el carrito
  ofrecía 1.000 y el backend rechazaba en 985. Es `cantidad − eventos − reservas` —la mesa es un
  LUGAR, no un compromiso, y por eso no resta— y da exactamente lo mismo que
  `Dispensacion#stock_disponible`, que es el punto: la pantalla pide el número que el backend va a
  validar. Y cuando hay algo reservado, el número **dice "libres"**: sin esa palabra, "165g" con
  "15g reservados" al lado se lee mal en los dos sentidos.
- **NO SE CREA EL `MostradorItem` SOLO AL RESERVAR** (evaluado y descartado, sep-2026). Subir a
  la mesa lo reservado del depósito no hace falta —**el dispensador YA entrega una reserva sin que
  el producto esté arriba**, `desde_reserva` es la excepción documentada y sólo pide la caja
  abierta— y **rompe el arqueo**: la mesa es lo que se PESA a la noche, así que 15 g que nadie
  movió dejan el ítem en 125 con 110 arriba y el cierre los descuenta como faltante real. Como la
  reserva es mínimo para mañana, pasaría en todos los cierres del medio.
- **LA MESA DICE CUÁNTO YA TIENE DUEÑO** (`reservado`, en `serialize_stock` del mostrador para que
  lo tengan las dos listas: la mesa y lo que se puede subir). En la tabla, **siempre y también en
  cero**, apagado — un número que aparece de la nada el día que hay una reserva no se aprende a
  mirar. En el teléfono sólo cuando hay algo: esa pantalla es de UNA línea por producto a
  propósito, y el cero se lee en la hoja del frasco.
- **EL FORMULARIO DEL MODAL VA ARRIBA DE TODO LO QUE LO LEE.** Los `computed` de `<script setup>`
  son perezosos y aguantan referenciar algo de más abajo, pero un `watch` evalúa su fuente AL
  REGISTRARSE: `stocksVisibles` tiene uno, y desde que la lista de reservar sale de la mesa esa
  cadena termina leyendo `form.es_reserva`. Declarado después, la pantalla ni abría. Es la misma
  trampa que mordió al partir la dispensa en pasos, y se cierra **de raíz** poniendo el estado
  primero en vez de acomodar cada `watch` a mano.
- **LO QUE ADMINISTRACIÓN BAJA A MEDIA TARDE TAMBIÉN CUENTA EN EL ARQUEO.** Los renglones del
  turno (`TurnoMostradorItem`) se crean al ABRIR, con lo que había entonces, e `imputar_a_mostrador`
  los BUSCABA: un producto agregado después se dispensaba —la mesa es el estado de AHORA, no la
  foto de la mañana— pero lo entregado no se sumaba a ningún lado. El faltante seguía cuadrando
  (el esperado sale de la mesa), así que no se veía; lo que salía mal era el **porcentaje de
  merma**, que dividía por un "entregado" más chico. Ahora es `find_or_create_by!` con
  `cantidad_apertura: 0`, que es la verdad: a la mañana no estaba.
- **BAJAR DE LA MESA NO ES SIEMPRE "VUELVE AL DEPÓSITO".** Cada línea que baja lleva `destino`:
  `deposito` (por defecto, libera el apartado y el `Stock` queda entero) o `merma` (sale del
  inventario con `StockMovimiento` tipo `merma`). Sin esa distinción, bajar 12 g porque se
  perdieron los devolvía al depósito: quedaban contados como existentes y la pérdida no se medía
  en ningún lado. **No choca con "el ajuste del arqueo NUNCA es merma"**: aquella regla existe
  porque un CONTEO no sabe qué pasó (lo que falta puede estar en el depósito); acá lo declara una
  persona. Subir nunca puede ser merma, y no se puede declarar más de lo que hay.
- **NO SE PUEDE ENTREGAR ALGO QUE TODAVÍA NO EXISTÍA** (`Dispensacion#fecha_no_anterior_al_producto`).
  Se compara contra `fecha_elaboracion` y NO contra `created_at`: una carga retroactiva es
  legítima y bloquearla dejaría afuera el trabajo de poner la historia al día. **Sin atajo**: el
  modal ofrece corregir la fecha de la dispensa o ir a corregir la del producto por su propia
  puerta. Cambiar la del stock desde la dispensa mueve su vencimiento, su orden de salida del
  depósito y el rendimiento de su lote — y si vino de una pesada, falsea el dato del cultivo.
- **EL ASIENTO CONTABLE ES IDEMPOTENTE** (`AplicarEfectos#asiento`), como el débito de cuenta
  corriente. Un ingreso repetido no deja hueco que mirar: no falta una fila, sobra. **Sin índice
  único en la base a propósito**: `RegistrarCobro` asienta por COBRO y una dispensa puede tener
  dos cobros del mismo medio (pagó una parte hoy y otra mañana).
- **"SIN CONEXIÓN" NO ES "NO CONTESTÓ A TIEMPO".** Los dos llegan sin `response`, pero el timeout
  significa que el pedido SALIÓ y la dispensa puede haber entrado. Decir ahí "no se registró,
  volvé a intentar" es pedir que se duplique una venta: se avisa que PUEDE haber quedado y se
  manda a mirar el historial.
- **DENTRO DEL SHELL SE NAVEGA POR EL SHELL.** Un link fijo a `/mostrador` desde una pantalla `/m`
  saca al usuario del envoltorio móvil y lo deja en la versión de escritorio, sin barra de abajo.
  El guard de PWA sólo corrige la app INSTALADA; en el navegador del celular esa ruta es válida y
  no hay nada que corregir. Los links de una tarjeta que vive en los dos lados miran `route.path`.
- **SIN SEDE DE ATENCIÓN NO HAY MOSTRADOR, Y HAY QUE DECIRLO** (`useMostrador#faltaSede`). El
  mostrador vive en una sede `social`/`mixta`: sin ninguna, `sedeId` queda en null, la pantalla se
  dibujaba como si todo estuviera bien —caja cerrada, mesa vacía— con "Abrir caja" habilitado, y
  abrir pegaba a `/sedes/null/mostrador/abrir`. Apareció probando en producción con el dispensador
  del Club Modelo. **Son DOS causas y el cartel dice la que corresponde**, porque se arreglan en
  lugares distintos: le asignaron sólo sedes que no atienden público (se corrige en su ficha) o la
  organización no tiene ninguna (se corrige en Sedes). Un cartel que manda a arreglar lo que no
  está roto es peor que no tener cartel. `motivoSinSede` los distingue mirando si ve sedes pero
  ninguna atiende.
- **LA PANTALLA DEL MOSTRADOR ARRANCA EN LA SEDE PROPIA** (`dispensario_sede`), no en la primera
  de la lista: quien atiende abre la caja en su mostrador, y aterrizar en otra sede le muestra una
  mesa vacía y ninguna caja abierta — la pantalla diciéndole que no hizo lo que acaba de hacer.
- **LA MERMA ES INEVITABLE Y NO ES CULPA DE NADIE.** El mostrador se cuenta para que la
  organización sepa cuánta hay y dónde, y encuentre sus cuellos de botella — no para señalar a
  alguien. El texto visible tiene que sonar así: una diferencia es un dato que se anota, no una
  falta que alguien explica. Nada de rojo, nada de "la diferencia es tuya", nada de "sin
  supervisión". El número que manda es el **porcentaje sobre lo entregado**, no los gramos: un
  ranking absoluto siempre encabeza con lo que más se vende y no dice nada.
- **`alertas_config` SE MERGEA, NUNCA SE REEMPLAZA** (`PreferencesController#update`). La escriben
  varias pantallas y cada formulario manda sólo SUS claves: reemplazando el jsonb entero, guardar
  en una borraba en silencio lo de la otra. Es la peor forma de perder una configuración — no
  falta un registro, cambia solo lo que la app hace, y se descubre porque un aviso deja de llegar.
- **LA HORA LÍMITE DE CIERRE VIVE EN `Club#hora_limite_cierre_mostrador`**, y la preguntan el job
  que avisa y la pantalla que la muestra. General para la organización y por sede cuando alguna
  cierra distinto; devuelve nil cuando está apagada, porque no avisar es un estado válido.
- **UN ARREGLO QUE NO LLEGA AL TELÉFONO NO EXISTE** (`main.js`, sep-2026). La PWA se actualiza
  sola, pero el navegador pregunta por una versión nueva **una sola vez: al registrar el service
  worker**, o sea al arrancar en frío — y una PWA instalada casi nunca arranca en frío. Se pregunta
  también **al volver a la app** y cada media hora. **Y no se recarga encima de alguien que está
  trabajando**: si hay un diálogo abierto (`hayAlgoAbierto`) se posterga, porque recargar con una
  dispensa a medio cargar es peor que estar una hora desactualizado.
- **LA DISPENSA EN EL TELÉFONO VA EN DOS PASOS** —qué se lleva y cómo paga— y **es la misma pantalla
  con otra distribución**, no otra pantalla: un solo componente, la lógica una sola vez (mismo
  patrón que `useMostrador`). La cantidad vive en la barra de abajo, pegada al pulgar y al producto
  que se acaba de tocar, y **no se repite** en el formulario. `v-show` y no `v-if`, para que lo
  cargado sobreviva a ir y volver. Sin pasos en el escritorio ni en reservas.
- **UN `watch` DESPIERTA A UN COMPUTED PEREZOSO.** En `<script setup>` los `computed` no se evalúan
  hasta que alguien los lee, así que uno puede referenciar algo declarado más abajo; un `watch`
  sobre ese computed **lo evalúa al registrarse** y ahí explota con `Cannot access before
  initialization` — la pantalla no abre. Pasó al partir la dispensa en pasos.
- **EN DESARROLLO, LOCALHOST NO SE THROTTLEA** (`rack_attack.rb`). El tope de sign-in son 5 por
  minuto y la suite de punta a punta hace siete logins: la corrida entera fallaba en un lugar que no
  tenía nada que ver. Una suite que falla por el ambiente enseña a ignorar los rojos. En producción
  el candado no se toca.
- **EL MODAL EN UN TELÉFONO ES LA PANTALLA, y se verifica EN un teléfono.** `ModalNuevaDispensacion`
  se rompía a ≤360 px de tres formas —el pie desbordado con "Cancelar" afuera, la lista con
  `max-height` fijo scrolleando tres píxeles (tarjetas cortadas = lo que se lee como "solapado"), y
  el aviso con `display:flex` partido en columnas por el link de adentro— y **ninguna se ve leyendo
  el CSS ni en un test de jsdom**: se reprodujeron con Playwright a 320/360/390 px sobre la app
  corriendo. Cualquier caja de texto con un enlace adentro va en `display: block`.
- **EL VEREDICTO DE LA MERMA VIVE EN UN SOLO LUGAR** (`Mostradores::Veredicto`, sep-2026): la
  última semana contra las ocho anteriores DE ESA organización, con pisos de historia (8 turnos) y
  de volumen (200 g) y factor 2. La regla estaba escrita adentro de `MermaMostradorJob`, así que el
  admin recibía el mail diciendo "algo cambió", entraba a mirar y **la pantalla no le decía nada de
  eso**. Ahora la preguntan los dos. El veredicto mira **siempre la última semana**, no el rango
  elegido en la solapa: si cambiara con el filtro no se podría comparar con nada. Y **siempre
  devuelve un estado** —`sin_historia`, `poco_volumen`, `sin_datos`— porque quedarse en blanco se
  lee como que está todo bien.
- **LA MERMA SE CORTA TAMBIÉN POR PERSONA, Y NUNCA COMO RANKING PELADO** (sep-2026, decisión de
  Germán: para ajustar hay que poder mirarlo). El reparo no es moral sino estadístico —quien más
  volumen mueve encabeza siempre, y quien fracciona flor pierde más que quien entrega prerolls—,
  así que la fila SIEMPRE lleva las tres cosas que evitan leerla mal: **`contra_promedio`** (el
  mismo mostrador, el mismo período, en PUNTOS y no en veces), el **volumen**, y **`suficientes`**
  (piso de 3 turnos; debajo se muestra igual pero sin conclusión y sin pintar la diferencia).
  **Se atribuye a quien ATENDIÓ = quien ABRIÓ**: la diferencia se produce durante la jornada, no
  al contarla. Si cerró otro, la fila lo dice (`cerro_otro`) — si no, el admin lee el número de
  alguien que no hizo ese arqueo. Sigue valiendo el tono: se mide para encontrar cuellos de
  botella, y el texto de la pantalla tiene que sonar así.
- **AL CERRAR LA CAJA, LOS CAMPOS LLEGAN CON UN NÚMERO** (sep-2026): el efectivo con lo esperado y
  el fondo con lo mismo ("dejo todo"), que es lo que la pantalla ya le dice a quien no puede
  retirar — vacío, el modal le anunciaba un retiro A SU NOMBRE que él no puede hacer y tenía que
  volver a tipear lo que acababa de contar. A administración el fondo NO se le llena: ella sí se
  lleva la recaudación. **Y NO ES UNA APUESTA: EL ESPERADO NO ES UN SECRETO**, es una cuenta —fondo
  inicial + lo cobrado EN EFECTIVO (lo de cuenta corriente y transferencia nunca entró al cajón) +
  otros ingresos en efectivo (una deuda que pagó, una seña, la rendición del repartidor) − los
  retiros— que cualquiera puede hacer, y que además la pantalla ya muestra al lado del campo desde
  que se decidió mostrar lo esperado. Esconderlo del campo no protegía nada: sólo obligaba a
  tipear un número que el sistema ya sabe. **Razonamiento de Germán, sep-2026** — si aparece en un
  comentario viejo el argumento contrario ("un campo lleno invita a confirmar sin contar"), es
  legacy y esto lo reemplaza.
- **CORREGIR UN CIERRE SE CALCULA CONTRA LO ESPERADO, NO CONTRA LO CONTADO**
  (`TurnoMostradorItem#efecto_en_inventario`). Restar lo viejo y sumar lo nuevo sólo vale si lo
  viejo se aplicó, y el sobrante de quien atiende queda ANOTADO sin aplicarse: corregir un cierre
  de 1.000 —donde había 500— a los 100 reales descontaba **900 g que nunca entraron**, en vez de
  los 400 que faltaron. Todo lo que haga cuentas contra `cantidad_cierre` tiene que preguntar
  primero si eso movió algo.
- **CONTAR NO CREA PRODUCTO DE LA NADA** (sep-2026). `ajustar_inventario!` con diferencia
  positiva SUMA al stock del club: contando 997 donde había 100 entraban 897 g **trazables que
  nadie cargó**. Es una puerta de entrada de producto sin origen y se dispara con un dedazo.
  **Quien atiende no puede declarar un sobrante** — él no elige qué hay sobre la mesa, la carga
  administración, y si de verdad sobra lo carga ella por su puerta, que descuenta del depósito.
  Son **TRES puertas** y se comportan distinto **a propósito**: `Contar` de a uno lo RECHAZA (no
  bloquea nada, sigue atendiendo); el CIERRE y la APERTURA lo ACEPTAN sin aplicarlo —guardan lo
  contado, no tocan nada y el turno cae en la lista de trabajo como `sobrante`— porque trabar el
  cierre dejaría la caja sin poder cerrarse a las once de la noche, y trabar la apertura dejaría
  el mostrador cerrado a las ocho de la mañana. El faltante se aplica siempre: restar lo que no
  está no inventa nada. Administración sí puede subir contando.
  **LA APERTURA ERA LA PUERTA MÁS GRANDE**, y parecía la más inocente: corregir al abrir "no toca
  el inventario", pero **sí mueve la mesa, y la mesa está APARTADA**. Subirla a 1.500 con 1.000 en
  la fila del `Stock` dejaba `Dispensacion#stock_disponible` —que suma `apartado_en_mostrador_de_sede`—
  autorizando 500 g que no existen, y `decrement!` no valida: la fila terminaba **en negativo**,
  con la mercadería ya afuera. Por eso `AbrirCaja#sobrante_sin_aplicar?` es el gemelo exacto del
  de `CerrarCaja`. **La mesa sólo se corrige HACIA ABAJO** cuando la cuenta quien atiende.
  Y `corregido` pasó a significar exactamente eso —la mesa que efectivamente bajó—: llamar
  "corregido" a un conteo que no corrigió nada es el tipo de etiqueta que hace que nadie mire la
  lista.
- **QUIEN ATENDIÓ ES EL QUE ABRIÓ *O* EL QUE CERRÓ.** La caja es del mostrador, no de una
  persona: es normal que la abra el admin a la mañana y la cierre contando quien atendió todo el
  día. Filtrando los turnos sólo por `abierto_por_id`, ése cerraba su arqueo y la pantalla le
  decía "todavía no cerraste ningún turno acá" — justo lo que necesita si al día siguiente le
  preguntan por una diferencia que él anotó.
- **LOS ARQUEOS SE MIDEN EN PLATA, NO EN CANTIDAD.** `faltante` y `dispensado` SUMAN unidades
  distintas: "faltó 23" eran 23 g de flor más 4 prerolls, un número que no significa nada y que
  no se compara entre turnos. La tabla de turnos muestra los pesos y en cuántos productos faltó;
  el CSV sí lleva las dos cosas, porque lo abre alguien que va a analizar, no a leer de un
  vistazo.
- **El ajuste del arqueo NUNCA es `merma`.** Es una corrección de conteo y va como `ajuste` con
  motivo obligatorio. El informe de Pérdidas cuenta `merma`: anotarlo ahí declararía destruido
  producto que puede estar entero. Corregir AL ABRIR no toca el inventario en absoluto — todavía
  no se sabe si faltó de verdad, y lo que se cargó de más puede estar en el depósito.
- **SACAR UN PRODUCTO DE LA MESA NO BORRA SU FILA.** Se pone en CERO y el scope
  `MostradorItem.con_stock` deja de listarlo — un renglón en cero es un pendiente eterno que hay
  que volver a explicar cada vez que alguien mira, pero **destruir la fila se lleva puesto, por
  `dependent: :destroy`, el `MostradorMovimiento` que dice quién lo sacó y por qué**: justo lo que
  se quería guardar. Todo lo que recorra la mesa tiene que usar ese scope.
- **QUÉ ES un producto se corrige, salvo con el EJERCICIO CERRADO.** `forma_producto` y `unidad`
  son editables (un stock cargado como `prensado` porque no existía `preroll` no puede quedar mal
  para siempre), pero si ese stock ya se dispensó dentro de un período contable cerrado
  (`clubs.contabilidad_cerrada_hasta`) el cambio se rechaza: reinterpretaría cantidades ya
  asentadas. Primero se reabre el período. **Se cuentan las DOS formas de dispensar** —
  `dispensaciones.stock_id` y `DispensacionItem`— en una sola query con OR y contando
  dispensaciones distintas: una dispensa de un producto queda escrita en los dos lados.
- **EL QUE ATIENDE NO ELIGE QUÉ HAY SOBRE LA MESA: LA CUENTA.** La mesa la carga administración
  (`Cargar`, gestiona-only) y él abre contando lo que encuentra. Esto reemplazó a la regla vieja
  de "abre con lo que heredó y puede corregir para abajo", que existía sólo porque abrir ERA
  poner mercadería: con la mesa permanente no hay nada que elegir al abrir.
- **Y NO VE EL DEPÓSITO: LO PIDE** (sep-2026, decisión de Germán que REVIRTIÓ la regla anterior —
  si aparece en un comentario viejo que "ver el depósito no se le tapa", es legacy). Cuánto hay
  guardado no es asunto suyo; lo que necesitaba de ahí era saber qué pedir, y para eso está el
  botón **Pedir reposición** (`mostrador#reponer`), que le avisa por campana y push a **admin y
  supervisor** en vez de dejarlo avisando por fuera de la app. Le llega **una sola fila de alerta
  marcada para supervisor**: el admin ve todas las de su organización, así que con dos filas la
  vería repetida. **Uno por producto y por día**, o la campana se llena del mismo aviso. El
  backend le manda **`hay_en_deposito` (sí/no), nunca `disponible`** — lo justo para no pedir lo
  que no hay—, y `StocksController#index` le muestra la MESA también fuera del carrito: antes el
  filtro aplicaba sólo con `para_dispensa` y su pantalla de Stock le mostraba el depósito entero.
  En el nav del teléfono, **Historial** ocupa el lugar visible y Stock queda en "Más".
- **EL MOSTRADOR DE OTRA SEDE NO SE TOCA.** `set_mostrador` y `CajasController#set_sede` filtran
  por `current_user.sedes_visibles_ids`: sin eso, un dispensador de Norte abría y cerraba el
  mostrador de Centro mandando otro `sede_id`. La pantalla sólo le ofrece las suyas, pero la
  pantalla no es la regla. (Sin sedes asignadas se ven todas: organización de una sola sede.)
- **"Sin stock disponible" es MENTIRA para el que atiende.** Con el mostrador cerrado, el
  dispensador ve el carrito vacío y el depósito está lleno: el mensaje tiene que decir que no hay
  nada sobre la mesa y dónde se arregla. Es el único lugar donde el frontend mira el rol para el
  mostrador, y sólo elige el TEXTO — la regla vive entera en `User#atiende_mostrador?`.
- **EL CARRITO DE QUIEN ATIENDE MUESTRA LO DE LA MESA EN LOS DOS CAMPOS.** `StocksController#index`
  pisa `cantidad` **y** `cantidad_disponible_real` con lo que hay arriba: el carrito muestra y
  valida contra `cantidad` (el frasco entero), así que pisar sólo el otro le decía "1.000 g" con
  300 sobre la mesa y lo dejaba cargar 500 para que el backend se lo rechazara al confirmar. Al
  admin NO se le pisa: dispensa del depósito entero y mostrarle la mesa le escondería lo que sí
  puede entregar.
- **LA CAJA CERRADA SE AVISA AL ABRIR EL CARRITO, NO AL CONFIRMAR.** Como la mesa es permanente, el
  producto sigue estando con la caja cerrada y la lista se llena igual; `Dispensacion
  #mostrador_abierto` recién rechaza al final, con el paciente enfrente. `ModalNuevaDispensacion`
  consulta el estado del mostrador al abrirse (sólo si quien dispensa atiende y tiene sede),
  avisa arriba de todo con el camino y deshabilita confirmar. **Si la consulta falla no traba
  nada**: el backend sigue siendo el que decide, y trabar por un request que no salió es peor.
- **UNA CAJA ABIERTA POR ERROR SE ANULA, Y ESO DESHACE LAS DOS COSAS.** Abrir crea la caja de
  plata Y el turno de mercadería, así que `CajaTurno#anular!` tiene que deshacer las dos: anulando
  sólo la caja, el turno quedaba abierto apuntando a una caja anulada y el mostrador no se podía
  ni reabrir —decía que ya había uno— ni cerrar —el cierre le pedía el arqueo a una caja que ya no
  estaba—. El turno se BORRA, no se cierra: nunca fue un turno, y dejarlo cerrado lo metería en la
  lista y en el cálculo de merma con un arqueo que nadie hizo. Si ya se dispensó, no es una
  apertura equivocada: se cierra con su arqueo. **La mesa no se toca** — es del mostrador y el
  producto sigue físicamente ahí.
- **`Sede#mostrador` LEE y `Sede#mostrador!` CREA.** Estaban en el mismo método: un `GET` que
  escribe en la base es una sorpresa que se paga cara.
- **Lo que el repartidor se quedó tiene que poder DEVOLVERSE** (`Rendiciones::SaldarACuenta`), y lo
  registra quien la recibe, nunca él — sería firmar su propio recibo. Entra al cajón como
  `ingreso_caja` y el saldo baja con un espejo `devolucion_a_cuenta`: **no es un ingreso del club**,
  esa plata siempre fue suya. Sin esto el saldo se acumulaba para siempre y no había forma de decir
  "ya la devolvió".
- **El mostrador es de quien ATIENDE, y ese es el DISPENSADOR y nadie más**
  (`User#atiende_mostrador?`). Admin y **supervisor** son administración: cargan la mesa, la
  arquean, retiran la recaudación y dispensan del depósito entero con o sin turno abierto. El
  supervisor estaba de los dos lados —administración para ver la merma y para llevarse la plata,
  "el que atiende" para dispensar—, o sea la misma persona cambiando de rol según qué pantalla
  mirara. Si administración saca algo que SÍ está arriba, se imputa igual al turno: que no pase
  por el mostrador no significa que el mostrador lo ignore. **Esa regla gobierna dos cosas a la
  vez** —el catálogo del carrito (`StocksController#index`) y la validación de `Dispensacion`— y
  por eso vive en un solo método: separadas, la pantalla ofrece lo que el backend rechaza.
  Y hay dos excepciones a "sólo lo que está sobre la mesa", las dos porque ya están apartadas a
  nombre de alguien y por eso no pueden estar arriba: la entrega de una **reserva** y lo apartado
  para un **evento**.
- **El cierre del mostrador NO espera al admin.** Si quedara pendiente de su visto bueno, a las
  once de la noche el mostrador está bloqueado y el que abre mañana no arranca. El aval es
  asincrónico. Misma lógica que el cierre de un reparto.
- **TODO PAQUETE QUE VUELVE SE DESARMA.** No se elige: es una decisión de CALIDAD, no de
  inventario. Un paquete que estuvo en la calle no se guarda armado esperando otro intento —
  cuando se despache de nuevo se arma en el momento, y para entonces puede haber cambiado hasta
  la forma de entrega (que lo pase a buscar por la organización). Al recibir la rendición, cada
  fallido de ese repartidor pasa por `Dispensaciones::Cancelar` —la misma reversa de siempre,
  extraída del controller para no escribirla dos veces— y su producto **sube a la mesa aunque ese
  frasco no estuviera arriba, si hay alguien atendiendo** (`Dispensacion#subir_al_mostrador`): si
  no, el gramo volvía al depósito y el que atiende no lo tenía para el próximo que lo pidiera, con
  el paquete ahí adelante. Cuando se despache de nuevo es una dispensa NUEVA.
  **`reprogramar` sigue existiendo** para el reintento del MISMO viaje —falla a las 18 y vuelve a
  intentar a las 19 sin pasar por la base—: ahí el paquete nunca volvió.
- **Lo que el repartidor tiene del club se ve ACUMULADO en su ficha** (`stats.a_cuenta`, donde ya
  vivía `caja_delivery`). Suelto, cada faltante parece un caso aislado y nadie nota que van seis
  meses seguidos. Se muestra como saldo, no como gasto: esa plata existe y se reclama.
- **LA PLATA NUNCA QUEDA EN EL AIRE.** En la rendición del repartidor no hay estado "en disputa":
  es efectivo, el que cuenta es el que la tiene en la mano y ese número entra al cajón, siempre.
  Lo que queda pendiente si el receptor ajustó es la CONFORMIDAD del repartidor —constancia, no
  candado— y va a la bandeja del admin, que es donde una diferencia de efectivo se resuelve:
  hablando. Un estado bloqueante dejaría plata que no está en ningún lado.
- **La rendición SÓLO se ajusta hacia abajo.** Si el repartidor trae MÁS de lo que figura cobrado,
  es que un cobro no se cargó: eso se arregla cargándolo. Ajustar para arriba taparía el cobro
  faltante y esa dispensa quedaría figurando impaga para siempre.
- **Lo que el repartidor no entregó NO es una pérdida**: esa plata existe y está con una persona.
  Va como `ajuste` categoría `a_cuenta_repartidor` con `retirado_por`, así que no baja el
  resultado — mismo criterio que `retiro_caja`. Categoría propia porque `retiro_caja` sólo admite
  admin o supervisor (`ROLES_RETIRO`) y acá el que la tiene es el repartidor. **Y el ingreso se
  asienta COMPLETO**: el paciente pagó esa plata, lo que falta no es menos venta.
- **Hay UNA sola forma de que la plata del repartidor entre al cajón** (`Rendiciones::Recibir`).
  `RecibirCajaDelivery` —la puerta vieja, para cuando el repartidor se fue sin rendir— crea la
  rendición y delega. Dos caminos distintos al mismo hecho es cómo dejan de coincidir.
- **La mesa se actualiza sola** por el canal del club (`stocks_club_X`, evento
  `mostrador_actualizado`), que ya existía — no se abre otro. Y **cada carga lleva número**: una
  tanda de cambios dispara varias recargas y nada garantiza el orden de llegada; sin el guard, la
  respuesta vieja aterriza última y la pantalla vuelve atrás, que se lee como "no se guardó".
- **Contar de a uno** (`Mostradores::Contar`) existe porque cerrar y reabrir con quince frascos
  son veinte minutos: el control que cuesta eso no se hace, y el que no se hace no controla nada.
  A diferencia del conteo de APERTURA —que sólo corre el punto de partida— acá la diferencia SÍ
  ajusta el inventario, igual que el cierre. Por eso los dos usan
  `MostradorItem#ajustar_inventario!`: estaba escrito dos veces, y la misma regla en dos lugares
  es de donde salen las divergencias. **Su pantalla es el botón "Contar" de cada fila**
  (`ModalContarItem`), y sólo para QUIEN ATIENDE y con la caja abierta: administración no cuenta a
  distancia —su gesto sobre la mesa es decir cuánto tiene que haber, que mueve producto del
  depósito— y con la caja cerrada el gesto es abrir, que ya cuenta todo. El servicio vivió sin
  pantalla desde el rediseño: construido, ruteado, con su función en `api.js` y sin un solo
  llamador.
- **EL MOTIVO DE UN CAMBIO DE MESA SE PIDE CON LA LISTA DELANTE** (`ModalCargarMesa`). Escrito
  antes, en una barra angosta, terminaba diciendo "carga" en todos los renglones —o sea nada, y el
  historial de la mesa es justo lo que se quería guardar—. Y con buscador y orden de por medio, lo
  tocado puede no estar todo en pantalla al guardar: el modal muestra el antes y el después de
  cada producto. Va en el pie de la tabla, no en una barra propia: eran dos franjas pegadas
  diciendo lo mismo.
- **EL BADGE DEL ENCABEZADO DICE "CAJA", NO "MOSTRADOR".** Desde que la mesa dejó de ser del turno,
  "Mostrador · Cerrado" con 300 g a la vista se contradice con lo que la persona está mirando.
- **El aviso de merma NO tiene umbral fijo** (`MermaMostradorJob`): un 3% puede ser normal
  fraccionando flor y un escándalo en aceite. Se compara la última semana contra las ocho
  anteriores DE ESA organización, con pisos de historia y de volumen, y uno por semana como mucho
  — repetirlo a diario es cómo se aprende a ignorarlo.
- **EL ARQUEO MUESTRA LO ESPERADO, y lo muestra a todos** (sep-2026, **decisión de Germán que
  REVIRTIÓ la regla anterior** — si aparece en un comentario viejo el criterio contrario, es
  legacy). La plata y los gramos, en la pantalla y **dentro del modal mientras se cuenta**, para
  quien atiende y para administración. Antes se escondía hasta que el conteo estuviera escrito,
  con el argumento de que nadie pesa 297 g teniendo el 297 delante. **Ese riesgo es real y no
  desapareció**: el número puesto delante invita a escribir ése en vez de terminar de contar, y si
  eso pasa la diferencia medida tiende a cero justo cuando existía. Pesó más lo otro: una
  diferencia vista EN EL MOMENTO se sale a buscar —el vuelto mal dado, el frasco que quedó en el
  depósito— y una descubierta al día siguiente ya no la puede explicar nadie. Lo que se guarda
  sigue siendo lo **CONTADO**, la diferencia queda anotada con su nombre y no frena el cierre. Si
  alguna vez la merma medida se aplana sospechosamente, **esto es lo primero que hay que mirar**.
  (`TablaMostrador` tenía una prop `contando` para taparlo: se retiró, no quedó código muerto.)
- **REVERTIR UNA DISPENSA: A LA MESA O AL DEPÓSITO, Y NO ES LO MISMO**
  (`Dispensacion#desimputar_del_mostrador`, inverso exacto de `imputar_a_mostrador`). Vuelve a la
  mesa en DOS casos y sólo en esos dos: el producto **ya está** arriba —salió de ahí y vuelve
  ahí—, o **no está pero hay alguien atendiendo**, que es el paquete que el repartidor no pudo
  entregar y el que atiende tiene ahí adelante. En el resto vuelve al depósito: subirlo igual
  dejaba cien gramos apartados sobre una mesa cerrada, invisibles como disponibles, esperando que
  alguien se diera cuenta de bajarlos —pasaba cada vez que un admin cancelaba una dispensa suya
  con el mostrador sin abrir—. El CONTADOR del turno, en cambio, sólo se revierte con el turno
  abierto: si ya cerró, su arqueo se hizo con el producto afuera y tocarlo movería un número que
  alguien firmó.
- **Un reparto FALLIDO no devuelve el stock, y está bien**: puede reprogramarse. Para devolverlo
  de verdad está `cancelar_entrega`, que revierte stock, cuenta corriente y asientos.
- **EL MOTIVO DEL RECHAZO SE NORMALIZA EN EL INTERCEPTOR** (`lib/api.js`, sep-2026). El backend
  contesta `{ error: "…" }` o `{ errors: [...] }` (validaciones de modelo) y las pantallas leen una
  cosa o la otra —219 leen `error`, 42 leen `errors[0]`—: las primeras se comían el motivo y
  mostraban un "no se pudo" pelado, que es el peor mensaje posible. El interceptor rellena `error`
  desde `errors`, así todas lo muestran y la pantalla nueva nace bien.
- **ENTREGAR UNA RESERVA ABRE EL MODAL, NO ENTREGA.** Hay una seña ya paga, un resto a cobrar y un
  medio de pago que elegir con el paciente enfrente: entregar de un toque salía a ciegas y con el
  medio guardado en la reserva (si era cuenta corriente y el paciente no la tiene habilitada,
  rebotaba). Es el mismo componente en los dos lados, así que la regla de cobro vive una vez.
- **EN MODO RESERVA, EL PRODUCTO NO SALE DE LA LISTA.** Los dos guards que limpian `stock_id`
  —al cambiar de sede y al no encontrarlo entre los visibles— lo borraban y dejaban "Entregar
  reserva" MUERTO, sin decir por qué: lo reservado **nunca** está en esa lista, porque ya está
  apartado a nombre del paciente. Tampoco se pregunta la sede ni se ofrece elegir producto, y los
  carteles de "no hay nada sobre la mesa" / "nada coincide" no aplican ahí.
- **ENTREGAR UNA RESERVA NECESITA LA CAJA ABIERTA** —crea una dispensa, y lo cobrado en efectivo
  tiene que tener dónde caer—, **pero NO necesita que el producto esté sobre la mesa**: es una de
  las dos excepciones, porque ya está apartado a nombre de esa persona (`desde_reserva`). La
  pantalla de reservas avisa antes y no habilita el botón, como el carrito.
- **LA PANTALLA NO LE PROPONE A NADIE ALGO QUE EL BACKEND LE VA A RECHAZAR.** Al dispensador con
  el carrito vacío el cartel le decía "bajá lo que falte del depósito", que es exactamente lo
  único que no puede hacer: la mesa la carga administración. Un cartel que propone una acción
  prohibida es peor que no tener cartel — parece culpa del usuario. Mismo criterio que el botón
  que no se habilita si el backend va a rechazar.
- **EL DEPÓSITO DE UNA COMPRA NO SE ELIGE: SE DEDUCE** (sep-2026) — la **familia de la categoría
  POR la sede**, que ya están las dos contestadas más arriba. Se AFIRMA, con la sede editable
  adentro de la oración; preguntarlo después de haberlo dicho eran dos preguntas para una decisión,
  con dos respuestas que podían contradecirse. **El comportamiento de la categoría y
  `Deposito#familia` son el mismo vocabulario** (`insumo` · `insumo_general` · `mercaderia`):
  `Deposito::FAMILIA` se escribió para reemplazar al comportamiento. **Ojo con
  `CategoriaContable#familia_deposito`**, que se llama parecido y devuelve otra cosa —la CLAVE del
  depósito (`cultivo`/`general`/`salon`)—: comparados entre sí no matchean nunca. Lo hace cumplir
  `verificar_familia!` en el backend, porque por la API se saltea siempre. **Dispensación no recibe
  compras** (lo llena la cosecha), y un depósito propio del club se comporta como insumos generales.
  Sigue existiendo **«esta vez no entra: es sólo un gasto»**, pero como SALIDA y no como una de dos
  opciones en igualdad: si la categoría guarda cosas, lo normal es que entre.
- **UN STOCK «SOLO DISPENSA» NO PUEDE VIVIR DONDE NO HAY MOSTRADOR** (sep-2026). El mostrador vive
  en una sede `social`/`mixta`: cargarlo en una de producción lo deja invisible para siempre, y así
  se perdió un preroll media hora. Las sedes que se ofrecen salen de la **disponibilidad**, que se
  declara en el mismo formulario, y la regla está también en el backend y en «Repartir a sede» (dos
  puertas). **`ambas` NO se acota**: la flor de un lote nace en la sede donde se cultiva y sirve
  para las dos cosas — acotarla haría inguardable el alta más común que hay. Sólo se acotan las
  declaraciones explícitas (`dispensa`, `produccion`).
- **NO HAY BOTÓN «FINALIZAR LOTE»: SE FINALIZA EL STOCK Y EL LOTE SE CIERRA SOLO** (sep-2026,
  decisión de Germán). Una organización sin dispensa nunca agota su stock, así que el lote se
  quedaba en `curado` para siempre acumulando días que no eran ciertos. Se cierra el stock diciendo
  **qué pasó** (`Stock::MOTIVOS_FINALIZACION`: entregado a otra organización · vendido · regalado ·
  uso interno · destruido) y `finalizar_si_stock_agotado!` hace el resto. **Un solo camino a
  `finalizado`**, que sigue significando «no queda nada»: un botón que escribiera el estado a mano
  rompería el balance de la trazabilidad y la validación que existe porque ya pasó.
- **CERRAR UN STOCK LLEVA FECHA, Y NO ES LA DE CARGA** (`stock_movimientos.fecha`, sep-2026). Se
  cierra un jueves y se registra el lunes: con `created_at` la merma caía en la semana equivocada.
  No futura y no anterior a `fecha_elaboracion` —no a `created_at`, que una carga retroactiva del
  producto es legítima—, y **el lote hereda esa fecha** al cerrarse. Todo lo que corte
  `stock_movimientos` por período usa el scope `en_periodo`, nunca `created_at`.
- **LA SEDE DE LA CATEGORÍA MANDA** (sep-2026). Una categoría contable puede estar acotada a una
  sede: entonces el gasto es de ESA sede y, si entra a un depósito, al de esa sede — no se pregunta,
  ya se decidió al elegir la categoría. El campo existía desde siempre (se elegía en el catálogo, se
  guardaba, se devolvía) y **no lo leía nadie**, que es la tercera vez que aparece ese patrón. La
  regla vive en `MovimientoContable#sede_de_la_categoria` (modelo, porque son varias las puertas que
  crean movimientos) y el backend rechaza un depósito de otra sede: si no, la plata queda en una
  sede y la mercadería en otra.
- **EL NOMBRE Y LA UNIDAD DE UN INSUMO NUEVO SE ESCRIBEN UNA VEZ, ARRIBA.** Un insumo nuevo se llama
  como lo que compraste y se mide en la unidad que ya elegiste: el campo *Nombre del insumo* sólo
  aparece si se pide. Mismo criterio que la cantidad, que se muestra en gris. Y la lista de «qué
  entró» **dice que es para reposición** — la etiqueta era «¿es algo que ya tenías?» y hubo que
  preguntar qué significaba.
- **CADA MODAL LARGO TERMINA EN UNA ORACIÓN QUE DICE QUÉ VA A PASAR.** «Salen $80.000 en efectivo.
  1.500 unidades de Bolsas entran al depósito General de Sede Central, a $53 cada una.» Es lo que
  deja cargar bien a alguien que no sabe de contabilidad, y lo mismo que hace la ficha de un cierre
  del mostrador. **El admin sabe de cultivar**, y esa es la regla que ordena el texto entero.
- **UN CIERRE SE CONGELA POR TRES RAZONES, Y LA REGLA VIVE EN `TurnoMostrador#bloqueo_correccion`**
  (sep-2026). Corregir mueve inventario real y asienta plata, y no tenía NINGUNA frontera
  temporal: cualquier cierre, para siempre. Vive en un solo lugar porque la preguntan los dos
  lados —`CorregirCierre` que la aplica y la ficha que la muestra—, y **el orden lo decide cuál
  tiene arreglo**: ① **se abrió otra caja** (abrir es contar: el producto ya se re-midió, y
  aplicar un delta viejo lo aleja de la última medición real; una caja **anulada** no congela
  nada) · ② **período contable cerrado** · ③ **marcado como visto**, que es el único con llave:
  se reabre para revisión con `DELETE …/turnos/:id/revisar` y el rastro queda en la auditoría.
  Sin esa llave, un clic de más sería permanente y el gesto —que tiene que ser liviano, la lista
  está para vaciarse— pasaría a ser una decisión que el admin duda antes de tomar. **La ficha DICE
  cuál de los tres es**: son tres arreglos distintos en tres lugares distintos.
- **«SEÑADA» NO ES «PAGA»** (`MReservasView`, sep-2026). La tarjeta decía «Señada ✓» apenas había
  seña, y una reserva puede estar señada con la mitad todavía por cobrar: se entregaba sin cobrar
  el resto. Se dicen **las dos cosas** —lo que ya puso y lo que falta—, que es lo que hay que
  decirle al paciente. Y **sin seña y sin total estimado no está paga**: ahí dice «se cobra al
  entregar», porque un `resta 0` puede significar que nunca se estimó el aporte. La tarjeta lleva
  además **la variedad**, que es con lo que se busca el frasco entre quince.
- **Corregir un cierre NO borra el movimiento equivocado** (`Mostradores::CorregirCierre`):
  asienta la diferencia al lado. Era el único lugar del módulo donde un dedazo destruía datos —21
  en vez de 215 ajusta el inventario real—, y borrar para tapar el error es peor que el error.
- **`Date#all_month` devuelve un rango de DATES.** Comparado contra un `created_at` corta a la
  MEDIANOCHE del último día: el día 31 no se contaba nada de esa jornada. Mordió al consumo de IA
  (el tope no se aplicaba y el cliente tenía un día gratis por mes) y a los informes por período.
  `Date#all_day` sí devuelve Times: ese no tiene el problema.
- **NI RELEVO NI RECEPCIÓN: ABRIR ES CONTAR.** El relevo —que el que entra recuente lo que él
  mismo dejó— se descartó desde el principio: termina en un botón que nadie mira, y encima esa
  firma después se usa para acusar a alguien que nunca contó. La RECEPCIÓN separada (el admin
  declara, quien atiende confirma) se descartó después, por lo mismo: era la misma verificación
  pedida dos veces. Queda un solo gesto —quien va a atender pesa lo que encuentra y cuenta la
  plata— y ese es el punto de partida del arqueo, que es lo único que hacía falta: sin él, la
  diferencia de la noche mezcla lo que se consumió atendiendo con lo que nunca estuvo.
- **La plata ENTRA y SALE del cajón, y el arqueo tiene que ver las dos.** `CajaTurno#ingresos`
  (`ingreso_caja` + `devolucion_caja`) es el simétrico de `salidas`, y las dos ignoran lo
  posterior al cierre. `devolucion_caja` se ataba a la caja abierta desde siempre pero el esperado
  no la sumaba: el turno cerraba con un sobrante igual a lo devuelto. **`ingreso_caja` va como
  `ajuste`**, nunca como ingreso: esa plata ya era del club, sólo cambió de lugar. Y una dispensa
  cobrada en efectivo con la caja abierta ya entra sola — usar `ingreso_caja` para eso la cuenta
  dos veces.
- **Al ABRIR se cuenta la PLATA además del stock**, y si no coincide el fondo pasa a ser lo
  contado. Sin corregirlo, el cierre vuelve a encontrar la misma diferencia y la cuenta dos veces.
  Ojo con la asimetría: los gramos que faltan **pueden estar en el depósito** (corregir no toca el
  inventario), pero los pesos que faltan **no están en ningún lado** (corregir sí asienta la
  pérdida).
- **UN ARQUEO FIRMADO NO SE MUEVE DESPUÉS.** `efectivo_esperado_ars` se calcula EN VIVO cada vez
  que alguien lo mira, también en un turno cerrado, así que todo lo que entra en esa cuenta tiene
  que ignorar lo que pase después del cierre. `salidas`, `ingresos` y `otros_ingresos_efectivo` ya
  lo hacían; **lo cobrado no**, y cancelar hoy una dispensa de ayer soft-borra su `Cobro`: el
  turno que cerró cuadrado aparecía con un sobrante igual a lo cancelado. `cobros_del_arqueo` y
  `ventas_del_arqueo` (el buffet tiene el mismo problema: `BarVenta` también es soft-delete)
  cuentan lo que estaba en el cajón esa noche — incluyen lo anulado DESPUÉS y excluyen lo
  cancelado ANTES, que no estaba a la hora de contar. Es la peor forma de un error contable: no
  falta una fila ni sobra un movimiento, el total cambia solo.
- **`rake contabilidad:auditar` es con lo que uno se da cuenta.** Sólo lee: saldos de cuenta
  corriente contra su propio historial, lo asentado de cada dispensa contra lo cobrado, cobros
  colgando de dispensas canceladas. **Sus tests verifican también el SILENCIO** —la dispensa mixta
  lleva dos asientos y está bien, el efectivo sin rendir no tiene asiento a propósito— porque un
  aviso que grita en falso entrena a ignorar todos los demás. Ojo con `where.not` sobre columnas
  que admiten NULL: `estado_envio != 'cancelada'` es NULL para una dispensa sin envío y no
  matchea, así que la auditoría revisaba sólo los repartos y daba verde sin haber mirado nada.
- **Lo que se retira al cerrar la caja no cuenta como salida del turno** (`CajaTurno#salidas`
  ignora lo posterior a `cerrada_at`). Si contara, bajaría lo esperado y la diferencia de arqueo
  quedaría mal para siempre: un turno que cerró cuadrado aparecería con un sobrante igual a lo que
  se llevaron. Y **el retiro sólo queda a nombre de un admin o supervisor**
  (`MovimientoContable::ROLES_RETIRO`): el que atiende cierra pero no se lleva la recaudación —
  deja todo como fondo y lo retira después quien responde.
- **`punto_type` de una caja de dispensario es `'Mostrador'`, y se pregunta en UN solo lugar**
  (`CajaTurno.abierta_en_sede` / `del_mostrador`). Estaba escrito a mano en cinco archivos y
  ninguno fallaba al desactualizarse: simplemente no encontraba caja, el cobro quedaba suelto y el
  arqueo mentía en silencio.
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
- **Un adicional no se prende sin su suite** (`sin_addons_huerfanos`, 25-ago). Delivery sin
  Producción y dispensa o IoT sin Cultivo dejaban un módulo CONTRATADO que no hacía nada, y el
  aviso vivía en el campo `requiere`, en letra chica. El candado va en el controller porque por la
  API se saltea siempre, y corre **DESPUÉS de las bajas programadas**: al revés, dar de baja una
  suite le cortaba hoy mismo los adicionales que la organización ya pagó.
- **Lo que el alta muestra prendido tiene que ser lo que se crea.** `SAClubNuevo` tenía su propia
  lista de defaults y el backend mergeaba `FEATURES_POR_DEFECTO` encima: mostraba Delivery y Correo
  apagados y la organización nacía con los dos. Los defaults salen de `GET /super_admin/catalogo`
  y el wizard manda **todas** las claves, también las apagadas — una ausente reaparece prendida.
- **En el alta, primero los MÓDULOS y después el PLAN.** El plan es una consecuencia: recién
  sabiendo qué compró se pueden mostrar los topes que aplican (`PlanEnforcer::RECURSO_SUITE`) y
  ofrecer los roles que van a poder entrar. Los pasos son Identidad → Módulos → Plan → Acceso →
  Resumen, y el resumen existe porque antes se creaba a ciegas.
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
- **`render file:` NO EXISTE EN MODO API, y no falla: devuelve vacío.** Esta app es
  `ActionController::API`, así que `spa_fallback` contestaba 200 con un ESPACIO y `text/plain` en
  toda ruta profunda. **La PWA instalada abre `start_url: '/m'`**: en una instalación nueva la
  primera navegación va a la red, recibía la página vacía —pantalla negra— y como no corría JS, no
  se registraba el service worker: no había salida. No se veía porque `/` lo sirve el middleware de
  estáticos sin pasar por el controller, y en desarrollo no hay `public/index.html`, o sea que se
  caía por la otra rama. Se sirve con `render plain: ..., content_type: 'text/html'` y **sin
  caché**: el shell nombra los assets por hash, y uno viejo cacheado apunta a archivos que ya no
  existen.
- **EL HELPER DE SPECS LE PONE `/api` A TODO.** `spec/support/api_prefix.rb` prefija cualquier
  ruta que no empiece con `/api`, `/webhooks`, `/public/`… o `http`. Un spec de una ruta del
  FRONTEND (`get '/m'`) prueba `/api/m` y pasa por la razón equivocada — se escapa con la URL
  absoluta (`http://www.example.com/m`).
- **El service worker necesita `NavigationRoute`.** Sin él la PWA instalada NO ABRE sin internet:
  `start_url` es `/m` y esa navegación no matchea la entrada `index.html` del precache. (Se decía
  que "en producción lo tapa el `spa_fallback` de Rails": era FALSO, ver arriba — el fallback
  devolvía vacío, y el precache era lo ÚNICO que hacía andar la app instalada.) `/me` sigue SIN cachearse a propósito (servido del caché, tras un logout devolvía el
  usuario viejo).
- **Un módulo se pide por su clave NUEVA y en un solo lugar.** Chequear la vieja (`ia_voz`) con
  la nueva guardada (`ia`) daba false: `feature?` resuelve viejo ⇒ nuevo, no al revés. Rompía el
  registro por voz de toda organización moderna con el botón a la vista.
- **EN LA PWA, UN LINK DE ESCRITORIO TIENE DESTINO SI LA PANTALLA EXISTE BAJO `/m`**
  (`rutaEnShell`). El guard rebota todo lo que no empiece con `/m`, pero varias vistas se montan
  en los dos lados sin escribirse dos veces (`/m/mostrador`, `/m/stock`, `/m/historial`): rebotar
  al home era perder un viaje que tenía a dónde ir, y le pegaba a lo que más se usa — "Ir al
  mostrador", en la pantalla donde aterriza el dispensador, lo devolvía a esa misma pantalla.
  **Se le pregunta al router**, no a una lista a mano. Y **el permiso se pide sobre la ruta de
  ESCRITORIO**: bajo `/m` la matriz es un solo prefijo para todo el shell, así que mapear a ciegas
  le abría `/m/pacientes` a un repartidor. La PWA no puede ser más permisiva que el escritorio.

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

**El de diagnóstico, que se puede correr cuando sea porque sólo lee:**

```
bundle exec rake contabilidad:auditar                # todas las organizaciones
bundle exec rake contabilidad:auditar CLUB=slug      # una sola
bundle exec rake contabilidad:auditar DETALLE=1      # cada caso, no sólo el conteo
```

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

- **Un test que espera con `setTimeout(0)` no es un test, es una apuesta.** `finanzasCatalogo`
  esperaba "cinco vueltas del reloj" a que montara el componente y fallaba **sólo con la máquina
  sin CPU libre** (la suite de Rails corriendo al lado): pasa o falla según cuán ocupada esté la
  máquina, que es la peor clase de rojo — enseña a desconfiar de toda la suite. Se espera con
  `flushPromises`, y **lo que se monta se desmonta** (`afterEach`): cada `DsDropdown` vivo deja un
  listener en `document`. El `vitest.config.js` ya documenta la misma familia de problema (el test
  de ESLint ocupa un núcleo 13 s y mata por timeout a los de DOM que corren al lado).


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

**Lo que no aclara, que no confunda.** Se probó una guía de "cómo funciona el día" arriba del
mostrador y se sacó el mismo día: el paso 1 decía *"se abre con lo que quedó contado anoche"* y la
primera vez **no hay anoche** — al lado, la pantalla decía "Elegí qué baja del depósito". Un cartel
que se contradice con lo que la persona está mirando es peor que no tener cartel. La pantalla ya
se explica sola en cada momento, que es donde sirve.

**El botón NO puede quedar habilitado si el backend va a rechazar.** Pedir más de lo que hay libre
se avisa en la fila Y deshabilita "Abrir mostrador". Dejar apretar para que rebote del otro lado es
el peor error posible: parece culpa del usuario.

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
