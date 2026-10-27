<template>
  <div class="ch">
    <div ref="lista" class="ch__lista" aria-live="polite">
      <p v-if="!mensajes.length && !cargando" class="ch__vacio">{{ vacio }}</p>
      <template v-for="m in filas" :key="m.key">
        <span v-if="m.dia" class="ch__dia">{{ m.dia }}</span>
        <div v-else class="ch__burbuja" :class="[m.mio ? 'ch__burbuja--mia' : 'ch__burbuja--otra', { 'ch__burbuja--seguida': m.seguida }]" :data-testid="m.mio ? 'msj-mio' : 'msj-otro'">
          <b v-if="m.firma" class="ch__firma">{{ m.firma }}</b>
          <RouterLink v-if="m.dispensa" :to="linkDispensa(m.dispensa)" class="ch__cita">
            <b>Dispensa Nº {{ m.dispensa.numero }}</b>
            <span>{{ m.dispensa.resumen }}</span>
          </RouterLink>
          <a v-if="m.adjunto" :href="m.adjunto.url" target="_blank" rel="noopener" class="ch__adjunto">
            <img v-if="m.adjunto.es_imagen" :src="m.adjunto.url" :alt="m.adjunto.nombre" class="ch__img" />
            <span v-else class="ch__archivo"><span class="ch__pdf" aria-hidden="true">PDF</span>{{ m.adjunto.nombre }}</span>
          </a>
          <span v-if="m.texto" class="ch__texto">{{ m.texto }}</span>
          <span class="ch__meta">
            {{ m.hora }}
            <span v-if="m.mio" class="ch__tilde" :class="{ 'ch__tilde--leido': m.leido }" :aria-label="m.leido ? 'Leído' : 'Enviado'">{{ m.leido ? '✓✓' : '✓' }}</span>
          </span>
        </div>
      </template>
      <div v-if="escribiendo" class="ch__burbuja ch__burbuja--otra ch__puntos" :aria-label="escribiendo">
        <span></span><span></span><span></span>
      </div>
    </div>

    <div v-if="cita" class="ch__cita-pendiente">
      <div><b>{{ cita.titulo }}</b><span>{{ cita.detalle }}</span></div>
      <button type="button" class="ch__x" aria-label="Quitar la referencia" @click="$emit('quitar-cita')">×</button>
    </div>
    <div v-if="archivo" class="ch__cita-pendiente">
      <div><b>{{ archivo.name }}</b><span>Se manda con tu mensaje</span></div>
      <button type="button" class="ch__x" aria-label="Quitar el archivo" @click="archivo = null">×</button>
    </div>

    <slot name="sobre-barra" />
    <form class="ch__barra" @submit.prevent="mandar">
      <input ref="file" type="file" accept="image/*,application/pdf" class="ch__file" @change="elegirArchivo" />
      <button type="button" class="ch__boton-suave" aria-label="Adjuntar una foto o un PDF" :disabled="enviando" @click="$refs.file.click()">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 11l-8.5 8.5a5 5 0 0 1-7-7L14 4a3.5 3.5 0 0 1 5 5l-8.5 8.5a2 2 0 0 1-3-3L15 7"/></svg>
      </button>
      <label :for="idTexto" class="ch__sr">Escribí un mensaje</label>
      <textarea :id="idTexto" ref="texto" v-model="borrador" rows="1" class="ch__input" :placeholder="placeholder"
                :disabled="enviando" @keydown="tecla" @input="alEscribir" />
      <button type="submit" class="ch__enviar" aria-label="Enviar" :disabled="enviando || (!borrador.trim() && !archivo)">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 12l16-8-6 16-2.5-6.5z"/></svg>
      </button>
    </form>
  </div>
</template>

<script setup>
// El chat del portal, el mismo para los dos lados (27-oct-2026): el paciente en su portal y
// administración en la ficha y en la bandeja. Burbujas, día por día, tildes (✓ enviado, ✓✓ en
// azul leído), «está escribiendo…» y Enter para mandar (Shift+Enter, renglón nuevo).
//
// No pide nada: recibe los mensajes y emite `enviar`. Quién pide y a dónde manda lo decide la
// pantalla que lo usa.
import { computed, nextTick, ref, watch } from 'vue'
import { achicarImagen } from '../../lib/imagenes.js'

