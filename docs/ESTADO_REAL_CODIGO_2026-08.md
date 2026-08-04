# Estado real del código — auditoría documental (2026-08-04)

> Contraste entre lo que estaba **asumido/documentado** y lo que el **código realmente hace** hoy.
> Todo lo de acá se verificó leyendo el fuente (modelos, policies, controllers, specs, migraciones,
> schema, rutas, package.json, Gemfile.lock). Donde se corrió algo, se indica.
> **Este documento es la base para escribir los manuales de uso por rol** — si algo acá contradice
> a `CLAUDE.md` o a notas viejas, manda esto.

---

## 0. Tabla resumen

| # | Punto | Estado | Verificado en |
|---|---|---|---|
| 1 | Roles del sistema | ❌ **CORREGIDO** — son **11**, no 8. `paciente` es un rol con login real | `backend/app/models/user.rb:40-52` |
| 2 | Acceso a datos clínicos | ⚠️ **PARCIALMENTE CORREGIDO** — hay **dos superficies clínicas distintas** con reglas distintas | `paciente_policy.rb`, `pacientes_controller.rb`, `indicacion_medica_controller.rb`, `patient_documents_controller.rb` |
| 2b | Spec de regresión | ✅ **CONFIRMADO y CORRIENDO VERDE** (63 ejemplos, 0 fallas) | `spec/requests/paciente_historia_clinica_leak_spec.rb` + 4 más |
| 3a | AUTH-01 (JWT) | ✅ **CONFIRMADO** — sin fallback, `raise` al boot | `config/initializers/devise.rb:325-328` |
| 3b | AZ-01/AZ-02 (leak clínico) | ✅ **CONFIRMADO** — allowlist en master, no revertido | `pacientes_controller.rb:12-27,77-89` |
| 3c | ENC-01 (cifrado) | ✅ **CONFIRMADO** con matices — backfill es **rake, no migración** | `paciente.rb:31-48`, `lib/tasks/encryption_backfill.rake` |
| 3d | TEN-01 (tenancy) | ✅ **MÁS AVANZADO DE LO DOCUMENTADO** — `require_tenant=true` ya activo, 62 modelos | `config/initializers/acts_as_tenant.rb:20`, `application_controller.rb:56-79` |
| 4 | Flujo de manicura | ❌ **CORREGIDO** — `manicura_pendiente` **no existe**; `secado` **sí es estado de planta** | `lote.rb:44`, `plant.rb:24`, `pesaje_manicura.rb:5` |
| 5 | ARICCAME | ✅ **CONFIRMADO** — flag `features['ariccame']`, default OFF | `club.rb:155-172`, `db/schema.rb:452` |
| 6 | Dispensación | ❌ **CORREGIDO** — el cap mensual **existe y se enforcea** (apagado por defecto, invisible en UI) | `dispensacion.rb:110,250-259` |
| 7 | Máquina dispensadora | ✅ **CONFIRMADO** — cero líneas de código | búsqueda global sin resultados |
| 8 | Asistente de voz IA | ⚠️ **CORREGIDO** — string exacto `claude-sonnet-4-6`; **no tiene acción de dispensar** | `asistente_controller.rb:516,546` |
| 9 | Multi-tenancy y DNI | ⚠️ **CORREGIDO** — DNI **no es la única** unicidad global | `db/schema.rb` (índices únicos) |
| 10 | Infraestructura | ✅ **CONFIRMADO** salvo subdominios | `Gemfile.lock`, `package.json`, `docker-compose.yml` |
| 10b | Routing de subdominio por club | ❌ **NO IMPLEMENTADO** — `current_club = Club.first` con TODO | `app/controllers/public/base_controller.rb:33` |

---

## 1. Roles y permisos

### 1.1 Los 11 roles reales

`User#role` es un enum de PostgreSQL con **11 valores** (`backend/app/models/user.rb:40-52`):

```
super_admin · admin · medico · cultivador · supervisor · abogado
auditor · dispensador · manicura · paciente · delivery
```

**Correcciones respecto de lo asumido:**

- Faltaban **`abogado`** y **`auditor`** en la lista documentada.
- **`paciente` NO es "solo acceso vía QR".** Es un rol de login completo, con entrada en la matriz
  `Permissions::PERMISSIONS` (`concerns/permissions.rb:69-73`: `mi_perfil`, `mis_dispensaciones`,
  `eventos`) y en `usePermissions.js:83`. Los accesos por QR/token (`/c/:token` carnet,
  `/d/:token` pasaporte de dispensa) son **anónimos y públicos**, no el rol `paciente`.

### 1.2 Tres mecanismos de autorización coexistiendo (importante para los manuales)

| Mecanismo | Dónde | Cobertura |
|---|---|---|
| `before_action :require_*` ad-hoc | La mayoría de los controllers | **Es la barrera primaria** |
| Pundit (`app/policies/`) | **Solo 11 recursos** | `alerta_interna, application, club, documento, informe, lote, paciente, pesada, pesaje_manicura, plant, sala` |
| `Permissions::PERMISSIONS` + `can?` | `concerns/permissions.rb` | **NO se usa en ningún controller del backend.** Se espeja a mano en `frontend/src/composables/usePermissions.js` |

