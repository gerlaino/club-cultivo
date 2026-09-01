<template>
  <div class="mst">
    <!-- ── Encabezado: qué es esto y en qué estado está ───────────────────────── -->
    <header class="mst__head">
      <div class="mst__head-left">
        <h1 class="mst__title">Mostrador</h1>
        <p class="mst__sub">Lo que hay sobre la mesa para dispensar hoy.</p>
      </div>

      <div class="mst__head-right">
        <select v-if="sedes.length > 1" v-model="sedeId" class="mst__select mst__select--sede">
          <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
        </select>
        <span v-if="tab === 'hoy'" class="mst__estado" :class="`is-${estado}`">
          <span class="mst__estado-dot" />{{ ESTADO_LABEL[estado] }}
        </span>
      </div>
    </header>

    <!-- Un repartidor esperando que le reciban la caja: acá es donde está el cajón. Al recibirla
         entra plata Y puede subir producto a la mesa, así que la pantalla se recarga. -->
    <RendicionCajaCard @recibida="cargar" />

    <nav class="mst__tabs">
      <button class="mst__tab" :class="{ 'is-on': tab === 'hoy' }" @click="tab = 'hoy'">Hoy</button>
      <!-- Los turnos cerrados los ve TAMBIÉN el que atiende, con los suyos: cerraba y no tenía
           dónde mirarlo si al día siguiente le preguntaban por una diferencia. -->
      <button class="mst__tab" :class="{ 'is-on': tab === 'turnos' }" @click="tab = 'turnos'">
        Turnos
      </button>
      <template v-if="gestiona">
        <button class="mst__tab" :class="{ 'is-on': tab === 'merma' }" @click="tab = 'merma'">
          Merma
          <span v-if="sinRevisar" class="mst__tab-badge">{{ sinRevisar }}</span>
        </button>
        <button class="mst__tab" :class="{ 'is-on': tab === 'rendiciones' }" @click="tab = 'rendiciones'">
          Rendiciones
        </button>
      </template>
    </nav>

    <!-- ══ RENDICIONES: lo que ya rindieron los repartidores ══════════════════ -->
    <template v-if="tab === 'rendiciones'">
      <p class="mst__seccion-sub">
        Lo que cada repartidor cobró en la calle y lo que entregó al volver. Lo que falta no es
        una pérdida: queda a su nombre y se ve acumulado en su ficha.
      </p>
      <RendicionCajaCard historial />
    </template>

    <!-- ══ MERMA: dónde se le va el producto ══════════════════════════════════ -->
    <MostradorMerma v-else-if="tab === 'merma'" :sede-id="sedeId" :varias-sedes="sedes.length > 1"
                    @sin-revisar="sinRevisar = $event" />

    <!-- ══ TURNOS: los que ya cerraron ════════════════════════════════════════ -->
    <MostradorTurnos v-else-if="tab === 'turnos'" :sede-id="sedeId" />

    <template v-else>

    <div v-if="cargando" class="mst__skel-wrap">
      <div v-for="n in 4" :key="n" class="mst__skel" />
    </div>

    <p v-else-if="error" class="mst__aviso mst__aviso--error">{{ error }}</p>

    <!-- ══ CERRADO: abrirlo ═══════════════════════════════════════════════════ -->
    <section v-else-if="!abierto" class="mst__card">
      <div class="mst__card-head">
        <h2 class="mst__card-title">Abrir el mostrador</h2>
        <p class="mst__card-sub">
          {{ sugerido.length
             ? 'Viene con lo que se contó en el cierre anterior. Corregí lo que no coincida.'
             : 'Elegí qué baja del depósito a la mesa.' }}
        </p>
      </div>

      <label class="mst__fondo">
        <span class="mst__fondo-lbl">
          Fondo de caja
          <em v-if="fondoSugerido !== null" class="mst__fondo-hint">
            quedaron ${{ fmt(fondoSugerido) }} en el cajón anoche
          </em>
        </span>
        <span class="mst__fondo-input">
          <span class="mst__fondo-signo">$</span>
          <input v-model.number="fondo" type="number" min="0" step="100" class="mst__input mst__input--fondo" />
        </span>
      </label>

      <ul v-if="borrador.length" class="mst__draft">
        <li v-for="(it, i) in borrador" :key="it.stock_id" class="mst__draft-row">
          <div class="mst__draft-prod">
            <span class="mst__draft-nombre">{{ it.etiqueta }}</span>
            <span class="mst__draft-meta">
              {{ it.numero }}<template v-if="it.lote"> · lote {{ it.lote }}</template>
              · {{ fmt(it.disponible) }} {{ it.unidad }} libres
            </span>
          </div>
          <div class="mst__draft-cant">
            <input v-model.number="it.cantidad" type="number" min="0" step="0.1"
                   class="mst__input mst__input--cant" :aria-label="`Cantidad de ${it.etiqueta}`" />
            <span class="mst__draft-unidad">{{ it.unidad }}</span>
          </div>
          <button class="mst__icon-btn" title="Sacar de la lista" @click="borrador.splice(i, 1)">
            <X :size="16" />
          </button>
        </li>
      </ul>
      <p v-else class="mst__vacio">Todavía no pusiste nada sobre la mesa.</p>

      <!-- El producto Y cuánto, en el mismo gesto. Antes la cantidad aparecía recién en la fila
           de abajo, después de agregar: se podía poner, pero no se veía — que para el que abre el
           mostrador por primera vez es lo mismo que no poder. Y con el mostrador ya abierto,
           "Bajar a la mesa" sí la pregunta en el acto: eran dos formas de hacer lo mismo. -->
      <div class="mst__agregar">
        <select v-model="aAgregar" class="mst__select">
          <option value="">Agregar del depósito…</option>
          <option v-for="s in agregables" :key="s.stock_id" :value="s.stock_id">
            {{ s.etiqueta }} — {{ fmt(s.disponible) }} {{ s.unidad }} libres
          </option>
        </select>
        <div class="mst__agregar-cant">
          <input v-model.number="cantAAgregar" type="number" min="0" step="0.1"
                 class="mst__input mst__input--cant" placeholder="Cuánto"
                 aria-label="Cuánto baja a la mesa" @keyup.enter="agregarAlBorrador" />
          <span class="mst__draft-unidad">{{ unidadAAgregar }}</span>
        </div>
        <button class="mst__btn mst__btn--ghost"
                :disabled="!aAgregar || !(cantAAgregar > 0) || !!excedeDisponible"
                @click="agregarAlBorrador">
          Agregar
        </button>
      </div>
      <p v-if="excedeDisponible" class="mst__aviso mst__aviso--warn">
        En el depósito quedan {{ fmt(excedeDisponible.disponible) }} {{ excedeDisponible.unidad }}
        de {{ excedeDisponible.etiqueta }}.
      </p>

      <div class="mst__acciones">
        <button class="mst__btn mst__btn--primary" :disabled="guardando || !borrador.length" @click="abrir">
          {{ guardando ? 'Abriendo…' : 'Abrir mostrador' }}
        </button>
      </div>

      <!-- Un dedazo en el cierre —21 en vez de 215— deja un faltante de 194 g que después nadie
           entiende. El que cierra tiene que saber, en el momento, que eso se arregla y dónde. -->
      <p v-if="huboTurnoAnterior" class="mst__pie">
        ¿Se contó mal el cierre anterior? Se corrige desde <b>Turnos</b>, sin borrar nada: queda
        asentada la diferencia.
      </p>
    </section>

    <!-- ══ ABIERTO SIN RECIBIR: el admin lo cargó, falta que lo recibas ═══════ -->
    <section v-else-if="!turno.confirmado" class="mst__card">
      <div class="mst__card-head">
        <h2 class="mst__card-title">
          {{ loCargueYo ? 'Esperando que lo reciban' : `${turno.abierto_por} dejó esto sobre la mesa` }}
        </h2>
        <p class="mst__card-sub">
          {{ loCargueYo
             ? 'Lo tiene que revisar y confirmar quien vaya a atender: dos firmas de la misma persona no son ninguna.'
             : 'Revisá que esté y confirmá. Si algo no coincide, corregí el número antes de arrancar.' }}
        </p>
      </div>

      <ul class="mst__draft">
        <li v-for="r in recepcion" :key="r.item_id" class="mst__draft-row"
            :class="{ 'is-quitado': r.quitar }">
          <div class="mst__draft-prod">
            <span class="mst__draft-nombre">{{ r.etiqueta }}</span>
            <span class="mst__draft-meta">
              {{ r.quitar ? 'no está sobre la mesa — se saca' : `dejó ${fmt(r.esperado)} ${r.unidad}` }}
            </span>
          </div>
          <div v-if="!r.quitar" class="mst__draft-cant">
            <input v-if="!loCargueYo" v-model.number="r.contado" type="number" min="0" step="0.1"
                   class="mst__input mst__input--cant" :aria-label="`Contado de ${r.etiqueta}`" />
            <span v-else class="mst__mesa">{{ fmt(r.esperado) }}</span>
            <span class="mst__draft-unidad">{{ r.unidad }}</span>
          </div>
          <span v-if="!loCargueYo && !r.quitar" class="mst__dif" :class="difClase(r)">{{ difTexto(r) }}</span>
          <!-- El producto que directamente NO ESTÁ se saca, no se pone en cero: un renglón en
               cero es un pendiente que hay que volver a explicar cada vez que alguien mira. -->
          <button v-if="!loCargueYo" class="mst__icon-btn"
                  :title="r.quitar ? 'Volver a ponerlo' : 'No está sobre la mesa'"
                  @click="r.quitar = !r.quitar">
            <Undo2 v-if="r.quitar" :size="16" />
            <X v-else :size="16" />
          </button>
        </li>
      </ul>

      <label v-if="hayCorreccion" class="mst__campo mst__campo--motivo">
        <span class="mst__campo-lbl">Motivo de la diferencia</span>
        <input v-model="motivoRecepcion" type="text" class="mst__input"
               placeholder="Ej: faltaban 3 g de Northern" />
      </label>

      <!-- La plata se recibe igual que la mercadería: los dos arqueos arrancan de un número
           verificado, o el cierre no mide nada. -->
      <div v-if="turno.caja" class="mst__caja">
        <div class="mst__caja-fila mst__caja-fila--total">
          <span>{{ loCargueYo ? 'Fondo que dejaste' : 'Tendría que haber en la caja' }}</span>
          <b>${{ fmt(turno.caja.esperado_ars) }}</b>
        </div>
        <label v-if="!loCargueYo" class="mst__campo mst__campo--fila">
          <span class="mst__campo-lbl">Cuento</span>
          <input v-model.number="efectivoRecepcion" type="number" min="0" step="100"
                 class="mst__input mst__input--fondo" />
        </label>
        <p v-if="!loCargueYo && difRecepcion !== null" class="mst__dif-caja" :class="difRecepcion === 0 ? 'is-ok' : 'is-mal'">
          {{ difRecepcion === 0 ? 'Cuadra' : `${difRecepcion > 0 ? 'Sobran' : 'Faltan'} $${fmt(Math.abs(difRecepcion))}` }}
        </p>
        <label v-if="difRecepcion" class="mst__campo mst__campo--motivo">
          <span class="mst__campo-lbl">Motivo de la diferencia en caja</span>
          <input v-model="motivoEfectivo" type="text" class="mst__input" placeholder="Ej: faltaban $2.000" />
        </label>
      </div>

      <div v-if="!loCargueYo" class="mst__acciones">
        <button class="mst__btn mst__btn--primary" :disabled="guardando" @click="confirmar">
          {{ guardando ? 'Confirmando…' : (hayCorreccion ? 'Corregir y recibir' : 'Confirmar y arrancar') }}
        </button>
      </div>
    </section>

    <!-- ══ ABIERTO Y RECIBIDO: operar ═════════════════════════════════════════ -->
    <template v-else>
      <section class="mst__turno">
        <div class="mst__turno-info">
          <span class="mst__turno-quien">{{ turno.confirmado_por || turno.abierto_por }}</span>
          <span class="mst__turno-desde">desde las {{ hora(turno.confirmado_at || turno.abierto_at) }}</span>
          <span v-if="turno.confirmado_por && turno.confirmado_por !== turno.abierto_por"
                class="mst__turno-desde">· lo dejó {{ turno.abierto_por }}</span>
        </div>
        <div class="mst__turno-acc">
          <!-- En gramos no se compara con nada; en plata se ve de un vistazo que sobre esa mesa
               hay medio sueldo. Sólo para quien responde por eso. -->
          <span v-if="gestiona && turno.valor_mesa_ars" class="mst__valor-mesa">
            ${{ fmt(turno.valor_mesa_ars) }} sobre la mesa
          </span>
          <button class="mst__btn mst__btn--primary" @click="abrirCierre">Cerrar y contar</button>
        </div>
      </section>
      <p v-if="turno.hubo_correccion_apertura" class="mst__aviso mst__aviso--warn">
        La apertura se corrigió sobre lo que dejó el turno anterior.
      </p>

      <div class="mst__table-wrap">
        <table class="mst__table tabla-cards">
          <thead>
            <tr>
              <th>Producto</th>
              <th class="mst__th-num">En la mesa</th>
              <th class="mst__th-num">Salió</th>
              <th class="mst__th-num">En depósito</th>
              <th class="mst__th-acc"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="it in turno.items" :key="it.id" :class="{ 'is-alerta': it.senal === 'sin_repuesto' }">
              <td data-col="Producto">
                <div class="mst__prod">{{ it.etiqueta }}</div>
                <div class="mst__prod-meta">
                  <span v-if="it.senal === 'reponer'" class="mst__pill mst__pill--warn">Reponer</span>
                  <span v-else-if="it.senal === 'sin_repuesto'" class="mst__pill mst__pill--danger">Sin repuesto</span>
                  <span v-if="it.sin_supervision" class="mst__pill mst__pill--info">Repuesto desde el mostrador</span>
                </div>
              </td>
              <td class="mst__td-num" data-col="En la mesa">
                <span class="mst__mesa">{{ fmt(it.esperado) }}</span>
                <span class="mst__unidad">{{ it.unidad }}</span>
              </td>
              <td class="mst__td-num mst__td-mut" data-col="Salió">
                {{ it.dispensada > 0 ? `${fmt(it.dispensada)} ${it.unidad}` : '—' }}
              </td>
              <td class="mst__td-num mst__td-mut" data-col="En depósito">
                {{ fmt(it.en_deposito) }} {{ it.unidad }}
              </td>
              <td class="mst__td-acc" data-col="">
                <button class="mst__btn mst__btn--mini" @click="abrirMover(it, 'carga')">Reponer</button>
                <button class="mst__btn mst__btn--mini mst__btn--ghost" @click="abrirMover(it, 'devolucion')">
                  Devolver
                </button>
                <!-- Contar SÓLO este, sin cerrar el turno: con quince frascos, cerrar y reabrir
                     son veinte minutos y nadie lo hace dos veces por día. -->
                <button class="mst__btn mst__btn--mini mst__btn--ghost" @click="abrirConteo(it)">
                  Contar sólo este
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="gestiona && turno.caja" class="mst__caja-barra">
        <span class="mst__caja-barra-lbl">
          En la caja tendría que haber <b>${{ fmt(turno.caja.esperado_ars) }}</b>
        </span>
        <button class="mst__btn mst__btn--mini" @click="abrirPlata('ingreso')">Poner plata</button>
        <button class="mst__btn mst__btn--mini mst__btn--ghost" @click="abrirPlata('salida')">Sacar plata</button>
      </div>

      <div class="mst__acciones mst__acciones--turno">
        <select v-model="aAgregar" class="mst__select">
          <option value="">Bajar otro producto del depósito…</option>
          <option v-for="s in agregables" :key="s.stock_id" :value="s.stock_id">
            {{ s.etiqueta }} — {{ fmt(s.disponible) }} {{ s.unidad }} libres
          </option>
        </select>
        <button class="mst__btn mst__btn--ghost" :disabled="!aAgregar" @click="bajarNuevo">Bajar a la mesa</button>
      </div>
    </template>

    <!-- ══ CERRAR: los dos arqueos, en un gesto ═══════════════════════════════ -->
    <div v-if="cierre" class="mst__modal-back" @click.self="cierre = null">
      <div class="mst__modal mst__modal--ancho">
        <h3 class="mst__modal-title">Cerrar el mostrador</h3>
        <p class="mst__modal-sub">
          Contá lo que queda y escribilo. Recién ahí te muestro lo que tendría que haber —
          si lo vieras antes, escribirías ese número y el conteo no mediría nada.
        </p>

        <div class="mst__conteo">
          <div v-for="c in cierre.conteos" :key="c.item_id" class="mst__conteo-row">
            <div class="mst__conteo-prod">
              <span class="mst__draft-nombre">{{ c.etiqueta }}</span>
              <!-- Lo esperado NO se muestra hasta que el conteo está escrito: nadie pesa 297 g
                   teniendo el 297 delante. Con el número a la vista, el arqueo es teatro y toda
                   la merma que medimos da cero. -->
              <span v-if="contado(c)" class="mst__draft-meta">
                tendría que haber {{ fmt(c.esperado) }} {{ c.unidad }}
              </span>
            </div>
            <div class="mst__conteo-cant">
              <input v-model.number="c.contado" type="number" min="0" step="0.1"
                     class="mst__input mst__input--cant" :aria-label="`Contado de ${c.etiqueta}`" />
              <span class="mst__draft-unidad">{{ c.unidad }}</span>
            </div>
            <span class="mst__dif" :class="difClase(c)">{{ difTexto(c) }}</span>
          </div>
        </div>

        <!-- Un faltante sin explicación no se puede revisar después: a los tres días nadie se
             acuerda. Por eso el motivo aparece sólo cuando hace falta, y es obligatorio. -->
        <label v-if="hayDiferencia" class="mst__campo mst__campo--motivo">
          <span class="mst__campo-lbl">Motivo de la diferencia</span>
          <input v-model="cierre.motivo" type="text" class="mst__input"
                 placeholder="Ej: merma de fraccionamiento" />
        </label>

        <div v-if="turno?.caja" class="mst__caja">
          <!-- Mismo criterio que los gramos: primero se cuenta, después se muestra contra qué. -->
          <template v-if="cierre.efectivo !== null && cierre.efectivo !== ''">
            <div class="mst__caja-fila">
              <span>Fondo con el que abrió</span><b>${{ fmt(turno.caja.fondo_ars) }}</b>
            </div>
            <div class="mst__caja-fila">
              <span>Cobrado en efectivo</span><b>${{ fmt(turno.caja.cobrado_efectivo_ars) }}</b>
            </div>
            <div class="mst__caja-fila mst__caja-fila--total">
              <span>Tendría que haber</span><b>${{ fmt(turno.caja.esperado_ars) }}</b>
            </div>
          </template>

          <label class="mst__campo mst__campo--fila">
            <span class="mst__campo-lbl">Efectivo contado</span>
            <input v-model.number="cierre.efectivo" type="number" min="0" step="100"
                   class="mst__input mst__input--fondo" />
          </label>
          <p v-if="difCaja !== null" class="mst__dif-caja" :class="difCaja === 0 ? 'is-ok' : 'is-mal'">
            {{ difCaja === 0 ? 'Cuadra' : `${difCaja > 0 ? 'Sobran' : 'Faltan'} $${fmt(Math.abs(difCaja))}` }}
          </p>

          <label class="mst__campo mst__campo--fila">
            <span class="mst__campo-lbl">Dejo de fondo para mañana</span>
            <input v-model.number="cierre.fondo" type="number" min="0" step="100"
                   class="mst__input mst__input--fondo" />
          </label>
          <!-- El que atiende no se lleva la recaudación: eso queda a nombre de quien responde
               por la plata. Sin nadie a quien atribuirlo, se deja todo como fondo. -->
          <p v-if="aRetirar > 0" class="mst__retiro">
            Se retiran <b>${{ fmt(aRetirar) }}</b> — quedan a tu nombre.
          </p>
        </div>

        <div class="mst__modal-acc">
          <button class="mst__btn mst__btn--ghost" @click="cierre = null">Cancelar</button>
          <button class="mst__btn mst__btn--primary" :disabled="guardando" @click="confirmarCierre">
            {{ guardando ? 'Cerrando…' : 'Cerrar mostrador' }}
          </button>
        </div>
      </div>
    </div>

    </template>

    <!-- ── Contar un producto sin cerrar el turno ─────────────────────────────── -->
    <div v-if="conteo" class="mst__modal-back" @click.self="conteo = null">
      <div class="mst__modal">
        <h3 class="mst__modal-title">Contar {{ conteo.item.etiqueta }}</h3>
        <p class="mst__modal-sub">
          Pesá lo que hay y escribilo. Recién ahí te muestro lo que tendría que haber —
          si lo vieras antes, escribirías ese número.
        </p>
        <input v-model.number="conteo.contado" type="number" min="0" step="0.1"
               class="mst__input" placeholder="Cuento" aria-label="Contado" />
        <template v-if="difConteo !== null">
          <p class="mst__caja-fila mst__caja-fila--total">
            <span>Tendría que haber</span><b>{{ fmt(conteo.item.esperado) }} {{ conteo.item.unidad }}</b>
          </p>
          <p class="mst__dif-caja" :class="difConteo === 0 ? 'is-ok' : 'is-mal'">
            {{ difConteo === 0 ? 'Cuadra'
               : `${difConteo > 0 ? 'Sobran' : 'Faltan'} ${fmt(Math.abs(difConteo))} ${conteo.item.unidad}` }}
          </p>
        </template>
        <label v-if="difConteo" class="mst__campo mst__campo--motivo">
          <span class="mst__campo-lbl">Qué pasó</span>
          <input v-model="conteo.motivo" type="text" class="mst__input" placeholder="Ej: se cayó al piso" />
        </label>
        <div class="mst__modal-acc">
          <button class="mst__btn mst__btn--ghost" @click="conteo = null">Cancelar</button>
          <button class="mst__btn mst__btn--primary" :disabled="guardando || difConteo === null"
                  @click="confirmarConteo">Registrar</button>
        </div>
      </div>
    </div>

    <!-- ── Poner o sacar plata del cajón, con el turno andando ────────────────── -->
    <div v-if="plata" class="mst__modal-back" @click.self="plata = null">
      <div class="mst__modal">
        <h3 class="mst__modal-title">{{ plata.tipo === 'ingreso' ? 'Poner plata en el cajón' : 'Sacar plata del cajón' }}</h3>
        <p class="mst__modal-sub">
          {{ plata.tipo === 'ingreso'
             ? 'Cambio, reponer el fondo, o lo que se cobró por fuera. No cuenta como ingreso del club: esa plata ya era suya.'
             : 'Un gasto pagado con la caja baja el resultado; un retiro no, pero queda a nombre de alguien.' }}
        </p>
        <input v-model.number="plata.monto" type="number" min="0" step="100" class="mst__input"
               placeholder="Monto" aria-label="Monto" />
        <input v-model="plata.motivo" type="text" class="mst__input"
               :placeholder="plata.tipo === 'ingreso' ? 'De dónde sale' : 'Para qué se saca'" />
        <select v-if="plata.tipo === 'salida'" v-model="plata.clase" class="mst__select">
          <option value="retiro">Retiro — sigue siendo del club</option>
          <option value="gasto">Gasto — el club gastó esa plata</option>
        </select>
        <div class="mst__modal-acc">
          <button class="mst__btn mst__btn--ghost" @click="plata = null">Cancelar</button>
          <button class="mst__btn mst__btn--primary" :disabled="guardando || !plata.monto || !plata.motivo"
                  @click="confirmarPlata">Confirmar</button>
        </div>
      </div>
    </div>

    <!-- ── Reponer / devolver un producto que ya está en el turno ─────────────── -->
    <div v-if="mover" class="mst__modal-back" @click.self="mover = null">
      <div class="mst__modal">
        <h3 class="mst__modal-title">
          {{ mover.tipo === 'carga' ? 'Reponer' : 'Devolver al depósito' }} — {{ mover.item.etiqueta }}
        </h3>
        <p class="mst__modal-sub">
          {{ mover.tipo === 'carga'
             ? `Hay ${fmt(mover.item.en_deposito)} ${mover.item.unidad} libres en el depósito.`
             : `Hay ${fmt(mover.item.esperado)} ${mover.item.unidad} sobre la mesa.` }}
        </p>
        <input v-model.number="mover.cantidad" type="number" min="0" step="0.1"
               class="mst__input" placeholder="Cantidad" aria-label="Cantidad" />
        <div class="mst__modal-acc">
          <button class="mst__btn mst__btn--ghost" @click="mover = null">Cancelar</button>
          <button class="mst__btn mst__btn--primary" :disabled="guardando || !mover.cantidad" @click="confirmarMover">
            Confirmar
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
// El MOSTRADOR: la mercadería que está sobre la mesa hoy.
//
// Para una organización que sólo dispensa, es LA pantalla — se abre a la mañana, se opera todo
// el día y se cierra a la noche. Por eso el estado va arriba y grande, y las tres columnas
// (en la mesa / salió / en depósito) contestan la única pregunta que se hace el que la mira:
// ¿alcanza hasta que cierre, o hay que bajar más?
//
// NADA DE ESTO ES PARA SEÑALAR A NADIE. La merma existe y es inevitable: contar sirve para que
// la organización sepa cuánta hay y dónde, y con eso encuentre sus cuellos de botella. El texto
// de la pantalla tiene que sonar así — una diferencia es un dato que se anota, no una falta que
// alguien tiene que explicar.
//
// Lo que se carga se APARTA, no se descuenta: la fila Stock sigue siendo una sola. Ver
// `Mostradores::AbrirTurno` en el backend.
import { ref, computed, watch, onMounted } from 'vue'
import { X, Undo2 } from 'lucide-vue-next'
import RendicionCajaCard from '../components/RendicionCajaCard.vue'
import MostradorMerma from '../components/mostrador/MostradorMerma.vue'
import MostradorTurnos from '../components/mostrador/MostradorTurnos.vue'
import { getMostrador, abrirMostrador, confirmarMostrador, cargarMostrador, devolverMostrador,
         cerrarMostrador, ingresoCajaMostrador, salidaCajaMostrador,
         contarMostrador } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'
