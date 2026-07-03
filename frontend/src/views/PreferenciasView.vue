<script setup>
import { onMounted, reactive, ref, watch } from 'vue'
import AppDatePicker from '../components/ui/AppDatePicker.vue'
import { useClubStore } from '../stores/club'
import Avatar from '../components/Avatar.vue'
import { useConfirm } from '../composables/useConfirm.js'
import { testSmtp, conectarEmail, desconectarEmail } from '../lib/api.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const club  = useClubStore()
const toast = ref(null)
const pristine = ref(true)
const logoPreview = ref(null)
let toastTimer = null
const { confirm } = useConfirm()

// Email — cada club conecta SU casilla (email + contraseña de aplicación). Sin correo, no manda.
const emailModo      = ref('sin_configurar')  // 'propio' | 'sin_configurar'
const emailRemitente = ref('')
const conectarForm = reactive({ email: '', app_password: '', from_name: '' })
const conectando = ref(false)
const smtpTesting = ref(false)

const TIPOS_ORGANIZACION = [
  { value: 'asociacion_civil',  label: 'Asociación Civil' },
  { value: 'fundacion',         label: 'Fundación' },
  { value: 'cooperativa',       label: 'Cooperativa' },
  { value: 'sociedad_de_hecho', label: 'Sociedad de Hecho' },
  { value: 'otro',              label: 'Otro' },
]

const TIMEZONES = [
  { value: 'America/Argentina/Buenos_Aires', label: 'Buenos Aires (GMT-3)' },
  { value: 'America/Argentina/Cordoba',      label: 'Córdoba (GMT-3)' },
  { value: 'America/Argentina/Mendoza',      label: 'Mendoza (GMT-3)' },
  { value: 'America/Argentina/Salta',        label: 'Salta (GMT-3)' },
  { value: 'America/Argentina/Tucuman',      label: 'Tucumán (GMT-3)' },
  { value: 'America/Argentina/Jujuy',        label: 'Jujuy (GMT-3)' },
  { value: 'America/Argentina/Catamarca',    label: 'Catamarca (GMT-3)' },
  { value: 'America/Argentina/La_Rioja',     label: 'La Rioja (GMT-3)' },
  { value: 'America/Argentina/San_Juan',     label: 'San Juan (GMT-3)' },
  { value: 'America/Argentina/San_Luis',     label: 'San Luis (GMT-3)' },
  { value: 'America/Argentina/Rio_Gallegos', label: 'Río Gallegos (GMT-3)' },
  { value: 'America/Argentina/Ushuaia',      label: 'Ushuaia (GMT-3)' },
]

const form = reactive({
  name:                        '',
  legal_name:                  '',
  email:                       '',
  phone:                       '',
  website:                     '',
  address:                     '',
  city:                        '',
  state:                       '',
  timezone:                    'America/Argentina/Buenos_Aires',
  cuit:                        '',
  numero_igj:                  '',
  numero_resolucion_reprocann: '',
  fecha_resolucion_reprocann:  '',
  tipo_organizacion:           '',
})

const errors = reactive({
  name: '', email: '', phone: '', website: '', cuit: '',
})

onMounted(async () => {
  if (!club.data) await club.fetch().catch(() => {})
  loadFromStore()
})
watch(() => club.data, loadFromStore)

function loadFromStore() {
  if (!club.data) return
  Object.assign(form, {
    name:                        club.data.name          || '',
    legal_name:                  club.data.legal_name    || '',
    email:                       club.data.email         || '',
    phone:                       club.data.phone         || '',
    website:                     club.data.website       || '',
    address:                     club.data.address       || '',
    city:                        club.data.city          || '',
    state:                       club.data.state         || '',
    timezone:                    club.data.timezone      || 'America/Argentina/Buenos_Aires',
    cuit:                        club.data.cuit                        || '',
    numero_igj:                  club.data.numero_igj                  || '',
    numero_resolucion_reprocann: club.data.numero_resolucion_reprocann || '',
    fecha_resolucion_reprocann:  club.data.fecha_resolucion_reprocann?.slice(0, 10) || '',
    tipo_organizacion:           club.data.tipo_organizacion           || '',
  })
  logoPreview.value = club.data.logo_url || null
  emailModo.value      = club.data.email_modo || 'sin_configurar'
  emailRemitente.value = club.data.email_remitente || ''
  conectarForm.email = ''; conectarForm.app_password = ''; conectarForm.from_name = ''
  pristine.value = true
}

