<script setup>
import { ref, computed, onMounted } from 'vue'
import AppDatePicker from '../../components/ui/AppDatePicker.vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { useRouter } from 'vue-router'
import { Building2, Gauge, Zap, Users, ChevronRight, ChevronLeft, Check, ArrowLeft,
         AlertTriangle, Lock, Copy, Info } from 'lucide-vue-next'
import { createSuperAdminClub, getSuperAdminCatalogo } from '../../lib/api.js'

const router = useRouter()

const PASOS = ['Identidad', 'Plan', 'Módulos', 'Acceso']

const paso    = ref(1)
const saving  = ref(false)
const error   = ref(null)
const creado  = ref(null)

// ── Catálogo ──────────────────────────────────────────────────────────
// Qué se puede vender lo dice el backend. Antes esta pantalla repetía la lista a mano y ya
// decía cosas distintas que `Club::ADDONS`: un módulo nuevo obligaba a acordarse de cuatro
// lugares y el que se olvidaba quedaba invisible.
const catalogo  = ref(null)
const cargando  = ref(true)

const planes         = computed(() => catalogo.value?.planes || [])
const suites         = computed(() => catalogo.value?.suites || [])
const addons         = computed(() => catalogo.value?.addons || [])
const incluidos      = computed(() => catalogo.value?.incluidos || [])
const enConstruccion = computed(() => catalogo.value?.en_construccion || [])
const rolesAlta      = computed(() => catalogo.value?.roles_alta || [])

// ── Form ──────────────────────────────────────────────────────────────
const form = ref({
  name:              '',
  legal_name:        '',
  email:             '',
  phone:             '',
  city:              '',
  state:             '',
  country:           'Argentina',
  timezone:          'America/Argentina/Buenos_Aires',
  plan:              'basico',
  plan_trial:        true,
  plan_activo_hasta: '',
  features:          { cultivo: true, produccion_dispensa: true, bar: true },
})

const haySuite = computed(() => suites.value.some(s => form.value.features[s.clave] === true))

// Un módulo incluido sólo entra si el club se lleva la suite que lo contiene.
function incluidoActivo(inc) { return form.value.features[inc.incluido_en] === true }

const PAISES    = ['Argentina', 'Uruguay', 'Colombia', 'España', 'Alemania', 'Canadá', 'Estados Unidos', 'México', 'Chile', 'Brasil', 'Otro']
const TIMEZONES = ['America/Argentina/Buenos_Aires', 'America/Montevideo', 'America/Bogota', 'America/Santiago', 'Europe/Berlin', 'America/Toronto', 'America/New_York']

// ── Usuarios ──────────────────────────────────────────────────────────
const rolesSeleccionados = ref(['admin'])
const passwordInicial    = ref('')
const passwordCopiada    = ref(false)

function toggleRol(rol) {
  if (rol === 'admin') return          // el admin siempre se crea: sin él nadie entra al club
  const idx = rolesSeleccionados.value.indexOf(rol)
  if (idx >= 0) rolesSeleccionados.value.splice(idx, 1)
  else rolesSeleccionados.value.push(rol)
}

async function copiarPassword(valor) {
  try {
    await navigator.clipboard.writeText(valor)
    passwordCopiada.value = true
    setTimeout(() => { passwordCopiada.value = false }, 1800)
  } catch { /* sin portapapeles: queda visible igual, que es lo que importa */ }
}

onMounted(async () => {
  try {
    const { data } = await getSuperAdminCatalogo()
    catalogo.value = data
    passwordInicial.value = data.password_default || ''
  } catch {
    error.value = 'No se pudo cargar el catálogo de planes y módulos.'
  } finally {
    cargando.value = false
  }
})

// ── Slug preview ──────────────────────────────────────────────────────
const slugPreview = computed(() =>
  form.value.name.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'slug'
)

function emailRol(rol) { return `${rol}@${slugPreview.value}.com` }

// ── Validación ────────────────────────────────────────────────────────
const errores = ref({})

function validarPaso1() {
  const e = {}
  if (!form.value.name.trim())  e.name  = 'El nombre es requerido'
  if (!form.value.email.trim()) e.email = 'El email es requerido'
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.value.email)) e.email = 'Email inválido'
  errores.value = e
  return !Object.keys(e).length
}

function siguiente() {
  if (paso.value === 1 && !validarPaso1()) return
  if (paso.value < PASOS.length) paso.value++
}
function anterior() { if (paso.value > 1) paso.value-- }

