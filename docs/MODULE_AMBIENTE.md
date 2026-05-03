# Módulo Ambiente — Documento de diseño H0 v2

> Última actualización: 2026-04-28
> Estado: **APROBADO — H0 v2 + ajustes v2.1, autorizado H1**

---

## 0. Decisiones arquitecturales aprobadas

| Decisión | Resolución |
|---|---|
| **Sidekiq** | SÍ. Queues: `default`, `mailers`, `ambiente`, `notifications`. Sidekiq Web en `/sidekiq` con auth admin. `:async` solo en test, nunca en producción. |
| **AR::Encryption** | SÍ, obligatorio. `encrypts :metadata, deterministic: false` en `Dispositivo`. `webhook_token_digest` almacenado con BCrypt (no cifrado AR — el token es un secreto comparado por igualdad, no necesita determinismo). Ver `docs/SECURITY.md`. |
| **ActionCable + Redis** | SÍ. Dev: `adapter: async`. Producción: `adapter: redis, url: redis://localhost:6379/1` (DB 1, Sidekiq usa DB 0). `NotificationBell.vue` implementa polling fallback cada 30s si el cable no conecta en 5s. |
| **`registros_ambientales` legacy** | Mantener como diario de cultivo. `after_save` idempotente propaga métricas a `lecturas_ambientales`. |
| **Polimorfismo en lecturas** | Agregar `origen_record_type` + `origen_record_id` a `lecturas_ambientales` para trazar la fuente exacta. |

---

## 1. Auditoría del estado actual

### Qué existe hoy

| Artefacto | Descripción | Decisión |
|---|---|---|
| `registros_ambientales` (tabla) | Fat-row por lote. Métricas en columnas separadas + datos agronómicos (fertilizacion, plagas, notas_nutricion). Anclada a `lote_id`, no `sala_id`. | **Mantener**. Es un diario de cultivo. Convive con la nueva tabla. |
| `RegistroAmbiental` (model) | Valida rangos, calcula VPD en `before_save` con Tetens. Fuentes: manual, csv_bluelab, sensor_mqtt, asistente_voz. | **Mantener**. Agregar `after_save` idempotente que propaga métricas a `lecturas_ambientales`. |
| `RegistrosAmbientalesController` | `GET/POST/DELETE /lotes/:lote_id/registros_ambientales`. | **Mantener** sin cambios. La propagación ocurre en el modelo. |
| `GraficosLote.vue` | Gráfico SVG de series temporales. Lee de `/lotes/:id/registros_ambientales`. | **Migrar en H2** al nuevo endpoint `/salas/:id/ambiente`. |
| `AsistenteVoz.vue` | Crea `registro_ambiental` por voz. | **Sin tocar**. El `after_save` propaga. |
| `TareasDelLote.vue` | Crea `registro_ambiental` al completar tareas de medición. | **Sin tocar**. Idem. |

### Problema central del modelo legacy

`registros_ambientales` mezcla dos conceptos:
1. **Métricas puntuales** (temperatura, humedad, VPD, CO₂…) → van a `lecturas_ambientales`
2. **Notas agronómicas** (fertilizacion, plagas, notas_nutricion, observaciones) → se quedan en `registros_ambientales`

La nueva tabla `lecturas_ambientales` es un **log de alta frecuencia**: una fila = una métrica = un timestamp, diseñada para sensores a 30–300 segundos de intervalo.

---

## 2. Schema final (v2 con cambios aprobados)

### 2.1 `dispositivos`

```sql
CREATE TABLE dispositivos (
  id                    BIGSERIAL PRIMARY KEY,
  club_id               BIGINT NOT NULL REFERENCES clubs(id),
  sala_id               BIGINT NOT NULL REFERENCES salas(id),
  tipo                  VARCHAR NOT NULL,
  -- enum: pulse | bluelab | tuya_plug | shelly_plug | melcloud_ac | daikin | generic
  marca                 VARCHAR,
  modelo                VARCHAR,
  serial                VARCHAR,
  nombre_amigable       VARCHAR NOT NULL,
  estado                VARCHAR NOT NULL DEFAULT 'activo',
  -- enum: activo | mantenimiento | baja
  ultima_lectura_at     TIMESTAMPTZ,
  webhook_token_digest  VARCHAR,
  -- BCrypt digest del token de webhook. El plain-text se retorna UNA SOLA VEZ al crear/regenerar.
  last_token_rotated_at TIMESTAMPTZ,
  -- Timestamp de la última rotación de token. Frontend muestra warning
  -- "Token rotado hace X — esperando primer ping con nuevo token"
  -- mientras ultima_lectura_at IS NULL OR ultima_lectura_at < last_token_rotated_at
  metadata              JSONB NOT NULL DEFAULT '{}',
  -- Cifrado con AR::Encryption (deterministic: false).
  -- Guarda credenciales driver-específicas: Tuya access_key/secret, IDs externos, etc.
  -- Nunca se almacena en plain text en la DB.
  created_at            TIMESTAMPTZ NOT NULL,
  updated_at            TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_dispositivos_club ON dispositivos(club_id);
CREATE INDEX idx_dispositivos_sala ON dispositivos(sala_id);
CREATE UNIQUE INDEX idx_dispositivos_serial
  ON dispositivos(club_id, serial) WHERE serial IS NOT NULL;
```

**Ciclo de vida del webhook token**:
1. Admin crea dispositivo con `fuente: webhook`
2. Controller genera `token = SecureRandom.hex(32)`, guarda `BCrypt::Password.create(token)` en `webhook_token_digest`
3. Respuesta incluye el `token` plain-text **una sola vez** — no se vuelve a mostrar
4. `POST /dispositivos/:id/regenerar_token` genera un nuevo par si el token se compromete

**AR::Encryption setup** (ver `docs/SECURITY.md`):
```bash
rails db:encryption:init   # genera primary_key, deterministic_key, key_derivation_salt
rails credentials:edit     # pegar las claves bajo active_record_encryption:
```

### 2.2 `lecturas_ambientales` (v2 con campos polimórficos)

