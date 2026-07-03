# Backups de la base (PostgreSQL → Cloudflare R2)

Backup **diario automático** de la base de producción, comprimido, versionado por fecha,
guardado en un bucket de **Cloudflare R2**, con **retención de 30 días** y un procedimiento
de **restore** para emergencias.

> Contexto legal: la base tiene datos de salud (Ley 25.326). Los backups son igual de
> sensibles que la base → bucket **privado**, credenciales por env var, retención acotada.

---

## Cómo funciona

- Un **cron job en Render** (`db-backup-diario`) corre todos los días a las **07:00 UTC**
  (04:00 Argentina, baja carga) el comando `bundle exec rake backup:create`.
- `backup:create` hace:
  1. `pg_dump --format=custom` de `DATABASE_URL` → archivo `.dump` (formato custom, ya
     comprimido y restaurable con `pg_restore`).
  2. Lo sube a `s3://$BACKUP_BUCKET/postgres/club_cultivo_YYYY-MM-DD_HHMMSS.dump`.
  3. Aplica **retención**: borra del bucket los backups de más de 30 días.
- Las tareas **no bootean la app** (no dependen de `:environment`): sólo usan las env vars,
  `pg_dump`/`pg_restore` y `aws-sdk-s3`. Por eso no necesitan `SECRET_KEY_BASE` ni el resto
  de los secrets de prod.

Archivos:
- `backend/lib/tasks/backup.rake` — tareas `backup:create`, `backup:list`, `backup:prune`, `backup:restore`.
- `render.yaml` — define el cron job.

---

## Variables de entorno (setear en el cron de Render)

| Variable | Qué es |
|---|---|
| `DATABASE_URL` | Connection string de la base de **producción** (Internal Database URL del dashboard de Render). |
| `BACKUP_BUCKET` | Nombre del bucket R2 **dedicado** a backups (distinto del de ActiveStorage). |
| `S3_ENDPOINT` | Endpoint R2: `https://<account_id>.r2.cloudflarestorage.com`. |
| `S3_REGION` | `auto` (R2). |
| `BACKUP_S3_ACCESS_KEY_ID` | Access Key del token R2 de backup (least-privilege). *Opcional*: si no está, usa `S3_ACCESS_KEY_ID`. |
| `BACKUP_S3_SECRET_ACCESS_KEY` | Secret del token R2 de backup. *Opcional*: si no está, usa `S3_SECRET_ACCESS_KEY`. |

Ninguna credencial va hardcodeada: todo sale de env vars.

---

## Restore (emergencia)

Se corre desde la **Shell del servicio** en Render (Dashboard → el servicio → *Shell*), que
ya tiene `pg_restore`, la gema y las env vars.

1. Listar los backups disponibles:

   ```
   cd backend
   bundle exec rake backup:list
   ```

   Devuelve, del más viejo al más nuevo:
   `2026-07-03 07:00 UTC   42.3 MB  postgres/club_cultivo_2026-07-03_070001.dump`

2. Restaurar uno (⚠ **pisa** los datos actuales de la base destino, con `--clean --if-exists`):

   ```
   bundle exec rake 'backup:restore[postgres/club_cultivo_2026-07-03_070001.dump]'
   ```

   Por defecto restaura sobre `DATABASE_URL`. Para restaurar a **otra** base (recomendado:
   probar primero en una base de staging/scratch), pasá `RESTORE_DATABASE_URL`:

   ```
   env RESTORE_DATABASE_URL=postgres://user:pass@host:5432/otra_base bundle exec rake 'backup:restore[postgres/club_cultivo_2026-07-03_070001.dump]'
   ```

   > `pg_restore` puede imprimir warnings tipo `... does not exist, skipping` por el
   > `--clean` sobre una base vacía: es normal, el restore igual se aplica.

### Probar el restore (recomendado hacerlo una vez, no esperar a la emergencia)
Creá una base Postgres chica y descartable en Render, seteá `RESTORE_DATABASE_URL` a esa,
corré el restore y verificá con `psql` que las tablas/filas estén. Después borrala.

---

## Correr un backup a mano (verificación)

Desde la Shell del servicio (o el cron con *Run job* en el dashboard):

```
cd backend
bundle exec rake backup:create
```

Y para forzar la limpieza de retención:

```
bundle exec rake backup:prune
```

---

## Notas / requisitos

- **`pg_dump`/`pg_restore`**: el runtime del cron debe tenerlos (postgresql-client). Verificá
  una vez en la Shell del servicio con `pg_dump --version`. La versión del cliente debe ser
  **>= la del server** de la base — si Render actualiza el Postgres a un major nuevo, alineá
  el cliente.
- **Un solo cron = una base**: este cron apunta a `DATABASE_URL` (producción). Para backupear
  también **staging**, duplicá el cron con el `DATABASE_URL` de staging (y, si querés,
  un prefijo o bucket distinto).
- **Restore parcial**: el formato custom permite `pg_restore -l archivo.dump` para listar el
  contenido y `-L` para restaurar sólo ciertas tablas, si alguna vez hace falta.