Consecuencia práctica: **la matriz `PERMISSIONS` no es fuente de verdad de lo que el backend
permite** — describe lo que el frontend muestra. Para el manual de un rol hay que mirar el
controller concreto.

### 1.3 Bloqueos globales

- **`auditor` → solo lectura absoluta**, bloqueado en `ApplicationController#block_auditor_writes!`
  (`application_controller.rb:33-40`): cualquier verbo que no sea GET/HEAD/OPTIONS → 403.
- **`super_admin` en modo observador** → escritura bloqueada fuera de `/api/super_admin/`
  (`application_controller.rb:42-48`). El modo expira (`observer_expires_at`).
- **Club eliminado/inactivo** → 403 en todo lo que cuelgue de `BaseController`
  (`base_controller.rb:21-27`).

---

## 2. Acceso a datos clínicos — hay DOS superficies, no una

Este es el punto más importante a corregir para los manuales, porque las dos superficies tienen
**reglas de rol distintas** y ambas están cubiertas por specs verdes.

### 2.1 Superficie A — campos clínicos embebidos en la ficha del paciente

`GET /pacientes/:id` (`pacientes_controller.rb:77-101`). Los 11 campos clínicos
(`notas_clinicas, motivo_consulta, anamnesis, antecedentes_personales, antecedentes_familiares,
diagnostico_principal, diagnostico_secundario, evolucion_clinica, alergias, medicacion_habitual,
grupo_sanguineo`) se agregan al JSON **solo si** `policy(@paciente).ver_notas_clinicas?`.

`PacientePolicy` (`app/policies/paciente_policy.rb:4-10`):

| Constante | Roles | Qué habilita |
|---|---|---|
| `ROLES_LECTURA` | `admin, medico, supervisor, dispensador` | Ver la ficha (datos **no** clínicos) |
| `ROLES_CLINICA` | `admin, medico, supervisor` | Ver historia clínica + `#timeline` |
| `ROLES_EDITAR_CLINICA` | `admin, medico` | Editar historia clínica |

**El supervisor SÍ ve la historia clínica acá.** (Lo documentado decía eso — es correcto para
esta superficie.)

`super_admin` y `dispensador` quedan fuera **por rol**, no por falta de club: `super_admin` con
`club_id` seteado igual recibe **403** en `#show` (cubierto por spec).

`authorize @paciente` está presente en `#show` (línea 78), `#timeline` (119), `#subir_reprocann`
y `#eliminar_reprocann` (104, 113).

### 2.2 Superficie B — indicaciones médicas y documentos clínicos

- `IndicacionMedicaController` (`indicacion_medica_controller.rb:3,72-76`)
- `PatientDocumentsController` (`patient_documents_controller.rb:3,115-119`)

Ambos: `before_action :require_medico_or_admin` → **solo `medico` y `admin`**.
**El supervisor recibe 403 acá**, igual que cultivador/manicura/dispensador/delivery/abogado.
Cubierto por `spec/requests/clinica_authz_spec.rb:17`.

> ⚠️ **Divergencia real entre superficies A y B.** El supervisor puede leer el diagnóstico y la
> evolución clínica desde la ficha del paciente, pero no puede abrir las indicaciones médicas ni
> los documentos clínicos firmados. `SECURITY_AUDIT.md:65` afirma "Acceso clínico = médico + admin
> únicamente" — eso es cierto solo para la superficie B. **Es una decisión a tomar antes de
> escribir el manual del supervisor**, no un bug que yo deba resolver.

### 2.3 Hueco encontrado: `#index` no llama `authorize`

`GET /pacientes` (`pacientes_controller.rb:29-75`) usa `policy_scope(Paciente)` pero **nunca llama
`authorize`**, así que `PacientePolicy#index?` (que exige `ROLES_LECTURA`) **no se evalúa**.
El único filtro es el blocklist `check_pacientes_role!` (línea 450-455), que bloquea
`delivery, abogado, cultivador, manicura, auditor`.

Efecto: un usuario con rol **`paciente`** o **`super_admin`** con club asignado pasa el blocklist y
recibe el listado de pacientes del club con los campos **no clínicos** de la allowlist — que incluyen
`dni`, `dni_normalizado`, `email`, `telefono`, `domicilio_*`, `carnet_token`.
La lista **no** expone campos clínicos (allowlist estricta, cubierto por spec).

Verificado por lectura del código; **no hay spec que cubra `#index` para los roles `paciente` o
`super_admin`** (`spec/requests/paciente_roles_spec.rb` no los prueba). No lo toqué —
queda como hallazgo para decidir.

### 2.4 Specs corridos

```
docker compose run --rm -e RAILS_ENV=test backend bundle exec rspec \
  spec/requests/paciente_historia_clinica_leak_spec.rb \
  spec/requests/clinica_authz_spec.rb \
  spec/requests/paciente_notas_clinicas_spec.rb \
  spec/requests/paciente_roles_spec.rb \
  spec/requests/dispensador_paciente_tabs_spec.rb

→ 63 examples, 0 failures
```

(El spec de regresión que buscabas existe y se llama exactamente
`spec/requests/paciente_historia_clinica_leak_spec.rb`.)

