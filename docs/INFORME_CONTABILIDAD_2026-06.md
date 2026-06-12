# Informe — Módulo de Contabilidad
**Fecha:** 2026-06-12 · **Autor:** Claude (análisis de código: `MovimientoContable`, `CostoLote`, `CuentaCorriente`, controllers, `ContabilidadView`, `ModalNuevoMovimiento`, analytics P&L)

> **Estado (2026-06-12, mismo día):** Germán aprobó la semántica de **caja con deuda visible** y se implementaron los pasos 2, 3, 4, 7 y 8 del plan (C1, C2, C3, E3 y P1 resueltos; specs en `spec/requests/contabilidad_caja_spec.rb`). Quedan pendientes: **#5 unificar costos** (CostoLote vs libro) y **#6 cierre de mes + versionado** (requiere migración).

## Resumen ejecutivo

Tu intuición es correcta. El módulo funciona bien como **registro de caja con dashboard** (los KPIs, el desglose por sede, el CSV y el modal de carga están bien resueltos), pero **no es todavía un sistema contable confiable**: hay un caso de doble conteo de ingresos, dos sistemas de costos paralelos que no se hablan, movimientos automáticos editables que pueden divergir de la operación real, y cero inmutabilidad/auditoría. Ninguno de estos problemas se ve en el dashboard — se ven el día que un contador externo o un auditor cruza los números.

---

## Hallazgos críticos (afectan la veracidad de los números)

### C1. Doble conteo de ingresos con cuenta corriente ⚠️ el más grave
Cuando se dispensa con medio `cuenta_corriente` o `no_abona`:
1. Se crea un `MovimientoContable` tipo `recupero_costo` (cuenta como **ingreso**) con **`pagado: true` hardcodeado** — aunque el socio no pagó nada.
2. Se debita la cuenta corriente del socio (correcto).
3. Cuando el socio después paga su deuda, el admin registra un movimiento `aporte_socio` — que **también cuenta como ingreso** (está en `CATEGORIAS_INGRESO`) y además acredita la CC.

Resultado: **la misma plata entra dos veces al libro**. Un socio que dispensa $10.000 a crédito y luego los paga genera $20.000 de ingresos contables. El balance del mes/año está inflado en exactamente el monto del circuito de crédito.

### C2. El débito de cuenta corriente aplica a TODOS los medios de pago
`DispensacionesController#create`: si el paciente tiene límite de crédito configurado, se debita su CC **aunque pague en efectivo**. O sea: paga $5.000 cash (ingreso al libro, correcto) y además le queda una deuda de $5.000 en su cuenta corriente. Si después "salda" esa deuda fantasma con un aporte → otro ingreso (vuelve C1). El comentario del código dice que es deliberado ("Debitar crédito para todos los medios de pago") — **necesito que me confirmes la intención**, porque tal como está, un paciente con crédito configurado que paga en efectivo acumula deuda por cosas que ya pagó.

### C3. Los movimientos automáticos son editables y borrables sin restricción
- El botón Editar de `ContabilidadView` aplica a cualquier movimiento, incluidos los generados por dispensaciones. Editarle el monto a uno de esos lo desincroniza para siempre de la dispensación que lo originó.
- `movimientos_contables#destroy` (API) permite borrar el ingreso de una dispensación dejando la dispensación viva — el espejo exacto del problema que ya detectaste (borrar dispensación deja el ingreso, por el `dependent: :nullify`).
- Peor: **editar o borrar un `aporte_socio` no revierte el crédito** que ese aporte le dio a la cuenta corriente del socio (el `after_create :acreditar_cuenta_corriente` solo corre al crear). Borrás el aporte del libro y el socio se queda el crédito gratis.

### C4. El tipo `ajuste` es invisible en todos los totales
Los scopes son `ingresos = [ingreso, recupero_costo]` y `egresos = [egreso]`. Un movimiento tipo `ajuste` no entra en ninguno: no afecta KPIs, ni balance, ni dashboard, ni P&L. Existe en el formulario, se puede cargar… y no hace nada. O se le da semántica (con signo) o se elimina del vocabulario.

---

## Hallazgos estructurales

### E1. Dos sistemas de costos paralelos que no se reconcilian
- El **libro** registra egresos (insumo, electricidad, sueldo…) con `lote_id` opcional.
- `CostoLote` registra costos del lote (insumos, energía, mano de obra) **cargados a mano, por separado**.
- El P&L por lote de analytics usa **solo `CostoLote`**, ignorando los egresos del libro vinculados a ese lote.

Consecuencia: cargás la factura de luz en el libro, y el P&L del lote no la ve salvo que la vuelvas a tipear en CostoLote. Doble carga manual = divergencia garantizada. Es el clásico "dos fuentes de verdad" y la razón #1 por la que el módulo se siente poco profesional.

### E2. Sin cierre de período ni rastro de auditoría
Cualquier movimiento es editable para siempre, sin historial de qué cambió, quién y cuándo (solo `updated_at`). Para un dominio que rinde cuentas a auditores y a ARICCAME, esto es una carencia seria: un libro contable profesional necesita (a) **cierre de mes** que congele movimientos, y (b) **versionado** de cambios (quién tocó qué). Hoy un número del informe semestral puede cambiar retroactivamente sin dejar huella.

