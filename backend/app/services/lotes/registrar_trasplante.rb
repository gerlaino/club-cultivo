module Lotes
  # Registra un trasplante de un lote: crea un PlantActivity 'transplant' por planta
  # (incluidas las ya cosechadas, porque un trasplante pasado se registra sobre el
  # lote tal como estaba) con la maceta origen→destino que muestra la timeline.
  # Si el lote sigue en cultivo, actualiza además su tamaño de maceta actual.
  # Se puede backdatear (fecha pasada). Lo usan el botón "Registrar trasplante" del
  # lote y la completación de la tarea de trasplante.
  class RegistrarTrasplante
    # Estados en los que el lote ya salió del cultivo: registrar un trasplante pasado
    # sigue siendo válido (es historia), pero NO se toca la "maceta actual".
    ESTADOS_POST_COSECHA = %w[cosecha secado curado en_manicura manicura_pendiente finalizado].freeze

    Result = Struct.new(:ok, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(lote:, usuario:, destino:, origen: nil, fecha: nil)
      @lote    = lote
      @usuario = usuario
      @destino = destino.to_d
      @origen  = origen.presence&.to_d
      @fecha   = fecha
    end

    def call
      return Result.new(ok: false, error: 'Indicá la maceta destino (en litros).') if @destino <= 0

      occurred = (@fecha.present? ? (Date.parse(@fecha.to_s) rescue Date.current) : Date.current)
                   .in_time_zone.change(hour: 12)
      # Incluimos cosechadas (NO descartadas): un trasplante pasado se registra sobre
      # las plantas que vivieron ese trasplante, aunque el lote ya esté cosechado.
      plants = @lote.plants.where.not(state: 'descartada')
      return Result.new(ok: false, error: 'El lote no tiene plantas para registrar el trasplante.') if plants.empty?

      ActiveRecord::Base.transaction do
        plants.find_each do |p|
          p.activities.create!(
            user:          @usuario,
            activity_type: 'transplant',
            description:   "Trasplante#{@origen ? " de #{@origen.to_f}L" : ''} a #{@destino.to_f}L",
            occurred_at:   occurred,
            metadata:      { 'maceta_origen_l' => @origen&.to_f, 'maceta_destino_l' => @destino.to_f },
          )
        end

        # Rastro en el historial unificado (categoria=trasplante con la maceta en metadata).
        @lote.lote_eventos.create!(
          tipo: 'actividad', categoria: 'trasplante', user: @usuario, club: @lote.club,
          registrado_en: occurred,
          descripcion: nil,
          metadata: {
            'maceta_origen_l'  => @origen&.to_f,
            'maceta_destino_l' => @destino.to_f,
            'plantas'          => plants.size,
          },
        )

        # Solo actualizamos la "maceta actual" si el lote sigue en cultivo.
        @lote.update!(tamanio_maceta: @destino) unless ESTADOS_POST_COSECHA.include?(@lote.estado)
      end
      Result.new(ok: true)
    rescue => e
      Result.new(ok: false, error: e.message)
    end
  end
end
