# Club Cultivo — Documento de Plataforma

> Versión: junio 2026  
> Audiencia: equipo fundador, inversores, nuevos colaboradores técnicos  
> Propósito: descripción completa de la plataforma, estado actual, mejoras propuestas y visión a futuro

---

## 1. Visión y filosofía del producto

Club Cultivo es una plataforma SaaS B2B diseñada para la **gestión integral de clubes de cannabis**. No es un club: es la herramienta operativa que los clubes usan para funcionar. Cada club suscripto opera dentro de un espacio completamente aislado (multi-tenancy), con sus propios datos, usuarios y configuración.

La propuesta de valor es clara: reemplazar hojas de cálculo, sistemas artesanales y procesos manuales por una plataforma unificada que cubra el ciclo completo del producto — desde la semilla hasta la dispensación al socio — con trazabilidad total, cumplimiento regulatorio y datos accionables.

La visión a largo plazo es más ambiciosa: convertirse en la plataforma de datos del sector, agregando información anonimizada de miles de clubs para generar modelos predictivos de rendimiento, optimización genética, automatización de grow rooms y benchmarking sectorial.

---

## 2. Stack tecnológico y arquitectura

| Capa | Tecnología |
|---|---|
| Backend | Ruby on Rails (API mode) |
| Frontend | Vue 3 + Composition API + Pinia |
| Base de datos | PostgreSQL |
| Cache / colas | Redis + Sidekiq |
| Contenedores | Docker / Docker Compose |
| Deploy | Render.com |
| Tests | RSpec + FactoryBot |

La arquitectura sigue un patrón clásico de SPA + API REST:

- El **frontend** (Vue 3) es una aplicación de página única que corre en el browser y consume la API Rails.
- El **backend** (Rails API mode) expone todos los recursos bajo `/api`, maneja autenticación via JWT (Devise + devise-jwt), y coordina los jobs en background via Sidekiq.
- Los **datos ambientales** ingresan por webhook (`/webhooks/lecturas`) o por importación manual/CSV, y se propagan al modelo `LecturaAmbiental` que los cruza con lotes activos.
- **ActionCable** provee canales de WebSocket para notificaciones en tiempo real (alertas, updates de estado).

El multi-tenancy se implementa a nivel de scope: cada recurso pertenece a un `Club`, y todos los controllers filtran automáticamente por el club del usuario autenticado.

---

## 3. Roles y matriz de acceso

La plataforma define **nueve roles** de usuario, cada uno con su propio layout de interfaz, navegación y permisos de acceso:

| Rol | Descripción | Acceso principal |
|---|---|---|
| **Admin** | Gestión total del club | Todos los módulos |
| **Supervisor** | Operación + reportes, sin configuración | Cultivo, socios, contabilidad, tareas |
| **Cultivador** | Operación del grow room | Salas, lotes, plantas, tareas, ambiente |
| **Manicuro** | Post-cosecha | Manicura, pesadas, stocks propios |
| **Dispensador** | Entregas a socios | Dispensaciones, stock disponible, socios (solo lectura limitada) |
| **Delivery** | Logística de envíos | Despachos pendientes, entrega, reporte de fallos |
| **Médico** | Prescripción y documentación clínica | Pacientes, indicaciones médicas, documentos |
| **Abogado** | Documentación legal | Documentos legales del club |
| **Auditor** | Lectura de reportes regulatorios | Informes REPROCANN, producción, cumplimiento |
| **Super Admin** | Gestión de la plataforma | Todos los clubs, métricas globales |

Cada rol tiene su propio sidebar, dashboard de inicio y conjunto de rutas accesibles. Los roles externos (médico, abogado, auditor, delivery) tienen acceso estrictamente acotado y no pueden navegar fuera de su sección.

---

## 4. Módulos de la plataforma

---

### 4.1 Socios / Pacientes

**Qué es**  
El registro central de todos los socios del club. Cada socio tiene un perfil completo con datos personales, estado de membresía, documentación adjunta, historial clínico, dispensaciones recibidas, indicaciones médicas vigentes y cuenta corriente en gramos.

**Qué puede hacer cada rol**  
- **Admin / Supervisor**: acceso completo — alta, baja, edición, exportación CSV, envío de mails, historial completo.  
- **Médico**: acceso a la historia clínica, indicaciones y documentos clínicos. No ve datos financieros.  
- **Dispensador / Delivery**: acceso de solo lectura a datos mínimos necesarios para completar una entrega. No pueden ver historia clínica ni datos sensibles.  
- **Auditor / Abogado / Manicuro / Cultivador**: sin acceso.

