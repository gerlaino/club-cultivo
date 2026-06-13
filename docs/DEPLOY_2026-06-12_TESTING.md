# Deploy 2026-06-12 — Resumen de cambios y plan de testing

**Estado de suites:** Backend 571/571 ✅ · Frontend 58/58 ✅ · Build de producción ✅

---

## PARTE 1 — Qué cambió

### A. Seguridad: el JWT ya no se expone al JavaScript
- **Antes:** el login devolvía el token en el header `Authorization` y el frontend lo guardaba en `localStorage` — cualquier XSS podía robarlo.
- **Ahora:** para web, el token viaja **solo** en la cookie httpOnly. El frontend ya no lo lee ni lo guarda (y limpia el que hubiera quedado en localStorage). La **app mobile no cambia**: manda `X-Mobile-Client` y sigue recibiendo el header.
- Archivos: `jwt_cookie_middleware.rb`, `frontend/src/lib/api.js`.
- ⚠️ **Efecto post-deploy:** usuarios con sesión vieja cuya cookie haya expirado van a tener que loguearse de nuevo una vez. Normal.

### B. Contabilidad de caja con deuda visible
- Dispensación a crédito (`cuenta_corriente` / `no_abona`) → asiento **"A crédito"** (`pagado: false`) que **no suma a los ingresos**. El ingreso real entra cuando el socio paga (aporte). Se eliminó el doble conteo.
- Pagar en **efectivo/transferencia ya no debita la cuenta corriente** (antes generaba deuda fantasma si el socio tenía límite configurado).
- Asientos generados por dispensaciones: **no se editan ni borran a mano** (ícono 🔗 lo indica); se corrigen desde la dispensación. Borrar la dispensación borra su asiento.
- Borrar un **aporte de socio revierte el crédito** que había acreditado. Cambiarle el monto está bloqueado (se borra y recarga).
- Nuevo KPI **"Por cobrar"** en el dashboard contable (suma de deudas reales de socios) y botón eliminar en "últimos movimientos".
- Abogado ya no ve botones de edición que el backend le rechazaba.

### C. Crédito en gramos — terminado de cablear
Estaba a medio hacer (del 10/06): los métodos existían pero nada los llamaba y el medio de pago no era válido. Ahora: dispensar con `credito_gramos` valida crédito activo y saldo, debita gramos, y al eliminar la dispensación los devuelve.

### D. Manicura consolidada en una sola entrada
- El sidebar ahora tiene **una sola entrada: "Manicura"** (la vista de pesajes diarios, ahora centrada — tenía un bug de CSS). El badge suma pesajes pendientes + lotes del flujo viejo.
- "Aprobaciones" salió del sidebar. Si quedan lotes del flujo anterior esperando aprobación, aparece un **banner ámbar** en Manicura que lleva a la vista vieja (que ahora aclara que es legacy). Cuando no quede ninguno, el banner desaparece solo.
- **Guard anti doble stock:** un lote que ya generó stock por pesajes confirmados no se puede aprobar por el flujo viejo (duplicaría los gramos).
- Fix de bug crítico: la asociación `pesajes_manicura` apuntaba a una clase inexistente → la **finalización automática del lote nunca había funcionado**. Ahora al confirmar el último pesaje (todas las plantas cubiertas), el lote se finaliza solo.
- *Pendiente próximo bloque:* migrar el cierre del manicurista al flujo nuevo y eliminar el estado `manicura_pendiente` definitivamente.

### E. Planes de trabajo: quitar planes aplicados
- Nueva sección **"Planes aplicados"** en Planes de trabajo: lista con objetivo, fecha, progreso, historial, y botón **"Quitar"** (cancela tareas pendientes/en progreso, conserva completadas).
- Aplicar un plan **desde el detalle de un lote** ahora también registra la aplicación (antes era invisible e imposible de revertir).

