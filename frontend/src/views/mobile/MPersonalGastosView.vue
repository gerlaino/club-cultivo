<template>
  <div class="mpg">
    <header class="mpg__header">
      <div>
        <h1 class="mpg__title">Gastos</h1>
        <p class="mpg__sub">{{ g.mesLabel.value }}</p>
      </div>
      <button type="button" class="mpg__nuevo" @click="abrirNuevo"><i class="bi bi-plus-lg"></i> Gasto</button>
    </header>

    <!-- El número del mes, y el del año para tener contra qué mirarlo. -->
    <div class="mpg__kpis">
      <div class="mpg__kpi">
        <span class="mpg__kpi-num">{{ g.ars(g.totalMes.value) }}</span>
        <span class="mpg__kpi-lbl">este mes</span>
      </div>
      <div class="mpg__kpi">
        <span class="mpg__kpi-num">{{ g.ars(g.totalAnio.value) }}</span>
        <span class="mpg__kpi-lbl">en el año</span>
      </div>
    </div>

    <div class="mpg__meses">
      <button type="button" class="mpg__mes-btn" @click="g.moverMes(-1)" aria-label="Mes anterior"><i class="bi bi-chevron-left"></i></button>
      <span class="mpg__mes-txt">{{ g.mesLabel.value }}</span>
      <button type="button" class="mpg__mes-btn" :disabled="g.esMesActual.value" @click="g.moverMes(1)" aria-label="Mes siguiente"><i class="bi bi-chevron-right"></i></button>
    </div>

    <div v-if="g.cargando.value" class="mpg__loading"><i class="bi bi-arrow-repeat mpg__spin"></i> Cargando…</div>
    <div v-else-if="!g.gastos.value.length" class="mpg__empty">
      <i class="bi bi-receipt"></i>
      <p class="mpg__empty-title">Sin gastos este mes</p>
      <p class="mpg__empty-hint">Sustrato, fertilizante, luz, una lámpara: anotalo y el costo por gramo sale solo.</p>
    </div>
    <ul v-else class="mpg__list">
      <li v-for="x in g.gastos.value" :key="x.id" class="mpg__item" @click="abrirEditar(x)">
        <span class="mpg__item-ico"><i class="bi bi-receipt"></i></span>
        <span class="mpg__item-txt">
          <span class="mpg__item-desc">{{ x.descripcion }}</span>
          <span class="mpg__item-sub">{{ x.categoria_label || x.categoria }} · {{ g.fechaCorta(x.fecha) }}<template v-if="x.lote?.codigo"> · {{ x.lote.codigo }}</template></span>
        </span>
        <span class="mpg__item-monto">{{ g.ars(x.monto_ars) }}</span>
      </li>
    </ul>

    <p class="mpg__pie">Tocá un gasto para corregirlo. El costo por lote está en <RouterLink to="/contabilidad">Gastos</RouterLink> del escritorio.</p>

    <MobileSheet v-model="sheet" :title="g.form.id ? 'Corregir gasto' : 'Nuevo gasto'">
      <GastoForm :form="g.form" :categorias="g.categorias.value" :lotes="g.lotesAbiertos.value" :hoy="g.hoy"
                 :error="g.error.value" :guardando="g.guardando.value"
                 @guardar="guardar" @cancelar="sheet = false" />
      <button v-if="g.form.id" type="button" class="mpg__borrar" :disabled="g.guardando.value" @click="borrar">Borrar este gasto</button>
    </MobileSheet>
  </div>
</template>

<script setup>
// Los gastos del cultivador de casa, en el teléfono. El estado vive en `useGastosPersonal`
// (compartido con el escritorio); acá sólo la presentación.
import { ref, onMounted } from 'vue'
import { useGastosPersonal } from '../../composables/useGastosPersonal.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import MobileSheet from '../../components/mobile/MobileSheet.vue'
import GastoForm from '../../components/personal/GastoForm.vue'

const g     = useGastosPersonal()
const toast = useToast()
const { confirm } = useConfirm()
const sheet = ref(false)

function abrirNuevo()   { g.nuevo();   sheet.value = true }
function abrirEditar(x) { g.editar(x); sheet.value = true }

async function guardar() {
  const editaba = !!g.form.id
  if (await g.guardar()) {
    sheet.value = false
    toast.success(editaba ? 'Gasto corregido' : 'Gasto anotado')
  }
}

