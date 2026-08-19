# ROADMAP — Cultivo Espacial
**Fecha:** 2026-05-10  
**Horizonte:** 24 semanas (6 meses)  
**Objetivo estratégico:** Ser el único sistema ALL-IN-ONE que combine trazabilidad de cultivo completa + módulo médico REPROCANN + compliance ARICCAME/ANMAT en Argentina.

---

## RESUMEN EJECUTIVO

Cultivo Espacial es un sistema en estado **avanzado y sorprendentemente completo** para su etapa. El stack es moderno (Rails 7.2 + Vue 3 + Pinia), el schema está bien normalizado (42 tablas), y se han implementado módulos que la competencia directa (Araucann) simplemente no tiene: módulo médico REPROCANN, indicaciones terapéuticas, firma digital de documentos, delivery con trazabilidad de envío, cuenta corriente en gramos, y rol médico con dashboard propio.

La cadena de cultivo vegetativo→floración→cosecha→secado→curado→manicura→stock está completamente modelada con bitácora de eventos, pesadas por planta, aprobaciones y QR por planta. El módulo de ambiente IoT es sofisticado: sensores via webhook, reglas configurable, alertas automáticas, setpoints por fase y genética.

**Las brechas críticas son 4:**
1. La cadena planta → stock no está formalizada con FK
2. Los stocks no tienen número de lote de producto (bloquea etiquetado y ARICCAME)
3. ARICCAME (ANMAT) no existe en ninguna forma
4. Multi-tenancy basada solo en club_id sin aislamiento a nivel BD (riesgo de seguridad)

**La ventaja competitiva real** es el módulo médico. Ningún competidor argentino del sector lo tiene. Esta es la diferenciación que hay que explotar agresivamente.

---

## BRECHAS CRÍTICAS 🔴

### BC-1: Número de lote de producto y QR en stocks
Sin un código de lote de producto en `stocks`, no hay etiquetado, no hay trazabilidad retail, y no hay base para ARICCAME. Bloquea el cumplimiento regulatorio completo.

### BC-2: ARICCAME / ANMAT — completamente ausente
ARICCAME es el sistema de trazabilidad obligatorio del ANMAT para cannabis medicinal. Un club con resolución REPROCANN que dispensa productos debería reportar cada movimiento. Sin este módulo, los clubes suscriptos están en riesgo legal.

### BC-3: FK y soft-delete en plants
`lotes.genetica_id` es un INTEGER sin FK constraint — riesgo de corrupción silenciosa. `plants` no tiene `deleted_at` — plantas no se pueden archivar sin eliminarlas.

### BC-4: Multi-tenancy sin aislamiento real a nivel BD
Un bug en cualquier controller puede exponer datos de otro club. Con el crecimiento de la plataforma, esto es un riesgo de seguridad que debe resolverse antes de tener más de 20 clubes en producción.

---

## BRECHAS COMPETITIVAS 🟡

### BComp-1: Asistente IA básico
Araucann tiene "Araucanio", un asistente IA integrado. Cultivo Espacial tiene los endpoints y el componente VoiceInput pero sin un modelo de lenguaje conectado de forma robusta.

### BComp-2: Plan vs Real no sistematizado
Araucann permite comparar la planificación del lote (plantas objetivo, rendimiento esperado, fechas) vs lo que realmente ocurrió. Cultivo Espacial tiene `plants_count` en lotes pero sin comparación ni reportes.

### BComp-3: QR en productos / stocks
Las plantas tienen QR pero los productos finales (stocks) no. Araucann permite escanear el envase de producto y ver su origen completo.

### BComp-4: Cámara en sala (parcial)
Los campos `camera_stream_url` y `camera_snapshot_url` existen en `salas` pero no hay UI ni integración funcional.

---

## VENTAJAS PROPIAS 🟢

