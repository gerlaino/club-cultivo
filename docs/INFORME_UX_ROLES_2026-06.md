# Informe UX/UI por rol — Club Cultivo
**Fecha:** 2026-06-12 · **Autor:** Claude
**Método:** lectura del código de las ~75 vistas, router, composables y flujos — **no ejecuté la app**. Donde opino "como usuario" estoy infiriendo la experiencia desde el código; lo marco cuando la confianza es baja. Para validar esto en serio, el siguiente paso natural es una sesión conmigo ejecutando la app rol por rol (`/run`).

---

## Parte 1 — Opinión sincera, rol por rol

### 👑 Admin del club
**Lo que tiene:** el rol más rico por lejos — dashboard propio, aprobaciones (manicura, stocks pendientes, curado), socios + críticos REPROCANN, analítica con 4 tabs, contabilidad con P&L, configuración unificada, navegación TopBar + sidebar contextual.

**Mi experiencia simulada:** es el rol mejor servido, pero también el más **sobrecargado de superficie**: el admin tiene acceso a todo y la consecuencia es que su mapa mental de la app es enorme. La navegación rediseñada (tabs primarios + sidebar contextual) fue la decisión correcta. Lo que me falta como admin es **jerarquía de urgencia**: tengo aprobaciones pendientes, socios con REPROCANN por vencer, alertas ambientales y stock bajo — cada una vive en su sección. Un admin real abre la app a la mañana y quiere una sola respuesta: *"¿qué necesita mi decisión hoy?"*. El dashboard muestra métricas; lo que pediría es una **bandeja de pendientes accionable** (aprobar desde ahí mismo) como módulo central del dashboard.

**Fricciones concretas:** `AdminStocksPendientesView` con 1.642 líneas sugiere una pantalla que acumuló demasiados modos; las aprobaciones de manicura, curado y stock son tres vistas separadas para lo que conceptualmente es una sola cola de trabajo.

### 🌱 Cultivador
**Lo que tiene:** dashboard con tareas del día y próximas cosechas, lotes/plantas/salas con QR, plan de trabajo (+IA), registro rápido vía RegistroLoteModal de 2 pasos, ambiente por sala, app móvil — el único rol con experiencia mobile completa.

**Mi experiencia simulada:** es el rol donde el producto entiende mejor a su usuario. El cultivador trabaja con las manos sucias y guantes, y la inversión en mobile + QR + AccionsDropdown ⚡ + registro en 2 pasos refleja eso. Mi crítica honesta: **la fricción residual está en la captura de datos ambientales manuales** — `registros_ambientales` tiene ~17 campos (temperatura, humedad, VPD, pH, EC, runoff…); si el form los expone todos cada vez, el cultivador va a dejar de cargarlos a la semana. La data ambiental es tu activo para las Fases 4-5: cada campo de fricción de carga es data que no vas a tener. Verificaría que el form tenga "carga mínima rápida" (3 campos) vs "carga completa".

**Fricción concreta:** la divergencia app vs. realidad que vos mismo documentaste (secado = tiempo, no sala) — si el modelo de fases obliga al cultivador a "mover" lotes a una sala de secado que no existe físicamente, cada cosecha genera un registro mentiroso.

### ✂️ Manicura
**Lo que tiene:** flujo completo y bien secuenciado (pendientes → espera → pesajes → stocks), vistas por etapa (cosecha/secado/curado), mobile, flujo de aprobación admin.

**Mi experiencia simulada:** el flujo pesaje → aprobación está bien pensado (separar registro de aprobación reduce error en el dato más sensible de trazabilidad: el peso). Mi duda sincera: **6 vistas separadas para un rol cuyo trabajo es lineal**. Un manicuro tiene una pregunta: "¿qué peso hoy?". Sospecho que MncPendientes ya cumple ese rol y el resto es navegación secundaria — si es así, está bien; si el usuario tiene que adivinar en cuál de las 6 vistas está su lote, está mal. Para validar en uso real.

