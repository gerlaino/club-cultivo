<template>
  <div class="rpc" data-testid="renovacion-portal">
    <div class="rpc__hd">
      <FileUp :size="16" />
      <div>
        <b>El paciente subió la renovación de su REPROCANN</b>
        <span>El {{ fecha(renovacion.subida_at) }} desde su portal · espera que la revises</span>
      </div>
    </div>

    <a v-if="renovacion.constancia_url" :href="renovacion.constancia_url" target="_blank" rel="noopener" class="rpc__constancia">
      <img v-if="renovacion.es_imagen" :src="renovacion.constancia_url" :alt="renovacion.constancia_nombre" />
      <span v-else class="rpc__pdf">PDF</span>
      <span>{{ renovacion.constancia_nombre }} · ver la constancia</span>
    </a>

    <template v-if="puedeRevisar">
      <form v-if="!rechazando" class="rpc__form" @submit.prevent="aprobar">
        <label class="rpc__campo">
          <span>Vence el</span>
          <input v-model="vencimiento" type="date" :min="hoy" required data-testid="renovacion-vencimiento" />
        </label>
        <label class="rpc__campo">
          <span>Nº de REPROCANN <i>(si cambió)</i></span>
          <input v-model.trim="numero" type="text" :placeholder="numeroActual || 'Sin cambios'" />
        </label>
        <div class="rpc__acts">
          <button type="submit" class="rpc__btn rpc__btn--ok" :disabled="trabajando || !vencimiento" data-testid="renovacion-aprobar">Aprobar y cargar la fecha</button>
          <button type="button" class="rpc__btn" :disabled="trabajando" @click="rechazando = true">No se puede aprobar</button>
        </div>
      </form>
      <form v-else class="rpc__form" @submit.prevent="rechazar">
        <label class="rpc__campo rpc__campo--ancho">
          <span>¿Por qué? <i>(lo lee el paciente)</i></span>
          <textarea v-model.trim="motivo" rows="2" placeholder="La foto no se lee, subila de nuevo." required />
        </label>
        <div class="rpc__acts">
          <button type="submit" class="rpc__btn rpc__btn--mal" :disabled="trabajando || !motivo">Avisarle al paciente</button>
          <button type="button" class="rpc__btn" :disabled="trabajando" @click="rechazando = false">Volver</button>
        </div>
      </form>
    </template>
    <p v-else class="rpc__nota">La revisa administración o el médico.</p>
  </div>
</template>

<script setup>
// La renovación del REPROCANN que subió el paciente desde su portal (27-oct-2026), en su ficha:
// la constancia y, para quien puede, aprobarla cargando el vencimiento nuevo o devolverla con el
// motivo. Las dos cosas le avisan al paciente.
import { ref } from 'vue'
import { FileUp } from 'lucide-vue-next'
import { updateReprocannRenovacion } from '../../lib/api.js'
import { hoyISO } from '../../utils/dates.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  socioId:      { type: [Number, String], required: true },
  renovacion:   { type: Object, required: true },
  numeroActual: { type: String, default: '' },
  puedeRevisar: { type: Boolean, default: false },
})
const emit = defineEmits(['revisada'])

const toast = useToast()
const hoy = hoyISO()
const vencimiento = ref('')
const numero = ref('')
const motivo = ref('')
const rechazando = ref(false)
const trabajando = ref(false)

const fecha = (f) => (f ? new Date(f).toLocaleDateString('es-AR', { day: 'numeric', month: 'long' }) : '')

async function aprobar() {
  trabajando.value = true
  try {
    await updateReprocannRenovacion(props.socioId, props.renovacion.id, {
      accion: 'aprobar', fecha_vencimiento_nueva: vencimiento.value, reprocann_numero_nuevo: numero.value || undefined,
    })
    toast.success('Renovación aprobada: el paciente ya la ve al día')
    emit('revisada')
  } catch (e) {
    toast.error(e?.response?.data?.errors?.join(', ') || 'No se pudo aprobar')
  } finally {
    trabajando.value = false
  }
}

async function rechazar() {
  trabajando.value = true
  try {
    await updateReprocannRenovacion(props.socioId, props.renovacion.id, { accion: 'rechazar', observaciones: motivo.value })
    toast.success('Le avisamos al paciente')
    emit('revisada')
  } catch (e) {
    toast.error(e?.response?.data?.errors?.join(', ') || 'No se pudo avisar')
  } finally {
    trabajando.value = false
  }
}
</script>

<style scoped>
.rpc { border: 1px solid var(--c-sky-600); background: var(--c-sky-100); border-radius: 12px; padding: 1rem; margin-bottom: 1rem; display: flex; flex-direction: column; gap: .75rem; }
.rpc__hd { display: flex; gap: .6rem; align-items: flex-start; color: var(--c-slate-900); }
.rpc__hd > svg { color: var(--c-sky-600); margin-top: 2px; flex: none; }
.rpc__hd div { display: flex; flex-direction: column; }
.rpc__hd span { font-size: .82rem; color: var(--c-slate-600); }
.rpc__constancia { display: flex; align-items: center; gap: .6rem; background: #fff; border-radius: 10px; padding: .5rem .65rem; text-decoration: none; color: var(--c-slate-900); font-size: .85rem; font-weight: 600; }
.rpc__constancia img { width: 56px; height: 56px; object-fit: cover; border-radius: 8px; }
.rpc__pdf { width: 40px; height: 48px; display: grid; place-items: center; border: 1px solid var(--c-slate-300); border-radius: 6px; font-size: .7rem; font-weight: 800; color: var(--c-rust-600); background: #fff; }
.rpc__form { display: flex; flex-wrap: wrap; gap: .75rem; align-items: flex-end; }
.rpc__campo { display: flex; flex-direction: column; gap: .25rem; font-size: .8rem; font-weight: 600; color: var(--c-slate-700); }
.rpc__campo i { font-weight: 400; color: var(--c-slate-500); }
.rpc__campo--ancho { flex: 1 1 100%; }
.rpc__campo input, .rpc__campo textarea { min-height: 38px; border: 1px solid var(--c-slate-300); border-radius: 8px; padding: .35rem .6rem; font: inherit; font-size: .88rem; background: #fff; }
.rpc__acts { display: flex; gap: .5rem; flex-wrap: wrap; }
.rpc__btn { min-height: 38px; padding: 0 .9rem; border-radius: 8px; border: 1px solid var(--c-slate-300); background: #fff; color: var(--c-slate-900); font-weight: 600; font-size: .85rem; cursor: pointer; }
.rpc__btn:disabled { opacity: .55; cursor: default; }
.rpc__btn--ok { background: var(--c-leaf-700); border-color: var(--c-leaf-700); color: #fff; }
.rpc__btn--mal { background: var(--c-rust-600); border-color: var(--c-rust-600); color: #fff; }
.rpc__nota { margin: 0; font-size: .82rem; color: var(--c-slate-600); }
</style>