| Ventaja | Detalle | Valor estratégico |
|---------|---------|------------------|
| Módulo médico REPROCANN | Único en el mercado | Diferenciador principal |
| Indicaciones terapéuticas | Vinculadas a dispensaciones | Compliance legal |
| Firma digital de documentos | Paciente + médico | Valor legal |
| Delivery con tracking | Estado de envío, delivery rol | Operativo único |
| Cuenta corriente ($+gramos) | Crédito por paciente | Flexibilidad financiera |
| Informe REPROCANN para auditor | Read-only, sin datos sensibles | Transparencia |
| Límite mensual por paciente (g) | Configurable por médico | Control regulatorio |
| Rol médico con dashboard | Scope propio de indicaciones | UX de rol |
| Observer mode (super_admin) | Ver club sin escribir | Soporte sin riesgo |
| PlanEnforcer (planes SaaS) | Límites por tier | Monetización |
| Setpoints por fase y genética | Recomendaciones ambientales | Valor agronómico |

---

## ROADMAP EN 3 FASES

---

### FASE 1 — Compliance & Base de trazabilidad (semanas 1-4)
**Meta:** Cerrar las brechas que bloquean el cumplimiento legal y la integridad de datos.

- [ ] **TICKET-001: FK y número de lote en stocks** | Complejidad: S | Archivos: `db/migrate/`, `app/models/stock.rb`, `app/controllers/stocks_controller.rb`
  - Agregar `pesada_id`, `numero_lote_producto`, `fecha_elaboracion`, `fecha_vencimiento_est`, `club_id` a `stocks`
  - Auto-generar `numero_lote_producto` al crear stock desde pesada aprobada
  - Agregar `codigo_qr` a stocks con auto-generación similar a plants

- [ ] **TICKET-002: Fix FK de lotes.genetica_id** | Complejidad: S | Archivos: `db/migrate/`
  - Convertir a bigint + agregar FK constraint con `on_delete: :nullify`
  - Script de limpieza de orphans antes de aplicar constraint

- [ ] **TICKET-003: Soft delete y club_id en plants** | Complejidad: M | Archivos: `db/migrate/`, `app/models/plant.rb`, controllers de plants
  - Agregar `deleted_at` y `club_id` (con backfill)
  - Actualizar scopes y queries para filtrar por `deleted_at IS NULL`

- [ ] **TICKET-004: reprocann_adjunto → ActiveStorage** | Complejidad: M | Archivos: `app/models/paciente.rb`, `app/controllers/pacientes_controller.rb`, `db/migrate/`
  - Migrar de string URL a `has_one_attached :reprocann_adjunto`
  - Script de migración de archivos existentes si los hay
  - Actualizar frontend para usar endpoint de upload

- [ ] **TICKET-005: Alertas automáticas por vencimiento de indicaciones** | Complejidad: M | Archivos: `app/jobs/`, `app/models/indicacion_medica.rb`
  - Job Sidekiq diario que detecta indicaciones por vencer (30d, 7d, vencidas)
  - Crear `alertas_internas` para rol médico y admin
  - Agregar flags `alerta_30_dias_enviada`, `alerta_vencida_enviada`

- [ ] **TICKET-006: Plan vs Real en lotes** | Complejidad: M | Archivos: `db/migrate/`, `app/models/lote.rb`, `frontend/src/views/LoteDetailView.vue`
  - Agregar campos objetivo vs real (plantas, rendimiento, fechas) a lotes
  - Widget en LoteDetail mostrando % de desviación
  - Incluir en informes de producción

- [ ] **TICKET-007: INASE número de registro en genéticas** | Complejidad: S | Archivos: `db/migrate/`, `app/models/genetica.rb`, `frontend/src/views/GeneticaDetalleView.vue`
  - Agregar `numero_registro_inase`, `fecha_registro_inase`, `categoria_inase`
  - Campo editable en UI de genéticas

- [ ] **TICKET-008: Número de renovación REPROCANN (workflow)** | Complejidad: M | Archivos: `db/migrate/`, `app/models/`, `frontend/src/views/SocioDetailView.vue`
  - Crear tabla `reprocann_renovaciones` con estados (en_tramite→aprobada)
  - UI para iniciar y registrar renovaciones desde SocioDetail
  - Timeline de renovaciones en historial del paciente

---

