<template>
  <!-- GUÍA DE NUTRIENTES del autocultivo (11-oct-2026): una referencia por fase —qué nutriente
       predomina y en qué rangos de EC y pH moverse—, nunca una receta por marca. Se lee y, si la
       persona quiere, se aplica: eso copia los rangos a SUS alertas (`Nutricion::Guia`). El aviso
       va siempre arriba: no nos hacemos responsables de una cosecha por ofrecer un plan. -->
  <div class="gnu">
    <p v-if="cargando" class="gnu__cargando">Cargando…</p>
    <template v-else-if="guia">
      <div class="gnu__aviso" role="note">
        <i class="bi bi-info-circle" aria-hidden="true"></i>
        <span>{{ guia.aviso }}</span>
      </div>

      <section v-for="f in guia.fases" :key="f.fase" class="gnu__fase">
        <header class="gnu__fase-cab">
          <h2 class="gnu__fase-t">{{ f.titulo }}</h2>
          <span class="gnu__predomina">{{ f.predomina }}</span>
        </header>
        <p class="gnu__detalle">{{ f.detalle }}</p>

        <div class="gnu__rangos">
          <div v-for="t in TIPOS" :key="t.k" class="gnu__rango">
            <span class="gnu__rango-k">{{ t.label }}</span>
            <strong class="gnu__rango-v">{{ rango(f[t.k]) }}</strong>
            <span v-if="distinto(f, t.k)" class="gnu__rango-tuyo">tu alerta: {{ rango(f.tus_rangos[t.k]) }}</span>
            <span class="gnu__rango-cmp" :class="claseCmp(f.comparacion[t.k])">{{ textoCmp(f.comparacion[t.k]) }}</span>
          </div>
        </div>
      </section>

      <section class="gnu__notas">
        <p><strong>Suelo vivo.</strong> {{ guia.suelo_vivo }}</p>
        <p><strong>pH en tierra.</strong> {{ guia.ph_tierra }}</p>
      </section>

      <div class="gnu__aplicar">
        <p v-if="guia.aplicada" class="gnu__aplicada"><i class="bi bi-check2-circle"></i> Tus alertas usan estos rangos.</p>
        <template v-else>
          <p class="gnu__aplicar-p">Si querés, usá estos rangos para tus alertas de ambiente. Después los cambiás cuando quieras en Configuración → Alertas.</p>
          <button type="button" class="gnu__btn" :disabled="aplicando" @click="aplicar">
            {{ aplicando ? 'Aplicando…' : 'Usar estos rangos en mis alertas' }}
          </button>
        </template>
      </div>

      <footer class="gnu__fuentes">
        <span>De dónde sale:</span>
        <a v-for="x in guia.fuentes" :key="x.url" :href="x.url" target="_blank" rel="noopener">{{ x.titulo }}</a>
      </footer>
    </template>
    <p v-else class="gnu__cargando">No se pudo cargar la guía.</p>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getGuiaNutricion, aplicarGuiaNutricion } from '../../lib/api'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast'

const TIPOS = [{ k: 'ec', label: 'EC' }, { k: 'ph', label: 'pH' }]
const { confirm } = useConfirm()
const toast = useToast()

const guia = ref(null)
const cargando = ref(true)
const aplicando = ref(false)

async function cargar() {
  try { guia.value = (await getGuiaNutricion()).data } catch { guia.value = null } finally { cargando.value = false }
}
onMounted(cargar)

const num = (n) => Number(n).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const rango = (r) => (r ? `${num(r.min)} – ${num(r.max)}` : '—')
const distinto = (f, k) => f.tus_rangos?.[k] && (f.tus_rangos[k].min !== f[k]?.min || f.tus_rangos[k].max !== f[k]?.max)
function textoCmp(c) {
  if (!c?.registros) return `sin registros en ${guia.value.dias_comparacion} días`
  if (!c.fuera) return `tus ${c.registros} registros, dentro`
  return `${c.fuera} de ${c.registros} registros, fuera`
}
const claseCmp = (c) => (!c?.registros ? '' : c.fuera ? 'gnu__rango-cmp--fuera' : 'gnu__rango-cmp--ok')

