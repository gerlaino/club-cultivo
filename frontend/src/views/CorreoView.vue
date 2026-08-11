<script setup>
// Correo electrónico de la organización: la casilla desde donde salen los mails y las
// plantillas con las que se escriben.
//
// La conexión de la casilla estaba en Configuración → General, mezclada con el nombre y el
// logo. Se movió acá porque ahora es un módulo contratable con espacio propio, y porque el
// orden importa: sin casilla conectada las plantillas no sirven para nada, así que la pantalla
// lo dice en vez de ofrecer un editor que no manda.
import { onMounted, reactive, ref, computed } from 'vue'
import { useClubStore } from '../stores/club'
import { useConfirm } from '../composables/useConfirm.js'
import { useToast } from '../composables/useToast.js'
import DsSpinner from '../design-system/components/Spinner.vue'
import EnvioMasivo from '../components/correo/EnvioMasivo.vue'
import {
  testSmtp, conectarEmail, desconectarEmail,
  fetchPlantillasMail, crearPlantillaMail, updatePlantillaMail, borrarPlantillaMail,
} from '../lib/api.js'

const club = useClubStore()
const { confirm } = useConfirm()
const { success: toastOk, error: toastErr } = useToast()

/* ── Casilla ─────────────────────────────────────────────────────── */
const conectarForm = reactive({ email: '', app_password: '', from_name: '' })
const conectando   = ref(false)
const smtpTesting  = ref(false)

// Contratado ≠ configurado. `mailer` dice si la organización tiene el módulo; `email_modo`,
// si además conectó la casilla. Son dos preguntas distintas y la pantalla las separa.
const tieneModulo = computed(() => club.data?.features?.mailer === true)
const conectado   = computed(() => club.data?.email_modo === 'propio')
const remitente  = computed(() => club.data?.email_remitente || club.data?.smtp_from || '')

async function conectar() {
  if (!conectarForm.email || !conectarForm.app_password) {
    return toastErr('Ingresá el email de la organización y la contraseña de aplicación.')
  }
  conectando.value = true
  try {
    await conectarEmail({ ...conectarForm })
    await club.fetch()
    conectarForm.app_password = ''
    toastOk('Casilla conectada — ya mandás desde tu correo')
    cargarPlantillas()
  } catch (e) {
    toastErr(e?.response?.data?.error || 'No se pudo conectar')
  } finally {
    conectando.value = false
  }
}

async function desconectar() {
  const ok = await confirm({
    title: '¿Desconectar la casilla?',
    // Sin casilla NO se manda nada: `ApplicationMailer#mail_para_club` corta antes de enviar.
    // El texto viejo decía que los mails "volvían a salir desde la plataforma", que no pasa.
    message: 'La organización va a dejar de poder mandar mails: ni los de bienvenida ni los que se escriben desde la ficha del paciente. Las plantillas quedan guardadas.',
    confirmText: 'Desconectar',
  })
  if (!ok) return
  try {
    await desconectarEmail()
    await club.fetch()
    toastOk('Casilla desconectada')
  } catch (e) {
    toastErr(e?.response?.data?.error || 'Error al desconectar')
  }
}

async function probar() {
  smtpTesting.value = true
  try {
    const { data } = await testSmtp()
    toastOk(`Mail de prueba enviado a ${data.enviado_a}`)
  } catch (e) {
    toastErr(e?.response?.data?.error || 'Error al enviar el mail de prueba')
  } finally {
    smtpTesting.value = false
  }
}

/* ── Plantillas ──────────────────────────────────────────────────── */
const plantillas = ref([])
const variables  = ref([])
const cargando   = ref(true)
const guardando  = ref(false)
const editando   = ref(null)   // objeto en edición, o null
const form       = reactive({ nombre: '', asunto: '', cuerpo: '', activa: true, bienvenida: false })

// Paciente de mentira para la vista previa. Es el único lugar donde se resuelven las variables
// en el frontend; el mail de verdad lo arma el backend con el paciente real.
const EJEMPLO = {
  nombre: 'Ana', apellido: 'Pérez', nombre_completo: 'Ana Pérez',
  reprocann_numero: 'RP-123456', reprocann_vencimiento: '20/03/2029',
}

function resolver(texto) {
  const org = club.data?.name || 'tu organización'
  return String(texto || '').replace(/\{\{\s*([a-z_]+)\s*\}\}/g, (crudo, clave) => {
    if (clave === 'organizacion') return org
    return EJEMPLO[clave] !== undefined ? EJEMPLO[clave] : crudo
  })
}

