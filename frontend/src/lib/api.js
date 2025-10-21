import axios from "axios";

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || "http://localhost:3001",
  withCredentials: true, // ← manda la cookie _club_session siempre
});

// Si el server responde 401, limpiamos sesión (carga diferida para evitar ciclo)
api.interceptors.response.use(
  (r) => r,
  async (err) => {
    if (err?.response?.status === 401) {
      try {
        const { useAuthStore } = await import("@/stores/auth");
        useAuthStore().$reset();
      } catch {}
    }
    return Promise.reject(err);
  }
);

// -------- Auth (compat) --------
// 👇 Importante: usar endpoints JSON para evitar respuestas HTML/redirecciones
export const signIn  = (email, password) => api.post("/users/sign_in.json",  { user: { email, password } });
export const signOut = ()                   => api.delete("/users/sign_out.json");
export const me      = ()                   => api.get("/me");

// -------- Salas (compat) --------
export const listSalas   = ()            => api.get("/salas");
export const getSala     = (id)          => api.get(`/salas/${id}`);
export const createSala  = (payload)     => api.post("/salas", { sala: payload });
export const updateSala  = (id, payload) => api.patch(`/salas/${id}`, { sala: payload });
export const deleteSala  = (id)          => api.delete(`/salas/${id}`);

// -------- Lotes (compat + nuevo) --------
export const listLotes         = ()            => api.get("/lotes");
export const listLotesBySala   = (salaId)      => api.get(`/salas/${salaId}/lotes`);
export const createLoteInSala  = (salaId, p)   => api.post(`/salas/${salaId}/lotes`, { lote: p });
export const getLote           = (id)          => api.get(`/lotes/${id}`);
export const updateLote        = (id, payload) => api.patch(`/lotes/${id}`, { lote: payload });
export const deleteLote        = (id)          => api.delete(`/lotes/${id}`);

// Plantas
export const listPlantsBySala = (salaId)   => api.get(`/lotes/0/plants`, { params: { sala_id: salaId } });
export const listPlantsByLote = (loteId)   => api.get(`/lotes/${loteId}/plants`);
export const getPlant         = (id)       => api.get(`/plants/${id}`);
export const createPlantInLote= (loteId,p) => api.post(`/lotes/${loteId}/plants`, { plant: p });
export const updatePlant      = (id,p)     => api.put(`/plants/${id}`, { plant: p });
export const deletePlant      = (id)       => api.delete(`/plants/${id}`);
export const getStats         = ()         => api.get(`/stats`);

// Perfil
export const getProfile       = ()        => api.get("/profile");
export const updateProfile    = (payload) => api.patch("/profile", { user: payload });
export const updateMyPassword = (payload) => api.patch("/profile/password", { user: payload });
export const uploadAvatar     = (file) => {
  const fd = new FormData();
  fd.append("avatar", file);
  return api.patch("/profile/avatar", fd, { headers: { "Content-Type": "multipart/form-data" } });
};

// Preferencias del Club
export const getPreferences     = ()            => api.get("/preferences");
export const updatePreferences  = (payload)     => api.put("/preferences", { club: payload });
export const uploadClubLogo     = (file) => {
  const form = new FormData();
  form.append("logo", file);
  return api.post("/preferences/logo", form, { headers: { "Content-Type": "multipart/form-data" } });
};

// SOCIOS
export const listSocios        = (params = {}) => api.get("/socios", { params });
export const getSocio          = (id)          => api.get(`/socios/${id}`);
export const createSocio       = (payload)     => api.post("/socios", { socio: payload });
export const updateSocio       = (id, payload) => api.put(`/socios/${id}`, { socio: payload });
export const deleteSocio       = (id)          => api.delete(`/socios/${id}`);
export const listSocioNotas    = (socioId)     => api.get(`/socios/${socioId}/notas`);
export const createSocioNota   = (socioId, c)  => api.post(`/socios/${socioId}/notas`, { nota: { contenido: c } });
export const deleteSocioNota   = (notaId)      => api.delete(`/socio_notas/${notaId}`);

// USUARIOS (equipo del club)
export const listUsers           = (params = {}) => api.get('/usuarios', { params });
export const getUser             = (id)          => api.get(`/usuarios/${id}`);
export const createUser          = (payload)     => api.post('/usuarios', { user: payload });
export const updateUser          = (id, payload) => api.put(`/usuarios/${id}`, { user: payload });
export const deleteUser          = (id)          => api.delete(`/usuarios/${id}`);
export const resetUserPassword   = (id)          => api.post(`/usuarios/${id}/reset_password`);

export default api;