```sql
CREATE TABLE lecturas_ambientales (
  id                  BIGSERIAL PRIMARY KEY,
  club_id             BIGINT NOT NULL,
  -- desnormalizado para scoping rápido sin JOIN a salas
  sala_id             BIGINT NOT NULL REFERENCES salas(id),
  dispositivo_id      BIGINT REFERENCES dispositivos(id),
  -- nullable: NULL = entrada manual o backfill
  lote_id             BIGINT REFERENCES lotes(id),
  -- nullable: lote dominante en la sala al momento de la lectura
  tipo                VARCHAR NOT NULL,
  -- enum: ver sección 2.2.1
  valor               DECIMAL(10, 4) NOT NULL,
  unidad              VARCHAR(10) NOT NULL,
  medido_at           TIMESTAMPTZ NOT NULL,
  -- timestamp del sensor/origen, NO el timestamp de inserción
  fuente              VARCHAR NOT NULL DEFAULT 'manual',
  -- enum: manual | webhook | csv_import | backfill
  origen_record_type  VARCHAR,
  -- clase Rails del registro origen, ej: 'RegistroAmbiental', 'CsvImport'
  origen_record_id    BIGINT,
  -- ID del registro origen (polimórfico)
  created_at          TIMESTAMPTZ NOT NULL,
  updated_at          TIMESTAMPTZ NOT NULL
);

-- Índice de idempotencia (ÚNICO por dispositivo+tipo+timestamp)
CREATE UNIQUE INDEX idx_la_idempotencia
  ON lecturas_ambientales(dispositivo_id, tipo, medido_at)
  WHERE dispositivo_id IS NOT NULL;

-- Índices de query
CREATE INDEX idx_la_sala_tipo_medido
  ON lecturas_ambientales(sala_id, tipo, medido_at DESC);
CREATE INDEX idx_la_dispositivo_medido
  ON lecturas_ambientales(dispositivo_id, medido_at DESC)
  WHERE dispositivo_id IS NOT NULL;
CREATE INDEX idx_la_club_medido
  ON lecturas_ambientales(club_id, medido_at DESC);
CREATE INDEX idx_la_origen
  ON lecturas_ambientales(origen_record_type, origen_record_id)
  WHERE origen_record_id IS NOT NULL;
```

**Idempotencia en escritura** (comportamiento `after_save` del `RegistroAmbiental` y endpoint webhook):

```ruby
# En lugar de INSERT ciego:
LecturaAmbiental.find_or_initialize_by(
  dispositivo_id: dispositivo_id,   # nil para manuales
  sala_id:        sala_id,
  tipo:           tipo,
  medido_at:      medido_at
).tap do |l|
  l.assign_attributes(valor: valor, unidad: unidad, ...)
  l.save!
end
```

Para entradas manuales (dispositivo_id = nil) el índice UNIQUE no aplica. La idempotencia se logra por `origen_record_type + origen_record_id + tipo`: no se vuelve a crear si ya existe una lectura con ese origen.

**2.2.1 Enum `tipo`** (compartido entre `lecturas_ambientales`, `setpoints_fase`, `reglas_ambientales`)

```
temperatura | humedad | vpd | co2 | ppfd | lux |
ec | ph | ec_runoff | ph_runoff | temperatura_sustrato | humedad_sustrato |
flujo_aire | oxigeno_disuelto
```

**VPD calculado automáticamente**: cuando llegan `temperatura` y `humedad` del mismo dispositivo/sala en el mismo batch, el backend llama a `Ambiente::VpdCalculator.calculate(t, hr)` (extrae el Tetens de `RegistroAmbiental`) y persiste una fila adicional con `tipo: 'vpd'` y `fuente` igual a la del batch.

### 2.2.2 Constante canónica de tipos y unidades

```ruby
# app/models/concerns/ambiente_tipos.rb
module AmbienteTipos
  TIPOS_CANONICOS = {
    'temperatura'          => '°C',
    'humedad'              => '%',
    'vpd'                  => 'kPa',
    'co2'                  => 'ppm',
    'ph'                   => 'pH',
    'ec'                   => 'mS/cm',
    'ppfd'                 => 'µmol/m²s',
    'lux'                  => 'lux',
    'ec_runoff'            => 'mS/cm',
    'ph_runoff'            => 'pH',
    'temperatura_sustrato' => '°C',
    'humedad_sustrato'     => '%',
    'flujo_aire'           => 'm/s',
    'oxigeno_disuelto'     => 'mg/L',
  }.freeze

  TIPOS = TIPOS_CANONICOS.keys.freeze
end
```

Esta constante es la fuente única de verdad para tipos y unidades canónicas. Todos los modelos (`LecturaAmbiental`, `SetpointFase`, `ReglaAmbiental`) incluyen el concern e imponen validación:

```ruby
# En LecturaAmbiental y SetpointFase:
validates :tipo,   inclusion: { in: AmbienteTipos::TIPOS }
validate  :unidad_canonica

def unidad_canonica
  return if tipo.blank?
  expected = AmbienteTipos::TIPOS_CANONICOS[tipo]
  return unless expected
  if unidad != expected
    errors.add(:unidad, "para tipo '#{tipo}' debe ser '#{expected}', recibido '#{unidad}'")
  end
end
```

**Rechazo en webhook (422)**: si el driver envía `{ tipo: 'temperatura', valor: 24.5, unidad: 'F' }`, el controller retorna:
```json
{ "error": "Unidad inválida: para tipo 'temperatura' debe ser '°C', recibido 'F'" }
```

Los drivers deben convertir a unidades canónicas antes de enviar. El `Sensors::BaseDriver` expone un método `canonical_unit(tipo)` para esta conversión.

### 2.3 `setpoints_fase`

```sql
CREATE TABLE setpoints_fase (
  id            BIGSERIAL PRIMARY KEY,
  club_id       BIGINT NOT NULL,
  genetica_id   BIGINT REFERENCES geneticas(id),
  -- nullable: NULL = default para toda la fase; non-null = override por cepa
  fase          VARCHAR NOT NULL,
  -- enum: clon | madre | vegetativo | floracion | lavado | secado | curado
  tipo_lectura  VARCHAR NOT NULL,
  -- mismo enum que lecturas_ambientales.tipo
  valor_min     DECIMAL(10, 4),
  valor_max     DECIMAL(10, 4),
  valor_ideal   DECIMAL(10, 4),
  unidad        VARCHAR(10) NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL,
  updated_at    TIMESTAMPTZ NOT NULL
);
-- UNIQUE separados para manejar NULL correctamente en PostgreSQL
CREATE UNIQUE INDEX idx_setpoints_default
  ON setpoints_fase(club_id, fase, tipo_lectura)
  WHERE genetica_id IS NULL;
CREATE UNIQUE INDEX idx_setpoints_genetica
  ON setpoints_fase(club_id, genetica_id, fase, tipo_lectura)
  WHERE genetica_id IS NOT NULL;
CREATE INDEX idx_setpoints_club_fase ON setpoints_fase(club_id, fase);
```

**Lookup**: `SetpointFase.para(club_id:, genetica_id:, fase:, tipo:)` busca primero con genetica_id; si no encuentra, usa el default (genetica_id IS NULL). Si no hay default, retorna nil y el frontend no muestra banda de setpoint.

### 2.4 `reglas_ambientales`

