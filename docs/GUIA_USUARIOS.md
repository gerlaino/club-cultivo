# Guía de usuarios y flujos — Club Cultivo

> Documento de referencia para armar tutoriales. Refleja el estado real del código a
> **julio 2026**. Cubre los 11 roles, qué puede/no puede cada uno, qué ve en pantalla y el
> flujo de trabajo de cada sección. Si algo contradice al código, manda el código.

App: **Vue 3 (SPA) + Rails 7.2 (API)**. Multi-tenant: cada club es un tenant aislado por
`club_id`. Contexto legal argentino: REPROCANN, ARICCAME/ANMAT, Ley 25.326 (datos de salud).

---

## 1. Cómo funciona el acceso (dos modelos)

Hay **11 roles**: `super_admin, admin, medico, cultivador, supervisor, abogado, auditor, dispensador, manicura, paciente, delivery`.

El acceso se resuelve de dos formas según el rol:

- **Roles "silo" (bloqueados a su sección):** `super_admin`, `auditor`, `medico`, `abogado`,
  `delivery`. Cada uno arranca en su home y **solo** puede navegar dentro de su prefijo
  (ej. el médico solo `/medico/*`, el delivery solo `/delivery/*`). Si intentan ir a otra
  parte, los devuelve a su home.
- **Roles del shell principal (gateados por permiso de ruta):** `admin`, `supervisor`,
  `cultivador`, `dispensador`, `manicura`. Comparten la app con el sidebar por secciones;
  cada ruta se habilita/oculta según una matriz de permisos por recurso/acción.
- **`paciente`:** no usa el panel del club; tiene su perfil, sus dispensaciones y su carnet
  digital (más web pública por token, sin login).

> Nota técnica: la autorización **fina del backend** hoy es por chequeos ad-hoc en cada
> controller (no por la matriz). La matriz vive en el frontend (navegación/UI). Para los
> tutoriales, lo que importa es el comportamiento efectivo, que es el que se describe abajo.

**Móvil / PWA:** `admin, supervisor, cultivador, manicura, delivery` tienen vistas móviles
optimizadas (rutas `/m/*`), pensadas para trabajar en la sala / en la calle desde el teléfono.

---

## 2. Roles — qué puede y no puede cada uno

### 👑 admin
**Es el dueño operativo del club. Puede todo dentro de su club.**
- **Ve:** todas las secciones del sidebar — Dashboard, Cultivo (Salas, Lotes, Plantas,
  Genéticas), Pacientes (+ Dispensaciones + REPROCANN), Producción (Stock, Cosecha,
  Manicura), Comercial (Reservas, Despachos, Contabilidad), Tareas (+ Plan de trabajo),
  Reportes (Analítica, Auditoría, Trazabilidad, ARICCAME, Documentos), Configuración
  (General, Suscripción, Equipo, Sedes, Alertas, Sitio web, Integraciones, Papelera).
- **Puede:** crear/editar/borrar en todos los módulos; aprobar pesajes de manicura; cerrar
  curado y generar stock; confirmar/editar dispensaciones; gestionar reservas; ver y editar
  historia clínica; cerrar períodos contables; gestionar el equipo y las sedes; configurar
  ambiente/alertas; restaurar desde la Papelera.
- **NO puede:** cosas de plataforma (planes globales, otros clubes) — eso es del super_admin.
- **Restricción nueva:** en un lote **asignado a un manicura**, el admin **no** registra el
  peso desde el detalle de la planta ni desde el batch: eso lo hace el manicura asignado
  (ver flujo de Manicura). El admin sí puede si el lote no tiene manicura asignado.

### 🧑‍⚕️ medico (silo `/medico`)
**Solo su sección clínica.** Módulo médico completo.
- **Puede:** ver/crear/editar **pacientes** (los suyos, con seguimiento médico); **historia
  clínica** completa (anamnesis, diagnósticos, evolución, alergias, medicación, notas
  clínicas); **indicaciones médicas** (crear/editar) y generar la **prescripción PDF**;
  **turnos** (agenda, disponibilidad, check-ins, fichas); ver dispensaciones del paciente
  (lectura) y reportes médicos.