**Funcionalidad actual**  
- Alta y edición de socios con datos personales completos (DNI, domicilio, contacto, fecha de nacimiento).  
- Estado de membresía: activo / inactivo / suspendido.  
- **Documento REPROCANN**: carga, visualización, renovaciones y seguimiento de vencimiento.  
- **Historia clínica**: sección semi-estructurada con motivo de consulta, antecedentes, diagnóstico y notas clínicas. Editable por el médico.  
- **Indicaciones médicas**: prescripciones con genética indicada, dosis, frecuencia y vigencia. El médico las crea; el dispensador las consulta al momento de entregar.  
- **Cuenta corriente en gramos**: saldo disponible, límite configurado, movimientos de crédito y débito. Permite que un socio "acumule crédito" para retirar producto en cuotas.  
- **Cuenta corriente monetaria**: registro de pagos, cuota social y ajustes manuales.  
- **Documentos adjuntos**: plantillas configurables (contratos, consentimientos, certificados). Firma digital integrada.  
- **Historial de correos**: registro de todos los mails enviados al socio desde la plataforma, con asunto, fecha y contenido.  
- **Notas internas**: registro libre de observaciones del equipo, con fecha y autor.  
- **Timeline**: vista cronológica de todos los eventos del socio (altas, dispensaciones, indicaciones, documentos, notas).  
- **Carnet digital**: URL pública única (`/c/:token`) con QR y datos básicos del socio para verificación en puerta.  
- **Exportación CSV**: listado completo para reportes regulatorios o auditorías.

**Mejoras propuestas**  
- Alertas automáticas por vencimiento de REPROCANN (hoy existen alertas internas, falta notificación proactiva por mail X días antes del vencimiento).  
- Segmentación avanzada de socios por genética indicada, frecuencia de consumo y antigüedad, para análisis de demanda.  
- Dashboard de estado de la membresía: socios por renovar, morosos, con REPROCANN vencido — hoy hay que consultar los informes para verlo.  
- Integración con firma electrónica de terceros (DocuSign / Autofirma) para contratos con validez legal reforzada.

---

### 4.2 Dispensaciones

**Qué es**  
El registro de cada entrega de producto a un socio. Es el módulo más crítico en términos de cumplimiento regulatorio: cada gramo entregado debe estar trazado al stock de origen, a la indicación médica y al socio receptor.

**Qué puede hacer cada rol**  
- **Dispensador / Admin**: crear dispensaciones, consultar historial, ver stock disponible.  
- **Delivery**: ver sus paquetes asignados, marcar entrega realizada o reportar fallo.  
- **Auditor**: lectura del informe de dispensaciones (no accede al módulo operativo).

**Funcionalidad actual**  
- **Creación de dispensación**: selección de socio activo → selección de stock disponible → cantidad en gramos → método de pago → confirmación.  
- **Validaciones en tiempo real**: el sistema verifica que el socio esté activo, que el stock sea suficiente, que la cantidad no supere el límite mensual configurado, y que el crédito en gramos sea suficiente si el método de pago es `credito_gramos`.  
- **Modos de entrega**: retiro en sede (inmediato) o envío con delivery (programado con fecha y dirección).  
- **Estados del ciclo**: pendiente → en viaje → entregada / fallo / reprogramada.  
- **Stock asignado por sede**: el dispensador solo ve el stock de su sede, evitando errores de asignación.  
- **Historial paginado** con filtros por fecha, socio, estado y método de pago.  
- **Exportación CSV** del historial completo.  
- **Mis paquetes** (vista delivery): lista filtrada de los envíos asignados al repartidor.

**Mejoras propuestas**  
- Sistema de turno / reserva previa: socio agenda su retiro online desde el carnet digital y el dispensador recibe la lista organizada del día.  
- Firma electrónica del receptor al momento de entrega (especialmente para delivery), con captura de firma en pantalla táctil.  
- Alertas de stock mínimo por sede integradas al flujo de dispensación.  
- Límites configurables por genética (no solo por volumen global), para clubes con restricciones específicas por cepa.

---

### 4.3 Cultivo — Salas (Grow Rooms)

**Qué es**  
Las salas son los espacios físicos de cultivo del club. Cada sala contiene lotes activos, tiene capacidad definida y condiciones ambientales propias. Es la unidad de organización espacial del grow room.

**Qué puede hacer cada rol**  
- **Admin / Supervisor**: crear, editar y gestionar salas, asignar cultivadores.  
- **Cultivador**: operar su sala asignada — cargar lotes, registrar lecturas, ver alertas.  
- **Manicuro**: acceso de solo lectura para coordinar post-cosecha.

**Funcionalidad actual**  
- Creación de salas con nombre, descripción y capacidad de plantas.  
- **Asignación de cultivadores**: cada sala tiene uno o más cultivadores responsables. El cultivador solo ve las salas que tiene asignadas.  
- **Carga de lotes**: el cultivador mueve un lote existente a su sala desde la vista de detalle.  
- **Lecturas ambientales manuales**: temperatura, humedad, CO₂, PPFD, EC, pH — con timestamp. Se visualizan en gráfico temporal.  
- **Semáforo ambiental**: indicador visual de temperatura y humedad respecto al setpoint configurado (verde / amarillo / rojo).  
- **Alertas activas**: lista de alertas de condiciones fuera de rango para esa sala.  
- **Sedes**: las salas pueden pertenecer a sedes físicas diferentes, permitiendo que un club opere en múltiples locaciones.

**Mejoras propuestas**  
- Vista de planta de la sala (layout visual con posición de cada lote), hoy la lista es plana.  
- Historial de ocupación por sala: qué lotes pasaron por cada sala y cuándo.  
- Dashboard comparativo entre salas: rendimiento promedio, eficiencia ambiental, kg producidos en el período.

---

### 4.4 Cultivo — Lotes

**Qué es**  
El lote es la unidad de producción: un conjunto de plantas de la misma genética que inicia y cierra un ciclo completo de cultivo juntas. Es el objeto más rico en datos de toda la plataforma.

