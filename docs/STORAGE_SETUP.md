# Storage de archivos — setup para escala (object storage)

**Decisión:** object storage S3-compatible (no disco local). Recomendado **Cloudflare R2**
por costo de egress cero (servir imágenes a miles de clubes no genera factura de tráfico)
y CDN global incluido. El código es agnóstico: sirve R2 o S3 cambiando solo env vars.

## Estado del código (ya hecho)
- Gema `aws-sdk-s3` agregada.
- `config/storage.yml`: servicios `amazon` (privado, URLs firmadas que expiran — para
  documentos clínicos/pacientes) y `amazon_public` (para assets públicos vía CDN).
- `production.rb`: `config.active_storage.service` se controla con `ACTIVE_STORAGE_SERVICE`
  (default `local`, así el deploy no se rompe hasta cargar credenciales).

## Provisión paso a paso — Cloudflare R2 (recomendado)

Tiempo: ~15 minutos. Necesitás una tarjeta (R2 la pide aunque uses el tier gratis).

### Paso 1 — Crear cuenta Cloudflare
1. Entrá a https://dash.cloudflare.com/sign-up y registrate con tu email (gratis).
2. Verificá el email y logueate. Vas a caer en el dashboard principal.

### Paso 2 — Activar R2
1. En el menú lateral izquierdo, buscá **R2 Object Storage** (o "R2").
2. La primera vez te pide **suscribirte a R2**: te va a pedir agregar un **método de pago
   (tarjeta)**. Es obligatorio aunque el tier gratis alcanza de sobra al principio
   (10 GB de almacenamiento gratis por mes y, lo más importante, **egress siempre gratis**).
3. Confirmá la suscripción.

### Paso 3 — Crear el bucket
1. Dentro de R2, clic en **Create bucket**.
2. Nombre: `cultivo-prod` (o el que prefieras, anotalo).
3. **Location**: dejá "Automatic" (o elegí la región más cercana si te deja).
4. Dejalo **privado** (es el default — NO marques acceso público).
5. Create bucket.

### Paso 4 — Obtener el Account ID / endpoint
1. En la página principal de R2, a la derecha vas a ver tu **Account ID** (una cadena larga
   de letras y números). Copialo.
2. Tu endpoint S3 es: `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`
   (reemplazá `<ACCOUNT_ID>` por el valor del punto anterior).

### Paso 5 — Crear el API Token (las credenciales)
1. En R2, clic en **Manage R2 API Tokens** (arriba a la derecha) → **Create API token**.
2. Nombre: `cultivo-render`.
3. Permisos: **Object Read & Write**.
4. Scope: podés limitarlo al bucket `cultivo-prod` (recomendado) o dejarlo a todos.
5. Create. **IMPORTANTE:** te muestra **una sola vez** dos valores — copialos ya:
   - **Access Key ID**
   - **Secret Access Key**
   (Si los perdés, no se recuperan: hay que crear un token nuevo.)

### Paso 6 — Cargar las variables en Render
En el dashboard de Render → tu servicio **backend** → pestaña **Environment** → agregá:
```
ACTIVE_STORAGE_SERVICE = amazon
S3_BUCKET              = cultivo-prod
S3_REGION              = auto
S3_ENDPOINT            = https://<ACCOUNT_ID>.r2.cloudflarestorage.com
S3_ACCESS_KEY_ID       = <Access Key ID del Paso 5>
S3_SECRET_ACCESS_KEY   = <Secret Access Key del Paso 5>
```
Guardá → Render hace redeploy solo.

### Paso 7 — Probar
1. Entrá a la app como admin → Configuración del club → subí un logo.
2. Forzá un redeploy en Render (o esperá al próximo).
3. Recargá la app: el logo **debe seguir ahí**. Si persiste, quedó funcionando.

> Costos: el tier gratis cubre 10 GB de almacenamiento y el egress (servir los archivos)
> es **siempre gratis** en R2. Recién pagás almacenamiento por encima de 10 GB (~USD 0,015
> por GB/mes). Para arrancar es prácticamente gratis.

### Alternativa — AWS S3
Mismos pasos conceptuales pero en la consola de AWS (crear bucket S3 + usuario IAM con
política de acceso al bucket + access keys). En las env vars: **omitir** `S3_ENDPOINT` y usar
`S3_REGION = sa-east-1` (San Pablo). Ojo: en S3 el egress **se paga**, por eso recomiendo R2.

## Roadmap a escala (preparado, se activa cuando haga falta — no es urgente)

1. **CDN para assets públicos:** dominio propio (ej. `cdn.tuclub.com`) apuntando al bucket
   público de R2; rutear logos y web pública al servicio `amazon_public`
   (`has_one_attached :logo, service: :amazon_public`). Servido y cacheado en el edge,
   sin pasar por Rails.
2. **Direct uploads:** con 1000 clubes, que los archivos suban directo del navegador al
   bucket (no a través del backend) para no saturar Rails. ActiveStorage ya lo soporta
   (`direct_upload: true` + CORS del bucket).
3. **Variantes de imagen:** `image_processing` + libvips en el Dockerfile para servir
   miniaturas (avatares/logos redimensionados) en vez de full-res.
4. **Migración de archivos existentes:** si algún día se cambia de proveedor, ActiveStorage
   permite mirror service para copiar sin downtime.

## Importante
- Los archivos subidos **antes** de configurar R2 ya se perdieron (disco efímero de Render).
  Logo y demás hay que volver a subirlos una vez configurado.
- El bucket `amazon` es **privado**: los documentos de pacientes se sirven con URLs firmadas
  que expiran. Nunca exponer ese bucket públicamente.