// ── Submit ────────────────────────────────────────────────────────────
async function handleSubmit() {
  saving.value = true
  error.value  = null
  try {
    const club = { ...form.value }
    Object.keys(club).forEach(k => { if (club[k] === '') delete club[k] })
    const { data } = await createSuperAdminClub({
      club,
      roles_a_crear:    rolesSeleccionados.value,
      password_inicial: passwordInicial.value,
    })
    creado.value = data
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || 'Error al crear el club'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="cnv">

    <!-- Back -->
    <RouterLink :to="{ name: 'sa-clubs' }" class="cnv__back">
      <ArrowLeft :size="14" :stroke-width="2" /> Organizaciones
    </RouterLink>

    <!-- ══ SUCCESS ══ -->
    <div v-if="creado" class="cnv__success">
      <div class="cnv__success-check"><Check :size="28" :stroke-width="2.5" /></div>
      <h2 class="cnv__success-title">Organización creada</h2>
      <p class="cnv__success-sub">
        <strong>{{ creado.club.name }}</strong> está listo.
        Se {{ creado.usuarios.length === 1 ? 'creó' : 'crearon' }}
        {{ creado.usuarios.length }} usuario{{ creado.usuarios.length !== 1 ? 's' : '' }}.
      </p>

      <!-- Lo que hay que pasarle al club. Es el único momento en que está todo junto, así que
           se muestra entero y se puede copiar de una. -->
      <div class="cnv__entrega">
        <div class="cnv__entrega-head">
          <span class="cnv__entrega-title">Datos de acceso</span>
          <button type="button" class="cnv__pass-copy" @click="copiarPassword(creado.password_inicial)">
            <Check v-if="passwordCopiada" :size="14" :stroke-width="2.5" />
            <Copy v-else :size="14" :stroke-width="2" />
            {{ passwordCopiada ? 'Copiada' : 'Copiar contraseña' }}
          </button>
        </div>
        <div class="cnv__entrega-pass">
          Contraseña temporal: <code>{{ creado.password_inicial }}</code>
        </div>
        <div class="cnv__usuarios-grid">
          <div v-for="u in creado.usuarios" :key="u.id" class="cnv__usuario-card">
            <div class="cnv__usuario-role">{{ u.role }}</div>
            <div class="cnv__usuario-email">{{ u.email }}</div>
          </div>
        </div>
      </div>

      <div class="cnv__success-actions">
        <RouterLink :to="{ name: 'sa-club-detail', params: { id: creado.club.id } }" class="cnv__btn-primary">
          Ver club
          <ChevronRight :size="16" :stroke-width="2" />
        </RouterLink>
        <button class="cnv__btn-ghost" @click="creado = null; paso = 1">Crear otro</button>
      </div>
    </div>

    <!-- ══ CARGANDO EL CATÁLOGO ══ -->
    <div v-else-if="cargando" class="cnv__cargando">
      <DsSpinner :size="22" />
      <span>Cargando planes y módulos…</span>
    </div>

    <!-- ══ WIZARD ══ -->
    <template v-else>

      <!-- Header + stepper -->
      <div class="cnv__header">
        <h1 class="cnv__title">Nueva organización</h1>
        <div class="cnv__stepper">
          <div
            v-for="(nombre, i) in PASOS" :key="nombre"
            class="cnv__step"
            :class="{ 'cnv__step--done': paso > i + 1, 'cnv__step--active': paso === i + 1 }"
          >
            <div class="cnv__step-dot">
              <Check v-if="paso > i + 1" :size="12" :stroke-width="3" />
              <span v-else>{{ i + 1 }}</span>
            </div>
            <span class="cnv__step-label">{{ nombre }}</span>
          </div>
          <div class="cnv__step-line" :style="{ width: `${((paso - 1) / (PASOS.length - 1)) * 100}%` }"></div>
        </div>
      </div>

      <!-- ─── Paso 1: Identidad ─── -->
      <div v-if="paso === 1" class="cnv__panel">
        <div class="cnv__panel-header">
          <div class="cnv__panel-ico"><Building2 :size="18" :stroke-width="1.75" /></div>
          <div>
            <div class="cnv__panel-title">Identidad de la organización</div>
            <div class="cnv__panel-sub">Datos de identificación y contacto</div>
          </div>
        </div>
        <div class="cnv__panel-body">
          <div v-if="Object.keys(errores).length" class="cnv__alert">
            Corregí los campos marcados en rojo antes de continuar.
          </div>
          <div class="cnv__grid">
            <div class="cnv__field cnv__field--full">
              <label class="cnv__label">Nombre de la organización <span class="cnv__req">*</span></label>
              <input v-model.trim="form.name" class="cnv__input" :class="{ 'cnv__input--err': errores.name }"
                     placeholder="Club Medicinal del Sur" />
              <span v-if="errores.name" class="cnv__err">{{ errores.name }}</span>
              <span v-else class="cnv__hint">Slug: <code>{{ slugPreview }}</code></span>
            </div>
            <div class="cnv__field cnv__field--full">
              <label class="cnv__label">Razón social</label>
              <input v-model.trim="form.legal_name" class="cnv__input"
                     placeholder="Asociación Civil Club Medicinal del Sur" />
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Email de contacto <span class="cnv__req">*</span></label>
              <input v-model.trim="form.email" type="email" class="cnv__input" :class="{ 'cnv__input--err': errores.email }"
                     placeholder="contacto@clubmedicinal.org" />
              <span v-if="errores.email" class="cnv__err">{{ errores.email }}</span>
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Teléfono</label>
              <input v-model.trim="form.phone" class="cnv__input" placeholder="+54 9 11 1234-5678" />
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Ciudad</label>
              <input v-model.trim="form.city" class="cnv__input" placeholder="Buenos Aires" />
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Provincia</label>
              <input v-model.trim="form.state" class="cnv__input" placeholder="CABA" />
            </div>
            <div class="cnv__field">
              <label class="cnv__label">País</label>
              <select v-model="form.country" class="cnv__input">
                <option v-for="p in PAISES" :key="p" :value="p">{{ p }}</option>
              </select>
            </div>
            <div class="cnv__field">
              <label class="cnv__label">Zona horaria</label>
              <select v-model="form.timezone" class="cnv__input">
                <option v-for="tz in TIMEZONES" :key="tz" :value="tz">{{ tz }}</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <!-- ─── Paso 2: Plan ───
           El plan dice CUÁNTO. Qué módulos tiene el club es la pantalla siguiente: mezclarlas
           era lo que hacía que un club quedara sin límites y sin poder hacer nada. -->
      <div v-if="paso === 2" class="cnv__panel">
        <div class="cnv__panel-header">
          <div class="cnv__panel-ico cnv__panel-ico--purple"><Gauge :size="18" :stroke-width="1.75" /></div>
          <div>
            <div class="cnv__panel-title">Cuánto puede crecer</div>
            <div class="cnv__panel-sub">El plan fija los topes. Qué módulos usa se elige en el paso siguiente</div>
          </div>
        </div>
        <div class="cnv__panel-body">

          <div class="cnv__planes">
            <button
              v-for="p in planes" :key="p.clave"
              type="button"
              class="cnv__plan"
              :class="{ 'cnv__plan--on': form.plan === p.clave }"
              @click="form.plan = p.clave"
            >
              <div class="cnv__plan-top">
                <span class="cnv__plan-check"><Check v-if="form.plan === p.clave" :size="12" :stroke-width="3" /></span>
                <span class="cnv__plan-name">{{ p.label }}</span>
              </div>
              <ul class="cnv__plan-limites">
                <li v-for="linea in p.resumen" :key="linea">{{ linea }}</li>
              </ul>
            </button>
          </div>

          <div class="cnv__row-2" style="margin-top:1.5rem">
            <div class="cnv__field">
              <label class="cnv__label">Vigente hasta</label>
              <AppDatePicker v-model="form.plan_activo_hasta" />
              <span class="cnv__hint">Dejá vacío para sin vencimiento</span>
            </div>
            <label class="cnv__toggle">
              <input v-model="form.plan_trial" type="checkbox" class="cnv__toggle__input" />
              <div class="cnv__toggle__track"><div class="cnv__toggle__thumb"></div></div>
              <div>
                <div class="cnv__toggle__label">Período de prueba</div>
                <div class="cnv__hint">Muestra el cartel "Trial" en el panel de la organización</div>
              </div>
            </label>
          </div>

        </div>
      </div>

      <!-- ─── Paso 3: Módulos ─── -->
      <div v-if="paso === 3" class="cnv__panel">
        <div class="cnv__panel-header">
          <div class="cnv__panel-ico cnv__panel-ico--purple"><Zap :size="18" :stroke-width="1.75" /></div>
          <div>
            <div class="cnv__panel-title">Qué puede hacer</div>
            <div class="cnv__panel-sub">Primero la suite; después lo que se le suma encima</div>
          </div>
        </div>
        <div class="cnv__panel-body">

          <!-- Suites: lo que realmente se vende. Un club puede tomar una, la otra o las dos. -->
          <div class="cnv__section-label">Suites</div>
          <div class="cnv__suites">
            <button
              v-for="s in suites" :key="s.clave"
              type="button"
              class="cnv__suite"
              :class="{ 'cnv__suite--on': form.features[s.clave] }"
              @click="form.features[s.clave] = !form.features[s.clave]"
            >
              <span class="cnv__suite-check">{{ form.features[s.clave] ? '✓' : '' }}</span>
              <span class="cnv__suite-txt">
                <span class="cnv__suite-name">{{ s.label }}</span>
                <span class="cnv__suite-desc">{{ s.desc }}</span>
              </span>
            </button>
          </div>
          <p v-if="!haySuite" class="cnv__warn">
            Sin ninguna suite, el club entra pero no puede operar. Elegí al menos una.
          </p>

          <!-- Incluidos: van con la suite. Sin interruptor, porque no hay nada que decidir. -->
          <div v-if="incluidos.length" class="cnv__section-label" style="margin-top:1.5rem">
            Ya incluido
          </div>
          <div v-if="incluidos.length" class="cnv__incluidos">
            <div
              v-for="inc in incluidos" :key="inc.clave"
              class="cnv__incluido"
              :class="{ 'cnv__incluido--off': !incluidoActivo(inc) }"
            >
              <Check v-if="incluidoActivo(inc)" :size="14" :stroke-width="3" class="cnv__incluido-ico" />
              <Lock v-else :size="13" :stroke-width="2" class="cnv__incluido-ico" />
              <div>
                <div class="cnv__incluido-name">{{ inc.label }}</div>
                <div class="cnv__incluido-desc">
                  <template v-if="incluidoActivo(inc)">Viene con {{ inc.incluido_en_label }}</template>
                  <template v-else>Necesita la suite {{ inc.incluido_en_label }}</template>
                </div>
              </div>
            </div>
          </div>

          <!-- Add-ons: lo que sí se decide. Cada uno avisa si necesita algo más para andar. -->
          <div class="cnv__section-label" style="margin-top:1.5rem">Módulos adicionales</div>
          <div class="cnv__feat-grid">
            <label
              v-for="a in addons" :key="a.clave"
              class="cnv__feat-toggle"
              :class="{ 'cnv__feat-toggle--on': form.features[a.clave], 'cnv__feat-toggle--warn': a.incompleto }"
            >
              <div class="cnv__feat-left">
                <div>
                  <div class="cnv__feat-name">{{ a.label }}</div>
                  <div class="cnv__feat-desc">{{ a.desc }}</div>
                  <!-- Lo que antes era una nota al pie: prender el interruptor no alcanza. -->
                  <div v-if="a.requiere && form.features[a.clave]" class="cnv__feat-requiere">
                    <AlertTriangle :size="11" :stroke-width="2.5" />
                    {{ a.requiere }}
                  </div>
                </div>
              </div>
              <input v-model="form.features[a.clave]" type="checkbox" class="cnv__toggle__input" />
              <div class="cnv__toggle__track cnv__toggle__track--sm"><div class="cnv__toggle__thumb cnv__toggle__thumb--sm"></div></div>
            </label>
          </div>

          <!-- En construcción: se listan para que nadie los prometa creyendo que están. -->
          <template v-if="enConstruccion.length">
            <div class="cnv__section-label" style="margin-top:1.5rem">Todavía no disponible</div>
            <div class="cnv__construccion">
              <div v-for="e in enConstruccion" :key="e.clave" class="cnv__constr-item">
                <Info :size="14" :stroke-width="2" class="cnv__constr-ico" />
                <div>
                  <div class="cnv__constr-name">{{ e.label }}</div>
                  <div class="cnv__constr-desc">{{ e.desc }}</div>
                </div>
                <span class="cnv__constr-badge">En construcción</span>
              </div>
            </div>
          </template>

        </div>
      </div>

      <!-- ─── Paso 4: Acceso inicial ─── -->
      <div v-if="paso === 4" class="cnv__panel">
        <div class="cnv__panel-header">
          <div class="cnv__panel-ico cnv__panel-ico--blue"><Users :size="18" :stroke-width="1.75" /></div>
          <div>
            <div class="cnv__panel-title">Con qué entran</div>
            <div class="cnv__panel-sub">Qué usuarios se crean y con qué contraseña</div>
          </div>
        </div>
        <div class="cnv__panel-body">

          <!-- En claro y a propósito: es temporal y hay que poder dictársela al club. Detrás
               de puntitos había que acordarse de lo que uno mismo acababa de tipear. -->
          <div class="cnv__field cnv__pass" style="margin-bottom:1.5rem">
            <label class="cnv__label">Contraseña temporal</label>
            <div class="cnv__pass-row">
              <input v-model="passwordInicial" type="text" autocomplete="off" spellcheck="false"
                     class="cnv__input cnv__input--mono" placeholder="ClaveDelClub1" />
              <button type="button" class="cnv__pass-copy" :disabled="!passwordInicial"
                      @click="copiarPassword(passwordInicial)">
                <Check v-if="passwordCopiada" :size="14" :stroke-width="2.5" />
                <Copy v-else :size="14" :stroke-width="2" />
                {{ passwordCopiada ? 'Copiada' : 'Copiar' }}
              </button>
            </div>
            <span class="cnv__hint">La misma para todos los usuarios que se creen. Cada uno la cambia desde su perfil.</span>
          </div>

          <div class="cnv__section-label">Usuarios a crear</div>
          <div class="cnv__roles-grid">
            <div
              v-for="r in rolesAlta" :key="r.clave"
              class="cnv__role-card"
              :class="{
                'cnv__role-card--on':       rolesSeleccionados.includes(r.clave),
                'cnv__role-card--required': r.clave === 'admin',
              }"
              @click="toggleRol(r.clave)"
            >
              <div class="cnv__role-top">
                <div class="cnv__role-check">
                  <Check v-if="rolesSeleccionados.includes(r.clave)" :size="12" :stroke-width="3" />
                </div>
                <span class="cnv__role-label">{{ r.label }}</span>
                <span v-if="r.clave === 'admin'" class="cnv__role-req">siempre</span>
              </div>
              <div class="cnv__role-desc">{{ r.desc }}</div>
              <div class="cnv__role-email">{{ emailRol(r.clave) }}</div>
            </div>
          </div>
          <p class="cnv__hint" style="margin-top:.75rem">
            Los demás roles se crean después desde la ficha de la organización.
          </p>

          <div v-if="error" class="cnv__alert" style="margin-top:1.25rem">{{ error }}</div>
        </div>
      </div>

      <!-- ── Navegación ── -->
      <div class="cnv__nav">
        <button v-if="paso > 1" class="cnv__btn-ghost" @click="anterior">
          <ChevronLeft :size="16" :stroke-width="2" /> Anterior
        </button>
        <div class="cnv__nav-spacer"></div>
        <button v-if="paso < PASOS.length" class="cnv__btn-primary" @click="siguiente">
          Siguiente <ChevronRight :size="16" :stroke-width="2" />
        </button>
        <button v-else class="cnv__btn-primary" :disabled="saving" @click="handleSubmit">
          <DsSpinner v-if="saving" :size="15" />
          <Check v-else :size="16" :stroke-width="2.5" />
          {{ saving ? 'Creando…' : 'Crear club' }}
        </button>
      </div>

    </template>
  </div>
</template>

<style scoped>
.cnv {
  padding: 2rem 2.5rem 3rem;
}

.cnv__back {
  display: inline-flex; align-items: center; gap: .4rem;
  font-size: .78rem; font-weight: 600; color: var(--c-slate-500);
  text-decoration: none; margin-bottom: 1.5rem;
  transition: color .15s;
}
.cnv__back:hover { color: var(--c-slate-900); }

/* Header + stepper */
.cnv__header { margin-bottom: 2rem; }
.cnv__title { font-size: 1.75rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 1.5rem; letter-spacing: -.04em; }

.cnv__stepper {
  position: relative;
  display: flex; align-items: center; gap: 0;
  background: var(--c-slate-50); border: 1px solid var(--c-slate-200);
  border-radius: 12px; padding: .875rem 1.25rem;
}
.cnv__step {
  display: flex; align-items: center; gap: .5rem;
  flex: 1; position: relative; z-index: 1;
}
.cnv__step:last-child { flex: 0; }
.cnv__step-dot {
  width: 26px; height: 26px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: .75rem; font-weight: 700; flex-shrink: 0;
  background: var(--c-slate-200); color: var(--c-slate-400);
  border: 2px solid var(--c-slate-200);
  transition: all .2s;
}
.cnv__step--active .cnv__step-dot {
  background: var(--c-slate-900); color: #fff; border-color: var(--c-slate-900);
}
.cnv__step--done .cnv__step-dot {
  background: #1b5e20; color: #fff; border-color: #1b5e20;
}
.cnv__step-label {
  font-size: .78rem; font-weight: 600; color: var(--c-slate-400);
  white-space: nowrap;
}
.cnv__step--active .cnv__step-label { color: var(--c-slate-900); }
.cnv__step--done .cnv__step-label   { color: #1b5e20; }

/* Connector line */
.cnv__step:not(:last-child)::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--c-slate-200);
  margin: 0 .75rem;
}
.cnv__step-line { display: none; } /* handled by ::after */

