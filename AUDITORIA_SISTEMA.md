# AUDITORÍA DEL SISTEMA — Club Cultivo
**Fecha:** 2026-05-10  
**Auditor:** Claude (arquitecto técnico)  
**Stack:** Rails 7.2 + Vue 3 + PostgreSQL  
**Schema version:** 2026_05_09_000001 (42 tablas)

---

## PASO 1 — MAPEO ESTRUCTURAL DEL PROYECTO

### 1a. Backend (Rails 7.2 API mode)

**Modelos identificados (app/models/):** 30+ modelos

| Modelo | Tabla | Asociaciones clave |
|--------|-------|-------------------|
| Club | clubs | has_many salas, lotes, pacientes, geneticas, sedes, users |
| Sede | sedes | belongs_to club; has_many salas, stocks, user_sedes |
| Sala | salas | belongs_to club, sede; has_many lotes, dispositivos, alertas, sala_cultivadores |
| Lote | lotes | belongs_to club, sala, genetica; has_many plants, pesadas, lote_eventos, registros_ambientales, stocks |
| Plant | plants | belongs_to lote; has_many plant_activities, notas; belongs_to planta_madre (self-join) |
| PlantActivity | plant_activities | belongs_to plant, user |
| Genetica | geneticas | belongs_to club (optional); has_many lotes, setpoints_fase |
| Pesada | pesadas | belongs_to lote, registrado_por (User), aprobada_por (User); has_many pesadas_plantas |
| PesadaPlanta | pesadas_plantas | belongs_to pesada, plant |
| LoteEvento | lote_eventos | belongs_to lote, user, club, sala_origen, sala_destino |
| Stock | stocks | belongs_to sede, lote (optional); has_many dispensaciones, stock_movimientos |
| StockMovimiento | stock_movimientos | belongs_to stock, sede_origen, sede_destino, usuario |
| Paciente | pacientes | belongs_to club; has_many dispensaciones, indicacion_medicas, paciente_notas, patient_documents, cuenta_corrientes |
| IndicacionMedica | indicacion_medicas | belongs_to paciente, user (médico) |
| Dispensacion | dispensaciones | belongs_to paciente, user, stock, indicacion_medica (opt), sede, delivery (User) |
| CostoLote | costo_lotes | belongs_to lote, club, calculado_por (User) |
| MovimientoContable | movimientos_contables | belongs_to club, sede, lote, dispensacion, paciente, created_by |
| CuentaCorriente | cuenta_corrientes | belongs_to paciente, club; has_many cuenta_corriente_movimientos |
| Tarea | tareas | belongs_to club, sala, lote, plant, asignada_a, creada_por |
| Dispositivo | dispositivos | belongs_to club, sala; has_many lecturas_ambientales |
| LecturaAmbiental | lecturas_ambientales | belongs_to club, sala, dispositivo, lote |
| RegistroAmbiental | registros_ambientales | belongs_to lote, user, club |
| ReglaAmbiental | reglas_ambientales | belongs_to club, sala; has_many alertas |
| Alerta | alertas | belongs_to club, regla, sala, lectura, reconocida_por, resuelta_por |
| AlertaInterna | alertas_internas | belongs_to club, creada_por |
| PatientDocument | patient_documents | belongs_to club, paciente, template, created_by |
| DocumentTemplate | document_templates | belongs_to club, created_by |
| Documento | documentos | belongs_to club, user, paciente, subido_por |
| User | users | belongs_to club (optional), observer_club; has_many sala_cultivadores |
| Nota | notas | polymorphic (noteable) |
| PacienteNota | paciente_notas | belongs_to club, paciente, created_by, deleted_by |
| SetpointFase | setpoints_fase | belongs_to club, genetica (opt) |
| JwtDenylist | jwt_denylists | - |
| Evento | eventos | belongs_to club |
| Noticia | noticias | belongs_to club |