**Qué puede hacer cada rol**  
- **Admin / Supervisor**: vista completa, edición, costos, cierre de ciclo.  
- **Cultivador**: operación diaria, transiciones de fase, registro de eventos y lecturas.  
- **Manicuro**: post-cosecha — pesadas, manejo de stocks de manicura.  
- **Auditor**: solo visible en informes de producción.

**Funcionalidad actual**  

*Estados del ciclo (máquina de estados):*  
`germinacion → esqueje → vegetativo → floracion → cosecha → en_manicura → manicura_pendiente → curado → finalizado`

- **Creación con código automático**: el código se genera con formato `L-{AÑO}-{NRO}` (ej: `L-26-004`).  
- **Datos base**: genética, sala, cantidad de plantas, fecha de inicio, rendimiento objetivo.  
- **Transiciones de fase**: el cultivador avanza el lote manualmente con validaciones por estado (no se puede saltar fases). Cada transición queda registrada en el timeline.  
- **Registros de actividad**: formularios estructurados para cada actividad habitual — riego, nutrición, poda, luz, trasplante, plaguicidas, limpieza, condiciones ambientales. Cada registro tiene timestamp y autor.  
- **Cosecha parcial**: posibilidad de cosechar solo algunas plantas del lote.  
- **Costo del lote**: módulo dedicado para cargar costos de insumos, energía y mano de obra. Genera el costo por gramo producido.  
- **Fotos**: galería de fotos del lote con lightbox.  
- **Notas internas**: observaciones libres del equipo.  
- **Timeline completo**: vista cronológica de todos los eventos, actividades, transiciones y notas.  
- **Plan vs Real**: comparativa de fechas previstas vs fechas reales por fase (solo disponible cuando el lote tiene plan de trabajo asociado).  
- **IA Card**: análisis automatizado del lote con el asistente de IA.  
- **Exportación CSV** del historial de lotes.

**Mejoras propuestas**  
- **Registro de maduración**: hoy el campo THC% y CBD% no existe como dato de campo. Agregar campo "análisis de laboratorio" con fecha y valores para lotes analizados.  
- **Alerta de retraso de fase**: si un lote lleva más días en una fase de lo configurado en el setpoint, disparar alerta automática.  
- **Comparativa entre lotes de la misma genética**: ver si el lote actual va mejor o peor que el promedio histórico, en tiempo real.  
- **Peso parcial durante curado**: hoy solo se registra el peso final post-manicura. Agregar pesadas intermedias para seguimiento de pérdida de humedad en secado.

---

### 4.5 Cultivo — Plantas

**Qué es**  
Trazabilidad individual de cada planta. Permite registrar actividades, pesos y fotografías por planta, y relacionarla con su lote de origen.

**Funcionalidad actual**  
- Ficha individual con número de planta, estado, genética, sala y lote.  
- **Actividades por planta**: log de intervenciones (riego, poda, etc.) con timestamp.  
- **Fotos por planta**: galería con lightbox.  
- **Registro de peso**: pesadas individuales en el flujo de cosecha.  
- **QR único por planta**: URL pública (`/p/:codigo_qr`) que muestra los datos básicos de la planta.  
- **Alta de plantas**: formulario de creación individual o por lote.

**Mejoras propuestas**  
- Detección de anomalías por planta via foto: en la Fase 4 (IA), subir una foto y recibir diagnóstico automático de deficiencias, plagas o estrés hídrico.  
- Agrupación visual por "mapa del grow room": ver las plantas ordenadas por posición física en la sala.

---

### 4.6 Genética de Cepas

**Qué es**  
El catálogo de genéticas del club: las variedades que cultivan, con sus características agronómicas, efectos y rendimiento esperado.

**Funcionalidad actual**  
- Ficha por genética: nombre, tipo (indica/sativa/híbrida), THC% y CBD% esperados, tiempo de floración, rendimiento esperado (g/planta), descripción, terpenos.  
- Galería de fotos.  
- **Página pública**: cada genética tiene una URL pública para el sitio web del club (`/s/:codigo_qr`).  
- Herencia de datos al lote: cuando se crea un lote con esa genética, hereda el rendimiento objetivo.

**Mejoras propuestas**  
- **Historial de rendimiento real por genética**: cruzar los datos de lotes finalizados con la ficha de la genética para mostrar el rendimiento promedio real vs esperado directamente en la ficha. Hoy ese dato solo existe en Analytics.  
- **Comparativa de cepas**: gráfico radar comparando THC, CBD, rendimiento, tiempo de floración entre las genéticas del club.  
- Importación desde bases de datos de semilleros (Seedfinder, Leafly) para poblar fichas automáticamente.

---

### 4.7 Stocks e Inventario

**Qué es**  
El inventario de producto terminado disponible para dispensación. Un stock se genera cuando un lote finaliza su proceso de post-cosecha y el producto queda disponible para ser asignado a socios.

**Funcionalidad actual**  
- Creación de stock desde lote finalizado (principal) o por compra externa.  
- **Canal de distribución**: regulatorio (uso médico con REPROCANN) o social (uso recreativo según normativa local).  
- **Asignación por sede**: el stock se asigna a una sede específica para que el dispensador de esa sede lo vea disponible.  
- **Trazabilidad del stock**: de qué lote proviene, qué genética, cuándo se produjo, qué pesadas intermedias tuvo.  
- **Vista de etiqueta**: genera una etiqueta imprimible con QR para rotulado del producto.  
- **QR público del stock** (`/s/:codigo_qr`): URL con información del producto para verificación.  
- **Stocks pendientes de asignación**: vista admin para aprobar y asignar stocks antes de que queden disponibles.