import { useSedeStore } from '../stores/sede.js'
import { useStockChannel } from '../composables/useStockChannel.js'
import { useToast } from '../composables/useToast.js'

const sedeStore = useSedeStore()
const auth      = useAuthStore()
const toast     = useToast()

// La merma es información de GESTIÓN: el que atiende no la ve. No porque haya algo que
// esconderle, sino porque no es una pantalla para él — decide con lo que tiene sobre la mesa.
const gestiona = computed(() => ['admin', 'supervisor', 'super_admin'].includes(auth.user?.role))

const sedeId    = ref(null)
const cargando  = ref(true)
const guardando = ref(false)
const error     = ref('')
const turno     = ref(null)
const sugerido  = ref([])
const disponibles = ref([])
const borrador  = ref([])
const fondo     = ref(0)
const aAgregar  = ref('')
// Cuánto de eso baja a la mesa. Va acá y no en la fila de abajo: elegir el producto y decir
// cuánto es UN gesto, y separarlos escondía la mitad.
const cantAAgregar = ref(null)
const mover     = ref(null)
const cierre    = ref(null)
const fondoSugerido = ref(null)
const recepcion = ref([])
const motivoRecepcion = ref('')
const efectivoRecepcion = ref(null)
const motivoEfectivo = ref('')
const plata = ref(null)
const conteo     = ref(null)
// Mismo criterio que el cierre: lo esperado no se muestra hasta que el conteo está escrito.
const difConteo  = computed(() => {
  const c = conteo.value
  if (!c || c.contado === null || c.contado === '') return null
  return Math.round((Number(c.contado) - c.item.esperado) * 1000) / 1000
})
const tab       = ref('hoy')
// Viene con la carga principal: un aviso que sólo aparece cuando ya entraste a mirarlo no avisa.
const sinRevisar = ref(0)