/* Panel */
.cnv__panel {
  background: #fff; border: 1px solid var(--c-slate-200);
  border-radius: 16px; overflow: hidden;
  margin-bottom: 1.25rem;
}
.cnv__panel-header {
  display: flex; align-items: center; gap: .875rem;
  padding: 1.1rem 1.4rem; border-bottom: 1px solid var(--c-slate-100);
  background: #fafbfc;
}
.cnv__panel-ico {
  width: 38px; height: 38px; border-radius: 10px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  background: rgba(27,94,32,.1); color: #1b5e20;
}
.cnv__panel-ico--purple { background: rgba(124,58,237,.1); color: #7c3aed; }
.cnv__panel-ico--blue   { background: rgba(3,105,161,.1);  color: #0369a1; }
.cnv__panel-title { font-size: .9rem; font-weight: 800; color: var(--c-slate-900); }
.cnv__panel-sub   { font-size: .75rem; color: var(--c-slate-400); margin-top: .1rem; }
.cnv__panel-body  { padding: 1.4rem; }

/* Form */
.cnv__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 640px) { .cnv__grid { grid-template-columns: 1fr; } }
.cnv__row-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 640px) { .cnv__row-2 { grid-template-columns: 1fr; } }

.cnv__field { display: flex; flex-direction: column; gap: .3rem; }
.cnv__field--full { grid-column: 1 / -1; }
.cnv__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.cnv__req   { color: #dc2626; }
.cnv__input {
  background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 9px;
  padding: .6rem .9rem; font-size: .875rem; color: var(--c-slate-900);
  width: 100%; box-sizing: border-box; transition: border .15s;
}
.cnv__input:focus { outline: none; border-color: #1b5e20; background: #fff; box-shadow: 0 0 0 3px rgba(27,94,32,.08); }
.cnv__input--err  { border-color: #dc2626; }
.cnv__err  { font-size: .72rem; color: #dc2626; font-weight: 600; }
.cnv__hint { font-size: .72rem; color: var(--c-slate-400); }
.cnv__hint code { background: var(--c-slate-100); padding: .1em .4em; border-radius: 4px; font-size: .85em; }
.cnv__alert {
  background: #fef2f2; border: 1px solid #fecaca; color: #dc2626;
  padding: .75rem 1rem; border-radius: 9px; font-size: .82rem; margin-bottom: 1rem;
}
.cnv__section-label {
  font-size: .68rem; font-weight: 800; text-transform: uppercase;
  letter-spacing: .06em; color: var(--c-slate-400); margin-bottom: .6rem;
}

/* Planes */
.cnv__suites { display: flex; flex-direction: column; gap: 10px; }
.cnv__suite {
  display: flex; align-items: center; gap: 12px; text-align: left; cursor: pointer;
  padding: 14px 16px; border-radius: 12px; border: 1.5px solid var(--c-slate-200); background: #fff;
  transition: all .15s;
}
.cnv__suite--on { border-color: var(--c-leaf-500, #5A8A72); background: var(--c-leaf-50, #F4F8F5); }
.cnv__suite-check {
  width: 22px; height: 22px; border-radius: 6px; flex-shrink: 0;
  border: 1.5px solid var(--c-slate-300); display: grid; place-items: center;
  font-size: 13px; color: #fff; font-weight: 700;
}
.cnv__suite--on .cnv__suite-check { background: var(--c-leaf-800, #1A3D2E); border-color: var(--c-leaf-800, #1A3D2E); }
.cnv__suite-txt { display: flex; flex-direction: column; gap: 2px; }
.cnv__suite-name { font-size: 15px; font-weight: 700; color: var(--c-slate-900); }
.cnv__suite-desc { font-size: 12px; color: var(--c-slate-500); line-height: 1.4; }
.cnv__warn { margin: 10px 0 0; font-size: 12px; color: #b45309; }
.cnv__feat-toggle--warn { border-color: #fcd34d; }
/* Cargando el catálogo */
.cnv__cargando {
  display: flex; align-items: center; justify-content: center; gap: .75rem;
  padding: 4rem 0; color: var(--c-slate-500); font-size: .85rem;
}

/* Planes — dos tarjetas con sus topes a la vista */
.cnv__planes { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 700px) { .cnv__planes { grid-template-columns: 1fr; } }
.cnv__plan {
  padding: 1rem 1.125rem; border: 1.5px solid var(--c-slate-200); border-radius: 12px;
  background: var(--c-slate-50); text-align: left; cursor: pointer; transition: all .15s;
}
.cnv__plan:hover:not(.cnv__plan--on) { border-color: var(--c-slate-400); background: var(--c-slate-100); }
.cnv__plan--on { border-color: #1b5e20; background: #f0fdf4; }
.cnv__plan-top { display: flex; align-items: center; gap: .5rem; margin-bottom: .625rem; }
.cnv__plan-check {
  width: 18px; height: 18px; border-radius: 5px; flex-shrink: 0;
  border: 1.5px solid var(--c-slate-300); background: #fff;
  display: flex; align-items: center; justify-content: center; color: #fff;
}
.cnv__plan--on .cnv__plan-check { background: #1b5e20; border-color: #1b5e20; }
.cnv__plan-name { font-size: .95rem; font-weight: 800; color: var(--c-slate-900); }
.cnv__plan-limites { list-style: none; margin: 0; padding: 0; display: grid; gap: .25rem; }
.cnv__plan-limites li { font-size: .74rem; color: var(--c-slate-500); line-height: 1.35; }
.cnv__plan--on .cnv__plan-limites li { color: var(--c-slate-600); }

/* Incluidos en la suite — sin interruptor, porque no hay nada que decidir */
.cnv__incluidos { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px,1fr)); gap: .5rem; }
.cnv__incluido {
  display: flex; align-items: flex-start; gap: .55rem;
  padding: .7rem .85rem; border: 1px dashed var(--c-slate-300); border-radius: 10px;
  background: #f0fdf4;
}
.cnv__incluido--off { background: var(--c-slate-50); }
.cnv__incluido-ico { flex-shrink: 0; margin-top: .1rem; color: #1b5e20; }
.cnv__incluido--off .cnv__incluido-ico { color: var(--c-slate-400); }
.cnv__incluido-name { font-size: .8rem; font-weight: 700; color: var(--c-slate-900); }
.cnv__incluido--off .cnv__incluido-name { color: var(--c-slate-500); }
.cnv__incluido-desc { font-size: .69rem; color: var(--c-slate-500); line-height: 1.35; margin-top: .1rem; }

/* Qué le falta a un módulo prendido para andar de verdad */
.cnv__feat-requiere {
  display: flex; align-items: center; gap: .3rem; margin-top: .35rem;
  font-size: .66rem; font-weight: 600; color: #b45309; line-height: 1.3;
}

/* En construcción — se lista para que nadie lo prometa creyendo que está */
.cnv__construccion { display: grid; gap: .5rem; }
.cnv__constr-item {
  display: flex; align-items: center; gap: .6rem;
  padding: .7rem .85rem; border: 1px solid var(--c-slate-200); border-radius: 10px;
  background: var(--c-slate-50);
}
.cnv__constr-ico  { flex-shrink: 0; color: var(--c-slate-400); }
.cnv__constr-name { font-size: .8rem; font-weight: 700; color: var(--c-slate-500); }
.cnv__constr-desc { font-size: .69rem; color: var(--c-slate-400); line-height: 1.35; }
.cnv__constr-badge {
  margin-left: auto; flex-shrink: 0;
  font-size: .62rem; font-weight: 800; text-transform: uppercase; letter-spacing: .05em;
  color: var(--c-slate-500); background: var(--c-slate-200);
  padding: .2rem .45rem; border-radius: 5px;
}

/* Contraseña temporal — visible a propósito */
.cnv__pass { max-width: 420px; }
.cnv__pass-row { display: flex; gap: .5rem; align-items: stretch; }
.cnv__pass-row .cnv__input { flex: 1; }
.cnv__input--mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; letter-spacing: .02em; }
.cnv__pass-copy {
  display: inline-flex; align-items: center; gap: .35rem; flex-shrink: 0;
  padding: 0 .75rem; border: 1.5px solid var(--c-slate-200); border-radius: 9px;
  background: #fff; color: var(--c-slate-600);
  font-size: .75rem; font-weight: 700; cursor: pointer; transition: all .15s;
}
.cnv__pass-copy:hover:not(:disabled) { border-color: #1b5e20; color: #1b5e20; }
.cnv__pass-copy:disabled { opacity: .5; cursor: not-allowed; }

/* Lo que hay que pasarle al club, todo junto */
.cnv__entrega {
  border: 1px solid var(--c-slate-200); border-radius: 12px;
  background: var(--c-slate-50); padding: 1rem 1.125rem; margin-bottom: 1.5rem; text-align: left;
}
.cnv__entrega-head { display: flex; align-items: center; justify-content: space-between; gap: 1rem; margin-bottom: .625rem; }
.cnv__entrega-title {
  font-size: .7rem; font-weight: 800; text-transform: uppercase; letter-spacing: .07em;
  color: var(--c-slate-500);
}
.cnv__entrega-pass { font-size: .8rem; color: var(--c-slate-600); margin-bottom: .75rem; }
.cnv__entrega-pass code {
  font-size: .85rem; font-weight: 700; color: var(--c-slate-900);
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 6px; padding: .15rem .4rem;
}

/* Toggle */
.cnv__toggle {
  display: flex; align-items: flex-start; gap: .75rem;
  padding: .75rem 1rem; background: var(--c-slate-50);
  border: 1.5px solid var(--c-slate-200); border-radius: 10px; cursor: pointer;
}
.cnv__toggle:hover { border-color: #1b5e20; }
.cnv__toggle__input { display: none; }
.cnv__toggle__track {
  width: 40px; height: 22px; background: var(--c-slate-300); border-radius: 999px;
  position: relative; transition: background .2s; flex-shrink: 0; margin-top: .15rem;
}
.cnv__toggle__input:checked + .cnv__toggle__track { background: #1b5e20; }
.cnv__toggle__thumb {
  position: absolute; width: 16px; height: 16px; background: #fff;
  border-radius: 50%; top: 3px; left: 3px;
  transition: left .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2);
}
.cnv__toggle__input:checked + .cnv__toggle__track .cnv__toggle__thumb { left: 21px; }
.cnv__toggle__label { font-size: .875rem; font-weight: 700; color: var(--c-slate-900); }

/* Compact toggle for features */
.cnv__toggle__track--sm  { width: 32px; height: 18px; flex-shrink: 0; }
.cnv__toggle__thumb--sm  { width: 12px; height: 12px; top: 3px; left: 3px; }
.cnv__toggle__input:checked + .cnv__toggle__track--sm .cnv__toggle__thumb--sm { left: 17px; }

/* Feature flags grid */
.cnv__feat-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px,1fr)); gap: .4rem; }
.cnv__feat-toggle {
  display: flex; align-items: center; gap: .6rem;
  padding: .6rem .75rem; border-radius: 9px;
  border: 1.5px solid var(--c-slate-200); background: var(--c-slate-50);
  cursor: pointer; transition: border-color .15s, background .15s;
  user-select: none;
}
.cnv__feat-toggle--on { border-color: #bbf7d0; background: #f0fdf4; }
.cnv__feat-left { display: flex; align-items: center; gap: .5rem; flex: 1; min-width: 0; }
.cnv__feat-name { font-size: .78rem; font-weight: 700; color: var(--c-slate-900); }
.cnv__feat-desc { font-size: .68rem; color: var(--c-slate-400); }

/* Roles */
.cnv__roles-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px,1fr)); gap: .6rem; }
.cnv__role-card {
  padding: .875rem 1rem; border-radius: 10px;
  border: 1.5px solid var(--c-slate-200); background: var(--c-slate-50);
  cursor: pointer; transition: all .15s; user-select: none;
}
.cnv__role-card--on { border-color: #1b5e20; background: #f0fdf4; }
.cnv__role-card--required { cursor: default; }
.cnv__role-top { display: flex; align-items: center; gap: .5rem; margin-bottom: .3rem; }
.cnv__role-check {
  width: 18px; height: 18px; border-radius: 5px; border: 1.5px solid var(--c-slate-200);
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
  background: #fff; transition: all .15s;
}
.cnv__role-card--on .cnv__role-check { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.cnv__role-label { font-size: .82rem; font-weight: 800; color: var(--c-slate-900); flex: 1; }
.cnv__role-req   { font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; background: var(--c-slate-100); color: var(--c-slate-400); padding: .15em .5em; border-radius: 5px; }
.cnv__role-desc  { font-size: .72rem; color: var(--c-slate-500); margin-bottom: .35rem; }
.cnv__role-email { font-size: .68rem; color: var(--c-slate-400); font-family: monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

/* Navigation bar */
.cnv__nav {
  display: flex; align-items: center; gap: .75rem;
  padding-top: .25rem;
}
.cnv__nav-spacer { flex: 1; }
.cnv__btn-primary {
  display: inline-flex; align-items: center; gap: .45rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .75rem 1.4rem; border-radius: 10px;
  font-size: .875rem; font-weight: 700; cursor: pointer;
  transition: background .15s; white-space: nowrap;
}
.cnv__btn-primary:hover:not(:disabled) { background: #166534; }
.cnv__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.cnv__btn-ghost {
  display: inline-flex; align-items: center; gap: .4rem;
  background: transparent; color: var(--c-slate-500);
  border: 1.5px solid var(--c-slate-200); padding: .75rem 1.25rem;
  border-radius: 10px; font-size: .875rem; font-weight: 600;
  cursor: pointer; text-decoration: none; transition: all .15s;
}
.cnv__btn-ghost:hover { background: var(--c-slate-50); color: var(--c-slate-900); }

/* Success */
.cnv__success {
  background: #fff; border: 1px solid #bbf7d0; border-radius: 16px;
  padding: 3rem 2rem; text-align: center; max-width: 600px; margin: 0 auto;
}
.cnv__success-check {
  width: 56px; height: 56px; border-radius: 50%;
  background: #dcfce7; color: #15803d;
  display: flex; align-items: center; justify-content: center;
  margin: 0 auto 1rem;
}
.cnv__success-title { font-size: 1.5rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 .5rem; }
.cnv__success-sub { font-size: .875rem; color: var(--c-slate-500); margin: 0 0 1.5rem; }
.cnv__usuarios-grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(140px,1fr));
  gap: .6rem; margin-bottom: 2rem; text-align: left;
}
.cnv__usuario-card {
  background: var(--c-slate-50); border: 1px solid var(--c-slate-200);
  border-radius: 10px; padding: .7rem .875rem;
}
.cnv__usuario-role  { font-size: .68rem; font-weight: 800; text-transform: uppercase; letter-spacing: .05em; color: #1b5e20; margin-bottom: .2rem; }
.cnv__usuario-email { font-size: .72rem; color: var(--c-slate-500); font-family: monospace; word-break: break-all; }
.cnv__success-actions { display: flex; justify-content: center; gap: .75rem; flex-wrap: wrap; }
</style>
