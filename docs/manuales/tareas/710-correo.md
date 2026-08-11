---
titulo: Conectar el correo de la organización
roles: [admin]
modulo: Configuración
orden: 20
---

Para poder mandarle mails a los pacientes, la organización conecta **su propia casilla**.

1. Entrá a **Configuración → Preferencias → Correo**.
2. Cargá el **email** y una **contraseña de aplicación** — no la contraseña normal de la cuenta.
   En Gmail se genera desde la configuración de seguridad, con verificación en dos pasos activada.
3. Opcionalmente, el nombre que verá quien reciba el mail.
4. Guardá.

El servidor y el puerto **se detectan solos** para Gmail, Outlook y Yahoo. Si usás otro proveedor,
te va a pedir el servidor SMTP.

**Verifica antes de guardar**: manda un mail de prueba a esa misma casilla y sólo si llega guarda
los datos. Si falla, te muestra el error del servidor tal cual — así se ve si es la contraseña o
la dirección.

> Mientras no esté conectado, el módulo de correo figura como *"no funciona todavía"* y la ficha
> del paciente no deja enviar mails.
