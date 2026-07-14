import axios from "axios";
import { useToast } from "../composables/useToast.js";

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || "http://localhost:3001/api",
  withCredentials: true,  // envía httpOnly cookie automáticamente en cada request
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  }
});

// La autenticación web viaja únicamente en la cookie httpOnly (withCredentials).
// El token nunca se guarda en localStorage: si fuera legible desde JS, cualquier
// XSS podría robarlo. La línea siguiente limpia restos de la versión anterior.
localStorage.removeItem('jwt_token');

export function clearAuthToken() {
  localStorage.removeItem('jwt_token');
  delete api.defaults.headers.common['Authorization'];
}

// RESPONSE INTERCEPTOR: manejar errores de autenticación y servidor
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const status = error?.response?.status;
    const url = error?.config?.url || "";

    if (status === 401 && !url.includes('/users/sign_in')) {
      let loggingOut = false;
      try {
        const { useAuthStore } = await import("../stores/auth");
        const auth = useAuthStore();
        loggingOut = auth.loggingOut;
        auth.user = null;
        auth.bootstrapped = true;
      } catch {}

      // El 401 del bootstrap (/me) NO fuerza redirect acá: el router.beforeEach ya manda
      // a /login preservando la ruta de origen (?redirect=…) — así un QR escaneado sin
      // sesión vuelve a su página tras loguearse. Para otros 401 (sesión vencida mientras
      // usabas una página protegida) mandamos a login conservando a dónde volver.
      // Si estamos cerrando sesión, NO capturamos la ruta actual: el próximo usuario
      // no debe caer en la página del anterior.
      const esBootstrap = url.replace(/\?.*$/, '').endsWith('/me');
      const path = window.location.pathname;
      if (!esBootstrap && !loggingOut && !path.startsWith('/login')) {
        const retorno = encodeURIComponent(path + window.location.search);
        window.location.href = `/login?redirect=${retorno}`;
      }
    }

    if (status === 500) {
      const toast = useToast();
      toast.error('Error en el servidor. Intentá de nuevo en unos segundos.', { timeout: 5000 });
    }

    return Promise.reject(error);
  }
);

// -------- Auth --------
export const signIn  = (email, password) => api.post("/users/sign_in", { user: { email, password } });
export const signOut = () => api.delete("/users/sign_out");
export const me               = () => api.get("/me");

// -------- Salas --------
export const listSalas   = () => api.get("/salas");
export const getSala     = (id) => api.get(`/salas/${id}`);
export const createSala      = (payload)         => api.post("/salas", { sala: payload });
export const updateSala      = (id, payload)     => api.patch(`/salas/${id}`, { sala: payload });
export const deleteSala      = (id)              => api.delete(`/salas/${id}`);
export const cambiarFaseSala  = (id)              => api.post(`/salas/${id}/cambiar_fase`);
export const registrarSala    = (id, payload)     => api.post(`/salas/${id}/registrar_sala`, { registro_ambiental: payload });

// -------- LOTES --------
export const listLotes = (params = null) => {
  if (typeof params === 'number') return api.get(`/salas/${params}/lotes`)
  return api.get('/lotes', { params: params || undefined })
}
export const getLote      = (id)         => api.get(`/lotes/${id}`)
export const getLotePorQR = (codigoQr)   => api.get(`/lotes/por_qr/${codigoQr}`)
export const createLote = (salaId, payload) => api.post(`/salas/${salaId}/lotes`, { lote: payload });
export const updateLote         = (id, payload, extra = {}) => api.put(`/lotes/${id}`, { lote: payload, ...extra });
export const registrarTrasplante = (id, payload) => api.post(`/lotes/${id}/registrar_trasplante`, payload);
export const deleteLote = (id) => api.delete(`/lotes/${id}`);
export const getLoteProximoCodigo = () => api.get('/lotes/proximo_codigo')
export const createLoteHeredado = (salaId, lotePayload, diasParams) =>
  api.post(`/salas/${salaId}/lotes`, { lote: lotePayload, heredado: true, ...diasParams })
// Lote cosechado sin sala de cultivo: el backend resuelve la sala de proceso "Cosecha" por sede.
export const createLoteCosechadoEnSede = (sedeId, lotePayload, diasParams) =>
  api.post('/lotes', { lote: lotePayload, heredado: true, sede_id: sedeId, ...diasParams })
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
export const getGeneticaResenas = (id) => api.get(`/geneticas/${id}/resenas`);
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
export const testSmtp          = () => api.post("/preferences/test_smtp");
export const conectarEmail     = (payload) => api.patch("/preferences/conectar_email", payload);
export const desconectarEmail  = () => api.delete("/preferences/desconectar_email");
export const updateTwilio      = (payload) => api.patch("/preferences/update_twilio", payload);
export const destroyTwilio     = () => api.delete("/preferences/destroy_twilio");
export const testTwilio        = () => api.post("/preferences/test_twilio");
export const solicitarWhatsapp = (numero) => api.patch("/preferences/solicitar_whatsapp", { numero });
export const uploadClubLogo    = (file) => {
  const form = new FormData();
  form.append("logo", file);
  return api.post("/preferences/logo", form, { headers: { "Content-Type": "multipart/form-data" } });
};