### 💊 Dispensador
**Lo que tiene:** DispensarView con buscador de paciente, stock disponible, carrito, modal de confirmación con medios de pago (deshabilitados con tooltip cuando no aplican — buen detalle), historial con filtros server-side, stock por sede.

**Mi experiencia simulada:** es el flujo más crítico de cara al socio y está razonablemente bien resuelto. Dos críticas serias:
1. **Las reglas de dinero se descubren al final.** El crédito insuficiente y el precio sin configurar se validan en el submit (server-side). El dispensador arma el carrito, abre el modal, elige medio de pago… y recién ahí se entera de que no podía. Lo correcto: al seleccionar el paciente, mostrar arriba el **crédito disponible ($)** de su cuenta corriente y validar el carrito contra eso en vivo. Los datos ya viajan en la API. (Nota: NO mostrar límite mensual de gramos — no es una feature en uso; ver decisión de Germán del 2026-06-12.)
2. **No tiene mobile**, y es un rol de mostrador que perfectamente podría dispensar desde una tablet. Está bien como decisión de prioridades, lo anoto como gap consciente.

### 🚚 Delivery
**Lo que tiene:** dashboard, mis paquetes, iniciar viaje en lote, entregar con firma, reportar fallo con motivo obligatorio, reprogramación (admin).

**Mi experiencia simulada:** la máquina de estados es correcta y los guards del backend están bien (solo su paquete, solo estados válidos). Es un rol que trabaja **en la calle con el teléfono**: no encontré vistas `/m` para delivery — si está usando la web desktop en un teléfono, esa es la peor experiencia de la app hoy. Candidato fuerte para la próxima ola mobile, es un rol chico (2 vistas).

### 🩺 Médico
**Lo que tiene:** el módulo más completo después de admin — pacientes, fichas, indicaciones, turnos con disponibilidad, check-ins, documentos con firma digital, prescripción PDF.

**Mi experiencia simulada:** funcionalmente es la ventaja competitiva del producto (la auditoría vs. Araucann lo confirma). Mi crítica: el médico es el usuario **menos tolerante a UX confusa y el que menos tiempo le va a dedicar a aprender la app**. Tiene 7 vistas propias; verificaría que su dashboard responda sus dos únicas preguntas reales: "¿a quién atiendo hoy?" (turnos) y "¿qué indicaciones están por vencer?". Existe `IndicacionVencimientoJob`, así que la data está — la pregunta es si le llega proactivamente o tiene que ir a buscarla.

### ⚖️ Abogado
**Lo que tiene:** dashboard + mis documentos, socios en lectura, informes REPROCANN.

**Opinión:** correcto para lo que es — un rol de consulta esporádica. Sin objeciones; no invertiría más acá hasta que un abogado real lo pida.

### 🔍 Auditor
**Lo que tiene:** solo-lectura forzada a nivel `ApplicationController` (la decisión de seguridad más elegante de la app), banner persistente (`AuditorBanner`), 7 informes dedicados incluyendo trazabilidad y plan-vs-real.

**Opinión:** este rol está **mejor diseñado que la media del mercado**. Un inspector que entra y tiene informes de cumplimiento listos sin poder romper nada es un argumento de venta para el club. Única mejora: exportación PDF/CSV en *todos* los informes de auditor (verificar cobertura), porque el auditor se lleva papel.

### 👁️ Supervisor
**Lo que tiene:** dashboard + lectura de cultivo + gestión de tareas + recibe alertas de delivery fallido.

**Opinión:** es el rol más difuso del sistema. Lee cultivo, asigna tareas, recibe alertas de delivery — ¿quién es esta persona en un club real? Si es "el segundo del admin", quizás debería ser un admin con menos permisos y no un rol aparte. No es urgente, pero es el rol que revisaría conceptualmente antes de seguirle agregando cosas.

### 🤒 Paciente
**Lo que tiene:** perfil, sus dispensaciones, eventos, carnet público con QR.

