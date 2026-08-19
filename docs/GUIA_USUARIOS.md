# Guía de usuarios y flujos — Cultivo Espacial

> Documento de referencia para armar los manuales. Refleja el estado real del código a
> **7 de agosto de 2026** (HEAD `8e05ebf`). Si algo contradice al código, manda el código.

**Cómo se verificó esta versión.** La versión anterior era del 4 de julio y quedaron 254 commits
en el medio. Se verificaron **contra el código fuente**: el ciclo de vida del lote y la planta,
las rutas y permisos por rol, el catálogo de módulos y su gating. El resto se reconcilió con los
cuerpos de commit y el CHANGELOG. Las secciones marcadas con ⚠️ **no se reverificaron línea por
línea** y hay que mirarlas antes de publicarlas en un manual.

> **Nota**: el `CHANGELOG.md` está al día hasta *Agosto 2026 (e)*; los ~35 commits del 6 y 7 de
> agosto (módulos por suites, informes en PDF real, Equipo, VPD de hoja, rutas por rol) todavía
> no tienen entrada.

App: **Vue 3 (SPA) + Rails 7.2 (API)**. Multi-tenant: cada club es un tenant aislado por
`club_id`. Contexto legal argentino: REPROCANN, ARICCAME/ANMAT, Ley 25.326 (datos de salud).

---

## 1. Cómo funciona el acceso

Hay **11 roles**: `super_admin, admin, medico, cultivador, supervisor, abogado, auditor,
dispensador, manicura, paciente, delivery`.

### La raíz ya no es el login
- **Sin sesión, `/` muestra `/bienvenida`** — una landing pública que explica qué es el producto.
- **Con sesión, `/` sigue siendo el dashboard de siempre.** El dashboard no se movió: los ~17
  "Inicio" de sidebars, topbars y breadcrumbs apuntan donde apuntaban.
- El posicionamiento dejó de ser "plataforma REPROCANN": es *"una plataforma para toda
  organización que cultiva: clubes, investigación y producción"*. REPROCANN y ARICCAME siguen
  estando, pero como **consecuencia** de la data que se carga operando, no como identidad.

### Dos modelos de navegación
- **Roles "silo" (bloqueados a su sección):** `super_admin`, `auditor`, `medico`, `abogado`,
  `delivery`. Cada uno arranca en su home y solo navega dentro de su prefijo.
- **Roles del shell principal:** `admin`, `supervisor`, `cultivador`, `dispensador`, `manicura`.
  Comparten la app con el sidebar por secciones.
- **`paciente`:** no usa el panel del club.

### La matriz de rutas ahora cubre los 11 roles
Antes cubría solo a los 5 silos: los del shell compartido no se podían filtrar mirando el prefijo
del layout, así que un cultivador que **escribía la URL** `/contabilidad` llegaba a la pantalla,
el backend le devolvía 403 y veía una vista rota sin entender por qué. Hoy cada rol declara sus
secciones (`ROLE_ALLOWED_PREFIX` en `router/index.js`):

| Rol | Secciones propias (además de `/perfil`, `/login`, `/bienvenida`) |
|---|---|
| `cultivador` | `/` `/salas` `/lotes` `/plantas` `/geneticas` `/tareas` `/plan-trabajo` `/historial-cultivador` `/cosechado` `/dispositivos` `/reglas-ambientales` `/m` |
| `supervisor` | lo del cultivador **+** `/pacientes` `/socios` `/historial` `/admin/stock` `/insumos` `/sedes` |
| `manicura` | `/` `/cosechado` `/lotes` `/plantas` `/tareas` `/m` |
| `dispensador` | `/` `/pacientes` `/socios` `/historial` `/admin/stock` `/insumos` `/bar` `/entregas` `/m` |
| silos | su propio prefijo (`/medico`, `/auditor`, `/abogado`, `/delivery`, `/super-admin`) |

Cuando bloquea, **el aviso nombra el rol y dice a quién pedirle acceso** — antes te devolvía al
dashboard sin explicación, como si te hubieras equivocado de click.

**Rutas públicas:** las marcadas `meta.public` (carnet del socio, pasaporte de dispensa, web del
club) quedan **fuera** del chequeo de roles. Antes, un médico o un delivery logueado que abría un
carnet recibía "Sin permisos" y era expulsado a su home.

> Nota técnica: la autorización fina del backend es por chequeos ad-hoc en cada controller. Para
> los manuales importa el comportamiento efectivo, que es el descrito acá.

