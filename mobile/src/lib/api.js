import { useAuthStore } from '@/stores/auth'

const BASE = (import.meta.env.VITE_API_URL || 'http://localhost:3001/api')

async function request(method, path, body, formData) {
  const auth = useAuthStore()
  const headers = {
    'X-Mobile-Client': 'true',  // le indica al backend que devuelva el token en el body
  }

  if (!formData) headers['Content-Type'] = 'application/json'
  if (auth.jwt)  headers['Authorization'] = auth.jwt

  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: formData ? formData : body ? JSON.stringify(body) : undefined,
  })

  if (res.status === 204) return { data: null }
  const json = await res.json()

  // Capturar JWT del body (solo presente en login cuando X-Mobile-Client: true)
  if (json?.token) auth.setJwt(json.token)

  if (!res.ok) {
    const err = new Error(json.error || json.errors?.join(', ') || 'Error')
    err.response = { data: json, status: res.status }
    throw err
  }
  return { data: json }
}

const get    = (path)       => request('GET',    path)
const post   = (path, body) => request('POST',   path, body)
const patch  = (path, body) => request('PATCH',  path, body)
const del    = (path)       => request('DELETE', path)
const upload = (path, fd)   => request('POST',   path, null, fd)

// ── Auth ──────────────────────────────────────────────────────
export const login = (email, password) =>
  post('/users/sign_in', { user: { email, password } })

export const getMe = () => get('/v1/users/me')

// ── Sedes ─────────────────────────────────────────────────────
export const getSedes      = ()   => get('/v1/sedes')
export const getSedeDetail = (id) => get(`/v1/sedes/${id}`)

// ── Salas ─────────────────────────────────────────────────────
export const getSala = (id) => get(`/v1/salas/${id}`)

// ── Lotes ─────────────────────────────────────────────────────
export const getLote       = (id)         => get(`/v1/lotes/${id}`)
export const createLote    = (salaId, d)  => post(`/v1/salas/${salaId}/lotes`, { lote: d })
export const updateLote    = (id, d)      => patch(`/v1/lotes/${id}`, { lote: d })
export const deleteLote    = (id)         => del(`/v1/lotes/${id}`)
export const avanzarFase   = (id, d)      => post(`/v1/lotes/${id}/avanzar_fase`, d)
export const uploadFotoLote = (id, fd)    => upload(`/v1/lotes/${id}/fotos`, fd)

// ── Registros ambientales (lote) ──────────────────────────────
export const createRegistro = (loteId, d) =>
  post(`/v1/lotes/${loteId}/registros_ambientales`, d)

// ── Plants ────────────────────────────────────────────────────
export const getPlanta          = (id)        => get(`/v1/plants/${id}`)
export const createPlanta       = (loteId, d) => post(`/v1/lotes/${loteId}/plants`, { plant: d })
export const updatePlanta       = (id, d)     => patch(`/v1/plants/${id}`, { plant: d })
export const deletePlanta       = (id)        => del(`/v1/plants/${id}`)
export const createPlantActivity = (id, d)   => post(`/v1/plants/${id}/activities`, d)
export const uploadFotoPlanta   = (id, fd)    => upload(`/v1/plants/${id}/fotos`, fd)

// ── Tareas ────────────────────────────────────────────────────
export const getTareas     = (params) => get(`/v1/tareas?${new URLSearchParams(params)}`)
export const completarTarea = (id, d) => post(`/v1/tareas/${id}/completar`, d)
