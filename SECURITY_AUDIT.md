# SECURITY_AUDIT.md — Cultivo Espacial / Club Cultivo

**Tipo:** Relevamiento de seguridad profundo, **READ-ONLY** (no se modificó código de la app).
**Fecha:** 2026-06-25
**Alcance:** `backend/` (Rails 7.2 API), `frontend/` (Vue SaaS), `web-publica/`, `mobile/` (Capacitor). Deploy en Render detrás de Cloudflare.
**Datos en juego:** datos sensibles de salud (historia clínica, diagnósticos, indicaciones médicas), DNI, datos de contacto de pacientes/socios.
**Marco legal aplicado:** Ley 25.326 (arts. 9 seguridad, 12 transferencia internacional, 16 supresión/habeas data) y Res. AAIP 47/2018 (datos sensibles → **nivel reforzado**: cifrado at-rest + registro de accesos).

> **⚠️ Actualización julio 2026 — varias filas de abajo quedaron viejas:**
> - **ENC-01 (cifrado at-rest): RESUELTO.** `Paciente` y `User` ya usan `encrypts` en todos los
>   campos de salud + DNI (`dni`/`dni_normalizado`/`reprocann_numero` **determinísticos** por el
>   índice único). Las filas que dicen "`paciente.rb` sin `encrypts`" son de la foto del 25-jun.
> - **AUTH-01 (secreto JWT): RESUELTO.** `config/initializers/devise.rb` toma el secreto solo de
>   `ENV['DEVISE_JWT_SECRET_KEY']` **sin fallback** (raise al boot).
> - **AZ — hallazgo nuevo, ya REMEDIADO:** además de AZ-01/02/03, `pacientes#show/#index`
>   exponían la historia clínica a roles con lectura de la ficha (dispensador) porque el
>   serializer sólo excluía `notas_clinicas`. Fix: **allowlist** de campos + `authorize` +
>   `PacientePolicy` por rol (`ROLES_CLINICA = admin/medico/supervisor`; super_admin/dispensador
>   fuera). Cubierto por `spec/requests/paciente_historia_clinica_leak_spec.rb`.
> - **Pendiente real:** TEN-01b (jobs sin `ActsAsTenant.with_tenant`) y la rotación de claves de
>   cifrado en prod.

> **Nota metodológica:** cada hallazgo tiene evidencia `archivo:línea`. Donde la realidad del código difiere de lo asumido en `CLAUDE.md` / notas previas, se marca explícitamente en la sección *Realidad vs. asumido*. Los hallazgos de auth/autz/cifrado críticos se verificaron a mano además del relevamiento automatizado.

---

## 0. Estado de remediación (2026-06-25)

| ID | Estado | Cambio |
|---|---|---|
| **AUTH-01** | ✅ **Remediado** | `devise.rb`: eliminado el fallback `'temporary_secret_for_dev'`. El secreto JWT sale sólo de `ENV['DEVISE_JWT_SECRET_KEY']`; si falta o está vacía, la app **falla fuerte al boot** (`raise`). Verificado: bootea con ENV, raise sin ENV. (Nota: `application_cable/connection.rb:19-20` tenía un fallback a `credentials.devise_jwt_secret_key` que es **nil** → ahora código muerto porque el boot garantiza la ENV; conviene simplificarlo en una pasada futura.) |
| **AZ-01** | ✅ **Remediado** | `indicacion_medica_controller.rb`: `require_medico_or_admin` ahora aplica a **todas** las acciones (se quitó el `except:` que eximía `index/show/prescripcion_pdf`). |
| **AZ-02** | ✅ **Remediado** | `patient_documents_controller.rb`: agregado `before_action :require_medico_or_admin` + método privado. |
| **AZ-03** | ✅ **Remediado** | `paciente_notas_controller.rb`: blocklist → **allowlist** (sólo médico/admin). |