**Móvil / PWA:** `admin, supervisor, cultivador, manicura, delivery` tienen vistas móviles (`/m/*`).

---

## 2. Módulos: dos suites y sus add-ons

**Esto es nuevo (6–7 de agosto) y condiciona todo lo demás:** lo que un rol ve depende primero de
qué módulos tiene contratado el club, y recién después de su rol.

### Las dos suites (`Club::SUITES`)
| Clave | Nombre | Qué incluye |
|---|---|---|
| `cultivo` | **Cultivo** | Genéticas, lotes, plantas, salas, cosecha, post-cosecha y tareas. |
| `produccion_dispensa` | **Producción y dispensa** | Pacientes, stock, dispensaciones, reservas, cuenta corriente, delivery y contabilidad. |

### Los add-ons (`Club::ADDONS`)
| Clave | Nombre | Requiere |
|---|---|---|
| `bar` | Buffet | — |
| `eventos` | Eventos | Que el Buffet esté activo |
| `medico` | Módulo médico | — |
| `iot` | Ambiente / IoT | Hardware del club (Sonoff, Pulse Grow) o importación CSV |
| `ia` | Asistente IA | `ANTHROPIC_API_KEY` en el entorno |
| `mailer` | Correo al paciente | SMTP del club cargado en Preferencias |
| `whatsapp` | WhatsApp | Cuenta de Twilio del club |
| `vista_paciente` | Portal del paciente | ⚠️ **incompleto**: falta el tablero del paciente (carnet y dispensaciones) |
| `ariccame` | ARICCAME | ⚠️ **incompleto**: la transmisión está simulada, no envía nada |

`ariccame`, `eventos`, `chatbot` y `vista_paciente` están en `ADDONS_INCOMPLETOS`: vienen apagados y el super
admin muestra la advertencia antes de dejar activarlos.

**Un club nuevo nace con:** las dos suites + `bar` + `medico`. Los que dependen de algo externo
(IoT, IA, mail, WhatsApp) se prenden a mano cuando el club los tenga resueltos.

### El gating es real
`require_feature!` (en `ApplicationController`) bloquea **27 controllers** y el menú lateral.
Devuelve 403 con `requiere_modulo: true` y el nombre del módulo. Hasta el 6 de agosto solo cuatro
add-ons gateaban de verdad; hoy las suites también.

**Los dos clubes parciales funcionan de punta a punta:**
- **Solo Cultivo** — cultiva, cosecha y manicura (todo eso *es* cultivo), y su lote llega igual
  hasta el stock. Lo que cambia es la **salida**: el stock se va por transferencia, merma o
  ajuste, no por dispensación.
- **Solo Producción/Dispensa** — no cultiva, así que no genera stock propio. Su inventario entra
  por **compra externa** (que exige proveedor) y de ahí dispensa normalmente.

### Ya no hay planes con nombre
El super admin **dejó de hablar de Semilla / Brote / Cosecha / Federación** (esa era la tabla de
precios vieja). La lista de clubes muestra **qué contrató** cada uno —suites + cantidad de
add-ons— y se filtra por eso: las dos suites, solo Cultivo, solo Dispensa.

> `PlanEnforcer` con sus cupos sigue existiendo en el backend; lo que se retiró es la
> presentación por plan nombrado en el super admin.

---

## 3. Roles — qué puede y no puede cada uno

### 👑 admin
**Es el dueño operativo del club. Puede todo dentro de su club.**
- **Ve:** todas las secciones del sidebar — Dashboard, Cultivo (Salas, Lotes, Plantas, Genéticas),
  Pacientes (+ Dispensaciones + REPROCANN), Producción (Stock, Cosecha, Manicura), Comercial
  (Reservas, Despachos, Contabilidad), Tareas (+ Plan de trabajo), Reportes, Configuración —
  **según los módulos que el club tenga activos**.
- **Puede:** crear/editar/borrar en todos los módulos; aprobar pesajes de manicura; cerrar curado
  y generar stock; confirmar/editar dispensaciones; gestionar reservas; ver y editar historia
  clínica; cerrar períodos contables; gestionar equipo y sedes; configurar ambiente/alertas;
  restaurar desde la Papelera.
- **Equipo (rehecho):** al dar de alta, la **contraseña la genera el backend** —distinta para cada
  usuario— y viene armada para **dictarse por teléfono**: sin `0/O` ni `1/l/I`, en bloques
  (`BiTc-XnPb-5447`). Queda en pantalla, no en un toast que se va solo. Hay botón de
  **restablecer contraseña** en la ficha del usuario: la genera, la muestra e informa si el mail
  salió o no. **Un fallo de SMTP ya no tumba un alta.**
