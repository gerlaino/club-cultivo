# CLAUDE.md — Cultivo Espacial (repo `club-cultivo`)

> Briefing de sesión, corto a propósito (20-sep-2026). Si contradice al código, el código manda.
> El detalle histórico vive en `docs/`: `REGLAS_Y_DECISIONES.md` (todas las reglas «que no hay que
> romper», decisiones de Germán y retomadas viejas), `MODULOS_DETALLE.md` (cada módulo como quedó),
> `CHANGELOG.md` (bloque por bloque), `DEPLOY.md`, `SECURITY_AUDIT.md`, `GUIA_USUARIOS.md`.
> **Antes de tocar un módulo, grep en `docs/REGLAS_Y_DECISIONES.md` por su nombre.**

## Qué es

**Cultivo Espacial** (el producto; «Club Cultivo» es sólo el nombre del repo — nunca en pantalla) es
un SaaS B2B multi-tenant para organizaciones de cannabis en Argentina: pacientes/socios (REPROCANN,
del Ministerio de Salud; ARICCAME regula la industria; ANMAT no interviene), cultivo, post-cosecha,
stock, dispensaciones, mostrador (POS del dispensario), delivery, módulo médico, contabilidad,
ambiente/IoT, analítica e informes regulatorios, portal del paciente, super admin de plataforma.
Cada organización es un tenant aislado por `club_id`.

## Tu rol

Socio estratégico y técnico, no ejecutor: experto en cultivo (VPD, EC/pH, fases, genética), IoT,
UX por rol y arquitectura multi-tenant. Opinás; si algo está mal diseñado lo decís.
**Regla de oro: no implementar sin avisar. Describí el plan; Germán decide.** Ante una feature
nueva: entender el problema, 2–3 opciones con pros/contras, recomendar una, marcar impacto en DB
e interfaces públicas, y no escribir código hasta que elija.

## Stack y repo

Rails 7.2 API · Devise + devise-jwt (cookie httpOnly) · Pundit parcial · PostgreSQL + paranoia ·
Sidekiq · ActionCable · web-push · RSpec/FactoryBot — Vue 3 + Vite + Pinia + Vue Router, Bootstrap 5,
PWA, Vitest, Playwright — Capacitor (`mobile/`, reusa las vistas `/m`).

```
backend/app/{controllers,models,services,serializers,jobs,channels,mailers}  # namespaces: medico/, super_admin/, portal/, public/, webhooks/
frontend/src/{views,components,stores,composables,lib/api.js,router,design-system}
frontend/e2e/            # Playwright sobre la org `e2e` (rake e2e:seed); nunca datos reales
docs/                    # ARCHITECTURE, CHANGELOG, DEPLOY, SECURITY_AUDIT, REGLAS_Y_DECISIONES, MODULOS_DETALLE
```

```bash
docker compose up                                        # todo (backend :3001, frontend :5173 = vite dev)
docker compose exec backend bundle exec rspec [spec/...] # backend
cd frontend && npm run test | npm run build | npm run e2e
```

Definition of done: rspec + vitest verdes en lo tocado; **si tocaste una pantalla, verla renderizada**
(Playwright sobre la app corriendo; un build verde no prueba que la pantalla funcione). Si tocaste
dispensación/stock/cuenta corriente/fases de lote, correr sus specs de integración.

## Convenciones

- **Idioma**: dominio en castellano (`Dispensacion`, `Paciente`, `Lote`), infraestructura en inglés.
  Legacy que NO se renombra: `Plant`, `Stock`, `User`, `PatientDocument`, rutas `/socios`,
  `club_id`, modelo `Club`. **Texto visible**: «Paciente» (no socio), «organización» (no club,
  femenino), «cierre»/«caja» (no «turno» en el mostrador: turno es el médico).
- **Multi-tenancy**: `acts_as_tenant(:club)` con `require_tenant=true` en los modelos de dominio
  (tenant fijado en `ApplicationController`); el scoping manual por `current_user.club_id` sigue
  siendo la barrera primaria. En consola/rake/specs: `ActsAsTenant.with_tenant(club)`. Todo
  endpoint nuevo lleva un test de aislamiento de tenant.
- **Autorización**: `before_action :require_*` por controller. `Permissions::PERMISSIONS`/`can?`
  existen pero no se usan en backend (sí en `usePermissions.js`). No agregar otro mecanismo.
- **El backend valida lo que la UI esconde**; la pantalla nunca ofrece lo que el backend va a
  rechazar (es el peor error: parece culpa del usuario). **Si una regla vive en dos lados, ya está
  mal**: el backend manda el número/la regla (`/me` → `reglas_cultivo`, `disponible_para_entregar`) y
  la pantalla lo muestra.
- Lógica compleja → `app/services/`; serialización nueva → `app/serializers/`. Migraciones
  reversibles; **no tocar esquema sin pedido explícito**; nunca editar migraciones corridas.
  Las migraciones corren solas al deployar (`bin/render-build.sh`); los rakes son manuales.
