<script setup>
// Reseña del paciente sobre un producto del pasaporte de dispensa. Estrellas (general) +
// sabor/aroma/efecto (opcionales) + comentario. Autorizada por token de dispensa + DNI.
// Feedback interno del club. Una por (dispensa, genética), editable.
import { reactive, ref } from 'vue'
import axios from 'axios'

const props = defineProps({
  base:           { type: String, required: true },
  token:          { type: String, required: true },
  dni:            { type: String, required: true },
  geneticaId:     { type: [Number, String], required: true },
  geneticaNombre: { type: String, default: '' },
  miResena:       { type: Object, default: null },
})

const AXES = [
  { key: 'puntaje_sabor',  label: 'Sabor'  },
  { key: 'puntaje_aroma',  label: 'Aroma'  },
  { key: 'puntaje_efecto', label: 'Efecto' },
]

const form = reactive({
  estrellas:      props.miResena?.estrellas ?? 0,
  puntaje_sabor:  props.miResena?.puntaje_sabor ?? null,
  puntaje_aroma:  props.miResena?.puntaje_aroma ?? null,
  puntaje_efecto: props.miResena?.puntaje_efecto ?? null,
  comentario:     props.miResena?.comentario ?? '',
})

const guardada = ref(!!props.miResena)
const editando = ref(false)
const enviando = ref(false)
const error    = ref('')

function setAxis(key, n) { form[key] = form[key] === n ? null : n }

async function enviar() {
  if (!form.estrellas) { error.value = 'Elegí al menos las estrellas.'; return }
  enviando.value = true; error.value = ''
  try {
    await axios.post(`${props.base}/d/${props.token}/resena`, {
      dni:            props.dni,
      genetica_id:    props.geneticaId,
      estrellas:      form.estrellas,
      puntaje_sabor:  form.puntaje_sabor,
      puntaje_aroma:  form.puntaje_aroma,
      puntaje_efecto: form.puntaje_efecto,
      comentario:     form.comentario,
    }, { timeout: 12000 })
    guardada.value = true; editando.value = false
  } catch (e) {
    error.value = e?.response?.status === 429
      ? 'Demasiados intentos. Esperá un minuto.'
      : 'No se pudo guardar. Probá de nuevo.'
  } finally {
    enviando.value = false
  }
}
</script>

<template>
  <div class="rf">
    <div class="rf__head">
      <span class="rf__title">
        <i class="bi bi-star-fill"></i>
        {{ guardada && !editando ? 'Tu reseña' : 'Reseñá este producto' }}
      </span>
      <span v-if="guardada && !editando" class="rf__saved">Guardada ✓</span>
    </div>

    <!-- Vista guardada (read-only) -->
    <template v-if="guardada && !editando">
      <div class="rf__ro-stars">
        <span v-for="n in 5" :key="n" class="rf__star" :class="{ on: n <= form.estrellas }">★</span>
      </div>
      <div v-if="form.puntaje_sabor || form.puntaje_aroma || form.puntaje_efecto" class="rf__ro-axes">
        <span v-if="form.puntaje_sabor">Sabor {{ form.puntaje_sabor }}/5</span>
        <span v-if="form.puntaje_aroma">Aroma {{ form.puntaje_aroma }}/5</span>
        <span v-if="form.puntaje_efecto">Efecto {{ form.puntaje_efecto }}/5</span>
      </div>
      <p v-if="form.comentario" class="rf__ro-com">“{{ form.comentario }}”</p>
      <button class="rf__edit" type="button" @click="editando = true">Editar</button>
    </template>

    <!-- Form -->
    <template v-else>
      <div class="rf__axis">
        <span class="rf__axis-lbl">Valoración general</span>
        <span class="rf__stars">
          <button v-for="n in 5" :key="n" type="button" class="rf__star rf__star--btn" :class="{ on: n <= form.estrellas }" @click="form.estrellas = n">★</button>
        </span>
      </div>

      <div v-for="ax in AXES" :key="ax.key" class="rf__axis">
        <span class="rf__axis-lbl">{{ ax.label }} <small>opcional</small></span>
        <span class="rf__stars">
          <button v-for="n in 5" :key="n" type="button" class="rf__star rf__star--btn rf__star--sm" :class="{ on: n <= form[ax.key] }" @click="setAxis(ax.key, n)">★</button>
        </span>
      </div>

      <textarea v-model.trim="form.comentario" class="rf__txt" rows="3" maxlength="1000" placeholder="Contanos qué te pareció (opcional)"></textarea>

      <p v-if="error" class="rf__err">{{ error }}</p>

      <div class="rf__actions">
        <button v-if="guardada" class="rf__btn rf__btn--ghost" type="button" @click="editando = false">Cancelar</button>
        <button class="rf__btn" type="button" :disabled="!form.estrellas || enviando" @click="enviar">
          {{ enviando ? 'Guardando…' : (guardada ? 'Actualizar' : 'Enviar reseña') }}
        </button>
      </div>
    </template>
  </div>
</template>

<style scoped>
.rf {
  margin-top: .9rem; padding: .95rem 1rem;
  background: #f4f8f4; border: 1px solid #e2ebe2; border-radius: 14px;
  display: flex; flex-direction: column; gap: .65rem;
}
.rf__head { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
.rf__title { font-size: .82rem; font-weight: 800; color: #14442e; display: inline-flex; align-items: center; gap: .4rem; }
.rf__title i { color: #d4a017; }
.rf__saved { font-size: .68rem; font-weight: 700; color: #15803d; }

.rf__axis { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
.rf__axis-lbl { font-size: .78rem; font-weight: 600; color: #3f5347; }
.rf__axis-lbl small { color: #9aa79f; font-weight: 500; font-size: .66rem; }
.rf__stars { display: inline-flex; gap: .1rem; }
.rf__star { color: #d7e0d7; font-size: 1.35rem; line-height: 1; }
.rf__star--sm { font-size: 1.1rem; }
.rf__star.on { color: #f5a623; }
.rf__star--btn { background: none; border: none; cursor: pointer; padding: 0 1px; transition: transform .1s; }
.rf__star--btn:hover { transform: scale(1.15); }

.rf__txt {
  width: 100%; border: 1px solid #d7e0d7; border-radius: 10px; padding: .55rem .7rem;
  font-size: .82rem; font-family: inherit; color: #14251b; resize: vertical; background: #fff;
}
.rf__txt:focus { outline: none; border-color: #1b5e20; }

.rf__err { font-size: .74rem; color: #dc2626; margin: 0; }
.rf__actions { display: flex; gap: .5rem; justify-content: flex-end; }
.rf__btn {
  border: none; background: #1b5e20; color: #fff; font-weight: 700; font-size: .8rem;
  padding: .5rem .9rem; border-radius: 10px; cursor: pointer; transition: background .12s;
}
.rf__btn:hover:not(:disabled) { background: #14532d; }
.rf__btn:disabled { opacity: .5; cursor: not-allowed; }
.rf__btn--ghost { background: transparent; color: #56635b; border: 1px solid #d7e0d7; }

.rf__ro-stars { display: flex; gap: .1rem; }
.rf__ro-stars .rf__star { font-size: 1.25rem; }
.rf__ro-axes { display: flex; flex-wrap: wrap; gap: .6rem; font-size: .74rem; color: #3f5347; font-weight: 600; }
.rf__ro-com { margin: 0; font-size: .82rem; color: #3f5347; font-style: italic; line-height: 1.4; }
.rf__edit { align-self: flex-start; background: none; border: none; color: #1b5e20; font-weight: 700; font-size: .76rem; cursor: pointer; padding: 0; }
</style>