- **NO puede:** cosas de plataforma (planes globales, otros clubes) — eso es del super_admin.
- **Candado de manicura:** en un lote **asignado a un manicura**, el admin **no** registra el peso
  desde el detalle de la planta ni desde el batch. Sí puede si el lote no tiene manicura asignado.

### 🌱 cultivador (shell principal, foco Cultivo)
**Opera el cultivo de las salas/sedes que tiene asignadas.**
- **Puede:** Plantas, Lotes, Salas (ver/editar), Plan de trabajo, mediciones y ambiente,
  Genéticas (lectura), reportes de cultivo. Registra riego/fertilización/podas, avanza fases,
  cosecha, carga fotos y análisis de laboratorio.
- **⚠️ CORRECCIÓN respecto de la versión anterior — la visibilidad es al revés de lo que decía:**
  un cultivador **sin sedes asignadas ve TODO el cultivo del club**. Es a propósito: un club de
  una sola sede no debería tener que asignársela a cada persona para que la app le sirva. Con
  sedes asignadas, sí se filtra por ellas. (Vive en `User#salas_ids_asignadas` y lo consumen los
  cuatro controllers que lo necesitan; antes estaba escrito a mano en cada uno y faltaba justo en
  los dos de plantas, así que **veía lotes pero ninguna planta**.)
- **Post-cosecha:** al cosechar, el lote **suelta la sala** para liberar el slot. El alcance
  post-cosecha se resuelve por **sede** (`Lote.al_alcance_de`), si no las plantas de un lote
  cosechado no le aparecían nunca.
- **NO crea salas.** El backend siempre devolvió 403; ahora la UI tampoco ofrece el botón.
- **Al crear un lote solo se ofrecen salas donde ese lote puede estar.** Un lote nuevo arranca
  enraizando y va a vegetativo: en 12/12 no prende nada, así que las salas de floración no son
  opción.
- **Asistente por voz** (add-on `ia`): dicta su reporte de sala. No puede crear tareas por voz.
- **NO puede:** pacientes, dispensación, stock/comercial, contabilidad, configuración, reportes
  oficiales.
- **En el teléfono** la barra es **Cultivo · Escanear · + · Tareas · Mis horas**. A una planta se
  llega **escaneando su QR o desde su lote** — así se trabaja parado en la sala. No hay lista de
  todas las plantas ni Genéticas en móvil (es material de consulta de escritorio).

### ✂️ manicura (home `/mnc/pendientes`)
**Post-cosecha: pesa las cosechas que el admin le asigna.**
- **Puede:** ver sus lotes en manicura asignados; registrar el **peso** de las plantas —escaneando
  el QR de cada una o con "Registrar por lote"—; ver inventario de manicura, lotes y genéticas
  (lectura).
- **Candado (provisorio):** si un lote está **asignado a un manicura**, **solo esa persona**
  registra el peso (ni el admin ni otro manicura), para evitar ediciones concurrentes que
  "pierden" la planta. Cierra la jornada → la manda **a confirmar** → el admin aprueba → se genera
  el stock de flor seca.
- **NO puede:** dispensar, ver pacientes/clínico, contabilidad, configuración.

### 💊 dispensador (shell principal, foco mostrador)
**Atiende el mostrador: dispensa, cobra y maneja el stock de su sede.**
- **Puede:** ver socios (lectura) y crear pacientes básicos (sin seguimiento médico, dispara
  alerta al admin); **dispensar** (carrito multi-producto, medios de pago, descuento, crédito de
  cuenta corriente); ver el inventario por sede; ver tareas y notas de socio.
- **Puede asignar el envío** de una dispensa (nuevo, 6-ago).
- **Buffet:** puede **cargar la mercadería que recibe** (`comprar`, con costo y egreso a su
  nombre) y **vender lo que no está en el catálogo** — línea suelta *"Otro / Varios"*, que
  registra la venta sin tocar inventario. El panel del Buffet **cuenta las ventas sueltas del
  mes** para que la gestión termine de cargar esos productos. El buscador del Buffet busca **por
  código de barras**.
- **Se le retiró `reponer`**, que subía stock **sin costo y sin asiento contable**.
- **Reservas:** **convierte** una reserva en dispensa (*Entregar*), pero **no** las crea ni las
  gestiona.
- **NO puede:** ver historia clínica; cultivo, contabilidad, configuración, informes oficiales.

