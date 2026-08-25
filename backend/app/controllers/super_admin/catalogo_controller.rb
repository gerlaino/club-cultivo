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
          usuarios_por_rol: l[:usuarios_por_rol],
          # Cada tope con la suite a la que le importa. El wizard elige los módulos ANTES que el
          # plan, así que puede mostrar sólo los topes que aplican: nombrarle salas y plantas a
          # una organización que no compró Cultivo es la mitad de la tarjeta en ruido, y no hay
          # forma de saber desde ahí cuáles cuentan.
          recursos: PlanEnforcer::RECURSOS.map { |r|
            { clave: r, label: RECURSO_LABEL[r], valor: l[r],
              texto: l[r].nil? ? "#{RECURSO_LABEL[r]} sin límite" : "#{l[r]} #{RECURSO_LABEL[r]}",
              suite: PlanEnforcer::RECURSO_SUITE[r] }
          },
          # Se mantiene para lo que ya lo consumía.
          resumen:  PlanEnforcer::RECURSOS.map { |r|
            l[r].nil? ? "#{RECURSO_LABEL[r]} sin límite" : "#{l[r]} #{RECURSO_LABEL[r]}"
          },
        }
      },
      # Con qué nace una organización si no se toca nada. La pantalla del alta tenía su propia
      # copia (`{ cultivo, produccion_dispensa, bar }`) y el backend mergeaba la suya encima: el
      # wizard mostraba Delivery y Correo APAGADOS y la organización se creaba con los dos
      # prendidos. La pantalla decía una cosa y pasaba otra.
      features_por_defecto: Club::FEATURES_POR_DEFECTO,
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
      # Con el módulo del que depende cada rol: el alta elige los módulos antes que los usuarios,
      # así que la pantalla puede ofrecer sólo los roles que van a poder entrar. Un cultivador en
      # una organización sin Cultivo loguea a una app sin una sola pantalla, y el que lo descubre
      # es el cliente.
      roles_alta: Club::ROLES_ALTA.map { |r|
        modulo = Club::MODULO_POR_ROL[r]
        { clave: r, label: Club::ROLES_META.dig(r, :label), desc: Club::ROLES_META.dig(r, :desc),
          requiere_modulo: modulo, requiere_modulo_label: modulo && Club.label_modulo(modulo) }
      },
      # Los tramos de IA. Ya NO se eligen: hay uno por plan y salen de ahí (`Club#ia_config`).
      # Se siguen sirviendo para poder mostrar cuánto trae cada plan, que es lo que se vende.
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
