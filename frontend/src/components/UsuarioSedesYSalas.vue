<template>
  <div class="uss">
    <div v-if="loading" class="uss__loading"><DsSpinner :size="18" /></div>

    <template v-else>
      <!-- UNA SEDE, Y ADENTRO SUS SALAS (Germán, 13-sep-2026): se asigna la sede y ahí mismo
           aparecen sus salas para elegir. Sin sede asignada no hay salas que elegir — la sede
           es la puerta—, y sin ninguna sede, la persona ve toda la organización. -->
      <div v-for="sede in sedes" :key="sede.id" class="uss__sede" :class="{ 'uss__sede--on': isSede(sede) }">
        <button type="button" class="uss__chip uss__chip--sede" :class="{ 'uss__chip--on': isSede(sede) }"
                :disabled="ocupado || !puedeEditar"
                :title="isSede(sede) ? 'Quitar esta sede (y sus salas)' : 'Asignar esta sede'"
                @click="toggleSede(sede)">
          <span class="uss__ico">
            <DsSpinner v-if="toggling === `sede-${sede.id}`" :size="12" />
            <i v-else-if="isSede(sede)" class="bi bi-check-lg"></i>
            <i v-else class="bi bi-plus-lg"></i>
          </span>
          <span class="uss__nombre">{{ sede.nombre }}</span>
          <span class="uss__tipo">{{ tipoLabel(sede.tipo) }}</span>
        </button>

        <!-- Las salas de ESA sede, sólo con la sede asignada. -->
        <div v-if="isSede(sede)" class="uss__salas">
          <template v-if="salasDe(sede).length">
            <button v-for="sala in salasDe(sede)" :key="sala.id" type="button" class="uss__chip uss__chip--sala"
                    :class="{ 'uss__chip--on': isSala(sala) }" :disabled="ocupado || !puedeEditar"
                    :title="isSala(sala) ? 'Quitar esta sala' : 'Asignar esta sala'"
                    @click="toggleSala(sala)">
              <span class="uss__ico">
                <DsSpinner v-if="toggling === `sala-${sala.id}`" :size="12" />
                <i v-else-if="isSala(sala)" class="bi bi-check-lg"></i>
                <i v-else class="bi bi-plus-lg"></i>
              </span>
              <span class="uss__nombre">{{ sala.nombre }}</span>
            </button>
          </template>
          <span v-else class="uss__sin-salas">{{ sinSalasTexto(sede) }}</span>
        </div>
      </div>
      <div v-if="!sedes.length" class="uss__vacio"><i class="bi bi-building-dash"></i> La organización no tiene sedes cargadas.</div>

      <p class="uss__nota">
        <i class="bi bi-info-circle"></i>
        <template v-if="!sedesAsignadas.length">Sin sedes asignadas ve toda la organización.</template>
        <template v-else-if="!salasAsignadas.length">Ve todo lo de {{ sedesAsignadas.length === 1 ? 'esta sede' : 'estas sedes' }}; sin salas marcadas, todas sus salas.</template>
        <template v-else>Ve {{ salasAsignadas.length === 1 ? 'la sala marcada' : `las ${salasAsignadas.length} salas marcadas` }} de {{ sedesAsignadas.length === 1 ? 'esta sede' : 'estas sedes' }}.</template>
      </p>
      <p v-if="esManicurador" class="uss__nota uss__nota--warn"><i class="bi bi-info-circle"></i> Un manicura tiene una sola sala: elegir otra la reemplaza.</p>
    </template>

    <div v-if="error" class="uss__error"><i class="bi bi-exclamation-triangle-fill"></i> {{ error }}</div>
  </div>
</template>

<script setup>
// SEDES Y SALAS DE UN USUARIO, ANIDADAS. Reemplaza a `UsuarioSedesManager` + `UsuarioSalasManager`
// puestos uno debajo del otro: la sede es la puerta y las salas cuelgan de ella. Mismo backend
// (cuatro endpoints de asignar/desasignar); acá sólo cambia cómo se presenta.
import { ref, computed, onMounted } from 'vue'
import DsSpinner from '../design-system/components/Spinner.vue'
import { logger } from '../utils/logger.js'
import { useAuthStore } from '../stores/auth'
import { sedesParaRol } from '../lib/roles.js'
import {
  getUserSedesAsignadas, asignarSedeAUsuario, desasignarSedeAUsuario, listSedes,
  getUserSalasAsignadas, asignarSalaAUsuario, desasignarSalaAUsuario, listSalas,
} from '../lib/api.js'

const props = defineProps({
  userId:   { type: Number, required: true },
  userRole: { type: String, default: '' },
})

const auth           = useAuthStore()
const sedesAsignadas = ref([])
const salasAsignadas = ref([])
const todasLasSedes  = ref([])
const todasLasSalas  = ref([])
const loading        = ref(false)
const toggling       = ref(null)
const error          = ref('')

const puedeEditar   = computed(() => auth.user?.role === 'admin')
const esManicurador = computed(() => props.userRole === 'manicura')
const ocupado       = computed(() => toggling.value !== null)

const TIPO = { social: 'dispensario', produccion: 'producción', mixta: 'mixta' }
const tipoLabel = (t) => TIPO[t] || t || ''
const isSede = (sede) => sedesAsignadas.value.some(s => s.id === sede.id)
const isSala = (sala) => salasAsignadas.value.some(s => s.id === sala.id)