### F. Varios
- **Chip del club** (logo + nombre) en el TopBar del admin, a la izquierda del breadcrumb. Sin logo → avatar con iniciales.
- **Toggles de crédito y descuento** en Cuenta Corriente del socio: arreglados (no encendían cuando el valor era 0).
- Campo "Límite de dispensación mensual" **eliminado** del modal de edición de socio (decisión: no es una feature en uso).
- `CLAUDE.md` reescrito + informes en `docs/` (`INFORME_INGENIERIA`, `INFORME_UX_ROLES`, `INFORME_CONTABILIDAD`).

### G. Cambios tuyos pre-existentes que entran en este mismo commit
Estaban sin commitear en el working tree (los respeté): reversa de stock por nota en `Dispensacion#incrementar_stock`, timeout de 10s en Axios, y reload automático del service worker en `main.js` (⚠️ recomendé cambiarlo por un toast — puede recargar en medio de un form).

### Notas de deploy
1. Correr `rails db:migrate` (hay una migración tuya del 10/06 que estaba pendiente en test: índice único de `numero_lote_producto` por club).
2. El `frontend/dist/` tenía archivos de root (build viejo dentro de Docker) — ya lo limpié; si el build de Render falla por permisos, es eso.
3. No hay migraciones nuevas mías — cero cambios de schema.

---

## PARTE 2 — Plan de testing manual

> Preparación: entorno levantado (`docker compose up`), logueado como **admin**. Tené a mano un paciente con cuenta corriente y un stock con precio configurado.

### T1. Login y seguridad del token (5 min)
1. Abrí DevTools → pestaña Network. Hacé login.
2. ✅ En la respuesta de `sign_in`: **no** debe haber header `Authorization`; en `Set-Cookie` debe estar `jwt_token` con `HttpOnly`.
3. DevTools → Application → Local Storage: ✅ **no** debe existir `jwt_token`.
4. Navegá la app, recargá la página (F5): ✅ la sesión se mantiene.
5. Logout → ✅ vuelve al login y no podés navegar atrás a vistas privadas.
6. **Mobile:** abrí la app Android y logueate. ✅ Debe funcionar igual que siempre.

### T2. Identidad del club (2 min)
1. Mirá el TopBar: ✅ logo + nombre del club a la izquierda del breadcrumb.
2. Configuración del club → borrá el logo → ✅ aparece avatar con iniciales.
3. Achicá la ventana (< 640px): ✅ queda solo el logo, sin nombre.

### T3. Dispensaciones — los 4+1 medios de pago (15 min, el más importante)
Para cada caso, anotá el saldo de CC del paciente ANTES (pestaña Cuenta Corriente).

**a) Efectivo:**
1. Dispensá 5g en efectivo a un paciente CON crédito configurado.
2. ✅ Contabilidad → Libro: aparece el asiento con estado "✓ Pagado".
3. ✅ Cuenta corriente del paciente: **sin cambios** (no se generó deuda). ← *esto antes fallaba*
4. ✅ KPI "Ingresos este mes" subió por el monto.

**b) Cuenta corriente:**
1. Dispensá 5g con medio "cuenta corriente".
2. ✅ Libro: asiento con estado **"A crédito"** y el ícono 🔗 en lugar de editar/borrar.
3. ✅ KPI Ingresos: **NO** subió. ✅ KPI "Por cobrar": apareció/subió por el monto.
4. ✅ CC del paciente: saldo bajó por el monto, movimiento de débito en el historial.

**c) No abona:** igual que (b). Si el paciente no tiene crédito configurado → ✅ error claro antes de confirmar.

**d) Crédito insuficiente:** dispensá por más del margen disponible → ✅ error "Crédito insuficiente", sin asiento ni débito.

**e) Crédito en gramos** (si lo usás): activá crédito en gramos al paciente con saldo p.ej. 100g.
1. Dispensá 10g con medio crédito_gramos → ✅ saldo en gramos baja a 90.
2. Dispensá 200g → ✅ error "gramos insuficientes".