**Mejoras propuestas**  
- **Gestión de vencimiento**: los stocks deberían tener fecha de expiración (basada en método de conservación) con alerta automática.  
- **Reserva de stock**: asociar un stock a una dispensación futura antes de que el socio retire, para evitar que otro la use.  
- **Inventario por sede en tiempo real**: dashboard de stock disponible, reservado y despachado por sede.

---

### 4.8 Monitoreo Ambiental e IoT

**Qué es**  
El módulo de sensórica ambiental. Permite registrar y analizar las condiciones físicas de las salas de cultivo: temperatura, humedad relativa, CO₂, PPFD (intensidad lumínica), EC y pH de la solución nutritiva.

**Qué puede hacer cada rol**  
- **Admin**: configuración de dispositivos, reglas y setpoints.  
- **Cultivador**: registro de lecturas manuales, visualización de histórico y alertas activas de su sala.

**Funcionalidad actual**  

*Modelos de datos:*  
- `Dispositivo`: sensor registrado con token único para autenticación por webhook.  
- `LecturaAmbiental`: lectura individual con timestamp, tipo de variable, valor, sala y lote asociado.  
- `RegistroAmbiental`: agrupador de múltiples lecturas del mismo momento (temperatura + humedad + CO₂ en un solo registro).  
- `ReglaAmbiental`: condición configurable que dispara una `Alerta` cuando la lectura supera o baja del umbral.  
- `SetpointFase`: valores objetivo por fase del cultivo (vegetativo, floración, etc.).

*Ingesta de datos:*  
- **Webhook automático** (`POST /webhooks/lecturas`): sensores hardware envían datos directamente a la API con su token. Produce lecturas en tiempo real.  
- **Importación CSV**: subida manual de históricos desde dispositivos sin conectividad permanente.  
- **Importación asistida por IA**: el asistente puede parsear datos de sensores en formatos no estándar.  
- **Registro manual**: el cultivador carga lecturas desde la interfaz directamente.

*Visualización:*  
- Gráfico temporal de temperatura y humedad en la vista de sala.  
- Semáforo ambiental (verde/amarillo/rojo) respecto al setpoint.  
- Lista de alertas activas por sala con reconocimiento y resolución.

**Mejoras propuestas**  
- **Dashboard ambiental en tiempo real**: hoy el gráfico es estático (requiere reload). Con ActionCable ya disponible, se puede hacer push de nuevas lecturas al gráfico en vivo.  
- **VPD automático**: calcular el Vapor Pressure Deficit a partir de temperatura + humedad y mostrarlo como variable derivada, ya que es la métrica ambiental más relevante para el cultivador profesional.  
- **Alertas push / notificaciones mobile**: hoy las alertas son internas (campanita en la app). Agregar notificación por mail o push notification cuando una condición crítica se activa.  
- **Histórico comparativo**: superponer el histórico ambiental de dos períodos o dos salas en el mismo gráfico.

---

### 4.9 Analítica y Business Intelligence

**Qué es**  
El módulo de análisis de datos del club. Transforma los datos operativos en indicadores estratégicos para la toma de decisiones. Actualmente tiene cinco dimensiones de análisis.

**Qué puede hacer cada rol**  
- **Admin / Supervisor**: acceso completo.  
- Otros roles: sin acceso directo (los datos se consumen indirectamente via informes o dashboards de rol).

**Dimensiones actuales**  

**Tab Genética — Rendimiento por cepa**  
Responde: ¿cuál es mi cepa más eficiente?  
- Rendimiento promedio real (g) por genética.  
- g/planta: eficiencia de espacio/densidad.  
- Desvío % respecto al objetivo configurado.  
- Merma de plantas: % de plantas perdidas por lote.  
- Lotes activos vs finalizados.  
- Tabla de lotes recientes con estado y métricas.

**Tab Ciclos — Análisis de tiempos**  
Responde: ¿cuánto tiempo tarda cada fase de cultivo?  
- Duración promedio de cada fase (vegetativo, floración, post-cosecha).  
- Outliers: lotes que se desviaron significativamente del tiempo esperado.  
- Tendencia de eficiencia a lo largo del tiempo.

**Tab Pérdidas — Merma y eficiencia**  
Responde: ¿dónde pierdo producto?  
- Merma total y por fase.  
- Correlación entre pérdida de plantas y rendimiento final.  
- Evolución histórica de la tasa de merma.

**Tab Comparativa**  
Responde: ¿cómo comparo períodos o salas?  
- Comparativa de rendimiento entre salas.  
- Comparativa año/año o trimestre/trimestre.

**Tab Ambiente — Correlación ambiental**  
Responde: ¿qué condiciones de cultivo producen mejor rendimiento?  
- Cruza `LecturaAmbiental` con `rendimiento_real_g` del lote.  
- Análisis de correlación por buckets de VPD, temperatura y pH.  
- KPIs: lotes con datos ambientales, variables analizadas, mejor lote ambiental.  
- Tabla de huella ambiental: por lote, sus promedios de temperatura, humedad, CO₂, PPFD, EC, pH y el rendimiento real.  
- Insight cards: rango óptimo detectado para VPD, temperatura y pH basado en datos históricos reales.

