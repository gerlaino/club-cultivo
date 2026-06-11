<template>
  <div class="page">
    <div class="page-header">
      <button class="back-btn" @click="router.back()">‹</button>
      <h1>{{ sede?.nombre || 'Sede' }}</h1>
    </div>
    <div class="page-content">
      <div v-if="loading" class="empty-state"><div class="spinner spinner--dark" /></div>
      <div v-else-if="!salas.length" class="empty-state">
        <div class="icon">🏠</div>
        <p>Sin salas en esta sede</p>
      </div>
      <template v-else>
        <p class="section-title">Salas ({{ salas.length }})</p>
        <button
          v-for="sala in salas"
          :key="sala.id"
          class="sala-card"
          @click="router.push({ name: 'sala-detail', params: { id: sala.id } })"
        >
          <div class="sala-card__left">
            <span class="sala-card__emoji">{{ kindEmoji(sala.kind) }}</span>
            <div>
              <div class="sala-card__nombre">{{ sala.nombre }}</div>
              <div class="sala-card__meta">
                <span class="pill" :style="kindStyle(sala.kind)">{{ sala.kind }}</span>
                <span v-if="sala.lotes_count"> · {{ sala.lotes_count }} lotes</span>
              </div>
            </div>
          </div>
          <span class="sala-card__arrow">›</span>
        </button>
      </template>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getSedeDetail } from '@/lib/api'

const route  = useRoute()
const router = useRouter()
const sede   = ref(null)
const salas  = ref([])
const loading = ref(true)

const KIND_META = {
  vegetativo: { emoji: '🌱', bg: '#dcfce7', color: '#16a34a' },
  floracion:  { emoji: '🌸', bg: '#fef3c7', color: '#d97706' },
  mixta:      { emoji: '🌿', bg: '#f0fdf4', color: '#1b5e20' },
  madre:      { emoji: '🌳', bg: '#e0f2fe', color: '#0891b2' },
  clon:       { emoji: '🪴', bg: '#ede9fe', color: '#7c3aed' },
  manicura:   { emoji: '✂️', bg: '#fff7ed', color: '#ea580c' },
}
function kindEmoji(k)  { return KIND_META[k]?.emoji || '🏠' }
function kindStyle(k)  {
  const m = KIND_META[k]
  return m ? { background: m.bg, color: m.color } : { background: '#f1f5f9', color: '#64748b' }
}

onMounted(async () => {
  try {
    const { data } = await getSedeDetail(route.params.id)
    sede.value  = data
    salas.value = data.salas || []
  } catch { salas.value = [] }
  loading.value = false
})
</script>

<style scoped>
.sala-card {
  display: flex; align-items: center; justify-content: space-between;
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--r-card); padding: .9rem 1rem;
  width: 100%; text-align: left; margin-bottom: .75rem;
  box-shadow: var(--shadow); transition: all .1s;
}
.sala-card:active { transform: scale(.98); }
.sala-card__left  { display: flex; align-items: center; gap: .75rem; flex: 1; }
.sala-card__emoji { font-size: 1.5rem; }
.sala-card__nombre{ font-size: .95rem; font-weight: 700; color: var(--text); }
.sala-card__meta  { display: flex; align-items: center; gap: .4rem; margin-top: .25rem; font-size: .75rem; color: var(--text-2); }
.sala-card__arrow { font-size: 1.4rem; color: var(--green-border); }
</style>