async function borrar() {
  const ok = await confirm({ title: '¿Borrar este gasto?', message: 'Sale del mes y del costo del lote, si tenía uno.', confirmText: 'Borrar' })
  if (!ok) return
  try {
    await g.borrar({ id: g.form.id })
    sheet.value = false
    toast.success('Gasto borrado')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo borrar')
  }
}

onMounted(() => g.cargarTodo())
</script>

<style scoped>
.mpg { padding: 0 0 1.5rem; }
.mpg__header { display: flex; align-items: flex-start; justify-content: space-between; gap: .75rem; padding: 1rem 1rem .5rem; }
.mpg__title { font-size: 1.15rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.mpg__sub { margin: .15rem 0 0; font-size: .8rem; color: var(--c-slate-500); }
.mpg__nuevo {
  display: inline-flex; align-items: center; gap: .35rem; padding: .55rem .85rem; border-radius: 12px; border: none;
  background: var(--c-leaf-800, #1A3D2E); color: #fff; font-size: .85rem; font-weight: 700; flex-shrink: 0;
}
.mpg__nuevo:active { transform: scale(.96); }

.mpg__kpis { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; padding: .5rem 1rem 0; }
.mpg__kpi { display: flex; flex-direction: column; gap: .1rem; padding: .85rem .9rem; background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 14px; }
.mpg__kpi-num { font-family: var(--font-display, sans-serif); font-size: 1.35rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); line-height: 1.1; }
.mpg__kpi-lbl { font-size: .72rem; font-weight: 600; color: var(--c-ink-500, #6b7280); }

.mpg__meses { display: flex; align-items: center; justify-content: space-between; padding: .9rem 1rem .5rem; }
.mpg__mes-btn { width: 34px; height: 34px; border-radius: 50%; border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700); }
.mpg__mes-btn:disabled { opacity: .35; }
.mpg__mes-txt { font-size: .85rem; font-weight: 700; color: var(--c-slate-800); }

.mpg__loading { display: flex; align-items: center; gap: .5rem; justify-content: center; padding: 2.5rem; color: var(--c-slate-400); font-size: .875rem; }
.mpg__spin { animation: mpg-spin .8s linear infinite; }
@keyframes mpg-spin { to { transform: rotate(360deg); } }
.mpg__empty { margin: 0 1rem; display: flex; flex-direction: column; align-items: center; gap: .3rem; padding: 2.2rem 1rem; text-align: center; color: var(--c-slate-500); background: #fff; border: 1px dashed var(--c-leaf-200, #cfe0d6); border-radius: 14px; }
.mpg__empty i { font-size: 2rem; color: var(--c-leaf-500, #5A8A72); }
.mpg__empty-title { margin: .3rem 0 0; font-size: .92rem; font-weight: 700; color: var(--c-slate-900); }
.mpg__empty-hint { margin: 0; font-size: .8rem; }

.mpg__list { list-style: none; margin: 0; padding: 0 1rem; display: flex; flex-direction: column; gap: .45rem; }
.mpg__item { display: flex; align-items: center; gap: .7rem; padding: .7rem .8rem; background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: 14px; cursor: pointer; }
.mpg__item:active { transform: scale(.985); }
.mpg__item-ico { width: 36px; height: 36px; border-radius: 10px; display: grid; place-items: center; font-size: 1rem; flex-shrink: 0; background: var(--c-leaf-50, #F4F8F5); color: var(--c-leaf-700, #2D7D46); }
.mpg__item-txt { display: flex; flex-direction: column; gap: .1rem; min-width: 0; flex: 1; }
.mpg__item-desc { font-size: .9rem; font-weight: 600; color: var(--c-ink-900, #1a1d1f); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mpg__item-sub { font-size: .74rem; color: var(--c-ink-500, #6b7280); }
.mpg__item-monto { font-weight: 700; font-size: .95rem; color: var(--c-ink-900, #1a1d1f); white-space: nowrap; }
.mpg__pie { margin: 1rem 1rem 0; font-size: .76rem; color: var(--c-slate-500); text-align: center; }
.mpg__pie a { color: var(--c-leaf-700, #2D7D46); font-weight: 600; }
.mpg__borrar { width: 100%; margin-top: .4rem; padding: .7rem; border: none; background: none; color: #b91c1c; font-size: .85rem; font-weight: 600; }
</style>
