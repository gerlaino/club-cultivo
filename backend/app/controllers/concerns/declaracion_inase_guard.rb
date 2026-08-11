# Un informe que se PRESENTA ante el organismo no puede nombrar variedades que la organización no
# puede acreditar: o están inscriptas en el INASE, o se declaran contra una que lo esté.
#
# Se bloquea la DESCARGA (PDF / Excel), nunca la pantalla. El informe INASE en pantalla es
# justamente el que lista qué falta declarar: bloquearlo dejaría a la organización sin poder ver su
# propio problema, y con veintipico de variedades pendientes nunca podría destrabarse.
module DeclaracionInaseGuard
  extend ActiveSupport::Concern

  private

  # Las genéticas de la organización que no están inscriptas ni declaradas. nil si está todo en orden.
  def geneticas_sin_declarar
    current_user.club.geneticas
                .where(registrada_inase: [false, nil], declarada_como_id: nil)
                .order(:nombre)
                .pluck(:nombre)
                .presence
  end

  # Devuelve true si CORTÓ (ya renderizó el error). El llamador tiene que frenar ahí.
  def bloquear_descarga_si_falta_declarar!
    pendientes = geneticas_sin_declarar
    return false if pendientes.nil?

    render json: {
      error: 'No se puede descargar el informe: hay variedades que la organización no puede acreditar ' \
             'ante el INASE. Declará cada una contra una variedad inscripta desde su ficha.',
      geneticas_sin_declarar: pendientes,
      requiere_declaracion_inase: true,
    }, status: :unprocessable_entity
    true
  end
end
