import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createRouter, createMemoryHistory } from 'vue-router'
import { setActivePinia, createPinia } from 'pinia'

// AC: el portal del paciente es un portal CLÍNICO. Lo primero que ve es si puede retirar, y
// después lo suyo que viene; el boletín de la organización va al final.
//
// Estos tests MONTAN las pantallas de verdad. El build compila una variable inexistente sin
// chistar y la pantalla explota recién al abrirse —ya pasó cuatro veces en este proyecto—, así que
// lo que se verifica acá es el render, no la compilación: que salga el texto que el paciente lee.

const api = vi.hoisted(() => ({
  getPortalMiEstado: vi.fn(),
  getPortalMiSalud: vi.fn(),
  getPortalCuentaCorriente: vi.fn(),
  getPortalHistorial: vi.fn(),
  getPortalNoticias: vi.fn(),
  getPortalEventos: vi.fn(),
  getPortalGeneticas: vi.fn(),
  getPortalClub: vi.fn(),
}))
vi.mock('@/lib/portalApi', () => api)
vi.mock('../lib/portalApi', () => api)

import PortalHomeView from '../views/portal/PortalHomeView.vue'
import PortalMiSaludView from '../views/portal/PortalMiSaludView.vue'
import PortalDelClubView from '../views/portal/PortalDelClubView.vue'
import PortalCredencial from '../components/portal/PortalCredencial.vue'
import { usePortalClubStore } from '../stores/portalClub'
import PortalNavBar from '../components/portal/PortalNavBar.vue'
import PortalFooter from '../components/portal/PortalFooter.vue'
import PortalAvisos from '../components/portal/PortalAvisos.vue'

const router = createRouter({
  history: createMemoryHistory(),
  routes: [{ path: '/:pathMatch(.*)*', component: { template: '<div/>' } }],
})

const montar = (comp, props = {}) =>
  mount(comp, { props, global: { plugins: [router] } })

const CREDENCIAL = {
  nombre: 'Juan', apellido: 'Gómez', dni: '30111222', numero_socio: 42,
  carnet_token: 'tok-abc', reprocann_numero: 'RP-9',
  reprocann_vencimiento: '2027-03-10', reprocann_categoria: 'vigente',
  dias_para_vencer: 200, habilitado: true,
}

beforeEach(() => {
  setActivePinia(createPinia())
  api.getPortalMiEstado.mockResolvedValue({ credencial: CREDENCIAL, avisos: [] })
  api.getPortalMiSalud.mockResolvedValue({ tiene_modulo: true, proximo_turno: null, turnos: [], indicacion: null })
  api.getPortalCuentaCorriente.mockResolvedValue({ tiene: false })
  api.getPortalHistorial.mockResolvedValue([])
  api.getPortalNoticias.mockResolvedValue([])
  api.getPortalEventos.mockResolvedValue([])
  api.getPortalGeneticas.mockResolvedValue([])
  api.getPortalClub.mockResolvedValue({ name: 'Club Verde' })
})

// La ficha de la organización la pide el shell UNA vez y la comparten la barra y el pie. En un
// test que monta el pie solo, hay que sembrarla.
const conClub = (datos) => { usePortalClubStore().club = datos }

describe('La credencial', () => {
  it('muestra el nombre, el DNI y el número de socio', () => {
    const w = montar(PortalCredencial, { credencial: CREDENCIAL })

    expect(w.text()).toContain('Juan Gómez')
    expect(w.text()).toContain('30111222')
    expect(w.text()).toContain('42')
  })

  // Lo que el paciente vino a saber no es "vigente": es si puede retirar. El texto lo dice así.
  it('con el REPROCANN vigente dice que puede retirar, y hasta cuándo', () => {
    const w = montar(PortalCredencial, { credencial: CREDENCIAL })

    expect(w.text()).toContain('Podés retirar')
    expect(w.text()).toContain('10 de marzo de 2027')
  })

  it('vencido lo dice con lo que le cambia, no con la palabra "vencido" sola', () => {
    const w = montar(PortalCredencial, {
      credencial: { ...CREDENCIAL, reprocann_categoria: 'vencido', habilitado: false,
                    reprocann_vencimiento: '2026-07-01', dias_para_vencer: -49 },
    })

    expect(w.text()).toContain('No podés retirar')
    expect(w.text()).toContain('Renovalo')
    // La tarjeta entera cambia de color: es el único estado que impide retirar, y con un puntito
    // distinto no se ve.
    expect(w.find('.pcr').classes()).toContain('pcr--vencido')
  })

  it('por vencer dice cuántos días faltan: es lo que hace arrancar el trámite', () => {
    const w = montar(PortalCredencial, {
      credencial: { ...CREDENCIAL, reprocann_categoria: 'por_vencer', dias_para_vencer: 12 },
    })

    expect(w.text()).toContain('Se te vence pronto')
    expect(w.text()).toContain('faltan 12 días')
  })

  it('sin REPROCANN no se rompe: manda a hablar con la organización', () => {
    const w = montar(PortalCredencial, {
      credencial: { ...CREDENCIAL, reprocann_categoria: 'sin_reprocann', reprocann_numero: null,
                    reprocann_vencimiento: null, dias_para_vencer: null, habilitado: false },
    })

    expect(w.text()).toContain('Sin REPROCANN')
    expect(w.text()).toContain('Hablá con tu organización')
  })
})