// Tres momentos, no dos: cerrado · abierto pero sin recibir · andando. El del medio existe
// porque cuando lo carga el admin hay una entrega, y hasta que el que atiende no la firma nadie
// puede responder por lo que hay sobre la mesa.
const ESTADO_LABEL = { cerrado: 'Cerrado', sin_recibir: 'Falta recibirlo', abierto: 'Abierto' }

// Sólo las sedes que dispensan tienen mostrador: una de producción no atiende pacientes.
const sedes    = computed(() => (sedeStore.sedes || []).filter(s => s.tipo === 'social' || s.tipo === 'mixta'))
const abierto  = computed(() => !!turno.value)
const estado   = computed(() =>
  !turno.value ? 'cerrado' : (turno.value.confirmado ? 'abierto' : 'sin_recibir')
)
// Quien cargó la mesa no se la recibe a sí mismo: serían dos firmas de la misma persona, o sea
// ninguna. Ve lo que dejó, y espera.
// Los dos ids tienen que EXISTIR: sin el guard, `undefined === undefined` da true y todo el
// mundo vería la pantalla de espera — nadie podría recibir la mesa nunca.
const loCargueYo = computed(() => {
  const yo = auth.user?.id
  const quien = turno.value?.abierto_por_id
  return !!turno.value && !turno.value.confirmado && !!yo && !!quien && yo === quien
})
// Se cerró algo antes: sin eso, hablar de "corregir el cierre anterior" no significa nada.
const huboTurnoAnterior = computed(() => sugerido.value.length > 0 || fondoSugerido.value !== null)
// Sacar un producto de la mesa también es corregir lo que declaró el admin, y también pide
// motivo: es la diferencia más grande que puede haber.
const hayCorreccion = computed(() =>
  recepcion.value.some(r => r.quitar ||
    (r.contado !== null && r.contado !== '' && Number(r.contado) !== r.esperado))
)
// Lo que falta o sobra en el cajón al recibirlo. A diferencia del stock —donde lo que el admin
// declaró de más sigue en el depósito— acá la plata que falta no está en ningún lado.
const difRecepcion = computed(() => {
  if (!turno.value?.caja || efectivoRecepcion.value === null || efectivoRecepcion.value === '') return null
  return Math.round((Number(efectivoRecepcion.value) - turno.value.caja.esperado_ars) * 100) / 100
})

