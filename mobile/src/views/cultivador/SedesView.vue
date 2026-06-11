<template>
  <div class="page">
    <div class="page-header">
      <h1>Sedes</h1>
    </div>
    <div class="page-content">
      <div v-if="loading" class="empty-state"><div class="spinner spinner--dark" /></div>
      <div v-else-if="!sedes.length" class="empty-state">
        <div class="icon">🏭</div>
        <p>Sin sedes asignadas</p>
      </div>
      <template v-else>
        <button
          v-for="sede in sedes"
          :key="sede.id"
          class="sede-card"
          @click="router.push({ name: 'sede-detail', params: { id: sede.id } })"
        >
          <div class="sede-card__body">
            <div class="sede-card__nombre">🏭 {{ sede.nombre }}</div>
            <div class="sede-card__meta">
              <span>{{ sede.salas_count ?? sede.salas?.length ?? '—' }} salas</span>
              <span v-if="sede.ciudad"> · {{ sede.ciudad }}</span>
            </div>
          </div>
          <span class="sede-card__arrow">›</span>
        </button>
      </template>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { getSedes } from '@/lib/api'

const router  = useRouter()
const sedes   = ref([])
const loading = ref(true)

onMounted(async () => {
  try {
    const { data } = await getSedes()
    sedes.value = data || []
  } catch { sedes.value = [] }
  loading.value = false
})
</script>

<style scoped>
.sede-card {
  display: flex; align-items: center;
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--r-card); padding: 1rem 1rem 1rem 1.1rem;
  width: 100%; text-align: left;
  box-shadow: var(--shadow); margin-bottom: .75rem;
  transition: all .1s;
}
.sede-card:active { transform: scale(.98); }
.sede-card__body  { flex: 1; }
.sede-card__nombre{ font-size: .95rem; font-weight: 700; color: var(--text); }
.sede-card__meta  { font-size: .75rem; color: var(--text-2); margin-top: .25rem; }
.sede-card__arrow { font-size: 1.4rem; color: var(--green-border); }
</style>
