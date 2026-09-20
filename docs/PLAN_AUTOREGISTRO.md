# Plan: auto-registro con prueba de 30 días (sólo uso personal)

> Acordado con Germán el 20-sep-2026 y **pospuesto**: se hace cuando él lo levante. Este
> documento deja el plan armado para no volver a pensarlo. Nada de esto está implementado.

## La decisión

- **Sólo para uso personal.** Una organización NO se registra sola: deja sus datos y la creamos
  nosotros desde el super admin (formulario «Quiero Cultivo Espacial para mi organización» que
  manda un mail a Germán y guarda la solicitud).
- **La prueba nace pelada:** plan `personal`, `features = Club::FEATURES_PERSONAL` (sólo
  Cultivo). Sin ambiente/IoT, sin IA, sin chatbot, sin registro por voz (cae solo: depende del
  flag `ia`). Lo que quiera sumar, lo activa Germán después.
- **30 días** (`plan_trial: true`, `plan_activo_hasta: hoy + 30`). **Día 31 se corta** con
  cartel «Tu prueba terminó» + botón «Escribinos» (WhatsApp/mail). Cobrar online queda para
  después: la activación es manual desde el super admin (`plan_trial: false`, fecha nueva).
- **Verificación de mail obligatoria** antes de crear nada: frena las cuentas basura.

## Lo que ya existe y se reusa

- `Club#plan_trial`, `Club#plan_activo_hasta`, `PlanVencimientoJob` (push + mail 7 días antes
  y el día), `AccesoMailer` (mail de plataforma), `Clubs::SembrarPersonal` (arma el cultivo de
  una persona), `Club#crear_usuarios_default!` con `login_para` (entra con su mail), la
  suspensión en `ApplicationController` (modelo para el corte), el token de restablecer
  contraseña (se reusa para verificar el mail: **cero columnas nuevas en `users`**).

## Lo que falta (en orden)

1. **Infra (Germán, antes de tocar código):** `APP_HOST` en Render — sin eso los links por
   mail apuntan a localhost. SMTP de plataforma funcionando (`SMTP_*`, `MAIL_FROM`).
2. **Backend público** (`app/controllers/public/registro_controller.rb`):
   - `POST /public/registro` {nombre, email, password, acepta_terminos} → guarda un
     `User` **sin club** con `confirmado_at: nil`… *(alternativa sin columna: guardar la
     solicitud en `solicitudes_registro` con el token, y crear User+Club recién al verificar —
     **recomendada**: no quedan usuarios huérfanos si nunca verifica)*.
   - `GET /public/registro/verificar?token=` → crea Club personal + User + siembra
     (`SembrarPersonal`), inicia sesión y redirige a `/m/personal/hoy`.
   - `POST /public/contacto` {nombre, organizacion, email, telefono, mensaje} → tabla
     `solicitudes_contacto` + mail a Germán.
   - rack-attack: 3 registros/hora por IP, 5 contactos/hora.
   - Mail repetido → «ya hay una cuenta con ese mail: entrá o recuperá la contraseña».
3. **El corte** en `ApplicationController`, al lado de la suspensión: `club.plan_trial &&
   club.plan_vencido?` → 402 `{ error: 'prueba_vencida' }`; el front muestra el cartel
   (`PruebaVencidaView`) con «Escribinos». El super admin ya lista «quedaste en hacer»; sumar
   «prueba vencida, no activó» con el mail a mano.
4. **Landing** (`/bienvenida`): dos botones. «Probar 30 días gratis» → `/registro` (form de 3
   campos + términos). «Para mi organización» → `/contacto`. Página `/registro/verificado` y
   `/registro/revisa-tu-mail`.
5. **Términos de uso** (no es código): texto de Germán, con la línea «para uso personal según
   REPROCANN». Va antes de abrir la puerta.

## Impacto en DB

- `solicitudes_registro` (nombre, email, password_digest, token, expira_el, verificada_at).
- `solicitudes_contacto` (nombre, organizacion, email, telefono, mensaje, atendida_at).
- Nada en `users`/`clubs`.

## Tests que tienen que existir

- Registro → mail → verificar → club personal SIN flags (`features == FEATURES_PERSONAL`),
  `plan_trial`, `plan_activo_hasta == hoy + 30`, usuario admin con su mail.
- Token vencido / usado dos veces / mail repetido.
- Día 31: cualquier endpoint de la app devuelve 402 `prueba_vencida`; `/me` sigue contestando
  (para que el cartel sepa quién es).
- rack-attack en los tres endpoints.
- Aislamiento: el club nuevo no ve nada de otro (test de tenant, como todo endpoint nuevo).
