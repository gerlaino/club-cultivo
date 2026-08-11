---
titulo: Dar de alta un paciente
roles: [admin, medico, dispensador]
modulo: Pacientes
orden: 10
---

1. Entrá a **Pacientes** y tocá **Nuevo paciente**.
2. Cargá lo obligatorio: **nombre**, **apellido**, **DNI** y **fecha de nacimiento**.
3. Si ya tiene REPROCANN, cargá el **número** y la **fecha de vencimiento**.
4. Guardá.

**El DNI es único en toda la plataforma, no sólo en tu organización.** Si al guardar te dice que
ya está registrado, esa persona figura en otra organización: bajo REPROCANN nadie puede estar en
dos a la vez. Hablalo con la administración antes de insistir.

### Estados del REPROCANN

| Estado | Qué significa |
|---|---|
| Activo | Certificado aprobado y vigente |
| En trámite | Presentado, esperando resolución |
| Vencido | Se le pasó la fecha |
| Sin registro | Todavía no lo inició |

El sistema cruza el estado con la fecha: un certificado **activo cuyo vencimiento ya pasó** se
muestra como **vencido**, aunque nadie lo haya cambiado a mano. Un trámite **en trámite** no se
pisa aunque esté vencido — significa que hay una renovación en curso.