const stockAAgregar = computed(() => disponibles.value.find(s => s.stock_id === aAgregar.value) || null)
const unidadAAgregar = computed(() => stockAAgregar.value?.unidad || '')
// No se puede bajar lo que no está. El backend lo rechaza igual, pero decirlo acá evita llenar
// el formulario entero para que rebote al final.
const excedeDisponible = computed(() => {
  const s = stockAAgregar.value
  if (!s || !(cantAAgregar.value > 0)) return null
  return Number(cantAAgregar.value) > Number(s.disponible) ? s : null
})

// Lo que todavía no está en la lista: no tiene sentido ofrecer dos veces el mismo frasco.
const agregables = computed(() => {
  const puestos = new Set(
    abierto.value ? turno.value.items.map(i => i.stock_id) : borrador.value.map(i => i.stock_id)
  )
  return disponibles.value.filter(s => !puestos.has(s.stock_id))
})

// Hay diferencia si algún conteo no coincide con lo esperado. El motivo se pide una sola vez
// para todo el cierre: es la misma explicación ("hoy la balanza redondeó") repetida por ítem.
const hayDiferencia = computed(() =>
  !!cierre.value?.conteos.some(c => c.contado !== null && c.contado !== '' && Number(c.contado) !== c.esperado)
)
const difCaja = computed(() => {
  const c = cierre.value
  if (!c || c.efectivo === null || c.efectivo === '') return null
  return Math.round((Number(c.efectivo) - (turno.value?.caja?.esperado_ars ?? 0)) * 100) / 100
})
const aRetirar = computed(() => {
  const c = cierre.value
  if (!c) return 0
  return Math.max(Number(c.efectivo || 0) - Number(c.fondo || 0), 0)
})

