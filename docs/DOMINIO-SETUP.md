# Setup del dominio propio (cultivoespacial.com)

> Guía paso a paso para apuntar el dominio propio al deploy de Render.
> Contexto: el front se buildea con `VITE_API_URL=/api` (relativo) y Rails sirve la SPA
> desde `public/` → **todo es mismo-origen**. Por eso apuntar el dominio es casi
> plug-and-play: login/logout/cookie/cable siguen al dominio solos.

## Antes de empezar
- Acceso al panel de **Render** (el web service de Rails, `club-cultivo-1`).
- Acceso al panel de **DNS** del dominio `cultivoespacial.com`.

## Pasos

### 1. Render → agregar el dominio
- Render → web service de Rails → **Settings** → **Custom Domains** → **Add Custom Domain**.
- Agregar `cultivoespacial.com` y `www.cultivoespacial.com`.
- Render muestra los registros DNS a crear. Dejar esa pantalla abierta.

### 2. DNS → crear los registros
- En el panel del dominio, crear **exactamente** los registros que indicó Render
  (normalmente `CNAME` para `www` → `club-cultivo-1.onrender.com`, y para la raíz
  un `A`/`ALIAS`/`ANAME` según el proveedor).
- Esperar propagación (minutos a un par de horas). Render pone ✅ y emite el SSL solo.

### 3. Render → variables de entorno (Environment)
- Agregar **una sola**:
  - `FRONTEND_URL = https://cultivoespacial.com`  (para links de mails / QR)
- **NO** setear `COOKIE_DOMAIN` ni `EXTRA_CORS_ORIGINS` (no hacen falta con todo en un servicio).

### 4. Redeploy
- Al guardar la ENV, Render suele redeployar solo. Si no: **Manual Deploy → Deploy**.
- No hay que tocar código (el build ya usa `/api` relativo).

### 5. Probar
- [ ] Login normal entra bien.
- [ ] **Logout** saca y obliga a re-loguear.
- [ ] Incógnito: login + logout OK.
- [ ] iPhone/Safari: login + logout OK.
- [ ] QR de stock deslogueado → login → **lleva al stock** (no al inicio).
- [ ] Sin error de WebSocket en consola (o reconecta solo).

## Plan B (solo si algún día se separan front y API en dominios distintos)
NO es el caso actual. Si pasara:
- `COOKIE_DOMAIN = .cultivoespacial.com`  (comparte la cookie entre subdominios)
- `EXTRA_CORS_ORIGINS = https://<dominio-del-front>`  (lista separada por comas)

El código ya soporta ambas variables (set y delete de la cookie usan el mismo domain;
CORS suma esos orígenes). Sin setearlas, todo queda como hoy.

## Referencias en el código
- Build del front + copia a `public/`: `backend/bin/render-build.sh`
- Cookie JWT: `backend/config/initializers/jwt_cookie_middleware.rb`
- Logout: `backend/app/controllers/users/sessions_controller.rb#destroy`
- CORS: `backend/config/initializers/cors.rb`
- URL del WebSocket: `frontend/src/lib/cable.js`
