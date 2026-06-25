<template>
  <div class="raf">
    <div class="raf__row">
      <select v-model="form.categoria" class="raf__sel">
        <option v-for="t in CATEGORIAS" :key="t.value" :value="t.value">{{ t.emoji }} {{ t.label }}</option>
      </select>
      <AppDatePicker v-model="form.fecha" :max="hoy" class="raf__date" />
    </div>

    <!-- Campos según categoría -->
    <div v-if="form.categoria === 'trasplante'" class="raf__row">
      <input v-model.number="form.macetaOrigen" type="number" step="0.5" min="0" class="raf__num" placeholder="Maceta origen (L)" />
      <span class="raf__arrow">→</span>
      <input v-model.number="form.macetaDestino" type="number" step="0.5" min="0.1" class="raf__num" placeholder="Maceta destino (L) *" />
    </div>
    <div v-else-if="form.categoria === 'fertilizacion'" class="raf__row">
      <input v-model="form.producto" type="text" class="raf__input" maxlength="120" placeholder="Producto / fórmula" />
      <input v-model.number="form.ec" type="number" step="0.1" min="0" class="raf__num" placeholder="EC" />
    </div>
    <div v-else-if="form.categoria === 'riego'" class="raf__row">
      <input v-model.number="form.volumen" type="number" step="0.1" min="0" class="raf__num" placeholder="Volumen (L)" />
      <input v-model.number="form.ec" type="number" step="0.1" min="0" class="raf__num" placeholder="EC" />
    </div>

    <input v-if="form.categoria !== 'trasplante'" v-model="form.descripcion" type="text"
           class="raf__input" maxlength="200" :placeholder="placeholderDescripcion" @keyup.enter="guardar" />
    <div class="raf__actions">
      <button class="raf__cancel" @click="$emit('cancelar')">Cancelar</button>
      <button class="raf__save" :disabled="!formValido" @click="guardar">Registrar</button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { CATEGORIAS, placeholderFor } from '../../lib/historialHelpers.js'

const emit = defineEmits(['crear', 'trasplante', 'cancelar'])

const hoy = new Date().toISOString().split('T')[0]
const blank = () => ({ categoria: 'riego', fecha: hoy, descripcion: '', producto: '', ec: null, volumen: null, macetaOrigen: null, macetaDestino: null })
const form = ref(blank())

const placeholderDescripcion = computed(() => placeholderFor(form.value.categoria))
const formValido = computed(() => {
  if (form.value.categoria === 'trasplante') return form.value.macetaDestino > 0
  if (['nota', 'otro'].includes(form.value.categoria)) return form.value.descripcion.trim().length > 0
  return true
})

function guardar() {
  if (!formValido.value) return
  const f = form.value
  if (f.categoria === 'trasplante') {
    emit('trasplante', { fecha: f.fecha, maceta_origen_l: f.macetaOrigen || undefined, maceta_destino_l: f.macetaDestino })
    form.value = blank()
    return
  }
  const metadata = {}
  if (f.ec != null && f.ec !== '')          metadata.ec = Number(f.ec)
  if (f.volumen != null && f.volumen !== '') metadata.volumen_l = Number(f.volumen)
  if (f.categoria === 'fertilizacion' && f.producto.trim()) metadata.producto = f.producto.trim()
  emit('crear', {
    tipo: 'actividad', categoria: f.categoria,
    descripcion: f.descripcion.trim() || null, metadata,
    registrado_en: `${f.fecha}T12:00:00`,
  })
  form.value = blank()
}
</script>

<style scoped>
.raf { display: flex; flex-direction: column; gap: .5rem; }
.raf__row { display: flex; gap: .5rem; align-items: center; }
.raf__sel { flex: 1; min-width: 0; border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .45rem .55rem; font-size: .82rem; color: #0f172a; background: #fff; }
.raf__date { flex: 1; min-width: 0; }
.raf__input { width: 100%; box-sizing: border-box; border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .5rem .65rem; font-size: .85rem; color: #0f172a; outline: none; }
.raf__input:focus { border-color: #16a34a; }
.raf__num { width: 100%; min-width: 0; flex: 1; box-sizing: border-box; border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .5rem .55rem; font-size: .85rem; color: #0f172a; outline: none; }
.raf__num:focus { border-color: #16a34a; }
.raf__arrow { color: #94a3b8; font-weight: 800; flex-shrink: 0; }
.raf__actions { display: flex; justify-content: flex-end; gap: .5rem; }
.raf__cancel { background: #fff; border: 1.5px solid #cbd5e1; color: #334155; border-radius: 8px; padding: .4rem .85rem; font-size: .8rem; font-weight: 600; cursor: pointer; }
.raf__save { background: #1b5e20; border: none; color: #fff; border-radius: 8px; padding: .4rem 1rem; font-size: .8rem; font-weight: 700; cursor: pointer; }
.raf__save:disabled { opacity: .5; cursor: not-allowed; }
</style>