**Servicios (app/services/):**
- `PlanEnforcer` — valida límites de plan (plantas, lotes, pacientes, etc.)
- `Ambiente::AlertaCreator` — crea alertas ambientales según reglas configuradas
- `Ambiente::EvaluadorReglas` — evalúa lecturas contra reglas definidas
- `Ambiente::VpdCalculator` — calcula VPD (Vapor Pressure Deficit)
- `Sensors::BaseDriver` — driver base para sensores IoT
- `Sensors::ManualCsvDriver` — importación manual de lecturas via CSV

**Jobs (app/jobs/):** Solo `ApplicationJob` base. Sin jobs personalizados.

**Serializers:** No existen. Serialización inline en controllers.

---

### 1b. Frontend (Vue 3 + Pinia + Vite)

**Vistas (src/views/):** 69 archivos `.vue`

**Router:** 60+ rutas con guards por rol  
**Stores (Pinia):** 13 stores (auth, plants, lotes, pacientes, salas, contabilidad, ambiente, tareas, etc.)  
**Composables:** 11 composables (useQRCode, usePermissions, useAmbiente, usePlan, etc.)  
**API client:** axios con JWT interceptors, 100+ funciones agrupadas  

---

### 1c. Tabla de módulos

| Módulo | Modelo Rails | Tabla PG | Rutas API | Vista Vue | Estado |
|--------|-------------|----------|-----------|-----------|--------|
| Autenticación | User (Devise+JWT) | users | POST /api/users/sign_in | LoginView | ✅ |
| Perfil / Usuarios | User | users | GET/PATCH /api/profile, /api/usuarios | PerfilView, UsuariosView | ✅ |
| Clubs / Onboarding | Club | clubs | via super_admin | SAClubs | ✅ |
| Sedes | Sede | sedes | CRUD /api/sedes | SedesView, SedeDetail | ✅ |
| Salas | Sala | salas | CRUD /api/salas | SalasView, SalaDetail | ✅ |
| Ambiente / Sensores | LecturaAmbiental, Dispositivo | lecturas_ambientales, dispositivos | /api/salas/:id/lecturas, /api/dispositivos | SalaAmbiente, DispositivosView | ✅ |
| Reglas ambientales | ReglaAmbiental, Alerta | reglas_ambientales, alertas | CRUD /api/reglas_ambientales | ReglasAmbientalesView | ✅ |
| Setpoints por fase | SetpointFase | setpoints_fase | CRUD /api/setpoints_fase | (inline en salas) | ⚠️ |
| Genéticas | Genetica | geneticas | CRUD /api/geneticas | GeneticasView, GeneticaDetalle | ✅ |
| Lotes | Lote | lotes | CRUD /api/lotes + transitions | LotesView, LoteDetail | ✅ |
| Plantas | Plant | plants | CRUD /api/plants | PlantasView, PlantaDetail | ✅ |
| QR de plantas | Plant | plants.codigo_qr | GET /p/:codigo_qr | PlantaQrView (pública) | ✅ |
| Actividades planta | PlantActivity | plant_activities | CRUD /api/plants/:id/plant_activities | PlantActivitiesTimeline | ✅ |
| Pesadas / Manicura | Pesada, PesadaPlanta | pesadas, pesadas_plantas | CRUD /api/lotes/:id/pesadas | MncPendientes, MncEspera | ✅ |
| Bitácora de lote | LoteEvento | lote_eventos | /api/lotes/:id/lote_eventos | (inline LoteDetail) | ✅ |
| Tareas | Tarea | tareas | CRUD /api/tareas | TareasView | ✅ |
| Costos de lote | CostoLote | costo_lotes | /api/lotes/:id/costo | (inline LoteDetail) | ✅ |
| Stocks / Inventario | Stock, StockMovimiento | stocks, stock_movimientos | /api/stocks | StockDispensadorView | ✅ |
| Socios / Pacientes | Paciente | pacientes | CRUD /api/pacientes | SociosView, SocioDetail | ✅ |
| Indicaciones médicas | IndicacionMedica | indicacion_medicas | /api/pacientes/:id/indicaciones | IndicacionesMedicas | ✅ |
| Dispensaciones | Dispensacion | dispensaciones | CRUD /api/dispensaciones | DispensarView, Historial | ✅ |
| Cuenta corriente | CuentaCorriente | cuenta_corrientes | /api/pacientes/:id/cuenta_corriente | (inline SocioDetail) | ✅ |
| Documentos paciente | PatientDocument | patient_documents | /api/pacientes/:id/documents | PacienteDocumentos | ✅ |
| Templates de docs | DocumentTemplate | document_templates | CRUD /api/document_templates | DocumentTemplatesView | ✅ |
| Delivery | Dispensacion (estado_envio) | dispensaciones | PATCH /api/dispensaciones/:id/entregar | DeliveryDashboard | ✅ |
| Módulo médico | User (rol médico) | users | /api/me, /api/indicaciones_medicas | MedicoDashboard | ✅ |
| Módulo auditor | User (rol auditor) | users | /api/informes/* | AuditorDashboard | ✅ |
| Módulo abogado | User (rol abogado) | users | /api/documentos | AbogadoDashboard | ✅ |
| Contabilidad | MovimientoContable | movimientos_contables | CRUD /api/movimientos_contables | ContabilidadView | ✅ |
| Informes REPROCANN | (query agregada) | - | GET /api/informes/reprocann | InformeReprocannView | ✅ |
| Informes producción | (query agregada) | - | GET /api/informes/produccion | InformeProduccionView | ✅ |
| Informe semestral | (query agregada) | - | GET /api/informe_semestral | InformeSemestralView | ✅ |
| Asistente IA | - | - | POST /api/asistente/parsear,ejecutar | AsistenteVoz.vue | ⚠️ |
| Super Admin | Club, User | clubs, users | /api/super_admin/* | SADashboard | ✅ |
| Web pública del club | Evento, Noticia, Genetica | - | GET /public/* | WebPublicaView | ✅ |
| IoT / Webhooks | LecturaAmbiental | lecturas_ambientales | POST /webhooks/lecturas | - | ⚠️ |
| Cámara streaming | Sala | salas.camera_stream_url | - | (field exists, no UI) | 🚧 |
| ARICCAME (ANMAT) | - | - | - | - | ❌ |
| Blockchain | - | - | - | - | ❌ |
| App móvil | - | - | - | - | ❌ |

---

## PASO 2 — ANÁLISIS DEL SCHEMA DE BASE DE DATOS

**Total:** 42 tablas | Rails 7.2 | PostgreSQL | `enable_extension "plpgsql"`

### Tablas principales de negocio

```
clubs:          name, legal_name, cuit, numero_igj, slug, plan, plan_activo_hasta,
                numero_resolucion_reprocann, fecha_resolucion_reprocann, tipo_organizacion,
                web_activa, activo, deleted_at + redes sociales

sedes:          club_id, nombre, tipo, direccion, ciudad, provincia, pais,
                declarada_reprocann, reprocann_domicilio_id, activa, deleted_at

salas:          club_id, sede_id, nombre, tipo, kind, state, pots_count, plants_max,
                camera_stream_url, camera_snapshot_url, deleted_at

lotes:          club_id, sala_id, genetica_id (INTEGER, no FK constraint!),
                codigo, estado, start_date, plants_count, strain (deprecated),
                grow_type, light_type, fotoperiodo, sustrato_especifico,
                tamanio_maceta, semanas_floracion, deleted_at

plants:         lote_id, codigo_qr (unique), nombre, state, origen,
                fecha_germinacion, fecha_vegetativo, fecha_floracion, fecha_cosecha,
                peso_seco, altura_actual, num_colas, estado_salud, color_hojas,
                es_seleccion, pasada_cosecha, planta_madre_id
                ⚠️ NO tiene club_id directo | NO tiene deleted_at

geneticas:      club_id, nombre, tipo, origen, thc, cbd, terpenos, tiempo_floracion,
                rendimiento, altura, dificultad, criador, registrada_inase, slug, global

pesadas:        lote_id, registrado_por_id, fase_origen, fase_destino,
                peso_humedo_g, peso_seco_g, peso_curado_g, manicurado,
                plantas_manicuradas, plantas_cosechadas,
                aprobada_at, aprobada_por_id, rechazada_at, motivo_rechazo

pesadas_plantas: pesada_id, plant_id, peso_humedo_g, peso_seco_g
                 ✅ Trazabilidad por planta individual

stocks:         sede_id, lote_id, origen, forma_producto, unidad, cantidad,
                costo_unitario_ars, precio_sugerido_ars, lote_origen_consumido_g,
                proveedor, descripcion, categoria, estado
                ⚠️ NO tiene codigo_lote_producto | NO tiene plant_id

pacientes:      club_id, nombre, apellido, dni, dni_normalizado, fecha_nacimiento,
                email, telefono, notas_clinicas, con_seguimiento_medico,
                reprocann_numero, reprocann_vencimiento, reprocann_adjunto, reprocann_estado,
                limite_dispensacion_mensual_g, deleted_at

indicacion_medicas: paciente_id, user_id, patologia, dosificacion, via_administracion,
                    duracion_dias, fecha_emision, fecha_vencimiento, activa

dispensaciones: paciente_id, user_id, stock_id, indicacion_medica_id, sede_id,
                fecha_dispensacion, cantidad, aporte_socio_ars, precio_unitario_ars,
                medio_pago, con_envio, estado_envio, delivery_id,
                direccion_envio, contacto_nombre, contacto_telefono, codigo_paquete,
                entregado_at, motivo_fallo

tareas:         club_id, sala_id, lote_id, plant_id, asignada_a_id, creada_por_id,
                titulo, tipo, estado, prioridad, fecha_programada, fecha_completada,
                horas_estimadas, horas_reales, horas_aplicadas_al_lote,
                recurrente, frecuencia, intervalo, recurrencia_hasta, parent_tarea_id

costo_lotes:    lote_id, club_id, costo_insumos, costo_energia, costo_mano_obra,
                costo_prorrateado, costo_total, gramos_producidos, costo_por_gramo

movimientos_contables: club_id, sede_id, lote_id, dispensacion_id, paciente_id,
                       tipo, categoria, descripcion, monto_ars, fecha,
                       comprobante_numero, comprobante_tipo, proveedor, pagado, medio_pago

patient_documents: club_id, paciente_id, template_id, nombre, tipo, estado, datos (jsonb),
                   contenido_html, hash_documento, firma_paciente_data, firmado_paciente_at,
                   firma_medico_data, firmado_medico_at, archivado_at

lecturas_ambientales: club_id, sala_id, dispositivo_id, lote_id, tipo, valor, unidad,
                      medido_at, fuente (manual|webhook), idempotencia por dispositivo+tipo+timestamp

registros_ambientales: lote_id, user_id, club_id, temperatura, humedad, vpd, co2, ph, ec,
                       ppfd, horas_luz, espectro_luz, fase_nutricional, plagas_observadas,
                       temperatura_sustrato, ph_runoff, ec_runoff, fertilizacion
```

### Diagrama ER (relaciones reales del schema)

```
[clubs] 1──N [sedes] 1──N [salas] 1──N [lotes] 1──N [plants]
   │                          │              │           │
   │                     [dispositivos]  [pesadas]  [plant_activities]
   │                          │         1──N [pesadas_plantas] ──1 [plants]
   │              [lecturas_ambientales]
   │
   ├──N [pacientes] 1──N [indicacion_medicas]
   │         │             │
   │         │      [dispensaciones] N──1 [stocks] N──1 [lotes]
   │         │             │                │
   │    [cuenta_corrientes] │         [stock_movimientos]
   │    [paciente_notas]    │
   │    [patient_documents] │
   │                        │
   ├──N [movimientos_contables]
   │         links: lote_id, dispensacion_id, paciente_id
   │
   ├──N [geneticas] ──N [setpoints_fase]
   │       (lotes.genetica_id → geneticas, but no FK constraint)
   │
   ├──N [tareas] → polimórfico: sala_id | lote_id | plant_id
   │
   ├──N [lote_eventos] (bitácora de transiciones)
   │
   ├──N [reglas_ambientales] 1──N [alertas]
   │
   └──N [users] (roles: super_admin|admin|cultivador|supervisor|manicura|
                         dispensador|medico|abogado|auditor|paciente|delivery)
```

---

## PASO 3 — AUDITORÍA DE TRAZABILIDAD

### Cadena completa: semilla → paciente

| Eslabón | Modelo Rails | Tabla PG | Controller | Vista Vue | Estado |
|---------|-------------|----------|------------|-----------|--------|
| Genética / Cepa | Genetica | geneticas | GeneticasController | GeneticasView | ✅ |
| Lote de cultivo | Lote | lotes | LotesController | LoteDetailView | ✅ |
| Sala / Espacio | Sala | salas | SalasController | SalaDetailView | ✅ |
| Planta individual | Plant | plants | PlantsController | PlantaDetailView | ✅ |
| Eventos de planta | PlantActivity | plant_activities | PlantActivitiesController | PlantActivitiesTimeline | ✅ |
| Pesada / Cosecha | Pesada + PesadaPlanta | pesadas + pesadas_plantas | PesadasController | MncPendientes | ✅ |
| Secado / Curado | (fases del Lote) | lotes.estado | LotesController#avanzar_fase | LoteDetailView | ✅ |
| Manicura | Pesada (manicurado=true) | pesadas | LotesController#aprobar_manicura | AdminAprobaciones | ✅ |
| Producto / Stock | Stock | stocks | StocksController | StockDispensadorView | ⚠️ |
| Dispensación | Dispensacion | dispensaciones | DispensacionesController | DispensarView | ✅ |
| Socio / Paciente | Paciente | pacientes | PacientesController | SocioDetailView | ✅ |
| REPROCANN | (campos en Paciente) | pacientes | PacientesController | SocioDetailView | ✅ |

### Verificaciones específicas

| Verificación | Estado | Detalle |
|-------------|--------|---------|
| Eventos/bitácora por lote | ✅ Completo | `lote_eventos` con tipo, estado_anterior, estado_nuevo, timestamps |
| Eventos/bitácora por planta | ✅ Completo | `plant_activities` con activity_type, occurred_at, metadata jsonb |
| QR codes por planta | ✅ Completo | `plants.codigo_qr` único, auto-generado, ruta pública `/p/:codigo_qr` |
| QR codes por stock/producto | ❌ Faltante | `stocks` no tiene codigo_qr |
| ARICCAME / ANMAT | ❌ Faltante | Cero menciones en el codebase |
| Blockchain | ❌ No implementado | Sin gemas ni referencias |
| Plan vs Real | ❌ Faltante | `lotes.plants_count` es intención pero no hay comparación sistematizada |
| Costos por lote | ✅ Completo | `costo_lotes` con insumos, energía, mano de obra, costo por gramo |
| Costos por planta individual | ❌ Faltante | No hay cost tracking a nivel planta |
| Trazabilidad planta → stock | ⚠️ Parcial | `stocks.lote_id` existe pero NO `stocks.plant_id` ni link a pesada específica |
| Número de lote de producto | ❌ Faltante | `stocks` no tiene campo de número de lote de producto trazable |
| INASE (registración genética) | ⚠️ Parcial | `geneticas.registrada_inase` (boolean) pero sin número de registro |
| Temperatura/Humedad por lote | ✅ Completo | `registros_ambientales` + `lecturas_ambientales` ambos linkeados a lote |
| VPD calculado | ✅ Completo | `VpdCalculator` service + campo `vpd` en registros |
| PPFD / DLI | ✅ Campo existe | `registros_ambientales.ppfd` presente |

### Brechas críticas de trazabilidad

1. **`stocks` no referencia `plant_id`**: Sabemos qué lote produjo el stock, pero no qué planta específica contribuyó a qué producto. La `pesada_planta` existe (peso individual) pero no conecta con `stocks`.

2. **`lotes.genetica_id` es INTEGER sin FK**: Violación de integridad referencial. Puede apuntar a una genética eliminada sin error.

3. **`plants` no tiene `deleted_at`**: Plantas eliminadas desaparecen físicamente. Sin soft delete, se pierde trazabilidad.

4. **`stocks` sin `numero_lote_producto`**: No hay forma de asignar un código de lote de producto al producto final (ej: "LOT-2026-001") que sea rastreable en una etiqueta.

5. **Pesada → Stock no está formalizada**: El flujo de "pesada aprobada → crea stock" existe en la UI pero no hay FK que lo documente en la BD.

---

## PASO 4 — AUDITORÍA DEL MÓDULO MÉDICO

### Estado actual

| Feature | Modelo Rails | Controller | Vista Vue | CRUD completo |
|---------|-------------|------------|-----------|---------------|
| Perfil paciente/socio | Paciente | PacientesController | SocioDetailView | ✅ |
| Indicaciones médicas | IndicacionMedica | IndicacionMedicaController | IndicacionesMedicas.vue | ✅ |
| REPROCANN (número, vencimiento) | Paciente | PacientesController | SocioDetailView | ✅ |
| Estado REPROCANN (sin_registro/por_vencer/vencido) | Paciente | PacientesController | SocioDetailView | ✅ |
| Adjunto REPROCANN | Paciente.reprocann_adjunto | PacientesController | SocioDetailView | ⚠️ (string URL, no ActiveStorage) |
| Límite mensual de dispensación (g) | Paciente | PacientesController | SocioDetailView | ✅ |
| Subida de documentos clínicos | PatientDocument | PatientDocumentsController | PacienteDocumentos.vue | ✅ |
| Firma digital de documentos | PatientDocument | PatientDocumentsController#firmar | PacienteDocumentos.vue | ✅ |
| Historial clínico / notas | PacienteNota | PacienteNotasController | SocioDetailView | ✅ |
| Notas clínicas libres | Paciente.notas_clinicas | PacientesController | SocioDetailView | ✅ |
| Seguimiento médico activo | Paciente.con_seguimiento_medico | PacientesController | SocioDetailView | ✅ |
| Alertas de vencimiento REPROCANN | Paciente (scope) | (no controller dedicado) | AlertaBadge.vue | ⚠️ |
| Dispensaciones vinculadas a paciente | Dispensacion | DispensacionesController | Dispensaciones.vue | ✅ |
| Dispensación vinculada a indicación médica | Dispensacion.indicacion_medica_id | DispensacionesController | DispensarView | ✅ |
| Informe REPROCANN (auditor) | (query) | InformesController | InformeReprocannView | ✅ |
| Historial dispensaciones por paciente | Dispensacion | DispensacionesController | HistorialDispensaciones | ✅ |
| Relación paciente ↔ stock trazado | Dispensacion → Stock → Lote | parcial | DispensarView | ⚠️ |
| Dashboard médico | User (rol médico) | - | MedicoDashboard | ✅ |
| Indicaciones del médico logueado | IndicacionMedica | IndicacionMedicaController#index_medico | MedicoIndicaciones | ✅ |

### Análisis del módulo médico

**Fortalezas únicas:**
- Integración REPROCANN en 3 niveles: Club (resolución), Sede (domicilio REPROCANN), Paciente (número individual)
- `dispensaciones.indicacion_medica_id` crea el vínculo legal: producto dispensado ↔ prescripción médica
- Templates de documentos con firma digital (paciente + médico) con hash de integridad
- Límite mensual de dispensación en gramos configurable por paciente
- Rol `medico` con su propio dashboard y scope de indicaciones
- Informe REPROCANN disponible para auditor sin acceso a datos clínicos completos
- `con_seguimiento_medico` flag para discriminar pacientes con tratamiento activo

**Debilidades:**
- `reprocann_adjunto` es un string URL en lugar de un ActiveStorage attachment — inconsistente con el manejo del resto de archivos
- No hay alertas automáticas por vencimiento de indicaciones médicas (solo por REPROCANN)
- No hay workflow de renovación de REPROCANN
- No hay campo para número de registro INASE del producto dispensado
- Falta vincular dispensación → cepa/lote específico en el informe REPROCANN

---

## PASO 5 — APIS EXTERNAS E INTEGRACIONES

### Gemfile — dependencias clave

| Gema | Versión | Propósito | Estado |
|------|---------|-----------|--------|
| rails | 7.2.0 | Framework | ✅ |
| pg | - | PostgreSQL | ✅ |
| devise | - | Autenticación | ✅ |
| devise-jwt | - | JWT tokens | ✅ |
| pundit | ~> 2.5 | Autorización por rol | ✅ |
| sidekiq | ~> 7.0 | Background jobs | ✅ configurado |
| sidekiq-cron | ~> 1.9 | Cron jobs | ✅ configurado |
| redis | >= 4.0.1 | Cache + Sidekiq | ✅ |
| paranoia | ~> 3.0 | Soft deletes | ✅ (parcial) |
| rack-attack | - | Rate limiting | ✅ |
| active_storage | (built-in) | Archivos adjuntos | ✅ |
| rspec-rails | - | Tests | ✅ |
| factory_bot_rails | - | Factories de tests | ✅ |

**Notable:** NO hay gema de serialización (ams, blueprinter, jsonapi-serializer). Serialización manual en controllers — deuda técnica futura.

### Frontend — package.json dependencias clave

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| vue | 3.5.33 | Framework |
| vue-router | 4.6.4 | Routing |
| pinia | 3.0.4 | Estado global |
| axios | 1.16.0 | HTTP client |
| chart.js | 4.5.1 | Gráficos |
| bootstrap | 5.3.8 | CSS framework |
| bootstrap-icons | 1.13.1 | Iconografía |
| qrcode | 1.5.4 | Generación QR |

### Multi-tenancy

**Tipo:** Soft multi-tenancy manual via `club_id`  
**Implementación:** Single schema compartida. Filtrado por `current_user.club_id` en cada query.  
**Sin:** Apartment gem, ActsAsTenant, Row Level Security de PostgreSQL.  
**Riesgo:** Un bug en cualquier controller puede exponer datos entre clubs. No hay barrera a nivel BD.

### WebSockets / ActionCable

❌ No hay ActionCable configurado. La sala de ambiente puede requerir polling en el cliente.

### Notificaciones

⚠️ Parcial: `alertas_internas` existe como tabla pero sin push notifications, emails, ni WebSockets. Las alertas son leídas en el polling de la UI.

### IoT / Sensores

✅ Infraestructura presente:
- Webhook endpoint: `POST /webhooks/lecturas` para sensores enviando datos
- `dispositivos` con `webhook_token_digest` para autenticación segura
- `lecturas_ambientales` con índice de idempotencia por dispositivo+tipo+timestamp
- `lecturas_ambientales_diarias` para agregados diarios (min/max/avg/p5/p95)
- `ReglaAmbiental` + `EvaluadorReglas` service para alertas automáticas
- Importación CSV manual como fallback

---

## PASO 6 — TABLA COMPARATIVA VS. ARAUCANN

| Feature | Araucann | Cultivo Espacial | Brecha | Prioridad |
|---------|----------|-----------------|--------|-----------|
| Trazabilidad genética → lote → planta | ✅ | ✅ | Ninguna | 🟢 |
| Eventos por planta con timestamps | ✅ | ✅ (plant_activities) | Ninguna | 🟢 |
| Bitácora de lote con transiciones | ✅ | ✅ (lote_eventos) | Ninguna | 🟢 |
| QR por planta (generación + escaneo) | ✅ | ✅ (completo) | Ninguna | 🟢 |
| QR por producto/stock | ✅ | ❌ | Alta | 🔴 |
| Fases del cultivo (veg→flor→cosecha→curado) | ✅ | ✅ | Ninguna | 🟢 |
| Costos por lote (insumos, energía, MO) | ✅ | ✅ (costo_lotes) | Ninguna | 🟢 |
| Costo por gramo calculado | ✅ | ✅ | Ninguna | 🟢 |
| Gestión de tareas (asignadas, recurrentes) | ✅ | ✅ (recurrencia) | Ninguna | 🟢 |
| Ambiente (temp, hum, CO2, VPD, EC, pH, PPFD) | ✅ | ✅ (completo) | Ninguna | 🟢 |
| Sensores IoT (webhook) | ✅ | ✅ | Ninguna | 🟢 |
| Alertas por reglas ambientales | ✅ | ✅ | Ninguna | 🟢 |
| Setpoints por fase y genética | ✅ | ✅ | Ninguna | 🟢 |
| Multi-sede | ✅ (plan Full) | ✅ (sedes) | Ninguna | 🟢 |
| Delivery / envío a domicilio | ❌ | ✅ (único) | N/A — ventaja | 🟢 |
| Asistente IA integrado | ✅ Araucanio | ⚠️ (básico) | Alta | 🟡 |
| Plan vs Real (planificado vs ejecutado) | ✅ | ❌ | Media | 🟡 |
| Cadena bulk → envasado → número de lote | ✅ | ⚠️ (sin num. lote) | Alta | 🔴 |
| Trazabilidad planta → stock específico | ✅ | ⚠️ (solo a lote) | Alta | 🔴 |
| Número de lote de producto (etiqueta) | ✅ | ❌ | Alta | 🔴 |
| Cámara en sala (stream/snapshot) | ✅ | 🚧 (campos en BD) | Media | 🟡 |
| Integración ARICCAME (ANMAT) | ✅ | ❌ | CRÍTICA | 🔴 |
| Blockchain trazabilidad | ✅ | ❌ | Baja (mkt) | 🟡 |
| **Módulo médico completo (REPROCANN)** | ❌ | **✅✅ (único)** | **VENTAJA** | 🟢 |
| **Indicaciones terapéuticas** | ❌ | **✅** | **VENTAJA** | 🟢 |
| **Dispensación vinculada a prescripción** | ❌ | **✅** | **VENTAJA** | 🟢 |
| **Firma digital de documentos** | ❌ | **✅** | **VENTAJA** | 🟢 |
| **Historial clínico + notas médicas** | ❌ | **✅** | **VENTAJA** | 🟢 |
| **Informe REPROCANN para auditor** | ❌ | **✅** | **VENTAJA** | 🟢 |
| **Límite de dispensación mensual/g** | ❌ | **✅** | **VENTAJA** | 🟢 |
| **Rol médico con dashboard propio** | ❌ | **✅** | **VENTAJA** | 🟢 |
| **Cuenta corriente de socio (crédito en $+g)** | ❌ | **✅** | **VENTAJA** | 🟢 |
| **Delivery con estado de envío** | ❌ | **✅** | **VENTAJA** | 🟢 |
| App móvil socios | ❌ | ❌ | Media | 🟡 |
| Carnet digital socio | ❌ | ❌ | Media | 🟡 |
| Multi-tenancy a nivel BD (aislamiento total) | ✅ | ⚠️ (soft) | Alta | 🔴 |
| Plans / límites por tier | ✅ | ✅ (PlanEnforcer) | Ninguna | 🟢 |

**Resumen de ventajas por lado:**
- Cultivo Espacial supera a Araucann en: módulo médico, compliance REPROCANN, delivery, cuenta corriente, firma digital
- Araucann supera a Cultivo Espacial en: ARICCAME, QR en productos, trazabilidad planta→stock, asistente IA maduro, plan vs real
- Empate técnico en: ambiente/IoT, cultivo, tareas, costos, multi-sede
