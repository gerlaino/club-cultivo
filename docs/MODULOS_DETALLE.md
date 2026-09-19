# Módulos existentes — detalle histórico (hasta 18-sep-2026)

> Extraído de `CLAUDE.md` el 18-sep-2026. Detalle largo de cada módulo tal como quedó. Ver `docs/CHANGELOG.md` para lo posterior.

## 📦 Módulos existentes (estado real)

Ninguno se considera cerrado; todos son candidatos a revisión.

1. **Socios/Pacientes** — alta, REPROCANN (número, vencimiento, renovaciones, críticos), documentos con firma digital, cuenta corriente, notas, mailer con historial. **El alta desde el mostrador (dispensador/supervisor) queda PENDIENTE de aprobación**: existe y se completa, pero no recibe dispensaciones ni reservas hasta que admin o médico la aprueben. El bloqueo vive en los modelos `Dispensacion` y `Reserva`, no en la UI. Un alta nace **aprobada** salvo que venga del mostrador (al revés, una importación de padrón dejaba a todos sin poder retirar).
2. **Módulo médico** — turnos, disponibilidad, check-ins, fichas, indicaciones médicas, prescripción PDF.
3. **Cultivo** — genéticas, lotes (estados/fases), plantas con QR, pesadas, plan de trabajo (+ generación IA), tareas (recurrentes + automáticas por fase), fotos, análisis de laboratorio.
4. **Manicura / post-cosecha** — pesajes, flujo de aprobación admin, curado, stocks de manicura.
5. **Stock** — por sede, movimientos, QR/etiquetas, aprobaciones pendientes.
6. **Dispensaciones** — **multi-stock**: una dispensa abarca varias líneas (`DispensacionItem`); UI = carrito en `ModalNuevaDispensacion` (abierto desde la ficha del socio y el historial; la vista `/dispensar` se eliminó). Medios de pago (efectivo/transferencia/cuenta corriente/no abona/contra-entrega), validación de crédito, descuento sobre el total, reservas (apartar stock a futuro, **fecha ≥ mañana**; **con carrito desde el 15-sep-2026**: `ReservaItem`, misma regla que `DispensacionItem` —la fila es primera línea + suma, lo apartado se lee de las líneas—), CSV. **Edición multi-ítem** (cantidad + precio por línea) con reconciliación de stock/cc; **precio manual por ítem** (admin/sup). **Todo paciente tiene cuenta corriente** (18-sep-2026): lo que paga de más queda a favor y se descuenta solo en la próxima; deber sigue pidiendo límite. (`limite_dispensacion_mensual_g` existe en el schema pero **no es una feature en uso** — ver Dominio.)
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
10. **Analítica e informes** — **Analítica son CUATRO solapas, una pregunta cada una** (sep-2026): Genéticas (¿cuál rinde mejor?, g/planta ponderado) · Fases (¿cuánto tarda cada fase?, cronología real + prendimiento) · Dónde y cómo (¿en qué sala, método, ambiente de floración?) · Costo (¿cuánto cuesta un gramo?, sólo cerrados). Cálculo en `app/services/analitica/*` sobre `Analitica::Universo` (lotes cerrados con rendimiento, todo el historial por defecto, umbral de 3 lotes para concluir). Benchmark, informe semestral, informes auditor (REPROCANN, producción, plan vs real, trazabilidad, INASE, pérdidas).
10b. **Informes del auditor, revisados uno por uno (sep-2026):** Producción, Trazabilidad (frasco y lote), Dispensaciones, Pérdidas, Plan vs. real y REPROCANN viven en `app/services/informes/*` (y `Stocks::Trazabilidad`, `Lotes::Trazabilidad`); pantalla, PDF y Excel leen el mismo hash. **Cumplimiento se retiró** (ruta redirige a REPROCANN). Reglas que valen para todos: por línea y por unidad, nunca `updated_at` como fecha de un hecho, la descarga pide el mismo período que la pantalla (`SelectorPeriodo`), DNI en 3 dígitos en pantalla y entero en el archivo. **INASE** (`Informes::Inase`) tiene período por fecha de cosecha, «en cultivo hoy», origen semilla/esqueje por variedad y **un aviso en vez de un KPI** para lo no vinculado — el aviso, la salvedad y el candado de «Para presentar» miran **la misma lista**: lo que aparece en el documento (`ids:` al guard). **La declaración semestral** (`Informes::Semestral`) **compone** Reprocann/Inase/Dispensaciones con el semestre como período y **todo al cierre**; la población del REPROCANN vive en `Informes::Reprocann#registrados/nomina(al:)`. **Analítica revisada (13-sep): la revisión informe por informe está COMPLETA.**
11. **ARICCAME** — reporte de dispensaciones y stock (feature flag por club). La transmisión está SIMULADA: no envía nada de verdad.
12. **Super admin** — panel de plataforma como **cola de trabajo** (cada pendiente con su acción, agrupado por urgencia: se está perdiendo plata · paga y no le funciona · **quedaste en hacer** · avisar con tiempo), organizaciones, **dos planes** (`PlanEnforcer`: básico/total, sólo límites), catálogo de módulos (`GET /super_admin/catalogo`), informes de plataforma, historial por organización. **El modo observador está SUSPENDIDO** (`User::OBSERVADOR_HABILITADO = false`). Un super_admin sin contexto que pega a un endpoint de organización recibe **409 explicando qué falta** (`block_super_admin_sin_contexto!`), no un 500.
    **Visto por el dueño del negocio (16-sep-2026, bloque bv):** el panel **abre con la plata**
    (`Precios`: constante con **valores provisorios**; `Club#precio_mensual` / `#factura?`; MRR,
    vencido y operando, vence este mes) · **último ingreso real** (`users.visto_at`, tocado una
    vez por hora desde `ApplicationController#marcar_visto!`; NO `devise :trackable`, que con JWT
    escribiría en cada request) · **contacto, notas y próxima acción** (`club_notas` sin tenant;
    la acción con fecha entra a la cola) · **puesta en marcha** derivada de los datos
    (`Clubs::PuestaEnMarcha`, la ven la ficha y el inicio del admin) · **demo y clonar** desde el
    panel (`SembrarDemoJob` en segundo plano; `Clubs::Clonar` sincrónico) · **suspender pide
    motivo** (`Club::MOTIVOS_SUSPENSION`; la cola muestra la acción del motivo, el cartel de la
    organización lo dice) y **archivar** saca de la cola sin borrar · **el vencimiento avisa**
    (`PlanVencimientoJob` 7 días antes y el día; franja en la app del admin) **pero no corta** ·
    Salud con último backup (`Backups::Ultimo`) y cron atrasados · adopción con **usado en 30
    días** · la ficha en **cuatro solapas**. **«Olvidé mi contraseña»** existe (`/olvide-contrasena`,
    `Users::PasswordsController`, `Acceso::EnviarRestablecimiento`, por la casilla de la
    PLATAFORMA y sólo a `User#email_real`) y el alta guarda **la persona detrás del admin**
    (`crear_usuarios_default!(admin:)`). `stats#show`/`#metricas` se retiraron.
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

