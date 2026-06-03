<template>
  <div class="stk">

    <!-- ── Header ─────────────────────────────────────────────── -->
    <div class="stk__header">
      <div>
        <h1 class="stk__title">Stock</h1>
        <p class="stk__sub">Inventario del club · asignación de sedes · stock externo</p>
      </div>
      <button class="stk__btn-primary" @click="openCrear">
        <i class="bi bi-plus-lg"></i> Agregar stock externo
      </button>
    </div>

    <div v-if="loading" class="stk__loading">
      <DsSpinner />
    </div>

    <template v-else>

      <!-- ── KPIs ───────────────────────────────────────────────── -->
      <div class="stk__kpis">
        <div class="stk__kpi">
          <div class="stk__kpi-ico">📦</div>
          <div class="stk__kpi-body">
            <div class="stk__kpi-val">{{ totalG }}<span class="stk__kpi-unit">g</span></div>
            <div class="stk__kpi-lbl">Total disponible</div>
          </div>
        </div>
        <div class="stk__kpi" :class="{ 'stk__kpi--warn': pendientes.length > 0 }">
          <div class="stk__kpi-ico">⏳</div>
          <div class="stk__kpi-body">
            <div class="stk__kpi-val">{{ pendientes.length }}</div>
            <div class="stk__kpi-lbl">Por asignar</div>
          </div>
        </div>
        <div class="stk__kpi">
          <div class="stk__kpi-ico">🏪</div>
          <div class="stk__kpi-body">
            <div class="stk__kpi-val">{{ sedesConStock.length }}</div>
            <div class="stk__kpi-lbl">Sedes con stock</div>
          </div>
        </div>
        <div class="stk__kpi">
          <div class="stk__kpi-ico">🌿</div>
          <div class="stk__kpi-body">
            <div class="stk__kpi-val">{{ stockPropio }}<span class="stk__kpi-unit">g</span></div>
            <div class="stk__kpi-lbl">Producción propia</div>
          </div>
        </div>
      </div>

      <!-- ── Tabs ───────────────────────────────────────────────── -->
      <div class="stk__tabs">
        <button
          v-for="tab in TABS" :key="tab.key"
          class="stk__tab" :class="{ 'stk__tab--active': tabActiva === tab.key }"
          @click="tabActiva = tab.key"
        >
          {{ tab.label }}
          <span
            v-if="tab.count != null"
            class="stk__tab-badge"
            :class="{ 'stk__tab-badge--warn': tab.key === 'por_asignar' && pendientes.length > 0 }"
          >{{ tab.count }}</span>
        </button>
      </div>

      <!-- ── Tab: Por asignar ───────────────────────────────────── -->
      <div v-if="tabActiva === 'por_asignar'">
        <div v-if="!pendientes.length" class="stk__empty">
          <span class="stk__empty-ico">✅</span>
          <p class="stk__empty-title">Todo asignado</p>
          <span class="stk__empty-sub">No hay stock pendiente de asignación a sede.</span>
        </div>
        <div v-else class="stk__pa-list">
          <div v-for="s in pendientes" :key="s.id" class="stk__pa-card">
            <div class="stk__pa-left">
              <div class="stk__pa-forma">{{ formaLabel(s.forma_producto) }}</div>
              <div class="stk__pa-chips">
                <span class="stk__chip stk__chip--g">{{ s.cantidad }}g</span>
                <span v-if="s.lote" class="stk__chip stk__chip--lote">{{ s.lote.codigo }}</span>
                <span v-if="s.lote?.genetica" class="stk__chip stk__chip--gen">{{ s.lote.genetica.nombre }}</span>
                <span v-if="s.origen === 'compra_externa'" class="stk__chip stk__chip--ext">Externo</span>
                <span class="stk__chip stk__chip--muted">{{ timeAgo(s.created_at) }}</span>
              </div>
            </div>
            <div class="stk__pa-right">
              <div class="stk__pa-qty">
                <input
                  type="number" class="stk__select stk__qty-input"
                  :max="s.cantidad" min="0.1" step="0.1"
                  v-model="cantidades[s.id]"
                  :placeholder="`${s.cantidad}g (todo)`"
                />
                <span class="stk__qty-hint">de {{ s.cantidad }}g</span>
              </div>
              <select v-model="asignaciones[s.id]" class="stk__select">
                <option value="">— Elegir sede —</option>
                <option v-for="sede in sedes" :key="sede.id" :value="sede.id">{{ sede.nombre }}</option>
              </select>
              <button class="stk__btn-primary stk__btn-sm" :disabled="asignando === s.id || !asignaciones[s.id]" @click="asignar(s)">
                <DsSpinner v-if="asignando === s.id" :size="12" />
                <i v-else class="bi bi-check-lg"></i>
                Asignar
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- ── Tab: Inventario ────────────────────────────────────── -->
      <div v-if="tabActiva === 'inventario'">
        <div v-if="!inventario.length" class="stk__empty">
          <span class="stk__empty-ico">📭</span>
          <p class="stk__empty-title">Sin stock asignado</p>
          <span class="stk__empty-sub">Asigná stock desde "Por asignar" o agregá stock externo.</span>
          <button class="stk__btn-outline stk__empty-cta" @click="openCrear">
            <i class="bi bi-plus-lg"></i> Agregar stock externo
          </button>
        </div>
        <template v-else>
          <div class="stk__filters">
            <button
              v-for="f in filtrosForma" :key="f.value"
              class="stk__chip-btn" :class="{ 'stk__chip-btn--active': filtroForma === f.value }"
              @click="filtroForma = f.value"
            >{{ f.label }}</button>
          </div>
          <div v-for="grupo in inventarioAgrupado" :key="grupo.sede_nombre" class="stk__grupo">
            <div class="stk__grupo-hd">
              <span class="stk__grupo-nombre">🏪 {{ grupo.sede_nombre }}</span>
              <span class="stk__grupo-total">{{ grupo.total }}g</span>
            </div>
            <div class="stk__inv-list">
              <div v-for="s in grupo.items" :key="s.id" class="stk__inv-row">
                <div class="stk__inv-main">
                  <span class="stk__inv-forma">{{ formaLabel(s.forma_producto) }}</span>
                  <div class="stk__inv-chips">
                    <span v-if="s.lote" class="stk__chip stk__chip--lote">{{ s.lote.codigo }}</span>
                    <span v-if="s.lote?.genetica" class="stk__chip stk__chip--gen">{{ s.lote.genetica.nombre }}</span>
                    <span v-else-if="s.genetica" class="stk__chip stk__chip--gen">{{ s.genetica.nombre }}</span>
                    <span v-if="s.origen === 'compra_externa'" class="stk__chip stk__chip--ext">Externo</span>
                    <span v-if="s.proveedor" class="stk__chip">{{ s.proveedor }}</span>
                  </div>
                </div>
                <div class="stk__inv-right">
                  <span class="stk__inv-g">{{ s.cantidad }}g</span>
                  <button class="stk__icon-btn" title="Editar stock" @click="abrirEditar(s)">
                    <i class="bi bi-pencil"></i>
                  </button>
                  <button class="stk__icon-btn" title="Repartir a sede" @click="openRepartir(s)">
                    <i class="bi bi-arrows-angle-expand"></i>
                  </button>
                  <button
                    v-if="s.forma_producto === 'flor_seca' && s.lote_id"
                    class="stk__icon-btn stk__icon-btn--amber"
                    title="Procesar derivado"
                    @click="openProcesar(s)"
                  >
                    <i class="bi bi-arrow-right-square"></i>
                  </button>
                  <RouterLink v-if="s.codigo_qr" :to="`/s/${s.codigo_qr}`" class="stk__icon-btn" title="Ver QR">
                    <i class="bi bi-qr-code"></i>
                  </RouterLink>
                </div>
              </div>
            </div>
          </div>
        </template>
      </div>

      <!-- ── Tab: Historial ─────────────────────────────────────── -->
      <div v-if="tabActiva === 'historial'">
        <div v-if="loadingHistorial" class="stk__loading">
          <DsSpinner />
        </div>
        <template v-else>
          <div class="stk__filters">
            <button
              v-for="f in FILTROS_ESTADO" :key="f.value"
              class="stk__chip-btn" :class="{ 'stk__chip-btn--active': filtroEstado === f.value }"
              @click="filtroEstado = f.value"
            >{{ f.label }}</button>
          </div>
          <div v-if="!historialFiltrado.length" class="stk__empty">
            <span class="stk__empty-ico">🗂️</span>
            <p class="stk__empty-title">Sin registros</p>
          </div>
          <div v-else class="stk__hist">
            <div class="stk__hist-hd">
              <span class="stk__hist-col stk__hist-col--estado">Estado</span>
              <span class="stk__hist-col stk__hist-col--producto">Producto</span>
              <span class="stk__hist-col stk__hist-col--sede">Sede</span>
              <span class="stk__hist-col stk__hist-col--cant">Cant.</span>
              <span class="stk__hist-col stk__hist-col--fecha">Fecha</span>
            </div>
            <div v-for="s in historialFiltrado" :key="s.id" class="stk__hist-row">
              <div class="stk__hist-col stk__hist-col--estado">
                <span class="stk__badge" :class="`stk__badge--${s.estado}`">{{ estadoLabel(s.estado) }}</span>
              </div>
              <div class="stk__hist-col stk__hist-col--producto">
                <span class="stk__hist-forma">{{ formaLabel(s.forma_producto) }}</span>
                <div class="stk__hist-chips">
                  <span v-if="s.lote" class="stk__chip stk__chip--lote stk__chip--xs">{{ s.lote.codigo }}</span>
                  <span v-if="s.lote?.genetica || s.genetica" class="stk__chip stk__chip--gen stk__chip--xs">
                    {{ s.lote?.genetica?.nombre || s.genetica?.nombre }}
                  </span>
                  <span v-if="s.origen === 'compra_externa'" class="stk__chip stk__chip--ext stk__chip--xs">Ext.</span>
                </div>
              </div>
              <div class="stk__hist-col stk__hist-col--sede">
                <span v-if="s.sede" class="stk__hist-sede-nm">{{ s.sede.nombre }}</span>
                <span v-else class="stk__hist-pool">Pool</span>
              </div>
              <div class="stk__hist-col stk__hist-col--cant">
                <span class="stk__hist-g">{{ s.cantidad }}g</span>
              </div>
              <div class="stk__hist-col stk__hist-col--fecha">
                <span class="stk__hist-fecha">{{ formatDate(s.created_at) }}</span>
              </div>
            </div>
          </div>
        </template>
      </div>

    </template>

    <!-- ── Modal: Agregar stock externo ──────────────────────────── -->
    <Teleport to="body">
      <Transition name="stk-fade">
        <div v-if="showCrear" class="stk__overlay" @click.self="closeCrear">
          <div class="stk__modal">
            <div class="stk__modal-hd">
              <div class="stk__modal-ico"><i class="bi bi-box-seam"></i></div>
              <div>
                <h2 class="stk__modal-title">Nuevo stock externo</h2>
                <p class="stk__modal-sub">Stock adquirido fuera del ciclo de cultivo propio</p>
              </div>
              <button class="stk__modal-close" @click="closeCrear"><i class="bi bi-x-lg"></i></button>
            </div>

            <form class="stk__modal-body" @submit.prevent="guardarStock">
              <div v-if="crearError" class="stk__alert">{{ crearError }}</div>
              <div class="stk__form-grid">
                <div class="stk__field stk__field--full">
                  <label class="stk__label">Forma del producto <span class="stk__req">*</span></label>
                  <select class="stk__input" v-model="crearForm.forma_producto" required>
                    <option v-for="f in FORMAS" :key="f.value" :value="f.value">{{ f.label }}</option>
                  </select>
                </div>
                <div class="stk__field">
                  <label class="stk__label">Cantidad (g) <span class="stk__req">*</span></label>
                  <div class="stk__input-row">
                    <input type="number" min="0.1" step="0.1" class="stk__input" v-model="crearForm.cantidad" placeholder="0.0" required />
                    <span class="stk__input-suf">g</span>
                  </div>
                </div>
                <div class="stk__field">
                  <label class="stk__label">Sede destino <span class="stk__req">*</span></label>
                  <select class="stk__input" v-model="crearForm.sede_id" required>
                    <option value="">— Elegir sede —</option>
                    <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                  </select>
                </div>
                <div class="stk__field">
                  <label class="stk__label">Variedad / Cepa <span class="stk__opt">opcional</span></label>
                  <input type="text" class="stk__input" v-model="crearForm.genetica_libre" placeholder="Ej: OG Kush, Amnesia, …" />
                </div>
                <div class="stk__field">
                  <label class="stk__label">Precio sugerido (ARS/g) <span class="stk__opt">opcional</span></label>
                  <input type="number" min="0" step="0.01" class="stk__input" v-model="crearForm.precio_sugerido_ars" placeholder="0.00" />
                </div>
                <div class="stk__field">
                  <label class="stk__label">Costo unitario (ARS/g) <span class="stk__opt">opcional</span></label>
                  <input type="number" min="0" step="0.01" class="stk__input" v-model="crearForm.costo_unitario_ars" placeholder="0.00" />
                </div>
                <div class="stk__field stk__field--full">
                  <label class="stk__label">Proveedor <span class="stk__req">*</span></label>
                  <input type="text" class="stk__input" v-model="crearForm.proveedor" placeholder="Nombre del proveedor o productor" required />
                </div>
                <div class="stk__field stk__field--full">
                  <label class="stk__label">Notas <span class="stk__opt">opcional</span></label>
                  <textarea class="stk__input stk__textarea" rows="2" v-model="crearForm.descripcion" placeholder="Observaciones…"></textarea>
                </div>
              </div>
            </form>

            <div class="stk__modal-ft">
              <button type="button" class="stk__btn-ghost" @click="closeCrear">Cancelar</button>
              <button class="stk__btn-primary" :disabled="creando || !crearForm.cantidad" @click="guardarStock">
                <DsSpinner v-if="creando" :size="12" />
                <i v-else class="bi bi-plus-lg"></i>
                Crear stock
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

  </div>

    <!-- ── Modal: Editar stock ───────────────────────────────────────────── -->
    <Teleport to="body">
      <Transition name="stk-fade">
        <div v-if="showEditarModal" class="stk__overlay" @click.self="showEditarModal = false">
          <div class="stk__modal">
            <div class="stk__modal-hd">
              <div class="stk__modal-ico"><i class="bi bi-pencil"></i></div>
              <div>
                <h2 class="stk__modal-title">Editar stock</h2>
                <p class="stk__modal-sub">{{ formaLabel(editandoStock?.forma_producto) }} · {{ editandoStock?.sede?.nombre || '—' }}</p>
              </div>
              <button class="stk__modal-close" @click="showEditarModal = false"><i class="bi bi-x-lg"></i></button>
            </div>
            <div class="stk__modal-body">
              <div v-if="editarError" class="stk__alert">{{ editarError }}</div>
              <div class="stk__form-grid">
                <div class="stk__field">
                  <label class="stk__label">Cantidad (g) <span class="stk__req">*</span></label>
                  <div class="stk__input-row">
                    <input type="number" min="0" step="0.1" class="stk__input" v-model.number="editarForm.cantidad" />
                    <span class="stk__input-suf">g</span>
                  </div>
                </div>
                <div class="stk__field">
                  <label class="stk__label">Precio sugerido (ARS/g) <span class="stk__opt">opcional</span></label>
                  <input type="number" min="0" step="0.01" class="stk__input" v-model.number="editarForm.precio_sugerido_ars" placeholder="0.00" />
                </div>
                <div class="stk__field">
                  <label class="stk__label">Costo unitario (ARS/g) <span class="stk__opt">opcional</span></label>
                  <input type="number" min="0" step="0.01" class="stk__input" v-model.number="editarForm.costo_unitario_ars" placeholder="0.00" />
                </div>
                <div v-if="editandoStock?.origen === 'compra_externa'" class="stk__field">
                  <label class="stk__label">Proveedor</label>
                  <input type="text" class="stk__input" v-model.trim="editarForm.proveedor" placeholder="Nombre del proveedor" />
                </div>
                <div class="stk__field stk__field--full">
                  <label class="stk__label">Descripción <span class="stk__opt">opcional</span></label>
                  <input type="text" class="stk__input" v-model.trim="editarForm.descripcion" placeholder="Observaciones…" />
                </div>
              </div>
            </div>
            <div class="stk__modal-ft">
              <button type="button" class="stk__btn-ghost" @click="showEditarModal = false">Cancelar</button>
              <button class="stk__btn-primary" :disabled="savingEditar" @click="guardarEditar">
                <DsSpinner v-if="savingEditar" :size="12" />
                <i v-else class="bi bi-check-lg"></i>
                Guardar cambios
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- ── Modal: Repartir stock ───────────────────────────────────────── -->
    <Teleport to="body">
      <Transition name="stk-fade">
        <div v-if="showRepartir" class="stk__overlay" @click.self="closeRepartir">
          <div class="stk__modal">
            <div class="stk__modal-hd">
              <div class="stk__modal-ico"><i class="bi bi-arrows-angle-expand"></i></div>
              <div>
                <h2 class="stk__modal-title">Repartir stock</h2>
                <p class="stk__modal-sub">{{ formaLabel(repartirTarget?.forma_producto) }} · {{ repartirTarget?.cantidad }}g disponibles en {{ repartirTarget?.sede?.nombre || '—' }}</p>
              </div>
              <button class="stk__modal-close" @click="closeRepartir"><i class="bi bi-x-lg"></i></button>
            </div>
            <div class="stk__modal-body">
              <div v-if="repartirError" class="stk__alert">{{ repartirError }}</div>
              <div class="stk__form-grid">
                <div class="stk__field">
                  <label class="stk__label">Cantidad a enviar (g) <span class="stk__req">*</span></label>
                  <div class="stk__input-row">
                    <input type="number" min="0.1" :max="repartirTarget?.cantidad" step="0.1"
                      class="stk__input" v-model="repartirForm.cantidad"
                      :placeholder="`máx ${repartirTarget?.cantidad}g`" />
                    <span class="stk__input-suf">g</span>
                  </div>
                  <span v-if="repartirForm.cantidad && Number(repartirForm.cantidad) < repartirTarget?.cantidad" class="stk__field-hint">
                    Quedan {{ (repartirTarget.cantidad - Number(repartirForm.cantidad)).toFixed(1) }}g en sede actual
                  </span>
                </div>
                <div class="stk__field">
                  <label class="stk__label">Sede destino <span class="stk__req">*</span></label>
                  <select class="stk__input" v-model="repartirForm.sede_id">
                    <option value="">— Elegir sede —</option>
                    <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                  </select>
                </div>
              </div>
            </div>
            <div class="stk__modal-ft">
              <button type="button" class="stk__btn-ghost" @click="closeRepartir">Cancelar</button>
              <button class="stk__btn-primary" :disabled="repartiendo" @click="ejecutarRepartir">
                <DsSpinner v-if="repartiendo" :size="12" />
                <i v-else class="bi bi-arrows-angle-expand"></i>
                Repartir
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- ── Modal: Procesar derivado ────────────────────────────────────── -->
    <Teleport to="body">
      <Transition name="stk-fade">
        <div v-if="showProcesar" class="stk__overlay" @click.self="closeProcesar">
          <div class="stk__modal">
            <div class="stk__modal-hd">
              <div class="stk__modal-ico stk__modal-ico--amber"><i class="bi bi-arrow-right-square"></i></div>
              <div>
                <h2 class="stk__modal-title">Procesar derivado</h2>
                <p class="stk__modal-sub">Flor seca → derivado · {{ procesarTarget?.lote?.codigo || '' }}</p>
              </div>
              <button class="stk__modal-close" @click="closeProcesar"><i class="bi bi-x-lg"></i></button>
            </div>
            <div class="stk__modal-body">
              <div v-if="procesarError" class="stk__alert">{{ procesarError }}</div>
              <div class="stk__procesar-src">
                <span class="stk__procesar-src-lbl">Stock origen</span>
                <span class="stk__procesar-src-val">{{ procesarTarget?.cantidad }}g de flor seca disponibles</span>
              </div>
              <div class="stk__form-grid">
                <div class="stk__field">
                  <label class="stk__label">Gramos a consumir <span class="stk__req">*</span></label>
                  <div class="stk__input-row">
                    <input type="number" min="0.1" :max="procesarTarget?.cantidad" step="0.1"
                      class="stk__input" v-model="procesarForm.gramos_consumir"
                      :placeholder="`máx ${procesarTarget?.cantidad}g`" />
                    <span class="stk__input-suf">g</span>
                  </div>
                </div>
                <div class="stk__field">
                  <label class="stk__label">Forma del derivado <span class="stk__req">*</span></label>
                  <select class="stk__input" v-model="procesarForm.forma_producto">
                    <option v-for="f in FORMAS_DERIVADO" :key="f.value" :value="f.value">{{ f.label }}</option>
                  </select>
                </div>
                <div class="stk__field">
                  <label class="stk__label">Cantidad resultante <span class="stk__req">*</span></label>
                  <div class="stk__input-row">
                    <input type="number" min="0.01" step="0.01"
                      class="stk__input" v-model="procesarForm.cantidad_resultado"
                      placeholder="0.0" />
                    <span class="stk__input-suf">g</span>
                  </div>
                </div>
                <div class="stk__field">
                  <label class="stk__label">Sede destino <span class="stk__req">*</span></label>
                  <select class="stk__input" v-model="procesarForm.sede_id">
                    <option value="">— Elegir sede —</option>
                    <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                  </select>
                </div>
              </div>
              <div v-if="mermaG > 0" class="stk__merma">
                <span class="stk__merma-ico">⚠️</span>
                <span class="stk__merma-txt">Merma: <strong>{{ mermaG }}g ({{ mermaPct }}%)</strong></span>
              </div>
            </div>
            <div class="stk__modal-ft">
              <button type="button" class="stk__btn-ghost" @click="closeProcesar">Cancelar</button>
              <button class="stk__btn-amber" :disabled="procesando" @click="ejecutarProcesar">
                <DsSpinner v-if="procesando" :size="12" />
                <i v-else class="bi bi-arrow-right-square"></i>
                Procesar
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import {
  listStocksPendientes, listStocks, listStocksHistorial,
  asignarStock, listSedes, createStock, updateStock,
} from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()

