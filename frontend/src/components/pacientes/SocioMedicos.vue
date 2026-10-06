<template>
  <div class="smd">
    <div class="smd__head">
      <span class="smd__title"><Stethoscope :size="15" /> Médicos que lo atienden</span>
    </div>

    <p v-if="!medicos.length" class="smd__vacio">
      Ningún médico todavía.
      <template v-if="puedeEditar">Vinculale uno: es el que lo va a poder ver.</template>
    </p>
    <ul v-else class="smd__lista">
      <li v-for="m in medicos" :key="m.medico_id" class="smd__item">
        <span>{{ m.nombre }}</span>
        <button v-if="puedeEditar" type="button" class="smd__quitar" :disabled="trabajando"
                :aria-label="`Desvincular a ${m.nombre}`" @click="quitar(m)">
          <X :size="14" />
        </button>
      </li>
    </ul>

    <div v-if="puedeEditar && disponibles.length" class="smd__agregar">
      <select v-model="elegido" class="smd__select" :disabled="trabajando" aria-label="Médico a vincular">
        <option value="">Vincular un médico…</option>
        <option v-for="m in disponibles" :key="m.id" :value="m.id">{{ m.nombre_completo }}</option>
      </select>
      <button type="button" class="smd__btn" :disabled="!elegido || trabajando" @click="agregar">Vincular</button>
    </div>
    <p class="smd__nota">El médico ve sólo a los pacientes vinculados a él. Darle un turno también lo vincula.</p>
  </div>
</template>

<script setup>
// LOS MÉDICOS DE UN PACIENTE (Javi y Germán, 6-oct-2026). Un paciente puede tener más de uno; el
// médico ve sólo a sus vinculados (lo aplica el backend). Administración vincula y desvincula;
// el médico sólo ve la lista.
import { ref, computed, onMounted } from 'vue'
import { Stethoscope, X } from 'lucide-vue-next'
import { getAdminMedicos, vincularMedico, desvincularMedico } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'

const props = defineProps({
  pacienteId:  { type: Number, required: true },
  // Los que vienen en la ficha (`medicos` del show): [{ medico_id, nombre }].
  medicos:     { type: Array, default: () => [] },
  puedeEditar: { type: Boolean, default: false },
})
const emit = defineEmits(['cambio'])
const toast = useToast()
const { confirm } = useConfirm()

const todos = ref([])
const elegido = ref('')
const trabajando = ref(false)

const disponibles = computed(() => todos.value.filter(m => !props.medicos.some(v => v.medico_id === m.id)))

onMounted(async () => {
  if (!props.puedeEditar) return
  try { todos.value = (await getAdminMedicos()).data || [] } catch { todos.value = [] }
})

async function agregar() {
  trabajando.value = true
  try {
    await vincularMedico(props.pacienteId, Number(elegido.value))
    elegido.value = ''
    toast.success('Médico vinculado')
    emit('cambio')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo vincular')
  } finally {
    trabajando.value = false
  }
}

async function quitar(m) {
  const ok = await confirm({
    title: `¿Desvincular a ${m.nombre}?`,
    message: 'Deja de ver a este paciente: su ficha, su historia clínica y sus indicaciones.',
    confirmText: 'Desvincular',
  })
  if (!ok) return
  trabajando.value = true
  try {
    await desvincularMedico(props.pacienteId, m.medico_id)
    toast.success('Médico desvinculado')
    emit('cambio')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo desvincular')
  } finally {
    trabajando.value = false
  }
}
</script>

<style scoped>
.smd { display: flex; flex-direction: column; gap: .7rem; }
.smd__head { display: flex; align-items: center; justify-content: space-between; }
.smd__title { display: inline-flex; align-items: center; gap: .45rem; font-weight: 700; font-size: .92rem; color: var(--c-ink-950); }
.smd__vacio { margin: 0; font-size: .85rem; color: var(--c-slate-500); }
.smd__lista { list-style: none; margin: 0; padding: 0; display: flex; flex-wrap: wrap; gap: .45rem; }
.smd__item { display: inline-flex; align-items: center; gap: .35rem; padding: .3rem .4rem .3rem .75rem; border-radius: 999px; background: var(--c-leaf-50); border: 1px solid var(--c-leaf-100); font-size: .85rem; font-weight: 600; color: var(--c-leaf-900); }
.smd__quitar { display: grid; place-items: center; width: 22px; height: 22px; border: none; border-radius: 50%; background: transparent; color: var(--c-slate-500); cursor: pointer; }
.smd__quitar:hover { background: var(--c-slate-100); color: var(--c-rust-600); }
.smd__agregar { display: flex; gap: .5rem; flex-wrap: wrap; }
.smd__select { flex: 1 1 200px; min-height: 38px; border: 1.5px solid var(--c-slate-200); border-radius: 10px; padding: 0 .7rem; font-size: .88rem; background: var(--c-paper); }
.smd__btn { min-height: 38px; padding: 0 1rem; border: none; border-radius: 10px; background: var(--c-leaf-800); color: var(--c-paper); font-weight: 700; font-size: .85rem; cursor: pointer; }
.smd__btn:disabled { opacity: .45; cursor: not-allowed; }
.smd__nota { margin: 0; font-size: .75rem; color: var(--c-slate-400); }
</style>