// -------- PACIENTES --------
export const listPacientes         = (params = {}) => api.get("/pacientes", { params });
export const getPacientesCriticos  = () => api.get("/pacientes/criticos");
export const getPaciente           = (id) => api.get(`/pacientes/${id}`);
export const createPaciente     = (payload) => api.post("/pacientes", { paciente: payload });
export const updatePaciente     = (id, payload) => api.put(`/pacientes/${id}`, { paciente: payload });
export const deletePaciente     = (id) => api.delete(`/pacientes/${id}`);
export const getPacienteTimeline  = (id) => api.get(`/pacientes/${id}/timeline`)
export const getPacienteTurnos    = (id) => api.get(`/pacientes/${id}/turnos`)
export const subirReprocannDoc   = (id, file) => {
  const fd = new FormData()
  fd.append('archivo', file)
  return api.post(`/pacientes/${id}/subir_reprocann`, fd, { headers: { 'Content-Type': 'multipart/form-data' } })
}
export const eliminarReprocannDoc = (id) => api.delete(`/pacientes/${id}/eliminar_reprocann`)

export const enviarMailPaciente  = (id, payload) => api.post(`/pacientes/${id}/enviar_mail`, { mail: payload })
export const getMailsPaciente    = (id)           => api.get(`/pacientes/${id}/mails_enviados`)

export const listReprocannRenovaciones   = (pacienteId) => api.get(`/pacientes/${pacienteId}/reprocann_renovaciones`)
export const createReprocannRenovacion   = (pacienteId, payload) => api.post(`/pacientes/${pacienteId}/reprocann_renovaciones`, payload)
export const updateReprocannRenovacion   = (pacienteId, id, payload) => api.put(`/pacientes/${pacienteId}/reprocann_renovaciones/${id}`, payload)
export const deleteReprocannRenovacion   = (pacienteId, id) => api.delete(`/pacientes/${pacienteId}/reprocann_renovaciones/${id}`)

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
export const registrarPagoCC     = (pacienteId, payload) => api.post(`/pacientes/${pacienteId}/cuenta_corriente/registrar_pago`, payload)
export const setLimiteCC         = (pacienteId, limite)  => api.patch(`/pacientes/${pacienteId}/cuenta_corriente/set_limite`, { limite_credito: limite })

export const exportPacientesCSV  = (params = {}) => api.get('/pacientes/export_csv', { params, responseType: 'blob' })
export const listDispensaciones = (pacienteId, params = {}) => api.get(`/pacientes/${pacienteId}/dispensaciones`, { params });
export const listDispensacionesFecha = (params = {}) => api.get('/dispensaciones', { params });
export const getDispensacion = (id) => api.get(`/dispensaciones/${id}`);
export const createDispensacion = (pacienteId, payload) => api.post(`/pacientes/${pacienteId}/dispensaciones`, { dispensacion: payload });
export const updateDispensacion = (id, payload) => api.put(`/dispensaciones/${id}`, { dispensacion: payload });
export const deleteDispensacion = (id) => api.delete(`/dispensaciones/${id}`);

// ── Reservas de dispensa ────────────────────────────────────────────────────
export const createReserva   = (pacienteId, payload) => api.post(`/pacientes/${pacienteId}/reservas`, { reserva: payload });
export const listReservas    = (params = {})         => api.get('/reservas', { params });
export const listReservasPaciente = (pacienteId)     => api.get(`/pacientes/${pacienteId}/reservas`);
export const entregarReserva = (id, payload = {})    => api.patch(`/reservas/${id}/entregar`, payload);
export const cancelarReserva = (id, motivo = null)   => api.patch(`/reservas/${id}/cancelar`, { motivo });
export const anularSenaReserva = (id)                => api.patch(`/reservas/${id}/anular_sena`);
export const updateReserva   = (id, payload)         => api.patch(`/reservas/${id}`, { reserva: payload });
export const deleteReserva   = (id)                  => api.delete(`/reservas/${id}`);