// ── State ──────────────────────────────────────────────────────────────────────
const loading          = ref(true)
const pendientes       = ref([])
const inventario       = ref([])
const historial        = ref([])
const historialLoaded  = ref(false)
const loadingHistorial = ref(false)
const sedes            = ref([])

// ── Repartir ───────────────────────────────────────────────────────────────────
const showRepartir   = ref(false)
const repartirTarget = ref(null)
const repartirForm   = ref({ sede_id: '', cantidad: '' })
const repartirError  = ref(null)
const repartiendo    = ref(false)

// ── Procesar ───────────────────────────────────────────────────────────────────
const showProcesar   = ref(false)
const procesarTarget = ref(null)
const procesarForm   = ref({ gramos_consumir: '', forma_producto: 'aceite', cantidad_resultado: '', sede_id: '' })
const procesarError  = ref(null)
const procesando     = ref(false)

// ── Tabs ───────────────────────────────────────────────────────────────────────
const tabActiva = ref('por_asignar')
const TABS = computed(() => [
  { key: 'por_asignar', label: '⏳ Por asignar', count: pendientes.value.length },
  { key: 'inventario',  label: '📦 Inventario',  count: inventario.value.length },
  { key: 'historial',   label: '📋 Historial',   count: null },
])

watch(tabActiva, async (val) => {
  if (val === 'historial' && !historialLoaded.value) {
    loadingHistorial.value = true
    try {
      const { data } = await listStocksHistorial()
      historial.value = data || []
      historialLoaded.value = true
    } catch { toast.error('Error al cargar historial') }
    finally { loadingHistorial.value = false }
  }
})

