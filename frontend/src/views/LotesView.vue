<template>
  <div style="padding:16px">
    <h2>Lotes</h2>
    <form @submit.prevent="crear" style="display:flex; gap:8px; flex-wrap:wrap; margin-bottom:12px">
      <input v-model="code" placeholder="Código" required />
      <select v-model="stage">
        <option value="vegetativo">vegetativo</option>
        <option value="floracion">floracion</option>
        <option value="cosechado">cosechado</option>
      </select>
      <input v-model.number="plants_count" type="number" min="0" placeholder="Plantas" />
      <input v-model.number="sala_id" type="number" min="1" placeholder="Sala ID" />
      <button>Crear</button>
    </form>
    <div v-if="store.loading">Cargando...</div>
    <div v-else-if="store.error" style="color:#b00">{{ store.error }}</div>
    <ul>
      <li v-for="l in store.items" :key="l.id">{{ l.code }} — {{ l.stage }} — plantas: {{ l.plants_count ?? 0 }} — sala: {{ l.sala_id }}</li>
    </ul>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue"
import { useLotesStore } from "../stores/lotes"
const store = useLotesStore()
const code = ref("")
const stage = ref("vegetativo")
const plants_count = ref(0)
const sala_id = ref(1)
onMounted(() => store.fetchAll())
const crear = async () => {
  await store.create({ code: code.value, stage: stage.value, plants_count: plants_count.value, sala_id: sala_id.value })
  code.value=""; stage.value="vegetativo"; plants_count.value=0
}
</script>
