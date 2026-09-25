import { describe, it, expect, vi } from 'vitest'

vi.mock('../stores/auth', () => ({ useAuthStore: () => ({ user: null, isAuthenticated: false }) }))
vi.mock('../composables/useToast', () => ({ useToast: () => ({ warning: vi.fn() }) }))
vi.mock('../composables/usePermissions', () => ({ usePermissions: () => ({ can: () => true }) }))

const { lineasDeReceta, avisoAlPlantar, textoProximoPaso, reglasSueloVivo } = await import('../lib/camas.js')
const { puedeEntrar } = await import('../router/index.js')

// SUELO VIVO (Germán, 22/25-sep-2026; docs/PLAN_SUELO_VIVO.md). Lo que la pantalla muestra lo
// calcula el backend; estos tests fijan que la pantalla lo diga igual y no invente.

describe('la cuenta de una receta usa la unidad del insumo (la manda el backend)', () => {
  // AC: la harina se compra en bolsas de kg y la receta dice g/m². Sin convertir, un top dress de
  // 100 g/m² en 1,44 m² descontaba 144 KG.
  const topDress = { items: [{ insumo_id: 1, nombre: 'Harina de kelp', dosis: '100', unidad_label: 'g/m²', unidad_insumo: 'kilogramo', stock_actual: '10', factor: 0.001 }] }

  it('100 g/m² en 1,44 m² son 0,144 kg, no 144', () => {
    const [l] = lineasDeReceta(topDress, 1.44)
    expect(l.cantidad).toBe(0.144)
    expect(l.faltante).toBe(0)
  })

  it('si no alcanza lo que hay, dice cuánto falta (y no bloquea: eso lo decide quien carga)', () => {
    const [l] = lineasDeReceta(topDress, 100) // 10 kg pedidos… hay 10: justo
    expect(l.faltante).toBe(0)
    const [m] = lineasDeReceta(topDress, 150) // 15 kg
    expect(m.faltante).toBe(5)
    expect(m.modo_faltante).toBe('descontar_disponible')
  })

  it('una cantidad corregida a mano gana sobre la calculada', () => {
    const [l] = lineasDeReceta(topDress, 1.44, [{ insumo_id: 1, cantidad: 0.2 }])
    expect(l.cantidad).toBe(0.2)
  })

  it('sin factor (misma unidad) multiplica derecho', () => {
    const [l] = lineasDeReceta({ items: [{ insumo_id: 2, nombre: 'Té', dosis: 2, unidad_insumo: 'mililitro', stock_actual: 1000 }] }, 20)
    expect(l.cantidad).toBe(40)
  })
})

describe('plantar en una cama que descansa o se cocina avisa, no bloquea', () => {
  it('descansando con fecha: dice hasta cuándo y que plantar corta el descanso', () => {
    const t = avisoAlPlantar({ nombre: 'Cama A', estado: 'descansando', proximo_paso: { tipo: 'fin_descanso', fecha: '2026-11-15', faltan_dias: 12 } })
    expect(t).toContain('La Cama A descansa hasta el')
    expect(t).toContain('faltan 12 días')
    expect(t).toContain('Plantar corta el descanso')
  })

  it('descansando sin fecha (el cultivador no cargó días): igual avisa', () => {
    expect(avisoAlPlantar({ nombre: 'Cama B', estado: 'descansando', proximo_paso: { tipo: 'descansando', lleva_dias: 4 } }))
      .toBe('La Cama B está descansando. Plantar corta el descanso.')
  })

  it('cocinándose: avisa que puede quemar las raíces', () => {
    expect(avisoAlPlantar({ nombre: 'Cama A', estado: 'cocinando', cocina_hasta: '2026-10-12' })).toContain('puede quemar las raíces')
  })

  it('lista o en uso: no hay nada que avisar', () => {
    expect(avisoAlPlantar({ nombre: 'Cama A', estado: 'lista' })).toBeNull()
    expect(avisoAlPlantar({ nombre: 'Cama A', estado: 'en_uso' })).toBeNull()
  })
})

describe('el «qué viene» de la cama', () => {
  it('top dress vencido se marca como alerta', () => {
    const t = textoProximoPaso({ tipo: 'top_dress', fecha: '2026-09-20', faltan_dias: -3 })
    expect(t.alerta).toBe(true)
    expect(t.texto).toContain('Toca top dress')
  })

  it('sin paso (sin números del cultivador) no dice nada', () => {
    expect(textoProximoPaso(null)).toBeNull()
  })
})

describe('las reglas vienen del backend (y hay un respaldo para no quedar en blanco)', () => {
  it('sin /me cargado, el respaldo tiene los tres usos y sus unidades', () => {
    const r = reglasSueloVivo()
    expect(r.usos_receta).toEqual(['riego', 'top_dress', 'mezcla'])
    expect(r.unidades_por_uso.top_dress).toEqual(['g_m2', 'ml_m2'])
  })
})

describe('la ficha de la cama es de quien cultiva', () => {
  it('cultivador y supervisor pueden abrir /camas/:id; dispensador no', () => {
    expect(puedeEntrar('cultivador', '/camas/12')).toBe(true)
    expect(puedeEntrar('supervisor', '/camas/12')).toBe(true)
    expect(puedeEntrar('dispensador', '/camas/12')).toBe(false)
    expect(puedeEntrar('manicura', '/camas/12')).toBe(false)
  })
})
