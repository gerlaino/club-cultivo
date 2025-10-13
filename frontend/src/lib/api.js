import axios from "axios";

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || "http://localhost:3001",
  withCredentials: true,
});

// -------- Auth (compat) --------
export const signIn  = (email, password) => api.post("/users/sign_in", { user: { email, password }});
export const signOut = () => api.delete("/users/sign_out");
export const me      = () => api.get("/me");

// -------- Salas (compat) --------
export const listSalas   = () => api.get("/salas");
export const getSala     = (id) => api.get(`/salas/${id}`);
export const createSala  = (payload) => api.post("/salas", { sala: payload });
export const updateSala  = (id, payload) => api.patch(`/salas/${id}`, { sala: payload });
export const deleteSala  = (id) => api.delete(`/salas/${id}`);

// -------- Lotes (compat + nuevo) --------
// GLOBAL (compatibilidad con código viejo):
export const listLotes   = () => api.get("/lotes");            // <- si tu backend no lo expone, no lo uses
// Lotes por sala (recomendado / usado en SalaDetail):
export const listLotesBySala  = (salaId) => api.get(`/salas/${salaId}/lotes`);
export const createLoteInSala = (salaId, payload) =>
  api.post(`/salas/${salaId}/lotes`, { lote: payload });

// Lote puntual (compat)
export const getLote     = (id) => api.get(`/lotes/${id}`);
export const updateLote  = (id, payload) => api.patch(`/lotes/${id}`, { lote: payload });
export const deleteLote  = (id) => api.delete(`/lotes/${id}`);

// Plantas
export function listPlantsBySala(salaId) {
  // usa index con filtro por sala, vía ?sala_id=
  return api.get(`/lotes/0/plants`, { params: { sala_id: salaId } });
}

export function listPlantsByLote(loteId) {
  return api.get(`/lotes/${loteId}/plants`);
}

export function getPlant(id) {
  return api.get(`/plants/${id}`);
}

export function createPlantInLote(loteId, payload) {
  // payload: { code?, strain, notes?, stage?, health?, photo_url? }
  return api.post(`/lotes/${loteId}/plants`, { plant: payload });
}

export function updatePlant(id, payload) {
  return api.put(`/plants/${id}`, { plant: payload });
}

export function deletePlant(id) {
  return api.delete(`/plants/${id}`);
}

export function getStats() {
  return api.get(`/stats`);
}

export function listSocios(club_id) {
  return api.get(`/${club_id}/socios`);
}

// Perfil
export const getProfile       = ()          => api.get("/profile")
export const updateProfile    = (payload)   => api.patch("/profile", { user: payload })
export const updateMyPassword = (payload)   => api.patch("/profile/password", { user: payload })
export const uploadAvatar     = (file) => {
  const fd = new FormData()
  fd.append("avatar", file)
  return api.patch("/profile/avatar", fd, { headers: { "Content-Type": "multipart/form-data" } })
}

export default api;

