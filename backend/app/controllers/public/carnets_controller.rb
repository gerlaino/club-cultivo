module Public
  class CarnetsController < BaseController
    self.public_tenant_mode = :token # carnet_token es global → lookup cross-club

    def show
      paciente = Paciente.where(carnet_token: params[:token]).first

      return render json: { error: 'Carnet no encontrado' }, status: :not_found unless paciente

      reprocann_estado = if paciente.reprocann_numero.blank?
        'sin_registro'
      elsif paciente.reprocann_vencimiento.nil?
        'vigente'
      elsif paciente.reprocann_vencimiento < Time.zone.today
        'vencido'
      elsif paciente.reprocann_vencimiento <= 30.days.from_now
        'por_vencer'
      else
        'vigente'
      end

      render json: {
        nombre:               paciente.nombre,
        apellido_inicial:     "#{paciente.apellido[0]}.",
        numero_socio:         paciente.id,
        estado_membresia:     paciente.deleted_at ? 'baja' : 'activo',
        reprocann_estado:     reprocann_estado,
        reprocann_vencimiento: paciente.reprocann_vencimiento,
        club: {
          nombre: paciente.club.name,
          logo:   paciente.club.logo.attached? ? url_for(paciente.club.logo) : nil,
        },
        emitido_at: paciente.created_at.to_date,
      }
    end
  end
end
