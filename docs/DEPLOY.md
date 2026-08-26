# Despliegue — ambientes, variables y cómo no romper el que anda

> Escrito el 20-ago-2026 a partir del código, no de memoria: cada variable de acá está leída de
> algún `ENV[...]` del repo. Si agregás una nueva, sumala a este archivo en el mismo commit.

---

## 1. El estado real hoy, con los nombres que confunden

**El servicio que se llama `cultivo-staging-api` ES PRODUCCIÓN.** No es un ambiente de prueba: es la
app que usan las organizaciones. El nombre quedó de cuando se levantó apurado y nunca se cambió.

| Servicio en Render | Qué es en realidad |
|---|---|
| `cultivo-staging-api` | **La app en vivo** (API + SPA en el mismo origen) |
| `club-cultivo-worker` | El Sidekiq de producción |
| `club-cultivo-1` | Frontend estático **legacy**. Ver §6 |
| `club-cultivo-stg`, `club-cultivo-stg-worker` | Muertos. Intento de staging, falló |
| `club-cultivo-staging`, `club-cultivo-staging-worker` | Muertos. Segundo intento |
| `club-cultivo-staging-db` | Base de alguno de esos intentos |
| `db-backup-diario` | Cron de backup. **Fallando desde el 7-ago** |

Renombrar el servicio de producción cambia su URL `.onrender.com`, así que **no se toca hasta que el
dominio propio esté configurado y apuntando**. Mientras tanto, este documento es la traducción.

---

## 2. Qué es "un ambiente"

No es un servicio. Son cuatro piezas y ninguna es opcional:

1. **Web** (Ruby) — sirve la API y la SPA. `bin/render-build.sh` compila el frontend y lo deja en
   `backend/public/`, así que **no hay un static site aparte** y no debe haberlo: el login en
   incógnito y en iOS depende de que la cookie sea first-party.
2. **Worker** (Ruby) — Sidekiq. Vencimientos de REPROCANN, alertas de ambiente, envíos masivos,
   informes, push. **Su ausencia no rompe nada visible**: los avisos simplemente dejan de llegar.
   En producción estuvo 79 días sin existir y nadie lo notó.
3. **Postgres**.
4. **Redis** — cola de Sidekiq y adaptador de ActionCable. Con `maxmemory-policy` distinto de
   `noeviction`, Redis descarta claves bajo presión y **Sidekiq pierde jobs**.

Configuración del web service:

```
Root Directory:     backend
Build Command:      bash bin/render-build.sh
Start Command:      bundle exec puma -C config/puma.rb
Health Check Path:  /up          ← "/" contesta 404 A PROPÓSITO; no sirve
```

Worker: `Build: bundle install` · `Start: bundle exec sidekiq -C config/sidekiq.yml`

---

## 3. Las variables, y qué se rompe si faltan

### 3.1 Sin estas la app NO ARRANCA

Se verifican al bootear y **no hay fallback silencioso** — se prefirió que reviente el deploy antes
que servir una app a medias.

| Variable | Dónde se verifica | Qué pasa si falta |
|---|---|---|
| `DATABASE_URL` | — | No hay base |
| `SECRET_KEY_BASE` | Rails | No bootea |
| `DEVISE_JWT_SECRET_KEY` | `config/initializers/devise.rb` | Lanza excepción explícita |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | `config/application.rb` | Lanza excepción |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | `config/application.rb` | Lanza excepción |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | `config/application.rb` | Lanza excepción |

Las tres de cifrado protegen los datos de salud at-rest (Ley 25.326 art. 9): patología,
dosificación, vía de administración, observaciones y DNI.

> ⚠️ **Cambiar una clave de cifrado hace ilegible lo ya guardado.** No se rotan sin un plan de
> re-cifrado. Hoy `support_unencrypted_data = true` permite leer filas viejas en texto plano;
> endurecerlo es un pendiente y exige que el backfill esté completo.

### 3.2 Sin estas la app arranca pero algo no funciona

| Variable | Qué se cae |
|---|---|
| `REDIS_URL` | Jobs y tiempo real (stock, ambiente, alertas) |
| `FRONTEND_URL` | CORS y orígenes de ActionCable → **el tiempo real se cae en silencio** |
| `APP_HOST` | Los links absolutos de los mailers |
| `ACTIVE_STORAGE_SERVICE` | Cae a disco local: en Render **los archivos se pierden en cada deploy** |
| `S3_*` / `AWS_*` | Fotos, PDFs y documentos clínicos |
| `SMTP_HOST` · `SMTP_USER` · `SMTP_PASS` | Ningún correo de plataforma |
| `MAIL_FROM` | Remitente; por defecto `noreply@cultivoespacial.com` |
| `VAPID_PUBLIC_KEY` · `VAPID_PRIVATE_KEY` · `VAPID_EMAIL` | Notificaciones push |
| `ANTHROPIC_API_KEY` | Asistente, análisis de lote, plan de trabajo, lectura de CSV |
| `SIDEKIQ_PASSWORD` | El panel `/sidekiq` queda con la clave `changeme` |
| `EXTRA_CORS_ORIGINS` | Orígenes extra, separados por coma (para la transición de dominio) |
| `ARICCAME_SIMULAR` | En cualquier ambiente que no sea producción debe ser `true` |

