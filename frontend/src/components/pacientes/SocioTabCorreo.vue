<template>
  <div>
    <!-- Sin email: warning -->
    <div v-if="socio && !socio.email" class="sc__noemail">
      <AlertTriangle :size="20" class="sc__noemail-ico" />
      <div>
        <strong>Este paciente no tiene email registrado.</strong>
        <span> Editá sus datos para agregar uno antes de enviar mensajes.</span>
      </div>
      <button class="sc__edit-link" @click="$emit('open-edit')">Editar datos →</button>
    </div>

    <!-- Compose card -->
    <div class="sc__card sc__compose" :class="{ 'sc__compose--disabled': !socio?.email }">
      <div class="sc__to">
        <Mail :size="14" class="sc__to-ico" />
        <span class="sc__to-label">Para:</span>
        <span class="sc__to-name">{{ socio?.nombre }} {{ socio?.apellido }}</span>
        <span v-if="socio?.email" class="sc__to-email">&lt;{{ socio.email }}&gt;</span>
        <span v-else class="sc__to-missing">sin email</span>
      </div>

      <!-- Las plantillas son las de la organización, editables en Configuración → Correo
           electrónico. Antes eran cuatro fijas escritas en el frontend. -->
      <div class="sc__templates">
        <button
          class="sc__tpl-chip"
          :class="{ 'sc__tpl-chip--active': mailPlantilla === null }"
          @click="aplicarPlantilla(null)"
        >✏️ Escribir libre</button>
        <button
          v-for="tpl in plantillas"
          :key="tpl.id"
          class="sc__tpl-chip"
          :class="{ 'sc__tpl-chip--active': mailPlantilla === tpl.id }"
          @click="aplicarPlantilla(tpl.id)"
        >{{ tpl.nombre }}</button>
      </div>

      <div v-if="mailPreview" class="sc__preview">
        <div class="sc__preview-subject">{{ mailForm.asunto || '(sin asunto)' }}</div>
        <div class="sc__preview-body">{{ mailForm.cuerpo || '(sin contenido)' }}</div>
      </div>

      <template v-else>
        <div class="sc__field">
          <label class="sc__field-label">Asunto</label>
          <input v-model="mailForm.asunto" class="sc__input" placeholder="Asunto del mensaje…"
                 maxlength="200" :disabled="!socio?.email" />
        </div>
        <div class="sc__field">
          <label class="sc__field-label">Mensaje</label>
          <textarea v-model="mailForm.cuerpo" class="sc__textarea"
                    placeholder="Escribí el mensaje…" rows="7" maxlength="3000"
                    :disabled="!socio?.email"></textarea>
          <div class="sc__charcount">{{ mailForm.cuerpo.length }} / 3000</div>
        </div>
      </template>

      <div class="sc__actions">
        <button class="sc__preview-btn" @click="mailPreview = !mailPreview"
                :disabled="!mailForm.asunto && !mailForm.cuerpo">
          {{ mailPreview ? 'Editar' : 'Vista previa' }}
        </button>
        <button class="sc__send-btn"
                :disabled="!socio?.email || mailSending || !mailForm.asunto.trim() || !mailForm.cuerpo.trim()"
                @click="submitMail">
          <DsSpinner v-if="mailSending" :size="16" />
          <Mail v-else :size="15" />
          {{ mailSending ? 'Enviando…' : 'Enviar mail' }}
        </button>
      </div>
    </div>

    <!-- Historial -->
    <div class="sc__history-wrap">
      <div class="sc__history-title">Historial de mails enviados</div>

      <div v-if="mailLoading" class="sc__loading"><DsSpinner :size="40" /></div>

      <div v-else-if="!mailHistory.length" class="sc__empty">
        <div class="sc__empty-ico"><Mail :size="24" /></div>
        <div class="sc__empty-title">Todavía no se envió ningún mail</div>
      </div>

      <div v-else class="sc__history">
        <div v-for="m in mailHistory" :key="m.id" class="sc__item">
          <div class="sc__item-ico"><Mail :size="14" /></div>
          <div class="sc__item-body">
            <div class="sc__item-subject">{{ m.asunto }}</div>
            <div class="sc__item-meta">
              {{ formatDateTime(m.enviado_at) }} · {{ m.remitente }} → {{ m.email_destino }}
            </div>
          </div>
          <div class="sc__item-tipo">
            <!-- El nombre de la plantilla con la que salió; si fue libre, el tipo crudo. -->
            <span class="sc__tipo-badge">{{ m.plantilla_nombre || m.tipo }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import { AlertTriangle, Mail } from 'lucide-vue-next'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { useSocioCorreo } from '../../composables/useSocioCorreo.js'

const props = defineProps({
  socioId: { type: Number, required: true },
  socio:   { type: Object, default: null },
})
defineEmits(['open-edit'])

const {
  mailHistory, mailLoading, mailSending, mailPreview, mailPlantilla, mailForm, plantillas,
  aplicarPlantilla, cargarPlantillas, loadMailHistory, submitMail,
} = useSocioCorreo(props.socioId, { s: computed(() => props.socio) })

onMounted(() => { loadMailHistory(); cargarPlantillas() })

function formatDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString('es-AR', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}
</script>

<style scoped>
/* No-email warning */
.sc__noemail {
  display: flex; align-items: flex-start; gap: .75rem;
  background: #fffbeb; border: 1px solid #fde68a; border-radius: 10px;
  padding: .875rem 1rem; margin-bottom: 1rem; font-size: .875rem; color: #92400e; flex-wrap: wrap;
}
.sc__noemail-ico { color: #d97706; flex-shrink: 0; margin-top: .1rem; }
.sc__edit-link {
  background: none; border: none; color: #1b5e20; font-weight: 700; font-size: .875rem;
  cursor: pointer; margin-left: auto; white-space: nowrap; padding: 0;
}
.sc__edit-link:hover { text-decoration: underline; }

/* Card */
.sc__card { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; overflow: hidden; margin-bottom: 1rem; }

/* Compose */
.sc__compose { display: flex; flex-direction: column; gap: .875rem; padding: 1.25rem; }
.sc__compose--disabled { opacity: .6; pointer-events: none; }

.sc__to {
  display: flex; align-items: center; gap: .4rem; flex-wrap: wrap;
  padding: .6rem .875rem; background: var(--c-slate-50); border-radius: 8px;
  font-size: .84rem; border: 1px solid #e8f0eb;
}
.sc__to-ico { color: #1b5e20; flex-shrink: 0; }
.sc__to-label { font-weight: 700; color: #6b7280; }
.sc__to-name { font-weight: 600; color: var(--c-slate-900); }
.sc__to-email { color: var(--c-slate-500); }
.sc__to-missing { color: #dc2626; font-style: italic; }

.sc__templates { display: flex; gap: .4rem; flex-wrap: wrap; }
.sc__tpl-chip {
  display: inline-flex; align-items: center; gap: .3rem;
  background: var(--c-slate-100); border: 1.5px solid var(--c-slate-200); border-radius: 20px;
  padding: .35rem .8rem; font-size: .8rem; font-weight: 600; color: var(--c-slate-600);
  cursor: pointer; transition: all .15s;
}
.sc__tpl-chip:hover { border-color: #1b5e20; color: #1b5e20; background: #f0fdf4; }
.sc__tpl-chip--active { background: #e8f5e9; border-color: #1b5e20; color: #1b5e20; }

.sc__field { display: flex; flex-direction: column; gap: .3rem; }
.sc__field-label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.sc__input {
  background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 8px;
  padding: .65rem .875rem; font-size: .875rem; color: var(--c-slate-900);
  width: 100%; box-sizing: border-box; transition: border .15s;
}
.sc__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); background: #fff; }
.sc__textarea {
  background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 8px;
  padding: .7rem .875rem; font-size: .875rem; color: var(--c-slate-900); line-height: 1.6;
  width: 100%; box-sizing: border-box; resize: vertical; min-height: 140px;
  transition: border .15s; font-family: inherit;
}
.sc__textarea:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); background: #fff; }
.sc__charcount { font-size: .7rem; color: var(--c-slate-400); text-align: right; margin-top: .2rem; }

.sc__preview {
  background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 8px;
  padding: 1.25rem 1rem; min-height: 180px;
}
.sc__preview-subject { font-weight: 700; color: var(--c-slate-900); font-size: .95rem; margin-bottom: .75rem; border-bottom: 1px solid var(--c-slate-200); padding-bottom: .6rem; }
.sc__preview-body { font-size: .875rem; color: var(--c-slate-700); line-height: 1.7; white-space: pre-wrap; }

.sc__actions { display: flex; align-items: center; justify-content: flex-end; gap: .5rem; flex-wrap: wrap; }
.sc__preview-btn {
  background: transparent; border: 1.5px solid var(--c-slate-200); color: var(--c-slate-600);
  padding: .6rem 1rem; border-radius: 8px; font-size: .84rem; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.sc__preview-btn:hover:not(:disabled) { border-color: #1b5e20; color: #1b5e20; }
.sc__preview-btn:disabled { opacity: .4; cursor: not-allowed; }
.sc__send-btn {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .65rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 700;
  cursor: pointer; transition: background .15s;
}
.sc__send-btn:hover:not(:disabled) { background: #144a18; }
.sc__send-btn:disabled { opacity: .55; cursor: not-allowed; }

/* History */
.sc__history-wrap { margin-top: 1.5rem; }
.sc__history-title { font-size: .72rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: var(--c-slate-400); margin-bottom: .75rem; }
.sc__loading { display: flex; justify-content: center; padding: 2rem; }
.sc__empty { text-align: center; padding: 1.5rem 1rem; color: var(--c-slate-400); }
.sc__empty-ico { display: flex; justify-content: center; margin-bottom: .5rem; opacity: .4; }
.sc__empty-title { font-size: .875rem; font-weight: 600; color: var(--c-slate-500); }
.sc__history { display: flex; flex-direction: column; gap: 0; background: #fff; border: 1px solid #e5e7eb; border-radius: 10px; overflow: hidden; }
.sc__item { display: flex; align-items: flex-start; gap: .75rem; padding: .875rem 1rem; border-bottom: 1px solid var(--c-slate-100); }
.sc__item:last-child { border-bottom: none; }
.sc__item-ico { width: 32px; height: 32px; flex-shrink: 0; border-radius: 8px; background: #e8f5e9; color: #1b5e20; display: flex; align-items: center; justify-content: center; }
.sc__item-body { flex: 1; min-width: 0; }
.sc__item-subject { font-size: .875rem; font-weight: 600; color: var(--c-slate-900); margin-bottom: .15rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.sc__item-meta { font-size: .75rem; color: var(--c-slate-400); }
.sc__item-tipo { flex-shrink: 0; }
.sc__tipo-badge { font-size: .7rem; font-weight: 600; background: var(--c-slate-100); color: var(--c-slate-600); padding: .15rem .5rem; border-radius: 5px; }
</style>
