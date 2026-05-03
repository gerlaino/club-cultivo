export const ROLES = [
  { value: 'admin',       label: 'Admin',       color: '#dc2626', bg: 'rgba(220,38,38,.1)',    icon: 'bi-shield-fill-check'   },
  { value: 'medico',      label: 'Médico',       color: '#15803d', bg: 'rgba(21,128,61,.1)',    icon: 'bi-heart-pulse-fill'    },
  { value: 'cultivador',  label: 'Cultivador',   color: '#0891b2', bg: 'rgba(8,145,178,.1)',    icon: 'bi-flower1'             },
  { value: 'dispensador', label: 'Dispensador',  color: '#0891b2', bg: 'rgba(8,145,178,.08)',   icon: 'bi-bag-check-fill'      },
  { value: 'manicura',    label: 'Manicura',     color: '#7c3aed', bg: 'rgba(124,58,237,.1)',   icon: 'bi-scissors'            },
  { value: 'delivery',    label: 'Delivery',     color: '#f59e0b', bg: 'rgba(245,158,11,.1)',   icon: 'bi-bicycle'             },
  { value: 'abogado',     label: 'Abogado',      color: '#92400e', bg: 'rgba(146,64,14,.1)',    icon: 'bi-briefcase-fill'      },
  { value: 'auditor',     label: 'Auditor',      color: '#475569', bg: 'rgba(71,85,105,.1)',    icon: 'bi-clipboard-data-fill' },
  { value: 'paciente',    label: 'Paciente',     color: '#0369a1', bg: 'rgba(3,105,161,.1)',    icon: 'bi-person-heart'        },
  { value: 'super_admin', label: 'Super admin',  color: '#0f172a', bg: 'rgba(15,23,42,.08)',    icon: 'bi-star-fill'           },
]

export const roleLabel = (value) => ROLES.find(r => r.value === value)?.label ?? value

export const roleMeta  = (value) => ROLES.find(r => r.value === value)
  ?? { value, label: value, color: '#475569', bg: 'rgba(71,85,105,.1)', icon: 'bi-person' }
