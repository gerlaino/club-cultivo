<script setup>
import { ref, watch, computed } from "vue";
import { useSalasStore } from "../../stores/salas";

const props = defineProps({ modelValue: Object }); // si viene => editar
const emit = defineEmits(["close", "saved"]);

const store = useSalasStore();

const form = ref({
  name: "",
  state: "activa",
  pots_count: 0,
  notes: ""
});
const isEdit = computed(() => !!props.modelValue?.id);
const saving = ref(false);
const error = ref(null);

watch(() => props.modelValue, (v) => {
  if (v && v.id) {
    form.value = {
      name: v.name || "",
      state: v.state || "activa",
      pots_count: v.pots_count ?? 0,
      notes: v.notes || ""
    };
  } else {
    form.value = { name: "", state: "activa", pots_count: 0, notes: "" };
  }
}, { immediate: true });

async function onSubmit() {
  error.value = null; saving.value = true;
  try {
    if (isEdit.value) {
      await store.update(props.modelValue.id, form.value);
    } else {
      await store.create(form.value);
    }
    emit("saved");
  } catch (e) {
    error.value = "No se pudo guardar la sala";
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div class="modal fade show d-block" style="background: rgba(0,0,0,.4);">
    <div class="modal-dialog">
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title">{{ isEdit ? "Editar sala" : "Nueva sala" }}</h5>
          <button type="button" class="btn-close" @click="$emit('close')"></button>
        </div>

        <form @submit.prevent="onSubmit">
          <div class="modal-body">
            <div v-if="error" class="alert alert-danger">{{ error }}</div>

            <div class="mb-3">
              <label class="form-label">Nombre</label>
              <input class="form-control" v-model.trim="form.name" required />
            </div>

            <div class="mb-3">
              <label class="form-label">Estado</label>
              <select class="form-select" v-model="form.state">
                <option value="activa">Activa</option>
                <option value="mantenimiento">Mantenimiento</option>
                <option value="inactiva">Inactiva</option>
              </select>
            </div>

            <div class="mb-3">
              <label class="form-label">Cant. macetas</label>
              <input type="number" min="0" class="form-control" v-model.number="form.pots_count" />
            </div>

            <div class="mb-3">
              <label class="form-label">Notas</label>
              <textarea class="form-control" rows="2" v-model.trim="form.notes"></textarea>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn btn-light" type="button" @click="$emit('close')" :disabled="saving">Cancelar</button>
            <button class="btn btn-primary" type="submit" :disabled="saving">
              {{ saving ? "Guardando..." : (isEdit ? "Guardar cambios" : "Crear sala") }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>
