<script setup>
/**
 * Los módulos de una organización, en una sola pantalla y sin botón de guardar.
 *
 * Antes esto vivía dentro de la ficha (1300 líneas) con un "Guardar" arriba de todo: tocabas
 * tres interruptores, te ibas a otra pestaña y no se había guardado nada. Un interruptor es una
 * decisión de una sola cosa —prender o apagar un módulo— y confirmarla dos veces no la hace más
 * segura, la hace más fácil de perder. Acá cada toggle se guarda solo y avisa qué pasó; lo único
 * que pregunta antes es la BAJA, que tiene consecuencias y una fecha que hay que leer.
 */
import { ref, computed } from 'vue'
import { updateSuperAdminClub, provisionarPulse, provisionarWhatsappClub,
         desconectarWhatsappClub, getSuperAdminCatalogo } from '../../lib/api.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { onMounted } from 'vue'

const props = defineProps({
  club: { type: Object, required: true },
})
const emit = defineEmits(['actualizado'])

const { confirm } = useConfirm()
const toast = useToast()

const guardando = ref(null)   // clave del módulo que se está guardando
const iaTiers   = ref([])

const ICONO = {
  cultivo: '🌱', produccion_dispensa: '⚖️',
  bar: '🍺', eventos: '🎉', medico: '🩺', iot: '📡', ia: '🤖',
  mailer: '✉️', whatsapp: '💬', ariccame: '📋', delivery: '🚚',
}

// Qué estado mostrar, en UNA palabra. El backend ya distingue prendido de andando.
const ESTADO = {
  andando:      { txt: 'Andando',      clase: 'sam__badge--ok' },
  falta_config: { txt: 'Falta configurar', clase: 'sam__badge--warn' },
}

const suites    = computed(() => props.club.suites || [])
const addons    = computed(() => props.club.addons || [])
const incluidos = computed(() => props.club.incluidos || [])
const enObra    = computed(() => props.club.en_construccion || [])
const features  = computed(() => props.club.features || {})
const bajas     = computed(() => props.club.features_baja || {})

const activos = computed(() =>
  [...suites.value, ...addons.value].filter(m => features.value[m.clave] === true).length
)

// Los adicionales van DEBAJO del pack al que le sirven, no en una lista plana de diez.
// La pantalla la usan dos personas y una de ellas no vive adentro de la app: "Buffet" y
// "Ambiente / IoT" uno al lado del otro no dicen para qué es cada uno ni qué hay que tener
// contratado para que sirvan. El `pack` lo manda el backend (`Club::ADDONS`), no se decide acá.
function addonsDe(packClave) {
  return addons.value.filter(a => a.pack === packClave)
}
const addonsTransversales = computed(() => addons.value.filter(a => !a.pack))

// Un grupo por pack, en el mismo orden que los packs, y los transversales al final. Se arma acá
// y no en el template para poder decir además si el pack está contratado: un adicional de
// Cultivo en una organización sin Cultivo se puede prender y no hace nada.
const addonsAgrupados = computed(() => {
  const grupos = suites.value
    .map(s => ({
      titulo:    `Adicionales de ${s.label}`,
      sinPack:   !features.value[s.clave],
      packLabel: s.label,
      items:     addonsDe(s.clave),
    }))
    .filter(g => g.items.length)

  if (addonsTransversales.value.length) {
    grupos.push({
      titulo:  'Sirven a los dos packs',
      sinPack: false,
      items:   addonsTransversales.value,
    })
  }
  return grupos
})

// Los módulos que vienen dentro de una suite se muestran como una línea DEBAJO de ella, no como
// tarjetas aparte: no son una decisión, son parte de lo que ya se compró.
function incluidosDe(suiteClave) {
  return incluidos.value.filter(i => i.incluido_en === suiteClave)
}

function fechaCorta(f) {
  if (!f) return ''
  return new Date(String(f) + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'long' })
}