- **NO puede:** cultivo, stock, dispensar, contabilidad, configuración del club. Está
  encerrado en `/medico`.

### 🌱 cultivador (shell principal, foco Cultivo)
**Opera el cultivo de las salas/sedes que tiene asignadas.**
- **Puede:** Plantas (CRUD), Lotes (CRUD), Salas (CRUD), Plan de trabajo, mediciones y
  ambiente (dispositivos, lecturas, setpoints por fase, reglas y alertas), Genéticas
  (lectura), reportes de cultivo. Registra riego/fertilización/podas, avanza fases,
  cosecha plantas, carga fotos y análisis de laboratorio.
- **Ve solo lo suyo:** los lotes/plantas se filtran por las **salas de sus sedes asignadas**.
- **NO puede:** pacientes, dispensación, stock/comercial, contabilidad, configuración,
  reportes oficiales. En la práctica su ciclo termina cuando el lote pasa a **cosecha**
  (ahí lo toma manicura/admin).

### 👀 supervisor (shell principal)
**Rol de oversight de cultivo + un pie en lo comercial.**
- **Puede (cultivo, lectura):** Salas, Lotes, Plantas, Sedes, Genéticas — solo ver.
- **Puede (gestión):** **Tareas** (crear/editar/borrar/asignar) y **Plan de trabajo**.
- **Puede (comercial):** **dispensar** y **gestionar reservas** (crear/editar/cancelar) —
  esto va más allá de la matriz de navegación; es comportamiento de dominio.
- **Puede (clínico, lectura):** ver **historia clínica** del paciente (junto a admin y
  médico) — pero **no** la edita.
- **NO puede:** editar cultivo (solo lectura), configuración del club, cerrar contabilidad.

### ⚖️ abogado (silo `/abogado`)
**Cumplimiento legal, solo lectura.**
- **Puede:** ver **socios** (lectura), **reportes legales**, **informes REPROCANN** y
  **trazabilidad**.
- **NO puede:** nada operativo (ni cultivo, ni dispensar, ni configurar). Encerrado en
  `/abogado`.

### 🔍 auditor (silo `/auditor`)
**Solo lectura global, para auditorías/inspecciones.**
- **Puede:** ver informes oficiales (Producción, Cumplimiento, Sedes, Dispensaciones,
  Plan vs Real, INASE, REPROCANN), **Trazabilidad** (cadena origen→cultivo→stock→dispensa),
  plantas, lotes, socios, lecturas ambientales y alertas — **todo en modo lectura**. Puede
  **descargar PDF** de los informes.
- **NO puede:** escribir absolutamente nada. Bloqueado a nivel `ApplicationController`.

### 💊 dispensador (shell principal, foco Dispensación)
**Atiende el mostrador: dispensa y maneja el stock de su sede.**
- **Puede:** ver **socios** (lectura) y crear pacientes básicos (sin seguimiento médico,
  dispara una alerta al admin); **dispensar** (carrito multi-producto, medios de pago,
  descuento, crédito de cuenta corriente); ver el **inventario por sede**; ver tareas y
  notas de socio (crear notas).
- **Reservas:** **convierte** una reserva en dispensa (acción *Entregar*), pero **no** las
  crea ni las gestiona (eso es admin/supervisor).
- **NO puede:** ver **historia clínica** (bloqueado: solo ve datos no clínicos del socio);
  cultivo, contabilidad, configuración, informes oficiales.

### ✂️ manicura (home `/mnc/pendientes`)
**Post-cosecha: pesa las cosechas que el admin le asigna.**
- **Puede:** ver sus **lotes en manicura asignados** (cola en `/mnc/pendientes`); registrar
  el **peso** de las plantas del lote — escaneando el QR de cada planta o con "Registrar por
  lote" (carga conjunta, eligiendo qué plantas); ver el inventario de manicura, lotes y
  genéticas (lectura).