> Nota de entorno: los specs **no corren con el Ruby local** — `vendor/bundle` tiene `openssl 4.0.2`
> compilado contra `OPENSSL_3.4.0`, que no está en el host WSL. Hay que correrlos dentro del
> contenedor (`docker compose run --rm -e RAILS_ENV=test backend bundle exec rspec ...`).

---

## 3. Seguridad y cifrado — estado real

### 3.1 AUTH-01 — secreto JWT ✅ RESUELTO

`config/initializers/devise.rb:320-336`:

```ruby
jwt.secret = ENV['DEVISE_JWT_SECRET_KEY'].presence ||
  raise('DEVISE_JWT_SECRET_KEY no está definida (o está vacía). ...')
```

**No queda ningún fallback funcional.** La app no arranca sin la ENV.
Detalle menor: en `devise.rb:17` sigue el `config.secret_key = '27a5b9...'` **comentado** que
genera Devise por default. Es inerte (está comentado) pero es un secreto de ejemplo en el repo —
conviene borrar la línea en alguna pasada.

Expiración del token: **12 horas** (`jwt.expiration_time = 12.hours.to_i`).

### 3.2 AZ-01/AZ-02 — leak clínico ✅ MERGEADO, NO REVERTIDO

El fix está en `master` y vivo:
- `CAMPOS_NO_CLINICOS` / `CAMPOS_CLINICOS` como allowlists explícitas (`pacientes_controller.rb:12-27`)
- `authorize @paciente` en `#show`
- gate `policy(@paciente).ver_notas_clinicas?` antes de mergear los campos clínicos
- `PacientePolicy` con allowlist **por rol** (no por presencia/ausencia de club)

Specs verdes (ver §2.4).

### 3.3 ENC-01 — encriptación de campos ✅ CONFIRMADO (con correcciones)

**Determinístico vs no-determinístico** — confirmado exactamente como lo tenías anotado
(`app/models/paciente.rb:31-48`):

```ruby
encrypts :dni,              deterministic: true
encrypts :dni_normalizado,  deterministic: true
encrypts :reprocann_numero, deterministic: true
encrypts :email            # no-determinístico
encrypts :telefono
encrypts :notas_clinicas, :motivo_consulta, :anamnesis, :antecedentes_personales,
         :antecedentes_familiares, :diagnostico_principal, :diagnostico_secundario,
         :evolucion_clinica, :alergias, :medicacion_habitual, :grupo_sanguineo
```

También cifran: `User` (`dni`, `phone` — `user.rb:22-23`), `IndicacionMedica`, `PatientDocument`.
`nombre`/`apellido` y `domicilio_*`/`envio_*` quedan **en claro a propósito** (búsqueda LIKE y
lógica de envíos — ENC-01b, decisión consciente).

Efecto colateral documentado en el código: `dni_normalizado` va determinístico → **no admite LIKE
parcial**, solo igualdad exacta. La búsqueda por DNI en `#index` es exacta
(`pacientes_controller.rb:43-52`).

**El backfill NO es una migración.** Es una rake task: `lib/tasks/encryption_backfill.rake`
(`rails encryption:backfill`). Sobre tus tres preguntas:

| Pregunta | Respuesta | Evidencia |
|---|---|---|
| ¿Usa `with_deleted`? | ✅ Sí | `model.respond_to?(:with_deleted) ? model.with_deleted : model.unscoped` — comentario explícito: *"Incluir soft-deleted (paranoia): esos datos sensibles también deben cifrarse"* |
| ¿Batched? | ✅ Sí | `find_each(batch_size: 200)` |
| ¿Idempotente? | ✅ Sí | Documentado en el header y por construcción (`*_will_change!` + `save!(validate: false)`) — re-cifrar una fila ya cifrada no pierde datos. Efecto conocido: bumpea `updated_at` |

**El comentario inline sobre la excepción de scoping global del DNI existe, pero está en el modelo,
no en la migración:**

- `app/models/paciente.rb:56` — *"Unicidad global (no por club) — requisito REPROCANN: un DNI no
  puede estar en dos clubes a la vez"*, con mensaje de error de cara al usuario que lo explica.
- `app/policies/paciente_policy.rb:5-10` — comentarios de por qué la allowlist es por rol.
- La migración original (`db/migrate/20251011142647_create_socios.rb:28`, `add_index :socios,
  :dni_normalizado, unique: true`) **no tiene comentario**.

**Pendiente real (no bloqueante para el código, sí para prod):**
1. Generar y cargar las 3 claves de producción (`ACTIVE_RECORD_ENCRYPTION_*`). Sin ellas la app
   no arranca en prod (fail-fast por diseño).
2. Correr `rails encryption:backfill` post-deploy.
3. En una deploy posterior: `support_unencrypted_data = false` en `application.rb:74`
   (**hoy está en `true`**).

### 3.4 TEN-01 — multi-tenancy ✅ MÁS CERRADO DE LO QUE PENSABAS

| Aspecto | Documentado | Real |
|---|---|---|
| Modelos con `acts_as_tenant` | 42 | **62** |
| `require_tenant` | "diferido, alto riesgo" | **`true` — ya está activo** (`config/initializers/acts_as_tenant.rb:20`) |
| Jobs envueltos | pendiente | hecho (16 jobs) |
| Pundit | "pendiente" | **parcial y así se queda** — 11 policies; el resto es `require_*` ad-hoc |