### 🧑‍⚕️ medico (silo `/medico`, add-on `medico`)
**Solo su sección clínica.** Rehecho en agosto: tenía **tres puertas para lo mismo**.
- **La ficha del paciente es UNA sola** (`SocioDetailView`). Antes había dos fichas del mismo
  paciente más pantallas propias de Indicaciones y Documentos que listaban las de **todos** los
  pacientes mezclados. Lo que era pantalla pasó a ser **tab de su paciente**.
- **Indicaciones es una tab del paciente** (admin y médico editan, supervisor lee) y arriba
  muestra el **consumo dispensado** (90 días, promedio mensual, sparkline) — que es el contexto
  con el que se prescribe.
- **Documentos: una sola puerta.** Convivían **dos modelos**: la pantalla del médico escribía
  `Documento` (sin cifrar) y la ficha lee `PatientDocument` (cifrado, con firma y hash), así que
  un PDF subido por una puerta **no aparecía nunca por la otra**. Ahora todo entra por
  `PatientDocument`, que sumó los tipos que faltaban (receta, certificado médico, estudio clínico,
  DNI). Los tipos institucionales del club **dejaron de ofrecérsele** al médico: no es él quien
  sube el estatuto.
- **Duración y vencimiento dejaron de pisarse.** Antes `calculate_fecha_vencimiento` sobrescribía
  el vencimiento **siempre** que hubiera `duracion_dias`, sin avisar: el médico escribía una fecha
  y el sistema se la cambiaba. Ahora la duración **propone** y **la fecha escrita a mano gana**;
  el formulario dice cuál de las dos manda, y la lista marca la indicación sin fecha con **"no
  genera alertas"**.
- **"Mis Pacientes" se pagina en el servidor**, con filtros y KPIs server-side (contando en el
  cliente, "3 vencidos" podía significar 40). El **orden es de agenda, no alfabético**: primero
  quien tiene turno con ese médico, después quien tiene una indicación por vencer — y la fila dice
  **por qué** está arriba.
- **Puede:** historia clínica completa, indicaciones + prescripción PDF, turnos (agenda,
  disponibilidad, check-ins), ver dispensaciones del paciente (lectura).
- **NO puede:** cultivo, stock, contabilidad, configuración del club.
- Tiene su **campana de alertas propia** en `MedicoTopBar` (el `NotificationBell` de `App.vue`
  pertenece al layout viejo y solo lo ven admin y cultivador).

### 👀 supervisor (shell principal)
Oversight de cultivo + un pie en lo comercial. Cultivo en **lectura**; **Tareas** y **Plan de
trabajo** con gestión; **dispensa** y **gestiona reservas**; ve (no edita) historia clínica.
Misma regla de visibilidad que el cultivador: **sin sedes asignadas ve todo el cultivo del club**.

### ⚖️ abogado (silo `/abogado`)
Cumplimiento legal, solo lectura: socios, reportes legales, informes REPROCANN y trazabilidad.

### 🔍 auditor (silo `/auditor`)
**Solo lectura global**, bloqueado a nivel `ApplicationController`. Ve los informes oficiales y
la Trazabilidad, con descarga PDF/Excel. No escribe absolutamente nada.

### 🚚 delivery (silo `/delivery`)
Reparte los despachos asignados: inicia viaje, navega, entrega con firma y foto, reporta fallo,
reprograma, cobra contra-entrega. **No ve qué ni cuánto** contiene el paquete (ni en la UI ni en
el payload): solo destinatario, dirección, contacto y monto a cobrar.

### 🛡️ super_admin (silo `/super-admin`)
Gestiona clubes, **módulos contratados** (suites + add-ons), métricas globales y el modo
observador (solo lectura). Carga la **API key de Pulse Grow** del club al activar IoT (cifrada,
igual que el token de Twilio; va por club porque la cuenta de Pulse es del club). **No ve datos de
salud** de los socios. **Suspender ≠ eliminar** un club.

### 🙋 paciente
Ve su perfil, sus dispensaciones, sus eventos y su carnet digital. La web pública y el pasaporte
de dispensa se acceden por **token, sin login**.

---

## 4. Flujos de trabajo (end-to-end)

### 4.1 El ciclo del lote — CAMBIÓ EL MODELO

> **Lo más importante de esta actualización.** `germinacion` y `esqueje` **dejaron de ser
> estados**: se colapsaron en **`enraizado`**. Cualquier manual escrito sobre el modelo viejo está
> mal.

