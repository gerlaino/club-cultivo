# Changelog

## Septiembre 2026 (ac) — el arqueo que se movía solo, y con qué darse cuenta

Germán preguntó si el descuadre que ya había mordido en el stock —una reversa que se aplicaba dos
veces al editar— podía estar pasando en contabilidad, "porque ahí no nos vamos a dar cuenta".
Podía, y de una forma peor.

**UN ARQUEO FIRMADO SE MOVÍA DESPUÉS.** `CajaTurno#efectivo_esperado_ars` se calcula en vivo cada
vez que alguien lo mira, también en turnos ya cerrados. Sus componentes ignoran a propósito lo
posterior al cierre (`salidas`, `ingresos` y `otros_ingresos_efectivo` filtran por `cerrada_at`)
justamente para que la diferencia de arqueo no cambie — la regla estaba escrita para el retiro de
la recaudación. **Lo cobrado había quedado afuera**: cancelar hoy una dispensa de ayer soft-borra
su `Cobro`, y el turno que cerró CUADRADO pasaba a mostrar un sobrante igual a lo cancelado. Es la
peor forma de un error contable: no falta una fila ni sobra un movimiento, el total cambió solo.
El buffet tenía el mismo agujero (`BarVenta` también es soft-delete y una venta se deshace desde
la venta).

`cobros_del_arqueo` / `ventas_del_arqueo` congelan la foto: con la caja cerrada cuentan lo que
estaba en el cajón esa noche —incluye lo anulado DESPUÉS, excluye lo cancelado ANTES—. Tres specs,
uno de ellos para que el arreglo no se pase de largo e invente un faltante.

**Y `rake contabilidad:auditar`, que es con lo que uno se da cuenta.** Sólo lee. Compara el saldo
de cada cuenta corriente contra su propio historial, lo asentado de cada dispensa contra lo
cobrado, y busca cobros colgando de dispensas canceladas. No arregla nada: decidir qué pasó con un
descuadre es de una persona.

Lo más instructivo fue afinarlo. Las primeras tres versiones gritaban en falso —la dispensa mixta
que legítimamente lleva dos asientos, el efectivo que el repartidor todavía no rindió, el paquete
contra-entrega que no cobró nada—, y un aviso que grita en falso entrena a ignorar todos los
demás. Pero el peor error fue el opuesto: `where.not(estado_envio: 'cancelada')` **excluye los
NULL en SQL**, y como una dispensa sin envío tiene ese campo en NULL, la auditoría miraba sólo las
que tenían reparto y contestaba "todo bien" sin haber revisado casi nada. Sobre datos reales daba
verde igual: lo encontraron los tests del propio auditor, que por eso verifican tanto que cante el
descuadre como que se quede callado con lo legítimo.

Sobre la base de desarrollo (que incluye una copia de Mitocondria) queda **un** hallazgo real: una
dispensa de $25.000 del 31-08 que no dejó asiento, del lote de pruebas de reparto de esa noche.

2778 rspec ✓.

---

## Septiembre 2026 (ab) — los huecos del mostrador, mirando la pantalla

Repaso del módulo rol por rol, con la app corriendo. Casi todo lo que apareció es la misma clase
de error: **la pantalla ofrece un camino que el backend termina rechazando**, o una regla escrita
en un lado y leída en otro.

**El disponible que veía quien atiende era el del DEPÓSITO.** `StocksController#index` ya filtraba
el carrito a lo que está sobre la mesa y pisaba `cantidad_disponible_real` con esa cantidad — pero
el carrito muestra y valida contra `cantidad`, el frasco entero. Con 300 g sobre la mesa y 1.000 en
el depósito, la pantalla decía **1.000 g** y lo dejaba cargar 500 para que el backend se lo
rechazara al confirmar, con el paciente enfrente. Se pisan los dos campos. Apareció mirando la
pantalla renderizada: los 1748 tests en verde no lo veían.

**La caja cerrada se avisa ANTES de armar el carrito.** La mesa es permanente, así que con la caja
cerrada el producto sigue estando y el carrito se llenaba igual; el rechazo llegaba al final
(`Dispensacion#mostrador_abierto`). Ahora, al abrir el modal, quien atiende consulta el estado de
su mostrador: si no hay turno, un aviso arriba de todo con el camino ("abrila en Mostrador") y el
botón de confirmar deshabilitado. Si la consulta falla no traba nada — el backend sigue siendo el
que decide.

**En la PWA instalada, "Ir al mostrador" no iba a ningún lado.** El guard rebota todo lo que no
empiece con `/m`, y varias pantallas se montan en los dos lados sin escribirse dos veces
(`/m/mostrador`, `/m/stock`, `/m/historial`). El link de la tarjeta de caja —en la pantalla que más
usa el dispensador— lo devolvía a esa misma pantalla: el botón parecía no hacer nada. `rutaEnShell`
le pregunta al router si existe el equivalente bajo `/m` (nada de listas a mano) y **pide el permiso
sobre la ruta de ESCRITORIO**: bajo `/m` la matriz es un solo prefijo para todo el shell, así que
mapear a ciegas le habría abierto `/m/pacientes` a un repartidor.

**`Mostradores::Contar` tenía servicio, ruta y función en `api.js`, y ninguna pantalla.** Contar un
frasco sin cerrar la caja era el punto entero —cerrar y reabrir con quince productos son veinte
minutos, y el control que cuesta eso no se hace— y el único camino seguía siendo el arqueo completo.
Botón por fila para quien atiende (con la caja abierta; administración no cuenta a distancia) y
modal `ModalContarItem`: lo esperado no aparece hasta que el conteo está escrito, y con diferencia
el motivo es obligatorio, porque acá el ajuste SÍ toca el inventario.

**Confirmar los cambios de la mesa** (`ModalCargarMesa`): el motivo se escribía en una barra angosta
ANTES de ver qué se estaba cambiando, y con buscador y orden de por medio lo tocado podía no estar
todo en pantalla. Ahora "Revisar y guardar" abre la lista completa con el antes y el después de cada
producto, cuánta plata queda sobre la mesa, un chip "sale de la mesa" para los que van a cero, y
recién ahí el motivo, con sugerencias según se esté subiendo o bajando. De paso, el botón se
deshabilita si alguna fila pide más de lo que hay libre (lo avisaba la fila, pero dejaba apretar).

**Detalles que quedaban del rediseño de la mesa:** el badge del encabezado decía "Cerrado" cuando lo
cerrado es la CAJA (la mesa sigue con su producto a la vista); la tarjeta de caja le decía al
dispensador "cargala" cuando la mesa la carga administración; y el shell de la PWA le daba al
dispensador identidad celeste cuando en el escritorio es verde (`--c-role-dispensador`).

**Y "su" mostrador ahora sale de una sede que ATIENDE.** `/me` elegía `sedes_asignadas.activas
.first` sin filtrar por tipo: en una organización que además cultiva, si al dispensador le caía
primero una sede de producción, la tarjeta de caja le contestaba "no se pudo cargar el mostrador"
sin decir por qué y sin forma de arreglarlo desde la pantalla.

**Y una prueba de navegador que estaba en rojo en master**: `getByRole('link', { name: 'Mostrador' })`
matcheaba dos links (la tab y el de la tarjeta) y moría con "strict mode violation", no con un fallo
de la app.

2772 rspec ✓ · 1748 vitest ✓ · 7 pruebas de navegador ✓.

---

## Septiembre 2026 (aa) — la plata que entra sin pasar por una dispensa

Germán preguntó qué pasa si un paciente llega y paga una deuda sin que haya una dispensa nueva de
por medio. La respuesta era: esa plata desaparece. `CuentaCorrientesController#registrar_pago`
crea un `MovimientoContable` (categoría `aporte_socio`) que **no se ata a ninguna caja** —
`CajaTurno#total_efectivo_ars` sólo mira `Cobro`, lo que sale de una dispensa—. Un paciente que
paga $10.000 en efectivo entra al cajón de verdad, y a la noche quien arquea encuentra un
sobrante que no puede explicar.

**El mismo agujero, en un segundo lugar**: la seña de una reserva (`ReservasController
#registrar_sena`) crea el mismo tipo de movimiento suelto.

En vez de parchear los dos puntos de entrada, un único enganche en `MovimientoContable`: si es
`aporte_socio`, tiene medio de pago, y hay una caja abierta en esa sede, se ata sola
(`atar_a_la_caja_abierta`). Ningún controller nuevo tiene que acordarse de hacerlo.

**Línea PROPIA en el arqueo, no sumada al efectivo cobrado** (`CajaTurno
#total_otros_ingresos_efectivo_ars`): si el conteo no cuadra, quien lo mira tiene que poder
distinguir si vino de una venta o de un pago de deuda, no adivinarlo. El modal de conteo lo
muestra como una nota bajo "Efectivo" cuando corresponde.

2767 rspec ✓ · 1709 vitest ✓.

---

## Septiembre 2026 (z) — un badge para saber de dónde va a descontar

Administración dispensa del depósito entero, más allá de lo que haya sobre la mesa del
mostrador — pero si el producto que elige está sobre alguna mesa, la dispensa **descuenta de
ahí igual**, aunque no pase por el mostrador (`Dispensacion#imputar_a_mostrador` no distingue
quién dispensa). Esa parte ya funcionaba; lo que faltaba era que quien elige lo supiera ANTES,
no que el que atiende cerrara esa noche con un faltante que no esperaba.

`StocksController#serialize_stock` suma `en_mostrador` (si el frasco está apartado en alguna
mesa) y el carrito le pone un chip **🏪 Mostrador** al lado del producto — sólo para quien ve el
depósito completo: al dispensador ya se le filtró la lista a lo que está sobre la mesa, y
repetirle el badge en cada fila no diría nada nuevo.

2763 rspec ✓ · 1709 vitest ✓.

---

## Septiembre 2026 (y) — el primer día sin fondo abría sin caja

Segunda pasada sobre el bloque (x), cerrando lo que había quedado pendiente y lo que apareció
probando los flujos por rol.

**El agujero real: abrir sin nada que heredar, el primer día.** El dispensador puede abrir la caja
sin escribir el efectivo contado — normalmente hereda el fondo del último cierre, y eso está bien.
Pero el PRIMER día no hay ningún cierre anterior, y si tampoco escribe nada, el turno se abría
**igual, pero sin ninguna caja atrás**: `TurnoMostrador#caja_turno` quedaba `nil`, y todo lo cobrado
en efectivo durante ese turno no tenía dónde caer — no aparecía en ningún arqueo, y a la noche esa
plata simplemente no estaba en ningún lado. `Mostradores::AbrirCaja` ahora lo rechaza con un mensaje
claro, y el modal marca el campo como obligatorio **sólo en ese caso puntual** — el resto de los
días sigue sin pedir nada, como corresponde a la regla de "no bloquea por diferencia".

**Limpieza de esquema.** Se fue `turno_mostrador_movimientos` (tabla + modelo) y las cuatro columnas
muertas de `turno_mostrador_items` (`cantidad_repuesta`, `cantidad_devuelta`, `cantidad_ajuste`,
`cantidad_heredada`) — nada las escribía desde el bloque (x).

**Las tres razones de "pide una mirada", unificadas.** Estaban escritas dos veces: en SQL en el
controller (para el badge) y en Ruby en `Mostradores::Merma` (para la lista). Coincidían, pero es
el patrón que en este proyecto siempre terminó divergiendo. `Mostradores::MotivosDeRevision` es
ahora el único lugar que decide qué cuenta como pendiente.

**El admin llega directo al mostrador de una sede.** Ya podía verlo —el selector con todas sus
sedes andaba—, pero no había forma de llegar directo: la fila "Cajas del día" del tablero llevaba
a la ficha de la sede, y desde ahí "Ir al mostrador" siempre aterrizaba en la primera sede de la
lista, no en la que se estaba mirando. Con dos sedes, clickear "Norte" llevaba al mostrador de
Centro. `MostradorView` ahora respeta `?sede=` en la URL.

**Los gramos de la mesa, ocultos mientras se cuenta.** Con el modal de cierre abierto, la tabla de
atrás seguía mostrando cuánto decía el sistema — la misma fuga que ya se había tapado para el
efectivo, pero por el otro lado.

2761 rspec ✓ · 1707 vitest ✓.

---

## Septiembre 2026 (x) — la mesa deja de ser del turno

El mostrador funcionaba, pero ataba dos cosas que son distintas y de personas distintas: **qué hay
sobre la mesa** y **el arqueo de una jornada**. Abrir el turno ERA poner la mercadería, así que el
admin no podía gobernar la mesa a distancia —que es el punto entero del módulo, poder delegar
tranquilo— y cualquier cosa que volviera al mostrador a las once de la noche dependía de que
hubiera un turno abierto para tener dónde caer.

Ahora el mostrador tiene **contenido propio y permanente** (`MostradorItem`), y el turno se queda
con lo suyo: contar al abrir y contar al cerrar.

```
Mostrador ──┬── MostradorItem      → qué hay AHORA, permanente. Es lo que se aparta.
            │     └── MostradorMovimiento → cada subida y bajada, con quién y por qué
            └── TurnoMostrador     → el ARQUEO de una jornada: lo contado al abrir y al cerrar
```

- **El apartado ya no depende del turno.** El producto está físicamente sobre esa mesa a las tres
  de la tarde y a la medianoche. Antes se liberaba al cerrar: de noche el sistema lo daba por libre
  y una reserva de paciente podía comprometerlo.
- **`turno_mostrador_id` es opcional en el movimiento**, a propósito: el admin carga la mesa a las
  siete de la mañana, cuando todavía no abrió nadie. Cuando SÍ hay turno queda atado a él, para que
  el arqueo de esa noche sepa qué pasó mientras estaba abierto.
- **Backfill en la migración**: sin él, el día del deploy toda organización con el mostrador
  abierto amanece con la mesa vacía y el producto igualmente apartado.

### La recepción separada desaparece: ABRIR ES CONTAR

Eran dos verificaciones para el mismo hecho —el admin declaraba, quien atendía confirmaba— y la
segunda era un botón que nadie miraba. Ahora quien va a atender **pesa lo que encuentra y cuenta la
plata**, en un solo gesto, y eso es el punto de partida del arqueo.

**No bloquea por diferencia.** Si lo que cuenta no coincide, pone lo que contó y abre: la
diferencia queda anotada con su nombre y la ve el admin. Bloquearlo dejaría el mostrador cerrado a
las ocho de la mañana esperando a alguien que no está, que es exactamente lo que este módulo existe
para evitar.

- **La mesa se corrige con lo contado** pero **NO toca el inventario**: acá todavía no se sabe si
  faltó de verdad o si la mesa se cargó de más, y el producto puede estar en el depósito. El conteo
  del CIERRE sí ajusta —el producto estaba arriba, se contó, y no está— y va como `ajuste` con
  motivo, nunca como `merma`.
- Se fueron `mostrador/confirmar` y `mostrador/devolver`: bajar al depósito es escribir un número
  más chico en la tabla.

### La caja del dispensario se abre y se cierra en UN solo lugar

`POST /sedes/:id/caja/abrir` existía y sólo pedía un fondo: **abrir por ahí salteaba la mitad del
arqueo**, porque no contaba la mercadería — y la ficha de la sede lo ofrecía como si fuera lo
normal. Junto con `confirmar_apertura`, `solicitar_cierre`, `confirmar_cierre` y `cerrar`, se
retiraron. En `cajas#*` queda lo que es de la caja y no del mostrador: mover plata y anular.

- **`sin_confirmar` es del BUFFET, no del dispensario.** El tablero preguntaba
  `apertura_confirmada?` a las dos cajas por igual: como en el dispensario ya nadie confirma nada,
  toda caja del mostrador iba a quedar `sin_confirmar` para siempre, esperando un paso que no le
  toca a nadie.
- **Anular una caja abierta por error dejaba la sede sin poder dispensar.** Abrir es un gesto que
  crea DOS cosas, y `anular!` sólo deshacía una: el turno quedaba abierto apuntando a una caja
  anulada, y desde ahí el mostrador no se podía volver a abrir —decía que ya había uno— ni cerrar
  —el cierre le pedía el arqueo a una caja que ya no estaba—. Ahora se deshacen las dos. El turno
  se **borra**, no se cierra: nunca fue un turno, y dejarlo cerrado lo metería en la lista y en el
  cálculo de merma con un arqueo que nadie hizo. Si ya se dispensó, no es una apertura equivocada:
  se cierra con su arqueo. **La mesa no se toca** — es del mostrador y el producto sigue ahí.

### Lo que vuelve: a la mesa o al depósito

Revertir una dispensa empujaba producto a la mesa **siempre**. Con la mesa permanente eso significa
que un admin que cancelaba una dispensa suya a las diez de la mañana, con el mostrador sin abrir,
dejaba cien gramos **apartados sobre una mesa vacía**: invisibles como disponibles en el depósito,
esperando que alguien se diera cuenta de bajarlos.

Vuelve a la mesa en dos casos, y sólo en esos dos:

- el producto **ya está** sobre la mesa — salió de ahí y vuelve ahí, esté quien esté;
- **no está, pero hay alguien atendiendo**. Es el caso que motivó la regla: el paquete que el
  repartidor no pudo entregar vuelve a las 19:00 y el que atiende lo tiene ahí adelante.

En el resto vuelve al depósito, que es donde no molesta a nadie.

### La papelera se retiró

Restaurar re-aplicaba los efectos sobre el estado de **HOY**, no sobre el de entonces: traer de
vuelta una dispensación de hace tres semanas le sacaba producto a la mesa del mostrador de hoy, y
quien estaba atendiendo cerraba con un faltante que no era suyo y no podía explicar.

Deshacer algo que movió stock o plata **no es desenterrar la fila**: es la reversa explícita que ya
existe (`Dispensaciones::Cancelar`), que sabe revertir contra el estado actual y es la que usa la
rendición del repartidor. El soft-delete sigue: los registros no se pierden, simplemente no hay un
botón que los re-ejecute a ciegas. `Restore::*` y sus specs quedan en el repo por si vuelve acotada
a lo **inerte** —una genética, una sala, una tarea—, que es donde restaurar es literalmente volver
a poner la fila.

### Lo que apareció mirando la pantalla, rol por rol

- **El esperado del cajón se le mostraba a quien lo iba a contar.** El modal de conteo se cuida de
  no revelarlo hasta que escribís, pero la pantalla de atrás decía *"en caja tendría que haber
  $20.000"* todo el día, sin guard de rol. Con el número a la vista se escribe ese, el conteo es
  teatro y toda la merma que se mide da cero. Ahora es sólo para administración, que monitorea.
- **El cartel del carrito vacío le proponía al dispensador lo único que no puede hacer**: *"bajá lo
  que falte del depósito"*. La mesa la carga administración. Un cartel que propone una acción
  prohibida es peor que no tener cartel.
- **Los tres motivos de la lista de trabajo se renombraron** al modelo nuevo: `sin_supervision` era
  una bandera del modelo viejo y su chip salía **vacío**. Ahora son *faltó producto*, *se corrigió
  al abrir* y *se movió la mesa durante el turno*.

### Limpieza

`Mostradores::AbrirTurno`, `CerrarTurno`, `ConfirmarApertura` y `MoverStock` se fueron; entraron
`AbrirCaja`, `Cargar`, `CerrarCaja` y `Contar` — el conteo suelto vivía en el controller, que era
el único de los cuatro sin service. El ajuste de inventario por conteo estaba escrito **dos veces**
(cierre y conteo suelto) y ahora vive en `MostradorItem#ajustar_inventario!`.

`TurnoMostradorMovimiento` quedó marcado como **histórico**: no se escribe más, pero la tabla tiene
las filas de los turnos viejos. Darla de baja —junto con `cantidad_repuesta`, `cantidad_devuelta`,
`cantidad_ajuste` y `cantidad_heredada`, que ya no escribe nadie— es una migración aparte.

**2759 rspec ✓ · 1707 vitest ✓ · 7 pruebas de navegador ✓.**

---

## Septiembre 2026 (w) — qué es un producto se puede corregir

Un stock cargado como **`prensado` porque todavía no existía `preroll`** no se podía arreglar: la
forma y la unidad no eran editables, así que un frasco quedaba mal etiquetado para siempre. Son una
etiqueta, y una etiqueta equivocada se arregla — la unidad se deriva de la forma (un preroll se
cuenta, el hash se pesa) pero queda editable, porque hay comestibles que se venden por gramo.

**La salvedad es el EJERCICIO CERRADO.** Cambiar la unidad reinterpreta cantidades ya escritas —los
3 que salieron como gramos pasan a leerse como unidades— y esas salidas tienen su asiento. Si el
período contable ya se cerró (`clubs.contabilidad_cerrada_hasta`), eso es reescribir lo que se
presentó: se rechaza, y el mensaje dice que primero hay que reabrir el período. Sobre un período
**abierto** sí se permite, que es exactamente el momento en que las correcciones se hacen.

- **Cuenta las dos formas de dispensar.** Una salida vive en `dispensaciones.stock_id` **o** en un
  `DispensacionItem`; mirar sólo la primera dejaba cambiar un stock que el carrito ya había
  dispensado dentro del período cerrado. Y es UNA query con OR contando dispensaciones distintas:
  una dispensa de un solo producto queda escrita en los dos lados, así que sumar las dos cuentas la
  contaba dos veces.
- **El resto del producto se sigue editando** aunque el período esté cerrado: sólo se congela qué
  es. Un stock que no se puede ni corregir de precio no le sirve a nadie.
- **La pantalla se entera antes de ofrecerlo** (`puede_cambiar_forma` en el `show`): el selector
  aparece deshabilitado **con el motivo**, no escondido. Esconderlo sin decir por qué se lee como
  que la app está rota.
- De paso, **`preroll` no tenía etiqueta ni ícono** en el detalle: se mostraba crudo, en minúscula.

---

## Agosto 2026 (v) — el mostrador

Hasta ahora una organización que dispensa abría la caja de plata y nada más. La mercadería salía
del depósito sin que nadie declarara qué había sobre la mesa a la mañana ni qué quedaba a la
noche, y la merma —que es inevitable— no se medía en ningún lado.

**El mostrador es el punto de venta del dispensario**, hermano de la `Barra` del buffet. No es un
módulo que se contrata ni un interruptor que se prende: **es dónde opera el dispensador**, y viene
con la suite de Producción y dispensa.

### La pieza que faltaba: `Mostrador`

La caja del dispensario apuntaba a la **`Sede`** —no porque estuviera bien, sino porque no existía
la entidad: `CajaTurno#de_dispensario?` preguntaba literalmente `punto_type == 'Sede'`—. Eso dejaba
dos ideas distintas de "punto de venta" conviviendo y ninguna forma de decir "este stock está sobre
la mesa de este mostrador".

```
Sede (social o mixta)
 ├── Barra      → CajaTurno
 └── Mostrador  → CajaTurno + TurnoMostrador (la mercadería)
```

Quién atiende cada mostrador **no necesitó tabla nueva**: `UserSede` ya asigna dispensadores a
sedes, y el mostrador es de la sede.

La migración repunta las cajas que ya existían y **falla el deploy** si quedara una sola sin dueño:
una caja huérfana no tira error, sólo hace que el arqueo mienta. Y `punto_type: 'Sede'` estaba
escrito a mano en **cinco archivos** más `de_dispensario?`; ninguno fallaba al quedar
desactualizado, simplemente no encontraba caja y el cobro quedaba suelto. Todos pasan por
`CajaTurno.abierta_en_sede`.

### El stock se APARTA, no se descuenta

Es la mecánica del apartado de un evento (`EventoBarProvision`) con otro destinatario: cargar el
mostrador **bloquea** la cantidad, no la descuenta. La fila `Stock` sigue siendo una sola con su
`ST-xx` y su QR, porque **lo trazable sale del inventario por dispensación y nunca por cambiar de
mesa**. Descontar cerraría solo un lote cargado entero a la mesa y rompería el balance de
trazabilidad (`producido − dispensado − merma = en stock`).

Cargar y devolver **no generan `StockMovimiento`**: el rastro vive en el turno
(`TurnoMostradorMovimiento`, con hora y autor). El único movimiento de stock que genera todo esto
es el **ajuste del cierre**.

Y el corolario que no se puede romper: si aparta pero la dispensa no imputa, el stock cargado se
vuelve indispensable y el disponible cae el doble — el mismo bug que ya había pasado con los
eventos. `Dispensacion#imputar_a_mostrador` es el gemelo exacto de `imputar_a_apartado_evento`.

### El día, de punta a punta

1. **El admin carga la mesa** — fondo de caja y qué stock, y cuánto, baja del depósito.
2. **El que atiende lo recibe.** Ve lo que dejó el admin con los números ya puestos: confirmar es
   un click, corregir es cambiar el número y escribir el motivo. **Hasta que no firma, no
   dispensa** — ni por pantalla ni por API, y el carrito no le ofrece nada.
3. **Atiende.** El carrito le ofrece **sólo lo de la mesa y con el número de la mesa**: si arriba
   hay 300 g y en el depósito 1.240, ve 300.
4. **Cierra.** Cuenta mercadería y efectivo, deja el fondo y sale el retiro. **Cierra en el acto**,
   sin esperar al admin.
5. **El próximo abre** con lo que quedó anoche, gramos y fondo, editable.

**No hay relevo con firma cruzada.** Se descartó a propósito: ahí la misma persona cuenta dos veces
lo que ella misma dejó y termina en un botón que nadie mira. Cerrar-y-reabrir **es** el arqueo, y
se puede hacer varias veces por día. La recepción (paso 2) es otra cosa: son DOS personas, y sin
ese punto de partida verificado la diferencia de la noche mezcla lo que se consumió atendiendo con
lo que nunca estuvo sobre la mesa.

### El agujero de la plata que no se veía

El cierre pedía el efectivo contado y nada más. Si contabas $230.000 y mañana abrías con $50.000 de
fondo, **los otros $180.000 no tenían ningún movimiento que dijera que salieron del cajón**. Ahora
el cierre parte lo contado en el **fondo que queda** y el **retiro** de la recaudación, que sale
como `retiro_caja` (un `ajuste`, no un egreso: esa plata sigue siendo del club) y con dueño. El
fondo se **hereda**: el que abre no lo declara.

Y una regla que ya existía frenó el diseño, con razón: **`MovimientoContable::ROLES_RETIRO` sólo
deja que un admin o supervisor sea dueño de un retiro.** O sea, el dispensador cierra pero no se
lleva la recaudación. Si cierra él y no hay a quién atribuirla, deja todo como fondo y la plata se
queda en el cajón, que es donde está de verdad.

**Bug arreglado en `CajaTurno#salidas`:** el retiro del cierre contaba como salida del turno, así
que bajaba lo esperado y la diferencia de arqueo quedaba mal **para siempre** — un turno que cerró
cuadrado aparecería después con un sobrante igual a lo que se llevaron. Ahora `salidas` ignora lo
posterior al cierre.

### La plata se recibe igual que la mercadería

El que atiende confirma **los dos**: lo que hay sobre la mesa y lo que hay en el cajón. Si el
efectivo no coincide, el fondo pasa a ser **lo contado** —es lo que hay— y la diferencia se asienta
como `diferencia_caja` con quién la detectó y cuándo. Sin corregir el fondo, el cierre volvería a
encontrar la misma diferencia y la contaría dos veces.

A diferencia del stock, acá la diferencia **sí es una pérdida real**: los gramos que el admin
declaró de más siguen en el depósito, pero los pesos que faltan no están en ningún lado.

### La plata también entra al cajón, no sólo sale

Había `salida_caja` (gasto) y `retiro_caja`, pero **ninguna forma de PONER plata**: traer cambio,
reponer el fondo, dejar lo que alguien cobró por fuera. Nuevo `ingreso_caja`, espejo exacto de
`retiro_caja` — va como `ajuste` porque esa plata ya era del club, sólo cambió de lugar, y
asentarla como ingreso inflaría la facturación.

(Una dispensa cobrada en efectivo con la caja abierta **ya entra sola**: el cobro se engancha al
turno. Usar `ingreso_caja` para eso la contaría dos veces.)

**Bug que esto destapó:** `devolucion_caja` —la plata que alguien devuelve de un retiro— se ataba
a la caja abierta con el comentario *"la devolución la tiene que esperar el turno que está
corriendo"*, pero `efectivo_esperado_ars` **no la sumaba**: el turno cerraba con un sobrante igual
a lo devuelto. La intención estaba escrita y no implementada. Ahora hay `CajaTurno#ingresos`,
simétrico de `salidas`, y las dos ignoran lo posterior al cierre.

### Los cuatro huecos que quedaban

- **La mesa se actualiza sola.** Si el admin baja producto desde su oficina, el que atiende lo ve
  sin recargar — recargar es justo lo que nadie hace con alguien esperando enfrente. Se reusa el
  canal del club en vez de abrir otro. **Y cada carga lleva número**: una tanda de cambios dispara
  varias recargas, y sin ordenarlas la respuesta vieja aterriza última y la pantalla vuelve atrás.
  Lo cazó el e2e, que vio 300 donde tenía que haber 297.