// ── Prender / apagar ────────────────────────────────────────────────────────────
async function alternar(modulo) {
  // Bloqueado: no se prende ni para probar. El backend lo rechaza igual —el candado no vive en
  // el toggle— pero un interruptor que se mueve y vuelve solo parece un error de la app.
  if (modulo.bloqueado && features.value[modulo.clave] !== true) {
    toast.warning(`${modulo.label} todavía no se puede activar. ${modulo.motivo_bloqueo || ''}`.trim())
    return
  }
  const prendido = features.value[modulo.clave] === true
  if (prendido) return apagar(modulo)
  return guardar({ ...features.value, [modulo.clave]: true }, modulo, 'prendido')
}

// Apagar programa una baja para el fin del período pago: la organización pagó el mes y hasta
// ahí lo sigue teniendo. Se explica ANTES de tocar nada, porque "apagar" sugiere que se corta
// hoy y no es lo que pasa.
async function apagar(modulo) {
  if (bajas.value[modulo.clave]) {
    // Ya estaba dado de baja y lo vuelve a tocar: eso CANCELA la baja.
    return guardar({ ...features.value, [modulo.clave]: true }, modulo, 'baja cancelada')
  }
  const ok = await confirm({
    title: `Dar de baja ${modulo.label}`,
    message: 'No se corta hoy: sigue andando hasta el final del período que la organización ya pagó, ' +
             'y después se apaga solo. Podés volver a prenderlo antes de esa fecha y la baja se cancela.',
    confirmText: 'Dar de baja',
    variant: 'danger',
  })
  if (!ok) return
  return guardar({ ...features.value, [modulo.clave]: false }, modulo, 'baja')
}

async function guardar(featuresNuevas, modulo, accion) {
  guardando.value = modulo.clave
  try {
    const { data } = await updateSuperAdminClub(props.club.id, { features: featuresNuevas })
    emit('actualizado', data)
    const baja = (data.bajas_programadas || [])[0]
    if (baja) {
      toast.success(`${modulo.label} sigue andando hasta el ${fechaCorta(baja.hasta)}.`)
    } else if (accion === 'baja cancelada') {
      toast.success(`${modulo.label}: baja cancelada, sigue como estaba.`)
    } else {
      toast.success(`${modulo.label} ${accion}.`)
    }
  } catch (e) {
    toast.error(e?.response?.data?.errors?.join(', ') || `No se pudo guardar ${modulo.label}`)
  } finally {
    guardando.value = null
  }
}

// ── IA: un solo control ─────────────────────────────────────────────────────────
//
// Había dos perillas —el tramo y un "límite por hora" que lo sobrescribía— y la que estaba a la
// vista era la que menos importa: lo que se COBRA es el tope mensual. Ahora se elige el tramo y
// listo; al elegirlo se limpia el override horario (0 = usar el del tramo) para que no quede un
// número viejo aplicándose sin que nadie lo vea.
async function elegirTier(tier) {
  guardando.value = 'ia'
  try {
    const { data } = await updateSuperAdminClub(props.club.id, { ia_tier: tier.clave, ia_limite_hora: 0 })
    emit('actualizado', data)
    toast.success(`Asistente IA: plan ${tier.label} (${tier.limite_mes.toLocaleString('es-AR')} créditos por mes).`)
  } catch {
    toast.error('No se pudo cambiar el plan de IA')
  } finally {
    guardando.value = null
  }
}

const iaUso = computed(() => props.club.ia_uso)
// Qué preguntas puede contestar el chatbot con los datos que la organización tiene cargados.
const chatbotListo = computed(() => props.club.chatbot_listo || [])
const iaPorcentaje = computed(() => {
  const u = iaUso.value
  if (!u?.tope) return 0
  // Contra créditos, que es la unidad del tope. Con `llamadas` la barra podía marcar 30% y el
  // dictado salir rechazado.
  return Math.min(100, Math.round((u.creditos / u.tope) * 100))
})
// ── Pulse Grow (IoT) ────────────────────────────────────────────────────────────
const pulseKey    = ref('')
const savingPulse = ref(false)

async function guardarPulse() {
  if (!pulseKey.value) { toast.error('Pegá la API key primero'); return }
  savingPulse.value = true
  try {
    const { data } = await provisionarPulse(props.club.id, pulseKey.value)
    emit('actualizado', data)
    pulseKey.value = ''
    toast.success('API key guardada. Los sensores ya pueden leerse.')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo guardar')
  } finally { savingPulse.value = false }
}

