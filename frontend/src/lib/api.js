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
export const listPlantsByLote = (loteId) =>
  client.get(`/lotes/${loteId}/plants`);

export const createPlantInLote = (loteId, payload) =>
  client.post(`/lotes/${loteId}/plants`, { plant: payload });

export const getPlant = (id) =>
  client.get(`/plants/${id}`);

export const updatePlant = (id, payload) =>
  client.put(`/plants/${id}`, { plant: payload });

export const deletePlant = (id) =>
  client.delete(`/plants/${id}`);


export default api;