// ── Delivery ──────────────────────────────────────────────────────────────────
export const exportDispensacionesCSV = (params = {}) => api.get('/dispensaciones/export_csv', { params, responseType: 'blob' })
export const getMisPaquetes   = ()                  => api.get('/dispensaciones/mis_paquetes')
export const iniciarViaje     = (ids)               => api.patch('/dispensaciones/iniciar_viaje', { ids })
// Entrega + cobros del delivery. Si hay fotos (comprobante de pago/entrega), va multipart.
export const entregarPaquete  = (id, { notasEntrega, firmaData, cobros = [], comprobante = null, comprobanteEntrega = null } = {}) => {
  if (comprobante || comprobanteEntrega) {
    const fd = new FormData()
    if (notasEntrega) fd.append('notas_entrega', notasEntrega)
    if (firmaData)    fd.append('firma_entrega_data', firmaData)
    cobros.forEach((c, i) => { fd.append(`cobros[${i}][medio]`, c.medio); fd.append(`cobros[${i}][monto]`, c.monto) })
    if (comprobante)        fd.append('comprobante', comprobante)
    if (comprobanteEntrega) fd.append('comprobante_entrega', comprobanteEntrega)
    return api.patch(`/dispensaciones/${id}/entregar`, fd, { headers: { 'Content-Type': 'multipart/form-data' } })
  }
  return api.patch(`/dispensaciones/${id}/entregar`, { notas_entrega: notasEntrega, firma_entrega_data: firmaData || null, cobros })
}
export const reportarFallo    = (id, motivoFallo)   => api.patch(`/dispensaciones/${id}/reportar_fallo`, { motivo_fallo: motivoFallo })
export const reprogramarPaquete = (id)             => api.patch(`/dispensaciones/${id}/reprogramar`)
export const cancelarEntregaDispensacion = (id, motivo) => api.patch(`/dispensaciones/${id}/cancelar_entrega`, { motivo })
export const listDeliveryUsers  = ()                => api.get('/usuarios', { params: { role: 'delivery' } })
export const listEntregadores   = ()                => api.get('/usuarios', { params: { roles: ['delivery', 'admin', 'supervisor'] } })
export const listDespachos     = (params = {})      => api.get('/dispensaciones', { params: { con_envio: 'true', ...params } })
export const getRutaEntrega    = (params = {})      => api.get('/rutas_entrega', { params })
export const ordenarRuta       = (payload)          => api.post('/rutas_entrega/ordenar', payload)
export const bloquearRuta      = (id, bloqueada)    => api.patch(`/rutas_entrega/${id}/bloqueo`, { bloqueada })
export const reasignarDelivery = (id, deliveryId)  => api.patch(`/dispensaciones/${id}`, { dispensacion: { delivery_id: deliveryId } })

// -------- USUARIOS (equipo del club) --------
export const listUsers         = (params = {}) => api.get('/usuarios', { params });
export const getUser           = (id) => api.get(`/usuarios/${id}`);
export const getUsuarioStats   = (id, params = {}) => api.get(`/usuarios/${id}/stats`, { params });
export const recibirCajaDelivery = (id) => api.post(`/usuarios/${id}/recibir_caja`);