### T4. Pago de deuda y reversas (10 min)
1. Con la deuda de T3-b: Contabilidad → Nuevo movimiento → Ingreso / "Aporte socio" / mismo monto / elegí el paciente.
2. ✅ CC del paciente: la deuda se canceló (saldo volvió). ✅ KPI Ingresos subió AHORA (una sola vez en todo el ciclo). ✅ "Por cobrar" bajó.
3. **Borrá ese aporte** desde el libro → ✅ pide confirmación, y la CC vuelve a mostrar la deuda (crédito revertido).
4. **Borrá la dispensación** de T3-b (historial → eliminar) → ✅ el asiento "A crédito" desaparece del libro, el stock vuelve, y la CC queda en cero (deuda revertida).
5. Intentá **editar** un asiento generado por dispensación vía API o UI → ✅ no hay botón; si forzás por API, 422 con mensaje claro.

### T5. Manicura consolidada (10 min)
1. Sidebar → Operaciones: ✅ hay UNA entrada "Manicura" (no más "Aprobaciones"). El badge muestra pendientes.
2. Entrá a Manicura: ✅ la vista está **centrada**. Si hay lotes del flujo viejo → ✅ banner ámbar "N lotes del flujo anterior esperando aprobación".
3. Click en el banner → vista de Aprobaciones con la nota de "flujo anterior". Aprobá tu lote pendiente → ✅ genera stock y finaliza. Al volver a Manicura → ✅ el banner desapareció.
4. **Flujo nuevo completo:** como manicurista, registrá pesajes diarios de un lote hasta cubrir todas las plantas. Como admin confirmá cada uno. ✅ Al confirmar el último, el lote pasa solo a "finalizado" (esto nunca había funcionado). ✅ El stock acumuló los gramos confirmados.
5. **Guard anti doble stock:** con un lote con pesajes confirmados, intentá aprobarlo por el flujo viejo → ✅ error "ya generó stock a través de pesajes".

### T6. Planes de trabajo (5 min)
1. Planes de trabajo → aplicá una plantilla a un lote (con el modal o desde el detalle del lote).
2. ✅ Aparece en la nueva sección "Planes aplicados" con progreso y tareas creadas.
3. Completá una tarea del plan → ✅ el % de progreso sube.
4. **"Quitar"** → confirmación → ✅ tareas pendientes canceladas en el calendario, las completadas siguen. Con "Ver historial" → ✅ la aplicación figura como "cancelado".

### T7. Cuenta corriente — toggles (3 min)
1. Paciente sin crédito → pestaña Cuenta Corriente → tocá el toggle de crédito.
2. ✅ Se enciende y aparece el input vacío ← *antes no pasaba nada*. Cargá un monto → Guardar → ✅ persiste.
3. Mismo test con el toggle de **descuento**. Apagá el toggle → Guardar → ✅ queda en 0/sin descuento.

### T8. Editar socio (2 min)
1. Detalle de socio → Editar.
2. ✅ Ya NO existe el campo "Límite de dispensación mensual". El descuento por defecto sigue estando.

### T9. Regresión rápida (10 min)
- Dispensación **con envío** (delivery): crear → iniciar viaje → entregar. ✅ Estados y notificaciones como siempre.
- Export CSV de dispensaciones y de movimientos contables. ✅ Abren bien.
- Dashboard admin: ✅ tarjetas y links funcionan (la de aprobaciones lleva a la vista legacy si hay pendientes).
- Una pasada por: Lotes, Plantas, Salas, Stock, Analítica. ✅ Sin errores en consola del navegador.
- Login como **auditor**: ✅ entra, ve informes, no puede escribir. Como **abogado**: ✅ no ve botones de edición en ningún lado.

---

*Si algo de T3/T4 no da como se describe acá, no deployes y avisame: es el corazón financiero.*

---

# Anexo — Lote 2026-06-13 (4 pendientes grandes)

**Estado:** Backend 582/582 ✅ · Frontend 58/58 ✅ · Build ✅
**Migraciones nuevas:** `clubs.contabilidad_cerrada_hasta` y tabla `auditorias`. Correr `rails db:migrate`.

## Qué cambió

**1. Service worker — toast en vez de reload automático.** Al haber nueva versión aparece un banner abajo ("Hay una nueva versión — Actualizar"); recién al tocar el botón se actualiza y recarga. Nunca recarga solo en medio de un formulario.