*Todos los endpoints de analytics tienen caché de 15 minutos con bust explícito.*

**Mejoras propuestas**  
- **Modelos de regresión**: hoy el análisis ambiental es descriptivo (promedios por bucket). El siguiente paso natural es calcular la correlación de Pearson y construir un modelo de regresión simple que prediga el rendimiento dado un set de condiciones.  
- **Alertas basadas en analítica**: "el lote L-26-004 tiene condiciones similares a los lotes que históricamente tuvieron merma alta".  
- **Export PDF con branding del club**: hoy existe export CSV. Agregar un reporte PDF auto-generado con los gráficos y KPIs del período.  
- **Dashboard ejecutivo con filtro por período**: poder comparar trimestre actual vs anterior con un solo clic.

---

### 4.10 Contabilidad y Finanzas

**Qué es**  
El registro financiero del club. No es contabilidad completa (no hay plan de cuentas estricto ni integración contable), pero provee un registro estructurado de ingresos y egresos que permite calcular rentabilidad por período.

**Qué puede hacer cada rol**  
- **Admin / Supervisor**: acceso completo.  
- Otros roles: sin acceso.

**Funcionalidad actual**  
- **Movimientos contables**: cada movimiento tiene tipo (ingreso/egreso), categoría, monto, fecha, descripción, y puede estar asociado a una sede o a un lote específico.  
- **Categorías configurables**: el club define sus propias categorías de gastos e ingresos.  
- **Dashboard financiero**: balance del período, total ingresos, total egresos, resultado neto. Filtrable por sede, categoría y rango de fechas.  
- **Exportación CSV** del histórico de movimientos.  
- **Costo por lote** (`CostoLote`): módulo separado dentro de cada lote para registrar costos de insumos, energía, mano de obra y otros. Calcula automáticamente el costo por gramo producido al finalizar el lote.  
- **Cuenta corriente del socio**: registro de pagos de cuota social, abonos y ajustes por socio.

**Mejoras propuestas**  
- **P&L por lote completo**: cruzar automáticamente el costo del lote con el valor de dispensación del stock producido para calcular el margen real por lote.  
- **Integración con facturación**: exportar movimientos en formato compatible con sistemas contables (AFIP, contadores externos).  
- **Dashboard de flujo de caja mensual**: proyección de ingresos futuros basada en cuotas de socios y dispensaciones programadas.

---

### 4.11 Plan de Trabajo y Tareas

**Qué es**  
El módulo de gestión operativa del equipo. Permite planificar el trabajo del grow room, asignar tareas a cultivadores y hacer seguimiento de lo ejecutado.

**Qué puede hacer cada rol**  
- **Admin / Supervisor**: crear y publicar planes de trabajo, asignar tareas, ver dashboards.  
- **Cultivador**: ver sus tareas asignadas, iniciarlas y completarlas.

**Funcionalidad actual**  

*Plan de Trabajo:*  
- Un plan de trabajo es una plantilla de tareas para un ciclo de cultivo (ej: "Plan Estándar Floración 8 semanas").  
- Contiene `PlanTareas`: tareas ordenadas con días relativos al inicio, tipo, responsable y descripción.  
- Puede publicarse (queda activo) o archivarse.  
- **Interpretación de archivo por IA**: el asistente puede parsear un plan en texto libre o PDF y generar las PlanTareas estructuradas automáticamente.  
- **Vistas de planificación**: mes, semana y trimestre — visualización de las tareas del plan en calendar.

*Tareas operativas:*  
- Creación manual de tareas con tipo, sala/lote/planta asociada, fecha y responsable.  
- Estados: pendiente → en curso → completada / cancelada.  
- Tareas recurrentes: la tarea puede configurarse como serie (diaria, semanal, mensual) con cancelación de serie completa.  
- **Dashboard de tareas**: KPIs de completitud, tareas vencidas y próximas por vencer.  
- **Vista kanban** por estado.  
- **Vista semana** tipo calendario.

**Mejoras propuestas**  
- **Tareas generadas automáticamente desde el Plan de Trabajo**: al asociar un plan a un lote, el sistema debería proponer generar las tareas del plan con fechas calculadas automáticamente. Hoy el link plan ↔ lote existe para Plan vs Real pero no genera tareas.  
- **Notificaciones de vencimiento**: recordatorio al cultivador cuando una tarea asignada está por vencer o ya venció.  
- **Completitud por sala / cultivador**: informe de productividad del equipo.

---

### 4.12 Informes y Auditoría (REPROCANN)

**Qué es**  
El módulo de reportes regulatorios. Diseñado especialmente para cumplir con los requisitos de información de REPROCANN (Registro del Programa de Cannabis Medicinal, Argentina) y para dar visibilidad a auditores internos o externos.

**Qué puede hacer cada rol**  
- **Auditor**: acceso de solo lectura a todos los informes.  
- **Admin**: acceso completo con posibilidad de exportar.

**Informes disponibles**  

