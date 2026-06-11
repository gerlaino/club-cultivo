<template>
  <div class="usm">

    <div v-if="loading" class="usm__loading">
      <DsSpinner />
    </div>

    <template v-else-if="salasParaRol.length === 0">
      <div class="usm__empty">
        <i class="bi bi-grid-3x3-gap"></i>
        <span>No hay salas disponibles en sedes de producción.</span>
      </div>
    </template>

    <template v-else>
      <div v-if="esManicurador" class="usm__mode-hint">
        <i class="bi bi-info-circle"></i>
        Solo puede tener una sala asignada. Seleccioná otra para reemplazarla.
      </div>

      <div v-for="(grupo, sedeNombre) in salasPorSede" :key="sedeNombre" class="usm__group">
        <div class="usm__group-label">
          <i class="bi bi-building"></i>
          {{ sedeNombre }}
        </div>
        <div class="usm__grid">
          <button
            v-for="sala in grupo"
            :key="sala.id"
            class="usm__sala"
            :class="{
              'usm__sala--on':      isAsignada(sala),
              'usm__sala--spinner': toggling === sala.id,
            }"
            :disabled="toggling !== null || !puedeEditar"
            @click="toggle(sala)"
          >
            <div class="usm__sala-ico">
              <DsSpinner v-if="toggling === sala.id" :size="12" />
              <i v-else-if="isAsignada(sala)" class="bi bi-check-lg"></i>
              <i v-else class="bi bi-plus-lg"></i>
            </div>
            <span class="usm__sala-nombre">{{ sala.nombre }}</span>
          </button>
        </div>
      </div>

      <div class="usm__footer">
        <div v-if="salasAsignadas.length" class="usm__chips">
          <span v-for="s in salasAsignadas" :key="s.id" class="usm__chip">
            <i class="bi bi-check-circle-fill"></i>
            {{ s.nombre }}
          </span>
        </div>
        <span v-else class="usm__none">Sin salas asignadas</span>
      </div>
    </template>

    <div v-if="errorMsg" class="usm__error">
      <i class="bi bi-exclamation-triangle-fill"></i>
      {{ errorMsg }}
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import DsSpinner from '../design-system/components/Spinner.vue'
import { logger } from '../utils/logger.js'
import { useAuthStore } from '../stores/auth'
import { getUserSalasAsignadas, asignarSalaAUsuario, desasignarSalaAUsuario, listSalas } from '../lib/api.js'

const props = defineProps({
  userId:   { type: Number, required: true },
  userRole: { type: String, default: '' },
})

const auth           = useAuthStore()
const salasAsignadas = ref([])
const todasLasSalas  = ref([])
const loading        = ref(false)
const toggling       = ref(null)
const errorMsg       = ref('')

const puedeEditar   = computed(() => auth.user?.role === 'admin')
const esManicurador = computed(() => props.userRole === 'manicura')

const salasParaRol = computed(() =>
  todasLasSalas.value.filter(s => {
    if (!['produccion', 'mixta'].includes(s.sede?.tipo)) return false
    return esManicurador.value ? s.kind === 'manicura' : s.kind !== 'manicura'
  })
)

const salasPorSede = computed(() => {
  const map = {}
  for (const sala of salasParaRol.value) {
    const key = sala.sede?.nombre || 'Sin sede'
    if (!map[key]) map[key] = []
    map[key].push(sala)
  }
  return map
})

function isAsignada(sala) {
  return salasAsignadas.value.some(s => s.id === sala.id)
}

async function toggle(sala) {
  if (!puedeEditar.value) return
  errorMsg.value = ''
  toggling.value = sala.id
  try {
    if (isAsignada(sala)) {
      await desasignarSalaAUsuario(props.userId, sala.id)
      salasAsignadas.value = salasAsignadas.value.filter(s => s.id !== sala.id)
    } else {
      await asignarSalaAUsuario(props.userId, sala.id)
      if (esManicurador.value) {
        salasAsignadas.value = [sala]
      } else {
        salasAsignadas.value = [...salasAsignadas.value, sala]
      }
    }
  } catch (e) {
    errorMsg.value = e.response?.data?.error || 'Error al actualizar la sala'
    logger.error(e)
  } finally {
    toggling.value = null
  }
}

onMounted(async () => {
  loading.value = true
  try {
    const [resAsig, resTodas] = await Promise.all([
      getUserSalasAsignadas(props.userId),
      puedeEditar.value ? listSalas() : Promise.resolve({ data: [] }),
    ])
    salasAsignadas.value = resAsig.data || []
    todasLasSalas.value  = resTodas.data || []
  } catch (e) { logger.error(e) }
  finally { loading.value = false }
})
</script>

<style scoped>
.usm { display: flex; flex-direction: column; gap: .875rem; }

/* Loading */
.usm__loading {
  display: flex; align-items: center; justify-content: center; padding: 2rem;
}

/* Empty */
.usm__empty {
  display: flex; align-items: center; gap: .5rem;
  font-size: .82rem; color: #94a3b8; padding: .5rem 0;
}

/* Hint manicura */
.usm__mode-hint {
  display: flex; align-items: flex-start; gap: .45rem;
  background: #fffbeb; border: 1px solid #fde68a;
  color: #92400e; padding: .6rem .875rem;
  border-radius: 8px; font-size: .78rem; line-height: 1.4;
}

/* Grupo por sede */
.usm__group { display: flex; flex-direction: column; gap: .45rem; }
.usm__group-label {
  display: flex; align-items: center; gap: .4rem;
  font-size: .7rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: .05em; color: #94a3b8;
}

/* Grid de salas */
.usm__grid { display: flex; flex-wrap: wrap; gap: .4rem; }

.usm__sala {
  display: inline-flex; align-items: center; gap: .45rem;
  padding: .45rem .8rem; border-radius: 9px;
  border: 1.5px solid #e2e8f0; background: #f8fafc;
  font-size: .82rem; font-weight: 500; color: #475569;
  cursor: pointer; transition: all .15s;
}
.usm__sala:hover:not(:disabled) {
  border-color: #a5d6a7; background: #f0fdf4; color: #1b5e20;
}
.usm__sala--on {
  border-color: #1b5e20; background: #e8f5e9; color: #1b5e20; font-weight: 600;
}
.usm__sala--on:hover:not(:disabled) {
  border-color: #b91c1c; background: #fef2f2; color: #b91c1c;
}
.usm__sala:disabled { opacity: .55; cursor: not-allowed; }

.usm__sala-ico {
  width: 16px; height: 16px; display: flex;
  align-items: center; justify-content: center;
  font-size: .75rem; flex-shrink: 0;
}

/* Footer chips */
.usm__footer {
  padding-top: .25rem;
  border-top: 1px solid #f1f5f9;
}
.usm__chips { display: flex; flex-wrap: wrap; gap: .35rem; }
.usm__chip {
  display: inline-flex; align-items: center; gap: .3rem;
  background: #e8f5e9; color: #1b5e20;
  border: 1px solid #a5d6a7;
  padding: .2em .65em; border-radius: 6px;
  font-size: .75rem; font-weight: 600;
}
.usm__chip i { font-size: .65rem; }
.usm__none { font-size: .78rem; color: #94a3b8; font-style: italic; }

/* Error */
.usm__error {
  display: flex; align-items: center; gap: .45rem;
  background: #fef2f2; border: 1px solid #fecaca;
  color: #b91c1c; padding: .6rem .875rem;
  border-radius: 8px; font-size: .8rem;
}
</style>