// ── KPIs ───────────────────────────────────────────────────────────────────────
const totalG = computed(() =>
  parseFloat(inventario.value.reduce((s, x) => s + x.cantidad, 0).toFixed(1))
)
const stockPropio = computed(() =>
  parseFloat(inventario.value
    .filter(x => x.origen !== 'compra_externa')
    .reduce((s, x) => s + x.cantidad, 0).toFixed(1))
)
const sedesConStock = computed(() =>
  [...new Set(inventario.value.map(x => x.sede_id).filter(Boolean))]
)

// ── Inventario ─────────────────────────────────────────────────────────────────
const filtroForma = ref('todos')
const filtrosForma = computed(() => {
  const formas = [...new Set(inventario.value.map(x => x.forma_producto))]
  return [
    { value: 'todos', label: 'Todos' },
    ...formas.map(f => ({ value: f, label: formaLabel(f) })),
  ]
})
const inventarioFiltrado = computed(() =>
  filtroForma.value === 'todos'
    ? inventario.value
    : inventario.value.filter(x => x.forma_producto === filtroForma.value)
)
const inventarioAgrupado = computed(() => {
  const grupos = {}
  for (const s of inventarioFiltrado.value) {
    const key = s.sede?.nombre || 'Sin sede'
    if (!grupos[key]) grupos[key] = { sede_nombre: key, items: [], total: 0 }
    grupos[key].items.push(s)
    grupos[key].total = parseFloat((grupos[key].total + s.cantidad).toFixed(1))
  }
  return Object.values(grupos).sort((a, b) => b.total - a.total)
})

