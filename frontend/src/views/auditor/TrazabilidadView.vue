<template>
  <div class="trz">

    <!-- Header + búsqueda -->
    <div class="trz__top">
      <div class="trz__top-left">
        <h1 class="trz__title"><i class="bi bi-diagram-3-fill"></i> Trazabilidad legal</h1>
        <p class="trz__sub">Un frasco, de la planta al paciente, con la cuenta cerrada: de qué salió, qué recibió, a quién fue y qué falta por explicar.</p>
      </div>
      <div class="trz__top-right">
        <div class="trz__search-wrap">
          <i class="bi bi-search trz__search-ico"></i>
          <input
            ref="inputRef"
            v-model="query"
            class="trz__search-input"
            placeholder="N.° lote, ID o código QR…"
            autocomplete="off"
            @input="onInput"
            @keyup.enter="buscarDesdeInput"
            @keydown.esc="cerrarAuto"
            @focus="autoVisible = true"
            @blur="onBlur"
          />
          <button class="trz__search-btn" :disabled="!query.trim() || loading" @click="buscarDesdeInput">
            <DsSpinner v-if="loading" :size="14" />
            <i v-else class="bi bi-arrow-right"></i>
          </button>

          <!-- Autocomplete -->
          <div v-if="autoVisible && sugerencias.length" class="trz__autocomplete">
            <button
              v-for="s in sugerencias"
              :key="s.id"
              class="trz__auto-item"
              @mousedown.prevent="seleccionarStock(s)"
            >
              <span class="trz__auto-num">{{ s.numero_lote_producto || `#${s.id}` }}</span>
              <span class="trz__auto-meta">
                {{ FORMA_LABELS[s.forma_producto] || s.forma_producto }}
                <span v-if="s.cantidad_g" class="trz__auto-g">· {{ s.cantidad_g }} g</span>
              </span>
            </button>
          </div>
        </div>

        <button v-if="data?.stock" class="trz__btn-pdf" @click="exportPdf">
          <i class="bi bi-printer"></i> PDF
        </button>
        <button v-if="data" class="trz__btn-back" @click="volver">
          <i class="bi bi-arrow-left"></i> Volver
        </button>
      </div>
    </div>

    <!-- Error -->
    <div v-if="error" class="trz__alert">
      <i class="bi bi-exclamation-triangle-fill"></i> {{ error }}
    </div>

    <!-- Loading cadena -->
    <div v-if="loading" class="trz__loader">
      <DsSpinner />
      Cargando cadena de trazabilidad…
    </div>

    <!-- ESTADO: listado. Dos solapas —LOTES y FRASCOS— con los mismos filtros. La trazabilidad
         arranca también desde el lote (Germán, sep-2026): un lote en floración no tiene frasco
         todavía, y la pregunta del auditor puede empezar por la planta. -->
    <template v-else-if="!data">
      <div v-if="loadingList" class="trz__loader">
        <DsSpinner /> Cargando…
      </div>
      <template v-else>
        <div class="trz__tabs">
          <button class="trz__tab" :class="{ 'trz__tab--on': solapa === 'lotes' }" @click="solapa = 'lotes'">Lotes · {{ lotesFiltrados.length }}</button>
          <button class="trz__tab" :class="{ 'trz__tab--on': solapa === 'frascos' }" @click="solapa = 'frascos'">Frascos · {{ stocksFiltrados.length }}</button>
        </div>
        <div class="trz__filtros">
          <select v-model="filtro.estado" class="trz__filtro">
            <option value="">Todos los estados</option>
            <template v-if="solapa === 'lotes'">
              <option value="cultivo">En cultivo</option>
              <option value="cosechados">Cosechados (sin finalizar)</option>
              <option value="finalizado">Finalizados</option>
            </template>
            <template v-else>
              <option value="con_stock">Con producto</option>
              <option value="agotado">Agotados</option>
            </template>
          </select>
          <select v-model="filtro.sede" class="trz__filtro">
            <option value="">Todas las sedes</option>
            <option v-for="sd in sedesDeLista" :key="sd" :value="sd">{{ sd }}</option>
          </select>
          <select v-model="filtro.genetica" class="trz__filtro">
            <option value="">Todas las genéticas</option>
            <option v-for="g in geneticasDeLista" :key="g" :value="g">{{ g }}</option>
          </select>
          <label class="trz__filtro-fechas">
            <span>{{ solapa === 'lotes' ? 'Arrancó' : 'Elaborado' }} entre</span>
            <input v-model="filtro.desde" type="date" class="trz__filtro" />
            <span>y</span>
            <input v-model="filtro.hasta" type="date" class="trz__filtro" />
          </label>
          <button v-if="hayFiltros" class="trz__filtro-limpiar" @click="limpiarFiltros">Limpiar</button>
        </div>

        <div v-if="solapa === 'lotes'" class="trz__stocks-section">
          <div v-if="!lotesFiltrados.length" class="trz__empty-plain"><i class="bi bi-inbox"></i> Ningún lote con esos filtros.</div>
          <div v-else class="trz__table-wrap">
            <table class="trz__table">
              <thead>
                <tr><th>Lote</th><th>Genética</th><th>Sede</th><th>Estado</th><th>Arrancó</th><th class="trz__th-r">Plantas</th><th>Frascos</th><th></th></tr>
              </thead>
              <tbody>
                <tr v-for="l in lotesFiltrados" :key="l.id" class="trz__tr" @click="abrirLote(l.id)">
                  <td class="trz__td-code">{{ l.codigo }}</td>
                  <td class="trz__td-gen">{{ l.genetica?.nombre || '—' }}</td>
                  <td>{{ sedeDeLote(l) || '—' }}</td>
                  <td><span class="trz__estado-pill">{{ estadoLabel(l.estado) }}</span><span v-if="l.dias_en_estado != null" class="trz__dias"> · {{ l.dias_en_estado }} días</span></td>
                  <td class="trz__td-fecha">{{ formatDate(l.start_date) }}</td>
                  <td class="trz__td-g">{{ l.plants_count ?? '—' }}</td>
                  <td class="trz__td-lote">
                    <template v-if="frascosDeLote(l).length">{{ frascosDeLote(l).map(f => f.numero_lote_producto).join(' · ') }}</template>
                    <span v-else class="trz__muted">{{ ['finalizado'].includes(l.estado) ? '—' : 'todavía ninguno' }}</span>
                  </td>
                  <td class="trz__td-action"><span class="trz__td-ver">Ver cadena <i class="bi bi-arrow-right"></i></span></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div v-else class="trz__stocks-section">
          <div v-if="!stocksFiltrados.length" class="trz__empty-plain"><i class="bi bi-inbox"></i> Ningún frasco con esos filtros.</div>
          <div v-else class="trz__table-wrap">
            <table class="trz__table">
              <thead>
                <tr><th>N.° lote</th><th>Genética</th><th>Forma</th><th class="trz__th-r">Cantidad</th><th>Lote origen</th><th>Sede</th><th>Elaborado</th><th></th></tr>
              </thead>
              <tbody>
                <tr v-for="s in stocksFiltrados" :key="s.id" class="trz__tr" @click="seleccionarStock(s)">
                  <td class="trz__td-code">{{ s.numero_lote_producto || `#${s.id}` }}</td>
                  <td class="trz__td-gen">{{ s.genetica_nombre || s.genetica?.nombre || '—' }}</td>
                  <td><span class="trz__forma-badge">{{ FORMA_LABELS[s.forma_producto] || s.forma_producto }}</span></td>
                  <td class="trz__td-g">{{ s.cantidad ?? '—' }} {{ s.unidad || 'g' }}</td>
                  <!-- Un stock comprado afuera no tiene lote propio: tiene origen conocido, es externo. -->
                  <td class="trz__td-lote">
                    <span v-if="s.origen === 'compra_externa'" class="trz__externo">Externo</span>
                    <template v-else>{{ s.lote_codigo || s.lote?.codigo || '—' }}</template>
                    <span v-if="s.origen === 'derivado_lote'" class="trz__deriv" title="Elaborado a partir de ese lote">derivado</span>
                  </td>
                  <td>{{ s.sede?.nombre || '—' }}</td>
                  <td class="trz__td-fecha">{{ formatDate(s.fecha_elaboracion) }}</td>
                  <td class="trz__td-action"><span class="trz__td-ver">Ver cadena <i class="bi bi-arrow-right"></i></span></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </template>
    </template>

    <!-- ESTADO: cadena de custodia -->
    <div v-if="data" id="trz-report" class="trz__report">

      <!-- Banner -->
      <div class="trz__banner">
        <div>
          <div class="trz__banner-label">{{ data.stock ? 'Trazabilidad del frasco' : 'Trazabilidad del lote' }}</div>
          <div class="trz__banner-ref">{{ data.stock ? (data.stock.numero_lote_producto || `STOCK-${data.stock.id}`) : data.lote?.codigo }}</div>
        </div>
        <div class="trz__banner-date"><i class="bi bi-calendar3"></i> {{ hoy }}</div>
      </div>

      <!-- LA CUENTA. Es lo único del informe que un auditor comprueba con lápiz: entró tanto,
           salió tanto a pacientes, salió tanto por otro lado (CON NOMBRE: un traslado o un
           derivado son el mismo producto en otra fila, no una pérdida), queda tanto. Lo que
           ningún movimiento explica se llama así, y es lo que hay que ir a buscar. -->
      <div v-if="data.totales" class="trz__balance">
        <div class="trz__bal-item">
          <span class="trz__bal-lbl">Entró</span>
          <span class="trz__bal-val">{{ data.totales.gramos_producidos }} {{ unidad }}</span>
          <span v-if="data.totales.plantas_origen" class="trz__bal-pct">de {{ data.totales.plantas_origen }} plantas</span>
          <span v-else-if="data.stock.producido_desde" class="trz__bal-pct">de {{ data.stock.producido_desde.gramos }} g de {{ data.stock.producido_desde.numero }}</span>
          <span v-else-if="data.stock.proveedor" class="trz__bal-pct">comprado a {{ data.stock.proveedor }}</span>
        </div>
        <span class="trz__bal-op">−</span>
        <div class="trz__bal-item">
          <span class="trz__bal-lbl">A pacientes</span>
          <span class="trz__bal-val">{{ data.totales.gramos_dispensados }} {{ unidad }}</span>
          <span class="trz__bal-pct">{{ data.totales.dispensaciones_count }} entregas · {{ data.totales.pct_dispensado }}%</span>
        </div>
        <span class="trz__bal-op">−</span>
        <div class="trz__bal-item trz__bal-item--salidas">
          <span class="trz__bal-lbl">Salió por otro lado</span>
          <span class="trz__bal-val">{{ data.totales.otras_salidas_g }} {{ unidad }}</span>
          <ul v-if="data.salidas?.length" class="trz__bal-sub">
            <li v-for="m in data.salidas" :key="m.id" :class="{ 'trz__bal-sub--merma': m.tipo === 'merma' }">
              <span>{{ salidaLabel(m) }}</span>
              <span class="trz__bal-sub-g">{{ Math.abs(m.gramos) }} {{ unidad }}</span>
            </li>
          </ul>
        </div>
        <span class="trz__bal-op">=</span>
        <div class="trz__bal-item trz__bal-item--total">
          <span class="trz__bal-lbl">Queda</span>
          <span class="trz__bal-val">{{ data.totales.cantidad_disponible_g }} {{ unidad }}</span>
          <ul v-if="data.totales.en_mesa_g > 0" class="trz__bal-sub">
            <li><span>sobre la mesa</span><span class="trz__bal-sub-g">{{ data.totales.en_mesa_g }} {{ unidad }}</span></li>
            <li><span>en el depósito</span><span class="trz__bal-sub-g">{{ data.totales.en_deposito_g }} {{ unidad }}</span></li>
          </ul>
        </div>
        <div v-if="data.totales.sin_explicar_g" class="trz__bal-item trz__bal-item--alerta">
          <span class="trz__bal-lbl">Sin explicar</span>
          <span class="trz__bal-val">{{ data.totales.sin_explicar_g }} {{ unidad }}</span>
          <span class="trz__bal-pct">ningún movimiento lo explica</span>
        </div>
      </div>
      <!-- La cuenta en una oración: lo que se lee en voz alta delante del auditor. -->
      <p v-if="data.frase" class="trz__frase" :class="{ 'trz__frase--abierta': data.totales.sin_explicar_g }">{{ data.frase }}</p>

      <!-- Cadena -->
      <div class="trz__chain-divider">
        <span><i class="bi bi-link-45deg"></i> CADENA DE CUSTODIA</span>
      </div>

      <div class="trz__chain">

        <!-- Nodo 1: ORIGEN -->
        <div class="trz__node trz__node--origen">
          <div class="trz__node-head">
            <span class="trz__node-badge trz__node-badge--origen">🌱 {{ esExterno ? 'ORIGEN' : 'ORIGEN GENÉTICO' }}</span>
            <span class="trz__node-code">{{ origenLabel }}</span>
          </div>
          <div class="trz__node-body">
            <div class="trz__fields">
              <!-- Un producto comprado afuera no tiene lote: tiene proveedor. Ese es su origen. -->
              <div v-if="esExterno" class="trz__field">
                <span class="trz__field-lbl">Proveedor</span>
                <span class="trz__field-val">{{ data.stock.proveedor || 'No registrado' }}</span>
              </div>
              <div class="trz__field">
                <span class="trz__field-lbl">Genética</span>
                <span class="trz__field-val">{{ genetica?.nombre || 'No registrada' }}</span>
              </div>
              <div v-if="genetica?.thc || genetica?.cbd" class="trz__field">
                <span class="trz__field-lbl">Perfil declarado</span>
                <span class="trz__field-val">THC {{ genetica.thc || '—' }}% · CBD {{ genetica.cbd || '—' }}%</span>
              </div>
              <!-- Medido, no declarado: es lo más fuerte que se le puede mostrar a un paciente,
                   y va al lado del declarado porque es la misma pregunta. -->
              <div v-if="ultimoAnalisis" class="trz__field">
                <span class="trz__field-lbl">Perfil medido</span>
                <span class="trz__field-val">THC {{ ultimoAnalisis.thc_pct ?? '—' }}% · CBD {{ ultimoAnalisis.cbd_pct ?? '—' }}%<span v-if="ultimoAnalisis.laboratorio"> · {{ ultimoAnalisis.laboratorio }}</span><span v-if="ultimoAnalisis.fecha"> · {{ fecha(ultimoAnalisis.fecha) }}</span></span>
              </div>
              <div class="trz__field" v-if="data.lote?.genetica?.tipo">
                <span class="trz__field-lbl">Tipo</span>
                <span class="trz__field-val">{{ data.lote.genetica.tipo }}</span>
              </div>
              <div class="trz__field" v-if="data.lote?.genetica?.numero_registro_inase">
                <span class="trz__field-lbl">Reg. INASE</span>
                <span class="trz__field-val trz__field-inase">
                  <i class="bi bi-patch-check-fill"></i>
                  {{ data.lote.genetica.numero_registro_inase }}
                </span>
              </div>
            </div>
          </div>
        </div>

        <div v-if="data.lote" class="trz__arrow"><i class="bi bi-arrow-down"></i></div>

        <!-- Nodo 2: CULTIVO (lote + plantas). Un stock externo no pasa por acá: no tiene lote,
             y un nodo vacío se lee como que falta el dato. -->
        <div v-if="data.lote" class="trz__node trz__node--lote">
          <div class="trz__node-head">
            <span class="trz__node-badge trz__node-badge--lote">📦 CULTIVO / LOTE</span>
            <span v-if="data.lote" class="trz__node-code">{{ data.lote.codigo }}</span>
          </div>
          <div class="trz__node-body">
            <div class="trz__fields">
              <div class="trz__field">
                <span class="trz__field-lbl">Estado</span>
                <span class="trz__estado-pill">{{ estadoLabel(data.lote?.estado) }}</span>
                <span v-if="data.lote?.dias_en_estado != null" class="trz__dias">{{ data.lote.dias_en_estado }} días ahí</span>
              </div>
              <div v-if="data.lote?.sede || data.lote?.sala" class="trz__field">
                <span class="trz__field-lbl">Dónde</span>
                <span class="trz__field-val">{{ [data.lote.sede, data.lote.sala].filter(Boolean).join(' · ') }}</span>
              </div>
              <div v-if="data.lote?.start_date" class="trz__field">
                <span class="trz__field-lbl">Arrancó</span>
                <span class="trz__field-val">{{ formatDate(data.lote.start_date) }}</span>
              </div>
              <!-- Un derivado hereda la cadena de la flor de la que salió, y dice de qué frasco. -->
              <div v-if="data.stock?.producido_desde" class="trz__field">
                <span class="trz__field-lbl">Elaborado de</span>
                <span class="trz__field-val">{{ data.stock.producido_desde.gramos }} g de <a href="#" class="trz__link" @click.prevent="buscar(data.stock.producido_desde.id)">{{ data.stock.producido_desde.numero }}</a></span>
              </div>
              <div v-if="data.pesada" class="trz__field">
                <span class="trz__field-lbl">Pesada</span>
                <span class="trz__field-val">{{ data.pesada.peso_total_g }} g · {{ formatDate(data.pesada.registrado_at) }}</span>
              </div>
            </div>

            <!-- Cronología del ciclo: cada cambio de estado con los días del anterior, los
                 descartes y los pesajes. Leía `lote_eventos`, que el backend nunca mandó. -->
            <div v-if="timeline.length" class="trz__timeline">
              <div
                v-for="(ev, idx) in timeline"
                :key="idx"
                class="trz__tl-item"
                :class="{ 'trz__tl-item--pesada': ev.type === 'pesada' }"
              >
                <div class="trz__tl-dot">{{ ev.icon }}</div>
                <div class="trz__tl-text">
                  <span class="trz__tl-title">{{ ev.titulo }}</span>
                  <span v-if="ev.detalle" class="trz__tl-detail">{{ ev.detalle }}</span>
                  <span class="trz__tl-date">{{ formatDate(ev.fecha) }}</span>
                </div>
              </div>
            </div>

            <!-- PLANTAS POR NOMBRE, no por QR (Germán, sep-2026): el código QR es un identificador de
                 máquina y quince seguidos son una pared. Se nombra como en manicura (L-26-023-P020);
                 el QR queda como título al pasar el mouse y entero en el PDF. Plegada en cinco filas:
                 un lote de 40 plantas es una lista que se abre, no una pared. -->
            <div v-if="data.plantas?.length || data.plantas_descartadas?.length" class="trz__plantas">
              <span class="trz__plantas-lbl">
                {{ data.plantas?.length || 0 }} {{ data.atribucion === 'planta' ? 'plantas pesadas a este frasco' : (data.stock ? 'plantas del lote' : 'plantas') }}
                <template v-if="data.plantas_descartadas?.length"> · {{ data.plantas_descartadas.length }} descartadas</template>
              </span>
              <span v-if="data.atribucion === 'lote'" class="trz__plantas-nota">
                Sin pesaje planta por planta: el origen se acredita a nivel de lote, no como medición individual.
              </span>
              <table class="trz__plantas-tabla">
                <thead><tr><th>Planta</th><th>Origen</th><th class="num">Peso seco</th><th>Estado</th></tr></thead>
                <tbody>
                  <tr v-for="p in plantasVisibles" :key="p.id" :class="{ 'trz__planta--descartada': p.descartada }">
                    <td class="mono" :title="p.codigo_qr">{{ p.nombre || p.codigo_qr || `#${p.id}` }}</td>
                    <td>{{ p.origen === 'semilla' ? 'Semilla' : p.origen === 'esqueje' ? 'Esqueje' : (p.origen || '—') }}</td>
                    <td class="num">{{ p.peso_g ? `${p.peso_g} g${p.promedio ? ' (prom.)' : ''}` : '—' }}</td>
                    <td class="trz__planta-estado">{{ p.descartada ? `descartada · ${motivoLabel(p.motivo_descarte) || 'sin motivo'}` : (p.estado ? estadoPlanta(p.estado) : '') }}</td>
                  </tr>
                </tbody>
              </table>
              <button v-if="todasLasPlantas.length > PLANTAS_PLEGADAS" type="button" class="trz__detalle-btn" @click="plantasAbiertas = !plantasAbiertas">
                <i :class="plantasAbiertas ? 'bi bi-chevron-down' : 'bi bi-chevron-right'"></i>
                {{ plantasAbiertas ? 'Ver menos' : `Ver las ${todasLasPlantas.length} plantas` }}
              </button>
            </div>
          </div>
        </div>

        <div v-if="data.aplicaciones?.registros" class="trz__arrow"><i class="bi bi-arrow-down"></i></div>

        <!-- Nodo 3: QUÉ SE LE APLICÓ.
             La cadena decía de qué plantas salió el frasco y no qué recibieron esas plantas. Los
             datos estaban todos en los registros ambientales y no los mostraba nadie.
             Es un RESUMEN, no un log: sesenta riegos uno abajo del otro no los lee nadie. Lo que
             contesta "¿qué le pusieron a esto?" es la lista de productos y cuántas veces. -->
        <div v-if="data.aplicaciones?.registros" class="trz__node trz__node--aplic">
          <div class="trz__node-head">
            <span class="trz__node-badge trz__node-badge--aplic">🧪 QUÉ SE LE APLICÓ</span>
            <span class="trz__node-code">{{ data.aplicaciones.registros }} registros</span>
          </div>
          <div class="trz__node-body">

            <!-- Lo sanitario PRIMERO y aparte de la nutrición: en un producto medicinal es el
                 dato más sensible que hay, y mezclarlo con el bloom es lo que no puede pasar. -->
            <div v-if="data.aplicaciones.fitosanitarios?.length" class="trz__fito">
              <div class="trz__fito-tit">⚠️ Aplicaciones fitosanitarias</div>
              <div v-for="(f, i) in data.aplicaciones.fitosanitarios" :key="i" class="trz__fito-row">
                <strong>{{ f.producto }}</strong>
                <span v-if="f.motivo"> · contra {{ f.motivo }}</span>
                <span v-if="f.fecha"> · {{ fecha(f.fecha) }}</span>
                <span v-if="f.carencia_dias"> · carencia {{ f.carencia_dias }} días</span>
              </div>
            </div>

            <div class="trz__fields">
              <div class="trz__field" v-if="data.aplicaciones.nutricion?.productos?.length">
                <span class="trz__field-lbl">Nutrición ({{ data.aplicaciones.nutricion.veces }} aplicaciones)</span>
                <span class="trz__field-val">{{ data.aplicaciones.nutricion.productos.join(' · ') }}</span>
              </div>
              <div class="trz__field" v-if="data.aplicaciones.nutricion?.enraizantes?.length">
                <span class="trz__field-lbl">Enraizante</span>
                <span class="trz__field-val">{{ data.aplicaciones.nutricion.enraizantes.join(' · ') }}</span>
              </div>
              <div class="trz__field" v-for="(n, act) in data.aplicaciones.actividades" :key="act">
                <span class="trz__field-lbl">{{ actividadLabel(act) }}</span>
                <span class="trz__field-val">{{ n }}</span>
              </div>
            </div>

            <div v-if="data.aplicaciones.plagas?.length" class="trz__fields trz__fields--mt">
              <div class="trz__field" v-for="(p, i) in data.aplicaciones.plagas" :key="i">
                <span class="trz__field-lbl">Plaga observada</span>
                <span class="trz__field-val">{{ p.plaga }} ({{ p.veces }}×)</span>
              </div>
            </div>

            <!-- El log completo, PLEGADO. Un auditor puede necesitar registro por registro, pero
                 abrirlo por defecto convierte el informe en sesenta filas que nadie lee. -->
            <div v-if="data.aplicaciones.detalle?.length" class="trz__detalle">
              <button type="button" class="trz__detalle-btn" @click="detalleAbierto = !detalleAbierto">
                <i :class="detalleAbierto ? 'bi bi-chevron-down' : 'bi bi-chevron-right'"></i>
                Ver los {{ data.aplicaciones.detalle.length }} registros uno por uno
              </button>
              <div v-if="detalleAbierto" class="trz__detalle-lista">
                <div v-for="(r, i) in data.aplicaciones.detalle" :key="i" class="trz__detalle-row">
                  <span class="trz__detalle-fecha">{{ fecha(r.fecha) }}</span>
                  <span class="trz__detalle-cuerpo">
                    <span v-if="r.actividades?.length">{{ r.actividades.map(actividadLabel).join(', ') }}</span>
                    <span v-if="r.fertilizacion"> · {{ r.fertilizacion }}</span>
                    <span v-if="r.fitosanitario" class="trz__detalle-fito"> · {{ r.fitosanitario }}</span>
                    <span v-if="r.plagas"> · plaga: {{ r.plagas }}</span>
                    <span v-if="r.ph != null"> · pH {{ r.ph }}</span>
                    <span v-if="r.ec != null"> · EC {{ r.ec }}</span>
                    <span v-if="r.temperatura != null"> · {{ r.temperatura }}°C</span>
                    <span v-if="r.humedad != null"> · {{ r.humedad }}% HR</span>
                    <span v-if="r.observaciones"> · {{ r.observaciones }}</span>
                  </span>
                </div>
              </div>
            </div>

            <!-- Todos los análisis, si hubo más de uno; el último ya está arriba, en el origen. -->
            <div v-if="data.analisis_laboratorio?.length > 1" class="trz__lab">
              <div class="trz__fito-tit">🔬 Análisis de laboratorio</div>
              <div v-for="(a, i) in data.analisis_laboratorio" :key="i" class="trz__fito-row">
                <span v-if="a.thc_pct != null">THC {{ a.thc_pct }}%</span>
                <span v-if="a.cbd_pct != null"> · CBD {{ a.cbd_pct }}%</span>
                <span v-if="a.cbg_pct != null"> · CBG {{ a.cbg_pct }}%</span>
                <span v-if="a.laboratorio"> · {{ a.laboratorio }}</span>
                <span v-if="a.fecha"> · {{ fecha(a.fecha) }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- LOS FRASCOS QUE SALIERON DEL LOTE, cada uno con su link: la cadena sigue en cada uno. -->
        <template v-if="data.frascos">
          <div class="trz__arrow"><i class="bi bi-arrow-down"></i></div>
          <div class="trz__node trz__node--stock">
            <div class="trz__node-head">
              <span class="trz__node-badge trz__node-badge--stock">🏷️ FRASCOS QUE SALIERON</span>
              <span class="trz__node-code">{{ data.frascos.length }}</span>
            </div>
            <div class="trz__node-body">
              <div v-if="data.frascos.length" class="trz__disp-wrap">
                <table class="trz__disp-table">
                  <thead><tr><th>Frasco</th><th>Forma</th><th>Sede</th><th>Entró</th><th>Queda</th><th>Elaborado</th></tr></thead>
                  <tbody>
                    <tr v-for="f in data.frascos" :key="f.id">
                      <td class="trz__td-bold"><a href="#" class="trz__link" @click.prevent="buscar(f.id)">{{ f.numero || `#${f.id}` }}</a></td>
                      <td>{{ FORMA_LABELS[f.forma] || f.forma }}</td>
                      <td>{{ f.sede || '—' }}</td>
                      <td class="trz__td-g">{{ f.cantidad_inicial }} {{ f.unidad || 'g' }}</td>
                      <td class="trz__td-g">{{ f.cantidad }} {{ f.unidad || 'g' }}</td>
                      <td class="trz__td-fecha">{{ formatDate(f.fecha_elaboracion) }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <div v-else class="trz__no-disp"><i class="bi bi-inbox"></i> Todavía no salió ningún frasco de este lote.</div>
            </div>
          </div>
        </template>

        <template v-if="data.stock">
        <div class="trz__arrow"><i class="bi bi-arrow-down"></i></div>

        <!-- Nodo 3: STOCK -->
        <div class="trz__node trz__node--stock">
          <div class="trz__node-head">
            <span class="trz__node-badge trz__node-badge--stock">🏷️ ESTE FRASCO</span>
            <span class="trz__node-code">{{ data.stock.numero_lote_producto || `ID ${data.stock.id}` }}</span>
          </div>
          <div class="trz__node-body">
            <div class="trz__fields">
              <div class="trz__field">
                <span class="trz__field-lbl">Forma</span>
                <span class="trz__field-val">{{ FORMA_LABELS[data.stock.forma_producto] || data.stock.forma_producto }}</span>
              </div>
              <div class="trz__field">
                <span class="trz__field-lbl">Entró</span>
                <span class="trz__field-val trz__field-g">{{ data.stock.cantidad_inicial_g }} {{ unidad }}<span v-if="data.stock.fecha_elaboracion"> · {{ formatDate(data.stock.fecha_elaboracion) }}</span></span>
              </div>
              <div class="trz__field">
                <span class="trz__field-lbl">Hoy</span>
                <span class="trz__field-val trz__field-g">{{ data.stock.cantidad_disponible_g }} {{ unidad }}<span v-if="data.stock.sede"> en {{ data.stock.sede }}</span></span>
              </div>
              <!-- Si el frasco se partió a otra sede o se convirtió en un derivado, la cadena
                   continúa en otra fila, con su propio balance. Cada una nombra a la otra. -->
              <div v-if="data.siguio_en?.length" class="trz__field">
                <span class="trz__field-lbl">Siguió en</span>
                <span class="trz__field-val">
                  <template v-for="(x, i) in data.siguio_en" :key="x.stock_id">
                    <span v-if="i"> · </span>
                    <a href="#" class="trz__link" @click.prevent="buscar(x.stock_id)">{{ x.numero }}</a>
                    ({{ x.gramos }} g, {{ x.tipo === 'derivado' ? (FORMA_LABELS[x.forma] || 'derivado') : x.sede || 'otra sede' }})
                  </template>
                </span>
              </div>
            </div>
            <div v-if="data.stock.codigo_qr" class="trz__qr-row">
              <i class="bi bi-qr-code"></i>
              <code>{{ data.stock.codigo_qr }}</code>
            </div>
          </div>
        </div>

        <div class="trz__arrow"><i class="bi bi-arrow-down"></i></div>

        <!-- Nodo 4: DISPENSACIONES -->
        <div class="trz__node trz__node--dispens">
          <div class="trz__node-head">
            <span class="trz__node-badge trz__node-badge--dispens">💊 A QUIÉN FUE</span>
            <span class="trz__node-sub">
              {{ data.totales.dispensaciones_count }} entregas · {{ data.totales.gramos_dispensados }} {{ unidad }}
            </span>
          </div>
          <div class="trz__node-body">
            <div v-if="data.dispensaciones.length" class="trz__disp-wrap">
              <table class="trz__disp-table">
                <thead>
                  <tr>
                    <th>Fecha</th>
                    <th>Paciente</th>
                    <!-- Últimos TRES en pantalla; el DNI entero va sólo en el PDF, que es lo
                         que se entrega (decisión de Germán, sep-2026). -->
                    <th>DNI</th>
                    <th>Cantidad</th>
                    <th>Cómo</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="d in data.dispensaciones" :key="d.id">
                    <td class="trz__td-fecha">{{ formatDate(d.fecha) }}</td>
                    <td class="trz__td-bold">{{ d.paciente || d.paciente_iniciales }}</td>
                    <td class="trz__td-mono">···{{ d.paciente_dni_last3 }}</td>
                    <td class="trz__td-g">{{ d.cantidad_g }} {{ unidad }}</td>
                    <td class="trz__td-canal">{{ d.canal }}<span v-if="d.junto_con?.length"> · con {{ d.junto_con.join(', ') }}</span></td>
                  </tr>
                  <!-- Los totales de arriba son sobre TODAS; acá se listan las últimas cien. -->
                  <tr v-if="data.dispensaciones_omitidas">
                    <td colspan="5" class="trz__td-mas">… {{ data.dispensaciones_omitidas }} entregas más. El total es sobre todas; el PDF las lleva completas.</td>
                  </tr>
                </tbody>
                <tfoot>
                  <tr>
                    <td colspan="3"><strong>Total</strong></td>
                    <td class="trz__td-g"><strong>{{ data.totales.gramos_dispensados }} {{ unidad }}</strong></td>
                    <td></td>
                  </tr>
                </tfoot>
              </table>
            </div>
            <div v-else class="trz__no-disp">
              <i class="bi bi-inbox"></i> Sin dispensaciones registradas para este stock.
            </div>
          </div>
        </div>
        </template>

      </div>

      <!-- Sin marca de la plataforma: el documento es de la organización (misma regla que el PDF). -->
      <div class="trz__footer-legal">
        Al {{ hoy }} · Contiene datos personales de pacientes: tratar como información sensible.
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { getStockTrazabilidad, getLoteTrazabilidad, listStocks, listLotes } from '../../lib/api.js'
import { descargarArchivo } from '../../lib/descargas.js'
import { hoyISO } from '../../utils/dates.js'
import { ESTADO_META, PLANT_STATE_META } from '../../lib/loteHelpers.js'

const FORMA_LABELS = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite', tintura: 'Tintura',
  crema: 'Crema', capsula: 'Cápsula', comestible: 'Comestible', prensado: 'Prensado',
  preroll: 'Preroll', otro: 'Otro', externo: 'Externo',
}
const FASE_ICONS = {
  semilla: '🌰', esqueje: '🌱', germinacion: '🌱', vegetativo: '🌿', floracion: '🌸',
  cosecha: '🌾', en_manicura: '✂️', curado: '🫙', finalizado: '✅',
}
// Plant::MOTIVOS_DESCARTE. Importa la diferencia: no es lo mismo una planta que no prendió que
// una descartada por error humano — leído desde afuera, el motivo es media explicación del hueco.
const MOTIVO_DESCARTE_LABELS = {
  no_prendio: 'No prendió', plaga: 'Plaga', enfermedad: 'Enfermedad', macho: 'Macho',
  hermafrodita: 'Hermafrodita', estres: 'Estrés', rotura: 'Rotura', otro: 'Otro',
}
const motivoLabel = (m) => MOTIVO_DESCARTE_LABELS[m] || m
const estadoLabel = (e) => ESTADO_META[e]?.label || e
const estadoPlanta = (e) => PLANT_STATE_META[e]?.label || e

// Cada salida con su nombre y, cuando el producto sigue existiendo, a dónde fue. Un traslado o
// un derivado no son pérdida: son el mismo producto en otra fila.
const SALIDA_LABELS = {
  transferencia: 'traslado', produccion: 'a derivado', consumo_evento: 'consumo en evento',
  salida: 'salida', ajuste: 'ajuste de conteo', merma: 'merma',
}
function salidaLabel(m) {
  const base = SALIDA_LABELS[m.tipo] || m.tipo
  if (m.destino?.numero) {
    const donde = m.tipo === 'produccion' ? `${m.destino.numero}` : `${m.destino.numero}${m.destino.sede ? ` · ${m.destino.sede}` : ''}`
    return `${base} → ${donde}`
  }
  const cuando = m.fecha ? ` · ${fecha(m.fecha)}` : ''
  return m.detalle ? `${base} · ${m.detalle}${cuando}` : `${base}${cuando}`
}

// Cómo se llaman las tareas en el idioma en que se habla de ellas: en la base son claves
// (`limpieza_sala`, `scrog_lst`) y en un informe que lee un auditor eso no dice nada.
const ACTIVIDAD_LABELS = {
  riego: 'Riegos', nutricion: 'Fertilizaciones', poda: 'Podas', defoliacion: 'Defoliaciones',
  scrog_lst: 'SCROG / LST', revision_plagas: 'Revisiones de plaga',
  limpieza_sala: 'Limpiezas', ajuste_luz: 'Ajustes de luz',
}
const actividadLabel = (a) => ACTIVIDAD_LABELS[a] || String(a).replaceAll('_', ' ')

const fecha = (f) => (f ? new Date(f).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '')

const query       = ref('')
const loading     = ref(false)
const loadingList = ref(true)
const error       = ref(null)
const data        = ref(null)
const stocksList  = ref([])
const lotesList   = ref([])
const autoVisible = ref(false)

// ── Solapas y filtros del listado ───────────────────────────────────────────
const solapa = ref('lotes')
const filtro = ref({ estado: '', sede: '', genetica: '', desde: '', hasta: '' })
const hayFiltros = computed(() => Object.values(filtro.value).some(Boolean))
function limpiarFiltros () { filtro.value = { estado: '', sede: '', genetica: '', desde: '', hasta: '' } }

const EN_CULTIVO = ['enraizado', 'vegetativo', 'floracion']
const COSECHADOS = ['cosecha', 'en_manicura', 'curado']
const sedeDeLote = (l) => l.sede?.nombre || l.sala?.sede?.nombre || l.sede_nombre
const frascosDeLote = (l) => stocksList.value.filter(s => (s.lote_id ?? s.lote?.id) === l.id)
const enRango = (fecha) => {
  if (!fecha) return !filtro.value.desde && !filtro.value.hasta
  const f = String(fecha).slice(0, 10)
  return (!filtro.value.desde || f >= filtro.value.desde) && (!filtro.value.hasta || f <= filtro.value.hasta)
}
const lotesFiltrados = computed(() => lotesList.value.filter(l => {
  const e = filtro.value.estado
  if (e === 'cultivo' && !EN_CULTIVO.includes(l.estado)) return false
  if (e === 'cosechados' && !COSECHADOS.includes(l.estado)) return false
  if (e === 'finalizado' && l.estado !== 'finalizado') return false
  if (filtro.value.sede && sedeDeLote(l) !== filtro.value.sede) return false
  if (filtro.value.genetica && l.genetica?.nombre !== filtro.value.genetica) return false
  return enRango(l.start_date)
}))
const stocksFiltrados = computed(() => stocksList.value.filter(s => {
  const e = filtro.value.estado
  if (e === 'con_stock' && !(Number(s.cantidad) > 0)) return false
  if (e === 'agotado' && Number(s.cantidad) > 0) return false
  if (filtro.value.sede && s.sede?.nombre !== filtro.value.sede) return false
  if (filtro.value.genetica && (s.genetica_nombre || s.genetica?.nombre) !== filtro.value.genetica) return false
  return enRango(s.fecha_elaboracion)
}))
const sedesDeLista = computed(() => [...new Set([...lotesList.value.map(sedeDeLote), ...stocksList.value.map(s => s.sede?.nombre)].filter(Boolean))].sort())
const geneticasDeLista = computed(() => [...new Set([...lotesList.value.map(l => l.genetica?.nombre), ...stocksList.value.map(s => s.genetica_nombre || s.genetica?.nombre)].filter(Boolean))].sort())

// ── Plantas: una lista, vivas y descartadas, plegada ──
const PLANTAS_PLEGADAS = 5
const plantasAbiertas = ref(false)
const todasLasPlantas = computed(() => [
  ...(data.value?.plantas || []),
  ...(data.value?.plantas_descartadas || []).map(p => ({ ...p, descartada: true })),
])
const plantasVisibles = computed(() => plantasAbiertas.value ? todasLasPlantas.value : todasLasPlantas.value.slice(0, PLANTAS_PLEGADAS))
const genetica = computed(() => data.value?.stock?.genetica || data.value?.lote?.genetica || null)
// El log detallado arranca plegado: se abre a pedido, no por defecto.
const detalleAbierto = ref(false)

const hoy = new Date().toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' })

const sugerencias = computed(() => {
  const q = query.value.trim().toLowerCase()
  if (!q || q.length < 2) return []
  return stocksList.value
    .filter(s =>
      (s.numero_lote_producto || '').toLowerCase().includes(q) ||
      String(s.id).includes(q) ||
      (s.codigo_qr || '').toLowerCase().includes(q)
    )
    .slice(0, 8)
})

const unidad = computed(() => data.value?.stock?.unidad || 'g')
const esExterno = computed(() => data.value?.stock?.origen === 'compra_externa' && !data.value?.lote)
const ultimoAnalisis = computed(() => data.value?.analisis_laboratorio?.[0] || null)

const origenLabel = computed(() => {
  if (esExterno.value) return 'Compra externa'
  if (!data.value?.plantas?.length) return 'No especificado'
  const origenes = [...new Set(data.value.plantas.map(p => p.origen).filter(Boolean))]
  if (!origenes.length) return 'No especificado'
  return origenes.map(o => o === 'semilla' ? 'Semilla' : o === 'esqueje' ? 'Esqueje' : o).join(' / ')
})

// La cronología la arma el backend (`cronologia`): cambios de estado con los días del anterior,
// descartes y pesajes, ya ordenados. Antes se leía `lote_eventos`, que nunca llegaba.
const CRONO_ICONS = { estado: null, descarte: '🚫', pesaje: '⚖️' }
const timeline = computed(() => {
  if (!Array.isArray(data.value?.cronologia)) return []
  return data.value.cronologia.map(ev => ({
    type:    ev.tipo,
    fecha:   ev.fecha,
    icon:    ev.tipo === 'estado' ? (FASE_ICONS[ev.estado] || '📋') : CRONO_ICONS[ev.tipo] || '📋',
    titulo:  ev.tipo === 'estado' ? estadoLabel(ev.estado) : ev.titulo,
    detalle: ev.detalle || null,
  }))
})

onMounted(async () => {
  try {
    const [r, l] = await Promise.all([listStocks(), listLotes()])
    stocksList.value = r.data || []
    lotesList.value  = l.data || []
  } catch { stocksList.value = []; lotesList.value = [] }
  finally { loadingList.value = false }
})

async function abrirLote (id) {
  loading.value = true
  error.value   = null
  data.value    = null
  plantasAbiertas.value = false
  try {
    const res = await getLoteTrazabilidad(id)
    data.value = res.data
  } catch (e) {
    error.value = e.response?.data?.error || 'Error al cargar la trazabilidad del lote'
  } finally {
    loading.value = false
  }
}

function onInput() { autoVisible.value = true; error.value = null }
function onBlur() { setTimeout(() => { autoVisible.value = false }, 150) }
function cerrarAuto() { autoVisible.value = false }

async function seleccionarStock(s) {
  query.value = s.numero_lote_producto || String(s.id)
  autoVisible.value = false
  await buscar(s.id)
}

async function buscarDesdeInput() {
  const q = query.value.trim()
  if (!q) return
  autoVisible.value = false
  if (!isNaN(Number(q))) { await buscar(Number(q)); return }

  let found = stocksList.value.find(s => s.numero_lote_producto === q || s.codigo_qr === q)
  if (!found) {
    try {
      const r = await listStocks()
      stocksList.value = r.data || []
      found = stocksList.value.find(s => s.numero_lote_producto === q || s.codigo_qr === q)
    } catch { /* noop */ }
  }
  if (!found) { error.value = `No se encontró "${q}"`; return }
  await buscar(found.id)
}

async function buscar(id) {
  loading.value = true
  error.value   = null
  data.value    = null
  plantasAbiertas.value = false
  try {
    const res = await getStockTrazabilidad(id)
    data.value = res.data
  } catch (e) {
    error.value = e.response?.data?.error || 'Error al cargar trazabilidad'
  } finally {
    loading.value = false
  }
}

function volver() {
  data.value  = null
  query.value = ''
  error.value = null
}

// El PDF lo arma el servidor: la trazabilidad es lo primero que pide un auditor y se bajaba
// como una foto de la pantalla, sin texto seleccionable ni buscable.
async function exportPdf() {
  const st = data.value?.stock
  if (!st?.id) return
  try {
    const ref = st.numero_lote_producto || st.id
    await descargarArchivo(`/stocks/${st.id}/trazabilidad.pdf`, {
      filename: `trazabilidad_${ref}_${hoyISO()}.pdf`,
    })
    error.value = null
  } catch (e) {
    // El motivo lo trae el backend. Antes acá había un `catch` pelado que lo tiraba y decía
    // "reintentá en un momento" — invitando a reintentar algo que no iba a andar nunca.
    error.value = e.message
  }
}

const formatDate = d => d
  ? new Date(d).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' })
  : '—'
</script>

<style scoped>
.trz { padding: var(--sp-6, 1.5rem); }

/* Top bar */
.trz__top {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 1rem; flex-wrap: wrap; margin-bottom: 1.5rem;
}
.trz__top-left {}
.trz__title {
  font-size: 1.35rem; font-weight: 800; color: var(--c-slate-900);
  margin: 0 0 .25rem; display: flex; align-items: center; gap: .5rem;
}
.trz__sub { font-size: .82rem; color: var(--c-slate-500); margin: 0; }

.trz__top-right { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }

/* Search */
.trz__search-wrap { position: relative; display: flex; align-items: center; }
.trz__search-ico {
  position: absolute; left: .8rem; color: var(--c-slate-400); font-size: .85rem; pointer-events: none; z-index: 1;
}
.trz__search-input {
  background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 9px;
  padding: .6rem 3rem .6rem 2.2rem; font-size: .875rem; color: var(--c-slate-900);
  width: 280px; outline: none; transition: border-color .15s; font-family: inherit;
}
.trz__search-input:focus { border-color: #1b5e20; }
.trz__search-btn {
  position: absolute; right: .35rem; background: #1b5e20; color: #fff;
  border: none; border-radius: 6px; padding: .3rem .6rem;
  cursor: pointer; display: flex; align-items: center; transition: background .15s;
}
.trz__search-btn:hover:not(:disabled) { background: #144a18; }
.trz__search-btn:disabled { opacity: .4; cursor: not-allowed; }

.trz__autocomplete {
  position: absolute; top: calc(100% + 2px); left: 0; right: 0;
  background: #fff; border: 1.5px solid #1b5e20; border-radius: 8px;
  box-shadow: 0 8px 24px rgba(0,0,0,.1); z-index: 50; overflow: hidden;
}
.trz__auto-item {
  display: flex; align-items: center; justify-content: space-between;
  width: 100%; background: none; border: none; padding: .55rem .9rem;
  cursor: pointer; text-align: left; transition: background .1s;
  border-bottom: 1px solid var(--c-slate-100);
}
.trz__auto-item:last-child { border-bottom: none; }
.trz__auto-item:hover { background: #f0fdf4; }
.trz__auto-num { font-size: .82rem; font-weight: 700; color: var(--c-slate-900); font-family: monospace; }
.trz__auto-meta { font-size: .72rem; color: var(--c-slate-400); }
.trz__auto-g { color: #d97706; }

.trz__btn-pdf, .trz__btn-back {
  display: inline-flex; align-items: center; gap: .4rem;
  border: none; padding: .55rem .9rem; border-radius: 8px;
  font-size: .82rem; font-weight: 600; cursor: pointer; white-space: nowrap; transition: all .15s;
}
.trz__btn-pdf  { background: #1b5e20; color: #fff; }
.trz__btn-pdf:hover  { background: #144a18; }
.trz__btn-back { background: var(--c-slate-100); color: var(--c-slate-600); }
.trz__btn-back:hover { background: var(--c-slate-200); }

/* Alert */
.trz__alert {
  display: flex; align-items: center; gap: .5rem; color: #dc2626;
  background: #fef2f2; border: 1px solid #fecaca; border-radius: 9px;
  padding: .7rem 1rem; margin-bottom: 1.25rem; font-size: .875rem;
}

/* Loader */
.trz__loader {
  display: flex; align-items: center; justify-content: center; padding: 2rem;
}

/* Empty plain */
.trz__empty-plain {
  padding: 3rem 0; color: var(--c-slate-400); font-size: .9rem;
  display: flex; align-items: center; gap: .5rem;
}

/* Stocks list */
.trz__stocks-section {}
.trz__stocks-header {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: .75rem; flex-wrap: wrap; gap: .5rem;
}
.trz__stocks-count { font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-800); }
.trz__stocks-hint { font-size: var(--fs-13); color: var(--c-ink-400); display: flex; align-items: center; gap: .3rem; }

.trz__table-wrap {
  border: 1px solid var(--c-ink-100); border-radius: 14px; overflow: hidden; overflow-x: auto; background: #fff;
}
.trz__table { width: 100%; border-collapse: collapse; font-size: var(--fs-14); background: #fff; }
.trz__table thead th {
  text-align: left; font-size: 11px; font-weight: 700;
  text-transform: uppercase; letter-spacing: .05em; color: var(--c-ink-500);
  background: var(--c-ink-50); padding: var(--sp-3) var(--sp-4);
  border-bottom: 1px solid var(--c-ink-100); white-space: nowrap;
}
.trz__th-r { text-align: right; }
.trz__tr { cursor: pointer; transition: background .12s; }
.trz__tr:not(:last-child) td { border-bottom: 1px solid var(--c-ink-100); }
.trz__tr:hover { background: var(--c-leaf-50, #f0fdf4); }
.trz__tr td { padding: var(--sp-3) var(--sp-4); color: var(--c-ink-900); vertical-align: middle; }
.trz__td-code { font-weight: 700; color: var(--c-ink-900); }
.trz__td-gen { font-weight: 600; color: var(--c-ink-800); }
.trz__externo { font-size: .74rem; font-weight: 600; color: var(--c-slate-600); background: var(--c-slate-100); border-radius: 999px; padding: .1em .55em; }
.trz__deriv { margin-left: .35rem; font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .03em; color: #7c3aed; background: #f3e8ff; border-radius: 999px; padding: .1em .45em; }
.trz__td-lote { font-family: var(--font-mono, monospace); font-size: var(--fs-13); color: var(--c-ink-500); }
.trz__td-fecha { color: var(--c-ink-400); font-size: var(--fs-13); white-space: nowrap; }
.trz__td-action { text-align: right; }
.trz__td-ver {
  font-size: var(--fs-13); font-weight: 600; color: var(--c-leaf-700, #15803d);
  display: inline-flex; align-items: center; gap: .3rem; opacity: 0; transition: opacity .15s; white-space: nowrap;
}
.trz__tr:hover .trz__td-ver { opacity: 1; }
.trz__forma-badge {
  display: inline-block; background: var(--c-leaf-100, #dcfce7); color: var(--c-leaf-700, #15803d);
  font-size: var(--fs-13); font-weight: 600; padding: .15em .65em; border-radius: 999px; white-space: nowrap;
}

/* Report */
.trz__banner {
  display: flex; align-items: center; justify-content: space-between;
  background: var(--c-slate-900); color: #fff; border-radius: 12px;
  padding: .875rem 1.25rem; margin-bottom: 1.25rem; flex-wrap: wrap; gap: .5rem;
}
.trz__banner-label { font-size: .65rem; color: rgba(255,255,255,.45); font-weight: 600; text-transform: uppercase; letter-spacing: .06em; }
.trz__banner-ref { font-family: monospace; font-size: 1rem; font-weight: 700; }
.trz__banner-date { font-size: .78rem; color: rgba(255,255,255,.5); display: flex; align-items: center; gap: .35rem; }

/* KPIs */
/* Chain divider */
.trz__balance {
  display: flex; align-items: center; flex-wrap: wrap; gap: .5rem 1rem;
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 12px;
  padding: .9rem 1.1rem; margin-bottom: 1rem;
}
.trz__bal-item { display: flex; flex-direction: column; gap: .1rem; min-width: 92px; }
.trz__bal-lbl { font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: var(--c-slate-400); }
.trz__bal-val { font-size: 1rem; font-weight: 800; color: var(--c-slate-900); }
.trz__bal-pct { font-size: .68rem; color: var(--c-slate-500); }
/* Lo que salió sin pasar por el mostrador: no es un error, pero es lo que hay que poder
   explicar si alguien pregunta. */
.trz__bal-item--alerta .trz__bal-val { color: #b45309; }
.trz__bal-item--total .trz__bal-val { color: #15803d; }
.trz__bal-op { font-size: 1.05rem; font-weight: 700; color: var(--c-slate-300); }
/* El desglose de cada caja: qué es cada salida y dónde está lo que queda. La merma es lo único
   que se pinta: es la única salida que es pérdida. */
.trz__bal-item--salidas { min-width: 180px; }
.trz__bal-sub { list-style: none; margin: .25rem 0 0; padding: 0; display: flex; flex-direction: column; gap: .1rem; font-size: .72rem; color: var(--c-slate-600); }
.trz__bal-sub li { display: flex; justify-content: space-between; gap: .75rem; }
.trz__bal-sub-g { font-variant-numeric: tabular-nums; white-space: nowrap; }
.trz__bal-sub--merma { color: #b45309; font-weight: 600; }
.trz__frase { font-size: .9rem; color: var(--c-slate-700); margin: -.25rem 0 1rem; line-height: 1.5; }
.trz__frase--abierta { color: #92400e; }
.trz__link { color: #1b5e20; text-decoration: underline; text-decoration-color: var(--c-slate-300); }
.trz__td-canal { font-size: .78rem; color: var(--c-slate-500); }
.trz__td-mas { font-size: .78rem; color: var(--c-slate-400); font-style: italic; }
.trz__chain-divider {
  display: flex; align-items: center; gap: .75rem;
  font-size: .65rem; font-weight: 700; color: var(--c-slate-400);
  text-transform: uppercase; letter-spacing: .07em; margin-bottom: 1rem;
}
.trz__chain-divider::before, .trz__chain-divider::after {
  content: ''; flex: 1; height: 1px; background: var(--c-slate-200);
}

/* Chain layout: 2-col on wide screens */
.trz__chain { display: flex; flex-direction: column; }

.trz__node {
  background: #fff; border: 2px solid var(--c-slate-200); border-radius: 14px; overflow: hidden;
}
.trz__node--origen { border-color: #d1fae5; }
.trz__node--lote   { border-color: #bbf7d0; }
.trz__node--stock  { border-color: #fde68a; }
.trz__node--aplic  { border-color: #ddd6fe; }
.trz__node-badge--aplic { background: #ede9fe; color: #5b21b6; }
.trz__fito { background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; padding: .6rem .8rem; margin-bottom: .75rem; }
.trz__lab  { background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 8px; padding: .6rem .8rem; margin-top: .75rem; }
.trz__fito-tit { font-size: .72rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; margin-bottom: .3rem; }
.trz__fito-row { font-size: .82rem; line-height: 1.5; }
.trz__fields--mt { margin-top: .75rem; }
.trz__detalle { margin-top: .75rem; }
.trz__detalle-btn { background: none; border: none; padding: 0; cursor: pointer; font-size: .78rem; color: #5b21b6; display: flex; align-items: center; gap: .35rem; font-family: inherit; }
.trz__detalle-btn:hover { text-decoration: underline; }
.trz__detalle-lista { margin-top: .5rem; display: flex; flex-direction: column; gap: .3rem; max-height: 340px; overflow-y: auto; }
.trz__detalle-row { display: flex; gap: .6rem; font-size: .78rem; line-height: 1.45; padding-bottom: .3rem; border-bottom: 1px solid rgba(0,0,0,.05); }
.trz__detalle-fecha { flex-shrink: 0; opacity: .6; font-variant-numeric: tabular-nums; }
.trz__detalle-cuerpo { min-width: 0; overflow-wrap: anywhere; }
.trz__detalle-fito { color: #b91c1c; font-weight: 600; }
.trz__node--dispens { border-color: #bae6fd; }

.trz__node-head {
  display: flex; align-items: center; gap: .75rem; flex-wrap: wrap;
  padding: .65rem 1.25rem; border-bottom: 1px solid var(--c-slate-100); background: #fafbfc;
}
.trz__node-badge {
  font-size: .65rem; font-weight: 700; letter-spacing: .05em;
  padding: .2em .65em; border-radius: 999px;
}
.trz__node-badge--origen { background: #d1fae5; color: #065f46; }
.trz__node-badge--lote   { background: #dcfce7; color: #14532d; }
.trz__node-badge--stock  { background: #fef3c7; color: #78350f; }
.trz__node-badge--dispens { background: #dbeafe; color: #1e3a5f; }
.trz__node-code { font-family: monospace; font-size: .9rem; font-weight: 700; color: var(--c-slate-900); }
.trz__node-sub  { font-size: .8rem; color: var(--c-slate-500); }

.trz__node-body { padding: 1rem 1.25rem; display: flex; flex-direction: column; gap: .875rem; }

.trz__fields { display: flex; flex-wrap: wrap; gap: 1rem; }
.trz__field  { display: flex; flex-direction: column; gap: .15rem; min-width: 120px; }
.trz__field-lbl { font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-400); }
.trz__field-val { font-size: .875rem; color: var(--c-slate-900); font-weight: 500; }
.trz__field-inase { display: inline-flex; align-items: center; gap: .3rem; color: #15803d; }
.trz__field-g { color: #d97706; font-weight: 700; }
.trz__estado-pill {
  display: inline-block; background: var(--c-slate-100); color: var(--c-slate-600);
  font-size: .72rem; font-weight: 700; text-transform: capitalize;
  padding: .2em .65em; border-radius: 999px; align-self: flex-start;
}
.trz__qr-row { display: inline-flex; align-items: center; gap: .45rem; font-size: .75rem; color: var(--c-slate-400); }
.trz__qr-row code { background: var(--c-slate-100); padding: .1em .4em; border-radius: 4px; font-size: .72rem; }

/* Timeline */
.trz__timeline {
  border-left: 2px solid var(--c-slate-200); padding-left: 1.1rem;
  display: flex; flex-direction: column; gap: .5rem;
}
.trz__tl-item { display: flex; align-items: flex-start; gap: .6rem; }
.trz__tl-dot {
  width: 24px; height: 24px; border-radius: 50%; background: var(--c-slate-100);
  display: flex; align-items: center; justify-content: center; font-size: .8rem;
  flex-shrink: 0; margin-left: -1.72rem; border: 2px solid #fff;
}
.trz__tl-item--pesada .trz__tl-dot { background: #fef3c7; }
.trz__tl-text { display: flex; flex-direction: column; gap: .05rem; padding-top: .1rem; }
.trz__tl-title { font-size: .82rem; font-weight: 600; color: var(--c-slate-900); }
.trz__tl-detail { font-size: .72rem; color: var(--c-slate-500); }
.trz__tl-date { font-size: .68rem; color: var(--c-slate-400); }

/* Plantas chips */
.trz__plantas { display: flex; flex-direction: column; gap: .35rem; }
.trz__plantas-tabla { width: 100%; border-collapse: collapse; font-size: .8rem; margin-top: .25rem; }
.trz__plantas-tabla th { text-align: left; font-size: .65rem; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-400); padding: .25rem .5rem; border-bottom: 1px solid var(--c-slate-200); }
.trz__plantas-tabla td { padding: .3rem .5rem; border-bottom: 1px solid var(--c-slate-100); color: var(--c-slate-800); }
.trz__plantas-tabla .num { text-align: right; font-variant-numeric: tabular-nums; }
.trz__plantas-tabla .mono { font-family: var(--font-mono, monospace); font-size: .78rem; }
.trz__planta--descartada td { color: var(--c-slate-400); }
.trz__planta-estado { font-size: .74rem; color: var(--c-slate-500); }
.trz__tabs { display: flex; gap: .25rem; border-bottom: 1px solid var(--c-slate-200); margin-bottom: .75rem; }
.trz__tab { background: none; border: none; border-bottom: 2px solid transparent; padding: .45rem .9rem; font: inherit; font-size: .875rem; color: var(--c-slate-500); cursor: pointer; }
.trz__tab--on { color: #1b5e20; border-bottom-color: #1b5e20; font-weight: 700; }
.trz__filtros { display: flex; flex-wrap: wrap; gap: .5rem; align-items: center; margin-bottom: .9rem; }
.trz__filtro { background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 8px; padding: .4rem .6rem; font-size: .82rem; color: var(--c-slate-900); font-family: inherit; }
.trz__filtro-fechas { display: inline-flex; align-items: center; gap: .4rem; font-size: .8rem; color: var(--c-slate-500); }
.trz__filtro-limpiar { background: none; border: none; font: inherit; font-size: .8rem; color: #1b5e20; cursor: pointer; text-decoration: underline; }
.trz__dias { font-size: .74rem; color: var(--c-slate-500); }
.trz__muted { color: var(--c-slate-400); font-size: .8rem; }
.trz__plantas-lbl { font-size: .68rem; font-weight: 600; color: var(--c-slate-500); }
.trz__plantas-chips { display: flex; flex-wrap: wrap; gap: .25rem; }
/* Las descartadas se leen distinto de las que produjeron: en gris, no en verde. */
.trz__plantas-nota { font-size: .66rem; color: var(--c-slate-500); line-height: 1.35; }

/* Arrow */
.trz__arrow { text-align: center; color: var(--c-slate-400); font-size: 1.25rem; padding: .3rem 0; line-height: 1; }

/* Dispensaciones table */
.trz__disp-wrap { overflow-x: auto; }
.trz__disp-table { width: 100%; border-collapse: collapse; font-size: .8rem; }
.trz__disp-table th {
  padding: .45rem .75rem; background: var(--c-slate-50); font-weight: 700; color: var(--c-slate-500);
  font-size: .65rem; text-transform: uppercase; letter-spacing: .05em;
  border-bottom: 1.5px solid var(--c-slate-200); text-align: left;
}
.trz__disp-table td { padding: .45rem .75rem; border-bottom: 1px solid var(--c-slate-100); }
.trz__disp-table tfoot td { border-top: 2px solid var(--c-slate-200); border-bottom: none; background: var(--c-slate-50); }
.trz__disp-table tbody tr:last-child td { border-bottom: none; }
.trz__td-n { text-align: right; color: var(--c-slate-400); }
.trz__td-bold { font-weight: 700; color: var(--c-slate-900); }
.trz__td-mono { font-family: monospace; color: var(--c-slate-500); }
.trz__td-g { text-align: right; color: #15803d; font-weight: 700; }
.trz__td-fecha { color: var(--c-slate-400); font-size: .72rem; }
.trz__no-disp {
  font-size: .875rem; color: var(--c-slate-400); font-style: italic;
  display: flex; align-items: center; gap: .4rem; padding: .25rem 0;
}

/* Footer legal */
.trz__footer-legal {
  margin-top: 1.5rem; padding: .75rem 1.25rem;
  background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 10px;
  font-size: .68rem; color: var(--c-slate-400); text-align: center; font-style: italic;
}

@media print {
  .trz__top, .trz__btn-pdf, .trz__btn-back { display: none !important; }
  .trz { padding: 0; }
  .trz__node { break-inside: avoid; }
}
</style>
