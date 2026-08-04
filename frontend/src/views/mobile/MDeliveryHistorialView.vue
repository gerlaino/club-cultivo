<template>
  <div class="mdh">
    <div class="mdh__resumen">
      <div class="mdh__stat">
        <span class="mdh__stat-n mdh__stat-n--ok">{{ resumen.entregados ?? 0 }}</span>
        <span class="mdh__stat-l">Entregados</span>
      </div>
      <div class="mdh__stat">
        <span class="mdh__stat-n mdh__stat-n--bad">{{ resumen.fallidos ?? 0 }}</span>
        <span class="mdh__stat-l">Fallidos</span>
      </div>
      <select v-model.number="dias" class="mdh__rango" @change="cargar">
        <option :value="7">7 días</option>
        <option :value="30">30 días</option>
        <option :value="90">90 días</option>
      </select>
    </div>

    <div v-if="loading" class="mdh__muted">Cargando…</div>

    <div v-else-if="!paquetes.length" class="mdh__empty">
      <span class="mdh__empty-ico">🚚</span>
      <p>Todavía no cerraste ninguna entrega en este período.</p>
    </div>

    <div v-else class="mdh__list">
      <div v-for="p in paquetes" :key="p.id" class="mdh__card">
        <div class="mdh__card-head">
          <span class="mdh__paciente">{{ p.paciente_nombre || '—' }}</span>
          <span class="mdh__estado" :class="`mdh__estado--${p.estado_envio}`">
            {{ p.estado_envio === 'entregado' ? 'Entregado' : 'Fallido' }}
          </span>
        </div>
        <div v-if="p.direccion_envio" class="mdh__dir">{{ p.direccion_envio }}</div>
        <div class="mdh__pie">
          <span class="mdh__fecha">{{ fechaHora(p.entregado_at || p.updated_at) }}</span>
          <span v-if="p.motivo_fallo" class="mdh__motivo">{{ p.motivo_fallo }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getMiHistorialDelivery } from '../../lib/api.js'

const dias     = ref(30)
const loading  = ref(false)
const paquetes = ref([])
const resumen  = ref({})

onMounted(cargar)

async function cargar() {
  loading.value = true
  try {
    const { data } = await getMiHistorialDelivery(dias.value)
    paquetes.value = data.dispensaciones ?? []
    resumen.value  = data.resumen ?? {}
  } catch { paquetes.value = [] } finally { loading.value = false }
}

function fechaHora(f) {
  if (!f) return ''
  const d = new Date(f)
  return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}
</script>

<style scoped>
.mdh { padding: .75rem; display: flex; flex-direction: column; gap: .75rem; }

.mdh__resumen {
  display: flex; align-items: center; gap: .75rem;
  background: #fff; border: 1px solid var(--c-ink-100, #f1f5f9); border-radius: 12px; padding: .75rem .9rem;
}
.mdh__stat { display: flex; flex-direction: column; }
.mdh__stat-n { font-size: 1.3rem; font-weight: 800; line-height: 1; }
.mdh__stat-n--ok  { color: #15803d; }
.mdh__stat-n--bad { color: #dc2626; }
.mdh__stat-l { font-size: .7rem; color: var(--c-ink-400, #94a3b8); text-transform: uppercase; }
.mdh__rango {
  margin-left: auto; border: 1px solid var(--c-ink-200, #e2e8f0); border-radius: 8px;
  padding: .4rem .5rem; font-size: .8rem; background: #fff;
}

.mdh__muted { text-align: center; color: var(--c-ink-400, #94a3b8); padding: 1rem; font-size: .85rem; }
.mdh__empty { text-align: center; padding: 2rem 1rem; color: var(--c-ink-500, #64748b); }
.mdh__empty-ico { font-size: 2rem; display: block; margin-bottom: .5rem; }

.mdh__list { display: flex; flex-direction: column; gap: .5rem; }
.mdh__card {
  background: #fff; border: 1px solid var(--c-ink-100, #f1f5f9); border-radius: 12px;
  padding: .75rem .9rem; display: flex; flex-direction: column; gap: .3rem;
}
.mdh__card-head { display: flex; justify-content: space-between; align-items: center; gap: .5rem; }
.mdh__paciente { font-weight: 600; color: var(--c-ink-800, #1e293b); }
.mdh__estado { font-size: .7rem; font-weight: 700; padding: .12em .5em; border-radius: 999px; }
.mdh__estado--entregado { background: #dcfce7; color: #15803d; }
.mdh__estado--fallido   { background: #fee2e2; color: #b91c1c; }
.mdh__dir { font-size: .8rem; color: var(--c-ink-600, #475569); }
.mdh__pie { display: flex; justify-content: space-between; gap: .5rem; font-size: .72rem; color: var(--c-ink-400, #94a3b8); }
.mdh__motivo { font-style: italic; }
</style>