const fmt  = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const hora = (iso) => (iso ? new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) : '')

// Cada carga lleva número. Con el tiempo real, una tanda de cambios dispara varias recargas y
// nada garantiza que lleguen en orden: si la respuesta vieja aterriza última, la pantalla vuelve
// a un estado anterior — se ve como si la corrección no se hubiera guardado.
let cargaEnCurso = 0

async function cargar () {
  if (!sedeId.value) { cargando.value = false; return }
  const mia = ++cargaEnCurso
  cargando.value = true
  error.value = ''
  try {
    const { data } = await getMostrador(sedeId.value)
    if (mia !== cargaEnCurso) return // llegó tarde: ya hay una carga más nueva

    turno.value       = data.turno
    sugerido.value    = data.sugerido || []
    disponibles.value = data.disponibles || []
    fondoSugerido.value = data.fondo_sugerido ?? null
    sinRevisar.value = data.sin_revisar ?? 0
    // La recepción arranca con lo que declaró el admin: confirmar es un click, corregir es
    // cambiar el número. Vacío obligaría a recontar todo aunque esté bien.
    recepcion.value = (turno.value && !turno.value.confirmado)
      ? turno.value.items.map(it => ({
          item_id: it.id, etiqueta: it.etiqueta, unidad: it.unidad,
          esperado: it.esperado, contado: it.esperado, quitar: false,
        }))
      : []
    motivoRecepcion.value = ''
    motivoEfectivo.value = ''
    efectivoRecepcion.value = (turno.value && !turno.value.confirmado)
      ? (turno.value.caja?.esperado_ars ?? null) : null
    if (!turno.value && fondo.value === 0 && data.fondo_sugerido != null) fondo.value = data.fondo_sugerido
    // El borrador arranca con lo que dejó el cierre anterior, editable. No es un conteo
    // obligatorio: es un número que viene puesto y que se corrige sólo si no coincide.
    if (!turno.value) borrador.value = sugerido.value.map(s => ({ ...s }))
  } catch (e) {
    if (mia === cargaEnCurso) error.value = e?.response?.data?.error || 'No se pudo cargar el mostrador.'
  } finally {
    if (mia === cargaEnCurso) cargando.value = false
  }
}

function agregarAlBorrador () {
  const s = disponibles.value.find(x => x.stock_id === aAgregar.value)
  if (!s || !(cantAAgregar.value > 0) || excedeDisponible.value) return

  borrador.value.push({ ...s, cantidad: cantAAgregar.value })
  aAgregar.value = ''
  cantAAgregar.value = null
}

