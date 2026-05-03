# Security — Club Cultivo

> Audiencia: desarrolladores y DevOps. No publicar externamente.

---

## 1. Gestión de claves AR::Encryption

### Setup inicial

```bash
# Generar las 3 claves necesarias (ejecutar UNA VEZ por entorno)
rails db:encryption:init

# Output de ejemplo:
# active_record_encryption:
#   primary_key: abc123...
#   deterministic_key: def456...
#   key_derivation_salt: ghi789...

# Agregar al credentials del entorno correspondiente:
rails credentials:edit --environment production
```

### Dónde viven las claves

| Entorno | Ubicación | Acceso |
|---|---|---|
| Development | `config/credentials/development.yml.enc` | `RAILS_MASTER_KEY` en `.env.local` |
| Test | `config/credentials/test.yml.enc` | `RAILS_MASTER_KEY` en CI secrets |
| Production | `config/credentials/production.yml.enc` | `RAILS_MASTER_KEY` en secretos del host |

**Nunca** almacenar `RAILS_MASTER_KEY` en el repositorio ni en variables de entorno planas en producción. Usar un secret manager (AWS Secrets Manager, GCP Secret Manager, Doppler, etc.).

### Qué está cifrado

| Modelo | Campo | Motivo |
|---|---|---|
| `Dispositivo` | `metadata` | Credenciales OAuth Tuya, API keys Pulse, tokens externos |

`deterministic: false` significa que el mismo valor produce distintos ciphertexts en cada cifrado. Esto hace imposible buscar por valor pero maximiza la seguridad. Como `metadata` es JSONB y nunca se filtra por valor en SQL, esto es correcto.

### Rotación de claves

El proceso de rotación NO es instantáneo. Seguir estos pasos:

```bash
# 1. Agregar la nueva clave como "secondary" en credentials.yml.enc
active_record_encryption:
  primary_key: <NUEVA_CLAVE>
  deterministic_key: <NUEVA_DETERMINISTIC>
  key_derivation_salt: <NUEVA_SALT>
  previous_schemes:
    - primary_key: <CLAVE_VIEJA>
      deterministic_key: <DETERMINISTIC_VIEJA>
      key_derivation_salt: <SALT_VIEJA>

# 2. Re-encrypt todos los registros con la nueva clave primaria
rails runner "Dispositivo.find_each { |d| d.touch }"
# (touch fuerza re-encrypt al guardar)

# 3. Verificar que todos los registros se leen correctamente
rails runner "Dispositivo.find_each { |d| d.metadata }"

# 4. Remover previous_schemes del credentials
# 5. Deploy y smoke test
```

### Backup y restore con datos cifrados

**Backup**: `pg_dump` no tiene acceso a las claves — el dump contiene el ciphertext. Para restaurar en otro entorno, necesitás tanto el dump como el `RAILS_MASTER_KEY` del entorno original.

```bash
# Backup con estructura cifrada (normal)
pg_dump $DATABASE_URL > backup.sql

# Restore en entorno de staging (necesita la misma MASTER_KEY)
RAILS_MASTER_KEY=<key_de_produccion> psql $STAGING_DB < backup.sql
```

**Importante**: si perdés el `RAILS_MASTER_KEY`, los datos en `metadata` son irrecuperables. Mantener el key en al menos 2 ubicaciones seguras y separadas.

**Para restore a un entorno diferente con sus propias claves**:
```bash
# 1. Restore con la key original
# 2. Correr: rails runner "Dispositivo.find_each { |d| d.save! }"
#    (re-cifra con las claves del nuevo entorno)
# 3. Cambiar la MASTER_KEY del entorno al nuevo valor
```

---

## 2. Webhook token (dispositivos)

Los webhook tokens NO usan AR::Encryption. Usan BCrypt porque:
- El token es un secreto que se compara por igualdad (`==`)
- BCrypt es el estándar para "hashes de contraseñas" — resistente a timing attacks
- AR::Encryption está diseñado para datos que necesitan ser recuperados — acá solo necesitamos comparar

### Ciclo de vida

```
1. Admin crea Dispositivo con tipo que requiere webhook
2. Controller: token = SecureRandom.hex(32)
              dispositivo.webhook_token_digest = BCrypt::Password.create(token)
              dispositivo.save!
3. Respuesta incluye { webhook_token: token } ← solo esta vez
4. El token se entrega al operador del sensor vía interfaz segura
5. El sensor lo envía en: Authorization: Bearer <token>
6. Controller verifica: BCrypt::Password.new(digest) == token
```

**Si el token se compromete**: `POST /dispositivos/:id/regenerar_token` genera un nuevo par. El token viejo queda inmediatamente inválido.

---

## 3. Autenticación y sesiones

- **Devise** con cookie `HttpOnly`, `SameSite=Strict`, `Secure` en producción
- **JWT denylist** (`jwt_denylists` table) para invalidar sesiones en logout
- **Endpoint webhook** (`/webhooks/*`): no usa sesión Devise, solo token BCrypt

---

## 4. CORS

Configurado en `config/initializers/cors.rb`. Solo permite origins de:
- `https://app.clubcultivo.ar` (producción)
- `http://localhost:5173` (desarrollo)

Nunca `origins '*'` en producción.

---

## 5. Checklist de seguridad por deploy

- [ ] `RAILS_MASTER_KEY` en secret manager del host (no en código ni env plano)
- [ ] `DATABASE_URL` con usuario de aplicación (no `postgres` superuser)
- [ ] Redis en red privada (no expuesto a internet)
- [ ] Sidekiq Web (`/sidekiq`) detrás de auth admin — verificar que el mount esté activo
- [ ] `SECRET_KEY_BASE` rotada si hay sospecha de compromiso
- [ ] Logs no imprimen valores de `metadata` — verificar que AR::Encryption no loguee plain text
- [ ] Rack::Attack activo en producción — verificar que no esté comentado

---

## 6. Secrets que NUNCA van al repositorio

```
RAILS_MASTER_KEY
DATABASE_URL
REDIS_URL
SECRET_KEY_BASE
TUYA_ACCESS_KEY / TUYA_SECRET_KEY  (van en dispositivos.metadata, cifrado)
```

`.gitignore` cubre `*.local` y `config/credentials/*.key`. Verificar con:
```bash
git ls-files config/credentials/*.key  # debe retornar vacío
```
