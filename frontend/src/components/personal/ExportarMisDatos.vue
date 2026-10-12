<template>
  <!-- «EXPORTAR MIS DATOS» (autocultivo, 11-oct-2026): todo lo cargado en un ZIP —informes en PDF y
       Excel, plantas, diario y fotos—. Se arma en segundo plano (con cientos de fotos tarda) y se
       baja con la sesión, nunca por un link público: son datos de salud. -->
  <section class="emd">
    <div class="emd__txt">
      <h2 class="emd__t">Tus datos</h2>
      <p class="emd__p">Bajá todo lo que cargaste en un archivo ZIP: informes en PDF y Excel, tus plantas, el diario y las fotos.</p>
      <p v-if="est.estado === 'armando'" class="emd__estado"><i class="bi bi-arrow-repeat emd__spin" aria-hidden="true"></i> Armando el archivo… con muchas fotos puede tardar unos minutos.</p>
      <p v-else-if="est.estado === 'listo'" class="emd__estado emd__estado--ok">Listo · {{ peso }} · se borra el {{ vence }}</p>
      <p v-else-if="est.estado === 'error'" class="emd__estado emd__estado--mal">No se pudo armar. Probá de nuevo; si sigue, escribinos.</p>
    </div>
    <div class="emd__acc">
      <button v-if="est.estado === 'listo'" type="button" class="emd__btn" :disabled="bajando" @click="bajar">
        {{ bajando ? 'Bajando…' : 'Descargar ZIP' }}
      </button>
      <button v-if="est.estado !== 'armando'" type="button" class="emd__btn" :class="{ 'emd__btn--linea': est.estado === 'listo' }"
              :disabled="pidiendo" @click="pedir">
        {{ est.estado === 'listo' ? 'Volver a armar' : 'Preparar mis datos' }}
      </button>
    </div>
  </section>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { getExportacionDatos, pedirExportacionDatos } from '../../lib/api'
import { descargarArchivo } from '../../lib/descargas'
import { useToast } from '../../composables/useToast'

const toast = useToast()
const est = ref({ estado: 'nada' })
const pidiendo = ref(false)
const bajando = ref(false)
let timer = null

async function consultar() {
  try { est.value = (await getExportacionDatos()).data } catch { /* queda lo que había */ }
  clearTimeout(timer)
  if (est.value.estado === 'armando') timer = setTimeout(consultar, 4000)
}
onMounted(consultar)
onUnmounted(() => clearTimeout(timer))

async function pedir() {
  pidiendo.value = true
  try { est.value = (await pedirExportacionDatos()).data; consultar() }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo pedir la exportación') }
  finally { pidiendo.value = false }
}

async function bajar() {
  bajando.value = true
  try { await descargarArchivo('/mis_datos/exportar/descargar', { filename: `mis-datos-${new Date().toISOString().slice(0, 10).replaceAll('-', '')}.zip` }) }
  catch (e) { toast.error(e.message) }
  finally { bajando.value = false }
}

const peso = computed(() => {
  const b = est.value.bytes || 0
  return b > 1048576 ? `${(b / 1048576).toLocaleString('es-AR', { maximumFractionDigits: 1 })} MB` : `${Math.max(1, Math.round(b / 1024))} KB`
})
const vence = computed(() => (est.value.vence_at
  ? new Date(est.value.vence_at).toLocaleString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
  : ''))
</script>

<style scoped>
.emd { display: flex; flex-wrap: wrap; gap: var(--sp-3); align-items: center; justify-content: space-between; padding: var(--sp-4); border: 1px solid var(--c-leaf-100); border-radius: 14px; background: var(--c-paper); }
.emd__txt { flex: 1 1 260px; display: flex; flex-direction: column; gap: 4px; }
.emd__t { margin: 0; font-size: var(--fs-16); font-weight: 800; color: var(--c-ink-900); }
.emd__p { margin: 0; color: var(--c-ink-700); font-size: var(--fs-14); }
.emd__estado { margin: 4px 0 0; font-size: var(--fs-13); color: var(--c-ink-700); }
.emd__estado--ok { color: var(--c-leaf-800); font-weight: 600; }
.emd__estado--mal { color: var(--c-gold-500); font-weight: 600; }
.emd__spin { display: inline-block; animation: emd-giro 1s linear infinite; }
@keyframes emd-giro { to { transform: rotate(360deg); } }
.emd__acc { display: flex; gap: var(--sp-2); flex-wrap: wrap; }
.emd__btn { border: 0; border-radius: 10px; padding: 10px 16px; font-weight: 700; background: var(--c-leaf-800); color: var(--c-paper); cursor: pointer; }
.emd__btn--linea { background: transparent; color: var(--c-leaf-800); border: 1px solid var(--c-leaf-300); }
.emd__btn:disabled { opacity: .6; cursor: default; }
</style>