// Sólo las sedes donde este rol tiene algo que hacer (regla del backend, vía /me), más las que
// ya tenga asignadas de antes aunque hoy no se ofrezcan: se ven, marcadas, para poder quitarlas.
// Sin permiso de edición se ven sólo las asignadas.
const sedes = computed(() => {
  if (!puedeEditar.value) return sedesAsignadas.value
  const ofrecidas = sedesParaRol(props.userRole, todasLasSedes.value, auth.user?.reglas_cultivo)
  const heredadas = sedesAsignadas.value.filter(a => !ofrecidas.some(o => o.id === a.id))
  return [...ofrecidas, ...heredadas]
})

// Las salas de cultivo de esa sede (las de manicura para un manicura). Una sede de dispensario
// no tiene salas de cultivo: se asigna igual —la persona ve esa sede— y lo dice.
const salasDe = (sede) => todasLasSalas.value.filter(s =>
  s.sede?.id === sede.id && (esManicurador.value ? s.kind === 'manicura' : s.kind !== 'manicura'))
const sinSalasTexto = (sede) => ['produccion', 'mixta'].includes(sede.tipo)
  ? 'Esta sede no tiene salas de cultivo todavía.'
  : 'Es una sede de dispensario: no tiene salas de cultivo.'

onMounted(async () => {
  loading.value = true
  try {
    const [rSedes, rSalas, rTodasSedes, rTodasSalas] = await Promise.all([
      getUserSedesAsignadas(props.userId), getUserSalasAsignadas(props.userId),
      listSedes(), puedeEditar.value ? listSalas() : Promise.resolve({ data: [] }),
    ])
    sedesAsignadas.value = rSedes.data || []
    salasAsignadas.value = rSalas.data || []
    todasLasSedes.value  = rTodasSedes.data || []
    todasLasSalas.value  = puedeEditar.value ? (rTodasSalas.data || []) : salasAsignadas.value
  } catch (e) { logger.error(e) }
  finally { loading.value = false }
})

async function toggleSede(sede) {
  if (!puedeEditar.value) return
  error.value = ''
  toggling.value = `sede-${sede.id}`
  try {
    if (isSede(sede)) {
      // Quitar la sede se lleva sus salas: una sala de una sede que no ve no significa nada.
      for (const sala of salasAsignadas.value.filter(s => s.sede?.id === sede.id)) {
        await desasignarSalaAUsuario(props.userId, sala.id)
        salasAsignadas.value = salasAsignadas.value.filter(s => s.id !== sala.id)
      }
      await desasignarSedeAUsuario(props.userId, sede.id)
      sedesAsignadas.value = sedesAsignadas.value.filter(s => s.id !== sede.id)
    } else {
      await asignarSedeAUsuario(props.userId, sede.id)
      sedesAsignadas.value = [...sedesAsignadas.value, sede]
    }
  } catch (e) {
    error.value = e.response?.data?.error || 'No se pudo actualizar la sede'
    logger.error(e)
  } finally { toggling.value = null }
}

async function toggleSala(sala) {
  if (!puedeEditar.value) return
  error.value = ''
  toggling.value = `sala-${sala.id}`
  try {
    if (isSala(sala)) {
      await desasignarSalaAUsuario(props.userId, sala.id)
      salasAsignadas.value = salasAsignadas.value.filter(s => s.id !== sala.id)
    } else {
      await asignarSalaAUsuario(props.userId, sala.id)
      salasAsignadas.value = esManicurador.value ? [sala] : [...salasAsignadas.value, sala]
    }
  } catch (e) {
    error.value = e.response?.data?.error || 'No se pudo actualizar la sala'
    logger.error(e)
  } finally { toggling.value = null }
}
</script>

<style scoped>
.uss { display: flex; flex-direction: column; gap: .6rem; }
.uss__loading { display: flex; justify-content: center; padding: .5rem 0; }
.uss__sede { display: flex; flex-direction: column; gap: .4rem; }
.uss__sede--on { padding-bottom: .4rem; border-bottom: 1px solid var(--c-slate-100); }
.uss__salas { display: flex; flex-wrap: wrap; gap: .35rem; padding-left: 1.6rem; }
.uss__chip {
  display: inline-flex; align-items: center; gap: .45rem;
  padding: .45rem .8rem; border-radius: 9px;
  border: 1.5px solid var(--c-slate-200); background: var(--c-slate-50);
  font-size: .82rem; font-weight: 500; color: var(--c-slate-600);
  cursor: pointer; transition: all .15s; font-family: inherit; align-self: flex-start;
}
.uss__chip--sede { font-weight: 600; }
.uss__chip--sala { padding: .35rem .7rem; font-size: .78rem; }
.uss__chip:hover:not(:disabled) { border-color: var(--c-leaf-300); background: var(--c-leaf-50); color: var(--c-leaf-800); }
.uss__chip--on { border-color: var(--c-leaf-800); background: var(--c-leaf-100); color: var(--c-leaf-800); font-weight: 600; }
.uss__chip--on:hover:not(:disabled) { border-color: var(--c-rust-600); background: var(--c-rust-100); color: var(--c-rust-600); }
.uss__chip:disabled { opacity: .55; cursor: not-allowed; }
.uss__ico { width: 16px; height: 16px; display: flex; align-items: center; justify-content: center; font-size: .75rem; flex-shrink: 0; }
.uss__nombre { font-weight: inherit; }
.uss__tipo { font-size: .68rem; color: var(--c-slate-400); font-weight: 400; }
.uss__sin-salas { font-size: .76rem; color: var(--c-slate-400); font-style: italic; }
.uss__vacio { font-size: .82rem; color: var(--c-slate-500); }
.uss__nota { margin: 0; font-size: .74rem; color: var(--c-slate-500); display: flex; align-items: center; gap: .35rem; }
.uss__nota--warn { color: var(--c-amber-500); }
.uss__error { font-size: .78rem; color: var(--c-rust-600); display: flex; align-items: center; gap: .35rem; }
</style>
