<template>
  <div style="padding:16px">
    <h2>Salas</h2>
    <form @submit.prevent="crear" style="display:flex; gap:8px; flex-wrap:wrap; margin-bottom:12px">
      <input v-model="name" placeholder="Nombre" required />
      <select v-model="state">
        <option value="activa">activa</option>
        <option value="inactiva">inactiva</option>
        <option value="mantenimiento">mantenimiento</option>
      </select>
      <input v-model.number="pots_count" type="number" min="0" placeholder="Macetas" />
      <button>Crear</button>
    </form>
    <div v-if="store.loading">Cargando...</div>
    <div v-else-if="store.error" style="color:#b00">{{ store.error }}</div>
    <ul>
      <li v-for="s in store.items" :key="s.id">{{ s.name }} — {{ s.state }} — macetas: {{ s.pots_count ?? 0 }}</li>
    </ul>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue"
import { useSalasStore } from "../stores/salas"
const store = useSalasStore()
const name = ref("")
const state = ref("activa")
const pots_count = ref(0)
onMounted(() => store.fetchAll())
const crear = async () => {
  await store.create({ name: name.value, state: state.value, pots_count: pots_count.value })
  name.value=""; state.value="activa"; pots_count.value=0
}
</script>