| Informe | Qué muestra |
|---|---|
| **REPROCANN** | Estado de todos los socios con REPROCANN: vigentes, por vencer (<30 días), vencidos. Detalle por socio con número de REPROCANN y fechas. |
| **Producción** | Lotes activos, finalizados y en post-cosecha. Gramos producidos por período. Detalle por cepa. |
| **Dispensaciones** | Total de dispensaciones por período, por socio, por genética. Con status de entrega. |
| **Sedes** | Resumen por locación: stock disponible, socios activos, dispensaciones del período. |
| **Cumplimiento** | Métricas de cumplimiento: % socios con REPROCANN vigente, % dispensaciones entregadas a tiempo, % tareas completadas. |
| **Plan vs Real** | Comparativa entre lo planificado en el plan de trabajo y lo ejecutado realmente. |

- **Informe Semestral**: reporte estructurado en el formato requerido por REPROCANN para la presentación oficial semestral. Incluye datos del club, socios registrados, producción y dispensaciones del período.

**Mejoras propuestas**  
- Envío automático del informe semestral por mail al equipo administrativo con recordatorio 30 días antes del vencimiento.  
- **Trazabilidad completa gramo a gramo**: informe que permite seguir cada gramo desde la semilla hasta el socio, pasando por lote → pesada → stock → dispensación. Hoy la cadena existe en el modelo de datos pero no hay un informe unificado que la exponga visualmente.

---

### 4.13 Médico — Indicaciones y Documentación Clínica

**Qué es**  
El módulo del profesional médico del club. Le permite emitir indicaciones terapéuticas para los socios, gestionar la documentación clínica y llevar un seguimiento de los pacientes.

**Qué puede hacer el médico**  
- Ver la lista de sus pacientes (socios del club con indicaciones vigentes o vencidas).  
- Crear y actualizar indicaciones médicas: genética indicada, dosis, frecuencia, vigencia.  
- Completar y editar la historia clínica de cada paciente.  
- Firmar y gestionar documentos clínicos.

**Funcionalidad actual**  
- Dashboard médico con resumen de indicaciones activas, por vencer y vencidas.  
- Lista de indicaciones del médico con filtros por estado y fecha.  
- Acceso a la historia clínica del paciente (editable por el médico).  
- Firma digital de documentos clínicos.  
- Documentos médicos: listado de documentos de sus pacientes.

**Mejoras propuestas**  
- Generación de prescripción en PDF con firma digital para presentar ante REPROCANN.  
- Alertas de vencimiento de indicaciones con workflow de renovación automatizado.  
- Estadísticas del médico: cuántos pacientes activos, distribución por diagnóstico, evolución de dosis.

---

### 4.14 Abogado y Documentación Legal

**Qué es**  
El módulo para el asesor legal del club. Le da acceso a los documentos legales sin exposición a datos clínicos ni operativos.

**Funcionalidad actual**  
- Dashboard con acceso a documentos legales del club.  
- Vista de documentos clasificados por tipo y estado.  
- Sin acceso a socios, cultivo, finanzas ni operación.

**Mejoras propuestas**  
- Módulo de contratos con socios: el abogado podría revisar y validar los contratos de membresía antes de que sean enviados a firma.  
- Alertas de vencimiento de habilitaciones municipales, permisos sanitarios y renovaciones regulatorias del club.

---

### 4.15 Delivery y Logística

**Qué es**  
El módulo del repartidor. Gestiona los envíos de product a los socios que eligieron la opción de delivery.

**Qué puede hacer el rol delivery**  
- Ver el listado de paquetes asignados a su nombre.  
- Marcar paquetes como entregados.  
- Reportar fallos de entrega con motivo.  
- Reprogramar entregas fallidas para una nueva fecha.

**Funcionalidad actual**  
- **Mis paquetes**: lista filtrable de envíos asignados, ordenados por fecha programada.  
- **Vista despacho**: lista organizada para ruta de distribución del día.  
- Estados de entrega: pendiente → en viaje → entregado / fallido / reprogramado.  
- El admin puede ver el estado de todos los envíos y reasignar.

**Mejoras propuestas**  
- Integración con Google Maps para optimización de ruta de delivery.  
- Notificación al socio cuando su paquete está en camino (SMS o WhatsApp vía Twilio).  
- Firma del receptor en pantalla al momento de entrega para prueba de recepción.

---

### 4.16 Post-cosecha — Manicura

**Qué es**  
El módulo del manicuro. Cubre el proceso de post-cosecha desde que el lote se cosecha hasta que el producto queda listo como stock disponible.

**Ciclo de post-cosecha:**  
`cosecha → [en manicura] → [manicura pendiente aprobación admin] → curado → [cerrar curado] → stock creado`

**Funcionalidad actual**  
- **Lotes en cosecha**: lista de lotes listos para iniciar manicura.  
- **Lotes en secado / curado**: seguimiento de la etapa de secado y curado.  
- **Pesadas**: registro de pesadas durante el proceso (verde, seco, post-manicura). Cada pesada tiene fecha, responsable y peso en gramos.  
- **Pendientes de aprobación**: cuando el manicuro completa su trabajo, el admin recibe una solicitud de aprobación antes de que el stock se cree formalmente.  
- **Cerrar curado**: wizard que guía al admin para registrar el peso final y crear el stock.  
- **Stocks de manicura**: lista de stocks generados por el proceso.  
- **Admin approvals**: flujo de aprobación para manicura, curado y stocks pendientes desde la perspectiva del admin.

