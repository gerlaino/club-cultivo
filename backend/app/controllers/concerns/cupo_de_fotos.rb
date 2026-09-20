# La red de las fotos, para las tres puertas por las que entran (lote, sala, planta): el tope
# del plan y el tamaño de cada archivo. Vive en un concern y no repetido en cada controller
# porque la regla es UNA, y el día que cambie el número tiene que cambiar en un solo lugar.
#
# El backend valida lo que la UI esconde: la galería ya dice «llegaste a 300 fotos» y apaga la
# cámara, pero lo que decide es esto.
module CupoDeFotos
  extend ActiveSupport::Concern

  private

  # `nil` si la foto cabe; si no, renderiza el error y devuelve algo truthy para cortar.
  def rechazar_foto_si_no_cabe!(archivo)
    if archivo.respond_to?(:size) && archivo.size.to_i > PlanEnforcer::FOTO_MAX_BYTES
      mb = (PlanEnforcer::FOTO_MAX_BYTES / 1.megabyte).to_i
      render json: { error: "La foto pesa más de #{mb} MB. Sacala de nuevo con menos resolución o achicala antes de subirla." },
             status: :unprocessable_entity
      return true
    end

    enforcer = PlanEnforcer.new(current_user.club)
    return nil if enforcer.puede_subir_foto?

    info = enforcer.info
    render json: PlanEnforcer.error_limite('fotos', info[:limites][:fotos], plan: info[:label])
                             .merge(cupo: enforcer.cupo_fotos), status: :payment_required
    true
  end
end