```sql
CREATE TABLE reglas_ambientales (
  id                BIGSERIAL PRIMARY KEY,
  club_id           BIGINT NOT NULL,
  sala_id           BIGINT REFERENCES salas(id),
  -- nullable: NULL = aplica a TODAS las salas del club
  nombre            VARCHAR NOT NULL,
  descripcion       TEXT,
  tipo_lectura      VARCHAR NOT NULL,
  condicion         VARCHAR NOT NULL,
  -- enum: gt | lt | gte | lte | between | out_of_range
  umbral_a          DECIMAL(10, 4) NOT NULL,
  umbral_b          DECIMAL(10, 4),
  -- solo para: between (min, max), out_of_range (fuera de [a, b])
  duracion_minutos  INTEGER NOT NULL DEFAULT 5,
  -- la condición debe sostenerse N minutos antes de crear alerta
  accion            VARCHAR NOT NULL DEFAULT 'notificar',
  -- enum: notificar | crear_tarea | webhook | todas
  prioridad         VARCHAR NOT NULL DEFAULT 'media',
  -- enum: baja | media | alta | critica
  activa            BOOLEAN NOT NULL DEFAULT true,
  webhook_url       TEXT,
  created_at        TIMESTAMPTZ NOT NULL,
  updated_at        TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_reglas_club_activa ON reglas_ambientales(club_id, activa);
CREATE INDEX idx_reglas_sala
  ON reglas_ambientales(sala_id)
  WHERE sala_id IS NOT NULL;
```

**Evaluación de `duracion_minutos`**: el evaluador consulta las lecturas más recientes del período y verifica que la condición esté violada de forma sostenida. Solo dispara si no existe ya una alerta `activa` o `reconocida` para `(regla_id, sala_id)`.

### 2.5 `alertas`

```sql
CREATE TABLE alertas (
  id                      BIGSERIAL PRIMARY KEY,
  club_id                 BIGINT NOT NULL,
  regla_id                BIGINT NOT NULL REFERENCES reglas_ambientales(id),
  sala_id                 BIGINT NOT NULL REFERENCES salas(id),
  lectura_id              BIGINT REFERENCES lecturas_ambientales(id),
  estado                  VARCHAR NOT NULL DEFAULT 'activa',
  -- enum: activa | reconocida | resuelta
  mensaje                 TEXT NOT NULL,
  reconocida_at           TIMESTAMPTZ,
  reconocida_por_user_id  BIGINT REFERENCES users(id),
  resuelta_at             TIMESTAMPTZ,
  resuelta_por_user_id    BIGINT REFERENCES users(id),
  created_at              TIMESTAMPTZ NOT NULL,
  updated_at              TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_alertas_club_estado ON alertas(club_id, estado);
CREATE INDEX idx_alertas_sala_estado ON alertas(sala_id, estado);
CREATE INDEX idx_alertas_regla       ON alertas(regla_id);
```

### 2.6 `lecturas_ambientales_diarias` (tabla de retención)

```sql
CREATE TABLE lecturas_ambientales_diarias (
  id          BIGSERIAL PRIMARY KEY,
  club_id     BIGINT NOT NULL,
  sala_id     BIGINT NOT NULL REFERENCES salas(id),
  tipo        VARCHAR NOT NULL,
  fecha       DATE NOT NULL,
  valor_min   DECIMAL(10, 4) NOT NULL,
  valor_max   DECIMAL(10, 4) NOT NULL,
  valor_avg   DECIMAL(10, 4) NOT NULL,
  valor_p5    DECIMAL(10, 4),
  valor_p95   DECIMAL(10, 4),
  n_lecturas  INTEGER NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL
);
CREATE UNIQUE INDEX idx_lad_unique ON lecturas_ambientales_diarias(sala_id, tipo, fecha);
CREATE INDEX idx_lad_sala_fecha ON lecturas_ambientales_diarias(sala_id, fecha DESC);
CREATE INDEX idx_lad_club_fecha ON lecturas_ambientales_diarias(club_id, fecha DESC);
```

Ver sección 10 (Retención y volumen) para la política de retención y el job de agregación.

---

## 3. Lista de migraciones

```
20260429_000001_create_dispositivos.rb
20260429_000002_create_lecturas_ambientales.rb            # incluye origen polimórfico + idx idempotencia
20260429_000003_create_lecturas_ambientales_diarias.rb
20260429_000004_create_setpoints_fase.rb
20260429_000005_create_reglas_ambientales.rb
20260429_000006_create_alertas.rb
20260429_000007_backfill_lecturas_from_registros_ambientales.rb
```

### Migración de backfill (20260429_000007)

```ruby
METRIC_MAP = {
  temperatura:          ['temperatura',          '°C'],
  humedad:              ['humedad',              '%'],
  vpd:                  ['vpd',                  'kPa'],
  co2:                  ['co2',                  'ppm'],
  ph:                   ['ph',                   'pH'],
  ec:                   ['ec',                   'mS/cm'],
  temperatura_sustrato: ['temperatura_sustrato', '°C'],
  ph_runoff:            ['ph_runoff',            'pH'],
  ec_runoff:            ['ec_runoff',            'mS/cm'],
  ppfd:                 ['ppfd',                 'µmol/m²s'],
}.freeze

def up
  RegistroAmbiental.includes(:lote).find_each do |r|
    sala_id = r.lote.sala_id
    METRIC_MAP.each do |col, (tipo, unidad)|
      val = r.public_send(col)
      next if val.nil?
      # Idempotente: upsert por origen polimórfico
      execute <<~SQL
        INSERT INTO lecturas_ambientales
          (club_id, sala_id, lote_id, tipo, valor, unidad, medido_at, fuente,
           origen_record_type, origen_record_id, created_at, updated_at)
        VALUES
          (#{r.club_id}, #{sala_id}, #{r.lote_id}, '#{tipo}', #{val}, '#{unidad}',
           '#{r.registrado_en.utc.iso8601}', 'backfill',
           'RegistroAmbiental', #{r.id}, NOW(), NOW())
        ON CONFLICT DO NOTHING
      SQL
    end
  end
end

def down
  execute "DELETE FROM lecturas_ambientales WHERE fuente = 'backfill'"
end
```

**Nota**: el `ON CONFLICT DO NOTHING` funciona sobre el índice de origen polimórfico. Si se vuelve a correr, no duplica. La migración es segura de re-ejecutar.

---

## 4. Backend: Models, Services, Controllers, Jobs

### 4.1 Models nuevos

**`Dispositivo`**
```ruby
class Dispositivo < ApplicationRecord
  belongs_to :club
  belongs_to :sala

  encrypts :metadata, deterministic: false

  TIPOS   = %w[pulse bluelab tuya_plug shelly_plug melcloud_ac daikin generic].freeze
  ESTADOS = %w[activo mantenimiento baja].freeze

  validates :nombre_amigable, presence: true
  validates :tipo,   inclusion: { in: TIPOS }
  validates :estado, inclusion: { in: ESTADOS }

  # webhook_token_digest es BCrypt — no AR::Encryption
  def webhook_token_matches?(token)
    webhook_token_digest.present? &&
      BCrypt::Password.new(webhook_token_digest) == token
  end

  def regenerar_token!
    plain = SecureRandom.hex(32)
    update!(
      webhook_token_digest:  BCrypt::Password.create(plain),
      last_token_rotated_at: Time.current
    )
    plain  # retornar plain-text UNA SOLA VEZ
  end

  # true mientras el sensor no haya enviado un ping con el nuevo token
  def token_pendiente_confirmacion?
    last_token_rotated_at.present? &&
      (ultima_lectura_at.nil? || ultima_lectura_at < last_token_rotated_at)
  end
end
```