const props = defineProps({
  mensajes:  { type: Array, default: () => [] },
  // Qué lado es «el mío»: `paciente` en el portal, `organizacion` en la ficha y la bandeja.
  lado:      { type: String, required: true },
  // Hasta cuándo leyó el OTRO lado: de ahí salen los ✓✓ de mis mensajes.
  leidoHasta: { type: String, default: null },
  escribiendo: { type: String, default: null },
  cita:      { type: Object, default: null },
  enviando:  { type: Boolean, default: false },
  cargando:  { type: Boolean, default: false },
  vacio:     { type: String, default: 'Todavía no hay mensajes.' },
  placeholder: { type: String, default: 'Escribí un mensaje' },
  // A dónde lleva la dispensa citada (la del portal o la de la ficha).
  linkDispensa: { type: Function, default: (d) => ({ name: 'portal-dispensa', params: { id: d.id } }) },
})
const emit = defineEmits(['enviar', 'escribiendo', 'quitar-cita'])

const borrador = ref('')
const archivo = ref(null)
const lista = ref(null)
const texto = ref(null)
const idTexto = `ch-${Math.random().toString(36).slice(2, 8)}`

const DIAS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado']
const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']

function nombreDelDia(fecha) {
  const hoy = new Date(); hoy.setHours(0, 0, 0, 0)
  const d = new Date(fecha); d.setHours(0, 0, 0, 0)
  const dias = Math.round((hoy - d) / 86400000)
  if (dias === 0) return 'Hoy'
  if (dias === 1) return 'Ayer'
  if (dias < 7) return DIAS[d.getDay()].replace(/^./, (c) => c.toUpperCase())
  return `${d.getDate()} de ${MESES[d.getMonth()]}`
}

const filas = computed(() => {
  const out = []
  let diaAnterior = null
  let anterior = null
  for (const m of props.mensajes) {
    const dia = nombreDelDia(m.at)
    if (dia !== diaAnterior) { out.push({ key: `d-${m.id}`, dia }); diaAnterior = dia; anterior = null }
    const mio = m.autor === props.lado
    const seguida = anterior && anterior.autor === m.autor && anterior.quien === m.quien
    out.push({
      key: m.id, mio, seguida, texto: m.texto, adjunto: m.adjunto, dispensa: m.dispensa,
      // Del lado del paciente, la organización firma con el nombre de quien contestó.
      firma: !mio && !seguida && m.quien ? m.quien : null,
      hora: new Date(m.at).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }),
      leido: mio && !!props.leidoHasta && new Date(props.leidoHasta) >= new Date(m.at),
    })
    anterior = m
  }
  return out
})

async function alFondo() {
  await nextTick()
  if (lista.value) lista.value.scrollTop = lista.value.scrollHeight
}
watch(() => [props.mensajes.length, !!props.escribiendo], alFondo, { immediate: true })

// «Está escribiendo»: como mucho un aviso cada 2,5 s mientras teclea.
let ultimoAviso = 0
function alEscribir() {
  const ahora = Date.now()
  if (ahora - ultimoAviso > 2500) { ultimoAviso = ahora; emit('escribiendo') }
  if (texto.value) { texto.value.style.height = 'auto'; texto.value.style.height = `${Math.min(texto.value.scrollHeight, 140)}px` }
}

function tecla(e) {
  if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); mandar() }
}

async function elegirArchivo(e) {
  const f = e.target.files?.[0]
  e.target.value = ''
  if (!f) return
  // Las fotos se achican antes de subir (la del teléfono pesa 4-8 MB); el PDF va como está.
  archivo.value = f.type.startsWith('image/') ? await achicarImagen(f).catch(() => f) : f
}

function mandar() {
  const t = borrador.value.trim()
  if ((!t && !archivo.value) || props.enviando) return
  emit('enviar', { texto: t, archivo: archivo.value })
  borrador.value = ''
  archivo.value = null
  if (texto.value) texto.value.style.height = 'auto'
}

defineExpose({ enfocar: () => texto.value?.focus() })
</script>