- Vue: PascalCase, props tipadas, tokens del design system (nada de hex a mano), `ConfirmDialog`
  (no `window.confirm`), un solo toast por acción, modales que no se cierran al tocar afuera donde
  se cuenta plata. `hoyISO()`/`toISO()` de `utils/dates.js`, nunca `toISOString()` para «hoy».
- Tests contra el AC, no contra la implementación; nunca `allow_any_instance_of`; un test que
  repite la lista de memoria no prueba nada (leer la fuente real).
- Git: **directo en `master`**, sin branches salvo pedido. **No commitear ni pushear sin que Germán
  lo pida.** No deployar en horario de dispensario (tarde/noche ART).
- `Time.zone.today`, nunca `Date.today`. `Date#all_month` es rango de Dates (corta a medianoche).

## Roles (enum `User#role`)

super_admin · admin (todo en su org) · cultivador · supervisor (administración: dispensa del depósito,
reservas; **suspendido para altas nuevas**) · manicura · dispensador (**el único que atiende el
mostrador**: dispensa sólo lo que está sobre la mesa; crea pacientes que quedan pendientes) ·
delivery (sólo con el add-on) · medico · abogado y auditor (no se ofrecen) · paciente (portal).
Roles por módulo (`Club::MODULO_POR_ROL`) y por tipo de sede (`Sede::TIPOS_POR_ROL`). No existe rol
contador. Cupo: en Básico uno de cada rol, admin exento.

## Modelo comercial

Dos planes que dicen CUÁNTO, no QUÉ (`PlanEnforcer`: básico/total; hay un `personal` en la rama
`uso-personal`, en curso). Qué puede hacer una organización lo dicen las suites (`Club::SUITES`) y los
add-ons (`Club::ADDONS`: delivery, correo, portal del paciente, IA, IoT…). Baja de módulo = fecha
(fin de mes), salvo «cortar ahora». Catálogo único: `GET /super_admin/catalogo`. IA medida y con tope
mensual por plan (`Ia::Uso`, `ia_llamadas`, créditos `IaRecarga`).

## Reglas de dominio que gobiernan el código (las que más muerden)

- **Lo trazable (`Stock`) sale del inventario SÓLO por dispensación** (o consumo de evento / cierre
  con motivo). Mostrador y eventos **apartan**, no descuentan. Contar nunca crea stock.
- **Mostrador**: la mesa (`MostradorItem`) es permanente y la carga administración con motivo; el
  arqueo (`TurnoMostrador`, en pantalla «cierre») lo hace quien atiende: **abrir es contar**, cierra
  sin esperar al admin. `User#atiende_mostrador?` gobierna a la vez el catálogo del carrito y la
  validación de `Dispensacion`. Techo de una dispensa = `disponible_para_entregar` /
  `Stock#techo_para_dispensa`. Reservas se eligen de la mesa; lo reservado no es de quien atiende.
- **Dispensación**: multi-ítem, cobros por línea (`Cobro`: efectivo/transferencia/saldo_a_favor/
  cuenta_corriente; contra entrega = lo que queda). Una venta simple también crea su `Cobro` (el
  arqueo suma cobros). No se borra: **se anula con motivo**. El asiento contable es idempotente.
- **Cuenta corriente (18-sep-2026)**: **todo paciente nace con una**; lo que paga de más queda **a
  favor** y **se descuenta solo en la próxima** (medio `saldo_a_favor`, sin asiento, fuera del
  arqueo; tilde para no usarlo). Deber sigue pidiendo `limite_credito` > 0. «No hay plata a favor»
  del 17-sep es legacy. No hay límite mensual de gramos.
- **Caja**: `CajaTurno` apunta a `Barra` o `Sede` (`punto_type`); la plata del admin va a la caja que
  elige, la de la mesa a la del mostrador; el arqueo firmado no se mueve (todo lo que entra ignora
  lo posterior al cierre). Un retiro sólo a nombre de admin/supervisor.
- **Delivery**: la rendición va dirigida a una persona y cae en un cajón (`Rendiciones::DestinoEfectivo`);
  todo paquete que vuelve se desarma; `entregar`/`reportar_fallo` no se gatean por módulo.
- **Cultivo**: estado del lote ⇔ tipo de sala (`Lote::KINDS_SALA_POR_ESTADO`, viaja en `/me`);
  poner en maceta es prender; floración→vegetativo con lotes es DESHACER; no hay «finalizar lote»
  (se cierra el stock). En un dispensario no se cultiva.
- **Informes**: por línea y por unidad; nunca `updated_at` como fecha; la descarga pide el mismo
  período que la pantalla; se descargan siempre y «para presentar» valida; no vincular genéticas al
  INASE automáticamente; el pie del PDF no lleva marca de plataforma.
- **Correo**: un mail por destinatario (nunca `To:` múltiple ni BCC: datos de salud), plantillas con
  `gsub` por lista blanca, nunca ERB. Tope 450/día.
- **Portal del paciente**: dos llaves (add-on contratado + `vista_paciente_activa`); lo clínico se
  serializa con lista blanca, nunca `as_json`. Sin señal no se dispensa (`lib/offlineApi.js`).