**`LecturaAmbiental`**
```ruby
class LecturaAmbiental < ApplicationRecord
  belongs_to :sala
  belongs_to :dispositivo, optional: true
  belongs_to :lote,        optional: true

  TIPOS   = %w[temperatura humedad vpd co2 ppfd lux ec ph ec_runoff ph_runoff
               temperatura_sustrato humedad_sustrato flujo_aire oxigeno_disuelto].freeze
  FUENTES = %w[manual webhook csv_import backfill].freeze

  validates :tipo,      inclusion: { in: TIPOS }
  validates :fuente,    inclusion: { in: FUENTES }
  validates :valor,     presence: true
  validates :medido_at, presence: true

  scope :recientes,          -> { order(medido_at: :desc) }
  scope :del_tipo,           ->(t) { where(tipo: t) }
  scope :de_sala,            ->(id) { where(sala_id: id) }
  scope :en_rango,           ->(desde, hasta) { where(medido_at: desde..hasta) }
  scope :ultimas_n_minutos,  ->(n) { where('medido_at >= ?', n.minutes.ago) }
  scope :para_timeseries,    ->(sala_id, tipo, desde, hasta) {
    de_sala(sala_id).del_tipo(tipo).en_rango(desde, hasta).recientes
  }
end
```

**`RegistroAmbiental`** (modificación mínima al existente):
```ruby
# Agregar al modelo existente:
after_save :propagar_a_lecturas_ambientales

private

METRIC_PROPAGATION_MAP = {
  temperatura: '°C', humedad: '%', vpd: 'kPa', co2: 'ppm',
  ph: 'pH', ec: 'mS/cm', temperatura_sustrato: '°C',
  ph_runoff: 'pH', ec_runoff: 'mS/cm', ppfd: 'µmol/m²s'
}.freeze

def propagar_a_lecturas_ambientales
  sala_id = lote.sala_id
  METRIC_PROPAGATION_MAP.each do |col, unidad|
    val = public_send(col)
    next if val.nil?
    # Idempotente: find_or_initialize_by origen polimórfico + tipo
    lectura = LecturaAmbiental.find_or_initialize_by(
      origen_record_type: 'RegistroAmbiental',
      origen_record_id:   id,
      tipo:               col.to_s
    )
    lectura.assign_attributes(
      club_id:   club_id,
      sala_id:   sala_id,
      lote_id:   lote_id,
      valor:     val,
      unidad:    unidad,
      medido_at: registrado_en,
      fuente:    'manual'
    )
    lectura.save!
  end
end
```

**`ReglaAmbiental`**
```ruby
class ReglaAmbiental < ApplicationRecord
  belongs_to :club
  belongs_to :sala, optional: true

  CONDICIONES = %w[gt lt gte lte between out_of_range].freeze
  ACCIONES    = %w[notificar crear_tarea webhook todas].freeze
  PRIORIDADES = %w[baja media alta critica].freeze

  def viola?(valor)
    v = valor.to_f
    case condicion
    when 'gt'            then v >  umbral_a
    when 'lt'            then v <  umbral_a
    when 'gte'           then v >= umbral_a
    when 'lte'           then v <= umbral_a
    when 'between'       then v >= umbral_a && v <= umbral_b
    when 'out_of_range'  then v <  umbral_a || v >  umbral_b
    else false
    end
  end

  scope :activas_para_sala, ->(sala_id) {
    where(activa: true)
      .where('sala_id = ? OR sala_id IS NULL', sala_id)
  }
end
```

### 4.2 Services nuevos

```
app/services/ambiente/vpd_calculator.rb
app/services/ambiente/evaluador_reglas.rb
app/services/ambiente/alerta_creator.rb
app/services/sensors/base_driver.rb
app/services/sensors/manual_csv_driver.rb   # H1
app/services/sensors/tuya_driver.rb         # H3
```

**`Ambiente::VpdCalculator`** (extrae la lógica de `RegistroAmbiental#calcular_vpd`):
```ruby
module Ambiente
  class VpdCalculator
    # Ecuación de Tetens — misma implementación que RegistroAmbiental
    def self.calculate(temperatura, humedad)
      t   = temperatura.to_f
      hr  = humedad.to_f
      svp = 0.6108 * Math.exp(17.27 * t / (t + 237.3))
      (svp * (1 - hr / 100.0)).round(3)
    end
  end
end
```

**`Ambiente::EvaluadorReglas.call(sala_id:, tipos:)`**:
1. Carga reglas activas para la sala + tipos recibidos
2. Para cada regla:
   a. Consulta lecturas filtrando **`.where.not(fuente: 'backfill').where('medido_at >= ?', regla.duracion_minutos.minutes.ago)`**
      — Motivo: excluir datos históricos de backfill/CSV import. Solo lecturas recientes de fuentes reales (manual, webhook, api) pueden disparar alertas. Esto previene tormentas de alertas al importar datos históricos.
   b. Si **todas** las lecturas del período violan la condición:
      - Busca si ya hay alerta `activa` o `reconocida` para `(regla_id, sala_id)`
      - Si no hay → `Ambiente::AlertaCreator.call(regla, sala_id, ultima_lectura)`
   c. Si **ninguna** viola Y hay alerta activa → auto-resolver (`Alerta#resolver_automatico!`)

**`Ambiente::AlertaCreator.call(regla, sala_id, lectura)`**:
1. `Alerta.create!(...)` con mensaje descriptivo
2. Si `accion in ['crear_tarea', 'todas']` → `Tarea.create!` vinculada a sala, prioridad de regla
3. Si `accion in ['webhook', 'todas']` && `regla.webhook_url.present?` → `WebhookJob.perform_later`
4. `ActionCable.server.broadcast("alertas_club_#{club_id}", { alerta: serialize(alerta) })`
5. `Notification::BellJob.perform_later(club_id)` → actualiza contador en `NotificationsChannel`

### 4.3 Jobs y Sidekiq

**Configuración Sidekiq**:
```ruby
# config/sidekiq.yml
:queues:
  - [default, 5]
  - [mailers, 3]
  - [ambiente, 2]
  - [notifications, 2]

# config/initializers/sidekiq.rb
Sidekiq.configure_server { |c| c.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') } }
Sidekiq.configure_client { |c| c.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') } }

# config/environments/production.rb
config.active_job.queue_adapter = :sidekiq

# config/environments/development.rb
config.active_job.queue_adapter = :sidekiq  # mismo en dev para paridad
# (test usa :test)
```

**Sidekiq Web** (solo admin):
```ruby
# config/routes.rb
require 'sidekiq/web'
authenticate :user, ->(u) { u.role == 'admin' || u.role == 'super_admin' } do
  mount Sidekiq::Web => '/sidekiq'
end
```