Único modelo con `belongs_to :club` **sin** `acts_as_tenant`: **`User`** (a propósito —
auth y super_admin operan cross-club).

Fijación del tenant: `ApplicationController#set_tenant_from_current_user` (líneas 56-79).
- sin usuario (público/login/webhooks) → sin tenant
- `super_admin` → sin tenant (cross-club a propósito)
- resto → `set_current_tenant(user.club)`
- usuario de club sin club resoluble → **403 ruidoso** en vez de seguir con tenant nil

Controllers públicos: `Public::BaseController` declara `public_tenant_mode` (`:club` o `:token`)
y envuelve el request en `with_tenant` / `without_tenant` (`public/base_controller.rb:5-28`).

**Qué falta para darlo por cerrado:** nada a nivel código de tenancy. Lo que queda es la
**autorización**, que es otro eje: unificar los tres mecanismos (§1.2) o al menos documentar cuál
manda. Y el hueco de `pacientes#index` (§2.3).

En consola/rake/seeds hay que envolver en `ActsAsTenant.with_tenant(club) { ... }` o las queries
explotan con `NoTenantSet`.

---

## 4. Flujo de cultivo y manicura

### 4.1 Estados del LOTE (`app/models/lote.rb:44`)

```
enraizado → vegetativo → floracion → cosecha → en_manicura → curado → finalizado
```

**Correcciones:**

- **`manicura_pendiente` NO EXISTE.** Cero ocurrencias en backend, specs y frontend.
  La aprobación del pesaje **no es un estado del lote**: vive en `PesajeManicura#estado`
  (`pesaje_manicura.rb:5`): `borrador → enviado → confirmado`. El lote sigue en `en_manicura`
  hasta que se confirma el pesaje, y ahí pasa a `curado` (que es cuando se crea el `Stock` y
  arranca el curado).
- **`secado` no es un estado del lote** ✅ (es una métrica: días de cosecha → stock, `dias_secado`).
- Faltaba `enraizado` al principio (los lotes **arrancan enraizando**, vengan de semilla o de
  esqueje — `estado_inicial_para_origen` siempre devuelve `'enraizado'`).
- Faltaba `curado` como estado explícito entre `en_manicura` y `finalizado`.

Otras constantes útiles para el manual:

| Constante | Valor |
|---|---|
| `CULTIVO_ESTADOS` (exigen sala) | `enraizado, vegetativo, floracion` |
| `POST_COSECHA` (sin sala) | `cosecha, en_manicura, curado, finalizado` |
| `AVANCE` (botón "avanzar fase") | `enraizado → vegetativo → floracion → cosecha` |
| `ORIGENES` (eje independiente de la fase) | `semilla, esqueje` |

`origen` y `estado` son **dos ejes independientes**: de dónde viene la planta no es una fase.

### 4.2 Estados de la PLANTA (`app/models/plant.rb:24`)

```
enraizado · vegetativo · floracion · secado · cosechado · descartada
```

> ⚠️ **`secado` SÍ es un estado real y vigente de `Plant`**, aunque no lo sea de `Lote`.
> No es código muerto: tiene validación de inclusión, scope `en_secado`, y lo consumen KPIs y
> vistas. **No lo trates como legacy.**

`MOTIVOS_DESCARTE`: `no_prendio, plaga, enfermedad, macho, hermafrodita, estres, rotura, otro`.

### 4.3 Referencias a `secado` — clasificadas

**Legítimas (estado de planta, NO tocar):**

| Archivo | Uso |
|---|---|
| `app/models/plant.rb:24,47` | `STATES` + scope `en_secado` |
| `app/controllers/stats_controller.rb:26` | KPI `plantas en secado` |
| `app/services/informe_semestral_service.rb:88` | `plantas_en_secado` (informe semestral) |
| `app/controllers/sedes_controller.rb:142` | suma `cosechado + secado` para "cosechadas" |
| `app/controllers/plants_controller.rb:341` | fecha de referencia por estado |
| `frontend/src/lib/loteHelpers.js:14,31` | `PLANT_STATES` + label/color |
| `frontend/src/views/PlantasView.vue:34`, `QuickActivity.vue:217` | UI de estados de planta |

**Sospechosas de legacy (referencian `secado`/`curado` como si fueran estados de LOTE):**

| Archivo | Nota |
|---|---|
| `app/policies/lote_policy.rb:41` | `when 'enraizado','vegetativo','floracion','cosecha','secado'` → `'secado'` nunca matchea un `Lote#estado`. Rama muerta. |
| `app/services/tareas_auto_service.rb:22` | clave `'secado' => [...]` en el mapa de tareas automáticas por fase → nunca se dispara para lotes. |
| `app/controllers/lotes_controller.rb:892` y `plant_activities_controller.rb:114` | mapas de labels `'secado' => 'Secado', 'curado' => 'Curado'` — inofensivos, pero mezclan vocabularios de lote y planta. |
| `app/controllers/historial_controller.rb:102` | ídem. |
| `frontend/src/views/CosechadoView.vue:231`, `PlantaQrView.vue:544`, `MCosechasPorPesarView.vue:21,84`, `RendimientoView.vue:332` | CSS/badges para un estado de lote `secado` que ya no se produce. Cosmético. |