- **Regla nueva (provisorio):** si un lote está **asignado a un manicura**, **solo esa
  persona** registra el peso (ni el admin ni otro manicura, para evitar ediciones
  concurrentes que "pierden" la planta). Cuando cierra la jornada, la manda **a confirmar**;
  el admin la aprueba y ahí se genera el stock de flor seca.
- **NO puede:** dispensar, ver pacientes/clínico, contabilidad, configuración.

### 🚚 delivery (silo `/delivery`)
**Reparte los despachos que tiene asignados.**
- **Puede:** ver sus **paquetes** (pendiente / en viaje / entregado / fallido); iniciar
  viaje, navegar a la dirección, **entregar** (con firma y foto), reportar fallo,
  reprogramar; cobrar **contra-entrega** (efectivo/transferencia) cuando corresponde.
- **NO puede/NO ve:** por privacidad, **no ve qué ni cuánto** contiene el paquete (ni en la
  UI ni en el payload); solo ve destinatario, dirección, contacto y el monto a cobrar.
  Nada de cultivo, pacientes, stock ni configuración.

### 🛡️ super_admin (silo `/super-admin`)
**Rol de plataforma (no de un club).**
- **Puede:** gestionar **clubes**, **planes** (límites vía PlanEnforcer), métricas globales,
  usuarios de plataforma, y el **modo observador** (entrar a un club en solo-lectura).
- **NO puede/NO debe:** ver **datos de salud** de los socios (por diseño de privacidad queda
  fuera de la historia clínica). No tiene club propio.

### 🙋 paciente
**El socio del club (no opera el panel).**
- **Puede:** ver **su perfil**, **sus dispensaciones**, sus **eventos**, y su **carnet
  digital** (QR público). La web pública del club y el pasaporte de dispensa se ven por
  **token, sin login**.
- **NO puede:** nada del panel de gestión.

---

## 3. Flujos de trabajo por sección (end-to-end)

### 3.1 Cultivo → cosecha → stock (el ciclo central)

El **lote** es la unidad que avanza de fase, y **las plantas heredan la fase del lote**: al
avanzar el lote, sus plantas (salvo las descartadas) toman el estado que corresponde
(`FASE_A_PLANT_STATE`).

- **Lote** (`Lote::ESTADOS`): `semilla`/`esqueje` → `vegetativo` → `floracion` → `cosecha` →
  `en_manicura` → `curado` → `finalizado`.
- **Planta** (`Plant::STATES`): arranca en `germinacion` (semilla) o `esqueje`; **hereda**
  `vegetativo` y `floracion` del lote; cuando el lote pasa a **cosecha**, todas quedan
  `cosechado`. `descartada` es una baja individual.
- **Post-cosecha:** con el lote en `en_manicura`/`curado`/`finalizado`, la planta sigue en
  `cosechado` — la etapa fina (en manicura, curado) se lee del **estado del lote**, no de un
  estado propio de la planta. (Por eso en `/lotes` y `/plantas` la etapa post-cosecha se
  deriva del lote.)

1. **Cultivador** crea el **lote** (genética, sala, cantidad de plantas). Empieza en
   vegetativo (o semilla/esqueje según origen).
2. Durante el ciclo registra tareas (riego, fertilización, poda), fotos, mediciones
   ambientales y análisis de laboratorio; **avanza las fases** cuando corresponde. El
   timeline del lote muestra: germinación → vegetativo → floración → cosecha → **en
   manicura** → curado.
3. Al **cosechar**, el lote pasa a estado `cosecha` (ya no tiene sala física; se ve en
   Producción → Cosecha). Las plantas quedan `cosechado`.
4. **Admin** asigna el lote a un **manicura** → pasa a `en_manicura` (ver 3.2).
5. Manicura pesa → admin aprueba → se genera **stock de flor seca** (`en_manicura → curado`).
6. El stock se asigna a una sede y queda disponible para dispensar (ver 3.3).

