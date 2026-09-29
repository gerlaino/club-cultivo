module Webhooks
  # POST /webhooks/riegos  { dispositivo_id, ml_por_maceta, timestamp? }  (header X-Webhook-Token)
  #
  # El aparato que maneja la bomba avisa que regó; el riego queda en cada lote en cultivo de su
  # sala, como si lo hubiera cargado una persona. Sincrónico (no job): el aparato necesita saber
  # si quedó (201), si ya estaba (200, reintento) o si no hay dónde anotarlo (422, no reintentar).
  class RiegosController < ActionController::API
    include AutenticaDispositivo

    def create
      r = ActsAsTenant.with_tenant(@dispositivo.club) do
        Riegos::RegistrarDesdeDispositivo.new(@dispositivo,
                                              ml_por_maceta: params[:ml_por_maceta],
                                              timestamp:     params[:timestamp]).call
      end
      return render json: { error: r.error }, status: :unprocessable_entity if r.error

      render json: {
        duplicado: r.duplicado,
        lotes: r.registros.map { |reg| { id: reg.lote_id, codigo: reg.lote.codigo, litros: reg.litros.to_f } },
      }, status: (r.duplicado ? :ok : :created)
    end
  end
end