**Dos ejes independientes:**
- **`estado`** (la etapa): `enraizado → vegetativo → floracion → cosecha → en_manicura → curado →
  finalizado`
- **`origen`** (de dónde viene la planta): `semilla | esqueje`

El origen **ya no define la fase inicial**: los dos arrancan enraizando. Eran dos estados para una
sola etapa —la planta sin raíz funcional— y lo que de verdad las separaba era el origen, que ya
vivía en su propia columna.

**Estados de la planta** (`Plant::STATES`): `enraizado, vegetativo, floracion, secado, cosechado,
descartada`. Las plantas **heredan la fase del lote** (`FASE_A_PLANT_STATE`), salvo las
descartadas.

> ⚠️ `secado` figura en `Plant::STATES` pero **ninguna transición lo produce** — no está en
> `FASE_A_PLANT_STATE`, y el comentario del modelo `Lote` dice explícitamente *"'secado' YA NO es
> un estado: es una métrica (días de cosecha→stock)"*. Es residuo. **No mencionarlo en los
> manuales.**

**El avance** (`AVANCE = enraizado → vegetativo → floracion → cosecha`) tiene **un paso menos** que
antes. Post-cosecha (`en_manicura`, `curado`) no va por `avanzar_fase!`: va por el flujo de
manicura.

#### Los tres relojes del lote
Esto es nuevo y es la clave para leer cualquier pantalla de cultivo:

| Reloj | Qué mide | Detalle |
|---|---|---|
| `dias_enraizado` | Cuánto tardó en prender | Corre mientras enraíza. Es lo que delata un propagador con problemas (manta térmica muerta, humedad baja) **antes** de que caiga el prendimiento. |
| `dias_ciclo` | El ciclo productivo | **Arranca en vegetativo, no en el esqueje.** `nil` mientras enraíza. |
| `dias_desde_inicio` | Total calendario | Desde `start_date`. |

**Por qué el ciclo no cuenta el enraizado:** en el domo la planta no crece, gasta reservas en
emitir raíz y ni siquiera come (por eso su registro no tiene EC ni pH). Contarlo como vegetativo
hace que un lote que tardó 20 días en prender aparente 20 días más de vege sin haber hecho un nudo
más, y ahí se pierde toda comparación entre lotes. Se informa aparte: *"45 días de ciclo + 12
enraizando"*.

En la UI son **dos columnas**: "En fase" (con el semáforo contra el objetivo) y "Total".

#### La sala impone el fotoperíodo, no la etapa
Una sala solo puede correr un fotoperíodo, así que lo que entra a un cuarto de 12/12 va a
florecer. Pero **enraizado y vegetativo comparten fotoperíodo** (los dos 18/6): meter un clonador
en una sala de vegetativo no le cambia nada.

- **De enraizado se sale cuando prende, no cuando cambia de cuarto.** Ni una sala de floración lo
  saca: un esqueje sin raíz no florece.
- **Un lote en floración no puede estar en una sala de vegetativo.**
- **Cambiar la fase de una sala ya no revegeta lotes en silencio.** El backend frena y devuelve
  qué lotes se verían afectados y cuántos días de fase pierde cada uno; recién con el sí explícito
  se guarda.

#### Prendimiento y maceta
- **Al salir del enraizado se declara cuántas prendieron** (un número). Es el único momento en que
  el dato existe y se sabe con certeza, mirando la bandeja. Las que no prendieron se marcan
  `descartada` + `no_prendio` — **no se borran**.
- **`motivo_descarte`** estructurado: `no_prendio, plaga, enfermedad, macho, hermafrodita, estres,
  rotura, otro`. Descartar una planta que estaba enraizando se clasifica sola como `no_prendio`.
  Revertir un descarte **borra el motivo**.
- **`GET /analytics/prendimiento`** — global y **por genética**, que es donde sirve: hay cepas que
  prenden al 95% y otras al 60%. Un lote que está enraizando **ahora no se mide**. Sin datos
  devuelve **nulo, no 0**. Tab **Prendimiento** en Analítica (≥85 verde, ≥70 amarillo).
- **La maceta se pide al prender** (validación `maceta_al_prender`): sin ese dato el lote entra a
  vegetativo sin saber en qué volumen crece, que es lo que gobierna riego y trasplante.
- **Alerta `maceta_chica` escalada por volumen** — el tiempo hasta que la raíz se enrolla depende
  de los litros: ≤0,4L → 12d; ≤0,6L → 18d; ≤1,5L → 25d; ≤4L → 35d; arriba de 4L se asume maceta
  final y no avisa. Se cuenta desde el **último trasplante** y **solo en vegetativo**.