async function abrir () {
  const items = borrador.value
    .filter(i => Number(i.cantidad) > 0)
    .map(i => ({ stock_id: i.stock_id, cantidad: i.cantidad }))
  if (!items.length) return toast.error('Poné al menos un producto sobre la mesa.')

  guardando.value = true
  try {
    await abrirMostrador(sedeId.value, { monto_inicial_ars: fondo.value || 0, items })
    toast.success('Mostrador abierto')
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo abrir el mostrador.')
  } finally {
    guardando.value = false
  }
}

function abrirMover (item, tipo) {
  mover.value = { item, tipo, cantidad: null }
}

async function confirmarMover () {
  const { item, tipo, cantidad } = mover.value
  guardando.value = true
  try {
    if (tipo === 'carga') await cargarMostrador(sedeId.value, { stock_id: item.stock_id, cantidad })
    else                  await devolverMostrador(sedeId.value, { item_id: item.id, cantidad })
    mover.value = null
    toast.success(tipo === 'carga' ? 'Repuesto' : 'Devuelto al depósito')
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo mover el stock.')
  } finally {
    guardando.value = false
  }
}

// ¿Ya escribió el conteo de este producto? Hasta que no lo escriba, no se le muestra contra qué.
const contado = (c) => c.contado !== null && c.contado !== ''

function difTexto (c) {
  if (c.contado === null || c.contado === '') return ''
  const d = Math.round((Number(c.contado) - c.esperado) * 1000) / 1000
  if (d === 0) return 'cuadra'
  return `${d > 0 ? '+' : ''}${fmt(d)} ${c.unidad}`
}
// Una diferencia NO es un error: la merma es inevitable y el punto de contar es medirla. Se
// destaca para que se vea, sin el rojo de "algo salió mal".
function difClase (c) {
  if (c.contado === null || c.contado === '') return ''
  return Number(c.contado) === c.esperado ? 'is-ok' : 'is-dif'
}

async function confirmar () {
  if (hayCorreccion.value && !motivoRecepcion.value.trim()) {
    return toast.error('Escribí el motivo de la diferencia.')
  }
  if (difRecepcion.value && !motivoEfectivo.value.trim()) {
    return toast.error('Escribí el motivo de la diferencia en caja.')
  }
  guardando.value = true
  try {
    const correcciones = recepcion.value
      .filter(r => r.quitar || Number(r.contado) !== r.esperado)
      .map(r => ({
        item_id: r.item_id, motivo: motivoRecepcion.value,
        ...(r.quitar ? { quitar: true } : { contado: r.contado }),
      }))
    await confirmarMostrador(sedeId.value, {
      correcciones,
      efectivo_contado_ars: efectivoRecepcion.value,
      motivo_efectivo: motivoEfectivo.value || undefined,
    })
    toast.success(correcciones.length ? 'Recibido con corrección' : 'Mostrador recibido')
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo confirmar el mostrador.')
  } finally {
    guardando.value = false
  }
}

function abrirConteo (item) {
  conteo.value = { item, contado: null, motivo: '' }
}

async function confirmarConteo () {
  const c = conteo.value
  if (difConteo.value && !c.motivo.trim()) return toast.error('Escribí qué pasó.')

  guardando.value = true
  try {
    await contarMostrador(sedeId.value, {
      item_id: c.item.id, contado: c.contado, motivo: c.motivo || undefined,
    })
    conteo.value = null
    toast.success(difConteo.value ? 'Diferencia registrada' : 'Cuadra')
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo registrar el conteo.')
  } finally { guardando.value = false }
}

function abrirPlata (tipo) {
  plata.value = { tipo, monto: null, motivo: '', clase: 'retiro' }
}

async function confirmarPlata () {
  const { tipo, monto, motivo, clase } = plata.value
  const cajaId = turno.value?.caja?.id
  if (!cajaId) return
  guardando.value = true
  try {
    if (tipo === 'ingreso') await ingresoCajaMostrador(sedeId.value, cajaId, { monto_ars: monto, motivo })
    else                    await salidaCajaMostrador(sedeId.value, cajaId, { monto_ars: monto, motivo, clase })
    plata.value = null
    toast.success(tipo === 'ingreso' ? 'Plata puesta en el cajón' : 'Plata sacada del cajón')
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo mover la plata.')
  } finally {
    guardando.value = false
  }
}

function abrirCierre () {
  cierre.value = {
    motivo: '',
    // El efectivo y el fondo arrancan VACÍOS a propósito: son un conteo, no un número que se
    // acepta apretando enter.
    efectivo: null,
    fondo: null,
    conteos: turno.value.items.map(it => ({
      item_id: it.id, etiqueta: it.etiqueta, unidad: it.unidad, esperado: it.esperado, contado: null,
    })),
  }
}

async function confirmarCierre () {
  const c = cierre.value
  if (c.conteos.some(x => x.contado === null || x.contado === '')) {
    return toast.error('Contá todo lo que está sobre la mesa.')
  }
  if (hayDiferencia.value && !c.motivo.trim()) {
    return toast.error('Escribí el motivo de la diferencia.')
  }

  guardando.value = true
  try {
    await cerrarMostrador(sedeId.value, {
      conteos: c.conteos.map(x => ({ item_id: x.item_id, contado: x.contado, motivo: c.motivo || undefined })),
      efectivo_contado_ars: c.efectivo,
      fondo_siguiente_ars:  c.fondo,
      notas: c.motivo || undefined,
    })
    cierre.value = null
    toast.success('Mostrador cerrado')
    await cargar()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo cerrar el mostrador.')
  } finally {
    guardando.value = false
  }
}

async function bajarNuevo () {
  const s = disponibles.value.find(x => x.stock_id === aAgregar.value)
  if (!s) return
  aAgregar.value = ''
  mover.value = { item: { ...s, id: null, esperado: 0, en_deposito: s.disponible }, tipo: 'carga', cantidad: null }
}

onMounted(async () => {
  if (!sedeStore.loaded) await sedeStore.fetchSedes()
  // No se llama a `cargar()` acá: fijar la sede dispara el watcher de abajo, que carga. Hacer
  // las dos cosas mandaba DOS pedidos por cada apertura de la pantalla.
  sedeId.value = sedes.value[0]?.id ?? null
})

// La mesa se actualiza sola. Si el admin baja producto desde su oficina, el que atiende lo ve
// sin recargar: recargar es justo lo que nadie hace cuando tiene a alguien esperando enfrente.
// Sólo si el aviso es de ESTA sede — con dos sedes abiertas, recargar por la otra es ruido.
// Y se agrupan: cargar la mesa emite un aviso por producto, y recargar una vez por cada uno
// sería mandar cinco requests para pintar la misma pantalla.
let recargaPendiente = null
useStockChannel(null, (evento) => {
  if (evento?.tipo !== 'mostrador_actualizado') return
  if (evento.sede_id && evento.sede_id !== sedeId.value) return

  clearTimeout(recargaPendiente)
  recargaPendiente = setTimeout(cargar, 300)
})

// Cambiar de sede recarga: si no, se veía el mostrador de la sede anterior. Las otras solapas
// son componentes y miran `sedeId` por su cuenta.
watch(sedeId, cargar, { immediate: true })
</script>

<style scoped>
.mst { padding: 20px 24px 48px; max-width: 1100px; }