**2. Manicura: flujo viejo eliminado.** Cuando el manicurista pesa un lote (en cualquier estado: en_manicura o secado), ahora **siempre** se crea un pesaje en la cola única de "Manicura" para confirmar. El estado `manicura_pendiente` ya no se genera. Lotes en "secado" pasan automáticamente a "en_manicura" al pesarlos. La vista "Aprobaciones" queda solo para lotes viejos que ya estaban en ese estado.

**3. Costos del lote derivados del libro contable.** Cargar un egreso en Contabilidad con un lote asignado actualiza automáticamente el CostoLote de ese lote (insumos / energía / mano de obra según categoría). En la card de costos del lote hay un botón **"Desde libro"** para recalcular a demanda. El P&L por lote ya no requiere doble carga.

**4. Cierre de período + auditoría.** En el dashboard de Contabilidad (admin) hay una barra para **cerrar el período** hasta fin del mes anterior: los movimientos de fechas cerradas quedan inmutables (no se crean, editan ni borran). Botón **Reabrir** para levantarlo (queda auditado). Cada create/update/delete de movimiento se registra en la tabla de auditoría con usuario y cambios.

## Testing — bloques nuevos

### T10. Service worker (requiere 2 deploys o build nuevo)
1. Con la app abierta, deployá una versión nueva. ✅ Aparece banner abajo, **sin recargar solo**.
2. Empezá a cargar un formulario largo, esperá el banner. ✅ El form no se pierde hasta que vos toques "Actualizar".
3. Tocá "Actualizar" → ✅ recarga con la versión nueva.

### T11. Manicura — flujo único (15 min)
1. Como manicurista, pesá un lote en **en_manicura**. ✅ No finaliza solo: queda un pesaje "enviado". Como admin, andá a **Manicura** → ✅ está el pesaje para confirmar → confirmá → ✅ genera/acumula stock.
2. Como manicurista, pesá un lote en **secado**. ✅ El lote pasa a "en_manicura" y se crea el pesaje en la misma cola (antes iba a "Aprobaciones"). Confirmalo desde Manicura.
3. Completá todas las plantas de un lote vía pesajes confirmados. ✅ Al confirmar el último, el lote pasa a "finalizado" solo.
4. ✅ Pesar sin peso (0g) → error claro.
5. Si tenés algún lote viejo en "manicura_pendiente": ✅ el banner ámbar en Manicura te lleva a Aprobaciones para terminarlo. Si no hay ninguno, no aparece banner.

### T12. Costos desde el libro (8 min)
1. Contabilidad → cargá un egreso categoría **Insumo** con un lote asignado, $5.000. Repetí con **Electricidad** $3.000 al mismo lote.
2. Andá al detalle del lote → card de Costos. ✅ Insumos $5.000, Energía $3.000, Total $8.000 (sin haberlos tipeado en el lote).
3. Editá los costos a mano y guardá → ✅ se respeta lo manual. Tocá **"Desde libro"** → ✅ vuelve a los valores del libro.
4. Borrá el egreso de Insumo en Contabilidad → volvé al lote → ✅ Insumos bajó a $0.

### T13. Cierre de período (10 min)
1. Contabilidad → dashboard (como admin). ✅ Barra "Sin cierre de período" con botón "Cerrar hasta [fin mes anterior]".
2. Cargá un movimiento con fecha del mes pasado. Cerrá el período → ✅ confirma y la barra pasa a "Libro cerrado hasta…".
3. Intentá editar/borrar ese movimiento del mes pasado → ✅ no hay botones (candado 🔒); por API daría 422.
4. Cargá un movimiento con fecha **de hoy** → ✅ funciona (posterior al cierre).
5. Intentá cargar uno con fecha **dentro del período cerrado** → ✅ error "período cerrado".
6. Tocá **Reabrir** → ✅ los movimientos vuelven a ser editables.
7. Intentá eliminar una **dispensación** cuyo asiento cae en período cerrado → ✅ error claro (no se puede).
8. (Opcional, rol no-admin) Un cultivador no ve la barra de cierre y el endpoint le da 403.

*Como antes: si T11/T12/T13 tocan algo financiero o de stock y no da como se describe, frená y avisame.*