> Regla de dominio: una planta/lote cuenta como **"en ciclo activo" hasta curado** (recién
> ahí se vuelve stock). El secado es tiempo, no una sala.

### 3.2 Manicura (post-cosecha)
1. **Admin** (Producción → Manicura, o desde el lote) **asigna** el lote cosechado a un
   manicura. El lote pasa a `en_manicura` y aparece en `/mnc/pendientes` de ese manicura, y
   en el board del admin con su **responsable**.
2. **El manicura asignado** pesa: escanea el QR de cada planta (peso por planta) o usa
   "Registrar por lote" (carga conjunta, **seleccionando qué plantas** y un peso total que
   se reparte como promedio). El peso siempre queda dentro de una **jornada (pesaje)**.
3. Cierra la jornada → **la envía a confirmar**.
4. **Admin** revisa y **confirma** el pesaje → se crea/actualiza el **contenedor de flor
   seca** (stock) del lote. Puede asignarle sede en el momento.
5. El lote pasa a `curado` (o queda para curado) y la flor seca queda como stock.

> Solo el manicura asignado escribe el peso de un lote asignado. El "Guardar peso" del
> detalle de la planta va por el flujo de pesaje (no edita el peso "suelto").

### 3.3 Dispensación
1. Desde la **ficha del socio** (o desde el Historial de dispensaciones), se abre el
   **carrito** (ModalNuevaDispensacion). Es **multi-producto**: varias líneas, cada una con
   su stock, cantidad y precio.
2. Se elige **medio de pago**: efectivo / transferencia / cuenta corriente / no abona /
   contra-entrega. Se puede aplicar **descuento** sobre el total. El admin/supervisor puede
   fijar un **precio manual** por ítem si el producto no tiene precio (y guardarlo en el
   producto).
3. Si el socio tiene **crédito de cuenta corriente**, puede dispensar sin pagar (queda como
   saldo). No hay límite mensual de gramos.
4. Al confirmar, se **descuenta el stock** de cada línea, se registra el movimiento
   contable y (si aplica) el débito de cuenta corriente.
5. **Con envío:** se genera un **despacho** para delivery (ver 3.4).
6. **Editar/anular:** el admin puede editar una dispensa multi-ítem (cantidad y precio por
   línea) — el sistema reconcilia stock y cuenta corriente en transacción.

> Quién dispensa: **admin, supervisor, dispensador** (el **médico** también puede, desde su
> flujo de indicación; y **delivery** al entregar contra-entrega).
> El dispensador **no** ve datos clínicos del socio.

### 3.4 Reservas
1. **Admin/supervisor** crean una **reserva**: apartan stock de flor seca para un socio, con
   una **fecha de entrega a partir de mañana** (una reserva "para hoy" es una dispensa
   directa) y una **seña** opcional.
2. El stock reservado queda **apartado**: baja el "disponible real" (se ve en el KPI
   *Reservado (flor)* del Stock) sin descontar el stock físico.
3. En la fecha, se **entrega**: el **dispensador** (o admin/supervisor) convierte la reserva
   en **dispensa**, cobrando el resto (total − seña).
4. Las reservas del día aparecen en el **dashboard del admin**.

### 3.5 Delivery / despachos
1. Una dispensación **con envío** genera un **despacho** (paquete). El admin/dispensador lo
   asigna a un **repartidor** (delivery) y arma la ruta.
2. **Delivery** ve sus paradas: inicia viaje, navega, y en cada entrega toma **firma** y
   foto; si es **contra-entrega**, cobra (efectivo/transferencia). Puede reportar fallo o
   reprogramar.
3. El delivery **no ve el contenido** del paquete (privacidad), solo destinatario,
   dirección, contacto y monto a cobrar.

