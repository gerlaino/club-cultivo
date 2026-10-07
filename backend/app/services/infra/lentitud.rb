# ¿ESTÁ RÁPIDA LA APP? Lo que contesta el panel de Estado con los tiempos que junta
# `Metricas::Respuesta`: lo más lento de hoy (qué, dónde, cuánto tarda la mayoría de las veces) y
# cómo anduvo hora por hora en las últimas 24.
#
# «La mayoría de las veces» es el percentil 75: el promedio lo arrastra un pedido raro, y el máximo
# asusta por uno solo. En pantalla nunca dice «percentil».
module Infra
  class Lentitud
    NORMAL_MS = 500
    LENTO_MS  = 1500
    # Con menos pedidos que esto, un número alto es casualidad, no un problema.
    MINIMO_PEDIDOS = 5

    ACCIONES = { 'index' => 'lista', 'show' => 'ficha', 'create' => 'alta', 'update' => 'edición',
                 'destroy' => 'baja' }.freeze
    # Los que más se abren, con el nombre que les da quien usa la app.
    NOMBRES = {
      'DispensacionesController#index'    => 'Lista de dispensas',
      'DispensacionesController#create'   => 'Registrar una dispensa',
      'PacientesController#index'         => 'Lista de pacientes',
      'PacientesController#show'          => 'Ficha del paciente',
      'StocksController#index'            => 'Stock',
      'LotesController#index'             => 'Lista de lotes',
      'LotesController#show'              => 'Ficha del lote',
      'TareasController#index'            => 'Tareas',
      'MeController#show'                 => 'Entrar a la app',
      'Users::SessionsController#create'  => 'Iniciar sesión',
      'InformesController#show'           => 'Un informe',
      'MostradoresController#show'        => 'Mostrador',
      'DashboardController#show'          => 'Inicio',
    }.freeze

    def self.call = new.call

    def call
      hoy = filas_desde(Time.current.beginning_of_day)
      lentas = hoy.select { |f| f['cantidad'].to_i >= MINIMO_PEDIDOS }
                  .map { |f| fila_visible(f) }
                  .sort_by { |f| -f[:ms] }
                  .first(6)
      peor = lentas.first
      estado = if peor.nil? then 'ok'
               elsif peor[:ms] >= LENTO_MS * 2 then 'mal'
               elsif peor[:ms] >= LENTO_MS then 'atencion'
               else 'ok'
               end
      {
        estado: estado,
        normal_ms: NORMAL_MS, lento_ms: LENTO_MS,
        pedidos_hoy: hoy.sum { |f| f['cantidad'].to_i },
        general_ms: Metricas::Respuesta.percentil(sumar(hoy)),
        lentas: lentas,
        por_hora: por_hora,
      }
    rescue ActiveRecord::StatementInvalid => e
      # La tabla todavía no existe (deploy a medias): el panel no se cae por esto.
      Rails.logger.warn("[lentitud] #{e.message}")
      { estado: 'desconocido', lentas: [], por_hora: [], normal_ms: NORMAL_MS, lento_ms: LENTO_MS }
    end

    def self.nombre(endpoint)
      return NOMBRES[endpoint] if NOMBRES.key?(endpoint)

      controller, action = endpoint.to_s.split('#')
      base = controller.to_s.split('::').last.to_s.delete_suffix('Controller').underscore.humanize
      [base, ACCIONES[action] || action.to_s.tr('_', ' ')].compact_blank.join(' · ')
    end

    private

    def filas_desde(desde)
      ActiveRecord::Base.connection.exec_query(<<~SQL, 'Lentitud', [desde]).to_a
        SELECT endpoint, club_id, SUM(cantidad) AS cantidad, SUM(total_ms) AS total_ms, MAX(max_ms) AS max_ms,
               #{(0..7).map { |i| "SUM(b#{i}) AS b#{i}" }.join(', ')}, MIN(hora) AS desde
        FROM metricas_respuesta WHERE hora >= $1 GROUP BY endpoint, club_id
      SQL
    end

    def fila_visible(f)
      {
        endpoint: f['endpoint'],
        que:      self.class.nombre(f['endpoint']),
        donde:    nombre_club(f['club_id'].to_i),
        ms:       Metricas::Respuesta.percentil(f),
        veces:    f['cantidad'].to_i,
        maximo_ms: f['max_ms'].to_i,
      }
    end

    def nombre_club(id)
      return 'sin organización' if id.zero?

      @clubes ||= Club.unscoped.pluck(:id, :name).to_h
      @clubes[id] || "organización ##{id}"
    end

    def sumar(filas)
      base = { 'cantidad' => 0, 'max_ms' => 0 }
      (0..7).each { |i| base["b#{i}"] = 0 }
      filas.each_with_object(base) do |f, acc|
        acc['cantidad'] += f['cantidad'].to_i
        acc['max_ms'] = [acc['max_ms'], f['max_ms'].to_i].max
        (0..7).each { |i| acc["b#{i}"] += f["b#{i}"].to_i }
      end
    end

    def por_hora
      desde = 23.hours.ago.beginning_of_hour
      filas = ActiveRecord::Base.connection.exec_query(<<~SQL, 'Lentitud', [desde]).to_a
        SELECT hora, SUM(cantidad) AS cantidad, MAX(max_ms) AS max_ms, #{(0..7).map { |i| "SUM(b#{i}) AS b#{i}" }.join(', ')}
        FROM metricas_respuesta WHERE hora >= $1 GROUP BY hora ORDER BY hora
      SQL
      por = filas.index_by { |f| f['hora'].to_time.to_i }
      (0..23).map do |i|
        h = desde + i.hours
        f = por[h.to_i]
        { hora: h.iso8601, pedidos: f ? f['cantidad'].to_i : 0, ms: f ? Metricas::Respuesta.percentil(f) : nil }
      end
    end
  end
end
