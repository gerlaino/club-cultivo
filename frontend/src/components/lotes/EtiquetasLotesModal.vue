<script setup>
import { ref, computed, watch } from 'vue'
import { listPlants } from '../../lib/api.js'
import { em } from '../../lib/loteHelpers.js'
import { useClubStore } from '../../stores/club.js'
import { useToast } from '../../composables/useToast.js'
import { useEtiquetasQR, ordenarItems } from '../../composables/useEtiquetasQR.js'
import BloqueoProgreso from '../ui/BloqueoProgreso.vue'
import { LAYOUT_LOTE, dibujarEtiquetaLote, LAYOUT_PLANTA, dibujarBanderitaPlanta } from '../../lib/pdfEtiquetas.js'

// Las etiquetas de los lotes elegidos en /lotes y, si se quiere, las banderitas de SUS plantas, en
// un solo PDF. Es para el día que creaste 20 lotes: sin esto había que ir a Plantas y volver a
// elegir las mismas plantas desde otra tabla.
//
// Las plantas se piden al abrir, no al tocar «Imprimir»: así el modal dice cuántas etiquetas van a
// salir antes de gastar papel, y el click de imprimir abre la ventana sin esperar a la red (si no,
// el bloqueador de popups se la come; ver useEtiquetasQR).
//
// Las DESCARTADAS no llevan banderita (ya no están en la sala). Las cosechadas sí: reimprimir las de
// un lote cosechado es un caso real — la etiqueta se moja, se rompe o se pierde en el secado.

const props = defineProps({
  show:  { type: Boolean, default: false },
  lotes: { type: Array,   default: () => [] },   // los seleccionados
})
const emit = defineEmits(['close', 'hecho'])

const club      = useClubStore()
const toast     = useToast()
const etiquetas = useEtiquetasQR()

const conLotes   = ref(true)
const conPlantas = ref(true)
const plantas    = ref([])
const cargando   = ref(false)
const errorCarga = ref(false)

const lotesConQR    = computed(() => props.lotes.filter(l => l.codigo_qr))
const lotesSinQR    = computed(() => props.lotes.length - lotesConQR.value.length)
const noDescartadas = computed(() => plantas.value.filter(p => p.state !== 'descartada'))
const plantasConQR  = computed(() => noDescartadas.value.filter(p => p.codigo_qr))
const plantasSinQR  = computed(() => noDescartadas.value.length - plantasConQR.value.length)
const descartadas   = computed(() => plantas.value.length - noDescartadas.value.length)

const cantidad = computed(() =>
  (conLotes.value ? lotesConQR.value.length : 0) + (conPlantas.value ? plantasConQR.value.length : 0))
const listo = computed(() => cantidad.value > 0 && !(conPlantas.value && cargando.value))

async function cargarPlantas() {
  plantas.value = []
  errorCarga.value = false
  if (!props.lotes.length) return
  cargando.value = true
  try {
    const { data } = await listPlants({ lote_ids: props.lotes.map(l => l.id) })
    plantas.value = data || []
  } catch {
    errorCarga.value = true
  } finally {
    cargando.value = false
  }
}

watch(() => props.show, (abierto) => {
  if (!abierto) return
  conLotes.value = true
  conPlantas.value = true
  cargarPlantas()
  if (!club.data) club.fetch().catch(() => { /* la organización es opcional en la etiqueta */ })
})