### 3.6 Stock / inventario (Producción → Stock)
- **KPIs:** *Flor seca disponible* (gramos reales, ya restando lo reservado), *Reservado
  (flor)* (lo apartado, si hay), *Por asignar*, *Sedes con stock*, *Derivados* (ítems no-flor
  como preroll, hash, aceite — inventario con su propia unidad, no se suma a los gramos).
- **Alerta de stock bajo:** el umbral (ej. 250 g) aplica **solo a flor seca**; los derivados
  no se comparan contra ese umbral.
- **Producción propia vs externa:** la flor sale del cultivo (origen lote); los derivados se
  producen consumiendo flor; también se puede **agregar stock externo** (comprado).

### 3.7 Contabilidad (Comercial → Contabilidad)
- **Libro diario:** ingresos y egresos, por categoría, con balance y P&L por lote/genética.
- **Nuevo movimiento:** en *Detalle de pago → medio de pago* hay una opción **"En cuotas"**
  (solo egresos): el monto es el **total** y se generan N egresos **mensuales**, uno por mes
  desde la fecha elegida (se puede backdatear). Sirve para una compra financiada (ej. un aire
  en 6 cuotas con la tarjeta del club); cada cuota impacta el balance de su mes.
- **Cierre de período:** el admin puede cerrar meses (quedan inmutables).
- No existe rol contador; la contabilidad la lleva el admin.

### 3.8 Ambiente / IoT (Cultivo)
- Dispositivos con webhook token, lecturas (temp, humedad, CO₂, pH, EC, PPFD), **setpoints
  por fase**, reglas y **alertas**, cálculo de **VPD**. Drivers: Sonoff, CSV manual, CSV-IA.
- El **dashboard del admin** muestra un widget de **Ambiente** con la última lectura por sala
  (temp/humedad + frescura); si no hay sensores, un vacío con CTA para configurar.
- Lo operan **cultivador** (sus salas) y **admin**.

### 3.9 Informes, Trazabilidad y ARICCAME (Reportes / auditor)
- **Analítica** (admin/supervisor): rendimiento por genética, ciclos, pérdidas, comparativa; export
  CSV/PDF. La ficha de cada **genética** muestra su historial de rendimiento (g/planta, avg,
  desvíos) + sparkline.
- **Auditoría** (auditor/admin): informes oficiales (Producción, Cumplimiento, Sedes,
  Dispensaciones, Plan vs Real, INASE, REPROCANN) con descarga PDF.
- **Trazabilidad:** cadena completa de un stock (origen → cultivo → plantas → dispensaciones)
  con verificación de compliance.
- **ARICCAME:** reporte regulatorio ANMAT de dispensaciones y stock (feature flag por club).

### 3.10 Configuración (admin)
General (datos del club, tipo de organización — usado en informes regulatorios), Suscripción
(plan), **Equipo** (alta de usuarios y roles), **Sedes**, **Alertas** (umbrales/setpoints),
**Sitio web** público del club, **Integraciones** (email/WhatsApp), **Papelera**
(restaurar registros borrados por soft-delete).

---

## 4. Informes en detalle (qué son, para qué, qué muestran y cómo se calculan)

Hay dos familias de reportes con acceso distinto:
- **Auditoría** (Reportes → Auditoría): acceso **auditor + admin**. Son los informes
  "oficiales/regulatorios", con descarga PDF (y Excel en REPROCANN).
- **Analítica** (Reportes → Analítica): acceso **admin + supervisor** (y super_admin en modo
  observador). Son los reportes internos de gestión.

Casi todos toman un **período** (mes actual / mes anterior / trimestre / año). Las
dispensaciones cuentan siempre **no canceladas**. Los datos de socios salen **anonimizados**
(iniciales + últimos 4 del DNI).

### A) Reportes de Auditoría (auditor / admin)

**REPROCANN** — *estado del registro de todos los socios.*
- Para qué: control de vigencia REPROCANN; documento presentable (PDF/Excel).
- Muestra: total de socios; con REPROCANN vigente; vencen en ≤30 días; vencidos; sin
  REPROCANN; y una lista anonimizada (iniciales, últimos 4 del DNI, estado, vencimiento).
