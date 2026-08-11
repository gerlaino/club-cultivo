---
titulo: La ficha clínica del paciente
roles: [medico, admin]
modulo: Módulo médico
orden: 10
---

La ficha del paciente es **una sola**, con solapas. No hay una pantalla aparte por tema: todo lo
de una persona está en su ficha.

- **Historia clínica** — anamnesis, antecedentes, diagnósticos, evolución, alergias, medicación.
- **Indicaciones** — arriba muestra lo que viene retirando (90 días, promedio mensual y una curva).
  Es el contexto con el que se prescribe.
- **Documentos** — recetas, certificados, estudios. Quedan cifrados y con firma.
- **Turnos** y **dispensaciones**, para ver.

> La historia clínica la ven **médico, administrador y supervisor**. El **dispensador no**: en el
> mostrador no se necesita y son datos de salud.

### Duración y vencimiento de una indicación
Si cargás una **duración en días**, el sistema **propone** un vencimiento. Si escribís la fecha a
mano, **manda la tuya** — antes la duración pisaba lo que escribías sin avisar. El formulario te
dice cuál de las dos está mandando.

Una indicación **sin fecha de vencimiento no genera alertas**, y la lista te lo marca. Si querés
que el sistema avise, ponele fecha.