- **Contar un producto sin cerrar el turno.** Cerrar y reabrir sigue siendo el arqueo completo,
  pero con quince frascos son veinte minutos: ese control no se hace dos veces por día. Contar de
  a uno cuesta treinta segundos, ajusta el inventario y corre el esperado del cierre para que a la
  noche no se cuente dos veces lo mismo.
- **La merma, sede por sede.** Es LA comparación que encuentra el cuello de botella: si en una se
  pierde el triple que en otra con el mismo producto, el problema no es la merma.
- **El aviso.** Sin umbral fijo, a propósito: un 3% puede ser normal fraccionando flor y un
  escándalo en aceite, y lo que importa no es el número sino que CAMBIÓ. Se compara la semana
  contra las ocho anteriores de esa organización, con pisos de historia y volumen, y como mucho
  uno por semana.

### Pruebas de punta a punta en el navegador

`frontend/e2e/` con Playwright, sobre una organización **aparte** (`slug: 'e2e'`, sembrada por
`rake e2e:seed`) — nunca sobre datos reales. Recorren el día del mostrador completo (cargar,
recibir corrigiendo, cerrar contando, heredar) y la rendición entera (rendir, contar, ajustar,
conformar, ver el historial y lo acumulado en la ficha).

**Encontraron cuatro cosas que ni el build ni los tests unitarios iban a encontrar:**

- **El rango de la merma se calculaba en el navegador con `toISOString()`, que da la fecha en
  UTC.** Con el cliente en una zona y Rails en Buenos Aires, entre las 21:00 y las 00:00 la
  solapa pedía un mañana donde todavía no había cerrado nadie y se veía vacía — justo en el
  horario en que se cierra el mostrador. Ahora el rango por defecto lo pone el **backend**, en su
  zona: el cliente no tiene por qué adivinar qué día es allá.
- **Al recibir una rendición, la mesa no se actualizaba.** El producto que volvía entraba al
  sistema y no aparecía en la pantalla del que lo acababa de recibir en la mano.
- Y dos del andamiaje, que valen igual porque hacen que una prueba mienta: cambiar de usuario sin
  limpiar la sesión (el caso seguía como el anterior y pasaba igual), y una petición en vuelo cuyo
  `Set-Cookie` reponía la sesión después de limpiarla. `entrar()` ahora **verifica** con quién
  quedó la sesión.

### La rendición del repartidor, con las dos personas adentro

Era unilateral: el que recibía apretaba un botón y el sistema daba por rendido todo lo que el
repartidor había cobrado. Dos agujeros — **nadie contaba la plata** (si traía menos, el sistema no
se enteraba) y el repartidor no tenía forma de dejar constancia de que la entregó.

Ahora **la inicia él**: elige a quién le rinde, y el monto no lo escribe —es la suma de lo que ya
cobró en cada puerta—. El receptor **cuenta** y recibe.

**La plata nunca queda en el aire.** Es efectivo: el que cuenta es el que la tiene en la mano y ese
número entra al cajón, siempre. No hay estado "en disputa" — dejaría plata que no está en ningún
lado. Si el receptor ajustó, lo que queda pendiente es la **conformidad** del repartidor, que es
constancia y no candado, y va a la bandeja del admin: una diferencia de efectivo se resuelve
hablando, no con un estado.

**Sólo se ajusta hacia abajo.** Si trae MÁS de lo que figura cobrado, es que un cobro no se cargó:
ajustar acá lo taparía y esa dispensa quedaría figurando impaga para siempre.

**Lo que no entregó no es una pérdida**: esa plata existe y está con una persona. Va como `ajuste`
categoría `a_cuenta_repartidor` con su nombre, así que no baja el resultado — mismo criterio que
`retiro_caja`. Y el ingreso se asienta **completo**: el paciente pagó esa plata, lo que falta no es
menos venta.

La puerta vieja (el admin recibe sin que el repartidor haya rendido) sigue andando y **delega en el
mismo servicio**: dos caminos al mismo hecho es cómo dejan de coincidir.

### La rendición también trae producto

El repartidor no vuelve sólo con plata: vuelve con los paquetes que no pudo entregar. **Todos se
desarman**, y no se elige — es una decisión de CALIDAD, no de inventario: un paquete que estuvo en
la calle no se guarda armado esperando otro intento, y cuando se despache de nuevo se arma en el
momento (para entonces puede haber cambiado hasta la forma de entrega, y pasar a buscarse por la
organización).

Su producto vuelve al stock y **sube a la mesa del mostrador abierto aunque ese frasco no estuviera
arriba**: si no, el gramo volvía al depósito y el que atiende no lo tenía para entregárselo al
próximo que lo pidiera, con el paquete ahí adelante. Cuando se despache de nuevo, es una dispensa
nueva.

`reprogramar` sigue existiendo para el reintento del MISMO viaje —falla a las 18 y vuelve a
intentar a las 19 sin pasar por la base—: ahí el paquete nunca volvió.

Para eso se extrajo `Dispensaciones::Cancelar` de `DispensacionesController#cancelar_entrega`: la
reversa de stock, cuenta corriente y asientos ahora vive en un solo lugar. Escribirla dos veces es
cómo dejan de coincidir a la primera corrección.

### Lo que el repartidor tiene del club, acumulado

En su ficha, al lado de la caja: cuánto se quedó en total y en cuántas rendiciones, con el detalle.
Suelto, cada faltante parece un caso aislado y nadie nota que van seis meses seguidos. Se muestra
como **saldo y no como gasto** —en ámbar, no en rojo—: esa plata existe, está con él y se reclama.

### El arqueo no puede mostrar la respuesta antes de preguntar

El cierre decía *"tendría que haber 297 g"* **arriba del campo donde se escribe lo contado**.
Nadie pesa 297 g teniendo el 297 delante: se escribe ese número y listo. Con eso el conteo es
teatro, la merma da cero siempre y el módulo entero deja de servir para lo único que se construyó.

Ahora lo esperado aparece **después** de escribir el conteo, producto por producto, y lo mismo con
el efectivo. En la RECEPCIÓN sí sigue viniendo precargado a propósito: ahí confirmar es un click y
un número mal puesto sólo corre el punto de partida, no la medición.

### Revertir una dispensa le devuelve el producto a la mesa

`incrementar_stock` devolvía el gramo al pozo pero el mostrador lo seguía dando por salido: el
frasco vuelve a la mesa y la noche cierra con un **sobrante** que el que atendió no puede
explicar. Faltaba el inverso de `imputar_a_mostrador`, y sólo aplica con el turno abierto — si ya
cerró, su arqueo se hizo con el producto afuera.

(Un reparto **fallido** no devuelve el stock, y está bien: puede reprogramarse. Para devolverlo de
verdad ya estaba `cancelar_entrega`.)

### Lo que apareció al abrirla en el navegador

Un build verde no prueba que la pantalla sirva. Abriéndola con datos reales apareció que **el
admin podía confirmarse a sí mismo la mesa que acababa de cargar**: la firma de recepción quedaba
decorativa, que es exactamente lo que queríamos evitar al descartar el relevo. Ahora quien carga
no recibe —la validación está en el servicio y la pantalla ni le ofrece el formulario— y si abre
el que atiende, nace confirmado.

De paso, `loCargueYo` comparaba dos ids que pueden ser nil: sin exigir que existan,
`undefined === undefined` daba true y **nadie** podría recibir la mesa nunca. Lo cazó un test.

### Deshacer un conteo mal cargado

Era el único lugar del módulo donde un dedazo destruía datos: 21 en vez de 215 cierra con un
faltante de 194 g y **ajusta el inventario real**. La caja se podía anular; esto no tenía vuelta
atrás. `Mostradores::CorregirCierre` **no borra el movimiento equivocado**: asienta la diferencia
al lado. Borrar para tapar un error es peor que el error — el rastro de que alguien corrigió es
justo lo que hay que poder mostrar después.

### El bug de los rangos mensuales

`Date#all_month` devuelve un rango de **Dates**. Comparado contra un `created_at`, el borde de
arriba es la MEDIANOCHE del último día: **el día 31 no se contaba nada de esa jornada**. Durante
el mes no se nota porque el borde está en el futuro.

Mordía en dos lugares, los dos encontrados hoy —que es 31—: el **consumo de IA** (el tope no se
aplicaba y el cliente tenía un día gratis por mes) y los **informes por período** (Pérdidas perdía
el día entero, justo cuando alguien cierra el mes y lo mira). `Date#all_day` sí devuelve Times:
ese no tiene el problema.

### Dónde se le va el producto (solapa Merma)

**La merma es inevitable y no es culpa de nadie.** Se mide para que la organización sepa cuánta hay,
en qué producto y en qué momento — para encontrar el cuello de botella. El texto de la pantalla
tiene que sonar así: una diferencia es un dato que se anota, no una falta que alguien explica.

El número que manda es el **porcentaje sobre lo entregado**, no los gramos: 3,6 g sobre 85
entregados es 4% y hay algo que mirar; los mismos 3,6 sobre 850 es 0,4% y es la balanza. Un ranking
absoluto siempre encabeza con lo que más se vende y no dice nada.

Además, si el que recibe **corrige seguido**, el cuello de botella no es la merma: es quien carga
la mesa, que declara mal. Por eso las correcciones de recepción se cuentan por turno.

El aviso de turnos sin mirar viaja en la carga principal de la pantalla, no en la solapa: uno que
sólo aparece cuando ya fuiste a mirar no avisa nada.

### El ajuste de arqueo NUNCA es merma

La regla de oro sigue: lo trazable sale del inventario por dispensación. Un faltante de arqueo es
una **corrección de conteo**, va como `ajuste` con motivo obligatorio, y se cuenta aparte de
`merma` —que es lo que mira el informe de Pérdidas—. Anotarlo como merma declararía destruido
producto que puede estar entero, y para un auditor eso es peor.

Corregir **al recibir** tampoco toca el inventario: si el admin declaró 300 y hay 297, esos 3 g
siguen en el depósito. Sólo se corrige el reparto entre mesa y depósito.

### Quién pasa por el mostrador

`Dispensacion::ROLES_DEL_MOSTRADOR` = `dispensador` y `supervisor`. **El admin no**: es el que
carga la mesa, el que arquea y el dueño de la mercadería, y pedirle turno abierto para registrar
una dispensa vieja es fricción sin control detrás. Si igual dispensa algo que está sobre la mesa,
se imputa al ítem lo mismo, así el arqueo no le miente al que atiende.

Dos excepciones a "sólo lo que está sobre la mesa", y las dos son mercadería **ya apartada a nombre
de alguien** (y por eso no puede estar arriba, porque el mostrador sólo levanta lo libre): la
entrega de una **reserva** y lo apartado para un **evento**.

### De paso

- **`recibir_caja_delivery` tomaba la caja abierta más reciente de CUALQUIER sede**, sin filtrar:
  con dos sedes con caja abierta, el efectivo del repartidor caía en la que había abierto más tarde
  — sobrante en una, faltante en la otra. Ahora entra en el mostrador del que la recibe, y si no hay
  forma de saberlo se rinde igual sin turno: la plata entró al club y eso no puede depender de que
  alguien haya abierto un mostrador.
- **`preroll` no se podía crear.** Estaba en `Stock::FORMAS_PRODUCTO` desde siempre, pero faltaba en
  el selector del alta y en el de "procesar flor seca en un derivado" — que es el caso principal,
  porque un preroll sale de la flor propia. La lista de formas está copiada en 12 archivos.
- **Y aunque estuviera en la lista, no entraba:** `Stock#validar_segun_origen` comparaba `cantidad`
  contra `lote_origen_consumido_g` sin mirar la unidad. De 100 g salen 200 prerolls de medio gramo
  o 400 cápsulas: el número es mayor porque **la unidad es otra**, y el sistema lo rechazaba
  diciendo "200g resultado". La regla vale sólo cuando el derivado se mide en gramos.
- **El inflector**: `mostrador` → `mostradors` en inglés rompía la tabla, la FK y la clase inferida
  de `has_many :mostradores`. Se resolvió donde ya estaba resuelto para `bar`:
  `config/initializers/inflections.rb`.

### Poniéndose en el lugar de cada uno

Con el módulo andando, la última pasada fue mirar la pantalla como cada persona que la usa. Lo que
apareció no eran bugs: eran **finales sin cerrar**.

**Qué baja a la mesa se elige en una TABLA, no en un desplegable.** Un `<select>` con cuarenta
frascos no deja ver nada, y elegir qué se pone sobre la mesa no es buscar un ítem: es **revisar el
inventario y decidir** — de qué lote, de cuándo, cuánto queda libre y a cuánto se vende. Encima la
cantidad aparecía recién en la fila de abajo, *después* de apretar Agregar: se podía poner, pero
no se veía, que para el que abre el mostrador por primera vez es lo mismo que no poder.

Es **la misma tabla con la que después se dispensa** (`ModalNuevaDispensacion`), y a propósito:
armar la mesa y dispensar de ella son la misma pregunta, y contestarla con dos tablas distintas es
cómo empiezan a contradecirse. Buscador por palabra, orden por cualquier columna, y el costo sólo
para quien responde por la mercadería.

Tres decisiones de diseño que valen más que la tabla:

- **La cantidad ES la marca.** Se pensó con un tilde por fila, como en genéticas, pero ahí marcar
  es un booleano y acá cada fila marcada necesita un número —y nunca es "todo": bajás 300 de
  1.240—. Con tilde aparecía el estado sin sentido *marcado en 0* y eran dos gestos para uno.
  Escribís un número, la fila se pinta; lo borrás, sale.
- **Lo heredado va arriba de todo, ordene por lo que ordene**, con su número puesto y un chip
  "viene del turno anterior". Es la propiedad más valiosa del módulo —el que abre no declara,
  corrige— y perderla entre cuarenta filas sería perder la mitad. Dice *turno anterior* y nunca
  *anoche*: el mostrador se cierra y se reabre varias veces por día, y a las tres de la tarde
  "anoche" es directamente falso.
- **Nada de paginación.** El listado ya viaja completo, así que buscar y ordenar se hacen en el
  cliente. Paginar traía el problema de verdad: cargás cantidades en la página 1, buscás, pasás a
  la 2 — y si el borrador vive dentro de la tabla, se pierde. Vive en la pantalla, y hay un pie
  fijo con `N productos · 215 g · 40 un · $X a costo` porque con buscador de por medio lo elegido
  puede no estar a la vista.

El mismo control reemplaza el "bajar otro producto" del turno abierto, que era otro selector y otro
modal: ahora se bajan **varios de una** (con el turno andando se acaban tres cosas juntas, y de a
uno son tres modales), cada uno con su rastro y una sola recarga al final.

**Se probó una guía de "cómo funciona el día" y se sacó el mismo día.** El paso 1 decía *"se abre
con lo que quedó contado anoche"* y la primera vez **no hay anoche**: al lado, la pantalla decía
"Elegí qué baja del depósito". Un cartel que se contradice con lo que estás mirando es peor que no
tener cartel. La regla que deja: **lo que no aclara, que no confunda** — y la pantalla ya se
explica sola en cada momento, que es donde sirve.

**El producto que directamente NO ESTÁ.** Al recibir sólo se podía corregir el número, y para un
frasco que no está sobre la mesa eso significa dejarlo en **cero** toda la jornada, ocupando un
renglón que hay que volver a explicar cada vez que alguien mira. Ahora se saca (`quitar: true`),
con su motivo y con el nombre de quien lo sacó.

La fila **no se borra**: borrarla se llevaba puesto, por `dependent: :destroy`, el movimiento que
acababa de registrar quién lo sacó y por qué — o sea, se perdía justo lo que se quería guardar. Se
queda sin un solo número y el scope `en_la_mesa` deja de listarla: *una fila sin ningún número es
una fila donde nunca pasó nada*.

**Sus turnos.** Cerraba y no tenía dónde mirarlo: si al día siguiente le preguntan por una
diferencia, no tenía con qué. Nueva solapa **Turnos** — administración ve todos, el que atiende ve
**los suyos**, y el filtro es del backend, no de la pantalla. Corregir el conteo sigue siendo de
administración, porque ajusta el inventario real; a él la pantalla le dice a quién avisarle.

**El repartidor no veía lo que tiene del club.** Si le anotaron $20.000 al rendir, tenía que
preguntar — y así es como algo chico se convierte en una discusión. Ahora lo ve donde ya mira sus
rendiciones (`mi_saldo_ars`).

**Y no había forma de devolverlo.** Lo que se quedaba se acumulaba **para siempre**: no existía
"ya la devolvió". `Rendiciones::SaldarACuenta` + el botón en su ficha. La plata entra al cajón como
`ingreso_caja` y el saldo baja con un movimiento espejo — **no es un ingreso del club**: esa plata
siempre fue suya, sólo estaba en el bolsillo de otro. Lo registra quien la recibe, nunca él: sería
firmar su propio recibo. **"Rendir en partes" es exactamente esto**: se rinde todo, se recibe lo
que trajo y el resto se salda después.

**Cuánto vale lo que hay sobre la mesa.** En gramos no se compara con nada; en plata se ve de un
vistazo que ahí arriba hay medio sueldo. A costo, y sólo para quien responde por eso.

**"Contar" pasó a "Contar sólo este".** El botón estaba al lado de "Cerrar y contar" y no había
forma de saber cuál era cuál.

**La solapa de Merma hacía dos cosas.** Arriba va ahora la **lista de trabajo** —los turnos que
piden una mirada, que se terminan— y abajo el análisis, que se consulta. Mezclada entre tres tablas
de estudio, la lista no se hacía nunca.

**Y la bandeja contaba una sola de las tres cosas que prometía.** Un turno pide una mirada por
faltante, por corrección al recibir **o** porque alguien bajó del depósito sin supervisión; el
contador miraba sólo la primera y las otras dos quedaban invisibles apenas cerraba el turno. Cada
renglón dice ahora **por qué** está ahí: un pendiente que no dice qué mirar obliga a abrirlo para
descubrir que no era nada.

**El aviso de merma también sale por mail** (con el módulo de Correo y la casilla conectada). La
campana la mira quien entra a la app, y el admin de una organización chica puede no entrar en toda
la semana — que es justo cuando esto importa. Va `deliver_now` y no `deliver_later`: esto ya corre
en un job, y encolar un mail desde adentro de otra cola sólo mueve el error de lugar — el `rescue`
dejaba de proteger de lo único que falla de verdad acá, que es la casilla mal configurada.

### El supervisor es administración, no "el que atiende"

Estaba de los dos lados a la vez: administración para ver la merma (`gestiona?`) y para llevarse la
recaudación (`ROLES_RETIRO`), pero "el que atiende" para dispensar — o sea, con turno abierto
obligatorio y viendo **sólo** lo que había sobre la mesa. La misma persona cambiaba de rol según
qué pantalla mirara.

Ahora `User#atiende_mostrador?` es **el dispensador y nadie más**. Al dispensar, admin y supervisor
ven todo el stock habilitado de su sede; el dispensador ve la mesa, y con el número de la mesa.
Si el supervisor saca algo que está arriba, se imputa igual al turno: que no pase por el mostrador
no significa que el mostrador lo ignore, o el arqueo de la noche le miente al que atendió.

Vale la pena decir por qué está en un solo método: esa regla gobierna **dos cosas a la vez** —el
catálogo que ofrece el carrito y la validación de `Dispensacion`—. Separadas, la pantalla ofrece
algo que el backend rechaza, que es el peor error posible porque parece culpa del usuario.

### El que atiende abre con lo que heredó, y nada más

La tabla nueva hizo evidente algo que ya estaba mal: al abrir, el dispensador podía poner sobre la
mesa **cualquier cosa del depósito**, y eso **no quedaba marcado en ningún lado**. Bajar lo mismo a
media tarde con "Bajar del depósito" sí se marca `sin_supervision` y va a la bandeja del admin: la
misma acción tenía dos tratos según la hora, y el control era decorativo — el que atiende tenía la
llave del depósito.

Ahora hereda: puede corregir **para abajo** —contó menos de lo que decía el cierre anterior, y esa
diferencia queda con su nombre— pero no sumar de más ni traer un producto que no venía. Si le falta
algo, lo baja con el mostrador **ya abierto**, que es la puerta que deja rastro. Y el primer día,
cuando no hay nada que heredar, la mesa la carga el dueño de la mercadería: la pantalla se lo dice
en vez de mostrarle una tabla vacía.

Se mantiene lo que importaba de la decisión original —**que el mostrador no dependa del admin para
arrancar**, porque a las 8 de la mañana puede no haber ninguno—: abre él, y como lo abre quien
atiende, nace confirmado.

Va en `AbrirTurno`, no en la pantalla: por la API se saltea siempre. Lo que hace el frontend es
ofrecerle sólo lo heredado y poner el techo por fila, para no invitarlo a llenar un formulario que
el backend va a rechazar.

*(Ver el depósito, en cambio, no se tocó: el dispensador ya lo ve en su pantalla de **Stock**, con
más columnas que acá. Taparlo en un lado y dejarlo en el otro sería teatro.)*

### Lo que apareció repasando la pantalla rol por rol

- **El mostrador de OTRA sede se podía operar mandando otro `sede_id`.** La pantalla sólo ofrece
  las sedes de la persona, pero la pantalla no es la regla: un dispensador de Norte abría, cargaba
  y cerraba el de Centro. Es el mismo agujero que ya se había tapado en el listado de stock, y la
  asignación de sedes existe justamente para esto. Va en las **dos** puertas del punto de venta:
  `MostradorController#set_mostrador` y `CajasController#set_sede`.
- **"Sin stock disponible" era mentira para el que atiende.** Con el mostrador cerrado, el
  dispensador abría el carrito y leía eso — mientras el depósito estaba lleno. Lo manda a buscar
  un problema que no existe y a los cinco minutos llama por teléfono. Ahora dice *"No hay nada
  sobre el mostrador. Abrilo —o bajá lo que falte del depósito— desde Mostrador"*.
- **La mesa que nadie vino a recibir se podía desarmar.** Al pasar el supervisor a administración,
  una mesa que abre él ya no nace confirmada: en una organización sin dispensador quedaba
  esperando para siempre, con el stock apartado, la caja abierta y **ni un solo botón en
  pantalla**. Quien la cargó puede cerrarla, por el camino de siempre.
- **La tabla se lee en el teléfono** (`tabla-cards`): ocho columnas con scroll horizontal no se
  leen parado frente a alguien, que es cómo se usa esta pantalla.
- **Y el mostrador ENTRA en la PWA** (`/m/mostrador`, en la barra de abajo del dispensador). Tenía
  la caja de plata pero no la mesa: atendiendo con el celular no podía ni recibirla ni cerrar
  contando, que es la mitad de su día. Reusa la MISMA pantalla en vez de escribir una segunda
  —igual que `/m/stock` e `/m/historial`—, con el mismo guard de rol: dos pantallas para el mismo
  hecho es cómo dejan de coincidir.

### De paso, otra vez

- **`ROLES_DEL_MOSTRADOR` vivía en `Dispensacion`**, que no es quien sabe qué hace cada rol. Pasó a
  `User#atiende_mostrador?`.
- **`Sede#mostrador` creaba uno de prepo al leerlo.** Un `GET` que escribe en la base es una
  sorpresa que se paga cara: quedó partido en `mostrador` (lee) y `mostrador!` (crea, y sólo si la
  sede dispensa).
- **Dos N+1 hermanos.** `Merma` preguntaba los movimientos **turno por turno** (un mes de sesenta
  turnos eran ciento veinte viajes para pintar una tabla), y `apartado_para_eventos` cargaba las
  provisiones de cada stock por separado en listados enteros — el gemelo del que ya se había
  arreglado para el mostrador. Los dos suman ahora en una query (`Stock.precargar_apartados`).
- **La lista de turnos no usa `serialize_turno`**: ése arma la mesa producto por producto y le
  pregunta el depósito a cada uno. Treinta turnos serían cientos de queries para una lista donde no
  se ve ni un producto.
- **El e2e ahora dice "levantá `docker compose up`"** en vez de escupir un error de shell.
- **La pantalla no se dibuja hasta tener datos, y refrescar no la desmonta.** Eran dos cosas: el
  esqueleto se pintaba en CADA recarga (y la mesa se recarga sola con cada aviso del canal), y
  además el watcher de la sede corre con `immediate` **antes** de que `onMounted` la fije, así que
  había una ventana en la que la pantalla se dibujaba vacía y un instante después se rearmaba. En
  las dos, lo que la persona hubiera empezado a escribir —el buscador, una cantidad— se perdía sin
  que hubiera tocado nada. Lo cazó el e2e, dos veces.
- **No se sugiere al abrir lo que ya no está.** Si un frasco que anoche quedó sobre la mesa desde
  entonces se agotó o se fue de la sede, su número se cargaba sin fila donde verlo ni corregirlo y
  el backend lo rechazaba al abrir. Y se sugiere como mucho lo que quedó libre: si anoche cerró
  con 20 y hoy hay 12, proponer 20 es proponer algo que no se puede cumplir.

### Esquema

`mostradores`, `turno_mostradores`, `turno_mostrador_items`, `turno_mostrador_movimientos`, más
`dispensaciones.turno_mostrador_id`, `stock_movimientos.turno_mostrador_id`, `rendiciones_caja` y
`cobros.rendicion_caja_id`. (`clubs.exigir_mostrador_abierto` se agregó y se sacó en el mismo
bloque: el mostrador no es una opción.)

**2775 rspec ✓ · 1769 vitest ✓ · build limpio · 7 pruebas de navegador ✓.**

---

## Agosto 2026 (u) — el plan es una consecuencia, no una pregunta

El alta de una organización la va a usar alguien que no escribió la app. Mirándola con esos ojos,
casi todo lo que apareció es la misma familia: **la pantalla preguntaba en un orden que no es el
del negocio, y decía cosas que el backend después no cumplía.**

### Los módulos van antes que el plan

El wizard preguntaba Identidad → **Plan** → Módulos → Acceso. Con ese orden, el paso del plan le
mostraba a cualquiera los seis topes — "3 salas · 450 plantas · 50 pacientes" — sin saber todavía si
esa organización compró Cultivo. La mitad de la tarjeta era ruido y no había forma de saber cuál
mitad.

Ahora es **Identidad → Módulos → Plan → Acceso → Resumen**, y cada paso usa lo que decidió el
anterior:

- El **plan** muestra sólo los topes que aplican a lo contratado (`PlanEnforcer::RECURSO_SUITE`
  dice a qué suite le importa cada uno, y viaja en el catálogo).
- El **acceso** ofrece sólo los roles que van a poder entrar (`Club::MODULO_POR_ROL`).
- El **resumen** es nuevo: hasta ahora se creaba a ciegas. Nunca se veía junto qué contrató, contra
  qué topes y con qué usuarios.

### Cada adicional, debajo de la suite que extiende

Eran diez tarjetas en una grilla plana: "Buffet" al lado de "Ambiente / IoT" no dice para qué es
cada uno ni qué hay que tener contratado para que sirva. El dato ya estaba —`Club::ADDONS[x][:pack]`,
que la ficha del club ya usaba— y el wizard lo ignoraba. Ahora hay un grupo por suite, uno para los
transversales (IA, chatbot), y el módulo médico va **adentro** del grupo de su suite con candado en
vez de en una sección "Ya incluido" aparte: no es una categoría, es una fila más de lo que se compró.

### Un adicional sin su suite ya no se puede prender

Se podía guardar Delivery sin Producción y dispensa, o IoT sin Cultivo: quedaba un módulo
**contratado que no hacía nada**, y el aviso vivía en el campo `requiere`, en letra chica. El
candado va en el backend (`sin_addons_huerfanos` en `SuperAdmin::ClubsController`) porque por la API
se saltea siempre, y corre **después** de las bajas programadas — al revés, dar de baja una suite le
cortaba hoy mismo los adicionales que la organización ya había pagado.

### El wizard mostraba módulos apagados que nacían prendidos

`SAClubNuevo.vue` tenía su propia lista de qué viene de fábrica (`{cultivo, produccion_dispensa,
bar}`) y el backend mergeaba `Club::FEATURES_POR_DEFECTO` encima, que además trae **Delivery y
Correo**. La pantalla los mostraba apagados y la organización nacía con los dos prendidos. Ahora los
defaults salen del catálogo y el wizard manda **todas** las claves, también las apagadas: una clave
ausente se completa con el default del backend y reaparece prendida.

### Los topes del plan Básico

`1 sede · 3 salas · lotes sin límite · 450 plantas · 50 pacientes`.

**Los lotes dejaron de limitarse.** El lote es una unidad de *organización*, no de capacidad:
ponerle tope empuja a meter todo en un lote gigante para no chocarlo, y eso rompe la trazabilidad,
que es el activo del producto. Lo que mide la capacidad real del cultivo son las plantas.

**Los usuarios dejaron de ser un número.** "5 usuarios" no se puede vender ni explicar, y dejaba dar
de alta cinco cultivadores y ningún dispensador. Ahora el Básico incluye **uno de cada rol** y el
Total no limita. Dos consecuencias:

- **El admin queda fuera del cupo.** No es un puesto de trabajo: es quien contrata, y son dos socios
  más veces de las que es uno solo. Con tope de uno, el día que el único admin se va hay que meter
  mano en la base para devolverle el control a alguien.