### 3.4 Desde dónde se acepta una conexión

`App.origenes_permitidos` (en `config/application.rb`) es la **fuente única**: la consumen CORS
(`config/initializers/cors.rb`) y el handshake de ActionCable (`config/environments/production.rb`).
La lista es `App::HOSTS_PROPIOS` + `FRONTEND_URL` + `EXTRA_CORS_ORIGINS`.

**Los hosts propios se SUMAN, no se reemplazan.** Estaba escrita dos veces y las dos copias
anotaban `club-cultivo-1.onrender.com` —el static viejo— sin anotar `cultivo-staging-api`, que es
donde la app corre de verdad. Al mover `FRONTEND_URL` al dominio propio, el host de Render salía de
la lista, y a todo el que siguiera entrando por ahí mientras el DNS propaga se le cortaba el tiempo
real **sin un error a la vista**: la pantalla se queda quieta.

`spec/config/origenes_permitidos_spec.rb` fija esto, incluido el caso de la transición.

Para armar links fuera de un request (mails, jobs, PDFs) se usa **`App.base_url`**: `FRONTEND_URL`,
y si no está, `https://` + `APP_HOST`. El mailer del portal del paciente tenía escrito a mano
`https://app.cultivoespacial.com` —un subdominio, cuando la dirección elegida es la raíz— y es
justo el mail donde la persona recibe su contraseña.

### 3.3 Sólo para el cron de backup

`BACKUP_BUCKET`, `DATABASE_URL`, y credenciales: usa `BACKUP_S3_ACCESS_KEY_ID` /
`BACKUP_S3_SECRET_ACCESS_KEY` si existen, y si no cae en las de la app (`S3_*`).

**En Render, un Cron Job NO hereda las variables del web service.** Hay que cargárselas una por una.

> **La causa por la que falló 13 días ya está arreglada, y era nuestra, no de Render.** El log
> decía `Falta ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` — una clave que el backup **no usa**. Pasaba
> porque el `Rakefile` hace `require_relative "config/application"`, y la verificación de esas
> claves estaba suelta en el cuerpo de la clase: se disparaba con CUALQUIER rake, incluidos los
> escritos a propósito sin `:environment`. Ahora es un `initializer`, que se ejecuta recién cuando
> la app arranca de verdad.
>
> **El cron NO debe tener las claves de cifrado**, y eso no es una concesión: produce un dump con
> los datos cifrados adentro. Darle además las llaves sería guardar la caja fuerte y la llave en el
> mismo lugar.

### De dónde sale cada valor

Son **cinco**, y **tres se copian tal cual** del web service de producción — la app ya usa el mismo
R2 para las fotos y los PDFs.

| Variable | De dónde | ¿Nueva? |
|---|---|---|
| `DATABASE_URL` | Render → la base de producción → **Internal Database URL** | copiar |
| `BACKUP_BUCKET` | Cloudflare → R2 → nombre del bucket de backups | **sí** |
| `S3_ENDPOINT` | Render → `cultivo-staging-api` → Environment → copiar | copiar |
| `S3_ACCESS_KEY_ID` | ídem | copiar |
| `S3_SECRET_ACCESS_KEY` | ídem | copiar |

`S3_REGION` **no hace falta**: el código ya usa `auto`, que es lo que corresponde en R2.

**Las credenciales se buscan con los mismos alternativos que `storage.yml`**, `AWS_*` incluidas:
`BACKUP_S3_ACCESS_KEY_ID` → `S3_ACCESS_KEY_ID` → `AWS_ACCESS_KEY_ID`. Antes el backup sólo miraba
las dos primeras y la app sí caía en `AWS_*`: con producción configurada así, las fotos subían y
el backup abortaba diciendo que faltaba una variable que estaba puesta con otro nombre.

Lo mismo con el bucket: `BACKUP_BUCKET` → `S3_BUCKET` → `AWS_BUCKET`. Uno dedicado sigue siendo lo
mejor, pero un backup mezclado bajo el prefijo `postgres/` es mejor que ningún backup.