// ── Historial ──────────────────────────────────────────────────────────────────
const filtroEstado = ref('todos')
const FILTROS_ESTADO = [
  { value: 'todos',                label: 'Todos' },
  { value: 'asignado',             label: 'Asignados' },
  { value: 'pendiente_asignacion', label: 'Por asignar' },
  { value: 'agotado',              label: 'Agotados' },
]
const historialFiltrado = computed(() =>
  filtroEstado.value === 'todos'
    ? historial.value
    : historial.value.filter(s => s.estado === filtroEstado.value)
)

// ── Load ───────────────────────────────────────────────────────────────────────
onMounted(async () => {
  try {
    const [rPend, rInv, rSedes, rGen] = await Promise.all([
      listStocksPendientes(), listStocks(), listSedes(),
    ])
    pendientes.value = rPend.data || []
    inventario.value = rInv.data  || []
    sedes.value      = rSedes.data || []
    pendientes.value.forEach(s => { asignaciones.value[s.id] = ''; cantidades.value[s.id] = '' })
    if (!pendientes.value.length) tabActiva.value = 'inventario'
  } catch { toast.error('Error al cargar stocks') }
  finally { loading.value = false }
})

// ── Asignar ────────────────────────────────────────────────────────────────────
const asignando    = ref(null)
const asignaciones = ref({})
const cantidades   = ref({})

