<template>
  <div class="use">
    <div v-if="loading" class="use__loading"><DsSpinner :size="18" /></div>

    <template v-else>
      <!-- Las sedes como chips que se prenden y apagan, igual que las salas de abajo: un
           desplegable con «Confirmar» para elegir entre dos o tres sedes eran tres clics y un
           lenguaje distinto al de la fila siguiente (Germán, 13-sep-2026). -->
      <div v-if="todasLasSedes.length" class="use__grid">
        <button v-for="sede in todasLasSedes" :key="sede.id" type="button" class="use__sede"
                :class="{ 'use__sede--on': isAsignada(sede) }"
                :disabled="toggling !== null || !puedeEditar"
                :title="isAsignada(sede) ? 'Quitar esta sede' : 'Asignar esta sede'"
                @click="toggle(sede)">
          <span class="use__sede-ico">
            <DsSpinner v-if="toggling === sede.id" :size="12" />
            <i v-else-if="isAsignada(sede)" class="bi bi-check-lg"></i>
            <i v-else class="bi bi-plus-lg"></i>
          </span>
          <span class="use__sede-nombre">{{ sede.nombre }}</span>
          <span class="use__sede-tipo">{{ tipoLabel(sede.tipo) }}</span>
        </button>
      </div>
      <div v-else class="use__empty"><i class="bi bi-building-dash"></i> La organización no tiene sedes cargadas.</div>

      <p class="use__nota">
        <i class="bi bi-info-circle"></i>
        <template v-if="sedesAsignadas.length">Ve sólo lo de {{ sedesAsignadas.length === 1 ? 'esta sede' : 'estas sedes' }}.</template>
        <template v-else>Sin sedes asignadas ve toda la organización.</template>
      </p>
    </template>

    <div v-if="error" class="use__error"><i class="bi bi-exclamation-triangle-fill"></i> {{ error }}</div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { logger } from '../utils/logger.js'
import { useAuthStore } from '../stores/auth'
import { sedesParaRol } from '../lib/roles.js'
import { getUserSedesAsignadas, asignarSedeAUsuario, desasignarSedeAUsuario, listSedes } from '../lib/api.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const props = defineProps({
  userId:   { type: Number, required: true },
  userRole: { type: String, default: '' },
})
// Las sedes asignadas, cada vez que cambian: el manager de salas se acota a ellas.
const emit = defineEmits(['change'])

const auth           = useAuthStore()
const sedesAsignadas = ref([])
const todasLasSedes  = ref([])
const loading        = ref(false)
const toggling       = ref(null)
const error          = ref('')

const puedeEditar = computed(() => auth.user?.role === 'admin')

const TIPO = { social: 'dispensario', produccion: 'producción', mixta: 'mixta' }
const tipoLabel = (t) => TIPO[t] || t || ''
const isAsignada = (sede) => sedesAsignadas.value.some(s => s.id === sede.id)
const avisar = () => emit('change', sedesAsignadas.value.map(s => s.id))

onMounted(async () => {
  loading.value = true
  try {
    const [resSedes, resTodas] = await Promise.all([
      getUserSedesAsignadas(props.userId),
      listSedes(),
    ])
    sedesAsignadas.value = resSedes.data || []
    // Sólo las sedes donde este rol tiene algo que hacer (regla del backend, vía /me), más las
    // que ya tenga de antes aunque hoy no se ofrezcan: se ven para poder quitarlas.
    const ofrecidas = sedesParaRol(props.userRole, resTodas.data || [], auth.user?.reglas_cultivo)
    todasLasSedes.value  = [...ofrecidas, ...sedesAsignadas.value.filter(a => !ofrecidas.some(o => o.id === a.id))]
    // Sin permiso de edición igual se ven las asignadas, marcadas.
    if (!puedeEditar.value) todasLasSedes.value = sedesAsignadas.value
    avisar()
  } catch (e) { logger.error(e) }
  finally { loading.value = false }
})

async function toggle(sede) {
  if (!puedeEditar.value) return
  error.value = ''
  toggling.value = sede.id
  try {
    if (isAsignada(sede)) {
      await desasignarSedeAUsuario(props.userId, sede.id)
      sedesAsignadas.value = sedesAsignadas.value.filter(s => s.id !== sede.id)
    } else {
      await asignarSedeAUsuario(props.userId, sede.id)
      sedesAsignadas.value = [...sedesAsignadas.value, sede]
    }
    avisar()
  } catch (e) {
    error.value = e.response?.data?.error || 'No se pudo actualizar la sede'
    logger.error(e)
  } finally { toggling.value = null }
}
</script>

<style scoped>
.use { display: flex; flex-direction: column; gap: .6rem; }
.use__loading { display: flex; justify-content: center; padding: .5rem 0; }
.use__grid { display: flex; flex-wrap: wrap; gap: .4rem; }
.use__sede {
  display: inline-flex; align-items: center; gap: .45rem;
  padding: .45rem .8rem; border-radius: 9px;
  border: 1.5px solid var(--c-slate-200); background: var(--c-slate-50);
  font-size: .82rem; font-weight: 500; color: var(--c-slate-600);
  cursor: pointer; transition: all .15s; font-family: inherit;
}
.use__sede:hover:not(:disabled) { border-color: var(--c-leaf-300); background: var(--c-leaf-50); color: var(--c-leaf-800); }
.use__sede--on { border-color: var(--c-leaf-800); background: var(--c-leaf-100); color: var(--c-leaf-800); font-weight: 600; }
.use__sede--on:hover:not(:disabled) { border-color: var(--c-rust-600); background: var(--c-rust-100); color: var(--c-rust-600); }
.use__sede:disabled { opacity: .55; cursor: not-allowed; }
.use__sede-ico { width: 16px; height: 16px; display: flex; align-items: center; justify-content: center; font-size: .75rem; flex-shrink: 0; }
.use__sede-nombre { font-weight: inherit; }
.use__sede-tipo { font-size: .68rem; color: var(--c-slate-400); font-weight: 400; }
.use__empty { font-size: .82rem; color: var(--c-slate-500); }
.use__nota { margin: 0; font-size: .74rem; color: var(--c-slate-500); display: flex; align-items: center; gap: .35rem; }
.use__error { font-size: .78rem; color: var(--c-rust-600); display: flex; align-items: center; gap: .35rem; }
</style>