- El badge muestra la maceta real (`Vegetativo · 0,5L`), no una etiqueta difusa. **"Vaso" salió**:
  el envase no es el dato, los litros sí.

#### Mover lotes
`POST /lotes/mover`, en tanda y **entre sedes**, desde `/lotes` (todos juntos) o desde la ficha de
la sala. El diálogo **enumera lote por lote qué va a cambiar** antes de confirmar. Mover a otra
sede cambia la sede del lote y con eso a dónde imputan sus costos. Los lotes post-cosecha se
ignoran: ya no viven en una sala.

#### El ciclo completo
1. **Cultivador** crea el lote (genética, sala, cantidad). Arranca **enraizando**.
2. Registra tareas, fotos, mediciones y análisis; avanza fases. Al salir del enraizado declara
   **cuántas prendieron** y **en qué maceta** van.
3. Al **cosechar**, el lote pasa a `cosecha`, **suelta la sala** y conserva la sede. Las plantas
   quedan `cosechado`. **La cosecha es un solo formulario** (antes el modal dependía de si el lote
   tenía plantas individuales cargadas, un dato que el cultivador no elige ni ve). La letra de
   corte se pide solo cuando aporta.
4. **Admin** asigna el lote a un manicura → `en_manicura`.
5. Manicura pesa → admin confirma → se crea el **stock de flor seca** → el lote pasa a `curado`.
6. `finalizado` cuando se agota el stock del lote.

> El cultivador que tocaba "avanzar fase" con el lote ya cosechado recibía *"Lote no puede
> transicionar en este estado"*. Ahora se le dice que **la asignación a manicura la hace el admin**.

