# Infraestructura de Cultivo Espacial — explicada simple

> Escrito el 2-oct-2026. Es la guía para operar la plataforma como una empresa de software y no a
> pulmón: qué piezas hay, cómo se ve si andan, qué hacer cuando algo se rompe, y los pasos que hay
> que hacer a mano en los paneles. El detalle técnico de variables y servicios sigue en
> `docs/DEPLOY.md`.

---

## 1. Qué es la app, en cuatro piezas

| Pieza | Dónde | Qué hace | Si se cae… |
|---|---|---|---|
| **La app** (`cultivo-staging-api`) | Render | Atiende a todos los usuarios: pantallas y datos | Nadie puede entrar |
| **El worker** (`club-cultivo-worker`) | Render | Avisos de REPROCANN, push, correos, alertas | **No se nota**: los avisos dejan de salir. Ya pasó 79 días |
| **La base de datos** (Postgres) | Render | Donde vive todo | Nadie puede trabajar |
| **Redis** | Render | La fila de trabajos y el «se actualiza solo» de las pantallas | El worker no recibe trabajo; las pantallas no se actualizan solas |

Y alrededor: **fotos y documentos** en Amazon S3, **backups** en S3, **dominio** en GoDaddy,
**correo** por SMTP.

> **El que se llama «staging» ES producción.** `cultivo-staging-api` es la app en vivo. El nombre
> quedó de cuando se armó apurado.

---

## 2. Cómo saber si todo anda

Tres lugares, cada uno para una pregunta:

1. **Super admin → Estado** — ¿anda todo? Semáforo, avisos con qué hacer, servidores, uso de memoria
   y CPU, backups, tareas programadas, cuánto usa cada organización y el costo estimado.
   *Si la app está caída, esta pantalla también: para eso es el punto 2.*
2. **El monitor externo (UptimeRobot)** — te manda un mail si se cae la app (`/salud`) o si no hubo
   backup (`/salud/backup`). Vive afuera, así que avisa aunque todo lo nuestro esté caído.
3. **Sentry** — qué pantalla anda lenta y qué error tuvo un usuario, con el detalle para arreglarlo.

---

## 3. Backups

**Cómo funciona hoy:**
- Todos los días a las **4 AM** (hora argentina) el cron `db-backup-diario` copia la base entera al
  bucket de S3 (`rake backup:create`). Se guardan **30 días**.
- Después, el cron `backup-verificacion` baja la copia del día y comprueba que se pueda leer y
  que tenga las tablas importantes (`rake backup:verificar`). El resultado se ve en Estado.
- Si no hubo backup en 26 horas, el monitor externo manda un mail.

**Lo que falta (pasos 4 a 6 de abajo):** un bucket aparte para los backups, que las fotos tengan
copia (versionado de S3), y la **prueba de restauración mensual**.

**Una vez por mes — prueba de restauración (15 minutos):**
1. En Render → `cultivo-pre-api` (preproducción) → **Shell**.
2. `bundle exec rake backup:list` → copiar el nombre del último (`postgres/club_cultivo_…dump`).
3. `RESTORE_DATABASE_URL=<la Internal URL de cultivo-pre-db> bundle exec rake 'backup:restore[postgres/club_cultivo_…dump]'`
4. Si termina con «✓ Restore completo», anotar la fecha acá abajo.

> Preproducción no puede LEER los datos cifrados de producción (tiene otras claves, a propósito:
> datos de salud no van a un ambiente de prueba). La prueba confirma que el archivo restaura
> entero; para revisar datos se usa `rake club:demo`.

| Fecha | Backup restaurado | Quién | Resultado |
|---|---|---|---|
| | | | |

---

## 4. Qué hacer si… (manuales)

### Se cayó la app (nadie puede entrar)
1. Abrir **Render → `cultivo-staging-api` → Events**. ¿Hubo un deploy recién? → **Rollback** al
   anterior (botón en el deploy que andaba).
2. Si no hubo deploy: **Logs** → buscar `Error` o `FATAL`. Si dice algo de la base → ver «La base no
   responde».
3. Si no se entiende: **Manual Deploy → Restart service**.
4. Avisar a las organizaciones si va a tardar.

