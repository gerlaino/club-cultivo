# Staging — cómo levantarlo y cómo se trabaja con él

Hasta ahora el único ambiente era producción: cada cambio se probaba con clubes
adentro. Con clubes ajenos operando eso deja de ser viable — no porque esté mal
hecho, sino porque **no se le puede cortar la app a alguien que la está usando
para trabajar**.

## Qué queda armado

| Servicio | Rama | Para qué |
|---|---|---|
| `club-cultivo-staging` | `staging` | La app completa, contra su propia base |
| `club-cultivo-staging-worker` | `staging` | Sidekiq: sin esto los cron no corren |
| `club-cultivo-staging-redis` | — | Colas y caché de staging |
| `club-cultivo-staging-db` | — | Base propia. **Nunca datos reales de un club** |

## Levantarlo (una vez)

1. **Crear la rama**
   ```bash
   git checkout -b staging && git push -u origin staging
   ```

2. **Render → New → Blueprint** → apuntar a este repo. Render lee `render.yaml`
   y crea los cuatro servicios de staging. Producción no se toca: está comentada
   a propósito.

3. **Cargar los secretos** de `club-cultivo-staging` y su worker (los marcados
   `sync: false`).

   ⚠️ **Cuatro cortan el arranque si faltan** — la app no bootea y el servicio queda en
   crash-loop: `DEVISE_JWT_SECRET_KEY` y las tres `ACTIVE_RECORD_ENCRYPTION_*`. Es a
   propósito (sin ellas la app "andaría" sin poder leer datos clínicos), pero si un
   servicio nuevo no arranca, empezá mirando esas cuatro.

   Podés reusar los valores de producción **salvo estos dos**:
   - **`S3_BUCKET`** → uno propio. Compartir el de prod significa que una prueba
     puede pisar o borrar archivos reales de un club.
   - Las **claves de encriptación** (`ACTIVE_RECORD_ENCRYPTION_*`) → si usás las
     mismas que prod, un dump de staging alcanza para leer datos clínicos reales.
     Generá otras:
     ```bash
     bin/rails db:encryption:init
     ```

4. **Poblarlo**
   ```bash
   bundle exec rails db:migrate
   bundle exec rake club:demo PASSWORD="LoQueQuieras"
   ```

## Cómo se trabaja a partir de acá

```
                merge                 merge
   feature  ──────────►  staging  ──────────►  master
                         (deploy               (deploy
                          automático)           a producción)
```

- Se pushea a `staging`, se prueba ahí, y recién entonces se mergea a `master`.
- **Producción deja de ser el lugar donde se descubren los errores.**
- Si algo sale mal en staging, no hay nadie trabajando del otro lado.

## Antes de mergear a master

- [ ] `bundle exec rspec` y `npx vitest run` en verde
- [ ] Probado en staging con el rol que corresponde
- [ ] Si hay migraciones: corridas en staging **primero**
- [ ] `rake sidekiq:health` en staging dice "worker corriendo"

## Probar el restore (hacerlo una vez, en serio)

Un backup que nunca se restauró es un archivo, no un backup. Staging es el lugar
para comprobarlo sin riesgo:

```bash
bundle exec rake backup:list                 # elegí una key
bundle exec rake backup:restore[<key>]       # sobre la base de STAGING
```

Anotá cuánto tardó: **ese número es tu tiempo real de recuperación** ante un
desastre, y es el dato que vas a necesitar el día que pase algo.