function config() {
  const clubName = club.data?.name || ''
  // La genética y el inicio salen del LOTE: la planta serializada no trae la fecha de inicio.
  const lotePorId = new Map(props.lotes.map(l => [l.id, l]))
  const geneticaDe = (l) => l?.genetica?.nombre_visible || l?.genetica?.nombre || l?.strain

  const tandaLotes = {
    items:    lotesConQR.value,
    urlDe:    (l) => `${window.location.origin}/l/${l.codigo_qr}`,
    layout:   LAYOUT_LOTE,
    dibujar:  dibujarEtiquetaLote,
    ordenPor: (l) => [l.codigo ?? ''],
    datosDe:  (l, qr) => ({
      qrDataUrl: qr,
      codigo:    l.codigo,
      genetica:  geneticaDe(l),
      estado:    em(l.estado).label,
      inicio:    l.start_date,
      plantas:   l.plants_count ?? 0,
      clubName,
    }),
  }
  const tandaPlantas = {
    items:    plantasConQR.value,
    urlDe:    (p) => `${window.location.origin}/p/${p.codigo_qr}`,
    layout:   LAYOUT_PLANTA,
    dibujar:  dibujarBanderitaPlanta,
    // Un lote, todas sus plantas en orden, después el siguiente.
    ordenPor: (p) => [p.lote?.codigo ?? '', p.nombre ?? ''],
    datosDe:  (p, qr) => {
      const l = lotePorId.get(p.lote?.id)
      return {
        qrDataUrl: qr,
        nombre:    p.nombre || p.codigo_qr,
        genetica:  p.genetica?.nombre_visible || p.genetica?.nombre || geneticaDe(l),
        lote:      p.lote?.codigo,
        inicio:    l?.start_date,
        clubName,
      }
    },
  }

  const n = props.lotes.length
  const que = conLotes.value && conPlantas.value ? 'lotes-y-plantas' : conLotes.value ? 'lotes' : 'plantas'
  const archivo = `etiquetas-${que}-${n}-${n === 1 ? 'lote' : 'lotes'}`

  // Con las dos cosas: intercalado y de corrido (decisión de Germán, 29-sep) — la etiqueta del
  // lote, las de sus plantas, el lote siguiente. Es lo más claro con cualquier papel: se corta y
  // cada lote queda junto. Un lote sin QR no lleva etiqueta pero sus plantas salen en su lugar.
  if (conLotes.value && conPlantas.value) {
    const plantasDe = new Map()
    for (const p of plantasConQR.value) {
      const id = p.lote?.id
      if (!plantasDe.has(id)) plantasDe.set(id, [])
      plantasDe.get(id).push(p)
    }
    const secuencia = []
    for (const l of ordenarItems(props.lotes, (x) => [x.codigo ?? ''])) {
      const suyas = ordenarItems(plantasDe.get(l.id) || [], tandaPlantas.ordenPor)
      if (l.codigo_qr) secuencia.push({ item: l, pieza: tandaLotes, pegadoAlSiguiente: suyas.length > 0 })
      for (const p of suyas) secuencia.push({ item: p, pieza: tandaPlantas })
    }
    return { secuencia, archivo }
  }

  // Una sola cosa: su plancha de siempre (9 lotes por hoja apaisada, 10 banderitas por vertical).
  return { tandas: [conLotes.value ? tandaLotes : tandaPlantas], archivo }
}

async function imprimir() {
  const r = await etiquetas.imprimir(config)
  if (r.vacio) toast.warning('No hay nada con código QR para etiquetar')
  else if (!r.ok && r.error) toast.error('No se pudieron generar las etiquetas')
  else if (r.viaDescarga) toast.warning('El navegador bloqueó la ventana: se descargó el PDF')
  if (r.ok) emit('hecho')
}
async function descargar() {
  const r = await etiquetas.descargar(config)
  if (r.vacio) toast.warning('No hay nada con código QR para etiquetar')
  else if (!r.ok && r.error) toast.error('No se pudieron generar las etiquetas')
  else if (r.ok) { toast.success('PDF descargado'); emit('hecho') }
}

function cerrar() { if (!etiquetas.ocupado.value) emit('close') }
</script>

