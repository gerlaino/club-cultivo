# Avisa cuando la merma del mostrador se sale de lo normal DE ESA ORGANIZACIÓN.
#
# La solapa de Merma existe, pero hay que acordarse de abrirla: si sube de 1,4% a 8% nadie se
# entera hasta que alguien va a mirar, y para entonces pasaron semanas. Un informe que hay que ir
# a buscar termina siendo un informe que no se mira.
#
# NO HAY UMBRAL FIJO, y es a propósito. Un 3% puede ser normal fraccionando flor y un escándalo
# en aceite; y lo que importa no es el número absoluto sino que CAMBIÓ. Se compara la última
# semana contra las ocho anteriores de la misma organización: cada una es su propio patrón.
#
# El aviso NO acusa a nadie: la merma es inevitable y lo que dice es "acá cambió algo, andá a
# mirar". Ver `Mostradores::Merma`.
class MermaMostradorJob < ApplicationJob
  queue_as :default

  # Hace falta historia para que "cambió" signifique algo: con dos turnos, cualquier diferencia
  # parece un salto.
  TURNOS_MINIMOS = 8
  # Y un piso de volumen: 2 g sobre 10 dispensados es 20% y no dice nada.
  GRAMOS_MINIMOS = 200
  # Cuánto tiene que empeorar respecto de su propio patrón para que valga interrumpir a alguien.
  FACTOR = 2.0

  def perform
    cada_club_con(:produccion_dispensa) { |club| procesar_club(club) }
  end

  private

  def procesar_club(club)
    club.mostradores.activos.includes(:sede).each { |m| revisar(club, m) }
  end

  def revisar(club, mostrador)
    hoy      = Time.zone.today
    semana   = medir(mostrador, hoy - 6, hoy)
    anterior = medir(mostrador, hoy - 62, hoy - 7)

    return if semana[:dispensado] < GRAMOS_MINIMOS
    return if anterior[:turnos] < TURNOS_MINIMOS || anterior[:pct].nil? || semana[:pct].nil?
    return if semana[:pct] <= anterior[:pct] * FACTOR
    return if aviso_reciente?(club, mostrador)

    AlertaInterna.create!(
      club:             club,
      tipo:             'merma_mostrador',
      # El texto dice qué cambió y contra qué, no que alguien hizo algo mal.
      mensaje:          "La merma del mostrador de #{mostrador.sede&.nombre} está en " \
                        "#{semana[:pct]}% esta semana, contra #{anterior[:pct]}% de las últimas " \
                        "semanas. Conviene mirar qué producto la está moviendo.",
      severidad:        'warning',
      destinada_a_role: 'admin',
      contexto: {
        mostrador_id: mostrador.id, sede_id: mostrador.sede_id, sede_nombre: mostrador.sede&.nombre,
        pct_semana: semana[:pct], pct_previo: anterior[:pct], faltante_ars: semana[:ars],
      }
    )
  end

  def medir(mostrador, desde, hasta)
    r = Mostradores::Merma.call(mostrador: mostrador, desde: desde, hasta: hasta)[:resumen]
    { pct: r[:merma_pct], dispensado: r[:dispensado].to_f, turnos: r[:turnos].to_i,
      ars: r[:faltante_ars].to_f }
  end

  # Uno por semana y por mostrador: repetirlo todos los días es cómo se aprende a ignorarlo.
  def aviso_reciente?(club, mostrador)
    AlertaInterna.where(club: club, tipo: 'merma_mostrador')
                 .where("contexto->>'mostrador_id' = ?", mostrador.id.to_s)
                 .where('created_at > ?', 7.days.ago)
                 .exists?
  end
end
