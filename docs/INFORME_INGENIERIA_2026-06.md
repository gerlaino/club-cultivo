# Informe de ingeniería — Club Cultivo
**Fecha:** 2026-06-12 · **Autor:** Claude (revisión de código estática, sin ejecutar la app)
**Alcance:** backend completo (controllers, modelos, services), frontend (estructura, router, flujo de dispensación), tests, documentación. Complementa la `AUDITORIA_SISTEMA.md` de mayo 2026 (que sigue siendo válida en trazabilidad y schema) — acá me enfoco en lo que esa auditoría no cubrió: calidad de implementación, seguridad de tenancy/autorización y deuda estructural.

---

## Resumen ejecutivo

La app está **funcionalmente mucho más completa de lo que su arquitectura interna puede sostener a largo plazo**. El producto cubre un dominio enorme (16 módulos, 11 roles, 3 frontends) con una sola persona detrás, y eso se nota en lo bueno (velocidad, cobertura funcional, decisiones de dominio acertadas) y en lo riesgoso: **la autorización y el aislamiento entre clubes dependen de disciplina manual repetida en ~90 controllers**, la lógica de negocio crítica (dinero y stock) vive en controllers y callbacks, y la cobertura de tests (47 specs backend para 18k líneas; 9 archivos de test para 95k líneas de frontend) no alcanza para proteger los flujos financieros.

Nada de esto es incendio hoy. Pero los tres primeros hallazgos son exactamente el tipo de deuda que en un SaaS multi-tenant con datos médicos se convierte en incidente, no en refactor.

---

## Hallazgos — severidad ALTA

### A1. Tres sistemas de autorización conviven, y el central está muerto
- `app/models/concerns/permissions.rb` define la matriz `PERMISSIONS` + `User#can?` — **`can?` no se invoca en ningún controller del backend** (verificado por grep). Es código muerto que documenta permisos que nadie hace cumplir.
- La autorización real son ~20 `before_action :require_*` ad-hoc, cada uno con su propia lista de roles hardcodeada (`require_dispensador_o_admin`, `require_criticos_role!`, `require_export_role!`, …).
- Pundit está instalado con 11 policies pero solo 5 controllers usan `authorize`/`policy_scope`.
- El frontend (`usePermissions.js`) espeja la matriz muerta, así que **lo que la UI muestra y lo que el backend permite se validan contra fuentes distintas**.

**Riesgo:** cada endpoint nuevo redefine sus permisos desde cero; un descuido = endpoint accesible por roles indebidos, y el drift UI/backend genera tanto agujeros como pantallas rotas ("veo el botón pero da 403").
**Recomendación:** elegir UN mecanismo. Mi propuesta: un `before_action` genérico en `BaseController` que consulte la matriz `PERMISSIONS` (mapeando controller→resource, action→action), excepciones vía Pundit donde haga falta lógica por registro, y borrar los `require_*` a medida que se migran. La matriz pasa a ser la fuente de verdad real y el frontend deja de mentir. Es el refactor con mejor relación costo/riesgo de todo este informe.

### A2. Multi-tenancy por disciplina manual
El scoping por `club_id` se repite a mano en cada query (`joins(stock: :sede).where(sedes: { club_id: current_user.club_id })`, `policy_scope`, scopes por modelo — tres estilos distintos). Un spot-check de los `find(params[:id])` no encontró IDOR evidente — buen trabajo — pero el patrón no es defendible cuando el sistema crece o entra otro dev.

**Recomendación (en orden de esfuerzo):**
1. **Ya:** shared example de RSpec "no expone datos de otro club" y aplicarlo a cada controller (un test barato que congela la garantía).
2. **Corto plazo:** concern `TenantScoped` con `Model.del_club(club_id)` único y consistente, o `Current.club` seteado en `BaseController`.
3. **Mediano plazo:** evaluar Row-Level Security de PostgreSQL como red de seguridad debajo del ORM (la auditoría de mayo ya lo marcó; sigue pendiente).