| **ENC-01** | ✅ **Remediado (cifrado activo)** | Active Record Encryption configurado (`application.rb`, claves por ENV con fail-fast en prod). `encrypts` aplicado a: **Paciente** (dni/dni_normalizado/reprocann_numero determinísticos; email, telefono y todo el bloque clínico no-determinístico), **IndicacionMedica** (patologia/dosificacion/via/observaciones), **PatientDocument** (contenido_html + DNIs de firma), **User** (dni/phone). Migración `grupo_sanguineo`→text. Búsqueda de DNI pasó a exacta (`pacientes_controller`). Verificado a nivel DB (columnas en ciphertext, lectura descifra, búsqueda+uniqueness OK). Suite: **808 examples, 0 failures**. |

**Pendiente de despliegue ENC-01 (acción de Germán):**
1. **Generar claves de PRODUCCIÓN** en el entorno prod (no se generan acá para no exponerlas): `docker compose exec backend rails db:encryption:init` (o `bin/rails`), y cargar las 3 (`primary_key`, `deterministic_key`, `key_derivation_salt`) como env vars en Render: `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`. **Sin ellas la app no arranca** (por diseño).
2. Deploy → correr el **backfill**: `rails encryption:backfill` (re-cifra los datos reales existentes; idempotente).
3. En una deploy posterior, endurecer: `support_unencrypted_data = false` en `application.rb`.

**Custodia crítica:** perder las claves = datos sensibles irrecuperables. Backup seguro de las 3 env vars de prod.

**ENC-01b (follow-up, no bloqueante):** `nombre`/`apellido` (búsqueda LIKE por nombre) y `domicilio_*`/`envio_*` (lógica de envíos) quedaron en texto plano a propósito. Evaluar cifrarlos con blind-index o aceptando búsqueda exacta.

| **TEN-01** | ✅ **Remediado (core)** | `acts_as_tenant` (gem) aplicado a **42 modelos de dominio** con `club_id`. Tenant fijado en el ciclo del request (`ApplicationController#set_tenant_from_current_user`): usuarios de club → auto-scope por `club_id`; super_admin/público/webhooks → sin tenant. `require_tenant=false` (aditivo, no rompe jobs). Genéticas globales vía `has_global_records`. Uniqueness global de DNI (REPROCANN) preservada. Plant: `set_club_id` movido a `before_validation`. Tests nuevos: `spec/models/tenant_isolation_spec.rb`. Suite: **812 examples, 0 failures**. `users` excluido a propósito (auth/super_admin). |

**Decisión tomada (TEN-01, require_tenant=false):** la defensa en profundidad queda en la capa de requests (donde ocurren los IDOR de usuarios). El flip a `require_tenant=true` se difiere (ver TEN-01b).

**TEN-01b (follow-up de hardening, NO hecho — alto riesgo):** poner `require_tenant=true` para que cualquier query a un modelo de club sin tenant *crashee* (en vez de quedar sin scope). Requiere cirugía por-job: de los 18 jobs, **8 iteran todos los clubes** (vencimientos, ariccame, informes, stock, alertas, tareas, reservas, postcosecha) y deben envolver cada club en `ActsAsTenant.with_tenant(club){…}`; el resto setear tenant desde su arg o usar `without_tenant`. También afecta endpoints públicos, rake tasks, seeds y consola. Beneficio marginal (la capa de requests ya está defendida) vs blast-radius alto → hacerlo como proyecto dedicado con su pasada de tests.

**Decisión tomada (supervisor):** queda **afuera** del acceso clínico. Supervisor es rol de cultivo ("lectura de cultivo + gestión de tareas"); la historia clínica no está en su dominio (mínimo privilegio + nivel reforzado AAIP 47/2018). Acceso clínico = **médico + admin** únicamente.

**Tests:** nuevo `spec/requests/clinica_authz_spec.rb` (médico/admin → 200; cultivador/supervisor/manicura/dispensador/delivery/abogado → 403; cross-club → 404). Suite de requests completa: **504 examples, 0 failures**.

