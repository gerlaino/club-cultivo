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
      # Una dispensa puede abarcar varias líneas (multi-stock). Reportamos cada producto por
      # separado en `items`; los campos planos quedan para compatibilidad (primera línea).
      lineas = @dispensacion.items.map do |it|
        st = it.stock
        {
          cantidad_g:     it.cantidad&.to_f,
          forma_producto: st&.forma_producto,
          numero_lote:    st&.numero_lote_producto || it.lote_codigo,
        }
      end
      primera = lineas.first || {}

      {
        fecha:              @dispensacion.fecha_dispensacion&.to_s,
        cantidad_g:         @dispensacion.cantidad_total.to_f,
        unidad:             @dispensacion.unidad,
        forma_producto:     primera[:forma_producto],
        numero_lote:        primera[:numero_lote],
        items:              lineas,
        club_cuit:          @dispensacion.paciente.club.cuit,
        paciente_reprocann: @dispensacion.paciente.reprocann_numero,
        indicacion_id:      @dispensacion.indicacion_medica_id,
      }
    end
  end
end