async function asignar(stock) {
  const sedeId = asignaciones.value[stock.id]
  if (!sedeId) { toast.error('Elegí una sede'); return }
  asignando.value = stock.id
  try {
    const payload = { sede_id: sedeId }
    const cant = Number(cantidades.value[stock.id])
    if (cant > 0 && cant < stock.cantidad) payload.cantidad = cant
    await asignarStock(stock.id, payload)
    pendientes.value = pendientes.value.filter(s => s.id !== stock.id)
    const { data } = await listStocks()
    inventario.value = data || []
    if (historialLoaded.value) {
      const { data: h } = await listStocksHistorial()
      historial.value = h || []
    }
    toast.success('Stock asignado')
    if (!pendientes.value.length) tabActiva.value = 'inventario'
  } catch (e) {
    toast.error(e.response?.data?.error || 'Error al asignar')
  } finally { asignando.value = null }
}

// ── Editar stock ───────────────────────────────────────────────────────────────
const showEditarModal = ref(false)
const editandoStock   = ref(null)
const editarForm      = ref({ cantidad: null, precio_sugerido_ars: null, costo_unitario_ars: null, descripcion: '', proveedor: '' })
const savingEditar    = ref(false)
const editarError     = ref(null)

function abrirEditar(s) {
  editandoStock.value = s
  editarForm.value = {
    cantidad:            parseFloat(s.cantidad),
    precio_sugerido_ars: s.precio_sugerido_ars ? parseFloat(s.precio_sugerido_ars) : null,
    costo_unitario_ars:  s.costo_unitario_ars  ? parseFloat(s.costo_unitario_ars)  : null,
    descripcion:         s.descripcion || '',
    proveedor:           s.proveedor   || '',
  }
  editarError.value = null
  showEditarModal.value = true
}

async function guardarEditar() {
  savingEditar.value = true
  editarError.value  = null
  try {
    const f = editarForm.value
    const payload = { cantidad: f.cantidad }
    if (f.precio_sugerido_ars != null) payload.precio_sugerido_ars = f.precio_sugerido_ars
    if (f.costo_unitario_ars  != null) payload.costo_unitario_ars  = f.costo_unitario_ars
    if (f.descripcion)                 payload.descripcion         = f.descripcion
    if (f.proveedor)                   payload.proveedor           = f.proveedor
    await updateStock(editandoStock.value.id, payload)
    showEditarModal.value = false
    const { data } = await listStocks()
    inventario.value = data || []
    if (historialLoaded.value) {
      const { data: h } = await listStocksHistorial()
      historial.value = h || []
    }
    toast.success('Stock actualizado')
  } catch (e) {
    editarError.value = e?.response?.data?.errors?.[0] || e?.response?.data?.error || 'Error al actualizar'
  } finally { savingEditar.value = false }
}

// ── Crear stock externo ────────────────────────────────────────────────────────
const showCrear  = ref(false)
const creando    = ref(false)
const crearError = ref(null)

const emptyForm = () => ({
  forma_producto: 'flor_seca', cantidad: '', sede_id: '',
  genetica_libre: '', precio_sugerido_ars: '', costo_unitario_ars: '',
  proveedor: '', descripcion: '',
})
const crearForm = ref(emptyForm())

function openCrear()  { crearForm.value = emptyForm(); crearError.value = null; showCrear.value = true }
function closeCrear() { showCrear.value = false }

async function guardarStock() {
  crearError.value = null
  if (!crearForm.value.cantidad || Number(crearForm.value.cantidad) <= 0) {
    crearError.value = 'La cantidad debe ser mayor a 0'; return
  }
  if (!crearForm.value.proveedor?.trim()) {
    crearError.value = 'El proveedor es obligatorio'; return
  }
  if (!crearForm.value.sede_id) {
    crearError.value = 'La sede es obligatoria'; return
  }
  creando.value = true
  try {
    const p = {
      origen: 'compra_externa',
      forma_producto: crearForm.value.forma_producto,
      cantidad:  Number(crearForm.value.cantidad),
      unidad:    'g',
      estado:    'asignado',
      proveedor: crearForm.value.proveedor,
      sede_id:   Number(crearForm.value.sede_id),
    }
    if (crearForm.value.precio_sugerido_ars) p.precio_sugerido_ars = Number(crearForm.value.precio_sugerido_ars)
    if (crearForm.value.costo_unitario_ars)  p.costo_unitario_ars  = Number(crearForm.value.costo_unitario_ars)
    const notaVariedad   = crearForm.value.genetica_libre?.trim() ? `Variedad: ${crearForm.value.genetica_libre.trim()}.` : ''
    const notaAdicional  = crearForm.value.descripcion?.trim() || ''
    const descripcionFinal = [notaVariedad, notaAdicional].filter(Boolean).join(' ')
    if (descripcionFinal) p.descripcion = descripcionFinal

    await createStock(p)
    toast.success('Stock externo creado')
    closeCrear()
    const [rPend, rInv] = await Promise.all([listStocksPendientes(), listStocks()])
    pendientes.value = rPend.data || []
    inventario.value = rInv.data  || []
    if (historialLoaded.value) {
      const { data: h } = await listStocksHistorial()
      historial.value = h || []
    }
    tabActiva.value = 'inventario'
  } catch (e) {
    crearError.value = e?.response?.data?.errors?.[0] || e?.response?.data?.error || 'Error al crear el stock'
  } finally { creando.value = false }
}

// ── Repartir functions ────────────────────────────────────────────────────────
function openRepartir(stock) {
  repartirTarget.value = stock
  repartirForm.value   = { sede_id: '', cantidad: '' }
  repartirError.value  = null
  showRepartir.value   = true
}
function closeRepartir() { showRepartir.value = false }

async function ejecutarRepartir() {
  const s = repartirTarget.value
  if (!repartirForm.value.sede_id) { repartirError.value = 'Elegí una sede'; return }
  const cant = Number(repartirForm.value.cantidad)
  if (!cant || cant <= 0) { repartirError.value = 'La cantidad es obligatoria'; return }
  if (cant > s.cantidad) { repartirError.value = `Máximo disponible: ${s.cantidad}g`; return }
  repartiendo.value = true
  repartirError.value = null
  try {
    await asignarStock(s.id, { sede_id: repartirForm.value.sede_id, cantidad: cant })
    toast.success('Stock repartido')
    closeRepartir()
    const [rPend, rInv] = await Promise.all([listStocksPendientes(), listStocks()])
    pendientes.value = rPend.data || []
    inventario.value = rInv.data || []
    if (historialLoaded.value) {
      const { data: h } = await listStocksHistorial()
      historial.value = h || []
    }
  } catch (e) {
    repartirError.value = e?.response?.data?.error || e?.response?.data?.errors?.[0] || 'Error al repartir'
  } finally { repartiendo.value = false }
}