**A revisar (impacto front):** cualquier UI de un rol distinto a médico/admin que renderice indicaciones / documentos / notas de paciente ahora recibirá **403**. El candidato más probable es **abogado** (lee socios). Las notas de **sala/lote** (cultivo) NO se vieron afectadas — usan otro controller. Decidir si abogado necesita lectura clínica.

---

## 1. Resumen ejecutivo

El sistema tiene una base de autenticación bien construida (JWT en cookie httpOnly, denylist de revocación, throttling de login, force_ssl) pero presenta **fallas críticas en protección de datos sensibles de salud** que lo ponen en incumplimiento directo del nivel reforzado de la Res. AAIP 47/2018 y del art. 9 de la Ley 25.326: **todos los datos clínicos y DNI se guardan y se loguean en texto plano**, y **el acceso a la historia clínica NO está restringido a médico/admin** como se asumía. También hay un **fallback de secreto JWT hardcodeado** que, de faltar la ENV en producción, permite forjar tokens de cualquier rol.

### Conteo de hallazgos por severidad

| Severidad | Cantidad | IDs |
|---|---|---|
| **Crítico** | 4 | AUTH-01, AZ-01, AZ-02, ENC-01 |
| **Alto** | 9 | TEN-01, AZ-03, AUTH-05, LOG-01, AUD-01, RET-01, ENC-02, HDR-01, DEP-01 |
| **Medio** | 8 | PUB-01, AZ-04, AZ-05, ENC-03, FE-01, AI-02, COOKIE-01, DEP-02 |
| **Bajo** | 9 | IDOR-01, SQLI-01, SEC-01, DOCKER-01, AI-01-res, RATE-01, INFO-pw, COOKIE-02, SQLI-misc |
| **OK / Positivo (verificado)** | — | JWT httpOnly, denylist, bcrypt, rack-attack login, master.key untracked, no secrets en git, sin VITE secretos, AI sin datos de salud |

**Los 4 a cerrar antes de onboardear pacientes reales:** ENC-01 (salud en texto plano at-rest), LOG-01 (salud/DNI en logs), AZ-01/AZ-02 (clínica accesible por todo rol), AUTH-01 (secreto JWT forjable).

---

## 2. Tabla de hallazgos