### A3. El flujo de dispensación: dinero y stock con doble fuente de verdad
`DispensacionesController#create` (líneas 60–115) hace pricing con descuento, validación de crédito por medio de pago, y la transacción contable. Pero el modelo `Dispensacion` **valida lo mismo de nuevo** (`credito_suficiente`, `credito_no_abona`) con reglas levemente distintas (el controller usa `cc.puede_dispensar?(monto)`, el modelo compara `saldo_disponible + limite_credito`). Dos implementaciones de la misma regla financiera divergen hoy y van a divergir más.

**Recomendación:** `Dispensaciones::CrearService` que concentre pricing + validación de crédito + creación + movimiento contable + débito de cuenta corriente. El modelo conserva solo invariantes (cantidad > 0, stock del club, límite mensual). Es el flujo más crítico del negocio y hoy es el más difícil de testear.

### A4. Race condition real en stock
`Dispensacion#stock_disponible` toma `stock.with_lock` **dentro de una validación**: el lock se libera al terminar la validación, y el decremento ocurre después en `after_create`. Dos dispensaciones concurrentes sobre el mismo stock pueden pasar ambas la validación y sobre-dispensar (stock negativo). Con varios dispensadores por sede esto va a pasar.

**Recomendación:** lock + re-chequeo + decremento dentro de la misma transacción (encaja natural en el service de A3). Red de seguridad adicional: `CHECK (cantidad >= 0)` en la tabla `stocks` (⚠️ requiere migración — decisión tuya).

### A5. Reversa de stock por matching de strings
`Dispensacion#incrementar_stock` (el WIP sin commitear) borra movimientos buscando `notas LIKE 'Dispensación #id —%'`. Usar un campo de texto libre como foreign key es frágil: si cambia el formato de la nota, la reversa falla silenciosamente y el kardex queda inconsistente.

**Recomendación:** columna `dispensacion_id` en `stock_movimientos` (⚠️ migración) y revertir por FK. El parche actual sirve como puente, pero no lo dejaría como solución definitiva.

### A6. Side effects críticos colgados de callbacks
`Dispensacion` tiene 7 callbacks que disparan: decremento de stock, reporte ARICCAME, webhook saliente, broadcast ActionCable, alertas internas. Consecuencias: imposible crear una dispensación sin disparar todo (imports, correcciones de datos, tests), y el orden/atomicidad es implícito. Mismo patrón que ya te obligó al hack de A5.

**Recomendación:** los side effects de integración (ARICCAME, webhook, broadcast, notificaciones) se mueven al service de A3; los callbacks quedan solo para invariantes del registro.

---

## Hallazgos — severidad MEDIA

### M1. Cobertura de tests muy por debajo de la criticidad del dominio
47 specs backend / 9 archivos frontend. Lo que más duele: **no hay protección automatizada sobre dinero (cuenta corriente, medios de pago, P&L) ni sobre el aislamiento de tenants**. Prioridad de inversión: (1) integración del flujo dispensación completo con los 4 medios de pago, (2) shared example de tenancy (A2), (3) transiciones de fase de lote, (4) concurrencia de stock (A4).

### M2. Controllers gigantes
`lotes_controller.rb` 1.002 líneas, `asistente_controller.rb` 789, `analytics_controller.rb` 777, `dispensaciones_controller.rb` 457. Síntoma de la falta de services/serializers. No hace falta big-bang: regla "si tocás un action, extraelo".

### M3. Serialización inline duplicada
5 serializers para ~90 controllers; el resto son hashes inline (`serialize_dispensacion` definido dentro del controller). El mismo recurso se serializa distinto en endpoints distintos → contratos frágiles con el frontend.

