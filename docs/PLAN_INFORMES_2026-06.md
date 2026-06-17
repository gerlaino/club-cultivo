# Plan — Sistema de informes profesionales

**Fecha:** 2026-06-14 · **Autor:** Claude (arquitectura)
**Objetivo:** que todo lo que la app exporta (PDF y tabular) salga con identidad de marca, calidad documental y cobertura pareja — pasar de "captura de pantalla en PDF" a "documento que un club presenta ante ARICCAME/REPROCANN sin pedir disculpas".

---

## 1. Diagnóstico (estado actual)

**Cómo se generan hoy los PDF:** cada vista arma su propio PDF desde el HTML de la pantalla con `html2pdf.js` (cliente). Consecuencias:
- Cada informe se ve como su pantalla: sin encabezado institucional, sin pie, sin paginación real, tipografía de UI.
- `html2pdf` pesa ~281 kB en el bundle y corre en el navegador del usuario (lento con tablas largas, cortes de página impredecibles).
- No hay identidad de marca ni datos legales del club (CUIT, resolución REPROCANN) en los documentos.

**Cobertura despareja** (relevado del código):
- Tienen PDF: informes auditor (reprocann, producción, dispensaciones, sedes, cumplimiento), trazabilidad, informe semestral, analítica.
- Solo CSV: pacientes, dispensaciones, contabilidad, lotes, plan de trabajo.
- Sin export: comparativa de analítica, "Plan vs Real", dashboard contable, rendimiento del cultivador.
- Documentos individuales (prescripción, docs de paciente con firma, carnet, etiquetas) van por caminos propios.

**Lo bueno que ya existe y hay que conservar:**
- `patient_documents.hash_documento` + firma digital → base lista para verificación.
- Carnet público con QR (`/c/:token`) → el patrón de "documento verificable" ya está probado.
- Vocabulario legal correcto (aporte/recupero) en contabilidad.

---

## 2. Decisiones de arquitectura (requieren tu elección)

### Decisión A — ¿Dónde y con qué se generan los PDF?

| Opción | Qué es | Ventajas | Desventajas |
|---|---|---|---|
| **A1. Server-side HTML→PDF** (Grover/Puppeteer headless Chrome) | El backend renderiza una plantilla ERB con CSS y la convierte a PDF | Control total de marca, paginación real, mismo HTML/CSS que ya sabemos escribir, fuentes web | Suma Chrome al contenedor de Render (~300 MB, más memoria); hay que vigilar consumo |
| **A2. Server-side Prawn** (Ruby puro) | PDF programático, dibujado por código | Sin dependencias de sistema (ideal para Render), liviano, pixel-perfect, ideal para documentos legales | Más código por informe; gráficos/tablas complejas son más trabajo |
| **A3. Cliente con plantilla** (seguir con html2pdf pero con layout de marca dedicado) | Mantener generación en el browser, pero con un componente "hoja membretada" reutilizable | Cero cambio de infra, rápido de implementar | Sigue el peso en el bundle y los cortes de página flojos; techo de calidad más bajo |

**Recomendación:** **A2 (Prawn) para los informes legales/oficiales** (REPROCANN, semestral, trazabilidad, dispensaciones — los que ve un inspector) + **A1 o A3 para los visuales con gráficos** (analítica). Prawn es lo más robusto en Render y lo correcto para documentos de cumplimiento; los informes con charts pueden quedar en cliente. Si querés un solo motor para todo, **A1** es el mejor equilibrio calidad/esfuerzo (asumiendo el costo de Chrome en el contenedor).

### Decisión B — ¿Formato tabular: CSV o Excel?

| Opción | Ventajas | Desventajas |
|---|---|---|
| **B1. XLSX** (gema `caxlsx`) | Encabezados con color, anchos, formato moneda/fecha, panel congelado, logo en hoja 1, varias hojas | Un poco más de código que CSV |
| **B2. Seguir con CSV** | Ya está hecho | Texto plano, sin formato, sin marca |

**Recomendación:** **B1 (XLSX)** para los exports operativos, con CSV como opción secundaria "datos crudos". Es el salto de "profesional" más visible en lo tabular.

### Decisión C — ¿Verificación de autenticidad?

Agregar a cada documento oficial un **QR + código de verificación** que apunte a un endpoint público (`/verificar/:codigo`) mostrando: club emisor, tipo de documento, fecha, hash y validez. Reutiliza la infra de hash existente.

**Recomendación:** **Sí.** Es barato (ya tenés hash + el patrón del carnet) y es un diferenciador real: ningún competidor entrega documentos verificables. Un inspector escanea y confirma que el papel no fue adulterado.

---

## 3. Arquitectura propuesta (común a todas las opciones)

1. **Capa de documentos unificada** en el backend:
   - `app/documents/base_document.rb` — encabezado institucional (logo + nombre + CUIT + resolución REPROCANN + sede), pie con paginación + fecha de emisión + usuario + QR de verificación. **Todos** los informes heredan de acá.
   - Un documento por informe (`ReprocannDocument`, `ProduccionDocument`, …) que solo define el cuerpo.
2. **Datos desde servicios, no desde controllers**: cada informe tiene un *query/service* que arma los datos (hoy parte vive inline en controllers). Eso permite reusar la misma data para PDF, XLSX y pantalla — una sola fuente de verdad por informe.
3. **Endpoints consistentes**: `GET /informes/:tipo.pdf` y `GET /informes/:tipo.xlsx` para cada informe. El frontend solo cambia el formato pedido.
4. **Branding por club**: el encabezado lee el logo y datos legales del club (depende de resolver antes el **storage persistente** — ver nota abajo).

> ⚠️ **Bloqueante previo:** el logo y datos institucionales en los PDF dependen de que el logo persista. Hoy el storage es efímero en Render (ver pendiente abierto). **Hay que resolver el storage antes** de que los documentos puedan llevar el logo del club de forma confiable.

---

## 4. Plan por fases

**Fase 0 — Prerrequisito:** resolver storage persistente (decisión ya pendiente: disco Render vs S3/R2).

**Fase 1 — Fundaciones (1 entregable):**
- Elegir motor (Decisión A) e instalar.
- `BaseDocument` con membrete + pie + QR de verificación.
- Endpoint público de verificación.
- Migrar **1 informe piloto** (REPROCANN, el más sensible) como prueba del molde.

**Fase 2 — Informes oficiales:** migrar al molde producción, dispensaciones, sedes, cumplimiento, trazabilidad, semestral. Todos con PDF profesional + verificación.

**Fase 3 — Tabular profesional (Decisión B):** `caxlsx`, migrar los 5 exports operativos a XLSX con hoja membretada; CSV queda como secundario.

**Fase 4 — Cobertura pareja:** agregar export a lo que hoy no tiene (comparativa analítica, Plan vs Real, dashboard contable, rendimiento cultivador).

**Fase 5 — Documentos individuales:** unificar prescripción médica, docs de paciente y etiquetas bajo el mismo `BaseDocument` (consistencia total de marca).

---

## 5. Qué necesito de vos para arrancar

1. **Decisión A** (motor PDF): ¿Prawn para legales + cliente para visuales (recomendado), o un solo motor A1 (Chrome) para todo?
2. **Decisión B** (tabular): ¿XLSX con caxlsx (recomendado) o seguir con CSV?
3. **Decisión C** (verificación QR): ¿la incluimos? (recomiendo sí)
4. **Storage** (Fase 0): disco persistente de Render o object storage — esto destraba el logo en los documentos.

Con eso defino el primer entregable concreto (Fase 1) y empezamos por el informe REPROCANN como piloto.
