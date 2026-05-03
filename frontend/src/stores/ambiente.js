import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import {
  getSalaAmbiente,
  getSalaAlertas,
  listAlertas,
  resolverAlerta as apiResolverAlerta,
  reconocerAlerta as apiReconocerAlerta,
  listDispositivos,
  createDispositivo as apiCreateDispositivo,
  updateDispositivo as apiUpdateDispositivo,
  deleteDispositivo as apiDeleteDispositivo,
  regenerarToken as apiRegenerarToken,
  listReglasAmbientales,
  createReglaAmbiental as apiCreateRegla,
  updateReglaAmbiental as apiUpdateRegla,
  deleteReglaAmbiental as apiDeleteRegla,
  listSetpointsFase,
  createSetpointFase as apiCreateSetpoint,
  updateSetpointFase as apiUpdateSetpoint,
  deleteSetpointFase as apiDeleteSetpoint,
} from '../lib/api.js'

export const useAmbienteStore = defineStore('ambiente', () => {
  const lecturas     = ref([])
  const alertas      = ref([])
  const dispositivos = ref([])
  const reglas       = ref([])
  const setpoints    = ref([])

  const loadingLecturas = ref(false)
  const error           = ref(null)

  // ── Getters ─────────────────────────────────────────────────────────────────
  const alertasActivas = computed(() => alertas.value.filter(a => a.estado === 'activa'))
  const alertasCount   = computed(() => alertasActivas.value.length)

  function lecturasPorTipo(tipo) {
    return lecturas.value.filter(l => l.tipo === tipo)
  }

  function ultimaLectura(tipo) {
    const filtered = lecturasPorTipo(tipo)
    if (!filtered.length) return null
    return filtered.reduce((a, b) =>
      new Date(a.medido_at) > new Date(b.medido_at) ? a : b
    )
  }

  // ── Ambiente (lecturas de sala) ──────────────────────────────────────────────
  async function cargarAmbiente(salaId, params = {}) {
    loadingLecturas.value = true
    error.value = null
    try {
      const res = await getSalaAmbiente(salaId, params)
      lecturas.value = res.data
    } catch (e) {
      error.value = e?.response?.data?.error || e.message
    } finally {
      loadingLecturas.value = false
    }
  }

  // ── Alertas ──────────────────────────────────────────────────────────────────
  async function cargarAlertas(salaId = null) {
    try {
      const res = salaId ? await getSalaAlertas(salaId) : await listAlertas()
      alertas.value = res.data
    } catch {}
  }

  async function resolverAlerta(id) {
    await apiResolverAlerta(id)
    alertas.value = alertas.value.filter(a => a.id !== id)
  }

  async function reconocerAlerta(id) {
    await apiReconocerAlerta(id)
    const idx = alertas.value.findIndex(a => a.id === id)
    if (idx !== -1) alertas.value[idx] = { ...alertas.value[idx], estado: 'reconocida' }
  }

  // ── Dispositivos ─────────────────────────────────────────────────────────────
  async function cargarDispositivos() {
    try {
      const res = await listDispositivos()
      dispositivos.value = res.data
    } catch {}
  }

  async function createDispositivo(payload) {
    const res = await apiCreateDispositivo(payload)
    dispositivos.value.push(res.data)
    return res.data
  }

  async function updateDispositivo(id, payload) {
    const res = await apiUpdateDispositivo(id, payload)
    const idx = dispositivos.value.findIndex(d => d.id === id)
    if (idx !== -1) dispositivos.value[idx] = res.data
    return res.data
  }

  async function deleteDispositivo(id) {
    await apiDeleteDispositivo(id)
    dispositivos.value = dispositivos.value.filter(d => d.id !== id)
  }

  async function regenerarToken(id) {
    const res = await apiRegenerarToken(id)
    const idx = dispositivos.value.findIndex(d => d.id === id)
    if (idx !== -1) dispositivos.value[idx] = { ...dispositivos.value[idx], ...res.data }
    return res.data
  }

  // ── Reglas Ambientales ───────────────────────────────────────────────────────
  async function cargarReglas() {
    try {
      const res = await listReglasAmbientales()
      reglas.value = res.data
    } catch {}
  }

  async function createRegla(payload) {
    const res = await apiCreateRegla(payload)
    reglas.value.push(res.data)
    return res.data
  }

  async function updateRegla(id, payload) {
    const res = await apiUpdateRegla(id, payload)
    const idx = reglas.value.findIndex(r => r.id === id)
    if (idx !== -1) reglas.value[idx] = res.data
    return res.data
  }

  async function deleteRegla(id) {
    await apiDeleteRegla(id)
    reglas.value = reglas.value.filter(r => r.id !== id)
  }

  // ── Setpoints ────────────────────────────────────────────────────────────────
  async function cargarSetpoints(params = {}) {
    try {
      const res = await listSetpointsFase(params)
      setpoints.value = res.data
    } catch {}
  }

  async function createSetpoint(payload) {
    const res = await apiCreateSetpoint(payload)
    setpoints.value.push(res.data)
    return res.data
  }

  async function updateSetpoint(id, payload) {
    const res = await apiUpdateSetpoint(id, payload)
    const idx = setpoints.value.findIndex(s => s.id === id)
    if (idx !== -1) setpoints.value[idx] = res.data
    return res.data
  }

  async function deleteSetpoint(id) {
    await apiDeleteSetpoint(id)
    setpoints.value = setpoints.value.filter(s => s.id !== id)
  }

  return {
    lecturas, alertas, dispositivos, reglas, setpoints,
    loadingLecturas, error,
    alertasActivas, alertasCount,
    lecturasPorTipo, ultimaLectura,
    cargarAmbiente, cargarAlertas, resolverAlerta, reconocerAlerta,
    cargarDispositivos, createDispositivo, updateDispositivo, deleteDispositivo, regenerarToken,
    cargarReglas, createRegla, updateRegla, deleteRegla,
    cargarSetpoints, createSetpoint, updateSetpoint, deleteSetpoint,
  }
})