### La base no responde
1. **Render → la base de datos**: ¿dice *Available*? Si dice otra cosa, Render tiene un problema:
   mirar https://status.render.com.
2. Si se llenó el disco o la memoria: subirla de plan (botón *Upgrade*). No se pierden datos.

### Los avisos no salen (REPROCANN, push, correos)
1. **Super admin → Estado**: ¿«Trabajos en segundo plano» en rojo?
2. **Render → `club-cultivo-worker` → Logs**. Si no está corriendo: **Manual Deploy**.
3. Si las tareas programadas siguen «sin correr», reiniciar el worker las vuelve a registrar.

### No hubo backup
1. **Render → `db-backup-diario` → Logs** del último intento.
2. **Trigger Run** para correrlo ya. Si falla con «Falta…», es una variable del cron (§3.3 de
   `DEPLOY.md`). El cron **no** debe tener las claves de cifrado.

### Hay que restaurar producción desde un backup (lo peor)
1. **No apurarse.** Primero restaurar en preproducción y confirmar que el backup sirve (§3).
2. Avisar a las organizaciones: lo cargado desde el backup hasta ahora se pierde.
3. En Render → la base → si el plan tiene **Point-in-time recovery**, usar eso (vuelve a cualquier
   minuto de los últimos días, mejor que el backup de las 4 AM).
4. Si no: Shell de `cultivo-staging-api` →
   `RESTORE_DATABASE_URL=<Internal URL de la base> bundle exec rake 'backup:restore[<key>]'`.

### Se filtró una clave
1. Generar una nueva en el servicio dueño (AWS, Render, Sentry…).
2. Cambiarla en Render → Environment de **cada** servicio que la usa (la app, el worker, los cron).
3. Borrar la vieja. Si fue `SECRET_KEY_BASE`: cambiarla desloguea a todos, que es lo que se busca.

---

## 5. Cómo se publica un cambio

- **Hoy:** cada push a `master` corre los tests en GitHub (CI). Con el paso 7 hecho, Render
  publica en producción **sólo si los tests pasaron**.
- **No publicar en horario de dispensario** (tarde/noche).
- Las migraciones corren solas al publicar; los `rake` se corren a mano desde el Shell.
- **Siguiente escalón (cuando haya más organizaciones):** preproducción que recibe cada push y
  producción con un botón. `render.yaml` ya declara preproducción.

---

## 6. Para proyectos nuevos

La receta de cualquier proyecto nuestro es la misma, y se arma en este orden:
1. Las cuatro piezas (app, worker, base, Redis) declaradas en un `render.yaml` en el repo.
2. CI en GitHub desde el día uno (`.github/workflows/ci.yml` de acá sirve de modelo).
3. `/up` para Render, `/salud` para el monitor externo, Sentry.
4. Backup diario + verificación + bucket propio.
5. Este mismo documento, copiado y adaptado.

---

## 7. LOS PASOS QUE HAY QUE HACER A MANO

Uno por vez. Si algo no coincide con lo que ves en la pantalla, mandá una captura antes de tocar.

### Paso 1 — Sentry (mide errores y pantallas lentas) · 10 min
1. Entrá a **sentry.io** → *Sign up* (gratis).
2. Cuando pregunte la plataforma, elegí **Rails**. Nombre del proyecto: `cultivo-espacial`.
3. Te muestra un **DSN** (empieza con `https://` y tiene `@` y `ingest.sentry.io`). Copialo.
4. En **Render → `cultivo-staging-api` → Environment → Add Environment Variable**:
   `SENTRY_DSN` = lo que copiaste. Opcional: `SENTRY_ENVIRONMENT` = `production`.
5. Lo mismo en **`club-cultivo-worker`**.
6. Opcional: `SENTRY_URL` = la dirección de tu proyecto en Sentry (para el botón «Abrir» del panel).
7. Guardar. Render reinicia solo.

### Paso 2 — Llave de Render (para el panel de Estado) · 5 min
1. **Render → tu avatar (arriba a la derecha) → Account Settings → API Keys → Create API Key**.
   Nombre: `panel-estado`.