### E3. `MEDIOS_PAGO` del libro: constante decorativa y desalineada
`MovimientoContable::MEDIOS_PAGO = [efectivo, transferencia, mercado_pago, cheque]` **no tiene validación de inclusión** — entra cualquier string. Y de hecho entra: las dispensaciones escriben `cuenta_corriente` y `no_abona`, que no existen en ese vocabulario. Cualquier reporte futuro que agrupe por medio de pago va a encontrar categorías fantasma.

### E4. `saldo_disponible` mutable sin lock ni invariante
La CC actualiza el saldo con `update!` sin lock pesimista: dos débitos concurrentes pueden leer el mismo `saldo_anterior` (el guard anti-doble-débito ayuda con el doble POST, no con la concurrencia real). Y no hay verificación de que `saldo_disponible == suma de movimientos` — si alguna vez divergen (ver C3), nada lo detecta. Sugerencia: derivar el saldo de la suma, o al menos un job de consistencia.

### E5. `belongs_to :sede` parece obligatorio, pero el dashboard contempla "Sin sede"
El modelo no tiene `optional: true` en sede, pero el dashboard tiene una rama entera para movimientos con `sede_id: nil`. Una de dos: o hay datos legacy nulos que hoy serían inválidos (un `update` cualquiera sobre ellos falla por validación), o la rama es código muerto. A verificar.

---

## Permisos (ejemplo vivo del drift frontend/backend del informe general)

`ContabilidadView` calcula `canEdit = ["admin","abogado"]`, pero el backend solo deja **leer a admin y auditor**, y **escribir solo a admin**. Un abogado que entre ve los botones de crear/editar y recibe 403 en todo — incluso en la carga inicial de datos.

## Menores
- Dashboard `por_sede`: ~6 queries por sede en loop — con 5+ sedes se va a sentir; se resuelve con 2 `group(:sede_id)`.
- `export_csv` carga todo en memoria (`find_each` + streaming cuando crezca).
- Montos serializados con `.to_f` — para mostrar está bien; nunca calcular sobre esos floats en el frontend.
- `Date.today` vs `Time.zone.today` mezclados (riesgo de off-by-one a medianoche).

## Lo que está bien (y conviene conservar)
- El vocabulario **aporte / recupero de costo** en vez de "venta/ingreso comercial" es exactamente el encuadre legal correcto para clubes sin fines de lucro en Argentina. No lo pierdas en ningún refactor.
- Guard anti-doble-débito y reversa de CC por suma real de débitos: bien pensados.
- UX del modal de carga (categorías filtradas por tipo, placeholders por categoría, preview del balance): el mejor formulario de la app.

---

## Propuesta de mejora (en orden)

| # | Acción | Resuelve | Esfuerzo |
|---|---|---|---|
| 1 | **Decidir la semántica contable** (decisión tuya, ver abajo) | C1, C2 | — |
| 2 | Implementarla: dispensación a crédito → `pagado: false`; el cobro posterior marca `pagado: true` en vez de crear otro ingreso. Débito de CC solo para `cuenta_corriente`/`no_abona` | C1, C2 | Medio |
| 3 | Bloquear editar/borrar movimientos con `dispensacion_id` (UI + backend) + `dependent: :destroy` en `Dispensacion` + botón eliminar para movimientos manuales | C3 + tu pedido original | Bajo |
| 4 | Reversa de CC al editar/borrar un `aporte_socio` (o directamente bloquear su edición y exigir contra-asiento) | C3 | Bajo-Medio |
| 5 | Unificar costos: P&L por lote suma egresos del libro con `lote_id`; `CostoLote` pasa a calcularse desde el libro (botón "recalcular") en vez de cargarse a mano | E1 | Medio |
| 6 | Cierre de mes (campo `cerrado_hasta` en club; movimientos anteriores → solo contra-asiento) + versionado de cambios | E2 | Medio |
| 7 | Validar `medio_pago` + sumar `cuenta_corriente`/`no_abona` al vocabulario; definir o eliminar `ajuste` | E3, C4 | Bajo |
| 8 | Alinear permisos de abogado (sacarlo de `canEdit`, decidir si tiene lectura) | P1 | Bajo |

### La decisión de fondo (punto 1)
Recomiendo **contabilidad de caja con deuda visible**: ingreso al libro solo cuando entra plata real (efectivo, transferencia, aporte de socio); la dispensación a crédito registra el movimiento con `pagado: false` (deuda, visible en un KPI "por cobrar") y el cobro posterior lo salda sin duplicar. Es lo que un club chico entiende, lo que su contador externo espera, y elimina C1 y C2 de raíz. La alternativa devengada (ingreso al dispensar, cobro neutro) también es válida pero más confusa para el usuario no contador. **Elegís vos** — todo el plan 2-en-adelante depende de esta decisión.
