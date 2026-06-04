<template>
  <div class="mm">
    <div class="mm__hero">
      <div class="mm__greeting">Hola, {{ auth.user?.first_name || 'Manicurador' }} ✂️</div>
      <div class="mm__date">{{ fechaHoy }}</div>
    </div>

    <!-- KPIs -->
    <div class="mm__kpis">
      <div class="mm__kpi">
        <div class="mm__kpi-val">{{ lotesPendientes.length }}</div>
        <div class="mm__kpi-lbl">Pendientes</div>
      </div>
      <div class="mm__kpi">
        <div class="mm__kpi-val">{{ lotesEnCosecha.length }}</div>
        <div class="mm__kpi-lbl">En cosecha</div>
      </div>
      <div class="mm__kpi">
        <div class="mm__kpi-val">{{ lotesEnCurado.length }}</div>
        <div class="mm__kpi-lbl">En curado</div>
      </div>
    </div>

    <!-- Acción principal: escanear QR -->
    <div class="mm__section-title">Acción principal</div>
    <div class="mm__scan-card">
      <i class="bi bi-qr-code-scan mm__scan-icon"></i>
      <div class="mm__scan-info">
        <div class="mm__scan-title">Registrar pesada</div>
        <div class="mm__scan-sub">Escaneá el QR de la planta para registrar el peso</div>
      </div>
    </div>

    <!-- Lotes pendientes de pesaje -->
    <div class="mm__section-title">Pendientes de pesaje</div>
    <div v-if="!lotesPendientes.length" class="mm__empty">Sin lotes pendientes</div>
    <div v-else class="mm__list">
      <RouterLink
        v-for="lote in lotesPendientes"
        :key="lote.id"
        :to="`/mnc/lotes/${lote.id}`"
        class="mm__lote-card"
      >
        <div class="mm__lote-ico">✂️</div>
        <div class="mm__lote-info">
          <div class="mm__lote-codigo">{{ lote.codigo }}</div>
          <div class="mm__lote-sub">{{ lote.strain || lote.genetica?.nombre || '—' }} · {{ lote.plants_count }} plantas</div>
        </div>
        <i class="bi bi-chevron-right mm__chevron"></i>
      </RouterLink>
    </div>

    <!-- Lotes en cosecha -->
    <template v-if="lotesEnCosecha.length">
      <div class="mm__section-title">En cosecha</div>
      <div class="mm__list">
        <RouterLink
          v-for="lote in lotesEnCosecha"
          :key="lote.id"
          :to="`/mnc/lotes/${lote.id}`"
          class="mm__lote-card mm__lote-card--cosecha"
        >
          <div class="mm__lote-ico">🌾</div>
          <div class="mm__lote-info">
            <div class="mm__lote-codigo">{{ lote.codigo }}</div>
            <div class="mm__lote-sub">{{ lote.strain || '—' }} · {{ lote.plants_count }} plantas</div>
          </div>
          <i class="bi bi-chevron-right mm__chevron"></i>
        </RouterLink>
      </div>
    </template>
  </div>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import { useAuthStore }  from '../../stores/auth'
import { useLotesStore } from '../../stores/lotes'

const auth  = useAuthStore()
const lotes = useLotesStore()

const fechaHoy = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })

const lotesPendientes = computed(() => lotes.items.filter(l => l.estado === 'manicura_pendiente'))
const lotesEnCosecha  = computed(() => lotes.items.filter(l => l.estado === 'en_manicura' || l.estado === 'secado'))
const lotesEnCurado   = computed(() => lotes.items.filter(l => l.estado === 'curado'))

onMounted(() => lotes.fetchAll?.())
</script>

<style scoped>
.mm { padding: 0 0 1rem; }
.mm__hero {
  background: linear-gradient(135deg, #1c1028 0%, #4a1d96 100%);
  padding: 1.25rem 1.25rem 1.5rem;
}
.mm__greeting { font-size: 1.1rem; font-weight: 700; color: #fff; }
.mm__date { font-size: .78rem; color: rgba(255,255,255,.6); margin-top: .15rem; text-transform: capitalize; }

.mm__kpis {
  display: grid; grid-template-columns: repeat(3, 1fr);
  gap: .75rem; padding: 1rem 1rem 0; margin-top: -1rem;
}
.mm__kpi { background: #fff; border-radius: 12px; padding: .875rem .5rem; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,.06); }
.mm__kpi-val { font-size: 1.5rem; font-weight: 800; color: #7c3aed; line-height: 1; }
.mm__kpi-lbl { font-size: .65rem; color: #94a3b8; font-weight: 600; margin-top: .2rem; text-transform: uppercase; letter-spacing: .04em; }

.mm__section-title { font-size: .7rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .06em; padding: 1.25rem 1.25rem .5rem; }

.mm__scan-card {
  margin: 0 1rem; background: linear-gradient(135deg, #f5f3ff, #ede9fe);
  border: 1.5px solid #c4b5fd; border-radius: 14px;
  padding: 1.25rem; display: flex; align-items: center; gap: 1rem;
}
.mm__scan-icon { font-size: 2.5rem; color: #7c3aed; }
.mm__scan-title { font-size: .95rem; font-weight: 700; color: #4c1d95; }
.mm__scan-sub { font-size: .75rem; color: #7c3aed; margin-top: .15rem; }

.mm__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }
.mm__empty { padding: .75rem 1.25rem; color: #94a3b8; font-size: .82rem; }
.mm__lote-card {
  background: #fff; border-radius: 12px; padding: .875rem 1rem;
  display: flex; align-items: center; gap: .75rem;
  text-decoration: none; box-shadow: 0 1px 4px rgba(0,0,0,.05);
}
.mm__lote-card--cosecha { border-left: 3px solid #dc2626; }
.mm__lote-ico { font-size: 1.3rem; flex-shrink: 0; }
.mm__lote-info { flex: 1; min-width: 0; }
.mm__lote-codigo { font-size: .88rem; font-weight: 700; color: #1a1a1a; }
.mm__lote-sub { font-size: .72rem; color: #94a3b8; margin-top: .1rem; }
.mm__chevron { color: #d4e6d4; font-size: .8rem; flex-shrink: 0; }
</style>
