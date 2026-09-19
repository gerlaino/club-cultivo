# Qué le falta a una organización para estar operando, derivado de sus datos. Sin tabla, sin
# banderas: se calcula mirando lo que hay. Una organización recién creada nace vacía —sin
# sedes, sin salas, sin pacientes, sin correo— y la ficha del super admin mostraba 0 · 0 · 0 sin
# decir qué faltaba; el admin de la organización, por su lado, terminaba el wizard de la primera
# sede y quedaba solo. Es donde choca quien da de alta una organización sin ayuda.
#
# Lo leen DOS pantallas —la ficha del panel de plataforma y el inicio del admin— y por eso vive
# acá: la misma lista escrita dos veces es exactamente lo que se nos viene rompiendo. Los pasos
# dependen de lo contratado: a una organización sin Cultivo no se le piden salas.
module Clubs
  class PuestaEnMarcha
    def self.de(club) = new(club).call

    def initialize(club)
      @club = club
    end

    def call
      pasos = []
      # En uso personal la sede se siembra con el alta («Mi cultivo») y no se le nombra: para
      # el que cultiva en casa no existe la palabra.
      unless @club.personal?
        pasos << paso('sedes', 'Crear la primera sede', @club.sedes.count.positive?,
                      'Todo cuelga de una sede: salas, mostrador, depósitos.', '/sedes')
      end

      if @club.suite?('cultivo')
        pasos << paso('salas', 'Crear una sala de cultivo', @club.salas.count.positive?,
                      'Sin sala no hay dónde poner un lote.', '/salas')
        pasos << paso('lotes', 'Abrir el primer lote', @club.lotes.count.positive?,
                      'Con el lote arrancan las tareas, las fases y la trazabilidad.', '/lotes')
      end

      if @club.suite?('produccion_dispensa')
        pasos << paso('pacientes', 'Cargar el padrón de pacientes', @club.pacientes.count.positive?,
                      'A mano o importando el padrón. Sin pacientes no hay a quién dispensar.', '/pacientes')
      end

      if @club.feature?('mailer')
        pasos << paso('correo', 'Conectar la casilla de correo', @club.smtp_configured?,
                      'Sin casilla no salen los avisos ni los accesos al portal.', '/configuracion/correo')
      end

      # Sin equipo no hay a quién esperar: el uso personal es una sola persona.
      unless @club.personal?
        pasos << paso('equipo', 'Que entre alguien más que el admin',
                      @club.users.del_equipo.where.not(role: 'admin').where.not(visto_at: nil).exists?,
                      'Un cultivador, un dispensador: la app se prueba operando.', '/usuarios')
      end

      hechos = pasos.count { |p| p[:hecho] }
      { completa: hechos == pasos.size, hechos: hechos, total: pasos.size, pasos: pasos }
    end

    private

    def paso(clave, label, hecho, detalle, ruta)
      { clave: clave, label: label, hecho: hecho, detalle: detalle, ruta: ruta }
    end
  end
end
