# Cuánto cuesta cada cosa, por mes y en DÓLARES. UNA constante, no una tabla: los precios cambian
# dos veces por año y con un commit alcanza; una pantalla para editarlos es una perilla más que
# nadie pidió. Cuando haya que cobrar distinto a una organización, ese día se agrega una columna
# de descuento — no antes.
#
# LA LISTA (6-oct-2026, Germán y su socio). Los packs cobran por TAMAÑO (`PlanEnforcer::PLANES`):
#
#   Autocultivo ............................ USD 8
#   Hasta 50 pacientes:  un pack USD 200 · Cultivo + Producción y dispensa USD 350
#   Hasta 100 pacientes: un pack USD 400 · los dos USD 700
#   Pack de 10 pacientes más ............... USD 80 (8 por paciente)
#   Sede extra ............................. USD 50
#
# Todo lo terminado viene adentro (`Club::INCLUIDOS_EN_SUITE`). Los extras (`Club::ADDONS` con
# `tipo: 'extra'`) todavía no se venden (`Club::EXTRAS_SIN_LANZAR`) y cuestan 0: el día que se
# lance uno, su precio va a `EXTRAS`.
#
# Las pantallas no suman nada por su cuenta: el alta del super admin pide la cuenta a
# `GET /super_admin/catalogo/cotizar`, que llama a `cotizar` — la misma que usa `de(club)`.
module Precios
  MONEDA = 'USD'.freeze

  AUTOCULTIVO = 8

  # Por escalón, cuánto cuesta según cuántos packs (Cultivo, Producción y dispensa) lleva.
  PACKS = {
    'basico' => { 1 => 200, 2 => 350 },
    'total'  => { 1 => 400, 2 => 700 },
  }.freeze

  PACIENTE_EXTRA = 8
  PACK_PACIENTES = PACIENTE_EXTRA * PlanEnforcer::PACK_PACIENTES
  SEDE_EXTRA     = 50

  # Los extras ya lanzados, con su precio. Vacío: están todos en desarrollo.
  EXTRAS = {}.freeze

  def self.extra(clave) = EXTRAS.fetch(clave.to_s, 0)

  # El precio de lista del escalón con esa cantidad de packs (lo que muestra el catálogo).
  def self.escalon(plan, packs)
    plan = PlanEnforcer.normalizar(plan)
    return AUTOCULTIVO if plan == 'personal'

    PACKS.dig(plan, packs.to_i) || 0
  end

  # La lista que muestran las páginas públicas (/bienvenida y sus dos puertas). Los números salen
  # de acá y de `PlanEnforcer::PLANES`; el texto de las tarjetas lo arma la página.
  def self.lista_publica
    personal = PlanEnforcer::PLANES['personal']
    {
      moneda: MONEDA,
      autocultivo: { precio: AUTOCULTIVO, plantas_floracion: personal[:plantas], espacios: personal[:salas] },
      escalones: PACKS.map { |clave, precios|
        l = PlanEnforcer::PLANES[clave]
        { clave: clave, label: l[:label], un_pack: precios[1], dos_packs: precios[2],
          pacientes: l[:pacientes], plantas_floracion: l[:plantas], salas: l[:salas], sedes: l[:sedes],
          usuarios_por_rol: l[:usuarios_por_rol], por_sede: l[:por_sede] }
      },
      pack_pacientes: { pacientes: PlanEnforcer::PACK_PACIENTES,
                        plantas_floracion: PlanEnforcer::PACK_PACIENTES * PlanEnforcer::PLANTAS_POR_PACIENTE,
                        precio: PACK_PACIENTES, por_paciente: PACIENTE_EXTRA },
      sede_extra: SEDE_EXTRA,
    }
  end

  # El desglose de una organización: qué paga y por qué, con el total. Es lo que se muestra en
  # la ficha y lo que suma el panel.
  def self.de(club)
    cotizar(plan: club.plan,
            suites: Club::SUITES.keys.select { |k| club.suite?(k) },
            packs_pacientes: club.packs_pacientes_extra,
            sedes_extra: club.sedes_extra,
            extras: Club::ADDONS.keys.select { |k| Club.extra?(k) && club.feature?(k) })
  end

  # La cuenta, para una organización que existe o para una que se está por crear.
  def self.cotizar(plan:, suites: [], packs_pacientes: 0, sedes_extra: 0, extras: [])
    plan   = PlanEnforcer.normalizar(plan)
    suites = Array(suites).map(&:to_s) & Club::SUITES.keys
    lineas = []

    if plan == 'personal'
      lineas << { tipo: 'plan', clave: plan, label: 'Autocultivo', monto: AUTOCULTIVO }
    else
      escalon = PlanEnforcer::PLANES.dig(plan, :label)
      nombres = suites.map { |s| Club::SUITES.dig(s, :label) }.join(' + ')
      lineas << { tipo: 'plan', clave: plan,
                  label: suites.any? ? "#{escalon} · #{nombres}" : "#{escalon} · sin packs",
                  monto: escalon(plan, suites.size) }

      packs = packs_pacientes.to_i
      if packs.positive?
        lineas << { tipo: 'pacientes_extra', clave: 'pacientes_extra',
                    label: "#{packs} #{packs == 1 ? 'pack' : 'packs'} de #{PlanEnforcer::PACK_PACIENTES} pacientes más",
                    monto: packs * PACK_PACIENTES }
      end

      sedes = sedes_extra.to_i
      if sedes.positive?
        lineas << { tipo: 'sedes_extra', clave: 'sedes_extra',
                    label: "#{sedes} #{sedes == 1 ? 'sede extra' : 'sedes extra'}",
                    monto: sedes * SEDE_EXTRA }
      end
    end

    Array(extras).map(&:to_s).select { |k| Club.extra?(k) }.each do |k|
      sin_lanzar = Club::EXTRAS_SIN_LANZAR.include?(k)
      lineas << { tipo: 'extra', clave: k,
                  label: sin_lanzar ? "#{Club::ADDONS.dig(k, :label)} (en desarrollo, sin cargo)" : Club::ADDONS.dig(k, :label),
                  monto: sin_lanzar ? 0 : extra(k) }
    end

    { lineas: lineas, total: lineas.sum { |l| l[:monto] }, moneda: MONEDA }
  end
end