function onChange() { pristine.value = false }

function onCuitInput() {
  let v = form.cuit.replace(/\D/g, '').slice(0, 11)
  if (v.length > 10)     v = v.slice(0, 2) + '-' + v.slice(2, 10) + '-' + v.slice(10)
  else if (v.length > 2) v = v.slice(0, 2) + '-' + v.slice(2)
  form.cuit = v
  onChange()
}

function validate() {
  Object.keys(errors).forEach(k => { errors[k] = '' })
  let ok = true
  if (!form.name.trim()) { errors.name = 'El nombre del club es obligatorio'; ok = false }
  if (form.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) { errors.email = 'Email inválido'; ok = false }
  if (form.phone && !/^[\d\s\+\-\(\)]{7,20}$/.test(form.phone)) { errors.phone = 'Teléfono inválido'; ok = false }
  if (form.website && !/^https?:\/\/.+\..+/.test(form.website)) { errors.website = 'Debe comenzar con https:// o http://'; ok = false }
  if (form.cuit && !/^\d{2}-\d{8}-\d$/.test(form.cuit)) { errors.cuit = 'Formato inválido (XX-XXXXXXXX-X)'; ok = false }
  return ok
}

async function save() {
  if (!validate()) return
  try {
    const payload = { ...form }
    Object.keys(payload).forEach(k => { if (payload[k] === '') payload[k] = null })
    await club.update(payload)
    pristine.value = true
    showToast('success', 'Preferencias guardadas correctamente')
  } catch (_) {
    showToast('danger', club.error || 'Error al guardar')
  }
}

function onLogoFile(e) {
  const file = e.target?.files?.[0]
  if (!file) return
  if (file.size > 5 * 1024 * 1024) { showToast('danger', 'El logo no puede superar 5 MB'); e.target.value = ''; return }
  const reader = new FileReader()
  reader.onload = () => { logoPreview.value = reader.result }
  reader.readAsDataURL(file)
  club.uploadLogo(file)
    .then(() => { logoPreview.value = club.logoUrl || logoPreview.value; showToast('success', 'Logo actualizado') })
    .catch(() => showToast('danger', club.error || 'Error al subir el logo'))
    .finally(() => { e.target.value = '' })
}

async function removeLogo() {
  const ok = await confirm({ title: '¿Quitar el logo del club?', message: 'El logo será eliminado permanentemente.', confirmText: 'Quitar logo' })
  if (!ok) return
  try { await club.removeLogo(); logoPreview.value = null; showToast('success', 'Logo eliminado') }
  catch (_) { showToast('danger', club.error || 'Error al eliminar el logo') }
}

function showToast(type, msg) {
  clearTimeout(toastTimer)
  toast.value = { type, msg }
  toastTimer = setTimeout(() => { toast.value = null }, 5000)
}

async function conectarMiEmail() {
  if (!conectarForm.email || !conectarForm.app_password) {
    showToast('danger', 'Ingresá el email del club y la contraseña de aplicación.')
    return
  }
  conectando.value = true
  try {
    await conectarEmail({ ...conectarForm })
    await club.fetch()  // dispara loadFromStore por el watch
    showToast('success', 'Correo conectado — ya mandás desde tu casilla ✓')
  } catch (e) {
    showToast('danger', e?.response?.data?.error || 'No se pudo conectar')
  } finally {
    conectando.value = false
  }
}

async function desconectarMiEmail() {
  const ok = await confirm({
    title: '¿Volver al correo de la plataforma?',
    message: 'Tus mails dejarán de salir desde tu casilla y volverán a salir desde la plataforma (con tu email de contacto como respuesta).',
    confirmText: 'Desconectar',
  })
  if (!ok) return
  try {
    await desconectarEmail()
    await club.fetch()
    showToast('success', 'Volviste al correo de la plataforma')
  } catch (e) {
    showToast('danger', e?.response?.data?.error || 'Error al desconectar')
  }
}

async function runTestSmtp() {
  smtpTesting.value = true
  try {
    const { data } = await testSmtp()
    showToast('success', `Mail de prueba enviado a ${data.enviado_a}`)
  } catch (e) {
    showToast('danger', e?.response?.data?.error || 'Error al enviar mail de prueba')
  } finally {
    smtpTesting.value = false
  }
}
</script>