describe('El inicio del portal', () => {
  it('arranca por la credencial, no por el boletín del club', async () => {
    const w = montar(PortalHomeView)
    await flushPromises()

    expect(w.findComponent(PortalCredencial).exists()).toBe(true)
    expect(w.text()).toContain('Juan Gómez')
  })

  it('muestra el próximo turno con su fecha y su médico', async () => {
    api.getPortalMiSalud.mockResolvedValue({
      tiene_modulo: true,
      proximo_turno: { id: 1, fecha_hora: '2026-09-03T15:30:00Z', tipo_label: 'Seguimiento', medico: 'Ana Pérez' },
      turnos: [], indicacion: null,
    })

    const w = montar(PortalHomeView)
    await flushPromises()

    expect(w.text()).toContain('Próximo turno')
    expect(w.text()).toContain('Ana Pérez')
  })

  // A quien paga siempre al contado, una sección con saldo cero le hace creer que debe algo.
  it('no ofrece la cuenta si la organización no se la abrió', async () => {
    const w = montar(PortalHomeView)
    await flushPromises()

    expect(w.text()).not.toContain('Mi cuenta')
  })

  it('con cuenta abierta y deuda dice cuánto debe', async () => {
    api.getPortalCuentaCorriente.mockResolvedValue({ tiene: true, debe: 8000, saldo: -8000 })

    const w = montar(PortalHomeView)
    await flushPromises()

    expect(w.text()).toContain('Debés')
    expect(w.text()).toContain('8.000')
  })

  // El motivo del rediseño: el boletín está vacío en casi toda organización, casi toda semana. La
  // pantalla tiene que servir igual.
  it('sin nada publicado sigue siendo útil: la credencial y lo suyo están', async () => {
    const w = montar(PortalHomeView)
    await flushPromises()

    expect(w.text()).toContain('Lo mío')
    expect(w.text()).toContain('Mis retiros')
    expect(w.text()).not.toContain('Del club')
  })

  it('con novedades las resume abajo, con un enlace a la sección', async () => {
    api.getPortalNoticias.mockResolvedValue([{ id: 7, titulo: 'Cosecha de agosto', preview: 'Ya está.' }])

    const w = montar(PortalHomeView)
    await flushPromises()

    expect(w.text()).toContain('Del club')
    expect(w.text()).toContain('Cosecha de agosto')
    expect(w.find('a[href="/portal/del-club"]').exists()).toBe(true)
  })
})

describe('Mi salud', () => {
  it('pone la dosis primero: es la línea que vino a buscar', async () => {
    api.getPortalMiSalud.mockResolvedValue({
      tiene_modulo: true, proximo_turno: null, turnos: [],
      indicacion: {
        id: 1, dosificacion: '3 gotas cada 8 horas', via_administracion: 'sublingual',
        patologia: 'Dolor crónico', fecha_emision: '2026-05-02', fecha_vencimiento: '2026-11-02',
        dias_hasta_vencimiento: 75, vencida: false, por_vencer: false, medico: 'Ana Pérez',
      },
    })

    const w = montar(PortalMiSaludView)
    await flushPromises()

    expect(w.find('.pms__dosis').text()).toBe('3 gotas cada 8 horas')
    expect(w.text()).toContain('Sublingual')
    expect(w.text()).toContain('Dolor crónico')
  })

  it('la indicación vencida se muestra y dice qué hacer, en vez de desaparecer', async () => {
    api.getPortalMiSalud.mockResolvedValue({
      tiene_modulo: true, proximo_turno: null, turnos: [],
      indicacion: {
        id: 1, dosificacion: '2 gotas', via_administracion: 'oral', patologia: 'X',
        fecha_emision: '2025-01-02', fecha_vencimiento: '2026-02-02',
        dias_hasta_vencimiento: -198, vencida: true, por_vencer: false, medico: 'Ana Pérez',
      },
    })

    const w = montar(PortalMiSaludView)
    await flushPromises()

    expect(w.text()).toContain('Pedí un turno para renovarla')
  })

  it('lista los turnos con su estado', async () => {
    api.getPortalMiSalud.mockResolvedValue({
      tiene_modulo: true, indicacion: null,
      proximo_turno: { id: 1, fecha_hora: '2026-09-03T15:30:00Z', tipo_label: 'Seguimiento', estado: 'confirmado', medico: 'Ana Pérez' },
      turnos: [{ id: 1, fecha_hora: '2026-09-03T15:30:00Z', tipo_label: 'Seguimiento', estado: 'confirmado', medico: 'Ana Pérez' }],
    })

    const w = montar(PortalMiSaludView)
    await flushPromises()

    expect(w.text()).toContain('Confirmado')
    expect(w.text()).toContain('Ana Pérez')
  })

  it('sin el módulo médico lo explica en vez de mostrar una pantalla vacía', async () => {
    api.getPortalMiSalud.mockResolvedValue({ tiene_modulo: false, proximo_turno: null, turnos: [], indicacion: null })

    const w = montar(PortalMiSaludView)
    await flushPromises()

    expect(w.text()).toContain('no tiene el módulo médico')
  })
})

