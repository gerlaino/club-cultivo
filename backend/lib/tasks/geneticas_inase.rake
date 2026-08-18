# Completar el catálogo GLOBAL de variedades inscriptas en el INASE.
#
# El catálogo es global (`club_id` NULL, `global: true`): es el registro nacional, no el de una
# organización. Contra estas variedades cada club declara lo que cultiva.
#
# Faltaba CAT3, una de las DOS primeras variedades nacionales de Cannabis sativa L. inscriptas en
# el Registro Nacional de Cultivares —junto con EVA, que sí estaba—, por las Resoluciones INASE
# 84 y 85 de 2022. Con ella el catálogo queda en las 9 que el INASE informa como inscriptas.
#
# OJO con lo que NO se carga: el INASE **no asigna un número de registro por variedad**. Lo que
# identifica a cada una es su NOMBRE en el Catálogo Nacional de Cultivares, y lo que consta
# aparte es la resolución que la inscribió. Por eso `numero_registro_inase` queda en nil acá y en
# las otras ocho: pedirlo era pedir un dato que no existe.
#
# Lo que SÍ se pudo confirmar de CAT3 va cargado; lo que no (perfil de THC/CBD, tipo) queda
# vacío en vez de inventado. En un catálogo regulatorio un campo en blanco es mejor que un dato
# que alguien supuso.
namespace :geneticas do
  desc 'Carga en el catálogo global del INASE las variedades que falten (SIMULAR=1 para ver sin escribir)'
  task inase_faltantes: :environment do
    simular = ENV['SIMULAR'].present?

    faltantes = [
      {
        nombre:      'CAT3',
        tipo:        nil,  # el perfil no está publicado
        thc:         nil,
        cbd:         nil,
        criador:     'Daniel Loza / Cultivo en Familia',
        origen:      'La Plata, Argentina',
        descripcion: 'CAT3 (Cepa Argentina Terapéutica 3). Una de las dos primeras variedades ' \
                     'nacionales de Cannabis sativa L. inscriptas en el Registro Nacional de ' \
                     'Cultivares, por las Resoluciones INASE 84 y 85 de 2022, junto con EVA. ' \
                     'Obtenida de los cultivos de Daniel Loza y las asociaciones platenses ' \
                     'Jardín del Unicornio y Cultivo en Familia, y caracterizada por la Facultad ' \
                     'de Ciencias Exactas de la UNLP. Forma parte de un proyecto que incluye ' \
                     'también CAT1 y CAT2.',
      },
    ]

    # Sin tenant: el catálogo es global y `Genetica` es tenant, así que una consulta sin esto
    # levanta `NoTenantSet` en vez de encontrar nada.
    ActsAsTenant.without_tenant do
      creadas = 0

      faltantes.each do |datos|
        # Se busca sobre TODAS las genéticas, no sólo las globales: si alguna organización cargó
        # una con ese nombre, crear la global igual rompería el índice único de slug por club.
        # Si ya está, se completan los campos que estén VACÍOS y no se pisa lo cargado a mano:
        # la primera corrida la creó sin criador ni descripción, y una tarea que sólo sabe crear
        # deja ese agujero para siempre.
        # Se busca con `unscoped` para ver también las borradas (el borrado es blando): si una
        # variedad del catálogo quedó marcada como eliminada, crearla de nuevo chocaría contra el
        # índice único de slug y además dejaría dos. Se restaura la que hay.
        existente = Genetica.unscoped.where(club_id: nil).find_by(nombre: datos[:nombre])
        if existente
          faltan = datos.reject { |campo, valor| valor.nil? || existente[campo].present? }
          faltan[:deleted_at] = nil if existente.deleted_at.present?

          if faltan.empty?
            puts "  = #{datos[:nombre]} ya está completa"
          elsif simular
            puts "  ~ #{datos[:nombre]} se completaría: #{faltan.keys.join(', ')} (simulación)"
          else
            existente.update_columns(faltan)
            puts "  ~ #{datos[:nombre]} completada: #{faltan.keys.join(', ')}"
          end
          next
        end

        if simular
          puts "  + #{datos[:nombre]} se crearía (simulación)"
          creadas += 1
          next
        end

        Genetica.create!(
          datos.merge(
            club_id:          nil,
            global:           true,
            # Obligatorio para las globales: `Genetica` valida que una global esté registrada.
            registrada_inase: true,
            activa:           true,
            disponible:       false, # es una variedad de referencia, no algo que el club cultive
          )
        )
        puts "  + #{datos[:nombre]} creada"
        creadas += 1
      end

      total = Genetica.unscoped.where(club_id: nil).count
      puts ''
      puts simular ? "Simulación: se crearían #{creadas}." : "Listo: #{creadas} creada(s)."
      puts "Catálogo global: #{total} variedades#{simular ? " (quedaría en #{total + creadas})" : ''}."
    end
  end
end