// Convierte un path relativo de ActiveStorage (/rails/active_storage/...) en URL
// absoluta contra el host de la API (front y API pueden estar en hosts distintos).
export const assetUrl = (path) => {
  if (!path) return null
  if (/^https?:\/\//.test(path)) return path
  const base = (import.meta.env.VITE_API_URL || 'http://localhost:3001/api').replace(/\/api\/?$/, '')
  return base + path
}
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
export const getSedesResumenFinanciero = ()  => api.get('/sedes/resumen_financiero')
export const createSede      = (payload)     => api.post('/sedes', { sede: payload })
export const updateSede      = (id, payload) => api.put(`/sedes/${id}`, { sede: payload })
export const deleteSede      = (id)          => api.delete(`/sedes/${id}`)

// Inventario global (sin sede específica)
export const getInventarioPendiente = ()              => api.get('/inventario/pendiente')
export const getStockDisponible     = ()              => api.get('/inventario/disponible')
export const aprobarMovimiento      = (id)            => api.post(`/inventario/aprobar/${id}`)
export const rechazarMovimiento     = (id, motivo)    => api.post(`/inventario/rechazar/${id}`, { motivo })

// ── Manicura ──────────────────────────────────────────────────────────────────
export const asignarManicurador  = (loteId, manicuradorId, params = {}) => api.post(`/lotes/${loteId}/asignar_manicurador`, { manicurador_id: manicuradorId, ...params })

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
export const cerrarPeriodoContable  = (hasta)        => api.post('/movimientos_contables/cerrar_periodo', { hasta })
export const reabrirPeriodoContable = (hasta = null) => api.post('/movimientos_contables/reabrir_periodo', { hasta })

// ── Finanzas · catálogo editable (categorías + unidades de negocio) ────────────
export const listCategoriasContables   = (params = {}) => api.get('/categorias_contables', { params })
export const createCategoriaContable   = (payload)     => api.post('/categorias_contables', { categoria_contable: payload })
export const updateCategoriaContable   = (id, payload) => api.put(`/categorias_contables/${id}`, { categoria_contable: payload })
export const deleteCategoriaContable   = (id)          => api.delete(`/categorias_contables/${id}`)
export const listUnidadesNegocio       = (params = {}) => api.get('/unidades_negocio', { params })
export const createUnidadNegocio       = (payload)     => api.post('/unidades_negocio', { unidad_negocio: payload })
export const updateUnidadNegocio       = (id, payload) => api.put(`/unidades_negocio/${id}`, { unidad_negocio: payload })
export const deleteUnidadNegocio       = (id)          => api.delete(`/unidades_negocio/${id}`)

// ── Finanzas · insumos (depósito + compra/consumo) ─────────────────────────────
export const listInsumos     = (params = {}) => api.get('/insumos', { params })
export const getInsumo       = (id)          => api.get(`/insumos/${id}`)
export const createInsumo    = (payload)     => api.post('/insumos', { insumo: payload })
export const updateInsumo    = (id, payload) => api.put(`/insumos/${id}`, { insumo: payload })
export const comprarInsumo   = (id, payload) => api.post(`/insumos/${id}/comprar`, payload)
export const consumirInsumo  = (id, payload) => api.post(`/insumos/${id}/consumir`, payload)
export const transferirInsumo = (id, payload) => api.post(`/insumos/${id}/transferir`, payload)

// ── Bar · entidad por sede + POS + dashboard ───────────────────────────────────
export const listBares          = ()               => api.get('/bares')
export const getBar             = (id)             => api.get(`/bares/${id}`)
export const createBar          = (payload)        => api.post('/bares', { bar: payload })
export const updateBar          = (id, payload)    => api.put(`/bares/${id}`, { bar: payload })
export const deleteBar          = (id)             => api.delete(`/bares/${id}`)
export const getBarDashboard    = (barId)          => api.get(`/bares/${barId}/dashboard`)
export const listBarProductos   = (barId, params = {}) => api.get(`/bares/${barId}/productos`, { params })
export const createBarProducto  = (barId, payload) => api.post(`/bares/${barId}/productos`, { bar_producto: payload })
export const updateBarProducto  = (barId, id, payload) => api.put(`/bares/${barId}/productos/${id}`, { bar_producto: payload })
export const deleteBarProducto  = (barId, id)      => api.delete(`/bares/${barId}/productos/${id}`)
export const reponerBarProducto = (barId, id, cantidad) => api.post(`/bares/${barId}/productos/${id}/reponer`, { cantidad })
export const comprarBarProducto = (barId, id, payload) => api.post(`/bares/${barId}/productos/${id}/comprar`, payload)
// Provisión + reserva de eventos
export const listProvisiones   = (barId, evId)             => api.get(`/bares/${barId}/eventos/${evId}/provisiones`)
export const upsertProvision   = (barId, evId, payload)    => api.post(`/bares/${barId}/eventos/${evId}/provisiones`, payload)
export const updateProvision   = (barId, evId, id, payload)=> api.patch(`/bares/${barId}/eventos/${evId}/provisiones/${id}`, payload)
export const deleteProvision   = (barId, evId, id)         => api.delete(`/bares/${barId}/eventos/${evId}/provisiones/${id}`)
export const reservarProvision = (barId, evId)             => api.post(`/bares/${barId}/eventos/${evId}/provisiones/reservar`)
export const cerrarProvision   = (barId, evId, payload)    => api.post(`/bares/${barId}/eventos/${evId}/provisiones/cerrar`, payload)
export const ajustarBarProducto = (barId, id, payload) => api.post(`/bares/${barId}/productos/${id}/ajustar`, payload)
export const getBarProductoMovimientos = (barId, id)   => api.get(`/bares/${barId}/productos/${id}/movimientos`)
export const crearBarVenta      = (barId, payload) => api.post(`/bares/${barId}/ventas`, payload)
export const listBarVentas      = (barId)          => api.get(`/bares/${barId}/ventas`)
export const deleteBarVenta     = (barId, id)      => api.delete(`/bares/${barId}/ventas/${id}`)

// ── Bar · caja de turno (apertura / cierre con arqueo) ─────────────────────────
export const getCajaActual      = (barId)          => api.get(`/bares/${barId}/cajas/actual`)
export const listCajas          = (barId)          => api.get(`/bares/${barId}/cajas`)
export const abrirCaja          = (barId, payload) => api.post(`/bares/${barId}/cajas/abrir`, payload)
export const cerrarCaja         = (barId, id, payload) => api.post(`/bares/${barId}/cajas/${id}/cerrar`, payload)

// ── Bar · eventos (proyecto con P&L) ───────────────────────────────────────────
export const listEventosBar    = (barId)             => api.get(`/bares/${barId}/eventos`)
export const getEventoBar      = (barId, id)         => api.get(`/bares/${barId}/eventos/${id}`)
export const createEventoBar   = (barId, payload)    => api.post(`/bares/${barId}/eventos`, { evento_bar: payload })
export const updateEventoBar   = (barId, id, payload) => api.put(`/bares/${barId}/eventos/${id}`, { evento_bar: payload })
export const deleteEventoBar   = (barId, id)         => api.delete(`/bares/${barId}/eventos/${id}`)
export const createEventoCosto = (barId, evId, payload) => api.post(`/bares/${barId}/eventos/${evId}/costos`, { evento_bar_costo: payload })
export const updateEventoCosto = (barId, evId, id, payload) => api.put(`/bares/${barId}/eventos/${evId}/costos/${id}`, { evento_bar_costo: payload })
export const deleteEventoCosto = (barId, evId, id)   => api.delete(`/bares/${barId}/eventos/${evId}/costos/${id}`)
export const createEventoTarea = (barId, evId, payload) => api.post(`/bares/${barId}/eventos/${evId}/tareas`, { evento_bar_tarea: payload })
export const updateEventoTarea = (barId, evId, id, payload) => api.put(`/bares/${barId}/eventos/${evId}/tareas/${id}`, { evento_bar_tarea: payload })
export const deleteEventoTarea = (barId, evId, id)   => api.delete(`/bares/${barId}/eventos/${evId}/tareas/${id}`)
export const createTipoEntrada = (barId, evId, payload)       => api.post(`/bares/${barId}/eventos/${evId}/tipos_entrada`, { evento_bar_tipo_entrada: payload })
export const updateTipoEntrada = (barId, evId, id, payload)   => api.put(`/bares/${barId}/eventos/${evId}/tipos_entrada/${id}`, { evento_bar_tipo_entrada: payload })
export const deleteTipoEntrada = (barId, evId, id)            => api.delete(`/bares/${barId}/eventos/${evId}/tipos_entrada/${id}`)
export const venderEntradas    = (barId, evId, tipoId, payload) => api.post(`/bares/${barId}/eventos/${evId}/tipos_entrada/${tipoId}/vender`, payload)
export const listEntradas      = (barId, evId)                => api.get(`/bares/${barId}/eventos/${evId}/entradas`)
export const anularEntrada     = (barId, evId, id)            => api.delete(`/bares/${barId}/eventos/${evId}/entradas/${id}`)
export const getPuertaEstado   = (barId, evId)                => api.get(`/bares/${barId}/eventos/${evId}/puerta`)
export const checkinEntrada    = (barId, evId, codigo)        => api.post(`/bares/${barId}/eventos/${evId}/puerta/checkin`, { codigo })
export const revertirCheckin   = (barId, evId, codigo)        => api.post(`/bares/${barId}/eventos/${evId}/puerta/revertir`, { codigo })

// ── Finanzas · reporte consolidado ─────────────────────────────────────────────
export const getReporteFinanzas    = (params = {}) => api.get('/finanzas/reporte', { params })
export const exportReporteFinanzas = (params = {}) => api.get('/finanzas/reporte/export', { params, responseType: 'blob' })

export const getAmbienteSalas       = ()             => api.get('/stats/ambiente_salas')
export const listComprasCuotas      = ()             => api.get('/compras_cuotas')
export const createCompraCuotas     = (payload)      => api.post('/compras_cuotas', { compra_cuotas: payload })
export const updateCompraCuotas     = (id, payload)  => api.patch(`/compras_cuotas/${id}`, { compra_cuotas: payload })
export const deleteCompraCuotas     = (id)           => api.delete(`/compras_cuotas/${id}`)
export const exportLotesCSV         = (params = {})  => api.get('/lotes/export_csv', { params, responseType: 'blob' })

// ── Costo por lote ────────────────────────────────────────────────────────────
export const getCostoLote    = (loteId)           => api.get(`/lotes/${loteId}/costo`)
export const createCostoLote = (loteId, payload)  => api.post(`/lotes/${loteId}/costo`, { costo_lote: payload })
export const updateCostoLote = (loteId, payload)  => api.put(`/lotes/${loteId}/costo`, { costo_lote: payload })
export const recalcularCostoLote = (loteId)       => api.post(`/lotes/${loteId}/costo/recalcular`)

// ── Informe semestral REPROCANN ───────────────────────────────────────────────
export const getInformeSemestral = (params = {}) => api.get('/informe_semestral', { params })

// ── Tareas ──────────────────────────────────────────────────────────

export const listTareas        = (params = {}) => api.get('/tareas', { params })
export const getTareasDashboard = ()            => api.get('/tareas/dashboard')

// ── Jornadas laborales (planilla de horas) ──
export const listJornadas   = (params = {})      => api.get('/jornadas', { params })
export const createJornada  = (jornada)          => api.post('/jornadas', { jornada })
export const updateJornada  = (id, jornada)      => api.patch(`/jornadas/${id}`, { jornada })
export const deleteJornada  = (id)               => api.delete(`/jornadas/${id}`)
export const getTarea          = (id)           => api.get(`/tareas/${id}`)
export const createTarea       = (payload)      => api.post('/tareas', { tarea: payload })
export const updateTarea       = (id, payload)  => api.patch(`/tareas/${id}`, { tarea: payload })
export const deleteTarea       = (id)           => api.delete(`/tareas/${id}`)
export const iniciarTarea      = (id)           => api.post(`/tareas/${id}/iniciar`)
export const completarTarea    = (id, data)     => api.post(`/tareas/${id}/completar`, data)
export const completarTareasMasivo = (ids)      => api.post('/tareas/completar_masivo', { ids })
export const cancelarTarea     = (id)           => api.post(`/tareas/${id}/cancelar`)
export const getTareasSemana    = (desde)        => api.get('/tareas/semana', { params: { desde } })
export const cancelarSerieTarea = (id)           => api.delete(`/tareas/${id}/cancelar_serie`)
export const getHistorial       = (params = {})  => api.get('/historial', { params })

// ── Plan de Trabajo ──────────────────────────────────────────
export const listPlanTrabajos         = (params = {})         => api.get('/plan_trabajos', { params })
export const getPlanTrabajo           = (id)                  => api.get(`/plan_trabajos/${id}`)
export const getPlanTrabajoActivo     = ()                    => api.get('/plan_trabajos/activo')
export const createPlanTrabajo        = (data)                => api.post('/plan_trabajos', data)
export const updatePlanTrabajo        = (id, data)            => api.patch(`/plan_trabajos/${id}`, data)
export const deletePlanTrabajo        = (id)                  => api.delete(`/plan_trabajos/${id}`)
export const publicarPlanTrabajo      = (id)                  => api.post(`/plan_trabajos/${id}/publicar`)
export const archivarPlanTrabajo      = (id)                  => api.post(`/plan_trabajos/${id}/archivar`)
export const interpretarArchivoPlan   = (formData)            => api.post('/plan_trabajos/interpretar_archivo', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
export const exportPlanCSV            = (id, params = {})     => api.get(`/plan_trabajos/${id}/export_csv`, { params, responseType: 'blob' })
export const listPlanTareas           = (planId)              => api.get(`/plan_trabajos/${planId}/plan_tareas`)
export const createPlanTarea          = (planId, data)        => api.post(`/plan_trabajos/${planId}/plan_tareas`, { plan_tarea: data })
export const updatePlanTarea          = (planId, tid, data, scope = 'esta') => api.patch(`/plan_trabajos/${planId}/plan_tareas/${tid}`, { plan_tarea: data, scope })
export const deletePlanTarea          = (planId, tid)         => api.delete(`/plan_trabajos/${planId}/plan_tareas/${tid}`)

// ── Aplicaciones de plantillas ────────────────────────────────
export const listAplicaciones         = (params = {})         => api.get('/aplicacion_planes', { params })
export const getAplicacion            = (id)                  => api.get(`/aplicacion_planes/${id}`)
export const createAplicacion         = (data)                => api.post('/aplicacion_planes', data)
export const cancelarAplicacion       = (id)                  => api.post(`/aplicacion_planes/${id}/cancelar`)
export const deleteAplicacion         = (id)                  => api.delete(`/aplicacion_planes/${id}`)

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
export const getSalaAmbiente          = (salaId, params = {}) => api.get(`/salas/${salaId}/ambiente`, { params })
export const getSalaAmbienteHistorico = (salaId, params = {}) => api.get(`/salas/${salaId}/historico`, { params })
export const getSalaAlertas           = (salaId)              => api.get(`/salas/${salaId}/alertas`)
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
export const updateLoteEvento  = (loteId, eventoId, payload) => api.patch(`/lotes/${loteId}/lote_eventos/${eventoId}`, { lote_evento: payload })
export const deleteLoteEvento  = (loteId, eventoId) => api.delete(`/lotes/${loteId}/lote_eventos/${eventoId}`)
export const cosecharPlantas   = (loteId, payload)  => api.post(`/lotes/${loteId}/cosechar_plantas`, payload)

export const getLoteFotos    = (loteId)          => api.get(`/lotes/${loteId}/fotos`)
export const uploadFotoLote  = (loteId, formData) => api.post(`/lotes/${loteId}/fotos`, formData, { headers: { 'Content-Type': 'multipart/form-data' } })
export const deleteFotoLote  = (loteId, fotoId)   => api.delete(`/lotes/${loteId}/fotos/${fotoId}`)
export const setFotoPortadaLote = (loteId, fotoId) => api.patch(`/lotes/${loteId}/fotos/${fotoId}/portada`)

// ── Super Admin ──────────────────────────────────────────────────────
export const getSuperAdminStats  = ()             => api.get('/super_admin/stats')
export const listSuperAdminClubs = ()             => api.get('/super_admin/clubs')
export const getSuperAdminClub   = (id)           => api.get(`/super_admin/clubs/${id}`)
export const createSuperAdminClub = (payload)     => api.post('/super_admin/clubs', payload)
export const updateSuperAdminClub = (id, payload) => api.put(`/super_admin/clubs/${id}`, { club: payload })
export const cambiarPlanClub     = (id, payload)  => api.patch(`/super_admin/clubs/${id}/cambiar_plan`, payload)
export const crearUsuariosDefault = (id)          => api.post(`/super_admin/clubs/${id}/crear_usuarios_default`)
export const eliminarClub        = (id)           => api.delete(`/super_admin/clubs/${id}`)
export const restaurarClub       = (id)           => api.patch(`/super_admin/clubs/${id}/restaurar`)
export const provisionarWhatsappClub = (id, payload) => api.patch(`/super_admin/clubs/${id}/provisionar_whatsapp`, payload)
export const desconectarWhatsappClub = (id)          => api.delete(`/super_admin/clubs/${id}/desconectar_whatsapp`)
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

export const addPlantFoto       = (plantId, formData) => api.post(`/plants/${plantId}/add_foto`, formData, { headers: { 'Content-Type': 'multipart/form-data' } })
export const removePlantFoto    = (plantId, blobId)   => api.delete(`/plants/${plantId}/fotos/${blobId}`)
export const registrarPesoPlanta      = (plantId, payload) => api.post(`/plants/${plantId}/registrar_peso`, payload)

export const getPlantaByQR = (codigoQr) => api.get(`/p/${codigoQr}`)
// Resuelve una planta por QR vía la instancia api autenticada (igual que getLotePorQR).
export const getPlantaPorQR = (codigoQr) => api.get(`/plants/por_qr/${codigoQr}`)

// ── Lote ciclo productivo ─────────────────────────────────────────────────────
export const transicionarLote  = (loteId, payload) => api.post(`/lotes/${loteId}/transiciones`, payload)
export const avanzarFaseLote   = (loteId, payload = {}) => api.post(`/lotes/${loteId}/avanzar_fase`, payload)
export const getLoteTimeline  = (loteId)          => api.get(`/lotes/${loteId}/timeline`)
export const getLoteHistorial = (loteId)          => api.get(`/lotes/${loteId}/historial`)
export const previewLotePlan  = (loteId, planId, fechaInicio)  => api.get(`/lotes/${loteId}/preview_plan`, { params: { plan_trabajo_id: planId, fecha_inicio: fechaInicio || undefined } })
export const aplicarLotePlan  = (loteId, planId, fechaInicio)  => api.post(`/lotes/${loteId}/aplicar_plan`, { plan_trabajo_id: planId, fecha_inicio: fechaInicio || undefined })

// ── Pesadas ───────────────────────────────────────────────────────────────────
export const getPesadas     = (loteId)          => api.get(`/lotes/${loteId}/pesadas`)
export const createPesada   = (loteId, payload) => api.post(`/lotes/${loteId}/pesadas`, { pesada: payload })
export const deletePesada   = (loteId, id)      => api.delete(`/lotes/${loteId}/pesadas/${id}`)

export const listAnalisisLaboratorio   = (loteId)          => api.get(`/lotes/${loteId}/analisis_laboratorio`)
export const createAnalisisLaboratorio = (loteId, payload) => api.post(`/lotes/${loteId}/analisis_laboratorio`, { analisis_laboratorio: payload })
export const deleteAnalisisLaboratorio = (loteId, id)      => api.delete(`/lotes/${loteId}/analisis_laboratorio/${id}`)

// ── Pesajes Manicura ──────────────────────────────────────────────────────────
export const listPesajesManicura      = (loteId)           => api.get(`/lotes/${loteId}/pesajes_manicura`)
export const getPesajeManicura        = (loteId, id)       => api.get(`/lotes/${loteId}/pesajes_manicura/${id}`)
export const createPesajeManicura     = (loteId, payload = {}) => api.post(`/lotes/${loteId}/pesajes_manicura`, payload)
export const registrarDirectoManicura = (loteId, payload = {}) => api.post(`/lotes/${loteId}/pesajes_manicura/registrar_directo`, payload)
export const enviarPesajeManicura     = (loteId, id)       => api.post(`/lotes/${loteId}/pesajes_manicura/${id}/enviar`)
export const deletePesajeManicura      = (loteId, id)       => api.delete(`/lotes/${loteId}/pesajes_manicura/${id}`)
export const reabrirPesajeManicura     = (loteId, id)       => api.post(`/lotes/${loteId}/pesajes_manicura/${id}/reabrir`)
export const confirmarPesajeManicura  = (loteId, id, payload) => api.post(`/lotes/${loteId}/pesajes_manicura/${id}/confirmar`, payload)
export const reajustarPesoPesajeManicura = (loteId, id, peso) => api.patch(`/lotes/${loteId}/pesajes_manicura/${id}/reajustar_peso`, { peso_confirmado_g: peso })
export const listPesajesManicuraAdmin = (params = {})      => api.get('/pesajes_manicura', { params })

// ── Lecturas ambientales ──────────────────────────────────────────────────────
export const createLecturaAmbiental = (salaId, payload) => api.post(`/salas/${salaId}/lecturas_ambientales`, { lectura_ambiental: payload })

export const aiImportCsvSala = (salaId, file) => {
  const form = new FormData()
  form.append('csv_file', file)
  return api.post(`/salas/${salaId}/ai_import`, form, { headers: { 'Content-Type': 'multipart/form-data' } })
}

// ── Stocks (nuevo modelo) ─────────────────────────────────────────────────────
export const listStocks           = (params = {})         => api.get('/stocks', { params })
export const listStocksPendientes = ()                    => api.get('/stocks', { params: { pendientes: true } })
export const listStocksHistorial  = (params = {})         => api.get('/stocks', { params: { historial: true, ...params } })
export const listStockInventario  = (params = {})         => api.get('/stocks/inventario', { params })
export const getStock             = (id)                  => api.get(`/stocks/${id}`)
export const createStock          = (payload)             => api.post('/stocks', { stock: payload })
export const updateStock          = (id, payload)         => api.patch(`/stocks/${id}`, { stock: payload })
export const asignarStock         = (id, payload)         => api.post(`/stocks/${id}/asignar`, payload)
export const ajustarStock         = (id, payload)         => api.post(`/stocks/${id}/ajuste`, payload)
export const descartarStock       = (id, payload)         => api.post(`/stocks/${id}/descartar`, payload)
export const producirStock        = (id, payload)         => api.post(`/stocks/${id}/producir`, payload)
export const deleteStock          = (id)                  => api.delete(`/stocks/${id}`)
export const getStockMovimientos  = (id)                  => api.get(`/stocks/${id}/movimientos`)
export const getSedeStocks        = (sedeId, params = {}) => api.get(`/sedes/${sedeId}/stocks`, { params })
export const getStockTrazabilidad = (id)                  => api.get(`/stocks/${id}/trazabilidad`)

// ── ARICCAME ──────────────────────────────────────────────────────────────────
export const listAriccameRegistros = (params = {}) => api.get('/ariccame_registros', { params })
export const getAriccameRegistro   = (id)          => api.get(`/ariccame_registros/${id}`)
export const reenviarAriccame      = (id)          => api.post(`/ariccame_registros/${id}/reenviar`)
export const transmitirPendientesAriccame = ()     => api.post('/ariccame_registros/transmitir_pendientes')

// Papelera (historial de borrados / restauración)
export const getPapelera        = (params = {})    => api.get('/papelera', { params })
export const restaurarPapelera  = (tipo, id)       => api.post('/papelera/restaurar', { tipo, id })

// ── Público — QR stocks ───────────────────────────────────────────────────────
export const getStockPublico  = (codigoQr) => axios.get(`/s/${codigoQr}`)
export const getStockByQR     = (codigoQr) => api.get(`/stocks/qr/${codigoQr}`)

// ── Analytics ─────────────────────────────────────────────────────────────────
export const getAnalyticsRendimiento      = (params = {}) => api.get('/analytics/rendimiento_genetica',   { params })
export const getAnalyticsDispensador      = ()            => api.get('/analytics/dispensador')
export const getAnalyticsProduccion       = (params = {}) => api.get('/analytics/produccion',              { params })
export const getAnalyticsCorrelacion      = (params = {}) => api.get('/analytics/correlacion_ambiental',   { params })
export const getAnalyticsPL               = ()            => api.get('/analytics/pl_lotes')
export const getAnalyticsEjecutivo        = ()            => api.get('/analytics/ejecutivo')
export const getAnalyticsComparativaSalas = ()            => api.get('/analytics/comparativa_salas')
export const getAnalyticsContabilidad     = ()            => api.get('/analytics/contabilidad')
export const getAnalyticsCostoPorGramoSede = ()           => api.get('/analytics/costo_por_gramo_sede')
export const getLotePL                    = (id)          => api.get(`/lotes/${id}/pl`)

// ── Alertas internas ──────────────────────────────────────────────────────────
export const getAlertasInternas       = (params = {}) => api.get('/alertas_internas', { params })
export const marcarAlertaInterna      = (id)          => api.patch(`/alertas_internas/${id}/marcar_leida`)
export const marcarTodasAlertasLeidas = ()            => api.patch('/alertas_internas/marcar_todas_leidas')

// ── Asistente IA ──────────────────────────────────────────────────────────────
export const parsearAsistente  = (texto, contexto)  => api.post('/asistente/parsear',       { texto, contexto })
export const ejecutarAsistente = (acciones, contexto) => api.post('/asistente/ejecutar',    { acciones, contexto })
export const consultarAsistente = (texto, contexto) => api.post('/asistente/consultar',     { texto, contexto })
export const analizarLote          = (lote_id) => api.post('/asistente/analizar_lote',       { lote_id })
export const getHistorialAnalisis  = (lote_id) => api.get('/asistente/historial_analisis',  { params: { lote_id } })

// ── Carnet público ────────────────────────────────────────────────────────────
export const getCarnetPublico = (token) => axios.get(`/api/c/${token}`)

// ── Médico — Ficha clínica ────────────────────────────────────────────────────
export const getMedicoPacientes  = ()         => api.get('/medico/pacientes')
export const getMedicoFicha      = (id)        => api.get(`/medico/pacientes/${id}/ficha`)
export const getMedicoTurnos     = ()          => api.get('/medico/turnos')
export const createMedicoTurno   = (payload)   => api.post('/medico/turnos',      { turno: payload })
export const updateMedicoTurno   = (id, payload) => api.patch(`/medico/turnos/${id}`, { turno: payload })
export const deleteMedicoTurno   = (id)        => api.delete(`/medico/turnos/${id}`)
export const createCheckIn            = (payload)   => api.post('/medico/check_ins', { check_in: payload })
export const getMedicoDisponibilidad  = ()           => api.get('/medico/disponibilidad')
export const saveMedicoDisponibilidad = (slots)      => api.put('/medico/disponibilidad', { disponibilidad: slots })

// ── Admin — Médicos ───────────────────────────────────────────────────────────
export const getAdminMedicos              = ()        => api.get('/admin/medicos')
export const getAdminMedicoDisponibilidad = (id)      => api.get(`/admin/medicos/${id}/disponibilidad`)
export const getAdminMedicoTurnos         = (id)      => api.get(`/admin/medicos/${id}/turnos`)
export const createAdminTurno             = (id, payload) => api.post(`/admin/medicos/${id}/crear_turno`, { turno: payload })
export const updateAdminTurno             = (id, payload) => api.patch(`/admin/turnos/${id}`, { turno: payload })
export const deleteAdminTurno             = (id)      => api.delete(`/admin/turnos/${id}`)

export default api;