const previewAsunto = computed(() => resolver(form.asunto))
const previewCuerpo = computed(() => resolver(form.cuerpo))

// Variables escritas que no existen: se muestran para que el admin lo vea acá y no en el mail
// que ya recibió el paciente.
const variablesDesconocidas = computed(() => {
  const validas = new Set(variables.value.map(v => v.clave))
  const usadas  = [...`${form.asunto} ${form.cuerpo}`.matchAll(/\{\{\s*([a-z_]+)\s*\}\}/g)].map(m => m[1])
  return [...new Set(usadas.filter(u => !validas.has(u)))]
})

async function cargarPlantillas() {
  cargando.value = true
  try {
    const { data } = await fetchPlantillasMail()
    plantillas.value = data.data || []
    variables.value  = data.variables || []
  } catch (e) {
    // 403 = la organización no tiene el módulo. No es un error para gritar: la pantalla no
    // debería ser alcanzable, y si lo fue, se muestra vacía.
    if (e?.response?.status !== 403) toastErr('No se pudieron cargar las plantillas')
  } finally {
    cargando.value = false
  }
}

function nueva() {
  editando.value = { id: null }
  Object.assign(form, { nombre: '', asunto: '', cuerpo: '', activa: true, bienvenida: false })
}

function editar(p) {
  editando.value = p
  Object.assign(form, { nombre: p.nombre, asunto: p.asunto, cuerpo: p.cuerpo, activa: p.activa, bienvenida: p.bienvenida })
}

function cerrar() { editando.value = null }

async function guardar() {
  if (!form.nombre.trim() || !form.asunto.trim() || !form.cuerpo.trim()) {
    return toastErr('El nombre, el asunto y el cuerpo son obligatorios.')
  }
  guardando.value = true
  try {
    if (editando.value.id) await updatePlantillaMail(editando.value.id, { ...form })
    else                   await crearPlantillaMail({ ...form })
    await cargarPlantillas()
    cerrar()
    toastOk('Plantilla guardada')
  } catch (e) {
    toastErr(e?.response?.data?.errors?.join(', ') || 'No se pudo guardar')
  } finally {
    guardando.value = false
  }
}

async function borrar(p) {
  const ok = await confirm({
    title: `¿Borrar "${p.nombre}"?`,
    message: 'Los mails que ya se enviaron con esta plantilla quedan en el historial de cada paciente.',
    confirmText: 'Borrar',
    danger: true,
  })
  if (!ok) return
  try {
    await borrarPlantillaMail(p.id)
    await cargarPlantillas()
    toastOk('Plantilla borrada')
  } catch { toastErr('No se pudo borrar') }
}

// Escribir las llaves literales dentro de una interpolación rompe el parser de Vue —lee el
// `{{` de adentro como una interpolación nueva—, así que se arman acá.
const llaves = (clave) => `{{${clave}}}`

function insertarVariable(clave) {
  form.cuerpo = `${form.cuerpo}{{${clave}}}`
}

onMounted(async () => {
  if (!club.data) await club.fetch()
  cargarPlantillas()
})
</script>