- **Qué roles puede tener depende de los módulos.** `Club::MODULO_POR_ROL` generaliza lo que antes
  cubría sólo a `delivery`: cultivador y manicura piden Cultivo, dispensador y médico piden
  Producción y dispensa. Un cultivador en una organización sin Cultivo loguea a una app sin una sola
  pantalla, y el que lo descubre es el cliente.

### La IA: dos tramos que salen del plan, y créditos que se venden

Eran tres tramos (básico/pro/enterprise) elegibles a mano en una perilla propia, así que la misma
organización podía tener el plan **Total** y la IA en **Básico**: la misma decisión escrita en dos
lugares que dejan de coincidir, sin que nadie se entere hasta que el cliente reclama. Ahora son dos
—Básico 500 / Total 2.000 créditos— y **salen del plan**. `ia_tier` queda en la tabla y en la
auditoría, pero no lo lee nadie.

Lo que sí se decide aparte es vender créditos por fuera, que es lo que se cobra: **`ia_recargas`**,
una fila por venta con fecha, cuántos, para qué y quién la cargó. Aplican al mes en curso y **no se
acumulan** — con un número suelto en `clubs` habría que acordarse de ponerlo en cero el día 1 o los
créditos quedarían regalados, y a fin de mes se facturaría de memoria. La ficha del super admin
muestra ahora `del plan / extra vendido / **extra consumido**`, que es el número que se factura.

### Usuarios: los últimos arriba, de a diez

El listado del panel salía ordenado por club y rol, así que el usuario recién creado caía en el
medio y había que buscarlo. Ahora es `created_at DESC`, paginado de a 10, con el filtro por
organización que **existía en el código y no estaba en la pantalla** (se declaraba, se usaba para
filtrar y no había forma de tocarlo) y con reset de página al filtrar — si estabas en la página 7 y
el buscador dejaba 12 resultados, la tabla quedaba vacía y parecía que no había encontrado nada.

## Agosto 2026 (t) — la credencial que repartíamos sin querer

Todo lo de acá salió del escaneo previo al depósito en la DNDA. No es una familia de errores de
diseño como los bloques anteriores: son **cosas que quedaron adentro del repo y de la app sin que
nadie las eligiera**, que es una forma distinta de deuda y se encuentra mirando, no razonando.

### No hay contraseña por defecto

`Club::PASSWORD_DEFAULT = ENV.fetch('CLUB_DEFAULT_PASSWORD', '123456Aa')`. La variable de entorno no
estaba puesta en ningún lado, así que el fallback **era** la contraseña: todo usuario creado desde el
panel de plataforma nacía con `123456Aa`.

Y no era sólo un fallback teórico. El formulario del super admin la traía **precargada en el campo**
(`SAUsuarios.vue`, `SAClubDetail.vue`), y el endpoint `GET /super_admin/catalogo` la **publicaba**
como `password_default` para que la pantalla pudiera hacerlo. O sea: nadie la elegía, todos la
recibían, y sabiendo el email de cualquier persona se entraba a su organización.

Lo llamativo es que la solución ya estaba escrita: `User.password_temporal` existe desde hace meses
para el "restablecer" y arma una clave **dictable por teléfono** (sin 0/O ni 1/l/I, con guiones que
separan los bloques). Sólo que el alta no la usaba.

Ahora cada alta genera la suya, el campo arranca **vacío** con un "dejalo vacío y se genera una", y
la generada se muestra **una vez** para poder dictarla — en un cartel en Usuarios, en un toast largo
en la ficha de la organización. Que se devuelva en claro sigue siendo a propósito: es temporal y
Devise pide cambiarla al entrar.

**Los usuarios creados ANTES la conservan.** `rake seguridad:usuarios_con_password_default` es el
único lugar donde la clave vieja sigue escrita, justamente porque es el que los encuentra. Hay que
correrlo y forzarles el cambio.

### Una sesión real estaba commiteada

`backend/cookies.txt` y `frontend/cookies.txt`: dos cookie jars de curl, en formato Netscape, con
una cookie `HttpOnly` de `cultivo-staging-api.onrender.com`. No el nombre de la cookie — **el
valor**. Se borraron y entraron al `.gitignore`, junto con `backend/config/routes.rbprintf`, tres
líneas de basura de un `printf` mal tipeado que estaban trackeadas desde vaya a saber cuándo.

Borrarlos **no revoca nada**: el valor sigue en el historial de git y la sesión sigue viva hasta que
se rote el secreto en Render. Eso es una acción de infraestructura, no de código.

### La cola offline se comía el trabajo a las 48 horas

Tenía un TTL "para evitar acumulación de entradas huérfanas". El problema es que entradas huérfanas
**no existen**: `marcarEnviado` borra el item, así que todo lo que sobrevive en el localStorage está
`pendiente` o `fallido` — trabajo real que todavía no llegó al servidor.

El TTL sólo podía borrar eso, y lo borraba **en silencio**, reescribiendo el localStorage al cargar.
El caso concreto: la manicura pesa un viernes a la tarde en un galpón sin señal y no vuelve a abrir
la app hasta el lunes. El pesaje desaparecía y nadie se enteraba — justo lo que la cola venía a
proteger, y a los tres días de haberla construido. Se sacó: ahora sólo se descarta cuando el
servidor confirma o cuando alguien lo elimina a mano.

### El portal del paciente se puede vender

Sale de `Club::ADDONS_INCOMPLETOS`. El tablero que le faltaba —credencial, estado del REPROCANN,
turnos, indicación y retiros— se hizo en el bloque (s). Lo que queda depende de cada organización:
cuántas novedades y eventos publique. Eso no es un módulo a medias, y su `requiere` ahora lo dice
así en vez de anunciar que está incompleto. El cajón queda con `bar`, `eventos` y `chatbot`.

**2395 rspec · 1525 vitest · build limpio.**

## Agosto 2026 (s) — el portal se vuelve clínico, y las perillas que no hacían nada

Tres perillas de esta app estaban conectadas a nada: el interruptor "Portal abierto / cerrado",
el cartel de "sin conexión" y la cola de sincronización. Las tres se veían, las tres prometían
algo, ninguna cumplía. Es una familia distinta de la del bloque (r) —allá una regla vivía en dos
lugares que dejaron de coincidir; acá **vivía en cero**— y es peor, porque una regla contradictoria
se nota y una promesa vacía no.

### El inicio del portal es el ESTADO DEL PACIENTE, no el boletín del club

El portal se había rediseñado como boletín —portada de novedades, agenda, catálogo— con este
razonamiento escrito en el código: *"entra a mirar qué hay de nuevo, no a revisar lo que ya hizo"*.

**El razonamiento tenía un error**: trata lo del paciente como PASADO, y casi nada lo es. El
REPROCANN vigente, el próximo turno, la indicación vigente y el saldo son presente y futuro, y son
las cuatro cosas que un paciente entra a preguntar. Encima el boletín está **vacío** en cualquier
organización que no publique —que son casi todas, casi todas las semanas—; su estado no está vacío
nunca.

El orden quedó: **credencial · lo mío · del club**. El boletín no se perdió: es `/portal/del-club`,
la misma pantalla, con su entrada en la barra.

- **La credencial** (`PortalCredencial`) es la pieza central: nombre, DNI, número de socio y el
  REPROCANN como semáforo con la fecha. A pantalla completa con QR, porque es lo único del producto
  que se usa **parado, en la puerta**. Vivía sólo en `/c/:token` —un link que le mandaron una vez— y
  el portal no la mostraba en ningún lado. Vencido, la tarjeta entera cambia de color: es el único
  estado que impide retirar, y con un puntito distinto no se ve.
- **El estado del REPROCANN vive EN la credencial**, no en una franja aparte: es la misma pregunta
  (¿puede retirar?) y separarla obligaba a leer dos cosas en dos lugares. `PortalAvisos` se quedó
  sólo con lo urgente; lo de "vence en 20 días" lo dice la credencial tres centímetros más abajo,
  con la fecha. Una franja que aparece casi siempre se deja de leer a la semana.
- **`/portal/mi-salud`**: turnos e indicación médica. El módulo médico existía desde hace meses y el
  portal no lo leía: el paciente llamaba para saber cuándo era su turno. Se arma con **lista blanca
  campo por campo, nunca `as_json`** — `Turno#notas_post` son las notas del médico para el médico y
  no salen jamás (hay spec que verifica que el texto no aparezca en el body). Los campos de
  `IndicacionMedica` están encriptados y sí se sirven: son suyos y los pide él.
- **Contacto murió como sección**: eran cuatro datos y un formulario de "Envianos un mensaje" que no
  mandaba nada a ningún lado. Bajaron al pie —que **no mostraba teléfono ni mail**—. De paso, en
  escritorio no había ninguna forma de cerrar sesión.
- La barra bajó de ocho entradas a cuatro o cinco.

### "Portal cerrado" no cerraba nada

`clubs.vista_paciente_activa` existía, se editaba en Configuración → Portal del paciente, se
guardaba y viajaba en `/preferences`. **No lo leía nadie.** El admin lo apagaba, la pantalla le
decía "Portal cerrado · Tus pacientes no ven esta sección", y sus pacientes entraban igual.

Ahora es **`Club#portal_paciente_disponible?` = contratado Y abierto**, en un solo lugar, y la
preguntan `User#rol_habilitado?` (el login) y `Portal::BaseController` (la sesión que ya estaba
abierta cuando el admin lo cerró). El mensaje distingue **"lo tienen cerrado"** de **"no tienen el
módulo"**: mandar a contratar lo que ya está comprado deja al admin buscando un botón que no existe.

**Con migración de backfill.** La columna nació con `default: false`, así que sin escribir el valor
que la realidad ya tenía, el día del deploy toda organización con el add-on y el interruptor sin
tocar se quedaba sin pacientes. Es la misma regla que ya costó un susto con los módulos derivados:
cuando un flag pasa a leerse, hay que backfillearlo.

Corolario para los tests: **toda spec que contrate `vista_paciente` tiene que pasar
`vista_paciente_activa: true`**. Son dos llaves. Se corrigieron ocho.

### Configuración se cortaba en pantalla

Ocho pestañas, y tres no eran configuración:

- **Suscripción** eran dos datos, y calculaba el plan mirando `features.ia`/`features.benchmark`
  devolviendo **"Premium IA / Pro / Standard"** — los planes VIEJOS; hoy son Básico y Total — más un
  "acceso completo a todas las funcionalidades" que con suites es falso. Ahora es una tarjeta en
  General con el plan real y los seis topes contra el uso, en rojo el que está lleno, que es lo
  único accionable. (`usePlan` también defaulteaba a `'semilla'`.)
- **Equipo** pasó al menú lateral: gestionar personas no es configurar la app, y su ruta
  (`/usuarios`) ya era de primer nivel — la pestaña sólo la escondía entre ocho.
- **Alertas** pasó a una tarjeta en General, y **su ruta se mudó bajo `/configuracion`**: colgada de
  la raíz y sin pestaña quedaba sin ninguna puerta, y `detectGroup` hacía resaltar *Dashboard*
  mientras estabas adentro.

**Los webhooks salieron de la vista del admin.** No están rotos —`Dispensacion`, `Paciente` y `Lote`
disparan de verdad vía `WebhookDispatcher`, con jobs y registro de entregas— pero configurar uno
pide una URL de destino que sólo existe si el club ya tiene otro programa corriendo, y quien la
consigue es un desarrollador. La maquinaria queda entera; el día que un cliente pida "mandame las
dispensaciones a mi sistema contable", está y anda. **Integraciones pasó a ser la pantalla de
WhatsApp**, gateada por su add-on: se mostraba siempre, y el candado estaba puesto sólo en
`NotificacionDeliveryService`, así que se cargaban las credenciales de Twilio y no salía nada.

Y aparecieron dos **rutas duplicadas sin ninguna puerta**: `/configuracion/sedes` y
`/configuracion/equipo` montaban la misma pantalla que `/sedes` y `/usuarios`. Se llegaba sólo
escribiendo la URL. Redirigen a las canónicas.

### Sin internet

- **La PWA instalada no abría.** `precacheAndRoute` guarda `index.html`, pero una navegación a `/m`
  —que es el `start_url` del manifest— no matchea esa entrada: workbox prueba `/m.html` y
  `/m/index.html`, que no existen, sale a la red y muere en el dinosaurio de Chrome. Se agregó
  `NavigationRoute` con fallback al shell y denylist para `/api`, `/rails`, `/sidekiq`, `/cable` y
  `/up`. En producción esto lo tapaba el `spa_fallback` de Rails; **offline no hay servidor, que es
  justo cuando hace falta**.
- **Las URLs de la cola llevaban `/api`, y el `baseURL` de axios también.** El reintento pegaba a
  `/api/api/lotes/...` → 404. Y un 404 tiene `response`, así que `procesarCola` lo tomaba como error
  de validación y lo marcaba FALLIDO en vez de reintentar. **Nada de lo encolado llegó nunca al
  servidor**: los registros de ambiente cargados sin señal se perdieron, y lo único que se vio fue
  "no pudieron sincronizarse".
- **El cartel dejó de prometer.** Decía "los registros se guardan localmente" y eso valía para tres
  flujos y para ninguno más. Ahora dice lo que siempre es verdad —que no hay conexión, y cuántas
  cosas esperan irse— y cuenta las dos colas. Qué se guarda y qué no lo dice cada pantalla, que es
  la única que lo sabe.

**Qué se guarda sin señal, que es una decisión de dominio y quedó escrita en `lib/offlineApi.js`:**

| | |
|---|---|
| Ambiente | **SÍ** — no mueve stock ni plata |
| Pesaje del manicura | **SÍ** (nuevo) — está frente a la balanza y ya pesó; no genera stock, espera la confirmación del admin |
| Entrega del repartidor | **SÍ**, en su propia cola — lo que se pierde es la FIRMA, y la persona ya se fue |
| Dispensar | **NO** (se sacó) — descontaba de una caché que puede estar vieja: dos dispensadores sin señal entregan el mismo gramo |
| `registrar_directo` del manicura | **NO** — genera stock en el acto |