// ── Procesar functions ────────────────────────────────────────────────────────
const FORMAS_DERIVADO = [
  { value: 'hash',       label: 'Hash' },
  { value: 'aceite',     label: 'Aceite' },
  { value: 'tintura',    label: 'Tintura' },
  { value: 'crema',      label: 'Crema' },
  { value: 'capsula',    label: 'Cápsula' },
  { value: 'comestible', label: 'Comestible' },
  { value: 'prensado',   label: 'Prensado' },
  { value: 'otro',       label: 'Otro' },
]

const mermaG = computed(() => {
  if (!showProcesar.value) return 0
  const consumir   = Number(procesarForm.value.gramos_consumir)
  const resultado  = Number(procesarForm.value.cantidad_resultado)
  if (!consumir || !resultado || resultado >= consumir) return 0
  return parseFloat((consumir - resultado).toFixed(2))
})
const mermaPct = computed(() => {
  const consumir  = Number(procesarForm.value.gramos_consumir)
  const resultado = Number(procesarForm.value.cantidad_resultado)
  if (!consumir || !resultado || resultado >= consumir) return 0
  return parseFloat(((consumir - resultado) / consumir * 100).toFixed(1))
})

function openProcesar(stock) {
  procesarTarget.value = stock
  procesarForm.value   = { gramos_consumir: '', forma_producto: 'aceite', cantidad_resultado: '', sede_id: '' }
  procesarError.value  = null
  showProcesar.value   = true
}
function closeProcesar() { showProcesar.value = false }

async function ejecutarProcesar() {
  procesarError.value = null
  const s        = procesarTarget.value
  const consumir = Number(procesarForm.value.gramos_consumir)
  const resultado = Number(procesarForm.value.cantidad_resultado)
  if (!consumir || consumir <= 0) { procesarError.value = 'Ingresá los gramos a consumir'; return }
  if (consumir > s.cantidad)      { procesarError.value = `Máximo disponible: ${s.cantidad}g`; return }
  if (!resultado || resultado <= 0) { procesarError.value = 'Ingresá la cantidad resultante'; return }
  if (!procesarForm.value.forma_producto) { procesarError.value = 'Elegí la forma del derivado'; return }
  if (!procesarForm.value.sede_id) { procesarError.value = 'Elegí una sede'; return }
  procesando.value = true
  try {
    await createStock({
      origen:                  'derivado_lote',
      lote_id:                 s.lote_id,
      lote_origen_consumido_g: consumir,
      forma_producto:          procesarForm.value.forma_producto,
      cantidad:                resultado,
      unidad:                  'g',
      estado:                  'asignado',
      sede_id:                 Number(procesarForm.value.sede_id),
    })
    toast.success('Derivado procesado')
    closeProcesar()
    const [rPend, rInv] = await Promise.all([listStocksPendientes(), listStocks()])
    pendientes.value = rPend.data || []
    inventario.value = rInv.data || []
    if (historialLoaded.value) {
      const { data: h } = await listStocksHistorial()
      historial.value = h || []
    }
  } catch (e) {
    procesarError.value = e?.response?.data?.errors?.[0] || e?.response?.data?.error || 'Error al procesar'
  } finally { procesando.value = false }
}

// ── Helpers ────────────────────────────────────────────────────────────────────
const FORMAS = [
  { value: 'flor_seca',  label: 'Flor seca' },
  { value: 'hash',       label: 'Hash' },
  { value: 'aceite',     label: 'Aceite' },
  { value: 'tintura',    label: 'Tintura' },
  { value: 'crema',      label: 'Crema' },
  { value: 'capsula',    label: 'Cápsula' },
  { value: 'comestible', label: 'Comestible' },
  { value: 'prensado',   label: 'Prensado' },
  { value: 'otro',       label: 'Otro' },
]
const FORMA_MAP = Object.fromEntries(FORMAS.map(f => [f.value, f.label]))
function formaLabel(f) { return FORMA_MAP[f] || f || 'Stock' }

function estadoLabel(e) {
  return { pendiente_asignacion: 'Por asignar', asignado: 'Asignado', agotado: 'Agotado' }[e] || e
}
function timeAgo(dateStr) {
  const d = Math.floor((Date.now() - new Date(dateStr)) / 86400000)
  if (d === 0) return 'hoy'
  if (d === 1) return 'ayer'
  return `hace ${d} días`
}
function formatDate(dateStr) {
  return new Date(dateStr).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: '2-digit' })
}
</script>

<style scoped>
.stk { padding: 1.5rem 1.75rem 3rem; }
@media (max-width: 640px) { .stk { padding: 1rem 1rem 2rem; } }