<template>
  <div class="cv">

    <!-- El módulo se puede dar de baja, y a esta URL se puede llegar tipeándola. Sin esto se
         veía media pantalla —el formulario de la casilla— sobre un backend que responde 403. -->
    <div v-if="!tieneModulo" class="cv__card">
      <div class="cv__vacio">
        <i class="bi bi-envelope-slash cv__vacio-ico"></i>
        <p class="cv__vacio-txt">
          Tu organización no tiene contratado el módulo de <strong>Correo electrónico</strong>.
          Escribinos si querés activarlo.
        </p>
      </div>
    </div>

    <template v-else>
    <!-- Casilla ─────────────────────────────────────────────── -->
    <section class="cv__card">
      <header class="cv__card-head">
        <div class="cv__card-ico"><i class="bi bi-envelope-at"></i></div>
        <div class="cv__card-titles">
          <h2 class="cv__card-title">Casilla de la organización</h2>
          <p class="cv__card-sub">Desde dónde salen los mails a los pacientes</p>
        </div>
        <span class="cv__badge" :class="conectado ? 'cv__badge--ok' : 'cv__badge--off'">
          <i :class="conectado ? 'bi bi-check-circle-fill' : 'bi bi-x-circle-fill'"></i>
          {{ conectado ? 'Conectada' : 'Sin conectar' }}
        </span>
      </header>

      <div class="cv__card-body">
        <template v-if="conectado">
          <div class="cv__nota cv__nota--ok">
            <i class="bi bi-check-circle-fill"></i>
            <span>Los mails salen desde <strong>{{ remitente }}</strong>.</span>
          </div>
          <div class="cv__acciones">
            <button class="cv__btn-outline" :disabled="smtpTesting" @click="probar">
              <DsSpinner v-if="smtpTesting" :size="15" />
              <i v-else class="bi bi-send"></i>
              {{ smtpTesting ? 'Enviando…' : 'Enviar mail de prueba' }}
            </button>
            <button class="cv__btn-ghost-danger" @click="desconectar">
              <i class="bi bi-box-arrow-left"></i> Desconectar
            </button>
          </div>
        </template>

        <template v-else>
          <div class="cv__nota cv__nota--info">
            <i class="bi bi-info-circle-fill"></i>
            <span>Conectá la casilla para poder mandar mails. Para Gmail necesitás una <strong>contraseña de aplicación</strong>, no tu contraseña normal.</span>
          </div>
          <ol class="cv__pasos">
            <li>Entrá a tu cuenta de Google → <strong>Seguridad</strong>.</li>
            <li>Activá la <strong>Verificación en 2 pasos</strong>, si no la tenés.</li>
            <li>Abrí <a href="https://myaccount.google.com/apppasswords" target="_blank" rel="noopener">myaccount.google.com/apppasswords</a> y creá una contraseña de aplicación.</li>
            <li>Copiá las <strong>16 letras</strong> y pegalas acá abajo.</li>
          </ol>
          <div class="cv__grid">
            <div class="cv__field">
              <label class="cv__label">Email de la organización</label>
              <input class="cv__input" type="email" v-model.trim="conectarForm.email" placeholder="miorganizacion@gmail.com" autocomplete="off" />
              <span class="cv__hint">Gmail, Outlook o Yahoo se detectan solos</span>
            </div>
            <div class="cv__field">
              <label class="cv__label">Contraseña de aplicación</label>
              <input class="cv__input" type="password" v-model.trim="conectarForm.app_password" placeholder="16 caracteres" autocomplete="new-password" />
            </div>
            <div class="cv__field cv__field--full">
              <label class="cv__label">Nombre para mostrar <span class="cv__opt">opcional</span></label>
              <input class="cv__input" v-model.trim="conectarForm.from_name" :placeholder="club.data?.name || 'Mi organización'" />
              <span class="cv__hint">Lo que ve el paciente como remitente</span>
            </div>
          </div>
          <div class="cv__acciones">
            <button class="cv__btn-primary" :disabled="conectando" @click="conectar">
              <DsSpinner v-if="conectando" :size="15" />
              <i v-else class="bi bi-plug"></i>
              {{ conectando ? 'Conectando…' : 'Probar y conectar' }}
            </button>
          </div>
        </template>
      </div>
    </section>

    <!-- Plantillas ──────────────────────────────────────────── -->
    <section class="cv__card">
      <header class="cv__card-head">
        <div class="cv__card-ico cv__card-ico--alt"><i class="bi bi-file-earmark-text"></i></div>
        <div class="cv__card-titles">
          <h2 class="cv__card-title">Plantillas de mail</h2>
          <p class="cv__card-sub">Los textos que la organización manda a sus pacientes</p>
        </div>
        <button v-if="conectado" class="cv__btn-primary cv__btn-primary--sm" @click="nueva">
          <i class="bi bi-plus-lg"></i> Nueva plantilla
        </button>
      </header>

      <div class="cv__card-body">
        <!-- Sin casilla no hay nada que hacer acá: un editor que no manda es una promesa falsa. -->
        <div v-if="!conectado" class="cv__vacio">
          <i class="bi bi-envelope-slash cv__vacio-ico"></i>
          <p class="cv__vacio-txt">Primero conectá la casilla de la organización. Después vas a poder escribir las plantillas.</p>
        </div>

        <div v-else-if="cargando" class="cv__cargando"><DsSpinner :size="18" /> Cargando plantillas…</div>

        <ul v-else class="cv__lista">
          <li v-for="p in plantillas" :key="p.id" class="cv__item">
            <div class="cv__item-main">
              <div class="cv__item-top">
                <span class="cv__item-nombre">{{ p.nombre }}</span>
                <span v-if="p.bienvenida" class="cv__chip cv__chip--bienvenida">Bienvenida</span>
                <span v-if="!p.activa" class="cv__chip cv__chip--off">Apagada</span>
              </div>
              <div class="cv__item-asunto">{{ p.asunto }}</div>
            </div>
            <div class="cv__item-acc">
              <button class="cv__icon-btn" title="Editar" @click="editar(p)"><i class="bi bi-pencil"></i></button>
              <button class="cv__icon-btn cv__icon-btn--danger" title="Borrar" @click="borrar(p)"><i class="bi bi-trash"></i></button>
            </div>
          </li>
        </ul>

        <p v-if="conectado && !cargando" class="cv__pie">
          La marcada como <strong>Bienvenida</strong> es la única que se manda sola, cuando se aprueba el alta de un paciente.
        </p>
      </div>
    </section>

    <!-- Enviar ───────────────────────────────────────────────── -->
    <section v-if="conectado" class="cv__card">
      <header class="cv__card-head">
        <div class="cv__card-ico cv__card-ico--envio"><i class="bi bi-send"></i></div>
        <div class="cv__card-titles">
          <h2 class="cv__card-title">Enviar un mail</h2>
          <p class="cv__card-sub">A varios pacientes o a direcciones sueltas — cada uno recibe el suyo</p>
        </div>
      </header>
      <div class="cv__card-body">
        <EnvioMasivo :plantillas="plantillas" :organizacion="club.data?.name || ''" />
      </div>
    </section>

    </template>

    <!-- Editor ──────────────────────────────────────────────── -->
    <Teleport to="body">
      <div v-if="editando" class="cv__overlay" @click.self="cerrar">
        <div class="cv__modal">
          <header class="cv__modal-head">
            <h3 class="cv__modal-title">{{ editando.id ? 'Editar plantilla' : 'Nueva plantilla' }}</h3>
            <button class="cv__icon-btn" @click="cerrar"><i class="bi bi-x-lg"></i></button>
          </header>

          <div class="cv__modal-body">
            <div class="cv__field">
              <label class="cv__label">Nombre</label>
              <input class="cv__input" v-model.trim="form.nombre" placeholder="Recordatorio de turno" />
              <span class="cv__hint">Sólo lo ves vos: es cómo la elegís en la ficha del paciente</span>
            </div>

            <div class="cv__field">
              <label class="cv__label">Asunto</label>
              <input class="cv__input" v-model="form.asunto" placeholder="Hola {{nombre}}" />
            </div>

            <div class="cv__field">
              <label class="cv__label">Cuerpo</label>
              <textarea class="cv__textarea" v-model="form.cuerpo" rows="9"></textarea>
            </div>

            <div class="cv__vars">
              <span class="cv__vars-lbl">Variables — clickeá para insertarla:</span>
              <div class="cv__vars-chips">
                <button v-for="v in variables" :key="v.clave" class="cv__var" :title="v.ayuda"
                        @click="insertarVariable(v.clave)">{{ llaves(v.clave) }}</button>
              </div>
            </div>

            <div v-if="variablesDesconocidas.length" class="cv__nota cv__nota--warn">
              <i class="bi bi-exclamation-triangle-fill"></i>
              <span>
                Esto no es una variable y va a salir tal cual en el mail:
                <strong>{{ variablesDesconocidas.map(llaves).join(', ') }}</strong>
              </span>
            </div>

            <div class="cv__preview">
              <div class="cv__preview-lbl">Vista previa — con un paciente de ejemplo</div>
              <div class="cv__preview-asunto">{{ previewAsunto }}</div>
              <div class="cv__preview-cuerpo">{{ previewCuerpo }}</div>
            </div>

            <label class="cv__check">
              <input type="checkbox" v-model="form.activa" />
              <span>Activa — se ofrece para enviar</span>
            </label>
            <label class="cv__check">
              <input type="checkbox" v-model="form.bienvenida" />
              <span>Es la plantilla de bienvenida — se manda al aprobar el alta de un paciente</span>
            </label>
          </div>

          <footer class="cv__modal-foot">
            <button class="cv__btn-ghost" :disabled="guardando" @click="cerrar">Cancelar</button>
            <button class="cv__btn-primary" :disabled="guardando" @click="guardar">
              <DsSpinner v-if="guardando" :size="14" />
              <i v-else class="bi bi-check-lg"></i>
              {{ guardando ? 'Guardando…' : 'Guardar' }}
            </button>
          </footer>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.cv { display: flex; flex-direction: column; gap: 1.25rem; padding-bottom: 3rem; }