/* ── Solapas ────────────────────────────────────────────────────────────────── */
.mst__tabs { display: flex; gap: 4px; margin-bottom: 18px; border-bottom: 1px solid var(--c-slate-200); }
.mst__tab {
  border: 0; background: transparent; cursor: pointer;
  padding: 9px 15px; margin-bottom: -1px;
  font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-500);
  border-bottom: 2px solid transparent;
  display: inline-flex; align-items: center; gap: 7px;
}
.mst__tab:hover  { color: var(--c-ink-900); }
.mst__tab.is-on  { color: var(--c-leaf-800); border-bottom-color: var(--c-leaf-800); }
.mst__tab-badge {
  background: var(--c-amber-100); color: var(--c-amber-500);
  border-radius: 999px; padding: 1px 7px; font-size: var(--fs-12);
}

/* ── Encabezado ─────────────────────────────────────────────────────────────── */
.mst__head {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 16px; flex-wrap: wrap; margin-bottom: 20px;
}
.mst__title {
  font-family: var(--font-display); font-size: var(--fs-28, 28px); font-weight: 700;
  color: var(--c-leaf-900); margin: 0; letter-spacing: -.02em;
}
.mst__sub { margin: 4px 0 0; font-size: var(--fs-14); color: var(--c-ink-500); }
.mst__head-left  { min-width: 0; }
.mst__head-right { display: flex; align-items: center; gap: 10px; flex-shrink: 0; }

.mst__estado {
  display: inline-flex; align-items: center; gap: 7px;
  padding: 7px 14px; border-radius: 999px;
  font-size: var(--fs-13); font-weight: 600;
}
.mst__estado-dot { width: 8px; height: 8px; border-radius: 50%; background: currentColor; }
.mst__estado.is-abierto     { background: var(--c-leaf-100);  color: var(--c-leaf-700); }
.mst__estado.is-cerrado     { background: var(--c-ink-100);   color: var(--c-ink-500); }
/* Cargado por el admin y esperando que lo reciba el que atiende: ni una cosa ni la otra. */
.mst__estado.is-sin_recibir { background: var(--c-amber-100); color: var(--c-amber-500); }

/* ── Tarjeta de apertura ────────────────────────────────────────────────────── */
.mst__card {
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px;
  padding: 22px; display: flex; flex-direction: column; gap: 18px;
}
.mst__card-head { border-bottom: 1px solid var(--c-slate-100); padding-bottom: 14px; }
.mst__card-title {
  font-family: var(--font-display); font-size: var(--fs-18); font-weight: 700;
  color: var(--c-leaf-900); margin: 0;
}
.mst__card-sub { margin: 4px 0 0; font-size: var(--fs-13); color: var(--c-ink-500); }

