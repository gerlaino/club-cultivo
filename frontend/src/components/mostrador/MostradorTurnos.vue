<template>
  <div class="trn">
    <p class="trn__sub">
      {{ gestiona
         ? 'Todos los turnos cerrados de esta sede.'
         : 'Los turnos que atendiste vos. Si mañana te preguntan por una diferencia, está acá.' }}
    </p>

    <p v-if="cargando" class="trn__vacio">Buscando…</p>
    <p v-else-if="!turnos.length" class="trn__vacio">Todavía no cerraste ningún turno acá.</p>

    <div v-else class="trn__table-wrap">
      <table class="trn__table tabla-cards">
        <thead>
          <tr>
            <th>Turno</th>
            <th class="trn__th-num">Entregado</th>
            <th class="trn__th-num">Faltó</th>
            <th class="trn__th-num">Caja</th>
            <th class="trn__th-acc"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="t in turnos" :key="t.id">
            <td data-col="Turno">
              <div class="trn__cuando">{{ fecha(t.cerrado_at) }} · {{ hora(t.abierto_at) }}–{{ hora(t.cerrado_at) }}</div>
              <div class="trn__meta">
                <span class="trn__mut">{{ t.atendio || t.cerrado_por }}</span>
                <span class="trn__mut">· {{ t.productos }} producto{{ t.productos === 1 ? '' : 's' }}</span>
                <span v-if="t.revisado" class="trn__pill trn__pill--ok">Visto</span>
              </div>
            </td>
            <td class="trn__td-num trn__mut" data-col="Entregado">{{ fmt(t.dispensado) }}</td>
            <td class="trn__td-num" data-col="Faltó">
              <template v-if="t.faltante > 0">
                <span class="trn__num">{{ fmt(t.faltante) }}</span>
                <span class="trn__unidad">${{ fmt(t.faltante_ars) }}</span>
              </template>
              <span v-else class="trn__ok">cuadró</span>
            </td>
            <td class="trn__td-num" data-col="Caja">
              <template v-if="t.efectivo_contado_ars !== null">
                <span class="trn__num">${{ fmt(t.efectivo_contado_ars) }}</span>
                <span v-if="t.diferencia_caja_ars" class="trn__unidad">
                  {{ t.diferencia_caja_ars > 0 ? '+' : '' }}${{ fmt(t.diferencia_caja_ars) }}
                </span>
              </template>
              <span v-else class="trn__mut">—</span>
            </td>
            <td class="trn__td-acc" data-col="">
              <!-- Corregir un conteo ajusta el inventario real: sólo administración. El que
                   atendió ve su turno para poder mostrarlo, no para reescribirlo. -->
              <button v-if="gestiona" class="trn__btn trn__btn--mini trn__btn--ghost"
                      @click="corrigiendo = t">Corregir conteo</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <p v-if="!gestiona && turnos.length" class="trn__nota">
      ¿Contaste mal alguno? Avisale a administración: el conteo se corrige desde acá, sin borrar
      nada — se asienta la diferencia.
    </p>

    <CorregirConteo v-if="corrigiendo" :sede-id="sedeId" :turno="corrigiendo"
                    @cerrar="corrigiendo = null" @corregido="cargar" />
  </div>
</template>

<script setup>
// LOS TURNOS QUE YA CERRARON.
//
// El que atiende cerraba su turno y no tenía dónde mirarlo después: si al día siguiente le
// preguntan por una diferencia, no tenía con qué. Administración ve todos; él ve LOS SUYOS —el
// backend filtra, no la pantalla.
import { ref, watch } from 'vue'
import CorregirConteo from './CorregirConteo.vue'
import { listTurnosMostrador } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({ sedeId: { type: Number, default: null } })

const toast    = useToast()
const turnos   = ref([])
const gestiona = ref(false)
const cargando = ref(false)
const corrigiendo = ref(null)

const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const fecha = (iso) => (iso ? new Date(iso).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' }) : '')
const hora  = (iso) => (iso ? new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) : '')

async function cargar () {
  if (!props.sedeId) return
  cargando.value = true
  try {
    const { data } = await listTurnosMostrador(props.sedeId)
    turnos.value   = data.turnos || []
    gestiona.value = !!data.gestiona
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudieron cargar los turnos.')
  } finally {
    cargando.value = false
  }
}

watch(() => props.sedeId, cargar, { immediate: true })
</script>

<style scoped>
.trn__sub   { margin: 0 0 14px; font-size: var(--fs-13); color: var(--c-ink-500); max-width: 60ch; }
.trn__vacio { margin: 0; font-size: var(--fs-14); color: var(--c-ink-500); }
.trn__nota  { margin: 12px 0 0; font-size: var(--fs-13); color: var(--c-ink-500); max-width: 60ch; }

.trn__table-wrap {
  background: #fff; border: 1px solid var(--c-slate-200);
  border-radius: 14px; overflow-x: auto;
}
.trn__table { width: 100%; border-collapse: collapse; }
.trn__table th {
  text-align: left; font-size: var(--fs-12); font-weight: 600; text-transform: uppercase;
  letter-spacing: .04em; color: var(--c-ink-500);
  padding: 13px 16px; border-bottom: 1px solid var(--c-slate-200); white-space: nowrap;
}
.trn__table td { padding: 14px 16px; border-bottom: 1px solid var(--c-slate-100); vertical-align: middle; }
.trn__table tbody tr:last-child td { border-bottom: 0; }

.trn__th-num, .trn__td-num { text-align: right; }
.trn__th-acc, .trn__td-acc { text-align: right; white-space: nowrap; }

.trn__cuando { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.trn__meta   { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 5px; align-items: center; }
.trn__mut    { color: var(--c-ink-500); font-size: var(--fs-13); }
.trn__num    { font-family: var(--font-mono); font-weight: 600; color: var(--c-ink-900); }
.trn__unidad { font-size: var(--fs-12); color: var(--c-ink-500); margin-left: 3px; }
.trn__ok     { font-size: var(--fs-13); color: var(--c-leaf-600); }

.trn__pill {
  display: inline-block; padding: 2px 8px; border-radius: 999px;
  font-size: var(--fs-12); font-weight: 600;
}
.trn__pill--ok { background: var(--c-leaf-100); color: var(--c-leaf-700); }

.trn__btn {
  border-radius: 9px; font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; border: 1px solid transparent;
}
.trn__btn--mini  { padding: 6px 12px; font-size: var(--fs-13); }
.trn__btn--ghost { background: #fff; color: var(--c-ink-700); border-color: var(--c-slate-300); }
</style>