### M4. `rescue => e` devolviendo `e.message` al cliente
En `DispensacionesController#create` (y patrón repetido en otros controllers) un error inesperado devuelve su mensaje interno con status 422. Filtra detalles de implementación y disfraza bugs de errores de validación. Recomendación: rescatar solo excepciones esperadas; lo demás que sea 500 logueado.

### M5. Documentación interna desactualizada (riesgo operativo, no cosmético)
`docs/ARCHITECTURE.md` afirma que no existen ActionCable, ARICCAME ni app móvil (existen los tres), documenta la matriz de permisos muerta como si rigiera, y nombra modelos que no existen (`Socio`, `SedeInventario` como flujo de dispensación). Cualquier persona (o IA) que lea los docs antes que el código va a tomar decisiones equivocadas. El nuevo `CLAUDE.md` ya corrige; falta `ARCHITECTURE.md`.

### M6. God components en el frontend
`SalaDetailView.vue` 1.772 líneas, `AdminStocksPendientesView.vue` 1.642, `PlantaDetailView.vue` 1.465. Mismo tratamiento que M2: extraer subcomponentes al tocar.

### M7. Naming de dominio inconsistente
`Plant`/`PlantActivity`/`PatientDocument` en inglés vs. la convención castellana; `socio_notas_controller` y `paciente_notas_controller` conviven para conceptos hermanos. No recomiendo renombrar (riesgo alto, valor bajo) — recomiendo **congelar**: nada nuevo en inglés de dominio, y la tabla de equivalencias ya quedó en el CLAUDE.md.

### M8. Pendientes de la auditoría de mayo que siguen abiertos
Del informe anterior, verifiqué que siguen sin resolver: `lotes.genetica_id` sin FK constraint, `plants` sin `deleted_at` (las demás tablas core lo tienen vía paranoia), y la trazabilidad pesada→stock sin formalizar en DB. Todos requieren migración; los dejo anotados para cuando decidas tocar schema.

---

## Hallazgos — severidad BAJA / observaciones

- **B1.** El reload automático en `controllerchange` del service worker (WIP en `main.js`) puede recargar la página mientras un operador está cargando una dispensación o un alta. Mejor: toast "Hay una nueva versión — recargar" (detalle ampliado en el informe UX).
- **B2.** El timeout de 10s agregado a Axios es buena idea; ojo con endpoints legítimamente lentos (export CSV grande, informes) — quizá merezcan timeout propio más alto.
- **B3.** `export_csv` carga todo el scope en memoria con `.each`; con años de dispensaciones convendrá `find_each` + streaming.
- **B4.** `Webhooks::LecturasController` está bien resuelto (token por dispositivo, digest, idempotencia, encolado) — lo destaco como el patrón a imitar para futuras integraciones.
- **B5.** El guard del router por `ROLE_ALLOWED_PREFIX` es razonable, pero es solo UX: la seguridad real es del backend (refuerza A1).

---

## Plan sugerido (orden recomendado)

| # | Acción | Esfuerzo | Toca DB |
|---|---|---|---|
| 1 | Shared example de aislamiento de tenant + aplicarlo a controllers críticos | Bajo | No |
| 2 | `Dispensaciones::CrearService` (unifica A3+A4+A6) + specs de integración de los 4 medios de pago | Medio | No |
| 3 | `stock_movimientos.dispensacion_id` y reversa por FK | Bajo | ⚠️ Sí |
| 4 | Autorización unificada sobre la matriz `PERMISSIONS` (A1), migrando controller por controller | Medio-Alto | No |
| 5 | `CHECK cantidad >= 0` en stocks + FK `lotes.genetica_id` + `deleted_at` en plants | Bajo | ⚠️ Sí |
| 6 | Actualizar `docs/ARCHITECTURE.md` | Bajo | No |
| 7 | Regla permanente: action tocado → service extraído + serializer extraído | Continuo | No |

Los puntos 3 y 5 requieren migraciones: **no los ejecuto sin tu OK explícito** (restricción del proyecto).
