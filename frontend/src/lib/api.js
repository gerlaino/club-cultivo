import axios from "axios";

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || "http://localhost:3001",
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  }
});

// REQUEST INTERCEPTOR: Agregar token JWT a cada request
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('jwt_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// RESPONSE INTERCEPTOR: Guardar token y manejar errores
api.interceptors.response.use(
  (response) => {
    // Si viene token en el header, guardarlo
    const token = response.headers['authorization'];
    if (token) {
      const cleanToken = token.replace('Bearer ', '');
      localStorage.setItem('jwt_token', cleanToken);
    }
    return response;
  },
  async (error) => {
    const status = error?.response?.status;
    const url = error?.config?.url || "";

    // Si es 401 (no autorizado)
    if (status === 401 && !url.includes('/users/sign_in')) {
      // Limpiar token inválido
      localStorage.removeItem('jwt_token');

      // Limpiar auth store
      try {
        const { useAuthStore } = await import("../stores/auth");
        const auth = useAuthStore();
        auth.user = null;
        auth.bootstrapped = true;
      } catch {}
    }

    return Promise.reject(error);
  }
);

// -------- Auth --------
export const signIn  = (email, password) => api.post("/users/sign_in", { user: { email, password } });
export const signOut = () => api.delete("/users/sign_out");
export const me      = () => api.get("/me");

// -------- Salas --------
export const listSalas   = () => api.get("/salas");
export const getSala     = (id) => api.get(`/salas/${id}`);
export const createSala  = (payload) => api.post("/salas", { sala: payload });
export const updateSala  = (id, payload) => api.patch(`/salas/${id}`, { sala: payload });
export const deleteSala  = (id) => api.delete(`/salas/${id}`);

// -------- LOTES --------
export const listLotes = () => api.get('/lotes');
export const getLote = (id) => api.get(`/lotes/${id}`);
export const createLote = (salaId, payload) => api.post(`/salas/${salaId}/lotes`, { lote: payload });
export const updateLote = (id, payload) => api.put(`/lotes/${id}`, { lote: payload });
export const deleteLote = (id) => api.delete(`/lotes/${id}`);

// -------- PLANTAS --------
export const listPlants = (params = {}) => api.get('/plants', { params });
export const getPlant = (id) => api.get(`/plants/${id}`);
export const createPlant = (payload) => api.post('/plants', { plant: payload });
export const updatePlant = (id, payload) => api.put(`/plants/${id}`, { plant: payload });
export const deletePlant = (id) => api.delete(`/plants/${id}`);

// -------- PLANT ACTIVITIES --------
export const listPlantActivities = (plantId) => api.get(`/plants/${plantId}/activities`);
export const createPlantActivity = (plantId, payload) => api.post(`/plants/${plantId}/activities`, { plant_activity: payload });
export const deletePlantActivity = (plantId, activityId) => api.delete(`/plants/${plantId}/activities/${activityId}`);

// -------- GENÉTICAS --------
export const listGeneticas = (params = {}) => api.get('/geneticas', { params });
export const getGenetica = (id) => api.get(`/geneticas/${id}`);
export const createGenetica = (payload) => api.post('/geneticas', { genetica: payload });
export const updateGenetica = (id, payload) => api.put(`/geneticas/${id}`, { genetica: payload });
export const deleteGenetica = (id) => api.delete(`/geneticas/${id}`);

// -------- Perfil --------
export const getProfile       = () => api.get("/profile");
export const updateProfile    = (payload) => api.patch("/profile", { user: payload });
export const updateMyPassword = (payload) => api.patch("/profile/password", { user: payload });
export const uploadAvatar     = (file) => {
  const fd = new FormData();
  fd.append("avatar", file);
  return api.patch("/profile/avatar", fd, { headers: { "Content-Type": "multipart/form-data" } });
};

// -------- Preferencias del Club --------
export const getPreferences    = () => api.get("/preferences");
export const updatePreferences = (payload) => api.put("/preferences", { club: payload });
export const uploadClubLogo    = (file) => {
  const form = new FormData();
  form.append("logo", file);
  return api.post("/preferences/logo", form, { headers: { "Content-Type": "multipart/form-data" } });
};

// -------- SOCIOS --------
export const listSocios      = (params = {}) => api.get("/socios", { params });
export const getSocio        = (id) => api.get(`/socios/${id}`);
export const createSocio     = (payload) => api.post("/socios", { socio: payload });
export const updateSocio     = (id, payload) => api.put(`/socios/${id}`, { socio: payload });
export const deleteSocio     = (id) => api.delete(`/socios/${id}`);
export const listSocioNotas  = (socioId) => api.get(`/socios/${socioId}/notas`);
export const createSocioNota = (socioId, c) => api.post(`/socios/${socioId}/notas`, { nota: { contenido: c } });
export const deleteSocioNota = (notaId) => api.delete(`/socio_notas/${notaId}`);

// -------- USUARIOS (equipo del club) --------
export const listUsers         = (params = {}) => api.get('/usuarios', { params });
export const getUser           = (id) => api.get(`/usuarios/${id}`);
export const createUser        = (payload) => api.post('/usuarios', { user: payload });
export const updateUser        = (id, payload) => api.put(`/usuarios/${id}`, { user: payload });
export const deleteUser        = (id) => api.delete(`/usuarios/${id}`);
export const resetUserPassword = (id) => api.post(`/usuarios/${id}/reset_password`);

export default api;