> **Ojo: hoy el destino NO es R2, es AWS S3.** Producción está configurada con `AWS_BUCKET`,
> `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_REGION`, y **no tiene `S3_ENDPOINT`** — sin
> endpoint el SDK habla con S3 de verdad. Esta sección decía R2 porque así se había planeado.
>
> Importa por la REGIÓN: `auto` es un valor de R2 y S3 no lo entiende. El código lo usa como
> default sólo cuando hay endpoint; sin endpoint exige una región real y la busca en
> `BACKUP_S3_REGION` → `S3_REGION` → `AWS_REGION`.

### Por qué el cron falla pidiendo una clave de cifrado

Si el log dice `Falta ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, **no le des las claves**: el arreglo
ya está en el código —el chequeo es un `initializer` y no se dispara con un rake sin
`:environment`— y lo que pasa es que **el Cron Job corre una versión vieja**. En Render un cron
tiene su propio deploy y no se actualiza con el del web service. La salida es redeployarlo, no
aflojar la regla.

Las credenciales caen en `S3_*` si no existen `BACKUP_S3_*`. Reusar las de la app funciona y es lo
más rápido para empezar; lo ideal después es un token de R2 **dedicado** y limitado al bucket de
backups, para que una filtración del backup no dé acceso a los documentos clínicos ni al revés.

Sobre el bucket: mejor uno separado del de la app. Si hay uno solo, funciona igual — los dumps van
bajo el prefijo `postgres/` — pero quedan mezclados con los archivos de pacientes.

`DATABASE_URL` interna vs externa: si el cron corre en la misma región que la base (Oregon), va la
**interna**, que no sale a internet. La externa funciona pero expone la base.

También necesita `pg_dump` en el PATH y de una versión compatible con el servidor.

### Verificar que quedó andando

1. Cargar las variables → **Trigger Run** a mano (no esperar al horario).
2. El log tiene que decir `✓ Backup subido: postgres/club_cultivo_<fecha>.dump`.
3. Confirmar que el archivo está: `rake backup:list` desde el Shell del servicio.
4. Un backup que nunca se restauró no es un backup: probar `rake 'backup:restore[<key>]'`
   contra **preproducción**, nunca contra producción.

---

## 4. Lo que NUNCA se comparte entre ambientes

Base · Redis · `SECRET_KEY_BASE` · `DEVISE_JWT_SECRET_KEY` · las tres claves de cifrado · bucket de
S3 · casilla SMTP.

El motivo dejó de ser teórico: apareció **una cookie de sesión real commiteada en el repo**. Como
era de un solo ambiente, el daño quedó acotado ahí. Con secretos compartidos, cualquier filtración
de un ambiente de prueba es una filtración de la app en vivo.

**Consecuencia deliberada:** con claves de cifrado distintas, preproducción no puede leer los
campos cifrados de un dump de producción tal cual. Por eso el clon se anonimiza en SQL — ver §8.

---

## 5. Cómo se publica

**Preproducción despliega sola** con cada push a `master` (`autoDeploy: true` en `render.yaml`).

**Producción NO.** Su auto-deploy va **apagado**: cuando preproducción está verificada, se aprieta
Deploy a mano. Es lo que da el "subo, pruebo, y recién ahí lo paso" sin sumar ramas — encaja con
trabajar directo en `master`.

Las **migraciones corren solas** dentro de `bin/render-build.sh`, con `set -o errexit`: si una falla,
falla el deploy entero y no queda una app a medias contra una base a medias. **Los rakes NO**: esos
se corren a mano, una vez, desde el Shell del servicio.

Antes de promover a producción, mirar en preproducción:

- [ ] `/up` responde
- [ ] Entra un usuario y `/me` contesta
- [ ] El tiempo real anda (abrir Stock y ver que llegue una actualización) → si no, mirar `FRONTEND_URL`
- [ ] Sidekiq procesa (`rake sidekiq:health`)
- [ ] Sube una foto y se ve (Active Storage bien apuntado)
- [ ] Las migraciones corrieron

---

## 6. Deudas conocidas de infraestructura

1. **`db-backup-diario` falló desde el 7-ago: 13+ días sin respaldo de la base de producción.**
   La causa está arreglada en el código (ver §3.3); falta **cargarle las variables al cron y
   dispararlo a mano** para confirmar que sube el dump.
2. **Cuatro servicios muertos** (`club-cultivo-stg*`, `club-cultivo-staging*`) de dos intentos de
   staging. Borrarlos: ocupan lugar y hacen imposible saber cuál es cuál. Antes, verificar si
   `club-cultivo-staging-db` tiene algo que valga la pena.
3. **`club-cultivo-1` (static) es legacy.** El frontend hoy lo sirve Rails desde el mismo origen.
   Mientras el static siga vivo y alguien entre por ahí, convive el problema de cookies cross-site
   que motivó la migración. Confirmar a dónde apunta el dominio antes de borrarlo.
4. **El dominio `cultivoespacial.com` no está configurado.** La decisión tomada: la raíz apunta al
   **web service**, no al static. Al hacerlo hay que setear `FRONTEND_URL` y `APP_HOST`, o el
   tiempo real se cae en silencio. **Del lado del código ya está listo** — ver §3.4.
5. **Rotar `SECRET_KEY_BASE` de producción**, por la cookie que estuvo commiteada. Desloguea a
   todos, que es justamente lo que se busca.
5b. **Simplificar la cookie de sesión, DESPUÉS del dominio.** `config/initializers/session_store.rb`
   usa `same_site: :none` + `partitioned: true`, que era necesario cuando el SPA salía de otro
   origen. Hoy es todo same-origin y alcanza `:lax`. No se toca junto con el dominio: mover
   cookies y host el mismo día es cómo se rompe el login.
6. **Renombrar `cultivo-staging-api`** a algo que diga que es producción — después del dominio.

---

## 7. Levantar preproducción

1. Borrar los cuatro servicios muertos (§6.2).
2. Render → Blueprints → New Blueprint Instance → apuntar al repo. Toma `render.yaml`.
3. Completar las variables marcadas `sync: false`: bucket **propio** de preproducción, SMTP, VAPID,
   `ANTHROPIC_API_KEY`. Los secretos los genera Render solo.
4. Esperar el primer deploy y recorrer la lista de §5.
5. Sembrar datos: `rake club:demo`.

**Verificar que `render.yaml` no toque producción:** los nombres son `cultivo-pre-*` y no coinciden
con ningún servicio existente, así que el blueprint sólo puede crear cosas nuevas. Producción sigue
administrada a mano hasta que se decida adoptarla acá, y esa es una migración aparte y deliberada
— no un efecto colateral.

---

## 8. Datos realistas en preproducción, sin datos de personas reales

Con datos inventados no aparecen los bugs que importan: los que aparecen son los de **volumen** y
los de **datos raros** —el paciente con dos REPROCANN, el lote con la fase mal, el nombre con
apóstrofe— y nada de eso lo genera un seed.

Entonces se clona producción y se anonimiza:

```bash
# 1. Traer el dump más reciente
rake backup:list
rake 'backup:restore[postgres/club_cultivo_<fecha>.dump]'   # ← con RESTORE_DATABASE_URL apuntando a PREPROD

