<template>
  <div class="dlv-dash">
    <div class="dlv-dash__header">
      <h1 class="dlv-dash__title"><Truck :size="20" :stroke-width="1.75" /> Panel de delivery</h1>
    </div>

    <div v-if="loading" class="dlv-dash__loading">Cargando…</div>

    <template v-else>
      <div class="dlv-dash__stats">
        <div class="dlv-dash__stat dlv-dash__stat--preparado">
          <span class="dlv-dash__stat-n">{{ stats.preparado }}</span>
          <span class="dlv-dash__stat-l">Preparados</span>
        </div>
        <div class="dlv-dash__stat dlv-dash__stat--retirado">
          <span class="dlv-dash__stat-n">{{ stats.retirado }}</span>
          <span class="dlv-dash__stat-l">En camino</span>
        </div>
        <div class="dlv-dash__stat dlv-dash__stat--entregado">
          <span class="dlv-dash__stat-n">{{ stats.entregado }}</span>
          <span class="dlv-dash__stat-l">Entregados hoy</span>
        </div>
      </div>

      <div class="dlv-dash__cta">
        <RouterLink to="/delivery/despachos" class="dlv-dash__btn">
          <PackageCheck :size="18" :stroke-width="1.75" /> Ver despachos
        </RouterLink>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { Truck, PackageCheck } from 'lucide-vue-next'

const loading = ref(false)
const stats = ref({ preparado: 0, retirado: 0, entregado: 0 })

onMounted(() => { /* módulo despachos pendiente de implementación */ })
</script>

<style scoped>
.dlv-dash { padding: var(--sp-6); max-width: 700px; }
.dlv-dash__header { margin-bottom: var(--sp-5); }
.dlv-dash__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.dlv-dash__loading { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; }
.dlv-dash__stats { display: flex; gap: var(--sp-4); margin-bottom: var(--sp-6); flex-wrap: wrap; }
.dlv-dash__stat { flex: 1; min-width: 120px; background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-4); text-align: center; }
.dlv-dash__stat-n { display: block; font-size: var(--fs-32); font-weight: 700; color: var(--c-ink-900); }
.dlv-dash__stat-l { font-size: var(--fs-13); color: var(--c-ink-500); font-weight: 500; }
.dlv-dash__stat--preparado .dlv-dash__stat-n { color: #B85C00; }
.dlv-dash__stat--retirado  .dlv-dash__stat-n { color: #2563EB; }
.dlv-dash__stat--entregado .dlv-dash__stat-n { color: #2D8A6B; }
.dlv-dash__cta { display: flex; gap: var(--sp-3); }
.dlv-dash__btn { display: inline-flex; align-items: center; gap: var(--sp-2); padding: var(--sp-2) var(--sp-5); background: var(--c-role-delivery, #1A3A4A); color: #fff; border-radius: var(--r-md); font-size: var(--fs-14); font-weight: 600; text-decoration: none; }
</style>
