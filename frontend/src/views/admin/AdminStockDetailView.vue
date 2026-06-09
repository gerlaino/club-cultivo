<template>
  <div class="sd">

    <!-- Back -->
    <div class="sd__back">
      <RouterLink to="/admin/stock" class="sd__back-link">
        <i class="bi bi-arrow-left"></i> Inventario
      </RouterLink>
    </div>

    <div v-if="loading" class="sd__loading"><DsSpinner /></div>

    <template v-else-if="stock">

      <!-- ── Hero ──────────────────────────────────────────────────── -->
      <div class="sd__hero">
        <div class="sd__hero-left">
          <div class="sd__forma-ico" :class="`sd__forma-ico--${stock.forma_producto}`">
            {{ formaIco(stock.forma_producto) }}
          </div>
          <div class="sd__hero-info">
            <h1 class="sd__hero-forma">{{ formaLabel(stock.forma_producto) }}</h1>
            <div class="sd__hero-lote">{{ stock.numero_lote_producto }}</div>
            <div class="sd__hero-chips">
              <span class="sd__badge" :class="`sd__badge--${stock.estado}`">{{ estadoLabel(stock.estado) }}</span>
              <span v-if="stock.lote?.genetica" class="sd__chip sd__chip--gen">{{ stock.lote.genetica.nombre }}</span>
              <span v-else-if="stock.genetica" class="sd__chip sd__chip--gen">{{ stock.genetica.nombre }}</span>
              <span v-if="stock.origen === 'compra_externa'" class="sd__chip sd__chip--ext">Externo</span>
              <span v-if="stock.estado_vencimiento && stock.estado_vencimiento !== 'ok'"
                class="sd__badge-venc" :class="`sd__badge-venc--${stock.estado_vencimiento}`">
                {{ badgeVencLabel(stock) }}
              </span>
            </div>
          </div>
        </div>
        <div class="sd__hero-kpis">
          <div class="sd__kpi">
            <div class="sd__kpi-val">{{ Number(stock.cantidad).toFixed(1) }}<span class="sd__kpi-unit">g</span></div>
            <div class="sd__kpi-lbl">Total físico</div>
          </div>
          <div class="sd__kpi" :class="{ 'sd__kpi--warn': stock.gramos_reservados > 0 }">
            <div class="sd__kpi-val">{{ Number(stock.cantidad_disponible_real).toFixed(1) }}<span class="sd__kpi-unit">g</span></div>
            <div class="sd__kpi-lbl">Disponible</div>
          </div>
          <div v-if="stock.gramos_reservados > 0" class="sd__kpi sd__kpi--amber">
            <div class="sd__kpi-val">{{ Number(stock.gramos_reservados).toFixed(1) }}<span class="sd__kpi-unit">g</span></div>
            <div class="sd__kpi-lbl">En delivery</div>
          </div>
        </div>
      </div>

      <!-- ── Layout ─────────────────────────────────────────────────── -->
      <div class="sd__layout">

        <!-- Main column -->
        <div class="sd__main">

          <!-- Datos -->
          <div class="sd__card">
            <div class="sd__card-hd">
              <h2 class="sd__card-title">Datos del stock</h2>
              <button v-if="!editando" class="sd__btn-ghost sd__btn-sm" @click="startEdit">
                <i class="bi bi-pencil"></i> Editar
              </button>
            </div>

            <template v-if="!editando">
              <div class="sd__data-grid">
                <div class="sd__data-item">
                  <span class="sd__data-lbl">Sede</span>
                  <span class="sd__data-val">{{ stock.sede?.nombre || 'Pool (sin sede)' }}</span>
                </div>
                <div class="sd__data-item">
                  <span class="sd__data-lbl">Origen</span>
                  <span class="sd__data-val">{{ origenLabel(stock.origen) }}</span>
                </div>
                <div class="sd__data-item">
                  <span class="sd__data-lbl">Precio sugerido</span>
                  <span class="sd__data-val">{{ stock.precio_sugerido_ars ? `$${Number(stock.precio_sugerido_ars).toFixed(2)}/g` : '—' }}</span>
                </div>
                <div class="sd__data-item">
                  <span class="sd__data-lbl">Costo unitario</span>
                  <span class="sd__data-val">{{ stock.costo_unitario_ars ? `$${Number(stock.costo_unitario_ars).toFixed(2)}/g` : '—' }}</span>
                </div>
                <div v-if="stock.fecha_elaboracion" class="sd__data-item">
                  <span class="sd__data-lbl">Fecha elaboración</span>
                  <span class="sd__data-val">{{ formatDate(stock.fecha_elaboracion) }}</span>
                </div>
                <div v-if="stock.fecha_vencimiento_est" class="sd__data-item">
                  <span class="sd__data-lbl">Vence estimado</span>
                  <span class="sd__data-val">{{ formatDate(stock.fecha_vencimiento_est) }}</span>
                </div>
                <div v-if="stock.proveedor" class="sd__data-item">
                  <span class="sd__data-lbl">Proveedor</span>
                  <span class="sd__data-val">{{ stock.proveedor }}</span>
                </div>
                <div v-if="stock.descripcion" class="sd__data-item sd__data-item--full">
                  <span class="sd__data-lbl">Descripción</span>
                  <span class="sd__data-val">{{ stock.descripcion }}</span>
                </div>
              </div>
            </template>

            <template v-else>
              <div v-if="editError" class="sd__alert">{{ editError }}</div>
              <div class="sd__form-grid">
                <div class="sd__field">
                  <label class="sd__label">Precio sugerido (ARS/g)</label>
                  <input type="number" min="0" step="0.01" class="sd__input" v-model.number="editForm.precio_sugerido_ars" placeholder="0.00" />
                </div>
                <div class="sd__field">
                  <label class="sd__label">Costo unitario (ARS/g)</label>
                  <input type="number" min="0" step="0.01" class="sd__input" v-model.number="editForm.costo_unitario_ars" placeholder="0.00" />
                </div>
                <div v-if="stock.origen === 'compra_externa'" class="sd__field">
                  <label class="sd__label">Proveedor</label>
                  <input type="text" class="sd__input" v-model.trim="editForm.proveedor" />
                </div>
                <div class="sd__field sd__field--full">
                  <label class="sd__label">Descripción / Notas</label>
                  <textarea class="sd__input sd__textarea" rows="2" v-model.trim="editForm.descripcion" placeholder="Observaciones…"></textarea>
                </div>
              </div>
              <div class="sd__edit-ft">
                <button class="sd__btn-ghost" @click="cancelEdit">Cancelar</button>
                <button class="sd__btn-primary" :disabled="saving" @click="guardarEdit">
                  <DsSpinner v-if="saving" :size="12" />
                  <i v-else class="bi bi-check-lg"></i>
                  Guardar
                </button>
              </div>
            </template>
          </div>

          <!-- Movimientos -->
          <div class="sd__card">
            <div class="sd__card-hd">
              <h2 class="sd__card-title">Historial de movimientos</h2>
              <span v-if="movimientos.length" class="sd__card-count">{{ movimientos.length }}</span>
            </div>
            <div v-if="loadingMov" class="sd__loading-sm"><DsSpinner /></div>
            <div v-else-if="!movimientos.length" class="sd__empty-sm">
              Sin movimientos registrados aún.
            </div>
            <div v-else class="sd__movs">
              <div v-for="m in movimientos" :key="m.id" class="sd__mov">
                <div class="sd__mov-line">
                  <div class="sd__mov-dot" :class="`sd__mov-dot--${m.tipo}`"></div>
                </div>
                <div class="sd__mov-body">
                  <div class="sd__mov-row">
                    <span class="sd__mov-tipo" :class="`sd__mov-tipo--${m.tipo}`">{{ movTipoLabel(m.tipo) }}</span>
                    <span class="sd__mov-g" :class="m.gramos >= 0 ? 'sd__mov-g--pos' : 'sd__mov-g--neg'">
                      {{ m.gramos >= 0 ? '+' : '' }}{{ m.gramos.toFixed(2) }}g
                    </span>
                  </div>
                  <div class="sd__mov-notas">{{ m.notas || '—' }}</div>
                  <div class="sd__mov-meta">
                    <span v-if="m.usuario">{{ m.usuario.nombre }}</span>
                    <span>{{ formatDate(m.created_at) }}</span>
                    <span v-if="m.sede_destino">→ {{ m.sede_destino.nombre }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

        </div>

        <!-- Aside -->
        <aside class="sd__aside">

          <!-- Acciones -->
          <div class="sd__card sd__card--acciones">
            <h2 class="sd__card-title">Acciones</h2>
            <div class="sd__actions">
              <button class="sd__action" @click="showAjustar = true" :disabled="stock.agotado">
                <span class="sd__action-ico sd__action-ico--green"><i class="bi bi-sliders"></i></span>
                <div class="sd__action-txt">
                  <div class="sd__action-lbl">Ajustar gramos</div>
                  <div class="sd__action-sub">Merma, pérdida o reconteo</div>
                </div>
              </button>
              <button class="sd__action" @click="openRepartir" :disabled="stock.agotado || !stock.sede_id">
                <span class="sd__action-ico sd__action-ico--blue"><i class="bi bi-arrows-angle-expand"></i></span>
                <div class="sd__action-txt">
                  <div class="sd__action-lbl">Repartir a sede</div>
                  <div class="sd__action-sub">Fraccioná y asigná a otra sede</div>
                </div>
              </button>
              <button
                v-if="stock.forma_producto === 'flor_seca' && stock.lote_id"
                class="sd__action sd__action--amber"
                @click="openProcesar"
                :disabled="stock.agotado"
              >
                <span class="sd__action-ico sd__action-ico--amber"><i class="bi bi-arrow-right-square"></i></span>
                <div class="sd__action-txt">
                  <div class="sd__action-lbl">Procesar derivado</div>
                  <div class="sd__action-sub">Convertir en hash, aceite, etc.</div>
                </div>
              </button>
              <div class="sd__actions-sep"></div>
              <button class="sd__action sd__action--danger" @click="showDescartar = true" :disabled="stock.agotado">
                <span class="sd__action-ico sd__action-ico--red"><i class="bi bi-trash"></i></span>
                <div class="sd__action-txt">
                  <div class="sd__action-lbl">Descartar stock</div>
                  <div class="sd__action-sub">Marcar como agotado con merma</div>
                </div>
              </button>
            </div>
          </div>

          <!-- Origen / trazabilidad -->
          <div class="sd__card">
            <h2 class="sd__card-title">Origen</h2>
            <div class="sd__data-grid">
              <div class="sd__data-item sd__data-item--full">
                <span class="sd__data-lbl">Tipo</span>
                <span class="sd__data-val">{{ origenLabel(stock.origen) }}</span>
              </div>
              <template v-if="stock.lote">
                <div class="sd__data-item sd__data-item--full">
                  <span class="sd__data-lbl">Lote origen</span>
                  <RouterLink :to="`/lotes/${stock.lote.id}`" class="sd__link">{{ stock.lote.codigo }}</RouterLink>
                </div>
                <div v-if="stock.lote.genetica" class="sd__data-item sd__data-item--full">
                  <span class="sd__data-lbl">Genética</span>
                  <span class="sd__data-val">{{ stock.lote.genetica.nombre }}</span>
                </div>
              </template>
              <div v-if="stock.lote_origen_consumido_g" class="sd__data-item sd__data-item--full">
                <span class="sd__data-lbl">Flor consumida</span>
                <span class="sd__data-val">{{ stock.lote_origen_consumido_g }}g</span>
              </div>
            </div>

            <!-- QR -->
            <RouterLink v-if="stock.codigo_qr" :to="`/s/${stock.codigo_qr}`" target="_blank" class="sd__qr-btn">
              <i class="bi bi-qr-code"></i>
              <div>
                <div class="sd__qr-lbl">Ver / imprimir QR</div>
                <div class="sd__qr-code">{{ stock.codigo_qr }}</div>
              </div>
              <i class="bi bi-box-arrow-up-right sd__qr-ext"></i>
            </RouterLink>
          </div>

        </aside>
      </div>
    </template>

    <div v-else class="sd__not-found">
      <span>📦</span>
      <p>Stock no encontrado</p>
      <RouterLink to="/admin/stock" class="sd__btn-ghost">← Volver al inventario</RouterLink>
    </div>

    <!-- ── Modal: Ajustar ────────────────────────────────────────────── -->
    <Teleport to="body">
      <Transition name="sd-fade">
        <div v-if="showAjustar" class="sd__overlay" @click.self="showAjustar = false">
          <div class="sd__modal">
            <div class="sd__modal-hd">
              <div class="sd__modal-ico"><i class="bi bi-sliders"></i></div>
              <div>
                <h2 class="sd__modal-title">Ajustar gramos</h2>
                <p class="sd__modal-sub">Stock actual: <strong>{{ stock?.cantidad }}g</strong></p>
              </div>
              <button class="sd__modal-close" @click="showAjustar = false"><i class="bi bi-x-lg"></i></button>
            </div>
            <div class="sd__modal-body">
              <div v-if="ajustarError" class="sd__alert">{{ ajustarError }}</div>
              <div class="sd__form-grid">
                <div class="sd__field">
                  <label class="sd__label">Tipo de ajuste <span class="sd__req">*</span></label>
                  <select class="sd__input" v-model="ajustarForm.tipo">
                    <option value="merma">Merma (pérdida de proceso)</option>
                    <option value="perdida">Pérdida / daño / robo</option>
                    <option value="reconteo">Reconteo (corrección de inventario)</option>
                  </select>
                </div>
                <div class="sd__field" v-if="ajustarForm.tipo !== 'reconteo'">
                  <label class="sd__label">Gramos a descontar <span class="sd__req">*</span></label>
                  <div class="sd__input-row">
                    <input type="number" min="0.01" :max="stock?.cantidad" step="0.01"
                      class="sd__input" v-model.number="ajustarForm.gramos"
                      :placeholder="`máx ${stock?.cantidad}g`" />
                    <span class="sd__input-suf">g</span>
                  </div>
                </div>
                <div class="sd__field" v-else>
                  <label class="sd__label">Nueva cantidad real (g) <span class="sd__req">*</span></label>
                  <div class="sd__input-row">
                    <input type="number" min="0" step="0.01"
                      class="sd__input" v-model.number="ajustarForm.nuevaCantidad"
                      :placeholder="`actual: ${stock?.cantidad}g`" />
                    <span class="sd__input-suf">g</span>
                  </div>
                </div>
                <div class="sd__field sd__field--full">
                  <label class="sd__label">Motivo <span class="sd__req">*</span></label>
                  <textarea class="sd__input sd__textarea" rows="2" v-model="ajustarForm.motivo" placeholder="Describí el motivo del ajuste…"></textarea>
                </div>
              </div>
              <div v-if="ajustarPreview !== null" class="sd__ajuste-preview" :class="ajustarDelta >= 0 ? 'sd__ajuste-preview--pos' : 'sd__ajuste-preview--neg'">
                <span>Resultado: <strong>{{ ajustarPreview.toFixed(2) }}g</strong></span>
                <span class="sd__ajuste-delta">{{ ajustarDelta >= 0 ? '+' : '' }}{{ ajustarDelta.toFixed(2) }}g</span>
              </div>
            </div>
            <div class="sd__modal-ft">
              <button class="sd__btn-ghost" @click="showAjustar = false">Cancelar</button>
              <button class="sd__btn-primary" :disabled="ajustando" @click="ejecutarAjustar">
                <DsSpinner v-if="ajustando" :size="12" />
                <i v-else class="bi bi-check-lg"></i>
                Confirmar ajuste
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- ── Modal: Descartar ──────────────────────────────────────────── -->
    <Teleport to="body">
      <Transition name="sd-fade">
        <div v-if="showDescartar" class="sd__overlay" @click.self="showDescartar = false">
          <div class="sd__modal">
            <div class="sd__modal-hd">
              <div class="sd__modal-ico sd__modal-ico--danger"><i class="bi bi-trash"></i></div>
              <div>
                <h2 class="sd__modal-title">Descartar stock</h2>
                <p class="sd__modal-sub">Se registrará una merma de <strong>{{ stock?.cantidad }}g</strong></p>
              </div>
              <button class="sd__modal-close" @click="showDescartar = false"><i class="bi bi-x-lg"></i></button>
            </div>
            <div class="sd__modal-body">
              <div v-if="descartarError" class="sd__alert">{{ descartarError }}</div>
              <div class="sd__descarte-warn">
                <i class="bi bi-exclamation-triangle-fill"></i>
                Esta acción marca el stock como <strong>agotado</strong> y no se puede revertir.
              </div>
              <div class="sd__form-grid">
                <div class="sd__field sd__field--full">
                  <label class="sd__label">Motivo del descarte <span class="sd__req">*</span></label>
                  <textarea class="sd__input sd__textarea" rows="3" v-model="descartarForm.motivo" placeholder="Ej: vencimiento, contaminación, pérdida irreversible…"></textarea>
                </div>
              </div>
            </div>
            <div class="sd__modal-ft">
              <button class="sd__btn-ghost" @click="showDescartar = false">Cancelar</button>
              <button class="sd__btn-danger" :disabled="descartando || !descartarForm.motivo.trim()" @click="ejecutarDescartar">
                <DsSpinner v-if="descartando" :size="12" />
                <i v-else class="bi bi-trash"></i>
                Descartar {{ stock?.cantidad }}g
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- ── Modal: Repartir ───────────────────────────────────────────── -->
    <Teleport to="body">
      <Transition name="sd-fade">
        <div v-if="showRepartir" class="sd__overlay" @click.self="showRepartir = false">
          <div class="sd__modal">
            <div class="sd__modal-hd">
              <div class="sd__modal-ico"><i class="bi bi-arrows-angle-expand"></i></div>
              <div>
                <h2 class="sd__modal-title">Repartir a sede</h2>
                <p class="sd__modal-sub">{{ stock?.cantidad }}g disponibles en {{ stock?.sede?.nombre || '—' }}</p>
              </div>
              <button class="sd__modal-close" @click="showRepartir = false"><i class="bi bi-x-lg"></i></button>
            </div>
            <div class="sd__modal-body">
              <div v-if="repartirError" class="sd__alert">{{ repartirError }}</div>
              <div class="sd__form-grid">
                <div class="sd__field">
                  <label class="sd__label">Cantidad a enviar (g) <span class="sd__req">*</span></label>
                  <div class="sd__input-row">
                    <input type="number" min="0.1" :max="stock?.cantidad" step="0.1"
                      class="sd__input" v-model.number="repartirForm.cantidad"
                      :placeholder="`máx ${stock?.cantidad}g`" />
                    <span class="sd__input-suf">g</span>
                  </div>
                </div>
                <div class="sd__field">
                  <label class="sd__label">Sede destino <span class="sd__req">*</span></label>
                  <select class="sd__input" v-model="repartirForm.sede_id">
                    <option value="">— Elegir sede —</option>
                    <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                  </select>
                </div>
              </div>
            </div>
            <div class="sd__modal-ft">
              <button class="sd__btn-ghost" @click="showRepartir = false">Cancelar</button>
              <button class="sd__btn-primary" :disabled="repartiendo" @click="ejecutarRepartir">
                <DsSpinner v-if="repartiendo" :size="12" />
                <i v-else class="bi bi-arrows-angle-expand"></i>
                Repartir
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- ── Modal: Procesar derivado ──────────────────────────────────── -->
    <Teleport to="body">
      <Transition name="sd-fade">
        <div v-if="showProcesar" class="sd__overlay" @click.self="showProcesar = false">
          <div class="sd__modal">
            <div class="sd__modal-hd">
              <div class="sd__modal-ico sd__modal-ico--amber"><i class="bi bi-arrow-right-square"></i></div>
              <div>
                <h2 class="sd__modal-title">Procesar derivado</h2>
                <p class="sd__modal-sub">{{ stock?.cantidad }}g de flor seca · {{ stock?.lote?.codigo }}</p>
              </div>
              <button class="sd__modal-close" @click="showProcesar = false"><i class="bi bi-x-lg"></i></button>
            </div>
            <div class="sd__modal-body">
              <div v-if="procesarError" class="sd__alert">{{ procesarError }}</div>
              <div class="sd__form-grid">
                <div class="sd__field">
                  <label class="sd__label">Gramos a consumir <span class="sd__req">*</span></label>
                  <div class="sd__input-row">
                    <input type="number" min="0.1" :max="stock?.cantidad" step="0.1"
                      class="sd__input" v-model.number="procesarForm.gramos_consumir"
                      :placeholder="`máx ${stock?.cantidad}g`" />
                    <span class="sd__input-suf">g</span>
                  </div>
                </div>
                <div class="sd__field">
                  <label class="sd__label">Forma del derivado <span class="sd__req">*</span></label>
                  <select class="sd__input" v-model="procesarForm.forma_producto">
                    <option v-for="f in FORMAS_DERIVADO" :key="f.value" :value="f.value">{{ f.label }}</option>
                  </select>
                </div>
                <div class="sd__field">
                  <label class="sd__label">Cantidad resultante (g) <span class="sd__req">*</span></label>
                  <div class="sd__input-row">
                    <input type="number" min="0.01" step="0.01"
                      class="sd__input" v-model.number="procesarForm.cantidad_resultado" placeholder="0.0" />
                    <span class="sd__input-suf">g</span>
                  </div>
                </div>
                <div class="sd__field">
                  <label class="sd__label">Sede destino <span class="sd__req">*</span></label>
                  <select class="sd__input" v-model="procesarForm.sede_id">
                    <option value="">— Elegir sede —</option>
                    <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                  </select>
                </div>
              </div>
              <div v-if="mermaG > 0" class="sd__merma">
                <span>⚠️</span>
                <span>Merma: <strong>{{ mermaG }}g ({{ mermaPct }}%)</strong></span>
              </div>
            </div>
            <div class="sd__modal-ft">
              <button class="sd__btn-ghost" @click="showProcesar = false">Cancelar</button>
              <button class="sd__btn-amber" :disabled="procesando" @click="ejecutarProcesar">
                <DsSpinner v-if="procesando" :size="12" />
                <i v-else class="bi bi-arrow-right-square"></i>
                Procesar
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import DsSpinner from '../../design-system/components/Spinner.vue'
import {
  updateStock, asignarStock, ajustarStock, descartarStock,
  getStockMovimientos, listSedes, createStock,
} from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const route  = useRoute()
const router = useRouter()
const toast  = useToast()

// ── Data ───────────────────────────────────────────────────────────────────────
const loading    = ref(true)
const stock      = ref(null)
const movimientos = ref([])
const loadingMov = ref(false)
const sedes      = ref([])

onMounted(async () => {
  const id = route.params.id
  try {
    const [rStock, rMov, rSedes] = await Promise.all([
      fetch(`/api/stocks/${id}`, { headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest' } }).then(r => r.json()),
      import('../../lib/api.js').then(({ getStockMovimientos }) => getStockMovimientos(id)),
      listSedes(),
    ])
    stock.value      = rStock.data || rStock
    movimientos.value = rMov.data || []
    sedes.value      = rSedes.data || []
  } catch {
    toast.error('Error al cargar el stock')
  } finally {
    loading.value = false
  }
})

async function recargar() {
  const id = route.params.id
  const [rStock, rMov] = await Promise.all([
    fetch(`/api/stocks/${id}`, { headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest' } }).then(r => r.json()),
    getStockMovimientos(id),
  ])
  stock.value       = rStock.data || rStock
  movimientos.value = rMov.data || []
}

// ── Edit datos ─────────────────────────────────────────────────────────────────
const editando  = ref(false)
const saving    = ref(false)
const editError = ref(null)
const editForm  = ref({})

function startEdit() {
  editForm.value = {
    precio_sugerido_ars: stock.value.precio_sugerido_ars ? Number(stock.value.precio_sugerido_ars) : null,
    costo_unitario_ars:  stock.value.costo_unitario_ars  ? Number(stock.value.costo_unitario_ars)  : null,
    proveedor:   stock.value.proveedor   || '',
    descripcion: stock.value.descripcion || '',
  }
  editError.value = null
  editando.value  = true
}
function cancelEdit() { editando.value = false }

async function guardarEdit() {
  saving.value    = true
  editError.value = null
  try {
    const f = editForm.value
    const payload = {}
    if (f.precio_sugerido_ars != null) payload.precio_sugerido_ars = f.precio_sugerido_ars
    if (f.costo_unitario_ars  != null) payload.costo_unitario_ars  = f.costo_unitario_ars
    if (f.proveedor)                   payload.proveedor           = f.proveedor
    if (f.descripcion)                 payload.descripcion         = f.descripcion
    await updateStock(stock.value.id, payload)
    await recargar()
    editando.value = false
    toast.success('Datos actualizados')
  } catch (e) {
    editError.value = e?.response?.data?.errors?.[0] || 'Error al guardar'
  } finally { saving.value = false }
}

// ── Ajustar ────────────────────────────────────────────────────────────────────
const showAjustar  = ref(false)
const ajustarForm  = ref({ tipo: 'merma', gramos: null, nuevaCantidad: null, motivo: '' })
const ajustarError = ref(null)
const ajustando    = ref(false)

const ajustarDelta = computed(() => {
  if (!stock.value) return 0
  const actual = parseFloat(stock.value.cantidad)
  if (ajustarForm.value.tipo !== 'reconteo') return -(ajustarForm.value.gramos || 0)
  const nueva = ajustarForm.value.nuevaCantidad
  return nueva != null ? nueva - actual : 0
})
const ajustarPreview = computed(() => {
  if (!stock.value) return null
  const actual = parseFloat(stock.value.cantidad)
  if (ajustarForm.value.tipo !== 'reconteo') {
    if (!ajustarForm.value.gramos) return null
    return Math.max(0, actual - ajustarForm.value.gramos)
  }
  return ajustarForm.value.nuevaCantidad != null ? ajustarForm.value.nuevaCantidad : null
})

async function ejecutarAjustar() {
  ajustarError.value = null
  const actual = parseFloat(stock.value.cantidad)
  const motivo = ajustarForm.value.motivo.trim()
  let gramos
  if (!motivo) { ajustarError.value = 'El motivo es obligatorio'; return }
  if (ajustarForm.value.tipo !== 'reconteo') {
    if (!ajustarForm.value.gramos || ajustarForm.value.gramos <= 0) { ajustarError.value = 'Ingresá los gramos a descontar'; return }
    gramos = -ajustarForm.value.gramos
  } else {
    if (ajustarForm.value.nuevaCantidad == null) { ajustarError.value = 'Ingresá la nueva cantidad'; return }
    gramos = ajustarForm.value.nuevaCantidad - actual
    if (gramos === 0) { ajustarError.value = 'La nueva cantidad es igual a la actual'; return }
  }
  ajustando.value = true
  try {
    await ajustarStock(stock.value.id, { tipo: ajustarForm.value.tipo, gramos, motivo })
    showAjustar.value = false
    ajustarForm.value = { tipo: 'merma', gramos: null, nuevaCantidad: null, motivo: '' }
    await recargar()
    toast.success('Stock ajustado')
  } catch (e) {
    ajustarError.value = e?.response?.data?.error || e?.response?.data?.errors?.[0] || 'Error al ajustar'
  } finally { ajustando.value = false }
}

// ── Descartar ──────────────────────────────────────────────────────────────────
const showDescartar  = ref(false)
const descartarForm  = ref({ motivo: '' })
const descartarError = ref(null)
const descartando    = ref(false)

async function ejecutarDescartar() {
  descartarError.value = null
  const motivo = descartarForm.value.motivo.trim()
  if (!motivo) { descartarError.value = 'El motivo es obligatorio'; return }
  descartando.value = true
  try {
    await descartarStock(stock.value.id, { motivo })
    showDescartar.value = false
    await recargar()
    toast.success('Stock descartado')
  } catch (e) {
    descartarError.value = e?.response?.data?.error || 'Error al descartar'
  } finally { descartando.value = false }
}

// ── Repartir ───────────────────────────────────────────────────────────────────
const showRepartir  = ref(false)
const repartirForm  = ref({ sede_id: '', cantidad: null })
const repartirError = ref(null)
const repartiendo   = ref(false)

function openRepartir() {
  repartirForm.value  = { sede_id: '', cantidad: null }
  repartirError.value = null
  showRepartir.value  = true
}

async function ejecutarRepartir() {
  repartirError.value = null
  const cant = Number(repartirForm.value.cantidad)
  if (!repartirForm.value.sede_id) { repartirError.value = 'Elegí una sede'; return }
  if (!cant || cant <= 0) { repartirError.value = 'La cantidad es obligatoria'; return }
  if (cant > stock.value.cantidad) { repartirError.value = `Máximo: ${stock.value.cantidad}g`; return }
  repartiendo.value = true
  try {
    await asignarStock(stock.value.id, { sede_id: repartirForm.value.sede_id, cantidad: cant })
    showRepartir.value = false
    await recargar()
    toast.success('Stock repartido')
  } catch (e) {
    repartirError.value = e?.response?.data?.error || 'Error al repartir'
  } finally { repartiendo.value = false }
}

// ── Procesar derivado ──────────────────────────────────────────────────────────
const showProcesar  = ref(false)
const procesarForm  = ref({ gramos_consumir: null, forma_producto: 'aceite', cantidad_resultado: null, sede_id: '' })
const procesarError = ref(null)
const procesando    = ref(false)

const FORMAS_DERIVADO = [
  { value: 'hash', label: 'Hash' }, { value: 'aceite', label: 'Aceite' },
  { value: 'tintura', label: 'Tintura' }, { value: 'crema', label: 'Crema' },
  { value: 'capsula', label: 'Cápsula' }, { value: 'comestible', label: 'Comestible' },
  { value: 'prensado', label: 'Prensado' }, { value: 'otro', label: 'Otro' },
]

const mermaG = computed(() => {
  const consumir  = Number(procesarForm.value.gramos_consumir)
  const resultado = Number(procesarForm.value.cantidad_resultado)
  if (!consumir || !resultado || resultado >= consumir) return 0
  return parseFloat((consumir - resultado).toFixed(2))
})
const mermaPct = computed(() => {
  const consumir  = Number(procesarForm.value.gramos_consumir)
  const resultado = Number(procesarForm.value.cantidad_resultado)
  if (!consumir || !resultado || resultado >= consumir) return 0
  return parseFloat(((consumir - resultado) / consumir * 100).toFixed(1))
})

function openProcesar() {
  procesarForm.value  = { gramos_consumir: null, forma_producto: 'aceite', cantidad_resultado: null, sede_id: '' }
  procesarError.value = null
  showProcesar.value  = true
}

async function ejecutarProcesar() {
  procesarError.value = null
  const consumir  = Number(procesarForm.value.gramos_consumir)
  const resultado = Number(procesarForm.value.cantidad_resultado)
  if (!consumir || consumir <= 0)        { procesarError.value = 'Ingresá los gramos a consumir'; return }
  if (consumir > stock.value.cantidad)   { procesarError.value = `Máximo: ${stock.value.cantidad}g`; return }
  if (!resultado || resultado <= 0)      { procesarError.value = 'Ingresá la cantidad resultante'; return }
  if (!procesarForm.value.sede_id)       { procesarError.value = 'Elegí una sede destino'; return }
  procesando.value = true
  try {
    await createStock({
      origen: 'derivado_lote', lote_id: stock.value.lote_id,
      lote_origen_consumido_g: consumir, forma_producto: procesarForm.value.forma_producto,
      cantidad: resultado, unidad: 'g', estado: 'asignado',
      sede_id: Number(procesarForm.value.sede_id),
    })
    showProcesar.value = false
    await recargar()
    toast.success('Derivado procesado correctamente')
  } catch (e) {
    procesarError.value = e?.response?.data?.errors?.[0] || e?.response?.data?.error || 'Error al procesar'
  } finally { procesando.value = false }
}

// ── Helpers ────────────────────────────────────────────────────────────────────
const FORMA_MAP = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite', tintura: 'Tintura',
  crema: 'Crema', capsula: 'Cápsula', comestible: 'Comestible', prensado: 'Prensado',
  otro: 'Otro', externo: 'Externo',
}
const FORMA_ICO = {
  flor_seca: '🌿', hash: '🪨', aceite: '💧', tintura: '🧪',
  crema: '🫙', capsula: '💊', comestible: '🍬', prensado: '🟫',
  otro: '📦', externo: '📦',
}
const ORIGEN_MAP = { lote: 'Producción propia', derivado_lote: 'Derivado de lote', compra_externa: 'Compra externa' }
const ESTADO_MAP = { pendiente_asignacion: 'Por asignar', asignado: 'Asignado', agotado: 'Agotado' }
const MOV_TIPO_MAP = { produccion: 'Producción', transferencia: 'Transferencia', dispensacion: 'Dispensación', ajuste: 'Ajuste', merma: 'Merma' }

function formaLabel(f)    { return FORMA_MAP[f]  || f || 'Stock' }
function formaIco(f)      { return FORMA_ICO[f]  || '📦' }
function origenLabel(o)   { return ORIGEN_MAP[o] || o }
function estadoLabel(e)   { return ESTADO_MAP[e] || e }
function movTipoLabel(t)  { return MOV_TIPO_MAP[t] || t }
function formatDate(d)    { return d ? new Date(d).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: '2-digit' }) : '—' }
function badgeVencLabel(s) {
  const dias = s.dias_para_vencimiento
  if (dias == null) return ''
  if (dias < 0)   return `Vencido +${Math.abs(dias)}d`
  if (dias === 0) return 'Vence hoy'
  return `Vence en ${dias}d`
}
</script>

<style scoped>
.sd { padding: 1.5rem 1.75rem 3rem; max-width: 1100px; }
@media (max-width: 640px) { .sd { padding: 1rem 1rem 2rem; } }

/* Back */
.sd__back { margin-bottom: 1.25rem; }
.sd__back-link {
  display: inline-flex; align-items: center; gap: .4rem;
  font-size: .82rem; font-weight: 600; color: #475569;
  text-decoration: none; padding: .35rem .6rem; border-radius: 6px;
  transition: background .15s, color .15s;
}
.sd__back-link:hover { background: #f1f5f9; color: #0f172a; }

/* ── Hero ─────────────────────────────────────────────────────────────────── */
.sd__hero {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 16px;
  padding: 1.5rem 1.75rem; margin-bottom: 1.5rem;
  display: flex; align-items: center; justify-content: space-between;
  gap: 1.5rem; flex-wrap: wrap;
  box-shadow: 0 1px 4px rgba(0,0,0,.04);
}
.sd__hero-left { display: flex; align-items: center; gap: 1.1rem; }
.sd__forma-ico {
  width: 56px; height: 56px; border-radius: 14px; font-size: 1.75rem;
  display: flex; align-items: center; justify-content: center;
  background: #f0fdf4; flex-shrink: 0;
}
.sd__forma-ico--aceite, .sd__forma-ico--tintura { background: #eff6ff; }
.sd__forma-ico--hash, .sd__forma-ico--prensado  { background: #fef3c7; }
.sd__forma-ico--crema, .sd__forma-ico--capsula  { background: #fdf4ff; }
.sd__forma-ico--compra_externa, .sd__forma-ico--externo { background: #f8fafc; }

.sd__hero-forma { font-size: 1.35rem; font-weight: 800; color: #0f172a; margin: 0 0 .2rem; letter-spacing: -.03em; }
.sd__hero-lote  { font-size: .78rem; font-weight: 700; color: #94a3b8; font-family: monospace; margin-bottom: .5rem; letter-spacing: .05em; }
.sd__hero-chips { display: flex; flex-wrap: wrap; gap: .35rem; }

.sd__hero-kpis { display: flex; gap: 1.5rem; flex-shrink: 0; }
.sd__kpi { text-align: center; }
.sd__kpi-val  { font-size: 1.6rem; font-weight: 900; color: #0f172a; line-height: 1; letter-spacing: -.04em; }
.sd__kpi-unit { font-size: .9rem; font-weight: 500; color: #94a3b8; margin-left: 1px; }
.sd__kpi-lbl  { font-size: .62rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .06em; margin-top: .2rem; }
.sd__kpi--warn .sd__kpi-val   { color: #15803d; }
.sd__kpi--amber .sd__kpi-val  { color: #d97706; }

/* Badges + chips */
.sd__badge {
  display: inline-flex; align-items: center; padding: .22em .65em;
  border-radius: 5px; font-size: .68rem; font-weight: 700; white-space: nowrap;
}
.sd__badge--pendiente_asignacion { background: #fef3c7; color: #92400e; border: 1px solid #fde68a; }
.sd__badge--asignado             { background: #dcfce7; color: #15803d; border: 1px solid #bbf7d0; }
.sd__badge--agotado              { background: #f1f5f9; color: #64748b; border: 1px solid #e2e8f0; }
.sd__badge-venc { font-size: .68rem; font-weight: 700; padding: .22em .65em; border-radius: 5px; }
.sd__badge-venc--vencido { background: #fee2e2; color: #dc2626; }
.sd__badge-venc--critico { background: #ffedd5; color: #ea580c; }
.sd__badge-venc--proximo { background: #fef9c3; color: #a16207; }
.sd__chip { font-size: .68rem; font-weight: 600; padding: .2em .6em; border-radius: 5px; background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0; }
.sd__chip--gen { background: #f0fdf4; color: #166534; border-color: #bbf7d0; }
.sd__chip--ext { background: #fef3c7; color: #92400e; border-color: #fde68a; }
.sd__chip--reg { background: #eff6ff; color: #1d4ed8; border-color: #bfdbfe; }

/* ── Layout ───────────────────────────────────────────────────────────────── */
.sd__layout { display: grid; grid-template-columns: 1fr 300px; gap: 1.25rem; align-items: start; }
@media (max-width: 860px) { .sd__layout { grid-template-columns: 1fr; } }
.sd__main  { display: flex; flex-direction: column; gap: 1.25rem; }
.sd__aside { display: flex; flex-direction: column; gap: 1.25rem; }

/* ── Card ─────────────────────────────────────────────────────────────────── */
.sd__card {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 14px;
  padding: 1.25rem 1.5rem; box-shadow: 0 1px 4px rgba(0,0,0,.04);
}
.sd__card-hd {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: 1rem;
}
.sd__card-title { font-size: .88rem; font-weight: 800; color: #0f172a; margin: 0; letter-spacing: -.01em; }
.sd__card-count {
  font-size: .68rem; font-weight: 700; background: #f1f5f9; color: #64748b;
  padding: .2em .55em; border-radius: 99px; border: 1px solid #e2e8f0;
}
.sd__card--acciones { padding: 1.25rem; }
.sd__card--acciones .sd__card-title { margin-bottom: 1rem; }

/* Data grid */
.sd__data-grid { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
.sd__data-item { display: flex; flex-direction: column; gap: .2rem; }
.sd__data-item--full { grid-column: 1 / -1; }
.sd__data-lbl { font-size: .68rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .05em; }
.sd__data-val { font-size: .85rem; color: #0f172a; font-weight: 500; }
.sd__link     { font-size: .85rem; color: #1d4ed8; text-decoration: none; font-weight: 600; }
.sd__link:hover { text-decoration: underline; }

/* Edit form */
.sd__form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: .875rem; }
@media (max-width: 480px) { .sd__form-grid { grid-template-columns: 1fr; } }
.sd__field     { display: flex; flex-direction: column; gap: .3rem; }
.sd__field--full { grid-column: 1 / -1; }
.sd__label     { font-size: .7rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.sd__req       { color: #ef4444; }
.sd__input     { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 7px; padding: .5rem .75rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; font-family: inherit; transition: border .15s; }
.sd__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.sd__textarea  { resize: vertical; min-height: 60px; }
.sd__input-row { display: flex; }
.sd__input-row .sd__input { border-radius: 7px 0 0 7px; }
.sd__input-suf { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-left: none; border-radius: 0 7px 7px 0; padding: .5rem .75rem; font-size: .82rem; font-weight: 600; color: #64748b; }
.sd__alert     { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; border-radius: 7px; padding: .55rem .75rem; font-size: .82rem; margin-bottom: 1rem; }
.sd__edit-ft   { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1rem; }

/* ── Actions ──────────────────────────────────────────────────────────────── */
.sd__actions { display: flex; flex-direction: column; gap: .5rem; }
.sd__action {
  display: flex; align-items: center; gap: .75rem;
  padding: .75rem .9rem; border-radius: 10px; border: 1.5px solid #e2e8f0;
  background: #fff; cursor: pointer; transition: all .15s; text-align: left; width: 100%;
}
.sd__action:hover:not(:disabled) { border-color: #a5d6a7; background: #f9fefb; }
.sd__action:disabled { opacity: .4; cursor: not-allowed; }
.sd__action--amber:hover:not(:disabled) { border-color: #fcd34d; background: #fffbeb; }
.sd__action--danger:hover:not(:disabled) { border-color: #fca5a5; background: #fef2f2; }
.sd__action-ico {
  width: 34px; height: 34px; border-radius: 8px; font-size: .95rem; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
}
.sd__action-ico--green { background: #f0fdf4; color: #15803d; }
.sd__action-ico--blue  { background: #eff6ff; color: #1d4ed8; }
.sd__action-ico--amber { background: #fffbeb; color: #d97706; }
.sd__action-ico--red   { background: #fef2f2; color: #dc2626; }
.sd__action-txt { flex: 1; min-width: 0; }
.sd__action-lbl { font-size: .82rem; font-weight: 700; color: #0f172a; }
.sd__action-sub { font-size: .7rem; color: #94a3b8; margin-top: 1px; }
.sd__actions-sep { height: 1px; background: #f1f5f9; margin: .25rem 0; }

/* QR button */
.sd__qr-btn {
  display: flex; align-items: center; gap: .75rem;
  margin-top: 1rem; padding: .65rem .9rem; border-radius: 8px;
  border: 1.5px dashed #cbd5e1; color: #475569; text-decoration: none;
  transition: all .15s;
}
.sd__qr-btn:hover { border-color: #1b5e20; color: #1b5e20; background: #f9fefb; }
.sd__qr-btn > i:first-child { font-size: 1.1rem; flex-shrink: 0; }
.sd__qr-lbl  { font-size: .78rem; font-weight: 700; }
.sd__qr-code { font-size: .65rem; font-family: monospace; color: #94a3b8; margin-top: 1px; word-break: break-all; }
.sd__qr-ext  { margin-left: auto; font-size: .7rem; opacity: .6; }

/* ── Movimientos timeline ──────────────────────────────────────────────────── */
.sd__movs { display: flex; flex-direction: column; }
.sd__mov  { display: flex; gap: .875rem; padding: .75rem 0; border-bottom: 1px solid #f8fafc; }
.sd__mov:last-child { border-bottom: none; padding-bottom: 0; }
.sd__mov-line { display: flex; flex-direction: column; align-items: center; flex-shrink: 0; padding-top: 4px; }
.sd__mov-dot  { width: 10px; height: 10px; border-radius: 50%; background: #e2e8f0; border: 2px solid #fff; box-shadow: 0 0 0 2px #e2e8f0; }
.sd__mov-dot--produccion   { background: #15803d; box-shadow: 0 0 0 2px #bbf7d0; }
.sd__mov-dot--transferencia { background: #1d4ed8; box-shadow: 0 0 0 2px #bfdbfe; }
.sd__mov-dot--dispensacion { background: #7e22ce; box-shadow: 0 0 0 2px #e9d5ff; }
.sd__mov-dot--ajuste       { background: #d97706; box-shadow: 0 0 0 2px #fde68a; }
.sd__mov-dot--merma        { background: #dc2626; box-shadow: 0 0 0 2px #fecaca; }
.sd__mov-body { flex: 1; min-width: 0; }
.sd__mov-row  { display: flex; align-items: center; justify-content: space-between; gap: .5rem; margin-bottom: .2rem; }
.sd__mov-tipo {
  display: inline-flex; align-items: center; padding: .18em .55em;
  border-radius: 4px; font-size: .65rem; font-weight: 700;
  background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0;
}
.sd__mov-tipo--produccion   { background: #f0fdf4; color: #15803d; border-color: #bbf7d0; }
.sd__mov-tipo--transferencia { background: #eff6ff; color: #1d4ed8; border-color: #bfdbfe; }
.sd__mov-tipo--dispensacion { background: #fdf4ff; color: #7e22ce; border-color: #e9d5ff; }
.sd__mov-tipo--ajuste       { background: #fefce8; color: #854d0e; border-color: #fef08a; }
.sd__mov-tipo--merma        { background: #fef2f2; color: #dc2626; border-color: #fecaca; }
.sd__mov-g     { font-size: .88rem; font-weight: 800; }
.sd__mov-g--pos { color: #15803d; }
.sd__mov-g--neg { color: #dc2626; }
.sd__mov-notas { font-size: .78rem; color: #374151; word-break: break-word; margin-bottom: .2rem; }
.sd__mov-meta  { display: flex; gap: .5rem; font-size: .68rem; color: #94a3b8; flex-wrap: wrap; }

/* ── Buttons ──────────────────────────────────────────────────────────────── */
.sd__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none; border-radius: 8px;
  padding: .55rem 1.1rem; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: background .15s;
}
.sd__btn-primary:hover:not(:disabled) { background: #144a18; }
.sd__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.sd__btn-ghost {
  display: inline-flex; align-items: center; gap: .4rem;
  background: transparent; color: #475569; border: 1.5px solid #e2e8f0;
  padding: .5rem 1rem; border-radius: 8px; font-size: .82rem; font-weight: 500;
  cursor: pointer; transition: all .15s; text-decoration: none;
}
.sd__btn-ghost:hover { background: #f8fafc; }
.sd__btn-sm { padding: .35rem .75rem; font-size: .75rem; }
.sd__btn-danger {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #dc2626; color: #fff; border: none; border-radius: 8px;
  padding: .55rem 1.1rem; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: background .15s;
}
.sd__btn-danger:hover:not(:disabled) { background: #b91c1c; }
.sd__btn-danger:disabled { opacity: .5; cursor: not-allowed; }
.sd__btn-amber {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #d97706; color: #fff; border: none; border-radius: 8px;
  padding: .55rem 1.1rem; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: background .15s;
}
.sd__btn-amber:hover:not(:disabled) { background: #b45309; }
.sd__btn-amber:disabled { opacity: .5; cursor: not-allowed; }

/* ── Modal ────────────────────────────────────────────────────────────────── */
.sd__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45); backdrop-filter: blur(3px);
  display: flex; align-items: flex-end; justify-content: center;
  z-index: 200; padding: 1rem;
}
@media (min-width: 640px) { .sd__overlay { align-items: center; } }
.sd__modal {
  background: #fff; border-radius: 16px;
  width: 100%; max-width: 520px; max-height: 92vh;
  display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.2);
}
.sd__modal-hd {
  display: flex; align-items: flex-start; gap: .75rem;
  padding: 1.25rem 1.25rem 1rem; border-bottom: 1px solid #f1f5f9;
}
.sd__modal-ico {
  width: 36px; height: 36px; background: #f0fdf4; color: #1b5e20;
  border-radius: 8px; display: flex; align-items: center; justify-content: center;
  font-size: 1rem; flex-shrink: 0;
}
.sd__modal-ico--amber  { background: #fffbeb; color: #d97706; }
.sd__modal-ico--danger { background: #fef2f2; color: #dc2626; }
.sd__modal-title { font-size: .95rem; font-weight: 800; color: #0f172a; margin: 0 0 2px; }
.sd__modal-sub   { font-size: .75rem; color: #64748b; margin: 0; }
.sd__modal-close {
  margin-left: auto; background: #f8fafc; border: none; width: 28px; height: 28px;
  border-radius: 6px; cursor: pointer; display: flex; align-items: center;
  justify-content: center; color: #64748b; flex-shrink: 0;
}
.sd__modal-close:hover { background: #e2e8f0; }
.sd__modal-body { padding: 1.25rem; overflow-y: auto; flex: 1; }
.sd__modal-ft   { display: flex; justify-content: flex-end; gap: .5rem; padding: 1rem 1.25rem; border-top: 1px solid #f1f5f9; }

/* Descarte warn */
.sd__descarte-warn {
  display: flex; align-items: flex-start; gap: .5rem;
  background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px;
  padding: .75rem .9rem; margin-bottom: 1rem; font-size: .82rem; color: #7f1d1d;
}
.sd__descarte-warn i { color: #dc2626; flex-shrink: 0; margin-top: .1rem; }

/* Ajuste preview */
.sd__ajuste-preview {
  display: flex; align-items: center; justify-content: space-between;
  border-radius: 8px; padding: .6rem .9rem; margin-top: 1rem;
  font-size: .82rem; font-weight: 500; border: 1px solid #e2e8f0; background: #f8fafc;
}
.sd__ajuste-preview--pos { background: #f0fdf4; border-color: #bbf7d0; color: #166534; }
.sd__ajuste-preview--neg { background: #fffbeb; border-color: #fde68a; color: #92400e; }
.sd__ajuste-delta { font-weight: 800; }

/* Merma */
.sd__merma {
  display: flex; align-items: center; gap: .5rem;
  background: #fffbeb; border: 1px solid #fde68a; border-radius: 8px;
  padding: .6rem .9rem; margin-top: 1rem; font-size: .82rem; color: #92400e;
}

/* Loading / empty */
.sd__loading    { display: flex; align-items: center; justify-content: center; padding: 4rem; }
.sd__loading-sm { display: flex; align-items: center; justify-content: center; padding: 1.5rem; }
.sd__empty-sm   { font-size: .82rem; color: #94a3b8; padding: .5rem 0; }
.sd__not-found  { display: flex; flex-direction: column; align-items: center; gap: .75rem; padding: 5rem 1rem; text-align: center; }
.sd__not-found span { font-size: 2.5rem; }
.sd__not-found p    { font-size: 1rem; font-weight: 700; color: #374151; margin: 0; }

/* Transitions */
.sd-fade-enter-active, .sd-fade-leave-active { transition: opacity .2s; }
.sd-fade-enter-from,  .sd-fade-leave-to      { opacity: 0; }
</style>