2. Copiala (se muestra una sola vez).
3. **Render → `cultivo-staging-api` → Environment → Add**: `RENDER_API_KEY` = la llave. Guardar.
4. Entrá a **Super admin → Estado**: tienen que aparecer los servidores.

### Paso 3 — Monitor externo (te avisa por mail) · 10 min
1. Entrá a **uptimerobot.com** → *Register* (gratis).
2. **Add New Monitor** → tipo **HTTP(s)** → URL `https://cultivoespacial.com/salud` → intervalo
   **5 minutos** → en *Alert contacts* tu mail (y el de tu socio). **Create**.
3. Otro monitor igual con `https://cultivoespacial.com/salud/backup`, intervalo **60 minutos**.
4. Para probar: los dos tienen que quedar en verde («Up») a los pocos minutos.

### Paso 4 — Cron de verificación de backups · 10 min
1. **Render → New → Cron Job** → mismo repo, branch `master`.
2. Nombre: **`backup-verificacion`** (con ese nombre el panel lo reconoce).
3. Root Directory: `backend` · Build: `bundle install` · Command: `bundle exec rake backup:verificar`
4. Schedule: `0 8 * * *` (5 AM hora argentina, una hora después del backup).
5. Environment: **las mismas variables que `db-backup-diario`** (bucket y credenciales). **No**
   le pongas las claves de cifrado. Necesita `pg_restore`: si el build falla por eso, avisame.
6. Crear → **Trigger Run** → en los Logs tiene que decir «✓ El backup se lee…».

### Paso 5 — Bucket aparte para los backups · 15 min
1. **AWS → S3 → Create bucket** → nombre `cultivo-espacial-backups` → misma región que el actual →
   *Block all public access* tildado → Create.
2. **AWS → IAM → Users → Create user** `backups-cron` → *Attach policies directly* → crear una
   política que sólo permita `s3:ListBucket`, `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`
   sobre ese bucket (si no sabés armarla, mandame captura y te paso el texto exacto).
3. Al usuario → *Security credentials* → *Create access key* → copiar las dos llaves.
4. En **`db-backup-diario`**, **`backup-verificacion`** y **`cultivo-staging-api`** → Environment:
   `BACKUP_BUCKET` = `cultivo-espacial-backups`, `BACKUP_S3_ACCESS_KEY_ID`,
   `BACKUP_S3_SECRET_ACCESS_KEY`, `BACKUP_S3_REGION` = la región.
5. **Trigger Run** en `db-backup-diario`. El panel deja de avisar «comparten bucket».
6. Los backups viejos quedan en el bucket anterior (`postgres/`); se borran solos a los 30 días.

### Paso 6 — Limpiar Render · 10 min
1. En **Super admin → Estado → «Ver servicios que no son de producción»** está la lista.
2. Antes de borrar cualquier base (`club-cultivo-staging-db`, etc.) **confirmá en el panel que no
   es la de producción** (la de producción dice «Base de datos» y está arriba).
3. Para cada servicio muerto: Render → el servicio → **Settings → Delete**.

### Paso 7 — Que sólo se publique lo que pasó los tests · 2 min
1. Esperá a que el próximo push muestre los tests en **GitHub → Actions** en verde (✓).
2. **Render → `cultivo-staging-api` → Settings → Auto-Deploy** → **After CI Checks Pass**.
3. Lo mismo en **`club-cultivo-worker`**.

### Paso 8 — Mirar el plan de la base · 2 min
1. **Render → la base de datos** (la de producción) → ¿qué **plan** dice y si tiene
   **Point-in-time recovery**? Mandame una captura: según eso vemos si conviene subirla.

### Paso 9 — Una vez por mes
- Prueba de restauración (§3) y anotarla en la tabla.
- Mirar **Estado**: costo, memoria de los servidores, cuánto creció cada organización.

### Pendientes viejos que siguen abiertos
- Rotar `SECRET_KEY_BASE` (Render → `cultivo-staging-api` → Environment → generar un valor nuevo).
- Confirmar que `APP_HOST` = `cultivoespacial.com` en `cultivo-staging-api` (los links de los mails).