<style scoped>
.ch { display: flex; flex-direction: column; min-height: 0; height: 100%; }
.ch__lista {
  flex: 1; min-height: 0; overflow-y: auto; padding: 1rem 1rem .5rem; display: flex; flex-direction: column; gap: 3px;
  background: var(--c-paper);
}
.ch__vacio { margin: auto; color: var(--c-ink-500); font-size: .9rem; text-align: center; max-width: 300px; }
.ch__dia {
  align-self: center; margin: .7rem 0 .35rem; font-size: .75rem; font-weight: 600; color: var(--c-ink-500);
  background: #fff; border-radius: 999px; padding: .15rem .75rem; box-shadow: 0 1px 1px rgba(0,0,0,.05);
}
.ch__burbuja {
  max-width: min(75%, 520px); padding: .45rem .7rem .3rem; border-radius: 14px; font-size: .93rem; line-height: 1.4;
  box-shadow: 0 1px 1px rgba(0,0,0,.07); margin-top: .45rem; display: flex; flex-direction: column; gap: .2rem;
}
.ch__burbuja--seguida { margin-top: 2px; }
.ch__burbuja--otra { align-self: flex-start; background: #fff; color: var(--c-ink-900); border-top-left-radius: 4px; }
.ch__burbuja--mia { align-self: flex-end; background: var(--c-leaf-100); color: var(--c-ink-900); border-top-right-radius: 4px; }
.ch__firma { font-size: .78rem; color: var(--c-leaf-700); }
.ch__texto { white-space: pre-wrap; word-break: break-word; }
.ch__meta { align-self: flex-end; font-size: .7rem; color: var(--c-ink-500); display: inline-flex; gap: .25rem; align-items: center; }
.ch__tilde { font-weight: 700; letter-spacing: -2px; }
.ch__tilde--leido { color: var(--c-sky-600); }
.ch__cita {
  display: flex; flex-direction: column; border-left: 3px solid var(--c-leaf-600); background: rgba(255,255,255,.6);
  border-radius: 8px; padding: .3rem .55rem; text-decoration: none; color: var(--c-ink-900); font-size: .82rem;
}
.ch__cita span { color: var(--c-ink-500); }
.ch__adjunto { display: block; text-decoration: none; color: var(--c-ink-900); }
.ch__img { max-width: 240px; max-height: 240px; border-radius: 10px; display: block; }
.ch__archivo { display: inline-flex; align-items: center; gap: .5rem; background: var(--c-paper); border-radius: 9px; padding: .45rem .6rem; font-size: .85rem; }
.ch__pdf { font-size: .65rem; font-weight: 800; color: var(--c-rust-600); border: 1px solid var(--c-ink-300); border-radius: 4px; padding: .3rem .25rem; background: #fff; }

.ch__puntos { flex-direction: row; gap: 4px; padding: .7rem .8rem; }
.ch__puntos span { width: 7px; height: 7px; border-radius: 50%; background: var(--c-ink-300); animation: ch-punto 1.2s infinite; }
.ch__puntos span:nth-child(2) { animation-delay: .2s; }
.ch__puntos span:nth-child(3) { animation-delay: .4s; }
@keyframes ch-punto { 0%, 60%, 100% { opacity: .35; transform: none } 30% { opacity: 1; transform: translateY(-3px) } }

.ch__cita-pendiente {
  display: flex; align-items: center; gap: .5rem; padding: .45rem .8rem; background: #fff; border-top: 1px solid var(--c-ink-100);
}
.ch__cita-pendiente > div { flex: 1; min-width: 0; display: flex; flex-direction: column; border-left: 3px solid var(--c-leaf-600); padding-left: .55rem; font-size: .82rem; }
.ch__cita-pendiente span { color: var(--c-ink-500); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ch__x { width: 34px; height: 34px; border: 0; background: transparent; font-size: 1.2rem; color: var(--c-ink-500); cursor: pointer; }

.ch__barra { display: flex; align-items: flex-end; gap: .45rem; padding: .55rem .65rem; background: #fff; border-top: 1px solid var(--c-ink-100); }
.ch__file { display: none; }
.ch__sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }
.ch__input {
  flex: 1; min-width: 0; min-height: 44px; max-height: 140px; resize: none; border: 1px solid var(--c-ink-300); border-radius: 22px;
  padding: .6rem 1rem; font: inherit; font-size: .95rem; line-height: 1.35; color: var(--c-ink-900); background: #fff;
}
.ch__input:focus { outline: 2px solid var(--c-leaf-300); border-color: var(--c-leaf-500); }
.ch__boton-suave { width: 44px; height: 44px; flex: none; border-radius: 50%; border: 0; background: transparent; color: var(--c-ink-500); cursor: pointer; display: grid; place-items: center; }
.ch__enviar { width: 46px; height: 46px; flex: none; border-radius: 50%; border: 0; background: var(--c-leaf-700); color: #fff; cursor: pointer; display: grid; place-items: center; }
.ch__enviar:disabled { background: var(--c-ink-300); cursor: default; }
</style>