- Cálculo: cuenta socios del club comparando `reprocann_vencimiento` con hoy — vigente
  (≥ hoy), por vencer (≤ 30 días), vencido (< hoy), sin REPROCANN (`reprocann_numero` nulo).

**Producción** — *resumen productivo del club en el período.*
- Muestra: total de lotes; lotes activos (no finalizados); lotes cosechados (finalizados en
  el período); **gramos producidos**; plantas totales (activas); y un desglose por estado
  (lotes + gramos por estado).
- Cálculo: `gramos_producidos` = suma de `peso_curado_g` de las **pesadas** con
  `fase_destino = finalizado` registradas en el período. `plantas_totales` = plantas que no
  están `cosechado`/`finalizado`, en las sedes del club.
- Ojo (limitación conocida): la columna "plantas por estado" viene en **0** (no se computa
  por estado, solo el total).

**Dispensaciones** — *actividad de dispensación del período (anonimizada).*
- Muestra: total de dispensaciones; gramos dispensados; pacientes atendidos (distintos);
  promedio por dispensación; y un resumen por paciente (iniciales, cantidad, total g, última
  fecha) — hasta 100.
- Cálculo: dispensaciones no canceladas del club en el período; `gramos` = suma de
  `cantidad`; `promedio` = gramos ÷ total.

**Sedes** — *foto por sede.*
- Muestra: total de sedes; activas; salas totales; plantas totales; y por sede: salas de
  cultivo, plantas activas y **stock disponible (g)**.
- Cálculo: plantas = Plant no cosechado/finalizado por sede; `stock_disponible` = **solo flor
  seca** disponible (g) de esa sede (los derivados no se suman como gramos).

**Cumplimiento** — *tablero de cumplimiento REPROCANN + alertas.*
- Muestra: socios con REPROCANN vigente; vencen 30d; vencidos; "dispensaciones sobre límite";
  **tasa de cumplimiento** (%); y alertas (vencidos, por vencer, sin seguimiento médico).
- Cálculo: `tasa = con_vigente ÷ total × 100`. Aclaración: "dispensaciones sobre límite" en
  realidad cuenta dispensaciones a socios **sin número REPROCANN** en el período (nombre
  heredado — no existe límite mensual de gramos).

**Plan vs Real** — *objetivo vs resultado real por lote.*
- Muestra: lotes con objetivo (rendimiento o cantidad de plantas); por lote, objetivo vs
  real y la **desviación %**; y el promedio de desviación de los lotes cerrados.
- Cálculo: `desv_rendimiento = (real − objetivo) ÷ objetivo × 100`;
  `desv_plantas = (cosechadas − objetivo) ÷ objetivo × 100`.

**INASE** — *registro de variedades ligado a la producción real.*
- Para qué: informe regulatorio de variedades cultivadas.
- Muestra: por genética, sus datos INASE (registrada, número, categoría, fecha, criador),
  THC/CBD, y lo que **produjo** (lotes, plantas, gramos); + totales (registradas / sin
  registrar / gramos / lotes).
- Cálculo: por genética — lotes = count; plantas = suma de `plants_count`; gramos = suma de
  `rendimiento_real_g`.

**Trazabilidad** — *cadena de custodia de un stock.*
- Muestra, escaneando/eligiendo un stock: origen → lote → plantas de origen → dispensaciones,
  con genética, cantidades y verificación de compliance. Es la trazabilidad "de la góndola a
  la planta".

### B) Analítica interna (admin / supervisor)

**Rendimiento por genética** — *qué cepa rinde mejor.*
- Muestra: por genética — lotes totales/finalizados, **rendimiento promedio (g)**, objetivo
  promedio, desviación %, **merma % promedio**, **g/planta**; + top 20 lotes recientes; +
  resumen global.