describe('Del club — el boletín, que dejó de ser el inicio', () => {
  it('sigue entero: portada, agenda y catálogo', async () => {
    api.getPortalNoticias.mockResolvedValue([{ id: 7, titulo: 'Cosecha de agosto', preview: 'Ya está.' }])
    api.getPortalEventos.mockResolvedValue([{ id: 3, titulo: 'Cata de terpenos', fecha_inicio: '2026-09-10T20:00:00Z' }])
    api.getPortalGeneticas.mockResolvedValue([{ id: 5, nombre: 'Amnesia Haze', tipo: 'sativa', thc: 18 }])

    const w = montar(PortalDelClubView)
    await flushPromises()

    expect(w.text()).toContain('Cosecha de agosto')
    expect(w.text()).toContain('Cata de terpenos')
    expect(w.text()).toContain('Amnesia Haze')
  })

  it('sin nada publicado manda al estado del paciente, que nunca está vacío', async () => {
    const w = montar(PortalDelClubView)
    await flushPromises()

    expect(w.text()).toContain('Todavía no hay nada publicado')
    expect(w.text()).toContain('Ver mi estado')
  })
})

describe('La barra y el pie', () => {
  // Eran ocho entradas, cinco de ellas del boletín. Con ocho, ninguna se lee.
  it('la barra lleva lo del paciente y una sola entrada al boletín', async () => {
    const w = montar(PortalNavBar)
    await flushPromises()

    const links = w.findAll('.pnb__nav .pnb__link').map(a => a.text())
    expect(links).toEqual(['Inicio', 'Mi salud', 'Mis retiros', 'Del club'])
  })

  it('la barra ofrece la cuenta sólo si la organización se la abrió', async () => {
    api.getPortalCuentaCorriente.mockResolvedValue({ tiene: true, debe: 0, saldo: 0 })

    const w = montar(PortalNavBar)
    await flushPromises()

    expect(w.findAll('.pnb__nav .pnb__link').map(a => a.text())).toContain('Mi cuenta')
  })

  // Contacto era una sección con un formulario que no mandaba nada. Los datos son cuatro y viven
  // en el pie, que se ve desde todas las pantallas.
  it('el pie tiene el teléfono y el mail de la organización', async () => {
    conClub({ name: 'Club Verde', phone: '1152213512', email: 'hola@club.ar' })

    const w = montar(PortalFooter)
    await flushPromises()

    expect(w.find('a[href="tel:1152213512"]').exists()).toBe(true)
    expect(w.find('a[href="mailto:hola@club.ar"]').exists()).toBe(true)
  })

  // En escritorio la salida no estaba en ningún lado: el paciente tenía que achicar la ventana
  // para que apareciera el menú del teléfono.
  it('el pie deja cerrar sesión y llegar a sus datos', async () => {
    const w = montar(PortalFooter)
    await flushPromises()

    expect(w.find('.pfo__salir').exists()).toBe(true)
    expect(w.find('a[href="/portal/cuenta"]').exists()).toBe(true)
  })
})

describe('La franja de avisos', () => {
  it('callada cuando no hay nada urgente: si aparece siempre, se deja de leer', async () => {
    const w = montar(PortalAvisos)
    await flushPromises()

    expect(w.find('.pav').exists()).toBe(false)
  })

  // Lo de nivel `atencion` lo dice la credencial, tres centímetros más abajo y con la fecha.
  it('tampoco aparece por un aviso de atención: eso ya lo dice la credencial', async () => {
    api.getPortalMiEstado.mockResolvedValue({
      credencial: CREDENCIAL,
      avisos: [{ tipo: 'reprocann_por_vencer', nivel: 'atencion', texto: 'Vence en 20 días.' }],
    })

    const w = montar(PortalAvisos)
    await flushPromises()

    expect(w.find('.pav').exists()).toBe(false)
  })

  it('aparece con lo único que impide retirar', async () => {
    api.getPortalMiEstado.mockResolvedValue({
      credencial: CREDENCIAL,
      avisos: [{ tipo: 'reprocann_vencido', nivel: 'urgente', texto: 'Tu REPROCANN está vencido.' }],
    })

    const w = montar(PortalAvisos)
    await flushPromises()

    expect(w.find('.pav').exists()).toBe(true)
    expect(w.text()).toContain('vencido')
  })
})