<template>
  <div class="pv">

    <!-- Header sticky -->
    <div class="pv__header">
      <div>
        <h1 class="pv__title">Preferencias del club</h1>
        <p class="pv__sub">Identidad, contacto, domicilio legal y datos regulatorios</p>
      </div>
      <button class="pv__btn-save" :disabled="club.saving || pristine" @click="save">
        <DsSpinner v-if="club.saving" :size="15" />
        <i v-else class="bi bi-check-lg"></i>
        {{ club.saving ? 'Guardando…' : 'Guardar cambios' }}
      </button>
    </div>

    <!-- Toast -->
    <Transition name="pv-toast">
      <div v-if="toast" class="pv__toast" :class="`pv__toast--${toast.type}`">
        <i :class="toast.type === 'success' ? 'bi bi-check-circle-fill' : 'bi bi-exclamation-triangle-fill'"></i>
        <span>{{ toast.msg }}</span>
        <button class="pv__toast-close" @click="toast = null"><i class="bi bi-x"></i></button>
      </div>
    </Transition>

    <div class="pv__body">

      <!-- Aside izquierdo -->
      <div class="pv__aside">
        <div class="pv__card">
          <div class="pv__card-header">
            <div class="pv__card-icon" style="background:rgba(124,58,237,.1);color:#7c3aed"><i class="bi bi-palette"></i></div>
            <div><div class="pv__card-title">Identidad visual</div><div class="pv__card-sub">Logo y nombre del club</div></div>
          </div>
          <div class="pv__card-body">
            <div class="pv__logo-wrap">
              <div class="pv__logo-preview">
                <img v-if="logoPreview" :src="logoPreview" alt="Logo" class="pv__logo-img" />
                <Avatar v-else :name="form.name || 'Club'" :size="88" />
                <div v-if="club.saving" class="pv__logo-overlay"><DsSpinner :size="24" /></div>
              </div>
              <div class="pv__logo-actions">
                <label class="pv__btn-outline" :class="{ 'pv__btn--disabled': club.saving }">
                  <i class="bi bi-image"></i> Cambiar logo
                  <input type="file" class="pv__file-hidden" accept="image/jpeg,image/png,image/webp" :disabled="club.saving" @change="onLogoFile" />
                </label>
                <button class="pv__btn-danger-ghost" :disabled="!logoPreview || club.saving" @click="removeLogo">
                  <i class="bi bi-x-circle"></i> Quitar
                </button>
              </div>
              <p class="pv__logo-hint">JPG, PNG o WebP · máx 5 MB</p>
            </div>

            <div class="pv__field">
              <label class="pv__label">Nombre del club <span class="pv__req">*</span></label>
              <input class="pv__input" :class="{ 'pv__input--err': errors.name }" v-model.trim="form.name" @input="onChange" placeholder="Ej: Verde Esperanza" />
              <span v-if="errors.name" class="pv__err">{{ errors.name }}</span>
            </div>

            <div class="pv__field">
              <label class="pv__label">Razón social</label>
              <input class="pv__input" v-model.trim="form.legal_name" @input="onChange" placeholder="Nombre legal (opcional)" />
              <span class="pv__hint">Usado en documentos oficiales y trazabilidad REPROCANN</span>
            </div>

            <div class="pv__field">
              <label class="pv__label">
                Tipo de organización
                <span v-if="!form.tipo_organizacion" class="pv__falta">Falta completar</span>
              </label>
              <select class="pv__input" :class="{ 'pv__input--falta': !form.tipo_organizacion }" v-model="form.tipo_organizacion" @change="onChange">
                <option value="">Seleccioná…</option>
                <option v-for="t in TIPOS_ORGANIZACION" :key="t.value" :value="t.value">{{ t.label }}</option>
              </select>
              <span v-if="!form.tipo_organizacion" class="pv__hint-warn">Se usa en los informes regulatorios (ARICCAME / REPROCANN). Completalo para que salgan correctos.</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Main derecho -->
      <div class="pv__main">

        <!-- Contacto -->
        <div class="pv__card">
          <div class="pv__card-header">
            <div class="pv__card-icon" style="background:rgba(3,105,161,.1);color:#0369a1"><i class="bi bi-envelope"></i></div>
            <div><div class="pv__card-title">Contacto</div><div class="pv__card-sub">Datos visibles para los socios del club</div></div>
          </div>
          <div class="pv__card-body">
            <div class="pv__grid">
              <div class="pv__field">
                <label class="pv__label">Email de contacto</label>
                <input type="email" class="pv__input" :class="{ 'pv__input--err': errors.email }" v-model.trim="form.email" @input="onChange" placeholder="contacto@miclub.org" />
                <span v-if="errors.email" class="pv__err">{{ errors.email }}</span>
              </div>
              <div class="pv__field">
                <label class="pv__label">Teléfono</label>
                <input type="tel" class="pv__input" :class="{ 'pv__input--err': errors.phone }" v-model.trim="form.phone" @input="onChange" placeholder="+54 11 1234-5678" />
                <span v-if="errors.phone" class="pv__err">{{ errors.phone }}</span>
              </div>
              <div class="pv__field pv__field--full">
                <label class="pv__label">Sitio web</label>
                <div class="pv__input-group">
                  <span class="pv__input-prefix"><i class="bi bi-globe"></i></span>
                  <input type="url" class="pv__input pv__input--prefixed" :class="{ 'pv__input--err': errors.website }" v-model.trim="form.website" @input="onChange" placeholder="https://miclub.org" />
                </div>
                <span v-if="errors.website" class="pv__err">{{ errors.website }}</span>
                <span v-else class="pv__hint">Opcional — debe incluir https://</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Domicilio -->
        <div class="pv__card pv__card--mt">
          <div class="pv__card-header">
            <div class="pv__card-icon" style="background:rgba(21,128,61,.1);color:#15803d"><i class="bi bi-geo-alt"></i></div>
            <div><div class="pv__card-title">Domicilio legal</div><div class="pv__card-sub">Requerido para informes REPROCANN y trazabilidad</div></div>
          </div>
          <div class="pv__card-body">
            <div class="pv__grid">
              <div class="pv__field pv__field--full">
                <label class="pv__label">Dirección</label>
                <input class="pv__input" v-model.trim="form.address" @input="onChange" placeholder="Av. Corrientes 1234, Piso 2" />
              </div>
              <div class="pv__field">
                <label class="pv__label">Ciudad</label>
                <input class="pv__input" v-model.trim="form.city" @input="onChange" placeholder="Buenos Aires" />
              </div>
              <div class="pv__field">
                <label class="pv__label">Provincia</label>
                <input class="pv__input" v-model.trim="form.state" @input="onChange" placeholder="CABA" />
              </div>
            </div>
          </div>
        </div>

        <!-- Datos legales -->
        <div class="pv__card pv__card--mt">
          <div class="pv__card-header">
            <div class="pv__card-icon" style="background:rgba(180,83,9,.1);color:#b45309"><i class="bi bi-shield-check"></i></div>
            <div><div class="pv__card-title">Datos legales y regulatorios</div><div class="pv__card-sub">Para el informe semestral REPROCANN — todos opcionales</div></div>
          </div>
          <div class="pv__card-body">
            <div class="pv__infobox">
              <i class="bi bi-info-circle-fill"></i>
              Estos datos aparecen en el informe semestral que se presenta ante el Ministerio de Salud. Podés completarlos después del onboarding, no bloquean ninguna funcionalidad.
            </div>
            <div class="pv__grid">
              <div class="pv__field">
                <label class="pv__label">CUIT de la organización</label>
                <input class="pv__input" :class="{ 'pv__input--err': errors.cuit }" v-model="form.cuit" @input="onCuitInput" placeholder="20-12345678-9" maxlength="13" />
                <span v-if="errors.cuit" class="pv__err">{{ errors.cuit }}</span>
                <span v-else class="pv__hint">Se formatea automáticamente</span>
              </div>
              <div class="pv__field">
                <label class="pv__label">Número IGJ</label>
                <input class="pv__input" v-model.trim="form.numero_igj" @input="onChange" placeholder="Ej: 001234" />
                <span class="pv__hint">N° de inscripción ante la IGJ</span>
              </div>
              <div class="pv__field">
                <label class="pv__label">N° Resolución REPROCANN org.</label>
                <input class="pv__input" v-model.trim="form.numero_resolucion_reprocann" @input="onChange" placeholder="Ej: 1780/2025" />
                <span class="pv__hint">Resolución de la organización, no del paciente</span>
              </div>
              <div class="pv__field">
                <label class="pv__label">Fecha de resolución</label>
                <AppDatePicker v-model="form.fecha_resolucion_reprocann" @update:model-value="onChange" />
              </div>
            </div>
          </div>
        </div>

        <!-- Regional -->
        <div class="pv__card pv__card--mt">
          <div class="pv__card-header">
            <div class="pv__card-icon" style="background:rgba(15,23,42,.06);color:#475569"><i class="bi bi-clock"></i></div>
            <div><div class="pv__card-title">Configuración regional</div><div class="pv__card-sub">Zona horaria para registros y reportes</div></div>
          </div>
          <div class="pv__card-body">
            <div class="pv__field" style="max-width:320px">
              <label class="pv__label">Zona horaria</label>
              <select class="pv__input" v-model="form.timezone" @change="onChange">
                <option v-for="tz in TIMEZONES" :key="tz.value" :value="tz.value">{{ tz.label }}</option>
              </select>
            </div>
          </div>
        </div>

        <!-- Correo del club -->
        <div class="pv__card pv__card--mt">
          <div class="pv__card-header">
            <div class="pv__card-icon" style="background:#f0fdf4;color:#15803d"><i class="bi bi-envelope-at"></i></div>
            <div>
              <div class="pv__card-title">Correo del club</div>
              <div class="pv__card-sub">Desde dónde salen los mails a los socios</div>
            </div>
            <div class="pv__smtp-badge" :class="emailModo === 'propio' ? 'pv__smtp-badge--ok' : 'pv__smtp-badge--off'">
              <i :class="emailModo === 'propio' ? 'bi bi-check-circle-fill' : 'bi bi-x-circle-fill'"></i>
              {{ emailModo === 'propio' ? 'Conectado' : 'Sin configurar' }}
            </div>
          </div>
          <div class="pv__card-body">

            <!-- Conectado -->
            <template v-if="emailModo === 'propio'">
              <div class="pv__infobox" style="background:#f0fdf4;border-color:#bbf7d0;color:#15803d">
                <i class="bi bi-check-circle-fill"></i>
                <span>Conectado. Los mails del club salen desde <strong>{{ emailRemitente }}</strong>.</span>
              </div>
              <div class="pv__smtp-actions">
                <button class="pv__btn-outline" :disabled="smtpTesting" @click="runTestSmtp">
                  <DsSpinner v-if="smtpTesting" :size="15" />
                  <i v-else class="bi bi-send"></i>
                  {{ smtpTesting ? 'Enviando…' : 'Enviar mail de prueba' }}
                </button>
                <button class="pv__btn-danger-ghost" @click="desconectarMiEmail">
                  <i class="bi bi-box-arrow-left"></i> Desconectar
                </button>
              </div>
            </template>

            <!-- Sin configurar: conectar el correo -->
            <div v-else class="pv__connect">
              <div class="pv__infobox" style="background:#eff6ff;border-color:#bfdbfe;color:#1e40af">
                <i class="bi bi-info-circle-fill"></i>
                <span>Conectá el correo del club para poder mandarles mails a tus socios. Para Gmail necesitás una <strong>contraseña de aplicación</strong> (no tu contraseña normal):</span>
              </div>
              <ol class="pv__steps">
                <li>Entrá a tu cuenta de Google → <strong>Seguridad</strong>.</li>
                <li>Activá la <strong>Verificación en 2 pasos</strong> (si no la tenés).</li>
                <li>Abrí <a href="https://myaccount.google.com/apppasswords" target="_blank" rel="noopener">myaccount.google.com/apppasswords</a> y creá una <strong>contraseña de aplicación</strong>.</li>
                <li>Copiá las <strong>16 letras</strong> y pegalas abajo.</li>
              </ol>
              <div class="pv__grid">
                <div class="pv__field">
                  <label class="pv__label">Email del club</label>
                  <input class="pv__input" type="email" v-model.trim="conectarForm.email" placeholder="miclub@gmail.com" autocomplete="off" />
                  <span class="pv__hint">Gmail, Outlook o Yahoo se detectan solos</span>
                </div>
                <div class="pv__field">
                  <label class="pv__label">Contraseña de aplicación</label>
                  <input class="pv__input" type="password" v-model.trim="conectarForm.app_password" placeholder="16 caracteres" autocomplete="new-password" />
                </div>
                <div class="pv__field pv__field--full">
                  <label class="pv__label">Nombre para mostrar <span style="font-weight:400;color:#94a3b8">(opcional)</span></label>
                  <input class="pv__input" v-model.trim="conectarForm.from_name" :placeholder="form.name || 'Mi Club'" />
                  <span class="pv__hint">Lo que ve el socio como remitente</span>
                </div>
              </div>
              <div class="pv__smtp-actions">
                <button class="pv__btn-save" :disabled="conectando" @click="conectarMiEmail">
                  <DsSpinner v-if="conectando" :size="15" />
                  <i v-else class="bi bi-plug"></i>
                  {{ conectando ? 'Conectando…' : 'Probar y conectar' }}
                </button>
              </div>
            </div>

          </div>
        </div>

        <!-- Footer save -->
        <div class="pv__footer-save">
          <button class="pv__btn-save" :disabled="club.saving || pristine" @click="save">
            <DsSpinner v-if="club.saving" :size="15" />
            <i v-else class="bi bi-check-lg"></i>
            {{ club.saving ? 'Guardando…' : 'Guardar cambios' }}
          </button>
          <span v-if="pristine" class="pv__no-changes">Sin cambios pendientes</span>
        </div>

      </div>
    </div>
  </div>