### FASE 2 — Paridad competitiva (semanas 5-12)
**Meta:** Igualar las capacidades de Araucann en los puntos donde están por delante.

- [ ] **TICKET-010: ARICCAME — Modelo y estructura base** | Complejidad: L | Archivos: `db/migrate/`, `app/models/ariccame_registro.rb`, `app/services/ariccame/`
  - Crear tabla `ariccame_registros` (tipo, estado, payload, respuesta)
  - Service `Ariccame::ReportadorStock` para entrada de producto
  - Service `Ariccame::ReportadorDispensacion` para cada dispensación
  - Agregar campo `ariccame_reportada` a dispensaciones

- [ ] **TICKET-011: ARICCAME — Integración API ANMAT** | Complejidad: XL | Archivos: `app/services/ariccame/`, `config/initializers/`
  - Investigar y documentar la API de ARICCAME (endpoint, formato, autenticación)
  - Implementar HTTP client para envío de registros
  - Job Sidekiq para reintentos de envíos fallidos
  - Dashboard de estado ARICCAME para admin (pendientes, confirmados, errores)

- [ ] **TICKET-012: QR en stocks — generación y vista pública** | Complejidad: M | Archivos: `app/models/stock.rb`, `app/controllers/public/`, `frontend/src/composables/useQRCode.js`
  - Auto-generar `codigo_qr` en stock al crearse
  - Ruta pública `/s/:codigo_qr` → información del stock (lote, genética, fecha, club)
  - Vista de etiqueta imprimible con QR, numero_lote_producto, forma, fecha

- [ ] **TICKET-013: Vista de etiqueta + impresión** | Complejidad: M | Archivos: `frontend/src/views/`
  - Vista "Etiqueta" para stocks: QR, número de lote, forma, genética, fecha elaboración, club
  - Botón imprimir optimizado para etiquetas de 60x40mm
  - Integración con TICKET-012

- [ ] **TICKET-014: Asistente IA — integración con Claude API** | Complejidad: L | Archivos: `app/controllers/asistente_controller.rb`, `frontend/src/components/AsistenteVoz.vue`
  - Conectar endpoint `/api/asistente` con Anthropic Claude API (claude-sonnet-4-6)
  - Contexto del lote/sala activo para respuestas específicas (ej: "¿cómo está el VPD de la Sala 2?")
  - Comandos de voz → acciones (ej: "registrar riego en lote Alpha")
  - Rate limiting y control de costos por club

- [ ] **TICKET-015: Dashboard Plan vs Real — Reporte de lote** | Complejidad: M | Archivos: `frontend/src/views/LoteDetailView.vue`, `app/controllers/informes_controller.rb`
  - Sección "Resultados" en LoteDetail: plantas planificadas vs cosechadas, rendimiento objetivo vs real
  - Indicadores de eficiencia: % merma por fase, rendimiento por m², costo real vs estimado
  - Incluir en InformeProduccionView

- [ ] **TICKET-016: Cámara en sala — UI básica** | Complejidad: M | Archivos: `frontend/src/views/SalaDetailView.vue`, `frontend/src/views/SalaAmbienteView.vue`
  - Mostrar iframe/img de stream si `sala.camera_stream_url` está configurado
  - Snapshot en tiempo real (reload cada N segundos)
  - Configuración de URLs desde SalaDetail (admin/cultivador)

- [ ] **TICKET-017: Multi-tenancy — Row Level Security en PostgreSQL** | Complejidad: XL | Archivos: `config/database.yml`, `app/models/application_record.rb`, `config/initializers/`
  - Implementar RLS a nivel PostgreSQL para aislamiento real por club
  - Alternativamente: ActsAsTenant con auditoría de queries cross-tenant
  - Tests de penetración básicos verificando que un usuario no puede ver datos de otro club
  - Prioridad alta antes de escalar a >20 clubes

- [ ] **TICKET-018: Serializers dedicados** | Complejidad: L | Archivos: `app/serializers/` (nuevo)
  - Introducir Blueprinter o Active Model Serializers
  - Migrar serialización inline de los controllers principales a serializers
  - Reducir tamaño de respuestas eliminando campos sensibles o innecesarios por defecto