| ID | Sev | Archivo:línea | Descripción | Norma |
|---|---|---|---|---|
| **AUTH-01** | Crítico | `config/initializers/devise.rb:321` | Secreto JWT con fallback hardcodeado: `ENV.fetch('DEVISE_JWT_SECRET_KEY', 'temporary_secret_for_dev')`. Si la ENV falta en prod, los tokens se firman con un string público → forja de JWT de cualquier user/rol. | 25.326 art.9 |
| **AZ-01** | Crítico | `app/controllers/indicacion_medica_controller.rb:3` | Indicaciones médicas: `require_medico_or_admin` excluye `:index, :show, :prescripcion_pdf`. Cualquier rol autenticado (cultivador, dispensador, delivery, manicura, abogado, auditor) lee patología/dosificación/vía y genera el PDF de prescripción. | 25.326 art.9; AAIP 47/2018 |
| **AZ-02** | Crítico | `app/controllers/patient_documents_controller.rb:1-4` | Documentos clínicos (incl. firmados) sin gate de rol: sólo `authenticate_user!` + `set_paciente`. Todo rol del club lee/descarga `#index`/`#show`. | 25.326 art.9; AAIP 47/2018 |
| **ENC-01** | Crítico | `db/schema.rb:761-789, 515-522, 824-829`; `app/models/paciente.rb` (sin `encrypts`) | Todos los campos de salud y DNI en **texto plano at-rest**: `dni`, `notas_clinicas`, `anamnesis`, `diagnostico_principal/secundario`, `evolucion_clinica`, `alergias`, `medicacion_habitual`, `grupo_sanguineo`, `patologia`, `dosificacion`, firmas/DNI en `patient_documents`. Único `encrypts` del repo es `dispositivo.rb:6` (metadata IoT, no sensible). | 25.326 art.9; AAIP 47/2018 (nivel reforzado) |
| **TEN-01** | Alto | `app/models/*.rb` (sin `acts_as_tenant`) | Aislamiento multi-tenant 100% manual: ningún modelo scopea por `club_id` a nivel modelo (los `default_scope` son sólo soft-delete/orden). Cualquier `Model.find(params[:id])` nuevo filtra/edita datos de otro club. Hoy los controllers samplados scopean bien, pero sin red de seguridad. | 25.326 art.9 |
| **AZ-03** | Alto | `app/controllers/paciente_notas_controller.rb:32-35` | Notas clínicas usan **blocklist** (`%w[dispensador delivery]`) en vez de allowlist → cultivador/manicura/supervisor/abogado/auditor leen y crean notas de paciente. | 25.326 art.9 |
| **AUTH-05** | Alto | `config/initializers/cors.rb:14-22` | CORS con `credentials: true` y orígenes desde `FRONTEND_URL` + `EXTRA_CORS_ORIGINS` (split por coma, sin validación). Sin `*`, pero cualquier valor inyectado en esa ENV se confía con credenciales. Verificar el valor real en prod. | — |
| **LOG-01** | Alto | `config/initializers/filter_parameter_logging.rb:6-8` | Filtro de logs cubre `passw/email/secret/token/_key/crypt/salt/certificate/otp/ssn`. **Faltan** `dni`, `documento`, `telefono/phone`, `direccion/domicilio/envio`, `notas_clinicas`, `diagnostico*`, `anamnesis`, `patologia`, `dosificacion`, `reprocann_numero`, etc. → payloads clínicos completos en logs en cada create/update de paciente. | 25.326 art.9; AAIP 47/2018 |
| **AUD-01** | Alto | `app/models/concerns/auditable.rb`; sólo en `app/models/movimiento_contable.rb` | Existe tabla `auditorias` y concern `Auditable`, pero sólo se incluye en contabilidad. **No** está en `Paciente`/`IndicacionMedica`/`PatientDocument`/`User`. Además sólo loguea create/update/destroy, no **lecturas**. No hay registro de accesos a datos sensibles. | AAIP 47/2018 (registro de accesos) |
| **RET-01** | Alto | `app/models/paciente.rb:2` (`acts_as_paranoid`) | Borrado sólo soft (`deleted_at`); DNI + historia clínica persisten indefinidamente. No hay mecanismo real de purga/`really_destroy!` expuesto → no se puede cumplir un pedido de supresión. | 25.326 art.16 (habeas data) |
| **ENC-02** | Alto | `config/application.rb`, `config/environments/production.rb` (sin keys) | Active Record Encryption aparenta **no estar configurado** (`config.active_record.encryption.*` ausente). El único `encrypts` (dispositivo.metadata) rompería en runtime si faltan las keys en credentials. | 25.326 art.9 |
| **HDR-01** | Alto | (ausente en `backend/app` y `backend/config`) | Sin headers de seguridad a nivel app: no hay CSP, X-Frame-Options/frame-ancestors, X-Content-Type-Options, Referrer-Policy, Permissions-Policy; sin gema `secure_headers`. HSTS sólo implícito por `force_ssl`. | 25.326 art.9 |
| **DEP-01** | Alto | `backend/Gemfile.lock` | 62 advisories Ruby. **rack@3.1.16** = 17 advisories (5 High: directory traversal CVE-2026-22860, DoS multipart). **jwt@3.1.2** CVE-2026-45363 (HMAC empty-key bypass, toca auth). **devise@4.9.4** CVE-2026-32700/40295. Rails→7.2.3.1 limpia 9 CVEs. | — |
| **PUB-01** | Medio | `app/controllers/public/base_controller.rb:9-12` | `@current_club ||= Club.first`. El sitio público sirve datos de Club.first sin importar el subdominio → con un segundo club, el público de B muestra contenido de A. (Coincide con "web pública multi-club pendiente".) | — |
| **AZ-04** | Medio | `app/controllers/paciente_turnos_controller.rb:1-2` | Turnos sólo `authenticate_user!`, sin gate de rol → cualquier rol del club lee turnos de cualquier paciente. | 25.326 art.9 |
| **AZ-05** | Medio | `app/controllers/historial_controller.rb:1-2` | Timeline global sólo `authenticate_user!`, sin gate de rol; puede exponer datos cross-módulo a roles de bajo privilegio. Revisar qué serializa. | 25.326 art.9 |
| **ENC-03** | Medio | `app/models/club.rb:193-201` | Token Twilio usa `message_verifier` (firma, NO cifra) pese a columna `twilio_auth_token_enc`. Legible por cualquiera con acceso a DB. Usar `message_encryptor`/`encrypts`. | — |
| **FE-01** | Medio | `frontend/src/lib/offlineApi.js:10-34` | Cache offline guarda **socios** (`cc_cache_socios`), stock y salas en localStorage texto plano (TTL 24h). En dispositivo compartido/perdido, lista de pacientes legible por cualquier JS same-origin. Mitiga parcialmente `stores/auth.js:131` (`localStorage.clear()` en logout). | 25.326 art.9 |
| **AI-02** | Medio | `app/controllers/asistente_controller.rb:506,535`; `app/services/analisis_lote_service.rb:113` | Transferencia internacional a `api.anthropic.com` (US) sin salvaguarda documentada (cláusulas contractuales / aviso de privacidad). Hoy el payload es sólo cultivo (bajo riesgo), pero la transferencia ocurre. | 25.326 art.12; AAIP 47/2018; Disp. 60-E/2016 |
| **COOKIE-01** | Medio | `config/initializers/session_store.rb:4-9` | Cookie de sesión `_club_session` con `same_site: :none` + `domain: :all` + `partitioned: true` (superficie CSRF amplia). La app es API/JWT, la sesión Rails casi no se usa para auth → evaluar removerla o angostarla. | — |
| **DEP-02** | Medio | `web-publica/package-lock.json`, `frontend/package-lock.json` | Runtime: **axios** (web-publica, ~24 advisories: prototype-pollution, SSRF NO_PROXY, MITM proxy, leak Proxy-Auth en redirect) y **dompurify** (frontend, bypass de sanitización). El resto de High/Critical npm son build/dev (vite, vitest, esbuild, tar vía Capacitor CLI). | — |
| **IDOR-01** | Bajo | `app/controllers/super_admin/users_controller.rb:8,20,29` | `Club.find`/`User.find` sin scope — pero es super_admin (cross-club por diseño), gateado por `require_super_admin!`. Aceptable, se nota por completitud. | — |
| **SQLI-01** | Bajo | `app/models/lectura_ambiental.rb:45` | `Arel.sql("...'#{medido_at}'::timestamptz...")` interpola un atributo. No explotable (validado como timestamp), pero es la única interpolación a SQL; parametrizar. | — |
| **RATE-01** | Bajo | `app/controllers/asistente_controller.rb:279-280` | `rate_limited?` rescata a `false` → ante fallo de Redis, el rate-limit del asistente IA falla **abierto** (costo/abuso, no fuga de datos). | — |
| **SEC-01** | Bajo | git history (`974fdc3`, `2b2c4a4`) | `.env` commiteados en el pasado (contenido benigno: `UID/GID`, `VITE_API_URL`). No tracked hoy, sin secretos. Normaliza mala práctica. | — |
| **DOCKER-01** | Bajo | `docker-compose.yml:8,32,53` | Credenciales inline `POSTGRES_PASSWORD: postgres` (sólo dev). Asegurar que prod no reusa este compose. | — |
| **INFO-pw** | Bajo | git history (`Club::PASSWORD_DEFAULT = '123456Aa'`) | Password default débil para usuarios sembrados/creados. Forzar reset-on-first-login. | — |
| **COOKIE-02** | Bajo (positivo) | `config/initializers/jwt_cookie_middleware.rb:27-32` | Cookie auth `jwt_token`: `httponly:true`, `secure` en prod, `same_site:Lax`, 12h. Correcto. | — |