async function borrarPulse() {
  savingPulse.value = true
  try {
    const { data } = await provisionarPulse(props.club.id, '')
    emit('actualizado', data)
    toast.success('API key quitada')
  } finally { savingPulse.value = false }
}

// ── WhatsApp (Twilio) ───────────────────────────────────────────────────────────
const waForm   = ref({ twilio_account_sid: '', twilio_auth_token: '', twilio_whatsapp_from: '' })
const savingWa = ref(false)

async function guardarWhatsapp() {
  savingWa.value = true
  try {
    const payload = { ...waForm.value }
    if (!payload.twilio_auth_token) delete payload.twilio_auth_token
    const { data } = await provisionarWhatsappClub(props.club.id, payload)
    emit('actualizado', data)
    waForm.value.twilio_auth_token = ''
    toast.success('WhatsApp conectado')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo conectar')
  } finally { savingWa.value = false }
}

async function desconectarWhatsapp() {
  try {
    const { data } = await desconectarWhatsappClub(props.club.id)
    emit('actualizado', data)
    toast.success('WhatsApp desconectado')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'Error')
  }
}

onMounted(async () => {
  waForm.value = {
    twilio_account_sid:   props.club.twilio_account_sid   || '',
    twilio_auth_token:    '',
    twilio_whatsapp_from: props.club.twilio_whatsapp_from || '',
  }
  try {
    const { data } = await getSuperAdminCatalogo()
    iaTiers.value = data.ia_tiers || []
  } catch { /* sin catálogo no se ofrecen tramos; el que tiene guardado sigue aplicando */ }
})
</script>