> **Nota de sesión y CSRF**: Sidekiq Web es una aplicación Rack que usa su propia sesión. El mount debe ser accesible por el mismo dominio que la app principal para que la cookie de sesión Rails sea válida. Si en producción se sirve en un subdominio separado (ej. `sidekiq.app.clubcultivo.ar`), configurar `config.session_store :cookie_store, key: '_club_session', domain: :all` en `config/initializers/session_store.rb`. La protección CSRF de Rails aplica al mount; no deshabilitar. Si Devise + JWT no comparte sesión con Sidekiq Web, usar HTTP Basic Auth como alternativa:
> ```ruby
> Sidekiq::Web.use(Rack::Auth::Basic) { |u, p| u == 'admin' && p == ENV['SIDEKIQ_PASSWORD'] }
> mount Sidekiq::Web => '/sidekiq'
> ```

**docker-compose**: agregar servicio `sidekiq`:
```yaml
sidekiq:
  build: ./backend
  command: bundle exec sidekiq -q ambiente -q notifications -q default -q mailers
  environment:
    - REDIS_URL=redis://redis:6379/0
    - DATABASE_URL=...
  depends_on: [db, redis]
```

**Jobs nuevos**:
```
app/jobs/evaluar_reglas_job.rb    # cola: ambiente
app/jobs/webhook_job.rb           # cola: default
app/jobs/agregar_lecturas_job.rb  # cola: ambiente, semanal (retención)
app/jobs/csv_import_job.rb        # cola: default
```

### 4.4 Controllers

```
app/controllers/dispositivos_controller.rb
app/controllers/lecturas_ambientales_controller.rb
app/controllers/setpoints_fase_controller.rb
app/controllers/reglas_ambientales_controller.rb
app/controllers/alertas_controller.rb
app/controllers/webhooks/lecturas_controller.rb
app/controllers/lecturas_ambientales/imports_controller.rb
```

**Endpoints completos**:

```
# Dispositivos (admin only)
GET    /dispositivos
POST   /dispositivos                   # retorna webhook_token plain-text si tipo lo requiere
GET    /dispositivos/:id
PATCH  /dispositivos/:id
DELETE /dispositivos/:id
POST   /dispositivos/:id/regenerar_token

# Lecturas — timeseries y entrada manual
GET  /salas/:id/ambiente?desde=&hasta=&tipo[]=&bucket=raw|daily
POST /salas/:id/lecturas              # entrada manual (cultivador+)

# Webhook — autenticado por token BCrypt, no por sesión
POST /webhooks/lecturas/:dispositivo_id

# Setpoints
GET    /setpoints_fase?fase=&genetica_id=
POST   /setpoints_fase
PATCH  /setpoints_fase/:id
DELETE /setpoints_fase/:id

# Reglas (admin only)
GET    /reglas_ambientales?sala_id=
POST   /reglas_ambientales
PATCH  /reglas_ambientales/:id
DELETE /reglas_ambientales/:id

# Alertas
GET  /alertas?estado=activa&sala_id=&since=    # since= para polling fallback
GET  /salas/:id/alertas?estado=activa
POST /alertas/:id/reconocer
POST /alertas/:id/resolver

# CSV Import
POST /lecturas_ambientales/import/preview   # dry-run: valida y retorna resumen
POST /lecturas_ambientales/import           # importación real (lanza job)
GET  /lecturas_ambientales/import/:job_id   # progreso del job
```

### 4.5 ActionCable Channels

```
app/channels/alertas_channel.rb          # stream: alertas_club_<club_id>
app/channels/sala_ambiente_channel.rb    # stream: sala_ambiente_<sala_id>
app/channels/notifications_channel.rb   # stream: notifications_user_<user_id>
```

`SalaAmbienteChannel` — broadcast desde `Webhooks::LecturasController` inmediatamente tras el insert, antes de encolar el job de evaluación (latencia ~ms para el gráfico en tiempo real).

---

## 5. Frontend: Vistas y composables

### 5.1 Vistas nuevas

| Ruta | Componente | Roles |
|---|---|---|
| `/salas/:id/ambiente` | `SalaAmbienteView.vue` | cultivador, admin |
| `/dispositivos` | `DispositivosView.vue` | admin |
| `/reglas-ambientales` | `ReglasAmbientalesView.vue` | admin |

### 5.2 Componentes nuevos

```
src/components/ambiente/
  AmbienteChart.vue         # timeseries 24h/7d/30d, reutiliza Chart.js
  SemaforoAmbiente.vue      # 4 pills verde/amarillo/rojo (temp/HR/VPD/CO₂)
  DispositivoCard.vue       # estado, último ping, latencia calculada
  AlertaBadge.vue           # chip prioridad+estado
  LecturaManualForm.vue     # form compacto para entrada manual por sala
  CsvImportFlow.vue         # wizard: upload → preview → confirm → progress
src/components/ui/
  NotificationBell.vue      # bell + contador + dropdown últimas 10 alertas
```

### 5.3 Composables y stores nuevos

```
src/stores/ambiente.js          # state: lecturas[], alertas[], dispositivos[]
src/composables/useAmbiente.js  # ActionCable + polling fallback
src/composables/useSetpoints.js # lookup setpoint para tipo+fase+genetica
src/composables/useAlertasBell.js  # contador global, compartido con NotificationBell
```

### 5.4 Modificaciones a existentes

| Archivo | Cambio |
|---|---|
| `App.vue` | `<NotificationBell>` en navbar; montar `AlertasChannel` en `onMounted` |
| `SalaDetailView.vue` | Mini-widget ambiente: últimas lecturas de temp/HR/VPD/CO₂ |
| `LoteDetailView.vue` | `GraficosLote` recibe datos del nuevo store (no fetch propio) |
| `GraficosLote.vue` | Aceptar prop `datos` — ya lo hace parcialmente |
| `src/router/index.js` | 3 rutas nuevas |
| `src/lib/api.js` | Funciones para todos los endpoints nuevos |
| `src/composables/usePermissions.js` | Extender con recursos: dispositivos, lecturas, reglas, alertas |

### 5.5 Layout SalaAmbienteView (mobile-first)

```
┌─────────────────────────────────────────┐
│ < Sede / Sala / Ambiente                │  breadcrumb
├─────────────────────────────────────────┤
│  🌡 23.4°C OK  💧 58% OK              │
│  💨 0.82kPa OK  ☁️ 1240ppm WARN        │  semáforo 2×2 en mobile, 1×4 en desktop
├─────────────────────────────────────────┤
│  [Temp] [HR] [VPD] [CO₂] [pH] [EC]    │  tab selector
│  ┌──────────────────────────────────┐  │
│  │         chart 24h                │  │  Chart.js línea
│  └──────────────────────────────────┘  │
├─────────────────────────────────────────┤
│  ⚡ Alertas activas (2)               │  collapsible
│    • Temperatura alta — hace 14 min   │
├─────────────────────────────────────────┤
│  📡 Dispositivos (3)                  │  collapsible
│    • Sensor-01  último ping: 2 min    │
├─────────────────────────────────────────┤
│  [+ Lectura manual]                    │  botón sticky bottom en mobile
└─────────────────────────────────────────┘
```

---