---

## 3. Realidad vs. asumido

Correcciones al estado documentado en `CLAUDE.md` y notas previas:

| Tema | Asumido / documentado | Realidad en el código |
|---|---|---|
| **Aislamiento multi-tenant** | "Multi-tenancy es manual; todo query scopeado por `club_id`" | ✅ **Correcto y verificado**. Ningún modelo enforce tenancy (sin `acts_as_tenant`/`default_scope` de club); depende 100% de disciplina en controllers. Los ~50 controllers autenticados samplados scopean bien vía `current_user.club.<assoc>`. **No se encontró IDOR cross-club explotable en rutas autenticadas.** El riesgo es estructural (un scope olvidado = fuga total) — TEN-01. |
| **Acceso a historia clínica** | "Restringido a médico/admin" | ❌ **Falso**. Indicaciones médicas (`:index/:show/:prescripcion_pdf`), documentos clínicos (todo), notas (blocklist), turnos: **accesibles por casi todo rol del club**. AZ-01/02/03/04. |
| **Auth JWT** | Bien construido | ✅ Mayormente: cookie httpOnly + denylist + throttle de login + expiración 12h. ❌ Pero AUTH-01: fallback de secreto hardcodeado. |
| **Cifrado de datos sensibles** | (implícito: se protege salud) | ❌ Salud y DNI en **texto plano** at-rest. Único `encrypts` es metadata IoT no sensible. ENC-01/02. |
| **Asistente IA → Anthropic** | (riesgo: ¿manda datos de salud?) | ✅ **No envía datos de paciente/salud/DNI**: el contexto es sólo cultivo (lote, cepa, ambiente, plantas, alertas). "REPROCANN" sólo aparece como string de persona. Residual: el transcript de voz se manda verbatim (AI-01-res), y la transferencia internacional carece de salvaguarda formal (AI-02). API key sólo ENV server-side, nunca al cliente ni a logs. |
| **JWT en frontend** | (riesgo: ¿localStorage?) | ✅ **httpOnly cookie**, no localStorage (purgado explícitamente, `api.js:14-17`). XSS-safe. Mobile usa Bearer (esperado para Capacitor). |
| **Pundit** | "parcial" | ✅ Confirmado parcial: policies para ~10 recursos, sólo 5 controllers llaman `authorize`/`policy_scope`. **Sin `verify_authorized` after_action** → controller que olvida el gate falla abierto (causa raíz de AZ-01/02). |
| **Auditor read-only** | "bloqueado en ApplicationController" | ✅ **Verificado**: `application_controller.rb:29-35` (`block_auditor_writes!`) bloquea todo no-GET para auditor. Modo observador idem (`:37-43`). Sólido. |
| **Mass assignment** | — | ✅ Limpio: **cero** `permit!` en todo el repo; strong params consistentes. |
| **Secrets en git** | — | ✅ `master.key` y `credentials.yml.enc` NO tracked (gitignored). Sin `sk-ant`/secretos en historial. Sin VITE_ sensibles (sólo URLs + VAPID pública). |
| **rack-attack** | (¿existe?) | ✅ Configurado: login 5/min/IP, webhooks, gate DNI dispensa 10/min, asistente 30/min, genérico 300/5min. Deshabilitado en test (correcto). |

