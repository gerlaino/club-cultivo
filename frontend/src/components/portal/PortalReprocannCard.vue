<template>
  <section id="reprocann" class="prc" aria-labelledby="prc-t">
    <div class="prc__hd">
      <h2 id="prc-t" class="prc__t">Mi REPROCANN</h2>
      <span v-if="estado" class="prc__pill" :class="`prc__pill--${estado.nivel}`" data-testid="reprocann-estado">{{ estado.texto }}</span>
    </div>

    <div v-if="cargando" class="prc__cargando"><DsSpinner :size="24" /></div>
    <template v-else-if="datos">
      <p class="prc__dato">
        <template v-if="datos.reprocann?.numero">Nº {{ datos.reprocann.numero }} · </template>
        <template v-if="datos.reprocann?.vencimiento">vence el {{ fecha(datos.reprocann.vencimiento) }}</template>
        <template v-else>Sin vencimiento cargado</template>
      </p>

      <!-- En revisión: lo que subió todavía no cambió nada -->
      <p v-if="renov?.estado === 'en_tramite'" class="prc__nota prc__nota--info" data-testid="renovacion-en-revision">
        Subiste la constancia el {{ fecha(renov.subida_at) }}. Tu organización la revisa y te avisa; mientras, seguís retirando como siempre.
      </p>
      <p v-else-if="renov?.estado === 'aprobada' && recienAprobada" class="prc__nota prc__nota--ok">
        Tu organización aprobó la renovación: vence el {{ fecha(renov.vencimiento_nuevo) }}.
      </p>
      <p v-else-if="renov?.estado === 'rechazada'" class="prc__nota prc__nota--mal">
        Tu organización no pudo aprobar la constancia que subiste<template v-if="renov.observaciones">: «{{ renov.observaciones }}»</template>. Subila de nuevo.
      </p>

      <label class="prc__subir" :class="{ 'prc__subir--off': subiendo }" data-testid="subir-renovacion">
        <input type="file" accept="image/*,application/pdf" class="prc__file" :disabled="subiendo" @change="subir" />
        <DsSpinner v-if="subiendo" :size="18" />
        <template v-else>
          <b>{{ renov?.estado === 'en_tramite' ? 'Subir otra constancia' : 'Subir la constancia de renovación' }}</b>
          <span>Una foto o el PDF que te dio el Ministerio. La revisa tu organización.</span>
        </template>
      </label>
      <p v-if="error" class="prc__nota prc__nota--mal" role="alert">{{ error }}</p>
    </template>
  </section>
</template>

<script setup>
// El REPROCANN del paciente y su renovación (27-oct-2026): ve hasta cuándo vale y sube la
// constancia de renovación desde el teléfono. Queda «en revisión» hasta que la organización la
// aprueba (y carga la fecha nueva) o la rechaza con el motivo. En vivo por `PacienteChannel`
// (recurso `papeles`): cuando la revisan, esto se actualiza solo.
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { getPortalPapeles, subirRenovacionReprocann } from '@/lib/portalApi'
import { achicarImagen } from '@/lib/imagenes.js'
import { alCambiar } from '@/lib/cambios.js'
import DsSpinner from '@/design-system/components/Spinner.vue'

const datos = ref(null)
const cargando = ref(true)
const subiendo = ref(false)
const error = ref(null)

const renov = computed(() => datos.value?.renovacion || null)
// Una aprobación se celebra un mes; después es la de siempre y no hace falta decirla.
const recienAprobada = computed(() => renov.value?.revisada_at && (Date.now() - new Date(renov.value.revisada_at)) < 30 * 86400000)

const ESTADOS = {
  vigente:       { nivel: 'ok', texto: 'Vigente' },
  por_vencer:    { nivel: 'atencion', texto: 'Por vencer' },
  vencido:       { nivel: 'urgente', texto: 'Vencido' },
  pendiente:     { nivel: 'atencion', texto: 'Trámite en curso' },
  sin_reprocann: { nivel: 'atencion', texto: 'Sin cargar' },
}
const estado = computed(() => {
  if (renov.value?.estado === 'en_tramite') return { nivel: 'info', texto: 'Renovación en revisión' }
  return ESTADOS[datos.value?.reprocann?.categoria] || null
})

const fecha = (f) => (f ? new Date(String(f).length === 10 ? `${f}T00:00:00` : f).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' }) : '')

async function cargar() {
  try { datos.value = await getPortalPapeles() } catch { datos.value = null } finally { cargando.value = false }
}

async function subir(e) {
  const f = e.target.files?.[0]
  e.target.value = ''
  if (!f) return
  subiendo.value = true
  error.value = null
  try {
    const archivo = f.type.startsWith('image/') ? await achicarImagen(f).catch(() => f) : f
    await subirRenovacionReprocann(archivo)
    await cargar()
  } catch (err) {
    error.value = err?.response?.data?.error || 'No se pudo subir. Probá de nuevo.'
  } finally {
    subiendo.value = false
  }
}

let soltar = null
onMounted(() => { cargar(); soltar = alCambiar('papeles', cargar) })
onUnmounted(() => soltar?.())
</script>

<style scoped>
.prc { background: var(--p-papel); border: 1px solid var(--p-linea); border-radius: var(--p-radio); padding: 1.1rem 1.2rem; margin-bottom: 1.5rem; scroll-margin-top: 80px; }
.prc__hd { display: flex; justify-content: space-between; align-items: center; gap: .5rem; flex-wrap: wrap; }
.prc__t { font-size: 1.05rem; font-weight: 800; color: var(--p-tinta); margin: 0; }
.prc__pill { font-size: .75rem; font-weight: 700; padding: .2rem .6rem; border-radius: 999px; }
.prc__pill--ok { background: var(--p-marca-suave); color: var(--p-ok); }
.prc__pill--atencion { background: var(--p-atencion-bg); color: var(--p-atencion); }
.prc__pill--urgente { background: var(--p-urgente-bg); color: var(--p-urgente); }
.prc__pill--info { background: var(--c-sky-100); color: var(--c-sky-600); }
.prc__cargando { padding: 1rem; display: flex; justify-content: center; }
.prc__dato { margin: .4rem 0 .8rem; color: var(--p-suave); font-size: .92rem; }
.prc__nota { margin: 0 0 .8rem; padding: .65rem .8rem; border-radius: 12px; font-size: .88rem; line-height: 1.45; }
.prc__nota--info { background: var(--c-sky-100); color: var(--c-slate-700); }
.prc__nota--ok { background: var(--p-marca-suave); color: var(--p-tinta); }
.prc__nota--mal { background: var(--p-urgente-bg); color: var(--p-urgente); }
.prc__subir {
  display: flex; flex-direction: column; align-items: center; gap: .2rem; text-align: center; cursor: pointer;
  border: 1.5px dashed var(--p-marca-linea); border-radius: 14px; padding: 1rem; background: var(--p-hundido); color: var(--p-tinta);
}
.prc__subir span { font-size: .82rem; color: var(--p-suave); }
.prc__subir--off { cursor: default; opacity: .7; }
.prc__file { position: absolute; width: 1px; height: 1px; opacity: 0; }
.prc__subir:focus-within { outline: 2px solid var(--p-marca-linea); }
</style>