**Mejoras propuestas**  
- Tracking de pérdida de humedad durante secado: registrar el peso en múltiples puntos para calcular la curva de secado y estimar el momento óptimo de manicura.  
- Rendimiento de manicura por operario: métricas de velocidad y eficiencia por manicuro.

---

### 4.17 Asistente de Inteligencia Artificial

**Qué es**  
Un asistente conversacional integrado en la plataforma que puede responder preguntas sobre el estado del club, interpretar datos de cultivo, parsear documentos y analizar lotes. El asistente tiene acceso al contexto del club (lotes, socios, lecturas ambientales, genéticas) y puede razonar sobre ese contexto.

**Funcionalidad actual**  
- **Consultas en lenguaje natural**: el usuario puede preguntar en castellano (ej: "¿cuál fue el mejor lote de Sherbet del año?") y el asistente responde con datos reales del club.  
- **Análisis de lote**: analiza un lote específico y genera un informe cualitativo sobre su rendimiento, condiciones y posibles mejoras.  
- **Historial de análisis**: registro de los análisis generados para revisión posterior.  
- **Parseo de documentos**: puede interpretar un plan de trabajo en formato texto o PDF y generar las tareas estructuradas.  
- **Importación asistida de lecturas ambientales**: parsea datos de sensores en formatos no estándar.  
- **Niveles de suscripción**: el asistente tiene tiers (básico/pro/enterprise) con límites de uso por club.

**Mejoras propuestas**  
- **Modo proactivo**: el asistente detecta automáticamente situaciones anómalas (lote retrasado, merma alta, alerta ambiental recurrente) y genera una notificación con análisis contextual, sin que el usuario lo solicite.  
- **Voz**: input por voz para el cultivador que tiene las manos ocupadas en el grow room. La infraestructura del componente `VoiceInput` ya existe.  
- **Integración con el flujo de creación de lote**: al crear un lote, el asistente sugiere el objetivo de rendimiento basado en el historial de esa genética.

---

### 4.18 Web Pública y Carnets

**Qué es**  
La cara pública del club. URLs accesibles sin autenticación para verificación externa e integración con el sitio web del club.

**Funcionalidad actual**  
- **Web pública del club** (`/public/club`): información del club, genéticas disponibles, noticias y eventos — para integrar en el sitio web externo del club vía API.  
- **Carnet digital del socio** (`/c/:token`): página con datos básicos del socio para verificación en puerta o por autoridades. Tiene QR único.  
- **QR de planta** (`/p/:codigo_qr`): página con datos de la planta para trazabilidad pública.  
- **QR de stock** (`/s/:codigo_qr`): página con información del producto para verificación.  
- **Genéticas públicas** (`/public/geneticas`): catálogo público de variedades del club.

**Mejoras propuestas**  
- **Verificación de autenticidad del carnet**: agregar un mecanismo de firma criptográfica para que el carnet sea verificable como auténtico ante autoridades.  
- **Página pública del club con diseño personalizable**: que cada club pueda customizar colores, logo y contenido de su página pública desde Preferencias.

---

### 4.19 Configuración, Preferencias y Usuarios

**Qué es**  
El módulo de configuración del club para el administrador.

**Funcionalidad actual**  

*Preferencias del club:*  
- Logo del club (subida de imagen).  
- Configuración SMTP personalizada para envío de mails desde el dominio del club (con botón de test).  
- Configuración general del club (nombre, descripción, datos de contacto).

*Gestión de usuarios:*  
- Alta, edición y baja de usuarios del club.  
- Asignación de rol.  
- Asignación de salas específicas al cultivador (solo ve las salas que tiene asignadas).  
- Asignación de sedes (para roles que operan en locaciones específicas).  
- Reset de contraseña desde el panel admin.

*Perfil personal:*  
- Edición de nombre, email y avatar.  
- Cambio de contraseña.

**Mejoras propuestas**  
- **SSO / OAuth**: login con Google o Microsoft para facilitar onboarding de nuevos usuarios del club.  
- **Auditoría de acciones**: log de quién hizo qué en la plataforma (hoy no existe un log de auditoría de acciones de usuario).  
- **Notificaciones configurables**: que cada usuario pueda elegir qué alertas recibe por mail vs solo en la app.

---

### 4.20 Super Admin — Gestión de la Plataforma

**Qué es**  
El panel exclusivo de Passare (la empresa detrás de Club Cultivo) para administrar todos los clubs suscriptos a la plataforma.

**Funcionalidad actual**  
- Lista de todos los clubs con estado de suscripción.  
- Crear / editar / suspender clubs.  
- Cambiar el plan de suscripción de un club.  
- **Modo observación**: el super admin puede "entrar" como admin de cualquier club para soporte o QA, sin conocer la contraseña del admin.  
- Gestión de usuarios cross-club.  
- **Métricas de la plataforma**: KPIs globales — clubs activos, socios totales, dispensaciones del mes, lotes activos.  
- **Benchmark**: datos agregados y anonimizados de rendimiento entre clubs para benchmarking sectorial.

**Mejoras propuestas**  
- **Métricas de engagement por club**: qué módulos usa cada club, con qué frecuencia, qué features tiene desactivadas. Para detectar clubs en riesgo de churn.  
- **Billing integrado**: gestión del ciclo de facturación desde el panel super admin (hoy es manual).