</template>

<style scoped>
.pv { max-width: 1100px; margin: 0 auto; padding: 0 0 3rem; }

.pv__header {
  display: flex; align-items: center; justify-content: space-between;
  gap: 1rem; padding: 1.5rem 1.75rem 1.25rem;
  position: sticky; top: 0; z-index: 10;
  background: rgba(242,245,242,.95); backdrop-filter: blur(8px);
  border-bottom: 1px solid rgba(0,0,0,.06); flex-wrap: wrap;
}
.pv__title { font-size: 1.6rem; font-weight: 800; color: #0f172a; margin: 0 0 .15rem; letter-spacing: -.03em; }
.pv__sub   { font-size: .8rem; color: #94a3b8; margin: 0; }

.pv__body {
  display: grid; grid-template-columns: 280px 1fr;
  gap: 1.5rem; padding: 1.5rem 1.75rem 0; align-items: start;
}
@media (max-width: 900px) { .pv__body { grid-template-columns: 1fr; } }
.pv__aside { position: sticky; top: 90px; }
.pv__main  { display: flex; flex-direction: column; }

.pv__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.pv__card--mt { margin-top: 1.25rem; }
.pv__card-header { display: flex; align-items: center; gap: .875rem; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.pv__card-icon  { width: 36px; height: 36px; border-radius: 9px; display: flex; align-items: center; justify-content: center; font-size: .9rem; flex-shrink: 0; }
.pv__card-title { font-size: .9rem; font-weight: 800; color: #0f172a; }
.pv__card-sub   { font-size: .75rem; color: #94a3b8; margin-top: .1rem; }
.pv__card-body  { padding: 1.25rem; display: flex; flex-direction: column; gap: 1rem; }

.pv__logo-wrap    { display: flex; flex-direction: column; align-items: center; gap: .75rem; }
.pv__logo-preview { position: relative; width: 88px; height: 88px; border-radius: 50%; }
.pv__logo-img     { width: 88px; height: 88px; border-radius: 50%; object-fit: cover; box-shadow: 0 2px 10px rgba(0,0,0,.12); }
.pv__logo-overlay { position: absolute; inset: 0; background: rgba(0,0,0,.45); border-radius: 50%; display: flex; align-items: center; justify-content: center; }
.pv__logo-actions { display: flex; gap: .5rem; flex-wrap: wrap; justify-content: center; }
.pv__logo-hint    { font-size: .7rem; color: #94a3b8; text-align: center; margin: 0; }

.pv__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 640px) { .pv__grid { grid-template-columns: 1fr; } }
.pv__field      { display: flex; flex-direction: column; gap: .35rem; }
.pv__field--full { grid-column: 1 / -1; }
.pv__label { font-size: .75rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.pv__falta { margin-left: .4rem; font-size: .6rem; font-weight: 700; color: #b45309; background: #fef3c7; border-radius: 999px; padding: .1em .5em; text-transform: none; letter-spacing: 0; }
.pv__input--falta { border-color: #f59e0b !important; background: #fffbeb; }
.pv__hint-warn { display: block; margin-top: .3rem; font-size: .7rem; color: #b45309; }
.pv__req   { color: #dc2626; }
.pv__input {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px;
  padding: .65rem .9rem; font-size: .875rem; color: #0f172a;
  width: 100%; box-sizing: border-box; transition: border .15s, box-shadow .15s;
}
.pv__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); background: #fff; }
.pv__input--err { border-color: #dc2626 !important; }
.pv__input--prefixed { border-radius: 0 9px 9px 0; border-left: none; }
.pv__input-group { display: flex; }
.pv__input-prefix { display: flex; align-items: center; justify-content: center; padding: 0 .75rem; background: #f1f5f9; border: 1.5px solid #e2e8f0; border-right: none; border-radius: 9px 0 0 9px; color: #94a3b8; }
.pv__err  { font-size: .72rem; color: #dc2626; font-weight: 600; }
.pv__hint { font-size: .72rem; color: #94a3b8; }
.pv__file-hidden { display: none; }

.pv__infobox {
  display: flex; align-items: flex-start; gap: .6rem;
  background: #fffbeb; border: 1px solid #fde68a; border-radius: 9px;
  padding: .75rem 1rem; font-size: .8rem; color: #92400e; line-height: 1.5;
  grid-column: 1 / -1;
}
.pv__infobox i { flex-shrink: 0; margin-top: .1rem; }

.pv__btn-save {
  display: inline-flex; align-items: center; gap: .5rem;
  background: var(--brand-primary, #1b5e20); color: #fff;
  border: none; padding: .65rem 1.5rem; border-radius: 9px;
  font-size: .875rem; font-weight: 700; cursor: pointer;
  transition: background .15s, transform .1s, opacity .15s; white-space: nowrap;
}
.pv__btn-save:hover:not(:disabled) { background: #144a18; transform: translateY(-1px); }
.pv__btn-save:disabled { opacity: .45; cursor: not-allowed; transform: none; }

.pv__btn-outline {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #fff; color: #475569; border: 1.5px solid #e2e8f0;
  padding: .45rem .875rem; border-radius: 8px; font-size: .78rem;
  font-weight: 600; cursor: pointer; transition: all .15s;
}
.pv__btn-outline:hover { border-color: #94a3b8; background: #f8fafc; }
.pv__btn--disabled { opacity: .5; pointer-events: none; }

.pv__btn-danger-ghost {
  display: inline-flex; align-items: center; gap: .4rem;
  background: transparent; color: #dc2626; border: 1.5px solid #fecaca;
  padding: .45rem .875rem; border-radius: 8px; font-size: .78rem;
  font-weight: 600; cursor: pointer; transition: all .15s;
}
.pv__btn-danger-ghost:hover:not(:disabled) { background: #fef2f2; }
.pv__btn-danger-ghost:disabled { opacity: .4; cursor: not-allowed; }

.pv__footer-save {
  display: flex; align-items: center; gap: 1rem;
  margin-top: 1.5rem; padding-top: 1.5rem; border-top: 1px solid #f1f5f9;
}
.pv__no-changes { font-size: .78rem; color: #94a3b8; }

.pv__toast {
  display: flex; align-items: center; gap: .75rem;
  padding: .875rem 1.1rem; border-radius: 10px;
  font-size: .875rem; font-weight: 500; margin: 1rem 1.75rem 0;
}
.pv__toast--success { background: #f0fdf4; border: 1px solid #bbf7d0; color: #14532d; }
.pv__toast--danger  { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; }
.pv__toast-close { margin-left: auto; background: none; border: none; color: inherit; opacity: .6; cursor: pointer; font-size: 1rem; padding: 0; }
.pv__toast-close:hover { opacity: 1; }


.pv-toast-enter-active, .pv-toast-leave-active { transition: all .3s; }
.pv-toast-enter-from, .pv-toast-leave-to { opacity: 0; transform: translateY(-8px); }

.pv__smtp-badge {
  margin-left: auto; display: inline-flex; align-items: center; gap: .35rem;
  font-size: .72rem; font-weight: 700; padding: .25rem .7rem; border-radius: 999px;
}
.pv__smtp-badge--ok  { background: #dcfce7; color: #15803d; }
.pv__smtp-badge--off { background: #f1f5f9; color: #64748b; }

.pv__smtp-actions { display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; }
.pv__connect { display: flex; flex-direction: column; gap: 1rem; }
.pv__connect a { color: #2563eb; font-weight: 600; }
.pv__steps { margin: 0; padding-left: 1.25rem; display: flex; flex-direction: column; gap: .4rem; font-size: .82rem; color: #475569; line-height: 1.45; }
.pv__steps li::marker { color: #16a34a; font-weight: 700; }
</style>

