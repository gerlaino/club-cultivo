# Variedades que la organización no puede acreditar ante el INASE: o están inscriptas, o se
# declaran contra una que lo esté.
#
# ANTES BLOQUEABA TODA DESCARGA Y ESO ESTABA MAL. La app no es un canal oficial: nada de lo que
# se baja se presenta solo. Lo que se descarga es, por defecto, el material con el que la
# organización mira SU realidad — y negárselo la dejaba sin poder ver su propio problema, con un
# cartel que además invitaba a reintentar algo que no iba a andar nunca.
#
# Quedan DOS caminos, y la diferencia la pide quien descarga (`para_presentar`):
#   · normal        → sale siempre, completo, con una SALVEDAD arriba nombrando qué no se puede
#                     acreditar. El documento no miente: sin declarar, la variedad ya sale con su
#                     nombre de uso, así que la salvedad nombra lo que el papel ya muestra.
#   · para presentar → valida. Si falta algo no sale, y dice qué falta.
#
# El día que exista presentación directa desde la app, el segundo camino ya es el que corresponde.
module DeclaracionInaseGuard
  extend ActiveSupport::Concern

  private

  # ¿Quien descarga dijo que es para presentar ante la autoridad? Es explícito a propósito: no
  # se deduce del informe, porque el mismo informe sirve para las dos cosas.
  def para_presentar?
    ActiveModel::Type::Boolean.new.cast(params[:para_presentar]).present?
  end

  # Las genéticas que no están inscriptas ni declaradas. nil si está todo en orden.
  #
  # `ids` acota a las variedades que REALMENTE aparecen en el documento. Un informe de la
  # organización (INASE, semestral) habla de toda la organización y va sin acotar; la trazabilidad
  # de un frasco habla de ESE frasco, y avisar ahí por una variedad que no lo tocó nunca es ruido
  # que enseña a ignorar el recuadro.
  def geneticas_sin_declarar(ids: nil)
    scope = current_user.club.geneticas.where(registrada_inase: [false, nil], declarada_como_id: nil)
    scope = scope.where(id: ids) if ids

    scope.order(:nombre).pluck(:nombre).presence
  end

  # Para el camino normal: qué decir en el papel. nil = no hay nada que aclarar.
  def salvedad_inase(ids: nil)
    geneticas_sin_declarar(ids: ids)
  end

  # Para el camino "para presentar": devuelve true si CORTÓ (ya renderizó el error) y el llamador
  # tiene que frenar ahí. Sin `para_presentar` no corta nunca.
  def bloquear_descarga_si_falta_declarar!(ids: nil)
    return false unless para_presentar?

    pendientes = geneticas_sin_declarar(ids: ids)
    return false if pendientes.nil?

    render json: {
      error: 'No se puede presentar el informe: hay variedades que la organización no puede acreditar ' \
             'ante el INASE. Declará cada una contra una variedad inscripta desde su ficha, o descargalo ' \
             'sin marcar "para presentar" para verlo igual.',
      geneticas_sin_declarar: pendientes,
      requiere_declaracion_inase: true,
    }, status: :unprocessable_entity
    true
  end
end
