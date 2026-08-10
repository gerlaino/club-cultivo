<template>
  <div class="lfs__section">
    <button class="lfs__toggle" @click="toggleFotos">
      <div class="lfs__toggle-left">
        <span class="lfs__emoji">📷</span>
        <span class="lfs__title">Fotos del lote</span>
        <span v-if="fotos.length > 0" class="lfs__pill">{{ fotos.length }}</span>
      </div>
      <div class="lfs__toggle-right">
        <button class="lfs__btn-cam" @click.stop="fotoInput?.click()" :disabled="uploadingFoto">
          <DsSpinner v-if="uploadingFoto" :size="12" />
          <i v-else class="bi bi-camera-fill"></i>
        </button>
        <i class="bi lfs__chevron" :class="fotosExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
      </div>
    </button>

    <input ref="fotoInput" type="file" accept="image/*" style="display:none" @change="handleFotoSelect" />

    <div v-show="fotosExpanded" class="lfs__body">
      <EmptyState v-if="fotos.length === 0" icon="📷" title="Sin fotos todavía" compact>
        <template #actions>
          <button class="lfs__btn-outline" @click="fotoInput?.click()">
            <i class="bi bi-camera-fill"></i> Subir primera foto
          </button>
        </template>
      </EmptyState>
      <div v-else class="lfs__grid">
        <div v-for="(f, i) in fotos" :key="f.id" class="lfs__foto">
          <div class="lfs__foto-img-wrap" @click="openLightbox(i)">
            <img :src="f.url" :alt="f.filename" class="lfs__foto-img" />
            <span v-if="f.es_portada" class="lfs__foto-portada-badge" title="Se muestra en el slot del layout">⭐ Portada</span>
          </div>
          <div class="lfs__foto-footer">
            <div class="lfs__foto-info">
              <span v-if="f.descripcion" class="lfs__foto-desc">{{ f.descripcion }}</span>
              <span class="lfs__foto-date">{{ f.created_at_label }}</span>
            </div>
            <div class="lfs__foto-acts">
              <button v-if="canEdit && !f.es_portada" class="lfs__foto-star" @click.stop="marcarPortada(f)" title="Marcar como portada del slot">
                <i class="bi bi-star"></i>
              </button>
              <button v-if="canEdit" class="lfs__foto-del" @click.stop="eliminarFoto(f)" title="Eliminar foto">
                <i class="bi bi-trash"></i>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Upload modal -->
  <Teleport to="body">
    <div v-if="showFotoUploadModal" class="lfs__overlay">
      <div class="lfs__modal">
        <div class="lfs__modal-header">
          <div>
            <h3 class="lfs__modal-title">📷 Subir foto</h3>
            <p class="lfs__modal-sub">{{ fotoUploadFile?.name }}</p>
          </div>
          <button class="lfs__modal-close" @click="cancelarSubidaFoto"><i class="bi bi-x-lg"></i></button>
        </div>
        <div class="lfs__modal-body">
          <div v-if="fotoUploadPreview" class="lfs__preview-wrap">
            <img :src="fotoUploadPreview" class="lfs__preview-img" alt="Preview" />
          </div>
          <div class="lfs__field" style="margin-top:.85rem">
            <label class="lfs__label">Descripción <span class="lfs__opt">opcional</span></label>
            <input type="text" class="lfs__input" v-model.trim="fotoUploadDescripcion"
                   placeholder="Ej: día 14 vegetativo, síntoma de deficiencia…" maxlength="200" />
          </div>
        </div>
        <div class="lfs__modal-footer">
          <button class="lfs__btn-ghost" @click="cancelarSubidaFoto">Cancelar</button>
          <button class="lfs__btn-primary" :disabled="uploadingFoto" @click="confirmarSubidaFoto">
            <DsSpinner v-if="uploadingFoto" :size="14" />
            <i v-else class="bi bi-cloud-upload"></i>Subir foto
          </button>
        </div>
      </div>
    </div>
  </Teleport>

  <Lightbox
    :images="lightboxImages"
    :index="lightboxIndex"
    :open="lightboxOpen"
    @close="lightboxOpen = false"
    @update:index="lightboxIndex = $event"
  />
</template>

<script setup>
import { useLoteFotos } from '../../composables/useLoteFotos.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import EmptyState from '../ui/EmptyState.vue'
import Lightbox   from '../ui/Lightbox.vue'

const props = defineProps({
  loteId:  { type: Number, required: true },
  canEdit: { type: Boolean, default: false },
})

const {
  fotos, uploadingFoto, fotoInput,
  showFotoUploadModal, fotoUploadFile, fotoUploadDescripcion, fotoUploadPreview,
  fotosExpanded, lightboxOpen, lightboxIndex, lightboxImages,
  toggleFotos, openLightbox,
  handleFotoSelect, confirmarSubidaFoto, cancelarSubidaFoto, eliminarFoto, marcarPortada,
} = useLoteFotos(props.loteId)
</script>