Ninguna rompe nada; son ramas inalcanzables y estilos huérfanos.

---

## 5. ARICCAME ✅ CONFIRMADO

- **Es un feature flag por club**, dentro de la columna jsonb `clubs.features`
  (`db/schema.rb:452`: `t.jsonb "features", default: {}, null: false`, con índice GIN).
- La clave es **`ariccame`**, declarada en `Club::AVAILABLE_FEATURES` (`club.rb:155-172`).
- Se consulta con `club.feature?(:ariccame)` → `features['ariccame'] == true` (`club.rb:172-174`).
- **Default: OFF** — el default de la columna es `{}`, así que la ausencia de la clave es `false`.
  No hay migración que lo prenda para nadie.
- Modelo de datos: `AriccameRegistro` (tipo dispensación/stock, estado, `codigo_ariccame`),
  más `dispensaciones.ariccame_reportada` (default `false`, con índice parcial sobre las no
  reportadas).

**Los 12 feature flags reales** (`club.rb:155-168`) — varios no estaban documentados:

```
ia_analisis · ia_voz · web_publica · mailer · iot · alertas
ariccame · cuenta_corriente · analytics · multi_sede · insumos · bar
```

---

## 6. Dispensación — el cap mensual SÍ existe

### 6.1 Corrección importante

Lo documentado decía "sin cap mensual enforced". **Falso a medias.**

`app/models/dispensacion.rb:110`:

```ruby
validate :limite_mensual_no_superado, on: :create
```

`app/models/dispensacion.rb:250-259`:

```ruby
def limite_mensual_no_superado
  return unless paciente && cantidad.to_d > 0
  limite = paciente.limite_dispensacion_mensual_g.to_d
  return if limite <= 0
  restante = limite - paciente.dispensado_mes_actual_g.to_d
  if cantidad.to_d > restante
    errors.add(:cantidad, "supera el límite mensual del paciente (...)")
  end
end
```

Es decir:

| | Realidad |
|---|---|
| ¿Existe la validación? | **Sí, y bloquea la creación** |
| ¿Está activa por defecto? | **No** — `pacientes.limite_dispensacion_mensual_g` es `decimal(8,2)` **sin default** (nil) → `limite <= 0` → `return` temprano |
| ¿Se puede prender? | Sí, vía `PATCH /pacientes/:id`. **Solo `admin` y `super_admin`** pueden setearlo (`pacientes_controller.rb:428-430`) |
| ¿Aparece en la UI? | **No.** Cero ocurrencias de `limite_dispensacion_mensual_g` / `porcentaje_limite_mensual` en `frontend/src` |
| ¿Se expone en la API? | **Sí** — está en `CAMPOS_NO_CLINICOS` (línea 15) y `porcentaje_limite_mensual` en los `methods` de `#show` (línea 83) |

**Redacción correcta para el manual:** *"No hay cap mensual configurado ni visible en la interfaz.
El campo existe en el modelo y, si un admin lo setea vía API, la creación de dispensaciones que lo
excedan es rechazada. El control financiero real es el crédito de cuenta corriente."*

`CLAUDE.md` dice *"no construir features sobre él ni exponerlo más en UI"* — eso sigue siendo la
política; solo hay que dejar de decir que no existe.

### 6.2 Log cronológico ✅ CONFIRMADO

`Dispensacion` scope `recientes` (`dispensacion.rb:129`):
`order(fecha_dispensacion: :desc, created_at: :desc)`. Lo usa `dispensaciones_controller.rb:17`.

### 6.3 Gramos totales ✅ CONFIRMADO como contador histórico

`dispensaciones_controller.rb:20`:
```ruby
@meta = { total: base.count, pagina: page, limite: limit, gramos_totales: base.sum(:cantidad).to_f }
```
Es la suma del scope filtrado (histórico del paciente), **no** un contador con semántica de límite.

### 6.4 Contexto adicional para el manual

- **Medios de pago reales** (`dispensacion.rb:10`):
  `efectivo · transferencia · cuenta_corriente · no_abona · credito_gramos · mixto · regalo`
  (`credito_gramos`, `mixto` y `regalo` no estaban documentados).
- **Multi-stock**: una dispensa tiene N `DispensacionItem`. `cantidad_total` suma las líneas y cae
  al campo legacy `cantidad` si todavía no hay líneas.
- **Estados de envío**: `pendiente · en_viaje · entregado · fallido · cancelada`.
- `dispensaciones` **no tiene columna `club_id`** — deriva el tenant del paciente
  (`dispensacion.rb:8`). No es `acts_as_tenant`.

---

## 7. Máquina dispensadora — ✅ CONFIRMADO: NO EXISTE

Búsqueda global sobre `backend/app`, `backend/db`, `backend/config` y `frontend/src` de:
`DispensingMachine`, `dispensing_machine`, `MaquinaDispensadora`, `maquina_dispensadora`,
`validate_patient`, `kiosco`, `kiosk`, `carrusel` → **cero resultados**.

No hay modelo, ni migración, ni endpoint, ni ruta, ni vista. El concepto (v0 kiosco / v1 columna
motorizada / v2 multi-carrusel) sigue siendo solo diseño. El próximo paso que tenías anotado
(`DispensingMachine` + `validate_patient`) sigue siendo el próximo paso.