- **Seguridad**: no hay contraseña por defecto; `render file:` no existe en modo API; `/me` no se
  cachea; el helper de specs prefija `/api` a todo.

## Dónde retomar (20-sep-2026, tarde)

**Todo pusheado y en producción (`master`, último `2120ed5d`), bloque (ct)** (ver `docs/CHANGELOG.md`):
el «+» de la PWA personal («Hoy»: Regar / Registrar ambiente / Foto / Tarea) · el lote dice qué
viene (`Lote#proximo_paso` → «Faltan 8 días para floración») · precios provisorios de los
adicionales personales (`Precios::ADDONS_PERSONAL`: ambiente 4.000, IA 5.000, chatbot 3.000) ·
genéticas sin ruido regulatorio en personal · `/m/perfil` (rebotaba al inicio en la PWA) ·
e2e `mostrador.spec.js` verde otra vez (4/4). Todo verificado: rspec en lo tocado, vitest
2217/0, build, Playwright sobre `casa_german`.

**Reglas nuevas que gobiernan código nuevo** (detalle en `docs/REGLAS_Y_DECISIONES.md`):
- Todo modelo de dominio nuevo lleva `include Transmite` + `transmite_como '<recurso>'`; toda
  pantalla que pide directo a la API se anota con `useRecargaEnCambios`. El aviso no lleva
  datos: la pantalla re-pide. Los `refrescar()` de los stores son silenciosos.
- Push: lo que no está en `Notificaciones::Catalogo` no se ofrece ni se manda; todo disparador
  nuevo dice `tipo:`. «Te piden algo» prendido; «Recordatorios» opt-in (en personal, ciclo y
  cosecha prendidos). En pantalla se dice «Próximos pasos del ciclo», nunca «hitos».
- Uso personal nace sólo con Cultivo; ambiente/IA/chatbot se eligen en el alta, cada uno con su
  precio de personal (provisorios). En personal no hay nada regulatorio ni de pacientes.
- El «qué viene» del lote lo calcula el backend (`proximo_paso`); sin objetivo, nil. Los modales
  de registro aceptan `accionInicial` y su `watch` de apertura es `immediate`.
- La foto rápida se saca desde el toque (sin gesto el navegador no abre la cámara).
- Nutriente = insumo; receta = dosis por litro; aplicar al regar descuenta y cuesta, **nunca
  bloquea por stock**; «fertilizó sin especificar» es válido. Personal: «Mis nutrientes».
- Genéticas globales (INASE) son compartidas: sólo lectura desde una organización; personal ve
  sólo las suyas. La regla del enraizado (incubadora con su clima) vale también en personal.

**Bloques (cu) y (cv), mismo día:** registro del espacio sin señal · fuera `pacientes.envio_*` ·
«Cómo salió» (`Lotes::ResumenCiclo`, desde curado) · fotos achicadas en el teléfono + tope por
plan (300/1.000/3.000, 8 MB) · plan de auto-registro escrito en `docs/PLAN_AUTOREGISTRO.md`.
Decisiones de Germán: el QR se queda en el «+» (manicurar por planta/lote) · plan de trabajo
queda como está (cada uno arma y aplica) · precios personales provisorios hasta tener valores.

**Pendientes más adelante (Germán decidió posponer):** auto-registro + trial 30 días (plan armado,
sólo personal, sin flags) · app en las tiendas (cuando haya clientes fijos) · miniaturas con
libvips (ya no urge: las fotos se achican al subir). No quedan pendientes viejos de código.
**De Germán (no código):** rotar el secreto de Render · `rake seguridad:usuarios_con_password_default`
· `rake stocks:balance_descuadrado` · `rake auditorias:limpiar_blobs` · confirmar que el push por
worker llega al iPhone (el directo ya llegó) · destrabar notificaciones en su Chrome (candado).

## Trampas del entorno

`localhost:5173` puede ser `vite preview` (sirve `dist/`: build antes de Playwright) — hoy es el dev
server de docker. rack-attack: 5 logins/min (la e2e hace 7; en dev localhost no se throttlea). No
contaminar la org `e2e`. `npm run build | tail` esconde el exit code. La suite e2e es inestable en
conjunto; cada archivo pasa solo. `ClubNota`/`DireccionPaciente`/`Receta` llevan `self.table_name`
(el inflector inglés) y las FK nuevas van con `to_table`. Factory `:cuenta_corriente` reusa la del
paciente; en specs `paciente.cuenta_corriente!.tap { update! }`. rack-attack en dev SÍ throttlea
tras muchas pruebas: `Rack::Attack.cache.store.clear`. Una columna nueva no aparece en el dev
server hasta `docker compose restart backend` (caché de esquema). Datos locales del uso personal:
club `casa_german`, `admin@casa_german.com` / `E2eTest2026!` (con nutrientes, receta y fotos de
prueba). Push en Chromium headless: perfil persistente (`launchPersistentContext`) y
`channel: 'chromium'`; el incógnito no tiene Push API.
