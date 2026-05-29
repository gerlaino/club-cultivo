module Ariccame
  # Registra una dispensación a paciente en ARICCAME/ANMAT.
  class ReportadorDispensacion
    def initialize(dispensacion)
      @dispensacion = dispensacion
    end

    def call
      return if @dispensacion.ariccame_reportada?
      # Guard contra double-create si update_column falla entre reintentos del job.
      return if AriccameRegistro.exists?(dispensacion: @dispensacion)

      # TODO: ariccame_reportada se setea al crear el registro local (estado: 'pendiente').
      # La transmisión real a ARICCAME/ANMAT aún no está implementada — ver AriccameRegistro.estado.
      AriccameRegistro.create!(
        club:         @dispensacion.paciente.club,
        dispensacion: @dispensacion,
        tipo:         'dispensacion',
        estado:       'pendiente',
        payload:      build_payload,
      )

      @dispensacion.update_column(:ariccame_reportada, true)
    end

    private

    def build_payload
      {
        fecha:              @dispensacion.fecha_dispensacion&.to_s,
        cantidad_g:         @dispensacion.cantidad&.to_f,
        unidad:             @dispensacion.unidad,
        forma_producto:     @dispensacion.stock&.forma_producto,
        numero_lote:        @dispensacion.stock&.numero_lote_producto,
        club_cuit:          @dispensacion.paciente.club.cuit,
        paciente_reprocann: @dispensacion.paciente.reprocann_numero,
        indicacion_id:      @dispensacion.indicacion_medica_id,
      }
    end
  end
end
