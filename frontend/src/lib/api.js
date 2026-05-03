import axios from "axios";

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || "http://localhost:3001/api",
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  }
});

// Restore JWT from previous session
const storedToken = localStorage.getItem('jwt_token');
if (storedToken) {
  api.defaults.headers.common['Authorization'] = storedToken;
}

// REQUEST INTERCEPTOR: Attach JWT token
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('jwt_token');
  if (token) {
    config.headers['Authorization'] = token;
  }
  return config;
});

// RESPONSE INTERCEPTOR: Capture JWT + manejar errores de autenticación
api.interceptors.response.use(
  (response) => {
    const token = response.headers['authorization'];
    if (token) {
      localStorage.setItem('jwt_token', token);
      api.defaults.headers.common['Authorization'] = token;
    }
    return response;
  },
  async (error) => {
    const status = error?.response?.status;
    const url = error?.config?.url || "";

    if (status === 401 && !url.includes('/users/sign_in')) {
      localStorage.removeItem('jwt_token');
      delete api.defaults.headers.common['Authorization'];
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
export const me               = () => api.get("/me");
export const getMisMovimientos = () => api.get("/me/movimientos");

// -------- Salas --------
export const listSalas   = () => api.get("/salas");
export const getSala     = (id) => api.get(`/salas/${id}`);
export const createSala  = (payload) => api.post("/salas", { sala: payload });
export const updateSala  = (id, payload) => api.patch(`/salas/${id}`, { sala: payload });
export const deleteSala  = (id) => api.delete(`/salas/${id}`);

// -------- LOTES --------
export const listLotes = (params = null) => {
  if (typeof params === 'number') return api.get(`/salas/${params}/lotes`)
  return api.get('/lotes', { params: params || undefined })
}
export const getLote = (id) => api.get(`/lotes/${id}`);
export const createLote = (salaId, payload) => api.post(`/salas/${salaId}/lotes`, { lote: payload });
export const updateLote = (id, payload) => api.put(`/lotes/${id}`, { lote: payload });
export const deleteLote = (id) => api.delete(`/lotes/${id}`);
export const cargarLoteEnSala = (salaId, loteId) => api.post(`/salas/${salaId}/cargar_lote`, { lote_id: loteId });

// -------- PLANTAS --------
export const listPlants = (params = {}) => api.get('/plants', { params });
export const getPlant = (id) => api.get(`/plants/${id}`);
export const createPlant = (payload) => api.post('/plants', { plant: payload });
export const updatePlant = (id, payload) => api.put(`/plants/${id}`, { plant: payload });
export const deletePlant = (id) => api.delete(`/plants/${id}`);

// -------- PLANT ACTIVITIES --------
export const getPlantActivities = (plantId) => api.get(`/plants/${plantId}/plant_activities`);
export const createPlantActivity = (plantId, payload) => api.post(`/plants/${plantId}/plant_activities`, { plant_activity: payload });
export const deletePlantActivity = (plantId, activityId) => api.delete(`/plants/${plantId}/plant_activities/${activityId}`);

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

// -------- PACIENTES --------
export const listPacientes      = (params = {}) => api.get("/pacientes", { params });
export const getPaciente        = (id) => api.get(`/pacientes/${id}`);
export const createPaciente     = (payload) => api.post("/pacientes", { paciente: payload });
export const updatePaciente     = (id, payload) => api.put(`/pacientes/${id}`, { paciente: payload });
export const deletePaciente     = (id) => api.delete(`/pacientes/${id}`);
export const getPacienteTimeline = (id) => api.get(`/pacientes/${id}/timeline`)
export const listPacienteNotas  = (pacienteId) => api.get(`/pacientes/${pacienteId}/notas`);
export const createPacienteNota = (pacienteId, c) => api.post(`/pacientes/${pacienteId}/notas`, { nota: { contenido: c } });
export const deletePacienteNota = (notaId) => api.delete(`/paciente_notas/${notaId}`);
// deprecated aliases
export const listSocios      = listPacientes;
export const getSocio        = getPaciente;
export const createSocio     = createPaciente;
export const updateSocio     = updatePaciente;
export const deleteSocio     = deletePaciente;
export const listSocioNotas  = listPacienteNotas;
export const createSocioNota = createPacienteNota;
export const deleteSocioNota = deletePacienteNota;

// -------- INDICACIONES MÉDICAS --------
export const listIndicaciones = (pacienteId) => api.get(`/pacientes/${pacienteId}/indicaciones`);
export const getIndicacion = (id) => api.get(`/indicaciones/${id}`);
export const createIndicacion = (pacienteId, payload) => api.post(`/pacientes/${pacienteId}/indicaciones`, { indicacion_medica: payload });
export const updateIndicacion = (id, payload) => api.put(`/indicaciones/${id}`, { indicacion_medica: payload });
export const deleteIndicacion = (id) => api.delete(`/indicaciones/${id}`);

// -------- DISPENSACIONES --------
export const getCuentaCorriente  = (pacienteId)         => api.get(`/pacientes/${pacienteId}/cuenta_corriente`)
export const cargarCreditoCC     = (pacienteId, payload) => api.post(`/pacientes/${pacienteId}/cuenta_corriente/cargar`, payload)
export const ajustarCC           = (pacienteId, payload) => api.post(`/pacientes/${pacienteId}/cuenta_corriente/ajuste`, payload)
export const setLimiteCC         = (pacienteId, limite)  => api.patch(`/pacientes/${pacienteId}/cuenta_corriente/set_limite`, { limite_credito: limite })

export const listDispensaciones = (pacienteId) => api.get(`/pacientes/${pacienteId}/dispensaciones`);
export const listDispensacionesFecha = (params = {}) => api.get('/dispensaciones', { params });
export const getDispensacion = (id) => api.get(`/dispensaciones/${id}`);
export const createDispensacion = (pacienteId, payload) => api.post(`/pacientes/${pacienteId}/dispensaciones`, { dispensacion: payload });
export const updateDispensacion = (id, payload) => api.put(`/dispensaciones/${id}`, { dispensacion: payload });
export const deleteDispensacion = (id) => api.delete(`/dispensaciones/${id}`);

// -------- USUARIOS (equipo del club) --------
export const listUsers         = (params = {}) => api.get('/usuarios', { params });
export const getUser           = (id) => api.get(`/usuarios/${id}`);
export const createUser        = (payload) => api.post('/usuarios', { user: payload });
export const updateUser        = (id, payload) => api.put(`/usuarios/${id}`, { user: payload });
export const deleteUser        = (id) => api.delete(`/usuarios/${id}`);
export const resetUserPassword = (id) => api.post(`/usuarios/${id}/reset_password`);
export const getUserSalasAsignadas = (userId) => api.get(`/usuarios/${userId}/salas_asignadas`)
export const asignarSalaAUsuario   = (userId, salaId) => api.post(`/usuarios/${userId}/asignar_sala`, { sala_id: salaId })
export const desasignarSalaAUsuario = (userId, salaId) => api.delete(`/usuarios/${userId}/desasignar_sala`, { data: { sala_id: salaId } })

// -------- DOCUMENT TEMPLATES --------
export const listDocumentTemplates  = ()         => api.get('/document_templates')
export const getDocumentTemplate    = (id)       => api.get(`/document_templates/${id}`)
export const createDocumentTemplate = (payload)  => api.post('/document_templates', { document_template: payload })
export const updateDocumentTemplate = (id, payload) => api.put(`/document_templates/${id}`, { document_template: payload })
export const deleteDocumentTemplate = (id)       => api.delete(`/document_templates/${id}`)

// -------- PATIENT DOCUMENTS --------
export const listPatientDocuments   = (pacienteId)  => api.get(`/pacientes/${pacienteId}/documents`)
export const getPatientDocument     = (pacienteId, id) => api.get(`/pacientes/${pacienteId}/documents/${id}`)
export const uploadPatientDocument  = (pacienteId, formData) => api.post(`/pacientes/${pacienteId}/documents`, formData, { headers: { 'Content-Type': 'multipart/form-data' } })
export const createPatientDocument  = (pacienteId, payload) => api.post(`/pacientes/${pacienteId}/documents`, { document: payload })
export const updatePatientDocument  = (pacienteId, id, payload) => api.put(`/pacientes/${pacienteId}/documents/${id}`, { document: payload })
export const deletePatientDocument  = (pacienteId, id) => api.delete(`/pacientes/${pacienteId}/documents/${id}`)
export const firmarDocumento        = (pacienteId, id, payload) => api.post(`/pacientes/${pacienteId}/documents/${id}/firmar`, payload)
export const archivarDocumento      = (pacienteId, id) => api.patch(`/pacientes/${pacienteId}/documents/${id}/archivar`)

// DOCUMENTOS
export const getDocumentos    = ()         => api.get('/documentos')
export const createDocumento  = (formData) => api.post('/documentos', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
export const deleteDocumento  = (id)       => api.delete(`/documentos/${id}`)

// -------- SEDES --------
export const listSedes       = ()            => api.get('/sedes')
export const getSede         = (id)          => api.get(`/sedes/${id}`)
export const createSede      = (payload)     => api.post('/sedes', { sede: payload })
export const updateSede      = (id, payload) => api.put(`/sedes/${id}`, { sede: payload })
export const deleteSede      = (id)          => api.delete(`/sedes/${id}`)
export const getSedeInventario   = (id)               => api.get(`/sedes/${id}/inventario`)
export const agregarStock        = (id, payload)       => api.post(`/sedes/${id}/agregar_stock`, payload)
export const listStockDisponible = (sedeId)                => api.get(`/sedes/${sedeId}/inventario`)
export const getStockPendiente   = (sedeId)                => api.get(`/sedes/${sedeId}/stock_pendiente`)
export const aprobarStock        = (sedeId, movId)         => api.post(`/sedes/${sedeId}/aprobar_stock/${movId}`)
export const rechazarStock       = (sedeId, movId, motivo) => api.post(`/sedes/${sedeId}/rechazar_stock/${movId}`, { motivo })

// Inventario global (sin sede específica)
export const getInventarioPendiente = ()              => api.get('/inventario/pendiente')
export const getStockDisponible     = ()              => api.get('/inventario/disponible')
export const aprobarMovimiento      = (id)            => api.post(`/inventario/aprobar/${id}`)
export const rechazarMovimiento     = (id, motivo)    => api.post(`/inventario/rechazar/${id}`, { motivo })

// ── Aprobación manicura ───────────────────────────────────────────────────────
export const aprobarManicura  = (loteId, observaciones) => api.post(`/lotes/${loteId}/aprobar_manicura`, { observaciones })
export const rechazarManicura = (loteId, motivo)        => api.post(`/lotes/${loteId}/rechazar_manicura`, { motivo })

// -------- PLAN --------
export const getPlan = () => api.get('/plan')

// ── Contabilidad ──────────────────────────────────────────────────────────────
export const getContableDashboard  = (params = {}) => api.get('/movimientos_contables/dashboard', { params })
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

// ── Informe semestral REPROCANN ───────────────────────────────────────────────
export const getInformeSemestral = (params = {}) => api.get('/informe_semestral', { params })

// ── Tareas ──────────────────────────────────────────────────────────

export const listTareas        = (params = {}) => api.get('/tareas', { params })
export const getTareasDashboard = ()            => api.get('/tareas/dashboard')
export const getTareasKanban   = (params = {}) => api.get('/tareas/kanban', { params })
export const getTarea          = (id)           => api.get(`/tareas/${id}`)
export const createTarea       = (payload)      => api.post('/tareas', { tarea: payload })
export const updateTarea       = (id, payload)  => api.patch(`/tareas/${id}`, { tarea: payload })
export const deleteTarea       = (id)           => api.delete(`/tareas/${id}`)
export const iniciarTarea      = (id)           => api.post(`/tareas/${id}/iniciar`)
export const completarTarea    = (id, data)     => api.post(`/tareas/${id}/completar`, data)
export const cancelarTarea     = (id)           => api.post(`/tareas/${id}/cancelar`)
export const getTareasSemana   = (desde)        => api.get('/tareas/semana', { params: { desde } })
export const cancelarSerieTarea = (id)          => api.delete(`/tareas/${id}/cancelar_serie`)

// Gestión de cultivadores asignados a salas

export const getSalaCultivadores = (salaId) => api.get(`/salas/${salaId}/cultivadores`)

export const asignarCultivador = (salaId, userId) => api.post(`/salas/${salaId}/cultivadores`, { user_id: userId })

export const desasignarCultivador = (salaId, userId) => api.delete(`/salas/${salaId}/cultivadores/${userId}`)
export const getUserSedesAsignadas  = (userId)          => api.get(`/usuarios/${userId}/sedes_asignadas`)
export const asignarSedeAUsuario    = (userId, sedeId)  => api.post(`/usuarios/${userId}/asignar_sede`, { sede_id: sedeId })
export const desasignarSedeAUsuario = (userId, sedeId)  => api.delete(`/usuarios/${userId}/desasignar_sede`, { data: { sede_id: sedeId } })

export const getRegistrosAmbientales  = (loteId)          => api.get(`/lotes/${loteId}/registros_ambientales`)
export const createRegistroAmbiental  = (loteId, payload)  => api.post(`/lotes/${loteId}/registros_ambientales`, { registro_ambiental: payload })
export const deleteRegistroAmbiental  = (loteId, id)       => api.delete(`/lotes/${loteId}/registros_ambientales/${id}`)

// ── Módulo Ambiente ──────────────────────────────────────────────────────────
export const getSalaAmbiente     = (salaId, params = {}) => api.get(`/salas/${salaId}/ambiente`, { params })
export const getSalaAlertas      = (salaId)              => api.get(`/salas/${salaId}/alertas`)
export const listAlertas         = (params = {})         => api.get('/alertas', { params })
export const getAlerta           = (id)                  => api.get(`/alertas/${id}`)
export const reconocerAlerta     = (id)                  => api.post(`/alertas/${id}/reconocer`)
export const resolverAlerta      = (id)                  => api.post(`/alertas/${id}/resolver`)

export const listDispositivos    = ()            => api.get('/dispositivos')
export const createDispositivo   = (payload)     => api.post('/dispositivos', { dispositivo: payload })
export const updateDispositivo   = (id, payload) => api.put(`/dispositivos/${id}`, { dispositivo: payload })
export const deleteDispositivo   = (id)          => api.delete(`/dispositivos/${id}`)
export const regenerarToken      = (id)          => api.post(`/dispositivos/${id}/regenerar_token`)

export const listReglasAmbientales  = (params = {}) => api.get('/reglas_ambientales', { params })
export const getReglaAmbiental      = (id)           => api.get(`/reglas_ambientales/${id}`)
export const createReglaAmbiental   = (payload)      => api.post('/reglas_ambientales', { regla_ambiental: payload })
export const updateReglaAmbiental   = (id, payload)  => api.put(`/reglas_ambientales/${id}`, { regla_ambiental: payload })
export const deleteReglaAmbiental   = (id)           => api.delete(`/reglas_ambientales/${id}`)

export const listSetpointsFase   = (params = {}) => api.get('/setpoints_fase', { params })
export const createSetpointFase  = (payload)     => api.post('/setpoints_fase', { setpoint_fase: payload })
export const updateSetpointFase  = (id, payload) => api.put(`/setpoints_fase/${id}`, { setpoint_fase: payload })
export const deleteSetpointFase  = (id)          => api.delete(`/setpoints_fase/${id}`)

export const getLoteEventos    = (loteId)          => api.get(`/lotes/${loteId}/lote_eventos`)
export const createLoteEvento  = (loteId, payload)  => api.post(`/lotes/${loteId}/lote_eventos`, { lote_evento: payload })

export const getLoteFotos    = (loteId)        => api.get(`/lotes/${loteId}/fotos`)
export const uploadFotoLote  = (loteId, formData) => api.post(`/lotes/${loteId}/fotos`, formData, { headers: { 'Content-Type': 'multipart/form-data' } })

// ── Super Admin ──────────────────────────────────────────────────────
export const getSuperAdminStats  = ()             => api.get('/super_admin/stats')
export const listSuperAdminClubs = ()             => api.get('/super_admin/clubs')
export const getSuperAdminClub   = (id)           => api.get(`/super_admin/clubs/${id}`)
export const createSuperAdminClub = (payload)     => api.post('/super_admin/clubs', { club: payload })
export const updateSuperAdminClub = (id, payload) => api.put(`/super_admin/clubs/${id}`, { club: payload })
export const cambiarPlanClub     = (id, payload)  => api.patch(`/super_admin/clubs/${id}/cambiar_plan`, payload)
export const crearUsuariosDefault = (id)          => api.post(`/super_admin/clubs/${id}/crear_usuarios_default`)
export const eliminarClub        = (id)           => api.delete(`/super_admin/clubs/${id}`)
export const restaurarClub       = (id)           => api.patch(`/super_admin/clubs/${id}/restaurar`)
export const listSuperAdminUsers = ()             => api.get('/super_admin/users')
export const createSuperAdminUser = (payload)     => api.post('/super_admin/users', { user: payload })
export const updateSuperAdminUser = (id, payload) => api.put(`/super_admin/users/${id}`, { user: payload })
export const deleteSuperAdminUser = (id)          => api.delete(`/super_admin/users/${id}`)

// -------- NOTICIAS --------
export const listNoticias  = (params = {}) => api.get('/noticias', { params })
export const getNoticia    = (id)          => api.get(`/noticias/${id}`)
export const createNoticia = (payload)     => api.post('/noticias', { noticia: payload })
export const updateNoticia = (id, payload) => api.patch(`/noticias/${id}`, { noticia: payload })
export const deleteNoticia = (id)          => api.delete(`/noticias/${id}`)

// -------- EVENTOS --------
export const listEventos  = (params = {}) => api.get('/eventos', { params })
export const getEvento    = (id)          => api.get(`/eventos/${id}`)
export const createEvento = (payload)     => api.post('/eventos', { evento: payload })
export const updateEvento = (id, payload) => api.patch(`/eventos/${id}`, { evento: payload })
export const deleteEvento = (id)          => api.delete(`/eventos/${id}`)

export const getSalaNotas   = (salaId)   => api.get(`/salas/${salaId}/notas`)
export const createSalaNota = (salaId, payload) => api.post(`/salas/${salaId}/notas`, payload)
export const getLoteNotas   = (loteId)   => api.get(`/lotes/${loteId}/notas`)
export const createLoteNota = (loteId, payload) => api.post(`/lotes/${loteId}/notas`, payload)
export const getPlantNotas  = (plantId)  => api.get(`/plants/${plantId}/notas`)
export const createPlantNota = (plantId, payload) => api.post(`/plants/${plantId}/notas`, payload)
export const deleteNota     = (id)       => api.delete(`/notas/${id}`)

export const getPlantaByQR = (codigoQr) => api.get(`/p/${codigoQr}`)

// ── Lote ciclo productivo ─────────────────────────────────────────────────────
export const transicionarLote  = (loteId, payload) => api.post(`/lotes/${loteId}/transiciones`, payload)
export const avanzarFaseLote   = (loteId)          => api.post(`/lotes/${loteId}/avanzar_fase`)
export const cerrarCurado      = (loteId, payload) => api.post(`/lotes/${loteId}/cerrar_curado`, payload)
export const getLoteTimeline  = (loteId)          => api.get(`/lotes/${loteId}/timeline`)

// ── Pesadas ───────────────────────────────────────────────────────────────────
export const getPesadas     = (loteId)          => api.get(`/lotes/${loteId}/pesadas`)
export const createPesada   = (loteId, payload) => api.post(`/lotes/${loteId}/pesadas`, { pesada: payload })
export const deletePesada   = (loteId, id)      => api.delete(`/lotes/${loteId}/pesadas/${id}`)

// ── Lecturas ambientales ──────────────────────────────────────────────────────
export const createLecturaAmbiental = (salaId, payload) => api.post(`/salas/${salaId}/lecturas_ambientales`, { lectura_ambiental: payload })

// ── Stocks (nuevo modelo) ─────────────────────────────────────────────────────
export const listStocks           = (params = {})         => api.get('/stocks', { params })
export const listStocksPendientes = ()                    => api.get('/stocks', { params: { pendientes: true } })
export const createStock          = (payload)             => api.post('/stocks', { stock: payload })
export const asignarStock         = (id, payload)         => api.post(`/stocks/${id}/asignar`, payload)
export const getSedeStocks        = (sedeId, params = {}) => api.get(`/sedes/${sedeId}/stocks`, { params })

export default api;