- Cálculo: rendimiento promedio = media de `rendimiento_real_g` de los lotes con dato;
  merma % = media de `(plants_count − plants_count_cosechadas) ÷ plants_count × 100`;
  g/planta = media de `(rendimiento_real_g ÷ plants_count)`.

**Producción: Pérdidas / Ciclos / Comparativa**
- **Pérdidas** (por genética): merma % = `(total − cosechadas) ÷ total`; descarte % =
  `descartadas ÷ total`, por lote y promediado.
- **Ciclos** (por genética): **días promedio por fase** (vegetativo, floración, cosecha,
  secado, curado), calculados con los **`lote_eventos`** (cambios de estado) — días reales
  entre transiciones. Además desglosa la propagación (días de propagación / vegetativo puro)
  usando `start_date`.
- **Comparativa**: lotes finalizados de la **misma genética** (2 o más) enfrentados —
  rendimiento, objetivo, plantas, tipo de cultivo y luz.

**P&L por lote** — *rentabilidad de cada lote.*
- Muestra: por lote — costo total, costo/gramo, **ingresos**, gramos dispensados,
  ingreso/gramo, **margen** y margen %.
- Cálculo: ingresos = suma de `cantidad × precio_unitario_ars` de las dispensaciones no
  canceladas de ese lote; margen = ingresos − costo total.

**Contabilidad (P&L mensual)** — *últimos 12 meses + proyección.*
- Muestra: por mes — ingresos, costos, margen; + proyección de los lotes en curso.
- Cálculo: **ingresos = del libro de caja** (`MovimientoContable` de tipo ingreso, incluye
  señas/aportes, excluye crédito impago) — no se recomputa desde dispensaciones. Costos =
  `CostoLote` del mes. Proyección = lotes en curso × rendimiento objetivo × precio sugerido.

**Comparativa de salas** — *qué sala produce mejor.*
- Muestra: por sala — ciclos (lotes finalizados), kg producidos, kg/planta, **días promedio**
  del ciclo, lotes activos y la **última lectura ambiental** (temp/humedad/CO₂).
- Cálculo: días promedio = media de `(fecha de finalización − start_date)` desde
  `lote_eventos`; kg = `rendimiento_real_g ÷ 1000`.

**Ejecutivo (resumen anual)** — *año actual vs anterior.*
- Muestra: gramos producidos, gramos dispensados, ingresos, costo total, margen, margen %,
  ciclos cerrados — del año en curso comparado con el anterior.

**Correlación ambiental** — *¿el ambiente explica el rendimiento?*
- Muestra: correlación (Pearson **r**, **r²**) y regresión lineal entre variables
  ambientales y el rendimiento de los lotes (requiere ≥3 lotes con datos).

### C) Otros
- **Informe semestral:** resumen consolidado del semestre (producción + dispensaciones).
- **ARICCAME:** reporte regulatorio ANMAT de dispensaciones y stock (feature flag por club).
- **Dashboard del dispensador** (datos, no un informe formal): gramos de hoy/semana/mes,
  reservas del día, etc. Acceso admin/dispensador.

---

## 5. Notas para armar los tutoriales

- **Por rol:** conviene un tutorial por rol que arranque en su **home** y recorra solo lo que
  ese rol ve (no mostrarle al delivery cosas de cultivo, etc.).
- **Recalcar las reglas "sorpresa":**
  - Manicura: solo el asignado pesa el lote; el peso va por el pesaje (no se edita suelto).
  - Dispensador: no ve historia clínica; convierte reservas pero no las crea.
  - Delivery: no ve el contenido del paquete.
  - Reservas: la fecha es a partir de mañana.
  - Stock: los gramos son **solo flor seca**; los derivados van aparte.
  - "En ciclo activo" hasta curado; el secado es tiempo, no sala.
- **Móvil:** cultivador, manicura y delivery trabajan principalmente desde el teléfono (PWA).
- **Público sin login:** carnet del socio, pasaporte de dispensa (con gate de DNI) y web del
  club se acceden por token/QR.
