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

// -------- INDICACIONES MÉDICAS --------
export const listIndicaciones = (socioId) => api.get(`/socios/${socioId}/indicaciones`);
export const getIndicacion = (id) => api.get(`/indicaciones/${id}`);
export const createIndicacion = (socioId, payload) => api.post(`/socios/${socioId}/indicaciones`, { indicacion_medica: payload });
export const updateIndicacion = (id, payload) => api.put(`/indicaciones/${id}`, { indicacion_medica: payload });
export const deleteIndicacion = (id) => api.delete(`/indicaciones/${id}`);

// -------- DISPENSACIONES --------
export const listDispensaciones = (socioId) => api.get(`/socios/${socioId}/dispensaciones`);
export const getDispensacion = (id) => api.get(`/dispensaciones/${id}`);
export const createDispensacion = (socioId, payload) => api.post(`/socios/${socioId}/dispensaciones`, { dispensacion: payload });
export const updateDispensacion = (id, payload) => api.put(`/dispensaciones/${id}`, { dispensacion: payload });
export const deleteDispensacion = (id) => api.delete(`/dispensaciones/${id}`);

// -------- USUARIOS (equipo del club) --------
export const listUsers         = (params = {}) => api.get('/usuarios', { params });
export const getUser           = (id) => api.get(`/usuarios/${id}`);
export const createUser        = (payload) => api.post('/usuarios', { user: payload });
export const updateUser        = (id, payload) => api.put(`/usuarios/${id}`, { user: payload });
export const deleteUser        = (id) => api.delete(`/usuarios/${id}`);
export const resetUserPassword = (id) => api.post(`/usuarios/${id}/reset_password`);

// -------- DOCUMENT TEMPLATES --------
export const listDocumentTemplates  = ()         => api.get('/document_templates')
export const getDocumentTemplate    = (id)       => api.get(`/document_templates/${id}`)
export const createDocumentTemplate = (payload)  => api.post('/document_templates', { document_template: payload })
export const updateDocumentTemplate = (id, payload) => api.put(`/document_templates/${id}`, { document_template: payload })
export const deleteDocumentTemplate = (id)       => api.delete(`/document_templates/${id}`)

// -------- PATIENT DOCUMENTS --------
export const listPatientDocuments   = (socioId)  => api.get(`/socios/${socioId}/documents`)
export const getPatientDocument     = (socioId, id) => api.get(`/socios/${socioId}/documents/${id}`)
export const createPatientDocument  = (socioId, payload) => api.post(`/socios/${socioId}/documents`, { document: payload })
export const updatePatientDocument  = (socioId, id, payload) => api.put(`/socios/${socioId}/documents/${id}`, { document: payload })
export const deletePatientDocument  = (socioId, id) => api.delete(`/socios/${socioId}/documents/${id}`)
export const firmarDocumento        = (socioId, id, payload) => api.post(`/socios/${socioId}/documents/${id}/firmar`, payload)
export const archivarDocumento      = (socioId, id) => api.patch(`/socios/${socioId}/documents/${id}/archivar`)

// -------- SEDES --------
export const listSedes       = ()            => api.get('/sedes')
export const getSede         = (id)          => api.get(`/sedes/${id}`)
export const createSede      = (payload)     => api.post('/sedes', { sede: payload })
export const updateSede      = (id, payload) => api.put(`/sedes/${id}`, { sede: payload })
export const deleteSede      = (id)          => api.delete(`/sedes/${id}`)
export const getSedeInventario = (id)        => api.get(`/sedes/${id}/inventario`)
export const agregarStock    = (id, payload) => api.post(`/sedes/${id}/agregar_stock`, payload)

// -------- PLAN --------
export const getPlan = () => api.get('/plan')

// ── Contabilidad ──────────────────────────────────────────────────────────────
export const getContableDashboard  = ()             => api.get('/movimientos_contables/dashboard')
export const listMovimientos        = (params = {})  => api.get('/movimientos_contables', { params })
export const getMovimiento          = (id)           => api.get(`/movimientos_contables/${id}`)
export const createMovimiento       = (payload)      => api.post('/movimientos_contables', { movimiento_contable: payload })
export const updateMovimiento       = (id, payload)  => api.put(`/movimientos_contables/${id}`, { movimiento_contable: payload })
export const deleteMovimiento       = (id)           => api.delete(`/movimientos_contables/${id}`)
export const exportMovimientosCSV   = (params = {})  => api.get('/movimientos_contables/export_csv', { params, responseType: 'blob' })

// ── Costo por lote ────────────────────────────────────────────────────────────
export const getCostoLote    = (loteId)           => api.get(`/lotes/${loteId}/costo`)
export const createCostoLote = (loteId, payload)  => api.post(`/lotes/${loteId}/costo`, { costo_lote: payload })
export const updateCostoLote = (loteId, payload)  => api.put(`/lotes/${loteId}/costo`, { costo_lote: payload })

export default api;