---

## 8. Asistente de voz IA

### 8.1 Archivos ✅ CONFIRMADOS

- `frontend/src/components/AsistenteVoz.vue`
- `backend/app/controllers/asistente_controller.rb`

### 8.2 String de modelo — EXACTO (esto era lo crítico)

**`claude-sonnet-4-6`** — hardcodeado en **dos** lugares del controller:

| Archivo:línea | Método | Modelo |
|---|---|---|
| `asistente_controller.rb:516` | `llamar_claude_libre` (consultas) | `'claude-sonnet-4-6'` |
| `asistente_controller.rb:546` | `llamar_claude` (parseo de reportes) | `'claude-sonnet-4-6'` |

Y en otros servicios que usan la API de Anthropic:

| Archivo:línea | Modelo |
|---|---|
| `app/services/analisis_lote_service.rb:123` | `'claude-sonnet-4-6'` |
| `app/services/plan_trabajo_ia_service.rb:201` | `'claude-sonnet-4-6'` |
| `app/services/sensors/ai_csv_driver.rb:137` | `'claude-haiku-4-5-20251001'` |

**Estado de validez:** `claude-sonnet-4-6` es un ID **válido y activo** hoy — es el Sonnet de la
generación anterior, no está retirado ni deprecado, así que **nada está roto**. El actual de esa
línea es `claude-sonnet-5` (misma ventana de contexto de 1M, mejor en coding/agéntico, tokenizer
distinto → ~30% más tokens para el mismo texto). `claude-haiku-4-5-20251001` también sigue vigente.
Todas las llamadas usan `anthropic-version: 2023-06-01` y `Net::HTTP` directo (sin SDK).

### 8.3 ¿El médico puede dispensar vía el asistente?

**La pregunta no aplica: el asistente no tiene ninguna acción de dispensación.**

Tipos de acción soportados (`asistente_controller.rb:224-232` — el `case` que ejecuta):

```
registro_ambiental · registro_ambiental_sala · registro_planta
nota_lote · nota_sala · avance_ciclo · tarea
```

Todo es **cultivo**. No hay `dispensacion`, ni stock, ni pacientes. Un tipo desconocido devuelve
`"Tipo desconocido: #{tipo}"`.

**Gates reales del asistente:**

| Gate | Dónde | Regla |
|---|---|---|
| Feature de club | `asistente_controller.rb:105,131,198` | `club.feature?(:ia_voz)` → si no, **403** |
| Autenticación | `BaseController` | `authenticate_user!` + club activo |
| Rol | `asistente_controller.rb:217-218` | **Único chequeo de rol:** `cultivador` no puede crear `tarea`. El prompt además le pide al modelo no generar tareas para ese rol (línea 122 las filtra, línea 299 lo instruye) |
| Escritura | `ApplicationController` | `auditor` y observador bloqueados globalmente |

O sea: **cualquier rol con login y club con `ia_voz` prendido puede usar el asistente**, y las
acciones que ejecuta son de cultivo. No hay allowlist de roles.

Otros detalles: `ConversacionAsistente` tiene índice único `(user_id, fecha)` — se usa para el
rate limit por tier de IA (`Club::IA_TIERS`: básico 20/h, pro 60/h, enterprise 200/h).

---

## 9. Multi-tenancy y DNI

### 9.1 Scoping por club ✅ CONSISTENTE

- **62 modelos** con `acts_as_tenant(:club)`.
- **`User` es el único modelo con `belongs_to :club` sin `acts_as_tenant`** — deliberado
  (auth y super_admin son cross-club).
- `require_tenant = true`: una query a un modelo tenant sin tenant fijado lanza
  `ActsAsTenant::Errors::NoTenantSet` en vez de devolver datos mal scopeados.
- Sigue habiendo scoping manual por `current_user.club_id` como barrera primaria en los endpoints;
  `acts_as_tenant` es defensa en profundidad.

### 9.2 DNI ✅ CONFIRMADO como unicidad global, ❌ pero NO es la única

`pacientes.dni_normalizado` tiene índice único **global** (`db/schema.rb:1380`), con la validación y
el mensaje al usuario explicando el porqué (`paciente.rb:56-58`): bajo REPROCANN un DNI no puede
pertenecer a dos clubes simultáneamente. Determinístico para que la igualdad y el uniqueness
funcionen sobre el ciphertext.

**Pero hay otros índices únicos sin `club_id`.** Clasificados:

**(a) Global por naturaleza — tokens/UUIDs/QR. Sin riesgo de fuga cross-tenant:**

| Índice | Tabla |
|---|---|
| `carnet_token` | `pacientes` |
| `token`, `codigo_paquete` | `dispensaciones` |
| `codigo_qr`, `codigo_qr_cosecha` | `lotes` |
| `codigo_qr` | `plants`, `stocks` |
| `codigo` | `evento_bar_entradas` |
| `hash_documento` | `patient_documents` |
| `endpoint` | `push_subscriptions` |

**(b) Global a propósito, con justificación de dominio:**