<template>
  <div class="sam">

    <div class="sam__hd">
      <span class="sam__hd-title">Módulos</span>
      <span class="sam__hd-count">{{ activos }} activo{{ activos === 1 ? '' : 's' }}</span>
      <span class="sam__hd-hint">Cada cambio se guarda solo</span>
    </div>

    <!-- ── Suites: lo que se contrata ── -->
    <div class="sam__group">
      <div class="sam__group-lbl">Qué contrató</div>
      <div class="sam__suite" v-for="s in suites" :key="s.clave"
           :class="{ 'sam__suite--on': features[s.clave] }">
        <span class="sam__ico">{{ ICONO[s.clave] || '🧩' }}</span>
        <div class="sam__txt">
          <div class="sam__name">{{ s.label }}</div>
          <div class="sam__desc">{{ s.desc }}</div>
          <div v-if="incluidosDe(s.clave).length && features[s.clave]" class="sam__incluye">
            Incluye: {{ incluidosDe(s.clave).map(i => i.label).join(', ') }}
          </div>
          <div v-if="bajas[s.clave]" class="sam__baja">
            Dada de baja — sigue andando hasta el {{ fechaCorta(bajas[s.clave]) }}
          </div>
        </div>
        <DsSpinner v-if="guardando === s.clave" :size="16" />
        <button v-else class="sam__switch" :class="{ 'sam__switch--on': features[s.clave] }"
                type="button" role="switch" :aria-checked="!!features[s.clave]"
                :aria-label="s.label" @click="alternar(s)">
          <span class="sam__knob"></span>
        </button>
      </div>
    </div>

    <!-- ── Adicionales, agrupados por el pack al que le sirven ── -->
    <div class="sam__group" v-for="g in addonsAgrupados" :key="g.titulo">
      <div class="sam__group-lbl">{{ g.titulo }}</div>
      <div v-if="g.sinPack" class="sam__group-nota">
        {{ g.packLabel }} no está contratado: prender esto no va a hacer nada.
      </div>
      <div v-for="a in g.items" :key="a.clave" class="sam__addon"
           :class="{ 'sam__addon--on': features[a.clave], 'sam__addon--off': a.bloqueado }">

        <div class="sam__row">
          <span class="sam__ico">{{ ICONO[a.clave] || '🧩' }}</span>
          <div class="sam__txt">
            <div class="sam__name">
              {{ a.label }}
              <span v-if="features[a.clave] && ESTADO[a.estado]"
                    class="sam__badge" :class="ESTADO[a.estado].clase">{{ ESTADO[a.estado].txt }}</span>
              <span v-if="a.bloqueado" class="sam__badge sam__badge--off">no disponible</span>
              <span v-else-if="a.incompleto" class="sam__badge sam__badge--obra">en construcción</span>
            </div>
            <div class="sam__desc">{{ a.desc }}</div>
            <!-- Qué le falta a ESTA organización, que es distinto de qué necesita el módulo. -->
            <div v-if="bajas[a.clave]" class="sam__baja">
              Dado de baja — sigue andando hasta el {{ fechaCorta(bajas[a.clave]) }}
            </div>
            <div v-else-if="a.bloqueado" class="sam__falta">{{ a.motivo_bloqueo }}</div>
            <div v-else-if="a.falta" class="sam__falta">{{ a.falta }}</div>
            <div v-else-if="a.requiere && !features[a.clave]" class="sam__desc sam__desc--req">{{ a.requiere }}</div>
          </div>
          <DsSpinner v-if="guardando === a.clave" :size="16" />
          <button v-else class="sam__switch"
                  :class="{ 'sam__switch--on': features[a.clave], 'sam__switch--off': a.bloqueado && !features[a.clave] }"
                  type="button" role="switch" :aria-checked="!!features[a.clave]"
                  :disabled="a.bloqueado && !features[a.clave]"
                  :aria-label="a.label" @click="alternar(a)">
            <span class="sam__knob"></span>
          </button>
        </div>

        <!-- La configuración aparece SOLO si el módulo está prendido y sólo la que hace falta. -->

        <!-- IA: el tramo y lo que va consumido -->
        <div v-if="a.clave === 'ia' && features.ia" class="sam__cfg">
          <div class="sam__tiers">
            <button v-for="t in iaTiers" :key="t.clave" type="button"
                    class="sam__tier" :class="{ 'sam__tier--on': (club.ia_tier || 'basico') === t.clave }"
                    @click="elegirTier(t)">
              <strong>{{ t.label }}</strong>
              <span>{{ t.limite_mes.toLocaleString('es-AR') }} créditos por mes</span>
            </button>
          </div>

          <!-- Cuánto va del mes. Se medía desde el 11-ago y no se veía en ninguna pantalla:
               se fijaba el tope sin poder mirar contra qué. -->
          <div v-if="iaUso" class="sam__uso">
            <div class="sam__uso-hd">
              <span>Este mes</span>
              <!-- CRÉDITOS, no llamadas: el tope se cuenta en créditos desde que una importación
                   de plan de trabajo dejó de valer lo mismo que un mapeo de CSV. Mostraba
                   `llamadas` contra un tope de créditos —dos unidades en la misma barra— y la
                   organización se podía quedar sin IA en un número distinto al que veía acá. -->
              <strong>{{ iaUso.creditos }} de {{ (iaUso.tope || 0).toLocaleString('es-AR') }} créditos</strong>
            </div>
            <div class="sam__bar">
              <div class="sam__bar-fill" :class="{ 'sam__bar-fill--alto': iaPorcentaje >= 80 }"
                   :style="{ width: iaPorcentaje + '%' }"></div>
            </div>
            <div class="sam__uso-meta">
              <span>Costo: US$ {{ iaUso.costo_usd }}</span>
              <span>·</span>
              <!-- Si el hit ratio cae a 0 con el asistente en uso, algo rompió el caché del
                   prompt: es la única forma de enterarse, porque no falla, sale más caro. -->
              <span>Caché: {{ iaUso.cache_hit }}%</span>
              <span>·</span>
              <span>{{ iaUso.llamadas }} llamada{{ iaUso.llamadas === 1 ? '' : 's' }} a la API</span>
            </div>
            <!-- En créditos y no en cantidad: una función puede usarse poco y costar ocho veces
                 más que otra, y contando llamadas eso no se ve. Las etiquetas salen del backend
                 para no tener la lista de funciones escrita en dos lados. -->
            <div v-if="(iaUso.desglose || []).length" class="sam__uso-fn">
              <span v-for="d in iaUso.desglose" :key="d.funcion">
                {{ d.label }}: <strong>{{ d.creditos }}</strong>
                <span class="sam__uso-fn-n">({{ d.llamadas }})</span>
              </span>
            </div>
          </div>
        </div>

        <!-- Qué va a poder contestar el chatbot en ESTA organización.
             No bloquea el toggle a propósito: con bloqueo duro no se podría prender ni para
             probar, y una organización sin datos hoy los tiene el mes que viene — el toggle
             quedaría muerto hasta que alguien note que ya se puede. Decir QUÉ va a poder hacer
             es más útil que un sí/no que no explica nada. -->
        <div v-if="a.clave === 'chatbot' && chatbotListo.length" class="sam__cfg">
          <div class="sam__cfg-hd">Con los datos de hoy va a poder contestar</div>
          <div v-for="c in chatbotListo" :key="c.pregunta" class="sam__cap">
            <span class="sam__cap-icon" :class="c.puede ? 'sam__cap-icon--si' : 'sam__cap-icon--no'">
              {{ c.puede ? '✓' : '·' }}
            </span>
            <span :class="{ 'sam__cap--no': !c.puede }">
              {{ c.pregunta }}<template v-if="!c.puede"> — {{ c.falta }}</template>
            </span>
          </div>
        </div>

        <!-- IoT: la API key de Pulse -->
        <div v-if="a.clave === 'iot' && features.iot" class="sam__cfg">
          <div class="sam__cfg-hd">
            API key de Pulse Grow
            <span class="sam__badge" :class="club.pulse_configurado ? 'sam__badge--ok' : 'sam__badge--warn'">
              {{ club.pulse_configurado ? 'Cargada' : 'Falta' }}
            </span>
          </div>
          <p class="sam__hint">Con una sola key se leen todos los sensores. Se saca de
            <strong>pulsegrow.com → Settings → API</strong>. También sirve el hardware propio dado de alta.</p>
          <div class="sam__cfg-row">
            <input v-model.trim="pulseKey" type="password" class="sam__input"
                   :placeholder="club.pulse_configurado ? '•••••••• (vacío = no cambiar)' : 'Pegá la API key'" />
            <button class="sam__btn" :disabled="savingPulse" @click="guardarPulse">
              {{ savingPulse ? 'Guardando…' : 'Guardar' }}
            </button>
            <button v-if="club.pulse_configurado" class="sam__btn sam__btn--danger"
                    :disabled="savingPulse" @click="borrarPulse">Quitar</button>
          </div>
        </div>

        <!-- WhatsApp: las credenciales de Twilio -->
        <div v-if="a.clave === 'whatsapp' && features.whatsapp" class="sam__cfg">
          <div class="sam__cfg-hd">
            Cuenta de Twilio
            <span class="sam__badge" :class="club.whatsapp_estado === 'conectado' ? 'sam__badge--ok' : 'sam__badge--warn'">
              {{ club.whatsapp_estado === 'conectado' ? 'Conectado' : 'Sin conectar' }}
            </span>
          </div>
          <p class="sam__hint">El número y la cuenta son de la organización: los avisos salen desde ahí.</p>
          <div class="sam__cfg-grid">
            <input v-model.trim="waForm.twilio_account_sid" class="sam__input" placeholder="Account SID" />
            <input v-model.trim="waForm.twilio_auth_token" type="password" class="sam__input"
                   :placeholder="club.whatsapp_estado === 'conectado' ? '•••••••• (vacío = no cambiar)' : 'Auth Token'" />
            <input v-model.trim="waForm.twilio_whatsapp_from" class="sam__input" placeholder="+54911..." />
          </div>
          <div class="sam__cfg-row">
            <button class="sam__btn" :disabled="savingWa" @click="guardarWhatsapp">
              {{ savingWa ? 'Guardando…' : 'Guardar credenciales' }}
            </button>
            <button v-if="club.whatsapp_estado === 'conectado'" class="sam__btn sam__btn--danger"
                    @click="desconectarWhatsapp">Desconectar</button>
          </div>
        </div>

      </div>
    </div>

    <!-- ── Todavía no existe ── -->
    <div v-if="enObra.length" class="sam__obra">
      <span v-for="e in enObra" :key="e.clave">
        <strong>{{ e.label }}</strong> — en construcción, todavía no se puede activar.
      </span>
    </div>

  </div>