- [ ] **TICKET-019: Push notifications (alertas ambientales)** | Complejidad: L | Archivos: `app/jobs/`, `config/`
  - ActionCable o polling mejorado para alertas en tiempo real
  - Alternativa simple: email digest de alertas vía Sidekiq
  - Bell de notificaciones con badge en tiempo real en el TopBar

---

### FASE 3 — Diferenciación total (semanas 13-24)
**Meta:** Construir las funcionalidades únicas que consoliden a Cultivo Espacial como plataforma insustituible.

- [ ] **TICKET-020: Carnet digital de socio** | Complejidad: M | Archivos: `frontend/src/views/`, `app/controllers/`
  - QR único por socio/paciente con información mínima necesaria
  - Vista pública autenticada: nombre, estado membresía, REPROCANN vigente (sin datos clínicos)
  - Descargable como PDF / Apple Wallet / Google Wallet (fase posterior)

- [ ] **TICKET-021: App móvil — MVP** | Complejidad: XL | Stack: Vue 3 + Capacitor (reutiliza el frontend existente)
  - Convertir el frontend Vue en app móvil via Capacitor
  - Escaneo QR nativo (planta + producto)
  - Vista de planta por QR: historial, actividades, pesadas
  - Notificaciones push nativas
  - Foco inicial: cultivador (escáner) + dispensador (dispensar desde móvil)

- [ ] **TICKET-022: Trazabilidad completa planta → dispensación (UI)** | Complejidad: M | Archivos: múltiples vistas
  - Vista "árbol de trazabilidad": dado un QR de stock, mostrar el árbol completo
  - Planta origen → pesada → stock → dispensaciones → pacientes
  - Disponible para auditor y admin

- [ ] **TICKET-023: Dashboard analítico por rol — Cultivador** | Complejidad: L | Archivos: `frontend/src/views/DashboardView.vue`
  - Métricas: rendimiento promedio por genética, días promedio por fase, merma histórica
  - Comparativa entre lotes de la misma genética
  - Top genéticas por rendimiento/eficiencia

- [ ] **TICKET-024: Dashboard analítico por rol — Dispensador** | Complejidad: M | Archivos: `frontend/src/views/`
  - Stock disponible por producto con alerta de stock bajo
  - Pacientes con REPROCANN por vencer (próximos 30 días)
  - Dispensaciones del día / semana / mes
  - Top pacientes por volumen

- [ ] **TICKET-025: IA aplicada al cultivo — Recomendaciones** | Complejidad: XL
  - Con datos de `registros_ambientales` + `lecturas_ambientales` + `setpoints_fase`:
  - Detectar desviaciones del VPD objetivo para la fase actual
  - Sugerir ajustes de iluminación, temperatura, nutrición basado en fase + genética
  - Alertas predictivas: "la Sala 2 está fuera de rango de VPD por 3 días consecutivos"
  - Base para correlacionar condiciones ambientales con rendimiento futuro

- [ ] **TICKET-026: Benchmark entre clubes (anonimizado)** | Complejidad: L
  - Rendimiento promedio por genética a nivel plataforma (anonimizado)
  - Comparar mi club vs promedio de plataforma: rendimiento, costo por gramo, merma
  - Requiere consentimiento explícito del club + anonimización real

- [ ] **TICKET-027: API pública para investigación** | Complejidad: L
  - Endpoints públicos con datos anonimizados y agregados
  - Datos de genéticas (rendimiento promedio, perfil cannabinoide)
  - Para uso de investigadores y organizaciones del sector
  - Requiere TICKET-026 primero

- [ ] **TICKET-028: Módulo médico — Historia clínica estructurada** | Complejidad: L | Archivos: `app/models/`, `db/migrate/`, `frontend/src/views/medico/`
  - Reemplazar `notas_clinicas` (text libre) por campos estructurados
  - Anamnesis, antecedentes, diagnóstico, evolución
  - Timeline clínico integrado con dispensaciones e indicaciones
  - Exportar historia clínica en PDF firmado

