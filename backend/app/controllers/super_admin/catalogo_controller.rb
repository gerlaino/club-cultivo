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
          # Cuánto cuesta el escalón según cuántos packs lleve (1 o 2). El autocultivo tiene
          # un solo precio.
          precios:  clave == 'personal' ? { 0 => Precios::AUTOCULTIVO } : Precios::PACKS[clave],
          precio_mensual: Precios.escalon(clave, 1),
          limites:  PlanEnforcer::RECURSOS.to_h { |r| [r, l[r]] },
          usuarios_por_rol: l[:usuarios_por_rol],
          # true = el cupo de usuarios es por sede (dos de cada rol EN CADA sede).
          por_sede: l[:por_sede],
          # `false` = plan de una sola persona: el alta no ofrece equipo ni módulos.
          equipo:   l[:equipo] != false,
          personal: clave == 'personal',
          # Cada tope con la suite a la que le importa: el alta muestra sólo los que aplican a lo
          # que se eligió.
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
      # Lo que se compra encima del escalón.
      pack_pacientes: { pacientes: PlanEnforcer::PACK_PACIENTES,
                        plantas: PlanEnforcer::PACK_PACIENTES * PlanEnforcer::PLANTAS_POR_PACIENTE,
                        precio_mensual: Precios::PACK_PACIENTES },
      sede_extra:     { precio_mensual: Precios::SEDE_EXTRA },
      # Con qué nace una organización si no se toca nada.
      features_por_defecto: Club::FEATURES_POR_DEFECTO,
      # Con qué nace un uso personal, y lo único que puede tener.
      features_personal:    Club::FEATURES_PERSONAL,
      modulos_personal:     Club::MODULOS_PERSONAL,
      moneda: Precios::MONEDA,
      suites: Club::SUITES.map { |k, v| { clave: k, label: v[:label], desc: v[:desc] } },
      addons: Club::ADDONS.map { |k, v|
        { clave: k, label: v[:label], desc: v[:desc], requiere: v[:requiere],
          # `extra` se cobra aparte; `incluido_proximo` va a venir incluido cuando esté listo.
          tipo: v[:tipo], sin_lanzar: Club::EXTRAS_SIN_LANZAR.include?(k),
          precio_mensual: Precios.extra(k),
          pack: v[:pack], pack_label: v[:pack] && Club::SUITES.dig(v[:pack], :label),
          bloqueado: Club.addon_bloqueado?(k), motivo_bloqueo: Club::ADDONS_BLOQUEADOS[k],
          incompleto: Club::ADDONS_INCOMPLETOS.include?(k) }
      },
      # Vienen dentro de los packs: se muestran para que se sepa qué entra, sin interruptor.
      incluidos: Club::INCLUIDOS_EN_SUITE.map { |k, suites|
        meta = Club::INCLUIDOS_META[k]
        { clave: k, label: meta[:label], desc: meta[:desc], requiere: meta[:requiere],
          incluido_en: suites, incluido_en_label: suites.map { |s| Club::SUITES.dig(s, :label) }.join(' o ') }
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

  # GET /super_admin/catalogo/cotizar?plan=&suites[]=&packs_pacientes=&sedes_extra=&extras[]=
  #
  # La cuenta de lo que se está por dar de alta. La hace `Precios.cotizar`, la misma que arma el
  # desglose de una organización que ya existe: la pantalla no suma precios por su cuenta.
  def cotizar
    render json: Precios.cotizar(plan: params[:plan],
                                 suites: Array(params[:suites]),
                                 packs_pacientes: [params[:packs_pacientes].to_i, 0].max,
                                 sedes_extra: [params[:sedes_extra].to_i, 0].max,
                                 extras: Array(params[:extras]))
  end

  private

  RECURSO_LABEL = {
    sedes: 'sedes', salas: 'salas', lotes: 'lotes',
    plantas: 'plantas en floración', pacientes: 'pacientes', usuarios: 'usuarios', fotos: 'fotos',
  }.freeze
end