---

## 5. Flujo completo del producto — de la semilla al socio

```
SEMILLA / ESQUEJE
      │
      ▼
[Lote creado] ──── Genética asignada ──── Sala asignada
      │
      │ (cultivador registra actividades, condiciones ambientales)
      │
      ▼
[Estadíos: vegetativo → floración → cosecha]
      │
      │ (sensores envían lecturas ─→ LecturaAmbiental ─→ alertas si fuera de rango)
      │
      ▼
[Cosecha] ──── Pesada inicial (peso verde)
      │
      ▼
[Secado / Curado] ──── Pesadas intermedias ──── Manicuro asignado
      │
      ▼
[Aprobación admin] ──── Pesada final (peso seco post-manicura)
      │
      ▼
[Stock creado] ──── Asignado a sede ──── QR generado
      │
      ▼
[Dispensación] ──── Socio activo + REPROCANN vigente + indicación médica
      │              ──── Límite mensual verificado
      │              ──── Crédito suficiente verificado
      │
      ▼
[Entregado] ──── Retiro en sede (inmediato) o Delivery (programado)
      │
      ▼
[Movimiento contable] ──── Costo del lote ──── Margen calculado
      │
      ▼
[Analytics] ──── Rendimiento por cepa ──── Correlación ambiental
                 ──── Plan vs Real ──── Benchmark
```

---

## 6. Estado de madurez por módulo

| Módulo | Madurez | Notas |
|---|---|---|
| Socios | ★★★★☆ | Sólido. Falta alerta proactiva de vencimiento REPROCANN. |
| Dispensaciones | ★★★★☆ | Sólido. Falta firma receptor y reserva previa. |
| Salas | ★★★★☆ | Sólido. Falta historial de ocupación y comparativa. |
| Lotes | ★★★★★ | Módulo más completo de la plataforma. |
| Plantas | ★★★☆☆ | Funcional. Alta individual poco usada en la práctica. |
| Genéticas | ★★★☆☆ | Funcional. Falta historial real en la ficha. |
| Stocks | ★★★★☆ | Sólido. Falta vencimiento y reserva. |
| Monitoreo ambiental | ★★★☆☆ | La infraestructura es robusta, la UI es básica. Gran potencial. |
| Analítica | ★★★★☆ | 5 tabs bien diferenciadas. Falta regresión y PDF export. |
| Contabilidad | ★★★☆☆ | Funcional básico. Sin P&L cruzado ni proyección. |
| Plan de Trabajo | ★★★★☆ | Completo. Falta link automático lote → tareas. |
| Informes / Auditoría | ★★★★☆ | Sólido regulatoriamente. Falta trazabilidad unificada. |
| Asistente IA | ★★★★☆ | Bien integrado. Falta modo proactivo y voz. |
| Manicura | ★★★★☆ | Flujo completo implementado. |
| Delivery | ★★★☆☆ | Funcional. Falta optimización de ruta y notificación al socio. |
| Médico | ★★★★☆ | Bien delimitado. Falta generación de prescripción PDF. |
| Web pública | ★★★☆☆ | Funcional. Falta verificación criptográfica del carnet. |
| Configuración | ★★★★☆ | Sólido. Falta auditoría de acciones y notificaciones configurables. |

---

## 7. Visión a futuro — Fases 3, 4 y 5

### Fase 3 — IoT avanzado y automatización

La infraestructura de sensores ya existe. El siguiente paso es cerrar el loop de control:

- **Control automático de actuadores**: los reglas ambientales no solo alertan, sino que envían comandos a actuadores (ventiladores, humidificadores, luces) vía MQTT cuando una condición se activa.  
- **Dashboard ambiental en tiempo real** con WebSocket (ActionCable ya disponible).  
- **VPD calculado automáticamente** y mostrado como variable primaria.  
- **Cámaras de monitoreo**: integración de stream de video con detección de anomalías visuales (Fase 4 para el análisis, Fase 3 para el streaming).

### Fase 4 — Inteligencia artificial aplicada al cultivo

- **Predicción de rendimiento**: dado el historial ambiental y genético de un lote en curso, predecir el rendimiento final con intervalo de confianza.  
- **Detección de deficiencias y plagas por visión artificial**: el cultivador sube una foto y el modelo identifica si hay deficiencia de nitrógeno, signos de araña roja, botrytis u otras condiciones.  
- **Recomendaciones proactivas**: "el VPD de la sala Alfa lleva 3 días por encima del óptimo histórico para Sherbet — considera ajustar la humidificación".  
- **Optimización de genéticas**: a partir del historial de múltiples lotes, recomendar los rangos de condiciones que maximizan el rendimiento para cada cepa.

### Fase 5 — Plataforma de datos del sector

- **Benchmarking sectorial**: comparativa anonimizada de rendimiento, eficiencia y costos entre clubs suscriptos. El club ve cómo está posicionado respecto al promedio sectorial.  
- **API pública para investigación**: datos agregados y anonimizados disponibles para universidades y centros de investigación.  
- **Modelos de ML entrenados con datos reales**: el activo diferencial de la plataforma — ningún modelo de cannabis cultivado en clubes tiene acceso a la escala de datos que Club Cultivo puede acumular.

---

*Documento generado en junio 2026. Actualizar a medida que la plataforma evoluciona.*