---

## 4. Plan de remediación priorizado

### Tanda 0 — Antes de onboardear pacientes reales (bloqueante legal)
1. **AUTH-01** — Quitar el fallback del secreto JWT: `ENV.fetch('DEVISE_JWT_SECRET_KEY')` sin default (fail-fast) o desde credentials; rotar el secreto en prod. *(~30 min)*
2. **AZ-01 / AZ-02** — Agregar gate de rol médico/admin a indicaciones (`:index/:show/:prescripcion_pdf`) y a `patient_documents` (todas las acciones). *(~1-2 h)*
3. **LOG-01** — Sumar al `filter_parameters` todos los campos de salud + DNI + contacto. Bajo costo, alto impacto. *(~30 min)*
4. **ENC-01 / ENC-02** — Configurar Active Record Encryption (keys en credentials) y aplicar `encrypts` a columnas sensibles de `Paciente`/`IndicacionMedica`/`PatientDocument`/`User`. Requiere migración de datos existentes + decidir determinístico (para buscar por DNI) vs no. **Tocar schema → requiere aprobación explícita de Germán.** *(~1-2 días, incl. backfill)*

### Tanda 1 — Alta prioridad (semana 1)
5. **AZ-03 / AZ-04 / AZ-05** — Convertir blocklist→allowlist en notas; gate de rol en turnos e historial. *(~2-3 h)*
6. **AUTH-05** — Validar/whitelistear orígenes CORS; auditar el valor real de `EXTRA_CORS_ORIGINS` en prod. *(~1 h)*
7. **HDR-01** — Agregar `secure_headers` (o `default_headers`): CSP, X-Frame-Options, nosniff, Referrer-Policy. *(~half-day)*
8. **DEP-01** — `bundle update` dirigido: rack, jwt, devise, puma, faraday, addressable, nokogiri, sidekiq-cron + Rails→7.2.3.1. Correr specs. *(~half-day)*
9. **AUD-01** — Incluir `Auditable` en modelos clínicos; diseñar registro de **accesos** (lecturas) a datos sensibles. *(~1-2 días)*

