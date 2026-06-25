module Lotes
  # Registra un trasplante de un lote: crea un PlantActivity 'transplant' por planta
  # activa con la maceta origen→destino (lo que muestra la timeline) y actualiza el
  # tamaño de maceta actual del lote. Se puede backdatear (fecha pasada).
  # Lo usan el botón "Registrar trasplante" del lote y la completación de la tarea.
  class RegistrarTrasplante
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
      plants = @lote.plants.where.not(state: %w[descartada cosechado])
      return Result.new(ok: false, error: 'El lote no tiene plantas activas para trasplantar.') if plants.empty?

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
        @lote.update!(tamanio_maceta: @destino)
      end
      Result.new(ok: true)
    rescue => e
      Result.new(ok: false, error: e.message)
    end
  end
end