## 6. Matriz de permisos detallada

| Recurso / acción | admin | cultivador | manicurador | dispensador | medico | socio |
|---|---|---|---|---|---|---|
| `dispositivos.*` | CRUD | — | — | — | — | — |
| `reglas_ambientales.*` | CRUD | — | — | — | — | — |
| `setpoints_fase.*` | CRUD | read | — | — | — | — |
| `lecturas_ambientales.read` | ✓ | ✓ (sus salas) | ✓ (limitado) | — | — | — |
| `lecturas_ambientales.create` (manual) | ✓ | ✓ | — | — | — | — |
| `lecturas_ambientales.import` (CSV) | ✓ | ✓ | — | — | — | — |
| `alertas.read` | ✓ | ✓ (sus salas) | — | — | — | — |
| `alertas.reconocer` | ✓ | ✓ (sus salas) | — | — | — | — |
| `alertas.resolver` | ✓ | ✓ (sus salas) | — | — | — | — |
| `/webhooks/lecturas/:id` | — | — | — | — | — | — (token propio) |

**"Sus salas"**: cultivador solo accede a lecturas y alertas de las salas donde está asignado en `sala_cultivadores`. La restricción se aplica en el controller:

```ruby
# LecturasAmbientalesController
def salas_permitidas
  if current_user.admin?
    current_user.club.salas
  else
    current_user.salas  # via sala_cultivadores
  end
end
```

**Médico no accede a lecturas**: el médico tiene acceso solo a socios e indicaciones médicas. El perfil ambiental del cultivo es información operativa del club, no clínica. Confirmado en la especificación.

**Tests de permisos negativos requeridos por controller** (H1):

```
DispositivosController:
  cultivador → GET /dispositivos → 403
  cultivador → POST /dispositivos → 403

LecturasAmbientalesController:
  medico → GET /salas/:id/ambiente → 403
  dispensador → GET /salas/:id/ambiente → 403
  cultivador → sala no asignada → 403

ReglasAmbientalesController:
  cultivador → POST /reglas_ambientales → 403

AlertasController:
  cultivador → alerta de sala no asignada → 403
```

---

## 7. Plan de migración de datos legacy

```
Fase 1 (H1):
  ✓ Crear 7 tablas nuevas
  ✓ Correr backfill: registros_ambientales → lecturas_ambientales (fuente=backfill)
  ✓ Agregar after_save idempotente a RegistroAmbiental
  ✓ Verificar paridad de datos

Fase 2 (H2):
  ✓ GraficosLote.vue usa nuevo endpoint /salas/:id/ambiente
  ✓ Validar parity visual del gráfico

Fase 3 (post-estabilización):
  ✓ Documentar /lotes/:id/registros_ambientales como legacy en docs internos
  ✗ NO eliminar la tabla registros_ambientales
  ✗ NO romper el endpoint legacy (backward compat permanente)
```

---

## 8. Flujo completo: Sensor → Notificación

```
Sensor / Driver externo
     │
     ▼ HTTP POST /webhooks/lecturas/:dispositivo_id
     │   Header: Authorization: Bearer <token>
     │   Body: [{ tipo, valor, unidad, medido_at }] o formato driver-específico
     │
     ┌─[ Webhooks::LecturasController ]──────────────────────────────┐
     │  1. Rack::Attack: rate limit 1 req/s por dispositivo_id       │
     │  2. Autenticar: BCrypt.checkpw(token, dispositivo.digest)      │
     │  3. Validar medido_at: no futura, no >7 días de antigüedad    │
     │  4. Parser del driver (BaseDriver subclass)                    │
     │  5. Upsert lecturas_ambientales[] (idx idempotencia)           │
     │  6. Si temp+HR presentes: calcular VPD y upsert               │
     │  7. UPDATE dispositivos.ultima_lectura_at                      │
     │  8. ActionCable.broadcast("sala_ambiente_#{sala_id}", datos)   │  ← tiempo real inmediato
     │  9. EvaluarReglasJob.perform_later(sala_id, tipos)             │  ← evaluación async
     └───────────────────────────────────────────────────────────────┘
          │
          ├─▶ SalaAmbienteChannel → AmbienteChart.vue actualiza en tiempo real
          │
          ▼ Sidekiq cola :ambiente
     ┌─[ EvaluarReglasJob ]──────────────────────────────────────────┐
     │  Para cada regla activa de sala+tipos:                         │
     │    1. Lecturas últimos duracion_minutos                        │
     │    2. ¿Todas violan condición?                                 │
     │       SÍ + sin alerta activa → AlertaCreator.call             │
     │         → Alerta.create!                                       │
     │         → Tarea.create! (si accion=crear_tarea|todas)         │
     │         → WebhookJob.perform_later (si accion=webhook|todas)  │
     │         → ActionCable broadcast "alertas_club_#{club_id}"     │
     │         → NotificationBell.vue: contador++                    │
     │       NO  + hay alerta activa → alerta.resolver_automatico!   │
     └───────────────────────────────────────────────────────────────┘
```

---

## 9. Rate limit, auth y validaciones del webhook

### Auth por token BCrypt

```ruby
# app/controllers/webhooks/lecturas_controller.rb
class Webhooks::LecturasController < ActionController::API
  before_action :autenticar_dispositivo!

  private

  def autenticar_dispositivo!
    token = request.headers['Authorization']&.sub(/\ABearer /, '')
    @dispositivo = Dispositivo.find_by(id: params[:dispositivo_id])
    unless @dispositivo&.webhook_token_matches?(token)
      render json: { error: 'No autorizado' }, status: :unauthorized and return
    end
    unless @dispositivo.activo?
      render json: { error: 'Dispositivo inactivo' }, status: :forbidden
    end
  end
end
```

### Rack::Attack

```ruby
# config/initializers/rack_attack.rb

# Rate limit: 1 request/segundo por dispositivo en el endpoint webhook
Rack::Attack.throttle('webhooks/lecturas', limit: 1, period: 1) do |req|
  if req.path.start_with?('/webhooks/lecturas/')
    req.path.split('/').last  # dispositivo_id como discriminador
  end
end

# Límite más permisivo para batch (un dispositivo puede enviar N métricas en 1 request)
# → el endpoint acepta arrays, no un request por métrica

Rack::Attack.throttled_responder = lambda do |req|
  [429, { 'Content-Type' => 'application/json' },
   ['{"error":"Rate limit excedido. Máximo 1 request/segundo por dispositivo."}']]
end
```

### Validaciones de `medido_at`

```ruby
validates :medido_at, presence: true
validate  :medido_at_en_rango_valido

def medido_at_en_rango_valido
  return if medido_at.nil?
  if medido_at > Time.current + 5.minutes
    errors.add(:medido_at, 'no puede ser una fecha futura')
  elsif medido_at < 7.days.ago
    errors.add(:medido_at, 'no puede tener más de 7 días de antigüedad')
  end
end
```

### Idempotencia del endpoint webhook

