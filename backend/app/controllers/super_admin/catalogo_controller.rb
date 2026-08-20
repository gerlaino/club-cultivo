# Qué se puede vender, servido por el backend.
#
# Antes cada pantalla del super admin repetía la lista de módulos a mano —con sus labels, sus
# íconos y sus advertencias— y las tres copias ya decían cosas distintas entre sí y con
# `Club::ADDONS`. Un módulo nuevo obligaba a acordarse de cuatro lugares.
#
# Acá sale UNA vez, del modelo, y las pantallas la consumen.
class SuperAdmin::CatalogoController < SuperAdmin::BaseController
  def show
    render json: {
      planes: PlanEnforcer::PLANES.map { |clave, l|
        {
          clave:    clave,
          label:    l[:label],
          limites:  PlanEnforcer::RECURSOS.to_h { |r| [r, l[r]] },
          # Para la tarjeta del wizard: "1 sede · 3 salas · …" sin que el frontend
          # tenga que saber cómo se dice cada recurso.
          resumen:  PlanEnforcer::RECURSOS.map { |r|
            l[r].nil? ? "#{RECURSO_LABEL[r]} sin límite" : "#{l[r]} #{RECURSO_LABEL[r]}"
          },
        }
      },
      suites: Club::SUITES.map { |k, v| { clave: k, label: v[:label], desc: v[:desc] } },
      addons: Club::ADDONS.map { |k, v|
        { clave: k, label: v[:label], desc: v[:desc], requiere: v[:requiere],
          pack: v[:pack], pack_label: v[:pack] && Club::SUITES.dig(v[:pack], :label),
          bloqueado: Club.addon_bloqueado?(k), motivo_bloqueo: Club::ADDONS_BLOQUEADOS[k],
          incompleto: Club::ADDONS_INCOMPLETOS.include?(k) }
      },
      # Vienen dentro de una suite: se muestran para que se sepa qué entra, sin interruptor.
      incluidos: Club::INCLUIDOS_EN_SUITE.map { |k, suite|
        meta = Club::INCLUIDOS_META[k]
        { clave: k, label: meta[:label], desc: meta[:desc], requiere: meta[:requiere],
          incluido_en: suite, incluido_en_label: Club::SUITES.dig(suite, :label) }
      },
      en_construccion: Club::EN_CONSTRUCCION.map { |k, v|
        { clave: k, label: v[:label], desc: v[:desc], requiere: v[:requiere] }
      },
      roles_alta: Club::ROLES_ALTA.map { |r| { clave: r, label: Club::ROLES_META.dig(r, :label),
                                               desc: Club::ROLES_META.dig(r, :desc) } },
      # Los tramos de IA con sus DOS topes. El panel los duplicaba a mano (`[20,60,200]` escrito
      # en el template), así que cambiar un tramo acá dejaba a la pantalla escribiendo el valor
      # viejo: la misma duplicación que ya había pasado con la lista de módulos.
      ia_tiers: Club::IA_TIERS.map { |clave, t|
        { clave: clave, label: t[:label], limite_hora: t[:limite_hora],
          limite_mes: t[:limite_mes], color: t[:color] }
      },
      # `password_default` NO viaja más: era la credencial fija de la plataforma, y el panel la
      # usaba para precargar el campo del formulario. Ahora cada alta genera la suya y el endpoint
      # de creación la devuelve en `password_inicial` para dictarla.
    }
  end

  private

  RECURSO_LABEL = {
    sedes: 'sedes', salas: 'salas', lotes: 'lotes',
    plantas: 'plantas', pacientes: 'pacientes', usuarios: 'usuarios',
  }.freeze
end