- [ ] **TICKET-029: Integración con sistemas de salud (HL7/FHIR)** | Complejidad: XL
  - Largo plazo: exportar datos de pacientes en formato HL7/FHIR
  - Interoperabilidad con sistemas del MSAL (Ministerio de Salud Argentina)
  - Pre-condición: TICKET-028 completo

---

## RESUMEN DE PRIORIDADES

| # | Ticket | Complejidad | Prioridad | Semana |
|---|--------|-------------|-----------|--------|
| 001 | FK + número de lote en stocks | S | 🔴 | 1 |
| 002 | Fix FK genetica_id | S | 🔴 | 1 |
| 003 | Soft delete + club_id en plants | M | 🔴 | 1-2 |
| 004 | reprocann_adjunto → ActiveStorage | M | 🟡 | 2 |
| 005 | Alertas vencimiento indicaciones | M | 🟡 | 2-3 |
| 006 | Plan vs Real en lotes | M | 🟡 | 3-4 |
| 007 | INASE en genéticas | S | 🟡 | 1 |
| 008 | Workflow renovación REPROCANN | M | 🟡 | 3-4 |
| 010 | ARICCAME — estructura base | L | 🔴 | 5-7 |
| 011 | ARICCAME — integración API ANMAT | XL | 🔴 | 7-10 |
| 012 | QR en stocks | M | 🔴 | 5-6 |
| 013 | Vista etiqueta + impresión | M | 🟡 | 6 |
| 014 | Asistente IA con Claude API | L | 🟡 | 7-9 |
| 015 | Dashboard Plan vs Real | M | 🟡 | 8-9 |
| 016 | Cámara en sala UI | M | 🟢 | 9-10 |
| 017 | Multi-tenancy RLS | XL | 🔴 | 8-12 |
| 018 | Serializers dedicados | L | 🟡 | 10-11 |
| 019 | Push notifications | L | 🟡 | 11-12 |
| 020 | Carnet digital | M | 🟡 | 13-15 |
| 021 | App móvil MVP | XL | 🟡 | 13-20 |
| 022 | Trazabilidad completa UI | M | 🟢 | 14-15 |
| 023-024 | Dashboards analíticos | L | 🟢 | 15-17 |
| 025 | IA cultivo — recomendaciones | XL | 🟢 | 17-22 |
| 026-027 | Benchmark + API pública | L | 🟢 | 20-24 |
| 028-029 | HC estructurada + HL7 | XL | 🟢 | 20-24 |

**Leyenda complejidad:** S = 1-2 días | M = 3-5 días | L = 1-2 semanas | XL = 3-4 semanas

---

## POSICIÓN ESTRATÉGICA FINAL

```
NOSOTROS (Cultivo Espacial)          ARAUCANN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Módulo médico REPROCANN        ❌
✅ Indicaciones terapéuticas      ❌
✅ Firma digital documentos       ❌
✅ Delivery con tracking          ❌
✅ Cuenta corriente $+gramos      ❌
✅ Trazabilidad cultivo           ✅
✅ IoT / Ambiente / Alertas       ✅
✅ Tareas recurrentes             ✅
✅ QR por planta                  ✅
❌ QR por producto               ✅ → TICKET-012
❌ ARICCAME                      ✅ → TICKET-010/011
❌ Plan vs Real sistemático      ✅ → TICKET-006/015
⚠️ IA asistente (básico)        ✅ → TICKET-014
```

**Conclusión:** La base técnica es sólida y la diferenciación real ya existe (módulo médico).
El foco de las próximas 4 semanas debe ser cerrar las brechas de trazabilidad (número de lote, QR en productos, FK integrity) y arrancar el módulo ARICCAME, que es el único bloqueante regulatorio serio.
Todo lo demás es paridad o diferenciación que se puede ir sumando con el tiempo.

Somos el único sistema que puede decir: **semilla → planta → producto → paciente → prescripción médica → informe ANMAT**.  
Ningún competidor puede decir eso hoy. Hay que llegar ahí primero.