/* ── Header ─────────────────────────────────────────────────────────────────── */
.stk__header {
  display: flex; align-items: center; justify-content: space-between;
  gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap;
}
.stk__title { font-size: 1.6rem; font-weight: 800; color: #0f172a; letter-spacing: -.04em; margin: 0 0 .2rem; }
.stk__sub   { font-size: .82rem; color: #64748b; margin: 0; }

/* ── Buttons ────────────────────────────────────────────────────────────────── */
.stk__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none; border-radius: 8px;
  padding: .55rem 1.1rem; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: background .15s; white-space: nowrap;
}
.stk__btn-primary:hover:not(:disabled) { background: #144a18; }
.stk__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.stk__btn-sm    { padding: .42rem .85rem; font-size: .78rem; }
.stk__btn-ghost {
  display: inline-flex; align-items: center; gap: .4rem;
  background: transparent; color: #475569; border: 1.5px solid #e2e8f0;
  padding: .5rem 1rem; border-radius: 8px; font-size: .82rem; font-weight: 500;
  cursor: pointer; transition: all .15s;
}
.stk__btn-ghost:hover { background: #f8fafc; }
.stk__btn-outline {
  display: inline-flex; align-items: center; gap: .4rem;
  background: transparent; color: #1b5e20; border: 1.5px solid #a5d6a7;
  padding: .5rem 1.1rem; border-radius: 8px; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.stk__btn-outline:hover { background: #f0fdf4; }

/* ── KPIs ───────────────────────────────────────────────────────────────────── */
.stk__kpis {
  display: grid; grid-template-columns: repeat(4, 1fr);
  gap: .875rem; margin-bottom: 1.75rem;
}
@media (max-width: 700px) { .stk__kpis { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 400px) { .stk__kpis { grid-template-columns: 1fr; } }
.stk__kpi {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 12px;
  padding: 1rem 1.1rem; display: flex; align-items: flex-start; gap: .65rem;
  transition: box-shadow .15s;
}
.stk__kpi:hover { box-shadow: 0 2px 12px rgba(0,0,0,.06); }
.stk__kpi--warn { border-color: #fcd34d; background: #fffbeb; }
.stk__kpi-ico  { font-size: 1.35rem; flex-shrink: 0; margin-top: .05rem; }
.stk__kpi-val  { font-size: 1.75rem; font-weight: 800; line-height: 1; letter-spacing: -.04em; color: #0f172a; margin-bottom: .1rem; }
.stk__kpi-unit { font-size: 1rem; font-weight: 500; color: #94a3b8; margin-left: 2px; }
.stk__kpi-lbl  { font-size: .68rem; font-weight: 600; color: #64748b; text-transform: uppercase; letter-spacing: .05em; }

/* ── Tabs ───────────────────────────────────────────────────────────────────── */
.stk__tabs { display: flex; gap: .35rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
.stk__tab {
  display: inline-flex; align-items: center; gap: .4rem;
  padding: .5rem 1rem; border-radius: 8px; border: 1.5px solid #e2e8f0;
  background: #fff; color: #475569; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.stk__tab:hover { border-color: #a5d6a7; background: #f0fdf4; }
.stk__tab--active { background: #0f172a; color: #fff; border-color: #0f172a; }
.stk__tab-badge {
  min-width: 18px; height: 18px; background: #e2e8f0; color: #475569;
  border-radius: 999px; font-size: .62rem; font-weight: 800;
  display: inline-flex; align-items: center; justify-content: center; padding: 0 4px;
}
.stk__tab--active .stk__tab-badge { background: rgba(255,255,255,.2); color: #fff; }
.stk__tab-badge--warn { background: #fcd34d; color: #92400e; }

/* ── Loading / Empty ────────────────────────────────────────────────────────── */
.stk__loading { display: flex; align-items: center; justify-content: center; padding: 4rem; }

.stk__empty { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 3.5rem 1rem; text-align: center; }
.stk__empty-ico   { font-size: 2.5rem; }
.stk__empty-title { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0; }
.stk__empty-sub   { font-size: .82rem; color: #64748b; margin: 0; }
.stk__empty-cta   { margin-top: .75rem; }

/* ── Chips ──────────────────────────────────────────────────────────────────── */
.stk__chip {
  font-size: .68rem; font-weight: 600; padding: .2em .6em; border-radius: 5px;
  background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0;
}
.stk__chip--xs   { font-size: .62rem; padding: .15em .5em; }
.stk__chip--g    { background: #f0fdf4; color: #15803d; border-color: #bbf7d0; }
.stk__chip--lote { background: #eff6ff; color: #1d4ed8; border-color: #bfdbfe; }
.stk__chip--gen  { background: #f0fdf4; color: #166534; border-color: #bbf7d0; }
.stk__chip--ext  { background: #fef3c7; color: #92400e; border-color: #fde68a; }
.stk__chip--muted { background: #f8fafc; color: #94a3b8; border-color: #e2e8f0; }

/* ── Filters ────────────────────────────────────────────────────────────────── */
.stk__filters { display: flex; gap: .4rem; flex-wrap: wrap; margin-bottom: 1rem; }
.stk__chip-btn {
  background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0;
  border-radius: 999px; padding: .3rem .85rem; font-size: .75rem; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.stk__chip-btn:hover { border-color: #1b5e20; color: #1b5e20; }
.stk__chip-btn--active { background: #1b5e20; color: #fff; border-color: #1b5e20; }

/* ── Por asignar ────────────────────────────────────────────────────────────── */
.stk__pa-list { display: flex; flex-direction: column; gap: .75rem; }
.stk__pa-card {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 12px;
  padding: 1rem 1.25rem; display: flex; align-items: center;
  justify-content: space-between; gap: 1rem; flex-wrap: wrap;
}
.stk__pa-left  { flex: 1; min-width: 0; }
.stk__pa-forma { font-size: .95rem; font-weight: 700; color: #0f172a; margin-bottom: .35rem; }
.stk__pa-chips { display: flex; flex-wrap: wrap; gap: .3rem; }
.stk__pa-right { display: flex; align-items: center; gap: .5rem; flex-shrink: 0; flex-wrap: wrap; }
.stk__select {
  padding: .42rem .75rem; border: 1.5px solid #e2e8f0; border-radius: 8px;
  font-size: .82rem; color: #0f172a; background: #fff; cursor: pointer; min-width: 160px;
}
.stk__select:focus { outline: none; border-color: #1b5e20; }

/* ── Inventario ─────────────────────────────────────────────────────────────── */
.stk__grupo       { margin-bottom: 1.25rem; }
.stk__grupo-hd {
  display: flex; align-items: center; justify-content: space-between;
  padding: .5rem .75rem; background: #f8fafc; border: 1px solid #e2e8f0;
  border-radius: 8px 8px 0 0; border-bottom: none;
}
.stk__grupo-nombre { font-size: .8rem; font-weight: 700; color: #374151; }
.stk__grupo-total  { font-size: .8rem; font-weight: 700; color: #15803d; }
.stk__inv-list { border: 1px solid #e2e8f0; border-radius: 0 0 8px 8px; overflow: hidden; }
.stk__inv-row {
  display: flex; align-items: center; justify-content: space-between;
  gap: 1rem; padding: .75rem 1rem; background: #fff;
  border-bottom: 1px solid #f1f5f9;
}
.stk__inv-row:last-child { border-bottom: none; }
.stk__inv-main  { flex: 1; min-width: 0; }
.stk__inv-right { display: flex; align-items: center; gap: .5rem; flex-shrink: 0; }
.stk__inv-forma { font-size: .88rem; font-weight: 600; color: #0f172a; display: block; margin-bottom: .25rem; }
.stk__inv-chips { display: flex; flex-wrap: wrap; gap: .25rem; }
.stk__inv-g     { font-size: .95rem; font-weight: 800; color: #15803d; }
.stk__icon-btn  {
  width: 28px; height: 28px; border-radius: 6px; border: 1px solid #e2e8f0;
  display: flex; align-items: center; justify-content: center;
  color: #64748b; font-size: .8rem; text-decoration: none; transition: all .15s;
}
.stk__icon-btn:hover { border-color: #1b5e20; color: #1b5e20; background: #f0fdf4; }

/* ── Historial ──────────────────────────────────────────────────────────────── */
.stk__hist { background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden; }

.stk__hist-hd {
  display: flex; align-items: center; gap: .5rem;
  padding: .5rem 1rem; background: #f8fafc; border-bottom: 1px solid #e2e8f0;
}
.stk__hist-row {
  display: flex; align-items: center; gap: .5rem;
  padding: .65rem 1rem; border-bottom: 1px solid #f1f5f9;
  transition: background .1s;
}
.stk__hist-row:last-child { border-bottom: none; }
.stk__hist-row:hover { background: #f8fafc; }

.stk__hist-col { display: flex; flex-direction: column; justify-content: center; }
.stk__hist-hd .stk__hist-col { font-size: .68rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .04em; flex-direction: row; align-items: center; }

.stk__hist-col--estado  { width: 100px; flex-shrink: 0; }
.stk__hist-col--producto { flex: 1; min-width: 0; }
.stk__hist-col--sede    { width: 130px; flex-shrink: 0; }
.stk__hist-col--cant    { width: 70px; flex-shrink: 0; text-align: right; }
.stk__hist-col--fecha   { width: 80px; flex-shrink: 0; text-align: right; }

@media (max-width: 640px) {
  .stk__hist-col--sede  { display: none; }
  .stk__hist-col--fecha { display: none; }
  .stk__hist-hd { display: none; }
}

.stk__hist-forma   { font-size: .82rem; font-weight: 600; color: #0f172a; }
.stk__hist-chips   { display: flex; flex-wrap: wrap; gap: .25rem; margin-top: .2rem; }
.stk__hist-sede-nm { font-size: .78rem; color: #374151; }
.stk__hist-pool    { font-size: .75rem; color: #94a3b8; font-style: italic; }
.stk__hist-g       { font-size: .82rem; font-weight: 700; color: #15803d; }
.stk__hist-fecha   { font-size: .75rem; color: #94a3b8; }

/* ── Estado badges ──────────────────────────────────────────────────────────── */
.stk__badge {
  display: inline-flex; align-items: center;
  padding: .22em .65em; border-radius: 5px;
  font-size: .68rem; font-weight: 700; white-space: nowrap;
}
.stk__badge--pendiente_asignacion { background: #fef3c7; color: #92400e; border: 1px solid #fde68a; }
.stk__badge--asignado             { background: #dcfce7; color: #15803d; border: 1px solid #bbf7d0; }
.stk__badge--agotado              { background: #f1f5f9; color: #64748b; border: 1px solid #e2e8f0; }

/* ── Modal ──────────────────────────────────────────────────────────────────── */
.stk__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45); backdrop-filter: blur(3px);
  display: flex; align-items: flex-end; justify-content: center;
  z-index: 200; padding: 1rem;
}
@media (min-width: 640px) { .stk__overlay { align-items: center; } }
.stk__modal {
  background: #fff; border-radius: 16px;
  width: 100%; max-width: 540px; max-height: 92vh;
  display: flex; flex-direction: column;
  box-shadow: 0 20px 60px rgba(0,0,0,.2);
}
.stk__modal-hd {
  display: flex; align-items: flex-start; gap: .75rem;
  padding: 1.25rem 1.25rem 1rem; border-bottom: 1px solid #f1f5f9;
}
.stk__modal-ico {
  width: 36px; height: 36px; background: #f0fdf4; color: #1b5e20;
  border-radius: 8px; display: flex; align-items: center; justify-content: center;
  font-size: 1rem; flex-shrink: 0;
}
.stk__modal-title { font-size: .95rem; font-weight: 800; color: #0f172a; margin: 0 0 2px; }
.stk__modal-sub   { font-size: .75rem; color: #64748b; margin: 0; }
.stk__modal-close {
  margin-left: auto; background: #f8fafc; border: none; width: 28px; height: 28px;
  border-radius: 6px; cursor: pointer; display: flex; align-items: center;
  justify-content: center; color: #64748b; flex-shrink: 0;
}
.stk__modal-close:hover { background: #e2e8f0; }
.stk__modal-body { padding: 1.25rem; overflow-y: auto; flex: 1; }
.stk__modal-ft   { display: flex; justify-content: flex-end; gap: .5rem; padding: 1rem 1.25rem; border-top: 1px solid #f1f5f9; }
.stk__form-grid  { display: grid; grid-template-columns: 1fr 1fr; gap: .875rem; }
@media (max-width: 480px) { .stk__form-grid { grid-template-columns: 1fr; } }
.stk__field      { display: flex; flex-direction: column; gap: .3rem; }
.stk__field--full { grid-column: 1 / -1; }
.stk__label      { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.stk__req        { color: #ef4444; }
.stk__opt        { font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.stk__input      { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 7px; padding: .5rem .75rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; font-family: inherit; transition: border .15s; }
.stk__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.stk__input--mt   { margin-top: .35rem; }
.stk__textarea   { resize: vertical; min-height: 60px; }
.stk__input-row  { display: flex; }
.stk__input-row .stk__input { border-radius: 7px 0 0 7px; }
.stk__input-suf  { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-left: none; border-radius: 0 7px 7px 0; padding: .5rem .75rem; font-size: .82rem; font-weight: 600; color: #64748b; }
.stk__alert      { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; border-radius: 7px; padding: .55rem .75rem; font-size: .82rem; margin-bottom: 1rem; }

.stk-fade-enter-active, .stk-fade-leave-active { transition: opacity .2s; }
.stk-fade-enter-from,  .stk-fade-leave-to      { opacity: 0; }

/* ── Por asignar — qty ──────────────────────────────────────────────────────── */
.stk__pa-qty    { display: flex; align-items: center; gap: .35rem; }
.stk__qty-input { max-width: 140px; min-width: 100px; }
.stk__qty-hint  { font-size: .72rem; color: #94a3b8; white-space: nowrap; flex-shrink: 0; }

/* ── Inventory action buttons ───────────────────────────────────────────────── */
.stk__icon-btn--amber { border-color: #fde68a; color: #92400e; }
.stk__icon-btn--amber:hover { border-color: #f59e0b; color: #78350f; background: #fffbeb; }

/* ── Amber button ───────────────────────────────────────────────────────────── */
.stk__btn-amber {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #d97706; color: #fff; border: none; border-radius: 8px;
  padding: .55rem 1.1rem; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: background .15s;
}
.stk__btn-amber:hover:not(:disabled) { background: #b45309; }
.stk__btn-amber:disabled { opacity: .5; cursor: not-allowed; }

/* ── Modal amber icon ───────────────────────────────────────────────────────── */
.stk__modal-ico--amber { background: #fffbeb; color: #d97706; }

/* ── Field hint ─────────────────────────────────────────────────────────────── */
.stk__field-hint { font-size: .72rem; color: #64748b; margin-top: .2rem; }

/* ── Procesar source info ───────────────────────────────────────────────────── */
.stk__procesar-src {
  display: flex; align-items: center; justify-content: space-between;
  background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 8px;
  padding: .6rem .9rem; margin-bottom: 1rem;
}
.stk__procesar-src-lbl { font-size: .72rem; font-weight: 700; color: #166534; text-transform: uppercase; letter-spacing: .04em; }
.stk__procesar-src-val { font-size: .82rem; font-weight: 600; color: #15803d; }

/* ── Merma display ──────────────────────────────────────────────────────────── */
.stk__merma {
  display: flex; align-items: center; gap: .5rem;
  background: #fffbeb; border: 1px solid #fde68a; border-radius: 8px;
  padding: .6rem .9rem; margin-top: 1rem;
}
.stk__merma-ico { font-size: 1rem; flex-shrink: 0; }
.stk__merma-txt { font-size: .82rem; color: #92400e; }
</style>