| Índice | Tabla | Razón |
|---|---|---|
| `dni_normalizado` | `pacientes` | **REPROCANN** — la excepción documentada |
| `numero_registro_inase` | `geneticas` | Registro **nacional** INASE; las genéticas globales viven con `club_id: nil` |
| `slug` | `clubs` | Identidad del tenant |
| `email`, `reset_password_token` | `users` | `users` está fuera de tenancy por diseño |

**(c) Únicos por FK a `user_id` / `delivery_id` — implícitamente scopeados (el user pertenece a un club):**
`conversaciones_asistente(user_id, fecha)`, `jornadas_laborales(user_id, fecha)`,
`rutas_entrega(delivery_id, fecha)`, `sala_cultivadores(sala_id, user_id)`, `user_sedes(user_id, sede_id)`.

**Conclusión:** el DNI es la única excepción **de dominio** relevante junto con INASE. Ninguna de las
demás abre una fuga cross-club. La afirmación "DNI es la única excepción" es correcta en espíritu,
imprecisa al pie de la letra.

---

## 10. Infraestructura

### 10.1 Backend ✅ CONFIRMADO

| Componente | Versión real |
|---|---|
| Rails | **7.2.2.2** (API mode) |
| Ruby | **3.2.2** |
| PostgreSQL | **16** (imagen `postgres:16`) |
| Redis | **7** |
| devise | 4.9.4 |
| devise-jwt | 0.13.0 |
| pundit | 2.5.2 |
| paranoia | 3.0.1 |
| acts_as_tenant | 1.0.1 |
| sidekiq | 7.3.10 (+ sidekiq-cron 1.9) |
| pg | 1.6.2 |
| Otros | prawn/prawn-table, caxlsx, roo, pdf-reader, docx, aws-sdk-s3, web-push 3.0, twilio-ruby 7.0, rack-attack 6.7, rack-cors 3.0 |
| Tests | rspec-rails 7.0, factory_bot_rails 6.4, faker 3.0, shoulda-matchers 6.0, database_cleaner-active_record 2.1 |

### 10.2 Frontend ✅ CONFIRMADO

| Paquete | Versión (`frontend/package.json`) |
|---|---|
| vue | ^3.5.33 |
| pinia | ^3.0.4 |
| vue-router | ^4.6.4 |
| vite | ^7.0.6 |
| bootstrap | ^5.3.8 |
| chart.js | ^4.5.1 |
| @zxing/browser | ^0.2.1 (lector de código de barras) |
| jspdf | ^4.2.1 (etiquetas QR) |

`web-publica/`: vue ^3.5.29, vite ^7.3.1.

### 10.3 Puertos

| Servicio | Puerto | Fuente |
|---|---|---|
| Backend (host → contenedor) | **3001 → 3000** ✅ | `docker-compose.yml:36` |
| Frontend SaaS (Vite) | **5173** ✅ | `frontend/vite.config.js:55` |
| Web pública (Vite) | **5174** ✅ | `web-publica/vite.config.js:13` |
| Postgres | `${DB_PORT:-5434}` → **5435** en `.env` real | `docker-compose.yml:9` |
| Redis | `${REDIS_PORT:-6380}` → **6381** en `.env` real | `docker-compose.yml:15` |
| MailHog | 1025 (SMTP) / 8025 (UI) | `docker-compose.yml:64` |

API base del frontend: `http://localhost:3001/api` (`frontend/src/lib/api.js`).

### 10.4 Routing de subdominio por club ❌ NO IMPLEMENTADO

`app/controllers/public/base_controller.rb:31-34`:

```ruby
def current_club
  @current_club ||= Club.first # Por ahora club único
  # TODO: Implementar lógica según subdomain o parámetro cuando tengas múltiples clubs
end
```

**Toda la web pública resuelve al primer club de la base.** No hay:
- resolución por subdominio (`request.subdomain`) en ningún controller
- parámetro `:club_slug` en las rutas públicas — el namespace es `/api/public/*` plano
  (`config/routes.rb:19-26`)
- wildcard DNS configurado en `render.yaml` (ese archivo declara **solo** el cron de backup a R2;
  web/frontend/DB se administran desde el dashboard de Render)

`clubs.slug` existe y tiene índice único, así que la pieza de datos está — falta el ruteo.
Nota: `public/geneticas_controller.rb:8` tiene un comentario que documenta
`GET /p/:club_slug/geneticas/:slug`, pero **esa ruta no existe**: la real es
`/api/public/geneticas/:id` sin slug de club.

### 10.5 Despliegue

- Producción en **Render**; servicios administrados por dashboard, no por blueprint.
- `render.yaml` declara únicamente el cron `db-backup-diario` (07:00 UTC = 04:00 ART),
  `rake backup:create` → bucket R2 dedicado.
- Health check: **`/up`** (no `/`, porque `/` sirve el SPA y devuelve 404 si no hay build).
- El SPA se sirve desde el propio Rails (`application#spa_fallback` + `get '*path'`) → cookie JWT
  first-party same-origin.

---

## 11. Encontrado en el código y NO estaba en tu lista

Todo esto existe y funciona; ninguno figura en los 10 puntos que me pasaste.

### 11.1 Módulos completos