<style scoped>
.lfs__section { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; margin-top: 1.25rem; }
.lfs__toggle { width: 100%; display: flex; align-items: center; justify-content: space-between; padding: .9rem 1.1rem; background: transparent; border: none; cursor: pointer; transition: background .15s; text-align: left; }
.lfs__toggle:hover { background: #f0fdf4; }
.lfs__toggle-left { display: flex; align-items: center; gap: .6rem; }
.lfs__toggle-right { display: flex; align-items: center; gap: .5rem; }
.lfs__emoji { font-size: 1rem; }
.lfs__title { font-size: .9rem; font-weight: 700; color: #1a1a1a; }
.lfs__pill { background: #e8f5e9; color: #1b5e20; font-size: .68rem; font-weight: 700; padding: .15em .55em; border-radius: 999px; }
.lfs__chevron { color: #60725d; font-size: .75rem; }
.lfs__btn-cam { display: inline-flex; align-items: center; gap: .3rem; background: #e8f5e9; color: #1b5e20; border: 1px solid #d4e6d4; padding: .35rem .65rem; border-radius: 7px; font-size: .75rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.lfs__btn-cam:hover { background: #1b5e20; color: #fff; }
.lfs__body { border-top: 1px solid #e8f0e9; padding: .75rem 1.1rem; }
.lfs__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: .75rem; }
.lfs__foto { border-radius: 10px; overflow: hidden; border: 1px solid #d4e6d4; }
.lfs__foto-img-wrap { cursor: pointer; position: relative; }
.lfs__foto-portada-badge { position: absolute; top: 6px; left: 6px; background: rgba(21,128,61,.92); color: #fff; font-size: .62rem; font-weight: 700; padding: 2px 6px; border-radius: 6px; letter-spacing: .02em; }
.lfs__foto-acts { display: flex; align-items: center; gap: 2px; flex-shrink: 0; }
.lfs__foto-star { background: none; border: none; padding: 2px 3px; cursor: pointer; color: var(--c-slate-400); border-radius: 4px; font-size: .7rem; transition: color .12s, background .12s; }
.lfs__foto-star:hover { color: #d97706; background: #fef3c7; }
.lfs__foto-img { width: 100%; height: 120px; object-fit: cover; display: block; transition: opacity .15s; }
.lfs__foto-img-wrap:hover .lfs__foto-img { opacity: .85; }
.lfs__foto-footer { display: flex; align-items: flex-start; justify-content: space-between; gap: .25rem; padding: .35rem .5rem; background: #f4f8f4; min-height: 28px; }
.lfs__foto-info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 1px; }
.lfs__foto-desc { font-size: .65rem; color: var(--c-slate-700); line-height: 1.3; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-weight: 500; }
.lfs__foto-date { font-size: .6rem; color: var(--c-slate-400); }
.lfs__foto-del { flex-shrink: 0; background: none; border: none; padding: 2px 3px; cursor: pointer; color: var(--c-slate-400); border-radius: 4px; font-size: .7rem; transition: color .12s, background .12s; }
.lfs__foto-del:hover { color: #dc2626; background: #fee2e2; }
.lfs__btn-outline { display: inline-flex; align-items: center; gap: .3rem; background: transparent; color: #1b5e20; border: 1.5px solid #d4e6d4; padding: .5rem 1.1rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.lfs__btn-outline:hover { border-color: #1b5e20; background: #f0fdf4; }
/* Upload modal */
.lfs__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.lfs__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 440px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(27,94,32,.15); display: flex; flex-direction: column; }
.lfs__modal-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.25rem 1.5rem 1rem; border-bottom: 1px solid #e8f0e9; }
.lfs__modal-title { font-size: 1.05rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.lfs__modal-sub { font-size: .78rem; color: #60725d; margin: .2rem 0 0; }
.lfs__modal-close { background: #e8f5e9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #60725d; }
.lfs__modal-close:hover { background: #c8e6c9; }
.lfs__modal-body { padding: 1.25rem 1.5rem; flex: 1; }
.lfs__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #e8f0e9; }
.lfs__preview-wrap { border-radius: 8px; overflow: hidden; border: 1px solid var(--c-slate-200); }
.lfs__preview-img { width: 100%; max-height: 240px; object-fit: contain; display: block; background: var(--c-slate-50); }
.lfs__field { display: flex; flex-direction: column; gap: .35rem; }
.lfs__label { font-size: .78rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.lfs__opt { font-size: .68rem; font-weight: 500; color: var(--c-slate-400); text-transform: none; letter-spacing: 0; }
.lfs__input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px; padding: .6rem .85rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; }
.lfs__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.lfs__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.lfs__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.lfs__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; cursor: pointer; }
.lfs__btn-ghost:hover { background: #f0fdf4; }
</style>