.cv__card { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 12px; overflow: hidden; }
.cv__card-head { display: flex; align-items: center; gap: .875rem; padding: 1rem 1.25rem; border-bottom: 1px solid var(--c-slate-100); }
.cv__card-ico { width: 38px; height: 38px; flex-shrink: 0; display: grid; place-items: center; border-radius: 9px; background: #f0fdf4; color: #15803d; font-size: 1.05rem; }
.cv__card-ico--alt { background: #eff6ff; color: #1d4ed8; }
.cv__card-ico--envio { background: #fef3c7; color: #b45309; }
.cv__card-titles { flex: 1; min-width: 0; }
.cv__card-title { margin: 0; font-size: .95rem; font-weight: 700; color: var(--c-slate-900); }
.cv__card-sub { margin: .1rem 0 0; font-size: .78rem; color: var(--c-slate-500); }
.cv__card-body { padding: 1.25rem; display: flex; flex-direction: column; gap: 1rem; }

.cv__badge { display: inline-flex; align-items: center; gap: .35rem; flex-shrink: 0; font-size: .72rem; font-weight: 700; padding: .25em .7em; border-radius: 999px; }
.cv__badge--ok  { background: #dcfce7; color: #15803d; }
.cv__badge--off { background: var(--c-slate-100); color: var(--c-slate-500); }

.cv__nota { display: flex; align-items: flex-start; gap: .55rem; padding: .75rem 1rem; border-radius: 9px; font-size: .82rem; line-height: 1.5; border: 1px solid transparent; }
.cv__nota--ok   { background: #f0fdf4; border-color: #bbf7d0; color: #15803d; }
.cv__nota--info { background: #eff6ff; border-color: #bfdbfe; color: #1e40af; }
.cv__nota--warn { background: #fffbeb; border-color: #fde68a; color: #b45309; }

.cv__pasos { margin: 0; padding-left: 1.25rem; font-size: .82rem; color: var(--c-slate-600); line-height: 1.7; }
.cv__pasos a { color: #1d4ed8; }

.cv__grid { display: grid; grid-template-columns: 1fr 1fr; gap: .875rem; }
@media (max-width: 640px) { .cv__grid { grid-template-columns: 1fr; } }
.cv__field { display: flex; flex-direction: column; gap: .3rem; }
.cv__field--full { grid-column: 1 / -1; }
.cv__label { font-size: .78rem; font-weight: 600; color: var(--c-slate-700); }
.cv__opt { font-weight: 400; color: var(--c-slate-400); }
.cv__input, .cv__textarea { width: 100%; box-sizing: border-box; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .55rem .75rem; font-size: .875rem; color: var(--c-slate-900); font-family: inherit; transition: border .15s, box-shadow .15s; }
.cv__input:focus, .cv__textarea:focus { outline: none; border-color: var(--brand-primary, #1b5e20); box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.cv__textarea { resize: vertical; line-height: 1.6; }
.cv__hint { font-size: .72rem; color: var(--c-slate-400); }

.cv__acciones { display: flex; flex-wrap: wrap; gap: .5rem; }
.cv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .55rem 1.1rem; border-radius: 9px; font-size: .85rem; font-weight: 700; cursor: pointer; transition: background .15s; }
.cv__btn-primary:hover:not(:disabled) { background: #144a18; }
.cv__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
.cv__btn-primary--sm { padding: .4rem .8rem; font-size: .78rem; flex-shrink: 0; }
.cv__btn-outline { display: inline-flex; align-items: center; gap: .4rem; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .5rem 1rem; font-size: .82rem; font-weight: 600; color: var(--c-slate-700); cursor: pointer; transition: all .15s; }
.cv__btn-outline:hover:not(:disabled) { border-color: var(--brand-primary, #1b5e20); color: var(--brand-primary, #1b5e20); }
.cv__btn-outline:disabled { opacity: .55; cursor: not-allowed; }
.cv__btn-ghost { background: none; border: none; padding: .5rem .9rem; font-size: .85rem; font-weight: 600; color: var(--c-slate-500); cursor: pointer; border-radius: 8px; }
.cv__btn-ghost:hover { background: var(--c-slate-100); }
.cv__btn-ghost-danger { display: inline-flex; align-items: center; gap: .4rem; background: none; border: none; padding: .5rem .9rem; font-size: .82rem; font-weight: 600; color: #dc2626; cursor: pointer; border-radius: 8px; }
.cv__btn-ghost-danger:hover { background: #fef2f2; }

.cv__vacio { display: flex; flex-direction: column; align-items: center; gap: .6rem; padding: 2rem 1rem; text-align: center; }
.cv__vacio-ico { font-size: 1.6rem; color: var(--c-slate-300); }
.cv__vacio-txt { margin: 0; font-size: .85rem; color: var(--c-slate-500); max-width: 42ch; line-height: 1.55; }
.cv__cargando { display: flex; align-items: center; gap: .5rem; font-size: .85rem; color: var(--c-slate-500); padding: 1rem 0; }

.cv__lista { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; }
.cv__item { display: flex; align-items: center; gap: .75rem; padding: .75rem 0; border-bottom: 1px solid var(--c-slate-100); }
.cv__item:last-child { border-bottom: none; }
.cv__item-main { flex: 1; min-width: 0; }
.cv__item-top { display: flex; align-items: center; gap: .45rem; flex-wrap: wrap; }
.cv__item-nombre { font-size: .875rem; font-weight: 700; color: var(--c-slate-900); }
.cv__item-asunto { font-size: .78rem; color: var(--c-slate-500); margin-top: .15rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.cv__item-acc { display: flex; gap: .25rem; flex-shrink: 0; }
.cv__chip { font-size: .68rem; font-weight: 700; padding: .12em .5em; border-radius: 5px; }
.cv__chip--bienvenida { background: #f0fdf4; color: #15803d; }
.cv__chip--off { background: var(--c-slate-100); color: var(--c-slate-500); }
.cv__icon-btn { background: none; border: none; cursor: pointer; padding: .35rem .5rem; border-radius: 7px; color: var(--c-slate-500); font-size: .85rem; transition: all .15s; }
.cv__icon-btn:hover { background: var(--c-slate-100); color: var(--c-slate-900); }
.cv__icon-btn--danger:hover { background: #fef2f2; color: #dc2626; }
.cv__pie { margin: .25rem 0 0; font-size: .76rem; color: var(--c-slate-400); line-height: 1.5; }

.cv__overlay { position: fixed; inset: 0; background: rgba(15,23,42,.5); display: grid; place-items: center; padding: 1.25rem; z-index: 1200; }
.cv__modal { background: #fff; border-radius: 14px; width: min(620px, 100%); max-height: 92vh; display: flex; flex-direction: column; overflow: hidden; }
.cv__modal-head { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; border-bottom: 1px solid var(--c-slate-100); }
.cv__modal-title { margin: 0; font-size: .95rem; font-weight: 700; color: var(--c-slate-900); }
.cv__modal-body { padding: 1.25rem; overflow-y: auto; display: flex; flex-direction: column; gap: 1rem; }
.cv__modal-foot { display: flex; justify-content: flex-end; gap: .5rem; padding: .875rem 1.25rem; border-top: 1px solid var(--c-slate-100); }

.cv__vars { display: flex; flex-direction: column; gap: .4rem; }
.cv__vars-lbl { font-size: .75rem; font-weight: 600; color: var(--c-slate-500); }
.cv__vars-chips { display: flex; flex-wrap: wrap; gap: .35rem; }
.cv__var { background: var(--c-slate-100); border: 1px solid var(--c-slate-200); border-radius: 6px; padding: .2rem .5rem; font-family: monospace; font-size: .72rem; color: #1d4ed8; cursor: pointer; transition: all .15s; }
.cv__var:hover { background: #eff6ff; border-color: #bfdbfe; }

.cv__preview { background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 9px; padding: .875rem 1rem; }
.cv__preview-lbl { font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: var(--c-slate-400); margin-bottom: .5rem; }
.cv__preview-asunto { font-size: .85rem; font-weight: 700; color: var(--c-slate-900); margin-bottom: .4rem; }
.cv__preview-cuerpo { font-size: .82rem; color: var(--c-slate-600); line-height: 1.6; white-space: pre-wrap; }

.cv__check { display: flex; align-items: flex-start; gap: .5rem; font-size: .82rem; color: var(--c-slate-700); cursor: pointer; line-height: 1.45; }
.cv__check input { margin-top: .15rem; flex-shrink: 0; }
</style>