<template>
  <Teleport to="body">
    <div v-if="show" v-modal="cerrar" class="elm-overlay" @click.self="cerrar">
      <div class="elm" role="dialog" aria-labelledby="elm-titulo">
        <div class="elm__header">
          <div>
            <h2 id="elm-titulo" class="elm__title">Imprimir etiquetas</h2>
            <p class="elm__sub">{{ lotes.length }} {{ lotes.length === 1 ? 'lote seleccionado' : 'lotes seleccionados' }}</p>
          </div>
          <button class="elm__close" aria-label="Cerrar" @click="cerrar"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="elm__body">
          <label class="elm__opt">
            <input v-model="conLotes" type="checkbox" />
            <span>
              <strong>Etiquetas de los lotes</strong> ({{ lotesConQR.length }})
              <small v-if="lotesSinQR" class="elm__warn">{{ lotesSinQR }} sin QR: no se imprimen</small>
            </span>
          </label>

          <label class="elm__opt">
            <input v-model="conPlantas" type="checkbox" />
            <span>
              <strong>Banderitas de sus plantas</strong>
              <template v-if="cargando"> (contando…)</template>
              <template v-else-if="!errorCarga"> ({{ plantasConQR.length }})</template>
              <small v-if="errorCarga" class="elm__err">
                No se pudieron traer las plantas.
                <button class="elm__link" @click.prevent="cargarPlantas">Reintentar</button>
              </small>
              <small v-if="plantasSinQR" class="elm__warn">{{ plantasSinQR }} sin QR: no se imprimen</small>
              <small v-if="descartadas" class="elm__muted">{{ descartadas }} descartadas quedan afuera</small>
            </span>
          </label>

          <p v-if="conLotes && conPlantas" class="elm__nota">
            Salen de corrido: la etiqueta de cada lote y debajo las de sus plantas, después el lote
            siguiente.
          </p>
        </div>

        <div class="elm__footer">
          <button class="elm__btn-ghost" :disabled="etiquetas.ocupado.value" @click="cerrar">Cancelar</button>
          <button class="elm__btn" :disabled="!listo || etiquetas.ocupado.value" @click="descargar">
            <i class="bi bi-download"></i> Descargar
          </button>
          <button class="elm__btn elm__btn--main" :disabled="!listo || etiquetas.ocupado.value" @click="imprimir">
            <i class="bi bi-printer"></i> Imprimir {{ cantidad || '' }}
          </button>
        </div>
      </div>
    </div>

    <BloqueoProgreso
      :visible="etiquetas.ocupado.value"
      :titulo="etiquetas.titulo.value"
      :hechas="etiquetas.hechas.value"
      :total="etiquetas.total.value"
    />
  </Teleport>
</template>

<style scoped>
.elm-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1060; padding: 1rem; backdrop-filter: blur(3px);
}
.elm {
  background: #fff; border-radius: 18px; width: 100%; max-width: 480px;
  max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(0,0,0,.15);
}
.elm__header { display: flex; justify-content: space-between; align-items: flex-start; padding: 1.25rem 1.25rem .5rem; }
.elm__title  { font-size: 1.15rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.elm__sub    { font-size: .8rem; color: var(--c-slate-400); margin: .15rem 0 0; }
.elm__close  { background: none; border: none; color: var(--c-slate-400); font-size: 1rem; cursor: pointer; }
.elm__body   { padding: .5rem 1.25rem 1rem; display: flex; flex-direction: column; gap: .75rem; }
.elm__opt    { display: flex; gap: .6rem; align-items: flex-start; font-size: .9rem; color: var(--c-slate-900); cursor: pointer; }
.elm__opt input { margin-top: .2rem; }
.elm__opt small { display: block; font-size: .78rem; margin-top: .15rem; }
.elm__warn   { color: var(--c-amber-500); }
.elm__err    { color: #b91c1c; }
.elm__muted  { color: var(--c-slate-400); }
.elm__link   { background: none; border: none; padding: 0; color: inherit; text-decoration: underline; cursor: pointer; font-size: inherit; }
.elm__nota   { font-size: .8rem; color: var(--c-slate-400); margin: 0; }
.elm__footer { display: flex; justify-content: flex-end; gap: .5rem; padding: .75rem 1.25rem 1.25rem; flex-wrap: wrap; }
.elm__btn-ghost { background: none; border: none; color: var(--c-slate-400); font-weight: 600; cursor: pointer; padding: .5rem .75rem; }
.elm__btn {
  display: inline-flex; align-items: center; gap: .35rem;
  background: var(--c-slate-100); color: var(--c-slate-900); border: none;
  padding: .5rem .9rem; border-radius: 9px; font-size: .85rem; font-weight: 600; cursor: pointer;
}
.elm__btn--main { background: var(--c-leaf-700); color: #fff; }
.elm__btn--main:hover:not(:disabled) { background: var(--c-leaf-800); }
.elm__btn:disabled, .elm__btn-ghost:disabled { opacity: .5; cursor: default; }
</style>