### 4.2 Manicura (post-cosecha)
Sin cambios de fondo. Admin asigna → el manicura asignado pesa (QR por planta o "Registrar por
lote" con reparto promedio) dentro de una **jornada** → cierra y la manda a confirmar → admin
confirma → se crea/actualiza el contenedor de flor seca, con sede asignable en el momento.

**Verificado punta a punta** (`spec/requests/cultivo_ciclo_completo_spec.rb`) que el pesaje **por
la cola de aprobación y por el atajo del admin dan el mismo stock**, y que no se pueden saltear
pasos.

### 4.3 Dispensación
1. Desde la ficha del socio o el Historial se abre el **carrito** (`ModalNuevaDispensacion`),
   multi-producto: varias líneas, cada una con su stock, cantidad y precio.
2. Medio de pago: efectivo / transferencia / cuenta corriente / no abona / contra-entrega.
   Descuento sobre el total. Admin y supervisor pueden fijar **precio manual** por ítem.
3. Con **crédito de cuenta corriente** se puede dispensar sin pagar. **No hay límite mensual de
   gramos.**
4. Al confirmar: descuenta stock de cada línea, registra el movimiento contable y (si aplica) el
   débito de cuenta corriente.
5. **Con envío:** genera un despacho. **El dispensador puede asignarlo.**
6. **Editar/anular:** un solo modal de edición, con reconciliación de stock y cuenta corriente en
   transacción.

> Quién dispensa: **admin, supervisor, dispensador** (el médico desde su flujo de indicación, y
> delivery al entregar contra-entrega). El dispensador **no** ve datos clínicos.
> "Nueva dispensación" abre el flujo, no el historial.

### 4.4 Reservas
Admin/supervisor apartan stock para un socio con **fecha de entrega a partir de mañana** (una
reserva "para hoy" es una dispensa directa) y seña opcional. El stock queda **apartado**: baja el
disponible real sin descontar el físico. En la fecha, el **dispensador** (o admin/supervisor) la
convierte en dispensa cobrando el resto.

### 4.5 Delivery / despachos
Sin cambios: el despacho nace de una dispensa con envío, se asigna a un repartidor, y el delivery
entrega con firma y foto, cobra contra-entrega, reporta fallo o reprograma. **No ve el contenido
del paquete.**

### 4.6 Stock / inventario
- **KPIs:** *Flor seca disponible* (ya restando lo reservado), *Reservado (flor)*, *Por asignar*,
  *Sedes con stock*, *Derivados* (preroll, hash, aceite — con su propia unidad, no se suman a los
  gramos).
- **Alerta de stock bajo:** el umbral aplica **solo a flor seca**.
- **Origen:** producción propia (del cultivo) o **compra externa** (exige proveedor) — que es la
  única vía de entrada de un club que solo tiene la suite de Producción/Dispensa.

### 4.7 Contabilidad
- **Libro diario:** ingresos y egresos por categoría, balance y P&L por lote/genética.
- **"Sector" en vez de "área"**, y el área *Administración* pasó a llamarse **General**.
- **Alta de movimiento: un solo formulario** (rediseñado — primero el hecho, después el asiento).
  Incluye la opción **"En cuotas"** (solo egresos): el monto es el total y se generan N egresos
  mensuales desde la fecha elegida, backdateable.
- **Cierre de período:** el admin cierra meses (quedan inmutables). Guard: `hasta < hoy`.
- **Excel de contabilidad** funcional.
- No existe rol contador.

### 4.8 Ambiente / IoT (add-on `iot`)
- **El VPD que se muestra es el de HOJA, no el del aire.** La hoja transpira y se enfría respecto
  del aire, y ese par de grados decide un riego: con 26 °C y 60% de humedad, el de aire da
  1.35 kPa y el de hoja 0.97 — uno dice "está bien" y el otro "regá". Es también por qué el número
  no coincidía con el de la app del sensor: los dos eran correctos, medían cosas distintas.
- El ajuste es **por sala** (`salas.leaf_temp_offset`, default −2.0 °C) porque bajo LED la hoja se
  enfría más que bajo HPS. Se explica **en la propia pantalla**, al lado del número que produce.
- **Los dos "Pulse" son aparatos de empresas distintas** y la app los mezclaba:
  - **Pulse Grow** — monitor de sala con WiFi, sube a su nube solo. Tiene driver propio
    (`Sensors::PulseDriver`); antes caía en el genérico, que solo entiende claves en castellano, y
    **no registraba nada**.
  - **Bluelab Pulse** — medidor de mano de humedad y EC del **sustrato**, por Bluetooth. **No sube
    nada.**
- **Conectar un sensor es un solo paso:** al crear un equipo automático se genera el token y se
  muestran URL y token listos para copiar. A los de carga manual no se les pide token.
- La pantalla de ambiente de la sala tiene **solapa Sensores** con los de esa sala y si están
  mandando datos o mudos.
- **Rangos propios de enraizado** (antes se medía con la vara de vegetativo, que es lo opuesto):
  humedad 85–95%, temperatura 22–26 °C, EC 0–0.6, pH 5.5–6.0, **temperatura de sustrato 24–26 °C**
  (la variable que decide si prende). Chequeo diario: **1 día** sin registro, no 3 — es la etapa
  más frágil.
- **Los lotes enraizando no reciben el registro ambiental de la sala**: viven en un propagador con
  su propio clima (la sala marca 60% y adentro hay 90%).
- **El ambiente de la sala** es el registro más reciente entre sus lotes, mostrado **siempre con
  su antigüedad y el lote del que salió** — sin sensores el dato puede ser de hace una semana.

### 4.9 Asistente IA por voz (add-on `ia`)
Sin cambios de fondo. Tres modos: **Registrar por voz** (parsear → confirmar → ejecutar),
**Consultar** y **Análisis IA de lote** (solo admin/supervisor). El cultivador **no puede crear
tareas** por voz. Máx. 15 acciones por comando, deduplica idénticas, *registra solo lo mencionado,
nunca inventa valores*.

> Relacionado pero distinto: la **generación IA del plan de trabajo** (`PlanTrabajoIaService`) es
> del módulo Cultivo, no del asistente de voz.

### 4.10 Configuración (admin)
General (datos del club, tipo de organización), Suscripción, **Equipo** (ver §3), **Sedes** —que
había desaparecido del menú al reagrupar los flags y **volvió**—, **Alertas**, **Sitio web**,
**Integraciones**, **Papelera**.

---

## 5. Informes — CAMBIARON DE RAÍZ

**Seis de los siete informes generaban su PDF con `html2canvas`: el archivo era una foto JPEG de
la página web.** Sin texto seleccionable ni buscable, con la calidad atada al zoom del navegador,
columnas cortadas donde cayeran y sin membrete. Solo REPROCANN tenía un PDF de verdad.

**Ahora los siete se generan en el servidor** (`InformeDocument`, sobre la infraestructura del PDF
de REPROCANN) y **los siete tienen Excel**, que antes no existía en ninguno: montos como números,
totales, autofiltro y encabezados fijos.

Cada informe se define **una vez** —sus KPIs y sus tablas— y de esa definición salen la respuesta
JSON, el PDF y el Excel, así los tres dicen exactamente lo mismo.

- **Informe semestral REPROCANN** — el documento regulatorio más completo del club. **Su nómina NO
  va anonimizada**, a diferencia del resto: se presenta ante la autoridad, que necesita
  identificar a cada paciente.
- **P&L de producción** — PDF y Excel, con los meses arriba y la proyección de lotes en curso
  aparte, aclarando que son estimados y no dinero realizado.
- **Trazabilidad** — reconstruye la cadena en el orden en que se recorre: producto → genética →
  lote → plantas → entregas, con pacientes anonimizados. Es lo primero que pide un auditor.
- **Analítica queda como captura, a propósito**: ahí el contenido son los **gráficos**, y
  rasterizarlos es lo correcto. Para los números está el CSV de cada solapa.

**El índice de Reportes se reorganizó por para qué sirve cada informe**, no por qué módulo lo
produce:

| Grupo | Para qué |
|---|---|
| **Cumplimiento** | Lo que hay que mostrar si golpean la puerta |
| **Operación** | Cómo viene el club |
| **Análisis** | Para decidir |

Cada tarjeta dice **qué pregunta contesta** ("¿está todo el mundo en regla?", "¿cuánto sale y a
cuántos?"). Trazabilidad estaba en el menú lateral pero no en este índice; ahora sí.

### ⚠️ Detalle de cada informe
Las definiciones de qué muestra y cómo se calcula cada informe (REPROCANN, Producción,
Dispensaciones, Sedes, Cumplimiento, Plan vs Real, INASE, Trazabilidad, y la analítica interna:
rendimiento por genética, pérdidas, ciclos, comparativa, P&L por lote, comparativa de salas,
ejecutivo, correlación ambiental) **estaban documentadas en la versión de julio y no se
reverificaron en esta pasada.** Hubo un commit de "auditoría de informes: que los totales cierren"
(#29) que puede haber cambiado cálculos.

**Antes de escribir el manual de Reportes hay que releer esa sección contra el código.** Se
conserva en el historial de git: `git show 10e6580:docs/GUIA_USUARIOS.md`, sección 4.

Dos cosas que sí siguen valiendo:
- Las dispensaciones cuentan siempre **no canceladas**.
- Los datos de socios salen **anonimizados** (iniciales + últimos 4 del DNI) **en todos los
  informes menos el semestral REPROCANN**.

---

## 6. Notas para armar los manuales

**Alcance acordado (fases):** `admin` → `cultivador` → `manicura` → `dispensador` → `medico`.
Sin capturas de pantalla por ahora: se nombra el botón exacto en **negrita**. Si más adelante se
agregan, hay que revisarlas en cada release.

**Estructura:** un archivo por **tarea** con `roles:` y `plataforma:` en el frontmatter, y el
manual de cada rol se **compila** de las tareas que lo mencionan. Una tarea escrita una vez
aparece en los tres manuales que la necesitan.

**Móvil no lleva manual aparte:** bloque `📱 En el teléfono` dentro de cada tarea, solo donde
difiere de verdad.

### Las reglas "sorpresa" que hay que recalcar
- **El ciclo arranca en `enraizado`**, venga de semilla o de esqueje. El origen es un dato aparte,
  no una fase.
- **El ciclo productivo se cuenta desde vegetativo.** El enraizado se informa por separado.
- **De enraizado se sale cuando prende**, no al cambiar de sala.
- **Al prender hay que declarar cuántas prendieron y en qué maceta van** — sin la maceta no avanza.
- **Manicura:** solo el asignado pesa el lote; el peso va por el pesaje, no se edita suelto.
- **Cultivador sin sedes asignadas ve TODO el cultivo del club** (no es un bug).
- **El cultivador no crea salas** y no asigna manicura.
- **Dispensador:** no ve historia clínica; convierte reservas pero no las crea; puede comprar
  mercadería del Buffet pero **no reponer**.
- **Delivery:** no ve el contenido del paquete.
- **Reservas:** la fecha es a partir de mañana.
- **Stock:** los gramos son solo flor seca; los derivados van aparte.
- **Médico:** la duración **propone** el vencimiento, la fecha escrita a mano **gana**; una
  indicación sin fecha **no genera alertas**.
- **El VPD que muestra la app es el de hoja** — no coincide con el del sensor y está bien.
- **Lo que ve cada rol depende primero del módulo contratado**, después del rol.

**Público sin login:** carnet del socio, pasaporte de dispensa (con gate de DNI) y web del club,
por token/QR.