### Tanda 2 — Cumplimiento y hardening (semanas 2-3)
10. **RET-01** — Mecanismo real de supresión (`really_destroy!` controlado + política de retención) para habeas data. *(~1 día)*
11. **TEN-01** — Adoptar tenancy a nivel modelo (`acts_as_tenant`) como defensa en profundidad + unificar un base controller tenant-aware. **Cambio arquitectural transversal — proponer plan antes.** *(~2-3 días)*
12. **AI-02** — Documentar transferencia internacional: cláusulas contractuales + aviso de privacidad; opcional, scrubbing del transcript de voz. *(~1 día + legal)*
13. **PUB-01** — Resolución real de club por subdominio en `Public::BaseController` antes del segundo club. *(~half-day)*
14. **FE-01 / ENC-03 / COOKIE-01 / DEP-02** — No cachear socios en localStorage (o cifrar/acotar); migrar Twilio a `message_encryptor`; evaluar remover `_club_session`; actualizar axios/dompurify. *(~1-2 días en conjunto)*

### Tanda 3 — Bajo / higiene
15. **SQLI-01, RATE-01, SEC-01, DOCKER-01, INFO-pw** — Parametrizar el `Arel.sql`; decidir fail-closed en rate-limit del asistente; limpiar prácticas de `.env`; separar compose de prod; forzar reset de password default. *(~medio día)*

---

## 5. Notas sobre la auditoría de dependencias

- **bundler-audit 0.9.3** corrió contra `ruby-advisory-db` actualizado (1165 advisories, 2026-06-24). **npm audit** corrió online en los 3 proyectos JS. Sin fabricación de CVEs.
- Conteos: backend 62 (9 High), frontend 15 (1 Critical/7 High), web-publica 9 (4 High), mobile 5 (4 High).
- La mayoría de High/Critical de npm son **build/dev-only** (vite, vitest, esbuild, babel, tar vía Capacitor CLI). Los **runtime** que importan: `axios` (web-publica) y `dompurify` (frontend).
- Outputs crudos en el scratchpad de la sesión (`bundle_audit.txt`, `fe_audit.json`, `wp_audit.json`, `mob_audit.json`).

---

*Relevamiento read-only. No se aplicó ningún fix — sólo diagnóstico y plan. Los ítems marcados "tocar schema" o "cambio arquitectural" requieren aprobación explícita antes de implementar.*