El pesaje encolado se reintenta con `force_new`: un 409 `needs_choice` ("¿seguir la jornada anterior
o empezar una nueva?") no se le puede preguntar a nadie desde una cola que corre sola, y como tiene
`response` la cola lo marcaría fallido y perdería el pesaje. Abrir una jornada nueva es la salida
sin pérdida — el admin confirma dos en vez de una.

**Sobre reenviar dos veces:** el pesaje **ya era idempotente y no nos habíamos dado cuenta**. La
PLANTA es la clave natural —`distribuir_resto!` sólo toca las que no tienen peso—, así que un
reintento no puede duplicar nada y no hace falta ninguna columna nueva. Lo que faltaba era
**decirlo**: el 422 que devolvía era idéntico a un error de validación, la cola lo marcaba FALLIDO
y la manicura leía "no pudo sincronizarse" sobre un pesaje que sí había entrado. Si a partir de ese
aviso lo volvía a cargar, ahí sí quedaban dos jornadas. Ahora el backend contesta
**`ya_registrado: true`** y la cola lo da por enviado, sin ruido. El `raise` va dentro de la
transacción, así que tampoco queda una jornada vacía por reintento.

### Los tests leen la fuente, no la memoria

Es la lección del bloque (r) aplicada: el test de rutas por rol pasaba en verde con el login del
manicura roto porque repetía la misma lista equivocada que el código.

- `portalPaciente.test.js` (24) **monta las pantallas** y afirma el texto que lee el paciente. El
  build compila una variable inexistente sin chistar y la pantalla explota recién al abrirse.
- `configuracionAdmin.test.js` (13) lee `useNavContext` y el router y exige que **toda ruta de
  `/configuracion` tenga pestaña, enlace o redirect**. Fue el que encontró las duplicadas.
- `sinConexion.test.js` (11) fija la política de qué se encola: si alguien mueve un flujo de cajón,
  falla y tiene que venir a decir por qué.

**2381 rspec · 1518 vitest · build limpio.**

## Agosto 2026 (r) — el manicura no podía trabajar, y el contable no se entendía

Dos días de probar la app con alguien que no la escribió. Casi todo lo que apareció es de la
misma familia: **una regla escrita en dos lugares que dejaron de coincidir**.

### El manicura no podía ni entrar

Al loguearse, "/" lo manda a `/mnc/pendientes` (desde abril). Pero la matriz de prefijos por rol
—agregada en agosto— no incluía `/mnc`, así que el guard lo devolvía a "/", que lo volvía a
mandar a /mnc: un ida y vuelta que Vue Router aborta, dejando la app en el formulario de login.
**El backend autenticaba perfecto**: en los logs se ve `sign_in` 200, `/me` 200, `/preferences`
200 y después nada, porque ninguna pantalla llegó a montarse.

Aterrizar en un lugar prohibido es el peor caso de esa matriz: no te deja entrar a ningún lado.
El resto son botones que rebotan, y también estaban rotos —`/mis-horas` del cultivador, `/stock`
y `/reservas` del dispensador, `/analitica` del supervisor— porque la matriz se escribió de
memoria. **El test que la cubría repetía la misma lista de memoria**, por eso pasaba en verde.
El nuevo lee los sidebars reales y verifica dos cosas: que ningún link que un rol VE lo rebote,
y que su aterrizaje no esté prohibido.

Después, en la misma sesión: **tocar una planta para pesarla** decía "no tenés acceso" (las
pantallas de etiqueta —`/p`, `/s`, `/l`— no estaban en ninguna matriz, y no son una sección del
menú: se llega por la cámara o desde la ficha de al lado). Y **completar su propia tarea** daba
403: `completar_masivo` estaba en el mismo guard que editar y borrar, pero completar de a UNA no
lo está. Completar una tarea es hacer el trabajo, no gestionarlo; lo que se acota es el alcance
—quien no gestiona cierra sólo las suyas—, que además no es cosmético: la acción es un
`update_all`.

**Sin esperar el próximo reporte**, se cruzó la matriz contra las listas de roles que declara cada
ruta. Aparecieron tres contradicciones más; una se arregló y dos quedaron documentadas con su
razón (el super admin no entra a pantallas de organización; `/delivery/despachos` es una decisión
comercial pendiente).

### El módulo contable, rediseñado alrededor de la categoría

El alta hacía las mismas doce preguntas para pagar la luz que para comprar fertilizante. Son dos
cosas distintas, y **el propio modelo ya lo resolvía**: la categoría lleva sector, tipo y si va a
depósito. Ahora es obligatoria, va primera, y de ella sale todo lo demás — el sector se muestra
como consecuencia y cantidad, unidad y depósito aparecen sólo si la categoría stockea. Pagar la
luz quedó en cuatro campos.

Para que eso funcione, el catálogo pasó a **un solo nivel**: las hojas eran los nombres útiles
(Fertilizante, Electricidad, Sueldos) y las madres agrupaban sin clasificar. `rake
categorias:aplanar` PROMUEVE las subcategorías existentes con su sector, su destino y sus
movimientos, y retira las madres vacías — borrarlas hubiera dejado al club con "Insumos".

**Los sectores son cinco y no se crean** (General, Cultivo, Dispensario, Buffet, Otro), y hay **un
depósito por sector y por sede**, según el tipo de sede. Antes cualquiera creaba un área y cada
una arrastraba su depósito: aparecían tres "Cultivo" y el stock quedaba repartido sin saber cuál
era el bueno.

**"Entró plata" se fue del alta.** La que entra ya tiene su puerta y cargarla otra vez la contaría
dos veces: el pago de un paciente se registra en su cuenta corriente (que crea el movimiento
sola), el recupero sale de la dispensación y lo del buffet, del mostrador. Lo excepcional
—subvención, donación, venta de un bien— tiene ahora su propio formulario de cinco campos.

También: `cantidad` y `unidad` en el movimiento (de ahí sale el costo unitario, que antes sólo
existía si la compra entraba a un depósito), `sede` en la categoría, y Contabilidad pasó a ser
grupo de primer nivel — vivía adentro de "Comercial", gateado por la suite de dispensa, así que
una organización de sólo Cultivo no la veía en el menú pero llegaba desde Depósito.

### Los gastos que se repiten se definen una vez

La luz, el alquiler, el contador: todos los meses el mismo formulario tipeado de nuevo. Ahora hay
una solapa al lado de Categorías donde se dan de alta como **entidad**, y arriba del alta de
movimiento un buscador que al elegir uno rellena categoría, sector, sede, monto, cantidad,
unidad, medio de pago y proveedor. La fecha no: el gasto es de hoy, no del día que se definió.

La primera versión fue una casilla "es frecuente" sobre un movimiento ya cargado, y se descartó
el mismo día: así no se puede dar de alta "Luz" antes de la primera factura, ni corregir el monto
de referencia sin cargar un gasto de verdad. La casilla se sacó entera, columna incluida — dos
formas de decir lo mismo es exactamente lo que veníamos limpiando.

**El monto es una referencia, no una promesa.** La luz es fija todos los meses salvo en el monto,
que es justo lo que cambia. Nada se asienta solo: con inflación, un movimiento automático es un
dato falso. Y borrar un molde no toca los movimientos que se cargaron con él, que son movimientos
comunes.

### Salida no es merma

Un club que sólo contrató producción no tiene a quién dispensarle: su única salida era descartar,
y eso lo anotaba como merma. Entregarle producto a otra organización quedaba declarado como
producto **destruido** — el informe de Pérdidas lo contaba y la trazabilidad mostraba gramos
desaparecidos sin explicación, que para un auditor es peor que una pérdida declarada. Y como el
lote se finaliza cuando su stock llega a cero, sin salida legítima sus lotes quedaban abiertos
para siempre.

Ahora el cierre pregunta qué pasó: entregado, vendido, regalado, uso interno o destruido. Sólo el
último deja `merma`. **La regla de oro no cambia**: por el mostrador, lo trazable sale sólo por
dispensación o consumo declarado de un evento.

### Una variable que no existe no puede llegar a producción

"ReferenceError: socio is not defined" al abrir la ficha de un paciente. Tercera vez que pasa lo
mismo: Vite no sabe si un identificador suelto es un global del navegador o un olvido, así que
compila feliz y la pantalla explota al abrirse.

**La red ya existía** —ESLint lo marca con `no-undef`— y nadie la corría. Ahora corre como test, y
al prenderla aparecieron cuatro bugs vivos: editar cualquier movimiento contable, abrir la hoja de
lectura ambiental desde una sala, exportar a Excel y restablecer la contraseña de un usuario.
Ninguno estaba reportado.

De paso, la tabla de estados por tipo de sala pasó a viajar en `/me`: estaba escrita dos veces y
las copias se sincronizaban a mano.

### Lo chico que se nota

El estado del lote se acota al tipo de sala (en una de floración sólo hay floración) y **la sala
que falta se crea desde el alta**, pidiendo sólo el nombre. Las observaciones del stock aparecen
en Inventario y en la dispensación —donde dos frascos idénticos sólo se distinguen por eso—. El
vencimiento se dice "2 años y 7 meses" en vez de "947 días restantes". Y el cartel del informe
semestral dejó de sugerir que la plataforma presenta los informes ante el Ministerio de Salud: los
genera, los presenta la organización, y ARICCAME sigue simulado.

Suite: 2197 rspec + 1359 vitest + build limpio. **Manual: `rake categorias:aplanar`** (con
`SIMULAR=1` primero).

## Agosto 2026 (q) — ocho cosas que el sistema decía mal

Un bloque de correcciones sobre datos que la app mostraba o guardaba de una forma que no se
correspondía con lo que había pasado de verdad. No hay feature nueva: hay ocho lugares donde el
registro y la realidad se habían separado.

**Un DNI no puede ser único en toda la plataforma.** Se había leído el requisito del REPROCANN
—una persona se registra con UN cultivador a la vez— como si fuera una restricción de nuestra
base. No lo es, y traía tres problemas: quien se iba de una organización y entraba a otra no se
podía dar de alta hasta que la primera lo borrara (hacer depender el alta de un cliente de que
otro cliente haga algo, sin forma de pedírselo ni de saber a quién); el mensaje de error
**confirmaba que ese DNI existe en OTRA organización**, que es un dato de salud de alguien que no
es su paciente; y con `acts_as_paranoid` el registro borrado seguía ocupando el índice, así que
ni borrándolo se liberaba. Ahora es único por organización, con índice parcial sobre los no
borrados. La regla del organismo sigue existiendo donde corresponde: en el trámite, que lo
controla quien ve el padrón completo.

**El informe INASE declaraba variedades que la organización ya no trabaja.** "Eliminar" una
genética es `activa: false` —no se borra, puede tener lotes colgando— y el informe las leía todas.
Ahora declara las activas **más las archivadas que llegaron a cultivarse**: filtrar sólo por
activas era el error opuesto, y dejaba el informe sin cuadrar contra las plantas y los gramos que
sí figuran.

**El KPI de la sala mostraba el clima de la incubadora.** El registro ambiental cuelga del LOTE y
se propaga con el `sala_id`; un lote enraizando se mide **adentro del propagador** —28 °C y 90 %,
que es su objetivo— y eso salía publicado como el aire del cuarto. Peor: las reglas ambientales de
la sala se evaluaban contra ese número, así que la alerta de humedad alta saltaba cada vez que
alguien registraba un enraizado. Ahora hay un punto de medición (sala / incubadora) que **se
deriva del estado del lote**, no se pregunta en ningún formulario: dónde se midió es dónde está la
planta. El cuarto y el domo tienen su propio KPI, y el VPD automático ya no cruza la temperatura
de uno con la humedad del otro.

**La trazabilidad de un frasco listaba las diez plantas del lote.** Trazar es decir de qué plantas
salió ESTE frasco, no qué plantas tuvo el lote. Se leía sólo el vínculo del flujo viejo
(`Pesada`), así que un stock nacido del flujo de manicura —por donde entra hoy toda la flor seca—
no encontraba nada y caía a "todas las plantas del lote", **descartadas incluidas**: plantas que
no produjeron un gramo, presentadas como origen del producto. Ahora sale del pesaje por planta,
con lo que aportó cada una; cuando no hay pesaje individual se dice explícitamente que la
atribución es a nivel de lote; y las descartadas van aparte, con su motivo, para que la resta
cierre a la vista.

**Poner en maceta es prender.** Enraizado ⇔ sin maceta: el que enraíza vive en taco o bandeja. La
mitad de la regla ya existía (pasar a vegetativo exige indicar la maceta); faltaba la vuelta, y
quedaban lotes "enraizando" con maceta de 5 L. El caso que lo destapó: separar 5 plantas de un
lote enraizando poniéndolas en maceta de 0,5 L —que es exactamente el acto de prenderlas y
trasplantarlas— dejaba el lote hijo en enraizado. Ahora la regla vive en el modelo y cubre las
cuatro puertas (alta heredada, desprender, trasplante, edición), arrastra a las plantas y deja su
evento de fase. **No es una validación:** como validación volvía inguardable un lote que ya estaba
mal, y hay que poder corregirlo.

**El modal de editar lote pedía cosas que no son del lote.** Los días objetivo por fase son de la
**genética** —una Lemon florece lo que florece— y editarlos por lote era la puerta para que dos
lotes de la misma variedad tuvieran objetivos distintos sin razón; ahora se muestran y se editan
donde viven. Las fechas de inicio por fase se ofrecen **sólo hasta la fase actual**: un lote
enraizando no tiene fecha de floración, y el campo invitaba a inventar historia hacia adelante.

**Las salas son sólo de cultivo.** Manicura y cosecha son etapas del LOTE, no lugares que alguien
tenga que dar de alta. El alta de escritorio ya no las ofrecía, pero el onboarding —la primera
sala de una organización nueva— seguía ofreciendo Manicura, el modal de editar también, y el
backend no validaba nada: por API entraba cualquiera. Las salas de proceso que quedaron de cuando
se auto-creaban conservan su tipo en una opción bloqueada, para que editarles el nombre no se las
pise.

**Contabilidad: cuánto se compró.** La cantidad vivía sólo adentro del bloque de inventario, así
que un gasto que no entra a ningún depósito —diez horas de electricista, tres análisis de
laboratorio— no tenía dónde decirlo y se quedaba sin **costo unitario**, que es el número con el
que se compara un proveedor contra otro. Ahora cantidad y unidad son del movimiento y el bloque de
depósito las refleja: se siguen cargando en un solo lugar, que era el motivo de la regla anterior,
pero ese lugar es el cuerpo. Además la categoría puede acotarse a una **sede**, "¿va a depósito?"
se pregunta en castellano en vez de pedir un "comportamiento" (y **a cuál** lo decide el sector,
que ya tiene el suyo: una decisión menos que no puede contradecir a la otra), y los sectores se
marcan según el pack contratado —se informan, no se filtran: sus movimientos históricos siguen
existiendo y su columna del P&L tiene que seguir cuadrando—.

Suite: 2115 rspec + 1275 vitest + build limpio. Migraciones nuevas:
`dni_unico_por_organizacion`, `punto_de_medicion_ambiental`,
`cantidad_en_movimiento_y_sede_en_categoria`.

## Agosto 2026 (p) — lo que se contrata, aplicado de punta a punta

El bloque anterior convirtió Delivery, Correo e IA en módulos que se venden y se dan de baja.
Este cierra la otra mitad: que **prender y apagar cambie algo de verdad** en las tres capas —la
pantalla, la URL y la API—, porque un interruptor que no controla nada es peor que no tenerlo.

**El registro por voz estaba roto para toda organización moderna, y el botón se veía igual.**
`features` guarda la clave nueva (`ia`) y cada acción del asistente chequeaba además la vieja
(`ia_voz`). `feature?` resuelve viejo ⇒ nuevo, **no al revés**, así que devolvía false y el
endpoint contestaba "no está disponible para este club" mientras la pantalla mostraba el botón:
`features_expandidas` —lo que lee el frontend— sí lo derivaba. **Prendido en el panel, prendido
en el menú y rechazado al dictar**, que es la peor de las tres combinaciones porque parece un
error de la persona. Ahora `features_expandidas` deriva en los DOS sentidos (menos lo que está
en construcción, que no se enciende por la puerta de atrás) y el módulo se chequea **una sola
vez, en un `before_action`**: las cuatro acciones repetían el suyo con la clave equivocada.

**Delivery: se gateó el rol y se olvidaron los endpoints.** El repartidor no podía entrar, pero
el admin no depende del rol — seguía armando rutas y marcando envíos de un módulo que la
organización no tiene contratado. Ahora lo piden `rutas_entrega` y las acciones de reparto. **La
excepción es el punto importante:** `entregar` y `reportar_fallo` quedan afuera. Con el módulo
apagado el repartidor no puede ni loguearse, así que si el cierre también estuviera bloqueado no
quedaría **nadie** que pudiera registrar cómo terminó un paquete que ya está en la calle: se
quedarían abiertos para siempre. Es la misma decisión que ya tomaba `AplicarBajasModulosJob`, que
suelta lo pendiente y no toca lo que está en viaje. Y el candado de verdad va en el modelo: el
envío se marca al CREAR la dispensación, que es un endpoint de la suite, así que sin
`Dispensacion#delivery_contratado` apagar Delivery dejaba el checkbox "con envío" funcionando y
generando paquetes que nadie puede repartir. Es `on: :create`: lo que ya existe se sigue pudiendo
cerrar.

**WhatsApp: el interruptor manda, no las credenciales.** El servicio elegía el canal mirando
sólo si Twilio estaba cargado, así que a una organización a la que se le apagaba el add-on le
seguían saliendo —y cobrándose— los mensajes. Apagado, el aviso sale por mail, que es el canal
de siempre, en vez de perderse.

**La URL entraba aunque el menú escondiera la sección.** Escribir `/ariccame` a mano abría la
pantalla y recién ahí el backend contestaba 403: se veía un cascarón vacío con un error suelto.
El router ahora resuelve **qué módulo exige cada sección por PREFIJO, en una sola tabla** —son
151 rutas y marcar cada una en su `meta` es acordarse en cada alta—, gana el prefijo más largo
(`/bar/eventos` pide Eventos, no sólo el Buffet) y las secciones transversales no llevan bandera
a propósito. Sólo bloquea con las features ya cargadas: rebotar por una carrera de arranque sería
peor que dejar pasar, porque el backend sigue siendo la barrera real. En el menú, **Comercial**
pasa a depender de la suite de dispensa y **Despachos** de Delivery.

**Los módulos del super admin salen de la ficha y tienen pantalla propia** (`SAModulos`), y
cambia la mecánica: **cada interruptor se guarda solo**. Había un "Guardar" arriba de una lista
larga — se tildaban tres módulos, se cambiaba de pestaña y no se había guardado ninguno.
Confirmar dos veces una decisión de una sola cosa no la hace más segura, la hace más fácil de
perder; lo único que pregunta antes es la **baja**, que tiene consecuencias y una fecha que hay
que leer. **La IA queda con un solo control:** había dos perillas y la que estaba a la vista era
la que menos importa (el tope por hora), cuando lo que se cobra es el mensual. Y **se ve el
consumo del mes** —llamadas contra tope, costo, hit ratio del caché y apertura por función—: se
medía desde el 11-ago y no se exponía en ningún lado, así que se fijaba el tope sin poder mirar
contra qué. Los tramos ahora los manda `GET /super_admin/catalogo`: estaban copiados a mano en el
template, la misma duplicación que ya había pasado con la lista de módulos. Y el alta de usuarios
del panel acepta **`email_personal`**: confundía el identificador de login con el mail real de la
persona, así que el usuario nacía sin dirección a la que escribirle y los avisos rebotaban.

**Cierre: 2029+ rspec ✓ · 1264 vitest ✓.** Los tests nuevos incluyen el que faltaba de la tabla
de rutas, el de la pantalla de módulos **montada** (no compilada) y el del canal de WhatsApp sin
stubear a Twilio.

---

## Agosto 2026 (o) — organizaciones, el correo como módulo y la IA que se puede cobrar

**Club → Organización en todo el texto visible** (76 archivos entre frontend, backend, informes
y mailers). El producto no es sólo para clubes: también para investigación y producción. Se
cambia lo que se LEE; identificadores, rutas, clases CSS, stores, el modelo `Club` y `club_id`
quedan igual — misma regla que Socio → Paciente. Lo caro del rename es la concordancia (club es
masculino, organización femenino). De paso: **"Club Cultivo" es el nombre del REPOSITORIO, no
del producto** — el producto es **Cultivo Espacial**, y estaba mal en 15 archivos que ve el
usuario, incluidos los pies de todos los mailers y el prompt del asistente.

**El super admin ya no revienta fuera de su panel.** Es el único rol sin club: `current_user.club`
es nil y el tenant queda sin fijar, así que cualquier endpoint de organización —una pestaña
vieja, un link pegado— moría con un 500 pelado (hay 180 usos de `current_user.club.algo` fuera
del panel). Ahora `block_super_admin_sin_contexto!` responde **409 diciendo qué falta y cómo
conseguirlo**: abrir la organización desde el panel. Observando sí hay tenant, así que pasa de
largo.

**Cuánto IA consume cada organización, y un tope que se pueda cobrar.** No había forma de
contestar "cuánto consumió esta organización en julio": el rate limit vivía en Redis con TTL de
una hora y el consumo no se guardaba. `ia_llamadas` guarda cada llamada con organización,
persona, función, modelo, tokens y **el costo congelado** —los precios por millón cambian y un
informe de julio tiene que seguir diciendo lo que costó julio—; un modelo que no esté en la tabla
de precios se cobra al más caro conocido, porque cobrar de menos pasa desapercibido. Registran
las cinco funciones (asistente parsear y consultar, análisis de lote, plan de trabajo, mapeo de
CSV), también las fallidas, que cuestan igual.

Con eso se cerraron **tres bugs del rate limit**: contaba por USUARIO cuando el límite es de la
organización (cinco personas en básico daban 100 llamadas/hora en vez de 20); sólo lo chequeaba
el asistente, así que análisis de lote, plan de trabajo e importación de CSV eran ilimitados; y
`rescue false` dejaba de aplicar el límite en silencio si Redis se caía. Ahora **manda el tope
MENSUAL**, que se cuenta contra la base y no depende de Redis; el horario queda como freno de
ráfaga.

**Caché de prompt en el asistente.** El bloque fijo son ~1.400 tokens idénticos en cada dictado
de cada cultivador y se pagaban enteros todas las veces: el 90% del volumen de IA. `system` pasa
a ser un array de dos bloques —el fijo con `cache_control`, que se lee a 0,1×, y el contexto
después del corte—. `consultar` queda como estaba a propósito: su parte estable son ~60 tokens
contra un mínimo cacheable de 1024, y el marcador ahí no ahorraría nada. Para poder medirlo,
`costo_de` aprendió a sumar los tokens escritos y leídos de caché, y `resumen_mes` informa el
**hit ratio**: si queda en 0 con el asistente en uso, algo está invalidando el prefijo.

**El panel del super admin pasa de lista de avisos a cola de trabajo.** No faltaba información:
faltaba que cada fila dijera qué hacer. Ahora cada pendiente lleva su acción —Cobrar y renovar ·
Asignar suite · Completar configuración · Revisar sensores— y se agrupa por urgencia con el
motivo escrito: **Se está perdiendo plata** · **Paga y no le funciona** · **Avisar con tiempo**.
El orden es por plata, no por tipo de problema.

**Delivery y Correo pasan a ser módulos contratables**, y con ellos aparece la baja que respeta
lo pagado. `delivery` era un rol suelto: toda organización con Producción y dispensa podía
repartir. **Una baja no corta el servicio: fija una fecha** (`features_baja` guarda hasta cuándo
sigue andando; volver a prenderlo antes la cancela). Cuando llega, `AplicarBajasModulosJob` apaga
la bandera y **deja ordenado lo que el módulo dejaba colgando**: en Delivery suelta los repartos
que no salieron y avisa al admin, pero **lo que está EN VIAJE no se toca** —cortarlo dejaría al
repartidor con producto y sin poder registrar la entrega—. Las dos migraciones llevan backfill
obligatorio: sin él, el día del deploy las organizaciones que ya usaban el módulo se quedaban sin
él.

**El correo tiene pantalla propia y plantillas de cada organización.** Sale de Configuración →
General, donde estaba mezclado con el nombre y el logo, y pasa a su solapa: primero la casilla,
después las plantillas, porque sin casilla conectada las plantillas no sirven — y la pantalla lo
dice en vez de ofrecer un editor que no manda. Eran cuatro textos hardcodeados en el frontend
mientras el backend validaba sus NOMBRES: la plantilla de un lado y su validación del otro. Las
variables `{{nombre}}` se resuelven por `gsub` contra una **lista blanca cerrada, nunca ERB**: es
texto de usuario y evaluarlo sería ejecución de código en el servidor (hay un test que le mete
`<%= User.first.email %>` y verifica que salga literal). La bienvenida ahora viaja EN el alta y
sale **cuando corresponde**: admin y médico en el acto; el mostrador, recién al aprobar.

**Envíos masivos, con una regla que ordena todo: un mail por destinatario.** La selección
múltiple es de la interfaz; el backend arma un destinatario por persona. Con todos juntos en el
`To:` —o en BCC— cada paciente recibiría el padrón completo: nombre y mail de todos los demás.
Es una fuga de datos de salud (Ley 25.326) y no se puede deshacer; hay un test que verifica que
cada mensaje entregado tenga exactamente UNA dirección. **Tope diario propio de 450**, por debajo
de los ~500 de Gmail: pasarse no nos afecta a nosotros, le **suspenden la casilla al cliente** —
y con ella se cae hasta el mail de bienvenida. Se chequea ANTES de crear el envío, nunca a mitad
de camino. Quien no tiene dirección queda afuera **con nombre y apellido**: un contador de "3
salteados" no sirve; saber a quién llamar por teléfono, sí.

**El alta desde el mostrador pasa a ser una solicitud, no una admisión.** Verificar el REPROCANN
contra el certificado y el consentimiento de datos de salud no es trabajo de mostrador con la
persona esperando adelante — pero tampoco se puede mandar de vuelta a quien llega. El dispensador
y el supervisor cargan la ficha y queda **pendiente**: existe, se completa, y no recibe
dispensaciones ni reservas hasta que admin o médico la aprueben. **El bloqueo vive en los modelos**
(`Dispensacion` y `Reserva`), que es por donde pasa toda entrega. El default se invirtió a
propósito: un alta nace aprobada salvo que venga del mostrador — al revés, importar un padrón de
300 los dejaba a todos sin poder retirar.

**Contabilidad: el total manda.** El precio por unidad es una cuenta, no un campo — eran tres
inputs ligados y había que adivinar cuál mandaba. Ahora total + cantidad + unidad, y el unitario
se muestra calculado. **"Por categoría" mostraba "Otro" para todo** porque agrupaba por el string
legacy; ahora agrupa por la categoría real, sumando las subcategorías dentro de su madre. **La
categoría es el atajo, no la puerta**: nunca fue obligatoria en el backend y el frontend la
exigía igual, así que ahora los flujos y el catálogo coexisten de verdad. Y **el tipo lo elige la
persona**: estando en "Salió plata" sólo se ofrecen egresos, también al buscar — antes elegir una
del otro tipo daba vuelta el formulario "para ayudar", y un egreso terminaba guardado como
ingreso sin aviso. El sector deja de ser opcional al crear una categoría madre: con "sin sector"
por defecto, la plata caía en un limbo del balance por área.

**El onboarding y las sedes se alinean con las suites contratadas.** Una organización de sólo
Cultivo no atiende pacientes (no le sirve una sede social) y una de sólo dispensa no tiene salas:
ofrecer los tres tipos siempre era mandarla a un error que no puede resolver. La regla vive en
`Sede::SUITES_POR_TIPO` y la aplica el **controller, no el modelo** —como validación volvía
inguardable una sede que ya existía si se daba de baja una suite—. Sin Cultivo, el paso de la
sala se saltea entero.

**El tope de sedes no se esquiva apagando una, y ahora se avisa antes.** `puede_crear_sede?`
contaba las activas: en el plan Básico se podían tener todas las que quisieras creando, apagando
y volviendo a prender. Ahora cuenta las que EXISTEN, igual que las salas. Y el aviso llegaba
después de llenar el formulario: ahora "Nueva sede" chequea el tope al tocarlo y explica el
límite — el botón queda visible con candado, porque esconderlo no explica nada. **Una
organización suspendida veía 403 pelados**: el backend mandaba el motivo y nadie lo miraba. Ahora
hay un cartel a pantalla completa que dice qué pasó, a quién escribirle y —lo que más importa—
**que la información está resguardada**.

**Una tarea de mañana no se completa hoy — ahora en serio.** La regla existía sólo en la interfaz
y con criterio distinto por pantalla; el backend no validaba nada, ni en `completar` ni en
`completar_masivo` (que hace `update_all`). Estaba escondida, no aplicada. En la tanda se rechaza
el lote entero si hay una sola futura: filtrarla en silencio la dejaría sin hacer y sin que nadie
se entere.

**El QR de planta abría una pantalla vacía.** `PlantaQrView` hacía `usePWA()` sin haberlo
importado nunca: el setup explotaba y no se renderizaba una línea. **El build no lo caza** — Vite
no sabe si es un global del navegador o un olvido. Va con un test que barre 322 archivos y
verifica que todo `useAlgo(` que coincida con un composable o store del proyecto esté importado;
encontró **dos más** (`LoteQrView` igual de roto y `MScanView`, que es la pantalla desde la que se
llega a las otras dos). Y de paso la colisión de rutas que el propio `routes.rb` advertía: `/p` y
`/s` existían a nivel root y se comían la navegación del SPA devolviendo JSON; los datos pasan a
`/api`, que es de donde el frontend YA los pedía. Efecto colateral: el QR de stock, que devolvía
404, quedó arreglado.

**En la tabla de lotes, desde cuándo está en la fase.** "12d" solo no dice nada: se suma la
columna **Desde** y la línea de tiempo completa en el tooltip del badge. La fecha sale del MISMO
cálculo que `dias_en_estado`, con un test que verifica que no se contradigan. Se toma la ÚLTIMA
entrada a cada estado, no la primera: si un lote se avanzó por error y volvió, importa desde
cuándo está DONDE ESTÁ. `dias_floracion` sigue usando la primera y está bien — mide otra cosa.

**La lista de pacientes se lee:** "Apellido, Nombre" (la lista se ordena por apellido, así que es
lo que se recorre con la vista), REPROCANN partido en estado y "Vence", `table-layout: fixed` con
`<colgroup>` para que el email deje de comerse el sobrante. Y el badge salía de
`reprocann_vencimiento`, así que un trámite **pendiente** caía en "Sin REPROCANN": el mismo bug
que ya se había corregido en la ficha.

**Varios de uso diario:** el domicilio dejó de frenar la edición (la validación estaba duplicada
y se sacó de un solo lado), el error de guardado pasa a una franja fija arriba de los botones —al
final del cuerpo scrolleable no se veía y "Guardar" parecía no hacer nada—, el admin en el celular
ya no ve "Plantas" en el menú, y los **manuales de usuario** dejaron de parecer un borrador. **El
ícono de la PWA era un placeholder de marzo** (un cuadrado verde con un emoji 🌿): el manifest
usa el logo real en PNG, porque Chrome de escritorio elige mal entre íconos SVG al instalar.

**Rake nuevo:** `pacientes:normalizar_nombres` — capitalización de las cargas masivas ("Martin
Ezequiel BLANCO" → "Blanco"). No inventa acentos y respeta partículas y apóstrofos. `SIMULAR=1`.

**Cierre: 2029 rspec ✓ (0 fallas) · 1220 vitest ✓ · build limpio.**

---

## Agosto 2026 (n) — el panel de plataforma: el plan mide, las suites habilitan

**Dos planes en vez de cuatro, y el plan dice CUÁNTO, nunca QUÉ.** Convivían dos sistemas que
se contradecían: los planes (semilla/brote/cosecha/federación) fijaban los límites duros y las
suites decidían las capacidades, así que un club "federación" sin suites quedaba sin límites y
sin poder hacer nada. Ahora hay **básico** y **total**, y sólo miden crecimiento: sedes, salas,
lotes, plantas, pacientes y usuarios.

**Vuelve el límite de plantas** — con el tope sólo en lotes, dos lotes de mil plantas pasaban
por el plan chico — y **se suma el de salas**, que no existía. El de salas cuenta las salas que
EXISTEN y no las activas: si contara sólo las activas, se abrían salas sin techo poniéndolas
todas en mantenimiento. `PlanEnforcer` decide todos los límites de cobro y no tenía un solo spec.

**Los módulos, en tres cajones.** El **módulo médico y el correo salen de los add-ons** y pasan
a venir dentro de la suite de Producción y dispensa: los dos viven de la ficha del paciente, así
que un club de sólo Cultivo no los ve, y poder apagárselos a uno que sí la tiene era una perilla
que —olvidada— lo dejaba con media ficha. No se guardan como bandera: se derivan de la suite,
para que no puedan contradecirla. **La web pública pasa a llamarse "Vista del paciente"** y queda
EN CONSTRUCCIÓN: se lista para que nadie la prometa creyendo que está, y no se puede activar ni
por la API.

**Los interruptores dejaron de mentir por omisión.** Era lo más caro del panel: se prendía
WhatsApp y no pasaba nada hasta cargar Twilio tres pantallas más allá; se prendía Correo y no
andaba sin SMTP. Ahora cada módulo reporta su **estado real** —`andando`, `no funciona todavía`,
`apagado`— con qué le falta a ESE club, y la ficha abre diciendo cuántos módulos están prendidos
sin hacer nada.

**El alta, en cuatro pasos:** Identidad → Plan (dos tarjetas con sus topes) → Módulos (los tres
cajones) → Acceso. **La contraseña temporal se ve y se copia** —detrás de puntitos había que
acordarse de lo que uno mismo acababa de tipear— y al terminar entrega los datos de acceso
juntos. Los roles del alta se reducen a los cinco del arranque (admin, médico, cultivador,
dispensador, manicura), **filtrados también en el backend** porque el endpoint aceptaba
cualquiera que le mandaran.

**Un catálogo servido por el backend** (`GET /super_admin/catalogo`): la lista de módulos estaba
duplicada a mano en tres vistas y ya decía cosas distintas entre sí.

**El panel contesta qué hacer hoy, no cuántas plantas hay.** Era un recuento de plantas, lotes y
pacientes sumando todos los clubes: eso no le sirve a quien vende el software y tapaba lo único
accionable. Ahora responde tres preguntas en orden — **quién vence, quién necesita algo hoy y
quién se está por ir** — y los agregados se mudaron a **Informes**, donde son la semilla del
benchmarking del sector. "Necesita que hagas algo" junta planes vencidos, clubes sin suites,
módulos prendidos que no funcionan y **clubes que pagan IoT con las sondas calladas** — el fallo
silencioso que sólo se cazaba corriendo un rake a mano. "En silencio" es el churn que todavía no
pasó, medido por la última dispensación y el último lote. **Adopción** muestra contratado contra
andando: la diferencia es el trabajo pendiente.

**Shell del super admin al mismo patrón que el resto**, con el menú de usuario que no existía
—el logout era un ícono suelto al pie del sidebar— y **Mi perfil**, que no tenía ninguna
pantalla. Vive dentro del shell de plataforma porque `/perfil` no es hija de ese layout y
mandaba a una pantalla pelada sin forma de volver.

**Ahora queda rastro de lo que hacemos nosotros.** `Club` no era auditable y ninguna acción de
super_admin se registraba: cuando un club reclamaba "yo no pedí que me cambien el plan" no había
forma de saber quién ni cuándo. Allowlist estricta, con las credenciales fuera y un test que lo
verifica, e historial en la ficha del club.

**Modo observador: construido y SUSPENDIDO.** Entrar a medias a un club que está trabajando se
nota. Funciona el club efectivo, el tenant, el gating por los módulos del club observado y el
bloqueo de datos clínicos —que necesitó candado propio, porque los guards del namespace médico
dejan pasar a `super_admin` a propósito—, pero los guards de ROL de 26 controllers lo dejarían
navegando secciones vacías y 403. Queda apagado con `User::OBSERVADOR_HABILITADO`: una bandera
deja todo inerte, el endpoint responde 503 y una migración limpió las observaciones vivas.
**Para reactivarlo hace falta darle rol efectivo de admin del club observado.**

**Deploy:** `db:migrate` (`migrar_planes_a_basico_total`, `limpiar_features_incluidas_en_suite`,
`limpiar_observaciones_activas`).

## Agosto 2026 (m) — pérdidas, el arrastre del "mixto" y el design system completo

**Informe de PÉRDIDAS**, que no existía. Producción cuenta lo que salió bien y trazabilidad
cierra el balance de un producto, pero el club no tenía dónde ver cuánto se cayó en total.
Muestra plantas descartadas **con su motivo** —que es lo accionable: varias por plaga es un
problema de sala, varios machos es un problema de semilla—, la merma declarada, los ajustes de
inventario en menos, y el stock vencido que sigue en góndola (todavía no es pérdida, pero lo va
a ser). Una dispensación no cuenta como pérdida.

**`rake dispensaciones:recalcular_medio_pago`** para el arrastre del placeholder: las dispensas
que quedaron marcadas "mixto" antes del fix se recalculan desde sus cobros reales, con el mismo
criterio que `afinar_medio_pago!`. Un solo medio → ese medio; dos distintos → mixto de verdad;
sin cobros y sin contra entrega → no se toca, porque no hay con qué decidir y adivinar sería
peor.

**Design system (#40) completo:** 3.403 reemplazos en toda la app, con el mismo valor exacto —
ni un pixel distinto— más 46 fallbacks anidados simplificados. El test recorre ahora todos los
componentes: el gris de la app se cambia en un solo lugar y no puede volver un hexadecimal a
mano.

## Agosto 2026 (l) — los informes dicen a quién le hablan

El problema no era que faltaran columnas: los informes estaban armados **por entidad** y no
**por pregunta**, así que cada uno mostraba el conteo de su tabla y entre ellos daban números
distintos del mismo dato sin explicar por qué. Se separaron tres lectores: el organismo (lo que
se presenta), el dueño (análisis) y el que opera hoy (pendientes accionables).

- **REPROCANN declara la población REGISTRADA.** Sólo entran los que tienen trámite —vigente,
  vencido o en curso—; los que no lo iniciaron se informan aparte, porque son un pendiente
  interno y no algo que se presenta. **Se sacó el corte por sede: un paciente es del club.** Lo
  que agrupaba era la sede de su última dispensación, una dimensión que no existe en el modelo,
  y por eso los que nunca retiraron caían en una fila que parecía una sede.
- **Producción separa el período del presente.** Arriba lo cosechado en el período; abajo "Hoy
  en el cultivo" con el rendimiento acumulado. Ese era el bug de los 0 g.
- **Dispensaciones** suma DNI parcial, genética y forma: sin eso no se cruza con producción.
- **Trazabilidad** suma el BALANCE (producido − dispensado − merma = en stock, con el % que
  llegó al paciente). Mostraba la cadena pero no la cerraba.
- **INASE** agrupa por variedad acreditable: veinte genéticas declaradas contra la misma
  variedad daban veinte filas con el mismo nombre.
- **Todos llevan una reseña** de una o dos frases: qué contestan y con qué criterio.

**El padrón vive en Pacientes, no en Informes**, porque es la pantalla desde la que hay que
actuar. Los conteos se hacen sobre la NÓMINA (los que están en tratamiento): los dados de baja
no son pacientes del club y antes inflaban el total. Se suma "Sin retirar +90d".

**El enraizado tiene columna propia en Analítica**, con el origen al lado (semilla / esqueje) —
un esqueje y una semilla no enraízan igual— y ahora sí entra en el "Total cultivo".

**Salas madre:** `madre` y `clon` son sub-tipos de vegetativo y faltaban en
`KINDS_SALA_POR_ESTADO`, así que no se podía crear un lote en la sala de madres. Y en el alta,
el estado va antes que la sala, porque las salas ofrecidas dependen de la fase.

## Agosto 2026 (k) — el modal contable reordenado y el design system por superficies

**Nuevo movimiento se lee de arriba a abajo.** El problema no era el estilo: el único campo
obligatorio —Categoría— vivía en la columna secundaria bajo un título en jerga ("Se registra
así"), o sea que lo que bloquea el botón Guardar estaba en la columna que parece opcional. Y al
lado convivía con Comprobante, N° y Notas, que se tocan una de cada veinte veces. Ahora la
categoría abre el formulario (además es el atajo que completa tipo, sector y depósito), lo
secundario queda plegado con un resumen que avisa si hay algo adentro, "Cómo se pagó"
desaparece si marcaste Pendiente, y el modal pasa a una sola columna. Sin signos de pregunta:
eran seis "¿…?" seguidos.

**Design system (#40): cuatro superficies migradas** —super admin, Buffet, Contabilidad e
informes del auditor—. El método importa más que el resultado: `ink` (gris neutro) y `slate`
(azulado) NO son intercambiables, así que en vez de reemplazar la escala se le dio nombre a la
que ya se usaba, con el valor exacto. Ni un pixel distinto, y el gris de la app se cambia en un
solo lugar. El test recorre los directorios completos y falla si vuelve un hexadecimal a mano.

## Agosto 2026 (j) — la sede que no acotaba nada, y el módulo contable que no cerraba

**Una entrega sin cobros figuraba como pago "mixto".** Mixto significa que se pagó de dos
formas distintas, no que no se pagó. Dos piezas se tapaban: la reserva creaba la dispensación
con `medio_pago: 'mixto'` de placeholder "que los cobros afinan", y `afinar_medio_pago!` con
CERO cobros también resolvía 'mixto' —porque `[].size == 1` es false—. Cuando no había resto
que cobrar (la seña cubrió todo, o se cobra contra entrega), nadie corregía el placeholder.

**Asignarle una sede a un dispensador no servía de nada en el inventario:** veía —y podía
dispensar— el stock de TODAS las sedes del club. Ahora `User#sedes_visibles_ids` manda en el
listado de stock, en la pestaña de inventario y en las reservas. Sin sedes asignadas se sigue
viendo todo (club de una sola sede, o admin que no se asignó ninguna), y el stock del pool
—que no es de ninguna sede— se ve siempre.

**El informe de Producción decía 0 gramos** con veinte lotes curados: los sumaba de la tabla
`pesadas`, que el flujo real no llena (el club pesa por `PesajeManicura`). Y **se contradecía
solo**: el KPI "Plantas en pie" daba 156 y la tabla del mismo informe sumaba 548, porque una
contaba plantas vivas y la otra el `plants_count` declarado. Los dos arreglados y verificados.

**Del módulo contable**, siguiendo la idea de que la categoría tiene que trabajar por el
usuario:
- **Cantidad × precio c/u = total**, los tres campos ligados. La multiplicación va en centavos
  enteros: `2,5 × 3,33` daba 8,32 en punto flotante y en plata eso no se deja pasar.
- **La categoría define el tipo**: ya sabía el sector y el depósito, pero el combo filtraba
  *por* tipo, así que había que acertar "Salió plata" primero. Sigue sin ser obligatorio
  empezar por ahí — es un atajo, no un peaje.
- **"Registrar pago"** sobre cada gasto pendiente. Se podía marcar la deuda pero no saldarla:
  el total por pagar no bajaba nunca.
- **Filtros por sector**, y filtrar por una categoría madre ahora trae lo de sus hijas (antes
  devolvía vacío, porque los movimientos cuelgan de las subcategorías).

**De ocho informes a seis:** Cumplimiento era REPROCANN con otro título (sus KPIs salían de los
mismos conteos) y Sedes era el conteo de plantas de Producción partido por sede. Los endpoints
siguen respondiendo; salen de la navegación.

**Design system (#40), primera superficie:** los grises del panel de super admin salen de
tokens. La clave fue no reemplazar la escala: `ink` (neutro) y `slate` (azulado) no son
intercambiables, así que se le dio nombre a la que ya se usaba, con el valor exacto. 259
reemplazos, ni un pixel distinto, y un test que impide que vuelvan los hexadecimales a mano.

## Agosto 2026 (i) — declarar una genética ante el INASE

Los clubes cultivan variedades que **no** están inscriptas en el INASE, y la forma de
etiquetarlas es declararlas contra una que sí lo está. Eso pasaba en la etiqueta de papel y la
app no se enteraba: el informe INASE mostraba el nombre de fantasía y "sin registrar", que no
es lo que el club presenta ante el organismo.

Ahora cada genética puede declararse contra una variedad inscripta. El catálogo ya existía —las
8 variedades del INASE son genéticas globales, compartidas por todos los clubes— así que lo
único que faltaba era el vínculo: `geneticas.declarada_como_id`. Declarar es **opcional**: no
traba el alta ni el cultivo, y lo que queda sin declarar aparece listado como pendiente.

**Dónde se usa el nombre declarado y dónde no.** En los informes REGULATORIOS —INASE,
trazabilidad y semestral— sale la variedad inscripta, que es con la que se acredita. En las
pantallas internas (lotes, plantas, producción, analítica) sigue saliendo el nombre real: el
cultivador trabaja con "Northern Lights" y ver "ANANDA001" en su lista de lotes no le dice
nada. El informe INASE suma una columna "Se cultiva como" para que la traducción sea auditable
sin salir del documento.

El informe pasa a distinguir tres situaciones donde antes había dos: inscripta, declarada y
**sin acreditar**. Sólo la tercera es un pendiente, y tiene su propia sección al pie —lo único
accionable del informe—. `rake geneticas:sin_declarar` lista lo mismo por consola.

**El guard va en la descarga, no en la pantalla.** Un informe que se presenta ante el organismo
no puede nombrar variedades que el club no puede acreditar, así que el PDF y el Excel del
informe INASE, la trazabilidad y el semestral se niegan a generarse y devuelven cuáles faltan.
La PANTALLA se abre siempre: es la que lista los pendientes, y bloquearla dejaría al club sin
poder ver su propio problema —con veintipico de variedades sin declarar, nunca se destrabaría—.
Del lado del front, la descarga usa `responseType: 'blob'`, así que el cuerpo del error también
llegaba como blob y el rechazo se mostraba como "no se pudo generar, reintentá": ahora se lee y
se muestra el motivo real con la lista.

**Backfill de lo que ya estaba declarado a mano.** Antes de que existiera el vínculo, los clubes
escribían el par dentro del nombre: *"Blue Sherbet - Tropicana WFC"*. Eso ya es la declaración,
sólo que en un lugar que la app no puede leer. `rake geneticas:declarar_por_nombre` la reconoce,
la convierte en vínculo real y limpia el sufijo del nombre (el par pasa a vivir en el vínculo).
Si el nombre limpio chocara con otra genética del club, la declara igual pero no la renombra y
lo avisa. El slug no se toca, para no romper links de la web pública que estén circulando.

## Agosto 2026 (h) — el historial del delivery daba 403 y la pantalla decía "no hay nada"

**El repartidor no podía ver su propio historial.** `require_dispensaciones_role!` le permite al
rol `delivery` una lista corta de acciones y `mi_historial` no estaba en ella: el backend
respondía 403. El otro guard del mismo controller (`require_dispensador_o_admin`) sí lo
exceptuaba — dos guards, uno abierto y otro cerrado, el mismo patrón que el loop del login en la
PWA. Y el front hacía `catch { paquetes = [] }`, así que el error se veía como *"Todavía no
cerraste ninguna entrega en este período"*: fallaba en silencio. Ahora el historial carga, y
"vacío" y "no se pudo cargar" son dos pantallas distintas, la segunda con reintento.

**El rango de días filtraba por `updated_at`**, la última vez que se tocó el registro, no por
cuándo se cerró la entrega. Con eso el filtro mentía: una entrega de hace 40 días que después se
editó (un cobro corregido) volvía a caer dentro de "7 días". Pasa a `COALESCE(entregado_at,
fallido_at, updated_at)`, y `reportar_fallo` ahora **sí** registra cuándo falló: una entrega
guardaba `entregado_at` y un fallo no guardaba nada, así que el otro final posible del viaje no
tenía fecha propia. Columna `dispensaciones.fallido_at`, con los fallos ya existentes
rellenados desde `updated_at` — que es lo que el filtro venía usando igual.

**Los "No entregados" vuelven a arrancar desplegados.** Al hacer plegables las listas los había
dejado cerrados por defecto —el repartidor no puede resolverlos, los reprograma el admin— pero
esconder algo que acaba de pasar se lee como que no se registró.

## Agosto 2026 (g) — el lote que no cerraba, y los pacientes con iniciales

**Un lote no pasaba a "finalizado" al dispensarse.** `Dispensacion#decrementar_stock` descuenta con
`decrement!(:cantidad)`, que baja la cantidad pero **no toca el estado del stock** — y el callback
que cierra el lote escucha el cambio de estado. Resultado: se dispensaba un lote hasta el último
gramo, el stock quedaba `asignado` en cero y el lote se quedaba en `curado` para siempre. La
finalización automática sólo ocurría desde los ajustes manuales de inventario. Ahora la
dispensación marca el stock agotado cuando llega a cero, y eso cierra el ciclo.

**Y al revés: había lotes "finalizados" con producto adentro.** El informe de trazabilidad mostraba
un ciclo cerrado con 485 g sin dispensar. No lo hizo el flujo real: lo sembró `Clubs::SembrarDemo`,
que elegía el estado por antigüedad y después le sorteaba el gramaje, sin cruzarlos. Eran 16 lotes,
todos del Club Modelo. Se corrigieron tres cosas: el sembrador reconcilia estado y stock, hay un
rake para los que ya estaban mal (`lotes:corregir_finalizados_con_stock`) y —lo que faltaba de
raíz— **una validación**: un lote no puede pasar a `finalizado` si le queda producto. La regla
existía en un solo método y cualquier otro código la salteaba.

**Los derivados cuentan.** Un lote cierra cuando se agotan su flor **y** sus elaborados (el hash
lleva el `lote_id` del lote del que salió). Además, elaborar hash con el último gramo de flor
cerraba el lote un instante antes de que el derivado existiera: ahora el "agotado" del origen se
marca al final de la transacción, con el derivado ya en la base.

**En `/lotes` no se podía filtrar por "Finalizado".** Los lotes cerrados viven detrás de un tab que
no se lee como filtro, y el desplegable de estados excluía la opción a propósito. Ahora está, y
elegirla lleva al tab donde están — ofrecerla sin eso habría devuelto cero resultados.

**Dos bugs que aparecieron en el camino:** `LoteEvento` exigía `user`, pero el cierre automático
del lote nace de un callback donde no hay `current_user`: la última dispensación de un lote habría
fallado. El autor ahora viaja desde el llamador (`Stock#usuario_movimiento`). Y el atajo "todas las
plantas descartadas → finalizado" no miraba si el pesaje de manicura ya había creado el contenedor
de flor.

**Los pacientes salían con iniciales en los informes** ("A.G.") bajo la nota "el informe no expone
datos personales". No protegía nada —quien abre un informe ya puede ver la ficha completa del
paciente— y volvía las tablas ilegibles: dos "G.L." son indistinguibles y no se pueden cruzar con
nada. Ahora van con nombre y apellido en dispensaciones, trazabilidad (pantalla y PDF) y analítica;
el DNI sigue parcial. Las notas al pie que afirmaban anonimato se corrigieron: decían algo falso.

## Agosto 2026 (f) — qué pasa cuando un club apaga un módulo

Tres pendientes que resultaron ser la misma pregunta vista de tres lados.

**Los jobs no sabían nada de las suites.** Ninguno de los 13: corren fuera de un request, así que
no pasan por `check_club_activo!` ni por `require_feature!`. Un club que apagaba un módulo seguía
recibiendo sus alertas como si nada. El caso más caro no era ruido interno: `ReprocannVencimientoJob`
le manda el aviso de vencimiento **al paciente**, no al club. Ahora los jobs recorren con
`ApplicationJob#cada_club_con(:suite)`, que resuelve club operativo + suite prendida + tenant +
rescue por club, las tres cosas que cada uno repetía a mano o se olvidaba. `AlertaDetectorService`
es mixto —cuatro detectores de cultivo y uno de cuenta corriente— así que filtra adentro, detector
por detector.

**Y una capa que estaba escondida abajo:** `Club.activos` es `where(deleted_at: nil)`, pero
suspendido es `!activo?`. O sea que un club que dejó de pagar pasaba el filtro, y hasta los ocho
jobs que ya usaban `activos` —los que parecían correctos— le seguían mandando alertas y mails.
Scope nuevo `Club.operativos`: ni eliminado ni suspendido. `activos` queda como estaba para no
tocar a sus otros llamadores.

**El rol huérfano.** Un cultivador en un club que apagó Cultivo entraba igual, caía en el home y
cada endpoint suyo le devolvía 403 sin decir por qué: se veía como la app rota. Ahora
`User::MODULOS_POR_ROL` decide, el login lo rechaza nombrando el módulo que falta, y
`check_rol_habilitado!` cubre las sesiones ya abiertas (si el admin apaga el módulo al mediodía, el
front lo saca con el motivo en vez de llenarse de pantallas vacías). `admin`, `super_admin`,
`auditor` y `abogado` nunca se bloquean: los dos últimos tienen que poder mirar el histórico de un
módulo dado de baja. **Al dispensador le alcanza con `produccion_dispensa` O `bar`** — también
atiende el mostrador del Buffet, y hay clubes que compraron sólo eso.

**Los informes de un club que se baja de una suite: no hay nada que apagar.** No existe informe
persistido —ni modelo ni tabla—, cada apertura los recalcula sobre datos vivos. Consultarlos es
lectura pura y queda sin gating: un club dado de baja puede necesitar mostrarle papeles a un
auditor. Lo que sí se apaga es la emisión automática, o sea `InformeSemestralJob`, el único informe
que se manda solo.

**La ingesta de IoT ahora exige el add-on** (`Webhooks::LecturasController` devuelve 403, no 401:
el token es válido, lo que falta es el módulo). Nadie desenchufa un sensor porque el club se dio de
baja. ⚠️ **Esto necesita `rake suites:prender_iot_con_dispositivos` junto con el deploy**: el flag
`iot` nunca existió como bandera vieja —ninguna migración lo escribe— así que hoy ningún club lo
tiene, y sin el rake todo club con hardware deja de recibir datos en silencio.

**Del delivery.** Su logout vivía al fondo del sidebar, y el sidebar se esconde en mobile — o sea
que estaba a dos toques de distancia (hamburguesa → scroll) para el único rol que trabaja siempre
desde el celular. Pasó al menú de usuario de la topbar, como en todos los demás roles. Y las tres
listas del dashboard se pliegan, con contador al costado y la elección recordada entre viajes; los
"no entregados" arrancan cerrados, porque el repartidor no puede hacer nada con ellos.

**De paso:** `Dispositivo has_many :lecturas_ambientales` no declaraba `class_name`, así que Rails
buscaba `LecturasAmbientale` y **borrar un sensor tiraba 500**.

## Agosto 2026 (e) — el login esperaba al club, y dos catálogos que no coincidían

**El login que se trababa.** `login()` hacía `await club.fetch()` (GET `/preferences`) **antes** de
`router.push`, y el `finally` que libera el botón recién corre después de eso: si `/preferences`
colgaba —backend despertando—, el spinner no paraba y no se navegaba nunca. Afectaba **sólo a los
roles sin home propia** (admin, dispensador, cultivador, manicura, supervisor); médico, auditor,
abogado, delivery y super_admin se salteaban esa línea, y por eso a ellos les funcionaba. El club se
carga ahora en segundo plano —ninguna vista lo necesita para pintar— y el login tiene un techo de
15s por las dudas. El test lo reproduce: con el `await` puesto, se cuelga y falla por timeout.

En el camino se arreglaron dos cosas del mismo arranque de sesión: `main.js` llamaba a `fetchMe()`
directo (no a `ensureBootstrapped`), y `fetchMe` levantaba el `loading` del botón de login en **cada
arranque de la app**; además salían dos `/me` en paralelo por dos caminos distintos. Ahora `fetchMe`
**no puede** tocar ese flag —le sacamos el parámetro— y el bootstrap está memoizado.

**Dos catálogos que no coincidían**, los dos daban 422 sin explicación:
- `PlanTarea::TIPOS` tenía 8 tipos y el formulario ofrecía 13: guardar un plan con *nutrición*,
  *defoliación*, *SCROG/LST*, *ajuste de luz* o *revisión de plagas* fallaba. Ahora usa `Tarea::TIPOS`
  —una PlanTarea se materializa como Tarea, así que dos listas distintas garantizan que algo se rompa.
- El formulario de tareas **de mobile** creaba con `prioridad: 'media'`, que no existe en el enum
  (`baja normal alta urgente`): no se podía crear una tarea desde el teléfono. Los estilos de "media"
  quedan como alias para no romper lo ya guardado.

**Del dispensador:** el mostrador puede cargar la mercadería que recibe (`comprar`, con costo y
egreso a su nombre) y vender lo que no está en el catálogo (línea suelta "Otro / Varios", que
registra la venta sin tocar inventario). Se le retiró `reponer`, que subía stock **sin costo y sin
asiento**. El panel del Buffet cuenta las ventas sueltas del mes para que la gestión cargue esos
productos. Y el buscador del Buffet ahora busca por código de barras: el campo existía, pero el
filtro sólo miraba el nombre y el cartel decía "(pronto)".

## Agosto 2026 (d) — la PWA del cultivador es la sala, no la app entera

- **Las tareas atrasadas se arrastran a hoy también en el teléfono.** El escritorio ya lo hacía;
  mobile mostraba el día literal, así que 19 tareas vencidas quedaban escondidas en su día original
  y "hoy" aparecía vacío. La lógica salió a `useSemanaTareas` y ahora la comparten las dos vistas —
  una tarea que venció y sigue pendiente no es historia del martes, es trabajo de hoy.
- **La barra del cultivador queda en Cultivo · Escanear · + · Tareas · Mis horas.** A una planta se
  llega escaneando su QR o desde su lote, que es como se trabaja parado en la sala; una lista de
  todas las plantas en el celular no se usa, y Genéticas es material de consulta de escritorio.
- **El cultivador no crea salas**: el backend ya devolvía 403, pero la UI seguía ofreciendo el botón
  en el estado vacío de la sede — un camino que sólo llevaba a un error.
- **Al crear un lote sólo se ofrecen salas donde ese lote puede estar.** Un lote nuevo arranca
  enraizando y va a vegetativo: en 12/12 no germina ni prende nada, así que las salas de floración
  dejan de ser opción. Un lote existente sólo ve salas compatibles con la fase que declara. Y con
  varias sedes, se filtra por sede antes de elegir.
- **El KPI "N listos para avanzar" abre cuáles son**, con la fase actual, la siguiente y los días en
  fase, y cada uno navega a su lote. Era un número que no llevaba a ningún lado.
- **La semana de trabajo se pliega a partir de la quinta tarea por día.** Con 19 tareas la columna
  era ilegible. Lo atrasado y lo urgente quedan arriba —así lo que se esconde es lo menos
  importante— y el contador del encabezado sigue mostrando el total real.

## Agosto 2026 (c) — el cultivador veía lotes pero ninguna planta

El síntoma era ese, y la causa una asimetría: `lotes#index` tenía una red de seguridad para el
cultivador **sin sedes asignadas** (le muestra todo el cultivo del club) que `plants#index` y
`plants#kpis` no tenían — `where(sala_id: [])` devuelve cero filas, sin error ni aviso. Ese fallback
estaba escrito a mano en **cuatro** controllers y faltaba justo en los dos de plantas. Ahora vive
dentro de `User#salas_ids_asignadas` y los cuatro lo consumen.

De paso apareció el mismo agujero por otro lado: al cosechar, el lote **suelta la sala** para liberar
el slot (`avanzar_fase!` deja `sala_id = nil`), así que filtrando sólo por sala **las plantas de un
lote cosechado o en manicura no le aparecían nunca** al cultivador, ni en la lista ni en los KPIs.
El scope nuevo `Lote.al_alcance_de` resuelve el post-cosecha por **sede**.

- **Cambiar la fase de una sala ya no revegeta lotes en silencio.** Mover lotes a otra sala pedía
  confirmación lote por lote; editar el `kind` de la sala hacía lo mismo por la puerta de atrás, sin
  preguntar nada: un lote en día 45 de floración volvía a vegetativo y perdía el contador de días.
  Ahora el backend **frena** y devuelve qué lotes se verían afectados, con cuántos días de fase
  pierde cada uno; recién con el sí explícito se guarda. Y se le aplicó la misma guarda que ya tenía
  la acción "Cambiar fase": con esquejes enraizando adentro, la sala no pasa a 12/12.
- **Cosecha: un solo formulario.** El modal que se abría dependía de si el lote tenía plantas
  individuales cargadas — un dato que el cultivador no eligió ni ve. Ahora es el mismo, con un
  contador en lugar de la grilla cuando el lote sólo lleva el total. La **letra de corte** se pide
  únicamente cuando aporta (cosecha parcial o ya hay cortes previos). Y el cultivador que tocaba
  "avanzar fase" con el lote ya cosechado recibía *"Lote no puede transicionar en este estado"*:
  ahora se le dice que la asignación a manicura la hace el admin.
- **Días: dos columnas.** El número decía días **totales** y el semáforo de al lado medía días **en
  la fase** contra su objetivo. Ahora son "En fase" (con el semáforo) y "Total", como ya lo mostraba
  el historial de la sala.
- **La maceta aparecía dos veces** (columna y badge de estado): queda en su columna, que además sirve
  post-cosecha, donde el badge no la mostraba.
- **"Vaso" fuera**: el envase no es el dato, los litros sí — y 0,335 L y 0,5 L son los dos "un vaso".
  La lista de tamaños estaba copiada en **cinco** archivos, dos con valores distintos; ahora sale de
  `MACETA_OPCIONES`.
- **Bug del formulario de avanzar fase**: el campo "¿cuántas prendieron?" estaba **duplicado literal**,
  con el mismo `v-model`.
- **Análisis de laboratorio**: botón Cancelar (antes había que crear y borrar), aire y tokens del DS.
- **Historial del cultivador**: el código de lote se partía en dos líneas — columna de 110px y un pill
  sin `nowrap`.

## Agosto 2026 (b) — el médico tenía tres puertas para lo mismo

Testeando el rol médico apareció que había **dos fichas del mismo paciente** (`/medico/pacientes/:id`,
que es `SocioDetailView`, y `/medico/pacientes/:id/ficha`, con Timeline y Notas repetidos), más
pantallas propias de Indicaciones y Documentos que listaban las de **todos** los pacientes mezclados.
Y un tercer dashboard médico muerto en `components/dashboards/`, que además hacía una request por
paciente. **La ficha ahora es una sola**, y lo que era una pantalla pasó a ser una tab de su paciente.

- **Indicaciones es una tab del paciente.** Ya existían por paciente, pero escondidas dentro de la
  tab REPROCANN. Ahora tienen tab propia (admin y médico editan, supervisor lee) y arriba muestran
  el **consumo dispensado** (90 días, promedio mensual, sparkline) — que es el contexto con el que
  se prescribe, y era lo único que valía la pena rescatar de la ficha eliminada.
- **Documentos: lo clínico entra por un solo lado.** Había **dos modelos** conviviendo: la pantalla
  del médico escribía `Documento` (sin cifrado) y la ficha del paciente lee `PatientDocument` (con
  cifrado, firma y hash) — un PDF subido por una puerta no aparecía nunca por la otra. Los tipos que
  faltaban (receta, certificado médico, estudio clínico, DNI) se sumaron a `PatientDocument`. Los
  tipos institucionales del club dejaron de ofrecérsele al médico: no es él quien sube el estatuto.
- **Duración y vencimiento dejan de pisarse.** `calculate_fecha_vencimiento` sobrescribía el
  vencimiento **siempre** que hubiera `duracion_dias`, en alta y en edición, sin avisar: el médico
  escribía una fecha y el sistema la cambiaba. Ahora la duración **propone** (un tratamiento de 90
  días puede vivir dentro de una indicación válida hasta que venza el REPROCANN) y la fecha escrita
  a mano **gana**. El form dice cuál de las dos está mandando, y la lista marca la indicación sin
  fecha con "no genera alertas" — que era un agujero silencioso.
- **"Mis Pacientes" se pagina en el servidor** (antes: todos los pacientes del club en un JSON sin
  techo, y filtrado dos veces —server-side y otra vez en el cliente—). Filtros y KPIs pasan a ser
  server-side: contando en el cliente, "3 vencidos" podía significar 40. El **orden ya no es
  alfabético sino de agenda**: primero quien tiene turno con ese médico, después quien tiene una
  indicación por vencer, y la fila dice por qué está arriba.
- **Design system**: las vistas del médico usaban verdes Material hardcodeados (`#1b5e20`,
  `#14532d`, `#2e7d32`, `#f0fdf4`) en vez de los tokens `leaf`. Reemplazados.

**Nota:** la campana de alertas del médico **ya existía y funcionaba** (`MedicoTopBar`, con el
backend filtrando por `destinada_a_role`); el `NotificationBell` de `App.vue` que solo ve admin y
cultivador pertenece al layout viejo.

## Agosto 2026 (a) — la raíz deja de ser un formulario de login

Quien entraba al dominio sin sesión caía directo en el login: una pantalla que pide usuario y
contraseña sin explicar antes qué es esto. Ahora **`/` sin sesión muestra `/bienvenida`**, una
landing pública. Con sesión, `/` sigue siendo el dashboard de siempre — el dashboard **no se movió**,
así que los ~17 "Inicio" de sidebars, topbars y breadcrumbs siguen apuntando donde apuntaban.

El otro problema era de posicionamiento: el login se presentaba como **"Plataforma REPROCANN"**, con
REPROCANN también entre las tres métricas y como la primera de las tres features. Eso encajona el
producto en un registro y en un país, y deja afuera a cualquier organización que cultive por
investigación o para producir.

- **Landing (`LandingView.vue`)** con el eje corrido a lo que el producto realmente hace: *"Una
  plataforma para toda organización que cultiva: clubes, investigación y producción."* La cadena
  genética → lote → planta → cosecha → stock → entrega como columna vertebral, tres públicos
  explícitos y la grilla de módulos.
- **REPROCANN y ARICCAME siguen estando, pero como consecuencia y no como identidad**: son una salida
  de la data que ya se carga operando, tercera de las cuatro capacidades.
- **El login quedó sobrio**: se le sacó la columna de marketing (la veían operadores que entran a
  trabajar todos los días, no prospectos) y quedó el card centrado en cualquier tamaño de pantalla,
  con un enlace a la landing. De paso **se alineó al design system**: era la única vista con paleta
  propia, con verdes Material hardcodeados en vez de los tokens `leaf`.
- **Las rutas públicas ya no chocan contra la matriz de roles**: un `medico`/`auditor`/`delivery`
  logueado que abría un carnet o un pasaporte de dispensa recibía "Sin permisos" y era expulsado a su
  home. Ahora `meta.public` queda fuera de ese chequeo.

## Julio 2026 (ae) — mover un lote NO lo saca del enraizado

La regla de "el lote toma la fase de la sala destino" estaba mal enunciada. Lo que una sala impone no
es la etapa: es el **fotoperíodo**. Vegetativo y floración se diferencian por eso (18/6 vs 12/12) y
una sala solo puede correr uno, así que la planta que entra a un cuarto de 12/12 va a florecer.

Pero **enraizado y vegetativo comparten fotoperíodo**: los dos son 18/6. Meter un clonador en una
sala de vegetativo no le cambia nada — recibe la misma luz. Lo que lo tiene enraizando es que
**todavía no tiene raíz**, un estado de la planta y no algo que el cuarto le haga. Por eso el
clonador puede convivir en la sala de vegetativo, y por eso **de enraizado se sale cuando prende, no
cuando cambia de cuarto**. Ni siquiera una sala de floración lo saca: un esqueje sin raíz no florece.

El preview del diálogo también se corrigió en las dos pantallas: si el enraizado no va a cambiar, no
lo anuncia.

## Julio 2026 (ad) — mover lotes desde /lotes, y buscar/filtrar dentro de la sala

Mover lotes solo estaba en la ficha de la sala, y ese es el lugar equivocado para la mitad de los
casos: desde ahí solo se pueden mover los lotes **de esa sala**. `/lotes` es donde se ven todos
juntos y es el único lugar desde el que se puede agarrar lotes de salas distintas y mandarlos a la
misma.

- **"Mover a…" en la barra de selección de `/lotes`**, al lado de las etiquetas. Mismo diálogo que
  enumera lote por lote qué va a cambiar de fase antes de confirmar. Los lotes post-cosecha se
  ignoran: ya no viven en una sala.
- **Dentro de la sala: buscar por código o genética, filtrar por fase y seleccionar todo.** Con 30
  lotes, tildar de a uno para mover media sala no era una opción. "Seleccionar todo" toma lo
  **filtrado**, no la página — misma regla que la selección de etiquetas.
- **La maceta también en las tarjetas de lote de la sala** (`🪣 0,5L`), para que sea coherente con el
  badge y con la columna que ya estaba en la tabla de `/lotes`.

## Julio 2026 (ac) — la maceta, con su número, y la alerta de raíz enrollada

El período del vasito **sí** es distinto del vegetativo pleno —el pan de raíz se seca rapidísimo, la
EC recién arranca, y si te pasás de tiempo la raíz se enrolla y la planta se achaparra—, pero **no es
otra fase fisiológica: es vegetativo en maceta chica**. Modelarlo como estado hubiera repetido el
error que veníamos de sacar: un estado que en realidad es "la misma etapa con un modificador".

Y "esqueje" no era el nombre: un esqueje es el **corte**, o sea el origen. La prueba es que un lote
de semilla tendría que pasar por "esqueje", y una plántula nunca fue un corte.

- **El badge muestra la maceta real**: `Vegetativo · 0,5L`, no una etiqueta tipo "en vaso". 0,33L y
  0,5L no son lo mismo.
- **Alerta `maceta_chica` escalada por volumen.** El tiempo hasta que la raíz se enrolla no es un
  número fijo de días: depende de los litros (≤0,4L → 12d; ≤0,6L → 18d; ≤1,5L → 25d; ≤4L → 35d;
  arriba de 4L se asume maceta final y no se avisa). **Guardar el número real es justamente lo que
  hace posible la alerta**: con una etiqueta difusa no se podría calcular.
- Se cuenta desde el **último trasplante** (o el inicio del lote si nunca se trasplantó), y solo en
  vegetativo: en enraizado la planta está en taco y el reloj que corre es el del prendimiento.

*Se asume que dentro de un lote todas las plantas están igual (decisión de Germán: varios lotes antes
que macetas mixtas). Si eso cambia, el dato hay que bajarlo a la planta.*

## Julio 2026 (ab) — el modelo se colapsa: germinación + esqueje → enraizado

Eran **dos estados para una sola etapa**: la planta sin raíz funcional. Lo que de verdad las separaba
no es la etapa sino el **origen** —de dónde viene la planta—, que ya vivía en su propia columna.
Tenerlos como estados obligaba a duplicar setpoints, reglas y líneas de informe para algo idéntico, y
era la razón de que un admin cargara los clonadores como "esqueje" cuando estaban enraizando.

**Dos ejes independientes:** `estado` (enraizado → vegetativo → floración → cosecha…) y `origen`
(semilla | esqueje). El origen **ya no define la fase inicial**: los dos arrancan enraizando.

- `Lote::ESTADOS`, `AVANCE`, `CULTIVO_ESTADOS`, `FASE_A_PLANT_STATE`, `estado_inicial_para_origen`,
  `progreso_ciclo`; `Plant::STATES`; `LotePolicy`; y las listas de estados de lotes, sedes, stats,
  analytics, asistente y benchmark.
- **El avance del ciclo tiene un paso menos**: antes germinación→esqueje→vegetativo, ahora
  enraizado→vegetativo.
- `fase_setpoint` del detector de alertas queda sin traducción: el estado ya *es* la fase.
- **Migración de datos** (`lotes.estado`, `plants.state` y el historial en `lote_eventos`, que guarda
  los estados como texto y si no se migra deja la timeline mostrando fases que ya no existen).

**Ambigüedad histórica que hay que revisar a mano:** `esqueje` se usó con dos sentidos según quién
cargó —"está en el clonador" y "esqueje ya prendido en vaso"—. Los dos caen en `enraizado`; los que
ya habían prendido hay que promoverlos a vegetativo (se ven por sus días en fase). La migración es
irreversible por diseño: al colapsar se pierde cuál era, y reconstruirlo desde `origen` inventaría
datos.

## Julio 2026 (aa) — % de prendimiento: la métrica que se perdía

Los esquejes que no agarraban caían en `descartada` mezclados con plagas, machos y roturas. El
motivo del descarte existía solo como **texto libre** (iba a las notas y al evento del lote): sirve
para leer una planta, no para preguntar *"¿cuántos esquejes no prendieron?"*.

- **`plants.motivo_descarte`** (estructurado) convive con el texto libre, que se queda para el
  detalle. Motivos: `no_prendio`, `plaga`, `enfermedad`, `macho`, `hermafrodita`, `estres`, `rotura`,
  `otro`.
- **Sin fricción nueva:** descartar una planta que estaba **enraizando** se clasifica sola como
  `no_prendio` —descartar algo que todavía no tiene raíz *es* que no prendió— y fuera del enraizado
  el default es `otro`, que no ensucia la métrica. Un motivo explícito le gana al default.
- **Revertir un descarte borra el motivo**: si no, seguiría contando como "no prendió" una planta
  que está viva.
- **`GET /analytics/prendimiento`** — global y **por genética**, que es donde el dato sirve: hay
  cepas que prenden al 95% y otras al 60%, y eso cambia cuántos cortes hay que hacer. `intentos`
  incluye a las descartadas (si salieran del denominador el % daría siempre 100), y todo lo que no
  falló al enraizar cuenta como prendido — una planta perdida por plaga en floración igual había
  enraizado bien. **Un lote que está enraizando ahora no se mide**: todavía no tiene resultado, e
  incluirlo daría un prendimiento falsamente alto.
- Sin datos devuelve porcentaje **nulo**, no 0: "0% de prendimiento" donde no hay dato es peor que
  no mostrar nada.
- Tab **Prendimiento** en Analítica, con el % en color (≥85 verde, ≥70 amarillo) y la nota de qué
  revisar cuando baja del 70%.

## Julio 2026 (z) — el enraizado deja de medirse con la vara del vegetativo

`AlertaDetectorService` mandaba germinación y esqueje a los setpoints de **vegetativo**, con un
comentario que dejaba escrita la suposición equivocada ("comparten fisiología"). Es al revés: son
opuestas. Con los rangos de vegetativo (`humedad 50-70%`, `EC 0.8-1.4`) el sistema quedaba **ciego
para el problema real y gritando por el que no existe**:

- un clonador a **60% de humedad** —donde los esquejes se deshidratan y no prenden— **no disparaba
  ninguna alerta**, porque 60 cae cómodo dentro de 50-70;
- un clonador con **EC casi nula** —que es lo correcto, un esqueje sin raíz no absorbe— disparaba
  una **falsa alarma de EC baja** todos los días.

- **Rangos propios de enraizado**: humedad 85-95%, temperatura 22-26 °C, EC 0-0.6, pH 5.5-6.0.
- **Temperatura de sustrato al monitoreo** (24-26 °C). Es la variable que decide si prende, más que
  la del aire: por debajo de 22 °C el enraizado se frena aunque el cuarto esté perfecto. La columna
  existía en `RegistroAmbiental` y nadie la miraba. Las fases que no declaran rango de sustrato lo
  saltean, así que no aparecen falsos positivos en vegetativo ni floración.
- **Chequeo diario**: `DIAS_SIN_REGISTRO` no tenía entrada para enraizado y caía al default de 3
  días. Es la etapa más frágil del ciclo; va en 1.
- **`SetpointFase`: la fase `clon` pasa a `enraizado`** (migración incluida). "Clon" dejaba afuera a
  las plántulas de semilla, que están en la misma etapa. La fase existía desde siempre y **nunca se
  había usado**, porque el detector desviaba el enraizado antes de consultarla.
- `AlertaInterna::TIPOS_CULTIVO` suma `temperatura_sustrato_fuera_rango`.

## Julio 2026 (y) — mover lotes de sala, ambiente de la sala y el esqueje que no existía

**El bug: el registro ambiental de una sala se salteaba los esquejes.** `salas#registrar_sala` tenía
la lista de estados escrita a mano (`%w[vegetativo floracion]`) y se olvidaba de `esqueje` y
`germinacion` — justo las fases donde el ambiente más importa, porque un esqueje sin raíz depende del
aire para no deshidratarse. No era una decisión: el propio modelo **exige sala** para esos estados
(`validates :sala_id, presence: true, if: CULTIVO_ESTADOS.include?(estado)`), o sea que están en el
cuarto respirando el mismo aire. Ahora usa `Lote::CULTIVO_ESTADOS`, la fuente única. El mismo olvido
estaba en el dashboard de sede (`sedes#serialize_ops`), donde un lote en esqueje no contaba como vivo.

**Mover lotes de sala (nuevo).** Hasta ahora la única forma de que un lote cambiara de sala era
avanzando de fase, así que rebalancear salas, vaciar una para limpieza o corregir un alta obligaba a
fingir un avance y ensuciaba la historia. Nuevo `POST /lotes/mover`, en tanda y **entre sedes**:
- **El lote toma la fase de la sala destino.** Una sala en floración da 12/12: lo que entra ahí pasa a
  florecer, y sus plantas con él. El cuarto define el fotoperiodo, no el papel. Una sala **mixta** no
  impone nada — ahí conviven fases distintas a propósito.
- Mover a otra sede **cambia la sede del lote**, y con eso a dónde imputan sus costos.
- Deja `LoteEvento` con `sala_origen`/`sala_destino` (los campos ya existían para esto).
- En la UI: checkbox por lote y barra flotante. El diálogo **enumera lote por lote qué va a cambiar**
  antes de confirmar, en vez de un "¿estás seguro?" genérico, y avisa que pasar a floración no se
  deshace. `ConfirmDialog` pasó a `white-space: pre-line` para poder mostrar esa lista.

**Ambiente actual en la ficha de sala.** Los `RegistroAmbiental` cuelgan del lote, no de la sala, así
que "el ambiente de la sala" es el registro más reciente entre sus lotes. Se muestra temperatura,
humedad y **VPD calculado** (con temperatura de hoja estimada 2 °C por debajo del aire), con su nivel
en color. Siempre **con la antigüedad y el lote del que salió**: sin sensores el dato puede ser de
hace una semana, y mostrarlo pelado te haría creer que es de ahora.

**Dashboard de sede: plantas por fase en vez de un total.** "800 plantas" no dice nada: es un número
muy distinto si son 700 esquejes o 700 en floración — cambia el consumo, el riego, el espacio y lo que
vas a cosechar. Ahora germinación · esquejes · vegetativo · floración · cosechadas, contando por el
estado de la **planta** (dentro de un lote conviven estados por cosecha parcial), y mostrando solo las
fases que tienen algo.

## Julio 2026 (x) — el evento se arma como se piensa, y las entradas se imprimen

La ficha del evento estaba organizada según el modelo de datos (una caja por entidad: provisión,
entradas, costos, tareas) y no según lo que la persona tiene que hacer. Germán lo describió al
revés y mucho mejor: *"un listado de cosas necesarias así como servicios que se contraten, y después
lo que se consume durante el evento, entradas vendidas si es que hay, y luego la rendición del
evento con los sobrantes de mercadería para ver en términos contables cómo terminó"*.

- **Una sola lista "Qué necesito"**: mercadería y servicios contratados juntos, con un único
  `+ Agregar` que pregunta qué estás sumando. Antes eran dos cajas separadas, con dos vocabularios y
  dos UIs, para algo que el usuario piensa como una sola cosa. Los costos siguen viviendo en el
  padre (asientan el egreso en el libro al marcarse pagados) pero se muestran en la lista.
- **Los cuatro KPIs en $0 desaparecen** mientras se planifica: un evento recién creado no muestra
  ningún tablero, porque cuatro tarjetas en cero se leen como un error. En su lugar, una línea:
  *comprometido $X · N por comprar · N pagos pendientes*, que solo aparece cuando hay algo.
- **Entradas: una pregunta en vez de un vacío.** *¿Cobrás entrada? No / Sí* — en un club la cata
  gratis para socios es el caso normal, y "Sin tipos de entrada, creá el primero" sugería que
  faltaba hacer algo.
- **Rendición** en vez de "cerrar provisión — reconciliar": los tres destinos a la vista (vendido,
  consumido, sobra) pero **un solo número para cargar**. Lo vendido/dispensado lo acumula el sistema
  durante el evento y el sobrante se deriva. Marca en rojo y bloquea el cierre si lo declarado supera
  lo reservado. Ojo con la asimetría del back, que se respetó: la mercadería que descuenta usa
  `cantidad_consumida` como total absoluto (reemplaza), mientras que lo apartado usa
  `consumo_interno` y lo SUMA a lo ya dispensado.
- **"Cuenta regresiva" → "Pendientes del evento"**, que es lo que es: un to-do checkeable.
- **Entradas imprimibles (PDF)**: ticket de 180×70mm, 3 por A4, con **talón troquelado** — línea
  punteada y muescas en los cantos — que lleva el QR y el código para cortar en la puerta. Genérico
  a propósito: lo único que lo marca es el nombre del club y la franja de color. Una entrada gratis
  dice "Sin cargo", no "$0". Se imprimen de a una o todas juntas, reusando la misma máquina que las
  etiquetas de cultivo (medidas reales, progreso, arreglo del bloqueador de popups). Las anuladas no
  se imprimen.
- **Fix del modal invisible**: toda la carpeta `bar/` renderizaba sus overlays inline y era la única
  zona de la app que no usaba `<Teleport to="body">` — por eso `+ Producto` mostraba el velo pero no
  la caja. Los nueve overlays de los cuatro archivos ahora teleportan.

Backend sin cambios. Se confirmó con Germán que todo servicio se conoce con su valor de antemano, así
que `monto_ars` obligatorio se queda.

**QR resistente al maltrato** (las etiquetas se estaban humedeciendo en la sala): corrección de error
**H** (tolera 30% del código dañado, contra el 15% del default `M`), zona muda de 2, y **negro puro en
la banderita de planta**, que es la que se moja — el verde tiene menos contraste sobre material húmedo
o tóner rayado. Lote y entrada siguen en verde: viven protegidas. Las opciones del QR se consolidaron
en el layout (`layout.qr`), que estaban duplicadas en cuatro archivos. La banderita pasó de 20 a
**21mm de QR**: con H el código va a 41×41 módulos y en 20mm cada módulo quedaba en 0,44mm, al borde
de lo que resuelve una cámara de celular; con 21 vuelve a ~0,47mm.

*El arreglo de fondo, igual, es el material: papel sintético (BOPP/vinilo A4) en impresora **láser**.
Nunca inkjet —la tinta se corre— ni térmica directa, que se borra con el calor de la sala.*

## Julio 2026 (w) — alta de movimientos: dos columnas y catálogo editable ahí mismo

Si registrabas un gasto de algo cuya categoría o área no existía, tenías que salir a Configuración,
crearla y volver a empezar la carga. **Crear un movimiento y crear una categoría o un área piden el
mismo permiso (admin)**, así que la app te mandaba a otra pantalla a hacer algo que ya podías hacer
desde donde estabas: puro costo de navegación.

- **El modal pasa a dos columnas (940px)**: a la izquierda **el hecho** (qué pasó, cuánto, cuándo,
  destino del stock), a la derecha **su consecuencia contable** —categoría, sede, área, comprobante—
  visible pero en tono secundario. Se mantiene el orden del rediseño anterior (primero el hecho), y
  se corrige lo que estaba mal: la clasificación vivía detrás de un chevron, así que para darte
  cuenta de que la categoría sugerida estaba equivocada había que abrir un acordeón. La pantalla de
  intención sigue angosta: a 940px los cinco accesos quedaban desparramados.
- **Crear categoría sin salir**: si el buscador no encuentra lo que escribiste, aparece
  "Crear «Bebidas»" con las familias del tipo del movimiento para elegir dónde va. Queda seleccionada
  en el acto, sin esperar el refetch del padre.
- **Solo se crean SUBcategorías, a propósito.** Una sub hereda de su madre el área, la clave de
  sistema y el `comportamiento` — el que decide si la compra entra al depósito, al salón o a ningún
  inventario. Una **familia nueva define esa plomería**, y decidirla en el pie de un dropdown mientras
  cargás un gasto es la clase de error que se descubre tarde (compras que dejan de entrar al
  depósito). Eso sigue en Configuración.
- **Crear área sin salir** también, con su tipo (el back lo valida como obligatorio).
- Se borró `ComboboxCategorias.vue` (11 KB), que había quedado sin uso desde el rediseño de julio.
- Mobile queda como fallback de una columna, sin invertir ahí: la PWA se rediseña aparte, después de
  decidir qué módulos tiene sentido que entren y para qué roles.

## Julio 2026 (v) — las etiquetas pasan a PDF (medidas reales)

Las etiquetas se imprimían desde una hoja HTML, y ahí **los milímetros son una sugerencia**: el
diálogo de Chrome aplica su "ajustar a la página" y encoge todo un 3-5%. Con planchas autoadhesivas
eso arruina el calce, y el tamaño cambiaba de máquina en máquina. Ahora se genera un **PDF** con la
geometría clavada.

- **`lib/pdfEtiquetas.js` reemplaza a `etiquetaLote.js` + `etiquetaPlanta.js`** (y deja sin uso a
  `logoEmbed.js`, borrado). Sigue siendo **fuente única**: la misma pieza dibuja la etiqueta suelta
  de `LoteDetailView` / `PlantaDetailView` y la tanda de `/lotes`, `/plantas` y las plantas de un lote.
- **Se dibuja con primitivas de jsPDF, no rasterizando el HTML** (html2pdf/html2canvas): el texto
  queda vectorial, el archivo pesa una fracción y con 800 etiquetas html2canvas se arrastra. jsPDF
  entra por `import()` dinámico, así que es un chunk aparte y no pesa en las demás rutas.
- **Etiqueta de lote 93×60mm** — A4 **apaisada**, 3 por fila, 9 por página. En vertical solo entran 2,
  y achicarla para meter 3 deja el nombre de la genética ilegible, que es justo lo que hay que poder
  leer en el pasillo. **Banderita de planta 160×26mm** — dos mitades idénticas con línea de plegado
  punteada al medio (se pliega sobre el tronco y se lee de los dos lados), 10 por página en vertical.
- **Sin emoji en el PDF**: las fuentes estándar (helvetica/courier) no los traen y salen como basura
  impresa; el 🌿 se reemplazó por tipografía. Acentos y ñ sí funcionan (WinAnsi). Hay un test que
  falla si alguien vuelve a colar un emoji.
- La etiqueta suelta ahora **descarga un PDF del tamaño exacto** (93×60 / 160×26mm) en vez de abrir
  una ventana de impresión; el botón se deshabilita y dice "Generando…" mientras trabaja.
- Al terminar la tanda **se limpia la selección** (y con ella la barra): el trabajo ya está hecho.
- **La plancha sale ordenada por lote y número** (`ordenPor` en `useEtiquetasQR`), no en el orden de
  la tabla: un lote entero y en orden P001→P0NN, después el siguiente. La tabla de `/plantas` ordena
  por fecha de creación, y eso partía en dos un lote ampliado más tarde — con 3 plantas cargadas y 9
  agregadas 20 minutos después, las P001-P003 caían decenas de etiquetas más abajo, entre plantas de
  otros lotes, y parecían faltar. Se etiqueta recorriendo el lote, no la línea de tiempo del alta.
  Comparación con `Intl.Collator(numeric: true)`: sin eso, `P10` va antes que `P2`.

`useEtiquetasQR` conserva lo de la (u) —ventana abierta antes del await por el bloqueador de popups,
`BloqueoProgreso` mientras genera— y ahora recibe `layout` + `dibujar` + `datosDe` en vez de `htmlDe`
+ `css`. Tests: `pdfEtiquetas.test.js` cubre grilla por página, contenido, recorte a 2 líneas de la
genética, doble faz de la banderita y el desplazamiento de celda.

## Julio 2026 (u) — etiquetas QR en tanda

Etiquetar los lotes recién creados obligaba a entrar a cada uno y disparar una impresión por lote.
Ahora en **Plantas** y en **Lotes** se seleccionan filas y sale **una sola hoja**.

- **"Seleccionar todo" = todo lo FILTRADO, no la página visible** (`useSeleccion`): filtrás esqueje y
  entran los 47 esquejes aunque la tabla muestre 10. La selección **sobrevive al cambio de filtro y
  de página**, así se arma una tanda mixta en dos pasadas; la barra avisa cuántos quedaron fuera del
  filtro actual para que "25 seleccionadas" con 12 filas a la vista no parezca un bug.
- **Mientras genera, la pantalla se bloquea** (`BloqueoProgreso`): clicks, teclas —incluido Escape— y
  el scroll del fondo. Cambiar el filtro a mitad de camino imprimía una hoja que no era la pedida, y
  el botón se podía apretar dos veces.
- **`lib/etiquetaLote.js` es fuente única** de la etiqueta de lote (80×50mm): el HTML estaba inline en
  `LoteDetailView`, así que la tanda habría divergido a la primera corrección. Hoja A4 de 2×5 por
  página, sin partir etiquetas. Las plantas reusan la banderita plegable de `lib/etiquetaPlanta.js`:
  la etiqueta no cambia según de dónde se imprima.
- **Fix del bloqueador de popups:** `window.open()` se disparaba *después* del await de generación, y
  ahí ya no cuenta como gesto del usuario (le pasaba a las etiquetas de plantas de un lote). Ahora la
  ventana se abre en el mismo tick del click con un cartel de "generando" y recibe el HTML al final —
  por eso `useEtiquetasQR` recibe la **función** de config y no el config resuelto: resolverlo antes
  gastaba el gesto. Si igual la bloquean, cae en descarga y no se pierde el trabajo.

## Julio 2026 (t) — tareas pendientes accionables + tres bugs de producción

**Tareas: el listado que faltaba.** El calendario semanal era la única vista, así que las tareas
**sin fecha no se veían en ninguna pantalla** y las vencidas solo navegando a la semana pasada: el
KPI decía "tenés 7 pendientes" y no había forma de saber cuáles. Ahora `tareas#dashboard` devuelve
`pendientes` (el mismo scope `pendientes_al_dia` que el KPI, ordenado por fecha más vieja primero y
las sin fecha al final, tope 100), y `/tareas` lo muestra debajo del calendario agrupado en
**Vencidas / Hoy / Sin fecha**. El ✓ de cada fila la cierra sin pedir horas; con checkboxes aparece
la barra **"N seleccionadas → Completar"** (reusa `completar_masivo`, pensado justo para registrar
retroactivo). Click en la fila abre el panel de detalle de siempre, que es donde se cargan horas y
notas. El KPI Pendientes ahora hace scroll al bloque.

De paso, dos bugs de fecha en esa vista: `toISOString()` es UTC, así que **pasadas las 21hs (AR) las
tareas de hoy se veían como vencidas** y la navegación semanal arrancaba un día corrido. Y a
`TIPO_EMOJI`/`TIPO_META` les faltaban 5 tipos (`nutricion`, `defoliacion`, `scrog_lst`,
`ajuste_luz`, `revision_plagas`): salían con el pill vacío en el detalle.

**Borrar una venta del salón: había una sola puerta y era la equivocada.** `deleteBarVenta` no
estaba conectado a ninguna UI, así que la única forma aparente de deshacer una venta era borrar su
asiento "Venta bar #N" desde Contabilidad — y eso **se llevaba el ingreso del libro sin devolver el
stock** (la mercadería ya había salido al cobrar). `movimientos_contables#destroy` guardaba contra
dispensaciones y compras de insumo, pero no contra ventas del bar. Ahora lo bloquea con el mismo
criterio y explica dónde borrarla, y hay botón 🗑️ en **Salón → Vender → 🧾 Ventas**
(admin/supervisor) que revierte las dos cosas vía `BarVenta#revertir_efectos`.

**Depósitos duplicados: una race condition en la siembra.** En prod aparecían dos "General" y dos
"Cultivo" de la MISMA sede, creados con 1-2 ms de diferencia. La siembra corre desde un
`before_action` (`asegurar_depositos`) que tienen **dos** controllers (`depositos#index` e
`insumos#index`), y el frontend los pide en paralelo desde el mismo `onMounted`: los dos vieron que
faltaba sembrar y los dos sembraron. La unicidad era solo validación de modelo, que no protege de
una race. Cerrado por los dos lados:

- **Lock** de la fila del club en `Finanzas::SembrarDepositos` → el segundo request encuentra lo que
  sembró el primero (más un rescue de `RecordNotUnique` como red).
- **Índice único parcial** `index_depositos_sistema_unico` sobre
  `(club_id, COALESCE(sede_id, 0), clave_sistema)` con `WHERE clave_sistema IS NOT NULL AND
  deleted_at IS NULL`. El `COALESCE` importa: en un índice único los NULL son distintos entre sí, y
  sin eso dos legacy club-wide seguirían pudiendo duplicarse. La migración **deduplica antes** de
  crear el índice (SQL propio: una migración no debe depender de los modelos).
- **`rake depositos:deduplicar`** (con `DRY_RUN=1`) para inspeccionar/limpiar a mano: se queda con
  el id más bajo, le mueve insumos y productos del bar, y retira el resto (soft-delete).

Además, dos cosas que hacían ilegible el caso multi-sede: los tabs del Depósito ahora se
desambiguan con la sede cuando un nombre aparece repetido, y las opciones del filtro de sede se
derivan de los propios depósitos si el store de sedes no cargó (el club se veía como mono-sede: sin
filtro y con los tabs sin etiqueta). Y `Finanzas::SembrarDepositos` tenía un bug que dejaba la
sede-ificación trabada **para siempre**: `Sede` es soft-delete, y un insumo apuntando a una sede
borrada no tenía depósito destino → no se migraba → el depósito club-wide legacy no se podía retirar
nunca. Ahora cae en la sede principal.

**`＋ Comprar`** del Depósito abre el modal de Nuevo movimiento directo (`/contabilidad?nuevo=1`).

## Julio 2026 (s) — dispensar desde lo apartado para un evento + consumo interno

Cierra el ciclo de lo apartado (jul-27 «p»). Antes quedaba un agujero: se apartaba stock para un
evento pero el dispensador **no podía dispensarlo** (el propio apartado lo bloqueaba), y lo
consumido al cerrar no descontaba nada — el inventario quedaba inflado.

**El apartado se reparte en tres destinos, y dos se llenan solos:**

- **DISPENSADO — durante el evento.** El carrito de dispensa muestra lo apartado por eventos
  **en curso** (`stocks#index` expone `apartados_evento`) y el dispensador tilda *«dispensar desde
  lo reservado para Evento X»*. La línea guarda `dispensacion_items.evento_bar_id` (trazabilidad:
  qué evento consumió qué gramos, con su paciente) y la cantidad se **imputa a la provisión**
  (`cantidad_consumida`), liberando el bloqueo en la misma medida — sin doble descuento.
  Es explícito a propósito: **sin tildar, la dispensa sale del stock libre** y no se come lo
  apartado. Solo vale con el evento `en_curso` y con apartado real de ese stock.
- **CONSUMO INTERNO — al cerrar.** Lo que se consumió sin dispensar a nadie identificable
  (degustación, muestra) se declara en el cierre: descuenta de verdad con `StockMovimiento` tipo
  **`consumo_evento`** (tipo propio, no `merma`: no es lo mismo «se consumió en el aniversario»
  que «se pudrió») y es **COGS del evento**. Se recorta al saldo apartado: nunca descuenta de más.
- **LIBERADO.** El resto suelta el bloqueo y vuelve al pozo disponible.

**Contabilidad:** al evento le cuesta **solo el consumo interno**, no lo dispensado — eso tiene su
propio costo e ingreso en la dispensación y contarlo acá sería duplicarlo. Sin asientos nuevos:
es atribución calculada, el criterio que ya usa el módulo.

Migración `add_consumo_evento_a_provisiones_y_dispensas`
(`evento_bar_provisiones.cantidad_consumo_interno` + `dispensacion_items.evento_bar_id`).
Spec `evento_dispensa_apartado_spec` cubre el ciclo completo con el caso real (apartar 250 g,
dispensar 100 durante el evento, consumir 25, liberar 125).

## Julio 2026 (r) — el cierre de período nunca alcanza al día en curso

- **Guard:** `cerrar_periodo` ahora exige `hasta < hoy`. Si se pudiera cerrar el día en curso,
  todo asiento automático (venta del salón, dispensación, compra) nace con fecha de hoy y sería
  rechazado por la validación de período cerrado: el mostrador quedaría sin poder cobrar. La UI ya
  cerraba solo hasta fin del mes anterior; esto lo hace cumplir del lado del servidor.
- **Mensaje claro en vez de 500:** `bar/ventas#create` rescata `RecordInvalid` y explica el motivo
  (antes, con un cierre heredado que incluyera hoy, el POS devolvía un 500 sin explicación).
- Specs: cierre del día en curso rechazado, venta OK con cierre hasta ayer, venta bloqueada con
  mensaje si el cierre incluye hoy.

## Julio 2026 (q) — el mostrador del salón vende de otros depósitos (F4)

- **Antes:** el POS solo vendía `BarProducto` (depósito Salón). Vender una remera del depósito
  General obligaba a recargarla como producto del bar → el mismo ítem en dos lados y el stock
  descuadrado.
- **Ahora:** la línea de venta es **polimórfica** (`bar_venta_items.vendible_type/vendible_id`,
  migración `add_vendible_a_bar_venta_items` con backfill; `bar_producto_id` se conserva por
  compatibilidad). Una venta puede mezclar producto del bar + insumo, y **cada línea descuenta de
  SU depósito**. Borrar la venta repone en cada depósito de origen.
- **REGLA: ningún `Stock` se vende por el mostrador** — ni el propio, ni los derivados, ni el
  externo (merch/bebida). Todo lo trazable sale por **dispensación**, que ya es su canal (el
  carrito de dispensa lista el externo igual que la flor). Dos puertas de salida para el mismo
  ítem = descuadre y confusión sobre qué se maneja dónde.
- **`Bar::ItemVendible`** (nuevo): envoltorio único de "algo vendible/proveíble" — nombre, unidad,
  depósito, disponible, costo, precio, `descontar!`/`reponer!`. El `case` por tipo vive **una sola
  vez** y lo comparten el POS, la provisión de eventos (`EventoBarProvision` ahora delega en él) y
  la reversión de una venta.
- **Precio:** el ítem usa su precio propio (`precio_ars` / `precio_sugerido_ars`); un insumo no
  tiene precio de venta, así que exige **precio a mano — solo admin/supervisor**. El dispensador
  solo ve y cobra lo que ya tiene precio cargado.
- **Regla dura:** el stock **regulatorio** (flor y derivados) **no se vende por el mostrador** —
  sale por dispensación. El buscador nunca lo ofrece y el service lo rechaza.
- Endpoint nuevo `GET /bares/:id/vendibles?q=` (buscador cross-depósito, sin plata para el
  dispensador). Frontend: el buscador del POS suma la sección **“En otros depósitos”**; el carrito
  pasó a líneas genéricas (`{tipo, id, nombre, precio, disponible, deposito}`) con modal de precio
  para los ítems sin precio.

## Julio 2026 (p) — la flor se puede apartar para un evento del salón (F3b) + reserva parcial

- **`Stock` provisionable en eventos, SIEMPRE como APARTADO** (propio, derivados y externo por
  igual). Es **la misma mecánica que una reserva de paciente, con otro destinatario**: reservar
  **no descuenta** el inventario, bloquea la cantidad (`Stock#apartado_para_eventos`, que entra en
  `gramos_reservados` y `cantidad_disponible_real`) para que ninguna dispensa ni reserva de
  paciente la pise, y al cerrar el evento se libera. El stock sale del inventario **solo al
  dispensarse** — no se agregaron tipos de `StockMovimiento`: no hay salida sin dispensación.
- **No suma COGS al evento:** su costo e ingreso viven en la dispensación; contarlos también acá
  inflaría el resultado del evento.
- **Reserva PARCIAL:** `provisiones/reservar` aparta de cada ítem lo que haya y devuelve
  `advertencias` con el faltante (antes era todo-o-nada: un solo faltante bloqueaba la reserva
  entera del evento). Fix de paso: `faltante` ahora descuenta lo ya reservado (antes seguía
  marcando faltante después de reservar).
- Buscador de provisión y UI: el dispensario aparece junto al salón/cultivo/general, con chip
  **apartado** y el aviso de reserva parcial. Sin migración (el polimórfico ya existía).

## Julio 2026 (o) — la sede del movimiento la fija el depósito (no se puede divergir)

- **Guard de integridad multi-sede:** al cargar un movimiento con destino a un depósito, la **sede
  del asiento (y del insumo) la manda el depósito** — ya no se puede quedar en una sede distinta.
  - Backend (`aplicar_deposito!`): `sede_id = deposito.sede_id` (prioritario); actualiza el movimiento
    a esa sede aunque el form haya mandado otra. Spec en `movimiento_deposito_spec`.
  - Frontend (`ModalNuevoMovimiento`): al elegir un depósito, el selector de "Sede" del movimiento
    queda **bloqueado** en la sede del depósito, y el alta de insumo nuevo muestra "va a 📍 {sede}".

## Julio 2026 (ñ) — Depósitos por sede — Fase 2 (frontend sede-aware)

- **Hub Depósito (`InsumosView`):** los tabs se filtran por la **sede elegida** (selector que ya
  existía); con "Todo el club" se ven todos con la **sede en la etiqueta** (`Cultivo · Sede Centro`).
  Las vistas read-only (Salón/Dispensario) reciben la sede del depósito activo.
- **Catálogo por área (`FinanzasCatalogoView`):** cada depósito muestra su **📍 sede**.
- **Nuevo Movimiento (`ModalNuevoMovimiento`):** la opción de depósito muestra su sede, y **elegir un
  depósito fija la sede del movimiento** (cada depósito es de una sede).
- Backend: la serialización del depósito suma `sede_id`/`sede_nombre`; `asegurar_depositos` (también
  en `depositos_controller`) dispara la sede-ificación en el primer acceso. Build + 58 vitest verdes.

## Julio 2026 (n) — Depósitos por SEDE (multi-sede) — Fase 1 (backend)

- **Cambio foundational:** el depósito pasa de ser del CLUB a ser de una **SEDE**. Antes la sede
  vivía en el ítem (`insumo.sede_id`); ahora vive en el depósito. Cada sede tiene sus depósitos.
  - `Deposito.sede_id` (migración `add_sede_a_depositos`); unicidad de sistema por `(club, sede, clave)`.
  - **`SembrarDepositos` por sede:** General en todas; **Cultivo** en producción/mixta; **Salón**
    (con bar) y **Dispensario** en social/mixta. Al crear una sede, estrena sus depósitos.
  - **Sede-ificación de lo legacy (idempotente):** reasigna los insumos de los depósitos club-wide
    (sede_id nil) a su depósito por-sede (por la sede del insumo; los "pool" sin sede → la sede
    principal, la más antigua) y retira los viejos. Corre lazy en el primer acceso a Depósito/Insumos.
  - Specs de `sembrar_depositos` (per-sede por tipo, sede-ificación, migración legacy, idempotencia).
    Suite backend 1193 verde.
- **Pendiente Fase 2 (frontend sede-aware):** el hub Depósito, el catálogo por área y el Nuevo
  Movimiento deben **agrupar/mostrar por sede** (si no, un club multi-sede vería depósitos con nombre
  repetido). Para un club de **una sede** ya se ve igual que antes.

## Julio 2026 (m) — el área "Administración" pasa a llamarse "General"

- **Área del sistema "Administración" → "General"** (nombre visible más claro; el `tipo` interno
  sigue siendo `administracion`). Es el área transversal/administrativa del club — el catch-all para
  categorías genéricas (evita crear un "Sin área" real). Seed actualizado (`SembrarCatalogo`) para
  clubes nuevos + migración de datos `renombrar_administracion_a_general` para los existentes (solo
  renombra las que conservan el nombre por defecto, no pisa nombres personalizados).

## Julio 2026 (l) — Catálogo de Finanzas como mapa por área (acordeón)

- **Rediseño de la tab "Categorías" (Contabilidad → `FinanzasCatalogoView`):** de dos columnas
  paralelas (Categorías | Áreas) a un **acordeón por área**. Cada área del club se despliega y
  muestra **todo lo suyo junto**: sus categorías (madre → subcategoría, con las mismas acciones) y
  sus **depósitos** (read-only; se gestionan en el hub *Depósito*). El área es el eje — tanto las
  categorías como los depósitos responden a un área.
- **Bucket "Sin área":** las categorías sin área asignada caen en un desplegable "Sin área" al final,
  así ninguna queda huérfana. Cada área muestra un resumen ("X categorías · Y depósitos").
- Frontend puro (carga `listDepositos` para el mapa). Build + 58 vitest verdes.

## Julio 2026 (k) — "Depósito" como hub de inventario (gestión, no creación)

- **La sección "Depósito" (`/insumos`) es un hub de solo-gestión, no de creación:**
  - Muestra **todos los depósitos** (Cultivo, General, custom, + Salón y Dispensación read-only).
  - **Se quitó el "＋ Entrada" que creaba productos nuevos.** Los productos **nuevos se compran
    desde Contabilidad → Nuevo Movimiento** (ahí se elige el depósito destino; ya funcionaba).
  - Por producto: **Reponer** (→ genera el egreso), **Reconteo / Merma**, **Editar**, **Desactivar**,
    **Eliminar** (ya existían). El modal de entrada quedó como "Reponer stock" (sin modo "nuevo").
  - **Read-only** (se ven pero se operan desde su lugar): **Salón** (desde el bar) y **Dispensación**
    (su stock viene de cosecha/manicura).
- El tab de Producción vuelve a llamarse **"Stock"** (para que "Depósito" sea solo el hub del sidebar).

## Julio 2026 (j) — comprobante de venta del bar (no fiscal)

- **Reimprimir comprobante de una venta pasada:** botón **"🧾 Ventas"** en Vender → lista de últimas
  ventas (`listBarVentas`, ya trae ítems/total/medio/fecha) con **🖨️ reimprimir** por fila, que
  reabre el mismo ticket. Frontend puro, sin backend nuevo.
- **Imprimir comprobante tras cobrar:** al cerrar una venta en *Vender*, se ofrece el ticket
  imprimible (`TicketVenta.vue`, ancho tipo térmica) con el detalle: club/salón, fecha·hora·N°,
  ítems (cantidad × nombre · subtotal · precio unitario), total y medio de pago. Leyenda
  obligatoria **"COMPROBANTE NO VÁLIDO COMO FACTURA"**. Imprime con `window.print()` (un `@media
  print` no scoped deja visible solo el ticket). Sin backend: se arma del carrito al cobrar.

## Julio 2026 (i) — stock del bar: una puerta, alta en un paso, y libros que dicen "Bar"

- **Los asientos del bar se leen "Bar / Salón" (no "Otro"):** nueva categoría contable `bar`; la
  compra de mercadería, la venta, y los costos/entradas de eventos ahora se categorizan como `bar`
  (antes `otro`). El rollup "Por categoría", el libro y los reportes muestran "Bar / Salón". La
  compra desde *Nuevo Movimiento* también (`aplicar_salon!`). Nota: los movimientos viejos siguen
  en "Otro" (no es retroactivo).
- **Alta unificada del producto del bar (un paso):** `POST /bares/:id/productos` acepta
  `carga_inicial` (cantidad + costo) y crea el producto **y** registra la primera compra
  (stock + costo promedio + egreso "Bar") en la misma transacción. Adiós al "crear en 0 y después
  ir a Comprar". En *Stock del salón* (sección "Carga inicial") y en el *scan-to-create* de Vender.
- **Detalle al click en el libro:** cada asiento es clickeable → modal con qué/quién/cuándo/dónde;
  los del bar traen link **"Entrar al salón"** (`es_bar` + `bar_id` en la serialización).
- **Una sola puerta:** cartel en Insumos → Entrada avisando que la mercadería del bar se carga
  desde *Salón → Stock del salón* (ahí cayeron por error compras que debían ir al bar).
- Specs: alta unificada (`bar_producto_alta_spec`), compra categorizada `bar` (`bar_producto_spec`).

## Julio 2026 (h) — se guarda el Layout de slots de sala (para retomarlo con 3D)

- **Sacado el Layout de slots por sala:** la asignación a slots era ficticia (el grid metía los
  lotes activos por orden de id en `pots_count` posiciones; no había campo de slot real por lote),
  y con varios lotes por sala mostraba algo engañoso. Se removió la **tab "Layout"** de la ficha de
  sala y el campo **"Slots para lotes"** (`pots_count`) del alta/edición de sala.
- **Shelving reversible:** el componente `SalaLayoutGrid.vue` y la columna `pots_count` quedan
  **dormidos** (sin uso, sin borrar) para retomar la feature bien con la simulación de cultivo 3D.
  Sin migración.

## Julio 2026 (g) — audit log Fase 2 (Paciente/User/Reserva) + scan-to-create

- **Audit log Fase 2:** `include Auditable` en **Paciente, User y Reserva**.
  - **Privacidad primero (allowlist):** el concern suma `auditar_solo :campos` — audita SOLO lo
    listado, así una columna nueva no se filtra por olvido. **Paciente** audita solo `nombre`,
    `apellido`, `fecha_nacimiento`, `reprocann_vencimiento`, `reprocann_estado` — **nunca** los
    campos cifrados at-rest (dni, reprocann_numero, email, teléfono) ni los clínicos (anamnesis,
    diagnósticos, etc.), que descifrados romperían ENC-01 + la privacidad clínica.
  - **User** audita solo `role` (evento de seguridad clave) + nombre/apellido/emails — excluye
    automáticamente el ruido de Devise (login/sign_in tracking, tokens, password) y los cifrados
    (dni, phone). **Reserva** se audita completa (no cifra nada).
  - Endpoint y UI ya soportan los tipos nuevos (Paciente/Usuario/Reserva en el filtro del historial).
  - Specs: `auditable_fase2_spec` (allowlists + wiring: un campo clínico nunca llega al rastro).
- **Scan-to-create (código de barras):** en *Vender*, si un admin escanea (cámara o lector) un
  código **no registrado**, se abre el alta rápida del producto con el código ya cargado
  (nombre/categoría/precio/stock inicial). Así nunca hay que pre-cargar a mano: la primera vez que
  ves un producto, lo escaneás y lo creás. (No-admin: aviso de "código no asignado".)

## Julio 2026 (f) — código de barras en el POS del salón (lector físico + cámara)

- **Infra:** columna `codigo_barras` en `bar_productos` (migración `add_codigo_barras_a_bar_productos`),
  **única por bar** entre productos vivos (índice parcial `codigo_barras IS NOT NULL AND deleted_at IS NULL`).
  Validación de unicidad scopeada al bar (opcional; se reutiliza si el producto se borra).
- **Backend:** `codigo_barras` permitido y serializado en `Bar::ProductosController`.
- **Escaneo — dos modos, mismo handler:**
  - **Lector físico (USB/Bluetooth "keyboard wedge"):** en *Vender*, el buscador acepta el código +
    Enter → agrega el producto al carrito. Cero librería. (Si no matchea código pero hay un único
    resultado por nombre, también lo agrega.)
  - **Cámara (celu/tablet/webcam de escritorio):** componente `BarcodeScanner.vue` con `@zxing/browser`
    (1D EAN/UPC/Code-128 + 2D, cámara trasera por defecto, anti-rebote). Botón 📷 en *Vender* (escaneo
    continuo → agrega varios seguidos) y en el form de *Stock del salón* (scan-to-fill del código).
- **Carga del código:** en *Stock del salón*, el form de producto suma el campo "código de barras"
  (tipeado o escaneado con 📷).
- Spec: unicidad por bar en `bar_producto_spec`. Dep nueva: `@zxing/browser` (frontend).

## Julio 2026 (e) — historial por usuario (audit log, Fase 1)

- **Rastro de actividad por usuario, read-only:** aprovechando la infra ya existente (`Auditoria`
  inmutable + concern `Auditable`), se activó el registro en **Lote, Plant, Stock y Dispensación**
  (`include Auditable`). Cada create/update/delete queda con quién (`Current.user`), qué cambió
  (diff `campo: antes → después`) y cuándo.
- **Señal sobre ruido:** el concern ahora admite `no_auditar :campo`. Se excluyen contadores/derivados:
  `plants_count` en Lote; `cantidad` y `lote_origen_consumido_g` en Stock (los cambios de cantidad
  ya viven en `stock_movimientos` con usuario). Dispensación deriva `club_id` del paciente.
- **Endpoint:** `GET /usuarios/:id/auditorias` (admin-only, tenant-scoped, más recientes primero).
  Filtrable por **rango de fechas** (`desde`/`hasta`) y **tipo**; paginado (`per_page` 10/25/50,
  `total_pages`). Devuelve el diff formateado solo en ediciones.
- **UI:** tab **"Historial de actividad"** en el detalle de usuario (`UsuarioDetail`), read-only:
  **tabla** (Fecha · Acción · Tipo · Registro · Cambios) con **filtros** (desde/hasta/tipo) y
  **paginador**. Muestra antes→después con nombres de campo legibles.
- **Sin migración** (la tabla `auditorias` ya existía). No es retroactivo: registra desde ahora.
- Spec: `usuario_auditorias_spec` (endpoint, paginación, aislamiento de tenant, exclusiones, 403 no-admin).

## Julio 2026 (d) — rediseño del Salón COMPLETO (B3–B6)

- **B3 · Vender = lista + buscador:** `BarPosView` pasó del grid con tabs de categoría a una
  **lista buscable por nombre** (chips de categoría como filtro secundario, "Todas" por defecto) +
  **hueco reservado para el lector de código de barras**. Cada fila: nombre, categoría, precio,
  stock y "+". Carrito igual, a la derecha.
- **B4 · Resumen liviano:** el Panel muestra glanceable lo accionable (resultado del mes, caja del
  turno, KPIs de hoy, **reponer**) y **pliega el análisis** (ventas por hora, top de hoy, lecturas)
  detrás de un toggle "Análisis del salón", cerrado por defecto.
- **Horario del evento:** columna `horario` (texto libre, ej. "22:00 a 05:00", migración
  `add_horario_a_eventos_bar`). Se pide en el modal de alta y se muestra en el listado y la ficha.
- **Cierre — Depósito→solapa Salón read-only:** `DepositoSalon.vue` dejó de duplicar la gestión del
  stock del bar (sacados Comprar / Reconteo / +Producto). Ahora es una **vista de solo lectura**
  (lista valorizada + historial de movimientos) con CTA a **Stock del salón**, único lugar de gestión.
- **Cierre — editar evento desde la ficha:** botón **✏️ Editar** en `EventoBarDetailView` (modal
  nombre/fecha/horario/aforo/ingresos estimados). Antes esos campos solo se seteaban al crear.

## Julio 2026 (d.1) — rediseño del Salón: caja con confirmación (B5) + eventos por fases (B6)

- **B5 · Caja de turno con confirmación entre roles:** el ciclo de la caja ahora reparte
  responsabilidades — admin/supervisor **abre** (fondo) → el dispensador **confirma** que la plata
  está → el dispensador **envía el cierre** (cuenta el efectivo, ve el esperado) → admin/supervisor
  **confirma el cierre** (o cierra directo). Estado intermedio `pendiente_cierre` (migración
  `add_confirmacion_a_caja_turnos`, índice único de "caja activa" que incluye el pendiente).
  `Bar::Pulso`/`Barra#caja_activa` exponen la caja pendiente para que gestión la vea; las ventas
  siguen enganchándose solo a `caja_abierta`. Frontend: `CajaSheet.vue` (una pantalla, acción según
  rol+estado) reachable desde el **chip de `BarNav`** en cualquier vista del bar (así el dispensador
  la opera desde Vender/Stock, sin ver el Panel). El chip refleja el estado (Sin caja / Falta
  confirmar / Caja abierta / Cierre pendiente).
- **B6 · Eventos por fases:** el `<select>` de estado se reemplazó por un **stepper**
  (`EventoStepper.vue`: planificado → en venta → en curso → cerrado, con cancelar fuera del carril).
  Backend: guard de transiciones (`EventoBar.transiciones_desde`, validación `transicion_valida`) —
  un evento terminal (finalizado/cancelado) **no se reabre**; el detalle expone `transiciones`. Alta
  de evento pasó a **modal mínimo** (nombre/fecha/aforo/ingresos estimados); el resto se completa
  dentro. Specs: `caja_confirmacion_spec` y `evento_bar_fases_spec` (71 ejemplos del bar en verde).
- **Pendiente del rediseño del Salón:** B3 (Vender lista+buscador) y B4 (Resumen liviano) siguen
  sin hacer. Idea de diseño sin cerrar: un campo `horario` en el evento (requiere migración) —
  el modal de alta hoy no lo pide.

## Julio 2026 (c) — capa de sede, salón inteligente, regalo, limpieza

- **Contexto de sede (UI):** store `sede` + selector en el `AdminTopBar` (gated `multi_sede`) —
  al marcar una sede actual, los módulos de-sede se re-filtran. Cableado en Depósito de insumos
  y en el dashboard de Contabilidad (sincronizado en ambos sentidos).
- **Insumos por sede:** cada insumo vive en una sede (`sede_id`, nullable = pool del club);
  **transferencia entre sedes** (origen baja stock, destino recibe valorizado al promedio del
  origen y recalcula el suyo; crea el insumo si no existe). La compra desde Nuevo Movimiento
  elige sede (default la actual).
- **Salón — panel inteligente (`Bar::Pulso`):** resultado del mes + margen + tendencia,
  ventas por hora, top con margen, "Lecturas del salón" (estrella, agotado que se vendía,
  margen bajo, tendencia), reponer con medidores. Rediseño de `BarPanelView` (acento cobre).
- **Salón — caja de turno:** apertura con fondo inicial y **cierre con arqueo** (efectivo
  contado vs esperado → diferencia). Modelo `CajaTurno`; ventas se enganchan por `caja_turno_id`.
- **Dispensación — regalo:** checkbox "es un regalo" (no cobra, no toca cuenta corriente; el
  stock igual se descuenta; queda trazado). Short-circuit al flujo legacy con `medio_pago='regalo'`.
- **Sedes — capa financiera (MVP):** `Sedes::ResumenFinanciero` — resultado del mes + tendencia
  y capital inmovilizado (stock + insumos valorizados) por sede + consolidado, en el cockpit.
- **Limpieza:** removido el subsistema muerto de inventario de sede (`SedeInventario`/
  `InventarioMovimiento`, tablas ya dropeadas, endpoints sin rutear) y el `ManicuradorDashboard`
  legacy (form roto contra `agregar_stock`; el manicura ya usa `/mnc` + pesaje).
- **Auth cross-site:** verificado que ya está resuelto en código (SPA same-origin desde Rails,
  cookie `jwt_token` first-party). Sin cambios; solo restaba confirmar config de Render.

## Julio 2026 (b) — endurecimiento para escala + pulido de manicura

- **TEN-01b (jobs):** los 16 jobs con datos de club ahora fijan el tenant
  (`ActsAsTenant.with_tenant(club)`) — defensa en profundidad completa en la capa de jobs
  (`jwt_denylist_cleanup` y `push_notification` exentos por ser tenant-agnósticos).
- **Reservas:** cerrado el gate de backend — el dispensador solo `index/show/entregar`; crear/
  editar/cancelar/anular seña = admin/supervisor (espeja el front).
- **Informes:** "plantas por estado" en Producción ya se computa (no venía en 0);
  `dispensaciones_sobre_limite` → `dispensaciones_sin_reprocann` (label honesto).
- **Manicura:** aviso "¿seguir la anterior / empezar una nueva / cancelar?" al pesar con una
  jornada enviada sin confirmar; botón verde + cancelar seguro; se sacó "Nuevo pesaje" (jornada
  vacía redundante); hint "faltan N de M plantas".
- **PlantaDetail:** reconectadas las acciones **Medición (Bluelab BLE, EC/pH)** y **Trasplante**
  (los modales existían pero ningún botón los abría — regresión).
- **Lint:** limpieza de deuda en las vistas tocadas.

## Julio 2026 — seguridad clínica, backups, KPIs de stock, candado de manicura

- **Seguridad AZ (historia clínica):** `pacientes#show/#index` filtraban la historia clínica
  (anamnesis, diagnósticos, evolución, alergias, medicación…) a roles no clínicos (dispensador).
  Se pasó a **allowlist** de campos + `authorize`; `PacientePolicy` decide por rol
  (`ROLES_CLINICA = admin/medico/supervisor`). super_admin y dispensador bloqueados por rol.
- **Backups Postgres → R2:** rake `backup:create/list/prune/restore` + cron diario en
  `render.yaml` + `docs/backups.md`. Retención 30 días.
- **Stock (KPIs):** "Flor seca disponible" usa disponible **real** (resta reservas); nuevo KPI
  "Reservado (flor)"; "flor propia" → "Derivados". Stock bajo y gramos = solo flor seca.
- **Dispensaciones:** edición **multi-ítem** (cantidad + precio por línea) con reconciliación de
  stock/cc; precio manual por ítem (admin/sup); historial desplegable por ítem.
- **Contabilidad:** compras **en cuotas** (medio de pago "En cuotas" en Nuevo movimiento →
  genera N egresos mensuales, backdateable). Se saca "cheque".
- **Manicura (provisorio):** solo el **manicura asignado** registra el peso de un lote asignado
  (el "guardar" del detalle iba por `plants#update`, dejando el peso suelto → ahora va por el
  pesaje). El admin ya no pisa el peso de un lote asignado.
- **Reservas:** la fecha de entrega debe ser **a partir de mañana**.
- **UX admin:** widget de ambiente por sala, KPIs de plantas post-cosecha / cosecha lista,
  semáforo de días por fase, tipo de genética en /lotes, tabs del perfil (primarias + "Más"),
  botón PDF en informes del auditor.
- **Guía de usuarios:** nuevo `docs/GUIA_USUARIOS.md` (+ PDF) con roles y flujos.

## Limpieza del flujo de manicura (web) + estado fantasma `manicura_pendiente` eliminado (2026-06-30)

Relevamiento del flujo del rol **manicura** en la versión web (no PWA) y limpieza integral.

- **`manicura_pendiente` eliminado de toda la base**: era un sub-estado de aprobación que ya
  **nunca se asignaba** (la aprobación vive en `PesajeManicura` enviado→confirmado; el lote sigue
  `en_manicura` hasta pasar a `curado`). Se sacó de `Lote::ESTADOS`/`POST_COSECHA`/`progreso_ciclo`,
  scopes y labels de `lotes_controller`, `lote_serializer` (`puede_aprobar_manicura`, sin
  consumidores), `lote_policy`, `pesada`, `registrar_trasplante`, y de ~13 mapas de display del
  frontend. Verificado: 0 filas con ese estado en DB.
- **Autorización unificada**: `pesajes_manicura#create` ahora exige que el manicura esté **asignado**
  al lote (o que el lote no tenga manicurador), igual que `plants#registrar_peso`. Antes cualquier
  manicura podía pesar cualquier lote `en_manicura`. + 2 specs.
- **Bug funcional corregido**: en `PlantaDetailView`, `canManicura` gateaba sobre `manicura_pendiente`
  (nunca verdadero) → el manicura nunca podía actuar desde la ficha de planta. Ahora `en_manicura`.
- **Badge admin "aprobaciones pendientes"** (`useNavContext`): consultaba `manicura_pendiente`
  (siempre 0). Ahora cuenta los pesajes **enviados** reales.
- **Inventario en web para manicura**: nueva ruta `/mnc/stocks` + ítem "Inventario" en el sidebar
  (`StocksManicuraView` ya existía pero estaba huérfana).
- **Routing legacy**: `/manicura` redirige a `/mnc/pendientes` (antes a una pantalla admin-only);
  `App.vue` (nav link + ROLE_PRIORITY) repuntados.
- **Salas**: se retiró `manicura` del alta de salas (`ModalCrearSala`) — las salas son solo de
  cultivo; la manicura se trabaja por estado del lote, no en una sala. El kind sigue válido en el
  backend para salas existentes (mismo criterio que `cosecha`).
- rspec backend verde · vitest 58/58 · `vite build` OK.

## Entregar reserva = crear dispensación (unificado con el modal y el flujo de cobros) (2026-06-24)

Entregar una reserva ahora reusa el modal de **nueva dispensación** (modo "entregar reserva") y el
**motor de cobros** — antes usaba un modal aparte y el camino viejo de cobro (medio único, sin pago
partido ni contra-entrega).

- **Backend**: el motor de cobros (`cobros_param`, `aplicar_lineas_cobro!`, `afinar_medio_pago!`,
  `acreditar_excedente!`) se movió al concern `DispensacionesFinancieras` para compartirlo.
  `reservas#entregar` ahora cobra el **resto** (total − seña) con ese motor: soporta efectivo,
  transferencia, cuenta corriente, **contra-entrega** y excedente a favor. Mantiene el link de la
  reserva, marca entregada y libera el stock apartado.
- **Frontend**: `ModalNuevaDispensacion` acepta una prop `reserva` → modo "entregar reserva":
  producto/cantidad de la reserva (solo lectura), banner "Seña $X · A cobrar $resto", y el medio
  de pago del resto. `ReservasView` y la tab de dispensaciones del socio abren ese modal (en vez
  de `ModalEntregarReserva`).
- Specs de reservas actualizados al flujo de cobros (incl. contra-entrega y parcial a cuenta).
  Suite backend 775 verde.

## Caja del delivery: efectivo en tránsito + recepción (2026-06-24)

El efectivo que cobra el delivery en las entregas queda "en tránsito": NO se asienta como ingreso
hasta que el admin recibe la caja. Da control de faltantes.

- `cobros.rendido` (default true) + `rendido_at`. El efectivo de entrega se crea `rendido: false`
  y `RegistrarCobro` **no** crea su asiento (lo difiere). Transferencia y cuenta corriente se
  asientan al entregar como siempre.
- `Dispensaciones::RecibirCajaDelivery`: al recibir la caja, asienta el ingreso de cada cobro
  efectivo pendiente y lo marca rendido.
- `GET /usuarios/:id/stats` incluye `caja_delivery` (efectivo en mano, cobros pendientes, en viaje).
- `POST /usuarios/:id/recibir_caja` (admin).
- UsuarioDetail (admin → equipo → delivery): card "Caja del delivery" con efectivo en mano +
  botón "Recibir caja".
- Spec: efectivo no asentado hasta recibir; al recibir se crea el movimiento y se marca rendido.

## Cobros: pagos múltiples / parciales / contra-entrega por dispensa (2026-06-24)

Rediseño completo del cobro de dispensaciones. Una dispensa ahora puede cobrarse con varios medios
(efectivo + transferencia), parcialmente, o dejar el resto en cuenta corriente; y el delivery puede
cobrar al entregar (con foto de comprobante de transferencia).

**Modelo / contabilidad**
- Tabla `cobros` (medio, monto, pagado, contexto, comprobante ActiveStorage) + `dispensaciones.cobrar_en_entrega`.
- `Cobro` + `Dispensacion#saldo_pendiente` / `total_cobrado` / `monto_sin_cobrar` / `usa_cobros?`.
- `Dispensaciones::RegistrarCobro` (service): única fuente de verdad. Registra una línea, valida
  bloqueos y arma la contabilidad (asiento + débito de cuenta corriente) en una transacción.

**Reglas (bloquea cuando corresponde)**
- Lo que no se paga en efectivo/transferencia → cuenta corriente (acotado por el cupo del socio).
- Cuenta corriente exige cuenta activa y cupo suficiente; si no, se bloquea (rollback total).
- **Sobrepago permitido**: si el socio paga de más (transfirió de más, le pagó de más al delivery),
  el excedente se acredita a favor en su cuenta corriente (reusa el asiento `aporte_socio`). Solo se
  bloquea si no tiene cuenta corriente donde acreditarlo. El delivery no es quien lo determina.
- Contra-entrega: al crear no se asienta nada; el delivery cobra al entregar.
- Las dispensas legacy (sin cobros) quedan saldadas y no entran al flujo nuevo.
- Editar el monto de una dispensa con cobros se bloquea (cancelar y rehacer); cancelar revierte
  cobros + cuenta corriente.

**Backfill**: las dispensaciones existentes se espejaron a `cobros` (sin re-ejecutar contabilidad).

**Frontend**
- Dispensar (`DispensarView`): composer de cobro (efectivo + transferencia, resto a cuenta) + toggle
  "cobra el delivery"; se distribuye por ítem del carrito.
- Entrega (`DeliveryDashboard`): muestra "a cobrar", inputs de efectivo/transferencia, resto a cuenta,
  y subida de foto de comprobante; entrega vía multipart.

Tests: service (6) + flujos create/entrega/cancelación (4) + suite backend completa (**770**) verde;
vitest **58** verde.

## Contabilidad / cuenta corriente: 2 fixes de UI (2026-06-24)

- **"Recupero dispensación"** ahora muestra el selector de paciente (opcional) en Contabilidad,
  para atribuir el ingreso a un socio. No toca la cuenta corriente (saldar deuda sigue siendo
  "Registrar cobro" en la ficha del socio).
- **Cuenta corriente**: tipografía uniformada con Contabilidad — se sacó el `monospace` ("máquina
  de escribir"); números con `tabular-nums` y el valor grande igual al KPI de Contabilidad.

## Fix REAL: QR de planta se colgaba cargando (endpoint autenticado) (2026-06-23)

La causa de fondo de por qué **lote andaba y planta no**: `LoteQrView` usa `getLotePorQR` →
`api.get('/lotes/por_qr/...')` (instancia **api autenticada**, mismo baseURL/cookie/CORS que todo
lo demás). `PlantaQrView`, en cambio, hacía `auth.ensureBootstrapped()` (podía colgarse en
cold-start) + un `axios.get` **crudo cross-origin** al endpoint público raíz `/p/...`. En
producción el front y la API están en hosts onrender distintos, así que ese fetch quedaba colgado
(CORS / cross-site) → pantalla trabada en "cargando".

- **Nuevo endpoint autenticado** `GET /api/plants/por_qr/:codigo_qr` (`plants#por_qr`), scoped al
  club, espejo de `lotes#por_qr`. Devuelve `id`, `estado` y `lote.estado`.
- `PlantaQrView` ahora resuelve con `getPlantaPorQR` (instancia `api`), **sin** `ensureBootstrapped`
  ni axios crudo — exactamente el patrón de `LoteQrView`. El nombre/logo del club salen del store.
- Spec con aislamiento de tenant (no expone plantas de otro club).

## QR de planta: comportamiento por rol × estado (2026-06-23)

Al escanear el QR de una planta, el destino ahora depende del rol y de la fase de la planta:

| Rol | Planta pre-cosecha | Planta cosechada+ | Lote en manicura/secado |
|---|---|---|---|
| **admin / supervisor** | → detalle | → detalle | → detalle |
| **cultivador** | → detalle | tarjeta "Planta cosechada — sin permisos" | tarjeta "sin permisos" |
| **manicura** | tarjeta "Aún no en manicura" | tarjeta según fase | **→ pesaje por QR** |
| **otros** | detalle si tiene permiso `plantas:show`; si no, "sin permisos" | | |

**Causa del bug que quedaba en blanco**: `PlantaQrView` llamaba a `getPlant()` (instancia `api`)
para todos antes de decidir. En el navegador del celular sin cookie cross-site, el 401 disparaba
el interceptor (→ `/login`) a la vez que el `catch` redirigía al detalle: dos navegaciones en
carrera = pantalla en blanco. Ahora la decisión se toma **solo con la data pública** (sin llamada
autenticada previa) y la navegación es una sola.

- Backend: `GET /p/:codigo_qr` ahora incluye `lote.estado` (additivo) para poder decidir sin
  segunda llamada.
- `getPlant()` se llama únicamente en el flujo de pesaje de manicura (que ya está dentro de la
  ventana en_manicura/secado).
- Nuevos estados de tarjeta: `mensaje` (cosechada/sin permisos/aún no en manicura) reutilizando el
  estilo existente.

## Delivery: entrega secuencial por orden de ruta (2026-06-23)

El delivery solo puede cerrar (entregar / reportar problema) el despacho que es la **siguiente
parada en camino** de su ruta. No puede saltear: si la 1ra y 2da siguen abiertas, no puede tocar
la 3ra. Recién al cerrar una parada (entregada **o** fallida — un problema cuenta como resuelto:
llegó al lugar y no pudo entregar) se habilita la siguiente.

- **Backend (autoritativo)**: `Dispensacion.siguiente_de_ruta` / `siguiente_en_ruta?` calculan la
  primera parada `en_viaje` por `orden_entrega` dentro del grupo de ruta (mismo `ruta_entrega_id`,
  o despachos sueltos del delivery si no hay ruta). `dispensaciones_controller#entregar` y
  `#reportar_fallo` devuelven **422** si no es la siguiente. El **admin queda exento** (puede
  corregir fuera de orden).
- **Frontend**: en "En camino", solo la primera parada (orden de ruta) muestra los botones
  Entregado/Problema y el chip "▶ Siguiente"; las demás quedan atenuadas con candado
  ("Cerrá primero la parada anterior").
- Specs: saltear → 422; cerrar en orden habilita la siguiente; fallido habilita la siguiente;
  admin puede saltear. (7 ejemplos verdes.)

## Fix: el delivery (en PWA) veía la vista admin de despachos (2026-06-23)

`MOBILE_HOME.delivery` apuntaba a `/m/delivery/despachos`, que renderizaba `DespachoListView`
(la vista de **admin**: KPIs, reasignar/cancelar, despachos de todos los repartidores) en lugar
del `DeliveryDashboard` del propio repartidor. Por eso el delivery en la PWA no veía ninguna de
las mejoras (firma, "siguiente", botón verde, Llamar/Ir) — estaban en su dashboard, que nunca
se mostraba. Ahora `/m/delivery/despachos` y `/m/delivery/historial` renderizan `DeliveryDashboard`.

## Delivery: firma, "siguiente", touch targets, acciones por parada (2026-06-23)

- **Fix de la firma de entrega**: el canvas tenía resolución interna fija (400×120) distinta del tamaño mostrado → en mobile la firma quedaba corrida/escalada. Ahora se ajusta al tamaño real (× devicePixelRatio) y el trazo mapea 1:1 con el dedo; canvas más alto (150px) para firmar cómodo.
- **"Siguiente"**: la primera entrega pendiente se resalta (borde verde + chip "▶ Siguiente").
- **Touch targets mobile**: botones más grandes (≥46px), texto de nombre/dirección más legible.
- Botón "Ruta en Maps" en **paleta verde** (outline).
- Cada parada suma **"Llamar"** (tel:) e **"Ir"** (Maps a esa única dirección) — para usar stop por stop.

## Fix: el delivery no podía marcar entregado (422 + 500 latente) (2026-06-23)

Dos bugs encadenados en `PATCH /dispensaciones/:id/entregar`:
- **422**: `delivery_fields_presentes` (exige dirección/contacto de envío) corría en **cada** save, no solo al crear → al re-guardar para marcar entregado, un despacho con algún campo de envío vacío rompía. Ahora la validación es `on: :create`.
- **500 latente** (lo tapaba el 422): `NotificacionDeliveryService` hacía `dispensacion.club`, pero `Dispensacion` no tiene esa asociación (el club va por `sede`). Corregido a `dispensacion.sede&.club`.
- Spec `despacho_entregar_spec` (entrega normal + despacho con campo de envío vacío).

## Delivery: reordenar su ruta + ruta en Google Maps (2026-06-23)

- **El repartidor puede reordenar sus entregas** (flechas ↑↓ en su dashboard) **solo si el club NO fijó el orden** (ruta no bloqueada). Backend: `rutas_entrega#ordenar` ahora permite al delivery ordenar su propia ruta no bloqueada (sigue bloqueado para staff-only el candado). Specs nuevos.
- **Botón "Ruta en Maps"**: arma la ruta en Google Maps (directions, modo conducción) con las direcciones **de los despachos seleccionados** (o todos los pendientes en orden si no hay selección). En la vista admin se agregaron **checkboxes** a los pendientes (en modo ruta) para elegir cuáles mandar a Maps; el dashboard del repartidor ya tenía selección.
- Ícono "con envío" del historial y de la lista del paciente: **camión** (consistente con despachos).

## Guard de cambio de rol (2026-06-23)

El cambio de rol queda permitido (el historial se atribuye por FK al usuario, no al rol, así que persiste), con dos resguardos:
- **Backend (`club_users#update`)**: bloquea cambiar el rol de un **delivery con despachos pendientes/en viaje** hasta reasignarlos (error con el número). Spec `cambio_rol_guard_spec`.
- **Frontend (`UsuariosView`)**: al cambiar el rol pide confirmación ("los permisos cambian de inmediato, el historial se conserva, revisá asignaciones").

## Ajustes UI: despachos, historial, equipo (2026-06-23)

- **Despachos**: la ruta solo reordena **pendientes** (la hoja de ruta se arma con esos); hint para descubrir la ruta cuando no hay repartidor filtrado; acciones de cada despacho agrupadas en **Etiqueta · Acciones ▾ (completar/fallo/reprogramar/reasignar) · Cancelar**.
- **Historial**: el ícono de "con envío" volvió a **camión** (lucide `Truck`), consistente con despachos.
- **Equipo**: la fila del usuario es clickeable → va al detalle; se quitó el ícono "ver perfil".

## Ruta de entrega: orden + candado (2026-06-23)

El admin puede fijar el orden en que el repartidor entrega los despachos y bloquearlo.
- **Backend**: migración `20260623000001` — tabla `rutas_entrega` (delivery+fecha+`bloqueada`, una por repartidor/día) + `ruta_entrega_id`/`orden_entrega` en `dispensaciones`. Modelo `RutaEntrega`. Controller `RutasEntregaController` (`#show`, `#ordenar`, `#bloqueo`). El serializer expone `orden_entrega`/`ruta_bloqueada`; `mis_paquetes` ordena por `orden_entrega`. Specs (`rutas_entrega_spec`: ordenar, bloquear, aislamiento de tenant, permisos).
- **Admin (`DespachoListView`)**: al filtrar por repartidor aparece la barra de ruta con **selector de fecha** (hoy o futura), flechas ↑↓ por despacho y toggle "Respetar orden" (candado). La ruta se trae/guarda por (repartidor, fecha elegida).
- **Delivery (`DeliveryDashboard`)**: los paquetes vienen en el orden de la ruta, con número visible; si está bloqueada, banner "orden fijado por el club".

## Fix: etiqueta de despacho en PWA + sin QR (2026-06-23)

- Tocar "Etiqueta" en PWA rebotaba a la home mobile: el guard de PWA no permitía la ruta. Se permiten las rutas que terminan en `/etiqueta` y el link abre in-app (sin `target="_blank"`, que rompe en PWA standalone).
- La etiqueta de despacho quedó **sin QR** (decisión de seguridad): club, destinatario, dirección, teléfono y código de paquete. Imprimible + descargable como PDF (`html2pdf.js`).

## Etiqueta de despacho con QR + dos direcciones del paciente (2026-06-22)

### Etiqueta de despacho (sin QR — decisión de seguridad)
- Vista nueva `EtiquetaDespachoView` en `/despachos/:id/etiqueta`: logo+nombre del club, **destinatario**, dirección de entrega, teléfono y **código de paquete**. **Sin QR**: un QR a la app interna en cada paquete que va a la calle era superficie de ataque innecesaria (exponía el login). Imprimible + **descargable como PDF** (`html2pdf.js`, igual que el carnet).
- `DespachoListView`: botón "Etiqueta" por despacho (abre en pestaña nueva).
- Redise UI: bordes de KPIs/inputs más visibles; "Dispensadas desde" y "Hasta" agrupadas en una fila alineada.

### Dos direcciones del paciente
- Migración `20260622000003`: `envio_*` (calle/altura/piso/depto/barrio/ciudad) en `pacientes` = dirección de entrega opcional.
- Domicilio del paciente ahora **requerido** (calle) en alta y edición; entrega **opcional** (sección desplegable "Dirección de entrega distinta").
- `Paciente#direccion_entrega`: usa la de envío si está cargada, si no el domicilio. Al dispensar/reservar con envío, el snapshot sale de ahí (`dispensaciones_controller`, `reservas_controller`).

## Fixes UI varios (2026-06-22)

- **/salas**: editar/eliminar desde las cards (grid) redirigía a dashboard. Los botones estaban dentro del `RouterLink` con `@click.stop` pero sin `.prevent` → el ancla navegaba igual. Ahora `@click.stop.prevent`.
- **/historial**: las dispensaciones con envío mostraban un badge celeste poco legible (ícono Truck chico). Ahora ícono de moto (`bi-scooter`) más grande y centrado.
- **Forms de paciente**: el campo de domicilio existía en crear y editar pero con rótulos distintos (en editar parecía "solo entrega"). Unificados: "Domicilio del paciente · se usa también para entregas". Es **un solo** domicilio que sirve de dirección y de entrega por defecto (no hay dos direcciones separadas).
- Doc nuevo: `docs/DOMINIO-SETUP.md` (pasos para el dominio propio).

## Andamiaje para dominio propio (inerte hasta setear ENV) (2026-06-22)

Preparación para mañana (dominio cultivoespacial.com). Todo inerte: sin las ENV nuevas, el comportamiento es idéntico al actual.
- **`lib/cable.js`** (frontend): helper único `cableUrl()` que deriva la URL del WebSocket del origen actual cuando `VITE_API_URL` es relativa (`/api`) — así el cable sigue al dominio que sirve la app. Reemplaza las 3 copias en composables.
- **`jwt_cookie_middleware.rb`** + **`sessions_controller#destroy`**: `COOKIE_DOMAIN` opcional (set y delete usan el mismo domain). Solo necesario si alguna vez se separan front/API en subdominios distintos.
- **`cors.rb`**: orígenes parametrizados por `FRONTEND_URL` + `EXTRA_CORS_ORIGINS` (lista por comas). Agregar dominio = setear ENV, sin tocar código.
- Recordatorio: el build ya usa `VITE_API_URL=/api` (relativo) y Rails sirve la SPA same-origin → al apuntar el dominio al mismo web service, todo (login/logout/cable/cookie) sigue al dominio solo.

## Fixes: detalle de planta (500) + aplicar plan (404) (2026-06-22)

- **500 en `GET /plants/:id`**: `serialize_plant_detail` accedía a `plant.lote.sala.id` sin nil-check; los lotes finalizados quedan sin sala (`sala_id: nil`) → reventaba. Ahora es nil-safe (igual que el serializer de lista). Spec `plant_show_sin_sala_spec.rb`.
- **404 "Plan no encontrado" al aplicar un plan a un lote**: `aplicar_plan`/`preview_plan` exigen `.publicados`, pero el modal listaba plantillas en cualquier estado (incluido borrador). Ahora `LoteAplicarPlanModal` lista solo planes **publicados**, con empty-state que explica que hay que publicarlo. Además `PlanTrabajoView` suma botón **"Publicar"** para borradores (antes solo se podía publicar al crear).

## Fix: editar estado del lote no refrescaba plantas ni historial (2026-06-22)

Al editar un lote por el modal (cambiar estado esqueje→vegetativo + fecha) el historial no se actualizaba sola (había que refrescar) y el listado de plantas quedaba con el estado viejo.
- **Backend (`lotes_controller#update`)**: si la edición cambia el `estado`, ahora propaga el nuevo estado a las plantas (mismo criterio que la máquina de estados: `FASE_A_PLANT_STATE`, sin tocar descartadas/cosechadas). Antes el update directo no las tocaba.
- **Frontend (`LoteDetailView`)**: `@saved` del modal ahora refresca lote + historial (`loadEventos`) + plantas (`plants.fetchByLote`) + gráficos. Antes solo refrescaba el lote.
- **Frontend (`stores/lotes.js`)**: `fetchOne` ahora sincroniza el lote en `items` / `itemsBySala`, así la lista `/lotes` (y la de la sala) no quedan con el estado viejo tras editar (antes `fetchOne` solo tocaba `current`).

## Fix: redirect post-login desde QR (2026-06-22)

Al escanear un QR (ej. de stock, `/s/:codigo_qr`) sin sesión, el login redirigía a inicio en vez de volver a la página del QR. **Causa**: el interceptor 401 de axios (`api.js`) hacía `window.location.href = '/login'` sin preservar la ruta, pisando el `?redirect=` que el router sí armaba — y el 401 del bootstrap (`/me`) lo disparaba siempre.
- **`api.js`**: el 401 del bootstrap (`/me`) ya no fuerza redirect (lo maneja `router.beforeEach`, que preserva la ruta). Otros 401 mandan a `/login?redirect=<ruta+query>`.
- **`stores/auth.js`**: `login()` respeta el `redirect` para **todos** los roles (antes lo ignoraba para super_admin/auditor/medico/abogado/delivery). Si el rol no tiene permiso, `beforeEach` lo reencauza a su home.

## Stock: cantidad inicial + listados enriquecidos (2026-06-22)

- **`stocks.cantidad_inicial`** (migración `20260622000002`): "lo que entró" vs cantidad actual. Se setea en `before_create` (externo/derivado nacen con su cantidad) y se acumula en `PesajeManicura#confirmar!` (manicura nace en 0). Backfill = suma de movimientos `produccion` o `cantidad`. Expuesto en `serialize_stock`.
- **`/stock` (dispensador)**: columna "Ingresó" (fecha), N° de producto y chip Propio/Externo bajo el producto, e "Inicial" como subtexto de Disponible (`420g · de 500g`). Info secundaria oculta en mobile.
- **`/admin/stock`** (tab Inventario): reescrito de cards a **tabla real** (Tipo · Cepa · Lote · Sede · Ingresó · Total cosechado · Actual) con **paginado y filtros server-side** (tipo / sede / rango de fecha) vía nuevo endpoint `GET /stocks/inventario` (`{ stocks, meta, totales }`). Los KPIs del header respetan el filtro activo. Spec `stocks_inventario_spec.rb` (paginado, filtros, aislamiento de tenant).

## Unificación del flujo de manicura (2026-06-22)

Se eliminó la convivencia de tres caminos para "manicura → stock" (pesajes nuevo, batch legacy, aprobación legacy) que colisionaban y producían el error de "asignar sede al confirmar". Ahora hay **un solo flujo**: `PesajeManicura` (borrador → enviado → confirmado).

### Backend
- **Modelo `Lote`**: eliminados `aprobar_manicura!`, `rechazar_manicura!`, `aprobar_y_finalizar!`, `completar_manicura_directa!` y el callback `push_manicura_pendiente`. El estado `manicura_pendiente` deja de usarse (queda en el enum por compatibilidad).
- **`PesajeManicura`**: `peso_calculado_g`/`plantas_registradas_count` soportan carga manual (sin QR) vía `peso_total_g`/`plantas_count`; nuevo `cargar_manual!`; `enviar!` dispara push al admin (reemplaza el push viejo a `/aprobaciones`).
- **`plants#registrar_peso`**: solo flujo `PesajeManicura` (se quitó la rama legacy de `Pesada` borrador); auto-transición `secado → en_manicura` al primer pesaje.
- **`pesajes_manicura#create`**: acepta carga manual (`plantas_count` + `peso_total_g` + `enviar`).
- **`lotes_controller`**: `transiciones` ya no carga manicura (422 si `manicurado`); retiradas las acciones `aprobar_manicura`, `rechazar_manicura`, `completar_manicura`, `finalizar_pesaje_manicura` y sus rutas. `LotePolicy`: scope de manicura = `secado` + `en_manicura` propios.
- **`Club`**: agregado `has_many :stocks` (faltaba; `PesajeManicura#confirmar!` lo usaba).
- **Migración `20260622000001`**: reconvierte lotes `manicura_pendiente` en vuelo al flujo nuevo (genera `PesajeManicura` enviado y los devuelve a `en_manicura`).

### Frontend
- `MncPesajesView`: botón **"Cerrar pesaje y mandar a confirmar"** (antes "Cerrar día y enviar"); copy "jornada/día" → "pesaje".
- `MncLoteDetailView` + `CompletarManicuraModal`: la carga por lote (sin QR) crea un `PesajeManicura` y lo manda a confirmar (sin sede; la sede se asigna en Stock).
- Alerta de Home y mobile admin repuntadas a `/admin/pesajes-manicura`; `/aprobaciones` y `/manicura` ahora redirigen ahí. Vista `AdminAprobacionesView` eliminada; ítem "Manicura" del sidebar con hint.
- API: eliminadas `aprobarManicura`, `rechazarManicura`, `completarManicura`, `finalizarPesajeManicura`.

### Tests
- 730 backend verde (nuevos specs de flujo unificado en `lote_machine_spec` y `pesajes_manicura_flujo_spec`; `dsfix7` reescrito al scope nuevo). 58 frontend verde.

---

## Housekeeping pre-IoT (2026-04-30, sesión 4)

### Deuda técnica eliminada
- **`Socio` + `SociosController` eliminados**: `Socio` mapeaba a tabla `socios` inexistente — model y controller muertos borrados. Rutas `/socios` ya apuntaban a `PacientesController` (sin cambio en comportamiento)
- **`SocioNota` eliminado**: alias redundante de `PacienteNota` usando la misma tabla `paciente_notas`
- **`SocioNotum` eliminado**: modelo zombie generado por Rails al singularizar mal `SocioNotas`
- **Tabla `socio_nota` droppeada**: migración `20260430000001_drop_socio_nota` — tabla huérfana sin controller ni UI

### Tests Bloque H (24 nuevos, 292 total)
- `spec/requests/cuenta_corrientes_spec.rb` — GET show, POST cargar, POST ajuste, auth 403, cross-club 404
- `spec/models/dispensacion_debitar_cc_spec.rb` — debita CC, crea movimiento, referencia dispensacion, saldo anterior/nuevo, created_by, no-op con aporte=0, no-op sin CC, transaccionalidad (rollback si movimiento falla)
- Nuevas factories: `stocks`, `cuenta_corrientes`

---

## Bloque H — Contabilidad: H4 integración CC + H5 PDF P&L (2026-04-30, sesión 3)

### H4 — Integración automática dispensación → CuentaCorriente
- `Dispensacion`: `after_create :debitar_cuenta_corriente`
  - Si `aporte_socio_ars > 0` y el paciente tiene CC: decrementa `saldo_disponible` y crea `CuentaCorrienteMovimiento` con `tipo:'debito'`, `dispensacion:self`, `created_by: user`
  - Opera dentro de la misma transacción que el `create` — rollback automático si falla
  - El `credito_suficiente` (validate on: :create) ya bloqueaba dispensaciones sin saldo; el after_create cierra el ciclo con el débito efectivo

### H5 — PDF del P&L de producción
- `ContabilidadView`: botón "Exportar PDF" en la barra de sub-tabs del P&L
  - Lazy import de `html2pdf.js` (sin impacto en bundle inicial)
  - Genera PDF en A4 landscape con escala 2x de la vista activa (Por lote o Por cepa)
  - Nombre de archivo automático: `PL_produccion_[subtab]_[fecha].pdf`
  - Spinner durante generación, botón deshabilitado mientras procesa

---

## Ola DS-FIX-9 — Admin hamburger responsive (2026-04-30)
- AdminTopBar: botón hamburguesa (`<Menu>`) oculto en desktop, visible en ≤1023px
- App.vue: `adminDrawerOpen` ref + Teleport drawer overlay con `AdminSidebar` reutilizada
- App.vue: fix bottom nav — excluye todos los roles con sidebar+drawer (admin, manicura, médico, abogado, auditor)
- AdminTopBar emite `toggle-drawer`, App.vue cierra el drawer en cambio de ruta

## Ola DS-FIX-8 — Design System cleanup (2026-04-30)
- Eliminada ruta `/manicura` del admin (ahora redirige a `/aprobaciones`)
- Tokens CSS unificados: `--c-role-*` = background canónico de cada sidebar (12 roles)
- `UsuariosView`: badges de rol consumen tokens via `roleStyle()` / `roleColor()` — sin colores hardcodeados
- Todos los sidebars actualizados a `var(--c-role-X)` (AdminSidebar, CultivadorSidebar, DispensadorSidebar, ManicuraSidebar, MedicoSidebar, AbogadoSidebar, AuditorSidebar, SuperAdminLayout)

## Ola DS-FIX-7 — Flujo aprobación manicura (2026-04-29)
- Estado `manicura_pendiente`: manicura registra pesada → queda pendiente de aprobación admin
- Vistas manicura: `MncPendientesView` (registrar pesada de secado) + `MncEsperaView` (solo lectura)
- Vista admin: `AdminAprobacionesView` (aprobar/rechazar con motivo) + `AdminCuradoView` (wizard 2 pasos: pesada curado + ingreso a stock)
- Backend: acciones `aprobar_manicura` / `rechazar_manicura` en LotesController
- Super admin sidebar: `var(--c-role-superadmin)` = `#1A1F36`
- 268 tests RSpec

## Ola DS-FIX-6 — Roles externos (2026-04-28)
- Layouts completos con sidebar + topbar + drawer para: médico, abogado, auditor
- Vistas: `MedicoLayout`, `AbogadoLayout`, `AuditorLayout` con rutas protegidas
- Backend: lockdown por rol en todos los controllers

## Ola DS-FIX-1 a DS-FIX-5 — Design System Ola 1 (2026-04-27)
- AdminSidebar dark con tokens `--c-role-admin`
- AdminTopBar con breadcrumb dinámico, notificaciones, avatar dropdown
- Design System primitivos: Avatar, Dropdown, EmptyState, Stat, Card, Badge, Banner, Button, Spinner
- App.vue bifurcado por rol (admin-shell, mnc-shell, dpv-shell, med-shell, abg-shell, aud-shell)
- Mobile: drawer con hamburguesa para dispensador, manicura, médico, abogado, auditor

## Bloque H — Contabilidad: CuentaCorriente + P&L por cepa (2026-04-30, sesión 2)

### H2 — CuentaCorriente de socios
- Backend: `CuentaCorrientesController` — `GET /pacientes/:id/cuenta_corriente`, `POST cargar`, `POST ajuste`
- Rutas anidadas bajo `/pacientes` en routes.rb
- API frontend: `getCuentaCorriente`, `cargarCreditoCC`, `ajustarCC`
- `SocioDetailView`: nuevo tab "Cuenta corriente" (solo admin)
  - Header con saldo disponible y límite de crédito
  - Barra de consumo con colores (verde/ámbar/rojo según porcentaje)
  - Form inline para cargar crédito y ajuste manual (valores +/-)
  - Historial de movimientos con tipo coloreado, monto, saldo resultante

### H3 — P&L por cepa
- `ContabilidadView` tab P&L: sub-tabs "Por lote" | "Por cepa"
- Vista "Por cepa": agrupa `todosLotes` por `genetica_id`, computa promedio/mín/máx de costo/g y gramos totales
- Sin llamadas adicionales al backend (usa datos del `listLotes()` ya cargado)

## Bloque H — Contabilidad: P&L por lote (2026-04-30)
- LoteDetailView: card "Costos de producción" en aside — carga/edita `CostoLote` inline
  - Campos: insumos, energía, mano de obra, prorrateado, gramos producidos
  - Muestra costo total y costo/gramo en tiempo real
- ContabilidadView: nuevo tab "P&L por lote"
  - Lista todos los lotes con costos cargados, ordenados por costo/g asc
  - Columnas: código, cepa, estado, costo total, gramos, $/g
  - Links al detalle del lote
- Backend: `serialize_lote` incluye `costo_total` y `gramos_producidos` + eager load `:costo_lote`
- AdminDashboard: fix endpoint `/inventario/pendiente` (404) → `listLotes({ estado: 'manicura_pendiente' })`
- AdminDashboard: card "Pipeline post-cosecha" (lotes en manicura_pendiente + curado)
- AdminDashboard: card "Stock disponible" agrupado por forma_producto
- AdminDashboard: acciones rápidas contextuales (Aprobaciones + Cerrar curado con badge count)

## Bloque G — Housekeeping (2026-04-28)

### G1 — Logger wrapper
- Created `src/utils/logger.js` — DEV-only wrapper around `console.*`
- Replaced all 50+ `console.log/error/warn/debug` calls across 24 files
- Production builds emit zero console output

### G2 — Dependency audit
- `npm audit fix` — reduced vulnerabilities from 18 to 4 (remaining 4 are build-time only in `vite-plugin-pwa`)
- Applied non-breaking minor/patch updates

### G3 — Test suite
- Added 58 unit tests across 9 test files
- Coverage: EmptyState, Paginator, Breadcrumb, Lightbox, ConfirmDialog, useConfirm, useToast, usePermissions, App
- Fixed `<Teleport to="body">` test pattern — use `document.querySelector()` instead of `w.find()`

### G4 — Docs
- Rewrote `frontend/README.md` (stack, credentials, commands)
- Created `docs/ARCHITECTURE.md` (folder structure, data model, permissions, critical flows, bundle breakdown)
- Created `docs/CHANGELOG.md` (this file)
- Created `docs/ROADMAP.md` (blocks H–K)

### G5 — Bundle optimization
- Added `manualChunks` in `vite.config.js`: vue, charts, qr split into separate chunks
- Converted `html2pdf.js` to lazy dynamic import in `InformeSemestralView`
- Main chunk: 1,948 kB → 676 kB (gzip: 575 kB → 187 kB)

### G6 — Security
- Verified: CORS restricted, HttpOnly cookies, `authenticate_user!` on all controllers
- Verified: no secrets committed, `.env*.local` in `.gitignore`
- 4 remaining audit warnings are build-time only (vite-plugin-pwa rollup deps)

### G7 — Dead code removal
- Deleted 6 unreferenced components: `BaseModal.vue`, `SalaModal.vue`, `ImpersonationBanner.vue`, `AgricultorDashboard.vue`, `PlantsByGeneticaChart.vue`, `UsuarioSedesManager.vue`
- No remaining TODO/FIXME markers

---

## Bloque F — UX polish (2026-04)

- Replaced all `alert()` with `useToast` / `useConfirm`
- Renamed `/socios` → `/pacientes` (canonical) with `/socios` alias for backward-compat
- Breadcrumb chains: added Sede segment via backend serializer (`includes(sala: :sede)`)
- Lightbox component added to photo galleries (LoteDetailView, PlantaDetailView)
- Paginator component replaces "Ver más" incremental pattern
- useToast / useConfirm wired into 4 detail views

---

## Bloque E — Roles & permissions (2026-04)

- `usePermissions` composable with full role matrix
- Backend `permissions.rb` concern mirrors frontend checks
- `PlanEnforcer` service enforces plan-level limits

---

## Bloque D — Salas & Lotes (2026-04)

- SalaDetailView, LoteDetailView, PlantaDetailView with full CRUD
- GraficosLote component (Chart.js)
- Sala → Cultivador assignment (SalaCultivadoresManager)

---

## Bloque C — Socios & Dispensaciones (2026-04)

- SocioDetailView, SocioNuevoView
- Dispensaciones component with limits display
- IndicacionesMedicas, PacienteDocumentos sub-components

---

## Bloque B — Auth & multi-tenant (2026-04)

- Devise Token Auth integration
- Auth store (Pinia), router guards
- Role-based dashboard routing (DashboardView)

---

## Bloque A — Foundation (2026-04)

- Vue 3 + Vite + Pinia + Vue Router scaffold
- Bootstrap 5 base layout
- Docker Compose full-stack setup