.mst__fondo { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
.mst__fondo-lbl { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.mst__fondo-input { display: inline-flex; align-items: center; gap: 6px; }
.mst__fondo-signo { font-size: var(--fs-16); color: var(--c-ink-500); }

.mst__input {
  border: 1px solid var(--c-slate-300); border-radius: 9px; padding: 9px 11px;
  font-size: var(--fs-14); font-family: var(--font-mono); width: 100%;
  background: #fff; color: var(--c-ink-900);
}
.mst__input:focus { outline: 2px solid var(--c-leaf-300); outline-offset: 1px; border-color: var(--c-leaf-500); }
.mst__input--fondo { width: 150px; text-align: right; }
.mst__input--cant  { width: 96px;  text-align: right; }

.mst__select {
  border: 1px solid var(--c-slate-300); border-radius: 9px; padding: 9px 11px;
  font-size: var(--fs-14); background: #fff; color: var(--c-ink-900); max-width: 100%;
}
.mst__select--sede { min-width: 160px; }

/* ── Borrador de apertura ───────────────────────────────────────────────────── */
.mst__draft { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; }
.mst__draft-row {
  display: flex; align-items: center; gap: 12px;
  padding: 12px 0; border-top: 1px solid var(--c-slate-100);
}
.mst__draft-prod { flex: 1; min-width: 0; }
.mst__draft-nombre { display: block; font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.mst__draft-meta   { display: block; font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }
.mst__draft-cant   { display: inline-flex; align-items: baseline; gap: 6px; }
.mst__draft-unidad { font-size: var(--fs-13); color: var(--c-ink-500); width: 22px; }

.mst__icon-btn {
  border: 0; background: transparent; color: var(--c-ink-500); cursor: pointer;
  padding: 6px; border-radius: 7px; display: inline-flex;
}
.mst__icon-btn:hover { background: var(--c-ink-100); color: var(--c-rust-600); }

.mst__vacio { margin: 0; font-size: var(--fs-14); color: var(--c-ink-500); }
.mst__seccion-sub { margin: 0 0 12px; font-size: var(--fs-13); color: var(--c-ink-500); max-width: 60ch; }
.mst__pie   { margin: 0; font-size: var(--fs-12); color: var(--c-ink-500); }
/* El renglón que se va de la mesa: se ve tachado antes de confirmar, para poder arrepentirse. */
.mst__draft-row.is-quitado .mst__draft-nombre { text-decoration: line-through; color: var(--c-ink-500); }
.mst__agregar { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
.mst__agregar .mst__select { flex: 1; min-width: 220px; }
.mst__agregar-cant { display: inline-flex; align-items: baseline; gap: 6px; }

/* ── Turno abierto ──────────────────────────────────────────────────────────── */
/* El turno y su acción, en una línea: el botón suelto debajo del nombre parecía de otra cosa. */
.mst__turno {
  display: flex; align-items: center; justify-content: space-between;
  gap: 12px; flex-wrap: wrap; margin-bottom: 14px;
}
.mst__turno-info { display: flex; align-items: baseline; gap: 8px; flex-wrap: wrap; }
.mst__turno-quien { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.mst__turno-desde { font-size: var(--fs-13); color: var(--c-ink-500); }
.mst__turno-acc   { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
/* En gramos no se compara con nada; en plata se ve de un vistazo cuánto hay ahí arriba. */
.mst__valor-mesa  { font-size: var(--fs-13); color: var(--c-ink-500); font-family: var(--font-mono); }

.mst__table-wrap {
  background: #fff; border: 1px solid var(--c-slate-200);
  border-radius: 14px; overflow-x: auto;
}
.mst__table { width: 100%; border-collapse: collapse; }
.mst__table th {
  text-align: left; font-size: var(--fs-12); font-weight: 600; text-transform: uppercase;
  letter-spacing: .04em; color: var(--c-ink-500);
  padding: 13px 16px; border-bottom: 1px solid var(--c-slate-200); white-space: nowrap;
}
.mst__table td { padding: 14px 16px; border-bottom: 1px solid var(--c-slate-100); vertical-align: middle; }
.mst__table tbody tr:last-child td { border-bottom: 0; }
.mst__table tbody tr.is-alerta { background: var(--c-rust-100); }

.mst__th-num, .mst__td-num { text-align: right; }
.mst__th-acc, .mst__td-acc { text-align: right; white-space: nowrap; }
.mst__td-mut { color: var(--c-ink-500); font-size: var(--fs-13); font-family: var(--font-mono); }

.mst__prod { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.mst__prod-meta { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 5px; }

/* El número que se lee de un vistazo: es la única pregunta del que atiende. */
.mst__mesa {
  font-family: var(--font-mono); font-size: var(--fs-18);
  font-weight: 700; color: var(--c-leaf-800);
}
.mst__unidad { font-size: var(--fs-12); color: var(--c-ink-500); margin-left: 3px; }

.mst__pill {
  display: inline-block; padding: 2px 8px; border-radius: 999px;
  font-size: var(--fs-12); font-weight: 600;
}
.mst__pill--warn   { background: var(--c-amber-100); color: var(--c-amber-500); }
.mst__pill--danger { background: var(--c-rust-100);  color: var(--c-rust-600); }
.mst__pill--info   { background: var(--c-sky-100);   color: var(--c-sky-600); }

/* ── Barra de caja del turno ────────────────────────────────────────────────── */
.mst__caja-barra {
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
  margin-top: 14px; padding: 12px 16px;
  background: var(--c-leaf-50); border-radius: 11px;
}
.mst__caja-barra-lbl { flex: 1; font-size: var(--fs-13); color: var(--c-ink-700); }
.mst__caja-barra-lbl b { font-family: var(--font-mono); color: var(--c-ink-900); }

/* ── Botones ────────────────────────────────────────────────────────────────── */
.mst__acciones { display: flex; gap: 10px; justify-content: flex-end; flex-wrap: wrap; }
.mst__acciones--turno { margin-top: 14px; justify-content: space-between; }
.mst__acciones--turno .mst__select { flex: 1; min-width: 220px; }

.mst__btn {
  border-radius: 9px; padding: 10px 18px; font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; border: 1px solid transparent; transition: background .12s, border-color .12s;
}
.mst__btn:disabled { opacity: .5; cursor: not-allowed; }
.mst__btn--primary { background: var(--c-leaf-800); color: #fff; }
.mst__btn--primary:not(:disabled):hover { background: var(--c-leaf-900); }
.mst__btn--ghost   { background: #fff; color: var(--c-ink-700); border-color: var(--c-slate-300); }
.mst__btn--ghost:not(:disabled):hover { background: var(--c-slate-50); }
/* La excepción, no la acción normal: corregir un conteo cerrado ajusta el inventario. */
.mst__btn--corregir { margin-left: 6px; }
.mst__btn--mini    { padding: 6px 12px; font-size: var(--fs-13); background: var(--c-leaf-100); color: var(--c-leaf-800); }
.mst__btn--mini.mst__btn--ghost { background: #fff; color: var(--c-ink-700); }

/* ── Avisos y esqueleto ─────────────────────────────────────────────────────── */
.mst__aviso { margin: 8px 0 0; padding: 10px 14px; border-radius: 9px; font-size: var(--fs-13); }
.mst__aviso--warn  { background: var(--c-amber-100); color: var(--c-amber-500); }
.mst__aviso--error { background: var(--c-rust-100);  color: var(--c-rust-600); }

.mst__skel-wrap { display: flex; flex-direction: column; gap: 10px; }
.mst__skel {
  height: 64px; border-radius: 12px;
  background: linear-gradient(90deg, var(--c-slate-100) 25%, var(--c-slate-50) 50%, var(--c-slate-100) 75%);
  background-size: 200% 100%; animation: mst-shimmer 1.4s infinite;
}
@keyframes mst-shimmer { from { background-position: 200% 0; } to { background-position: -200% 0; } }

/* ── Modal de reponer / devolver ────────────────────────────────────────────── */
.mst__modal-back {
  position: fixed; inset: 0; background: rgba(15, 42, 30, .45);
  display: flex; align-items: center; justify-content: center; padding: 20px; z-index: 1000;
}
.mst__modal {
  background: #fff; border-radius: 14px; padding: 24px;
  width: 100%; max-width: 400px; display: flex; flex-direction: column; gap: 14px;
}
.mst__modal-title {
  font-family: var(--font-display); font-size: var(--fs-16); font-weight: 700;
  color: var(--c-leaf-900); margin: 0;
}
.mst__modal-sub { margin: 0; font-size: var(--fs-13); color: var(--c-ink-500); }
.mst__modal-acc { display: flex; gap: 10px; justify-content: flex-end; }
.mst__modal--ancho { max-width: 560px; max-height: 88vh; overflow-y: auto; }

/* ── Conteo del cierre ──────────────────────────────────────────────────────── */
.mst__conteo { display: flex; flex-direction: column; }
.mst__conteo-row {
  display: flex; align-items: center; gap: 12px;
  padding: 11px 0; border-top: 1px solid var(--c-slate-100);
}
.mst__conteo-prod { flex: 1; min-width: 0; }
.mst__conteo-cant { display: inline-flex; align-items: baseline; gap: 6px; }

.mst__dif {
  font-family: var(--font-mono); font-size: var(--fs-13);
  min-width: 74px; text-align: right;
}
.mst__dif.is-ok  { color: var(--c-leaf-600); }
.mst__dif.is-dif { color: var(--c-amber-500); font-weight: 600; }

.mst__campo { display: flex; flex-direction: column; gap: 5px; }
.mst__campo-lbl { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); }
/* El monto es un número corto: a lo ancho de la tarjeta parece un campo de texto libre. */
.mst__campo--fila { flex-direction: row; align-items: center; justify-content: space-between; }
/* El motivo aparece sólo cuando hay diferencia. Se destaca porque hay que completarlo, no
   porque haya pasado algo malo. */
.mst__campo--motivo .mst__campo-lbl { color: var(--c-amber-500); }

/* ── El arqueo de plata, dentro del mismo cierre ────────────────────────────── */
.mst__caja {
  display: flex; flex-direction: column; gap: 11px;
  background: var(--c-leaf-50); border-radius: 11px; padding: 15px;
}
.mst__caja-fila {
  display: flex; justify-content: space-between; align-items: baseline;
  font-size: var(--fs-13); color: var(--c-ink-700);
}
.mst__caja-fila b { font-family: var(--font-mono); color: var(--c-ink-900); }
.mst__caja-fila--total {
  border-top: 1px solid var(--c-leaf-300); padding-top: 9px;
  font-weight: 600; color: var(--c-ink-900);
}
.mst__dif-caja { margin: 0; font-size: var(--fs-13); font-weight: 600; font-family: var(--font-mono); }
.mst__dif-caja.is-ok  { color: var(--c-leaf-600); }
.mst__dif-caja.is-mal { color: var(--c-amber-500); }
.mst__retiro { margin: 0; font-size: var(--fs-13); color: var(--c-ink-700); }

.mst__fondo-hint {
  display: block; font-style: normal; font-weight: 400;
  font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px;
}

@media (max-width: 640px) {
  .mst { padding: 16px 14px 40px; }
  .mst__draft-row { flex-wrap: wrap; }
  .mst__acciones--turno { flex-direction: column; align-items: stretch; }
}
</style>