async function aplicar() {
  const ok = await confirm({
    title: 'Usar los rangos de la guía',
    message: 'Tus alertas de EC y pH de germinación, vegetativo y floración pasan a usar estos rangos. ' +
             'Lo que cargaste para una genética en particular no se toca. No se crean tareas ni se cambian tus recetas.',
    confirmText: 'Usar estos rangos',
  })
  if (!ok) return
  aplicando.value = true
  try {
    guia.value = (await aplicarGuiaNutricion()).data
    toast.success('Listo: tus alertas usan los rangos de la guía')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudieron aplicar')
  } finally { aplicando.value = false }
}
</script>

<style scoped>
.gnu { display: flex; flex-direction: column; gap: var(--sp-4); }
.gnu__cargando { color: var(--c-ink-700); }
.gnu__aviso { display: flex; gap: var(--sp-2); align-items: flex-start; padding: var(--sp-3) var(--sp-4); border-radius: 12px; background: var(--c-amber-100); color: var(--c-ink-900); font-size: var(--fs-14); line-height: 1.45; }
.gnu__aviso i { color: var(--c-gold-500); margin-top: 2px; }
.gnu__fase { border: 1px solid var(--c-leaf-100); border-radius: 14px; background: var(--c-paper); padding: var(--sp-4); display: flex; flex-direction: column; gap: var(--sp-3); }
.gnu__fase-cab { display: flex; flex-wrap: wrap; align-items: baseline; justify-content: space-between; gap: var(--sp-2); }
.gnu__fase-t { margin: 0; font-size: var(--fs-18); font-weight: 800; color: var(--c-ink-900); }
.gnu__predomina { font-size: var(--fs-13); font-weight: 700; color: var(--c-leaf-800); background: var(--c-leaf-100); padding: 3px 10px; border-radius: 999px; }
.gnu__detalle { margin: 0; color: var(--c-ink-700); line-height: 1.5; }
.gnu__rangos { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: var(--sp-2); }
.gnu__rango { display: flex; flex-direction: column; gap: 2px; padding: var(--sp-3); border-radius: 10px; background: var(--c-leaf-50); border: 1px solid var(--c-leaf-100); }
.gnu__rango-k { font-size: var(--fs-12); font-weight: 700; color: var(--c-ink-700); text-transform: uppercase; letter-spacing: .04em; }
.gnu__rango-v { font-size: var(--fs-18); color: var(--c-ink-900); }
.gnu__rango-tuyo { font-size: var(--fs-12); color: var(--c-ink-700); }
.gnu__rango-cmp { font-size: var(--fs-12); color: var(--c-ink-700); }
.gnu__rango-cmp--ok { color: var(--c-leaf-800); font-weight: 600; }
.gnu__rango-cmp--fuera { color: var(--c-gold-500); font-weight: 600; }
.gnu__notas { display: flex; flex-direction: column; gap: var(--sp-2); color: var(--c-ink-700); font-size: var(--fs-14); line-height: 1.5; }
.gnu__notas p { margin: 0; }
.gnu__aplicar { display: flex; flex-direction: column; gap: var(--sp-2); align-items: flex-start; }
.gnu__aplicar-p { margin: 0; color: var(--c-ink-700); font-size: var(--fs-14); }
.gnu__aplicada { margin: 0; color: var(--c-leaf-800); font-weight: 600; }
.gnu__btn { border: 0; border-radius: 10px; padding: 10px 16px; font-weight: 700; background: var(--c-leaf-800); color: var(--c-paper); cursor: pointer; }
.gnu__btn:disabled { opacity: .6; cursor: default; }
.gnu__fuentes { display: flex; flex-wrap: wrap; gap: 6px 14px; font-size: var(--fs-12); color: var(--c-ink-700); }
.gnu__fuentes a { color: var(--c-leaf-800); }
</style>