**Opinión:** es el rol más desatendido, y está bien que así sea por ahora (el cliente es el club). Pero ojo al roadmap: el carnet digital + historial es la semilla de una app de socio que los clubes van a pedir como diferenciador. No hacer nada aún; no cerrarse puertas.

### 🛰️ Super admin
**Lo que tiene:** layout propio, clubes, usuarios, stats, modo observador con expiración.

**Opinión:** el modo observador (entrar a ver un club sin poder escribir, con expiración) es exactamente la herramienta de soporte que un SaaS necesita y casi nadie construye temprano. Bien. Lo que le falta a futuro: métricas de **salud por club** (uso, último login por rol, módulos activos) para detectar churn antes de que pase.

---

## Parte 2 — Mejoras UX/UI transversales (priorizadas)

**P1 — Crítico para operación diaria**
1. **Validación financiera anticipada en DispensarView** (detallado arriba): límite mensual restante y crédito visibles al elegir paciente, carrito validado en vivo. Es la mejora UX con mayor impacto/esfuerzo de la lista.
2. **El reload automático del service worker** (`controllerchange` → `window.location.reload()`, WIP actual en `main.js`) puede pisar un formulario a medio cargar — y los forms de esta app son largos (alta de socio, dispensación, pesada). Cambiar por toast persistente "Nueva versión disponible — [Recargar]". Un operador que pierde una carga de 3 minutos no confía más en la app.
3. **Bandeja unificada de pendientes para admin** (aprobaciones de manicura + curado + stocks + renovaciones REPROCANN en una sola cola accionable).

**P2 — Consistencia**
4. `LotesView` todavía usa `window.confirm` cuando existe `ConfirmDialog` en el design system. Auditar y unificar (es la única vista que lo hace — está a un paso de la consistencia total).
5. Errores 422 del backend mostrados como `full_messages` crudos en algunos flujos vs. mensajes diseñados en otros. Definir un formato único de error en `api.js` + toast.
6. El guard del router muestra toast "Sin permisos para acceder a esa sección" — si el usuario llegó ahí, es porque la UI le mostró un link que no debía ver. Cada aparición de ese toast es un bug de navegación a arreglar, no un mensaje a mejorar. (Se resuelve de raíz unificando la matriz de permisos — informe de ingeniería, hallazgo A1.)

**P3 — Calidad percibida**
7. **Estados vacíos con acción**: existe `EmptyState` en ui/ — verificar que cada vista lo use con CTA ("No hay lotes activos → Crear lote") y no tabla vacía.
8. **Charts de Chart.js**: tienen estados de carga (96 vistas con loading — bien), pero verificar estado "sin datos suficientes" en analítica para clubes nuevos: un dashboard lleno de gráficos vacíos en el onboarding es la primera impresión del producto.
9. **Accesibilidad** (no auditada a fondo — pendiente): focus management en los modales custom, `aria-label` en botones de ícono (los ⚡ dropdowns), contraste del sidebar dark. Vale una pasada dedicada.
10. **Vistas de 1.000+ líneas** (SalaDetail, PlantaDetail, LoteDetail): además del costo de mantenimiento, suelen esconder demasiados conceptos en una pantalla. Cuando se refactoricen (informe ing. M6), aprovechar para preguntar qué se puede sacar de la vista, no solo cómo dividir el archivo.

**P4 — Apuestas**
11. **Mobile para delivery** (rol chico, impacto alto, trabaja en la calle).
12. **Modo tablet para dispensador** (mostrador).
13. **Carga ambiental "rápida vs completa"** para cultivador — protege el pipeline de datos de las Fases 4-5.

---

## Cierre honesto

Lo que más me impresiona del producto: la cobertura funcional por rol y las decisiones de dominio (auditor read-only estructural, modo observador, aprobación de pesadas, indicación médica ↔ dispensación). Lo que más me preocupa no es UX: es que la experiencia que describe este informe está sostenida por la arquitectura que describe el otro. Las mejoras P1 son baratas; hacelas después de (o junto con) el service de dispensación, porque tocan el mismo flujo y conviene no pasar dos veces.