El índice `UNIQUE (dispositivo_id, tipo, medido_at)` garantiza que re-envíos del mismo dato no generan duplicados. El controller usa `INSERT ... ON CONFLICT DO UPDATE SET updated_at = NOW()` (upsert) para retornar 200 en lugar de 409 en re-envíos, lo que simplifica la lógica del cliente.

---

## 10. Retención y volumen de datos

### Cálculo de volumen

| Escenario | Frecuencia | Salas | Tipos | Filas/día | Filas/año |
|---|---|---|---|---|---|
| MVP (club pequeño) | 1/min | 3 | 5 | 21.600 | 7.9M |
| Club mediano | 1/min | 6 | 5 | 43.200 | 15.8M |
| Sensor IoT frecuente | 1/30s | 6 | 8 | 138.240 | 50.5M |
| Plataforma (50 clubes medianos) | 1/min | 300 | 5 | 2.160.000 | 788M |

Sin retención activa, la tabla crece sin límite. **Política: 90 días de datos crudos**.

### Tabla de agregados diarios

`lecturas_ambientales_diarias` (ver sección 2.6) almacena min/max/avg/p5/p95 por día. Sirve para:
- Gráficos históricos > 90 días (con menor resolución temporal — adecuado para esa escala)
- Reportes de tendencias por cepa/sala
- Análisis sin impacto en la tabla principal

### Job de retención y agregación semanal

```ruby
# app/jobs/agregar_lecturas_job.rb
class AgregarLecturasJob < ApplicationJob
  queue_as :ambiente

  def perform
    fecha_corte = 90.days.ago.to_date

    # 1. Agregar por día los datos antes de la fecha de corte (aún no agregados)
    LecturaAmbiental
      .where('DATE(medido_at) < ?', fecha_corte)
      .group(:sala_id, :club_id, :tipo)
      .select('sala_id, club_id, tipo, DATE(medido_at) AS fecha,
               MIN(valor) AS vmin, MAX(valor) AS vmax, AVG(valor) AS vavg,
               PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY valor) AS vp5,
               PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY valor) AS vp95,
               COUNT(*) AS n')
      .each do |row|
        LecturaAmbiental::Diaria.find_or_create_by(
          sala_id: row.sala_id, tipo: row.tipo, fecha: row.fecha
        ) do |d|
          d.assign_attributes(club_id: row.club_id, valor_min: row.vmin,
            valor_max: row.vmax, valor_avg: row.vavg,
            valor_p5: row.vp5, valor_p95: row.vp95, n_lecturas: row.n)
        end
      end

    # 2. Borrar datos crudos ya agregados (> 90 días)
    LecturaAmbiental
      .where('medido_at < ?', fecha_corte.beginning_of_day)
      .delete_all
  end
end
```

**Cron** (Sidekiq-cron o rake task semanal):
```ruby
# config/initializers/sidekiq_cron.rb (si se agrega sidekiq-cron)
Sidekiq::Cron::Job.create(
  name:  'Agregar lecturas ambientales',
  cron:  '0 3 * * 0',  # domingo 3 AM UTC
  class: 'AgregarLecturasJob'
)
```

Sin sidekiq-cron: rake task + cron de sistema en el host de producción:
```bash
# crontab
0 3 * * 0 cd /app && bundle exec rails ambiente:agregar_lecturas
```

**API con `bucket` param**: `GET /salas/:id/ambiente?bucket=raw` (últimos 90 días, alta resolución) vs `bucket=daily` (histórico, datos agregados). El frontend selecciona automáticamente según el rango pedido.

---

## 11. Timezone

### Regla universal

**Todos los `medido_at` se almacenan en UTC** (`TIMESTAMPTZ` en PostgreSQL). El backend nunca convierte al timezone del club al guardar.

**Frontend convierte** al timezone del club para mostrar. El club tiene `timezone` en la tabla `clubs` (ya existe el campo). Ejemplo: `'America/Argentina/Buenos_Aires'`.

```javascript
// src/utils/dates.js — agregar función
export function toClubTz(isoString, clubTimezone) {
  return new Date(isoString).toLocaleString('es-AR', {
    timeZone: clubTimezone || 'America/Argentina/Buenos_Aires'
  })
}
```

**Eje X del gráfico (`AmbienteChart.vue`)**: los timestamps del eje X se convierten con `toClubTz` antes de renderizar. El chart recibe timestamps UTC del backend y los convierte en el cliente.

**`NotificationBell.vue`**: los timestamps de alertas en el dropdown se muestran con `toClubTz`. Nunca UTC raw.

**Endpoint `GET /alertas?since=`** (polling fallback): el parámetro `since` debe enviarse en ISO 8601 UTC. El backend interpreta como UTC sin conversión.

```javascript
// useAlertasBell.js — polling fallback
const lastCheck = ref(new Date().toISOString())  // siempre UTC
// GET /alertas?estado=activa&since=<lastCheck>
```

**`medido_at` en webhook**: el driver externo debe enviar en ISO 8601 con timezone explícito (`2026-04-28T15:30:00-03:00` o `2026-04-28T18:30:00Z`). El backend lo parsea con `Time.parse(params[:medido_at]).utc`.

---

## 12. Tiempo real en SalaAmbienteView

### Estrategia dual: cable + polling fallback

```javascript
// src/composables/useAmbiente.js
export function useAmbiente(salaId) {
  const lecturas  = ref([])
  const connected = ref(false)
  let   cable     = null
  let   pollTimer = null

  async function cargarInicial() {
    const desde = new Date(Date.now() - 24 * 3600 * 1000).toISOString()
    const { data } = await api.get(`/salas/${salaId}/ambiente`, {
      params: { desde, bucket: 'raw' }
    })
    lecturas.value = data
  }

  function iniciarCable() {
    cable = createConsumer('/cable')
    const timeout = setTimeout(() => {
      if (!connected.value) iniciarPolling()  // fallback si no conecta en 5s
    }, 5000)

    cable.subscriptions.create(
      { channel: 'SalaAmbienteChannel', sala_id: salaId },
      {
        connected() {
          connected.value = true
          clearTimeout(timeout)
          detenerPolling()
        },
        disconnected() {
          connected.value = false
          iniciarPolling()
        },
        received(data) {
          // Agregar nueva lectura al array (o actualizar si ya existe)
          const idx = lecturas.value.findIndex(
            l => l.tipo === data.tipo && l.medido_at === data.medido_at
          )
          if (idx >= 0) lecturas.value[idx] = data
          else lecturas.value.push(data)
        }
      }
    )
  }

  function iniciarPolling() {
    if (pollTimer) return
    pollTimer = setInterval(async () => {
      if (document.hidden) return  // pausar si tab está en segundo plano
      const since = lecturas.value.at(-1)?.medido_at ?? new Date(0).toISOString()
      const { data } = await api.get(`/salas/${salaId}/ambiente`, {
        params: { desde: since, bucket: 'raw' }
      })
      // merge incremental
      data.forEach(l => {
        if (!lecturas.value.find(x => x.id === l.id)) lecturas.value.push(l)
      })
    }, 30_000)
  }

  function detenerPolling() {
    clearInterval(pollTimer)
    pollTimer = null
  }

  // Pausar cable cuando el tab está oculto (ahorro batería en mobile)
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) cable?.disconnect()
    else { cable?.connect(); if (!connected.value) iniciarPolling() }
  })

  onMounted(async () => {
    await cargarInicial()
    iniciarCable()
  })

  onUnmounted(() => {
    cable?.disconnect()
    detenerPolling()
  })

  return { lecturas, connected }
}
```

