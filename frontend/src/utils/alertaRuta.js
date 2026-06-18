import {
  Scissors, Clock, CheckCircle, XCircle,
  AlertTriangle, Zap, AlertCircle, Thermometer,
  Calendar, ClipboardCheck, ShieldAlert,
  Package, Scale, FileHeart, FileText, FileCheck,
  UserPlus, Bell, Wind,
} from 'lucide-vue-next'

// ─── Navigation ──────────────────────────────────────────────────────────────

export function resolverRutaAlerta(tipo, contexto = {}) {
  const c = contexto || {}

  switch (tipo) {
    case 'manicura_asignada':
    case 'manicura_aprobacion_pendiente':
    case 'manicura_aprobada':
    case 'manicura_rechazada':
    case 'manicura_eliminada':
    case 'manicura_reabierta':
      return c.lote_id ? `/lotes/${c.lote_id}` : null

    case 'sin_registro_ambiental':
    case 'cosecha_pendiente':
    case 'estado_critico_lote':
      return c.lote_id ? `/lotes/${c.lote_id}` : null

    case 'ph_fuera_rango':
    case 'ec_fuera_rango':
    case 'temperatura_fuera_rango':
    case 'humedad_fuera_rango':
      if (c.sala_id) return `/salas/${c.sala_id}/ambiente`
      return c.lote_id ? `/lotes/${c.lote_id}` : null

    case 'tarea_vencida_cultivo':
      return '/tareas'

    case 'stock_bajo':
      return '/sedes'

    case 'saldo_cc_bajo':
    case 'saldo_gramos_bajo':
    case 'documento_vencido':
    case 'reprocann_vencido':
    case 'reprocann_por_vencer':
    case 'indicacion_vencida':
    case 'indicacion_por_vencer':
    case 'paciente_creado_por_dispensador':
      return c.paciente_id ? `/pacientes/${c.paciente_id}` : '/pacientes'

    default:
      return null
  }
}

// ─── Labels ──────────────────────────────────────────────────────────────────

const TIPO_LABELS = {
  manicura_asignada:               'Manicura asignada',
  manicura_aprobacion_pendiente:   'Aprobación pendiente',
  manicura_aprobada:               'Manicura aprobada',
  manicura_rechazada:              'Manicura rechazada',
  sin_registro_ambiental:          'Sin registro ambiental',
  ph_fuera_rango:                  'pH fuera de rango',
  ec_fuera_rango:                  'EC fuera de rango',
  temperatura_fuera_rango:         'Temperatura fuera de rango',
  humedad_fuera_rango:             'Humedad fuera de rango',
  cosecha_pendiente:               'Cosecha pendiente',
  tarea_vencida_cultivo:           'Tarea vencida',
  estado_critico_lote:             'Estado crítico en lote',
  stock_bajo:                      'Stock bajo',
  saldo_cc_bajo:                   'Saldo CC bajo',
  saldo_gramos_bajo:               'Crédito gramos bajo',
  documento_vencido:               'Documento vencido',
  reprocann_vencido:               'REPROCANN vencido',
  reprocann_por_vencer:            'REPROCANN por vencer',
  indicacion_vencida:              'Indicación médica vencida',
  indicacion_por_vencer:           'Indicación por vencer',
  paciente_creado_por_dispensador: 'Nuevo paciente',
  otro:                            'Notificación',
}

export function tipoLabel(tipo) {
  return TIPO_LABELS[tipo] || tipo
}

// ─── Icon + color per tipo ────────────────────────────────────────────────────

const META = {
  manicura_asignada:               { component: Scissors,      bg: '#f0fdf4', color: '#16a34a' },
  manicura_aprobacion_pendiente:   { component: Clock,         bg: '#fffbeb', color: '#d97706' },
  manicura_aprobada:               { component: CheckCircle,   bg: '#f0fdf4', color: '#16a34a' },
  manicura_rechazada:              { component: XCircle,       bg: '#fef2f2', color: '#dc2626' },
  sin_registro_ambiental:          { component: Wind,          bg: '#f8fafc', color: '#64748b' },
  ph_fuera_rango:                  { component: AlertTriangle, bg: '#fffbeb', color: '#d97706' },
  ec_fuera_rango:                  { component: Zap,           bg: '#fffbeb', color: '#d97706' },
  temperatura_fuera_rango:         { component: Thermometer,   bg: '#fef2f2', color: '#dc2626' },
  humedad_fuera_rango:             { component: AlertCircle,   bg: '#eff6ff', color: '#2563eb' },
  cosecha_pendiente:               { component: Calendar,      bg: '#f0fdf4', color: '#16a34a' },
  tarea_vencida_cultivo:           { component: ClipboardCheck,bg: '#fef2f2', color: '#dc2626' },
  estado_critico_lote:             { component: ShieldAlert,   bg: '#fef2f2', color: '#dc2626' },
  stock_bajo:                      { component: Package,       bg: '#fffbeb', color: '#d97706' },
  saldo_cc_bajo:                   { component: Scale,         bg: '#fffbeb', color: '#d97706' },
  saldo_gramos_bajo:               { component: Scale,         bg: '#fffbeb', color: '#d97706' },
  documento_vencido:               { component: FileText,      bg: '#fef2f2', color: '#dc2626' },
  reprocann_vencido:               { component: FileCheck,     bg: '#fef2f2', color: '#dc2626' },
  reprocann_por_vencer:            { component: FileCheck,     bg: '#fffbeb', color: '#d97706' },
  indicacion_vencida:              { component: FileHeart,     bg: '#fef2f2', color: '#dc2626' },
  indicacion_por_vencer:           { component: FileHeart,     bg: '#fffbeb', color: '#d97706' },
  paciente_creado_por_dispensador: { component: UserPlus,      bg: '#f0fdf4', color: '#16a34a' },
  otro:                            { component: Bell,          bg: '#f8fafc', color: '#64748b' },
}

export function tipoMeta(tipo) {
  return META[tipo] || META.otro
}