| Módulo | Modelos |
|---|---|
| **Salón / Bar / POS** | `Barra`, `BarProducto`, `BarVenta`, `BarVentaItem`, `BarStockMovimiento`, `CajaTurno` |
| **Eventos del salón** | `EventoBar`, `EventoBarProvision`, `EventoBarEntrada`, `EventoBarTipoEntrada`, `EventoBarTarea`, `EventoBarCosto` |
| **Depósitos e insumos** | `Deposito`, `Insumo`, `InsumoCompra`, `InsumoConsumo` — depósitos pertenecen a una **sede** |
| **Contabilidad** | `MovimientoContable`, `CategoriaContable`, `CompraCuotas`, `Cobro`, `UnidadNegocio`, cierre de período (`clubs.contabilidad_cerrada_hasta`) |
| **Multi-sede** | `Sede`, `UserSede` — asignación de salas por sede, transferencias entre depósitos |
| **Audit log** | `Auditoria` + concern `Auditable` con `auditar_solo` / `no_auditar` por modelo (allowlist estricto que **nunca** incluye campos cifrados ni clínicos) |
| **Papelera / soft-delete** | `paranoia` + concerns `Restorable` / `RestorableInterface` + `Restore::Catalog` |
| **Reseñas de producto** | `ResenaProducto` — el paciente puntúa desde `/d/:token` (gate por DNI) |
| **Jornadas laborales** | `JornadaLaboral` — planilla de horas con confirmación entre roles |
| **Webhooks salientes** | `WebhookDispatcher` + `webhook_deliveries` (ej. `paciente.creado`) |
| **Análisis IA de lote** | `AnalisisIa` + historial (`/asistente/analizar_lote`, `/asistente/historial_analisis`) |

### 11.2 Capacidades sueltas

- **Cuenta corriente en gramos**, además de en pesos: `saldo_disponible_g`, `limite_credito_g`,
  `credito_gramos_activo?`, medio de pago `credito_gramos`.
- **Modo observador de super_admin**: `observer_club_id` + `observer_expires_at`, con bloqueo de
  escritura fuera de `/api/super_admin/`.
- **SMTP propio por club** (`smtp_host/port/user/pass/from/from_name`) + **Twilio/WhatsApp por club**
  (`twilio_account_sid`, `twilio_auth_token_enc`, `twilio_whatsapp_from`, `whatsapp_numero`).
- **Tiers de IA** con límite por hora: `Club::IA_TIERS` (basico 20 / pro 60 / enterprise 200),
  override por club vía `ia_limite_hora`.
- **Alertas configurables por club**: jsonb `alertas_config`, `umbral_stock_g` (default 50).
- **Benchmark opt-in** (`benchmark_opt_in`) con endpoint público de datos agregados anonimizados.
- **Desprendimiento de lotes** (split parcial): `Lote#lote_origen` / `#desprendidos`.
- **Genéticas globales**: `Genetica` con `global: true` y `club_id: nil` (`has_global_records`),
  sembradas con las variedades INASE argentinas (`Club::GENETICAS_INASE`).
- **`email_notificacion`** en `User`: usa `email_personal` si existe, porque el email de login puede
  ser un identificador inventado tipo `rol@club.com` que rebota.
- **Candado de manicura asignada**: si el lote tiene manicurador, solo esa persona registra el peso.
- **Rutas públicas por token**: `/c/:token` (carnet), `/d/:token` (pasaporte de dispensa),
  `/p/:codigo_qr` (planta), `/s/:codigo_qr` (stock) — todas anónimas, con `public_tenant_mode: :token`.

### 11.3 Deuda técnica visible

- `application.rb:74`: `support_unencrypted_data = true` — hay que apagarlo post-backfill en prod.
- `devise.rb:17`: secreto de ejemplo del generador, comentado. Borrarlo.
- `application_cable/connection.rb`: fallback a `credentials.devise_jwt_secret_key` que es `nil` →
  código muerto desde que el boot garantiza la ENV.
- `pacientes#index` sin `authorize` (§2.3).
- Ramas muertas por `secado` como estado de lote (§4.3).
- `Permissions::PERMISSIONS` sin uso en backend (§1.2) — o se adopta, o se documenta como
  "espejo del frontend" y se deja de leer como fuente de verdad.

---

## 12. Qué decidir antes de escribir los manuales

1. **Supervisor y datos clínicos** — hoy ve la historia clínica en la ficha pero no las indicaciones
   ni los documentos. ¿Se unifica hacia arriba o hacia abajo? (§2.2)
2. **`pacientes#index` sin `authorize`** — `paciente` y `super_admin` listan pacientes del club con
   DNI/email/teléfono. ¿Se cierra? (§2.3)
3. **Cap mensual de dispensación** — existe y enforcea. ¿Se documenta como capacidad de admin, o se
   remueve del modelo para que el código diga lo mismo que la política? (§6.1)
4. **Modelos de IA** — cuatro llamadas hardcodean `claude-sonnet-4-6` (válido, no roto). ¿Se
   centraliza en una constante/ENV para no tener que tocar cuatro archivos la próxima vez? (§8.2)
5. **Rol `paciente`** — tiene login, permisos y home, pero no está en `ROLE_ALLOWED_PREFIX` del
   router. ¿Es un rol vivo o vestigial? Determina si lleva manual propio. (§1.1)
6. **Web pública multi-club** — `Club.first` bloquea el onboarding del segundo club en la web
   pública. (§10.4)