# 2. Ver qué tocaría, sin tocar nada
rake preprod:anonimizar SIMULAR=1

# 3. Hacerlo (el nombre de la base se tipea a mano, a propósito)
rake preprod:anonimizar CONFIRMO_BASE=cultivo_pre
```

### Qué hace, en orden

**Primero corta los canales, después anonimiza.** El orden importa: si algo falla en el medio,
falla con preproducción ya incapaz de contactar a nadie.

Una copia de producción no trae sólo datos: trae **canales abiertos a personas reales**. Esto es lo
más peligroso y lo que menos se mira.

| Qué hereda | Qué podría pasar |
|---|---|
| `clubs.smtp_pass` | Preproducción manda mails **desde la casilla real de la organización**, a las casillas reales de sus pacientes |
| `clubs.twilio_auth_token_enc` | Manda WhatsApp de verdad |
| `webhooks.url` + `secret` | Le pega al sistema externo real del cliente |
| `push_subscriptions` | Le vibra el teléfono a un paciente real |

Después reemplaza la identidad —nombres, DNI, mails, teléfonos, domicilios de entrega y la firma de
recepción— y vacía el texto libre: notas clínicas, motivos y notas de turno, observaciones,
reseñas, el contenido de `auditorias.cambios` (que guarda los campos viejos tal como estaban) y los
campos cifrados de `indicacion_medicas`.

**Lo que NO toca**, porque es justamente lo que hace aparecer los bugs: fechas, cantidades, pesos,
códigos de lote, stock, movimientos contables, relaciones y volumen.

El reemplazo es **determinístico a partir del id** —el mismo paciente es siempre `Paciente N214`—
así que un bug que se reproduce hoy se sigue reproduciendo mañana y se puede hablar de "el 214"
entre dos corridas del clon.

### Por qué se puede confiar

`spec/tasks/preprod_anonimizar_spec.rb` **barre la base entera** —todas las tablas, todas las
columnas de texto y jsonb— buscando rastros de la persona de prueba. Si alguien agrega mañana una
columna con un teléfono adentro y no actualiza el anonimizador, ese test falla.

### Dos cosas para tener presentes

- **Las contraseñas no se tocan.** Los usuarios del clon quedan con el hash de producción, así que
  para entrar hay que resetear la que se vaya a usar. Cambiarlas a todas por una fija sería
  reintroducir el problema que se acaba de sacar de raíz.
- **No es un botón, es una rutina.** Cada corrida es un `pg_restore` completo que deja
  preproducción inutilizable un rato. Es algo de una vez por mes, no de todos los días.