### NotificationBell — polling fallback

```javascript
// src/composables/useAlertasBell.js
export function useAlertasBell() {
  const alertas   = ref([])
  const count     = computed(() => alertas.value.filter(a => a.estado === 'activa').length)
  const lastCheck = ref(new Date().toISOString())
  let   cable     = null
  let   pollTimer = null

  async function cargarRecientes() {
    const { data } = await api.get('/alertas', {
      params: { estado: 'activa', limit: 10 }
    })
    alertas.value = data
  }

  function iniciarCable() {
    cable = createConsumer('/cable')
    const timeout = setTimeout(() => iniciarPolling(), 5000)

    cable.subscriptions.create(
      { channel: 'AlertasChannel' },
      {
        connected()  { clearTimeout(timeout); detenerPolling() },
        disconnected() { iniciarPolling() },
        received(data) {
          alertas.value.unshift(data.alerta)
          if (alertas.value.length > 10) alertas.value.pop()
        }
      }
    )
  }

  function iniciarPolling() {
    if (pollTimer) return
    pollTimer = setInterval(async () => {
      if (document.hidden) return
      const { data } = await api.get('/alertas', {
        params: { estado: 'activa', since: lastCheck.value, limit: 10 }
      })
      lastCheck.value = new Date().toISOString()
      data.forEach(a => {
        if (!alertas.value.find(x => x.id === a.id)) alertas.value.unshift(a)
      })
    }, 30_000)
  }

  function detenerPolling() { clearInterval(pollTimer); pollTimer = null }

  onMounted(async () => { await cargarRecientes(); iniciarCable() })
  onUnmounted(() => { cable?.disconnect(); detenerPolling() })

  return { alertas, count }
}
```

---

## 13. CSV Import flow

### Formato del archivo

```csv
medido_at,tipo,valor,unidad,dispositivo_serial
2026-04-28T10:00:00-03:00,temperatura,24.5,°C,SENSOR-001
2026-04-28T10:00:00-03:00,humedad,62.3,%,SENSOR-001
2026-04-28T10:05:00-03:00,temperatura,24.8,°C,SENSOR-001
```

Reglas:
- `medido_at`: ISO 8601 con timezone (obligatorio)
- `tipo`: uno de los valores del enum de tipos (obligatorio)
- `valor`: número decimal (obligatorio)
- `unidad`: string (obligatorio)
- `dispositivo_serial`: serial del dispositivo para asociar (opcional — si está presente, se busca el dispositivo en el club; si no se encuentra, la fila se ignora con advertencia)
- Máximo 50.000 filas por import
- Encoding: UTF-8

### Flow en 3 pasos

```
1. POST /lecturas_ambientales/import/preview
   Body: { sala_id, file: <CSV> }
   Response: {
     total_filas: 1200,
     filas_validas: 1195,
     filas_invalidas: 5,
     rango: { desde: "2026-04-01", hasta: "2026-04-28" },
     tipos_detectados: ["temperatura", "humedad", "co2"],
     dispositivos_encontrados: ["SENSOR-001"],
     errores_muestra: [
       { fila: 34, error: "medido_at inválido: '2026-04-28'" },
       { fila: 201, error: "tipo desconocido: 'temp'" }
     ]
   }

2. POST /lecturas_ambientales/import
   Body: { sala_id, file: <CSV>, confirmar: true }
   Response: { job_id: "abc123", status: "enqueued" }
   → Lanza CsvImportJob en background

3. GET /lecturas_ambientales/import/:job_id
   Response: {
     status: "running|completed|failed",
     progreso: 45,        # porcentaje
     importadas: 540,
     ignoradas: 2,
     errores: []
   }
```

**`CsvImportJob`**:
- Lee el CSV fila a fila (streaming, sin cargar todo en memoria)
- Upsert en batches de 500 usando `INSERT ... ON CONFLICT DO NOTHING`
- Actualiza progreso en Redis (lectura por el endpoint de status)
- Al terminar, lanza `EvaluarReglasJob` para las salas afectadas

**`Sensors::ManualCsvDriver`** encapsula el parsing y validación del CSV, separando la lógica de I/O del job.

---

## 14. Seguridad — resumen ejecutivo

Ver `docs/SECURITY.md` para el documento completo. Puntos clave para este módulo:

- **`dispositivos.metadata`**: cifrado con `ActiveRecord::Encryption`, `deterministic: false`. Las claves viven en `credentials.yml.enc`, nunca en el código ni en variables de entorno planas.
- **`webhook_token_digest`**: BCrypt (no AR::Encryption). El token plain-text solo se transmite una vez, al crear o regenerar. El endpoint `/webhooks/*` no hereda de `ApplicationController` — no tiene sesión, solo token.
- **Rate limit**: Rack::Attack limita el endpoint webhook a 1 req/s por dispositivo.
- **Rotación de claves AR::Encryption**: documentada en `docs/SECURITY.md` — proceso de re-encrypt de todos los registros antes de retirar la clave vieja.

---

## 15. Dependencias externas / gems nuevas

| Gem | Versión | Motivo | ¿Ya en Gemfile? |
|---|---|---|---|
| `sidekiq` | ~> 7.0 | Background jobs persistentes | NO — agregar |
| `sidekiq-cron` | ~> 1.9 | Job semanal de retención | NO — agregar (opcional, alternativa: rake+cron) |
| `rack-attack` | ~> 6.7 | Rate limiting webhook | NO — agregar |
| `bcrypt` | — | Digest webhook_token | Sí (Devise lo usa) |
| `csv` | stdlib | Parsear CSV import | Stdlib Ruby, no gem |
| `ActiveRecord::Encryption` | built-in | Cifrar metadata | Built-in Rails 7.2 |

**No necesita**: `attr_encrypted` (obsoleto), `redis-rb` standalone (Rails 7.2 lo maneja), `jwt` (Devise ya implementado).

---

## 16. Qué NO hace este bloque

- **ProductPass / QR dossier** → Bloque I
- **IA diagnóstico por foto** → Bloque J
- **Crop steering EC/WC sustrato avanzado** → Bloque K
- **Tuya driver completo** → H3 (H1 entrega CSV + manual)
- **Particionamiento de tabla por mes** → cuando el volumen lo justifique (> 100M filas)
- **App móvil nativa / push notifications (FCM/APNs)** → Backlog
- **Multi-sensor por sala con fusión de datos** → Backlog (hoy: último valor por tipo)

---

*Esperando OK explícito para arrancar H1.*