</template>

<style scoped>
.sam { display: flex; flex-direction: column; gap: 1.25rem; padding: 1.25rem; }

/* Encabezado */
.sam__hd { display: flex; align-items: baseline; gap: .6rem; }
.sam__hd-title { font-size: .95rem; font-weight: 800; color: var(--c-slate-900); }
.sam__hd-count {
  font-size: .7rem; font-weight: 700; color: #15803d; background: #dcfce7;
  padding: .15em .6em; border-radius: 999px;
}
.sam__hd-hint { margin-left: auto; font-size: .72rem; color: var(--c-slate-400); }

.sam__group { display: flex; flex-direction: column; gap: .5rem; }
.sam__group-lbl {
  font-size: .68rem; font-weight: 800; text-transform: uppercase; letter-spacing: .06em;
  color: var(--c-slate-400);
}

.sam__group-nota {
  font-size: .74rem; color: #92400e; background: #fffbeb;
  border: 1px solid #fde68a; border-radius: 8px; padding: .45rem .65rem;
}

/* Fila común */
.sam__row { display: flex; align-items: flex-start; gap: .7rem; padding: .8rem .9rem; }
.sam__ico { font-size: 1.05rem; line-height: 1.3; flex-shrink: 0; }
.sam__txt { flex: 1; min-width: 0; }
.sam__name { font-size: .875rem; font-weight: 700; color: var(--c-slate-900); }
.sam__desc { font-size: .75rem; color: var(--c-slate-500); margin-top: 2px; line-height: 1.45; }
.sam__desc--req { color: var(--c-slate-400); }
.sam__incluye { font-size: .72rem; color: #15803d; margin-top: 4px; font-weight: 600; }
.sam__falta { font-size: .72rem; color: #b45309; margin-top: 4px; line-height: 1.4; }
/* Una baja no es un problema a resolver: es una fecha acordada. Por eso azul y no ámbar. */
.sam__baja { font-size: .72rem; color: #0369a1; margin-top: 4px; font-weight: 600; }

/* Suites: más peso visual, son lo que se vende */
.sam__suite {
  display: flex; align-items: flex-start; gap: .8rem; padding: .95rem 1rem;
  border: 1.5px solid var(--c-slate-200); border-radius: 12px; background: var(--c-slate-50);
  transition: border-color .15s, background .15s;
}
.sam__suite--on { border-color: #86efac; background: #f0fdf4; }
.sam__suite .sam__name { font-size: .95rem; }

/* Add-ons */
.sam__addon {
  border: 1.5px solid var(--c-slate-200); border-radius: 10px;
  background: var(--c-slate-50); overflow: hidden; transition: border-color .15s, background .15s;
}
.sam__addon--on { border-color: #86efac; background: #fff; }
/* Bloqueado: se ve, se entiende por qué, y no se puede tocar. */
.sam__addon--off { opacity: .62; }

/* Interruptor: botón de verdad, no un label con checkbox escondido — así lo alcanza el
   teclado y anuncia su estado. */
.sam__switch {
  width: 38px; height: 22px; border-radius: 999px; border: none; flex-shrink: 0;
  background: var(--c-slate-300); position: relative; cursor: pointer;
  transition: background .2s; padding: 0; margin-top: 2px;
}
.sam__switch--on { background: #15803d; }
.sam__switch--off { cursor: not-allowed; opacity: .5; }
.sam__knob {
  position: absolute; width: 16px; height: 16px; background: #fff; border-radius: 50%;
  top: 3px; left: 3px; transition: left .2s; box-shadow: 0 1px 2px rgba(0,0,0,.25);
}
.sam__switch--on .sam__knob { left: 19px; }
.sam__switch:focus-visible { outline: 2px solid #15803d; outline-offset: 2px; }

/* Estado en una palabra */
.sam__badge {
  margin-left: .4rem; font-size: .62rem; font-weight: 800; text-transform: uppercase;
  letter-spacing: .04em; padding: .2em .55em; border-radius: 5px; white-space: nowrap;
}
.sam__badge--ok   { background: #dcfce7; color: #15803d; }
.sam__badge--warn { background: #fef3c7; color: #b45309; }
.sam__badge--obra { background: var(--c-slate-100); color: var(--c-slate-500); }
.sam__badge--off { background: var(--c-slate-200); color: var(--c-slate-600); }

/* Configuración inline */
.sam__cfg {
  border-top: 1px solid var(--c-slate-200); background: var(--c-slate-50);
  padding: .85rem .9rem; display: flex; flex-direction: column; gap: .6rem;
}
.sam__cfg-hd {
  display: flex; align-items: center; gap: .5rem;
  font-size: .76rem; font-weight: 700; color: var(--c-slate-900);
}
.sam__cfg-row { display: flex; gap: .5rem; align-items: center; flex-wrap: wrap; }
.sam__cfg-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: .5rem; }
.sam__hint { font-size: .72rem; color: var(--c-slate-500); margin: 0; line-height: 1.45; }
.sam__input {
  background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 8px;
  padding: .5rem .8rem; font-size: .82rem; color: var(--c-slate-900);
  flex: 1; min-width: 170px; box-sizing: border-box;
}
.sam__input:focus { outline: none; border-color: #15803d; box-shadow: 0 0 0 3px rgba(21,128,61,.08); }
.sam__btn {
  background: #fff; color: var(--c-slate-600); border: 1.5px solid var(--c-slate-200);
  padding: .45rem .8rem; border-radius: 8px; font-size: .75rem; font-weight: 600;
  cursor: pointer; white-space: nowrap; transition: all .15s;
}
.sam__btn:hover:not(:disabled) { background: var(--c-slate-50); border-color: var(--c-slate-400); }
.sam__btn:disabled { opacity: .6; cursor: not-allowed; }
.sam__btn--danger { color: #b91c1c; border-color: #fca5a5; }
.sam__btn--danger:hover { background: #fef2f2; }

/* IA: tramos */
.sam__tiers { display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: .5rem; }
.sam__tier {
  display: flex; flex-direction: column; gap: 2px; text-align: left;
  padding: .6rem .7rem; border-radius: 9px; cursor: pointer;
  border: 1.5px solid var(--c-slate-200); background: #fff; transition: all .15s;
}
.sam__tier strong { font-size: .8rem; color: var(--c-slate-900); }
.sam__tier span { font-size: .68rem; color: var(--c-slate-500); }
.sam__tier--on { border-color: #15803d; background: #f0fdf4; }
.sam__tier--on strong { color: #15803d; }

/* IA: consumo */
.sam__uso {
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 9px;
  padding: .7rem .8rem; display: flex; flex-direction: column; gap: .45rem;
}
.sam__uso-hd { display: flex; justify-content: space-between; align-items: baseline; font-size: .74rem; color: var(--c-slate-500); }
.sam__uso-hd strong { font-size: .8rem; color: var(--c-slate-900); }
.sam__bar { height: 6px; background: var(--c-slate-100); border-radius: 999px; overflow: hidden; }
.sam__bar-fill { height: 100%; background: #15803d; border-radius: 999px; transition: width .3s; }
.sam__bar-fill--alto { background: #b45309; }
.sam__uso-meta { display: flex; gap: .4rem; font-size: .7rem; color: var(--c-slate-500); }
.sam__uso-fn { display: flex; flex-wrap: wrap; gap: .6rem; font-size: .7rem; color: var(--c-slate-500); }
.sam__uso-fn-n { opacity: .6; }
.sam__cap { display: flex; align-items: flex-start; gap: .45rem; font-size: .74rem; color: var(--c-slate-600); line-height: 1.45; padding: .1rem 0; }
.sam__cap-icon { flex-shrink: 0; font-weight: 700; width: .8rem; }
.sam__cap-icon--si { color: #2D8A6B; }
.sam__cap-icon--no { color: var(--c-slate-300); }
.sam__cap--no { color: var(--c-slate-400); }
.sam__uso-fn strong { color: var(--c-slate-900); }

/* En construcción */
.sam__obra { display: flex; flex-direction: column; gap: .25rem; font-size: .72rem; color: var(--c-slate-400); }
.sam__obra strong { color: var(--c-slate-500); }
</style>
