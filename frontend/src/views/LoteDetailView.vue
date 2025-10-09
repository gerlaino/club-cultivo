<script setup>
import { onMounted, ref, computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useLotesStore } from "../stores/lotes";

const route = useRoute();
const router = useRouter();
const lotes = useLotesStore();

const id = Number(route.params.id);
const loading = ref(true);
const error = ref(null);

onMounted(async () => {
  try {
    await lotes.fetchOne(id);
  } catch (e) {
    error.value = "No se pudo cargar el lote.";
  } finally {
    loading.value = false;
  }
});

const lote = computed(() => lotes.current);
</script>

<template>
  <div class="container py-4">
    <button class="btn btn-outline-secondary btn-sm mb-3" @click="router.back()">← Volver</button>

    <div v-if="loading" class="alert alert-info">Cargando…</div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else-if="!lote" class="alert alert-warning">Lote no encontrado.</div>

    <div v-else>
      <h2 class="mb-3">Lote #{{ lote.id }}</h2>
      <div class="row g-3">
        <div class="col-12 col-lg-8">
          <div class="card">
            <div class="card-body">
              <div class="mb-2"><strong>Plantas:</strong> {{ lote.plants_count }}</div>
              <div class="mb-2"><strong>Genética:</strong> {{ lote.strain || "—" }}</div>
              <div class="mb-2"><strong>Inicio:</strong> {{ lote.start_date || "—" }}</div>
              <div class="mb-2"><strong>Etapa:</strong> {{ lote.stage || "—" }}</div>
              <div class="mb-2"><strong>Tipo cultivo:</strong> {{ lote.grow_type || "—" }}</div>
              <div class="mb-2"><strong>Luminaria:</strong> {{ lote.light_type || "—" }}</div>
              <div class="mb-0"><strong>Notas:</strong> {{ lote.notes || "—" }}</div>
            </div>
          </div>
        </div>
        <div class="col-12 col-lg-4">
          <div class="card">
            <div class="card-header"><strong>Imagen</strong></div>
            <div class="card-body">
              <div class="ratio ratio-1x1 bg-light rounded d-flex align-items-center justify-content-center text-muted">
                (imagen futura)
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

